"""
Pulls hand-added $expand relationships off a running server and keeps them.

The UI team adds relationships through POST /admin/relationships when a join is real but no
foreign key expresses it, which is most of the ones onto views. Those land in the running
server's relationships.json. A deploy replaces that file, so without this they are lost, and
the loss is quiet: $expand simply stops offering them.

This pulls the live set, works out which entries are not in the generated set, records them
in relationships.manual.json, and rebuilds relationships.json as the union. Run it before
every deploy.

Every pulled relationship is validated against the cached schemas first. An entry naming a
table or column that does not exist is reported and not merged, because a bad one breaks
$expand for the whole source table rather than just itself.

Usage:
    python scripts/pull-live-relationships.py
    python scripts/pull-live-relationships.py --base http://localhost:5282
    python scripts/pull-live-relationships.py --dry-run
"""

import argparse
import json
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import relationships_merge as rm

DEFAULT_BASE = "https://ewt-dev-api.energysolutions.com"
METADIR = "EWT.Api/metadata"
FIELDS = ("name", "fromTable", "fromColumn", "toTable", "toColumn", "type")


def load_schemas():
    """Every entity across every instance, and which instances hold it."""
    entities = {}
    for fn in sorted(os.listdir(METADIR)):
        if not (fn.startswith("tables.") and fn.endswith(".json")):
            continue
        instance = fn[len("tables."):-len(".json")]
        with open(os.path.join(METADIR, fn), encoding="utf-8") as fh:
            for name, entity in json.load(fh)["tables"].items():
                slot = entities.setdefault(
                    name, {"columns": {c["columnName"].upper() for c in entity["columns"]},
                           "instances": []})
                slot["instances"].append(instance)
    return entities


def problems_with(rel, entities):
    """Why this relationship cannot be used, or an empty list."""
    issues = []
    for side in ("from", "to"):
        table = rel.get(f"{side}Table")
        column = rel.get(f"{side}Column")
        if not table or not column:
            issues.append(f"{side} side is incomplete")
            continue
        entity = entities.get(table)
        if entity is None:
            issues.append(f"{side} table {table} exists on no instance")
        elif column.upper() not in entity["columns"]:
            issues.append(f"{side} column {table}.{column} does not exist")
    return issues


def usable_on(rel, entities):
    """Instances where both ends exist, so the join can actually resolve."""
    a = set(entities.get(rel["fromTable"], {}).get("instances", []))
    b = set(entities.get(rel["toTable"], {}).get("instances", []))
    return sorted(a & b)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default=DEFAULT_BASE, help="running server to pull from")
    parser.add_argument("--dry-run", action="store_true", help="report, write nothing")
    args = parser.parse_args()

    url = args.base.rstrip("/") + "/admin/relationships"
    try:
        with urllib.request.urlopen(url, timeout=90) as response:
            live = json.load(response).get("relationships", [])
    except Exception as e:
        sys.exit(f"Could not read {url}: {e}")

    generated = rm.load(rm.GENERATED)
    if not generated:
        sys.exit(f"{rm.GENERATED} is missing. Run scripts/convert-schema-metadata.py first.")

    known = {rm.key(r) for r in generated}
    existing_manual = {rm.key(r): r for r in rm.load(rm.MANUAL)}
    entities = load_schemas()

    added, rejected, unchanged = [], [], 0
    for rel in live:
        if rm.key(rel) in known:
            continue                                  # came from a foreign key
        clean = {f: rel.get(f) for f in FIELDS}
        issues = problems_with(clean, entities)
        if issues:
            rejected.append((clean, issues))
            continue
        if existing_manual.get(rm.key(clean)) == clean:
            unchanged += 1
            continue
        added.append(clean)

    print(f"  pulled from : {args.base}")
    print(f"  live total  : {len(live)}   generated: {len(generated)}")
    print(f"  already held: {unchanged}")
    print(f"  new or changed: {len(added)}")
    print(f"  rejected    : {len(rejected)}")

    for rel, issues in rejected:
        print(f"    REJECTED {rel['fromTable']}.{rel['name']}: {'; '.join(issues)}")

    if added:
        print()
        for rel in sorted(added, key=lambda r: (r["fromTable"], r["name"])):
            where = usable_on(rel, entities)
            scope = "all 7" if len(where) == 7 else ", ".join(where) or "nowhere"
            print(f"    + {rel['fromTable']}.{rel['name']:<26}"
                  f"{rel['fromColumn']} -> {rel['toTable']}.{rel['toColumn']}   [{scope}]")

    if args.dry_run:
        print("\n  dry run, nothing written")
        return 0

    if not added:
        print("\n  nothing new to keep")
        rm.combine()
        return 0

    merged = dict(existing_manual)
    for rel in added:
        merged[rm.key(rel)] = rel
    manual = sorted(merged.values(), key=lambda r: (r["fromTable"], r["name"]))

    rm.save(rm.MANUAL, manual,
            "Hand-added $expand relationships, mostly joins onto views that no foreign key "
            "expresses. Pulled from a running server with scripts/pull-live-relationships.py. "
            "These survive regeneration; the generated ones do not survive being edited here.")
    print(f"\n  manual file now holds {len(manual)}  -> {rm.MANUAL}")
    rm.combine()
    return 0


if __name__ == "__main__":
    sys.exit(main())
