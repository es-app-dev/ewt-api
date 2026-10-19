"""
Runs the whole EWT access-analysis chain end to end.

Two steps were originally ad hoc (the HR reconciliation and the manager join); they
are folded in here so a site rename or a new database only needs one rerun.

    python scripts/run-pipeline.py            # everything
    python scripts/run-pipeline.py --from 5   # resume at a step

Requires the EWT API running on localhost:5199.
"""

import argparse
import collections
import csv
import json
import os
import subprocess
import sys
import urllib.request

SITES = ["CORP", "BCTN", "CLUT", "EWTN", "BRON", "BASC", "MEMTN"]
API = "http://localhost:5199"
nb = lambda b: (str(b or "").strip().lstrip("0") or "")
ne = lambda e: str(e or "").strip().lower()


def run(script):
    print(f"\n=== {script} ===", flush=True)
    r = subprocess.run([sys.executable, f"scripts/{script}"], text=True)
    if r.returncode:
        raise SystemExit(f"{script} failed ({r.returncode})")


def page(entity, site, select):
    out, skip = [], 0
    while True:
        u = (f"{API}/odata/{entity}?db={site}&$select={select}"
             f"&$top=10000&$skip={skip}").replace(" ", "%20")
        v = json.load(urllib.request.urlopen(u, timeout=240)).get("value", [])
        out += v
        if len(v) < 10000:
            return out
        skip += 10000


def reconcile():
    """Match every EWT account to the active-employee roster (badge, then work email)."""
    print("\n=== reconciliation against the HR roster ===", flush=True)
    emp_badge, emp_email = {}, {}
    with open("analysis/sf_active_employees.csv", encoding="utf-8-sig", errors="replace") as fh:
        for r in csv.DictReader(fh):
            b = nb(r.get("badge"))
            if b:
                emp_badge[b] = r
            e = ne(r.get("work_email"))
            if e:
                emp_email[e] = r

    acct = {}
    for s in SITES:
        for r in page("AT_ACCUTRACK_USERS", s, "USERNAME,EMAIL_ADDR,BADGE_NBR,ACTIVE_FLAG"):
            u = (r.get("USERNAME") or "").strip().upper()
            if not u:
                continue
            a = acct.setdefault(u, {"sites": set(), "badges": set(),
                                    "emails": set(), "active": set()})
            a["sites"].add(s)
            if nb(r.get("BADGE_NBR")):
                a["badges"].add(nb(r.get("BADGE_NBR")))
            if ne(r.get("EMAIL_ADDR")):
                a["emails"].add(ne(r.get("EMAIL_ADDR")))
            a["active"].add(r.get("ACTIVE_FLAG"))

    rows = []
    for u, a in sorted(acct.items()):
        hit, how = None, ""
        for b in a["badges"]:
            if b in emp_badge:
                hit, how = emp_badge[b], "badge"
                break
        if not hit:
            for e in a["emails"]:
                if e in emp_email:
                    hit, how = emp_email[e], "work_email"
                    break
        rows.append({
            "username": u, "sites": "|".join(sorted(a["sites"])),
            "site_count": len(a["sites"]),
            "ewt_active_flag": "|".join(sorted(str(x) for x in a["active"])),
            "has_badge_in_ewt": bool(a["badges"]), "has_email_in_ewt": bool(a["emails"]),
            "matched_active_employee": bool(hit), "matched_on": how,
            "employee_badge": nb(hit.get("badge")) if hit else "",
        })
    with open("analysis/ewt-account-reconciliation.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    matched = sum(1 for r in rows if r["matched_active_employee"])
    print(f"  {len(rows)} accounts, {matched} matched to an active employee")


def manager_join():
    """Attach manager and badge to the clean fact table."""
    print("\n=== manager join ===", flush=True)
    mgr = {}
    with open("analysis/ewt-badges-with-managers.csv", encoding="utf-8-sig", errors="replace") as fh:
        for r in csv.DictReader(fh):
            mgr[nb(r["badge"])] = {
                "manager_badge": r["manager_badge"].strip(),
                "manager_name": f'{r["manager_last_name"].strip()}, {r["manager_first_name"].strip()}',
                "employee_status": r["employee_status"].strip(),
            }
    rows = list(csv.DictReader(open("analysis/ewt-user-roles-clean.csv", encoding="utf-8")))
    out, missing = [], set()
    for r in rows:
        m = mgr.get(nb(r["employee_badge"]))
        if not m:
            missing.add(r["employee_badge"])
            continue
        e = dict(r)
        e.update(m)
        out.append(e)
    cols = ["manager_badge", "manager_name"] + [c for c in out[0] if c not in
                                                ("manager_badge", "manager_name")]
    with open("analysis/ewt-manager-user-site-roles.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        w.writerows(out)
    print(f"  {len(out)} rows; badges with no manager record: {len(missing)}")


STEPS = [
    ("extract role facts", lambda: run("extract-user-roles.py")),
    ("reconcile to HR roster", reconcile),
    ("filter known bogus", lambda: run("filter-known-bogus.py")),
    ("manager join", manager_join),
    ("find dormant users", lambda: run("find-dormant-users.py")),
    ("propose Entra groups", lambda: run("propose-entra-groups.py")),
    ("build role catalogue", lambda: run("build-role-catalogue.py")),
    ("build tree documents", lambda: run("build-tree-pdfs.py")),
]

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="start", type=int, default=1)
    a = ap.parse_args()
    for i, (name, fn) in enumerate(STEPS, 1):
        if i < a.start:
            print(f"[{i}/{len(STEPS)}] skip {name}")
            continue
        print(f"\n########## [{i}/{len(STEPS)}] {name} ##########")
        fn()
    print("\nPipeline complete.")
