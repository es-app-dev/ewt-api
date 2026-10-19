# Block WHERE clauses: built, live in the next dev dist

**From:** the API side (`C:\essource\ewt-api`)
**Date:** 2026-10-01
**Answers:** `API-HANDOFF-Block-Where.md`, 30 Sep
**Short version:** yes, built as asked. Send us the generated registry.

---

## What is in

`where=<name>` on `GET /odata/{entitySet}`, exactly the shape you proposed. The server holds the
text; the request carries only a name.

    GET /odata/AT_OUTBOUND_SHIPMENTS?db=BCTN&where=AT5521.OUTSHIPMT&$filter=SHIPMENT_NBR eq '000150'

    SELECT ... FROM AT_OUTBOUND_SHIPMENTS
     WHERE (<the registry's text for AT5521.OUTSHIPMT>) AND (<the translated $filter>)

Confirmed against dev BCTN:

| Query | Rows |
|---|---|
| `AT_OUTBOUND_SHIPMENTS`, no `where` | 31,163 |
| `where=AT5510.OUTSHIPMT` (excludes TRANSFER) | 23,309 |
| `where=AT5521.OUTSHIPMT` (site 2, dated) | 10,916 |
| `where=AT5521.OUTSHIPMT` **and** `$filter=DISP_SITE_SEQ_ID eq 3` | 0 |

That last row is the point: the clause ANDs on, so a `$filter` narrows within the block and cannot
widen past it.

- **`$count`, `$apply`, `$top`, `$skip`, `$orderby`, `$select`** all work inside the clause.
  `$count` and `$apply=aggregate($count as n)` agree on all three entries, so a total you show on a
  screen counts the rows the block shows and nothing else.
- **Writes are untouched.** PATCH, DELETE and `$batch` address rows by key as before.
- **Per entity set.** A name used against another table is a 400, not a silent pass.

## Binds

As you proposed: `&bind.MATL.CNTNR_SEQ_ID=4211`. Bound by Oracle, never concatenated. A value
containing `' OR '1'='1` returns 0 rows, because it is compared as a string.

In the registry the placeholder is the Forms name with dots turned to underscores, since
`:MATL.CNTNR_SEQ_ID` is not a legal Oracle bind name. So the clause reads `:MATL_CNTNR_SEQ_ID` and
the request still sends `bind.MATL.CNTNR_SEQ_ID`. We do the mapping; you write the Forms name in
`binds` and the underscored one in `sql`. A bind used more than once in one clause is fine.

`type` is `number`, `string` or `date`.

## The registry format

`EWT.Api/block-wheres.json`, placed on the server and reviewed by hand, like `relationships.json`.
Nothing writes it at runtime and there is no POST.

```json
{
  "blockWheres": [
    {
      "name": "AT3110.MATL",
      "entitySet": "AT_BARCODES",
      "sql": "NOT EXISTS (SELECT 1 FROM AT_BARCODE_HAZ_WASTE_CODES h WHERE h.MATL_SEQ_ID = :MATL_MATL_SEQ_ID)",
      "binds": [ { "name": "MATL.MATL_SEQ_ID", "type": "number" } ],
      "note": "AT3110 block MATL. Correlated on the master's current record."
    }
  ]
}
```

Rules, all enforced when the file loads:

- `name` unique, `entitySet` and `sql` required.
- `sql` is a **predicate only**: no semicolon, no `--` or `/*` comment, balanced parentheses, and it
  may not start with a statement keyword.
- Every declared bind must appear in `sql`; every `:placeholder` in `sql` must be declared.

A bad entry is **rejected and the rest still load**, with the reason logged at error level at
startup. We chose that over failing the whole file so one bad clause does not take the server down,
but it does mean a rejected entry is a screen quietly showing rows the legacy does not. Check the
startup log after you send a new registry. Example from our own testing:

```
Rejected 4 block WHERE entries:
  TEST.REJECT_UNDECLARED: the sql uses :NOT_DECLARED, which is not declared in binds
  TEST.REJECT_SEMICOLON: the sql contains a semicolon
  TEST.REJECT_COMMENT: the sql contains a comment, which would hide text from review
  TEST.REJECT_STATEMENT: the sql starts with a statement keyword; it must be a WHERE predicate only
```

## What is registered now

Three, the ones your document quotes in full. Everything else in your table is abridged with `...`,
so we did not guess at it.

| Name | Entity set |
|---|---|
| `AT5510.OUTSHIPMT` | `AT_OUTBOUND_SHIPMENTS` |
| `AT5511.OUTSHIPMT` | `AT_OUTBOUND_SHIPMENTS` |
| `AT5521.OUTSHIPMT` | `AT_OUTBOUND_SHIPMENTS` |

`GET /admin/block-wheres` lists what is live, with each entry's SQL and binds.

## What we need from you

The generated registry: one entry per block WHERE you cannot translate, in the format above, with
the **full** clause rather than the abridged one. Send it as a file and we will review and place it,
the same way as `relationships.json`. Points worth settling as you generate:

1. **One name per block, even when two blocks share a clause.** We registered AT5510 and AT5511
   separately although their text is identical, so either screen can change without touching the
   other. Keep doing that.
2. **`AT5161`, `AT1310.COMNT`, `WB1000`, `WB2002`, `AT1510`** are a single table row in your
   document. Those need to arrive as separate entries with their real text.
3. **The database link one.** A clause that reaches across a link will run on the signed-in session
   like any other, but tell us which it is so we watch it: the daughters' links were pointed at
   production until last week, and we would rather not find out through a WHERE clause.
4. **CONNECT BY.** Fine as a predicate if it is inside a subquery. If a block's clause needs
   CONNECT BY at the top level of its own query, that is not a predicate and will not fit this
   mechanism. Flag any of those and we will look at them separately.

## One thing we did not do

The two nav-property failures you reported:

    $filter=DISP_SITE_SEQ_ID eq 2 and Shipments/SHIPMENT_DT ne null          -> ORA-00904
    $filter=DISP_SITE_SEQ_ID eq 2 and Shipments/any(s:s/SHIPMENT_DT ne null) -> ORA-00936

Those are real. `$filter` does not understand a path through a navigation property at all: it
expects a plain column, so `Shipments/SHIPMENT_DT` reaches Oracle as a column name and ORA-00904 is
the honest answer. We have not fixed it, because as you note it would cover only the plain
semi-joins and you need the registry regardless. Say the word if you want it after the 87 are
unblocked, and note it would be a `$filter` change, not a `where=` one.

## Also

The 91 list-of-values procedures are live. `EWT_UI` now holds 99 public procedures, deployed and
`VALID` on all seven instances, confirmed through `/odata/proc?db=BCTN`. Note that endpoint takes
`db=`, not `instance=`, and that it returns one extra row for `EWT_UI` with a null `procedureName`:
that is the package-level row Oracle keeps in `ALL_PROCEDURES`. Filter it out.
