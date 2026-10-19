"""
Turns the UI team's sequence-map.json into the config the API loads.

The legacy forms allocate their own keys in PRE-INSERT (:BLOCK.PK := SOME_SEQ.NEXTVAL).
A REST client should not have to do that, so the server assigns the key on POST instead.

Only one shape is safe to auto-assign: the sequence feeds the table's SOLE primary key
column. Three shapes are not, and are written to "excluded" with the reason rather than
being dropped silently:

  compound PK  - the other key columns come from the client, so filling one of them
                 blind can collide
  not the PK   - e.g. AT_CONTACTS.ADDR_SEQ_ID <- ADDR_SEQ is a child allocating its
                 PARENT's key. Auto-assigning it would silently orphan the row.
  no PK        - nothing to fill; see the no-primary-key addressing work instead

Classification is done here against the API's own metadata, not taken on trust from
the input file. Both agree: 80 / 4 / 4 / 8.

Usage: python scripts/build-sequence-map.py
Output: EWT.Api/sequences.json
"""

import collections
import datetime
import json
import os

SRC = "C:/essource/ewt-ui/analysis/api/sequence-map.json"
OUT = "EWT.Api/sequences.json"
METADIR = "EWT.Api/metadata"

# Allocated by their sequence and nothing else, though the column is not a sole primary
# key. Verified in API-HANDOFF-Phase1-Gaps-REPLY-2.md Q1 by counting every write to each
# column across all 161 modules: no other assignment, never in an INSERT column list,
# never in an UPDATE ... SET.
APPROVED = {
    "AT_BARCODE_HAZ_WASTE_CODES":
        "no PK; 3 writes, all from CNTNR_HAZ_SEQ; measured unique on CLUT (83,221 rows) "
        "and BCTN (53,985 rows)",
    "AT_BARCODE_UHC_CODES":
        "no PK; 3 writes, all from CNTNR_UHC_SEQ; measured unique on BCTN (380 rows)",
    "AT_UHC_HAZ":
        "no PK; 1 write from UHC_HAZ_SEQ; measured unique on CORP (1,594 rows)",
    "AT_WASTE_STREAM_ANALYSIS_ITEMS":
        "no PK; 1 write from WSCMPANLITM_SEQ, plus one copy via a Designer temp in AT5331; "
        "measured unique on BCTN (1,161 rows)",
    "AT_PRODUCT_SERVICES":
        "compound PK; measured unique on CORP (754 rows)",
}

# Refused despite resembling the cases above. The last three were measured against the
# instance holding real volume, counting rows against distinct values of the column, and
# it is not unique there, so a sequence is not what allocates it. Auto-assigning one
# would collide.
REFUSED = {
    "WB_BATCH_HEADERS":
        "BATCH_SEQ_ID is assigned from something other than its sequence 33 times, "
        "appears in 9 INSERT column lists and is updated after insert 34 times",
    "AT_INVOICE_LINE_ITEMS":
        "measured on BCTN: 738,724 rows but 628,790 distinct INVLITM_SEQ_ID",
    "AT_INVOICE_LINE_RNCNTNR":
        "measured on BCTN: 18,615 rows but 3,740 distinct INVLITM_SEQ_ID; the column "
        "references the parent line item rather than being allocated per row",
    "AT_BATCH_DAUGHTERS":
        "measured on BCTN: 48,522 rows but 47,858 distinct CNTNR_SEQ_ID; the column "
        "references a container rather than being allocated per row",
}


def main():
    src = json.load(open(SRC, encoding="utf-8"))

    meta = {}
    for fn in sorted(os.listdir(METADIR)):
        if fn.startswith("tables.") and fn.endswith(".json"):
            inst = fn[len("tables."):-len(".json")]
            meta[inst] = json.load(open(os.path.join(METADIR, fn), encoding="utf-8"))["tables"]

    assign, excluded = {}, []
    for e in src["resolved"]:
        table, column, seq = e["table"], e["column"], e["sequence"]
        on = [i for i in meta if table in meta[i]]
        if not on:
            excluded.append({**pick(e), "reason": "table not present on any instance"})
            continue

        pks = {tuple(meta[i][table].get("primaryKeyColumns") or []) for i in on}
        if len(pks) > 1:
            excluded.append({**pick(e), "reason": "primary key differs between instances"})
            continue
        pk = pks.pop()

        sole_pk = len(pk) == 1 and pk[0].upper() == column.upper()

        if sole_pk:
            basis = "sole primary key"
        elif table in APPROVED:
            basis = APPROVED[table]
        else:
            if table in REFUSED:
                reason = REFUSED[table]
            elif not pk:
                reason = "table declares no primary key"
            elif len(pk) > 1:
                reason = f"column is part of a compound key ({', '.join(pk)})"
            else:
                reason = (f"column is not the primary key ({pk[0]}); "
                          "a child allocating its parent's key")
            excluded.append({**pick(e), "reason": reason})
            continue

        assign[table] = {"column": column, "sequence": seq, "basis": basis,
                         "instances": sorted(on), "forms": e["forms"]}

    # Structural review: does any allocated column belong to a different table?
    # Only entries that are NOT this table's own sole primary key are interesting. When the
    # column is this table's key, that is decisive, and some archive or workbench mirror
    # carrying the same column name says nothing: this schema is full of those, and flagging
    # them buries the one real signal under ten false ones.
    owners = pk_owners(meta)
    for table, entry in assign.items():
        if entry["basis"] == "sole primary key":
            continue
        elsewhere = sorted(owners.get(entry["column"].upper(), set()) - {table})
        if elsewhere:
            entry["alsoPrimaryKeyOf"] = elsewhere

    out = {
        "generated": datetime.date.today().isoformat(),
        "source": "ewt-ui/analysis/api/sequence-map.json, classified against EWT.Api/metadata/tables.*.json",
        "note": "Only tables in 'assign' get a server-assigned key on POST, and only when "
                "the client omits that column. Everything in 'excluded' is deliberate.",
        "assign": dict(sorted(assign.items())),
        "excluded": sorted(excluded, key=lambda x: (x["reason"], x["table"])),
    }
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(out, fh, indent=1)

    flagged = {t: v for t, v in assign.items() if "alsoPrimaryKeyOf" in v}
    reviewed = sum(1 for v in assign.values() if v["basis"] != "sole primary key")
    print(f"  auto-assign  : {len(assign)}  "
          f"({len(assign) - reviewed} sole PK, {reviewed} reviewed exceptions)")
    for r in sorted({x['reason'].split(' (')[0] for x in excluded}):
        print(f"  excluded     : {sum(1 for x in excluded if x['reason'].startswith(r))}  {r}")
    if flagged:
        print("")
        print(f"{len(flagged)} reviewed exception(s) use a column that is another table's")
        print("sole primary key. Advisory: confirm against data, never assume either way.")
        for table, entry in sorted(flagged.items()):
            print(f"    {table}.{entry['column']} is the PK of "
                  f"{', '.join(entry['alsoPrimaryKeyOf'])}")
            print(f"      basis: {entry['basis']}")

    print("")
    print(f"wrote {OUT}")


def pk_owners(meta):
    """
    Which tables have each column as their own sole primary key.

    The structural test for the mistake that got through once already: a map entry whose
    column is ANOTHER table's sole primary key is probably a child carrying its parent's
    key, not a column the sequence allocates. AT_CONTACTS.ADDR_SEQ_ID is the clear case,
    and AT_BATCH_DAUGHTERS.CNTNR_SEQ_ID is the one that was missed because it arrived
    labelled "compound key" rather than "parent reference".

    Advisory, never a verdict. This schema carries a lot of older duplicate tables, so a
    column can be some abandoned table's key and still be legitimately allocated here.
    Credit for the check to the UI side, in API-HANDOFF-Phase1-Gaps-REPLY-4.md.
    """
    owners = collections.defaultdict(set)
    for tables in meta.values():
        for name, t in tables.items():
            pk = t.get("primaryKeyColumns") or []
            if len(pk) == 1:
                owners[pk[0].upper()].add(name)
    return owners


def pick(e):
    return {"table": e["table"], "column": e["column"], "sequence": e["sequence"],
            "forms": e["forms"]}


if __name__ == "__main__":
    main()
