"""
Entra group proposal, groups-only edition.

The first proposal never granted anyone new access, which meant 149 individual roles
still had to exist in Entra as straggler assignments. That is too many objects to
manage. This version trades a small, measured amount of over-grant for a catalogue
small enough to review.

Method: start with one cluster per distinct access profile, then repeatedly merge the
pair whose combined role set adds the least new access. Group content is the UNION of
its members' roles, so nobody LOSES access - the cost is that some people gain a
little. That cost is reported per person and in total.

Usage: python scripts/propose-entra-groups-v2.py [--groups 20]
"""

import argparse
import collections
import csv
import itertools
import os
import re

ACTIVITY = "analysis/ewt-user-activity.csv"
ROLES = "analysis/ewt-user-roles-clean.csv"
SECMOD = "analysis/_security_modules.csv"
EXCLUDE = {"ACCUTRACK", "KABADORF"}
ADMINS = {"JDELK", "JCROY", "SEGEARY"}
RX = re.compile(r"^(AT[0-9A-Z]+?)_(ADMIN|OPER|GUEST|READ|USER)$")


def describe(roles, mod2):
    subs, areas, levels = collections.Counter(), collections.Counter(), collections.Counter()
    for role in roles:
        m = RX.match(role)
        if not m:
            continue
        levels[m.group(2)] += 1
        t = mod2.get(m.group(1))
        if t:
            subs[t[0]] += 1
            areas[t[1]] += 1
    if not subs:
        return "Unclassified"
    top = subs.most_common(2)
    name = top[0][0].title()
    if len(top) > 1 and top[1][1] >= top[0][1] * 0.6:
        name += " + " + top[1][0].title()
    elif areas:
        a = areas.most_common(1)[0][0]
        if a.upper() not in ("ADMINISTRATION", "GENERAL"):
            name += " / " + a.title()
    lead = levels.most_common(1)[0][0].title() if levels else ""
    return f"{name} ({lead})"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--groups", type=int, default=20, help="functional groups, excl. BASE and ADMIN")
    args = ap.parse_args()

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

    # real names, so the assignment list is reviewable by a human
    names = {}
    nb = lambda b: (str(b or "").strip().lstrip("0") or "")
    for path, f, l, b in (("analysis/ewt-badges-with-managers.csv", "first_name", "last_name", "badge"),
                          ("analysis/sf_active_employees.csv", "first_name", "last_name", "badge")):
        if not os.path.exists(path):
            continue
        for r in csv.DictReader(open(path, encoding="utf-8-sig", errors="replace")):
            k = nb(r.get(b))
            if k and k not in names:
                names[k] = ((r.get(f) or "").strip(), (r.get(l) or "").strip())

    emails = {}
    if os.path.exists("analysis/ewt-people-contact.csv"):
        for r in csv.DictReader(open("analysis/ewt-people-contact.csv", encoding="utf-8")):
            if r.get("email"):
                emails[r["username"].strip().upper()] = r["email"]

    mod2 = {}
    for r in csv.DictReader(open(SECMOD, encoding="utf-8")):
        mod2.setdefault(r["MODULE_NAME"].upper(), (r["SUBSYSTEM_NAME"], r["AREA_NAME"]))

    base = {r for r in everything if all(r in s for s in people.values())}

    # one cluster per distinct profile, then merge cheapest pair repeatedly
    prof = collections.defaultdict(list)
    for u, s in people.items():
        prof[frozenset(s)].append(u)
    clusters = [{"roles": set(s), "members": list(us)} for s, us in prof.items()]

    def cost_of(c):
        return sum(len(c["roles"] - people[u]) for u in c["members"])

    while len(clusters) > args.groups:
        best, bestcost = None, None
        for i, j in itertools.combinations(range(len(clusters)), 2):
            a, b = clusters[i], clusters[j]
            un = a["roles"] | b["roles"]
            delta = (sum(len(un - people[u]) for u in a["members"] + b["members"])
                     - cost_of(a) - cost_of(b))
            if bestcost is None or delta < bestcost:
                bestcost, best = delta, (i, j)
        i, j = best
        merged = {"roles": clusters[i]["roles"] | clusters[j]["roles"],
                  "members": clusters[i]["members"] + clusters[j]["members"]}
        clusters = [c for k, c in enumerate(clusters) if k not in (i, j)] + [merged]

    clusters.sort(key=lambda c: -len(c["members"]))
    os.makedirs("analysis", exist_ok=True)

    with open("analysis/entra-role-groups-v2.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["group_id", "proposed_name", "role_count", "members", "roles"])
        w.writerow(["ADMIN", "EWT Administrator (full rights)", len(everything),
                    len(ADMINS & set(held)), " ".join(sorted(everything))])
        for i, c in enumerate(clusters, 1):
            w.writerow([f"G{i:02d}", describe(c["roles"] - base, mod2), len(c["roles"]),
                        len(c["members"]), " ".join(sorted(c["roles"]))])

    rows, total_over = [], 0
    for c_i, c in enumerate(clusters, 1):
        for u in c["members"]:
            extra = c["roles"] - people[u]
            total_over += len(extra)
            fn, ln = names.get(badge.get(u, ""), ("", ""))
            rows.append({"username": u, "first_name": fn, "last_name": ln,
                         "email": emails.get(u, ""),
                         "employee_badge": badge.get(u, ""),
                         "entra_group": f"G{c_i:02d}",
                         "roles_held_today": len(people[u]),
                         "roles_after": len(c["roles"]),
                         "new_roles_gained": len(extra),
                         "gained_roles": " ".join(sorted(extra))})
    for u in sorted(ADMINS & set(held)):
        fn, ln = names.get(badge.get(u, ""), ("", ""))
        rows.append({"username": u, "first_name": fn, "last_name": ln,
                     "email": emails.get(u, ""),
                     "employee_badge": badge.get(u, ""), "entra_group": "ADMIN",
                     "roles_held_today": len(held[u]), "roles_after": len(everything),
                     "new_roles_gained": len(everything - held[u]),
                     "gained_roles": " ".join(sorted(everything - held[u]))})
    rows.sort(key=lambda r: (-r["new_roles_gained"], r["username"]))
    with open("analysis/entra-user-assignments-v2.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    cur = sum(len(s) for s in people.values())
    print(f"  people                 : {len(held)} ({len(people)} non-admin, {len(ADMINS & set(held))} admin)")
    print(f"  roles today            : {len(everything)}")
    print(f"  ENTRA OBJECTS          : {len(clusters) + 1} groups  (no individual roles)")
    print(f"  base roles common to all: {len(base)}")
    print(f"  over-grant             : {total_over} role-grants "
          f"({total_over / cur * 100:.1f}% of the {cur} that exist today)")
    print(f"    people gaining nothing : {sum(1 for r in rows if r['new_roles_gained'] == 0)}/{len(rows)}")
    print(f"    worst single person    : +{max(r['new_roles_gained'] for r in rows)} roles")
    print()
    print(f"    {'id':5s}{'roles':>7}{'people':>8}  name")
    print(f"    {'ADMIN':5s}{len(everything):>7}{len(ADMINS & set(held)):>8}  EWT Administrator (full rights)")
    for i, c in enumerate(clusters, 1):
        print(f"    G{i:02d}  {len(c['roles']):>7}{len(c['members']):>8}  {describe(c['roles'] - base, mod2)}")
    print("\n  wrote analysis/entra-role-groups-v2.csv")
    print("  wrote analysis/entra-user-assignments-v2.csv")


if __name__ == "__main__":
    main()
