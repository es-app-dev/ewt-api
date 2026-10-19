# We can make ORA-00054 fire - an offer, restated

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-09-24
**Answering:** `API-HANDOFF-Phase1-Gaps-REPLY-10.md` sections 1-3
**Audience:** the API side

A reply to REPLY-10 was written on 23 Sep as `API-HANDOFF-Phase1-Gaps-REPLY-11.md`; your
REPLY-11 of 24 Sep (the catalogue / `TA_*` one) used the same file name and replaced it. This
restates it under a name that will not collide. Your section 6 still lists `ORA-00054` as
never observed, so the offer is still open.

## 1. `$batch` change sets - accepted

Recorded in `ewt-ui/rules/common/API-CONTRACT.md` section 7: **one change set is one save**
(the manifest with its materials, containers and waste codes; never a screen's lookups). The
build specs will name the change set for each save. No batch-size restriction wanted.

## 2. `ORA-00054` has never fired - we can make it fire

We drive the legacy application from the machine it runs on (screen capture, OCR, clicks
placed from the JDAPI geometry, a record chosen from OData). It can hold a Forms row lock
deliberately and reversibly:

1. Open a form on a DEV row **you name** - a table with `MODIFIED_DT`, a row nobody cares about.
2. Change one field and stop. Forms locks the row on the first change (`SELECT ... FOR UPDATE
   NOWAIT` when the item is modified) and holds it until commit or clear. Nothing is saved.
3. You PATCH the same row with a **same-value** body. Expected: `409 RowLockedByAnotherUser`,
   `waitedSeconds: 3`, nothing written. If the probe does not fire, the write is a no-op.
4. We **Record > Clear** in Forms (rolls back the uncommitted change; no commit is ever issued).
   A second PATCH then succeeds, which checks the regression side too.

We can also record the mirror case - the Forms user's `FRM-40501` wording and timing when your
change set holds the row.

**Two things before it runs:** which table and row (your call), and a go from Bruce - typing
into a live DEV record, even uncommitted, is an operational act on a database with two writers.

## 3. Audit and concurrency notes - recorded

`EWT_API_AUDIT` holds API writes only (an absent row means "not changed through the API"), and
the 63 writable tables without `MODIFIED_DT` are marked known-unsafe for concurrent edits in the
build specs of the screens that bind them - both in `API-CONTRACT.md` section 7.
