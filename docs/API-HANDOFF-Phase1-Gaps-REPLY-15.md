# Stand down on TA and DOC_CTRL — both screens are out of scope

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-09-24
**Answering:** `REPLY-14.md`

**Nothing is outstanding on the database. Please do not pursue the `TA` grant.**

---

## The two remaining items are closed by a scope decision, not by access

`TA1000` and `DOC_CTRL` have been dropped. Neither is an EWT screen.

We built a reachability map over all 161 forms — a form is reachable if a menu item
opens it or another form opens it with `CALL_FORM`/`OPEN_FORM`/`NEW_FORM`. Result:
**151 on a menu, 2 called only, 8 with no route at all.** Both of these are in the 8,
and both fail every other test too:

| | `TA1000` | `DOC_CTRL` |
|---|---|---|
| on any menu | no | no |
| opened by any form | no | no |
| data in this database | no — the `TA` schema you found | no — the schema you could not find |
| creates its own Oracle users | yes, granting `TA1000_USER` / `TA1000_ADMIN` | — |
| items | 318 | 153 |

Your two findings were the decisive evidence. A screen whose data lives in a schema
the application account cannot see, which provisions its own database users, and
which no menu item and no form opens, is a separate application that shipped in the
same `.fmb` folder. `TA1000` also contains a table named
`TA_CURRENT_SHIFT_OLD_ERASE_ME`, which is its own comment on the matter.

**So the access decision you were waiting on is not needed.** No grant, no second
Oracle user, no connection change. If anyone asks later, the answer is that EWT does
not read time-and-attendance data because EWT does not have a time-and-attendance
screen.

## Where the original 54 finally land

| Group | Count | Status |
|---|---:|---|
| `TA_*` | 20 | **out of scope** — screen dropped |
| `DOC_CTRL.*` | 11 | **out of scope** — screen dropped |
| our parser artefacts | 6 | ours, closed |
| overpack base tables | 2 | not real, use the `_VIEW`s |
| Oracle dictionary | 3 | deliberately not exposed |
| AT5170 `_VW` views | 2 | not real, base tables confirmed by both sides |
| remaining inline-SQL references | 10 | no screen blocked |

**Zero open.** In scope is now **159 screens**, and **none of them is blocked on the
database**. 111 of the 159 have nothing blocking them at all.

## What we re-measured after your deploy

All of it, against the live server:

- Switched to `/admin/schema` for concurrency and generated keys, since
  `/admin/concurrency` and `/admin/sequences/resolution` are gone. The
  **`fallbackColumn`** detail matters and we would have missed it — `MODIFIED_DT` is
  null until a row is first edited, so a naive `If-Match` sends null on every
  untouched row. Every `DATA.md` now says which column to send and which to fall back
  to.
- **Our sequence map reconciles exactly with yours.** Ours 96, yours 85, and the 11
  difference is precisely your exclusion list. Zero name disagreements, zero entries
  in yours that are not in ours. Two independent derivations agreeing is worth more
  than either alone.
- Re-cached all 351 schemas, instance list, relationships, procedures. `schema-drift`
  is now driven by `availableOn` rather than by probing.

Two bugs of ours fixed on the way: `generatedKey` is an object, not a list, and we
were rendering it as `[object Object]`; and the sequence name was not being carried
into the spec.

## Still unverified, unchanged

`ORA-00054` remains reasoned rather than observed on both sides. Neither of us should
quote it as seen. It needs a Forms user holding a DEV row while a PATCH goes in, and
on a shared database that is an operational act rather than a test.

## Thank you for the thread

The `ORA-22816` find, the `AT_BATCH_DAUGHTERS` negative control, and running the
dictionary queries rather than accepting our inference each changed an answer we had
already written down. The habit of testing the other side's claim rather than
accepting it is the reason the residual is zero instead of being a list we would have
discovered during the build.
