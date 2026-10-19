# EWT access model — developer guide

How Entra group membership becomes EWT Oracle role access.

Generated from live grants across 7 Oracle instances.
Regenerate with `python scripts/build-nested-groups.py --flat`.

---

## 1. The model in one paragraph

EWT access is a set of Oracle database roles (`AT1710_ADMIN`, `AT3110_OPER`, …). Today
each person is granted those roles individually in each database. After migration, a
person's roles come entirely from their **Entra group membership**. Each Entra group maps
to a fixed set of Oracle roles. Groups are **flat** — no nesting — so a person is a direct
member of every group they need, and their access is the union of those groups' role sets.

```
Entra user
  └─ direct group memberships (median 23, max 47)
       └─ union of those groups' Oracle role sets
            └─ the person's effective EWT access
```

## 2. Why 52 groups, and why flat

Roles held by exactly the same set of people are indivisible — no assignment scheme can
separate them. There are **52 such clusters**, and that is a hard floor: 52 groups is the
minimum that reproduces today's access without granting anyone a role they do not have.

**Flat was chosen deliberately.** Nesting would cut assignments from 1,900 to 262, but
Entra ignores nesting in every mechanism that matters — app role assignment, app group
assignment, and the "groups assigned to the application" claim option. Going flat keeps
us on the same path EWIS already uses and removes a whole class of silent failure.

The cost is assignment volume. The benefit is that nothing in this model depends on an
Entra behaviour that has exceptions.

```
verification: 0 roles gained, 0 roles lost, across all 90 non-admin people
```

The build script asserts this and fails if it stops being true. Do not remove that
assertion.

## 3. Shape

| | |
|---|---|
| Role groups | 52 + `EWT-Administrator` = **53** |
| Sign-in gate | `EWT-Users` — flat, all 93, **0 roles** |
| Total Entra objects | **54** |
| Nesting | **none** — every membership is direct |
| Assignments | 1,903 role-group + 93 gate |
| Per person | median 23, max 47 |
| Largest group | `EWT-BaseAccess` — 66 roles, all 90 people |

## 4. Two layers, kept separate

| Question | Mechanism | Group |
|---|---|---|
| Can this person sign in? | Enterprise app assignment | `EWT-Users` only |
| What may they do? | Group membership → Oracle roles | the 53 role groups |

`EWT-Users` is the only group assigned to the EWT enterprise application. It carries no
roles. The 53 role groups are ordinary directory security groups the API reads and maps.

Because everything is flat and direct, app role assignment and group claims both work
correctly if you prefer them to Graph. That is the point of going flat.

## 5. Resolving a user's roles

Either path is valid now that nothing is nested:

```
groups = graph.memberOf(user)          // direct is sufficient - nothing to inherit
   or    token "groups" claim          // SecurityGroup, or groups-assigned-to-app
ewt    = groups ∩ knownEwtGroupIds
roles  = ⋃ roleSetOf(g) for g in ewt
cache(user, roles, ttl ≈ session)
```

`transitiveMemberOf` also works and costs nothing extra — use it if you want the code to
survive someone adding nesting later.

**The one limit that still applies: the token group cap.** 150 groups for SAML, 200 for
JWT. Over the limit Entra omits the groups claim *entirely* and substitutes a Graph link,
so the failure mode is total. An EWT user carries up to 47 EWT groups plus whatever else
the tenant puts them in. Comfortable, but not unlimited — if you read groups from the
token rather than Graph, apply a group filter (`EWT-` prefix) so tenant-wide membership
cannot push a user over.

## 6. Data files

| File | What it is |
|---|---|
| `analysis/entra-nested-groups.csv` | one row per group: id, name, role list |
| `analysis/entra-nested-assignments.csv` | person → their groups |
| `analysis/entra-nested-model.json` | both of the above, machine-readable |
| `analysis/ewt-role-catalogue.csv` | every role: what it does, tables, business area |
| `analysis/entra-nested-edges.csv` | empty in flat mode; kept so the schema is stable |

```jsonc
{
  "groups_detail": [
    { "id": "N26", "name": "EWT-CustomerService-Oper",
      "roles": ["AT1310_OPER", "..."], "parents": [], "reaches": 43 }
  ],
  "assignments_detail": { "JSMITH": ["N01", "N23", "N26", "..."] }
}
```

`parents` is present but always empty in flat mode. Do not build logic on it.

## 7. Group naming

`EWT-<Area>-<Level>`, e.g. `EWT-CustomerService-Oper`. Derived from `AT_SECURITY_MODULES`
(subsystem/area) plus the role's privilege suffix.

EWIS names its app roles semantically — `BILLING_UPDATE_FIELD_LEVEL`,
`WASTE_STREAM_DEL_FIELD_LEVEL` — rather than lifting legacy codes. EWT should end up the
same way. **These generated names are a starting point, not the final vocabulary.** Key
off `group_id` / the Entra object id, never the display name.

## 8. Admin accounts

`EWT-Administrator` holds all 243 roles. Three people: JDELK, JCROY, SEGEARY — confirmed
application admins/developers. They sit outside the clustering so their breadth does not
distort everyone else's groups.

## 9. Relationship to EWIS

EWIS resolves roles from **Entra app roles** via `/users/{id}/appRoleAssignments`. EWT
uses **security groups** instead, because 243 roles at a median of 123 per person is too
many to carry in a `roles` claim — EWIS's heaviest user carries 27.

If EWT is later switched to app roles for consistency, the flat structure transfers
directly: 53 app roles instead of 53 groups, same memberships, no redesign. That
portability is another reason flat was chosen.

## 10. Known gaps — read before trusting the numbers

- **19 people are unexplained.** On the administrator's own user list with real access
  counts, active in `AT_SEG_STAFF`, absent from `AT_ACCUTRACK_USERS`, `AT_ROLE_PRIVS`
  *and* `AT_MODULE_ACCESS` on all 7 instances. Not in this model.
- **The instance list looks complete.** `AT_CORP_CUST_SITES` names only the six daughters
  we connect to — seven sites on six databases (Bear Creek and Gallaher Rd share
  `atbctn`). "Eight daughters" counted sites. Confirm with
  `SELECT db_link FROM all_db_links` on CORP if certainty is needed.
- **Activity data stops mid-2025 at 5 of 7 sites.** `AT_MODULE_ACCESS` still writes at
  BCTN and CORP only. The 2-year window is the shortest that reaches past that cliff; a
  360-day window returns 2 people, not 93.
- **`AT_ACCUTRACK_USERS.ACTIVE_FLAG` is worthless** — `Y` for all 351. Use
  `AT_SEG_STAFF.STATUS_CD` (`A`/`I`) or the HR roster.

## 11. Regenerating

```bash
python scripts/run-pipeline.py                      # full chain from Oracle
python scripts/build-nested-groups.py --flat        # the group model (flat)
python scripts/build-admin-doc.py                   # the setup document
```

The pipeline needs the EWT API running on `localhost:5199`. Omitting `--flat` produces
the nested variant — 262 assignments instead of 1,903 — which is **not** the chosen
design and does not work with app-role assignment.
