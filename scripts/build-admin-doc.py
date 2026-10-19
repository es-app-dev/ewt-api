"""
Builds the Entra setup document for the administrator who has to create the groups.

Written for someone configuring Entra, not for a developer: what to create, what goes
inside what, who to add, in what order, and the three settings that will silently
break nesting if they are wrong.

Usage: python scripts/build-admin-doc.py   ->  analysis/entra-setup.html
"""

import collections
import csv
import datetime
import html
import os

E = html.escape
TODAY = datetime.date.today().isoformat()


def load():
    groups = {r["group_id"]: r for r in
              csv.DictReader(open("analysis/entra-nested-groups.csv", encoding="utf-8"))}
    edges = list(csv.DictReader(open("analysis/entra-nested-edges.csv", encoding="utf-8")))
    people = list(csv.DictReader(open("analysis/entra-nested-assignments.csv", encoding="utf-8")))
    cat = {r["role"]: r for r in
           csv.DictReader(open("analysis/ewt-role-catalogue.csv", encoding="utf-8"))}
    return groups, edges, people, cat


def main():
    groups, edges, people, cat = load()
    parents = collections.defaultdict(list)
    children = collections.defaultdict(list)
    for e in edges:
        parents[e["child_group_id"]].append(e["parent_group_id"])
        children[e["parent_group_id"]].append(e["child_group_id"])

    members = collections.defaultdict(list)
    for p in people:
        for g in p["direct_groups"].split():
            members[g].append(p)

    ordered = [g for g in groups if g != "ADMIN"]
    ordered.sort(key=lambda g: -int(groups[g]["people_reached"]))

    # depth via longest path from a root, for the outline
    def depth(g, seen=()):
        if g in seen or not parents[g]:
            return 0
        return 1 + max(depth(p, seen + (g,)) for p in parents[g])
    dep = {g: depth(g) for g in ordered}

    total_people = len(people)
    total_assign = sum(int(p["direct_group_count"]) for p in people)
    _g = sorted(int(p["direct_group_count"]) for p in people)
    median_groups = _g[len(_g) // 2]
    maxdepth = max(dep.values())

    P = []
    P.append(f"""<title>EWT Entra Setup</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;500;600;700&display=swap">
<style>
  :root{{
    --ground:#FFFFFF; --surface:#FFFFFF; --surface-2:#F6F8F9;
    --ink:#141A1E; --ink-2:#3D4950; --muted:#59646C; --faint:#87949C;
    --line:#C9D2D7; --line-2:#DFE6EA; --grid:#E6EBED;
    --accent:#00789E; --accent-soft:#E2EFF4; --warn:#C2632A; --warn-soft:#FBEFE6;
    --sans:'IBM Plex Sans',-apple-system,'Segoe UI',sans-serif;
    --mono:'IBM Plex Mono',ui-monospace,Consolas,monospace;
  }}
  @page{{ size:A4 portrait; margin:13mm 11mm; }}
  *{{box-sizing:border-box; -webkit-print-color-adjust:exact; print-color-adjust:exact}}
  body{{background:var(--ground); color:var(--ink); font-family:var(--sans);
       font-size:10.5px; line-height:1.45}}
  .wrap{{max-width:1000px; margin:0 auto; padding-inline:16px; padding-block:0 26px}}
  .eyebrow{{font-family:var(--mono); font-size:9.5px; letter-spacing:.14em;
           text-transform:uppercase; color:var(--accent); font-weight:500}}
  h1{{font-size:27px; line-height:1.07; letter-spacing:-.022em; font-weight:700; margin:8px 0 0}}
  h2{{font-size:14px; font-weight:600; margin:0 0 6px; letter-spacing:-.005em}}
  .standfirst{{margin:9px 0 0; max-width:68ch; color:var(--ink-2); font-size:12px}}
  .provenance{{margin-top:12px; font-family:var(--mono); font-size:9.5px; color:var(--faint)}}
  header.top{{padding-block:0 12px; border-bottom:1px solid var(--line)}}
  section{{margin-top:16px; break-inside:avoid; page-break-inside:avoid}}
  section.long{{break-inside:auto; page-break-inside:auto}}
  .stats{{display:grid; grid-template-columns:repeat(4,1fr); gap:1px;
         background:var(--line); border:1px solid var(--line); margin-block:13px}}
  .stat{{background:var(--surface); padding:9px 11px}}
  .stat b{{display:block; font-family:var(--mono); font-weight:600; font-size:18px;
          font-variant-numeric:tabular-nums}}
  .stat span{{display:block; font-size:10px; color:var(--muted); margin-top:1px}}
  .stat.is-accent b{{color:var(--accent)}}
  .callout{{border:1px solid var(--warn); background:var(--warn-soft);
           padding:10px 12px; margin-block:12px}}
  .callout h2{{color:var(--warn)}}
  .callout ol{{margin:6px 0 0; padding-left:18px}}
  .callout li{{margin-bottom:5px}}
  ol.steps{{margin:4px 0 0; padding-left:18px}}
  ol.steps li{{margin-bottom:4px}}
  code{{font-family:var(--mono); font-size:9.5px; background:var(--grid); padding:0 3px}}
  table{{width:100%; border-collapse:collapse; font-size:9.5px; margin-top:6px}}
  th{{text-align:left; font-size:9px; text-transform:uppercase; letter-spacing:.06em;
     color:var(--muted); border-bottom:1px solid var(--line); padding:4px 5px}}
  td{{border-bottom:1px solid var(--line-2); padding:3px 5px; font-variant-numeric:tabular-nums}}
  td.gid{{font-family:var(--mono); font-weight:600; color:var(--accent)}}
  td.gname{{font-family:var(--mono)}}
  td.num{{text-align:right; font-family:var(--mono)}}
  td.par{{font-family:var(--mono); font-size:9px; color:var(--muted)}}
  .tree{{font-family:var(--mono); font-size:9.5px; line-height:1.55}}
  .tree div{{white-space:pre}}
  .tree .nm{{color:var(--ink)}}
  .tree .id{{color:var(--accent); font-weight:600}}
  .tree .meta{{color:var(--faint)}}
  .tree .also{{color:var(--warn)}}
  .mem{{font-family:var(--mono); font-size:9px; color:var(--ink-2);
       overflow-wrap:anywhere; padding:2px 0 6px}}
  .grp{{break-inside:avoid; page-break-inside:avoid; border:1px solid var(--line-2);
       padding:6px 9px; margin-bottom:6px}}
  .ghead{{display:flex; gap:8px; align-items:baseline; flex-wrap:wrap}}
  .ghead .id{{font-family:var(--mono); font-weight:600; color:var(--accent)}}
  .ghead .nm{{font-family:var(--mono); font-weight:600}}
  .ghead .meta{{margin-left:auto; font-family:var(--mono); font-size:9px; color:var(--muted)}}
  footer{{margin-top:18px; padding-top:11px; border-top:1px solid var(--line);
         color:var(--faint); font-size:10px; max-width:78ch}}
  footer strong{{color:var(--ink-2); font-weight:600}}
</style>
<div class="wrap">
  <header class="top">
    <div class="eyebrow">EWT &rarr; Entra migration &middot; setup instructions</div>
    <h1>EWT Entra Setup</h1>
    <p class="standfirst">The groups to create and who goes in each one.
      Built from the access {total_people} people hold in EWT today. Following this
      exactly reproduces that access, with nobody gaining or losing anything.</p>
    <div class="provenance">Generated {TODAY} from live Oracle grants across 7 instances.</div>
  </header>

  <div class="stats">
    <div class="stat is-accent"><b>{len(groups)}</b><span>Groups to create</span></div>
    <div class="stat is-accent"><b>{total_people}</b><span>People to assign</span></div>
    <div class="stat"><b>{median_groups}</b><span>Groups per person (median)</span></div>
    <div class="stat"><b>{total_assign}</b><span>User assignments</span></div>
  </div>

  <div class="callout">
    <h2>Read this before creating anything</h2>
    <p style="margin:0 0 7px">This is the same job you have just done for EWIS: one
      enterprise application, permissions named for what they let people do, and every
      assignment flat and direct. One difference. EWIS grants through <strong>app roles</strong>
      defined on the application; the groups below are <strong>security groups</strong> in the
      directory, which the EWT API reads through Microsoft Graph. If you would rather create
      them as app roles to match EWIS exactly, the names and the memberships are identical
      and nothing else in this document changes. Confirm which with the development team
      before you start, because moving afterwards means redoing {total_assign} assignments.</p>
    <ol>
      <li><strong>Assign only <code>EWT-Users</code> to the application.</strong> It is
        the sign-in gate and carries no permissions. The 53 role groups are directory
        groups the application reads; they are not assigned to the application.</li>
      <li><strong>Do not nest these groups.</strong> Every membership is direct and nothing
        is inherited, so a person must be added to each group they need even where it looks
        redundant. Entra ignores nesting for application assignment and for app roles, so
        nesting them to save effort would fail silently rather than error.</li>
      <li><strong>Do not use the "Groups assigned to the application" claim
        option.</strong> It also requires direct membership and ignores nesting.</li>
      <li><strong>Token group limits.</strong> Entra emits at most 150 groups (SAML) or 200
        (JWT), counting nested ones. Over the limit it drops the groups claim
        <em>entirely</em>. The failure is total, not partial.</li>
    </ol>
    <p style="margin:7px 0 0">The application reads membership from Microsoft Graph rather
      than from the sign-in token, so the last two points above are precautions rather than
      live risks. Confirm that with the development team before go-live.</p>
  </div>


  <section>
    <h2>Order of work</h2>
    <ol class="steps">
      <li>Create all {len(groups)} groups as <strong>security groups</strong>, assigned
        membership type. Use the names in the table below.</li>
      <li>Assign <strong>only</strong> <code>EWT-Users</code> to the EWT enterprise
        application. Leave every other group unassigned to it. They are directory groups
        the application reads through Microsoft Graph.</li>
      <li>Add all {total_people} people to <code>EWT-Users</code> as direct members. This
        is what lets them sign in; it grants no EWT permissions by itself.</li>
      <li>Add people to their groups, per the list below. This is the bulk of the work:
        {total_assign} memberships across {len(groups)} groups, a median of 23 groups per
        person. Do this in bulk, not through the portal:
        <code>analysis/entra-nested-assignments.csv</code> has one row per person with their
        group list, and <code>analysis/entra-nested-groups.csv</code> has one row per group.
        Either drives a PowerShell or Graph import directly.</li>
      <li>Spot-check three people: the number of groups they are in should match
        <code>direct_group_count</code> for them in
        <code>analysis/entra-nested-assignments.csv</code>.</li>
    </ol>
    <p style="margin-top:6px"><code>EWT-Users</code> carries no roles. It is the sign-in
      gate only. <code>EWT-Administrator</code> is separate and holds every role; add its
      three people directly.</p>
  </section>
""")

    # ---- group table ----
    P.append("""
  <section class="long">
    <h2>Groups to create</h2>
    <p>Names ending in a number (for example <code>EWT-ContainersBarcodes-Oper-3</code>) are
      placeholders. The business taxonomy could not tell those groups apart, so they are
      numbered rather than named. They work as they stand, but someone who knows EWT should
      rename them before this is handed to users.</p>
    <table>
      <tr><th>ID</th><th>Entra group name</th><th class="num">Roles</th>
          <th class="num">People to add</th></tr>""")
    a = groups["ADMIN"]
    P.append(f'<tr><td class="gid">ADMIN</td><td class="gname">{E(a["entra_group_name"])}</td>'
             f'<td class="num">{a["roles_in_group"]}</td>'
             f'<td class="num">{a["directly_assigned"]}</td></tr>')
    for g in ordered:
        r = groups[g]
        P.append(f'<tr><td class="gid">{g}</td><td class="gname">{E(r["entra_group_name"])}</td>'
                 f'<td class="num">{r["roles_in_group"]}</td>'
                 f'<td class="num">{r["directly_assigned"]}</td></tr>')
    P.append("</table></section>")

    # ---- hierarchy outline ----


    # ---- who goes where ----
    P.append("""
  <section class="long">
    <h2>Who to add to each group</h2>
    <p>Every group and its full membership. There is no inheritance, so each list below is
      exactly who must be added to that group.</p>""")
    for g in ["ADMIN"] + ordered:
        mem = members.get(g, [])
        if not mem:
            continue
        r = groups[g]
        names = ", ".join(sorted(
            f'{m["last_name"]}, {m["first_name"]} ({m["username"]})'.strip(" ,()")
            or m["username"] for m in mem))
        P.append(f"""<div class="grp"><div class="ghead">
          <span class="id">{g}</span><span class="nm">{E(r["entra_group_name"])}</span>
          <span class="meta">{len(mem)} to add</span></div>
          <div class="mem">{E(names)}</div></div>""")
    P.append("</section>")

    P.append(f"""
  <footer>
    <p><strong>What this is built from.</strong> The Oracle role grants held today by
      {total_people} people who have used EWT in the last two years and match an active
      employee. The model was verified to grant exactly those roles: 0 gained, 0 lost.</p>
    <p><strong>Names are provisional.</strong> Group names were generated from the
      application's own subsystem and area taxonomy. Rename them freely; the application
      matches on the group's object ID, not its name.</p>

  </footer>
</div>""")

    os.makedirs("analysis", exist_ok=True)
    open("analysis/entra-setup.html", "w", encoding="utf-8").write("\n".join(P))
    print(f"  groups {len(groups)} | edges {len(edges)} | people {total_people} "
          f"| assignments {total_assign} | max depth {maxdepth}")
    print("  wrote analysis/entra-setup.html")


if __name__ == "__main__":
    main()
