"""
Converts docs/tables_extra.json (per-instance Oracle schema research) into the metadata
cache the API loads, one file per instance.

Why per instance: the seven databases do NOT share one schema. 1,388 entities are common
to all, but the union is 1,864 and CORP alone has 187 nobody else does. A single model
built from CORP advertises entities that are absent elsewhere and hides 279 that exist
elsewhere but not on CORP.

Also emits the $expand relationships from the real foreign keys.

Those go to relationships.generated.json, not straight to relationships.json, because the UI
team adds relationships of their own through POST /admin/relationships for joins no foreign
key expresses. Writing the generated set directly over relationships.json would delete
theirs. See scripts/relationships_merge.py.

Outputs
  EWT.Api/metadata/tables.<INSTANCE>.json   one per instance, API cache format
  EWT.Api/relationships.generated.json      $expand definitions from foreign keys
  EWT.Api/relationships.json                the above merged with relationships.manual.json

Usage: python scripts/convert-schema-metadata.py
"""

import collections
import datetime
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import relationships_merge as rm

SRC = "docs/tables_extra.json"
OUTDIR = "EWT.Api/metadata"
RELS = "EWT.Api/relationships.generated.json"
DEFAULT_OWNER = "ACCUTRACK"


def owner_from_existing():
    """Reuse whatever owner the current cache recorded; the research file omits it."""
    p = "EWT.Api/tables.json"
    if not os.path.exists(p):
        return DEFAULT_OWNER
    try:
        d = json.load(open(p, encoding="utf-8"))
        t = d.get("tables", d)
        owners = collections.Counter(v.get("owner") for v in t.values() if v.get("owner"))
        return owners.most_common(1)[0][0] if owners else DEFAULT_OWNER
    except Exception:
        return DEFAULT_OWNER


def unique_keys(e):
    """
    Unique constraints first, then unique indexes that no constraint already covers.

    A table with no PRIMARY KEY constraint can still have exactly one addressable row,
    and in this schema that is usually enforced by an index rather than declared. The API
    exposes these so a caller knows which columns will identify a row; 8 of the 277 bound
    tables depend on it.
    """
    out, seen = [], set()
    for uk in (e.get("uniqueKeys") or []):
        cols = uk.get("columns") or []
        if not cols or str(uk.get("status", "ENABLED")).upper() != "ENABLED":
            continue
        seen.add(tuple(cols))
        out.append({"name": uk["name"], "columns": cols, "source": "constraint"})
    for ix in (e.get("indexes") or []):
        cols = ix.get("columns") or []
        if not ix.get("unique") or not cols or tuple(cols) in seen:
            continue
        seen.add(tuple(cols))
        out.append({"name": ix["name"], "columns": cols, "source": "index"})
    return out


def convert_column(c):
    return {
        "columnName": c["name"],
        "dataType": c["dataType"],
        "dataLength": c.get("length"),
        "dataPrecision": c.get("precision"),
        "dataScale": c.get("scale"),
        "isNullable": bool(c.get("nullable")),
        "columnId": c.get("position"),
    }


def main():
    src = json.load(open(SRC, encoding="utf-8"))
    owner = owner_from_existing()
    os.makedirs(OUTDIR, exist_ok=True)
    today = datetime.datetime.now(datetime.timezone.utc).isoformat()

    summary, rels, seen_rel = [], [], set()
    for inst, entities in src.items():
        tables = {}
        for name, e in entities.items():
            is_view = str(e.get("kind", "TABLE")).upper() == "VIEW"
            tables[name] = {
                "tableName": name,
                "owner": owner,
                "columns": [convert_column(c) for c in e.get("columns", [])],
                # a view has no primary key; the research file agrees but be defensive
                "primaryKeyColumns": [] if is_view else list(e.get("primaryKey") or []),
                "uniqueKeys": [] if is_view else unique_keys(e),
                "isView": is_view,
            }

            # foreign keys -> $expand relationships. Single-column keys only: the
            # relationship model joins on one column and cannot express a composite.
            for fk in (e.get("foreignKeys") or []):
                cols, refcols = fk.get("columns") or [], fk.get("refColumns") or []
                if len(cols) != 1 or len(refcols) != 1:
                    continue
                if str(fk.get("status", "ENABLED")).upper() != "ENABLED":
                    continue
                ref = fk.get("refTable")
                if not ref or ref not in entities:
                    continue
                # name the navigation after the target, deduped per source table
                base = ref[3:] if ref.startswith("AT_") else ref
                nm = "".join(w.capitalize() for w in base.split("_"))
                key = (name, nm)
                i = 2
                while key in seen_rel and (name, f"{nm}{i}") in seen_rel:
                    i += 1
                if key in seen_rel:
                    nm, key = f"{nm}{i}", (name, f"{nm}{i}")
                if key in seen_rel:
                    continue
                seen_rel.add(key)
                rels.append({
                    "name": nm, "fromTable": name, "fromColumn": cols[0],
                    "toTable": ref, "toColumn": refcols[0], "type": "many-to-one",
                })

        out = {"generatedAt": today, "instance": inst, "tables": tables}
        path = os.path.join(OUTDIR, f"tables.{inst}.json")
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(out, fh, separators=(",", ":"))
        summary.append((inst, len(tables),
                        sum(1 for v in tables.values() if v["isView"]),
                        sum(1 for v in tables.values() if v["primaryKeyColumns"]),
                        sum(1 for v in tables.values()
                            if not v["primaryKeyColumns"] and v["uniqueKeys"]),
                        os.path.getsize(path)))

    rm.save(RELS, rels, "Generated from Oracle foreign keys by "
                        "scripts/convert-schema-metadata.py. Do not edit: it is overwritten "
                        "on every run. Hand-added entries belong in relationships.manual.json.")

    print(f"  owner recorded as: {owner}")
    print(f"  {'instance':10}{'entities':>10}{'views':>8}{'with PK':>9}{'UK only':>9}{'file':>12}")
    for i, n, v, pk, uk, sz in summary:
        print(f"  {i:10}{n:>10}{v:>8}{pk:>9}{uk:>9}{sz/1_048_576:>10.1f}MB")
    print(f"\n  wrote {len(summary)} files to {OUTDIR}/")
    print(f"  wrote {len(rels)} generated relationships to {RELS}")
    rm.combine()


if __name__ == "__main__":
    main()
