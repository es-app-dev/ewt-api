"""
Builds a plain-English catalogue of every EWT role in use.

Three sources are merged:
  * AT_SECURITY_MODULES - the maintained module description, subsystem and area
    (populated for all 184 modules, so this is the primary source of meaning).
  * the legacy Oracle Forms XML - the tables each form reads/writes, and the
    actions its buttons perform, which is what "what is it used for" really means.
  * observed grants - how many people hold the role and which proposed Entra
    group it lands in.

Usage: python scripts/build-role-catalogue.py
Output: analysis/ewt-role-catalogue.csv
"""

import collections
import csv
import os
import re

LEGACY = r"C:\essource\ewt-ui\legacy_XML"
SECMOD = "analysis/_security_modules.csv"
ROLES = "analysis/ewt-user-roles-clean.csv"
ACTIVITY = "analysis/ewt-user-activity.csv"
GROUPS = "analysis/entra-role-groups.csv"
OUT = "analysis/ewt-role-catalogue.csv"

RX = re.compile(r"^(AT[0-9A-Z]+?)_(ADMIN|OPER|GUEST|READ|USER)$")

# GUEST / OPER / ADMIN is the convention the role names follow. It is an inference
# from the naming, not something the database states, so it is labelled as such.
LEVEL_MEANING = {
    "GUEST": "View only (inferred from naming)",
    "OPER":  "Day-to-day use (inferred from naming)",
    "ADMIN": "Full control incl. setup (inferred from naming)",
    "READ":  "View only (inferred from naming)",
    "USER":  "Standard use (inferred from naming)",
}

NOISE = {"ERROR", "CAUTION", "INFO", "WARNING", "NOTE", "CANCEL", "OK", "EXIT",
         "CLOSE", "HELP", "TRUE", "FALSE", "YES", "NO"}


def scan_forms():
    """module code -> {title, tables, actions} from the legacy form XML."""
    out = {}
    if not os.path.isdir(LEGACY):
        print(f"  ! legacy XML not found at {LEGACY}; tables/actions will be blank")
        return out
    for fn in sorted(os.listdir(LEGACY)):
        if not fn.lower().endswith(".xml"):
            continue
        try:
            with open(os.path.join(LEGACY, fn), "r", encoding="utf-8",
                      errors="replace") as fh:
                text = fh.read()
        except OSError:
            continue

        m = re.search(r'FormModule\s+Name="([^"]+)"', text)
        if not m:
            continue
        code = m.group(1).strip().upper()

        title = ""
        for t in re.findall(r'Title="([^"]{3,80})"', text):
            if t.strip().upper() not in NOISE:
                title = t.strip()
                break

        # Tables the form actually reads or writes.
        tables = []
        for t in re.findall(r'QueryDataSourceName="([A-Z0-9_]{3,})"', text):
            if t not in tables:
                tables.append(t)

        # Push buttons are the actions a user can take on the screen. The Comment
        # attribute looks promising but is mostly code-generator noise (CGDV./CGBG.).
        actions = []
        for tag in re.findall(r'<Item\b[^>]*>', text):
            if 'ItemType="Push Button"' not in tag:
                continue
            lb = re.search(r'Label="([^"]{2,40})"', tag)
            if not lb:
                continue
            a = " ".join(lb.group(1).split())
            if a.upper() not in NOISE and a not in actions:
                actions.append(a)

        out[code] = {"title": title, "tables": tables, "actions": actions}
    return out


def main():
    forms = scan_forms()
    print(f"  legacy forms scanned: {len(forms)}")

    meta = {}
    for r in csv.DictReader(open(SECMOD, encoding="utf-8")):
        meta.setdefault(r["MODULE_NAME"].upper(), {
            "desc": (r["DESCRIPTION"] or "").strip(),
            "sub": r["SUBSYSTEM_NAME"], "area": r["AREA_NAME"]})

    active = {r["username"].strip().upper()
              for r in csv.DictReader(open(ACTIVITY, encoding="utf-8"))
              if r["active_within_2y"] == "Y"}

    holders = collections.defaultdict(set)
    titles = {}
    for r in csv.DictReader(open(ROLES, encoding="utf-8")):
        u = r["username"].strip().upper()
        if u in active and u != "ACCUTRACK":
            holders[r["role"]].add(u)
            if r["module_code"] and r["module_title"]:
                titles.setdefault(r["module_code"], r["module_title"])

    role_group = {}
    if os.path.exists(GROUPS):
        for g in csv.DictReader(open(GROUPS, encoding="utf-8")):
            for role in g["roles"].split():
                role_group.setdefault(role, []).append(
                    "BASE" if g["group_id"] == "BASE" else g["group_id"])

    rows = []
    for role, users in sorted(holders.items()):
        m = RX.match(role)
        code, lvl = (m.group(1), m.group(2)) if m else ("", "")
        md = meta.get(code, {})
        fm = forms.get(code, {})
        desc = md.get("desc") or titles.get(code) or fm.get("title") or ""
        tables = fm.get("tables", [])[:4]
        actions = fm.get("actions", [])[:3]

        if desc and actions:
            example = f"{desc} - e.g. {', '.join(a.title() for a in actions)}"
        elif desc and tables:
            example = f"{desc} - works with {', '.join(tables[:2])}"
        else:
            example = desc or "No description recorded"

        rows.append({
            "role": role,
            "module": code,
            "privilege": lvl,
            "what_it_means": LEVEL_MEANING.get(lvl, ""),
            "what_it_does": desc,
            "example_use": example,
            "subsystem": md.get("sub", ""),
            "area": md.get("area", ""),
            "main_tables": ", ".join(tables),
            "people_with_role": len(users),
            "entra_group": ", ".join(sorted(set(role_group.get(role, [])))) or "straggler",
        })

    os.makedirs("analysis", exist_ok=True)
    with open(OUT, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    described = sum(1 for r in rows if r["what_it_does"])
    withtab = sum(1 for r in rows if r["main_tables"])
    withact = sum(1 for r in rows if " - e.g. " in r["example_use"])
    print(f"  roles in catalogue     : {len(rows)}")
    print(f"    with a description   : {described}")
    print(f"    with tables listed   : {withtab}")
    print(f"    with example actions : {withact}")
    print(f"    grouped / straggler  : "
          f"{sum(1 for r in rows if r['entra_group'] != 'straggler')} / "
          f"{sum(1 for r in rows if r['entra_group'] == 'straggler')}")
    print(f"  wrote {OUT}")


if __name__ == "__main__":
    main()
