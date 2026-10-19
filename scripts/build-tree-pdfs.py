"""
Builds both PDF source documents as indented tree views:

  1. analysis/po-tree-manager.html   manager -> user -> site
  2. analysis/po-tree-site.html      site -> manager -> user   (CORP excluded)

Static HTML, no client-side JS: a print target should not depend on script timing
inside a headless renderer. Connectors are CSS borders rather than box-drawing
characters, so alignment does not depend on the mono font loading.

Usage: python scripts/build-tree-pdfs.py
"""

import csv
import collections
import datetime
import html
import os

ALL_SITES = ["CORP", "BCTN", "CLUT", "EWTN", "BRON", "BASC", "MEMTN"]
DAUGHTERS = [s for s in ALL_SITES if s != "CORP"]
SRC = "analysis/ewt-manager-user-site-roles.csv"
NAMES = "analysis/ewt-badges-with-managers.csv"

# Service / non-human accounts to keep out of an org view. ACCUTRACK is the Oracle
# schema owner; it survived the employee match only because a real person's work
# email is registered against it in AT_ACCUTRACK_USERS.
EXCLUDE_USERS = {"ACCUTRACK", "KABADORF"}   # schema owner; PO account provisioned for the migration
E = html.escape
TODAY = datetime.date.today().isoformat()

SHELL_CSS = """
  :root{
    --ground:#FFFFFF; --surface:#FFFFFF; --surface-2:#F6F8F9;
    --ink:#141A1E; --ink-2:#3D4950; --muted:#59646C; --faint:#87949C;
    --line:#C9D2D7; --line-2:#DFE6EA; --grid:#E6EBED;
    --accent:#00789E; --accent-soft:#E2EFF4; --corp:#C2632A; --corp-soft:#F7E9DF;
    --sans:'IBM Plex Sans',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
    --mono:'IBM Plex Mono',ui-monospace,Consolas,monospace;
  }
  @page{ size:A4 portrait; margin:13mm 11mm; }
  *{box-sizing:border-box; -webkit-print-color-adjust:exact; print-color-adjust:exact}
  body{background:var(--ground); color:var(--ink); font-family:var(--sans);
       font-size:11px; line-height:1.4}
  .wrap{max-width:1000px; margin:0 auto; padding-inline:16px; padding-block:0 28px}

  .eyebrow{font-family:var(--mono); font-size:9.5px; letter-spacing:.14em;
           text-transform:uppercase; color:var(--accent); font-weight:500}
  h1{font-size:26px; line-height:1.08; letter-spacing:-.022em; font-weight:700;
     margin:8px 0 0; text-wrap:balance}
  .standfirst{margin:9px 0 0; max-width:64ch; color:var(--ink-2); font-size:12px}
  .provenance{margin-top:12px; font-family:var(--mono); font-size:9.5px; color:var(--faint)}
  header.top{padding-block:0 12px; border-bottom:1px solid var(--line)}

  .stats{display:grid; grid-template-columns:repeat(4,1fr); gap:1px;
         background:var(--line); border:1px solid var(--line); margin-block:13px}
  .stat{background:var(--surface); padding:9px 11px}
  .stat b{display:block; font-family:var(--mono); font-weight:600; font-size:18px;
          font-variant-numeric:tabular-nums}
  .stat span{display:block; font-size:10px; color:var(--muted); margin-top:1px}
  .stat.is-accent b{color:var(--accent)}

  .overview{border:1px solid var(--line); padding:11px 13px 8px; margin-block:13px;
            break-inside:avoid; page-break-inside:avoid}
  .overview h2{font-size:12.5px; margin:0 0 7px; font-weight:600}
  .bar-row{display:grid; grid-template-columns:50px 1fr 96px; align-items:center;
           gap:9px; margin-bottom:5px}
  .bar-lab{font-family:var(--mono); font-size:10px; font-weight:500; color:var(--ink-2)}
  .bar-track{position:relative; height:12px; background:var(--grid)}
  .bar-fill{position:absolute; inset:0 auto 0 0; background:var(--accent)}
  .bar-row.corp .bar-fill{background:var(--corp)}
  .bar-val{font-family:var(--mono); font-size:10px; color:var(--ink-2);
           text-align:right; font-variant-numeric:tabular-nums}

  /* ---------- tree ---------- */
  ul.tree, ul.tree ul{ list-style:none; margin:0; padding:0 }
  ul.tree ul{ margin-left:9px }
  ul.tree ul li{ position:relative; padding-left:15px }
  ul.tree ul li::before{ content:""; position:absolute; left:0; top:0; bottom:0;
                         border-left:1px solid var(--line-2) }
  ul.tree ul li:last-child::before{ bottom:auto; height:.72em }
  ul.tree ul li::after{ content:""; position:absolute; left:0; top:.72em; width:10px;
                        border-top:1px solid var(--line-2) }

  .node-mgr{font-weight:600; font-size:11.5px; letter-spacing:-.004em}
  .node-user{font-family:var(--mono); font-size:10.5px; color:var(--ink-2);
             overflow-wrap:anywhere}
  .node-site{font-family:var(--mono); font-size:10px; color:var(--accent); font-weight:500}
  .node-site.corp{color:var(--corp)}
  .badge{font-family:var(--mono); font-size:9.5px; color:var(--faint); margin-left:6px}
  .count{font-family:var(--mono); font-size:9.5px; color:var(--accent);
         font-weight:600; margin-left:6px}
  li > .row{padding:1.5px 0}

  .sites{font-family:var(--mono); font-size:9.5px; color:var(--muted); margin-left:7px}
  .sites .corp-site{color:var(--corp); font-weight:600}
  .block{break-inside:avoid; page-break-inside:avoid; border:1px solid var(--line-2);
         padding:7px 9px 8px; margin:0 0 7px; background:var(--surface)}
  .cols{column-count:2; column-gap:16px}

  section.site{break-before:page; page-break-before:always; padding-top:4px}
  section.site:first-of-type{break-before:auto; page-break-before:auto}
  .site-head{display:flex; align-items:baseline; gap:10px; flex-wrap:wrap;
             border-bottom:2px solid var(--accent); padding-bottom:5px; margin-bottom:10px}
  .site-code{font-family:var(--mono); font-size:21px; font-weight:600; color:var(--accent)}
  .site-meta{font-family:var(--mono); font-size:10.5px; color:var(--muted); margin-left:auto}

  footer{margin-top:18px; padding-top:11px; border-top:1px solid var(--line);
         color:var(--faint); font-size:10px; max-width:76ch;
         break-inside:avoid; page-break-inside:avoid}
  footer strong{color:var(--ink-2); font-weight:600}
"""

FONTS = """<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;500;600;700&display=swap">"""


def load():
    """Returns people keyed by badge. One badge is one person, even when that person
    has more than one login (a name change leaves the old username behind)."""
    rows = [r for r in csv.DictReader(open(SRC, encoding="utf-8"))
            if r["username"].upper() not in EXCLUDE_USERS]

    names = {}
    for r in csv.DictReader(open(NAMES, encoding="utf-8-sig", errors="replace")):
        names[r["badge"].strip()] = f'{r["last_name"].strip()}, {r["first_name"].strip()}'

    # Accounts with no application activity in the last two years are left out of the
    # org view. Activity comes from AT_MODULE_ACCESS; see scripts/find-dormant-users.py.
    dormant = set()
    act_path = "analysis/ewt-user-activity.csv"
    if os.path.exists(act_path):
        by_user = {}
        for a in csv.DictReader(open(act_path, encoding="utf-8")):
            by_user[a["username"].strip().upper()] = a["active_within_2y"]
        dormant = {u for u, v in by_user.items() if v != "Y"}
        rows = [r for r in rows if r["username"].strip().upper() not in dormant]

    people = {}
    for r in rows:
        b = r["employee_badge"]
        p = people.setdefault(b, {"badge": b, "logins": set(), "sites": set(),
                                  "mgr": r["manager_badge"],
                                  "mgr_name": r["manager_name"],
                                  "name": names.get(b, "")})
        p["logins"].add(r["username"])
        p["sites"].add(r["site"])

    mgr_user_site = collections.defaultdict(lambda: collections.defaultdict(set))
    for p in people.values():
        mgr_user_site[(p["mgr_name"], p["mgr"])][label(p)] = p["sites"]
    return people, mgr_user_site


def label(p):
    """A person's display name: real name where known, then every login they hold."""
    logins = " / ".join(sorted(p["logins"]))
    return f'{p["name"]} ({logins})' if p["name"] else logins


def bars(order, values, sub, corp_key=None):
    mx = max(values.values())
    out = []
    for k in order:
        pct = values[k] / mx * 100
        cls = " corp" if k == corp_key else ""
        out.append(f'<div class="bar-row{cls}"><span class="bar-lab">{k}</span>'
                   f'<span class="bar-track"><span class="bar-fill" style="width:{pct:.1f}%">'
                   f'</span></span><span class="bar-val">{sub[k]}</span></div>')
    return "\n".join(out)

def _sites_inline(p, site=None):
    """A person's sites as a comma list. Within a site section, show only the OTHER
    daughter sites they reach; in the global view, show all of them."""
    if site is not None:
        others = sorted((x for x in p["sites"] if x != site and x != "CORP"),
                        key=DAUGHTERS.index)
        if not others:
            return ""
        return f'<span class="sites">also {", ".join(others)}</span>'
    ordered = sorted(p["sites"], key=ALL_SITES.index)
    parts = [f'<span class="corp-site">{s}</span>' if s == "CORP" else s for s in ordered]
    return f'<span class="sites">{", ".join(parts)}</span>'


def _node(badge, pool, children, site, seen):
    """One person, and beneath them anyone who reports to them within this pool."""
    if badge in seen:
        return ""
    seen = seen | {badge}
    p = pool[badge]
    kids = sorted(children.get(badge, []),
                  key=lambda k: (-len(children.get(k, [])), label(pool[k])))
    subtree = "".join(_node(k, pool, children, site, seen) for k in kids)
    sub = f"<ul>{subtree}</ul>" if subtree else ""
    mark = f'<span class="count">&#9662;{len(kids)}</span>' if kids else ""
    return (f'<li><span class="row"><span class="node-user">{E(label(p))}</span>'
            f'<span class="badge">#{E(badge)}</span>{mark}'
            f'{_sites_inline(p, site)}</span>{sub}</li>')


def _hierarchy(pool):
    """Splits a pool of people into parent->children plus the roots, where a root is
    someone whose own manager is not in the pool."""
    children = collections.defaultdict(list)
    roots = []
    for b, p in pool.items():
        if p["mgr"] in pool and p["mgr"] != b:
            children[p["mgr"]].append(b)
        else:
            roots.append(b)
    groups = collections.defaultdict(list)
    for b in roots:
        groups[(pool[b]["mgr_name"], pool[b]["mgr"])].append(b)
    return children, groups


def _blocks(pool, children, groups, site=None):
    out = []
    for (mname, mbadge), members in sorted(groups.items(),
                                           key=lambda kv: (-len(kv[1]), kv[0][0])):
        members.sort(key=lambda b: (-len(children.get(b, [])), label(pool[b])))
        reach = len(members) + sum(len(children.get(b, [])) for b in members)
        nodes = "".join(_node(b, pool, children, site, frozenset()) for b in members)
        out.append(
            f'<div class="block"><ul class="tree"><li>'
            f'<span class="row"><span class="node-mgr">{E(mname)}</span>'
            f'<span class="badge">#{E(mbadge)}</span>'
            f'<span class="count">{reach}</span></span>'
            f'<ul>{nodes}</ul></li></ul></div>')
    return out


def doc1(people):
    """The whole organisation as one tree: manager -> person -> their sites."""
    children, groups = _hierarchy(people)
    per_site = {s: len([p for p in people.values() if s in p["sites"]]) for s in ALL_SITES}
    sub = {s: f"{per_site[s]} people" for s in ALL_SITES}
    pairs = sum(len(p["sites"]) for p in people.values())
    also_manage = len({p["mgr"] for p in people.values()} & set(people))
    blocks = _blocks(people, children, groups, site=None)

    return f"""<title>EWT Access Tree</title>
{FONTS}
<style>{SHELL_CSS}</style>
<div class="wrap">
  <header class="top">
    <div class="eyebrow">EWT &rarr; Entra migration &middot; discovery</div>
    <h1>EWT Access Tree</h1>
    <p class="standfirst">Everyone holding EWT access, arranged by who reports to whom, with
      the sites each person can reach. Someone who manages others appears once, in their own
      place in the reporting line.</p>
    <div class="provenance">Source: AT_ACCUTRACK_USERS + AT_ROLE_PRIVS across 7 Oracle
      instances, joined to the active-employee roster. Generated {TODAY}.</div>
  </header>
  <div class="stats">
    <div class="stat is-accent"><b>{len(people)}</b><span>People</span></div>
    <div class="stat is-accent"><b>{len(groups)}</b><span>Reporting lines</span></div>
    <div class="stat"><b>{also_manage}</b><span>Who also manage others</span></div>
    <div class="stat"><b>{pairs}</b><span>Person to site assignments</span></div>
  </div>
  <div class="overview"><h2>People per site</h2>
    {bars(ALL_SITES, per_site, sub, corp_key="CORP")}
  </div>
  <div class="cols">{''.join(blocks)}</div>
  <footer>
    <p><strong>Reading this.</strong> The bold name heads a reporting line: that manager
      sits outside the EWT population. Beneath sit their people, and beneath those anyone who in
      turn reports to them, so nobody appears twice.
      <span style="font-family:var(--mono)">&#9662;n</span> marks someone who manages n others
      here. Sites each person reaches follow their name; CORP is marked in orange. Where a person
      holds more than one login, usually a name change, every login is listed.</p>
    <p><strong>Scope.</strong> People matched to an active employee only. The ACCUTRACK service
      account is excluded, as are accounts with no matching active employee and Oracle
      built-in grants.</p>
  </footer>
</div>"""


def doc2(people):
    """site -> manager -> person, nested by real reporting line. CORP excluded."""
    per_site, line_count, secs = {}, {}, []

    for site in DAUGHTERS:
        at_site = {b: p for b, p in people.items() if site in p["sites"]}
        children, groups = _hierarchy(at_site)
        per_site[site] = len(at_site)
        line_count[site] = len(groups)
        blocks = _blocks(at_site, children, groups, site=site)
        secs.append(
            f'<section class="site">'
            f'<div class="site-head"><span class="site-code">{site}</span>'
            f'<span class="site-meta">{line_count[site]} reporting lines &middot; '
            f'{per_site[site]} people</span></div>'
            f'<div class="cols">{"".join(blocks)}</div></section>')

    sub = {s: f"{per_site[s]} people &middot; {line_count[s]} lines" for s in DAUGHTERS}
    total_people = len({b for b, p in people.items() if p["sites"] & set(DAUGHTERS)})
    also_manage = len({p["mgr"] for p in people.values()} & set(people))

    return f"""<title>EWT Sites by Manager</title>
{FONTS}
<style>{SHELL_CSS}</style>
<div class="wrap">
  <header class="top">
    <div class="eyebrow">EWT &rarr; Entra migration &middot; discovery</div>
    <h1>EWT Sites by Manager</h1>
    <p class="standfirst">Each daughter site, and the people working in it arranged by who
      reports to whom. Where someone manages others at the same site, their reports sit
      beneath them. CORP is excluded; this is the operating-site view.</p>
    <div class="provenance">Source: AT_ACCUTRACK_USERS + AT_ROLE_PRIVS, joined to the
      active-employee roster. Generated {TODAY}.</div>
  </header>
  <div class="stats">
    <div class="stat is-accent"><b>{len(DAUGHTERS)}</b><span>Daughter sites</span></div>
    <div class="stat is-accent"><b>{total_people}</b><span>People</span></div>
    <div class="stat"><b>{also_manage}</b><span>Who also manage others</span></div>
    <div class="stat"><b>{sum(line_count.values())}</b><span>Reporting lines</span></div>
  </div>
  <div class="overview"><h2>People per site</h2>
    {bars(DAUGHTERS, per_site, sub)}
  </div>
  {''.join(secs)}
  <footer>
    <p><strong>Reading this.</strong> The bold name heads a reporting line; beneath it sit that
      manager's people at this site, and beneath them anyone who in turn reports to them, so
      nobody appears twice within a site.
      <span style="font-family:var(--mono)">&#9662;n</span> marks someone who manages n others
      here. &ldquo;also BCTN, BRON&rdquo; after a name means that person holds access at those
      other daughter sites too. Where a person has more than one login, usually a name
      change, every login is listed.</p>
    <p><strong>Scope.</strong> People matched to an active employee only. The ACCUTRACK service
      account is excluded: it is the Oracle schema owner and matched the roster only because a
      real employee's work email is registered against it.</p>
  </footer>
</div>"""


if __name__ == "__main__":
    people, _ = load()
    os.makedirs("analysis", exist_ok=True)
    open("analysis/po-tree-manager.html", "w", encoding="utf-8").write(doc1(people))
    open("analysis/po-tree-site.html", "w", encoding="utf-8").write(doc2(people))
    multi = [p for p in people.values() if len(p["logins"]) > 1]
    print(f"  people (badge-keyed): {len(people)}")
    print(f"  people with >1 login: {len(multi)}")
    print("  wrote analysis/po-tree-manager.html")
    print("  wrote analysis/po-tree-site.html")
