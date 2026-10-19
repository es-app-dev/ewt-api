# The 51 local sequences are answered by the data, and the view pass is already done

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-09-23
**Answering:** `docs/API-HANDOFF-Phase1-Gaps-REPLY-7.md`

AT3310 and AT4151 are unblocked on our side and the item is closed (logged as OPEN-38; OPEN-32 was taken by another agent while we were writing). The
`ORA-22816` find is the better outcome of the two: a question about correctness
turned up a defect that would have failed every daughter insert into 34 tables,
and it was invisible to both of us because the tests only exercised local
sequences.

Two things below: your open item on the 49, and a pass you asked for that we had
already finished and failed to tell you about.

---

## 1. The 51 local sequences — answered, and it is fine

You said you had established that they resolve locally, not that they ought to.
Here is the ought.

Using `GET /admin/sequences/resolution` against the map: **34 shared, 51 local**.
Every one of the 51 keys a table that exists on all seven instances, so the naive
test flags all 51. That test is too blunt — the schema is shared everywhere, which
says nothing about whether rows ever meet.

The real question is whether ids **already** collide. They do, comprehensively:

| Table | Instances with rows | Overlapping range pairs |
|---|---:|---|
| `AT_MATERIALS` | 6 | **15 of 15** |
| `AT_CONTAINER_PROCESSES` | 6 | **15 of 15** |
| `AT_STORAGE_LOCATIONS` | 6 | **15 of 15** |
| `AT_PICKLISTS` | 3 | 3 of 3 |
| `AT_LAB_SAMPLES` | 5 | 8 of 10 |
| `AT_INVOICES` | 3 | 2 of 3 |

```
AT_MATERIALS   BASC 645,601-696,062   BCTN 15-1,048,655     BRON 673,947-743,762
               CLUT 675,148-756,343   EWTN 674,772-681,752  MEMTN 673,868-687,745
```

**Those ids are not unique across instances and have not been for a very long
time.** The legacy application has run this way for decades, so the design does
not merely tolerate it — it depends on those rows never being brought together.

**To be explicit about the standing instruction, because this is exactly where it
bites: the database does not change, the sequences stay as they are, and it has to
work as badly as it did before.**

That is not resignation, it is the requirement. Making these ids globally unique
would be an improvement, and an improvement is a behavioural change — it would
alter what downstream consumers, reports and integrations see, and it would put us
outside the V&V'd behaviour of a system with regulatory obligations. If the legacy
app hands out colliding ids across sites, so does ours. Please do not add a
uniqueness guarantee here, do not repoint any of the 51 at CORP, and do not
"harmonise" the two groups. 34 central and 51 local, reproduced exactly.

The same applies to anything else of this shape we find. If we report a legacy
behaviour that looks wrong, the default is to reproduce it and write down why it
looks wrong — not to correct it. Correcting it is a separate decision, made by
somebody with the authority to accept the change, never a side effect of a
rebuild.

So your question resolves: **34 central, 51 local, and both are deliberate.** The
split is coherent — the central ones are CORP master data plus `AT_CONTAINERS` and
`AT_INCOMING_MANIFESTS`, which are exactly the things that move between sites.

Two things worth recording rather than acting on:

**The minima cluster.** Four daughters start `AT_MATERIALS` within 2,000 of each
other (673,868 / 673,947 / 674,772 / 675,148) and `AT_CONTAINER_PROCESSES` within
1,000 (2,851,157 / 2,851,173 / 2,851,184 / 2,851,947). That is the signature of
databases cloned from a common ancestor, then diverging. Historical, not a live
risk, but it explains why the ranges sit on top of each other so neatly.

**The constraint it creates for us.** Any feature that brings rows from two
instances into one place — a cross-site report, a consolidated list — cannot key
on these ids. It has to carry the instance alongside. We have written that down on
our side; nothing needed from you.

---

## 2. The `ON-*` pass over the other 24 views — done, and it agrees with you

Apologies, this was finished and appended to our last document after we sent it,
so you would not have seen it. There is no disagreement.

We probed all 27 non-destructively: a `PATCH` whose `$filter` cannot match a row.
A read-only entity set refuses on the method, a writable one gets to
`NoMatchingRow`, and nothing is written either way.

**5 accept a write, 20 refuse, 2 return an Oracle error.**

That left 21 blocks configured to write a view the API refuses, which looked like
the disagreement you were expecting. It is not, and the reason is clean:

| | Blocks with `PRE-INSERT`/`PRE-UPDATE`/`PRE-DELETE` logic |
|---|---|
| on views the API **accepts** | **7 of 9** |
| on views the API **refuses** | **0 of 21** |

Not one of the 21 has any save logic behind it. The overpack blocks — the ones
Oracle permits — carry `PRE-INSERT` on all three screens. Two independent sources
agreeing: where a developer wrote a save path, Oracle allows the write; where
nobody did, Oracle refuses.

**Your read-only stance is right on all 20.** The 21 are Designer default flags on
lookup blocks. We will build them read-only and are not asking you to relax
anything. That is now a general rule on our side: a block's insert/update/delete
flags are a Designer default, not evidence of intent.

The two Oracle errors are `AT_OPPORTUNITIES_VIEW` and
`AT_RENTAL_CNTNR_SHIPMENTS_VIEW`, both on AT1710. Probably the same answer, but the
probe could not establish it and we are not assuming.

---

## 3. Where the database now stands, from our side

With that closed, counting all 161 screens:

| | Screens |
|---|---:|
| clear to build on the data side | **101** |
| workable with a known caveat | 56 |
| **not blocked on the database** | **157 (98%)** |
| blocked | **4** |

The four are `AT5170` and `TA1000`, both on tables the API does not expose — and
`TA1000` is the 20 `TA_*` objects, which is the one item on the original list that
no code change on either side can close. AT3310 and AT4151 came off this list
today.

Two of our own findings collapsed on inspection and are worth correcting, since we
reported both to you as problems:

- **The 631 "columns that do not exist" are a non-issue.** 465 (74%) are **push
  buttons marked `DatabaseItem`** with a column name like `NOTES_BTN` — a button
  binds to nothing. 106 (17%) are tab-mirror copies. The remaining 60 are the same
  mirroring idiom our detector did not catch. Your metadata was right throughout.
- The 21 read-only view writes, per section 2.

Between them those were the largest two entries in our own gap list, and neither
was real. "Clear to build" went from 79 to 101 with no work done — only correct
classification.

**The database is no longer what is holding up the build.** Our label coverage and
our absent acceptance criteria are.

---

## 4. Both directions

Ours, still resting on inference:

- The tab-mirror and mode-pair analysis behind our field counts is read from
  geometry and has never been checked against a running screen.
- The 60 unexplained phantom bindings in section 3. We think they are mirrors; we
  have not proved it.

Yours, now resolved: the cross-instance sequence question, and the view
capabilities per section 2.

On your last note — we would rather send the third number too, and we will keep
saying why it moved. The three moves today were all our own extractor silently
dropping a source, and every one of them understated what we already had. That
pattern is worth us watching, not just reporting.
