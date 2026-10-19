# TA is a schema and we have no grant on it. DOC_CTRL is not here at all.

**From:** the API side (`C:\essource\ewt-api`)
**Date:** 2026-09-24
**Answering:** your cause-and-fix table for the 54 missing objects
**Audience:** the UI/spec side

Your diagnosis of the cause is right: those objects are in other schemas and the catalogue
only asks for what accutrack owns. We built the wider catalogue you proposed, **ran it, and
it found nothing**, so we have taken it back out. `OWNER = USER` stands.

The conclusion is one level up from config: **accutrack cannot see those objects at all, so
reaching them means connecting as a different Oracle user.** That is a connection and access
decision, not a catalogue setting, and it is not ours to make.

Your third row is confirmed exactly as you wrote it.

---

## 1. What we tried, and then reverted

We made the catalogue able to include objects in other schemas the account has privileges on,
ran a discovery pass over all seven databases with no owner filter, and then removed the
feature once the result was in. The query is back to:

```sql
WHERE OWNER = NVL(:schemaFilter, USER)
```

No config switch was left behind. The experiment is recorded here rather than in the code,
because a setting nobody should turn on is worse than no setting.

## 2. What the discovery pass found, which is why

Discovery run against all seven DEV databases, no owner filter, so every non-Oracle schema
accutrack can see:

```
CORP    no granted objects in other schemas
BASC    no granted objects in other schemas
BRON    no granted objects in other schemas
EWTN    no granted objects in other schemas
MEMTN   no granted objects in other schemas
BCTN    added 5 from ADMIN-SEGEARY, DPA, JDELK
CLUT    added 6 from ADMIN-SEGEARY
```

**Zero `TA_*`. Zero `DOC_CTRL`.** On any instance.

The 11 it did find are developer scratch tables, which is the second reason the feature came
back out:

```
JDELK           BU_UNRECON_CNTNR_MOVE_20161230    JD_CDTI    JD_GSPEC_CHECK
DPA             DBF_PLAN_TABLE
ADMIN-SEGEARY   ORDERS   BU_CONTAINERS_121516   TBL_BATCHES   TBL_BATCH_DAUGHTERS
                TBL_DISPOSE_LLRW_SHIPMENTS   TBL_LOCATION_MAPPING   TBL_REVENUE_CONTAINERS
```

Backup tables, an explain-plan table, and personal working tables. Nothing that belongs in a
catalogue, and everything that would creep into one: with the filter widened, the entity sets
a screen sees depend on what someone last left in their own schema.

## 3. The dictionary queries, run

We got them run against all seven DEV databases. Here is what the dictionary says.

**`TA` is a schema, and it exists.** Not `TA_` as a prefix on accutrack objects: a user named
`TA`, created 2015-08-10, present on **CORP, BCTN and BASC** and absent from CLUT, EWTN, BRON
and MEMTN. That matches a time-and-attendance system deployed at some sites and not others.

Against that schema, from accutrack:

| Query | Result on every instance |
|---|---|
| `all_objects` where name like `TA\_%` | **no rows** |
| `all_synonyms` where name like `TA\_%` | **no rows** |
| `all_tab_privs` to ACCUTRACK on any non-Oracle schema | **no rows** |

`TA1000_USER` and `TA1000_ADMIN` do not exist as accounts. So there is no grant and no
synonym: accutrack cannot see a single object in the `TA` schema. **Your read was right,
TA1000 needs a different Oracle user**, and the schema it needs is `TA` on the three
instances that have it.

**`DOC_CTRL` is not a schema here at all**, and this one did not go the way we expected:

- No `DOC_CTRL` user on any of the seven databases.
- No object owned by `DOC_CTRL` anywhere.
- **No database link to anything document-control.** The only links visible are the six
  sibling AT databases, EWIS DEV/TEST/PROD, and HIS20/HIS20BC.
- The bare names do not exist under accutrack either. We checked `DCN`, `DISTR_LIST`, `DOCS`,
  `RCVRS`, `SUPERCEDE`, `TRANS_DETAIL` and `TRANS_RECPT` against all seven catalogues: none of
  them, and no accutrack object containing `DCN`, `RCVR`, `SUPERCEDE`, `TRANS_DETAIL` or
  `TRANS_RECPT`.

So the seven `DOC_CTRL.*` references point at a schema that is not present in DEV and is not
reachable from it. Either document control lives in a database nobody has connected these to,
or that form is outside EWT's scope. It is not a permissions problem and no config on our
side reaches it.

**What this means for each group:**

| | Next step |
|---|---|
| `TA_*` (20) | An access decision: connect as `TA` on CORP, BCTN and BASC, or grant accutrack `SELECT` plus the writes TA1000 needs. Either is a change on our side once somebody with the authority decides EWT may read time-and-attendance data. |
| `DOC_CTRL.*` (7) | Find out where document control actually lives before anyone plans that screen. Nothing on these seven databases can serve it. |

One aside from the link list, since it touches the naming question: the public links are still
named `ATCAN.ENERGYSOLUTIONS.COM`. Oracle's own object names keep `CAN`, exactly as the TNS
alias and SID do. `BRON` is the instance code we serve; it was never going to change what
Oracle calls its own links.

## 4. Your third row is confirmed

`AT_OVERPACK_MASTERS` and `AT_OVERPACK_DETAILS` do not exist on any instance.
`AT_OVERPACK_MASTERS_VIEW` and `AT_OVERPACK_DETAILS_VIEW` do, owned by ACCUTRACK, on all
seven, already catalogued, and Oracle permits insert, update and delete on both. The forms
name the base tables; only the views are real. Nothing needed, exactly as you said.

## 5. Where that leaves the 54

| Group | Count | Status |
|---|---:|---|
| `TA_*` | 20 | the `TA` schema exists on CORP, BCTN and BASC; accutrack has no grant on it. Needs a different Oracle user or a grant. |
| `DOC_CTRL.*` | 7 | no such schema, no such objects, no link to one. Not present in DEV. |
| `AT_OVERPACK_MASTERS` / `_DETAILS` | 2 | not real; use the `_VIEW` versions, already exposed |
| Oracle dictionary (`DBA_ROLE_PRIVS`, `USER_ROLE_PRIVS`, `V$DATABASE`) | 3 | deliberately not exposed |
| remainder | 22 | not investigated on either side yet |

The 22 have not been looked at by us. If any of them matter for a screen you are about to
build, say which and we will check whether they are the same grant question or something
else.

## 6. Both directions

Ours, unverified:

- We assume the developer schemas above are not wanted. If `ADMIN-SEGEARY.TBL_*` turns out to
  back a real screen, say so and we will reopen this deliberately for that one owner.
- Still outstanding from our last document: `ORA-00054` has never been observed firing, so
  the lock-wait behaviour is reasoned rather than seen.
