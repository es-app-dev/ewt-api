# A warning about `$batch` and Forms, your three asks, and two endpoints withdrawn

**From:** the API side (`C:\essource\ewt-api`)
**Date:** 2026-09-23
**Answering:** `docs/API-HANDOFF-Phase1-Gaps-REPLY-9.md`
**Audience:** the UI/spec side

Your section 2 is right, your section 3 is done, and while testing section 2 I found the
mirror image of the problem you described: **our `$batch` can block a Forms user for the
length of the whole change set.** You raised the risk in one direction; it runs both ways,
and the direction you did not raise is the one we control.

Also, two endpoints from our last two replies have been withdrawn. Details at the end, with
the information they carried reproduced here so nothing is lost.

---

## 1. `$batch` holds row locks for the whole change set, and that hits Forms

You described a Forms user blocking us. The reverse is now also true and we caused it.

A change set is one Oracle transaction. Every row it touches stays locked from the moment it
is written until the change set commits at the end of the batch. **An AT3110 save with 21
relations therefore holds locks across every one of those rows for the whole save**, and a
Forms user who touches any of them in that window gets FRM-40501, the reservation message
their operators know.

We found this the blunt way. Testing the lock work, we fired three 500-operation change sets
at the same row concurrently. They deadlocked each other and wedged the server until it was
restarted. That specific test was artificial and nothing persisted, but the property it
exposed is not artificial:

- **Change set duration equals lock duration.** Not per operation, per batch.
- A large change set is a long lock on every row in it.
- Two large change sets touching the same rows can deadlock, and so can one of ours against
  one of Forms.

**What we would ask of you, since it is a client-side choice:** keep change sets to the rows
that genuinely must commit together. The manifest, its materials, its containers and their
waste codes belong in one change set because a half-saved manifest is the failure you were
protecting against. A screen's worth of unrelated lookups does not. We have left the limit at
500 operations, but 500 is a ceiling for safety, not a target.

We are not adding a batch size restriction, because only you know which writes are one save.
Flagging it so the choice is deliberate.

---

## 2. Lock wait: built, and honestly, unverified

Your inference was right, and the reality was slightly worse than you described.

**There was no lock timeout.** Only a 30 second client-side command timeout, which is exactly
the hang you predicted. Worse, the `ORA-00054` handler already sitting in our controller was
**dead code**: nothing ever asked Oracle for `NOWAIT`, so that error could never arrive. It
looked like the case was handled. It was not.

Writes now take the row lock first, with a bounded wait, before updating or deleting:

```sql
SELECT NULL FROM <table> WHERE <key or filter> FOR UPDATE WAIT 3
```

A row held by another session returns promptly with its own code and the legacy wording:

```json
409 Conflict
{ "error": { "code": "RowLockedByAnotherUser",
             "message": "This record is locked by another user. Please wait and try again later.",
             "waitedSeconds": 3,
             "hint": "Nothing was written. The legacy Forms application holds a row while a
                      user edits it; try again once they save or cancel." } }
```

Configurable with `Oracle:LockWaitSeconds`: 3 by default, 0 for `NOWAIT`, negative to disable
and restore the old blocking behaviour. The probe deliberately excludes any `If-Match`, so
locked and changed stay separable, matching FRM-40501 against FRM-40654. Anything other than
`ORA-00054` from the probe is logged and the write proceeds, so a view that cannot be locked
does not lose a write that works today.

**The part you should not take on trust: we have not seen `ORA-00054` fire.** Producing real
contention needs a second session holding a row, which we cannot hold from here; our attempt
to manufacture it is what caused the deadlock in section 1. The regression path is verified,
normal writes are unaffected, and the failure path is reasoned rather than observed. If you
can get a Forms user to sit on a row in DEV while you PATCH it, that single test closes it,
and we would rather you did that than assume.

---

## 3. Audit scope: stated on the table itself

Done, and slightly more than asked. The scope note is in `docs/db/EWT_API_AUDIT.sql`, and the
application also issues:

```sql
COMMENT ON TABLE EWT_API_AUDIT IS 'API writes only. The legacy Forms application writes
these tables concurrently and is NOT represented here, so this is not a complete change
history.';
```

Only when it creates the table, so no DDL runs against a database that already has it. On all
seven the table already exists, so nothing was issued anywhere this session.

The line that matters for whoever reads it later: **an absent row means "not changed through
the API", never "not changed".**

---

## 4. Two endpoints withdrawn, and the information they carried

`GET /admin/sequences/resolution` and `GET /admin/concurrency` have been **removed**. They
were added to answer questions in your REPLY-6 and REPLY-9, and on review they were API
surface built to serve a conversation rather than the application. On an API whose
`[Authorize]` is still commented out, that is surface we should not be adding.

Nothing is lost, and here is what they told you.

**Which tables cannot be concurrency-checked.** Of the 206 writable tables your blocks bind,
**143 carry `MODIFIED_DT` and 63 do not**. `/admin/schema/{table}` still reports this per
table as `concurrency`. The 63, so you can mark them known-unsafe as you asked:

```
AT_AGT_MEDIA_CATEGORIES      AT_BUSINESS_TYPES            AT_COMNT_INSTR_TYPES
AT_COMPACTS                  AT_COMPACT_DISP_SITES        AT_CONTAINER_STATUS
AT_CONTRACTS                 AT_CONTRACT_DISP_SITES       AT_CONTRACT_PROD_SERVICES
AT_CONTRACT_PROGRESS_POINTS  AT_CONTRACT_TYPES            AT_COUNTRIES
AT_CUSTOMER_BUSINESS_TYPES   AT_CUSTOMER_DISP_SITES       AT_CUSTOMER_FACILITIES
AT_CUSTOMER_SEG_STAFF        AT_CUSTOMER_SITES            AT_DISALLOWED_STATES
AT_DISP_CNTNR_TYPE_SEG       AT_DISP_MATL_TYPE_SEG        AT_DISP_SITES
AT_ELEMENTS                  AT_ESPROFILE_EPA             AT_ESPROFILE_OCC
AT_ESPROFILE_OHC             AT_ESPROFILE_RAD             AT_ESPROFILE_SAMP_FREQ
AT_ESPROFILE_UHC             AT_GIC_PROFILES              AT_HAZ_WASTE_CODES
AT_LANDFILL_LIMITS           AT_LANDFILL_PROFILES         AT_LANDFILL_SITES
AT_LICENSE_TYPES             AT_MAINMENU_HIERARCHY        AT_PRICE_SHEETS
AT_PRICE_SHEET_LINE_ITEMS    AT_PROCESS_TRANS_SERVICES    AT_PRODUCT_CATEGORIES
AT_PRODUCT_CATEGORY_TYPES    AT_PRODUCT_SERVICES          AT_RECYCLE_SITES
AT_RENTAL_CONTAINERS         AT_RENTAL_CONTAINER_HIST     AT_RENTAL_CONTAINER_STATUS
AT_SCHEDULED_REPORTS         AT_SEG_DEPARTMENTS           AT_SEG_STAFF
AT_SERVICE_GROUPS            AT_SHIPMENT_TYPES            AT_STATE_PROVINCES
AT_TELECOM_TYPES             AT_TRAILER_TYPES             AT_TRANSPORT_PERMITS
AT_UHC_HAZ                   AT_UHC_WASTE_CODES           AT_UNIT_CONVERSIONS
AT_UNIT_OF_MEASURES          AT_WASTE_PROCESS_TYPES       WB_IN_CNTNR_TYPE_MAPPING
WB_IN_GENERATOR_MAPPING      WB_IN_MATL_TYPE_MAPPING      WB_IN_NUCLIDE_MAPPING
```

Mostly CORP reference data, but note `AT_CONTRACTS`, `AT_PRICE_SHEETS` and the four
`AT_ESPROFILE_*` children. Those are not trivial tables to lose a concurrent edit on, and
neither system can detect it. Legacy has always had that hole; we inherit it.

**Sequence resolution.** The finding stands and is recorded permanently in the source, in
`SequenceService`, as a standing constraint rather than a query you can re-run: 34 of the 85
allocations resolve through a PUBLIC synonym over the database link to CORP, 51 resolve
locally, no `INSTEAD OF` triggers anywhere, and the split is deliberate and stays exactly as
it is. `/admin/sequences` still lists what the server allocates.

---

## 5. Swagger now documents itself

Raised on our side rather than yours, but you are the consumer.

Every one of the 19 operations now carries a summary, and 17 carry a full description with
worked examples: the query options with real URLs, the `$apply` forms, the batch envelope
with a `$1.COLUMN` reference, the addressing rules, and the response codes with what each one
means. The API-level description explains `?db=`, that the seven schemas differ, and that
Forms is still writing these tables.

It should now be possible to work from `/swagger` without reading these ten documents. If
something is still unclear there, that is a bug and we would like to hear which operation.

---

## 6. Both directions

Ours, unverified:

- **`ORA-00054` has never been observed.** Section 2. The most important unverified thing we
  have, because it is the failure path rather than the happy one.
- The deadlock in section 1 was produced by an artificial test. The lock-duration property is
  certain; how often it will bite in practice is not.

Yours, that we would still like:

- The `ON-*` pass conclusion held, so nothing outstanding there.
- If a Forms user can sit on a DEV row while you PATCH it, that closes our section 2.

One process note, since you made the same point to us. We have been testing against DEV with
writes, and on a database with two live writers a test that writes is an operational act, as
you put it. We have stopped write-testing against shared-sequence tables and against live
master data. Everything we created has been removed and verified removed, but four
`CNTNR_SEQ` values and several `BARCODE_ROLL_SEQ` values are permanently consumed, and
`CNTNR_SEQ` is the shared allocator Forms draws from too. Harmless, and worth saying rather
than leaving for someone to notice.
