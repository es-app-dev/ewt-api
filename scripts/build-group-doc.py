"""
Builds the "what is in each Entra group" reference, in two forms:

  analysis/entra-group-roles.csv   one row per (group, role) - for filtering
  analysis/entra-groups.html       readable document -> PDF

Every non-admin group contains the same 66 base roles, so the document lists those
once and then shows only what each group adds. Repeating them 21 times would double
the length and hide the thing a reviewer actually needs to see: the difference.

Usage: python scripts/build-group-doc.py
"""

import collections
import csv
import datetime
import html
import os
import re

GROUPS = "analysis/entra-role-groups-v2.csv"
ASSIGN = "analysis/entra-user-assignments-v2.csv"
CATALOGUE = "analysis/ewt-role-catalogue.csv"
E = html.escape
TODAY = datetime.date.today().isoformat()
RX = re.compile(r"^(AT[0-9A-Z]+?)_(ADMIN|OPER|GUEST|READ|USER)$")


def load():
    groups = list(csv.DictReader(open(GROUPS, encoding="utf-8")))
    sets = {g["group_id"]: set(g["roles"].split()) for g in groups}
    base = set.intersection(*[v for k, v in sets.items() if k != "ADMIN"])

    cat = {}
    for r in csv.DictReader(open(CATALOGUE, encoding="utf-8")):
        cat[r["role"]] = r

    gain = collections.defaultdict(int)
    members = collections.defaultdict(list)
    for r in csv.DictReader(open(ASSIGN, encoding="utf-8")):
        gain[r["entra_group"]] += int(r["new_roles_gained"])
        members[r["entra_group"]].append(r["username"])
    return groups, sets, base, cat, gain, members


def role_cells(roles, cat):
    """Render roles as compact cells: code, privilege, and what the module does."""
    out = []
    for role in sorted(roles):
        c = cat.get(role, {})
        m = RX.match(role)
        lvl = (m.group(2) if m else "").title()
        desc = c.get("what_it_does") or c.get("example_use") or ""
        if len(desc) > 52:
            desc = desc[:51] + "…"
        out.append(f'<div class="role"><span class="rc">{E(role)}</span>'
                   f'<span class="rl">{E(lvl)}</span>'
                   f'<span class="rd">{E(desc)}</span></div>')
    return "".join(out)


def main():
    groups, sets, base, cat, gain, members = load()
    nonadmin = [g for g in groups if g["group_id"] != "ADMIN"]
    admin = next((g for g in groups if g["group_id"] == "ADMIN"), None)
    total_people = sum(int(g["members"]) for g in groups)
    total_gain = sum(gain.values())

    parts = [f"""<title>EWT Entra Groups</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;500;600;700&display=swap">
<style>
  :root{{
    --ground:#FFFFFF; --surface:#FFFFFF; --surface-2:#F6F8F9;
    --ink:#141A1E; --ink-2:#3D4950; --muted:#59646C; --faint:#87949C;
    --line:#C9D2D7; --line-2:#DFE6EA; --grid:#E6EBED;
    --accent:#00789E; --accent-soft:#E2EFF4; --corp:#C2632A;
    --sans:'IBM Plex Sans',-apple-system,'Segoe UI',sans-serif;
    --mono:'IBM Plex Mono',ui-monospace,Consolas,monospace;
  }}
  @page{{ size:A4 portrait; margin:13mm 11mm; }}
  *{{box-sizing:border-box; -webkit-print-color-adjust:exact; print-color-adjust:exact}}
  body{{background:var(--ground); color:var(--ink); font-family:var(--sans);
       font-size:10.5px; line-height:1.4}}
  .wrap{{max-width:1000px; margin:0 auto; padding-inline:16px; padding-block:0 26px}}
  .eyebrow{{font-family:var(--mono); font-size:9.5px; letter-spacing:.14em;
           text-transform:uppercase; color:var(--accent); font-weight:500}}
  h1{{font-size:26px; line-height:1.08; letter-spacing:-.022em; font-weight:700; margin:8px 0 0}}
  .standfirst{{margin:9px 0 0; max-width:66ch; color:var(--ink-2); font-size:12px}}
  .provenance{{margin-top:12px; font-family:var(--mono); font-size:9.5px; color:var(--faint)}}
  header.top{{padding-block:0 12px; border-bottom:1px solid var(--line)}}
  .stats{{display:grid; grid-template-columns:repeat(4,1fr); gap:1px;
         background:var(--line); border:1px solid var(--line); margin-block:13px}}
  .stat{{background:var(--surface); padding:9px 11px}}
  .stat b{{display:block; font-family:var(--mono); font-weight:600; font-size:18px;
          font-variant-numeric:tabular-nums}}
  .stat span{{display:block; font-size:10px; color:var(--muted); margin-top:1px}}
  .stat.is-accent b{{color:var(--accent)}}

  table.idx{{width:100%; border-collapse:collapse; margin-block:12px; font-size:10px}}
  table.idx th{{text-align:left; font-weight:600; font-size:9.5px; text-transform:uppercase;
               letter-spacing:.06em; color:var(--muted); border-bottom:1px solid var(--line);
               padding:5px 6px}}
  table.idx td{{border-bottom:1px solid var(--line-2); padding:4px 6px;
               font-variant-numeric:tabular-nums}}
  table.idx td.id{{font-family:var(--mono); font-weight:600; color:var(--accent)}}
  table.idx td.num{{text-align:right; font-family:var(--mono)}}
  tr.admin td.id{{color:var(--corp)}}

  section.grp{{break-inside:avoid; page-break-inside:avoid; margin-top:14px;
              border:1px solid var(--line-2)}}
  section.grp.big{{break-inside:auto; page-break-inside:auto}}
  .ghead{{background:var(--surface-2); border-bottom:1px solid var(--line-2);
         padding:7px 10px; display:flex; gap:9px; align-items:baseline; flex-wrap:wrap}}
  .gid{{font-family:var(--mono); font-weight:600; font-size:12px; color:var(--accent)}}
  .gname{{font-weight:600; font-size:12px}}
  .gmeta{{margin-left:auto; font-family:var(--mono); font-size:9.5px; color:var(--muted)}}
  .gmembers{{padding:5px 10px 0; font-family:var(--mono); font-size:9px; color:var(--faint);
            overflow-wrap:anywhere}}
  .roles{{column-count:2; column-gap:14px; padding:6px 10px 9px}}
  .role{{break-inside:avoid; display:grid; grid-template-columns:82px 34px 1fr;
        gap:5px; align-items:baseline; padding:1px 0}}
  .rc{{font-family:var(--mono); font-size:9px; color:var(--ink-2)}}
  .rl{{font-family:var(--mono); font-size:8px; color:var(--accent); text-transform:uppercase}}
  .rd{{font-size:9px; color:var(--muted); overflow:hidden; text-overflow:ellipsis}}
  .note{{padding:0 10px 8px; font-size:9.5px; color:var(--muted)}}
  footer{{margin-top:18px; padding-top:11px; border-top:1px solid var(--line);
         color:var(--faint); font-size:10px; max-width:76ch}}
  footer strong{{color:var(--ink-2); font-weight:600}}
</style>
<div class="wrap">
  <header class="top">
    <div class="eyebrow">EWT &rarr; Entra migration &middot; group definitions</div>
    <h1>EWT Entra Groups</h1>
    <p class="standfirst">The proposed Entra groups and exactly which EWT roles each one
      contains. Every group includes the shared base listed first; each group section then
      shows only what it adds on top.</p>
    <div class="provenance">Generated {TODAY} from observed Oracle grants across 7 instances.</div>
  </header>
  <div class="stats">
    <div class="stat is-accent"><b>{len(groups)}</b><span>Entra groups</span></div>
    <div class="stat is-accent"><b>{total_people}</b><span>People assigned</span></div>
    <div class="stat"><b>{len(set().union(*sets.values()))}</b><span>EWT roles covered</span></div>
    <div class="stat"><b>{total_gain}</b><span>Roles newly granted</span></div>
  </div>

  <table class="idx">
    <tr><th>Group</th><th>Name</th><th class="num">People</th>
        <th class="num">Roles</th><th class="num">Beyond base</th><th class="num">New grants</th></tr>"""]

    if admin:
        parts.append(f'<tr class="admin"><td class="id">ADMIN</td><td>{E(admin["proposed_name"])}</td>'
                     f'<td class="num">{admin["members"]}</td><td class="num">{admin["role_count"]}</td>'
                     f'<td class="num">{len(sets["ADMIN"] - base)}</td>'
                     f'<td class="num">{gain.get("ADMIN", 0)}</td></tr>')
    for g in nonadmin:
        gid = g["group_id"]
        parts.append(f'<tr><td class="id">{gid}</td><td>{E(g["proposed_name"])}</td>'
                     f'<td class="num">{g["members"]}</td><td class="num">{g["role_count"]}</td>'
                     f'<td class="num">{len(sets[gid] - base)}</td>'
                     f'<td class="num">{gain.get(gid, 0)}</td></tr>')
    parts.append("</table>")

    parts.append(f"""
  <section class="grp big">
    <div class="ghead"><span class="gid">BASE</span>
      <span class="gname">Shared base, included in every group below</span>
      <span class="gmeta">{len(base)} roles &middot; all {total_people} people</span></div>
    <div class="note">Held by everyone today. Listed once here rather than repeated in
      all {len(nonadmin)} groups.</div>
    <div class="roles">{role_cells(base, cat)}</div>
  </section>""")

    order = ([admin] if admin else []) + nonadmin
    for g in order:
        gid = g["group_id"]
        extra = sets[gid] - base
        big = " big" if len(extra) > 60 else ""
        mem = members.get(gid, [])
        memline = (f'<div class="gmembers">{E(", ".join(sorted(mem)))}</div>'
                   if mem and len(mem) <= 20 else "")
        parts.append(f"""
  <section class="grp{big}">
    <div class="ghead"><span class="gid">{gid}</span>
      <span class="gname">{E(g["proposed_name"])}</span>
      <span class="gmeta">{g["members"]} people &middot; {g["role_count"]} roles
        ({len(extra)} beyond base) &middot; +{gain.get(gid, 0)} new</span></div>
    {memline}
    <div class="roles">{role_cells(extra, cat)}</div>
  </section>""")

    parts.append(f"""
  <footer>
    <p><strong>Reading this.</strong> A group's full contents are the {len(base)} base roles
      plus the roles listed in its own section. &ldquo;New grants&rdquo; is how many role
      assignments the group creates that its members do not hold today: the cost of
      merging similar people into one group. Nobody loses access.</p>
    <p><strong>Scope.</strong> People active in the last two years, matched to an active
      employee. The ACCUTRACK service account and the product-owner account provisioned for
      this migration are excluded.</p>
  </footer>
</div>""")

    os.makedirs("analysis", exist_ok=True)
    open("analysis/entra-groups.html", "w", encoding="utf-8").write("\n".join(parts))

    with open("analysis/entra-group-roles.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["group_id", "group_name", "role", "privilege", "in_shared_base",
                    "what_it_does", "subsystem", "area"])
        for g in order:
            gid = g["group_id"]
            for role in sorted(sets[gid]):
                c = cat.get(role, {})
                w.writerow([gid, g["proposed_name"], role, c.get("privilege", ""),
                            "Y" if role in base else "N", c.get("what_it_does", ""),
                            c.get("subsystem", ""), c.get("area", "")])

    rows = sum(len(sets[g["group_id"]]) for g in order)
    print(f"  wrote analysis/entra-groups.html")
    print(f"  wrote analysis/entra-group-roles.csv ({rows} group-role rows)")
    print(f"  base roles listed once: {len(base)}")


if __name__ == "__main__":
    main()
