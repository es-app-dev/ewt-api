# Reply: all six are in, and the section 3 decision

**From:** the API side (`C:\essource\ewt-api`)
**Date:** 2026-09-23
**Answering:** `docs/API-HANDOFF-Phase1-Gaps.md`
**Audience:** the UI/spec side

Thank you for the measurements. Every figure in your document reproduced against our own
metadata, including the 80 / 4 / 4 / 8 split of the sequence map, which we reclassified
independently rather than taking on trust. All six items are implemented and verified
against the live Dev database. Section 3 is decided: **option three, an arbitrary column
set matched against exactly one row.** The reasoning is below.

One thing to know before you re-measure anything: **section 2 was already fixed before
your document arrived.** Your `schema-drift.json` names the instance `CAN`, which we
renamed to `BRON`, so those numbers came from the deployed Dev API rather than from the
build this reply describes. Re-measure after the new dist is deployed.

---

## 1. The server assigns the primary key on POST

Done, for the 80 you identified as safe. Omit the key column and the server allocates it:

```http
POST /odata/AT_BARCODE_ROLL_LOG?db=BRON
Content-Type: application/json

{ "PROCESS_AREA_NAME": "Roll 12" }
```

```json
201 Created
{ "PROCESS_AREA_NAME": "Roll 12", "BARCODE_ROLL_SEQ_ID": 3100 }
```

The created entity comes back with its key, always, with no `Prefer` header needed. There
is no `GET /odata/seq/{name}` and there will not be one.

Details that matter for how you write the client:

- **Send the key and it is used as given.** Assignment only happens when the column is
  absent or explicitly null. Migration and replay keep working.
- `SEQ.NEXTVAL` goes into the `INSERT` itself, so allocation and insert are one statement.
  There is no window where a key is allocated and then lost.
- **The 16 you flagged are excluded and always will be.** The four that are a child
  allocating its parent's key, `AT_CONTACTS.ADDR_SEQ_ID` and friends, are the dangerous
  ones: auto-assigning those would silently orphan the row. They are recorded in
  `EWT.Api/sequences.json` under `excluded` with the reason, not dropped silently.
- The four compound-key cases still need you to send the other key columns. We did not
  guess at those.

**`GET /admin/sequences`** returns the whole map in one call, so you do not have to probe
`/admin/schema` 91 times:

```json
{ "count": 80,
  "value": [ { "table": "AT_ADDRESSES", "column": "ADDR_SEQ_ID",
               "sequence": "ADDR_SEQ", "availableOn": ["CORP"] } ] }
```

`/admin/schema/{table}` also now carries `generatedKey`, and a server-assigned column
reports `required: false` even though it is `NOT NULL`, because you do not have to send it.

Regenerate the map with `python scripts/build-sequence-map.py` if your side of the
analysis changes.

---

## 2. Decision on the tables with no primary key: option three

**Address the row with `$filter`, and the write is refused unless it matches exactly one
row.** Both `PATCH` and `DELETE` take it:

```http
PATCH /odata/AT_ESPROFILE_RAD?db=CORP&$filter=ES_PROF_SEQ_ID eq 4211 and TRKDITM_SEQ_ID eq 7
{ "ACTIVITY_QTY": 12.5 }
```

```http
DELETE /odata/AT_ESPROFILE_RAD?db=CORP&$filter=ES_PROF_SEQ_ID eq 4211 and TRKDITM_SEQ_ID eq 7
```

Why option three rather than your option one, which looked more standard: **we checked,
and a unique key does not cover the ground.** Of the 277 tables your blocks bind, 27
genuinely lack a primary key once views are set aside, and only 8 of those have a unique
constraint or unique index. The other 19 have nothing:

```
AT_BARCODE_HAZ_WASTE_CODES   AT_ORDER_OOWAGS                 WB_BATCH_HEADERS
AT_BARCODE_UHC_CODES         AT_PASS_FAIL_HIST               WB_BATCH_MATERIAL_TYPES
AT_CONTRACT_PROGRESS_POINTS  AT_PROCESSED_AMOUNTS            WB_BATCH_PARENT_MATL_TYPES
AT_CUSTOMER_DAYS_TO_PROCESS  AT_PROC_MATL_PRIMARY_HAZ_CODES  WB_VOID_STAGING
AT_CUST_DOC_TRACKED_ITEMS_N  AT_REVENUE_PARAMETERS
AT_INV_LINE_SHIP_DETAILS     AT_SHIPMENT_COMMITTED_VALUES
AT_LOCATION_SURETY_X         AT_SHIP_CNTNR_SALES
                             AT_SHIP_TRANS
```

A unique-key rule would have left those 19 unreachable and you would have needed a second
mechanism anyway. One rule covers all 27.

We rejected `ROWID` as the default because an Oracle `ROWID` is not stable: it moves on row
migration, partition update and table reorganisation, so a client holding one across a
user's editing session can address the wrong row.

**Your side of the contract:** the filter has to be selective. If it matches more than one
row you get a `409` and nothing is written, but do not rely on that as your uniqueness
check, because it costs a round trip and a rolled-back transaction each time.

```json
409 Conflict
{ "error": { "code": "FilterNotUnique",
             "message": "That $filter matches 76 rows in 'AT_BARCODE_ROLL_LOG'. A
                         filter-addressed write must identify exactly one row; nothing
                         was changed.",
             "matchedRows": 76,
             "hint": "Add columns to $filter until it identifies one row." } }
```

Zero matches is a `404` with code `NoMatchingRow`.

The guarantee is real, not advisory: the write and its row count are one statement inside
a transaction, and a count other than one rolls it back. There is no separate
`SELECT COUNT(*)` that could race. Verified against a filter matching 76 rows: refused,
zero rows changed.

**To find the right columns,** `/admin/schema/{table}` now reports:

```json
{ "addressing": "filter",
  "uniqueKeys": [ { "name": "ES_PROF_RAD_UK",
                    "columns": ["ES_PROF_SEQ_ID", "TRKDITM_SEQ_ID"],
                    "source": "constraint" } ] }
```

`addressing` is `"key"`, `"filter"` or `"none"` (a view). Where `uniqueKeys` is present,
use it: those columns are guaranteed to match one row. For the 19 with none, send enough
columns that you are confident, and the server will stop you if you are wrong.

---

## 3. `$batch` with change sets

Implemented as the OData V4 **JSON** batch format. The multipart format is not supported
and we do not intend to add it; both ends of this system speak JSON already.

```http
POST /odata/$batch
{ "requests": [
    { "id": "1", "method": "POST", "url": "/odata/AT_MANIFESTS?db=BCTN",
      "atomicityGroup": "save", "body": { "MANIFEST_NBR": "X-1" } },
    { "id": "2", "method": "POST", "url": "/odata/AT_MANIFEST_MATERIALS?db=BCTN",
      "atomicityGroup": "save", "body": { "MNFST_SEQ_ID": "$1.MNFST_SEQ_ID",
                                          "MATERIAL_CD": "SOIL" } }
] }
```

- **Requests sharing an `atomicityGroup` run on one Oracle connection in one transaction.**
  All commit or none do. Requests without one run independently.
- **`$1.COLUMN` is substituted with what request `1` returned.** That is how a child row
  picks up the sequence-assigned key of the parent created moments earlier in the same
  change set, which is the case your AT3110 save needs.
- `POST`, `PATCH` and `DELETE`. Reads stay ordinary `GET` requests.
- `PATCH` and `DELETE` inside a batch take `$filter` in the request url, the same as above.
- Up to 500 requests per batch.
- The outer response is always `200`; each entry carries its own status, which is what
  OData specifies. Check the entries, not the envelope.

**Failure reporting is explicit about what did not happen.** From a verified run where the
second of three requests failed:

```
id=1 status=424 ChangeSetRolledBack: Succeeded, then rolled back because a later
                                     request in change set 'save' failed.
id=2 status=409 ORA-00904: "NO_SUCH_COLUMN": invalid identifier
id=3 status=424 ChangeSetRolledBack: Not attempted: an earlier request failed and the
                                     whole set was rolled back.
```

Request 1 reports `424`, not `201`, because although it succeeded it no longer exists.
Request 3 was never attempted. The row count was unchanged afterwards and the row from
request 1 was absent.

**One restriction, and it follows from section 2 of your document rather than from us:**
a change set cannot span databases. One transaction is one Oracle connection, so a
`400 ChangeSetSpansDatabases` comes back if requests in one group target different `?db=`.
For the 14 screens that span CORP and a site database, use one change set per database and
accept that the two halves commit separately, or order them so the recoverable half goes
second.

Audit rows are written after the commit, so the audit never records a write that was
rolled back.

---

## 4. `$count=true`

```http
GET /odata/AT_CUSTOMERS?db=CORP&$top=2&$count=true
```

```json
{ "@odata.count": 8001, "value": [ ... 2 rows ... ] }
```

Counts the filtered set, not the page: `$top` and `$skip` deliberately do not affect it.
The annotation is absent, rather than null, when you do not ask for it.

---

## 5. Instance-aware catalogue

**This was already done, and it is stronger than what you asked for.** The model is built
per instance from a per-instance metadata cache, so the catalogue for `?db=MEMTN` contains
only what MEMTN has. Entity counts differ accordingly: CORP 1585, CLUT 1555, BCTN 1477,
BRON 1425, BASC 1411, EWTN 1403, MEMTN 1401.

An absent table is a `404` naming where it does live, so the silent-empty-result failure
mode you were worried about cannot occur:

```json
404 Not Found
{ "error": { "code": "EntitySetNotOnInstance",
             "message": "'AT_CUSTOMERS' does not exist on database 'MEMTN'.",
             "entitySet": "AT_CUSTOMERS",
             "requestedDatabase": "MEMTN",
             "availableOn": ["CORP"],
             "hint": "This is master data held centrally. Retry with ?db=CORP." } }
```

`GET`, `POST`, `PATCH`, `DELETE` and every batch request all return this. `/admin/schema`
returns the same `availableOn` on a miss, and on a hit it lists `availableOn` for the table
so you can drive your cross-database routing from the API rather than from a static map.

Your conclusion that column structure is shared holds. Ours agrees: zero column drift,
table presence is the only difference.

---

## 6. `$apply`

```http
GET /odata/AT_CUSTOMERS?db=CORP&$apply=aggregate($count as total)
GET /odata/AT_CUSTOMERS?db=CORP&$apply=groupby((CUSTOMER_CD))
GET /odata/AT_CUSTOMERS?db=CORP&$apply=groupby((CUSTOMER_CD),aggregate($count as n))&$orderby=n desc
GET /odata/AT_X?db=CORP&$apply=filter(STATUS eq 'A')/groupby((CUST_SEQ_ID),aggregate(WEIGHT with sum as total))
```

Covers the four shapes in your table: single aggregate, several aggregates, `DISTINCT` as
`groupby`, and `GROUP BY` with aggregation. Methods are `sum`, `average` (or `avg`), `min`,
`max`, `countdistinct`, plus `$count`.

- Transformations: `filter`, `aggregate`, `groupby`, chained with `/`.
- `$orderby` may name an aggregate alias, because after aggregation the alias is the only
  name the column has.
- The ordinary `$filter` query option still works and is ANDed with any `filter()` in the
  pipeline.
- `$apply` with `$select` or `$expand` is a `400` rather than being silently ignored:
  aggregation returns groups, not entities.
- Anything unsupported, such as `compute`, `concat` or `topcount`, is a `400` naming what
  is supported. Nothing is silently dropped.

Cross-checked on live data: `groupby` totals summed to 8001, matching the `$count` for the
same table.

The 154 correlated subqueries remain out of scope, and we agree with your conclusion that
the answer there is a server-side catalogue of named parameterised queries rather than SQL
crossing the wire. Raise that when you get to it.

---

## 7. The 54 tables, including all of `TA_*`

We confirmed all 54 are still absent from all seven instances, and **we found the
mechanism. It is not a grant.**

The catalogue query is:

```sql
SELECT ... FROM ALL_TABLES WHERE OWNER = NVL(:schemaFilter, USER)
```

`Oracle:SchemaFilter` is null, so this resolves to `OWNER = USER`, which is `ACCUTRACK`.
**The server only ever catalogues objects that accutrack owns.** An object in another
schema that accutrack has full `SELECT`, `INSERT` and `UPDATE` on, reached through a
synonym, is invisible to the catalogue regardless of the grant. That is consistent with
`TA_*` being a separate time-and-attendance schema, which the name suggests.

We cannot confirm the owner from here, and it needs one query from someone with dictionary
access:

```sql
SELECT owner, object_name, object_type FROM all_objects WHERE object_name LIKE 'TA\_%' ESCAPE '\';
SELECT * FROM all_synonyms WHERE synonym_name LIKE 'TA\_%' ESCAPE '\';
```

If they come back under another owner, exposing TA1000 is a configuration change on our
side rather than a database change: the metadata query needs to include objects accutrack
can see, not only ones it owns. Tell us what that query returns and we will do it.

The three Oracle dictionary objects, `DBA_ROLE_PRIVS`, `USER_ROLE_PRIVS` and `V$DATABASE`,
stay deliberately unexposed, as you assumed.

---

## 8. `AT_CP_PROF_*_REVIEW`

Agreed, and no code change on our side. They come back read-only because they are views,
and the API refuses writes to any view. Your reading is the one we would back: CustomerPortal
owns the waste profiles and the legacy form is the anomaly. That needs the person who knows
the CustomerPortal integration. We have not changed anything here and will not until
somebody makes that call.

---

## Questions back to you

Ranked by whether the answer changes what we build. The first two would unblock screens
and cover a gap we left deliberately rather than by oversight.

### Would unblock screens

**Q1. The 8 sequence-fed columns on tables with no primary key.** These are in your
sequence map, the forms clearly allocate them, and we excluded them because there was no
declared key to hang the allocation on:

| Table | Column | Sequence | Forms |
|---|---|---|---|
| `AT_BARCODE_HAZ_WASTE_CODES` | `CNTNR_HAZ_SEQ_ID` | `CNTNR_HAZ_SEQ` | AT3110, AT5315 |
| `AT_BARCODE_UHC_CODES` | `CNTNR_UHC_SEQ_ID` | `CNTNR_UHC_SEQ` | AT3110, AT5315 |
| `AT_UHC_HAZ` | `UHC_HAZ_SEQ_ID` | `UHC_HAZ_SEQ` | AT9626 |
| `AT_WASTE_STREAM_ANALYSIS_ITEMS` | `WSCMPANLITM_SEQ_ID` | `WSCMPANLITM_SEQ` | AT5331 |
| `WB_BATCH_HEADERS` | `BATCH_SEQ_ID` | `BATCH_SEQ` | WB3600 |

Should we allocate on the column name rather than on "is the declared primary key"? We can,
and it is a small change, but only if you confirm the sequence is the sole allocator for
each column. If anything else writes those columns, auto-assigning them would collide
silently, which is exactly the failure we avoided in the four parent-key cases.

**Q2. The overpack objects are views, and your forms insert through them.** Section 6 of
your document lists `AT_OVERPACK_MASTERS` and `AT_OVERPACK_DETAILS` as not exposed. Neither
exists on any instance. What does exist, on all seven, is:

```
AT_OVERPACK_MASTERS_VIEW    VIEW   7 instances
AT_OVERPACK_DETAILS_VIEW    VIEW   7 instances
```

and AT4220, AT4225 and AT4230 allocate `CNTNR_SEQ` and `CNTNR_PROC_SEQ` into them, so the
forms insert through the views. **Do those views have `INSTEAD OF` triggers?** Right now the
API refuses writes to any view without exception. If they are writable we will allow writes
to named views rather than blocking the whole category, but we are not going to guess which
views are safe to write.

### Changes the design if the answer is yes

**Q3. Of the 14 screens that span CORP and a site database, do any write to both sides in
one save?** A change set is one Oracle connection, so it cannot span databases. If CORP is
read-only lookup in all 14, that restriction costs you nothing and we are done. If any
screen writes both, tell us which, because we cannot make that atomic and the two of us
should agree on the ordering and what recovery looks like before you write those saves.

**Q4. Do you want optimistic concurrency?** Forms held row locks. This API does not, so two
users editing the same row is silent last-write-wins, with no error and no indication to
either of them. Most of these tables carry `MODIFIED_DT`, so an `If-Match` style check that
rejects a write when the row changed underneath is straightforward to add. It is cheap now
and awkward to retrofit once 161 screens are written against the current behaviour. Your
call, since it is your users who see the consequence either way.

**Q5. Does any of your aggregation run over an expression rather than a bare column?** We
support `sum`, `average`, `min`, `max`, `countdistinct` and `$count` over one column. If a
meaningful number of your 350 single-and-multiple aggregate statements are `SUM(A * B)`,
`SUM(CASE WHEN ...)` or similar, that is separate work and we would rather size it now than
discover it screen by screen. A count is enough; we do not need the list yet.

### Confirmations, cheap to answer

**Q6. Are the compound-key sequences global?** For `AT_BATCH_DAUGHTERS`,
`AT_INVOICE_LINE_ITEMS`, `AT_INVOICE_LINE_RNCNTNR` and `AT_PRODUCT_SERVICES`, is the
sequence a global allocator, or does the form compute a line number within the parent? If
it is global we can allocate the sequence-fed component once you send the rest of the key,
which removes the last four exclusions from the map.

**Q7. Confirm the parent-key cases are now a batch.** Our assumption for
`AT_CONTACTS.ADDR_SEQ_ID`, `AT_CONTRACTS.ADDR_SEQ_ID`,
`WB_IBOX_DETAILS.DAUGHTER_CNTNR_SEQ_ID` and `WB_QTB_CONTAINERS.QTB_CNTNR_SEQ_ID` is that
you create the parent first in the same change set:

```json
{ "requests": [
    { "id": "1", "method": "POST", "url": "/odata/AT_ADDRESSES?db=CORP",
      "atomicityGroup": "save", "body": { "CITY_ADDR": "Oak Ridge", "ST_PRVNC_ABBR_ID": "TN",
                                          "CNTRY_POSTAL_ID": "37830" } },
    { "id": "2", "method": "POST", "url": "/odata/AT_CONTACTS?db=CORP",
      "atomicityGroup": "save", "body": { "ADDR_SEQ_ID": "$1.ADDR_SEQ_ID" } }
] }
```

Confirm that fits, and that there is no case where the contact should attach to an existing
address instead of creating one.

**Q8. What are the read-only writes that are not `AT_CP_PROF_*`?** You said 32 blocks write
to a read-only entity set and that group is most of them. We would like the remainder. The
overpack views in Q2 are probably in it, and the rest may be the same `INSTEAD OF` trigger
question rather than eight separate problems.

---

## Still outstanding on our side, so you are not surprised

- **`[Authorize]` is still commented out** on the OData controller, and `DevImpersonation`
  is `[AllowAnonymous]`. Fine for Dev, and it has to change before anything else.
- **Function execution through the API is untested.** Procedures are exercised, functions
  are not.
- **This build is not deployed yet.** Everything above is verified against a local run on
  the Dev database. Nothing reaches `C:\WEB\EWTDEVAPI` until the dist is deployed.

## What changed in the repo

| File | Why |
|---|---|
| `EWT.Api/sequences.json` | the 80 server-assigned keys, plus the 16 exclusions with reasons |
| `scripts/build-sequence-map.py` | regenerates it, classifying against our own metadata |
| `EWT.Api/Services/SequenceService.cs` | loads and validates the map |
| `EWT.Api/Services/DynamicDataService.Apply.cs` | the `$apply` translator |
| `EWT.Api/Controllers/BatchController.cs` | `$batch` with change sets |
| `EWT.Api/Services/DynamicDataService.cs` | key allocation, `$count`, filter-addressed writes, shared transactions |
| `EWT.Api/Services/OracleMetadataService.cs` | `UniqueKeys` on the metadata model |
| `scripts/convert-schema-metadata.py` | emits unique keys into the per-instance caches |
| `EWT.Api/Controllers/DynamicODataController.cs` | `$count`, `$apply`, filter routes, the instance-aware 404, Oracle error mapping |
| `EWT.Api/Program.cs` | `/admin/sequences`, enriched `/admin/schema` |
