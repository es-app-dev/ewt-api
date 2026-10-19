# AT5170: we found the objects ourselves. Here is everything to check it.

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-09-24
**Answering:** our own REPLY-12, which asked you a question we should have answered

REPLY-12 asked you to look for `AT_CNTNR_CHEMICALS_VW` and `AT_CNTNR_METALS_VW` and
said "if they exist under another name" without telling you what to match on. That
was not a usable ask. We have done the work; below is the answer with the evidence
and the exact commands to disprove it.

**Conclusion: the two views do not exist and are not needed. The blocks read
`AT_BARCODE_CHEMICALS` and `AT_BARCODE_METALS`, which you already expose.**
Nothing is required from you. **AT5170 is unblocked.**

---

## 1. What the two blocks actually need

From the JDAPI dump of `at5170.fmb`. Both are **query-only** — `allows: query`, no
insert, update or delete — with no WHERE and no ORDER BY.

**Block `CHEMICALS`** — 5 rows displayed, binds 8 columns:

| Column | Forms type |
|---|---|
| `LT_CONCENTRATION` | Char(1) |
| `CONCENTRATION_AMT` | Number(30) |
| `MEASURED_UNIT_CD_ID` | Char(10) |
| `HAZ_CONSTITUENT_IND` | Char(30) |
| `PCT_MEASURE` | Char(1) |
| `EL_SEQ_ID` | Number(30) |
| `CNTNR_SEQ_ID` | Number(40) |
| ~~`RETURN_BTN`~~ | **Push Button** — see section 3 |

**Block `METALS`** — 4 rows displayed, binds 6 columns: `LT_CONCENTRATION`,
`CONCENTRATION_AMT`, `MEASURED_UNIT_CD_ID`, `EL_SEQ_ID`, `CNTNR_SEQ_ID`, and the
same `RETURN_BTN`.

## 2. The objects that carry those columns

We searched all 348 cached schemas for tables carrying at least three of the five
marker columns (`EL_SEQ_ID`, `CNTNR_SEQ_ID`, `CONCENTRATION_AMT`,
`LT_CONCENTRATION`, `MEASURED_UNIT_CD_ID`). Exactly two came back, both **5 of 5**:

| | `AT_BARCODE_CHEMICALS` | `AT_BARCODE_METALS` |
|---|---|---|
| kind / owner | table / ACCUTRACK | table / ACCUTRACK |
| columns | 14 | 13 |
| primary key | `CNTNR_CHEMICAL_SEQ_ID` | `CNTNR_METAL_SEQ_ID` |
| instances | all 7 | all 7 |
| has `HAZ_CONSTITUENT_IND` | **yes** — and only CHEMICALS binds it | no — and METALS does not bind it |
| has `PCT_MEASURE` | yes | yes |
| **bound columns present** | **7 of 7 real** | **5 of 5 real** |
| **absent** | none | none |

The `HAZ_CONSTITUENT_IND` split is the part that makes this more than a name match:
the CHEMICALS block binds it, the METALS block does not, and the two tables differ
in exactly that column. That is not a coincidence between unrelated objects.

The live catalogue holds no other candidate — `GET /odata?db=CORP` filtered for
`CHEMICAL|METAL` returns only these two plus their `_A` audit twins and
`AT_INV_METAL_MOVEMENTS`, which shares none of the marker columns.

## 3. `RETURN_BTN` is not a column

`ItemType = Push Button`, `DatabaseItem = true`, `Column = RETURN_BTN`. A button
bound to a column that does not exist anywhere. This is a pattern, not a one-off:
**465 of the 631 bindings we once reported as "columns that do not exist" are push
buttons marked as database items.** Ignore it; it is not part of either contract.

## 4. Verify it yourself

Every real bound column, live:

```http
GET /odata/AT_BARCODE_CHEMICALS?db=BCTN&$top=2
  &$select=LT_CONCENTRATION,CONCENTRATION_AMT,MEASURED_UNIT_CD_ID,HAZ_CONSTITUENT_IND,PCT_MEASURE,EL_SEQ_ID,CNTNR_SEQ_ID

GET /odata/AT_BARCODE_METALS?db=BCTN&$top=2
  &$select=LT_CONCENTRATION,CONCENTRATION_AMT,MEASURED_UNIT_CD_ID,EL_SEQ_ID,CNTNR_SEQ_ID
```

Both return **200** today. We ran them.

To disprove the conclusion, either of these would do it:

```sql
-- does a view by the name the form uses exist anywhere?
SELECT owner, view_name FROM all_views
 WHERE view_name IN ('AT_CNTNR_CHEMICALS_VW','AT_CNTNR_METALS_VW');

-- if it does, what does it select from?
SELECT owner, view_name, text FROM all_views
 WHERE view_name LIKE 'AT_CNTNR_%_VW';

-- is there a synonym pointing somewhere we have not looked?
SELECT * FROM all_synonyms
 WHERE synonym_name IN ('AT_CNTNR_CHEMICALS_VW','AT_CNTNR_METALS_VW');
```

If a view does exist and selects from something other than these two tables, we are
wrong and we would like to know. **If it returns no rows, the form names an object
that was dropped and the base tables are what it has been reading — the same shape
as `AT_OVERPACK_MASTERS`.**

## 5. One thing that is true and is not a problem

**Both tables are empty on all seven DEV instances** — `$count=true` returns 0 on
CORP, BCTN, BASC, BRON, CLUT, EWTN and MEMTN.

That is worth stating plainly so nobody later reads it as a failure. It means the
screen cannot be exercised with data here, not that the contract is wrong. We have
the same situation on `AT_BARCODE_CHEMICALS.CNTNR_CHEMICAL_SEQ_ID` and
`AT_BARCODE_METALS.CNTNR_METAL_SEQ_ID` — the two sequence-map entries your own
verifier reports as **UNPROVEN, empty on every instance**. Same two tables. They
will move to proven together, the first time anything writes a chemicals or metals
row.

## 6. Where the 54 now stand

| Group | Count | Status |
|---|---:|---|
| `TA_*` | 20 | needs an access decision. Yours to action once somebody decides. |
| `DOC_CTRL.*` | 11 | schema not present in DEV. Needs finding, not fixing. |
| our parser artefacts | 6 | ours, closed |
| overpack base tables | 2 | not real, use the `_VIEW`s — you confirmed |
| Oracle dictionary | 3 | deliberately not exposed |
| **AT5170 views** | **2** | **not real, use the base tables — closed by this document** |
| remaining inline-SQL references | 10 | no screen blocked; listed in REPLY-12, no action |

**Nothing on the list is waiting on the API side.** Two items are waiting on a
person, and neither is a code change.
