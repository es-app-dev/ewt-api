# Mapping the current EWT UI to the new access model

For whoever is building the replacement UI and needs to map today's screens to
tomorrow's permissions. Written to be read start to finish once, then used as a lookup.

---

## 1. What a permission actually is

Every screen in the legacy Oracle Forms app is a **module** with a code like `AT1710`.
Each module has up to three Oracle roles:

```
AT1710_GUEST   view only
AT1710_OPER    day-to-day use
AT1710_ADMIN   full control including setup
```

`GUEST` / `OPER` / `ADMIN` is inferred from the naming convention, not stated anywhere in
the database. Treat it as strong convention, not gospel — it is flagged as inferred in
the catalogue.

So "can this person open the Invoices screen?" becomes "do they hold any of
`AT1710_GUEST|OPER|ADMIN`?", and "can they edit?" becomes "do they hold `_OPER` or
`_ADMIN`?".

## 2. Mapping a legacy screen to its permission

| You have | You want | Use |
|---|---|---|
| a form file `at1710_fmb.xml` | the module code | `FormModule Name="AT1710"` inside it |
| a module code | what it's for | `ewt-role-catalogue.csv` → `what_it_does` |
| a module code | which tables it touches | same file → `main_tables` |
| a module code | where it sits in the business | same file → `subsystem`, `area` |
| a role | who can do it | same file → `people_with_role` |

`analysis/ewt-role-catalogue.csv` is the lookup table for all of this — 252 roles, 232
with a maintained description, 198 with their tables, 78 with example button actions
pulled from the legacy forms.

```
role, module, privilege, what_it_means, what_it_does, example_use,
subsystem, area, main_tables, people_with_role, entra_group
```

Example row:

```
AT1710_ADMIN | Maintain Invoice Worksheet | e.g. Accept Shipment, Accept Barcodes
             | ACCOUNTING / INVOICING | AT_INVOICES, AT_INVOICE_LINE_ITEMS | 4 people
```

The 161 legacy forms are at `C:\essource\ewt-ui\legacy_XML`. Useful attributes:
`FormModule Name` (module code), `Title` (screen name), `QueryDataSourceName` (the table
behind each block), and `ItemType="Push Button"` + `Label` (the actions on screen).
Ignore `Comment` — it is 90% code-generator noise like `CGDV.C.AT_INVOICES.INVOICE_TYPE_CD`.

## 3. Deciding what a user can see

At runtime the API resolves a signed-in user to a set of Oracle roles (see
`ENTRA-INTEGRATION-DEV.md`). For the UI, the question is only ever:

```
canView(module)  = holds  AT<module>_GUEST | _OPER | _ADMIN
canEdit(module)  = holds  AT<module>_OPER  | _ADMIN
canAdmin(module) = holds  AT<module>_ADMIN
```

Do not hard-code group names. Groups are named `EWT-<Area>-<Level>` but those names are
generated and the business will rename them. Always resolve to **roles**, then to
module + privilege.

One group is not a permission at all: **`EWT-Users`** is the sign-in gate assigned to
the enterprise application. Everyone is in it and it carries zero roles. Never treat
membership of it as granting anything.

Groups are **flat** — 53 role groups, no nesting, every membership direct. A person's
access is simply the union of the groups they belong to, so `memberOf` is sufficient;
there is nothing to expand.

## 4. Data available through the API

The API is a dynamic OData layer over all 7 Oracle instances. Every table and view is
exposed — 1585 entities.

```
GET /odata/instances                     the 7 databases
GET /odata/{entitySet}?db=BRON           rows, any table
    &$select= &$filter= &$orderby= &$top= &$skip= &$expand=
GET /odata/{entitySet}({key})?db=BRON
GET /admin/schema/{tableName}            columns + available $expand options
GET /admin/relationships                 the $expand definitions
```

Notes that will save you time:

- **`db` is required in spirit.** Omitting it silently uses `CORP`. Always pass it.
- **`$top` caps at 10000.** Above that it truncates with no indication. Page with `$skip`.
- **`$expand` needs relationships defined.** `relationships.json` ships empty — it is
  hand-maintained, and populating it is the UI side's job. `POST /admin/relationships`
  with `{name, fromTable, fromColumn, toTable, toColumn, type}`.
- **Dates work now.** `$filter=ENTER_DATE gt 2024-09-16` — ISO literals are converted to
  Oracle `TO_DATE`. This was broken until recently; if you see `ORA-01861`, the API is
  out of date.
- **A bad column in `$filter` leaks the raw Oracle error** (`ORA-00904`). Known wart,
  not yet fixed.

## 5. Tables worth knowing

| Table | Why |
|---|---|
| `AT_SECURITY_MODULES` | module → subsystem / area / description. The business taxonomy |
| `AT_ACCUTRACK_USERS` | app user list. **`ACTIVE_FLAG` is `Y` for everyone — useless** |
| `AT_SEG_STAFF` | staff roster. `STATUS_CD` `A`/`I` **does** work. Also holds `SSN_NBR` |
| `AT_ROLE_PRIVS` | who holds which role. `GRANTEE` may be a user *or* a role — grants nest |
| `AT_MODULE_ACCESS` | usage log, `ENTER_DATE`. The only live activity source |
| `AT_LOGONS_LOG` | looks like the login log. **Dead since May 2016. Do not use** |

`AT_SEG_STAFF` contains `SSN_NBR`. It is empty in the rows sampled, but the column is
served by an API that currently has `[Authorize]` commented out. Do not surface that
table in any UI without checking.

## 6. Mapping current users to the new model

`analysis/entra-nested-assignments.csv` — one row per person:

```
username, first_name, last_name, email, employee_badge,
direct_group_count, direct_groups, direct_group_names, effective_role_count
```

To show "what will change for this person": their `effective_role_count` today is
exactly what they will have after migration. The model is verified to grant zero extra
and lose zero. If your mapping produces a different set, your mapping is wrong.

## 7. What is not covered

- **19 people on the admin's user list are in none of our 7 databases** — absent from
  `AT_ACCUTRACK_USERS`, `AT_ROLE_PRIVS` *and* `AT_MODULE_ACCESS` everywhere, yet active
  in `AT_SEG_STAFF` with real access counts on that spreadsheet. The instance list itself
  looks complete: `AT_CORP_CUST_SITES` names only the six daughters we are connected to
  (seven sites on six databases — Bear Creek and Gallaher Rd share `atbctn`). So these
  people are reaching EWT by some route this model does not describe. Unresolved.
- **Activity data is stale at 5 of 7 sites** (nothing since mid-2025). Anything
  usage-driven in the UI should say so rather than imply recency.
- **`relationships.json` is empty**, so `$expand` returns no options until populated.
