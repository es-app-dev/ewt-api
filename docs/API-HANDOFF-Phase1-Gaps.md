# Handoff: what the UI needs from the API for phase 1

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-09-23
**Audience:** whoever is working on `ewt-api`

Every number here was measured against **your live Dev API** plus the JDAPI dumps
of all 161 Oracle Forms modules. Nothing is estimated. The commands that produced
each figure are in `ewt-ui/scripts/jdapi/`.

There is now a per-screen data contract at
`ewt-ui/rules/screens/<FORM>/DATA.md` — every block expressed as the exact OData
call, checked against `/admin/schema`. `ewt-ui/analysis/jdapi/DATA-INDEX.md`
summarises all 161. **77 of 161 screens have nothing blocking them.** This
document is the other 84.

**We are not changing the database.** No new tables, no altered procedures. An
audit table and one package of our own are the only permitted additions — your
`AuditService` is already exactly within that line.

---

## 1. Assign the primary key on POST — blocks 82 of 161 screens

Your `docs/OData-PATCH-Guide-for-UI.md` already names this:

> *"If the table uses an Oracle sequence for ID... The API does not auto-generate
> sequence values — it passes exactly what you send."*

The legacy forms allocate their own keys in `PRE-INSERT`
(`:BLOCK.PK := SOME_SEQ.NEXTVAL`) — **178 references, 101 sequences, 82 of 161
forms**. Until the server assigns them, none of those screens can create a row.

**Please do not add `GET /odata/seq/{name}`.** It hands the client a legacy
concept and is not how REST assigns keys. The standard behaviour: the client
POSTs without the key, the server fills it.

**Input, ready to use: `ewt-ui/analysis/api/sequence-map.json`**
96 `table.column -> sequence` pairs across 91 tables, derived from the forms and
then verified against your own `/admin/schema`:

| | |
|---|---:|
| sequence feeds the table's **sole primary key** — safe to auto-assign | **80** |
| part of a compound key — needs a decision | 4 |
| column is **not** the PK (a child creating its parent, e.g. `AT_CONTACTS.ADDR_SEQ_ID <- ADDR_SEQ`) — **do not auto-assign** | 4 |
| table declares no primary key at all — see section 3 | 8 |

Suggested behaviour, only for the 80:

```
POST /odata/{entitySet}?db={INSTANCE}
  → if the sole PK column is absent from the body and the table is in the map,
    populate it from that sequence
  → return the created entity including its key (Prefer: return=representation)
```

Returning the key matters: several forms need it to build child rows in the same
save.

---

## 2. The EDM is built from CORP, but 75 tables exist only on CORP

Your README says the daughters share CORP's schema, so the model is read once from
`Oracle:ModelSourceInstance`. **Half of that is right, and the half that is wrong
will produce silent empty results.**

Measured across all 7 instances, over the 277 tables the form blocks bind:

| | |
|---|---:|
| on CORP and every daughter, **columns identical** | 172 |
| columns differ between CORP and a daughter | **0** |
| **exist on CORP only — 404 on every daughter** | **75** |
| exist on a daughter but not CORP | 0 |
| not found on any instance | 30 |

So the *column structure* is genuinely shared — your model-once approach is sound
there. What is not shared is **which tables exist**. The CORP-only 75 are the
master data, which matches the business: customers, contacts, contracts, price
sheets, product services, carriers, rental containers, and the waste profiles
(`AT_ESPROFILES` and friends).

The consequence for us: a screen reading `AT_CUSTOMERS` must send `?db=CORP`
**regardless of which site the user signed into**, and `$expand` cannot cross
from a site table to a CORP one. **14 screens span both databases** and have to
issue two requests and join client-side. We handle that; `DATA.md` now says per
block which instance holds it.

The consequence for you: the catalogue currently advertises all 1,585 entity sets
for every `?db=`, including the 75 that only exist on CORP. Either mark table
presence per instance in the model, or return something clearer than an empty
result set when a table is absent on the requested instance. An empty `value: []`
is indistinguishable from "no rows", which is the worst failure mode here.

Full detail: `ewt-ui/analysis/api/schema-drift.json`.

---

## 3. 123 of 348 tables declare no primary key — PATCH and DELETE cannot address them

`PATCH` takes the key in the body and `DELETE` takes it in the URL, so a table
with no declared PK cannot be addressed at all. **71 form blocks update or delete
such a table today.**

Concentrated in the child tables of the bigger screens — for AT1330 alone:
`AT_ESPROFILE_RAD`, `AT_ESPROFILE_EPA`, `AT_ESPROFILE_UHC`, `AT_ESPROFILE_OCC`,
`AT_ESPROFILE_OHC`, all updatable and deletable from the form.

These almost certainly have a unique index without a PK constraint, which is
ordinary in a schema of this age. Options that do not touch the database:

- expose unique-index columns alongside `isPrimaryKey` in `/admin/schema` and let
  `PATCH`/`DELETE` accept a unique key, or
- accept `ROWID` as the addressing key, or
- accept an arbitrary column set as the `WHERE` and reject when it matches ≠ 1 row.

Any of the three works for us. The third is the most standard-looking. **We would
rather you pick than guess on our behalf** — it affects how we write every
child-table save.

---

## 4. `$count`, then `$apply`

Neither is implemented, so these are real work rather than switches. Of 953
distinct aggregate/`DISTINCT` statements in the forms:

| Shape | Count | Standard form | Cost |
|---|---:|---|---|
| `COUNT(*)` | 303 | `$count=true` | **small — a wrapper on the filter translator you already have** |
| single aggregate | 319 | `$apply=aggregate(col with sum as x)` | medium |
| `DISTINCT` only | 116 | `$apply=groupby((col))` | medium |
| `GROUP BY` + aggregate | 32 | `$apply=groupby(…,aggregate(…))` | medium |
| several aggregates | 31 | `$apply=aggregate(a…,b…)` | medium |
| **standard-expressible** | **801 (84%)** | | |
| correlated subquery | 154 | none — phase 2/3 | |

`$count` first: cheapest of everything in this document, clears a third of the
category.

---

## 5. `$batch` with change sets — the atomicity gap

Not on anyone's list yet, and it will bite.

Forms commits a whole master-detail hierarchy as **one transaction**. AT3110 has
21 relations; saving a manifest writes the manifest, its materials, its containers
and their waste codes together. Split across independent HTTP calls, a failure
halfway leaves the row half-saved and the user finds out.

240 master-detail relations across the app, so this affects most screens with more
than one block. It is the largest item here and the one with the worst failure
mode if skipped.

---

## 6. Tables the forms need that the API does not expose

54 real objects, checked against all 7 instances. The notable groups:

| Group | Count | Note |
|---|---:|---|
| `TA_*` (`TA_EMPLOYEES`, `TA_SHIFTS`, `TA_EVENTS`, `TA_VIEW_*` …) | 19 | **the entire data layer of screen TA1000.** Likely a different schema/owner — is `accutrack` meant to see them? |
| `AT_OVERPACK_MASTERS`, `AT_OVERPACK_DETAILS` | 2 | used by the overpack workbenches |
| `AT_ADV_NOTIF_CONTACTS`, `AT_COMMENT_MATERIALS`, `AT_CONTACT_REPORTS` | 3 | |
| `AT_CNTNR_CHEMICALS_VW`, `AT_CNTNR_METALS_VW` | 2 | views |
| `WB_IBOX_DETAIL_PARENTS` | 1 | |
| `DBA_ROLE_PRIVS`, `USER_ROLE_PRIVS`, `V$DATABASE` | 3 | Oracle dictionary — deliberately not exposed, we will route around |

Full list: `ewt-ui/analysis/api/tables-missing.json`. Our best guess is a grant or
owner-filter question rather than missing objects, but we cannot tell from outside.

---

## 7. One integration question, not an API bug

The `AT_CP_PROF_*_REVIEW` tables (`_TS_`, `_EE_`, `_RSO_`, `_IH_`, `_OPS_`) come
back **read-only**, but AT1330's blocks allow insert, update and delete on them.

`CP` is **CustomerPortal**, which is the source of truth for waste profiles. So
read-only is probably correct and the legacy form is writing to something it
should not — or it writes through a path we have not found. **This needs a person
who knows the CustomerPortal integration, not a code change.** Flagging it rather
than guessing. 32 blocks across the app write to a read-only entity set; this
group is most of them.

---

## Order of value to us

1. **Key assignment on POST** — without it, 82 screens cannot create anything.
2. **A decision on no-PK tables** (section 3) — 71 blocks cannot save edits.
3. **`$batch`** — without it, master-detail screens can half-save.
4. **`$count`** — cheap, clears 303 statements.
5. **Instance-aware catalogue** (section 2) — we can work around it, but the
   silent-empty-result failure mode is dangerous.
6. `$apply` — clears another 498.

## Inputs, ready to use

| File (under `C:\essource\ewt-ui`) | What it is |
|---|---|
| `analysis/api/sequence-map.json` | 96 `table.column -> sequence`, verified against `/admin/schema` |
| `analysis/api/schema-drift.json` | CORP vs all 6 daughters, per table |
| `analysis/api/tables-missing.json` | the 54 not exposed anywhere |
| `analysis/jdapi/DATA-INDEX.md` | API readiness for all 161 screens |
| `rules/screens/<FORM>/DATA.md` | per screen: every block as an OData call |
| `rules/screens/<FORM>/SERVER.md` | per screen: procedures, sequences, inline SQL |
| `rules/common/API-CONTRACT.md` | the reasoning behind all of the above |

## One thing we are explicitly not asking for

**A raw SQL endpoint.** It would re-create the dependency the standard API exists
to break, and it is an arbitrary-query surface on an unauthenticated API over a
DEV database refreshed from production — real customer names, manifest history
back to 1998, `AT_SEG_STAFF.SSN_NBR`. The 84% figure in section 4 is the point:
most of what looks like it needs raw SQL is ordinary aggregation with a standard
spelling. When the last 154 come up, the answer is a server-side catalogue of
named parameterised queries, not SQL crossing the wire.
