"""
Splits the flat (site, username, email, role) fact table into a clean set and an
excluded set, using the active-employee reconciliation as the filter.

Nothing is destroyed: every excluded row is written out with the reason, so a
decision can be revisited without re-running the extraction.

Inputs  : analysis/ewt-user-roles.csv
          analysis/ewt-account-reconciliation.csv
Outputs : analysis/ewt-user-roles-clean.csv
          analysis/ewt-user-roles-excluded.csv

Usage:  python scripts/filter-known-bogus.py [--keep-oracle-builtins]
"""

import argparse
import collections
import csv
import os

FACTS = "analysis/ewt-user-roles.csv"
RECON = "analysis/ewt-account-reconciliation.csv"
CLEAN = "analysis/ewt-user-roles-clean.csv"
EXCLUDED = "analysis/ewt-user-roles-excluded.csv"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keep-oracle-builtins", action="store_true",
                    help="keep CONNECT/DBA/RESOURCE-style grants in the clean set")
    args = ap.parse_args()

    with open(RECON, encoding="utf-8") as fh:
        recon = {r["username"]: r for r in csv.DictReader(fh)}

    with open(FACTS, encoding="utf-8") as fh:
        facts = list(csv.DictReader(fh))

    clean, excluded = [], []
    for row in facts:
        u = row["username"]
        m = recon.get(u)
        reasons = []

        if m is None:
            reasons.append("account_not_in_reconciliation")
        elif m["matched_active_employee"] != "True":
            # No active employee behind this login. Could also be a service or
            # shared account - hence excluded rather than deleted.
            reasons.append("no_active_employee")

        if not args.keep_oracle_builtins and row["role_class"] == "oracle_builtin":
            reasons.append("oracle_builtin_role")

        enriched = dict(row)
        enriched["matched_on"] = m["matched_on"] if m else ""
        enriched["employee_badge"] = m["employee_badge"] if m else ""
        enriched["site_count"] = m["site_count"] if m else ""

        if reasons:
            enriched["excluded_reason"] = ";".join(reasons)
            excluded.append(enriched)
        else:
            clean.append(enriched)

    os.makedirs("analysis", exist_ok=True)
    if clean:
        with open(CLEAN, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=list(clean[0].keys()))
            w.writeheader()
            w.writerows(clean)
    if excluded:
        with open(EXCLUDED, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=list(excluded[0].keys()))
            w.writeheader()
            w.writerows(excluded)

    print(f"  input rows      : {len(facts)}")
    print(f"  clean rows      : {len(clean)}   -> {CLEAN}")
    print(f"  excluded rows   : {len(excluded)} -> {EXCLUDED}")
    print()
    print("  excluded by reason:")
    for reason, n in collections.Counter(r["excluded_reason"] for r in excluded).most_common():
        print(f"    {reason:45s} {n:7d}")
    print()
    cu = {(r["site"], r["username"]) for r in clean}
    print(f"  clean: {len({u for _, u in cu})} distinct users, "
          f"{len(cu)} site+user pairs, "
          f"{len({r['role'] for r in clean})} distinct roles")
    print("  clean role mix:", dict(collections.Counter(r["role_class"] for r in clean)))


if __name__ == "__main__":
    main()
