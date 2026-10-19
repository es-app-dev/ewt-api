# Snapshot of the Dev API, 2026-09-24

Taken from `https://ewt-dev-api.energysolutions.com` before deploying the build that carries
the merged relationships and the unique-key fix. A before-picture, so a deploy can be
compared against what it replaced rather than trusted.

Everything here was read through the API. Read-only: no writes were made to that server.

| File | What it is |
|---|---|
| `instances.json` | the seven databases as the server reports them |
| `relationships.json` | all 1,525 `$expand` definitions, including the 48 the UI added |
| `sequences.json` | the 85 tables whose primary key the server allocates |
| `swagger.json` | the full OpenAPI document |
| `catalogue.<INSTANCE>.json` | every entity set on that instance, with kind and expand options |

## What this snapshot does NOT contain

**The server's `metadata/tables.*.json` files.** Those hold full column detail for roughly
10,250 entities across the seven instances, and reconstructing them through `/admin/schema`
would be one call per entity. Not worth that load on a shared server when the repo already
holds a copy that is provably correct.

## One difference worth recording

The repo's metadata is **not** a copy of the server's. It is better, on one instance:

```
CORP    local has uniqueKeys on 398 tables | live sample 0/5  -> WIPED
BCTN    298 | 5/5 INTACT      CLUT 297 | 5/5 INTACT
EWTN    297 | 5/5 INTACT      BRON 297 | 5/5 INTACT
BASC    297 | 5/5 INTACT      MEMTN 297 | 5/5 INTACT
```

Somebody ran `/admin/refresh-cache?db=CORP` against the running server. That path re-read
Oracle through `OracleMetadataService`, which did not read unique constraints, so it rewrote
CORP's cache without them. Only CORP was refreshed; the other six still carry what was
deployed.

The visible symptom is that `PATCH /odata/AT_ESPROFILE_RAD?db=CORP` without a filter no longer
returns `uniqueKeys` in its `NoPrimaryKey` error, so it has stopped telling callers which
columns to filter on. That is the field the UI team built their `DATA.md` generation around.

Fixed in the build this snapshot precedes: `GetUniqueKeysAsync` reads unique constraints and
unique indexes, so a refresh is now idempotent rather than lossy. Verified by running a
refresh and comparing against the Python generator: 398 versus 398, all 1,585 CORP tables
identical, primary keys and column counts identical.

**So deploying restores CORP rather than overwriting anything good.**
