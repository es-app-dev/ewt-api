"""
Builds the nested Entra group model and exports it.

Every role held by exactly the same set of people forms one indivisible "atom". An
atom becomes one Entra group. Where every member of atom B also holds atom A, B is
nested inside A, so B's members inherit A automatically. Nesting is only asserted
where it is already true of today's grants, which is why nobody gains or loses access.

Edges are transitively reduced: only immediate parents are kept, so the hierarchy is
a readable Hasse diagram rather than 378 redundant links.

Outputs
  analysis/entra-nested-groups.csv       one row per group
  analysis/entra-nested-edges.csv        child -> immediate parent
  analysis/entra-nested-assignments.csv  person -> the groups they are added to
  analysis/entra-nested-model.json       the same, for the API and UI work

Usage: python scripts/build-nested-groups.py
"""

import argparse
import collections
import csv
import json
import os
import re

ACTIVITY = "analysis/ewt-user-activity.csv"
ROLES = "analysis/ewt-user-roles-clean.csv"
SECMOD = "analysis/_security_modules.csv"
CONTACT = "analysis/ewt-people-contact.csv"
EXCLUDE = {"ACCUTRACK", "KABADORF"}
ADMINS = {"JDELK", "JCROY", "SEGEARY"}
RX = re.compile(r"^(AT[0-9A-Z]+?)_(ADMIN|OPER|GUEST|READ|USER)$")


def name_for(roles, mod2, seen):
    subs, areas, levels = collections.Counter(), collections.Counter(), collections.Counter()
    for r in roles:
        m = RX.match(r)
        if not m:
            continue
        levels[m.group(2)] += 1
        t = mod2.get(m.group(1))
        if t:
            subs[t[0]] += 1
            areas[t[1]] += 1
    if areas and areas.most_common(1)[0][0].upper() not in ("ADMINISTRATION", "GENERAL"):
        core = areas.most_common(1)[0][0].title()
    elif subs:
        core = subs.most_common(1)[0][0].title()
    else:
        core = "General"
    lvl = levels.most_common(1)[0][0].title() if levels else "Access"
    core = core.replace("/", " ").replace("-", " ")
    core = "".join(w.capitalize() for w in core.split())
    base = f"EWT-{core}-{lvl}"
    n = seen[base] = seen.get(base, 0) + 1
    return base if n == 1 else f"{base}-{n}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--flat", action="store_true",
                    help="no nesting: assign every atom a person holds directly. "
                         "Entra app-role assignment and app-group assignment both ignore "
                         "nesting, so this is the shape that matches the EWIS pattern.")
    args = ap.parse_args()
    FLAT = args.flat

    active = {r["username"].strip().upper()
              for r in csv.DictReader(open(ACTIVITY, encoding="utf-8"))
              if r["active_within_2y"] == "Y"}
    held, badge = collections.defaultdict(set), {}
    for r in csv.DictReader(open(ROLES, encoding="utf-8")):
        u = r["username"].strip().upper()
        if u in active and u not in EXCLUDE:
            held[u].add(r["role"])
            badge[u] = r["employee_badge"]
    everything = set().union(*held.values())
    people = {u: s for u, s in held.items() if u not in ADMINS}

    contact = {}
    if os.path.exists(CONTACT):
        for r in csv.DictReader(open(CONTACT, encoding="utf-8")):
            contact[r["username"].strip().upper()] = r

    mod2 = {}
    for r in csv.DictReader(open(SECMOD, encoding="utf-8")):
        mod2.setdefault(r["MODULE_NAME"].upper(), (r["SUBSYSTEM_NAME"], r["AREA_NAME"]))

    # --- atoms -------------------------------------------------------------
    by_userset = {}
    ubr = collections.defaultdict(set)
    for u, s in people.items():
        for r in s:
            ubr[r].add(u)
    for role, us in ubr.items():
        by_userset.setdefault(frozenset(us), set()).add(role)

    keys = sorted(by_userset, key=lambda k: (-len(k), sorted(by_userset[k])[0]))
    gid = {k: f"N{i:02d}" for i, k in enumerate(keys, 1)}
    seen = {}
    gname = {}
    for k in keys:
        gname[k] = ("EWT-BaseAccess" if len(k) == len(people)
                    else name_for(by_userset[k], mod2, seen))

    # --- nesting, transitively reduced -------------------------------------
    parents = {k: [a for a in keys if k < a] for k in keys}          # all ancestors
    immediate = {}
    for k in keys:
        ps = parents[k]
        # nearest ancestors only: drop any 'a' that has another ancestor sitting below it
        immediate[k] = [a for a in ps if not any(c < a for c in ps)]

    # --- assignments: the minimal atoms a person holds ---------------------
    assign = {}
    for u in people:
        mine = [k for k in keys if u in k]
        # flat: hold it, get it assigned. nested: only the minimal atoms, the rest inherit.
        assign[u] = mine if FLAT else [k for k in mine if not any(c < k for c in mine)]

    if FLAT:
        immediate = {k: [] for k in keys}

    # --- verify the model reproduces today's access exactly ----------------
    over = under = 0
    for u, direct in assign.items():
        reach = set()
        stack = list(direct)
        while stack:
            k = stack.pop()
            if k in reach:
                continue
            reach.add(k)
            if not FLAT:
                stack.extend(parents[k])
        granted = set().union(*[by_userset[k] for k in reach]) if reach else set()
        over += len(granted - people[u])
        under += len(people[u] - granted)
    assert over == 0 and under == 0, f"model is not exact: +{over} / -{under}"

    os.makedirs("analysis", exist_ok=True)

    with open("analysis/entra-nested-groups.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["group_id", "entra_group_name", "roles_in_group", "people_reached",
                    "directly_assigned", "immediate_parents", "roles"])
        # Sign-in gate. Assigned to the enterprise application, FLAT, every person a
        # direct member - because app assignment does not honour nesting. It grants no
        # roles; it only lets people authenticate.
        w.writerow(["GATE", "EWT-Users", 0, len(held), len(held), "", ""])
        w.writerow(["ADMIN", "EWT-Administrator", len(everything),
                    len(ADMINS & set(held)), len(ADMINS & set(held)), "",
                    " ".join(sorted(everything))])
        for k in keys:
            direct_n = sum(1 for u in assign if k in assign[u])
            w.writerow([gid[k], gname[k], len(by_userset[k]), len(k), direct_n,
                        " ".join(gid[p] for p in immediate[k]),
                        " ".join(sorted(by_userset[k]))])

    with open("analysis/entra-nested-edges.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["child_group_id", "child_name", "parent_group_id", "parent_name"])
        for k in keys:
            for p in immediate[k]:
                w.writerow([gid[k], gname[k], gid[p], gname[p]])

    with open("analysis/entra-nested-assignments.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["username", "first_name", "last_name", "email", "employee_badge",
                    "direct_group_count", "direct_groups", "direct_group_names",
                    "effective_role_count"])
        for u in sorted(people):
            c = contact.get(u, {})
            w.writerow([u, c.get("first_name", ""), c.get("last_name", ""),
                        c.get("email", ""), badge.get(u, ""),
                        len(assign[u]) + 1,
                        "GATE " + " ".join(gid[k] for k in assign[u]),
                        "EWT-Users; " + "; ".join(gname[k] for k in assign[u]),
                        len(people[u])])
        for u in sorted(ADMINS & set(held)):
            c = contact.get(u, {})
            w.writerow([u, c.get("first_name", ""), c.get("last_name", ""),
                        c.get("email", ""), badge.get(u, ""),
                        2, "GATE ADMIN", "EWT-Users; EWT-Administrator", len(held[u])])

    model = {
        "generated": __import__("datetime").date.today().isoformat(),
        "people": len(held), "groups": len(keys) + 1, "roles": len(everything),
        "assignments": sum(len(v) for v in assign.values()) + len(ADMINS & set(held)),
        "groups_detail": [
            {"id": "ADMIN", "name": "EWT-Administrator", "roles": sorted(everything),
             "parents": [], "reaches": len(ADMINS & set(held))}
        ] + [
            {"id": gid[k], "name": gname[k], "roles": sorted(by_userset[k]),
             "parents": [gid[p] for p in immediate[k]], "reaches": len(k)}
            for k in keys
        ],
        "assignments_detail": {u: [gid[k] for k in assign[u]] for u in sorted(people)}
        | {u: ["ADMIN"] for u in sorted(ADMINS & set(held))},
    }
    json.dump(model, open("analysis/entra-nested-model.json", "w", encoding="utf-8"), indent=1)

    print(f"  mode          : {'FLAT (no nesting)' if FLAT else 'NESTED'}")
    print(f"  groups        : {len(keys)} + ADMIN + GATE = {len(keys)+2}")
    print(f"  edges         : {sum(len(v) for v in immediate.values())} immediate "
          f"(from {sum(len(v) for v in parents.values())} total containments)")
    print(f"  assignments   : {sum(len(v) for v in assign.values()) + len(ADMINS & set(held))}")
    print(f"  verification  : gained {over}, lost {under}  -> exact")
    print("  wrote entra-nested-groups.csv / -edges.csv / -assignments.csv / -model.json")


if __name__ == "__main__":
    main()
