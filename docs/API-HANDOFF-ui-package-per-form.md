# EWT_UI is now one file per form, and you can CRUD them over the API

**From:** the API side (`C:\essource\ewt-api`)
**Date:** 2026-10-19
**Audience:** the UI/spec side
**Short version:** `EWT_UI.sql` is split into 60 files, one per form. You edit one form; the API
reassembles all 60 into the single `EWT_UI` package and compiles it. Nothing about how you
*call* the procedures changes. The one rule you must follow: **every procedure in `AT5510.sql`
must be named `at5510_<something>`**, and the API refuses the file otherwise.

---

## Why

One 350 KB file meant two people editing two different screens still collided, and a bad edit
anywhere made the whole package INVALID on all seven instances. Now a form is a file.

It is still **one Oracle package**. `EWT_UI.AT5510_SET_LOCATION` is called exactly as before.
A package per form was considered and rejected: 60 packages times 7 instances is not something
anyone should have to reason about.

## The layout

```
OurPackages/ewt_ui/
  _frame.sql        the package header, CREATE OR REPLACE lines and slash lines. Not yours.
  _manifest.json    assembly order
  _COMMON.sql       shared helpers that belong to no form (today: rule_error)
  AT1310.sql        one per form: 49 AT forms, 10 WB forms
  AT5510.sql
  ...
```

A fragment is two marked sections and nothing else:

```sql
-- EWT_UI fragment: AT5510
--#SPEC
  PROCEDURE at5510_set_location(p_outshipmt_seq_id IN NUMBER, ...);
--#BODY
  PROCEDURE at5510_set_location(p_outshipmt_seq_id IN NUMBER, ...) IS
  BEGIN
    ...
  END at5510_set_location;
```

- `--#SPEC` holds what goes in the package spec. `--#BODY` holds the definitions.
- **No `CREATE OR REPLACE`, no `/` lines, no `END ewt_ui;`.** `_frame.sql` supplies those.
- Anything above the first marker is a comment and is kept.

## The calls

All under `/admin/ui-package`. They need `Packages:AllowRuntimeDeploy`, which is **on at Dev
and off everywhere else**.

| Operation | Call | What it does |
|---|---|---|
| `ListUiPackageForms` | `GET /admin/ui-package/forms` | every form, in assembly order, with its procedure counts |
| `GetUiPackageForm` | `GET /admin/ui-package/forms/{FORM}` | that form's file, as plain text |
| `PutUiPackageForm` | `PUT /admin/ui-package/forms/{FORM}` | replaces it; creates it if new |
| `DeleteUiPackageForm` | `DELETE /admin/ui-package/forms/{FORM}` | removes it from the next assembly |
| `GetUiPackageAssembled` | `GET /admin/ui-package/assembled` | all 60 concatenated: exactly what a deploy compiles |
| `DeployUiPackage` | `POST /admin/ui-package/deploy?db=` | reassembles and compiles. `?db=` is required |
| `GetUiPackage` | `GET /admin/ui-package` | where the package stands on all seven instances |

### The loop

```bash
# take the form you are working on
curl "http://localhost:5282/admin/ui-package/forms/AT5510" > AT5510.sql

# edit it, then put it back. This validates and saves; it touches no database.
curl -X PUT "http://localhost:5282/admin/ui-package/forms/AT5510" \
     -H "Content-Type: text/plain" --data-binary @AT5510.sql

# compile all 60 onto one instance
curl -X POST "http://localhost:5282/admin/ui-package/deploy?db=BCTN"

# call what you changed
curl -X POST "http://localhost:5282/odata/proc/EWT_UI.AT5510_SET_LOCATION?db=BCTN" \
     -H "Content-Type: application/json" -d '{"P_OUTSHIPMT_SEQ_ID": 4211}'

# happy: put it on the rest
curl -X POST "http://localhost:5282/admin/ui-package/deploy?db=all"
```

`PUT` and `DEPLOY` are separate on purpose. A put saves the file; a deploy compiles every
form. So you can stage several forms and deploy once, and a put that turns out wrong has not
touched a database.

## The prefix rule, which is the thing to get right

**Every procedure in `{FORM}.sql` must begin with `{form}_`, lower case.** `AT5510.sql` may
only contain `at5510_*`. This is not style: it is how a form owns its procedures, how the
original split decided where all 168 went, and what stops two forms defining the same name and
one silently winning at assembly.

`_COMMON.sql` is the single exemption, for helpers that belong to no form.

**The API enforces it.** A `PUT` that breaks it is a 400 and nothing is written:

```json
{ "error": { "code": "FragmentRejected",
  "message": "Every procedure in AT3250 must be named at3250_<something>. These are not:
              helper_thing. A shared helper that belongs to no form goes in _COMMON instead." } }
```

It checks the names of every top-level `PROCEDURE`/`FUNCTION` in both sections, so a single
stray one in a file of twenty is named back to you.

### For your generators

`contract.cjs --lov-sql` and `block-package.cjs` currently write into the one big file between
markers. They now need to write one file per form. Both already know the form, since it is in
every procedure name they emit (`at1310_lov_*`, `at5510_w_*`), so the change is where the
output goes, not what it contains. Two things to build in:

1. **Derive the filename from the prefix, not the other way round.** Group the procedures you
   generate by their `at####`/`wb####` prefix and write each group to that form's file. Then
   the rule holds by construction and the API never has to reject anything.
2. **A procedure with no form prefix is a bug in the generator.** If you produce one, it has
   nowhere to live. Fail your own build rather than writing it to `_COMMON`: `_COMMON` is for
   hand-written shared helpers, and a generator putting things there will produce collisions
   nobody notices.

Names are still capped at 30 characters by Oracle, as now.

## Two more things the API will refuse

- **Declared but not defined.** A procedure under `--#SPEC` with no match under `--#BODY` is
  rejected by name. Oracle would otherwise report PLS-00323 against the whole package, which
  tells you nothing about which form caused it.
- **`CREATE OR REPLACE` or a `/` line in the code.** Those belong to the frame. Comments
  mentioning them are fine; the check ignores comments.

A compile failure at deploy still returns `USER_ERRORS` in the response, with type, line and
position, per instance.

## What we verified before handing this over

- The split is **lossless**: the 60 fragments plus the frame contain exactly the characters of
  the original file, no more and no less, with the same 168 spec declarations and 176 body
  definitions. `scripts/verify-ewt-ui-split.py` checks this without a database.
- Reassembly is **not** byte-identical to the old file, and cannot be: the original interleaved
  forms, so grouping by form reorders. What matters is that order is still legal, and it is:
  only 8 procedures are body-private and order-sensitive, 7 are called only from their own
  fragment, and the eighth, `rule_error`, is in `_COMMON`, which the manifest pins first.
- The assembled package **compiles clean on all seven instances**, reports 168 procedures, and
  all 68 generated query blocks still run on BCTN.
- A restart with the fragments unchanged issues **no DDL**, so nothing hits ORA-04068.

## What has not changed

How you call a procedure, the names, the signatures, `/odata/proc`, and the `where=` registry.
`db=` is still the parameter on `/odata/proc`, not `instance=`.
