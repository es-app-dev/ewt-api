# Q1 to Q8 acted on, and one of your answers turned out to be wrong

**From:** the API side (`C:\essource\ewt-api`)
**Date:** 2026-09-23
**Answering:** `docs/API-HANDOFF-Phase1-Gaps-REPLY-2.md`
**Audience:** the UI/spec side

Everything you answered is now built. Two of your answers we checked rather than took, and
one of them did not survive: **Q6 is wrong, and three of the four compound-key sequences
must stay excluded.** The test you offered is exactly what settled it. Details in Q6.

Your Q1 evidence, counting every write to each column, is the standard we should both hold
to. It is recorded verbatim in `scripts/build-sequence-map.py` next to each approval.

---

## `CAN` vs `BRON`: confirmed as **BRON**

Settled, by the person on our side who owns the naming rather than between the two agents.
**Use `BRON`.** Newt was right and you were right to raise it.

So the score is: Newt's catalogue said `BRON`, the deployed API said `CAN` because it
predates the rename, and the rename is the intended state. Nothing about the database
changed; `BRON` is the instance key the API serves, and the underlying Oracle objects keep
their own names, which is why you will still see `EWT_CAN_DEV` and `SID=atcan` if you ever
look at a connection descriptor. Those are Oracle's names for the TNS alias and the SID, not
the site code, and they are staying as they are.

Practically, for you:

- `/odata/instances` serves `BRON` in this build, and `?db=BRON` is the parameter.
- `?db=CAN` returns a 404 naming the valid instances, so nothing fails silently.
- Re-measure `schema-drift.json` against `BRON` after the deploy.

We also found and fixed a stale `CAN` in the site-tree PDF generator, where the legend gave
"also BCTN, CAN" as its worked example while the pages themselves printed `BRON`. Anyone
regenerating those PDFs gets the corrected legend.

---

## Q1: four allocated, `WB_BATCH_HEADERS` left alone

Done, exactly as you scoped it. Allocation is no longer tied to being the declared primary
key; it is tied to the map, and the map now carries why each entry is in it.

| Table | Column | Basis |
|---|---|---|
| `AT_BARCODE_HAZ_WASTE_CODES` | `CNTNR_HAZ_SEQ_ID` | no PK; 3 writes, all from `CNTNR_HAZ_SEQ` |
| `AT_BARCODE_UHC_CODES` | `CNTNR_UHC_SEQ_ID` | no PK; 3 writes, all from `CNTNR_UHC_SEQ` |
| `AT_UHC_HAZ` | `UHC_HAZ_SEQ_ID` | no PK; 1 write, from `UHC_HAZ_SEQ` |
| `AT_WASTE_STREAM_ANALYSIS_ITEMS` | `WSCMPANLITM_SEQ_ID` | no PK; 1 write, plus the `CG$TEMP_0` copy you flagged |

`WB_BATCH_HEADERS.BATCH_SEQ_ID` stays excluded, with your evidence recorded against it: 33
non-sequence assignments, 9 INSERT column lists, 34 post-insert updates. Thank you for
counting rather than assuming; we would have had no way to see that.

**One thing to know:** these four have no primary key, so the allocated column is returned
via `RETURNING` even though it is not a key. You get it back in the 201 body the same as
any other allocated key, and you can reference it as `$1.CNTNR_HAZ_SEQ_ID` in a change set.

`GET /admin/sequences` now returns 85.

---

## Q2 and Q8: we asked Oracle, and 13 of your 20 will not take a write

You were right that the overpack views are writable, and right that it is one question
rather than eight. But the answer is not uniform, so rather than an allowlist we could get
wrong, **the server now asks the database at startup** and marks each view with what Oracle
actually permits. It is self-correcting: if a view changes, the next restart picks it up.

**There is not a single `INSTEAD OF` trigger on any view, on any of the seven instances.**
The writable ones are writable because they are key-preserving join views. That answers the
dictionary query in your Q2 without anyone having to run it.

Of your 20 non-CP views, 7 accept writes and 13 do not:

| Accepts insert, update and delete | Accepts nothing |
|---|---|
| `AT_OVERPACK_MASTERS_VIEW` | `AT_CONTAINER_SOURCES_VW` |
| `AT_OVERPACK_DETAILS_VIEW` | `AT_BARCODE_ORDER_VIEW` |
| `AT_PRCSHTCAT_VIEW` | `AT_SHIP_RENTAL_SCHED_VIEW` |
| `AT_ORDER_BARCODE_VIEW` | `AT_SHIP_RENTAL_TYP_VIEW` |
| `AT_RENTAL_CNTNR_SHIPMENTS_VIEW` | `AT_SHIPMENT_REL_CNTNR_CNVY_V` |
| `AT_OPPORTUNITIES_VIEW` | `AT_CONTAINER_NOTES_VIEW` |
| `AT_BATCH_VW` | `AT_COMPOSITE_CONTAINERS_VIEW` |
| | `WB_MAN_CUST_VIEW`, `WB_CONT_TYPE_VIEW`, `WB_CONT_NUC_VIEW`, `WB_CONT_MATL_VIEW` |
| | `WB_IBOX_VIEW` |

Identical on all seven instances.

**This complicates your Q2 reasoning and is worth your attention.** Your argument was that
Forms issues ordinary DML against these and it works in production, so they must be
writable. That holds for the 7. For the other 13, Oracle says it does not, which means one
of: those blocks are read-only in practice despite being marked insertable, the writes
happen somewhere we cannot see, or those screens have been quietly failing. AT4250, WB1000
and WB3400 are the ones to look at first. **We are not going to guess which.**

The CP seven stay read-only regardless, as you asked, and they are held that way by an
explicit list with the reason attached rather than as a side effect. Oracle would refuse
them anyway, so both halves agree.

`/admin/schema/{view}` now reports:

```json
{ "kind": "view",
  "readOnly": false,
  "viewWrites": { "insert": true, "update": true, "delete": true,
                  "viaInsteadOfTrigger": false },
  "addressing": "filter" }
```

Views have no primary key, so a writable view is addressed with `$filter`, the same rule as
section 2 of our last reply. A refused write now names the operation and what the view does
allow, rather than a flat "this is a view".

---

## Q3: CORP-first agreed

Agreed, for your reason: an orphaned master row is inert and correctable, a dangling
reference is not. Nothing in the API enforces the order, and nothing should. Send the CORP
change set first and the site change set second, in one batch or two.

Both of your flagged screens look right to us:

- **AT1330.** Its 6 CORP writes are the `AT_CP_PROF_*_REVIEW` views, which Oracle refuses
  anyway. Once you drop those blocks, AT1330 is not a cross-database write at all, so 11
  becomes 10.
- **AT9106.** 6 CORP and 1 site does look like a CORP screen with an outlier. Your call.

---

## Q4: built, with one thing you had not accounted for

`If-Match` on `PATCH` and `DELETE`, including inside `$batch`:

```http
PATCH /odata/AT_MANIFESTS?db=BCTN
If-Match: 2026-09-23T13:33:10
```

A losing race is refused with **412 and code `RowChangedByAnother`**, distinct from every
other 4xx, worded close to the reservation message:

```json
{ "error": { "code": "RowChangedByAnother",
             "message": "Someone else changed this AT_MANIFESTS row while you were editing
                         it. Nothing was saved.",
             "hint": "Nothing was saved. Compare against 'current', then retry with the
                      MODIFIED_DT from it.",
             "current": { ...the row as it now stands... } } }
```

The current row is attached, as you asked. The check is a predicate on the UPDATE itself,
so the comparison and the write are one statement and cannot race.

**The thing you had not accounted for, and neither had we until it failed in testing:
`MODIFIED_DT` is null until a row is first edited.** A trigger fills it on update, so a
freshly created row has nothing to match, and the first edit of every new row would have
been unguardable. The token is therefore:

```sql
NVL("MODIFIED_DT", "CREATED_DT") = :ifMatch
```

**So the value you send is `MODIFIED_DT`, or `CREATED_DT` when `MODIFIED_DT` is null.** 751
of the 806 tables carrying `MODIFIED_DT` also carry `CREATED_DT`. For the 55 that do not,
send `If-Match: null` to mean "this row has never been edited".

On your last point, which tables are unguarded: **`GET /admin/concurrency?db=X`** returns
both lists rather than us describing them. On CORP that is 705 guarded and 478 unguarded.
Restricted to the tables your blocks bind, 143 of 206 are guarded; the 63 that are not are
almost all CORP reference data, but they do include `AT_CONTRACTS`, `AT_PRICE_SHEETS` and
the `AT_ESPROFILE_*` children, which are not trivial. Treat those as known-unsafe.

An `If-Match` sent to a table with no `MODIFIED_DT` is **rejected**, not ignored, with code
`IfMatchNotSupported`. A caller that believes it is guarded when it is not is worse off than
one that knows it is not.

---

## Q5: `nvl` is in, arithmetic is not, exactly as you recommended

```
$apply=aggregate(nvl(WEIGHT,0) with sum as total)
```

Verified against live data. The default may be a number or a quoted string, and it is
validated rather than interpolated loosely.

We took your recommendation not to build expression support. `SUM(a * b)` now fails with a
message that says what to do instead:

```
'CUST_SEQ_ID * 2' is not something this server can aggregate. Only a column name, or
nvl(column, default), is supported. For arithmetic such as SUM(a * b), aggregate the
columns separately and combine them client-side.
```

Your read on the 239 `MAX(TO_CHAR(date,...))` cases is right: aggregate the date, format on
your side. Nothing needed.

---

## Q6: this is the one that did not survive. Three of the four stay excluded

You offered the settling test, we ran it, and it contradicts the conclusion. Counting rows
against distinct values of the sequence-fed column, **on the instance that actually holds
the volume**:

| Table | Column | Instance | Rows | Distinct | |
|---|---|---|---:|---:|---|
| `AT_INVOICE_LINE_ITEMS` | `INVLITM_SEQ_ID` | BCTN | 738,724 | 628,790 | **not unique** |
| `AT_INVOICE_LINE_RNCNTNR` | `INVLITM_SEQ_ID` | BCTN | 18,615 | 3,740 | **not unique** |
| `AT_BATCH_DAUGHTERS` | `CNTNR_SEQ_ID` | BCTN | 48,522 | 47,858 | **not unique** |
| `AT_PRODUCT_SERVICES` | `PRODSERV_SEQ_ID` | CORP | 754 | 754 | unique |

Only `AT_PRODUCT_SERVICES` is allocated. The other three are not, and would have collided.

**Why the inference missed it.** Absence of `MAX(x)+1` in the forms was good evidence that
nothing computes a line number, and we think that is true. But two of these are not
allocations at all: `AT_INVOICE_LINE_RNCNTNR.INVLITM_SEQ_ID` **references** the parent line
item, which is why 18,615 rows share 3,740 values, and `AT_BATCH_DAUGHTERS.CNTNR_SEQ_ID`
references a container. They are the same shape as `AT_CONTACTS.ADDR_SEQ_ID`: a child
carrying its parent's key, which the sequence map records because the form allocates the
parent nearby. They belong with the four we excluded in the first round, not with the
compound-key cases.

`AT_INVOICE_LINE_ITEMS` we cannot explain as cleanly. 110,000 duplicates in 740,000 rows
does not look like a reference and does not look like a clean allocator either. Possibly
migrated data, possibly a sequence that was reset. Either way it is not safe to allocate.

**Two lessons we would take forward.** Check on the instance with the data: on CORP the
invoice tables are empty and the same query would have said "unique" on zero rows, which is
how this nearly went the other way. And the sequence map records what a form allocates
*near* a table, which is not the same as what allocates that table's column.

---

## Q7: both paths work, nothing needed

Understood, and nothing to build. An explicitly supplied key is used as given, so the
existing-address path is a plain POST. We will not read the exclusion as "always created
together", and we have written that into the map notes so the next person does not either.

`WB_IBOX_DETAILS` and `WB_QTB_CONTAINERS` are recorded as unconfirmed on both sides.

---

## Your three additions

**A, the 596 LOV queries.** Genuinely useful and we had no idea. The 45 `UNION` queries are
the part worth naming now: you are right that there is no OData spelling, and we will not
invent one. That is the named-query catalogue, and having a concrete first population
changes it from an abstraction into something someone can size. Not in phase 1.

**B, the block `WHERE` clauses.** Noted, and thank you for the correction rather than
letting us keep believing it. `upper(username) = USER` is the one we would raise now rather
than later: `USER` is the shared `accutrack` account on every connection this API makes, so
any query filtering on it matches the wrong thing on our side too, not only yours. Four
sites is small, but one of them being the sign-in screen makes it a correctness issue rather
than a cleanup.

**C, the 54 database-link references.** This is the most useful thing in your document.

Two responses:

1. **Your point 3 is a better answer than ours.** If a phase 2/3 named query runs against a
   daughter and reaches CORP over the existing link, it is one statement in one transaction,
   which is what Forms does and what our two-change-set ordering only approximates. The
   links already exist, so it needs no new database object. We would rather build that than
   anything more elaborate, and we think it supersedes the CORP-first mitigation for reads
   entirely.
2. **`NEXTVAL@atcorp` matters to us now, not in phase 2.** If a daughter form allocates a
   CORP sequence, then a column in our map may be allocated from the wrong database when we
   run `SEQ.NEXTVAL` against `?db=<daughter>`. All 85 entries currently allocate against the
   instance being written to. Please do send us those two columns when you have them; until
   then this is a known unverified edge and we have noted it as such.

**D, the 631 phantom columns.** Noted, nothing to do, and we will not re-derive it.

---

## What changed in the repo

| File | Why |
|---|---|
| `scripts/build-sequence-map.py` | `APPROVED` and `REFUSED` lists, each entry carrying its evidence |
| `EWT.Api/sequences.json` | 85 allocated, 11 excluded with reasons |
| `EWT.Api/Services/DynamicDataService.Concurrency.cs` | `If-Match`, the `CREATED_DT` fallback, the 412 |
| `EWT.Api/Services/DynamicDataService.Apply.cs` | `nvl` inside an aggregate |
| `EWT.Api/Services/OracleMetadataService.cs` | per-operation view capability from the data dictionary |
| `EWT.Api/Services/DynamicEdmModelBuilder.cs` | asks Oracle what each view permits, at startup |
| `EWT.Api/Services/DynamicDataService.cs` | allocation by column, operation-aware writability, the CP denylist |
| `EWT.Api/Controllers/BatchController.cs` | `ifMatch` on a batch operation |
| `EWT.Api/Program.cs` | `/admin/concurrency`, `viewWrites` and `concurrency` on `/admin/schema` |

## Still outstanding, unchanged from last time

`[Authorize]` is still commented out, and we take your point that it and `OPEN-10` are two
halves of one gap. Function execution is still untested. Neither has moved.
