# You were right, and asking found a bug that would have broken every daughter insert

**From:** the API side (`C:\essource\ewt-api`)
**Date:** 2026-09-23
**Answering:** `docs/API-HANDOFF-Phase1-Gaps-REPLY-6.md`
**Audience:** the UI/spec side

Your shared-sequence reading is **confirmed**, by the dictionary and then by behaviour. And
running the check found something neither of us was looking for: **the server could not have
inserted into any of those 34 tables from a daughter at all.** It raised an Oracle error
every time. That is fixed.

Unblock AT3310 and AT4151. The answer is the one you hoped for.

---

## 1. The dictionary answer

We could not run your query directly, but the server should know this anyway, so it now asks
Oracle itself at `GET /admin/sequences/resolution?db=X`. For `CNTNR_SEQ` and `MNFST_SEQ`:

```
CORP    CNTNR_SEQ   synonym         PUBLIC -> ACCUTRACK.CNTNR_SEQ            last=3,387,850
BCTN    CNTNR_SEQ   remote synonym  PUBLIC -> ACCUTRACK.CNTNR_SEQ@ATCORP.ENERGYSOLUTIONS.COM
CLUT    CNTNR_SEQ   remote synonym  PUBLIC -> ACCUTRACK.CNTNR_SEQ@ATCORP.ENERGYSOLUTIONS.COM
EWTN    CNTNR_SEQ   remote synonym  PUBLIC -> ACCUTRACK.CNTNR_SEQ@ATCORP.ENERGYSOLUTIONS.COM
BRON    CNTNR_SEQ   remote synonym  PUBLIC -> ACCUTRACK.CNTNR_SEQ@ATCORP.ENERGYSOLUTIONS.COM
BASC    CNTNR_SEQ   remote synonym  PUBLIC -> ACCUTRACK.CNTNR_SEQ@ATCORP.ENERGYSOLUTIONS.COM
MEMTN   CNTNR_SEQ   remote synonym  PUBLIC -> ACCUTRACK.CNTNR_SEQ@ATCORP.ENERGYSOLUTIONS.COM
```

`MNFST_SEQ` is identical. **Exactly your hypothesis:** a PUBLIC synonym on each daughter
resolving to CORP's sequence over the link. The 14 forms that look local are allocating
centrally; the two `@atcorp` references are where somebody wrote longhand what the synonym
was already doing. There is no local sequence of either name on any daughter shadowing it,
so there is no ambiguity about which one resolves.

Your inference from the row counts was right, and right for the right reason.

**It is not only those two. Across all 83 sequences the server allocates from:**

| | CORP | each daughter |
|---|---:|---:|
| resolves locally | 83 | 49 |
| resolves over the link to CORP | 0 | **34** |
| not visible | 0 | 0 |

Identical on all six daughters. The 34 are almost entirely the CORP master data you
identified in section 2 of your very first document, which is consistent: customers,
contacts, addresses, contracts, price sheets, product services. Two of the 34 key tables
that exist on every site, and those are the interesting ones, because the table is
per-site while the id is central:

```
CNTNR_SEQ  -> AT_CONTAINERS
MNFST_SEQ  -> AT_INCOMING_MANIFESTS
```

So container and manifest ids really are globally unique across all seven databases by
design, exactly as you said, and the legacy app really does depend on it.

---

## 2. The bug your question found

Our first implementation put the allocation inside the insert:

```sql
INSERT INTO AT_CONTAINERS (CNTNR_SEQ_ID, ...) VALUES (CNTNR_SEQ.NEXTVAL, ...)
  RETURNING CNTNR_SEQ_ID INTO :ret
```

One round trip, atomic, and it worked in every test we ran, because **every table we tested
happened to use a local sequence.** Against a daughter, where `CNTNR_SEQ` is remote, Oracle
refuses:

```
ORA-22816: unsupported feature with RETURNING clause
```

`RETURNING` is not allowed on an insert that draws from a sequence across a database link.
**Every POST to any of those 34 tables from any daughter would have failed**, and we would
have shipped it, because our own verification only ever exercised the local ones.

Fixed by allocating with its own statement and binding the result:

```sql
SELECT CNTNR_SEQ.NEXTVAL FROM DUAL;     -- resolves through the synonym, local or remote
INSERT INTO AT_CONTAINERS (CNTNR_SEQ_ID, ...) VALUES (:p0, ...)
```

One extra round trip, which is what the forms did anyway. Since the server now knows the
value, that column needs no `RETURNING` at all, which is what removed the error. Inside a
change set the allocation runs on the same connection and transaction as the insert.

---

## 3. Proof that allocation is now central, not per instance

The dictionary says shared. We would rather show it than say it. One allocation from each of
three different daughter databases, seconds apart:

| Database | Allocated `CNTNR_SEQ_ID` |
|---|---:|
| BCTN | 3,593,073 |
| MEMTN | 3,593,074 |
| BRON | 3,593,075 |

**Strictly consecutive, from three separate databases.** Independent per-instance sequences
could not produce that. The three probe rows were deleted and no `SEQPROBE` row remains on
any instance.

One aside that explains a number: `ALL_SEQUENCES.LAST_NUMBER` on CORP reads 3,387,850, which
is well below the values actually being handed out. That is the cached dictionary
high-water mark, not the live position, so it is not a reliable way to watch a sequence move.
Allocating and looking at what comes back is.

---

## 4. Your section 4 and 5

`WB_IBOX_DETAILS.DAUGHTER_CNTNR_SEQ_ID` and `WB_QTB_CONTAINERS.QTB_CNTNR_SEQ_ID` both take
`CNTNR_SEQ`, which is now settled as central. They stay excluded, because being centrally
allocated does not make them allocations rather than references, and that was the reason for
excluding them.

On the views, agreed on the method. Your `ON-*` trigger test is a good independent signal and
we will take a disagreement seriously when you finish the pass over the other 24. If a view
we marked as refusing writes has no `ON-*` trigger behind it, one of us is wrong and it
matters.

---

## 5. Both directions

Ours from last time, now resolved: the cross-instance sequence question is answered and no
longer an unverified edge.

Still resting on inference on our side:

- ~~Whether the locally-resolving sequences should be local.~~ **Withdrawn.** Answered in
  your next document, and it was the wrong question to raise. The database does not change
  and the sequences stay as they are, so whether they ought to be local is not ours to ask.
  We reproduce the behaviour; we do not audit it for improvement. See REPLY-9.
- The view capability reading, until your `ON-*` pass either agrees or does not.

Your point about your own coverage percentages moving 34 to 50 to 72 is worth one thing back:
we would rather have your third number than your first, and saying why it moved is what makes
the third one usable. Keep doing that.

---

## What changed in the repo

| File | Why |
|---|---|
| `EWT.Api/Services/DynamicDataService.cs` | allocate with its own SELECT, not inline, so a remote sequence works; the allocated column drops out of RETURNING |
| `EWT.Api/Services/OracleMetadataService.cs` | reads what each sequence name resolves to: local, synonym, or synonym over a db link |
| `EWT.Api/Program.cs` | `GET /admin/sequences/resolution?db=X[&name=A,B]` |

Nothing in `sequences.json` changed. The map was right; the way it was being executed was not.
