"""
One row per person: who they are, the Entra groups they will get, the Oracle roles they
hold today, and what actually changes.

The last three columns are the proof. roles_gained and roles_lost should be empty for
everyone except the three application administrators, who gain the handful of roles
needed to round them up to full rights.

Usage: python scripts/build-before-after.py
Output: analysis/ewt-before-after.csv
"""

import collections
import csv
import os

ACTIVITY = "analysis/ewt-user-activity.csv"
ROLES = "analysis/ewt-user-roles-clean.csv"
GROUPS = "analysis/entra-nested-groups.csv"
ASSIGN = "analysis/entra-nested-assignments.csv"
OUT = "analysis/ewt-before-after.csv"
EXCLUDE = {"ACCUTRACK", "KABADORF"}


def main():
    active = {r["username"].strip().upper()
              for r in csv.DictReader(open(ACTIVITY, encoding="utf-8"))
              if r["active_within_2y"] == "Y"}

    # what they hold today
    today = collections.defaultdict(set)
    for r in csv.DictReader(open(ROLES, encoding="utf-8")):
        u = r["username"].strip().upper()
        if u in active and u not in EXCLUDE:
            today[u].add(r["role"])

    group_roles, group_name = {}, {}
    for g in csv.DictReader(open(GROUPS, encoding="utf-8")):
        group_roles[g["group_id"]] = set(g["roles"].split())
        group_name[g["group_id"]] = g["entra_group_name"]

    rows = []
    for a in csv.DictReader(open(ASSIGN, encoding="utf-8")):
        u = a["username"].strip().upper()
        gids = [g for g in a["direct_groups"].split() if g != "GATE"]
        after = set().union(*[group_roles[g] for g in gids]) if gids else set()
        before = today.get(u, set())
        rows.append({
            "username": u,
            "first_name": a["first_name"],
            "last_name": a["last_name"],
            "email": a["email"],
            "employee_badge": a["employee_badge"],

            "new_group_count": len(a["direct_groups"].split()),
            "new_groups": a["direct_groups"],
            "new_group_names": a["direct_group_names"],

            "previous_role_count": len(before),
            "previous_roles": " ".join(sorted(before)),

            "roles_after_count": len(after),
            "roles_gained": " ".join(sorted(after - before)),
            "roles_lost": " ".join(sorted(before - after)),
            "unchanged": "Y" if after == before else "N",
        })

    rows.sort(key=lambda r: (r["unchanged"] == "Y", r["last_name"], r["username"]))
    os.makedirs("analysis", exist_ok=True)
    with open(OUT, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    changed = [r for r in rows if r["unchanged"] == "N"]
    print(f"  people                 : {len(rows)}")
    print(f"  unchanged              : {sum(1 for r in rows if r['unchanged']=='Y')}")
    print(f"  changed                : {len(changed)}")
    for r in changed:
        print(f"    {r['username']:<12} +{len(r['roles_gained'].split()):>3} "
              f"-{len(r['roles_lost'].split()):>3}  ({r['new_group_names']})")
    print(f"  total roles gained     : {sum(len(r['roles_gained'].split()) for r in rows)}")
    print(f"  total roles lost       : {sum(len(r['roles_lost'].split()) for r in rows)}")
    print(f"  wrote {OUT}")


if __name__ == "__main__":
    main()
