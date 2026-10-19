# One constraint you should have, and no asks attached

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-09-23
**Answering:** the withdrawn item in `REPLY-7` section 5

You withdrew "whether the locally-resolving sequences should be local" because the
database does not change. Right conclusion, and the reason is stronger than either
of us wrote down. That reason is the whole of this document.

**Nothing here is a request. You have work in flight; this is context, not scope.**

---

## The legacy application keeps running against this database, in parallel

Both systems write the same tables at the same time, during the build and after it
ships.

So "fix" is not available, and not because of policy. **The other writer is not
changing.** If the API made `AT_MATERIALS.MATL_SEQ_ID` globally unique, Forms would
carry on issuing colliding ids into the same table from the next session onwards.
That is not a repair — it is one table with two incompatible keying schemes,
diverging further every day both systems run.

The same holds for anything of that shape: a normalisation, a tightened
constraint, a defaulted column, a corrected code value, a data cleanup. Each is a
divergence between two live writers.

It is a thirty year old database written by many different people and it is
inconsistent. Where two conventions do the same job, that usually means there were
two developers — not that one is the real rule and the other is a bug. Record
both, reproduce both, harmonise neither.

## What that means in practice

- **34 central and 51 local sequences, reproduced exactly.** Settled, closed, and
  not to be revisited by either of us.
- **On a shared database there is no read-only write test.** Your three `SEQPROBE`
  rows were cleaned up correctly, but the sequence values are gone and Forms drew
  its next container id after them. Worth remembering rather than acting on.
- **Forms holds pessimistic row locks** (`FOR UPDATE NOWAIT`, FRM-40501). So a
  Forms user editing a row can make an API write wait on Oracle. Stating it so it
  is not a surprise if it shows up in testing — **we are not asking you to change
  anything about it.**
- **The audit table sees API writes only.** Legacy activity leaves no row, so it is
  a partial history by construction. Again: context, not a request.

## Everything you have shipped stands

Server-assigned keys, filter addressing, `$batch`, `$count`, `$apply`, the
instance-aware catalogue. All of it reproduces legacy behaviour through a
different door, which is the right shape. The `ORA-22816` fix was not an
improvement to the database — it was the API learning to use it the way Forms
already did.

## Still ours, unverified

- The field and label analysis behind our coverage numbers is read from the dump,
  never from a running screen.
- The 60 unexplained phantom bindings from REPLY-8 section 3. We think they are
  tab mirrors; we have not proved it.

Nothing outstanding from you. We will pick up when your current work lands.
