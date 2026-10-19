# Re: Impersonation handoff — API team reply

**From:** EWT-API → EWT-UI
**Re:** `API-HANDOFF-Impersonation.md` §7

Short version: we can build it on our **existing C# MSAL plumbing** (no Python port needed) — but the whole thing is gated on a **new server-side Graph credential + IT Security consent** that doesn't exist yet. Answers below.

## §7 answers
1. **App reg:** proposing a **dedicated** `EWT Impersonation (dev/test)` app-only registration per env, granted only the two Graph perms — *not* reusing the SPA/API app reg (that would over-grant the front-end app). **Consent not yet granted.**
2. **Cert or secret / who consents:** **certificate** (record expiry, fails closed on lapse). Admin consent is **IT Security / Entra-admin** — request initiated; the API team can't self-approve a tenant-wide directory-read grant.
3. **User-direct or group-based:** **TBD** — we'll confirm via Graph once creds exist. If you already know from the portal, tell us; it changes whether we expand `transitiveMembers`.
4. **Env-gating:** `/api/dev/*` behind a server-side config flag (same pattern as our `Audit:*` settings), **fail-closed** if unset, **404 in prod**. These endpoints will **require a valid bearer token** — they won't inherit the temporarily-disabled OData `[Authorize]`.
5. **SP object id per env:** we'll resolve via `servicePrincipals(appId='<clientId>')` (dev `55e229b7…`, test `7048b9dd…`) and publish the dev/test SP object ids back to you.

## Response shape
§1 shape accepted as-is — wire against it. One implementation note: we'll match on **`mail` OR `userPrincipalName`** (`$filter`), not `/users/{email}` (that resolves UPN/id only and 404s when `mail` ≠ UPN). So the returned `email` may be the UPN. Field names are fine; flag if that matters.

## Convergence with the new audit trail
The dual-actor / act-as piece (§1 future, §5) lands on our new `EWT_API_AUDIT` seam: `OWNER_USER` carries the impersonator, and we'll add an impersonated-target field to `EVENT_JSON`. Let's not build a second audit path.

## Critical path / dependency
Blocked on: dedicated Graph app reg → **cert** → **IT Security admin consent** for `Application.Read.All` + `User.ReadBasic.All`. Your role-set toggle keeps you unblocked meanwhile; we'll stand up `/api/dev/effective-roles` against the same `effectiveRoles` seam the moment the credential clears.
