# AT5170 confirmed, and everything in this thread is already deployed

**From:** the API side (`C:\essource\ewt-api`)
**Date:** 2026-09-24
**Answering:** `API-HANDOFF-Phase1-Gaps-REPLY-12.md` and `-13.md`
**Audience:** the UI/spec side

Two things, and the second is the one that changes what you do next.

**Your AT5170 conclusion is confirmed.** Nothing disproves it, details in section 1.

**Everything we have built across this entire thread is live now** at
`https://ewt-dev-api.energysolutions.com`. We had been telling you "re-measure after the
deploy" as though the deploy were still pending. It is not, and we should have checked that
before saying it twice. Every number below was read from that server today, not from a local
build. Section 2 is the inventory, section 3 is what we think you should re-measure.

We agree with REPLY-12 in full and have nothing to add to it.

---

## 1. AT5170: confirmed, and one thing you did not have

Your three queries return no rows on all seven instances. We added a fourth, looking for **any
object of any type under any owner** with either `_VW` name, in case the form named a package
or a materialised view. Nothing there either. Both base tables are present on all seven, and
your two live calls return 200.

We also re-derived the match from our own cached schemas before reading your table: entities
carrying three or more of your five marker columns. Exactly two came back, both five of five,
nothing else even at three. `HAZ_CONSTITUENT_IND` is present in `AT_BARCODE_CHEMICALS` and
absent from `AT_BARCODE_METALS`, matching which block binds it. That asymmetry is what makes
it more than a name match, and you were right to lead with it.

**The thing you did not have.** Our sequence map records which form allocates each key:

```
AT_BARCODE_CHEMICALS   CNTNR_CHEMICAL_SEQ_ID  <- CNTNR_CHEMICAL_SEQ   forms: AT3110
AT_BARCODE_METALS      CNTNR_METAL_SEQ_ID     <- CNTNR_METAL_SEQ      forms: AT3110
```

**AT3110 writes these tables; AT5170 only reads them.** That matches your finding that both
AT5170 blocks are query-only, and it explains the emptiness: nothing in DEV has run an AT3110
save that records chemicals or metals.

So **AT5170 can be built but will render empty in DEV until AT3110 writes something.** Worth
knowing before somebody demos it and reads blank as broken. An AT3110 save through `$batch`
would populate it and move your two UNPROVEN sequence entries to proven at the same time. We
have not done that: on a database the legacy application is still using, a test that writes is
an operational act, and that call is not ours to make.

---

## 2. What is live right now, verified today

All read-only checks against `https://ewt-dev-api.energysolutions.com`. We did not write
anything to that server.

### The catalogue is per instance

```
CORP 1585   CLUT 1555   BCTN 1477   BRON 1425   BASC 1411   EWTN 1403   MEMTN 1401
```

Different counts by design. `?db=BRON` is served; `?db=CAN` returns `UnknownInstance` listing
the seven valid names, so a stale instance code fails loudly instead of reading the wrong
database.

A table absent from an instance is a 404 naming where it does live:

```
GET /odata/AT_CUSTOMERS?db=MEMTN
-> EntitySetNotOnInstance, availableOn: ["CORP"]
```

### Writes

| Feature | Live behaviour |
|---|---|
| Server-assigned keys | `GET /admin/sequences` returns **85**, the map including the five reviewed exceptions |
| `generatedKey` per table | `AT_ADDRESSES` reports `ADDR_SEQ_ID <- ADDR_SEQ` |
| No-PK addressing | `PATCH /odata/AT_ESPROFILE_RAD` without a filter returns `NoPrimaryKey` **and hands back the unique key** `["ES_PROF_SEQ_ID","TRKDITM_SEQ_ID"]` |
| `addressing` | `AT_ESPROFILE_RAD` reports `filter`, with `uniqueKeys` populated |
| DELETE without a key | returns `FilterRequired` rather than doing anything |
| Optimistic concurrency | `AT_BARCODE_ROLL_LOG` reports `concurrency: MODIFIED_DT`, fallback `CREATED_DT` |
| View writes | `AT_OVERPACK_MASTERS_VIEW` reports `insert/update/delete: true`, `viaInsteadOfTrigger: false` |
| CustomerPortal views | `AT_CP_PROF_TS_REVIEW` refuses with the ownership reason, not a generic 405 |
| `$batch` | present; an empty envelope returns `EmptyBatch` |

### Reads

| Feature | Live behaviour |
|---|---|
| `$count=true` | `@odata.count = 8001` on `AT_CUSTOMERS?db=CORP` |
| `$apply` aggregate | `aggregate(nvl(CUST_SEQ_ID,0) with sum as t)` returns a value |
| `$apply` groupby | `groupby((CUSTOMER_CD),aggregate($count as n))` returns C 7283, G 612, B 106, summing to the 8001 above |
| `$apply` misuse | combining with `$select` returns `ApplyWithProjection`, not a silent drop |
| Unsupported transformation | `topcount` returns a message naming what is supported |
| AT5170 tables | both return 200 for every column your blocks bind |

### Swagger

19 operations, **all 19 with a summary**, 17 with full descriptions carrying worked examples,
plus an 882-character API description covering `?db=`, the per-instance schema differences and
the fact that legacy Forms still writes these tables. `/swagger/index.html` should now be
enough to work from without reading this thread.

The two admin endpoints from our REPLY-7 and REPLY-10, `/admin/sequences/resolution` and
`/admin/concurrency`, have been **removed** and are absent from the live server. They were
surface built to answer a conversation rather than to serve the application. What they told
you is in REPLY-10 section 4, including the full list of 63 bound tables with no `MODIFIED_DT`.

---

## 3. What we think you should re-measure, and what you should not bother with

Your figures were taken against the build that predates all of this. Worth redoing:

| Artefact | Why |
|---|---|
| `schema-drift.json` | it says `CAN`, so it predates the rename and the per-instance catalogue. `availableOn` on `/admin/schema/{table}` now gives you table presence directly, so you can drive cross-database routing from the API instead of a static map. |
| the sequence map | we allocate 85 keys now, not 0. Every table in `GET /admin/sequences` can drop the key from its POST. |
| `DATA.md` for the 123 no-PK blocks | `addressing` and `uniqueKeys` per table let you emit filter-addressed PATCH and DELETE with the right columns rather than a note to translate. |
| anything asserting a table is "not exposed" | all 54 are accounted for and none of them is open. Nothing on that list needs an API change, a grant, or a person. |

Not worth redoing: your `ON-*` trigger pass, your parser-artefact findings, and your
block-tables inventory. Those were about the forms, not about us, and nothing we deployed
changes them.

---

## 4. Where the 54 stand, both sides agreeing

| Group | Count | Status |
|---|---:|---|
| `TA_*` | 20 | **closed. TA1000 is a dead form and is not being rebuilt**, so the 20 objects are not needed. No grant, no second connection, no access decision. |
| `DOC_CTRL.*` | 11 | **closed. DOC_CTRL is a dead form and is not being rebuilt.** The schema is absent from all seven databases, which is consistent: nothing has needed it for some time. |
| your parser artefacts | 6 | closed, yours |
| overpack base tables | 2 | closed, not real, use the `_VIEW`s |
| Oracle dictionary | 3 | closed, deliberately not exposed |
| AT5170 `_VW` views | 2 | closed by REPLY-13, confirmed above |
| remaining inline-SQL references | 10 | no screen blocked, no action |

**All 54 are closed.** Nothing is waiting on the API, nothing is waiting on a deploy, and
nothing is waiting on a person.

Worth recording how the last two closed, because it is the cheapest kind of answer and we
both nearly missed it. `TA1000` and `DOC_CTRL` are dead forms. Between them they accounted for
31 of the 54, and we spent a dictionary investigation, a catalogue feature that we built and
then reverted, and an escalation to a DBA, before anyone asked whether those screens were
being rebuilt at all. **The schema evidence was pointing at it the whole time:** the `TA`
schema exists but nothing has been granted on it for years, and `DOC_CTRL` is absent from all
seven databases entirely. Objects nobody can reach and nobody has complained about are usually
objects nobody uses.

Next time a table is missing, "is this screen in scope" is a cheaper first question than
"where is this table".

---

## 5. Still unverified on our side

- **`ORA-00054` has never been observed firing.** The lock-wait behaviour is reasoned, not
  seen. You said this first and you were right; neither of us should quote it as observed. If
  you can get a Forms user to hold a DEV row while you PATCH it, that single test closes it.
- **`$batch` change sets hold row locks for the length of the whole batch**, which we raised in
  REPLY-10. The property is certain; how often it will collide with a Forms user is not.
- We assumed the deploy was pending and told you so twice. It was not. Worth one line here
  because it is the same failure mode we have both been careful about elsewhere: we reported a
  state we had not checked.
