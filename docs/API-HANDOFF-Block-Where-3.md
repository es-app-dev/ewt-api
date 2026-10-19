# Block WHERE registry: no longer needed for the 66

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-10-06
**Follows:** `API-HANDOFF-Block-Where-2.md`, 1 Oct
**Audience:** the API side
**Short version:** the 66 block WHEREs now run as procedures in our package, EWT_UI. Please don't spend more time
on the `where=` registry for them. The four questions in -2 are withdrawn. There is one thing to check after the
next restart.

---

## What changed

Each of the 66 entries in `docs/block-wheres.proposed.json` is now an EWT_UI procedure,
`EWT_UI.<FORM>_W_<BLOCK>`. Names over 30 characters are shortened with a 4-character suffix. Two FROM-clause
blocks run the same way as `EWT_UI.<FORM>_Q_<BLOCK>`, so the package holds 68 new procedures.

- **The query is the form's own.** Each procedure reads the block's table, its Alias, its WHERE and its
  ORDER BY from the JDAPI, and opens them as one cursor capped at 5,000 rows.
- **Every value is bound.** The WHERE's `:BLOCK.ITEM` references become `b_<block>_<item>` parameters, and the
  user's query criteria become `p_<column>` parameters. NULL means no criterion. There is no string
  concatenation.
- **The procedures only read.** The UI still saves through your entity endpoints by key.
- **They are generated** by `ewt-ui/scripts/jdapi/block-package.cjs` into `OurPackages/EWT_UI.sql`, between
  their own markers. They passed our package check: 105 ok, 0 failures.

They are deployed the usual way, by the next API restart. They use only the existing
`POST /odata/proc/{name}` route and its one-cursor reply, `{success, data: [rows]}`. Nothing new is asked of
the API.

## What we would still like

- **After the next restart:** confirm that the package compiles VALID on all 7 instances, as the list
  procedures did on 1 Oct.
- **The `where=` registry:** keep it if it is already built. The UI uses it only for a block the package does
  not hold, and today there are none. If it is not built, it can wait or be dropped. That is your call with
  Bruce.

## One behaviour to know about

`AT1510_W_AT_CPS_VIEW` runs the form's text exactly. That text reads `at_cnprodserv_view3@atcorp.energysolutions.com`
and calls `get_max_mod4@atcorp.energysolutions.com(...)`, so it relies on that database link on each daughter
instance, as the legacy form does. If a daughter has no such link, this one procedure fails at run time. The
other 67, and the package itself, are unaffected, because the cursor's SQL is dynamic.
