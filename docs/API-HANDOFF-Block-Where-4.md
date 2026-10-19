# Block query procedures: the doubled WHERE is fixed, and there is now a run check

**From:** the UI/spec side (`C:\essource\ewt-ui`)
**Date:** 2026-10-06
**Answers:** `API-HANDOFF-Block-Where-3-REPLY.md`, 6 Oct
**Audience:** the API side
**Short version:** you were right about both. The fix is in `OurPackages/EWT_UI.sql`, regenerated rather than
patched, and changes exactly the two procedures. It needs one more restart. We also added the run check.

---

## The two ORA-00936s

The cause is what you found. AT1510 RNCNTNRS and AT1710 SRC write the keyword `WHERE` into the block's
WHERE property themselves. Forms tolerates that, and our wrapper added a second one.

- **The fix:** the generator now drops a leading `WHERE` from the form's text before wrapping it. A comment
  before it is kept. The code is in `ewt-ui/scripts/jdapi/block-procs.cjs`, `whereText`.
- **Regenerated, not patched.** The diff against the deployed file is two lines, one in each procedure.
  No cursor in the file now has `WHERE (` followed by a line starting `WHERE`.
- **Validated:** 108 ok, 0 failures. The procedure signatures are unchanged, so nothing calling them changes.

**Please restart once more to deploy it.**

## The run check

We added `ewt-ui/scripts/jdapi/run-block-procs.cjs`. It calls every generated query procedure, with every
parameter null, one at a time, with a 90-second limit each. It writes `analysis/api/block-procs-run.json` and
exits 1 on any failure.

We ran it on BCTN against what is deployed now. The result is the same as yours: **66 run, and
AT1510_W_RNCNTNRS and AT1710_W_SRC fail with ORA-00936.** We will run it again after the restart and expect 68.

Three procedures are slow with null parameters, all because of the forms' own WHERE clauses:

| Procedure | Time | Why |
|---|---:|---|
| `AT5514_W_OUTCNTNR` | 71 s | calls `get_current_location_seq` once per terminal container |
| `AT4151_W_LINER_CREATE` | 20 s | calls `get_container_id` once per row |
| `WB4000_W_WB_INCOMING_MANIFESTS` | 14 s | calls `no_manifest_daughters` once per row |

The legacy runs the same queries, so this is not a regression. AT5514's is close to the time you would
give a request before cutting it off, so please tell us what that limit is.

## The rest

- **Your cast fix and the endpoint's logging:** thank you. Our check would have reported those six as HTTP
  500 with no cause.
- **The `where=` registry:** keeping it is fine. The UI uses it only for a block the package does not hold.
- **The atcorp link check, and the CLUT `@TEST` link:** noted, and thank you for checking where the link
  points rather than assuming.
- **The extra row in `/odata/proc` and `db=`:** noted.
