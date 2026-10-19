# Answers to Q1–Q8, and one thing to settle between us

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-09-23
**Answering:** `docs/API-HANDOFF-Phase1-Gaps-REPLY.md`

All six landed, and the section 3 decision is better than what we proposed —
checking whether a unique key actually covered the ground, finding it covered 8
of 27, and rejecting our option on evidence is exactly right. Filter-addressed
writes with a one-row guarantee inside the transaction is the rule we will build
against.

Every answer below is measured from the JDAPI dumps of all 161 forms. Where we
could not establish something we say so rather than guessing.

---

## The one thing to settle first: `CAN` vs `BRON`

You renamed `CAN` to `BRON`. Our `schema-drift.json` says `CAN` because that is
what the deployed API returned, and `/odata/instances` still serves `CAN` today.

Worth knowing: **Newt's catalogue said `BRON` and we overruled it** on the
grounds that the live API was more current. If `BRON` is right, Newt was right
and we were wrong, which is fine — but the instance code is user-visible in the
site picker, so we would like it confirmed by someone who knows the site rather
than settled between the two of us. Until then we will follow whatever
`/odata/instances` returns after your deploy, and we will re-measure the drift
map then.

---

## Q1 — the 8 sequence-fed columns on tables with no primary key

**Four are safe. `WB_BATCH_HEADERS.BATCH_SEQ_ID` is not.** Counting every write
to each column across all 161 modules:

| Column | From its sequence | Other `:=` | In an `INSERT` column list | In an `UPDATE … SET` | Verdict |
|---|---:|---:|---:|---:|---|
| `AT_BARCODE_HAZ_WASTE_CODES.CNTNR_HAZ_SEQ_ID` | 3 | 0 | 0 | 0 | **allocate** |
| `AT_BARCODE_UHC_CODES.CNTNR_UHC_SEQ_ID` | 3 | 0 | 0 | 0 | **allocate** |
| `AT_UHC_HAZ.UHC_HAZ_SEQ_ID` | 1 | 0 | 0 | 0 | **allocate** |
| `AT_WASTE_STREAM_ANALYSIS_ITEMS.WSCMPANLITM_SEQ_ID` | 1 | 1 | 0 | 0 | **allocate** — see note |
| `WB_BATCH_HEADERS.BATCH_SEQ_ID` | 36 | 33 | 9 | 34 | **keep excluded** |

So yes, please allocate on the column name rather than on "is the declared
primary key" — for the first four. For those, the sequence is the only thing that
ever writes the column: no other assignment, never in an `INSERT` column list,
never in an `UPDATE … SET`.

`BATCH_SEQ_ID` is the opposite and your instinct to exclude it was right. It is
assigned from somewhere other than the sequence 33 times, appears in 9 explicit
`INSERT` column lists and is **updated after insert 34 times**. It is a key that
gets carried between rows, not allocated per row. Auto-assigning it would be the
silent collision you were avoiding.

The one note: `AT_WASTE_STREAM_ANALYSIS_ITEMS` has a single other assignment, in
AT5331, `:= :GLOBAL.CG$TEMP_0` — a Designer temp holding a value read a few lines
earlier. It is a copy of the same allocation, not a second allocator. We are
confident, but it is one line of evidence rather than none, so flagging it.

---

## Q2 — the overpack views: yes, the forms really do insert through them

AT4220, AT4225 and AT4230 have **no `ON-INSERT`, `ON-UPDATE` or `ON-DELETE`
triggers at all** on `OVERPACK_MASTER` or `OVERPACK_DETAIL`. They have only
`PRE-INSERT` and `PRE-UPDATE`, which set values and then let Forms do its own
DML.

That settles the question from our side: Forms is issuing an ordinary
`INSERT`/`UPDATE` against `AT_OVERPACK_MASTERS_VIEW` and
`AT_OVERPACK_DETAILS_VIEW` and it works in production today. So those views are
writable in Oracle — either key-preserving or carrying `INSTEAD OF` triggers. We
cannot tell which from outside; the dictionary query is:

```sql
SELECT trigger_name, table_name, trigger_type FROM all_triggers
 WHERE table_name IN ('AT_OVERPACK_MASTERS_VIEW','AT_OVERPACK_DETAILS_VIEW');
```

**Please do allow writes to named views rather than the whole category** — and
see Q8, because this is not two views, it is twenty.

---

## Q3 — yes. 11 of the 14 cross-database screens write on both sides

This is the answer that changes the design, so here is the whole list:

| Screen | CORP blocks written | Site blocks written |
|---|---:|---:|
| AT1330 | 6 | 7 |
| AT3110 | 2 | 19 |
| AT3111 | 1 | 17 |
| AT3310 | 1 | 17 |
| WB1000 | 4 | 10 |
| AT9106 | 6 | 1 |
| AT3212 | 1 | 4 |
| AT7200 | 1 | 3 |
| AT1420 | 2 | 1 |
| AT5161 | 1 | 2 |
| AT5160 | 1 | 1 |
| AT1410 | 8 | 0 | *(CORP only — no conflict)* |
| AT5312 | 0 | 4 | *(site only — no conflict)* |
| AT3220 | 0 | 0 | *(read-only — no conflict)* |

The CORP side is usually small and usually **master data being maintained
incidentally**: AT3110 and AT3111 write one or two profile/carrier rows while
writing 17–19 site rows. AT9106 is the inverse.

Our proposal, which we would rather agree than discover: **order the change sets
so the CORP half commits first and the site half second.** CORP rows are master
data that can exist without the site rows referencing them — an orphaned carrier
or profile row is inert and correctable. A site row pointing at a CORP row that
was never created is not. If the site half fails, the CORP half is a recoverable
leftover; the reverse is a broken reference.

Two we would like you to look at rather than accept: **AT1330 (6 CORP writes)**
is the waste-profile screen and per Q8/section 8 those blocks are CustomerPortal
views we probably should not be writing at all — if that resolves to read-only,
AT1330 stops being a cross-database write. **AT9106 (6 CORP, 1 site)** is mostly
CORP with one site row and may be better modelled as a CORP screen.

---

## Q4 — yes, please add optimistic concurrency

We want it, and we would take it now rather than retrofitted.

The legacy app held row locks: Forms locks a row on first keystroke and the
second user gets *"unable to reserve record for update"* immediately. Two of the
161 forms even define their own `ON-LOCK` trigger. So the behaviour our users are
trained on is **"you cannot edit what someone else is editing"**, and silent
last-write-wins is not a smaller version of that — it is the opposite, and the
loss is invisible to both people.

`If-Match` on `MODIFIED_DT` is the right shape. Two asks:

- Make the rejection distinguishable from every other 4xx, with its own code, so
  we can show the user *"someone else changed this while you were editing"*
  rather than a generic failure. The legacy wording is a reservation message, not
  an error, and we want to stay close to it.
- Return the current row with the rejection if that is cheap, so we can show what
  changed instead of making them re-query.

Where a table has no `MODIFIED_DT`, we would rather have no check than a
different check — tell us which tables those are and we will treat them as
known-unsafe rather than assume they are covered.

---

## Q5 — 15. Genuine arithmetic is rare; `NVL` is the one worth having

Every aggregate call across the 161 modules, by what is inside the parentheses:

| Inside the aggregate | Count | Status |
|---|---:|---|
| a bare column | 1,012 | works today |
| `DISTINCT col` | 8 | `countdistinct` |
| **`NVL(col, default)` and nothing else** | **126** | one function |
| arithmetic (`a * b`, `a - b`) | 15 | |
| `CASE WHEN` | **0** | nothing to do |
| another nested function (mostly `TO_CHAR`) | 239 | mostly display formatting |

**Supporting `NVL` inside an aggregate is worth more than everything else
combined** — 126 sites, and it is one function with obvious semantics.

Genuine arithmetic is 15 sites and only two distinct shapes:
`SUM(activity_pct * 100)` in AT4120/AT4150/AT4151, and
`SUM(NVL(full_wt,0) - NVL(empty_wgt,0))` in WB3000/WB3200. Both can be computed
client-side from two aggregates if you would rather not build expression support.
**We would not spend the work.**

The 239 nested-function cases are nearly all `MAX(TO_CHAR(date, 'mask'))`, which
is formatting applied to an aggregate rather than aggregation over an expression —
`MAX(date)` then format on our side. No API work needed.

---

## Q6 — they look global, with one caveat we cannot close

We searched all 161 modules for per-parent line numbering — the `MAX(x)+1`
pattern — and found **three instances in the entire application**:
`max(customer_nbr)+1` in AT1310, and `MAX(SEQUENCE)+1` in WB3100 and WB3200.

**None of them is on the four compound-key tables you asked about.** On the
evidence we have, those sequences are global allocators and you can allocate the
sequence-fed component once we send the rest of the key.

The caveat: absence of the pattern in the form is not proof that nothing computes
a line number, because it could be happening inside a database package we cannot
read the body of. It is good evidence, not a guarantee. If you would rather have
certainty than our confidence here, a `SELECT` on each of those tables comparing
`COUNT(*)` to `COUNT(DISTINCT seq_col)` settles it in one query.

---

## Q7 — the batch pattern fits, but not for every case

Your example is right for the common path, and we will use it.

It is **not** right for all of them: `AT_CONTACTS` and `AT_CONTRACTS` both have an
address block that can point at an existing address. AT1310 (Maintain Customer
Information) has separate blocks for customer, contact and address, and the LOVs
on the address fields exist precisely so a user can pick one already on file.

So we need both paths, and which one applies is a runtime decision by the user,
not a property of the screen:

- new address → your change set, `$1.ADDR_SEQ_ID`
- existing address → a plain `POST` of the contact with `ADDR_SEQ_ID` already set

Nothing needed from you — you already said an explicitly supplied key is used as
given, which is exactly what the second path needs. Flagging it so the exclusion
is not later read as "these are always created together".

`WB_IBOX_DETAILS.DAUGHTER_CNTNR_SEQ_ID` and `WB_QTB_CONTAINERS.QTB_CNTNR_SEQ_ID`
we have not traced to the same confidence. Treat those two as unconfirmed.

---

## Q8 — 27 view tables, and you are right that it is one question

All 27 are views, so it is the `INSTEAD OF` question from Q2, not eight problems.
The CP group is 7 of them; here is the rest.

| View | Screens |
|---|---|
| `AT_OVERPACK_MASTERS_VIEW` | AT4220, AT4225, AT4230 |
| `AT_OVERPACK_DETAILS_VIEW` | AT4220, AT4225, AT4230 |
| `AT_CONTAINER_SOURCES_VW` | AT4250 (×2 blocks) |
| `AT_CP_PROF_*_REVIEW` (7 views) | AT1330 |
| `AT_PRCSHTCAT_VIEW` | AT1420 |
| `AT_ORDER_BARCODE_VIEW` | AT1551 |
| `AT_BARCODE_ORDER_VIEW` | AT1552 |
| `AT_RENTAL_CNTNR_SHIPMENTS_VIEW` | AT1710 |
| `AT_OPPORTUNITIES_VIEW` | AT1710 |
| `AT_SHIP_RENTAL_SCHED_VIEW`, `…_VIEW1`, `AT_SHIP_RENTAL_TYP_VIEW` | AT3212 |
| `AT_SHIPMENT_REL_CNTNR_CNVY_V` | AT3310 |
| `AT_BATCH_VW` | AT4151 |
| `AT_CONTAINER_NOTES_VIEW` | AT5170 |
| `AT_COMPOSITE_CONTAINERS_VIEW` | AT5310 |
| `WB_MAN_CUST_VIEW`, `WB_CONT_TYPE_VIEW`, `WB_CONT_NUC_VIEW`, `WB_CONT_MATL_VIEW` | WB1000 |
| `WB_IBOX_VIEW` | WB3400 |

One dictionary query covers all of them:

```sql
SELECT table_name, trigger_name, trigger_type FROM all_triggers
 WHERE trigger_type LIKE 'INSTEAD OF%' AND table_name IN ( … the 27 … );
```

Whatever comes back, **the CP seven should stay read-only regardless** — that is
an ownership decision, not a technical one, and it has not been made yet.

---

## What we will do next on our side

- Re-measure `schema-drift.json`, the sequence map and all 161 `DATA.md` against
  the new build once it is deployed, and drive cross-database routing from
  `availableOn` rather than our static map, as you suggested.
- Switch `DATA.md` generation to emit filter-addressed `PATCH`/`DELETE` with the
  `uniqueKeys` columns where `addressing` is `"filter"`.
- Note in every affected screen that a change set cannot span databases, with the
  CORP-first ordering from Q3 once you have agreed it.

## Noted, not asked about

Your three outstanding items are on our list too. `[Authorize]` being commented
out is the one we would not want to be the last to remember — our sign-in
currently does not verify a password either (`OPEN-10`), so there are two halves
of the same gap and they should probably close together.

---

# Three things you have not been told, added after the answers above

None of these blocks what you have just built. All three change what "phase 2/3"
turns out to be, so better now than in three months.

## A. The LOVs are a whole read surface we never counted — 596 queries

Our earlier numbers counted SQL in trigger and program-unit PL/SQL. **They missed
the LOVs entirely**, because a list-of-values query lives in a `RecordGroupQuery`
property, not in any code.

| | |
|---|---:|
| record groups across 161 forms | 809 |
| static (no query) | 29 |
| **distinct queries** | **596** |
| shared by more than one form | 97 |

Every one of these backs a picker. 665 of the app's rendered fields are
`AutoComplete` components, and none of them works until its record-group query
runs somewhere.

Against what standard OData can express:

| Shape | Distinct | Servable |
|---|---:|---|
| single table | 316 | `$filter` / `$select` |
| joined | 67 | `$expand`, where a relationship exists |
| function in the select list | 64 | no |
| subquery | 63 | no |
| **`UNION`** | **45** | **no — OData has no form for it at all** |
| aggregate / `DISTINCT` | 41 | `$apply` |

**316 of 596 are ordinary single-table lookups** and will just work. About 280
will not, and `UNION` is the hard one — there is no `$apply` transformation, no
`$filter` spelling, nothing. Those 45 are the clearest case yet for the named
parameterised query catalogue we both agreed was the phase 2/3 answer; we now
have a concrete first population for it rather than an abstraction.

No action requested. We wanted the number on the table before anyone sizes
phase 2.

## B. Block `WHERE` clauses mostly do not translate to `$filter`

We have been telling you a block's `WHERE` becomes a `$filter`. Having now looked
at all of them, that is true for a minority:

| Of 140 blocks with a `WHERE` | Count |
|---|---:|
| simple comparisons — translates directly | **23** |
| references a bind variable | 32 |
| contains a subquery | 34 |
| calls a function (`NVL`, `TRUNC`, `TO_DATE`, `DECODE`, …) | 18 |
| `LIKE` / `IN (list)` | 7 |
| other | 26 |

Examples of what the rest look like:

```sql
COMNT_SEQ_ID = (SELECT MAX(COMNT_SEQ_ID) FROM AT_COMMENT_INSTRUCTIONS WHERE …)
cntrct_mod_cntrct_id = get_max_mod4@atcorp.energysolutions.com(cntrct_contract_nbr)
invc_seq_id in (select invc_seq_id from at_invoice_line_items where advnotif_seq_id = …)
upper(username) = USER
```

This is **our** translation problem, not an API gap, and we will handle the bind
variables and the simple cases. We are telling you because the `DATA.md` files we
sent print these as `$filter` values with a note to translate them, and we would
rather you knew that note is doing more work than it looks like. It also means
the subquery cases join the same phase 2/3 population as the LOVs above.

One specific: **`upper(username) = USER` in AT0000**. Oracle's `USER` is now your
shared `accutrack` account, not the person. Any query filtering on `USER` silently
matches the wrong thing. It is only 4 sites app-wide, but one of them is the
sign-in screen, so we are flagging it rather than filing it.

## C. The legacy app crosses CORP and site with database links

This is the one we think you will most want to know, because it bears directly on
`ChangeSetSpansDatabases`.

**54 references to an Oracle database link, across 13 forms**, reaching 22
distinct objects — all of them pointing at CORP from a daughter:

| Form | Refs | | Object reached over the link | Refs |
|---|---:|---|---|---:|
| AT3310 | 15 | | `AT_CORP_SHIPMENT_RECORDS@atcorp…` | 9 |
| AT1510, AT5510 | 7 each | | `AT_CORP_CUST_SITES@atcorp…` | 5 |
| AT3110, WB1000, WB1100, WB4000 | 4 each | | `AT_RELEASE_TYPES@atcorp…` | 5 |
| AT3111, AT4120, DOC_CTRL | 2 each | | `GET_MAX_MOD4@atcorp…` | 4 |
| AT4151, AT7100, TA1000 | 1 each | | `VALIDATE_SEG_CUSTNBR@atcorp…` | 3 |

(Some hits are email addresses in comments; the `@atcorp` ones are real.)

Three consequences:

1. **Your restriction is correct, and the legacy app simply does not have it.**
   Forms reaches CORP from a site session inside one SQL statement, in one
   transaction, because Oracle resolves the link. We cannot reproduce that over
   two HTTP calls, and no API design fixes it — it is a property of the
   connection model. The CORP-first ordering we proposed in Q3 is a mitigation,
   not an equivalent.
2. **`NEXTVAL@atcorp.energysolutions.com` appears twice.** A daughter form
   allocates a **CORP** sequence over the link. If either of those columns is in
   your sequence map, the allocation has to happen against `?db=CORP` even though
   the row is being inserted into a site database. We have not yet worked out
   which columns those are — we will, and we will tell you.
3. **The links already exist in Oracle.** If a phase 2/3 named query is issued
   against a daughter instance, it can reach CORP by link the same way the form
   does, without the API holding two connections. That may be the cleanest answer
   for the cross-database reads, and it needs no new database object — the links
   are already there. Worth keeping in mind before anything more elaborate is
   designed.

## D. Small: 631 columns the forms bind that exist in no table

Not an API problem, and it does not need an answer — recorded so you do not
re-derive it if you see it.

631 items across the app have `DatabaseItem = true` with a `Column` that exists in
no table on any instance. AT1330 alone has 70 (`LICENSE_CONDITION_GROUP_2`
through `_12`, `WASTE_TYPE_DESCR_2` through `_12`). We checked every cached
schema: the columns are nowhere.

**Your metadata is right and the forms are wrong.** We mention it only because it
was the single largest category of "the API cannot serve this" in our own
generated output, and it turned out to be entirely a legacy-form defect. It is
handled on our side.
