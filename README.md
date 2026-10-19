# EWT API

Dynamic OData server over Oracle, ported from the EWIS API. The EDM model is built at
startup by reading the Oracle data dictionary, so there are no hand-written entity
classes — every table and view in the schema is exposed automatically.

## Databases

EWT spans a top-level **CORP** instance and its daughter databases. The daughters
share an identical schema, so the EDM model is read once from the instance named by
`Oracle:ModelSourceInstance` and reused for all of them.

Seven are configured. The instance name is the middle token of the TNS alias, so
`EWT_CORP_DEV` is addressed as `?db=CORP` and the name stays the same in every
environment. All Dev databases live on `dc1devewtdb1`, but **not on one port**:

| Instance | Legacy key | Dev TNS alias   | Port | SID       |
|----------|-----------|-----------------|------|-----------|
| `CORP`   | —         | `EWT_CORP_DEV`  | 1524 | `atcorp`  |
| `BCTN`   | 1064      | `EWT_BCTN_DEV`  | 1524 | `atbctn`  |
| `CLUT`   | 1127      | `EWT_CLUT_DEV`  | 1522 | `atclive` |
| `EWTN`   | 1111      | `EWT_EWTN_DEV`  | 1524 | `atewtn`  |
| `CAN`    | 3         | `EWT_CAN_DEV`   | 1524 | `atcan`   |
| `BASC`   | 4         | `EWT_BASC_DEV`  | 1524 | `atbasc`  |
| `MEMTN`  | 1067      | `EWT_MEMTN_DEV` | 1523 | `atmem`   |

Two irregularities worth remembering: CLUT and MEMTN are on their own ports, and
CLUT's SID is `atclive`, not `atclut`. These connect descriptors use **SID**, not
`SERVICE_NAME` as EWIS does.

The Dev descriptors are inlined into the connection strings, so `tnsnames.ora` does
not need to be deployed. `Oracle:TnsAdmin` is only needed if you switch back to the
alias form.

The database is chosen with the `db` query parameter, so the URL shape is identical
for every database:

```
/odata/{entitySet}?db={database}
```

```
GET  /odata/instances                  list the configured databases
GET  /odata                            entity sets (on the default database)
GET  /odata/SHIPMENT?db=CORP&$top=10
GET  /odata/SHIPMENT?db=BCTN&$filter=STATUS eq 'OPEN'&$expand=Generator
POST /odata/SHIPMENT?db=BCTN
GET  /odata/proc?db=CLUT               stored procedures on that database
GET  /api/Status                       health, probed per database
```

Omitting `db` falls back to `Oracle:DefaultInstance` (currently `CORP`). Set that to
null to require `db` on every request instead. An unrecognised value returns `404`
listing the configured databases.

Query support is unchanged from EWIS: `$select`, `$filter`, `$orderby`, `$expand`,
`$top`, `$skip`. `$expand` runs against the same database as the parent query.

Audit rows are written to the instance where the change was made, not to a central
table. `AuditService.EnsureSchemaAsync` checks every instance at startup and reports
how many are ready.

## Configuration

`Oracle:Instances` defines the nine databases. Connection strings in the tracked
appsettings files contain a `{PASSWORD}` token and **no real credentials** — supply
passwords out of band:

All seven instances connect as the same `accutrack` account, so one secret covers
them all. Following the EWIS convention, it can be base64 in the environment file:

```jsonc
// appsettings.Dev.json
"Oracle": { "DefaultPasswordBase64": "<base64 of the password>" }
```

or supplied out of band, which keeps it out of the repo entirely:

```
dotnet user-secrets set "Oracle:DefaultPasswordBase64" "<base64>"
Oracle__DefaultPasswordBase64=<base64>          # environment variable
Oracle__DefaultPassword=<plain>                 # plain, if you prefer
```

Resolution order, most specific first:

1. `Oracle:Instances:<NAME>:Password`
2. `Oracle:Instances:<NAME>:PasswordBase64`
3. `Oracle:DefaultPassword`
4. `Oracle:DefaultPasswordBase64`

Startup fails fast, naming the instance, if a `{PASSWORD}` token has nothing to
satisfy it.

> Base64 is encoding, not encryption — anyone with the file can decode it in one
> command. A real value in `appsettings.Dev.json` gets committed, which is how the
> EWIS credentials ended up in git. User-secrets or an environment variable avoids
> that with no change to how the app reads it.

or by environment variable:

```
Oracle__Instances__CORP__Password=<password>
```

Startup fails fast if an instance has a `{PASSWORD}` token with no password
configured, rather than serving a partially working API.

## Running

```
dotnet run --launch-profile https --project EWT.Api
```

Ports are 5282 (http) and 7268 (https), chosen to avoid colliding with the EWIS API
on 5182/7168 so both can run at once.

## Schema discovery

The EDM model comes from a metadata cache, `tables.json`. It is not in the repo yet —
the first run against a reachable database generates it:

1. Set the password (above).
2. Start the API. With no cache present it reads the Oracle data dictionary from
   `Oracle:ModelSourceInstance` (`CORP`) and writes `tables.json`.
3. The startup log prints the exact path it wrote to. **That path is the build output
   directory**, not the project folder, so copy it back to keep it:

   ```
   cp EWT.Api/bin/Debug/net8.0/tables.json EWT.Api/tables.json
   ```

4. Commit it. Later runs load the cache instead of querying Oracle, so startup no
   longer depends on the database being up.

`POST /admin/refresh-cache` rebuilds it from Oracle on demand, which is what you want
after a schema change. One cache serves every database, since the daughters share
CORP's schema.

## Relationships

`relationships.json` drives `$expand` and is maintained separately (by the GUI-side
agent), not generated from Oracle foreign keys. It ships empty, so `$expand` has no
options until it is populated:

```
GET    /admin/relationships                    current set, grouped by table
POST   /admin/relationships                    add one, persisted to relationships.json
DELETE /admin/relationships/{table}/{name}     remove one
```

A POST body needs `name`, `fromTable`, `fromColumn`, `toTable`, `toColumn` and
optionally `type`; the endpoint returns a worked example if any are missing.

## Before this is usable

- No `tables.json` yet — see Schema discovery above.
- `relationships.json` is empty; the EWIS relationships did not carry over.
- Two daughters are missing: the brief was eight, the Web.config list yielded six.
- Dev is fully configured and its listeners are reachable, but no login has been
  attempted — set the `accutrack` password via user-secrets to finish.
- Test and Prod still hold **unverified** alias-form connection strings (`_TST`,
  `_PRD`), guessed from the Dev naming pattern. Replace them with inlined descriptors
  once those tnsnames entries are known.
