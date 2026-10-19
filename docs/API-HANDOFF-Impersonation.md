# Handoff to the EWT API — Impersonation support (email → Entra roles)

**From:** EWT-UI
**Purpose:** The UI is adding a **dev/test-only** impersonation feature so testers can exercise the app's Entra role gating (`User` / `Admin` / none) without a separate account per role. The UI has everything it needs *except one thing from you*: given an **email**, return that user's **EWT Entra app roles**. This document specifies exactly what to build.

**Read alongside:**
- `EWT-IMPERSONATION-SECURITY.md` (this repo) — the security design/controls.
- `C:\essource\SF_to_EBS_D2\teams_sfd2_app\SFD2_SECURITY.md` + `sfd2_service.py` — the proven client-credentials Graph pattern to copy (`_graph_token()` + `requests` GET). Same mechanics; **broader consent** (see §4).

---

## 1. What the UI needs (the ask)

**Required — one endpoint:**

### `GET /api/dev/effective-roles?email={email}`
Returns the user's EWT app roles as they'd appear in the token `roles` claim.

- **Auth:** requires a valid EWT bearer token (any authenticated user — dev/test only).
- **Environment:** **dev/test only.** In production this endpoint must not exist / must 404. Fail closed if the env flag is unset.
- **200 response:**
  ```json
  { "email": "jdoe@energysolutions.com", "objectId": "…", "displayName": "Jane Doe",
    "found": true, "roles": ["User"] }
  ```
- **User exists but has no EWT role:** `"found": true, "roles": []` (valid — the UI tests the "Not Authorized" path with it).
- **No such user:** `"found": false, "roles": []`.
- **Graph failure:** `502`. **Wrong environment:** `404`/`403`.

**Recommended — a picker source (so testers don't type emails):**

### `GET /api/dev/ewt-users`
```json
[ { "objectId":"…", "displayName":"Jane Doe", "email":"jdoe@…", "roles":["User"] }, … ]
```
Only users assigned to EWT (naturally scoped — see §3). Same auth/env rules.

**Optional / future (not required now):** server-side **act-as** for end-to-end authorization + write audit — accept an impersonation context on data calls, enforce as the target, and log dual-actor. Separate ticket; flagged in the security write-up.

---

## 2. Context you need about EWT auth

- Single Entra app registration **per environment** that is both the SPA client and the API resource (`api://<id>/Access_As_User`). Tenant: `78a9186f-6f8c-4a40-88bc-780a1230929b`.
- App registration (client) IDs: **dev** `55e229b7-f820-4202-9716-f53273f7449f`, **test** `7048b9dd-2d1f-481f-9e16-7714a9fb6d05` (prod `0db76f52-…` — not in scope).
- The gate checks the **`roles` claim** for **`User`** (entry) and **`Admin`** (admin features). Those are **Entra App Roles** — not groups, not the DB.
- **Do not** use the legacy DB role tables (`EC_PERSON_PRIVS` / `EC_SECURITY_ROLES`) — they're legacy and being retired; roles must come from **Entra** so the test reflects production.

---

## 3. How to resolve roles (Microsoft Graph, app-only)

Copy SFD2's token mechanics (client-credentials, `scope=https://graph.microsoft.com/.default`, plain `requests`). Then:

```
# 1) EWT service principal (object id) + its role catalog, from the app (client) id:
GET /v1.0/servicePrincipals(appId='{ewtAppClientId}')?$select=id,appRoles
    → spId, and appRoles[] mapping appRoleId (GUID) → value ("User"/"Admin")

# 2a) Single email:
GET /v1.0/users/{email}?$select=id,displayName,userPrincipalName,mail
GET /v1.0/users/{id}/appRoleAssignments
    → keep entries where resourceId == spId, map appRoleId → value

# 2b) Full list (for /ewt-users):
GET /v1.0/servicePrincipals/{spId}/appRoleAssignedTo
    → principalId, principalDisplayName, principalType, appRoleId
    → resolve email via /users/{principalId}?$select=userPrincipalName,mail
```

**Group-assignment gotcha:** if EWT roles are assigned via **groups** (principalType `Group`), expand `GET /groups/{id}/transitiveMembers`. **Please confirm whether EWT app-role assignments are user-direct or group-based** — it changes the logic.

---

## 4. Permissions & config

**Graph application permissions (admin-consented):**
- **`Application.Read.All`** — read the service principal's `appRoleAssignedTo` + `appRoles`.
- **`User.ReadBasic.All`** — resolve name / UPN / mail.
- (`Directory.Read.All` is the broad alternative; prefer the two least-privilege scopes.)

> This is the key difference from SFD2: SFD2 used a **channel-scoped RSC**; this needs **tenant-wide directory read**. There is no RSC equivalent for app-role assignments. Both are strictly read-only. This grant is the item that needs **IT Security + Entra-admin sign-off**.

**Config (per environment, server-side only):**
- `GRAPH_TENANT_ID`, `GRAPH_CLIENT_ID`, credential (**certificate preferred** over secret)
- `EWT_APP_CLIENT_ID` (to resolve the SP) — or the SP object id directly
- Env flag enabling the `/api/dev/*` endpoints (dev/test only)

---

## 5. Security requirements (from the write-up — please honor)

- **Read-only.** The Graph app must never write. Verify a write attempt 403s.
- **Env-gated.** `/api/dev/*` exists only in dev/test; fail-closed if the flag is unset.
- **Secret/cert server-side only** — gitignored, excluded from deploy packages, never in source, logs, or responses. Prefer a **certificate**; record its expiry (fails closed on lapse).
- **Audit** every call: caller identity (from their token) + queried email + timestamp. This also seeds the fix for the current `ENVR`-stamps-everything gap.
- **Least privilege** scopes (the two above, not `Directory.Read.All`).

---

## 6. Definition of done

- [ ] `/api/dev/effective-roles?email=` returns correct roles for a known **User** and a known **Admin** (verify against the Entra portal).
- [ ] Unknown email → `found:false`; known user with no EWT role → `roles:[]`.
- [ ] `/api/dev/ewt-users` lists only EWT-assigned users with roles.
- [ ] Endpoints return 404 in production; fail closed if env flag unset.
- [ ] Graph credential is read-only, server-side, cert-based; a Graph write attempt fails.
- [ ] Each call emits an audit record (caller + email + time).

---

## 7. What we need from you (decisions/answers)

1. **Reuse** an existing Graph app reg (which one, and is consent already granted?) or **create** a dedicated "EWT Impersonation (dev/test)" registration?
2. **Certificate or secret**, and **who grants admin consent** (IT Security / Entra admin)?
3. Are EWT app-role assignments **user-direct or group-based**? (§3 gotcha.)
4. Confirm the **env-gating mechanism** you'll use for `/api/dev/*`.
5. Provide (or confirm you'll resolve) the **EWT service principal object id** per env.

The UI side ships now against a role-set toggle and will call `/api/dev/effective-roles` the moment it exists — same `effectiveRoles` seam, no rework. Response shape in §1 is what we'll consume; tell us if you'd change any field names before we wire it.
