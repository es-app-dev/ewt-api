# Q6 was wrong, and the check that would have caught it

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-09-23
**Answering:** `docs/API-HANDOFF-Phase1-Gaps-REPLY-3.md`

You were right to run the test rather than take the answer. Three of the four
compound-key sequences are not allocators and I said they were.

The diagnosis is the part worth keeping: **the sequence map records what a form
allocates *near* a table, not what allocates that table's column.** I had already
made that distinction correctly in Q1 — `AT_CONTACTS.ADDR_SEQ_ID` is a child
carrying its parent's key — and then failed to recognise the identical shape when
it arrived labelled "compound key". Same pattern, different heading, missed.

## The structural check, now in the generator

Rather than re-answer, here is a test that catches the class without needing row
counts. For each entry, ask whether the column is **this** table's own sole
primary key, or **another** table's:

| | Entries |
|---|---:|
| the column is this table's own sole PK | 80 |
| **the column is another table's PK — a reference** | **7** |
| the column is no table's sole PK | 9 |

The seven it flags:

```
AT_BATCH_DAUGHTERS.CNTNR_SEQ_ID        -> PK of AT_CONTAINERS, AT_OVERPACKS
AT_CONTACTS.ADDR_SEQ_ID                -> PK of AT_ADDRESSES
AT_CONTRACTS.ADDR_SEQ_ID               -> PK of AT_ADDRESSES
WB_BATCH_HEADERS.BATCH_SEQ_ID          -> PK of AT_BATCH_HEADERS
AT_OVERPACK_MASTERS_VIEW.CNTNR_SEQ_ID  -> PK of AT_CONTAINERS, AT_OVERPACKS
AT_BARCODE_HAZ_WASTE_CODES.CNTNR_HAZ_SEQ_ID -> PK of AT_CNTNR_HAZ_WASTE_CODES
AT_BARCODE_UHC_CODES.CNTNR_UHC_SEQ_ID       -> PK of AT_CNTNR_UHC_CODES
```

It catches **`AT_BATCH_DAUGHTERS` and `WB_BATCH_HEADERS` mechanically**, and the
two `ADDR_SEQ_ID` cases we had already excluded — the whole family, from schema
alone. It does not catch `AT_INVOICE_LINE_ITEMS`, which you were right to call
unexplainable; nothing structural distinguishes it and only the row count did.

## But it also flags two you have just shipped — and those are fine

The last two rows are `AT_BARCODE_HAZ_WASTE_CODES` and `AT_BARCODE_UHC_CODES`,
which you built in Q1 on my evidence. Before reporting that as a problem I ran
your test against live data, on the instance holding the volume:

| Table | Column | Instance | Rows | Distinct | |
|---|---|---|---:|---:|---|
| `AT_BARCODE_HAZ_WASTE_CODES` | `CNTNR_HAZ_SEQ_ID` | BCTN | 10,000+ | 10,000+ | unique |
| `AT_BARCODE_UHC_CODES` | `CNTNR_UHC_SEQ_ID` | BCTN | 380 | 380 | unique |
| `AT_UHC_HAZ` | `UHC_HAZ_SEQ_ID` | CORP | 1,594 | 1,594 | unique |
| `AT_WASTE_STREAM_ANALYSIS_ITEMS` | `WSCMPANLITM_SEQ_ID` | BCTN | 1,161 | 1,161 | unique |

**All four hold. Nothing you shipped needs changing.** The two flags are false
positives caused by `AT_CNTNR_HAZ_WASTE_CODES` and `AT_CNTNR_UHC_CODES` — older
duplicate tables carrying the same column as their key. This database has a lot of
those, so the structural check over-reports and has to be read as "look here",
never as a verdict.

**One caveat on the first row, stated rather than buried:** the query capped at
10,000 and returned exactly 10,000 distinct values, so that table is *consistent
with* unique but not proven. If you want it proven, a `COUNT(*)` against
`COUNT(DISTINCT CNTNR_HAZ_SEQ_ID)` on BCTN settles it, and you can run that where
we cannot.

## Both your lessons are now in our tooling

- **Check on the instance with the data.** Our verification sweeps every instance
  and reports from the one with the most rows, rather than from CORP because it
  happens to be first. Your point that CORP would have said "unique on zero rows"
  is exactly how this nearly went the other way, and it applies to anything we
  measure, not just sequences.
- **Allocated near ≠ allocates this column.** Every future sequence-map entry
  carries the ownership classification above alongside the write counts, so the
  two kinds of evidence sit next to each other instead of one being mistaken for
  the other.

## Standing offer

Any inference we send that rests on reading the forms rather than reading the
data, we would rather you test than accept — as you did here. We will keep
marking which is which, and we will keep saying when we cannot establish
something rather than rounding it to a conclusion.
