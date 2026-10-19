# OurPackages

PL/SQL packages that belong to the API, not to the legacy application.

A package of ours and the `EWT_API_AUDIT` table are the only two permitted additions to this
schema. Everything else in these databases belongs to the legacy Oracle Forms application,
which is still running against them, and is not ours to change.

## The contract

**EWT_UI is assembled from `ewt_ui/`, one file per form.** See "Iterating without a restart"
below and `docs/API-HANDOFF-ui-package-per-form.md`. The single-file `EWT_UI.sql` was deleted
on 2026-10-19; `scripts/assemble-ewt-ui.py` regenerates an equivalent whenever one is wanted.

For any other package, one `.sql` file per package. Put the spec and the body in the same file, separated the way
SQL*Plus separates them, with a line containing only a slash:

```sql
CREATE OR REPLACE PACKAGE EWT_API_EXAMPLE AS
  FUNCTION something(p_id IN NUMBER) RETURN VARCHAR2;
END EWT_API_EXAMPLE;
/
CREATE OR REPLACE PACKAGE BODY EWT_API_EXAMPLE AS
  FUNCTION something(p_id IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN NULL;
  END;
END EWT_API_EXAMPLE;
/
```

The package name is read from the source, so the filename is only a label. Use
`CREATE OR REPLACE` so a redeploy is not a drop.

**This directory is the source of truth.** A database that disagrees with it is reported as
drifted, not treated as correct.

## What happens at startup

For every file here, on every one of the seven instances, the API checks:

| | |
|---|---|
| present | is the package there at all |
| valid | `USER_OBJECTS.STATUS`, because a package can exist and still throw |
| current | a whitespace-insensitive fingerprint of the source on the database against this file |

and then compares the instances against each other. That last check is the one worth having:
a package can be present and valid on all seven and still be **three different versions**,
which nothing else would report and which makes the same call behave differently depending on
`?db=`.

## Deploying

Reporting is always on. Deploying is not:

```json
"Packages": { "Verify": true, "AutoDeploy": false }
```

`AutoDeploy` issues `CREATE OR REPLACE` where a package is missing or differs from the file.

**On for Dev, off for Test and Prod.** It is safe to leave on only because the fingerprint is
taken the way Oracle stores the source: a restart with everything already current deploys
nothing, so no session holding package state is handed ORA-04068. Before that was true, every
restart was a redeploy. Where it is off, the log names the file to run by hand and on which
instance.

Elsewhere it stays off. A package change to a database the legacy application is using should
go through the same control as any other release, not happen as a side effect of a restart.

This mirrors `Audit:AutoCreate`, which governs the audit table the same way.

## Iterating without a restart

A restart reloads metadata for seven instances before the API answers anything, which is too
slow a loop when the package changes several times a day. Three operations do the same job
against a running server:

| Operation | Route | What it does |
|---|---|---|
| `GetUiPackage` | `GET /admin/ui-package` | with no `?db=`, where EWT_UI stands on all seven; with `?db=BCTN`, the package as that instance holds it |
| `UpdateUiPackage` | `PUT /admin/ui-package` | replaces `OurPackages/EWT_UI.sql` on the server |
| `DeployUiPackage` | `POST /admin/ui-package/deploy?db=` | compiles it onto one instance or all seven |

They need:

```json
"Packages": { "Verify": true, "AutoDeploy": true, "AllowRuntimeDeploy": true }
```

`AllowRuntimeDeploy` is **Dev only and false unless set**. It compiles PL/SQL into the
database, so treat it as what it is.

### Update and deploy are deliberately different

- **Deploy** puts PL/SQL on a database. It is undone by the next restart, because AutoDeploy
  puts the shipped file back.
- **Update** changes what this server believes the package should be: the thing `matchesFile`
  is measured against, and the thing a restart restores.

So you can try something on one instance without claiming it is the truth, and claim it
separately once it works. `UpdateUiPackage` keeps the previous file beside it with a
timestamp, because that file is checked in: copy the new version into the repo when you are
happy with it.

### The loop

```bash
# what is on BCTN right now
curl "http://localhost:5282/admin/ui-package?db=BCTN&runnable=true" > work.sql

# edit work.sql, then compile it on BCTN only
curl -X POST "http://localhost:5282/admin/ui-package/deploy?db=BCTN" \
     -H "Content-Type: text/plain" --data-binary @work.sql

# run what you just changed
curl -X POST "http://localhost:5282/odata/proc/EWT_UI.MY_PROC?db=BCTN" \
     -H "Content-Type: application/json" -d '{"P_ID": 4211}'

# happy with it: make it the version this server ships
curl -X PUT "http://localhost:5282/admin/ui-package" \
     -H "Content-Type: text/plain" --data-binary @work.sql

# and put it on the rest
curl -X POST "http://localhost:5282/admin/ui-package/deploy?db=all"

# or abandon it: redeploy the shipped file, no body
curl -X POST "http://localhost:5282/admin/ui-package/deploy?db=BCTN"
```

A deploy that does not compile returns **USER_ERRORS in the response**, with type, line and
position, so the reason is not chased through the server log:

```json
{ "ok": false, "results": [ { "instance": "BCTN", "invalid": true,
  "summary": "4 compile error(s), first at PACKAGE BODY line 5: PL/SQL: ORA-00933...",
  "errors": [ { "type": "PACKAGE BODY", "line": 5, "position": 7,
                "text": "PL/SQL: ORA-00933: SQL command not properly ended" } ] } ] }
```

### What it will not do

- **EWT_UI only.** These routes name it; nothing here reaches a legacy `ACCUTRACK` package.
- **The instance is always named** on a deploy. No default, and `?db=all` must be spelled out.
  On this estate a request that guessed its database has already gone wrong once.
- **A deploy does not change the file.** Only `UpdateUiPackage` does. `matchesFile` in
  `GetUiPackage` is how you see you have drifted.
