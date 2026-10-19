# Locks and saves must work like the legacy: edit sessions

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-09-30
**Decision behind it:** Bruce, 30 Sep: *"Locks/saves should, sadly, work like legacy."* He chose this
over refusing at Save.
**Audience:** the API side
**Builds on:** `DynamicDataService.Locking.cs` (lock before write, bounded wait, 409
`RowLockedByAnotherUser`), `.Concurrency.cs` (If-Match on MODIFIED_DT, 412), `BatchController`
(change sets), and `API-HANDOFF-Lock-Test-Offer.md` (24 Sep).

## What the legacy does (standard Forms; every EWT block uses the default Lock Mode)

1. **On the first change to a queried record** (the first keystroke in a base-table item), Forms re-reads
   the row and compares it to what was queried. It compares **every queried column, not a timestamp**.
   If anything differs: *FRM-40654: Record has been updated by another user. Re-query to see change.*
2. Then `SELECT ... FOR UPDATE NOWAIT`. If another session holds the row, Forms retries and asks whether
   to keep trying, then gives *FRM-40501: ORACLE error: unable to reserve record for update or delete.*
   The second user is stopped **at the keystroke**, not at Save.
3. **The lock is held until Save or Clear.** That can be minutes or hours.
4. **Save is one transaction for the whole screen**: every block's deletes, updates and inserts together.
   A failure rolls all of it back, and the records stay changed on screen.
5. If the session dies (the applet closes, the network drops), Oracle rolls back and the locks go.

## What exists, and the gap

- The API takes a row lock **at write time**, with a bounded wait, and answers 409 if Forms holds it.
  That protects the API from Forms.
- `$batch` change sets give the one-transaction save. **The UI now saves every screen as one change set
  (`atomicityGroup: "save"`)**, as of 30 Sep.
- **The gap:** nothing holds a lock **between requests**. So a new-app user cannot hold a row against a
  Forms user or another new-app user while editing. They are stopped at Save, where the legacy stops
  them at the keystroke. And the 63 tables without MODIFIED_DT cannot detect a concurrent change at all;
  Forms' compare-every-column rule would cover them.

## What is asked: an edit session per editing screen

A server-side database session the client can come back to, holding one Oracle connection with an
open transaction. Suggested shape; yours to change:

| Call | Does |
|---|---|
| `POST /odata/$session?db=X` | Opens a session: a dedicated connection and a transaction. Returns `{ sessionId, idleTimeoutSeconds }`. |
| `POST /odata/$session/{id}/lock` | Locks one row. The body is `{ "url": "/odata/ENTITY?db=X&$filter=...", "original": { COL: value, ... } }`, with the row addressed as a batch DELETE addresses it. In the session's transaction, it reads the row `FOR UPDATE NOWAIT` and compares every column in `original` (NULL-safe; dates as dates). **200** locked. **409 `RowLockedByAnotherUser`**: someone holds it (FRM-40501). **412 `RowChangedByAnother`**: it differs, with the current row attached (FRM-40654). **404**: gone. |
| `$batch`, `PATCH`, `POST`, `DELETE`, `POST /odata/proc/...` with header `X-Edit-Session: {id}` | Run **on the session's connection, inside its transaction**. The rows are already locked, so no wait. EWT_UI procedures (for example `EWT_UI.AT5132_POST_UPDATE`) join the same transaction. |
| `POST /odata/$session/{id}/commit` | COMMIT; the locks go. The session stays open for the next edit, as a Forms session does. Or let a `$batch` sent with the header commit at its end: whichever is simpler. |
| `POST /odata/$session/{id}/rollback` | ROLLBACK; the locks go. The UI calls it on Clear, Clear Block, Exit, leaving the screen and sign-out. |
| `DELETE /odata/$session/{id}` | Roll back and close the connection. The UI sends it with `navigator.sendBeacon` when the tab closes. |
| `POST /odata/$session/{id}/ping` | Keep-alive. The UI pings every 60 s while the session holds locks. |

**Idle timeout.** A web tab can vanish without a word, which an applet could not. A session that has not
been pinged for a while is rolled back and closed. The suggestion is **900 s**, the same as the
workstation inactivity lock (screen-lock policy), so a lock never outlives a locked screen. Bruce's call.

**Binding.** A session belongs to the user who opened it (the signed-in identity; the Entra stub for now),
and only that user may use it. One `?db=` per session, as a change set is.

**Capacity.** One connection per screen currently holding edits: roughly the number of people typing at
once, not the number signed in. The UI opens a session only on the first change and closes it at
commit or rollback, if you would rather not keep it open between edits.

**Messages.** Keep the codes you already return (`RowLockedByAnotherUser`, `RowChangedByAnother`). The UI
maps them to the Forms wording.

## What the UI does with it (built once the routes exist)

- The first change to a fetched record calls `/lock` with the record's queried values.
  - On 409, the change is undone, and FRM-40501 is shown with a Retry.
  - On 412, the change is undone and FRM-40654 is shown.
  - Later changes to the same record do not lock again.
- Save sends the one change set with `X-Edit-Session`. The session commits, and the locks go.
- Clear, Exit, leaving, sign-out and tab close roll back and release.
- The If-Match guard stays for anything written without a session.

## Testing

The 24 Sep offer still stands: hold a Forms lock on a DEV row you name, and check both directions. It
needs Bruce's go, as it types into a live DEV record, uncommitted.
