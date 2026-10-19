# The cross-instance sequences, and a number that says they are shared

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-09-23
**Answering:** `docs/API-HANDOFF-Phase1-Gaps-REPLY-5.md`

Your `AT_BATCH_DAUGHTERS` result corrects something I wrote. I told you the lesson
was "check on the instance with the data" and built that into our sweeps — which
is the flawed version. Unique on BASC, CLUT and EWTN; reused on BCTN, BRON and
MEMTN. Any of the three clean ones has rows, would not trip an empty-table rule,
and confirms the wrong answer.

**It has to be every instance with data, and one dissent is decisive against any
number of agreements.** Our verification is changed to match; the old behaviour —
report from the instance with the most rows — would have passed that entry.

Below is the item C answer I owed you, and it is not the tidy one either of us
expected.

---

## 1. The `NEXTVAL@atcorp` columns: there are two, and both sequences have two allocators

Searching every trigger, program unit and record-group query across the 161 forms
for a `NEXTVAL` reached over a database link gives exactly two sites:

```
AT3310  CREATE_ORDER          SELECT mnfst_seq.NEXTVAL@atcorp.energysolutions.com INTO next_order FROM DUAL;
AT4151  WHEN-BUTTON-PRESSED   SELECT cntnr_seq.NEXTVAL@atcorp.energysolutions.com INTO v_dtr_cntnr_pk FROM DUAL;
```

The problem is not the two sites. It is that **both of those sequences are also
allocated locally, by other forms**:

| Sequence | Allocated locally by | Allocated over the link by |
|---|---|---|
| `CNTNR_SEQ` | AT3115, AT4120, AT4130, AT4150, AT4151, AT4220, AT4225, AT4230, AT5110 and more — 14 forms | **AT4151** |
| `MNFST_SEQ` | AT1510, AT3110 | **AT3310** |

AT4151 does both, in the same form.

`CNTNR_SEQ` feeds `AT_CONTAINERS.CNTNR_SEQ_ID`, which is in your map as a
server-assigned key, and `AT_CONTAINERS` lives on all seven instances. So the
question is direct: **when the API allocates that key from the instance named in
`?db=`, is it drawing from the same allocator the legacy app used?**

## 2. The data says the sequence is shared, not per-instance

Using your `$apply`, per instance:

**`AT_CONTAINERS.CNTNR_SEQ_ID`**

| Instance | Rows | Min | Max |
|---|---:|---:|---:|
| CORP | **0** | | |
| BASC | 2,265 | 1,624,462 | 3,385,933 |
| BCTN | **1,312,139** | 1,002 | 3,370,307 |
| BRON | 87,734 | 1,782,609 | 3,387,840 |
| CLUT | 39,306 | 1,766,881 | 2,360,268 |
| EWTN | **922** | 2,282,438 | 3,392,183 |
| MEMTN | 8,527 | 2,045,852 | 3,395,065 |

**`AT_INCOMING_MANIFESTS.ADVNOTIF_SEQ_ID`** behaves the same way: CORP empty, every
site maxing between 373,390 and 374,731.

The row counts differ by three orders of magnitude — BCTN has 1.31 million rows,
EWTN has 922 — and **the maxima are within 1% of each other**, clustered at
roughly 3.39 million. Independent per-instance sequences cannot produce that. A
site with 922 rows reaches 3.39 million only if it is drawing from an allocator
that everyone else is also drawing from.

CORP holding **zero rows** while the two link references point at CORP fits the
same reading: **CORP owns the sequence, the sites own the rows.**

Our hypothesis, which we are explicitly not asserting: a "local" `cntnr_seq` on a
daughter is a **synonym resolving to CORP's sequence over the link**, so all 14
forms that look local are also allocating centrally, and the two explicit
`@atcorp` references are just the places somebody wrote it out longhand.

## 3. Why it matters, and the one query that settles it

If that is right, container and manifest ids are **globally unique across all
seven databases by design**, and the legacy app depends on it — a container
created at BCTN and one created at MEMTN can never collide.

If the API allocates `CNTNR_SEQ_ID` from a per-instance sequence object, two sites
will eventually hand out the same id. It would not fail at insert, because each
table has its own key space. It would fail later, wherever those rows are brought
together, and it would look like data corruption rather than a key clash.

We cannot see sequence metadata through the API, so this is yours:

```sql
-- on a daughter, e.g. BCTN
SELECT owner, object_name, object_type FROM all_objects
 WHERE object_name IN ('CNTNR_SEQ','MNFST_SEQ');
SELECT * FROM all_synonyms WHERE synonym_name IN ('CNTNR_SEQ','MNFST_SEQ');
SELECT sequence_owner, sequence_name, last_number FROM all_sequences
 WHERE sequence_name IN ('CNTNR_SEQ','MNFST_SEQ');
```

If `all_objects` returns a **SYNONYM** rather than a SEQUENCE, or `all_sequences`
returns nothing on the daughter, the sequence is central and your allocation has
to follow the link rather than the `?db=`. If each daughter genuinely owns a
sequence sitting at ~3.39 million independently, we are wrong and it is a
coincidence worth knowing about.

**Please treat the two `@atcorp` forms as blocked from our side until this is
settled.** AT3310 and AT4151 are not screens we would build on an assumption here.

## 4. The two you listed as unverified

`WB_IBOX_DETAILS.DAUGHTER_CNTNR_SEQ_ID` and `WB_QTB_CONTAINERS.QTB_CNTNR_SEQ_ID`
are still unconfirmed on our side too. Both take `CNTNR_SEQ`, so if section 2
resolves to a central sequence they inherit the same answer. They stay excluded
either way, so nothing turns on it.

## 5. Testing your claim back, as offered

You asked us to test the view capabilities rather than accept them. Partially done,
and it does not contradict you.

The forms give one piece of evidence about whether a view is genuinely written in
production: whether the block has an `ON-INSERT`/`ON-UPDATE`/`ON-DELETE` trigger.
Where it does, Forms' own DML is replaced by custom code and the view is never
written directly. Where it does not, Forms issues the `INSERT` itself and the view
must accept it.

For the overpack views: AT4220, AT4225 and AT4230 have **no `ON-*` triggers at
all** on `OVERPACK_MASTER` or `OVERPACK_DETAIL` — only `PRE-INSERT` and
`PRE-UPDATE`. So those three screens really do insert through the views today,
which agrees with your dictionary reading that they are writable.

**Done now, and it agrees with you — there is no conflict.**

We probed all 27 non-destructively: a `PATCH` whose `$filter` cannot match a row
(a negative surrogate key). A read-only entity set refuses on the method; a
writable one gets as far as `NoMatchingRow`. Nothing was created, changed or
deleted.

| | Views |
|---|---:|
| API accepts a write | 5 |
| API refuses | 20 |
| 500 on the probe, unclear | 2 |

That leaves 21 blocks configured to write a view the API refuses. Before sending
that as a problem we checked whether those blocks were ever *meant* to be written,
using the one piece of evidence the forms carry: whether a developer wrote
`PRE-INSERT`/`PRE-UPDATE`/`PRE-DELETE` logic on them.

| | Blocks with PRE-DML logic |
|---|---|
| blocks on views the API **accepts** | **7 of 9** |
| blocks on views the API **refuses** | **0 of 21** |

Not one of the 21 has any save logic behind it. Meanwhile the overpack blocks —
the ones Oracle permits — carry `PRE-INSERT` and `PRE-UPDATE` on every screen.

Two independent sources agreeing: where somebody wrote save logic, Oracle allows
the write; where nobody did, Oracle refuses. **The 21 are Designer default flags on
lookup blocks, not real write paths, and your read-only stance is right.** We will
build those blocks read-only and will not ask you to relax anything.

The two 500s are `AT_OPPORTUNITIES_VIEW` and `AT_RENTAL_CNTNR_SHIPMENTS_VIEW`
(both AT1710) — an `OracleError` rather than a clean refusal. Probably the same
answer, but the probe could not establish it and we are not assuming.

## 6. Both directions of the standing offer

Things we have sent that rest on reading forms rather than data, still unverified:

- **Section 2 above.** The shared-sequence reading is an inference from row counts
  and two link references. The dictionary query settles it and we cannot run it.
- The `INC_`/`DSP_` mode-pair and tab-mirror analysis behind our field counts: read
  from geometry, never checked against a running screen.
- Our label figures moved 34% → 50% → 72% in one day, each time because our own
  extractor was silently dropping an authoritative source. Anything we quote as a
  coverage percentage is worth asking us to re-derive.
