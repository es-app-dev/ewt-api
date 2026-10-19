# The remainder is 14, and only two of them matter

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-09-24
**Answering:** `API-HANDOFF-Phase1-Gaps-REPLY-11.md` section 5

Running the discovery pass and then taking it back out was the right call, and
"a setting nobody should turn on is worse than no setting" is worth keeping. The
`TA` and `DOC_CTRL` answers are definitive and we are not going to ask again.

You asked which of the remainder matter. **It is 14, not 22, and two of them.**

---

## Only these two block a screen

| Table | Where | Why it matters |
|---|---|---|
| `AT_CNTNR_CHEMICALS_VW` | **AT5170 block `CHEMICALS`** | a real data block, not inline SQL |
| `AT_CNTNR_METALS_VW` | **AT5170 block `METALS`** | same |

Both are `_VW` views. AT5170 is one of only two screens still hard-blocked on the
data side, so these two are the whole of it. **If they exist under another name, or
under accutrack with a different spelling, that closes AT5170.** If they do not
exist at all, it is the `AT_OVERPACK_MASTERS` situation again and we will find the
real object from the form.

That is the only thing we need from you here.

## The other twelve — no action

| Table | Used by | What it is |
|---|---|---|
| `GTSD_LOGONS_LOG`, `PARAMETERS`, `SITE_USER`, `VIEW_EMAIL_NOTIFICATIONS` | DOC_CTRL, inline SQL | same dead schema you just ruled out. Four more rows of the same answer. |
| `AT_CONTAINER`, `AT_CONTAINER_TYPE` | AT4120/4130, AT4220/4225/4230 | **ours.** Dynamic SQL built by concatenation: `'… from at_container_type' \|\| 's where …'`. Our scanner split a string literal mid-identifier. The tables are `AT_CONTAINERS` and `AT_CONTAINER_TYPES`, both exposed and working. |
| `EC_CONTAINERS` | AT4152, inline SQL | an **EWIS** table, not EWT. A cross-system reference in the legacy form; not yours to serve. |
| `AT_TRAKKER_BACKUP` | AT5195, inline SQL | a backup table by name. Not wanted. |
| `AT_ADV_NOTIF_CONTACTS`, `AT_COMMENT_MATERIALS`, `AT_CONTACT_REPORTS` | AT1310, inline SQL | AT1310 is otherwise clear. Low priority — tell us if they turn up while you are in there, but do not go looking. |
| `WB_IBOX_DETAIL_PARENTS` | WB3600, inline SQL | one statement on one screen. Same. |

So of the original 54: **20 `TA_*`** need an access decision, **11 `DOC_CTRL`** are a
schema that is not here, **2 overpack** are not real, **3** are Oracle dictionary,
**6 are our own parser artefacts**, and **2** are the AT5170 views above.

## On the developer schemas

Agreed, not wanted. `ADMIN-SEGEARY.TBL_*`, `JDELK.*` and `DPA.*` back no block, no
picker and no statement in any of the 161 forms — we checked rather than assumed.
Nothing to reopen.

## On `ATCAN` vs `BRON`

Useful, and it settles more than the link names. Oracle's own objects say `CAN` —
TNS alias, SID and public link all agree — while `BRON` is an instance code chosen
on your side. So they are two different things and neither is wrong. We will follow
`/odata/instances` for routing and keep `CAN` in anything that describes the
database itself. Still worth one person confirming which one an operator should see
in the site picker, since that is the third thing again.

## Ours, still unverified

- The `ORA-00054` lock-wait reasoning is still reasoned, not seen, on our side too.
  Neither of us should quote it as observed.
- Our parser produced 6 of the 54. We have tightened it for schema-qualified and
  db-link names; the dynamic-SQL concatenation case above is fixed by inspection
  rather than by a rule, so expect a few more of that shape if we widen the scan.
