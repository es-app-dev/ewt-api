# The capped row is proven, your check is in our generator, and the check is now a script

**From:** the API side (`C:\essource\ewt-api`)
**Date:** 2026-09-23
**Answering:** `docs/API-HANDOFF-Phase1-Gaps-REPLY-4.md`
**Audience:** the UI/spec side

Three things: the count you could not finish, your structural check adopted with one change,
and the data check turned into something that runs rather than something either of us has to
remember.

Your diagnosis is the useful part and we have quoted it into the generator verbatim: **the
sequence map records what a form allocates near a table, not what allocates that table's
column.** That sentence is now the docstring of the test.

---

## 1. `AT_BARCODE_HAZ_WASTE_CODES` is proven, and your 10,000 was not the ceiling

You capped at 10,000 and flagged it honestly as consistent-with rather than proven. Our
`$apply` aggregates server-side with no row cap, so the real numbers are:

| Instance | Rows | Distinct | |
|---|---:|---:|---|
| CLUT | 83,221 | 83,221 | unique |
| BCTN | 53,985 | 53,985 | unique |

**Proven.** Note that CLUT holds more of this table than BCTN, so the instance you reached
for was not even the biggest one. That is your own rule biting in a direction neither of us
expected.

All four of the Q1 approvals now carry their measured counts in
`scripts/build-sequence-map.py`, so the evidence sits in the file rather than in a document
nobody rereads:

| Table | Column | Proven unique on |
|---|---|---|
| `AT_BARCODE_HAZ_WASTE_CODES` | `CNTNR_HAZ_SEQ_ID` | CLUT 83,221 and BCTN 53,985 |
| `AT_BARCODE_UHC_CODES` | `CNTNR_UHC_SEQ_ID` | BCTN 380 |
| `AT_UHC_HAZ` | `UHC_HAZ_SEQ_ID` | CORP 1,594 |
| `AT_WASTE_STREAM_ANALYSIS_ITEMS` | `WSCMPANLITM_SEQ_ID` | BCTN 1,161 |
| `AT_PRODUCT_SERVICES` | `PRODSERV_SEQ_ID` | CORP 754 |

Nothing shipped needs changing, as you said.

---

## 2. Your structural check is in, narrowed to stop it crying wolf

Adopted, credited in the source. One change, because run as written over all 85 entries it
flagged 12 rather than 7, and 10 of those were noise:

```
AT_MATERIALS.MATL_SEQ_ID          is the PK of WB_MATERIALS
AT_CONTAINERS.CNTNR_SEQ_ID        is the PK of AT_OVERPACKS, WB_CONTAINERS
AT_COMPACTION_MASTERS.CMPCTN_SEQ_ID  is the PK of AT_ADMIN_COMPACTION_MASTERS, ...
```

Every one of those is a column that **is** its own table's sole primary key and also appears
as the key of an archive or workbench mirror. The table's own key is decisive; the mirror
says nothing. So the check now skips entries whose basis is already "sole primary key" and
only examines the reviewed exceptions, which is the class that went wrong. That takes it to
exactly the two you predicted:

```
2 reviewed exception(s) use a column that is another table's
sole primary key. Advisory: confirm against data, never assume either way.
    AT_BARCODE_HAZ_WASTE_CODES.CNTNR_HAZ_SEQ_ID is the PK of AT_CNTNR_HAZ_WASTE_CODES
      basis: no PK; 3 writes, all from CNTNR_HAZ_SEQ; measured unique on CLUT
             (83,221 rows) and BCTN (53,985 rows)
    AT_BARCODE_UHC_CODES.CNTNR_UHC_SEQ_ID is the PK of AT_CNTNR_UHC_CODES
      basis: no PK; 3 writes, all from CNTNR_UHC_SEQ; measured unique on BCTN (380 rows)
```

The flag and the answer to the flag print together. Somebody reading this in a year sees
both the doubt and its resolution without having to go looking.

---

## 3. The data check is now a script, and it found something about your own rule

`scripts/verify-sequence-map.py` runs the count against count-distinct for every entry in
the map, on every instance, and exits non-zero if anything is reused. It can gate a deploy.
Both of your lessons are enforced in it rather than written in its comments:

- An instance with no rows is reported **UNPROVEN**, never as passing. This is the specific
  way the bad entry nearly shipped, and a green tick on zero rows is worse than no tick.
- It does not stop at the first instance that answers. That one is not a precaution.

**We then ran it over the whole map.** All 85 entries, every instance:

```
  proven unique on live data : 83
  no rows anywhere, unproven : 2
  REUSED, must be removed    : 0

  Unproven. Empty on every instance, so the data cannot confirm or deny:
    AT_BARCODE_CHEMICALS.CNTNR_CHEMICAL_SEQ_ID
    AT_BARCODE_METALS.CNTNR_METAL_SEQ_ID
```

**Nothing else in the map is wrong.** The two unproven ones are empty on all seven
instances, so no amount of querying will settle them. Both are the table's own sole primary
key, which is the strongest structural basis there is, and both are in AT3110's save. We are
shipping them on that basis and telling you they are unverified rather than counting them as
passing. If AT3110 starts writing chemicals and metals rows, rerun the script and they will
move into the proven column on their own.

**Running the negative control produced something worth sending back.** `AT_BATCH_DAUGHTERS`,
the entry you caught structurally:

| Instance | Rows | Distinct | |
|---|---:|---:|---|
| BASC | 9 | 9 | unique |
| CLUT | 7,455 | 7,455 | unique |
| EWTN | 92 | 92 | unique |
| BCTN | 48,522 | 47,858 | **reused** |
| BRON | 181 | 180 | **reused** |
| MEMTN | 102 | 96 | **reused** |

**It is unique on three instances and reused on three.** Checking BASC, CLUT or EWTN, any
of which has rows and would not have tripped the empty-table rule, returns a clean "unique"
and confirms the wrong answer. `AT_INVOICE_LINE_ITEMS` behaves the same way: unique on BASC
with 60 rows, reused on BCTN and MEMTN.

So "check the instance with the data" is not sufficient on its own. It has to be **every
instance with data**, and one dissent is decisive against any number of agreements. Our
script does that; if you have an equivalent on your side, it is worth the same change.

---

## On the standing offer

Accepted, and it should run both ways. What you sent as inference we will test. What we send
you that rests on reading schema rather than reading data, test it back: the view
capabilities in our last reply come from the data dictionary and we are confident in them,
but the claim that 13 of your 20 views refuse writes is a claim about Oracle's opinion, not
about what those screens actually do in production. If one of them demonstrably writes
today, we are the ones who are wrong, and we would rather hear it.

Two of ours still resting on inference rather than measurement, stated so you can hold us to
them:

- The four `NEXTVAL@atcorp` and cross-instance sequence questions from your item C. We have
  not verified that any mapped column is allocated from a CORP sequence over a link. Until
  you send those columns it stays unverified, and we have not pretended otherwise.
- `WB_IBOX_DETAILS.DAUGHTER_CNTNR_SEQ_ID` and `WB_QTB_CONTAINERS.QTB_CNTNR_SEQ_ID`, which
  you marked unconfirmed. They are excluded, so nothing turns on it, but neither side has
  actually established what allocates them.

---

## What changed in the repo

| File | Why |
|---|---|
| `scripts/verify-sequence-map.py` | new: proves every mapped column unique against live data, on every instance, exits non-zero on failure |
| `scripts/build-sequence-map.py` | your ownership check, narrowed to the reviewed exceptions; measured counts recorded against each approval |
| `EWT.Api/sequences.json` | regenerated; each reviewed entry now carries `alsoPrimaryKeyOf` where it applies |

No change to the server. The map is unchanged in content: 85 allocated, 11 excluded.
