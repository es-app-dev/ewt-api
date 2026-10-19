"""
Proposes Entra role groups from observed EWT grants.

Method
------
1. Population = people active in the last two years (94), matched to an active employee.
2. Roles are unioned per person across sites: Entra grants to an identity, not a database.
3. The base group is every role held by all 94 people.
4. Beyond the base, people fall into a small number of distinct access profiles. Profiles
   held by two or more people become named groups; profiles held by one person do not
   (a group of one is a per-user assignment with extra steps).
5. Each person is covered greedily, and a group is only ever assigned when the person
   already holds every role in it - so the proposal never grants anyone new access.
   Whatever a group cannot cover is reported as straggler roles.

Names come from AT_SECURITY_MODULES (subsystem / area) and the legacy form titles, so a
group reads as something a person can approve rather than a cluster id.

Usage: python scripts/propose-entra-groups.py
"""

import collections
import csv
import os
import re

ACTIVITY = "analysis/ewt-user-activity.csv"
ROLES = "analysis/ewt-user-roles-clean.csv"
SECMOD = "analysis/_security_modules.csv"
RX = re.compile(r"^(AT[0-9A-Z]+?)_(ADMIN|OPER|GUEST|READ|USER)$")

# ACCUTRACK is the Oracle schema owner. KABADORF is a product-owner account provisioned
# for the migration itself, so it describes the project rather than how EWT is used -
# it also held 9 roles no one else has, which inflated the catalogue.
EXCLUDE_USERS = {"ACCUTRACK", "KABADORF"}

# Application administrators / developers, confirmed by the business. These are meant to
# hold everything, so they get one full-rights group rather than an assembled role set.
ADMIN_USERS = {"JDELK", "JCROY", "SEGEARY"}


def load():
    active = {r["username"].strip().upper()
              for r in csv.DictReader(open(ACTIVITY, encoding="utf-8"))
              if r["active_within_2y"] == "Y"}
    rows = [r for r in csv.DictReader(open(ROLES, encoding="utf-8"))
            if r["username"].strip().upper() in active
            and r["username"].strip().upper() not in EXCLUDE_USERS]

    roles_by_user = collections.defaultdict(set)
    users_by_role = collections.defaultdict(set)
    badge, title = {}, {}
    for r in rows:
        u = r["username"].strip().upper()
        roles_by_user[u].add(r["role"])
        users_by_role[r["role"]].add(u)
        badge[u] = r["employee_badge"]
        if r["module_code"]:
            title.setdefault(r["module_code"], r["module_title"])

    mod2 = {}
    if os.path.exists(SECMOD):
        for r in csv.DictReader(open(SECMOD, encoding="utf-8")):
            mod2.setdefault(r["MODULE_NAME"].upper(), (r["SUBSYSTEM_NAME"], r["AREA_NAME"]))
    return roles_by_user, users_by_role, badge, title, mod2


def describe(roles, mod2):
    """Name a group after the work it unlocks, not after a cluster number."""
    subs, areas, levels = collections.Counter(), collections.Counter(), collections.Counter()
    for role in roles:
        m = RX.match(role)
        if not m:
            continue
        levels[m.group(2)] += 1
        tag = mod2.get(m.group(1))
        if tag:
            subs[tag[0]] += 1
            areas[tag[1]] += 1
    if not subs:
        return "Unclassified", ", ".join(sorted(levels)) or "-"
    top = subs.most_common(2)
    name = top[0][0].title()
    if len(top) > 1 and top[1][1] >= top[0][1] * 0.6:
        name += " + " + top[1][0].title()
    elif areas:
        a = areas.most_common(1)[0][0]
        if a.upper() not in ("ADMINISTRATION", "GENERAL"):
            name += " / " + a.title()
    lv = "+".join(l.title() for l, _ in levels.most_common())
    return name, lv


def main():
    roles_by_user, users_by_role, badge, title, mod2 = load()
    n = len(roles_by_user)
    base = {r for r, us in users_by_role.items() if len(us) == n}

    # Administrators take the full catalogue as a single group; they are removed from
    # profile clustering so their breadth does not distort everyone else's groups.
    everything = set().union(*roles_by_user.values())
    admins = {u for u in roles_by_user if u in ADMIN_USERS}

    profiles = collections.defaultdict(list)
    for u, s in roles_by_user.items():
        if u in admins:
            continue
        profiles[frozenset(s - base)].append(u)
    shared = sorted((p for p, us in profiles.items() if len(us) > 1),
                    key=lambda p: -len(profiles[p]))

    # Greedy, subset-constrained: never assign a group containing a role the person lacks.
    groups, assign, stragglers = {}, {}, {}
    for i, p in enumerate(shared, 1):
        nm, lv = describe(p, mod2)
        groups[f"G{i:02d}"] = {"name": nm, "levels": lv, "roles": p,
                               "members": set(profiles[p])}

    for u, held in roles_by_user.items():
        if u in admins:
            assign[u] = ["ADMIN"]
            stragglers[u] = []
            continue
        need = set(held) - base
        picked, covered = [], set()
        while True:
            fits = [(k, g) for k, g in groups.items()
                    if g["roles"] <= held and (g["roles"] - covered)]
            if not fits:
                break
            k, g = max(fits, key=lambda kv: len(kv[1]["roles"] - covered))
            picked.append(k)
            covered |= g["roles"]
        assign[u] = picked
        stragglers[u] = sorted(need - covered)

    os.makedirs("analysis", exist_ok=True)

    with open("analysis/entra-role-groups.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["group_id", "proposed_name", "privilege_levels",
                    "role_count", "people_holding", "assigned_to", "roles"])
        w.writerow(["BASE", "EWT Base Access", "All", len(base), n, n,
                    " ".join(sorted(base))])
        w.writerow(["ADMIN", "EWT Administrator (full rights)", "All",
                    len(everything), len(admins), len(admins),
                    " ".join(sorted(everything))])
        for k, g in groups.items():
            got = sum(1 for u in assign if k in assign[u])
            w.writerow([k, g["name"], g["levels"], len(g["roles"]),
                        len(g["members"]), got, " ".join(sorted(g["roles"]))])

    with open("analysis/entra-user-assignments.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["username", "employee_badge", "group_count", "groups",
                    "straggler_count", "straggler_roles"])
        for u in sorted(roles_by_user):
            w.writerow([u, badge.get(u, ""), len(assign[u]) + 1,
                        (" ".join(assign[u]) if u in admins
                         else "BASE " + " ".join(assign[u])),
                        len(stragglers[u]), " ".join(stragglers[u])])

    covered_fully = sum(1 for u in stragglers if not stragglers[u])
    print(f"  population                 : {n} active people")
    print(f"  distinct roles in use      : {len(users_by_role)}")
    print(f"  BASE group                 : {len(base)} roles, everyone")
    print(f"  named groups proposed      : {len(groups)} (+ base = {len(groups)+1})")
    print(f"  people fully covered       : {covered_fully}/{n}")
    print(f"  straggler grants remaining : {sum(len(v) for v in stragglers.values())}"
          f" across {sum(1 for v in stragglers.values() if v)} people")
    print()
    print("  proposed groups:")
    print(f"    {'id':5s} {'roles':>5} {'people':>6}  name")
    print(f"    {'BASE':5s} {len(base):>5} {n:>6}  EWT Base Access")
    for k, g in groups.items():
        print(f"    {k:5s} {len(g['roles']):>5} {len(g['members']):>6}  "
              f"{g['name']} ({g['levels']})")
    print("\n  wrote analysis/entra-role-groups.csv")
    print("  wrote analysis/entra-user-assignments.csv")


if __name__ == "__main__":
    main()
