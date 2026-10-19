"""
Finds EWT accounts with no application activity in the last N years.

Activity source is AT_MODULE_ACCESS.ENTER_DATE - the record of a user opening a
module. AT_LOGONS_LOG looks like the obvious source but was abandoned in May 2016
at every site, so it would mark the entire population dormant.

Two passes:
  1. page through everything since the cutoff, per site  -> who IS active
  2. for everyone else, ask each site for their single most recent row
     -> when they were last seen, so "dormant" can be dated rather than assumed

Usage: python scripts/find-dormant-users.py [--years 2] [--api http://localhost:5199]
Output: analysis/ewt-user-activity.csv
"""

import argparse
import collections
import csv
import datetime
import json
import os
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

SITES = ["CORP", "BCTN", "CLUT", "EWTN", "BRON", "BASC", "MEMTN"]
PAGE = 10000


def get(api, site, params, timeout=240):
    url = f"{api}/odata/AT_MODULE_ACCESS?db={site}&" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=timeout) as r:
        body = json.load(r)
    if isinstance(body, dict) and "error" in body:
        raise RuntimeError(f"{site}: {body['error']}")
    return body.get("value", [])


def active_since(api, site, cutoff):
    """Every (username -> most recent ENTER_DATE) at this site since the cutoff."""
    seen, skip = {}, 0
    while True:
        rows = get(api, site, {
            "$select": "USERNAME,ENTER_DATE",
            "$filter": f"ENTER_DATE gt {cutoff}",
            "$orderby": "ENTER_DATE asc",
            "$top": PAGE,
            "$skip": skip,
        })
        for r in rows:
            u = (r.get("USERNAME") or "").strip().upper()
            d = r.get("ENTER_DATE")
            if u and d and d > seen.get(u, ""):
                seen[u] = d
        if len(rows) < PAGE:
            return seen
        skip += PAGE


def last_seen_ever(api, site, username):
    """Most recent row for one user at one site, with no date window."""
    esc = username.replace("'", "''")
    rows = get(api, site, {
        "$select": "ENTER_DATE",
        "$filter": f"USERNAME eq '{esc}'",
        "$orderby": "ENTER_DATE desc",
        "$top": 1,
    })
    return rows[0]["ENTER_DATE"] if rows else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--years", type=int, default=2)
    ap.add_argument("--api", default="http://localhost:5199")
    args = ap.parse_args()

    today = datetime.date.today()
    cutoff = (today - datetime.timedelta(days=365 * args.years)).isoformat()
    print(f"  today {today} | {args.years}-year cutoff {cutoff}")

    # The population we care about: accounts already filtered to active employees.
    people = {}
    with open("analysis/ewt-manager-user-roles-clean.csv"
              if os.path.exists("analysis/ewt-manager-user-roles-clean.csv")
              else "analysis/ewt-manager-user-site-roles.csv", encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            u = r["username"].strip().upper()
            p = people.setdefault(u, {"badge": r["employee_badge"], "sites": set(),
                                      "manager": r["manager_name"]})
            p["sites"].add(r["site"])
    print(f"  population: {len(people)} usernames")

    # Pass 1 - who is active, and when last.
    recent = collections.defaultdict(dict)
    with ThreadPoolExecutor(max_workers=7) as ex:
        for site, res in zip(SITES, ex.map(lambda s: active_since(args.api, s, cutoff), SITES)):
            recent[site] = res
            print(f"    {site:6s} {len(res):4d} distinct users active since cutoff")

    last = {}
    for u in people:
        hits = [recent[s][u] for s in SITES if u in recent[s]]
        if hits:
            last[u] = (max(hits), True)

    dormant = [u for u in people if u not in last]
    print(f"  active in window: {len(last)}   no activity in window: {len(dormant)}")

    # Pass 2 - date the dormant ones rather than leaving them unexplained.
    print("  dating dormant accounts ...")

    def probe(u):
        hits = []
        for s in sorted(people[u]["sites"]):
            try:
                d = last_seen_ever(args.api, s, u)
                if d:
                    hits.append(d)
            except Exception:
                pass
        return u, (max(hits) if hits else None)

    with ThreadPoolExecutor(max_workers=8) as ex:
        for u, d in ex.map(probe, dormant):
            last[u] = (d, False)

    rows = []
    for u, p in sorted(people.items()):
        d, active = last.get(u, (None, False))
        days = ""
        if d:
            try:
                days = (today - datetime.date.fromisoformat(d[:10])).days
            except ValueError:
                days = ""
        rows.append({
            "username": u,
            "employee_badge": p["badge"],
            "manager": p["manager"],
            "sites": "|".join(sorted(p["sites"])),
            "last_activity": d or "",
            "days_since": days,
            f"active_within_{args.years}y": "Y" if active else "N",
        })

    os.makedirs("analysis", exist_ok=True)
    out = "analysis/ewt-user-activity.csv"
    with open(out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    never = [r for r in rows if not r["last_activity"]]
    print(f"\n  wrote {out}")
    print(f"    active within {args.years}y : {sum(1 for r in rows if r[f'active_within_{args.years}y'] == 'Y')}")
    print(f"    dormant               : {sum(1 for r in rows if r[f'active_within_{args.years}y'] == 'N')}")
    print(f"      of which never seen : {len(never)}")


if __name__ == "__main__":
    main()
