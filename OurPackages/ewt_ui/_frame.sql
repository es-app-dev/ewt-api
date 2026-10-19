--#PREAMBLE
-- ===========================================================================
-- EWT_UI - the one package of ours: write logic ported from the legacy screens
--
-- One package, not one per screen (Bruce, 30 Sep).  OurPackages/README.md allows
-- "a package of ours" and the EWT_API_AUDIT table as the only additions to this
-- schema.  Each screen's units live here as <form>_<unit> - at5510_set_location,
-- at3250_key_delrec - in a section per screen, spec and body alike, so a
-- screen's port reads top to bottom in one place.  EWT_API_* stays the API's own.
--
-- Everything here CALLS the legacy's database objects (containers.*,
-- locations.*, compare_lic, rental_container_status.*, ...) and reimplements
-- none of them.  They are shared with the legacy application and are not ours.
--
-- Deploy: CREATE OR REPLACE.  AutoDeploy is on at dev (Bruce, 28 Sep); for Test
-- and Prod run it by hand on each instance.  The API fingerprints it against
-- this file on all seven instances at startup and reports drift.
--
-- ERRORS, for every unit
--   -20510  a rule the operator is meant to see; message text is the legacy text
--   -20511  an unexpected failure, SQLERRM appended, as the form did
--
-- Method: ewt-ui/rules/common/PORTING-RULES.md
-- Per screen: ewt-ui/rules/screens/<FORM>/PORT-NOTES.md where one exists
-- ===========================================================================

--#SPEC-OPEN
CREATE OR REPLACE PACKAGE ewt_ui IS
--#SPEC-HEAD
/* ---------------------------------------------------------------------------
 * WHY THIS EXISTS
 *   The legacy Forms application keeps running against this database while the
 *   new UI runs.  Both write the same tables at the same time.  A package writes
 *   the way Forms writes - same session, same locking, same transaction shape -
 *   so the two writers behave alike.  Logic rewritten in the application tier
 *   would not, and the difference only shows under concurrency.
 *
 * WHAT A PORT CHANGES, AND NOTHING ELSE
 *   1. Screen fields (:BLOCK.item) become IN parameters, named after them.
 *   2. Forms alerts that stop processing (msg_alert/seg_msgs ... TRUE,
 *      alert_user ... 'FAIL') become RAISE_APPLICATION_ERROR -20510 with the
 *      SAME text, verbatim.  The operator has read that wording for years.
 *   3. form_trigger_failure becomes e_abort, raised the same way.
 *   4. Tables the API cannot serve are retargeted to the view Forms reaches.
 *   The SQL is otherwise character for character what the form runs, including
 *   the parts that are ugly.  Where the legacy is odd, this is odd.
 * ------------------------------------------------------------------------- */

  c_rule_error     CONSTANT PLS_INTEGER := -20510;
  c_unexpected     CONSTANT PLS_INTEGER := -20511;

  /* e_abort stands in for the Forms built-in form_trigger_failure.
   *
   * The pragma is what makes the port faithful rather than merely similar.  In
   * the form, msg_alert(...,TRUE) raises form_trigger_failure, and every unit
   * carries "WHEN form_trigger_failure THEN RAISE;" ahead of its WHEN OTHERS so
   * that an abort travels out untouched instead of being caught and re-labelled.
   * Binding e_abort to -20510 reproduces that exactly: rule_error raises -20510
   * carrying the operator's wording, the inner WHEN e_abort handlers let it pass,
   * and WHEN OTHERS still catches everything else and re-labels it as before. */
  e_abort          EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_abort, -20510);

--#SPEC-TAIL
END ewt_ui;
/
--#BODY-OPEN
CREATE OR REPLACE PACKAGE BODY ewt_ui IS
--#BODY-HEAD

--#BODY-TAIL
END ewt_ui;
/
