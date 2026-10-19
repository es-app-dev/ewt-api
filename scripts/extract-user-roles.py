"""
Extracts a flat (site, username, email, role) fact table from every EWT database.

Reads through the running EWT API rather than connecting to Oracle directly, so it
uses the same connection handling and the same seven configured instances.

Nothing is filtered out. Roles are *classified* instead - a 30-year-old schema will
contain oddities, and silently dropping them loses the interesting ones. Pivot or
filter downstream.

Usage:
    python scripts/extract-user-roles.py [--api http://localhost:5199] [--out analysis]
"""

import argparse
import collections
import csv
import json
import os
import re
import sys
import urllib.request

SITES = ["CORP", "BCTN", "CLUT", "EWTN", "BRON", "BASC", "MEMTN"]
PAGE = 10000  # matches MaxTop in DynamicODataController

# AT1710_ADMIN -> module AT1710, level ADMIN
MODULE_ROLE = re.compile(r"^(AT[0-9A-Z]+?)_(ADMIN|OPER|GUEST|READ|USER)$", re.I)


def fetch(api, site, entity, select, timeout=120):
    url = f"{api}/odata/{entity}?db={site}&$select={select}&$top={PAGE}"
    with urllib.request.urlopen(url, timeout=timeout) as r:
        body = json.load(r)
    rows = body.get("value", body if isinstance(body, list) else [])
    if len(rows) >= PAGE:
        print(f"  !! {site}/{entity} hit the {PAGE}-row cap - results may be truncated",
              file=sys.stderr)
    return rows


def load_module_titles(legacy_dir):
    """Map module code -> human title from the legacy Oracle Forms XML."""
    titles = {}
    if not os.path.isdir(legacy_dir):
        print(f"  (legacy XML not found at {legacy_dir}; titles will be blank)", file=sys.stderr)
        return titles
    for fn in os.listdir(legacy_dir):
        if not fn.lower().endswith(".xml"):
            continue
        path = os.path.join(legacy_dir, fn)
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                head = fh.read(200_000)  # module + first window are near the top
        except OSError:
            continue
        m = re.search(r'FormModule\s+Name="([^"]+)"', head)
        if not m:
            continue
        code = m.group(1).strip().upper()
        # First Title that is not a generic dialog caption.
        for t in re.findall(r'Title="([^"]{3,80})"', head):
            if t.strip().lower() not in ("error", "caution", "info", "warning", "note"):
                titles[code] = t.strip()
                break
        titles.setdefault(code, "")
    return titles


def classify(role):
    r = (role or "").upper()
    if r.startswith("BA_"):
        return "business_area", "", ""
    m = MODULE_ROLE.match(r)
    if m:
        return "module", m.group(1).upper(), m.group(2).upper()
    if r.startswith("AT"):
        return "application_other", "", ""
    return "oracle_builtin", "", ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--api", default="http://localhost:5199")
    ap.add_argument("--out", default="analysis")
    ap.add_argument("--legacy", default=r"C:\essource\ewt-ui\legacy_XML")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    titles = load_module_titles(args.legacy)
    print(f"module titles loaded: {len(titles)}")

    rows = []
    recon = []
    for site in SITES:
        print(f"[{site}] ...", end=" ", flush=True)
        users = fetch(args.api, site, "AT_ACCUTRACK_USERS", "USERNAME,EMAIL_ADDR,ACTIVE_FLAG")
        privs = fetch(args.api, site, "AT_ROLE_PRIVS",
                      "GRANTEE,GRANTED_ROLE,ADMIN_OPTION,DEFAULT_ROLE")

        by_user = {}
        for u in users:
            name = (u.get("USERNAME") or "").strip().upper()
            if name:
                by_user[name] = {
                    "email": (u.get("EMAIL_ADDR") or "").strip(),
                    "active": u.get("ACTIVE_FLAG"),
                }

        # Grant graph. A GRANTEE may be a user OR a role, so roles nest.
        edges = collections.defaultdict(list)
        for p in privs:
            g = (p.get("GRANTEE") or "").strip().upper()
            r = (p.get("GRANTED_ROLE") or "").strip().upper()
            if g and r:
                edges[g].append((r, p.get("ADMIN_OPTION"), p.get("DEFAULT_ROLE")))

        grantees = set(edges)
        # Reconciliation: the app user table and Oracle's grants rarely agree perfectly.
        recon.append({
            "site": site,
            "users_in_app_table": len(by_user),
            "oracle_grantees": len(grantees),
            "app_users_without_grants": len(set(by_user) - grantees),
            "grantees_not_in_app_table": len(grantees - set(by_user)),
            "grant_edges": len(privs),
        })

        # Resolve each app user's transitive role closure.
        for uname, info in sorted(by_user.items()):
            seen = {}
            stack = [(r, adm, dflt, "", 0) for r, adm, dflt in edges.get(uname, [])]
            while stack:
                role, adm, dflt, via, depth = stack.pop()
                if role in seen:
                    continue
                seen[role] = (adm, dflt, via, depth)
                for nr, nadm, ndflt in edges.get(role, []):
                    if nr not in seen:
                        stack.append((nr, nadm, ndflt, role, depth + 1))

            for role, (adm, dflt, via, depth) in sorted(seen.items()):
                cls, module, level = classify(role)
                rows.append({
                    "site": site,
                    "username": uname,
                    "email": info["email"],
                    "active_flag": info["active"],
                    "role": role,
                    "role_class": cls,
                    "module_code": module,
                    "module_level": level,
                    "module_title": titles.get(module, ""),
                    "grant_type": "direct" if depth == 0 else "inherited",
                    "granted_via": via,
                    "admin_option": adm,
                    "default_role": dflt,
                })
        print(f"{len(by_user)} users, {len(privs)} grant edges")

    facts = os.path.join(args.out, "ewt-user-roles.csv")
    with open(facts, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    rec = os.path.join(args.out, "ewt-reconciliation.csv")
    with open(rec, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(recon[0].keys()))
        w.writeheader()
        w.writerows(recon)

    print(f"\nwrote {len(rows)} rows -> {facts}")
    print(f"wrote {len(recon)} rows -> {rec}")


if __name__ == "__main__":
    main()
