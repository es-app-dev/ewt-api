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

CREATE OR REPLACE PACKAGE ewt_ui IS
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

/* ===========================================================================
 * AT5510 - Burial Shipment.  Ported from at5510.fmb (28 Sep, as EWT_UI_AT5510;
 * folded in here 30 Sep with the units renamed and nothing else changed).
 *
 * Checked with scripts/jdapi/validate-package.cjs when first ported:
 *   8 tables and views, all present on all 7 instances
 *   9 qualified column references, all present
 *   5 called database objects, all in GET /odata/proc, none reimplemented
 * Changed: AT_OVERPACK_DETAILS -> AT_OVERPACK_DETAILS_VIEW.  The base table does
 * not exist on any instance; only the view does, and it is what Forms reaches.
 * Source and rationale: ewt-ui/rules/screens/AT5510/PORT-NOTES.md
 * =========================================================================== */

  /* Bucket a burial shipment: push the shipment's disposal site down onto any
   * container that holds others, move processed amounts onto the shipment, then
   * reconcile.  Refuses unless a manifest exists and at least one container is
   * on the shipment. */
  PROCEDURE at5510_bucket_shipment(p_outshipmt_seq_id  IN NUMBER
                           ,p_manifest_nbr      IN VARCHAR2
                           ,p_disp_site_seq_id  IN NUMBER
                           ,p_has_containers    IN VARCHAR2);

  /* Set the from/to storage location for every container on the shipment and
   * record the movement, descending through overpacks and storage containers. */
  PROCEDURE at5510_set_location(p_outshipmt_seq_id        IN NUMBER
                        ,p_shipment_nbr            IN VARCHAR2
                        ,p_shipment_dt             IN DATE
                        ,p_shipper_seg_stf_seq_id  IN NUMBER);

  /* One container movement row, for the "loaded" transition. */
  PROCEDURE at5510_update_loaded_movement(p_cntnr_seq_id            IN NUMBER
                                  ,p_starting_loc_seq_id     IN NUMBER
                                  ,p_ending_loc_seq_id       IN NUMBER
                                  ,p_shipment_dt             IN DATE
                                  ,p_shipper_seg_stf_seq_id  IN NUMBER);

  /* Re-status every container on the shipment and record its movement. */
  PROCEDURE at5510_update_status(p_outshipmt_seq_id  IN NUMBER
                         ,p_in_cntnr_stat     IN VARCHAR2
                         ,p_from_location     IN NUMBER
                         ,p_to_location       IN NUMBER
                         ,p_shipment_dt       IN DATE
                         ,p_shipper_stf_id    IN NUMBER);

/* NOT PUBLIC, and deliberately so
 *   at5510_overpack_exists, at5510_storage_cntnr_exists, at5510_update_movement
 * are form units that portspec classed for the application tier ('reads' and
 * 'calls-pkg').  They are private in the body instead, because a database
 * package cannot call application code.  Anything a writing unit calls has to
 * come into the package with it.  See rules/common/PORTING-RULES.md. */

/* ===========================================================================
 * AT3250 - Maintain Container Rental Status.  Ported from at3250.fmb, block
 * RNCNTNRST, trigger KEY-DELREC (the whole trigger):
 *
 *   if not rental_container_status.status_ok_to_delete(:rncntnrst.rncntnrstat_cd_id) then
 *     seg_msgs('This status cannot be deleted as it is required by the Order Shipments module','E',TRUE);
 *     raise form_trigger_failure;
 *   else
 *     delete_record;
 *   end if;
 *
 * Why here: the guard is a database FUNCTION returning a PL/SQL BOOLEAN.  The
 * API cannot call a function (OPEN-32) and nothing outside PL/SQL binds a
 * BOOLEAN.  delete_record (a Forms built-in: mark the record for deletion) stays
 * with the screen: it calls this when Delete Record is pressed, and marks the
 * record if this returns quietly.  The delete itself goes at Save as any other.
 * =========================================================================== */

  /* May this status be deleted?  Quiet when it may; -20510 "This status cannot be
   * deleted as it is required by the Order Shipments module" when it may not. */
  PROCEDURE at3250_key_delrec(p_rncntnrstat_cd_id IN VARCHAR2);

/* ===========================================================================
 * AT5132 - Maintain Container Next Process.  Ported from at5132.fmb, block
 * CNTNR1 (AT_CONTAINERS: update only, and the one column it changes is
 * NEXT_PRCTRANTYP_SEQ_ID, through the shown Process code).
 *
 * THE LEGACY, in the order it runs
 *   1. Leaving the Process field (WHEN-VALIDATE-ITEM on DSP_PRCTRANTYP_CD_ID):
 *      the code is looked up into NEXT_PRCTRANTYP_SEQ_ID (the screen does that),
 *      then, unless the record is new, COMPARE_LIC(FALSE, ...) checks the
 *      mapping without writing, and anything but 'GOOD' refuses.
 *        -> at5132_when_validate_item
 *   2. Save: Forms UPDATEs the container, then POST-UPDATE runs the form unit
 *      MAKE_THE_CONNECTION: the process code must exist, then COMPARE_LIC(TRUE,
 *      ...) maps the container to its orders (UPDATE_LIC), and anything but
 *      'GOOD' refuses - which rolls the UPDATE back.
 *        -> at5132_post_update, which does the UPDATE too, so a refusal undoes it
 *           the same way: an unhandled error rolls back the whole call.
 *   COMPARE_LIC writes only through UPDATE_LIC, and only when its first argument
 *   is TRUE; NPC_TO_COST, which it always calls, writes nothing.  So step 1 is a
 *   pure check.
 *
 * CHANGED, beyond fields becoming parameters
 *   - :AT$CTRL.CURRENT_USER became p_current_user.  The form fills it with
 *     USER || '@' || the connect string (WHEN-NEW-FORM-INSTANCE), for example
 *     OPERATIONS@DEVBCTN.  This session's USER is the API's, so the screen passes it.
 *   - CGTE$OTHER_EXCEPTIONS re-raises form_trigger_failure, so alert_user's FAIL
 *     stops the commit in the form exactly as -20510 stops this call.
 *   - The UPDATE Forms issues itself is written out: NEXT_PRCTRANTYP_SEQ_ID only
 *     (CONTAINER_ID is Update Allowed No, so Forms leaves it out).
 *   - Forms re-reads and locks a record before changing it, and refuses one that
 *     changed since the query.  p_modified_dt, the value the screen read, does
 *     that here, with the Forms messages (FRM-40654, FRM-40501, FRM-40652).
 * KEPT AS THE LEGACY HAS THEM
 *   - :cntnr1.ord_seq is a hidden control item nothing sets, so COMPARE_LIC
 *     always receives NULL for p_soli_seq.  NULL is passed.
 *   - RETURN_MSG <> 'GOOD' is not TRUE for a NULL answer, so NULL would pass.
 *     COMPARE_LIC sets 'GOOD' first, so it never is.
 * =========================================================================== */

  /* POST-QUERY on CNTNR1: POP_VALID_NPC rebuilds AT_VALID_NPC_TMP for the container,
   * the list the Process LOV (MAP_NOMAP_NPC) reads.  The form runs it for every
   * record fetched; the screen runs it for the record whose list is about to open,
   * which is the only row of that table a user sees.  (CONTAINER_ID's
   * WHEN-VALIDATE-ITEM runs it too, but CONTAINER_ID cannot be typed into.)
   * NOTE: POP_VALID_NPC COMMITs inside itself - the legacy's own behaviour, kept.
   * It deletes and rewrites only this container's rows. */
  PROCEDURE at5132_post_query(p_cntnr_seq_id IN NUMBER);

  /* The field check, after the screen has looked the code up: COMPARE_LIC in check
   * mode.  Writes nothing.  Quiet on 'GOOD'; -20510 with COMPARE_LIC's message
   * otherwise.  Not for a new record (the form returns early; the block cannot
   * insert anyway). */
  PROCEDURE at5132_when_validate_item(p_cntnr_seq_id           IN NUMBER
                                     ,p_dsp_prctrantyp_cd_id   IN VARCHAR2
                                     ,p_current_user           IN VARCHAR2);

  /* Save one container's next process: the UPDATE Forms issues, then POST-UPDATE.
   * p_modified_dt is the row's MODIFIED_DT as the screen read it, in the API's
   * form YYYY-MM-DD"T"HH24:MI:SS; NULL skips the check. */
  PROCEDURE at5132_post_update(p_cntnr_seq_id             IN NUMBER
                              ,p_next_prctrantyp_seq_id   IN NUMBER
                              ,p_dsp_prctrantyp_cd_id     IN VARCHAR2
                              ,p_current_user             IN VARCHAR2
                              ,p_modified_dt              IN VARCHAR2);

/* ===========================================================================
 * AT5110 - Container Movement.  Ported from at5110.fmb: the Move button
 * (CONT$CTRL.CNTNR_MOVE_OK_BUTTON, WHEN-BUTTON-PRESSED) with the form units it
 * calls, STORAGE_CONTAINER_EXISTS, DOUBLE_CONTAINER_LOC and ADD_TIME_TO_DATE
 * (private in the body: they are not screen operations).
 *
 * WHAT THE LEGACY DOES
 *   For every record of the CONTAINER block, first to last: one AT_CONTAINER_MOVEMENTS
 *   row to the Move Location (the trigger's local function MOVEMENT), and when the
 *   container holds others, one row for each of them to the same location
 *   (DOUBLE_CONTAINER_LOC).  A stockpile or lift location adds a warning for the
 *   first container that CAN_CNTNR_GO_BURIAL refuses, and moves it anyway.  Then
 *   COMMIT_FORM.
 *
 * CHANGED, beyond fields becoming parameters
 *   - The CONTAINER block's records arrive as two lists in record order, one
 *     value per line (CHR(10)): p_cntnr_seq_ids and p_container_ids.  A blank
 *     record is an empty line.  p_blank_container is :CONT$CTRL.BLANK_CONTAINER:
 *     with 'Y', a last record with no container is dropped, as CLEAR_RECORD does.
 *   - MOVE_DATE and MOVE_TIME arrive as the items show them, and are converted
 *     with the items' own masks (MM/DD/RRRR, HH:MI PM), as Forms converts typed
 *     text.
 *   - alert_user(msg, 'I', 'NOFAIL') shows a message and carries on: here each
 *     one is a line of p_notices, in the order the legacy shows them, and the
 *     screen shows them when the call returns.  alert_user(.., 'FAIL') is
 *     rule_error.  BELL is dropped.
 *   - 'Moving all entered containers ... one moment please' is shown by the
 *     screen before the call, in that wording.
 *   - DO_KEY('COMMIT_FORM'): the call is one transaction, committed when it
 *     returns; an error rolls all of it back (the legacy's error path leaves the
 *     rows it inserted posted but uncommitted in the session).  Changes the user
 *     made to queried CONTAINER rows are not in it: the screen saves those
 *     through its own save first.
 *   - When every container moved (p_all_moved = 'Y') the screen clears Move
 *     Location, Date, Time and Operator; then it clears the CONTAINER block and
 *     goes to Move Location, as the legacy does.
 * KEPT AS THE LEGACY HAS THEM
 *   - A container CAN_CNTNR_GO_BURIAL refuses is moved anyway: the branch only
 *     adds the warning, and only once per press (msg_cnt).
 *   - MOVEMENT swallows every error and reports "Container X not moved".
 *   - MOVEMENT reads the location's LANDFILL_IND and LIFT_IND and the container's
 *     status, and fetches the next movement, and uses none of them.
 *   - DOUBLE_CONTAINER_LOC swallows every error, inserts with no operator, and
 *     stamps MOVED_TIME with today's time on Oracle's default date part.
 * =========================================================================== */

  /* The Move button.  p_moved is the count in "N Containers Moved"; p_all_moved
   * is 'Y' or 'N'; p_notices holds the NOFAIL messages, one per line.  -20510
   * 'Move Location, Date, Time and Operator must be entered' when one is empty. */
  PROCEDURE at5110_cntnr_move_ok(p_move_location          IN VARCHAR2
                                ,p_move_location_seq_id   IN NUMBER
                                ,p_move_date              IN VARCHAR2
                                ,p_move_time              IN VARCHAR2
                                ,p_move_operator          IN VARCHAR2
                                ,p_move_operator_seq_id   IN NUMBER
                                ,p_blank_container        IN VARCHAR2
                                ,p_cntnr_seq_ids          IN VARCHAR2
                                ,p_container_ids          IN VARCHAR2
                                ,p_moved                  OUT NUMBER
                                ,p_all_moved              OUT VARCHAR2
                                ,p_notices                OUT VARCHAR2);

  -- >>> generated by scripts/jdapi/contract.cjs --lov-sql: lists of values run as the form wrote them
  -- AT1310 CORP_CUST_LV (record group CORP_CUST_RG); not OData: could not read the query (expected ) at "<> :cust9.cust_seq_id or :cust9.cust_seq_id")
  PROCEDURE at1310_lov_corp_cust_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1310 LV_CUST_BUS_TYP_LST (record group RG_CUST_BUS_TYPE_LST); not OData: LIKE on something other than a literal
  PROCEDURE at1310_lov_lv_cust_bus_typ_lst(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT1310 LV_CUST_CUST_NBR_NAMES (record group RG_CUST_CUST_NBR_NAME); not OData: could not read the query (expected ) at "<> :cust9.cust_seq_id or :cust9.cust_seq_id")
  PROCEDURE at1310_lov_lv_cust_cust_nbr_na(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1310 LV_LIC_REST_LST (record group RG_LIC_REST_LST); not OData: could not read the query (expected ) at "= 'AT_CUSTOMER_LICENSES.LICENSE_RESTRICTION_CD' ) order")
  PROCEDURE at1310_lov_lv_lic_rest_lst(p_rows OUT SYS_REFCURSOR);
  -- AT1310 LV_SEG_STF_LST (record group RG_SEG_STAFF_LST); not OData: LIKE on something other than a literal
  PROCEDURE at1310_lov_lv_seg_stf_lst(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT1310 LV_STATE_PROVINCE_COUNTRIES (record group RG_STATE_PROVINCE_COUNTRIES); not OData: a join
  PROCEDURE at1310_lov_lv_state_province_c(p_rows OUT SYS_REFCURSOR);
  -- AT1410 CUST_DISP_SITES_LOV (record group CUST_DISP_SITES_RG); not OData: function EXISTS
  PROCEDURE at1410_lov_cust_disp_sites_lov(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1410 CUSTOMER_LOV (record group CUSTOMER_RG); not OData: function TO_CHAR
  PROCEDURE at1410_lov_customer_lov(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1410 SHIPPING_LOCATIONS_LOV (record group SHIPPING_LOCATIONS_RG); not OData: could not read the query (unexpected "NOT" in WHERE)
  PROCEDURE at1410_lov_shipping_locations_(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1410 STATE_LOV (record group STATE_RG); not OData: a join
  PROCEDURE at1410_lov_state_lov(p_rows OUT SYS_REFCURSOR);
  -- AT1510 DISP_SITE_LV (record group DISP_SITE_RG); not OData: a subquery in WHERE
  PROCEDURE at1510_lov_disp_site_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1510 PROFILE_LV (record group PROFILE_RG); not OData: could not read the query (expected ) at "+ 1 ) <")
  PROCEDURE at1510_lov_profile_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1551 CGFK$CNTNR_DSP_PRCTRANTYP_CD_I (record group PRCTRANS_TYPES_BY_ORDER); not OData: a join
  PROCEDURE at1551_lov_cgfk_cntnr_dsp_prct(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1551 LOV_COST (record group RG_COST); not OData: a join
  PROCEDURE at1551_lov_lov_cost(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1552 DAUGHTER_CONTAINERS (record group DAUGHTER_CONTAINERS); not OData: a join
  PROCEDURE at1552_lov_daughter_containers(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT1552 LOV_COST (record group RG_COST); not OData: a join
  PROCEDURE at1552_lov_lov_cost(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1553 LOV_ORDER (record group RG_ORDER); not OData: a join
  PROCEDURE at1553_lov_lov_order(p_rows OUT SYS_REFCURSOR);
  -- AT1710 CHARGE_TO_CUST_LOV (record group CHARGE_TO_CUST_RG); not OData: a subquery in WHERE
  PROCEDURE at1710_lov_charge_to_cust_lov(p_rows OUT SYS_REFCURSOR);
  -- AT1710 INV_CONTRACT_NBR (record group INV_CONTRACT_NBR); not OData: a subquery in WHERE
  PROCEDURE at1710_lov_inv_contract_nbr(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1710 INV_SEG_STAFF (record group INV_SEG_STAFF); not OData: a subquery in WHERE
  PROCEDURE at1710_lov_inv_seg_staff(p_rows OUT SYS_REFCURSOR);
  -- AT1710 LV_BARCODE (record group RG_BARCODE); not OData: a join
  PROCEDURE at1710_lov_lv_barcode(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1710 LV_SHIPMENTS (record group RG_SHIPMENTS); not OData: a join
  PROCEDURE at1710_lov_lv_shipments(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1710 LV_WKSHT_MNFSTS (record group RG_WKSHT_MNFSTS); not OData: a join
  PROCEDURE at1710_lov_lv_wksht_mnfsts(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT3110 CGFK$CUSTTRCK_DSP_CODE2 (record group CGFK$CUSTTRCK_DSP_CODE2); not OData: could not read the query (unexpected "not" in WHERE)
  PROCEDURE at3110_lov_cgfk_custtrck_ds_02(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT3110 CGFK$CUSTTRCK_DSP_CODE (record group CGFK$CUSTTRCK_DSP_CODE); not OData: could not read the query (unexpected "not" in WHERE)
  PROCEDURE at3110_lov_cgfk_custtrck_dsp_c(p1 IN NUMBER, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT3110 CGFK$MATLMATL_DSP_MATERIAL_TYP (record group CGFK$MATLMATL_DSP_MATERIAL_TYP); not OData: NOT / a subquery in WHERE
  PROCEDURE at3110_lov_cgfk_matlmatl_dsp_m(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT3110 CGFK$MATLMATL1_DSP_MATERIAL_TY (record group CGFK$MATLMATL1_DSP_MATERIAL_TY); not OData: NOT / a subquery in WHERE
  PROCEDURE at3110_lov_cgfk_matlmatl1_dsp_(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT3110 LOV_ACTIVITY (record group RG_ACTIVITY); not OData: UNION
  PROCEDURE at3110_lov_lov_activity(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT3110 LOV_ACTIVITY1 (record group RG_ACTIVITY); not OData: UNION
  PROCEDURE at3110_lov_lov_activity1(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT3110 ORDER_DISP_SITES (record group ORDER_DISP_SITES); not OData: a join
  PROCEDURE at3110_lov_order_disp_sites(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT3115 CGFK$CNTNR_DSP_PRCTRANTYP_CD_I (record group PRCTRANS_TYPES_BY_ORDER); not OData: a join
  PROCEDURE at3115_lov_cgfk_cntnr_dsp_prct(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT3115 CUST_DISP (record group CUST_DISP); not OData: a join
  PROCEDURE at3115_lov_cust_disp(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT3115 LOV_COST (record group RG_COST$); not OData: a join
  PROCEDURE at3115_lov_lov_cost(p1 IN VARCHAR2, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT3212 CGFK$RNCNTNR_DSP_CONTAINER_TYP (record group CGFK$RNCNTNR_DSP_CONTAINER_TYP); not OData: a subquery in WHERE
  PROCEDURE at3212_lov_cgfk_rncntnr_dsp_co(p_rows OUT SYS_REFCURSOR);
  -- AT3420 CGFK$PL_CNTNR_DSP_CONTAINER_ID (record group CGFK$PL_CNTNR_DSP_CONTAINER_ID); not OData: could not read the query (unexpected "not" in WHERE)
  PROCEDURE at3420_lov_cgfk_pl_cntnr_dsp_c(p_rows OUT SYS_REFCURSOR);
  -- AT4140 CONTAINERS (record group CONTAINERS); not OData: a join
  PROCEDURE at4140_lov_containers(p_rows OUT SYS_REFCURSOR);
  -- AT4150 BATCH_PARENTS (record group BATCH_PARENTS); not OData: could not read the query (expected FROM at "")
  PROCEDURE at4150_lov_batch_parents(p_rows OUT SYS_REFCURSOR);
  -- AT4150 LOV_COST (record group RG_COST); not OData: a join
  PROCEDURE at4150_lov_lov_cost(p1 IN NUMBER, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT4150 MAP_NONMAP_NPC (record group MAP_NONMAP_NPC); not OData: a join
  PROCEDURE at4150_lov_map_nonmap_npc(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT4150 MATERIAL_TYPES (record group MATERIAL_TYPES); not OData: function TO_CHAR
  PROCEDURE at4150_lov_material_types(p_rows OUT SYS_REFCURSOR);
  -- AT4150 PARENT_CONTENTS (record group MATERIAL_TYPES); not OData: function TO_CHAR
  PROCEDURE at4150_lov_parent_contents(p_rows OUT SYS_REFCURSOR);
  -- AT4210 DSP_CONTAINER_ID (record group DSP_CONTAINER_ID); not OData: a join
  PROCEDURE at4210_lov_dsp_container_id(p_rows OUT SYS_REFCURSOR);
  -- AT4211 DSP_CONTAINER_ID (record group DSP_CONTAINER_ID); not OData: a join
  PROCEDURE at4211_lov_dsp_container_id(p_rows OUT SYS_REFCURSOR);
  -- AT4220 PARTIAL_OVERPACKS (record group PARTIAL_OVERPACKS); not OData: a join
  PROCEDURE at4220_lov_partial_overpacks(p_rows OUT SYS_REFCURSOR);
  -- AT4225 PARTIAL_OVERPACKS (record group PARTIAL_OVERPACKS); not OData: a join
  PROCEDURE at4225_lov_partial_overpacks(p_rows OUT SYS_REFCURSOR);
  -- AT4230 PARTIAL_OVERPACKS (record group PARTIAL_OVERPACKS); not OData: a join
  PROCEDURE at4230_lov_partial_overpacks(p_rows OUT SYS_REFCURSOR);
  -- AT4240 GIC_CONTAINERS (record group GIC_CONTAINERS); not OData: a join
  PROCEDURE at4240_lov_gic_containers(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT4240 LOV_COST (record group RG_COST); not OData: a join
  PROCEDURE at4240_lov_lov_cost(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT4260 ADJ_CONTAINERS (record group ADJ_CONTAINERS); not OData: a join
  PROCEDURE at4260_lov_adj_containers(p_rows OUT SYS_REFCURSOR);
  -- AT4270 BINS (record group BINS); not OData: function EXISTS
  PROCEDURE at4270_lov_bins(p_rows OUT SYS_REFCURSOR);
  -- AT4280 TANKS (record group TANKS); not OData: function EXISTS
  PROCEDURE at4280_lov_tanks(p_rows OUT SYS_REFCURSOR);
  -- AT4420 SURVEYS (record group SURVEYS); not OData: a join
  PROCEDURE at4420_lov_surveys(p_rows OUT SYS_REFCURSOR);
  -- AT5120 CGFK$CNTNR_DSP_CONTAINER_ID (record group CGFK$CNTNR_CONTAINER_ID); not OData: a join
  PROCEDURE at5120_lov_cgfk_cntnr_dsp_cont(p_rows OUT SYS_REFCURSOR);
  -- AT5210 LV_MANIFESTS (record group RG_MANIFESTS); not OData: a join
  PROCEDURE at5210_lov_lv_manifests(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT5210 PARTITION_LOV (record group PARTITION_RG); not OData: UNION
  PROCEDURE at5210_lov_partition_lov(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT5210 PROCESSES (record group PROCESSES); not OData: could not read the query (unexpected "between" in WHERE)
  PROCEDURE at5210_lov_processes(p_rows OUT SYS_REFCURSOR);
  -- AT5210 PROJECT (record group PROJECT); not OData: a join
  PROCEDURE at5210_lov_project(p_rows OUT SYS_REFCURSOR);
  -- AT5310 CGFK$LABANLSMPL_DSP_SAMPLE_ID (record group CGFK$LABANLSMPL_DSP_SAMPLE_ID); not OData: a join
  PROCEDURE at5310_lov_cgfk_labanlsmpl_dsp(p1 IN VARCHAR2, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT5310 CONTAINERS (record group CONTAINERS); not OData: a join
  PROCEDURE at5310_lov_containers(p_rows OUT SYS_REFCURSOR);
  -- AT5311 CONTAINERS (record group CONTAINERS); not OData: a join
  PROCEDURE at5311_lov_containers(p_rows OUT SYS_REFCURSOR);
  -- AT5312 CGFK$LABSAMPLE2_DSP_BADGE_NBR (record group CGFK$LABSAMPLE2_DSP_BADGE_NBR); not OData: a subquery in WHERE
  PROCEDURE at5312_lov_cgfk_labsample2_dsp(p_rows OUT SYS_REFCURSOR);
  -- AT5312 FACILITY (record group FACILITY); not OData: a join
  PROCEDURE at5312_lov_facility(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT5312 REVIEWED_BY_STAFF (record group REVIEWED_BY_STAFF); not OData: a subquery in WHERE
  PROCEDURE at5312_lov_reviewed_by_staff(p_rows OUT SYS_REFCURSOR);
  -- AT5316 CONTAINERS (record group CONTAINERS); not OData: a join
  PROCEDURE at5316_lov_containers(p_rows OUT SYS_REFCURSOR);
  -- AT5316 CUSTOMERS (record group CUSTOMERS); not OData: a join
  PROCEDURE at5316_lov_customers(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT5390 FACILITY_LOV (record group FACILITY_RG); not OData: a join
  PROCEDURE at5390_lov_facility_lov(p_rows OUT SYS_REFCURSOR);
  -- AT5510 DISP_SITES_LOV (record group DISP_SITES_RG); not OData: function DECODE
  PROCEDURE at5510_lov_disp_sites_lov(p_rows OUT SYS_REFCURSOR);
  -- AT5510 WASTE_PROFILE_NUMBER_LOV (record group WASTE_PROFILE_NUMBER_RG); not OData: could not read the query (expected FROM at "EXTRACTVALUE ( cip .")
  PROCEDURE at5510_lov_waste_profile_numbe(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT5511 CGFK$OUTSHIPMT_DSP_CARRIER_NAM (record group CGFK$OUTSHIPMT_DSP_CARRIER_NAM); not OData: a join
  PROCEDURE at5511_lov_cgfk_outshipmt_dsp_(p_rows OUT SYS_REFCURSOR);
  -- AT5511 CONTAINERS (record group CONTAINERS); not OData: a join
  PROCEDURE at5511_lov_containers(p_rows OUT SYS_REFCURSOR);
  -- AT5514 LIFT_STOR_LOC_LV (record group LIFT_STOR_LOC_RG); not OData: could not read the query (Cannot read properties of undefined (reading 'toUpperCase'))
  PROCEDURE at5514_lov_lift_stor_loc_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT9106 CGFK$CONTSTR_DSP_CODE (record group CGFK$CONTSTR_DSP_CODE); not OData: function TO_CHAR
  PROCEDURE at9106_lov_cgfk_contstr_dsp_co(p_rows OUT SYS_REFCURSOR);
  -- AT9106 LV_LIC_REST_LST (record group RG_LIC_REST_LST); not OData: could not read the query (expected ) at "= 'AT_CUSTOMER_LICENSES.LICENSE_RESTRICTION_CD' ) order")
  PROCEDURE at9106_lov_lv_lic_rest_lst(p_rows OUT SYS_REFCURSOR);
  -- AT9603 PARENT_NPC_LOV (record group NPC); not OData: could not read the query (expected ) at "prctrantyp_cd_id FROM at_process_trans_types ptt2")
  PROCEDURE at9603_lov_parent_npc_lov(p_rows OUT SYS_REFCURSOR);
  -- AT9612 STATE_LOV (record group STATE_RG); not OData: a join
  PROCEDURE at9612_lov_state_lov(p_rows OUT SYS_REFCURSOR);
  -- AT9640 GROUPS_LOV (record group GROUPS_RG); not OData: a join
  PROCEDURE at9640_lov_groups_lov(p_rows OUT SYS_REFCURSOR);
  -- WB1000 CGFK$CUSTTRCK_DSP_CODE (record group CGFK$CUSTTRCK_DSP_CODE); not OData: could not read the query (unexpected "not" in WHERE)
  PROCEDURE wb1000_lov_cgfk_custtrck_dsp_c(p1 IN NUMBER, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- WB1000 CGFK$MATLMATL_DSP_MATERIAL_TYP (record group CGFK$MATLMATL_DSP_MATERIAL_TYP); not OData: NOT / a subquery in WHERE
  PROCEDURE wb1000_lov_cgfk_matlmatl_dsp_m(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- WB1000 CONTAINER_DISP_SITES (record group ORDER_DISP_SITES); not OData: a subquery in WHERE
  PROCEDURE wb1000_lov_container_disp_site(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- WB1000 CUST_VIEW_LV (record group CUST_VIEW_RG); not OData: a join
  PROCEDURE wb1000_lov_cust_view_lv(p_rows OUT SYS_REFCURSOR);
  -- WB1000 NPC_CODES (record group NPC_CODES); not OData: a join
  PROCEDURE wb1000_lov_npc_codes(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- WB1000 ORDER_DISP_SITES (record group ORDER_DISP_SITES); not OData: a subquery in WHERE
  PROCEDURE wb1000_lov_order_disp_sites(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- WB1000 PSC_LV (record group PSC_RG); not OData: a join
  PROCEDURE wb1000_lov_psc_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- WB1100 SURVEYORS (record group SURVEYORS); not OData: a subquery in WHERE
  PROCEDURE wb1100_lov_surveyors(p_rows OUT SYS_REFCURSOR);
  -- WB2001 LOV_DISPSITES (record group DISPSITES); not OData: could not read the query (expected FROM at ". CODE , AT_DISP_SITES")
  PROCEDURE wb2001_lov_lov_dispsites(p_rows OUT SYS_REFCURSOR);
  -- WB2001 LOV_RAD_FLAG (record group RAD_FLAG); not OData: UNION
  PROCEDURE wb2001_lov_lov_rad_flag(p_rows OUT SYS_REFCURSOR);
  -- WB2001 LOV_WASTE_CD (record group WASTE_CLASS); not OData: UNION
  PROCEDURE wb2001_lov_lov_waste_cd(p_rows OUT SYS_REFCURSOR);
  -- WB4000 ITEMS (record group ITEMS); not OData: a join
  PROCEDURE wb4000_lov_items(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- WB4000 MID_PSC (record group PSC); not OData: a join
  PROCEDURE wb4000_lov_mid_psc(p1 IN VARCHAR2, p2 IN VARCHAR2, p3 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- WB4000 QTB_BURIAL_PARENT_LV (record group QTB_BURIAL_PARENT_RG); not OData: could not read the query (expected FROM at "")
  PROCEDURE wb4000_lov_qtb_burial_parent_l(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- WB4000 VALID_NPC (record group VALID_NPC); not OData: a join
  PROCEDURE wb4000_lov_valid_npc(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< end of generated lists of values

  -- >>> generated by scripts/jdapi/block-package.cjs: query blocks run as the form wrote them
  -- AT1310 COMNT: AT_COMMENT_INSTRUCTIONS with the block's own WHERE; one optional criterion per column
  PROCEDURE at1310_w_comnt(b_cust9_cust_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_comnttyp_seq_id IN NUMBER, p_cntrct_seq_id IN NUMBER, p_comment_txt IN VARCHAR2, p_active_ind IN VARCHAR2, p_marketing_approval_ind IN VARCHAR2, p_comnt_seq_id IN NUMBER, p_created_by_name IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT1330 SEARCH: the block's own FROM-clause query; one optional criterion per column
  PROCEDURE at1330_q_search(p_waste_profile_number IN VARCHAR2, p_customer_nbr IN NUMBER, p_customer_name IN VARCHAR2, p_site_cd IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT1410 AT_CNTRCT_CUST_VIEW: AT_CNTRCT_CUST_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at1410_w_at_cntrct_cust_view(b_at_contracts_contract_nbr IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_parent_cntrct_seq_id IN NUMBER, p_contract_nbr IN VARCHAR2, p_mod_cntrct_id IN NUMBER, p_customer_nbr IN NUMBER, p_name IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT1410 CLONE_PROD_SERVICES: AT_CONTRACT_PROD_SERVICES with the block's own WHERE; one optional criterion per column
  PROCEDURE at1410_w_clone_prod_services(b_at_contracts_cntrct_seq_id IN NUMBER, b_at_contracts_cust_seq_id IN NUMBER, p_group_nbr IN VARCHAR2, p_subgroup_nbr IN VARCHAR2, p_cost IN NUMBER, p_unit_cd_id IN VARCHAR2, p_description IN VARCHAR2, p_prodserv_seq_id IN NUMBER, p_prodserv_prodcat_seq_id IN NUMBER, p_cnprodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_cntrct_seq_id IN NUMBER, p_contract_line_nbr IN VARCHAR2, p_current_available_amt IN NUMBER, p_sales_received_amt IN NUMBER, p_overestimate_limit_pct IN NUMBER, p_quantity IN NUMBER, p_prof_seq_id IN NUMBER, p_basis IN VARCHAR2, p_basis_pct IN NUMBER, p_min_charge IN NUMBER, p_density_min IN NUMBER, p_density_max IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT1510 AT_CPS_VIEW: AT_CNPRODSERV_VIEW3@ATCORP.ENERGYSOLUTIONS.COM with the block's own WHERE; one optional criterion per column
  PROCEDURE at1510_w_at_cps_view(b_mnfst_cust_seq_id IN NUMBER, b_mnfst_advnotif_expected_e379 IN DATE, b_mnfst_es_prof_seq_id IN NUMBER, b_mnfst_disp_site_seq_id IN NUMBER, p_cntrct_contract_nbr IN VARCHAR2, p_cntrct_mod_cntrct_id IN NUMBER, p_cnprodserv_seq_id IN NUMBER, p_prodserv_cd IN VARCHAR2, p_prodserv_descr IN VARCHAR2, p_dispsite_alias IN VARCHAR2, p_cnprodserv_cost IN NUMBER, p_cnprodserv_unit_cd_id IN VARCHAR2, p_cnprodserv_descr IN VARCHAR2, p_cnprodserv_cust_seq_id IN NUMBER, p_prodserv_prodcat_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_group_nbr IN VARCHAR2, p_subgroup_nbr IN VARCHAR2, p_disposal_revenue_ind IN VARCHAR2, p_certification_prog_ind IN VARCHAR2, p_life_of_plant_ind IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_tax_included_ind IN VARCHAR2, p_dispsite_code IN VARCHAR2, p_min_charge IN NUMBER, p_seg_resp_dept_nm IN VARCHAR2, p_contract_line_nbr IN VARCHAR2, p_prodcat_descr IN VARCHAR2, p_classified_ind IN VARCHAR2, p_prof_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT1510 AT_INVOICES: AT_INVOICES with the block's own WHERE; one optional criterion per column
  PROCEDURE at1510_w_at_invoices(b_mnfst_advnotif_seq_id IN NUMBER, p_invoice_nbr IN VARCHAR2, p_invoice_type_cd IN VARCHAR2, p_invoice_category_cd IN VARCHAR2, p_invc_seq_id IN NUMBER, p_invoice_loc_cd IN VARCHAR2, p_ship_to_cust_seq_id IN NUMBER, p_charge_to_cust_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_face_sheeted IN VARCHAR2, p_notes IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_terms IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT1510 RNCNTNRS: AT_RENTAL_CNTNR_SHIPMENTS_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at1510_w_rncntnrs(p_rental_container_id IN VARCHAR2, p_rncntnrstat_cd_id IN VARCHAR2, p_seg_owned_ind IN VARCHAR2, p_out_shipment_nbr IN VARCHAR2, p_shipment_type_cd IN VARCHAR2, p_consignee_cust_seq_id IN NUMBER, p_pick_up_cust_seq_id IN NUMBER, p_rncntnr_seq_id IN NUMBER, p_segordlitm_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT1551 UNMAPPED_BARCODES: AT_ORDER_BARCODE_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at1551_w_unmapped_barcodes(b_at_incoming_manifests_o_621d IN NUMBER, p_container_id IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_next_prctrantyp_seq_id IN NUMBER, p_source IN VARCHAR2, p_prctrantyp_cd_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_description IN VARCHAR2, p_anchor_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT1552 UNMAPPED_ORDERS: AT_BARCODE_ORDER_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at1552_w_unmapped_orders(b_at_containers_cntnr_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_manifest_nbr IN VARCHAR2, p_cust_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT1710 AT_RENTAL_CNTNR_SHIPMENTS_VIEW: AT_RENTAL_CNTNR_SHIPMENTS_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at1710_w_at_rental_cntnr__50a1(b_inv_ship_to_cust_seq_id IN NUMBER, b_at$ctrl_end_dt IN DATE, b_at$ctrl_begin_dt IN DATE, p_out_shipment_nbr IN VARCHAR2, p_rncntnr_seq_id IN NUMBER, p_rental_container_id IN VARCHAR2, p_old_sl_nbr IN VARCHAR2, p_tare_wgt IN NUMBER, p_seg_owned_ind IN VARCHAR2, p_rncntnrstat_cd_id IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_billing_cust_seq_id IN NUMBER, p_owned_by_cust_seq_id IN NUMBER, p_comment_txt IN VARCHAR2, p_storage_loc_sl_ind IN VARCHAR2, p_current_site_seq_id IN NUMBER, p_in_shipment_nbr IN VARCHAR2, p_in_cust_seq IN VARCHAR2, p_segordlitm_seq_id IN NUMBER, p_shipment_type_cd IN VARCHAR2, p_consignee_cust_seq_id IN NUMBER, p_pick_up_cust_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT1710 AT_SHIP_TRANS: AT_SHIP_TRANS with the block's own WHERE; one optional criterion per column
  PROCEDURE at1710_w_at_ship_trans(b_at_invoice_line_shipmen_da18 IN VARCHAR2, p_shipment_nbr IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_hittman_nbr IN VARCHAR2, p_contract_nbr IN VARCHAR2, p_notes IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT1710 PREV_INV: AT_INVOICE_LINE_CNTNR with the block's own WHERE; one optional criterion per column
  PROCEDURE at1710_w_prev_inv(b_at$ctrl_prev_cntnr_seq IN NUMBER, b_at$ctrl_advnotif_seq_id IN NUMBER, p_invc_seq_id IN NUMBER, p_invlitm_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_anchor_wgt IN NUMBER, p_inv_wgt IN NUMBER, p_advnotif_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT1710 SRC: AT_OPPORTUNITIES_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at1710_w_src(b_inv_charge_to_cust_seq_id IN NUMBER, b_wksht_prodserv_cd IN VARCHAR2, b_wksht_disp_site_alias IN VARCHAR2, b_wksht_advnotif_seq_id IN NUMBER, p_invoppty_seq_id IN NUMBER, p_contract_nbr IN VARCHAR2, p_manifest_nbr IN VARCHAR2, p_qty IN NUMBER, p_container_id IN VARCHAR2, p_invoppty_description IN VARCHAR2, p_prodserv_cd IN VARCHAR2, p_disp_site_alias IN VARCHAR2, p_disp_site_code IN VARCHAR2, p_description IN VARCHAR2, p_advnotif_seq_id IN NUMBER, p_cost IN NUMBER, p_invoiced_ind IN VARCHAR2, p_ordered_qty IN NUMBER, p_segordlitm_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT3110 AT_ESPROFILE_EPA: AT_ESPROFILE_EPA with the block's own WHERE; one optional criterion per column
  PROCEDURE at3110_w_at_esprofile_epa(b_matl_matl_seq_id IN NUMBER, b_matl_cntnr_seq_id IN NUMBER, p_es_prof_seq_id IN NUMBER, p_haz_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT3110 AT_ESPROFILE_EPA_I: AT_ESPROFILE_EPA with the block's own WHERE; one optional criterion per column
  PROCEDURE at3110_w_at_esprofile_epa_i(b_matl1_matl_seq_id IN NUMBER, b_matl1_cntnr_seq_id IN NUMBER, p_es_prof_seq_id IN NUMBER, p_haz_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT3110 CNTNR: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at3110_w_cntnr(b_matl_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT3115 CNTNR: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at3115_w_cntnr(b_parameter_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_disp_site_seq_id IN NUMBER, p_cntnr_stat_cd_id IN VARCHAR2, p_next_prctrantyp_seq_id IN NUMBER, p_cntnr_typ_seq_id IN NUMBER, p_disp_site_lock_ind IN VARCHAR2, p_exterior_dose_rate_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_agt_media_seq_id IN NUMBER, p_incinerator_factor_nbr IN NUMBER, p_anchor_wgt_source_cd IN VARCHAR2, p_anchor_wgt IN NUMBER, p_waste_vol IN NUMBER, p_waste_vol_unit_cd IN VARCHAR2, p_hazardous_cd IN VARCHAR2, p_notes IN VARCHAR2, p_source_ind IN VARCHAR2, p_source_manufacturer IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT4151 LINER_CREATE: AT_CONTAINER_PROCESSES with the block's own WHERE; one optional criterion per column
  PROCEDURE at4151_w_liner_create(p_batch_seq_id IN NUMBER, p_sealand_seq_id IN NUMBER, p_hic_seq_id IN NUMBER, p_liner_rtc_ind IN VARCHAR2, p_comment_txt IN VARCHAR2, p_liner_complete_ind IN VARCHAR2, p_filter_amt IN NUMBER, p_cntnr_proc_seq_id IN NUMBER, p_parent_daughter_type_cd IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_void_space_amt IN NUMBER, p_empty_wgt IN NUMBER, p_activity_pct IN NUMBER, p_difference_wgt IN NUMBER, p_full_wgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_innerpack_hgt IN NUMBER, p_void_difference_amt IN NUMBER, p_waste_wgt IN NUMBER, p_dose_rate_amt IN NUMBER, p_volume IN NUMBER, p_shift_cd IN VARCHAR2, p_anchor_wgt IN NUMBER, p_height IN NUMBER, p_locks_qty IN NUMBER, p_pre_sorted_ind IN VARCHAR2, p_assignment_method_cd IN VARCHAR2, p_incineration_factor_nbr IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_overpack_complete_ind IN VARCHAR2, p_overpack_full_ind IN VARCHAR2, p_highest_contact_amt IN NUMBER, p_average_contact_amt IN NUMBER, p_average_at_3ft_amt IN NUMBER, p_created_by_name IN VARCHAR2, p_modified_by_name IN VARCHAR2, p_slag_ind IN VARCHAR2, p_supervisor_seg_stf_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_hgt_unit_cd_id IN VARCHAR2, p_wgt_unit_cd_id IN VARCHAR2, p_vol_unit_cd_id IN VARCHAR2, p_parent_cntnr_seq_id IN NUMBER, p_pre_cmpctn_wgt_unit_cd_id IN VARCHAR2, p_byprodhdrs_seq_id IN NUMBER, p_db_trigger_ind IN VARCHAR2, p_part_cntnr_seq_id IN NUMBER, p_tclp_ind IN VARCHAR2, p_cntnr_proc_stat_cd_id IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_ash_volume IN NUMBER, p_ash_waste_wgt IN NUMBER, p_gross_wgt_ind IN VARCHAR2, p_compacted_ind IN VARCHAR2, p_innerpack_waste_vol IN NUMBER, p_ash_cntnr_seq_id IN NUMBER, p_original_vol IN NUMBER, p_original_wgt IN NUMBER, p_process_vol_pct IN NUMBER, p_non_processed_ind IN VARCHAR2, p_volume_processed IN NUMBER, p_wgt_processed IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT4210 COMPACTION_MASTER: AT_COMPACTION_MASTERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at4210_w_compaction_master(p_cmpctn_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT4211 COMPACTION_MASTER: AT_SHIP_COMPACTION_MASTERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at4211_w_compaction_master(p_cmpctn_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT4215 COMPACTION_MASTER: AT_COMPACTION_MASTERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at4215_w_compaction_master(p_cmpctn_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT4220 COMPACTION_MASTERS: AT_COMPACTION_MASTERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at4220_w_compaction_masters(p_cmpctn_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_innerpack_hgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT4220 OVERPACK_MASTER: AT_OVERPACK_MASTERS_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at4220_w_overpack_master(p_ovrpack_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_parent_daughter_type_cd IN VARCHAR2, p_volume IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_waste_wgt IN NUMBER, p_void_space_amt IN NUMBER, p_container_total_height IN NUMBER, p_dose_rate_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_comment_txt IN VARCHAR2, p_wgt_unit_cd_id IN VARCHAR2, p_void_unit_cd_id IN VARCHAR2, p_shift_cd IN VARCHAR2, p_overpack_complete_ind IN VARCHAR2, p_difference_wgt IN NUMBER, p_void_difference_amt IN NUMBER, p_vol_unit_cd_id IN VARCHAR2, p_seg_stf_seq_id IN NUMBER, p_super_seg_stf_seq_id IN NUMBER, p_cntnr_proc_stat_cd_id IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT4225 COMPACTION_MASTERS: AT_SHIP_COMPACTION_MASTERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at4225_w_compaction_masters(p_cmpctn_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_innerpack_hgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT4225 OVERPACK_MASTER: AT_OVERPACK_MASTERS_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at4225_w_overpack_master(p_ovrpack_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_parent_daughter_type_cd IN VARCHAR2, p_volume IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_waste_wgt IN NUMBER, p_void_space_amt IN NUMBER, p_container_total_height IN NUMBER, p_dose_rate_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_comment_txt IN VARCHAR2, p_wgt_unit_cd_id IN VARCHAR2, p_void_unit_cd_id IN VARCHAR2, p_shift_cd IN VARCHAR2, p_overpack_complete_ind IN VARCHAR2, p_difference_wgt IN NUMBER, p_void_difference_amt IN NUMBER, p_vol_unit_cd_id IN VARCHAR2, p_seg_stf_seq_id IN NUMBER, p_super_seg_stf_seq_id IN NUMBER, p_cntnr_proc_stat_cd_id IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT4230 CONTAINERS: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at4230_w_containers(p_next_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_used_vol IN NUMBER, p_total_hgt IN NUMBER, p_gross_wgt_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT4230 OVERPACK_MASTER: AT_OVERPACK_MASTERS_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at4230_w_overpack_master(p_ovrpack_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_parent_daughter_type_cd IN VARCHAR2, p_volume IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_waste_wgt IN NUMBER, p_void_space_amt IN NUMBER, p_dose_rate_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_comment_txt IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_void_unit_cd_id IN VARCHAR2, p_shift_cd IN VARCHAR2, p_overpack_complete_ind IN VARCHAR2, p_difference_wgt IN NUMBER, p_void_difference_amt IN NUMBER, p_vol_unit_cd_id IN VARCHAR2, p_super_seg_stf_seq_id IN NUMBER, p_cntnr_proc_stat_cd_id IN VARCHAR2, p_compacted_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT5160 CNTNR1: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5160_w_cntnr1(p_container_id IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT5161 AT_SHIPMENTS: AT_SHIPMENTS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5161_w_at_shipments(p_shipment_nbr IN VARCHAR2, p_shipment_type_cd IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT5161 CNTNR1: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5161_w_cntnr1(b_at_shipments_shipment_nbr IN VARCHAR2, p_container_id IN VARCHAR2, p_notes IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT5170 AT_CNTNR_LAB_RESULTS_VIEW: AT_CNTNR_LAB_RESULTS_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at5170_w_at_cntnr_lab_res_b392(b_cntnr_cntnr_seq_id IN NUMBER, p_element_cd IN VARCHAR2, p_activity_amt IN NUMBER, p_activity_unit_cd_id IN VARCHAR2, p_container_id IN VARCHAR2, p_sample_id IN VARCHAR2, p_code IN VARCHAR2, p_pass_fail_ind IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_labtyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT5170 CNTNR: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5170_w_cntnr(b_cntnr_container_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_gross_wgt IN NUMBER, p_tare_wgt IN NUMBER, p_anchor_wgt IN NUMBER, p_used_vol IN NUMBER, p_void_space_amt IN NUMBER, p_description IN VARCHAR2, p_notes IN VARCHAR2, p_exterior_alpha_contam_amt IN NUMBER, p_exterior_bg_contam_amt IN NUMBER, p_exterior_contam_unit_cd_id IN VARCHAR2, p_exterior_dose_rate_amt IN NUMBER, p_exterior_dose_rate_1m_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_waste_class_cd IN VARCHAR2, p_waste_class_amt IN NUMBER, p_inc_waste_class_cd IN VARCHAR2, p_rebucket IN VARCHAR2, p_incinerator_box_nbr IN VARCHAR2, p_incinerator_factor_nbr IN NUMBER, p_density_pct IN NUMBER, p_transuranic_pct IN NUMBER, p_ra226_pct IN NUMBER, p_hazardous_cd IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_vol_unit_cd_id IN VARCHAR2, p_override_vol IN NUMBER, p_within_cntnr_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_next_prctrantyp_seq_id IN NUMBER, p_total_hgt IN NUMBER, p_used_hgt IN NUMBER, p_hgt_unit_cd_id IN VARCHAR2, p_agt_media_seq_id IN NUMBER, p_oowag_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT5311 LABANLSMPL5: AT_LAB_ANALYSIS_SAMPLES with the block's own WHERE; one optional criterion per column
  PROCEDURE at5311_w_labanlsmpl5(p_pass_fail_ind IN VARCHAR2, p_mnfststat_cd_id IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_labsample_seq_id IN NUMBER, p_labanlsmpl_seq_id IN NUMBER, p_labtyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT5311 LABSAMPLE2: AT_LAB_SAMPLES with the block's own WHERE; one optional criterion per column
  PROCEDURE at5311_w_labsample2(p_sample_id IN VARCHAR2, p_labsample_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_req_by_seg_stf_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT5312 AT_ESPROFILE_SAMP_FREQ: AT_ESPROFILE_SAMP_FREQ with the block's own WHERE; one optional criterion per column
  PROCEDURE at5312_w_at_esprofile_sam_5d3f(b_labsample2_es_prof_seq_id IN NUMBER, p_esprofile_samp_freq_seq_id IN NUMBER, p_es_prof_seq_id IN NUMBER, p_site_seq_id IN NUMBER, p_shipment_nbr IN VARCHAR2, p_labsample_seq_id IN NUMBER, p_business_rule IN NUMBER, p_sample_type IN VARCHAR2, p_rule_type IN VARCHAR2, p_yd_marker IN NUMBER, p_create_user IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT5312 COMPOSITE: AT_LAB_SAMPLE_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5312_w_composite(b_labsample2_labsample_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_labsample_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT5316 LABANLSMPL5: AT_LAB_ANALYSIS_SAMPLES with the block's own WHERE; one optional criterion per column
  PROCEDURE at5316_w_labanlsmpl5(p_pass_fail_ind IN VARCHAR2, p_mnfststat_cd_id IN VARCHAR2, p_adjust_reason_text IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_entry_seg_stf_seq_id IN NUMBER, p_labsample_seq_id IN NUMBER, p_labanlsmpl_seq_id IN NUMBER, p_labtyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT5316 LABSAMPLE2: AT_LAB_SAMPLES with the block's own WHERE; one optional criterion per column
  PROCEDURE at5316_w_labsample2(p_sample_id IN VARCHAR2, p_labsample_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_req_by_seg_stf_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT5510 AT_OUTBOUND_SHIPMENTS: AT_OUTBOUND_SHIPMENTS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5510_w_at_outbound_shipments(p_outshipmt_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_shipment_nbr IN VARCHAR2, p_manifest_nbr IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_railcar_nbr IN VARCHAR2, p_epa_manifest_nbr IN VARCHAR2, p_es_prof_seq_id IN NUMBER, p_exclusive_use_ind IN VARCHAR2, p_cntnr_vol_ind IN VARCHAR2, p_cask_ind IN VARCHAR2, p_epa_regulated_waste_ind IN VARCHAR2, p_collector_ind IN VARCHAR2, p_processor_ind IN VARCHAR2, p_envirocare_cwf_ind IN VARCHAR2, p_qoc_cat2_ind IN VARCHAR2, p_electronic_541_ind IN VARCHAR2, p_electronic_542_ind IN VARCHAR2, p_electronic_add_notes_ind IN VARCHAR2, p_additional_notes IN VARCHAR2, p_shipment_status IN VARCHAR2, p_transport_permit_nbr IN VARCHAR2, p_generator_cd IN VARCHAR2, p_disp_purpose_cd IN VARCHAR2, p_disp_site_seq_id IN NUMBER, p_special_handling_instr IN VARCHAR2, p_shipper_seg_stf_seq_id IN NUMBER, p_man_addl_num_pgs IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT5511 OUTSHIPMT: AT_OUTBOUND_SHIPMENTS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5511_w_outshipmt(p_manifest_nbr IN VARCHAR2, p_shipment_nbr IN VARCHAR2, p_exclusive_use_ind IN VARCHAR2, p_shipment_status IN VARCHAR2, p_epa_regulated_waste_ind IN VARCHAR2, p_epa_manifest_nbr IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_transport_permit_nbr IN VARCHAR2, p_generator_cd IN VARCHAR2, p_collector_ind IN VARCHAR2, p_processor_ind IN VARCHAR2, p_outshipmt_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_shipper_seg_stf_seq_id IN NUMBER, p_cntnr_vol_ind IN VARCHAR2, p_additional_notes IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT5514 OUTCNTNR: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5514_w_outcntnr(b_landfill_headers_begin__b633 IN NUMBER, p_used_vol IN NUMBER, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT5520 OUTSHIPMT: AT_OUTBOUND_SHIPMENTS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5520_w_outshipmt(p_outshipmt_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_shipment_nbr IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT5521 OUTSHIPMT: AT_OUTBOUND_SHIPMENTS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5521_w_outshipmt(p_outshipmt_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_shipment_nbr IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT9999 AT_CUST_DOC_TRACKED_ITEMS: AT_CUST_DOC_TRACKED_ITEMS with the block's own WHERE; one optional criterion per column
  PROCEDURE at9999_w_at_cust_doc_trac_c339(b_at$ctrl_cntnr_seq IN NUMBER, p_custtrck_seq_id IN NUMBER, p_trkditm_seq_id IN NUMBER, p_cust_provided_ind IN VARCHAR2, p_activity_amt IN NUMBER, p_total_activity_pct IN NUMBER, p_inc_activity_amt IN NUMBER, p_snm_amt IN NUMBER, p_inc_snm_amt IN NUMBER, p_inc_source_material_amt IN NUMBER, p_source_material_amt IN NUMBER, p_accum_ind IN VARCHAR2, p_cust_seq_id IN NUMBER, p_matl_seq_id IN NUMBER, p_byprodhdrs_seq_id IN NUMBER, p_snm_741_ind IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT9999 AT_CUST_DOC_TRACKED_ITEMS_N: AT_CUST_DOC_TRACKED_ITEMS_N with the block's own WHERE; one optional criterion per column
  PROCEDURE at9999_w_at_cust_doc_trac_5461(b_at$ctrl_cntnr_seq_n IN NUMBER, b_at$ctrl_matl_seq_n IN NUMBER, p_activity_amt IN NUMBER, p_snm_amt IN NUMBER, p_source_material_amt IN NUMBER, p_lld_activity_amt IN NUMBER, p_custtrck_seq_id IN NUMBER, p_trkditm_seq_id IN NUMBER, p_cust_provided_ind IN VARCHAR2, p_total_activity_pct IN NUMBER, p_inc_activity_amt IN NUMBER, p_inc_snm_amt IN NUMBER, p_inc_source_material_amt IN NUMBER, p_accum_ind IN VARCHAR2, p_cust_seq_id IN NUMBER, p_matl_seq_id IN NUMBER, p_byprodhdrs_seq_id IN NUMBER, p_snm_741_ind IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT9999 DAUGHTERS: AT_CONTAINER_PROCESSES with the block's own WHERE; one optional criterion per column
  PROCEDURE at9999_w_daughters(b_at_anchor_retro_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_anchor_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB1000 SEGORDLITM: AT_SEG_ORDER_LINE_ITEMS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb1000_w_segordlitm(b_mnfst_advnotif_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_line_item_nbr IN NUMBER, p_status_cd IN VARCHAR2, p_segordlitm_seq_id IN NUMBER, p_cnprodserv_seq_id IN NUMBER, p_grp_cnprodserv_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB1000 WB_CONT_NUC_VIEW: WB_CONT_NUC_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE wb1000_w_wb_cont_nuc_view(p_trkditm_cd IN VARCHAR2, p_trkditm_seq_id IN NUMBER, p_inc_man_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB1100 DOUBLE_CONTAINMENT: WB_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb1100_w_double_containment(b_wb_incoming_manifests_a_0f8f IN NUMBER, p_incoming_barcode IN VARCHAR2, p_container_id IN VARCHAR2, p_gross_wgt IN NUMBER, p_tare_wgt IN NUMBER, p_used_vol IN NUMBER, p_cntnr_seq_id IN NUMBER, p_within_cntnr_seq_id IN NUMBER, p_next_prctrantyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB2002 AT_COMPACTION_MASTERS: AT_COMPACTION_MASTERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb2002_w_at_compaction_masters(p_cmpctn_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_innerpack_hgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB2002 AT_COMPACTION_MASTERS2: AT_COMPACTION_MASTERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb2002_w_at_compaction_ma_f0a9(p_cntnr_seq_id IN NUMBER, p_innerpack_hgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB2002 AT_CONTAINER_PROCESSES: AT_CONTAINER_PROCESSES with the block's own WHERE; one optional criterion per column
  PROCEDURE wb2002_w_at_container_pro_2fad(b_at_overpacks_cntnr_seq_id IN NUMBER, p_parent_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_innerpack_wgt IN NUMBER, p_innerpack_hgt IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB2002 AT_OVERPACKS: AT_OVERPACKS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb2002_w_at_overpacks(p_cntnr_seq_id IN NUMBER, p_underfill_amt IN NUMBER, p_rank IN NUMBER, p_rad_greater_0_ind IN VARCHAR2, p_rad_greater_180_ind IN VARCHAR2, p_ash_ind IN VARCHAR2, p_rad_greater_500_ind IN VARCHAR2, p_baghouse_dust_ind IN VARCHAR2, p_fly_ash_ind IN VARCHAR2, p_rad_greater_1000_ind IN VARCHAR2, p_treated_ash_ind IN VARCHAR2, p_full_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB2003 AT_CONTAINER_PROCESSES: AT_CONTAINER_PROCESSES with the block's own WHERE; one optional criterion per column
  PROCEDURE wb2003_w_at_container_pro_4055(b_op_cntnr_seq_id IN NUMBER, p_parent_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_innerpack_hgt IN NUMBER, p_volume IN NUMBER, p_innerpack_waste_vol IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB3000 SEARCH: the block's own FROM-clause query; one optional criterion per column
  PROCEDURE wb3000_q_search(p_parent_container_id IN VARCHAR2, p_daughter_barcode IN VARCHAR2, p_customer_nbr IN NUMBER, p_customer_name IN VARCHAR2, p_full_wt IN VARCHAR2, p_empty_wgt IN VARCHAR2, p_npc IN VARCHAR2, p_sort_dt IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB3100 LOAD_IBOX: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3100_w_load_ibox(b_at$ctrl_incinerator_id IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_online_status IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB3200 ACTIVITY_BURNED: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_activity_burned(b_burn_incinerator_incin IN VARCHAR2, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_ibox_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_void_indicator IN VARCHAR2, p_online_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_burn_reason IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB3200 ASHBOX_ACTIVITY: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_ashbox_activity(b_ashbox_incinerator_inci_45a5 IN VARCHAR2, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_ashdrum_seq_id IN NUMBER, p_ashdrum_seq_id_secondary IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_removed_ind IN VARCHAR2, p_ash_sequence IN NUMBER, p_incinerator_id IN VARCHAR2, p_online_status IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB3200 BURNED: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_burned(b_ashbox_incinerator_inci_45a5 IN VARCHAR2, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_ibox_seq_id IN NUMBER, p_ashdrum_seq_id IN NUMBER, p_ashdrum_seq_id_secondary IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_void_indicator IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_ash_sequence IN NUMBER, p_incinerator_id IN VARCHAR2, p_removed_ind IN VARCHAR2, p_online_status IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB3200 BURN_ACTIVITY_VIEW: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_burn_activity_view(b_burn_incinerator_incin IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_online_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_burn_reason IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB3200 LOAD_IBOX: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_load_ibox(b_at$ctrl_incinerator_id IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_online_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB3200 SUMMARY: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_summary(b_at$ctrl_incin_summary IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_incinerator_id IN VARCHAR2, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_void_indicator IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB3200 WB_ASHDRUM1: WB_ASHDRUM with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_wb_ashdrum1(b_at$ctrl_incinerator_id IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_ashdrum_seq_id IN NUMBER, p_ashdrum_barcode IN VARCHAR2, p_empty_wt IN NUMBER, p_full_wt IN NUMBER, p_waste_wt IN NUMBER, p_final_void IN NUMBER, p_dose_rate IN NUMBER, p_dose_rate_30cm IN NUMBER, p_dose_unit IN VARCHAR2, p_sample_amt IN NUMBER, p_sample_unit IN VARCHAR2, p_sample_reason IN VARCHAR2, p_comments IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB3200 WB_ASHDRUM2: WB_ASHDRUM with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_wb_ashdrum2(b_at$ctrl_incinerator_id IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_ashdrum_seq_id IN NUMBER, p_ashdrum_barcode IN VARCHAR2, p_empty_wt IN NUMBER, p_full_wt IN NUMBER, p_waste_wt IN NUMBER, p_final_void IN NUMBER, p_dose_rate IN NUMBER, p_dose_rate_30cm IN NUMBER, p_dose_unit IN VARCHAR2, p_sample_amt IN NUMBER, p_sample_unit IN VARCHAR2, p_sample_reason IN VARCHAR2, p_comments IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB4000 OPEN_PARENTS: WB_QTB_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb4000_w_open_parents(p_parent_empty_ind IN VARCHAR2, p_parent_container_id IN VARCHAR2, p_parent_full_wgt IN NUMBER, p_parent_empty_wgt IN NUMBER, p_psc IN VARCHAR2, p_advnotif_seq_id IN NUMBER, p_qtb_seq_id IN NUMBER, p_parent_cntnr_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_pseudo_parent_container_id IN VARCHAR2, p_parent_container_type IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB4000 OPEN_QTB: WB_QTB_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb4000_w_open_qtb(p_qtb_closed_ind IN VARCHAR2, p_qtb_barcode IN VARCHAR2, p_full_wgt IN NUMBER, p_empty_wgt IN NUMBER, p_container_type IN VARCHAR2, p_qtb_seq_id IN NUMBER, p_qtb_cntnr_seq_id IN NUMBER, p_cntnr_typ_seq_id IN NUMBER, p_sort_area IN VARCHAR2, p_alt_container_type IN VARCHAR2, p_sort_status IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB4000 WB_INCOMING_MANIFESTS: AT_INCOMING_MANIFESTS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb4000_w_wb_incoming_manifests(p_advnotif_seq_id IN NUMBER, p_manifest_nbr IN VARCHAR2, p_cust_seq_id IN NUMBER, p_processing_hold_ind IN VARCHAR2, p_brokered_shipment_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB4100 WB_QTB_CONTAINERS_DAU: WB_QTB_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb4100_w_wb_qtb_containers_dau(p_qtb_seq_id IN NUMBER, p_parent_container_id IN VARCHAR2, p_qtb_barcode IN VARCHAR2, p_pseudo_parent_container_id IN VARCHAR2, p_full_wgt IN NUMBER, p_empty_wgt IN NUMBER, p_cntnr_typ_seq_id IN NUMBER, p_container_type IN VARCHAR2, p_incinerator_box_nbr IN VARCHAR2, p_next_process_cd IN VARCHAR2, p_psc IN VARCHAR2, p_exterior_dose_rate_amt IN NUMBER, p_dose_rate_30cm IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< end of generated query blocks

END ewt_ui;
/
CREATE OR REPLACE PACKAGE BODY ewt_ui IS

  /* The form showed a message and abandoned the trigger.  Same message, same
   * effect: the caller gets the operator's wording and nothing is committed. */
  PROCEDURE rule_error(p_msg IN VARCHAR2) IS
  BEGIN
    RAISE_APPLICATION_ERROR(c_rule_error, p_msg);
  END rule_error;

/* ===========================================================================
 * AT5510 - Burial Shipment
 * =========================================================================== */

-- ---------------------------------------------------------------------------
-- Form units that the writing units call.
--
-- portspec classed these for the application tier because read on their own they
-- only SELECT, or only call another package.  That classification is right about
-- what they do and wrong about where they go: they are called from inside
-- at5510_bucket_shipment and at5510_set_location, and a database package cannot call code that
-- lives in the browser.  A callee follows its caller.
-- ---------------------------------------------------------------------------

  /* Does this container sit inside an overpack?
   *
   * Ported as found, including the shape.  The SELECT has no INTO fallback, so a
   * container with no overpack raises NO_DATA_FOUND, falls into WHEN OTHERS and
   * returns FALSE.  The function is correct by accident rather than by design.
   * The two statements after each RETURN are unreachable in the original as well
   * - PL/SQL warns (PLW-06002) and compiles.  They are kept so that a reader
   * comparing this against at5510.fmb sees the same text.
   *
   * Changed: at_overpack_masters -> at_overpack_masters_view.  The base table is
   * not on any instance; the view is on all seven, and is what Forms reaches. */
  FUNCTION at5510_overpack_exists(p_cntnr_seq_id IN NUMBER)
    RETURN BOOLEAN IS
    at5510_overpack_exists   VARCHAR(1);
  BEGIN
    SELECT 'Y'
    INTO   at5510_overpack_exists
    FROM   at_overpack_masters_view ovpck
    WHERE  ovpck.cntnr_seq_id = p_cntnr_seq_id;

    RETURN TRUE;
  EXCEPTION
    WHEN e_abort THEN
      RETURN FALSE;
      RAISE;                                            -- unreachable, as found
    WHEN OTHERS THEN
      RETURN FALSE;
      rule_error('Error: OVERPACK_EXISTS (Function Body). ' || SQLERRM);
  END at5510_overpack_exists;

-- ---------------------------------------------------------------------------
  /* Does anything sit inside this container?
   *
   * Ported as found.  Note the WHEN OTHERS branch: it reports and then falls off
   * the end of a function without returning, which raises ORA-06503, "Function
   * returned without value".  Here rule_error raises first, so the path ends in
   * an abort rather than ORA-06503 - the operator sees the same wording either
   * way, and the transaction ends either way. */
  FUNCTION at5510_storage_cntnr_exists(in_cntnr NUMBER)
    RETURN BOOLEAN IS
    count_storage   NUMBER;
  BEGIN
    SELECT COUNT(*)
    INTO   count_storage
    FROM   at_containers
    WHERE  within_cntnr_seq_id = in_cntnr;

    IF count_storage > 0 THEN
      RETURN (TRUE);
    ELSE
      RETURN (FALSE);
    END IF;

    RETURN NULL;                                        -- unreachable, as found
  EXCEPTION
    WHEN e_abort THEN
      RAISE;
    WHEN OTHERS THEN
      rule_error('Error: STORAGE_CONTAINER_EXISTS (Function Body). ' || SQLERRM);
  END at5510_storage_cntnr_exists;

-- ---------------------------------------------------------------------------
  /* Record a container movement through the existing CONTAINERS package.
   *
   * :AT_OUTBOUND_SHIPMENTS.shipper_seg_stf_seq_id became a parameter; the
   * IS NOT NULL guard around the whole body is the form's, not an addition.
   *
   * containers.create_container_movement is an existing database object - present
   * in GET /odata/proc on all seven instances - and is called, not reimplemented.
   *
   * The inner handler used severity 'W' and the abort flag TRUE.  The letter only
   * chose the alert icon; the third argument is what stopped processing.  So this
   * aborts, and the icon is the one thing the port cannot carry.  Error code
   * -20510 tells the client to draw it; see rules/common/MESSAGES.md. */
  PROCEDURE at5510_update_movement(p_cntnr_seq_id            IN NUMBER
                           ,p_starting_loc_seq_id     IN NUMBER
                           ,p_ending_loc_to_seq_id    IN NUMBER
                           ,p_shipper_seg_stf_seq_id  IN NUMBER) IS
  BEGIN
    IF p_shipper_seg_stf_seq_id IS NOT NULL THEN
      BEGIN
        containers.create_container_movement(p_container_seq      => p_cntnr_seq_id
                                            ,p_date_moved         => SYSDATE
                                            ,p_time_moved         => TO_CHAR(SYSDATE, 'HH24:MI')
                                            ,p_starting_loc_seq   => p_starting_loc_seq_id
                                            ,p_ending_loc_seq     => p_ending_loc_to_seq_id
                                            ,p_staff_seq_id       => p_shipper_seg_stf_seq_id);
      EXCEPTION
        WHEN OTHERS THEN
          rule_error(   'Failure: Create Container Movement. cntnr_seq_id: '
                     || p_cntnr_seq_id
                     || ', p_starting_loc_seq_id: '
                     || p_starting_loc_seq_id
                     || ', p_ending_loc_to_seq_id: '
                     || p_ending_loc_to_seq_id
                     || '. '
                     || SQLERRM);
      END;
    END IF;
  EXCEPTION
    WHEN e_abort THEN
      RAISE;
    WHEN OTHERS THEN
      rule_error('Error: UPDATE_MOVEMENT.(Procedure Body). ' || SQLERRM);
  END at5510_update_movement;

-- ---------------------------------------------------------------------------
  PROCEDURE at5510_update_loaded_movement(p_cntnr_seq_id            IN NUMBER
                                  ,p_starting_loc_seq_id     IN NUMBER
                                  ,p_ending_loc_seq_id       IN NUMBER
                                  ,p_shipment_dt             IN DATE
                                  ,p_shipper_seg_stf_seq_id  IN NUMBER) IS
    v_cntnrmv_seq_id   at_container_movements.cntnrmv_seq_id%TYPE;
    v_moved_time       at_container_movements.moved_time%TYPE;
  BEGIN
    IF p_shipper_seg_stf_seq_id IS NOT NULL THEN
      SELECT cntnrmv_seq.NEXTVAL
      INTO   v_cntnrmv_seq_id
      FROM   DUAL;

      v_moved_time := TO_CHAR(p_shipment_dt, 'HH24:MI:SS');

      INSERT INTO at_container_movements(cntnrmv_seq_id
                                        ,cntnr_seq_id
                                        ,moved_dt
                                        ,moved_time
                                        ,starting_storloc_seq_id
                                        ,ending_storloc_seq_id
                                        ,seg_stf_seq_id)
      VALUES      (v_cntnrmv_seq_id
                  ,p_cntnr_seq_id
                  ,p_shipment_dt
                  ,TO_DATE(v_moved_time, 'HH24:MI:SS')
                  ,p_starting_loc_seq_id
                  ,p_ending_loc_seq_id
                  ,p_shipper_seg_stf_seq_id);
      /* The original swallowed every error here.  A comment in the form says the
       * POST-DELETE and POST-FORMS-COMMIT triggers have always failed this insert
       * silently, that it was found during TFS 2450, and that it was left alone
       * for lack of time.  It is left alone here too: raising where the legacy
       * swallowed would change behaviour the rest of the system has adapted to.
       * Recorded in rules/common/LEGACY-WARTS.md rather than fixed. */
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END at5510_update_loaded_movement;

-- ---------------------------------------------------------------------------
  PROCEDURE at5510_bucket_shipment(p_outshipmt_seq_id  IN NUMBER
                           ,p_manifest_nbr      IN VARCHAR2
                           ,p_disp_site_seq_id  IN NUMBER
                           ,p_has_containers    IN VARCHAR2) IS
    count_storage   NUMBER := 0;

    CURSOR shipment_cur IS
      SELECT cntnr_seq_id
      FROM   at_outshipment_containers
      WHERE  outshipmt_seq_id = p_outshipmt_seq_id;

    CURSOR storage_container IS
      SELECT a.cntnr_seq_id
            ,b.outshipmt_seq_id
      FROM   at_containers a
            ,at_outshipment_containers b
            ,at_containers c
      WHERE      b.outshipmt_seq_id = p_outshipmt_seq_id
             AND b.cntnr_seq_id = c.cntnr_seq_id
             AND a.within_cntnr_seq_id = c.cntnr_seq_id
             AND c.cntnr_seq_id NOT IN (SELECT d.cntnr_seq_id
                                        FROM   at_overpack_masters_view d
                                        WHERE  c.cntnr_seq_id = d.cntnr_seq_id);
  BEGIN
    IF p_manifest_nbr IS NULL AND p_outshipmt_seq_id IS NULL THEN
      rule_error('You must have a Burial Shipment created before generating the Bucketing');
    END IF;

    IF p_has_containers IS NULL THEN
      rule_error('You must have at least one container on the Burial Shipment before generating the Bucketing');
    END IF;

    FOR ship_rec IN shipment_cur LOOP
      SELECT COUNT(*)
      INTO   count_storage
      FROM   at_containers
      WHERE  within_cntnr_seq_id = ship_rec.cntnr_seq_id;

      IF count_storage > 0 THEN
        UPDATE at_containers
        SET    disp_site_seq_id = p_disp_site_seq_id
        WHERE  cntnr_seq_id = ship_rec.cntnr_seq_id;
      END IF;
    END LOOP;

    FOR rec IN storage_container LOOP
      pop_cntnr_proc_amt(rec.cntnr_seq_id);

      UPDATE at_processed_amounts
      SET    outshipmt_seq_id = rec.outshipmt_seq_id
      WHERE  cntnr_seq_id = rec.cntnr_seq_id;
    END LOOP;

    fix_pa_diff(NULL, p_outshipmt_seq_id);
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = c_rule_error THEN
        RAISE;
      END IF;
      RAISE_APPLICATION_ERROR(c_unexpected, 'Error: BUCKET_SHIPMENT (Procedure Body). ' || SQLERRM);
  END at5510_bucket_shipment;

-- ---------------------------------------------------------------------------
  PROCEDURE at5510_set_location(p_outshipmt_seq_id        IN NUMBER
                        ,p_shipment_nbr            IN VARCHAR2
                        ,p_shipment_dt             IN DATE
                        ,p_shipper_seg_stf_seq_id  IN NUMBER) IS
    from_location     NUMBER;
    to_location       NUMBER;
    pick_up_cust      NUMBER;
    in_cntnr_stat     VARCHAR2(20) := 'SHIPPING_';
    lv_new_stat       VARCHAR2(20);
    lv_locat_phrase   VARCHAR2(30);

    CURSOR shipping_containers IS
      SELECT cntnr_seq_id
      FROM   at_outshipment_containers
      WHERE  outshipmt_seq_id = p_outshipmt_seq_id;

    /* AT_OVERPACK_DETAILS does not exist on any instance; the view does, and it
     * is what Forms actually reaches.  Confirmed with the API side. */
    CURSOR overpack_cursor(in_overpack_master NUMBER) IS
      SELECT cntnr_seq_id
      FROM   at_overpack_details_view
      WHERE  parent_cntnr_seq_id = in_overpack_master;

    CURSOR storage_cursor(in_outer_cntnr NUMBER) IS
      SELECT cntnr_seq_id
      FROM   at_containers
      WHERE  within_cntnr_seq_id = in_outer_cntnr;
  BEGIN
    BEGIN
      SELECT cust.customer_nbr
      INTO   pick_up_cust
      FROM   at_shipments ship
            ,at_customers cust
      WHERE      ship.pick_up_cust_seq_id = cust.cust_seq_id
             AND ship.shipment_nbr = p_shipment_nbr;
    EXCEPTION
      WHEN OTHERS THEN
        rule_error('Pick-up customer does not exist for this Order Shipment, and is needed to set "From" location for transferred barcodes.');
    END;

    BEGIN
      /* TM3928 MSC task to remove hard coding.
       * Burial: FROM one site TO offsite.  Start = pickup site (SHIPPING_xx),
       * end = OFFSITE. */
      SELECT in_cntnr_stat || NVL(ss.site_cd_id, 'BC')
      INTO   lv_locat_phrase
      FROM   at_seg_sites ss
            ,at_customers cust
      WHERE      ss.cust_seq_id = cust.cust_seq_id
             AND cust.customer_nbr = pick_up_cust;

      to_location   := locations.get_storage_location_seq(lv_locat_phrase);
      from_location := locations.get_storage_location_seq('OFFSITE');
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        rule_error('Could not locate storage location information for Loaded.');
      WHEN OTHERS THEN
        rule_error('Error retrieving storage location seq for Loaded location.');
    END;

    FOR ship_cntnr IN shipping_containers LOOP
      set_cntnr_status_global(ship_cntnr.cntnr_seq_id
                             ,'xxxx'
                             ,NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
                             ,lv_new_stat);

      IF at5510_overpack_exists(ship_cntnr.cntnr_seq_id) THEN
        at5510_update_loaded_movement(ship_cntnr.cntnr_seq_id, from_location, to_location
                              ,p_shipment_dt, p_shipper_seg_stf_seq_id);

        FOR innerpack IN overpack_cursor(ship_cntnr.cntnr_seq_id) LOOP
          at5510_update_loaded_movement(innerpack.cntnr_seq_id, from_location, to_location
                                ,p_shipment_dt, p_shipper_seg_stf_seq_id);
        END LOOP;

      ELSIF at5510_storage_cntnr_exists(ship_cntnr.cntnr_seq_id) THEN
        at5510_update_loaded_movement(ship_cntnr.cntnr_seq_id, from_location, to_location
                              ,p_shipment_dt, p_shipper_seg_stf_seq_id);

        FOR inner_c IN storage_cursor(ship_cntnr.cntnr_seq_id) LOOP
          IF at5510_overpack_exists(inner_c.cntnr_seq_id) THEN
            at5510_update_loaded_movement(inner_c.cntnr_seq_id, from_location, to_location
                                  ,p_shipment_dt, p_shipper_seg_stf_seq_id);

            FOR innerpack IN overpack_cursor(inner_c.cntnr_seq_id) LOOP
              at5510_update_loaded_movement(innerpack.cntnr_seq_id, from_location, to_location
                                    ,p_shipment_dt, p_shipper_seg_stf_seq_id);
            END LOOP;
          ELSE
            at5510_update_loaded_movement(inner_c.cntnr_seq_id, from_location, to_location
                                  ,p_shipment_dt, p_shipper_seg_stf_seq_id);
          END IF;
        END LOOP;

      ELSE
        at5510_update_loaded_movement(ship_cntnr.cntnr_seq_id, from_location, to_location
                              ,p_shipment_dt, p_shipper_seg_stf_seq_id);
      END IF;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = c_rule_error THEN
        RAISE;
      END IF;
      RAISE_APPLICATION_ERROR(c_unexpected, 'Error: SET_LOCATION (Procedure Body). ' || SQLERRM);
  END at5510_set_location;

-- ---------------------------------------------------------------------------
  PROCEDURE at5510_update_status(p_outshipmt_seq_id  IN NUMBER
                         ,p_in_cntnr_stat     IN VARCHAR2
                         ,p_from_location     IN NUMBER
                         ,p_to_location       IN NUMBER
                         ,p_shipment_dt       IN DATE
                         ,p_shipper_stf_id    IN NUMBER) IS
    lv_new_stat   VARCHAR2(20);

    CURSOR shipping_containers IS
      SELECT cntnr_seq_id
      FROM   at_outshipment_containers
      WHERE  outshipmt_seq_id = p_outshipmt_seq_id;

    CURSOR overpack_cursor(in_overpack_master NUMBER) IS
      SELECT cntnr_seq_id
      FROM   at_overpack_details_view
      WHERE  parent_cntnr_seq_id = in_overpack_master;

    CURSOR storage_cursor(in_outer_cntnr NUMBER) IS
      SELECT cntnr_seq_id
      FROM   at_containers
      WHERE  within_cntnr_seq_id = in_outer_cntnr;
  BEGIN
    FOR ship_cntnr IN shipping_containers LOOP
      set_cntnr_status_global(ship_cntnr.cntnr_seq_id
                             ,'xxxx'
                             ,NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
                             ,lv_new_stat);

      at5510_update_movement(ship_cntnr.cntnr_seq_id, p_from_location, p_to_location, p_shipper_stf_id);

      FOR innerpack IN overpack_cursor(ship_cntnr.cntnr_seq_id) LOOP
        at5510_update_movement(innerpack.cntnr_seq_id, p_from_location, p_to_location, p_shipper_stf_id);
      END LOOP;

      FOR inner_c IN storage_cursor(ship_cntnr.cntnr_seq_id) LOOP
        at5510_update_movement(inner_c.cntnr_seq_id, p_from_location, p_to_location, p_shipper_stf_id);

        FOR innerpack IN overpack_cursor(inner_c.cntnr_seq_id) LOOP
          at5510_update_movement(innerpack.cntnr_seq_id, p_from_location, p_to_location, p_shipper_stf_id);
        END LOOP;
      END LOOP;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = c_rule_error THEN
        RAISE;
      END IF;
      RAISE_APPLICATION_ERROR(c_unexpected, 'Error: UPDATE_STATUS (Procedure Body). ' || SQLERRM);
  END at5510_update_status;

/* ===========================================================================
 * AT3250 - Maintain Container Rental Status
 * =========================================================================== */

  PROCEDURE at3250_key_delrec(p_rncntnrstat_cd_id IN VARCHAR2) IS
  BEGIN
    IF NOT rental_container_status.status_ok_to_delete(p_rncntnrstat_cd_id) THEN
      rule_error('This status cannot be deleted as it is required by the Order Shipments module');
    END IF;
  EXCEPTION
    WHEN e_abort THEN
      RAISE;
    WHEN OTHERS THEN
      -- the trigger has no handler: an Oracle error would reach the operator as
      -- FRM-40735 with the ORA- text.  The text is kept, the unit is named.
      RAISE_APPLICATION_ERROR(c_unexpected, 'Error: KEY-DELREC RNCNTNRST. ' || SQLERRM);
  END at3250_key_delrec;

/* ===========================================================================
 * AT5132 - Maintain Container Next Process
 * =========================================================================== */

  PROCEDURE at5132_post_query(p_cntnr_seq_id IN NUMBER) IS
  BEGIN
    pop_valid_npc(p_cntnr_seq_id);
  EXCEPTION
    WHEN e_abort THEN
      RAISE;
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(c_unexpected, 'Error: POST-QUERY CNTNR1.(Data Block Level). ' || SQLERRM);
  END at5132_post_query;

-- ---------------------------------------------------------------------------
  PROCEDURE at5132_when_validate_item(p_cntnr_seq_id           IN NUMBER
                                     ,p_dsp_prctrantyp_cd_id   IN VARCHAR2
                                     ,p_current_user           IN VARCHAR2) IS
    return_msg   VARCHAR2(500);
  BEGIN
    IF (p_dsp_prctrantyp_cd_id IS NOT NULL) THEN
      return_msg := NULL;
      compare_lic(FALSE, p_cntnr_seq_id, p_dsp_prctrantyp_cd_id,
                  p_current_user, return_msg, NULL /* :cntnr1.ord_seq, never set */);
      IF return_msg <> 'GOOD' THEN
        rule_error(return_msg);
      END IF;
    END IF;
  EXCEPTION
    WHEN e_abort THEN
      RAISE;
    WHEN OTHERS THEN
      -- the trigger has no handler: Forms would show FRM-40735 with the ORA- text
      RAISE_APPLICATION_ERROR(c_unexpected, 'Error: WHEN-VALIDATE-ITEM CNTNR1.DSP_PRCTRANTYP_CD_ID. ' || SQLERRM);
  END at5132_when_validate_item;

-- ---------------------------------------------------------------------------
  /* MAKE_THE_CONNECTION, the form unit POST-UPDATE calls, as written. */
  PROCEDURE at5132_make_the_connection(p_cntnr_seq_id           IN NUMBER
                                      ,p_dsp_prctrantyp_cd_id   IN VARCHAR2
                                      ,p_current_user           IN VARCHAR2) IS
    return_msg   VARCHAR2(500);
    CURSOR c1(arg_prctrantyp_cd_id at_process_trans_types.prctrantyp_cd_id%TYPE) IS
        SELECT prctrantyp_seq_id
              ,map_ind
        FROM   at_process_trans_types
        WHERE  prctrantyp_cd_id = arg_prctrantyp_cd_id;
    c1_rec       c1%ROWTYPE;
  BEGIN
    OPEN c1(p_dsp_prctrantyp_cd_id);
    FETCH c1
        INTO c1_rec;
    IF c1%NOTFOUND THEN
        CLOSE c1;
        rule_error('This Process transaction does not exist in Accutrack System');
    END IF;
    return_msg   := NULL;
    compare_lic(TRUE
               ,p_cntnr_seq_id
               ,p_dsp_prctrantyp_cd_id
               ,p_current_user
               ,return_msg
               ,NULL /* :cntnr1.ord_seq, never set */);
    IF return_msg <> 'GOOD' THEN
        rule_error(return_msg);
    END IF;
    CLOSE c1;
  EXCEPTION
    WHEN e_abort THEN
        IF c1%ISOPEN THEN CLOSE c1; END IF;
        RAISE;
    WHEN OTHERS THEN
        IF c1%ISOPEN THEN CLOSE c1; END IF;
        RAISE_APPLICATION_ERROR(c_unexpected, 'Error: MAKE_THE_CONNECTION (Procedure Body). ' || SQLERRM);
  END at5132_make_the_connection;

-- ---------------------------------------------------------------------------
  PROCEDURE at5132_post_update(p_cntnr_seq_id             IN NUMBER
                              ,p_next_prctrantyp_seq_id   IN NUMBER
                              ,p_dsp_prctrantyp_cd_id     IN VARCHAR2
                              ,p_current_user             IN VARCHAR2
                              ,p_modified_dt              IN VARCHAR2) IS
    v_modified_dt   at_containers.modified_dt%TYPE;
  BEGIN
    -- Forms' re-read and lock before an update: the row must still be as the screen read it
    SELECT modified_dt
    INTO   v_modified_dt
    FROM   at_containers
    WHERE  cntnr_seq_id = p_cntnr_seq_id
    FOR UPDATE NOWAIT;
    IF p_modified_dt IS NOT NULL
       AND (v_modified_dt IS NULL
            OR v_modified_dt <> TO_DATE(p_modified_dt, 'YYYY-MM-DD"T"HH24:MI:SS')) THEN
      rule_error('FRM-40654: Record has been updated by another user. Re-query to see change.');
    END IF;

    -- the UPDATE Forms issues for this block
    UPDATE at_containers
    SET    next_prctrantyp_seq_id = p_next_prctrantyp_seq_id
    WHERE  cntnr_seq_id = p_cntnr_seq_id;

    -- POST-UPDATE on CNTNR1
    at5132_make_the_connection(p_cntnr_seq_id, p_dsp_prctrantyp_cd_id, p_current_user);
  EXCEPTION
    WHEN e_abort THEN
      RAISE;
    WHEN NO_DATA_FOUND THEN
      -- the container is gone since the query, as Forms reports it
      rule_error('FRM-40652: Cannot lock table or view.  Record deleted by another user.');
    WHEN OTHERS THEN
      IF SQLCODE = -54 THEN
        -- another session holds the row (ORA-00054, NOWAIT), as Forms reports it
        rule_error('FRM-40501: ORACLE error: unable to reserve record for update or delete.');
      END IF;
      RAISE_APPLICATION_ERROR(c_unexpected, 'Error: POST-UPDATE CNTNR1.(Data Block Level). ' || SQLERRM);
  END at5132_post_update;

/* ===========================================================================
 * AT5110 - Container Movement
 * =========================================================================== */

  /* ADD_TIME_TO_DATE, program unit of at5110.fmb, as it is (the RETURN NULL after
   * the RETURN is the legacy's, unreachable there too). */
  FUNCTION at5110_add_time_to_date ( P_DATE_ITEM   IN  DATE,
                                     P_TIME_ITEM   IN  DATE) RETURN DATE IS

  BEGIN

      RETURN( TO_DATE(TO_CHAR(P_DATE_ITEM,'DD/MM/YYYY')||' '||
                     TO_CHAR(P_TIME_ITEM,'HH:MI PM'),'DD/MM/YYYY HH:MI PM'));

      RETURN NULL; EXCEPTION
       WHEN VALUE_ERROR THEN
        RETURN (NULL);
  END at5110_add_time_to_date;

-- ---------------------------------------------------------------------------
  /* STORAGE_CONTAINER_EXISTS, program unit of at5110.fmb, as it is.  (AT5510's
   * unit of the same name differs: at5510_storage_cntnr_exists.) */
  FUNCTION at5110_storage_cntnr_exists(IN_CNTNR  IN  NUMBER)
  RETURN BOOLEAN
  IS
    STORAGE_CNT  NUMBER;
  BEGIN
     SELECT COUNT(CNTNR_SEQ_ID)
     INTO STORAGE_CNT
     FROM AT_CONTAINERS
     WHERE CNTNR_SEQ_ID IN (
           SELECT CNTNR_SEQ_ID
           FROM AT_CONTAINERS
           WHERE WITHIN_CNTNR_SEQ_ID = IN_CNTNR);
     --
     IF STORAGE_CNT > 0
     THEN
         RETURN(TRUE);
     ELSE
     	   RETURN(FALSE);
     END IF;
     --
  END at5110_storage_cntnr_exists;

-- ---------------------------------------------------------------------------
  /* DOUBLE_CONTAINER_LOC, program unit of at5110.fmb, as it is: every error is
   * swallowed, the operator is NULL, and MOVED_TIME is today's time on Oracle's
   * default date part (TO_DATE of 'HH24:MI:SS'). */
  PROCEDURE at5110_double_container_loc(IN_CNTNR  IN NUMBER)
  IS
  	  current_location_OUTER  NUMBER;
      current_date_moved    date;
      MOVEMENT_SEQ          NUMBER;
      append_sec_time       varchar2(20)  := null;
      STARTING_LOC_SEQ      NUMBER;
      ENDING_LOC_SEQ        NUMBER;
  --
      CURSOR INNER_CONTAINERS IS
         SELECT CNTNR_SEQ_ID
         FROM AT_CONTAINERS
         WHERE WITHIN_CNTNR_SEQ_ID = IN_CNTNR;
  --
  BEGIN
  --
  -- SET LOCATION OF THE CONTAINER INSIDE TO THE LOCATION OF THE
  -- OUTER CONTAINER (STORAGE CONTAINER)
  --
    BEGIN
      -- Retrieve current container FOR OUTER CONTAINER
      select  S1.STORLOC_SEQ_ID
        into  current_location_OUTER
        from  at_container_movements cntnrmov ,
              at_storage_locations S1
       where
              S1.storloc_seq_id = cntnrmov.ending_storloc_seq_id
          and CNTNRMOV.CNTNRMV_SEQ_ID = MAX_MOVE_DT(IN_CNTNR);
      --
      -- LOOP THROUGH INNER CONTAINERS AND SET THE INNER CONTAINER LOCATION TO THE OUTER CONTAINER
      --
      FOR REC IN INNER_CONTAINERS
      LOOP
      --
      -- GET CURRENT LOCATION FOR INNER CONTAINER
      --
       BEGIN
        select  S1.STORLOC_SEQ_ID
        into  STARTING_LOC_SEQ
        from  at_container_movements cntnrmov ,
              at_storage_locations S1
        where
              S1.storloc_seq_id = cntnrmov.ending_storloc_seq_id
          and CNTNRMOV.CNTNRMV_SEQ_ID = MAX_MOVE_DT(REC.CNTNR_SEQ_ID);
      --
        exception
        when others then
             STARTING_LOC_SEQ := NULL;
       --
       END;
      --
       BEGIN
        select cntnrmv_seq.nextval
        into movement_seq
        from dual;
      --
        append_sec_time := to_char(sysdate, 'HH24:MI:SS');
        insert into AT_CONTAINER_MOVEMENTs(CNTNRMV_SEQ_ID ,
                                          CNTNR_SEQ_ID,
                                          MOVED_DT,
                                          moved_time,
                                          STARTING_STORLOC_SEQ_ID,
                                          ENDING_STORLOC_SEQ_ID,
                                          seg_stf_seq_id)
                                  values (movement_seq,
                                          REC.CNTNR_SEQ_ID,
                                          SYSDATE,
                                          to_date(append_sec_time,'HH24:MI:SS'),
                                          STARTING_LOC_SEQ,
                                          CURRENT_LOCATION_OUTER,
                                          NULL);

        exception
          when others then
              NULL;
       END;

      END LOOP;

     exception
     when others then
        NULL;

    end;

  END at5110_double_container_loc;

-- ---------------------------------------------------------------------------
  /* WHEN-BUTTON-PRESSED on CONT$CTRL.CNTNR_MOVE_OK_BUTTON.  The trigger's text,
   * with :cont$ctrl.* as parameters and :container.* as the current record of the
   * two lists; what only moves the cursor or the screen is left as a comment. */
  PROCEDURE at5110_cntnr_move_ok(p_move_location          IN VARCHAR2
                                ,p_move_location_seq_id   IN NUMBER
                                ,p_move_date              IN VARCHAR2
                                ,p_move_time              IN VARCHAR2
                                ,p_move_operator          IN VARCHAR2
                                ,p_move_operator_seq_id   IN NUMBER
                                ,p_blank_container        IN VARCHAR2
                                ,p_cntnr_seq_ids          IN VARCHAR2
                                ,p_container_ids          IN VARCHAR2
                                ,p_moved                  OUT NUMBER
                                ,p_all_moved              OUT VARCHAR2
                                ,p_notices                OUT VARCHAR2) IS
      TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
      TYPE t_str IS TABLE OF VARCHAR2(4000) INDEX BY PLS_INTEGER;
      l_seqs           t_num;                -- the CONTAINER block's records, in order
      l_ids            t_str;
      l_count          PLS_INTEGER := 0;
      l_container_id   VARCHAR2(4000);       -- :container.container_id of the current record
      l_cntnr_seq_id   NUMBER;               -- :container.cntnr_seq_id of the current record
      l_move_date      DATE;                 -- :cont$ctrl.move_date
      l_move_time      DATE;                 -- :cont$ctrl.move_time
      l_notices        VARCHAR2(32767);

      counter          NUMBER := 0;
      seq_id           NUMBER;
      msg              VARCHAR2(2000);
      all_moved        BOOLEAN := TRUE;
      move_ok          VARCHAR2(10);
      valid            BOOLEAN
                           :=     (p_move_location IS NOT NULL)
                              AND (p_move_date IS NOT NULL)
                              AND (p_move_time IS NOT NULL)
                              AND (p_move_operator IS NOT NULL);

      msg_cnt          NUMBER := 0;
      reason           VARCHAR2(250);
      burial_loc1      VARCHAR2(1);
      stockpile_ind1   VARCHAR2(1);

      -- alert_user(msg, 'I', 'NOFAIL'): the message is shown and the trigger carries on
      PROCEDURE notice(p_msg IN VARCHAR2) IS
      BEGIN
          l_notices := SUBSTR(l_notices || CASE WHEN l_notices IS NOT NULL THEN CHR(10) END || p_msg, 1, 32767);
      END notice;

      -- one line of a CHR(10) list; an empty line is NULL
      FUNCTION line_of(p_list IN VARCHAR2, p_n IN PLS_INTEGER) RETURN VARCHAR2 IS
          l_from   PLS_INTEGER := 1;
          l_to     PLS_INTEGER;
      BEGIN
          FOR i IN 1 .. p_n - 1 LOOP
              l_from   := INSTR(p_list, CHR(10), l_from) + 1;
          END LOOP;
          l_to   := INSTR(p_list, CHR(10), l_from);
          RETURN CASE WHEN l_to = 0 THEN SUBSTR(p_list, l_from) ELSE SUBSTR(p_list, l_from, l_to - l_from) END;
      END line_of;

      FUNCTION movement(cntnr_sid IN at_containers.cntnr_seq_id%TYPE, container_id IN at_containers.container_id%TYPE)
          RETURN BOOLEAN IS
          CURSOR prior_mvmt IS
              SELECT   cntnrmv_seq_id
                      ,ending_storloc_seq_id
                      ,starting_storloc_seq_id
              FROM     at_container_movements
              WHERE        (   moved_dt < l_move_date
                            OR     moved_dt = l_move_date
                               AND moved_time < l_move_time)
                       AND cntnr_seq_id = cntnr_sid
              ORDER BY moved_dt DESC, moved_time DESC;

          CURSOR next_mvmt IS
              SELECT   cntnrmv_seq_id
                      ,ending_storloc_seq_id
                      ,starting_storloc_seq_id
              FROM     at_container_movements
              WHERE        (   moved_dt > l_move_date
                            OR     moved_dt = l_move_date
                               AND moved_time > l_move_time)
                       AND cntnr_seq_id = cntnr_sid
              ORDER BY moved_dt ASC, moved_time ASC;

          CURSOR offsite_sid IS
              SELECT storloc_seq_id
              FROM   at_storage_locations
              WHERE  storage_location_id = 'OFFSITE';

          the_time        DATE;
          next_move       next_mvmt%ROWTYPE;
          prior_move      prior_mvmt%ROWTYPE;
          offsite         at_storage_locations.storloc_seq_id%TYPE;
          inserted        BOOLEAN := FALSE;
          burial_loc      VARCHAR2(1);
          stockpile_ind   VARCHAR2(1);
          cntnr_stat      VARCHAR2(50);
      BEGIN
          BEGIN
              SELECT NVL(landfill_ind, 'N')
              INTO   stockpile_ind
              FROM   at_storage_locations
              WHERE  storloc_seq_id = p_move_location_seq_id;
          EXCEPTION
              WHEN OTHERS THEN
                  stockpile_ind   := 'N';
          END;

          BEGIN
              SELECT NVL(lift_ind, 'N')
              INTO   burial_loc
              FROM   at_storage_locations
              WHERE  storloc_seq_id = p_move_location_seq_id;
          EXCEPTION
              WHEN OTHERS THEN
                  burial_loc   := 'N';
          END;

          BEGIN
              SELECT cntnr_stat_cd_id
              INTO   cntnr_stat
              FROM   at_containers
              WHERE  cntnr_seq_id = cntnr_sid;
          EXCEPTION
              WHEN OTHERS THEN
                  cntnr_stat   := 'NONE';
          END;

          the_time   := at5110_add_time_to_date(l_move_date, l_move_time);

          OPEN prior_mvmt;

          FETCH prior_mvmt
              INTO prior_move;

          CLOSE prior_mvmt;

          OPEN next_mvmt;

          FETCH next_mvmt
              INTO next_move;

          CLOSE next_mvmt;

          IF prior_move.ending_storloc_seq_id = p_move_location_seq_id THEN
              msg        := 'Warning: New Location is same as Current Location for container ' || l_container_id || '.';
              notice(msg);
              -- BELL;
          END IF;

          SELECT cntnrmv_seq.NEXTVAL
          INTO   seq_id
          FROM   DUAL;

          INSERT INTO at_container_movements(cntnrmv_seq_id
                                            ,cntnr_seq_id
                                            ,moved_dt
                                            ,ending_storloc_seq_id
                                            ,starting_storloc_seq_id
                                            ,moved_time
                                            ,seg_stf_seq_id)
          VALUES      (seq_id
                      ,cntnr_sid
                      ,l_move_date
                      ,p_move_location_seq_id
                      ,p_move_location_seq_id
                      ,the_time
                      ,p_move_operator_seq_id);

          RETURN (TRUE);
      EXCEPTION
          WHEN OTHERS THEN
              RETURN (FALSE);
      END;
  BEGIN
      -- the items' own masks, as Forms converts what was typed
      l_move_date   := TO_DATE(p_move_date, 'MM/DD/RRRR');
      l_move_time   := TO_DATE(p_move_time, 'HH:MI PM');

      -- the CONTAINER block's records: one per line of each list, which must agree
      l_count   := CASE WHEN p_container_ids IS NULL THEN 1 ELSE LENGTH(p_container_ids) - LENGTH(REPLACE(p_container_ids, CHR(10))) + 1 END;
      IF l_count <> CASE WHEN p_cntnr_seq_ids IS NULL THEN 1 ELSE LENGTH(p_cntnr_seq_ids) - LENGTH(REPLACE(p_cntnr_seq_ids, CHR(10))) + 1 END THEN
          RAISE_APPLICATION_ERROR(c_unexpected, 'AT5110: the container lists do not have the same number of records.');
      END IF;
      FOR i IN 1 .. l_count LOOP
          l_ids(i)    := line_of(p_container_ids, i);
          l_seqs(i)   := TO_NUMBER(line_of(p_cntnr_seq_ids, i));
      END LOOP;

      IF valid THEN
          BEGIN
              SELECT NVL(landfill_ind, 'N')
              INTO   stockpile_ind1
              FROM   at_storage_locations
              WHERE  storloc_seq_id = p_move_location_seq_id;
          EXCEPTION
              WHEN OTHERS THEN
                  stockpile_ind1   := 'N';
          END;

          BEGIN
              SELECT NVL(lift_ind, 'N')
              INTO   burial_loc1
              FROM   at_storage_locations
              WHERE  storloc_seq_id = p_move_location_seq_id;
          EXCEPTION
              WHEN OTHERS THEN
                  burial_loc1   := 'N';
          END;

          -- response := alert_user('Moving all entered containers ... one moment please', 'I', 'NOFAIL');
          --   shown by the screen before the call

          -- GO_BLOCK('CONTAINER'); LAST_RECORD;
          IF     l_ids(l_count) IS NULL
             AND p_blank_container = 'Y' THEN
              -- CLEAR_RECORD; (:cont$ctrl.blank_container := 'N' is the screen's)
              l_count   := l_count - 1;
          END IF;

          -- Forms keeps one record in a block it has cleared: the loop below then runs once, on an
          -- empty record, which MOVEMENT cannot insert ("Container  not moved").  Kept.
          IF l_count = 0 THEN
              l_count     := 1;
              l_ids(1)    := NULL;
              l_seqs(1)   := NULL;
          END IF;

          -- FIRST_RECORD; LOOP ... IF :SYSTEM.LAST_RECORD = 'TRUE' THEN EXIT; ELSE NEXT_RECORD; END IF;
          FOR r IN 1 .. l_count LOOP
              l_container_id   := l_ids(r);
              l_cntnr_seq_id   := l_seqs(r);

              IF    stockpile_ind1 = 'Y'
                 OR burial_loc1 = 'Y' THEN
                  SELECT can_cntnr_go_burial(l_container_id)
                  INTO   move_ok
                  FROM   DUAL;

                  IF move_ok = 'FALSE' THEN
                      IF msg_cnt < 1 THEN
                          SELECT get_cntnr_nomove_reason(l_container_id)
                          INTO   reason
                          FROM   DUAL;

                          msg        := 'Error: The container ' || l_container_id || ' should not be moved to a stockpile or lift because ' || reason;
                          notice(msg);
                          msg_cnt    := msg_cnt + 1;
                          -- BELL;
                      END IF;

                      IF movement(l_cntnr_seq_id, l_container_id) THEN
                          counter   := counter + 1;

                          IF at5110_storage_cntnr_exists(l_cntnr_seq_id) THEN
                              at5110_double_container_loc(l_cntnr_seq_id);
                          END IF;
                      ELSE
                          all_moved   := FALSE;
                          msg         := 'Container ' || l_container_id || ' not moved';
                          notice(msg);
                      END IF;
                  ELSE
                      IF movement(l_cntnr_seq_id, l_container_id) THEN
                          counter   := counter + 1;

                          IF at5110_storage_cntnr_exists(l_cntnr_seq_id) THEN
                              at5110_double_container_loc(l_cntnr_seq_id);
                          END IF;
                      ELSE
                          all_moved   := FALSE;
                          msg         := 'Container ' || l_container_id || ' not moved';
                          notice(msg);
                      END IF;
                  END IF;
              ELSE  --not burial
                  IF movement(l_cntnr_seq_id, l_container_id) THEN
                      counter   := counter + 1;

                      IF at5110_storage_cntnr_exists(l_cntnr_seq_id) THEN
                          at5110_double_container_loc(l_cntnr_seq_id);
                      END IF;
                  ELSE
                      all_moved   := FALSE;
                      msg         := 'Container ' || l_container_id || ' not moved';
                      notice(msg);
                  END IF;
              END IF;
          END LOOP;

          msg                     := TO_CHAR(counter) || ' Containers Moved';
          notice(msg);

          -- IF all_moved THEN the screen clears :cont$ctrl.move_location, move_date, move_time and
          -- move_operator (p_all_moved).
          -- :SYSTEM.message_level := 5; DO_KEY('COMMIT_FORM'): this call is one transaction, committed
          -- when it returns.  GO_BLOCK('container'); CLEAR_BLOCK; GO_ITEM('CONT$CTRL.MOVE_LOCATION'):
          -- the screen's.
          p_moved       := counter;
          p_all_moved   := CASE WHEN all_moved THEN 'Y' ELSE 'N' END;
          p_notices     := l_notices;
      ELSE
          msg        := 'Move Location, Date, Time and Operator must be entered';
          rule_error(msg);   -- alert_user(msg, 'S', 'FAIL')
      END IF;
  EXCEPTION
      WHEN e_abort THEN
          RAISE;
      WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(c_unexpected, 'Error: WHEN-BUTTON-PRESSED CONT$CTRL.CNTNR_MOVE_OK_BUTTON. ' || SQLERRM);
  END at5110_cntnr_move_ok;

  -- >>> generated by scripts/jdapi/contract.cjs --lov-sql: lists of values run as the form wrote them
-- AT1310 CORP_CUST_LV: the record group's own query; P1 = :CUST9.CUST_SEQ_ID
  PROCEDURE at1310_lov_corp_cust_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select customer_nbr, name from at_customers where (cust_seq_id <> :b1 or :b2 is null ) order by customer_nbr
) WHERE ROWNUM <= 5000~'
      USING p1, p1;
  END;

  -- AT1310 LV_CUST_BUS_TYP_LST: the record group's own query; P1 = :CUSTBUSTYP4.DSP_SEG_CD
  PROCEDURE at1310_lov_lv_cust_bus_typ_lst(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select seg_cd, substr(description,1,25) description,bus_typ_seq_id from at_business_types where seg_cd like (:b1 || '%') order by seg_cd
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1310 LV_CUST_CUST_NBR_NAMES: the record group's own query; P1 = :CUST9.CUST_SEQ_ID
  PROCEDURE at1310_lov_lv_cust_cust_nbr_na(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select customer_nbr, name from at_customers where (cust_seq_id <> :b1 or :b2 is null ) order by customer_nbr
) WHERE ROWNUM <= 5000~'
      USING p1, p1;
  END;

  -- AT1310 LV_LIC_REST_LST: the record group's own query
  PROCEDURE at1310_lov_lv_lic_rest_lst(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select substr(rv_low_value,1,1) rv_low_value, substr(rv_meaning,1,100) rv_meaning from cg_ref_codes where (rv_domain = 'AT_CUSTOMER_LICENSES.LICENSE_RESTRICTION_CD') order by rv_low_value
) WHERE ROWNUM <= 5000~';
  END;

  -- AT1310 LV_SEG_STF_LST: the record group's own query; P1 = :CUSTSEGSTF17.DSP_LAST_NAME
  PROCEDURE at1310_lov_lv_seg_stf_lst(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select substr(last_name,1,25) last_name, substr(first_name,1,25) first_name,badge_nbr,seg_stf_seq_id from at_seg_staff where last_name like (:b1 || '%') and status_cd = 'A' order by last_name
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1310 LV_STATE_PROVINCE_COUNTRIES: the record group's own query
  PROCEDURE at1310_lov_lv_state_province_c(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select sp.st_prvnc_abbr_id , sp.name , sp.cntry_postal_id , c.telephone_country_cd from at_state_provinces sp , at_countries c where sp.cntry_postal_id = c.cntry_postal_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT1410 CUST_DISP_SITES_LOV: the record group's own query; P1 = :AT_CONTRACTS.CUST_SEQ_ID
  PROCEDURE at1410_lov_cust_disp_sites_lov(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   ds.code dsp_code
        ,ds.description dsp_description
        ,ds.operated_by_name dsp_operated_by_name
        ,ds.disp_site_seq_id
FROM     at_disp_sites ds
WHERE    EXISTS
             (SELECT cds.disp_site_seq_id
              FROM   at_customer_disp_sites cds
              WHERE      ds.disp_site_seq_id = cds.disp_site_seq_id
                     AND cds.cust_seq_id = :b1)
ORDER BY ds.code
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1410 CUSTOMER_LOV: the record group's own query; P1 = :AT_CONTRACTS.CUSTOMER_NBR
  PROCEDURE at1410_lov_customer_lov(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   name
        ,customer_nbr
        ,cust_seq_id
FROM     at_customers
WHERE    TO_CHAR(customer_nbr) LIKE (TO_CHAR(:b1) || '%')
ORDER BY name
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1410 SHIPPING_LOCATIONS_LOV: the record group's own query; P1 = :AT_CONTRACTS.CNTRCT_SEQ_ID, P2 = :AT_CONTRACTS.CUST_SEQ_ID
  PROCEDURE at1410_lov_shipping_locations_(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   cu.customer_nbr
        ,cu.name
        , :b1
        ,cu.cust_seq_id
FROM     at_customers cu
WHERE    cu.cust_seq_id NOT IN (SELECT csl.cust_seq_id
                                FROM   at_contract_shipping_locs csl
                                WHERE  csl.cntrct_seq_id = :b2)
ORDER BY CASE
             WHEN cu.cust_seq_id = :b3 THEN 0
             ELSE 1
         END
        ,cu.name
) WHERE ROWNUM <= 5000~'
      USING p1, p1, p2;
  END;

  -- AT1410 STATE_LOV: the record group's own query
  PROCEDURE at1410_lov_state_lov(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   sp.st_prvnc_abbr_id
        ,sp.name
        ,sp.cntry_postal_id
FROM     at_state_provinces sp
        ,at_countries c
WHERE    sp.cntry_postal_id = c.cntry_postal_id
ORDER BY sp.cntry_postal_id DESC, sp.st_prvnc_abbr_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT1510 DISP_SITE_LV: the record group's own query; P1 = :MNFST.CUST_SEQ_ID
  PROCEDURE at1510_lov_disp_site_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select ds.disp_site_seq_id,ds.code,ds.description
from at_disp_sites ds where ds.disp_site_seq_id in (select cds.disp_site_seq_id from at_customer_disp_sites cds where cds.cust_seq_id = :b1 and NVL(cds.allowed_ind,'N') = 'Y')
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1510 PROFILE_LV: the record group's own query; P1 = :MNFST.CUST_SEQ_ID
  PROCEDURE at1510_lov_profile_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select es_prof_seq_id,waste_profile_number
from at_esprofiles
where gen_cust_seq_id = :b1
and NVL(waste_rev_dt,sysdate + 1) < sysdate
and waste_profile_status = 'QC RELEASED' 
and site_cd in (select site_name from at_corp_cust_sites@atcorp
where upper(instance_name) in (select upper(parameter_value) from at_parameters where parameter_name = 'DATABASE_PREFIX'))
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1551 CGFK$CNTNR_DSP_PRCTRANTYP_CD_I: the record group's own query; P1 = :AT_INCOMING_MANIFESTS.ORD_NUM
  PROCEDURE at1551_lov_cgfk_cntnr_dsp_prct(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select DISTINCT ptt.prctrantyp_cd_id dsp_npc_code
     , ptt.description dsp_npc_description
     , ptt.prctrantyp_seq_id next_prctrantyp_seq_id 
from at_product_services ps
   , at_process_trans_services ppg
   , at_contract_prod_services cps
   , at_process_trans_types ptt
   , at_process_trans_types ptt_b 
where ptt.within_prctrantyp_seq_id = ptt_b.prctrantyp_seq_id(+)   and cps.cnprodserv_seq_id in 
    (select distinct cnprodserv_seq_id 
     from at_seg_order_line_items 
     where advnotif_seq_id = :b1 and      status_cd = 'OPEN') 
  and cps.prodserv_seq_id = ps.prodserv_seq_id
  and cps.prodserv_prodcat_seq_id = ps.prodcat_seq_id 
  and ps.prodserv_seq_id = ppg.prodserv_seq_id 
  and ppg.prctrantyp_seq_id = ptt.prctrantyp_seq_id 
    AND (NVL(CPS.GROUP_NBR,0) = 0 OR
        (NVL(CPS.GROUP_NBR,0) <> 0 
    AND NVL(CPS.SUBGROUP_NBR,0) <> 0))
order by ptt.prctrantyp_cd_id
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1551 LOV_COST: the record group's own query; P1 = :AT_INCOMING_MANIFESTS.ORD_NUM
  PROCEDURE at1551_lov_lov_cost(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT CPS.COST COST, CPS.UNIT_CD_ID UNIT_CD_ID, NVL(SOLI.ORDERED_QTY,0) ORDERED_QTY, SOLI.SEGORDLITM_SEQ_ID SEGORDLITM_SEQ_ID, PS.PRODSERV_CD PRODSERV_CD,'A' COST_TYPE, SUBSTR(PS.DESCRIPTION,1,40) PRODSERV_DESC, PS.PRODSERV_SEQ_ID PRODSERV_SEQ,SUBSTR(CPS.DESCRIPTION,1,60) SPECIAL_INS ,DS.CODE DISP_SITE
  FROM AT_PRODUCT_SERVICES PS
     , AT_CONTRACT_PROD_SERVICES CPS
     , AT_SEG_ORDER_LINE_ITEMS SOLI
     , AT_DISP_SITES DS
  WHERE PS.PRODSERV_SEQ_ID = CPS.PRODSERV_SEQ_ID
    AND CPS.DISP_SITE_SEQ_ID = DS.DISP_SITE_SEQ_ID
    AND CPS.CNPRODSERV_SEQ_ID = SOLI.CNPRODSERV_SEQ_ID
    AND SOLI.ADVNOTIF_SEQ_ID = :b1
    AND NVL(PS.INCLUDE_MAP_IND,'N') = 'Y' 
    AND SOLI.STATUS_CD = 'OPEN'
    AND (NVL(CPS.GROUP_NBR,0) = 0 OR
        (NVL(CPS.GROUP_NBR,0) <> 0 
    AND NVL(CPS.SUBGROUP_NBR,0) <> 0))
  ORDER BY PS.PRODSERV_CD, CPS.UNIT_CD_ID, CPS.COST
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1552 DAUGHTER_CONTAINERS: the record group's own query; P1 = :AT_CONTAINERS.CONTAINER_ID
  PROCEDURE at1552_lov_daughter_containers(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select DISTINCT ac.cntnr_seq_id, ac.container_id from at_containers ac, at_container_processes acp where acp.cntnr_seq_id = ac.cntnr_seq_id and acp.parent_daughter_type_cd = 'DAUGHTER' and ac.cntnr_stat_cd_id <> 'SHIPPED' and ac.container_id like :b1 order by ac.container_id
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1552 LOV_COST: the record group's own query; P1 = :LICPROC.ADVNOTIF_SEQ_ID
  PROCEDURE at1552_lov_lov_cost(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT CPS.COST COST,CPS.UNIT_CD_ID UNIT_CD_ID,NVL(SOLI.ORDERED_QTY,0) ORDERED_QTY,SOLI.SEGORDLITM_SEQ_ID SEGORDLITM_SEQ_ID,PS.PRODSERV_CD PRODSERV_CD,'A' COST_TYPE,SUBSTR(PS.DESCRIPTION,1,40) PRODSERV_DESC, PS.PRODSERV_SEQ_ID PRODSERV_SEQ_ID, SUBSTR(CPS.DESCRIPTION,1,65) SPECIAL_INS,DS.CODE DISP_SITE FROM AT_PRODUCT_SERVICES PS,AT_CONTRACT_PROD_SERVICES CPS, AT_SEG_ORDER_LINE_ITEMS SOLI,AT_DISP_SITES DS WHERE PS.PRODSERV_SEQ_ID = CPS.PRODSERV_SEQ_ID AND CPS.DISP_SITE_SEQ_ID = DS.DISP_SITE_SEQ_ID AND CPS.CNPRODSERV_SEQ_ID = SOLI.CNPRODSERV_SEQ_ID AND SOLI.ADVNOTIF_SEQ_ID = :b1 AND NVL(PS.INCLUDE_MAP_IND,'N') = 'Y' AND SOLI.STATUS_CD = 'OPEN' 
AND (NVL(CPS.GROUP_NBR,0) = 0 OR
    (NVL(CPS.GROUP_NBR,0) <> 0 AND NVL(CPS.SUBGROUP_NBR,0) <> 0))
ORDER BY PS.PRODSERV_CD, CPS.UNIT_CD_ID,CPS.COST
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1553 LOV_ORDER: the record group's own query
  PROCEDURE at1553_lov_lov_order(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select DISTINCT a.advnotif_seq_id, b.manifest_nbr from at_line_item_containers a, at_incoming_manifests b where a.advnotif_seq_id = b.advnotif_seq_id  and a.advnotif_seq_id <> '1086' order by a.advnotif_seq_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT1710 CHARGE_TO_CUST_LOV: the record group's own query
  PROCEDURE at1710_lov_charge_to_cust_lov(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   name dsp_name
        ,customer_nbr dsp_customer_nbr
        ,cust_seq_id charge_to_cust_seq_id
FROM     at_customers
WHERE    cust_seq_id IN (SELECT cust_seq_id
                         FROM   at_contracts)
ORDER BY name
) WHERE ROWNUM <= 5000~';
  END;

  -- AT1710 INV_CONTRACT_NBR: the record group's own query; P1 = :INV.CHARGE_TO_CUST_SEQ_ID
  PROCEDURE at1710_lov_inv_contract_nbr(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   c.inv_contract_nbr
        ,c.inv_deliv_ord_cust_mod
        ,c.contract_nbr
        ,NVL(c.payment_terms_txt, 'NET 30 Days') payment_terms_txt
        ,c.cntrct_seq_id
        ,c.effective_dt
        ,c.expiration_dt
FROM     at_contracts c
WHERE        c.cust_seq_id = :b1
         AND c.mod_cntrct_id IN (SELECT MAX(c1.mod_cntrct_id)
                                 FROM   at_contracts c1
                                 WHERE      c1.contract_nbr = c.contract_nbr
                                        AND NVL(approved_ind, 'N') = 'Y'
                                        AND c1.cust_seq_id = :b2)
ORDER BY inv_contract_nbr, contract_nbr, inv_deliv_ord_cust_mod
) WHERE ROWNUM <= 5000~'
      USING p1, p1;
  END;

  -- AT1710 INV_SEG_STAFF: the record group's own query
  PROCEDURE at1710_lov_inv_seg_staff(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT seg_stf_seq_id
      ,first_name
      ,SUBSTR(middle_name, 1, 1) middle_name
      ,last_name
FROM   at_seg_staff
WHERE      seg_dept_seq_id IN (SELECT seg_dept_seq_id
                               FROM   at_seg_departments
                               WHERE  code = 'INVOICING')
       AND status_cd = 'A'
) WHERE ROWNUM <= 5000~';
  END;

  -- AT1710 LV_BARCODE: the record group's own query; P1 = :INV.CHARGE_TO_CUST_SEQ_ID
  PROCEDURE at1710_lov_lv_barcode(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT DISTINCT c.container_id
               ,c.cntnr_seq_id
               ,c.anchor_wgt
               ,c.anchor_wgt inv_wgt
FROM   at_containers c
      ,at_cust_doc_tracked_items cdti
WHERE      cdti.cntnr_seq_id = c.cntnr_seq_id
       AND cdti.cust_seq_id = :b1
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1710 LV_SHIPMENTS: the record group's own query; P1 = :INV.CHARGE_TO_CUST_SEQ_ID
  PROCEDURE at1710_lov_lv_shipments(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT s.shipment_nbr
      ,s.scheduled_shipment_dt
      ,s.scheduled_delivery_dt
      ,s.shipment_type_cd
      ,s.round_trip_shipment_nbr
      ,s.waste_contents_txt
      ,s.shipment_dt
      ,s.received_dt
      ,im.manifest_nbr
FROM   at_shipments s
      ,at_shipments s1
      ,at_incoming_manifests im
WHERE      NVL(s.round_trip_shipment_nbr, 0) = s1.shipment_nbr(+)
       AND s.shipment_nbr = im.shipment_nbr(+)
       AND s.shipment_nbr IN (SELECT shipment_nbr
                              FROM   at_shipments
                              WHERE     consignee_cust_seq_id = :b1
                                     OR pick_up_cust_seq_id = :b2)
) WHERE ROWNUM <= 5000~'
      USING p1, p1;
  END;

  -- AT1710 LV_WKSHT_MNFSTS: the record group's own query; P1 = :INV.CHARGE_TO_CUST_SEQ_ID, P2 = :INV.CNTRCT_SEQ_ID
  PROCEDURE at1710_lov_lv_wksht_mnfsts(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   DISTINCT im.manifest_nbr
                 ,im.advnotif_seq_id
                 ,pc.description
                 ,cps.cost
                 ,cps.cost_currency_code
                 ,cps.unit_cd_id units
FROM     at_incoming_manifests im
        ,at_seg_order_line_items soli
        ,at_contract_prod_services cps
        ,at_product_categories pc
        ,at_contracts c
WHERE        im.cust_seq_id = :b1
         AND c.cntrct_seq_id = cps.cntrct_seq_id
         AND c.cntrct_seq_id = :b2
         AND cps.cnprodserv_seq_id = soli.cnprodserv_seq_id
         AND soli.advnotif_seq_id = im.advnotif_seq_id
         AND soli.status_cd = 'OPEN'
         AND cps.prodserv_prodcat_seq_id = pc.prodcat_seq_id
ORDER BY im.manifest_nbr
) WHERE ROWNUM <= 5000~'
      USING p1, p2;
  END;

  -- AT3110 CGFK$CUSTTRCK_DSP_CODE2: the record group's own query; P1 = :MATL1.MATL_SEQ_ID
  PROCEDURE at3110_lov_cgfk_custtrck_ds_02(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select trkditm.code dsp_code /* cg$fk */ ,trkditm.description dsp_description4 ,trkditm.snm_ind dsp_snm_ind ,trkditm.source_material_ind dsp_source_material_ind ,trkditm.trkditm_seq_id trkditm_seq_id, trkditm.snm_sm_convt_fctr_amt snm_sm_convt_fctr_amt from at_tracked_items trkditm where trkditm.trkditm_seq_id not in (select trkditm_seq_id from at_cust_doc_tracked_items where matl_seq_id = :b1)
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT3110 CGFK$CUSTTRCK_DSP_CODE: the record group's own query; P1 = :MATL.MATL_SEQ_ID, P2 = :MATL.HLD_NUCLIDE_CODE
  PROCEDURE at3110_lov_cgfk_custtrck_dsp_c(p1 IN NUMBER, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select trkditm.code dsp_code /* cg$fk */ ,trkditm.description dsp_description4 ,trkditm.snm_ind dsp_snm_ind ,trkditm.source_material_ind dsp_source_material_ind ,trkditm.trkditm_seq_id trkditm_seq_id, trkditm.snm_sm_convt_fctr_amt snm_sm_convt_fctr_amt from at_tracked_items trkditm where trkditm.trkditm_seq_id not in (select trkditm_seq_id from at_cust_doc_tracked_items where matl_seq_id = :b1) and trkditm.code not in (:b2||nvl(:b3,' '))
) WHERE ROWNUM <= 5000~'
      USING p1, p2, p2;
  END;

  -- AT3110 CGFK$MATLMATL_DSP_MATERIAL_TYP: the record group's own query; P1 = :MATL.MATL_SEQ_ID
  PROCEDURE at3110_lov_cgfk_matlmatl_dsp_m(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   matl_typ.material_type_cd dsp_material_type_cd
        ,matl_typ.description dsp_description
        ,matl_typ.matl_typ_seq_id matl_typ_seq_id
        ,NVL(order_by_nbr, 1000) order_by_nbr        
FROM     at_material_types matl_typ
WHERE        NOT EXISTS
                 (SELECT 'x'
                  FROM   at_material_to_material_types types
                  WHERE      types.matl_typ_seq_id = matl_typ.matl_typ_seq_id
                         AND types.matl_seq_id = :b1)
         AND matl_typ.show_in_lov = 'Y'
ORDER BY order_by_nbr, material_type_cd
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT3110 CGFK$MATLMATL1_DSP_MATERIAL_TY: the record group's own query; P1 = :MATL1.MATL_SEQ_ID
  PROCEDURE at3110_lov_cgfk_matlmatl1_dsp_(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   matl_typ1.material_type_cd dsp_material_type_cd
        ,matl_typ1.description dsp_description
        ,matl_typ1.matl_typ_seq_id matl_typ_seq_id
        ,NVL(order_by_nbr, 1000) order_by_nbr
FROM     at_material_types matl_typ1
WHERE        NOT EXISTS
                 (SELECT 'x'
                  FROM   at_material_to_material_types types
                  WHERE      types.matl_typ_seq_id = matl_typ1.matl_typ_seq_id
                         AND types.matl_seq_id = :b1)
         AND matl_typ1.show_in_lov = 'Y'
ORDER BY order_by_nbr, material_type_cd
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT3110 LOV_ACTIVITY: the record group's own query; P1 = :PARAMETER.ACTIVITY
  PROCEDURE at3110_lov_lov_activity(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select unit2.unit_cd_id activity_unit_cd_id /* cg$fk */ ,unit2.description dsp_description3 from at_unit_of_measures unit2 where unit2.category_cd = :b1 union select '%' ,'Percentage' from dual order by 1
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT3110 LOV_ACTIVITY1: the record group's own query; P1 = :PARAMETER.ACTIVITY
  PROCEDURE at3110_lov_lov_activity1(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select unit2.unit_cd_id activity_unit_cd_id /* cg$fk */ ,unit2.description dsp_description3 from at_unit_of_measures unit2 where unit2.category_cd = :b1 union select '%' ,'Percentage' from dual order by 1
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT3110 ORDER_DISP_SITES: the record group's own query; P1 = :MNFST.ADVNOTIF_SEQ_ID
  PROCEDURE at3110_lov_order_disp_sites(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.code, a.description,a.disp_site_seq_id from at_disp_sites a, at_order_disp_sites b where advnotif_seq_id = :b1 and b.disp_site_seq_id = a.disp_site_seq_id
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT3115 CGFK$CNTNR_DSP_PRCTRANTYP_CD_I: the record group's own query; P1 = :PARAMETER.ADVNOTIF_SEQ_ID
  PROCEDURE at3115_lov_cgfk_cntnr_dsp_prct(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select distinct ptt.prctrantyp_cd_id dsp_prctrantyp_cd_id
, ptt.description dsp_description
,ptt.prctrantyp_seq_id next_prctrantyp_seq_id
, 'Map Required' map
, ptt.map_ind 
FROM AT_PRODUCT_SERVICES PS
, AT_CONTRACT_PROD_SERVICES CPS
, AT_SEG_ORDER_LINE_ITEMS SOLI
, AT_PROCESS_TRANS_SERVICES NS
, AT_PROCESS_TRANS_TYPES PTT
WHERE PS.PRODSERV_SEQ_ID = CPS.PRODSERV_SEQ_ID
  AND CPS.CNPRODSERV_SEQ_ID = SOLI.CNPRODSERV_SEQ_ID
  AND PTT.PRCTRANTYP_SEQ_ID = NS.PRCTRANTYP_SEQ_ID
  AND NS.PRODSERV_SEQ_ID = PS.PRODSERV_SEQ_ID
  AND SOLI.ADVNOTIF_SEQ_ID = :b1 
  AND SOLI.STATUS_CD = 'OPEN'
  AND NVL(PTT.OBSOLETE_FLAG,'Y') = 'N'
order by ptt.prctrantyp_cd_id
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT3115 CUST_DISP: the record group's own query; P1 = :CNTNR.CUST_SEQ_ID, P2 = :CONTROL_BLOCK.DSP_SHIP_NBR
  PROCEDURE at3115_lov_cust_disp(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.code, a.description, a.disp_site_seq_id from at_disp_sites a,
at_customer_disp_sites b where a.disp_site_seq_id = b.disp_site_seq_id and b.cust_seq_id = :b1 and nvl(b.allowed_ind,'N') = 'Y' and exists (select c.disp_site_seq_id from at_incoming_manifests c where nvl(c.brokered_shipment_ind,'N') = 'Y' and c.advnotif_seq_id = :b2)
union
select a.code, a.description, a.disp_site_seq_id from at_disp_sites a,
at_order_disp_sites b, at_incoming_manifests c  where a.disp_site_seq_id = b.disp_site_seq_id and b.advnotif_seq_id = c.advnotif_seq_id and nvl(c.brokered_shipment_ind,'N') = 'N' and
b.advnotif_seq_id = :b3
) WHERE ROWNUM <= 5000~'
      USING p1, p2, p2;
  END;

  -- AT3115 LOV_COST: the record group's own query; P1 = :PARAMETER.ADVNOTIF_SEQ_ID, P2 = :CNTNR.DSP_PRCTRANTYP_CD_ID
  PROCEDURE at3115_lov_lov_cost(p1 IN VARCHAR2, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT PS.PRODSERV_CD PRODSERV_CD
       , CPS.COST COST
       , CPS.UNIT_CD_ID UNIT_CD_ID
       , NVL(SOLI.ORDERED_QTY,0) ORDERED_QTY
       , SOLI.SEGORDLITM_SEQ_ID  SEGORDLITM_SEQ_ID
       ,  'A' COST_TYPE 
       , CPS.description CNPRODSERV_DESC
       , PS.DESCRIPTION         PRODSERV_DESC      
  FROM AT_PRODUCT_SERVICES PS
     , AT_CONTRACT_PROD_SERVICES CPS
     , AT_SEG_ORDER_LINE_ITEMS SOLI
     , AT_PROCESS_TRANS_SERVICES NS
     , AT_PROCESS_TRANS_TYPES PTT
  WHERE PS.PRODSERV_SEQ_ID = CPS.PRODSERV_SEQ_ID
    AND PS.PRODSERV_SEQ_ID = NS.PRODSERV_SEQ_ID
    AND CPS.CNPRODSERV_SEQ_ID = SOLI.CNPRODSERV_SEQ_ID
    AND PTT.PRCTRANTYP_SEQ_ID = NS.PRCTRANTYP_SEQ_ID
    AND SOLI.ADVNOTIF_SEQ_ID = :b1
    AND PTT.PRCTRANTYP_CD_ID = :b2
    AND SOLI.STATUS_CD = 'OPEN'
    AND NVL(PS.INCLUDE_MAP_IND,'N') = 'Y' 
    AND (NVL(CPS.GROUP_NBR,0) = 0 OR
        (NVL(CPS.GROUP_NBR,0) <> 0
        AND NVL(CPS.SUBGROUP_NBR,0) <> 0))
  ORDER BY PS.PRODSERV_CD, CPS.UNIT_CD_ID, CPS.COST
) WHERE ROWNUM <= 5000~'
      USING p1, p2;
  END;

  -- AT3212 CGFK$RNCNTNR_DSP_CONTAINER_TYP: the record group's own query
  PROCEDURE at3212_lov_cgfk_rncntnr_dsp_co(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select cntnr_typ.container_type_cd dsp_container_type_cd /* cg$fk */ ,cntnr_typ.description dsp_description ,cntnr_typ.cntnr_typ_seq_id cntnr_typ_seq_id ,cntnr_typ.loading_type_cd from at_container_types cntnr_typ where cntnr_typ.cntnr_typ_seq_id in (select rc.cntnr_typ_seq_id from at_rental_containers rc)
order by cntnr_typ.container_type_cd
) WHERE ROWNUM <= 5000~';
  END;

  -- AT3420 CGFK$PL_CNTNR_DSP_CONTAINER_ID: the record group's own query
  PROCEDURE at3420_lov_cgfk_pl_cntnr_dsp_c(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select cntnr.container_id dsp_container_id /* cg$fk */ ,cntnr.cntnr_seq_id cntnr_seq_id from at_containers cntnr where cntnr.cntnr_stat_cd_id not in ('EMPTY','SHIPPED') and nvl(terminal_ind,'N') != 'Y'
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4140 CONTAINERS: the record group's own query
  PROCEDURE at4140_lov_containers(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select c.container_id,c.cntnr_stat_cd_id,cp.cntnr_proc_seq_id from at_containers c , at_container_processes cp where cp.prctrantyp_seq_id = 1 and cp.parent_daughter_type_cd = 'PARENT' and c.cntnr_seq_id=cp.cntnr_seq_id and cp.cntnr_proc_stat_cd_id not like 'QC%'
and c.cntnr_stat_cd_id = 'EMPTY' order by c.container_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4150 BATCH_PARENTS: the record group's own query
  PROCEDURE at4150_lov_batch_parents(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select ac.cntnr_seq_id, 
       ac.container_id, 
       ac.cntnr_stat_cd_id status_desc, 
       ac.description, 
       ac.gross_wgt, 
       ac.tare_wgt, 
       ac.gross_wgt - ac.tare_wgt waste_wgt,
       ac.used_vol,
       ac.VOID_SPACE_AMT,
       AC.NEXT_PRCTRANTYP_SEQ_ID, 
       ATT.PRCTRANTYP_CD_ID PRCTRANTYP_CD_ID,
       AC.DISP_SITE_LOCK_IND,
       AC.DISP_SITE_SEQ_ID,
       AC.ANCHOR_WGT,
       CT.CONTAINER_TYPE_CD
from at_containers ac, 
     AT_PROCESS_TRANS_TYPES ATT,
     AT_CONTAINER_TYPES CT
where AC.NEXT_PRCTRANTYP_SEQ_ID = ATT.PRCTRANTYP_SEQ_ID
  and ac.cntnr_stat_cd_id = 'IN USE'  
  AND AC.CNTNR_TYP_SEQ_ID = CT.CNTNR_TYP_SEQ_ID
  AND NOT EXISTS (SELECT BP.CNTNR_SEQ_ID FROM AT_CONTAINER_PROCESSES BP 
                  WHERE BP.CNTNR_SEQ_ID = AC.CNTNR_SEQ_ID AND                                                        BP.PARENT_DAUGHTER_TYPE_CD = 'PARENT' AND BP.BYPRODHDRS_SEQ_ID IS NULL) 
--      and
--      FAMILY_MAPPED(AC.CNTNR_SEQ_ID) > 0
      order by ac.container_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4150 LOV_COST: the record group's own query; P1 = :BATCH_PARENTS.ADVNOTIF_SEQ_ID, P2 = :XFER_DAUGHTER.DSP_NEXT_PRCTRANTYP_CD_ID
  PROCEDURE at4150_lov_lov_cost(p1 IN NUMBER, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT 
PS.PRODSERV_CD PRODSERV_CD
,DISP.ALIAS
,NVL(SOLI.ORDERED_QTY,0) ORDERED_QTY
,SOLI.SEGORDLITM_SEQ_ID SEGORDLITM_SEQ_ID
,'A' COST_TYPE
,CV.CNPRODSERV_DESCR
,SUBSTR(PS.DESCRIPTION,1,40) PRODSERV_DESC
FROM AT_PRODUCT_SERVICES PS,AT_CONTRACT_PROD_SERVICES CPS,AT_SEG_ORDER_LINE_ITEMS SOLI
,AT_PROCESS_TRANS_SERVICES NS,AT_PROCESS_TRANS_TYPES PTT,AT_DISP_SITES DISP,AT_CNPRODSERV_VIEW CV
WHERE PS.PRODSERV_SEQ_ID = CPS.PRODSERV_SEQ_ID
AND PS.PRODSERV_SEQ_ID = NS.PRODSERV_SEQ_ID
AND CPS.CNPRODSERV_SEQ_ID = SOLI.CNPRODSERV_SEQ_ID
AND CPS.CNPRODSERV_SEQ_ID = CV.CNPRODSERV_SEQ_ID
AND PTT.PRCTRANTYP_SEQ_ID = NS.PRCTRANTYP_SEQ_ID
AND CPS.DISP_SITE_SEQ_ID = DISP.DISP_SITE_SEQ_ID
AND SOLI.ADVNOTIF_SEQ_ID = :b1
AND PTT.PRCTRANTYP_CD_ID = :b2
AND NVL(PS.INCLUDE_MAP_IND,'N') = 'Y'
AND SOLI.STATUS_CD = 'OPEN'
ORDER BY PS.PRODSERV_CD
) WHERE ROWNUM <= 5000~'
      USING p1, p2;
  END;

  -- AT4150 MAP_NONMAP_NPC: the record group's own query; P1 = :BATCH_HDR.BATCH_SEQ_ID
  PROCEDURE at4150_lov_map_nonmap_npc(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT DISTINCT vnt.PRCTRANTYP_CD_ID PRCTRANTYP_CD_ID 
,vnt.PRCTRANTYP_SEQ_ID PRCTRANTYP_SEQ_ID
,vnt.MAP_IND MAP_IND
,vnt.DESCRIPTION DESCRIPTION
,'From Order' data_source
, ptt.rtc_ind
FROM AT_VALID_NPC_TMP vnt
    ,at_process_trans_types ptt
WHERE vnt.BATCH_NBR = :b1
  and vnt.prctrantyp_seq_id = ptt.prctrantyp_seq_id
  and NVL(ptt.obsolete_flag,'Y') = 'N'
UNION ALL
select 
ptt.prctrantyp_cd_id
,ptt.prctrantyp_seq_id
,'Map Not Required' map_ind
,ptt.description
,ptt.rtc_ind
,'Not from Order' data_source
from at_process_trans_types ptt_b,at_process_trans_types ptt
where ptt_b.prctrantyp_seq_id(+) = ptt.within_prctrantyp_seq_id
and NVL(ptt.map_ind,'N') = 'N'
and NVL(ptt.obsolete_flag,'Y') = 'N'
and ptt.prctrantyp_seq_id not in
 (select a.prctrantyp_seq_id from at_valid_npc_tmp A where A.BATCH_NBR = :b2)
ORDER BY 5,1
) WHERE ROWNUM <= 5000~'
      USING p1, p1;
  END;

  -- AT4150 MATERIAL_TYPES: the record group's own query
  PROCEDURE at4150_lov_material_types(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select material_type_cd, to_char(matl_typ_seq_id) matl_typ_seq_id, description, high_price_ind from at_material_types where NVL(SHOW_IN_LOV,'N') = 'Y' order by material_type_cd
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4150 PARENT_CONTENTS: the record group's own query
  PROCEDURE at4150_lov_parent_contents(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select material_type_cd, to_char(matl_typ_seq_id) matl_typ_seq_id, description, high_price_ind from at_material_types where NVL(SHOW_IN_LOV,'N') = 'Y' order by material_type_cd
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4210 DSP_CONTAINER_ID: the record group's own query
  PROCEDURE at4210_lov_dsp_container_id(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.cntnr_seq_id, a.container_id, b.container_type_cd, c.prctrantyp_cd_id, a.description, a.cntnr_typ_seq_id from at_containers a, at_container_types b, at_process_trans_types c where a.cntnr_typ_seq_id = b.cntnr_typ_seq_id and c.prctrantyp_seq_id = a.next_prctrantyp_seq_id and c.prctrantyp_cd_id like '2%' and all_parents_empty(a.cntnr_seq_id)='TRUE' and a.cntnr_seq_id not in (select d.cntnr_seq_id from at_compaction_masters d) and not exists (select 'x' from at_container_processes cp, at_process_trans_types ptt where cp.cntnr_seq_id = a.cntnr_seq_id and cp.prctrantyp_seq_id = ptt.prctrantyp_seq_id and ptt.prctrantyp_cd_id = 'OVERPACK') and cntnr_stat_cd_id = 'IN USE' order by a.container_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4211 DSP_CONTAINER_ID: the record group's own query
  PROCEDURE at4211_lov_dsp_container_id(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.cntnr_seq_id, a.container_id, b.container_type_cd, c.prctrantyp_cd_id, a.description, a.cntnr_typ_seq_id from at_containers a, at_container_types b, at_process_trans_types c where a.cntnr_typ_seq_id = b.cntnr_typ_seq_id and c.prctrantyp_seq_id = a.next_prctrantyp_seq_id and c.prctrantyp_cd_id like '2%' and all_parents_empty(a.cntnr_seq_id)='TRUE' and a.cntnr_seq_id not in (select d.cntnr_seq_id from at_compaction_masters d) and not exists (select 'x' from at_container_processes cp, at_process_trans_types ptt where cp.cntnr_seq_id = a.cntnr_seq_id and cp.prctrantyp_seq_id = ptt.prctrantyp_seq_id and ptt.prctrantyp_cd_id = 'OVERPACK') and cntnr_stat_cd_id = 'IN USE' order by a.container_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4220 PARTIAL_OVERPACKS: the record group's own query
  PROCEDURE at4220_lov_partial_overpacks(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select distinct ovrpk.cntnr_seq_id, ovrpk.transaction_dt, cont.container_id , cnttyp.container_type_cd, 'Partial Overpack' status from at_overpack_masters ovrpk, at_containers cont, at_container_types cnttyp where ovrpk.cntnr_seq_id = cont.cntnr_seq_id and nvl(ovrpk.compacted_ind,'Y')='Y' and cont.cntnr_typ_seq_id = cnttyp.cntnr_typ_seq_id and ( ovrpk.overpack_complete_ind is null or ovrpk.overpack_complete_ind = 'N') union select c.cntnr_seq_id, cp.transaction_dt, c.container_id, typ.container_type_cd , 'Solidified Container' from at_containers c, at_container_processes cp, at_container_types typ where c.cntnr_seq_id = cp.cntnr_seq_id and c.cntnr_typ_seq_id = typ.cntnr_typ_seq_id and c.agt_media_seq_id is not null and nvl(cp.compacted_ind,'Y')='Y' and not exists (select 'x' from at_overpack_masters op2 where op2.cntnr_seq_id = cp.cntnr_seq_id and (op2.overpack_complete_ind is null or op2.overpack_complete_ind = 'N')) and not exists (select 'x' from at_overpack_details opd where opd.cntnr_seq_id = cp.cntnr_seq_id) order by 5,3
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4225 PARTIAL_OVERPACKS: the record group's own query
  PROCEDURE at4225_lov_partial_overpacks(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select distinct ovrpk.cntnr_seq_id, ovrpk.transaction_dt, cont.container_id , cnttyp.container_type_cd, 'Partial Overpack' status from at_overpack_masters ovrpk, at_containers cont, at_container_types cnttyp where ovrpk.cntnr_seq_id = cont.cntnr_seq_id and nvl(ovrpk.compacted_ind,'Y')='Y' and cont.cntnr_typ_seq_id = cnttyp.cntnr_typ_seq_id and ( ovrpk.overpack_complete_ind is null or ovrpk.overpack_complete_ind = 'N') union select c.cntnr_seq_id, cp.transaction_dt, c.container_id, typ.container_type_cd , 'Solidified Container' from at_containers c, at_container_processes cp, at_container_types typ where c.cntnr_seq_id = cp.cntnr_seq_id and c.cntnr_typ_seq_id = typ.cntnr_typ_seq_id and c.agt_media_seq_id is not null and nvl(cp.compacted_ind,'Y')='Y' and not exists (select 'x' from at_overpack_masters op2 where op2.cntnr_seq_id = cp.cntnr_seq_id and (op2.overpack_complete_ind is null or op2.overpack_complete_ind = 'N')) and not exists (select 'x' from at_overpack_details opd where opd.cntnr_seq_id = cp.cntnr_seq_id) order by 5,3
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4230 PARTIAL_OVERPACKS: the record group's own query
  PROCEDURE at4230_lov_partial_overpacks(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select distinct ovrpk.cntnr_seq_id, ovrpk.transaction_dt, cont.container_id, cnttyp.container_type_cd, 'Partial Overpack' status from at_overpack_masters ovrpk, at_containers cont, at_container_types cnttyp where ovrpk.cntnr_seq_id = cont.cntnr_seq_id and cont.cntnr_typ_seq_id = cnttyp.cntnr_typ_seq_id and ( ovrpk.overpack_complete_ind is null or ovrpk.overpack_complete_ind = 'N') union select c.cntnr_seq_id, cp.transaction_dt, c.container_id, typ.container_type_cd, 'Solidified Container' from at_containers c, at_container_processes cp, at_container_types typ where c.cntnr_seq_id = cp.cntnr_seq_id and c.cntnr_typ_seq_id = typ.cntnr_typ_seq_id and c.agt_media_seq_id is not null and not exists (select 'x' from at_overpack_masters op2 where op2.cntnr_seq_id = cp.cntnr_seq_id and (op2.overpack_complete_ind is null or op2.overpack_complete_ind = 'N')) and not exists (select 'x' from at_overpack_details opd where opd.cntnr_seq_id = cp.cntnr_seq_id) order by 5,3
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4240 GIC_CONTAINERS: the record group's own query; P1 = :AT$CTRL.NPC
  PROCEDURE at4240_lov_gic_containers(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select DISTINCT b.cntnr_seq_id, b.container_id,b.next_prctrantyp_seq_id next_npc_seq_id,c.prctrantyp_cd_id dsp_npc_code from at_container_processes a, at_containers b, at_process_trans_types c where a.cntnr_seq_id = b.cntnr_seq_id and b.next_prctrantyp_seq_id = c.prctrantyp_seq_id and c.prctrantyp_cd_id = :b1 and b.cntnr_stat_cd_id = 'IN USE' and NOT EXISTS (SELECT * FROM at_container_processes d where d.parent_cntnr_seq_id = a.cntnr_seq_id) and NOT EXISTS (SELECT * FROM at_container_processes e where e.cntnr_seq_id = a.cntnr_seq_id and e.parent_daughter_type_cd = 'PARENT') order by b.container_id
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT4240 LOV_COST: the record group's own query; P1 = :AT_CONTAINERS.NEW_NPC_SEQ_ID, P2 = :AT_CONTAINERS.ADVNOTIF_SEQ_ID
  PROCEDURE at4240_lov_lov_cost(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT CPS.COST PRICE
     , CPS.UNIT_CD_ID PRICE_UNIT_CD_ID
     , PS.PRODSERV_CD PRODSERV_CD
     , SUBSTR(PS.DESCRIPTION,1,40) PRODSERV_DESC
     , PS.PRODSERV_SEQ_ID PRODSERV_SEQ,SUBSTR(CPS.DESCRIPTION,1,60) SPECIAL_INS 
     , DS.CODE DISP_SITE
     , SOLI.SEGORDLITM_SEQ_ID
         SEGORDLITM_SEQ_ID
  FROM AT_PRODUCT_SERVICES PS
     , AT_CONTRACT_PROD_SERVICES CPS
     , AT_SEG_ORDER_LINE_ITEMS SOLI
     , AT_DISP_SITES DS
     , AT_PROCESS_TRANS_SERVICES PTS
  WHERE PS.PRODSERV_SEQ_ID = CPS.PRODSERV_SEQ_ID
    AND CPS.DISP_SITE_SEQ_ID = DS.DISP_SITE_SEQ_ID
    AND CPS.CNPRODSERV_SEQ_ID = SOLI.CNPRODSERV_SEQ_ID
    AND CPS.PRODSERV_SEQ_ID = PTS.PRODSERV_SEQ_ID
    AND PTS.PRCTRANTYP_SEQ_ID = :b1
    AND SOLI.ADVNOTIF_SEQ_ID = :b2
    AND NVL(PS.INCLUDE_MAP_IND,'N') = 'Y' 
    AND SOLI.STATUS_CD = 'OPEN'
    AND (NVL(CPS.GROUP_NBR,0) = 0 OR
        (NVL(CPS.GROUP_NBR,0) <> 0 
      AND NVL(CPS.SUBGROUP_NBR,0) <> 0))
  ORDER BY PS.PRODSERV_CD, CPS.UNIT_CD_ID, CPS.COST
) WHERE ROWNUM <= 5000~'
      USING p1, p2;
  END;

  -- AT4260 ADJ_CONTAINERS: the record group's own query
  PROCEDURE at4260_lov_adj_containers(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select DISTINCT b.cntnr_seq_id, b.container_id,b.next_prctrantyp_seq_id next_npc_seq_id,c.prctrantyp_cd_id dsp_npc_code,
b.cntnr_stat_cd_id cntnr_stat_cd_id from  at_containers b, at_process_trans_types c where b.next_prctrantyp_seq_id = c.prctrantyp_seq_id and c.prctrantyp_cd_id IN ('890','891') and b.cntnr_stat_cd_id not in ('EMPTY','SHIPPED')  order by b.container_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4270 BINS: the record group's own query
  PROCEDURE at4270_lov_bins(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.container_id from at_containers  a 
where  nvl(a.terminal_ind,'N') = 'Y'
and a.container_id like 'BIN%'
and  exists (select 1 from at_containers b 
where b.melted_dt is null
and nvl(b.terminal_process_ind,'N') = 'Y'
and b.container_id like '%' || a.container_id || '%')
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4280 TANKS: the record group's own query
  PROCEDURE at4280_lov_tanks(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.container_id from at_containers  a 
where  nvl(a.terminal_ind,'N') = 'Y'
and a.container_id like 'TANK%'
and  exists (select 1 from at_containers b 
where b.melted_dt is null
and nvl(b.terminal_process_ind,'N') = 'Y'
and b.container_id like '%' || a.container_id || '%')
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4420 SURVEYS: the record group's own query
  PROCEDURE at4420_lov_surveys(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select distinct ac.survey_nbr,ac.survey_bin_nbr,ac.container_id,ac.cntnr_seq_id,cust.name,im.manifest_nbr
from at_materials mat, at_processed_amounts pa, at_customers cust, at_incoming_manifests im, at_containers ac
where pa.matl_seq_id = mat.matl_seq_id
and mat.advnotif_seq_id = im.advnotif_seq_id
and im.cust_seq_id = cust.cust_seq_id
and pa.cntnr_seq_id = ac.cntnr_seq_id
and ac.cntnr_stat_cd_id <> 'SHIPPED'
and ac.survey_nbr is not null
and ac.survey_bin_nbr IS NULL 
and not exists
 (select * from at_survey_bins sb 
   where sb.survey_bin_nbr = ac.survey_bin_nbr) 
order by ac.survey_nbr
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5120 CGFK$CNTNR_DSP_CONTAINER_ID: the record group's own query
  PROCEDURE at5120_lov_cgfk_cntnr_dsp_cont(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   DISTINCT cntnr1.container_id container_id
                 ,cntnr1.cntnr_seq_id cntnr_seq_id
                 ,cntnr1.cntnr_typ_seq_id cntnr_typ_seq_id
                 ,cntnr_typ1.container_type_cd container_type_cd
                 ,cntnr1.cntnr_stat_cd_id
FROM     at_containers cntnr1
        ,at_container_types cntnr_typ1
WHERE        cntnr_typ1.cntnr_typ_seq_id = cntnr1.cntnr_typ_seq_id
         AND (   cntnr1.cntnr_stat_cd_id IN ('STORAGE CONTAINER'
                                            ,'EMPTY STORAGE CONT.'
                                            ,'HOLD STORAGE CONT.'
                                            ,'LAB STORAGE CONT.')
              OR (    cntnr1.cntnr_stat_cd_id IN ('LOADED', 'SHIPPED')
                  AND EXISTS
                          (SELECT cntnr.cntnr_seq_id
                           FROM   at_containers cntnr
                           WHERE  cntnr.within_cntnr_seq_id = cntnr1.cntnr_seq_id)))
         AND cntnr1.within_cntnr_seq_id IS NULL
         AND NVL(cntnr1.terminal_ind, 'N') = 'N'
ORDER BY cntnr1.container_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5210 LV_MANIFESTS: the record group's own query; P1 = :BYPRODHDRS.CUST_SEQ_ID
  PROCEDURE at5210_lov_lv_manifests(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT DISTINCT A.MANIFEST_NBR MANIFEST_NBR, A.ADVNOTIF_SEQ_ID ORDER_NUM
FROM AT_INCOMING_MANIFESTS A, AT_MATERIALS B
WHERE A.ADVNOTIF_SEQ_ID = B.ADVNOTIF_SEQ_ID
AND B.CUST_SEQ_ID = :b1
ORDER BY A.ADVNOTIF_SEQ_ID DESC
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT5210 PARTITION_LOV: the record group's own query; P1 = :CNTNR_PROC.PARTITION_BARCODE
  PROCEDURE at5210_lov_partition_lov(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select container_id, cntnr_seq_id from at_containers where cntnr_stat_cd_id = 'IN USE' union select container_id, cntnr_seq_id from at_containers where container_id = :b1
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT5210 PROCESSES: the record group's own query
  PROCEDURE at5210_lov_processes(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select prctrantyp_seq_id, prctrantyp_cd_id, description from at_process_trans_types ptt where substr(prctrantyp_cd_id,1,1) between '0' and '9' and within_prctrantyp_seq_id is null order by prctrantyp_cd_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5210 PROJECT: the record group's own query
  PROCEDURE at5210_lov_project(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select bp. proj_name, bp.description, bp.byprodproj_seq_id, im.cust_seq_id from at_byproduct_projects bp, at_incoming_manifests im where im. advnotif_seq_id(+) = bp.advnotif_seq_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5310 CGFK$LABANLSMPL_DSP_SAMPLE_ID: the record group's own query; P1 = :LABANLSMPL.DSP_CONTAINER_ID, P2 = :LABANLSMPL.LABSAMPLE_SEQ_ID
  PROCEDURE at5310_lov_cgfk_labanlsmpl_dsp(p1 IN VARCHAR2, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select labsample.sample_id dsp_sample_id, labsample.container_id dsp_container_id /* cg$fk */ ,labsample.cntnr_seq_id dsp_cntnr_seq_id ,labsample.labsample_seq_id labsample_seq_id from at_lab_samples labsample ,at_containers cntnr where labsample.container_id = :b1 and cntnr.cntnr_seq_id (+) = labsample.cntnr_seq_id and labsample.labsample_seq_id = :b2 order by labsample.sample_id,labsample.container_id asc
) WHERE ROWNUM <= 5000~'
      USING p1, p2;
  END;

  -- AT5310 CONTAINERS: the record group's own query
  PROCEDURE at5310_lov_containers(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select smpl.labsample_seq_id, smpl.container_id, cntnr.hazardous_cd from at_lab_samples smpl, at_containers cntnr where cntnr.cntnr_seq_id (+) = smpl.cntnr_seq_id order by smpl.container_id, smpl.labsample_seq_id asc
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5311 CONTAINERS: the record group's own query
  PROCEDURE at5311_lov_containers(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select c.cntnr_seq_id, c.container_id from at_containers c,at_container_processes cp where cp.byprodhdrs_seq_id is not null and c.cntnr_seq_id = cp.cntnr_seq_id order by container_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5312 CGFK$LABSAMPLE2_DSP_BADGE_NBR: the record group's own query
  PROCEDURE at5312_lov_cgfk_labsample2_dsp(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   first_name dsp_first_name
        ,middle_name dsp_middle_name
        ,last_name dsp_last_name
        ,badge_nbr dsp_badge_nbr
        ,seg_stf_seq_id seg_stf_seq_id
FROM     at_seg_staff
WHERE        seg_dept_seq_id = (SELECT seg_dept_seq_id
                                FROM   at_seg_departments
                                WHERE  code = 'LAB')
         AND status_cd = 'A'
ORDER BY last_name, first_name, middle_name
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5312 FACILITY: the record group's own query; P1 = :CG$CTRL.SITE_IND
  PROCEDURE at5312_lov_facility(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.facility_cd ,a.description, a.fac_seq_id, b.site_cd_id from at_seg_facilities a, at_seg_sites b where a.site_seq_id = b.site_seq_id and substr(b.site_cd_id,1,1) = :b1 order by facility_cd
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT5312 REVIEWED_BY_STAFF: the record group's own query
  PROCEDURE at5312_lov_reviewed_by_staff(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   last_name dsp_last_name
        ,middle_name dsp_middle_name
        ,first_name dsp_first_name
        ,badge_nbr dsp_badge_nbr
        ,seg_stf_seq_id seg_stf_seq_id
FROM     at_seg_staff
WHERE        seg_dept_seq_id = (SELECT seg_dept_seq_id
                                FROM   at_seg_departments
                                WHERE  code = 'LAB')
         AND status_cd = 'A'
ORDER BY last_name, first_name
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5316 CONTAINERS: the record group's own query
  PROCEDURE at5316_lov_containers(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select c.cntnr_seq_id, c.container_id from at_containers c,at_container_processes cp where cp.byprodhdrs_seq_id is not null and c.cntnr_seq_id = cp.cntnr_seq_id order by container_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5316 CUSTOMERS: the record group's own query; P1 = :LABSAMPLE2.CNTNR_SEQ_ID
  PROCEDURE at5316_lov_customers(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select distinct a.customer_nbr, a.name, b.manifest_nbr, a.cust_seq_id from at_customers a, at_incoming_manifests b, at_materials c where a.cust_seq_id = c.cust_seq_id and b.advnotif_seq_id = c.advnotif_seq_id and c.matl_seq_id in (select matl_seq_id from at_cust_doc_tracked_items where cntnr_seq_id = :b1)
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT5390 FACILITY_LOV: the record group's own query
  PROCEDURE at5390_lov_facility_lov(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   sf.facility_cd
        ,sf.description
        ,ss.site_cd_id
        ,sf.fac_seq_id        
FROM     at_seg_facilities sf
        ,at_seg_sites ss
WHERE    sf.site_seq_id = ss.site_seq_id
ORDER BY sf.facility_cd
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5510 DISP_SITES_LOV: the record group's own query
  PROCEDURE at5510_lov_disp_sites_lov(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   code
        ,description
        ,contact_name
        ,contact_phone_nbr
        ,operated_by_name
        ,DECODE(alias, 'R', 'R', 'B') site_purpose
        ,disp_site_seq_id
FROM     at_disp_sites
ORDER BY code
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5510 WASTE_PROFILE_NUMBER_LOV: the record group's own query; P1 = :AT_OUTBOUND_SHIPMENTS.SHIPMENT_NBR
  PROCEDURE at5510_lov_waste_profile_numbe(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   e.waste_profile_number
        ,e.waste_stream_name
        ,CASE
             WHEN EXTRACTVALUE(cip.parametersxml, '/Profile/IsCWF/text()') = 'false' THEN 'N'
             ELSE 'Y'
         END
             cwf_ind
        ,e.site_cd
        ,e.es_prof_seq_id
FROM     at_esprofiles e
         INNER JOIN at_cp_import_profiles cip ON e.cp_import_seq_id = cip.cp_import_seq_id
         INNER JOIN at_corp_cust_sites ccs ON e.site_cd = ccs.site_name
WHERE        ccs.cust_seq_id = (SELECT s.consignee_cust_seq_id
                                FROM   at_shipments s
                                WHERE  s.shipment_nbr = :b1)
         AND e.gen_cust_seq_id IN (SELECT s.pick_up_cust_seq_id
                                   FROM   at_shipments s
                                   WHERE  s.shipment_nbr = :b2)
ORDER BY e.waste_profile_number
) WHERE ROWNUM <= 5000~'
      USING p1, p1;
  END;

  -- AT5511 CGFK$OUTSHIPMT_DSP_CARRIER_NAM: the record group's own query
  PROCEDURE at5511_lov_cgfk_outshipmt_dsp_(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select distinct carrier.carrier_name dsp_carrier_name /* cg$fk */ ,carrier.carrier_abbreviated_name dsp_carrier_abbreviated_name ,carrier.carrier_contact_name dsp_carrier_contact_name ,carrier.epa_nbr dsp_epa_nbr ,carrier.carrier_contact_phone_nbr dsp_carrier_contact_phone_nb ,carrier.carrier_status_cd dsp_carrier_status_cd ,carrier.carrier_seq_id carrier_seq_id from at_carriers carrier, at_addresses addr
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5511 CONTAINERS: the record group's own query
  PROCEDURE at5511_lov_containers(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select cnt.cntnr_seq_id,cnt.container_id,typ.container_type_cd,cnt.waste_class_cd
 from at_container_types typ,at_containers cnt
 where typ.cntnr_typ_seq_id = cnt.cntnr_typ_seq_id
 and cnt.cntnr_stat_cd_id = 'IN USE'
 and cnt.cntnr_seq_id not in
 (select osc.cntnr_seq_id from at_outshipment_containers osc where osc.cntnr_seq_id = cnt.cntnr_seq_id and osc.shipment_type_cd = 'B')
order by cnt.container_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5514 LIFT_STOR_LOC_LV: the record group's own query; P1 = :LANDFILL_HEADERS.DISP_STORLOC_SEQ_ID
  PROCEDURE at5514_lov_lift_stor_loc_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select STORAGE_LOCATION_ID,DESCRIPTION,STORLOC_SEQ_ID
from AT_STORAGE_LOCATIONS
where nvl(active_ind,'N') = 'Y'
  and NVL(lift_ind,'N') = 'Y'
  and disp_storloc_seq = NVL(:b1,-1)
order by 1
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT9106 CGFK$CONTSTR_DSP_CODE: the record group's own query
  PROCEDURE at9106_lov_cgfk_contstr_dsp_co(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT to_char(AGT_MEDIA.CODE)  DSP_CODE  /* CG$FK */
      ,AGT_MEDIA.NAME  DSP_NAME
      ,AGT_MEDIA.MEDIA_CD  DSP_MEDIA_CD
      ,AGT_MEDIA.AGT_MEDIA_SEQ_ID  AGT_MEDIA_SEQ_ID
FROM   AT_AGENTS_AND_MEDIAS AGT_MEDIA
ORDER BY  to_char(AGT_MEDIA.CODE) ASC
) WHERE ROWNUM <= 5000~';
  END;

  -- AT9106 LV_LIC_REST_LST: the record group's own query
  PROCEDURE at9106_lov_lv_lic_rest_lst(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select substr(rv_low_value,1,1) rv_low_value, substr(rv_meaning,1,100) rv_meaning from cg_ref_codes where (rv_domain = 'AT_CUSTOMER_LICENSES.LICENSE_RESTRICTION_CD') order by rv_low_value
) WHERE ROWNUM <= 5000~';
  END;

  -- AT9603 PARENT_NPC_LOV: the record group's own query
  PROCEDURE at9603_lov_parent_npc_lov(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   prctrantyp_cd_id
             npc
        ,description
             npc_descr
        ,(SELECT prctrantyp_cd_id
          FROM   at_process_trans_types ptt2
          WHERE  ptt.within_prctrantyp_seq_id = ptt2.prctrantyp_seq_id)
             parent_npc
        ,(SELECT description
          FROM   at_process_trans_types ptt2
          WHERE  ptt.within_prctrantyp_seq_id = ptt2.prctrantyp_seq_id)
             parent_npc_descr
        ,DECODE(process_cd,  'X', 'Sort / Transfer',  'C', 'Compaction',  'I', 'Incineration',  'S', 'Shipping')
             process_cd
        ,(SELECT description
          FROM   at_waste_process_types wpt2
          WHERE  wpt2.code = ptt.waste_proc_cd)
             waste_process_cd
        ,prctrantyp_seq_id
FROM     at_process_trans_types ptt
ORDER BY prctrantyp_cd_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT9612 STATE_LOV: the record group's own query
  PROCEDURE at9612_lov_state_lov(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   sp.st_prvnc_abbr_id
        ,sp.name
        ,sp.cntry_postal_id
FROM     at_state_provinces sp
        ,at_countries c
WHERE    sp.cntry_postal_id = c.cntry_postal_id
ORDER BY sp.cntry_postal_id, sp.st_prvnc_abbr_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT9640 GROUPS_LOV: the record group's own query
  PROCEDURE at9640_lov_groups_lov(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   lcg.group_name
        ,lcg.group_desc
        ,lcg.level_type
        ,lcg.active_ind
        ,ss.site_cd_id
        ,lcg.lcg_seq_id
FROM     at_license_condition_groups lcg
        ,at_seg_sites ss
WHERE    lcg.site_seq_id = ss.site_seq_id
ORDER BY lcg.group_name, lcg.level_type
) WHERE ROWNUM <= 5000~';
  END;

  -- WB1000 CGFK$CUSTTRCK_DSP_CODE: the record group's own query; P1 = :MATL.MATL_SEQ_ID, P2 = :MATL.HLD_NUCLIDE_CODE
  PROCEDURE wb1000_lov_cgfk_custtrck_dsp_c(p1 IN NUMBER, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select trkditm.code dsp_code /* cg$fk */ ,trkditm.description dsp_description4 ,trkditm.snm_ind dsp_snm_ind ,trkditm.source_material_ind dsp_source_material_ind ,trkditm.trkditm_seq_id trkditm_seq_id, trkditm.snm_sm_convt_fctr_amt snm_sm_convt_fctr_amt from at_tracked_items trkditm where trkditm.trkditm_seq_id not in (select trkditm_seq_id from at_cust_doc_tracked_items where matl_seq_id = :b1) and trkditm.code not in (:b2||nvl(:b3,' '))
) WHERE ROWNUM <= 5000~'
      USING p1, p2, p2;
  END;

  -- WB1000 CGFK$MATLMATL_DSP_MATERIAL_TYP: the record group's own query; P1 = :MATL.MATL_SEQ_ID
  PROCEDURE wb1000_lov_cgfk_matlmatl_dsp_m(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select matl_typ.material_type_cd dsp_material_type_cd /* cg$fk */ 
,matl_typ.description dsp_description 
,matl_typ.matl_typ_seq_id matl_typ_seq_id
, nvl(order_by_nbr,1000) order_by_nbr
,matl_typ.agent_media_ind 
from at_material_types matl_typ 
where not exists 
(select 'x' 
from at_material_to_material_types types 
where types.matl_typ_seq_id = matl_typ.matl_typ_seq_id 
and types.matl_seq_id = :b1)
and NVL(matl_typ.show_in_lov,'N') = 'Y' 
order by order_by_nbr, material_type_cd
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- WB1000 CONTAINER_DISP_SITES: the record group's own query; P1 = :MNFST.ADVNOTIF_SEQ_ID
  PROCEDURE wb1000_lov_container_disp_site(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.code, a.description,a.disp_site_seq_id from at_disp_sites a
where a.disp_site_seq_id in (select b.disp_site_seq_id from at_order_disp_sites b
where b.advnotif_seq_id = :b1)
order by a.code
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- WB1000 CUST_VIEW_LV: the record group's own query
  PROCEDURE wb1000_lov_cust_view_lv(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select cust.customer_nbr cust_customer_nbr
, cust.abbreviated_name cust_abbreviated_name
, cust.name cust_name
, cust.cust_seq_id cust_cust_seq_id 
, a.street_addr street
, a.city_addr city
, a.st_prvnc_abbr_id state
from at_customers cust
    ,at_contacts c
    ,at_contacts_contact_types cct
    ,at_contact_types ct
    ,at_addresses a
where cust.cust_seq_id = c.cust_seq_id
  and c.cntct_seq_id = cct.cntct_seq_id
  and c.addr_seq_id = a.addr_seq_id
  and cct.cntct_typ_seq_id = ct.cntct_typ_seq_id
  and ct.code = 'SHIPPING'
order by cust_name
) WHERE ROWNUM <= 5000~';
  END;

  -- WB1000 NPC_CODES: the record group's own query; P1 = :MATL.ADVNOTIF_SEQ_ID
  PROCEDURE wb1000_lov_npc_codes(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT npc.PRCTRANTYP_CD_ID, npc.DESCRIPTION, npc.PRCTRANTYP_seq_id 
FROM at_process_trans_types npc,
  at_process_trans_services pts,
  at_product_services ps,
  at_contract_prod_services cps,
  at_seg_order_line_items soli
WHERE cps.prodserv_seq_id = ps.prodserv_seq_id
 AND cps.cnprodserv_seq_id = soli.cnprodserv_seq_id
 AND ps.prodserv_seq_id = pts.prodserv_seq_id
 AND pts.prctrantyp_seq_id = npc.prctrantyp_seq_id
 AND soli.status_cd = 'OPEN'
 AND(cps.group_nbr IS NULL OR(cps.group_nbr IS NOT NULL
 AND cps.subgroup_nbr IS NOT NULL))
 AND nvl(ps.include_map_ind,   'N') = 'Y'
 AND soli.advnotif_seq_id = :b1
 and NVL(npc.obsolete_flag,'Y') = 'N'
UNION
SELECT 'NONE','NONE SELECTED',0
FROM AT_PROCESS_TRANS_TYPES
ORDER BY PRCTRANTYP_CD_ID
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- WB1000 ORDER_DISP_SITES: the record group's own query; P1 = :MNFST.ADVNOTIF_SEQ_ID
  PROCEDURE wb1000_lov_order_disp_sites(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.code, a.description,a.disp_site_seq_id from at_disp_sites a
where a.disp_site_seq_id in (select b.disp_site_seq_id from at_order_disp_sites b
where b.advnotif_seq_id = :b1)
order by a.code
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- WB1000 PSC_LV: the record group's own query; P1 = :MNFST.ADVNOTIF_SEQ_ID
  PROCEDURE wb1000_lov_psc_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select soli.segordlitm_seq_id
,ps.prodserv_cd
,cps.description sp_instr
,ps.description description
from at_product_services ps
    ,at_contract_prod_services cps
    ,at_seg_order_line_items soli
where ps.prodserv_seq_id = cps.prodserv_seq_id
and cps.cnprodserv_seq_id = soli.cnprodserv_seq_id
and soli.advnotif_seq_id = :b1
and soli.status_cd = 'OPEN'
AND(cps.group_nbr IS NULL OR(cps.group_nbr IS NOT NULL
AND cps.subgroup_nbr IS NOT NULL))
and NVL(ps.include_map_ind,'N') = 'Y'
order by 2
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- WB1100 SURVEYORS: the record group's own query
  PROCEDURE wb1100_lov_surveyors(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT LAST_NAME, FIRST_NAME, SEG_STF_SEQ_ID
FROM AT_SEG_STAFF
WHERE SEG_DEPT_SEQ_ID = (SELECT SEG_DEPT_SEQ_ID FROM AT_SEG_DEPARTMENTS
WHERE CODE = 'YARD')
ORDER BY LAST_NAME
) WHERE ROWNUM <= 5000~';
  END;

  -- WB2001 LOV_DISPSITES: the record group's own query
  PROCEDURE wb2001_lov_lov_dispsites(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT ALL AT_DISP_SITES.CODE, 
AT_DISP_SITES.DISP_SITE_SEQ_ID, AT_DISP_SITES.DESCRIPTION,
NVL(AT_DISP_SITES.ENVIROCARE_IND,'N') ENVIROCARE_IND
FROM AT_DISP_SITES ORDER BY 2
) WHERE ROWNUM <= 5000~';
  END;

  -- WB2001 LOV_RAD_FLAG: the record group's own query
  PROCEDURE wb2001_lov_lov_rad_flag(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT 'L' RAD_FLAG FROM DUAL
UNION ALL
SELECT 'H' FROM DUAL
UNION ALL
SELECT 'E' FROM DUAL
) WHERE ROWNUM <= 5000~';
  END;

  -- WB2001 LOV_WASTE_CD: the record group's own query
  PROCEDURE wb2001_lov_lov_waste_cd(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT 'A' WASTE_CLASS FROM DUAL
UNION ALL
SELECT 'B' FROM DUAL
UNION ALL
SELECT 'C' FROM DUAL
UNION ALL
SELECT '>C' FROM DUAL
) WHERE ROWNUM <= 5000~';
  END;

  -- WB4000 ITEMS: the record group's own query; P1 = :WB_QTB_CONTAINER.PARENT_CNTNR_SEQ_ID
  PROCEDURE wb4000_lov_items(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT a.manifested_line_item_nbr
      ,b.container_type_cd
      ,a.matl_seq_id
      ,a.advnotif_seq_id
FROM   at_materials a
      ,at_container_types b
      ,at_materials m2
WHERE      a.cntnr_typ_seq_id = b.cntnr_typ_seq_id
       AND a.parent_matl_seq_id = m2.matl_seq_id
       AND m2.cntnr_seq_id = :b1
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- WB4000 MID_PSC: the record group's own query; P1 = :FIRST_DAUGHTERS.NEXT_PROCESS_CD, P2 = :FIRST_DAUGHTERS.DSP_NEXT_PROCESS_CD, P3 = :WB_QTB_CONTAINER.ADVNOTIF_SEQ_ID
  PROCEDURE wb4000_lov_mid_psc(p1 IN VARCHAR2, p2 IN VARCHAR2, p3 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   DISTINCT ps.prodserv_cd psc
                 ,ds.alias
                 ,cps.description sp_instr
                 ,ps.description psc_desc
                 ,ps.prodserv_seq_id
                 ,cps.cnprodserv_seq_id
                 ,cps.cost
                 ,'A' cost_type
FROM     at_product_services ps
        ,at_process_trans_services ns
        ,at_process_trans_types ptt
        ,at_contract_prod_services cps
        ,at_seg_order_line_items soli
        ,at_disp_sites ds
WHERE        ptt.prctrantyp_seq_id = ns.prctrantyp_seq_id
         AND cps.prodserv_seq_id = ns.prodserv_seq_id
         AND cps.disp_site_seq_id = ds.disp_site_seq_id
         AND NVL(ps.include_map_ind, 'N') = 'Y'
         AND ptt.prctrantyp_cd_id = NVL( :b1, :b2)
         AND ps.prodserv_seq_id = cps.prodserv_seq_id
         AND cps.cnprodserv_seq_id = soli.cnprodserv_seq_id
         AND soli.advnotif_seq_id = :b3
         AND soli.status_cd = 'OPEN'
         AND NOT EXISTS
                 (SELECT 1
                  FROM   at_seg_order_line_items soli1
                  WHERE      soli1.grp_cnprodserv_seq_id = soli.cnprodserv_seq_id
                         AND soli1.advnotif_seq_id = :b4)
ORDER BY 1
) WHERE ROWNUM <= 5000~'
      USING p1, p2, p3, p3;
  END;

  -- WB4000 QTB_BURIAL_PARENT_LV: the record group's own query; P1 = :WB_QTB_CONTAINER.PARENT_CONTAINER_ID
  PROCEDURE wb4000_lov_qtb_burial_parent_l(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT t.qtb_barcode barcode
      ,t.full_wgt - t.empty_wgt full_wgt
      ,t.empty_wgt
      ,t.psc
      ,t.contents_pl
      ,t.contents_pa
      ,t.contents_cl
      ,t.contents_mt
      ,t.contents_wd
      ,t.contents_rb
      ,t.contents_as
      ,t.contents_al
      ,t.contents_ss
      ,t.contents_cp
      ,t.contents_ot
      ,t.contents_ot2
      ,t.qtb_cntnr_seq_id cntnr_seq_id
      ,t.other_contents_desc
      ,t.other_contents_desc2
      ,t.other_matl_typ_seq_id2
      ,t.other_matl_typ_seq_id
FROM   wb_qtb_containers t
WHERE      t.parent_container_id = :b1
       AND t.qtb_barcode IS NOT NULL
       AND NVL(t.full_wgt, 0) - NVL(t.empty_wgt, 0) <> 0
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- WB4000 VALID_NPC: the record group's own query; P1 = :WB_QTB_CONTAINER.ADVNOTIF_SEQ_ID
  PROCEDURE wb4000_lov_valid_npc(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   DISTINCT pt.prctrantyp_cd_id npc
                 ,ns.prctrantyp_seq_id next_npc_seq_id
                 ,pt.description
                 ,pt.rtc_ind
                 ,pt.prctrantyp_cd_id next_process_cd
FROM     at_product_services ps
        ,at_contract_prod_services cps
        ,at_seg_order_line_items soli
        ,at_process_trans_services ns
        ,at_process_trans_types pt
WHERE        ps.prodserv_seq_id = cps.prodserv_seq_id
         AND cps.cnprodserv_seq_id = soli.cnprodserv_seq_id
         AND pt.prctrantyp_seq_id = ns.prctrantyp_seq_id
         AND ns.prodserv_seq_id = ps.prodserv_seq_id
         AND soli.advnotif_seq_id = :b1
         AND soli.status_cd = 'OPEN'
         AND NVL(ps.include_map_ind, 'N') = 'Y'
         AND (   NVL(cps.group_nbr, 0) = 0
              OR (    NVL(cps.group_nbr, 0) <> 0
                  AND NVL(cps.subgroup_nbr, 0) <> 0))
         AND pt.show_in_lov = 'Y'
ORDER BY pt.prctrantyp_cd_id
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;
  -- <<< end of generated lists of values

  -- >>> generated by scripts/jdapi/block-package.cjs: query blocks run as the form wrote them
  -- AT1310 COMNT: AT_COMMENT_INSTRUCTIONS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1310_w_comnt(b_cust9_cust_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_comnttyp_seq_id IN NUMBER, p_cntrct_seq_id IN NUMBER, p_comment_txt IN VARCHAR2, p_active_ind IN VARCHAR2, p_marketing_approval_ind IN VARCHAR2, p_comnt_seq_id IN NUMBER, p_created_by_name IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_COMMENT_INSTRUCTIONS
 WHERE (
(COMNT_SEQ_ID = (SELECT MAX(COMNT_SEQ_ID)
FROM AT_COMMENT_INSTRUCTIONS WHERE
(CUST_SEQ_ID = :w1 AND
COMNTTYP_SEQ_ID = (SELECT COMNTTYP_SEQ_ID
FROM AT_COMNT_INSTR_TYPES 
WHERE CODE = 'CUSTOMER')))) 
)
   AND (:c1 IS NULL OR cust_seq_id = :c2)
   AND (:c3 IS NULL OR comnttyp_seq_id = :c4)
   AND (:c5 IS NULL OR cntrct_seq_id = :c6)
   AND (:c7 IS NULL OR (CASE WHEN INSTR(:c8, '%') + INSTR(:c9, '_') > 0 THEN CASE WHEN comment_txt LIKE :c10 THEN 1 END WHEN comment_txt = :c11 THEN 1 END) = 1)
   AND (:c12 IS NULL OR (CASE WHEN INSTR(:c13, '%') + INSTR(:c14, '_') > 0 THEN CASE WHEN active_ind LIKE :c15 THEN 1 END WHEN active_ind = :c16 THEN 1 END) = 1)
   AND (:c17 IS NULL OR (CASE WHEN INSTR(:c18, '%') + INSTR(:c19, '_') > 0 THEN CASE WHEN marketing_approval_ind LIKE :c20 THEN 1 END WHEN marketing_approval_ind = :c21 THEN 1 END) = 1)
   AND (:c22 IS NULL OR comnt_seq_id = :c23)
   AND (:c24 IS NULL OR (CASE WHEN INSTR(:c25, '%') + INSTR(:c26, '_') > 0 THEN CASE WHEN created_by_name LIKE :c27 THEN 1 END WHEN created_by_name = :c28 THEN 1 END) = 1)
) WHERE ROWNUM <= 5000~'
      USING b_cust9_cust_seq_id, p_cust_seq_id, p_cust_seq_id, p_comnttyp_seq_id, p_comnttyp_seq_id, p_cntrct_seq_id, p_cntrct_seq_id, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_active_ind, p_active_ind, p_active_ind, p_active_ind, p_active_ind, p_marketing_approval_ind, p_marketing_approval_ind, p_marketing_approval_ind, p_marketing_approval_ind, p_marketing_approval_ind, p_comnt_seq_id, p_comnt_seq_id, p_created_by_name, p_created_by_name, p_created_by_name, p_created_by_name, p_created_by_name;
  END;

  -- AT1330 SEARCH: the block's own FROM-clause query (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1330_q_search(p_waste_profile_number IN VARCHAR2, p_customer_nbr IN NUMBER, p_customer_name IN VARCHAR2, p_site_cd IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM (
SELECT p.waste_profile_number
       ,c.customer_nbr
       ,c.name customer_name
       ,p.site_cd
 FROM   at_esprofiles p
       ,at_customers c
 WHERE  p.gen_cust_seq_id = c.cust_seq_id
) q
 WHERE (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN q.waste_profile_number LIKE :c4 THEN 1 END WHEN q.waste_profile_number = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR q.customer_nbr = :c7)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN q.customer_name LIKE :c11 THEN 1 END WHEN q.customer_name = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN q.site_cd LIKE :c16 THEN 1 END WHEN q.site_cd = :c17 THEN 1 END) = 1)
 ORDER BY waste_profile_number, customer_nbr
) WHERE ROWNUM <= 5000~'
      USING p_waste_profile_number, p_waste_profile_number, p_waste_profile_number, p_waste_profile_number, p_waste_profile_number, p_customer_nbr, p_customer_nbr, p_customer_name, p_customer_name, p_customer_name, p_customer_name, p_customer_name, p_site_cd, p_site_cd, p_site_cd, p_site_cd, p_site_cd;
  END;

  -- AT1410 AT_CNTRCT_CUST_VIEW: AT_CNTRCT_CUST_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1410_w_at_cntrct_cust_view(b_at_contracts_contract_nbr IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_parent_cntrct_seq_id IN NUMBER, p_contract_nbr IN VARCHAR2, p_mod_cntrct_id IN NUMBER, p_customer_nbr IN NUMBER, p_name IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CNTRCT_CUST_VIEW
 WHERE (
contract_nbr = :w1
)
   AND (:c1 IS NULL OR cntrct_seq_id = :c2)
   AND (:c3 IS NULL OR parent_cntrct_seq_id = :c4)
   AND (:c5 IS NULL OR (CASE WHEN INSTR(:c6, '%') + INSTR(:c7, '_') > 0 THEN CASE WHEN contract_nbr LIKE :c8 THEN 1 END WHEN contract_nbr = :c9 THEN 1 END) = 1)
   AND (:c10 IS NULL OR mod_cntrct_id = :c11)
   AND (:c12 IS NULL OR customer_nbr = :c13)
   AND (:c14 IS NULL OR (CASE WHEN INSTR(:c15, '%') + INSTR(:c16, '_') > 0 THEN CASE WHEN name LIKE :c17 THEN 1 END WHEN name = :c18 THEN 1 END) = 1)
 ORDER BY CUSTOMER_NBR
) WHERE ROWNUM <= 5000~'
      USING b_at_contracts_contract_nbr, p_cntrct_seq_id, p_cntrct_seq_id, p_parent_cntrct_seq_id, p_parent_cntrct_seq_id, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_mod_cntrct_id, p_mod_cntrct_id, p_customer_nbr, p_customer_nbr, p_name, p_name, p_name, p_name, p_name;
  END;

  -- AT1410 CLONE_PROD_SERVICES: AT_CONTRACT_PROD_SERVICES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1410_w_clone_prod_services(b_at_contracts_cntrct_seq_id IN NUMBER, b_at_contracts_cust_seq_id IN NUMBER, p_group_nbr IN VARCHAR2, p_subgroup_nbr IN VARCHAR2, p_cost IN NUMBER, p_unit_cd_id IN VARCHAR2, p_description IN VARCHAR2, p_prodserv_seq_id IN NUMBER, p_prodserv_prodcat_seq_id IN NUMBER, p_cnprodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_cntrct_seq_id IN NUMBER, p_contract_line_nbr IN VARCHAR2, p_current_available_amt IN NUMBER, p_sales_received_amt IN NUMBER, p_overestimate_limit_pct IN NUMBER, p_quantity IN NUMBER, p_prof_seq_id IN NUMBER, p_basis IN VARCHAR2, p_basis_pct IN NUMBER, p_min_charge IN NUMBER, p_density_min IN NUMBER, p_density_max IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTRACT_PROD_SERVICES
 WHERE (
cntrct_seq_id = :w1 and cust_seq_id = :w2
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN group_nbr LIKE :c4 THEN 1 END WHEN group_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN subgroup_nbr LIKE :c9 THEN 1 END WHEN subgroup_nbr = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR cost = :c12)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN unit_cd_id LIKE :c16 THEN 1 END WHEN unit_cd_id = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN description LIKE :c21 THEN 1 END WHEN description = :c22 THEN 1 END) = 1)
   AND (:c23 IS NULL OR prodserv_seq_id = :c24)
   AND (:c25 IS NULL OR prodserv_prodcat_seq_id = :c26)
   AND (:c27 IS NULL OR cnprodserv_seq_id = :c28)
   AND (:c29 IS NULL OR disp_site_seq_id = :c30)
   AND (:c31 IS NULL OR cntrct_seq_id = :c32)
   AND (:c33 IS NULL OR (CASE WHEN INSTR(:c34, '%') + INSTR(:c35, '_') > 0 THEN CASE WHEN contract_line_nbr LIKE :c36 THEN 1 END WHEN contract_line_nbr = :c37 THEN 1 END) = 1)
   AND (:c38 IS NULL OR current_available_amt = :c39)
   AND (:c40 IS NULL OR sales_received_amt = :c41)
   AND (:c42 IS NULL OR overestimate_limit_pct = :c43)
   AND (:c44 IS NULL OR quantity = :c45)
   AND (:c46 IS NULL OR prof_seq_id = :c47)
   AND (:c48 IS NULL OR (CASE WHEN INSTR(:c49, '%') + INSTR(:c50, '_') > 0 THEN CASE WHEN basis LIKE :c51 THEN 1 END WHEN basis = :c52 THEN 1 END) = 1)
   AND (:c53 IS NULL OR basis_pct = :c54)
   AND (:c55 IS NULL OR min_charge = :c56)
   AND (:c57 IS NULL OR density_min = :c58)
   AND (:c59 IS NULL OR density_max = :c60)
 ORDER BY group_nbr, nvl(subgroup_nbr,0), get_the_code(prodserv_seq_id)
) WHERE ROWNUM <= 5000~'
      USING b_at_contracts_cntrct_seq_id, b_at_contracts_cust_seq_id, p_group_nbr, p_group_nbr, p_group_nbr, p_group_nbr, p_group_nbr, p_subgroup_nbr, p_subgroup_nbr, p_subgroup_nbr, p_subgroup_nbr, p_subgroup_nbr, p_cost, p_cost, p_unit_cd_id, p_unit_cd_id, p_unit_cd_id, p_unit_cd_id, p_unit_cd_id, p_description, p_description, p_description, p_description, p_description, p_prodserv_seq_id, p_prodserv_seq_id, p_prodserv_prodcat_seq_id, p_prodserv_prodcat_seq_id, p_cnprodserv_seq_id, p_cnprodserv_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_cntrct_seq_id, p_cntrct_seq_id, p_contract_line_nbr, p_contract_line_nbr, p_contract_line_nbr, p_contract_line_nbr, p_contract_line_nbr, p_current_available_amt, p_current_available_amt, p_sales_received_amt, p_sales_received_amt, p_overestimate_limit_pct, p_overestimate_limit_pct, p_quantity, p_quantity, p_prof_seq_id, p_prof_seq_id, p_basis, p_basis, p_basis, p_basis, p_basis, p_basis_pct, p_basis_pct, p_min_charge, p_min_charge, p_density_min, p_density_min, p_density_max, p_density_max;
  END;

  -- AT1510 AT_CPS_VIEW: AT_CNPRODSERV_VIEW3@ATCORP.ENERGYSOLUTIONS.COM with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1510_w_at_cps_view(b_mnfst_cust_seq_id IN NUMBER, b_mnfst_advnotif_expected_e379 IN DATE, b_mnfst_es_prof_seq_id IN NUMBER, b_mnfst_disp_site_seq_id IN NUMBER, p_cntrct_contract_nbr IN VARCHAR2, p_cntrct_mod_cntrct_id IN NUMBER, p_cnprodserv_seq_id IN NUMBER, p_prodserv_cd IN VARCHAR2, p_prodserv_descr IN VARCHAR2, p_dispsite_alias IN VARCHAR2, p_cnprodserv_cost IN NUMBER, p_cnprodserv_unit_cd_id IN VARCHAR2, p_cnprodserv_descr IN VARCHAR2, p_cnprodserv_cust_seq_id IN NUMBER, p_prodserv_prodcat_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_group_nbr IN VARCHAR2, p_subgroup_nbr IN VARCHAR2, p_disposal_revenue_ind IN VARCHAR2, p_certification_prog_ind IN VARCHAR2, p_life_of_plant_ind IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_tax_included_ind IN VARCHAR2, p_dispsite_code IN VARCHAR2, p_min_charge IN NUMBER, p_seg_resp_dept_nm IN VARCHAR2, p_contract_line_nbr IN VARCHAR2, p_prodcat_descr IN VARCHAR2, p_classified_ind IN VARCHAR2, p_prof_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM at_cnprodserv_view3@atcorp.energysolutions.com
 WHERE (
           cntrct_mod_cntrct_id =
               get_max_mod4@atcorp.energysolutions.com(cntrct_contract_nbr
                                                      , :w1
                                                      ,NVL( :w2, SYSDATE))
       AND cnprodserv_cust_seq_id = :w3
       AND prof_seq_id = NVL( :w4, prof_seq_id)
       AND disp_site_seq_id = NVL( :w5, disp_site_seq_id)
       AND NVL(subgroup_nbr, 0) = 0
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN cntrct_contract_nbr LIKE :c4 THEN 1 END WHEN cntrct_contract_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR cntrct_mod_cntrct_id = :c7)
   AND (:c8 IS NULL OR cnprodserv_seq_id = :c9)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN prodserv_cd LIKE :c13 THEN 1 END WHEN prodserv_cd = :c14 THEN 1 END) = 1)
   AND (:c15 IS NULL OR (CASE WHEN INSTR(:c16, '%') + INSTR(:c17, '_') > 0 THEN CASE WHEN prodserv_descr LIKE :c18 THEN 1 END WHEN prodserv_descr = :c19 THEN 1 END) = 1)
   AND (:c20 IS NULL OR (CASE WHEN INSTR(:c21, '%') + INSTR(:c22, '_') > 0 THEN CASE WHEN dispsite_alias LIKE :c23 THEN 1 END WHEN dispsite_alias = :c24 THEN 1 END) = 1)
   AND (:c25 IS NULL OR cnprodserv_cost = :c26)
   AND (:c27 IS NULL OR (CASE WHEN INSTR(:c28, '%') + INSTR(:c29, '_') > 0 THEN CASE WHEN cnprodserv_unit_cd_id LIKE :c30 THEN 1 END WHEN cnprodserv_unit_cd_id = :c31 THEN 1 END) = 1)
   AND (:c32 IS NULL OR (CASE WHEN INSTR(:c33, '%') + INSTR(:c34, '_') > 0 THEN CASE WHEN cnprodserv_descr LIKE :c35 THEN 1 END WHEN cnprodserv_descr = :c36 THEN 1 END) = 1)
   AND (:c37 IS NULL OR cnprodserv_cust_seq_id = :c38)
   AND (:c39 IS NULL OR prodserv_prodcat_seq_id = :c40)
   AND (:c41 IS NULL OR prodserv_seq_id = :c42)
   AND (:c43 IS NULL OR (CASE WHEN INSTR(:c44, '%') + INSTR(:c45, '_') > 0 THEN CASE WHEN group_nbr LIKE :c46 THEN 1 END WHEN group_nbr = :c47 THEN 1 END) = 1)
   AND (:c48 IS NULL OR (CASE WHEN INSTR(:c49, '%') + INSTR(:c50, '_') > 0 THEN CASE WHEN subgroup_nbr LIKE :c51 THEN 1 END WHEN subgroup_nbr = :c52 THEN 1 END) = 1)
   AND (:c53 IS NULL OR (CASE WHEN INSTR(:c54, '%') + INSTR(:c55, '_') > 0 THEN CASE WHEN disposal_revenue_ind LIKE :c56 THEN 1 END WHEN disposal_revenue_ind = :c57 THEN 1 END) = 1)
   AND (:c58 IS NULL OR (CASE WHEN INSTR(:c59, '%') + INSTR(:c60, '_') > 0 THEN CASE WHEN certification_prog_ind LIKE :c61 THEN 1 END WHEN certification_prog_ind = :c62 THEN 1 END) = 1)
   AND (:c63 IS NULL OR (CASE WHEN INSTR(:c64, '%') + INSTR(:c65, '_') > 0 THEN CASE WHEN life_of_plant_ind LIKE :c66 THEN 1 END WHEN life_of_plant_ind = :c67 THEN 1 END) = 1)
   AND (:c68 IS NULL OR cntrct_seq_id = :c69)
   AND (:c70 IS NULL OR (CASE WHEN INSTR(:c71, '%') + INSTR(:c72, '_') > 0 THEN CASE WHEN tax_included_ind LIKE :c73 THEN 1 END WHEN tax_included_ind = :c74 THEN 1 END) = 1)
   AND (:c75 IS NULL OR (CASE WHEN INSTR(:c76, '%') + INSTR(:c77, '_') > 0 THEN CASE WHEN dispsite_code LIKE :c78 THEN 1 END WHEN dispsite_code = :c79 THEN 1 END) = 1)
   AND (:c80 IS NULL OR min_charge = :c81)
   AND (:c82 IS NULL OR (CASE WHEN INSTR(:c83, '%') + INSTR(:c84, '_') > 0 THEN CASE WHEN seg_resp_dept_nm LIKE :c85 THEN 1 END WHEN seg_resp_dept_nm = :c86 THEN 1 END) = 1)
   AND (:c87 IS NULL OR (CASE WHEN INSTR(:c88, '%') + INSTR(:c89, '_') > 0 THEN CASE WHEN contract_line_nbr LIKE :c90 THEN 1 END WHEN contract_line_nbr = :c91 THEN 1 END) = 1)
   AND (:c92 IS NULL OR (CASE WHEN INSTR(:c93, '%') + INSTR(:c94, '_') > 0 THEN CASE WHEN prodcat_descr LIKE :c95 THEN 1 END WHEN prodcat_descr = :c96 THEN 1 END) = 1)
   AND (:c97 IS NULL OR (CASE WHEN INSTR(:c98, '%') + INSTR(:c99, '_') > 0 THEN CASE WHEN classified_ind LIKE :c100 THEN 1 END WHEN classified_ind = :c101 THEN 1 END) = 1)
   AND (:c102 IS NULL OR prof_seq_id = :c103)
   AND (:c104 IS NULL OR disp_site_seq_id = :c105)
 ORDER BY prodserv_cd asc, cntrct_contract_nbr asc
) WHERE ROWNUM <= 5000~'
      USING b_mnfst_cust_seq_id, b_mnfst_advnotif_expected_e379, b_mnfst_cust_seq_id, b_mnfst_es_prof_seq_id, b_mnfst_disp_site_seq_id, p_cntrct_contract_nbr, p_cntrct_contract_nbr, p_cntrct_contract_nbr, p_cntrct_contract_nbr, p_cntrct_contract_nbr, p_cntrct_mod_cntrct_id, p_cntrct_mod_cntrct_id, p_cnprodserv_seq_id, p_cnprodserv_seq_id, p_prodserv_cd, p_prodserv_cd, p_prodserv_cd, p_prodserv_cd, p_prodserv_cd, p_prodserv_descr, p_prodserv_descr, p_prodserv_descr, p_prodserv_descr, p_prodserv_descr, p_dispsite_alias, p_dispsite_alias, p_dispsite_alias, p_dispsite_alias, p_dispsite_alias, p_cnprodserv_cost, p_cnprodserv_cost, p_cnprodserv_unit_cd_id, p_cnprodserv_unit_cd_id, p_cnprodserv_unit_cd_id, p_cnprodserv_unit_cd_id, p_cnprodserv_unit_cd_id, p_cnprodserv_descr, p_cnprodserv_descr, p_cnprodserv_descr, p_cnprodserv_descr, p_cnprodserv_descr, p_cnprodserv_cust_seq_id, p_cnprodserv_cust_seq_id, p_prodserv_prodcat_seq_id, p_prodserv_prodcat_seq_id, p_prodserv_seq_id, p_prodserv_seq_id, p_group_nbr, p_group_nbr, p_group_nbr, p_group_nbr, p_group_nbr, p_subgroup_nbr, p_subgroup_nbr, p_subgroup_nbr, p_subgroup_nbr, p_subgroup_nbr, p_disposal_revenue_ind, p_disposal_revenue_ind, p_disposal_revenue_ind, p_disposal_revenue_ind, p_disposal_revenue_ind, p_certification_prog_ind, p_certification_prog_ind, p_certification_prog_ind, p_certification_prog_ind, p_certification_prog_ind, p_life_of_plant_ind, p_life_of_plant_ind, p_life_of_plant_ind, p_life_of_plant_ind, p_life_of_plant_ind, p_cntrct_seq_id, p_cntrct_seq_id, p_tax_included_ind, p_tax_included_ind, p_tax_included_ind, p_tax_included_ind, p_tax_included_ind, p_dispsite_code, p_dispsite_code, p_dispsite_code, p_dispsite_code, p_dispsite_code, p_min_charge, p_min_charge, p_seg_resp_dept_nm, p_seg_resp_dept_nm, p_seg_resp_dept_nm, p_seg_resp_dept_nm, p_seg_resp_dept_nm, p_contract_line_nbr, p_contract_line_nbr, p_contract_line_nbr, p_contract_line_nbr, p_contract_line_nbr, p_prodcat_descr, p_prodcat_descr, p_prodcat_descr, p_prodcat_descr, p_prodcat_descr, p_classified_ind, p_classified_ind, p_classified_ind, p_classified_ind, p_classified_ind, p_prof_seq_id, p_prof_seq_id, p_disp_site_seq_id, p_disp_site_seq_id;
  END;

  -- AT1510 AT_INVOICES: AT_INVOICES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1510_w_at_invoices(b_mnfst_advnotif_seq_id IN NUMBER, p_invoice_nbr IN VARCHAR2, p_invoice_type_cd IN VARCHAR2, p_invoice_category_cd IN VARCHAR2, p_invc_seq_id IN NUMBER, p_invoice_loc_cd IN VARCHAR2, p_ship_to_cust_seq_id IN NUMBER, p_charge_to_cust_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_face_sheeted IN VARCHAR2, p_notes IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_terms IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_INVOICES
 WHERE (
invc_seq_id in (
select invc_seq_id
from at_invoice_line_items
where advnotif_seq_id = :w1
union
select invc_seq_id
from at_invoice_line_shipments
where manifest_nbr in (
select manifest_nbr
from at_incoming_manifests
where advnotif_seq_id = :w2))
and advnotif_seq_id <> 1086
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN invoice_nbr LIKE :c4 THEN 1 END WHEN invoice_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN invoice_type_cd LIKE :c9 THEN 1 END WHEN invoice_type_cd = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR (CASE WHEN INSTR(:c12, '%') + INSTR(:c13, '_') > 0 THEN CASE WHEN invoice_category_cd LIKE :c14 THEN 1 END WHEN invoice_category_cd = :c15 THEN 1 END) = 1)
   AND (:c16 IS NULL OR invc_seq_id = :c17)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN invoice_loc_cd LIKE :c21 THEN 1 END WHEN invoice_loc_cd = :c22 THEN 1 END) = 1)
   AND (:c23 IS NULL OR ship_to_cust_seq_id = :c24)
   AND (:c25 IS NULL OR charge_to_cust_seq_id = :c26)
   AND (:c27 IS NULL OR seg_stf_seq_id = :c28)
   AND (:c29 IS NULL OR (CASE WHEN INSTR(:c30, '%') + INSTR(:c31, '_') > 0 THEN CASE WHEN face_sheeted LIKE :c32 THEN 1 END WHEN face_sheeted = :c33 THEN 1 END) = 1)
   AND (:c34 IS NULL OR (CASE WHEN INSTR(:c35, '%') + INSTR(:c36, '_') > 0 THEN CASE WHEN notes LIKE :c37 THEN 1 END WHEN notes = :c38 THEN 1 END) = 1)
   AND (:c39 IS NULL OR cntrct_seq_id = :c40)
   AND (:c41 IS NULL OR (CASE WHEN INSTR(:c42, '%') + INSTR(:c43, '_') > 0 THEN CASE WHEN terms LIKE :c44 THEN 1 END WHEN terms = :c45 THEN 1 END) = 1)
 ORDER BY invoice_nbr
) WHERE ROWNUM <= 5000~'
      USING b_mnfst_advnotif_seq_id, b_mnfst_advnotif_seq_id, p_invoice_nbr, p_invoice_nbr, p_invoice_nbr, p_invoice_nbr, p_invoice_nbr, p_invoice_type_cd, p_invoice_type_cd, p_invoice_type_cd, p_invoice_type_cd, p_invoice_type_cd, p_invoice_category_cd, p_invoice_category_cd, p_invoice_category_cd, p_invoice_category_cd, p_invoice_category_cd, p_invc_seq_id, p_invc_seq_id, p_invoice_loc_cd, p_invoice_loc_cd, p_invoice_loc_cd, p_invoice_loc_cd, p_invoice_loc_cd, p_ship_to_cust_seq_id, p_ship_to_cust_seq_id, p_charge_to_cust_seq_id, p_charge_to_cust_seq_id, p_seg_stf_seq_id, p_seg_stf_seq_id, p_face_sheeted, p_face_sheeted, p_face_sheeted, p_face_sheeted, p_face_sheeted, p_notes, p_notes, p_notes, p_notes, p_notes, p_cntrct_seq_id, p_cntrct_seq_id, p_terms, p_terms, p_terms, p_terms, p_terms;
  END;

  -- AT1510 RNCNTNRS: AT_RENTAL_CNTNR_SHIPMENTS_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1510_w_rncntnrs(p_rental_container_id IN VARCHAR2, p_rncntnrstat_cd_id IN VARCHAR2, p_seg_owned_ind IN VARCHAR2, p_out_shipment_nbr IN VARCHAR2, p_shipment_type_cd IN VARCHAR2, p_consignee_cust_seq_id IN NUMBER, p_pick_up_cust_seq_id IN NUMBER, p_rncntnr_seq_id IN NUMBER, p_segordlitm_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_RENTAL_CNTNR_SHIPMENTS_VIEW
 WHERE (
  AT_RENTAL_CNTNR_SHIPMENTS_VIEW.PICK_UP_CUST_SEQ_ID = (
       select c.cust_seq_id 
         from at_customers c
        where c.customer_nbr = 396 )

)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN rental_container_id LIKE :c4 THEN 1 END WHEN rental_container_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN rncntnrstat_cd_id LIKE :c9 THEN 1 END WHEN rncntnrstat_cd_id = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR (CASE WHEN INSTR(:c12, '%') + INSTR(:c13, '_') > 0 THEN CASE WHEN seg_owned_ind LIKE :c14 THEN 1 END WHEN seg_owned_ind = :c15 THEN 1 END) = 1)
   AND (:c16 IS NULL OR (CASE WHEN INSTR(:c17, '%') + INSTR(:c18, '_') > 0 THEN CASE WHEN out_shipment_nbr LIKE :c19 THEN 1 END WHEN out_shipment_nbr = :c20 THEN 1 END) = 1)
   AND (:c21 IS NULL OR (CASE WHEN INSTR(:c22, '%') + INSTR(:c23, '_') > 0 THEN CASE WHEN shipment_type_cd LIKE :c24 THEN 1 END WHEN shipment_type_cd = :c25 THEN 1 END) = 1)
   AND (:c26 IS NULL OR consignee_cust_seq_id = :c27)
   AND (:c28 IS NULL OR pick_up_cust_seq_id = :c29)
   AND (:c30 IS NULL OR rncntnr_seq_id = :c31)
   AND (:c32 IS NULL OR segordlitm_seq_id = :c33)
) WHERE ROWNUM <= 5000~'
      USING p_rental_container_id, p_rental_container_id, p_rental_container_id, p_rental_container_id, p_rental_container_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_seg_owned_ind, p_seg_owned_ind, p_seg_owned_ind, p_seg_owned_ind, p_seg_owned_ind, p_out_shipment_nbr, p_out_shipment_nbr, p_out_shipment_nbr, p_out_shipment_nbr, p_out_shipment_nbr, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_consignee_cust_seq_id, p_consignee_cust_seq_id, p_pick_up_cust_seq_id, p_pick_up_cust_seq_id, p_rncntnr_seq_id, p_rncntnr_seq_id, p_segordlitm_seq_id, p_segordlitm_seq_id;
  END;

  -- AT1551 UNMAPPED_BARCODES: AT_ORDER_BARCODE_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1551_w_unmapped_barcodes(b_at_incoming_manifests_o_621d IN NUMBER, p_container_id IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_next_prctrantyp_seq_id IN NUMBER, p_source IN VARCHAR2, p_prctrantyp_cd_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_description IN VARCHAR2, p_anchor_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_ORDER_BARCODE_VIEW
 WHERE (
advnotif_seq_id = :w1
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN container_id LIKE :c4 THEN 1 END WHEN container_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN cntnr_stat_cd_id LIKE :c9 THEN 1 END WHEN cntnr_stat_cd_id = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR next_prctrantyp_seq_id = :c12)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN source LIKE :c16 THEN 1 END WHEN source = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN prctrantyp_cd_id LIKE :c21 THEN 1 END WHEN prctrantyp_cd_id = :c22 THEN 1 END) = 1)
   AND (:c23 IS NULL OR cntnr_seq_id = :c24)
   AND (:c25 IS NULL OR advnotif_seq_id = :c26)
   AND (:c27 IS NULL OR (CASE WHEN INSTR(:c28, '%') + INSTR(:c29, '_') > 0 THEN CASE WHEN description LIKE :c30 THEN 1 END WHEN description = :c31 THEN 1 END) = 1)
   AND (:c32 IS NULL OR anchor_wgt = :c33)
 ORDER BY container_id
) WHERE ROWNUM <= 5000~'
      USING b_at_incoming_manifests_o_621d, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_next_prctrantyp_seq_id, p_next_prctrantyp_seq_id, p_source, p_source, p_source, p_source, p_source, p_prctrantyp_cd_id, p_prctrantyp_cd_id, p_prctrantyp_cd_id, p_prctrantyp_cd_id, p_prctrantyp_cd_id, p_cntnr_seq_id, p_cntnr_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_description, p_description, p_description, p_description, p_description, p_anchor_wgt, p_anchor_wgt;
  END;

  -- AT1552 UNMAPPED_ORDERS: AT_BARCODE_ORDER_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1552_w_unmapped_orders(b_at_containers_cntnr_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_manifest_nbr IN VARCHAR2, p_cust_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_BARCODE_ORDER_VIEW
 WHERE (
cntnr_seq_id = :w1
)
   AND (:c1 IS NULL OR advnotif_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN manifest_nbr LIKE :c6 THEN 1 END WHEN manifest_nbr = :c7 THEN 1 END) = 1)
   AND (:c8 IS NULL OR cust_seq_id = :c9)
 ORDER BY advnotif_seq_id
) WHERE ROWNUM <= 5000~'
      USING b_at_containers_cntnr_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_cust_seq_id, p_cust_seq_id;
  END;

  -- AT1710 AT_RENTAL_CNTNR_SHIPMENTS_VIEW: AT_RENTAL_CNTNR_SHIPMENTS_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1710_w_at_rental_cntnr__50a1(b_inv_ship_to_cust_seq_id IN NUMBER, b_at$ctrl_end_dt IN DATE, b_at$ctrl_begin_dt IN DATE, p_out_shipment_nbr IN VARCHAR2, p_rncntnr_seq_id IN NUMBER, p_rental_container_id IN VARCHAR2, p_old_sl_nbr IN VARCHAR2, p_tare_wgt IN NUMBER, p_seg_owned_ind IN VARCHAR2, p_rncntnrstat_cd_id IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_billing_cust_seq_id IN NUMBER, p_owned_by_cust_seq_id IN NUMBER, p_comment_txt IN VARCHAR2, p_storage_loc_sl_ind IN VARCHAR2, p_current_site_seq_id IN NUMBER, p_in_shipment_nbr IN VARCHAR2, p_in_cust_seq IN VARCHAR2, p_segordlitm_seq_id IN NUMBER, p_shipment_type_cd IN VARCHAR2, p_consignee_cust_seq_id IN NUMBER, p_pick_up_cust_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_RENTAL_CNTNR_SHIPMENTS_VIEW
 WHERE (
consignee_cust_seq_id = :w1
and (owned_by_cust_seq_id in (1296,3382,1202) or rented_by_cust_seq_id in (1296,3382,1202))
and (
    (out_dt <= :w2 and NVL(in_dt,:w3) >= :w4) 
    or
    (
    NVL(in_dt,:w5) >= :w6 and NVL(out_dt,:w7) <= :w8
    )
    )
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN out_shipment_nbr LIKE :c4 THEN 1 END WHEN out_shipment_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR rncntnr_seq_id = :c7)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN rental_container_id LIKE :c11 THEN 1 END WHEN rental_container_id = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN old_sl_nbr LIKE :c16 THEN 1 END WHEN old_sl_nbr = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR tare_wgt = :c19)
   AND (:c20 IS NULL OR (CASE WHEN INSTR(:c21, '%') + INSTR(:c22, '_') > 0 THEN CASE WHEN seg_owned_ind LIKE :c23 THEN 1 END WHEN seg_owned_ind = :c24 THEN 1 END) = 1)
   AND (:c25 IS NULL OR (CASE WHEN INSTR(:c26, '%') + INSTR(:c27, '_') > 0 THEN CASE WHEN rncntnrstat_cd_id LIKE :c28 THEN 1 END WHEN rncntnrstat_cd_id = :c29 THEN 1 END) = 1)
   AND (:c30 IS NULL OR cntnr_typ_seq_id = :c31)
   AND (:c32 IS NULL OR billing_cust_seq_id = :c33)
   AND (:c34 IS NULL OR owned_by_cust_seq_id = :c35)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN comment_txt LIKE :c39 THEN 1 END WHEN comment_txt = :c40 THEN 1 END) = 1)
   AND (:c41 IS NULL OR (CASE WHEN INSTR(:c42, '%') + INSTR(:c43, '_') > 0 THEN CASE WHEN storage_loc_sl_ind LIKE :c44 THEN 1 END WHEN storage_loc_sl_ind = :c45 THEN 1 END) = 1)
   AND (:c46 IS NULL OR current_site_seq_id = :c47)
   AND (:c48 IS NULL OR (CASE WHEN INSTR(:c49, '%') + INSTR(:c50, '_') > 0 THEN CASE WHEN in_shipment_nbr LIKE :c51 THEN 1 END WHEN in_shipment_nbr = :c52 THEN 1 END) = 1)
   AND (:c53 IS NULL OR (CASE WHEN INSTR(:c54, '%') + INSTR(:c55, '_') > 0 THEN CASE WHEN in_cust_seq LIKE :c56 THEN 1 END WHEN in_cust_seq = :c57 THEN 1 END) = 1)
   AND (:c58 IS NULL OR segordlitm_seq_id = :c59)
   AND (:c60 IS NULL OR (CASE WHEN INSTR(:c61, '%') + INSTR(:c62, '_') > 0 THEN CASE WHEN shipment_type_cd LIKE :c63 THEN 1 END WHEN shipment_type_cd = :c64 THEN 1 END) = 1)
   AND (:c65 IS NULL OR consignee_cust_seq_id = :c66)
   AND (:c67 IS NULL OR pick_up_cust_seq_id = :c68)
 ORDER BY /*get_cntnr_type(rental_container_id)*/ rental_container_id
) WHERE ROWNUM <= 5000~'
      USING b_inv_ship_to_cust_seq_id, b_at$ctrl_end_dt, b_at$ctrl_begin_dt, b_at$ctrl_begin_dt, b_at$ctrl_end_dt, b_at$ctrl_end_dt, b_at$ctrl_end_dt, b_at$ctrl_end_dt, p_out_shipment_nbr, p_out_shipment_nbr, p_out_shipment_nbr, p_out_shipment_nbr, p_out_shipment_nbr, p_rncntnr_seq_id, p_rncntnr_seq_id, p_rental_container_id, p_rental_container_id, p_rental_container_id, p_rental_container_id, p_rental_container_id, p_old_sl_nbr, p_old_sl_nbr, p_old_sl_nbr, p_old_sl_nbr, p_old_sl_nbr, p_tare_wgt, p_tare_wgt, p_seg_owned_ind, p_seg_owned_ind, p_seg_owned_ind, p_seg_owned_ind, p_seg_owned_ind, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id, p_billing_cust_seq_id, p_billing_cust_seq_id, p_owned_by_cust_seq_id, p_owned_by_cust_seq_id, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_storage_loc_sl_ind, p_storage_loc_sl_ind, p_storage_loc_sl_ind, p_storage_loc_sl_ind, p_storage_loc_sl_ind, p_current_site_seq_id, p_current_site_seq_id, p_in_shipment_nbr, p_in_shipment_nbr, p_in_shipment_nbr, p_in_shipment_nbr, p_in_shipment_nbr, p_in_cust_seq, p_in_cust_seq, p_in_cust_seq, p_in_cust_seq, p_in_cust_seq, p_segordlitm_seq_id, p_segordlitm_seq_id, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_consignee_cust_seq_id, p_consignee_cust_seq_id, p_pick_up_cust_seq_id, p_pick_up_cust_seq_id;
  END;

  -- AT1710 AT_SHIP_TRANS: AT_SHIP_TRANS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1710_w_at_ship_trans(b_at_invoice_line_shipmen_da18 IN VARCHAR2, p_shipment_nbr IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_hittman_nbr IN VARCHAR2, p_contract_nbr IN VARCHAR2, p_notes IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_SHIP_TRANS
 WHERE (
shipment_nbr = /*'000057'*/:w1
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN shipment_nbr LIKE :c4 THEN 1 END WHEN shipment_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR cntrct_seq_id = :c7)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN hittman_nbr LIKE :c11 THEN 1 END WHEN hittman_nbr = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN contract_nbr LIKE :c16 THEN 1 END WHEN contract_nbr = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN notes LIKE :c21 THEN 1 END WHEN notes = :c22 THEN 1 END) = 1)
) WHERE ROWNUM <= 5000~'
      USING b_at_invoice_line_shipmen_da18, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_cntrct_seq_id, p_cntrct_seq_id, p_hittman_nbr, p_hittman_nbr, p_hittman_nbr, p_hittman_nbr, p_hittman_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_notes, p_notes, p_notes, p_notes, p_notes;
  END;

  -- AT1710 PREV_INV: AT_INVOICE_LINE_CNTNR with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1710_w_prev_inv(b_at$ctrl_prev_cntnr_seq IN NUMBER, b_at$ctrl_advnotif_seq_id IN NUMBER, p_invc_seq_id IN NUMBER, p_invlitm_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_anchor_wgt IN NUMBER, p_inv_wgt IN NUMBER, p_advnotif_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_INVOICE_LINE_CNTNR
 WHERE (
CNTNR_SEQ_ID = NVL(:w1,0)
and advnotif_seq_id = :w2
)
   AND (:c1 IS NULL OR invc_seq_id = :c2)
   AND (:c3 IS NULL OR invlitm_seq_id = :c4)
   AND (:c5 IS NULL OR cntnr_seq_id = :c6)
   AND (:c7 IS NULL OR anchor_wgt = :c8)
   AND (:c9 IS NULL OR inv_wgt = :c10)
   AND (:c11 IS NULL OR advnotif_seq_id = :c12)
 ORDER BY INVC_SEQ_ID
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_prev_cntnr_seq, b_at$ctrl_advnotif_seq_id, p_invc_seq_id, p_invc_seq_id, p_invlitm_seq_id, p_invlitm_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_anchor_wgt, p_anchor_wgt, p_inv_wgt, p_inv_wgt, p_advnotif_seq_id, p_advnotif_seq_id;
  END;

  -- AT1710 SRC: AT_OPPORTUNITIES_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1710_w_src(b_inv_charge_to_cust_seq_id IN NUMBER, b_wksht_prodserv_cd IN VARCHAR2, b_wksht_disp_site_alias IN VARCHAR2, b_wksht_advnotif_seq_id IN NUMBER, p_invoppty_seq_id IN NUMBER, p_contract_nbr IN VARCHAR2, p_manifest_nbr IN VARCHAR2, p_qty IN NUMBER, p_container_id IN VARCHAR2, p_invoppty_description IN VARCHAR2, p_prodserv_cd IN VARCHAR2, p_disp_site_alias IN VARCHAR2, p_disp_site_code IN VARCHAR2, p_description IN VARCHAR2, p_advnotif_seq_id IN NUMBER, p_cost IN NUMBER, p_invoiced_ind IN VARCHAR2, p_ordered_qty IN NUMBER, p_segordlitm_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_OPPORTUNITIES_VIEW
 WHERE (
  AT_OPPORTUNITIES_VIEW.CUST_SEQ_ID = :w1 and
AT_OPPORTUNITIES_VIEW.PRODSERV_CD = :w2 and
NVL(AT_OPPORTUNITIES_VIEW.DISP_SITE_ALIAS,' ') = nvl(:w3,' ') and
AT_OPPORTUNITIES_VIEW.ADVNOTIF_SEQ_ID = :w4 and
AT_OPPORTUNITIES_VIEW.INVOICED_IND = 'N'

)
   AND (:c1 IS NULL OR invoppty_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN contract_nbr LIKE :c6 THEN 1 END WHEN contract_nbr = :c7 THEN 1 END) = 1)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN manifest_nbr LIKE :c11 THEN 1 END WHEN manifest_nbr = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR qty = :c14)
   AND (:c15 IS NULL OR (CASE WHEN INSTR(:c16, '%') + INSTR(:c17, '_') > 0 THEN CASE WHEN container_id LIKE :c18 THEN 1 END WHEN container_id = :c19 THEN 1 END) = 1)
   AND (:c20 IS NULL OR (CASE WHEN INSTR(:c21, '%') + INSTR(:c22, '_') > 0 THEN CASE WHEN invoppty_description LIKE :c23 THEN 1 END WHEN invoppty_description = :c24 THEN 1 END) = 1)
   AND (:c25 IS NULL OR (CASE WHEN INSTR(:c26, '%') + INSTR(:c27, '_') > 0 THEN CASE WHEN prodserv_cd LIKE :c28 THEN 1 END WHEN prodserv_cd = :c29 THEN 1 END) = 1)
   AND (:c30 IS NULL OR (CASE WHEN INSTR(:c31, '%') + INSTR(:c32, '_') > 0 THEN CASE WHEN disp_site_alias LIKE :c33 THEN 1 END WHEN disp_site_alias = :c34 THEN 1 END) = 1)
   AND (:c35 IS NULL OR (CASE WHEN INSTR(:c36, '%') + INSTR(:c37, '_') > 0 THEN CASE WHEN disp_site_code LIKE :c38 THEN 1 END WHEN disp_site_code = :c39 THEN 1 END) = 1)
   AND (:c40 IS NULL OR (CASE WHEN INSTR(:c41, '%') + INSTR(:c42, '_') > 0 THEN CASE WHEN description LIKE :c43 THEN 1 END WHEN description = :c44 THEN 1 END) = 1)
   AND (:c45 IS NULL OR advnotif_seq_id = :c46)
   AND (:c47 IS NULL OR cost = :c48)
   AND (:c49 IS NULL OR (CASE WHEN INSTR(:c50, '%') + INSTR(:c51, '_') > 0 THEN CASE WHEN invoiced_ind LIKE :c52 THEN 1 END WHEN invoiced_ind = :c53 THEN 1 END) = 1)
   AND (:c54 IS NULL OR ordered_qty = :c55)
   AND (:c56 IS NULL OR segordlitm_seq_id = :c57)
   AND (:c58 IS NULL OR cust_seq_id = :c59)
 ORDER BY invoppty_seq_id
) WHERE ROWNUM <= 5000~'
      USING b_inv_charge_to_cust_seq_id, b_wksht_prodserv_cd, b_wksht_disp_site_alias, b_wksht_advnotif_seq_id, p_invoppty_seq_id, p_invoppty_seq_id, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_qty, p_qty, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_invoppty_description, p_invoppty_description, p_invoppty_description, p_invoppty_description, p_invoppty_description, p_prodserv_cd, p_prodserv_cd, p_prodserv_cd, p_prodserv_cd, p_prodserv_cd, p_disp_site_alias, p_disp_site_alias, p_disp_site_alias, p_disp_site_alias, p_disp_site_alias, p_disp_site_code, p_disp_site_code, p_disp_site_code, p_disp_site_code, p_disp_site_code, p_description, p_description, p_description, p_description, p_description, p_advnotif_seq_id, p_advnotif_seq_id, p_cost, p_cost, p_invoiced_ind, p_invoiced_ind, p_invoiced_ind, p_invoiced_ind, p_invoiced_ind, p_ordered_qty, p_ordered_qty, p_segordlitm_seq_id, p_segordlitm_seq_id, p_cust_seq_id, p_cust_seq_id;
  END;

  -- AT3110 AT_ESPROFILE_EPA: AT_ESPROFILE_EPA with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at3110_w_at_esprofile_epa(b_matl_matl_seq_id IN NUMBER, b_matl_cntnr_seq_id IN NUMBER, p_es_prof_seq_id IN NUMBER, p_haz_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM at_esprofile_epa pe
 WHERE (
NOT EXISTS (SELECT 1
            FROM   at_barcode_haz_waste_codes bhwc2
            WHERE  bhwc2.matl_seq_id = :w1
            AND    bhwc2.cntnr_seq_id = :w2
            AND    bhwc2.haz_seq_id = pe.haz_seq_id)
)
   AND (:c1 IS NULL OR es_prof_seq_id = :c2)
   AND (:c3 IS NULL OR haz_seq_id = :c4)
 ORDER BY (SELECT haz_waste_cd
 FROM   at_haz_waste_codes hwc2
 WHERE  hwc2.haz_seq_id = pe.haz_seq_id)
) WHERE ROWNUM <= 5000~'
      USING b_matl_matl_seq_id, b_matl_cntnr_seq_id, p_es_prof_seq_id, p_es_prof_seq_id, p_haz_seq_id, p_haz_seq_id;
  END;

  -- AT3110 AT_ESPROFILE_EPA_I: AT_ESPROFILE_EPA with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at3110_w_at_esprofile_epa_i(b_matl1_matl_seq_id IN NUMBER, b_matl1_cntnr_seq_id IN NUMBER, p_es_prof_seq_id IN NUMBER, p_haz_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM at_esprofile_epa pe
 WHERE (
NOT EXISTS (SELECT 1
            FROM   at_barcode_haz_waste_codes bhwc2
            WHERE  bhwc2.matl_seq_id = :w1
            AND    bhwc2.cntnr_seq_id = :w2
            AND    bhwc2.haz_seq_id = pe.haz_seq_id)
)
   AND (:c1 IS NULL OR es_prof_seq_id = :c2)
   AND (:c3 IS NULL OR haz_seq_id = :c4)
 ORDER BY (SELECT haz_waste_cd
 FROM   at_haz_waste_codes hwc2
 WHERE  hwc2.haz_seq_id = pe.haz_seq_id)
) WHERE ROWNUM <= 5000~'
      USING b_matl1_matl_seq_id, b_matl1_cntnr_seq_id, p_es_prof_seq_id, p_es_prof_seq_id, p_haz_seq_id, p_haz_seq_id;
  END;

  -- AT3110 CNTNR: AT_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at3110_w_cntnr(b_matl_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINERS
 WHERE (
CNTNR_SEQ_ID = :w1
)
   AND (:c1 IS NULL OR cntnr_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN container_id LIKE :c6 THEN 1 END WHEN container_id = :c7 THEN 1 END) = 1)
) WHERE ROWNUM <= 5000~'
      USING b_matl_cntnr_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id;
  END;

  -- AT3115 CNTNR: AT_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at3115_w_cntnr(b_parameter_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_disp_site_seq_id IN NUMBER, p_cntnr_stat_cd_id IN VARCHAR2, p_next_prctrantyp_seq_id IN NUMBER, p_cntnr_typ_seq_id IN NUMBER, p_disp_site_lock_ind IN VARCHAR2, p_exterior_dose_rate_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_agt_media_seq_id IN NUMBER, p_incinerator_factor_nbr IN NUMBER, p_anchor_wgt_source_cd IN VARCHAR2, p_anchor_wgt IN NUMBER, p_waste_vol IN NUMBER, p_waste_vol_unit_cd IN VARCHAR2, p_hazardous_cd IN VARCHAR2, p_notes IN VARCHAR2, p_source_ind IN VARCHAR2, p_source_manufacturer IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINERS
 WHERE (
cntnr_seq_id = :w1
)
   AND (:c1 IS NULL OR cntnr_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN container_id LIKE :c6 THEN 1 END WHEN container_id = :c7 THEN 1 END) = 1)
   AND (:c8 IS NULL OR disp_site_seq_id = :c9)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN cntnr_stat_cd_id LIKE :c13 THEN 1 END WHEN cntnr_stat_cd_id = :c14 THEN 1 END) = 1)
   AND (:c15 IS NULL OR next_prctrantyp_seq_id = :c16)
   AND (:c17 IS NULL OR cntnr_typ_seq_id = :c18)
   AND (:c19 IS NULL OR (CASE WHEN INSTR(:c20, '%') + INSTR(:c21, '_') > 0 THEN CASE WHEN disp_site_lock_ind LIKE :c22 THEN 1 END WHEN disp_site_lock_ind = :c23 THEN 1 END) = 1)
   AND (:c24 IS NULL OR exterior_dose_rate_amt = :c25)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN dose_unit_cd_id LIKE :c29 THEN 1 END WHEN dose_unit_cd_id = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR agt_media_seq_id = :c32)
   AND (:c33 IS NULL OR incinerator_factor_nbr = :c34)
   AND (:c35 IS NULL OR (CASE WHEN INSTR(:c36, '%') + INSTR(:c37, '_') > 0 THEN CASE WHEN anchor_wgt_source_cd LIKE :c38 THEN 1 END WHEN anchor_wgt_source_cd = :c39 THEN 1 END) = 1)
   AND (:c40 IS NULL OR anchor_wgt = :c41)
   AND (:c42 IS NULL OR waste_vol = :c43)
   AND (:c44 IS NULL OR (CASE WHEN INSTR(:c45, '%') + INSTR(:c46, '_') > 0 THEN CASE WHEN waste_vol_unit_cd LIKE :c47 THEN 1 END WHEN waste_vol_unit_cd = :c48 THEN 1 END) = 1)
   AND (:c49 IS NULL OR (CASE WHEN INSTR(:c50, '%') + INSTR(:c51, '_') > 0 THEN CASE WHEN hazardous_cd LIKE :c52 THEN 1 END WHEN hazardous_cd = :c53 THEN 1 END) = 1)
   AND (:c54 IS NULL OR (CASE WHEN INSTR(:c55, '%') + INSTR(:c56, '_') > 0 THEN CASE WHEN notes LIKE :c57 THEN 1 END WHEN notes = :c58 THEN 1 END) = 1)
   AND (:c59 IS NULL OR (CASE WHEN INSTR(:c60, '%') + INSTR(:c61, '_') > 0 THEN CASE WHEN source_ind LIKE :c62 THEN 1 END WHEN source_ind = :c63 THEN 1 END) = 1)
   AND (:c64 IS NULL OR (CASE WHEN INSTR(:c65, '%') + INSTR(:c66, '_') > 0 THEN CASE WHEN source_manufacturer LIKE :c67 THEN 1 END WHEN source_manufacturer = :c68 THEN 1 END) = 1)
) WHERE ROWNUM <= 5000~'
      USING b_parameter_cntnr_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_disp_site_seq_id, p_disp_site_seq_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_next_prctrantyp_seq_id, p_next_prctrantyp_seq_id, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id, p_disp_site_lock_ind, p_disp_site_lock_ind, p_disp_site_lock_ind, p_disp_site_lock_ind, p_disp_site_lock_ind, p_exterior_dose_rate_amt, p_exterior_dose_rate_amt, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_agt_media_seq_id, p_agt_media_seq_id, p_incinerator_factor_nbr, p_incinerator_factor_nbr, p_anchor_wgt_source_cd, p_anchor_wgt_source_cd, p_anchor_wgt_source_cd, p_anchor_wgt_source_cd, p_anchor_wgt_source_cd, p_anchor_wgt, p_anchor_wgt, p_waste_vol, p_waste_vol, p_waste_vol_unit_cd, p_waste_vol_unit_cd, p_waste_vol_unit_cd, p_waste_vol_unit_cd, p_waste_vol_unit_cd, p_hazardous_cd, p_hazardous_cd, p_hazardous_cd, p_hazardous_cd, p_hazardous_cd, p_notes, p_notes, p_notes, p_notes, p_notes, p_source_ind, p_source_ind, p_source_ind, p_source_ind, p_source_ind, p_source_manufacturer, p_source_manufacturer, p_source_manufacturer, p_source_manufacturer, p_source_manufacturer;
  END;

  -- AT4151 LINER_CREATE: AT_CONTAINER_PROCESSES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at4151_w_liner_create(p_batch_seq_id IN NUMBER, p_sealand_seq_id IN NUMBER, p_hic_seq_id IN NUMBER, p_liner_rtc_ind IN VARCHAR2, p_comment_txt IN VARCHAR2, p_liner_complete_ind IN VARCHAR2, p_filter_amt IN NUMBER, p_cntnr_proc_seq_id IN NUMBER, p_parent_daughter_type_cd IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_void_space_amt IN NUMBER, p_empty_wgt IN NUMBER, p_activity_pct IN NUMBER, p_difference_wgt IN NUMBER, p_full_wgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_innerpack_hgt IN NUMBER, p_void_difference_amt IN NUMBER, p_waste_wgt IN NUMBER, p_dose_rate_amt IN NUMBER, p_volume IN NUMBER, p_shift_cd IN VARCHAR2, p_anchor_wgt IN NUMBER, p_height IN NUMBER, p_locks_qty IN NUMBER, p_pre_sorted_ind IN VARCHAR2, p_assignment_method_cd IN VARCHAR2, p_incineration_factor_nbr IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_overpack_complete_ind IN VARCHAR2, p_overpack_full_ind IN VARCHAR2, p_highest_contact_amt IN NUMBER, p_average_contact_amt IN NUMBER, p_average_at_3ft_amt IN NUMBER, p_created_by_name IN VARCHAR2, p_modified_by_name IN VARCHAR2, p_slag_ind IN VARCHAR2, p_supervisor_seg_stf_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_hgt_unit_cd_id IN VARCHAR2, p_wgt_unit_cd_id IN VARCHAR2, p_vol_unit_cd_id IN VARCHAR2, p_parent_cntnr_seq_id IN NUMBER, p_pre_cmpctn_wgt_unit_cd_id IN VARCHAR2, p_byprodhdrs_seq_id IN NUMBER, p_db_trigger_ind IN VARCHAR2, p_part_cntnr_seq_id IN NUMBER, p_tclp_ind IN VARCHAR2, p_cntnr_proc_stat_cd_id IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_ash_volume IN NUMBER, p_ash_waste_wgt IN NUMBER, p_gross_wgt_ind IN VARCHAR2, p_compacted_ind IN VARCHAR2, p_innerpack_waste_vol IN NUMBER, p_ash_cntnr_seq_id IN NUMBER, p_original_vol IN NUMBER, p_original_wgt IN NUMBER, p_process_vol_pct IN NUMBER, p_non_processed_ind IN VARCHAR2, p_volume_processed IN NUMBER, p_wgt_processed IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINER_PROCESSES
 WHERE (
parent_daughter_type_cd = 'PARENT'  and instr(get_container_id(cntnr_seq_id),'-REM1') > 0
)
   AND (:c1 IS NULL OR batch_seq_id = :c2)
   AND (:c3 IS NULL OR sealand_seq_id = :c4)
   AND (:c5 IS NULL OR hic_seq_id = :c6)
   AND (:c7 IS NULL OR (CASE WHEN INSTR(:c8, '%') + INSTR(:c9, '_') > 0 THEN CASE WHEN liner_rtc_ind LIKE :c10 THEN 1 END WHEN liner_rtc_ind = :c11 THEN 1 END) = 1)
   AND (:c12 IS NULL OR (CASE WHEN INSTR(:c13, '%') + INSTR(:c14, '_') > 0 THEN CASE WHEN comment_txt LIKE :c15 THEN 1 END WHEN comment_txt = :c16 THEN 1 END) = 1)
   AND (:c17 IS NULL OR (CASE WHEN INSTR(:c18, '%') + INSTR(:c19, '_') > 0 THEN CASE WHEN liner_complete_ind LIKE :c20 THEN 1 END WHEN liner_complete_ind = :c21 THEN 1 END) = 1)
   AND (:c22 IS NULL OR filter_amt = :c23)
   AND (:c24 IS NULL OR cntnr_proc_seq_id = :c25)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN parent_daughter_type_cd LIKE :c29 THEN 1 END WHEN parent_daughter_type_cd = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR cntnr_seq_id = :c32)
   AND (:c33 IS NULL OR prctrantyp_seq_id = :c34)
   AND (:c35 IS NULL OR void_space_amt = :c36)
   AND (:c37 IS NULL OR empty_wgt = :c38)
   AND (:c39 IS NULL OR activity_pct = :c40)
   AND (:c41 IS NULL OR difference_wgt = :c42)
   AND (:c43 IS NULL OR full_wgt = :c44)
   AND (:c45 IS NULL OR innerpack_wgt = :c46)
   AND (:c47 IS NULL OR innerpack_hgt = :c48)
   AND (:c49 IS NULL OR void_difference_amt = :c50)
   AND (:c51 IS NULL OR waste_wgt = :c52)
   AND (:c53 IS NULL OR dose_rate_amt = :c54)
   AND (:c55 IS NULL OR volume = :c56)
   AND (:c57 IS NULL OR (CASE WHEN INSTR(:c58, '%') + INSTR(:c59, '_') > 0 THEN CASE WHEN shift_cd LIKE :c60 THEN 1 END WHEN shift_cd = :c61 THEN 1 END) = 1)
   AND (:c62 IS NULL OR anchor_wgt = :c63)
   AND (:c64 IS NULL OR height = :c65)
   AND (:c66 IS NULL OR locks_qty = :c67)
   AND (:c68 IS NULL OR (CASE WHEN INSTR(:c69, '%') + INSTR(:c70, '_') > 0 THEN CASE WHEN pre_sorted_ind LIKE :c71 THEN 1 END WHEN pre_sorted_ind = :c72 THEN 1 END) = 1)
   AND (:c73 IS NULL OR (CASE WHEN INSTR(:c74, '%') + INSTR(:c75, '_') > 0 THEN CASE WHEN assignment_method_cd LIKE :c76 THEN 1 END WHEN assignment_method_cd = :c77 THEN 1 END) = 1)
   AND (:c78 IS NULL OR incineration_factor_nbr = :c79)
   AND (:c80 IS NULL OR pre_compaction_wgt = :c81)
   AND (:c82 IS NULL OR (CASE WHEN INSTR(:c83, '%') + INSTR(:c84, '_') > 0 THEN CASE WHEN overpack_complete_ind LIKE :c85 THEN 1 END WHEN overpack_complete_ind = :c86 THEN 1 END) = 1)
   AND (:c87 IS NULL OR (CASE WHEN INSTR(:c88, '%') + INSTR(:c89, '_') > 0 THEN CASE WHEN overpack_full_ind LIKE :c90 THEN 1 END WHEN overpack_full_ind = :c91 THEN 1 END) = 1)
   AND (:c92 IS NULL OR highest_contact_amt = :c93)
   AND (:c94 IS NULL OR average_contact_amt = :c95)
   AND (:c96 IS NULL OR average_at_3ft_amt = :c97)
   AND (:c98 IS NULL OR (CASE WHEN INSTR(:c99, '%') + INSTR(:c100, '_') > 0 THEN CASE WHEN created_by_name LIKE :c101 THEN 1 END WHEN created_by_name = :c102 THEN 1 END) = 1)
   AND (:c103 IS NULL OR (CASE WHEN INSTR(:c104, '%') + INSTR(:c105, '_') > 0 THEN CASE WHEN modified_by_name LIKE :c106 THEN 1 END WHEN modified_by_name = :c107 THEN 1 END) = 1)
   AND (:c108 IS NULL OR (CASE WHEN INSTR(:c109, '%') + INSTR(:c110, '_') > 0 THEN CASE WHEN slag_ind LIKE :c111 THEN 1 END WHEN slag_ind = :c112 THEN 1 END) = 1)
   AND (:c113 IS NULL OR supervisor_seg_stf_seq_id = :c114)
   AND (:c115 IS NULL OR seg_stf_seq_id = :c116)
   AND (:c117 IS NULL OR (CASE WHEN INSTR(:c118, '%') + INSTR(:c119, '_') > 0 THEN CASE WHEN dose_unit_cd_id LIKE :c120 THEN 1 END WHEN dose_unit_cd_id = :c121 THEN 1 END) = 1)
   AND (:c122 IS NULL OR (CASE WHEN INSTR(:c123, '%') + INSTR(:c124, '_') > 0 THEN CASE WHEN hgt_unit_cd_id LIKE :c125 THEN 1 END WHEN hgt_unit_cd_id = :c126 THEN 1 END) = 1)
   AND (:c127 IS NULL OR (CASE WHEN INSTR(:c128, '%') + INSTR(:c129, '_') > 0 THEN CASE WHEN wgt_unit_cd_id LIKE :c130 THEN 1 END WHEN wgt_unit_cd_id = :c131 THEN 1 END) = 1)
   AND (:c132 IS NULL OR (CASE WHEN INSTR(:c133, '%') + INSTR(:c134, '_') > 0 THEN CASE WHEN vol_unit_cd_id LIKE :c135 THEN 1 END WHEN vol_unit_cd_id = :c136 THEN 1 END) = 1)
   AND (:c137 IS NULL OR parent_cntnr_seq_id = :c138)
   AND (:c139 IS NULL OR (CASE WHEN INSTR(:c140, '%') + INSTR(:c141, '_') > 0 THEN CASE WHEN pre_cmpctn_wgt_unit_cd_id LIKE :c142 THEN 1 END WHEN pre_cmpctn_wgt_unit_cd_id = :c143 THEN 1 END) = 1)
   AND (:c144 IS NULL OR byprodhdrs_seq_id = :c145)
   AND (:c146 IS NULL OR (CASE WHEN INSTR(:c147, '%') + INSTR(:c148, '_') > 0 THEN CASE WHEN db_trigger_ind LIKE :c149 THEN 1 END WHEN db_trigger_ind = :c150 THEN 1 END) = 1)
   AND (:c151 IS NULL OR part_cntnr_seq_id = :c152)
   AND (:c153 IS NULL OR (CASE WHEN INSTR(:c154, '%') + INSTR(:c155, '_') > 0 THEN CASE WHEN tclp_ind LIKE :c156 THEN 1 END WHEN tclp_ind = :c157 THEN 1 END) = 1)
   AND (:c158 IS NULL OR (CASE WHEN INSTR(:c159, '%') + INSTR(:c160, '_') > 0 THEN CASE WHEN cntnr_proc_stat_cd_id LIKE :c161 THEN 1 END WHEN cntnr_proc_stat_cd_id = :c162 THEN 1 END) = 1)
   AND (:c163 IS NULL OR qc_seg_stf_seq_id = :c164)
   AND (:c165 IS NULL OR ash_volume = :c166)
   AND (:c167 IS NULL OR ash_waste_wgt = :c168)
   AND (:c169 IS NULL OR (CASE WHEN INSTR(:c170, '%') + INSTR(:c171, '_') > 0 THEN CASE WHEN gross_wgt_ind LIKE :c172 THEN 1 END WHEN gross_wgt_ind = :c173 THEN 1 END) = 1)
   AND (:c174 IS NULL OR (CASE WHEN INSTR(:c175, '%') + INSTR(:c176, '_') > 0 THEN CASE WHEN compacted_ind LIKE :c177 THEN 1 END WHEN compacted_ind = :c178 THEN 1 END) = 1)
   AND (:c179 IS NULL OR innerpack_waste_vol = :c180)
   AND (:c181 IS NULL OR ash_cntnr_seq_id = :c182)
   AND (:c183 IS NULL OR original_vol = :c184)
   AND (:c185 IS NULL OR original_wgt = :c186)
   AND (:c187 IS NULL OR process_vol_pct = :c188)
   AND (:c189 IS NULL OR (CASE WHEN INSTR(:c190, '%') + INSTR(:c191, '_') > 0 THEN CASE WHEN non_processed_ind LIKE :c192 THEN 1 END WHEN non_processed_ind = :c193 THEN 1 END) = 1)
   AND (:c194 IS NULL OR volume_processed = :c195)
   AND (:c196 IS NULL OR wgt_processed = :c197)
) WHERE ROWNUM <= 5000~'
      USING p_batch_seq_id, p_batch_seq_id, p_sealand_seq_id, p_sealand_seq_id, p_hic_seq_id, p_hic_seq_id, p_liner_rtc_ind, p_liner_rtc_ind, p_liner_rtc_ind, p_liner_rtc_ind, p_liner_rtc_ind, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_liner_complete_ind, p_liner_complete_ind, p_liner_complete_ind, p_liner_complete_ind, p_liner_complete_ind, p_filter_amt, p_filter_amt, p_cntnr_proc_seq_id, p_cntnr_proc_seq_id, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_cntnr_seq_id, p_cntnr_seq_id, p_prctrantyp_seq_id, p_prctrantyp_seq_id, p_void_space_amt, p_void_space_amt, p_empty_wgt, p_empty_wgt, p_activity_pct, p_activity_pct, p_difference_wgt, p_difference_wgt, p_full_wgt, p_full_wgt, p_innerpack_wgt, p_innerpack_wgt, p_innerpack_hgt, p_innerpack_hgt, p_void_difference_amt, p_void_difference_amt, p_waste_wgt, p_waste_wgt, p_dose_rate_amt, p_dose_rate_amt, p_volume, p_volume, p_shift_cd, p_shift_cd, p_shift_cd, p_shift_cd, p_shift_cd, p_anchor_wgt, p_anchor_wgt, p_height, p_height, p_locks_qty, p_locks_qty, p_pre_sorted_ind, p_pre_sorted_ind, p_pre_sorted_ind, p_pre_sorted_ind, p_pre_sorted_ind, p_assignment_method_cd, p_assignment_method_cd, p_assignment_method_cd, p_assignment_method_cd, p_assignment_method_cd, p_incineration_factor_nbr, p_incineration_factor_nbr, p_pre_compaction_wgt, p_pre_compaction_wgt, p_overpack_complete_ind, p_overpack_complete_ind, p_overpack_complete_ind, p_overpack_complete_ind, p_overpack_complete_ind, p_overpack_full_ind, p_overpack_full_ind, p_overpack_full_ind, p_overpack_full_ind, p_overpack_full_ind, p_highest_contact_amt, p_highest_contact_amt, p_average_contact_amt, p_average_contact_amt, p_average_at_3ft_amt, p_average_at_3ft_amt, p_created_by_name, p_created_by_name, p_created_by_name, p_created_by_name, p_created_by_name, p_modified_by_name, p_modified_by_name, p_modified_by_name, p_modified_by_name, p_modified_by_name, p_slag_ind, p_slag_ind, p_slag_ind, p_slag_ind, p_slag_ind, p_supervisor_seg_stf_seq_id, p_supervisor_seg_stf_seq_id, p_seg_stf_seq_id, p_seg_stf_seq_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_hgt_unit_cd_id, p_hgt_unit_cd_id, p_hgt_unit_cd_id, p_hgt_unit_cd_id, p_hgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_parent_cntnr_seq_id, p_parent_cntnr_seq_id, p_pre_cmpctn_wgt_unit_cd_id, p_pre_cmpctn_wgt_unit_cd_id, p_pre_cmpctn_wgt_unit_cd_id, p_pre_cmpctn_wgt_unit_cd_id, p_pre_cmpctn_wgt_unit_cd_id, p_byprodhdrs_seq_id, p_byprodhdrs_seq_id, p_db_trigger_ind, p_db_trigger_ind, p_db_trigger_ind, p_db_trigger_ind, p_db_trigger_ind, p_part_cntnr_seq_id, p_part_cntnr_seq_id, p_tclp_ind, p_tclp_ind, p_tclp_ind, p_tclp_ind, p_tclp_ind, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_qc_seg_stf_seq_id, p_qc_seg_stf_seq_id, p_ash_volume, p_ash_volume, p_ash_waste_wgt, p_ash_waste_wgt, p_gross_wgt_ind, p_gross_wgt_ind, p_gross_wgt_ind, p_gross_wgt_ind, p_gross_wgt_ind, p_compacted_ind, p_compacted_ind, p_compacted_ind, p_compacted_ind, p_compacted_ind, p_innerpack_waste_vol, p_innerpack_waste_vol, p_ash_cntnr_seq_id, p_ash_cntnr_seq_id, p_original_vol, p_original_vol, p_original_wgt, p_original_wgt, p_process_vol_pct, p_process_vol_pct, p_non_processed_ind, p_non_processed_ind, p_non_processed_ind, p_non_processed_ind, p_non_processed_ind, p_volume_processed, p_volume_processed, p_wgt_processed, p_wgt_processed;
  END;

  -- AT4210 COMPACTION_MASTER: AT_COMPACTION_MASTERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at4210_w_compaction_master(p_cmpctn_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_COMPACTION_MASTERS
 WHERE (
ALL_PARENTS_EMPTY(CNTNR_SEQ_ID)='TRUE' AND PRCTRANTYP_SEQ_ID IN (select PRCTRANTYP_SEQ_ID FROM AT_PROCESS_TRANS_TYPES 
where PRCTRANTYP_CD_ID like '2%')
)
   AND (:c1 IS NULL OR cmpctn_seq_id = :c2)
   AND (:c3 IS NULL OR prctrantyp_seq_id = :c4)
   AND (:c5 IS NULL OR cntnr_seq_id = :c6)
   AND (:c7 IS NULL OR pre_compaction_wgt = :c8)
   AND (:c9 IS NULL OR (CASE WHEN INSTR(:c10, '%') + INSTR(:c11, '_') > 0 THEN CASE WHEN wgt_unit_cd_id LIKE :c12 THEN 1 END WHEN wgt_unit_cd_id = :c13 THEN 1 END) = 1)
   AND (:c14 IS NULL OR seg_stf_seq_id = :c15)
) WHERE ROWNUM <= 5000~'
      USING p_cmpctn_seq_id, p_cmpctn_seq_id, p_prctrantyp_seq_id, p_prctrantyp_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_pre_compaction_wgt, p_pre_compaction_wgt, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_seg_stf_seq_id, p_seg_stf_seq_id;
  END;

  -- AT4211 COMPACTION_MASTER: AT_SHIP_COMPACTION_MASTERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at4211_w_compaction_master(p_cmpctn_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_SHIP_COMPACTION_MASTERS
 WHERE (
ALL_PARENTS_EMPTY(CNTNR_SEQ_ID)='TRUE' AND PRCTRANTYP_SEQ_ID IN (select PRCTRANTYP_SEQ_ID FROM AT_PROCESS_TRANS_TYPES 
where PRCTRANTYP_CD_ID like '2%')
)
   AND (:c1 IS NULL OR cmpctn_seq_id = :c2)
   AND (:c3 IS NULL OR prctrantyp_seq_id = :c4)
   AND (:c5 IS NULL OR cntnr_seq_id = :c6)
   AND (:c7 IS NULL OR pre_compaction_wgt = :c8)
   AND (:c9 IS NULL OR (CASE WHEN INSTR(:c10, '%') + INSTR(:c11, '_') > 0 THEN CASE WHEN wgt_unit_cd_id LIKE :c12 THEN 1 END WHEN wgt_unit_cd_id = :c13 THEN 1 END) = 1)
   AND (:c14 IS NULL OR seg_stf_seq_id = :c15)
) WHERE ROWNUM <= 5000~'
      USING p_cmpctn_seq_id, p_cmpctn_seq_id, p_prctrantyp_seq_id, p_prctrantyp_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_pre_compaction_wgt, p_pre_compaction_wgt, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_seg_stf_seq_id, p_seg_stf_seq_id;
  END;

  -- AT4215 COMPACTION_MASTER: AT_COMPACTION_MASTERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at4215_w_compaction_master(p_cmpctn_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_COMPACTION_MASTERS
 WHERE (
ALL_PARENTS_EMPTY(CNTNR_SEQ_ID)='TRUE' AND PRCTRANTYP_SEQ_ID IN (select PRCTRANTYP_SEQ_ID FROM AT_PROCESS_TRANS_TYPES 
where PRCTRANTYP_CD_ID like '2%')
)
   AND (:c1 IS NULL OR cmpctn_seq_id = :c2)
   AND (:c3 IS NULL OR cntnr_seq_id = :c4)
   AND (:c5 IS NULL OR pre_compaction_wgt = :c6)
) WHERE ROWNUM <= 5000~'
      USING p_cmpctn_seq_id, p_cmpctn_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_pre_compaction_wgt, p_pre_compaction_wgt;
  END;

  -- AT4220 COMPACTION_MASTERS: AT_COMPACTION_MASTERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at4220_w_compaction_masters(p_cmpctn_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_innerpack_hgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_COMPACTION_MASTERS
 WHERE (
not exists (select 'x' from at_process_trans_types c where c.prctrantyp_seq_id = at_compaction_masters.prctrantyp_seq_id connect by prior c.prctrantyp_seq_id = c.within_prctrantyp_seq_id start with c.prctrantyp_seq_id = (select prctrantyp_seq_id from at_incinerate_process_view))
)
   AND (:c1 IS NULL OR cmpctn_seq_id = :c2)
   AND (:c3 IS NULL OR prctrantyp_seq_id = :c4)
   AND (:c5 IS NULL OR cntnr_seq_id = :c6)
   AND (:c7 IS NULL OR pre_compaction_wgt = :c8)
   AND (:c9 IS NULL OR (CASE WHEN INSTR(:c10, '%') + INSTR(:c11, '_') > 0 THEN CASE WHEN wgt_unit_cd_id LIKE :c12 THEN 1 END WHEN wgt_unit_cd_id = :c13 THEN 1 END) = 1)
   AND (:c14 IS NULL OR innerpack_hgt = :c15)
   AND (:c16 IS NULL OR innerpack_wgt = :c17)
   AND (:c18 IS NULL OR seg_stf_seq_id = :c19)
) WHERE ROWNUM <= 5000~'
      USING p_cmpctn_seq_id, p_cmpctn_seq_id, p_prctrantyp_seq_id, p_prctrantyp_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_pre_compaction_wgt, p_pre_compaction_wgt, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_innerpack_hgt, p_innerpack_hgt, p_innerpack_wgt, p_innerpack_wgt, p_seg_stf_seq_id, p_seg_stf_seq_id;
  END;

  -- AT4220 OVERPACK_MASTER: AT_OVERPACK_MASTERS_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at4220_w_overpack_master(p_ovrpack_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_parent_daughter_type_cd IN VARCHAR2, p_volume IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_waste_wgt IN NUMBER, p_void_space_amt IN NUMBER, p_container_total_height IN NUMBER, p_dose_rate_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_comment_txt IN VARCHAR2, p_wgt_unit_cd_id IN VARCHAR2, p_void_unit_cd_id IN VARCHAR2, p_shift_cd IN VARCHAR2, p_overpack_complete_ind IN VARCHAR2, p_difference_wgt IN NUMBER, p_void_difference_amt IN NUMBER, p_vol_unit_cd_id IN VARCHAR2, p_seg_stf_seq_id IN NUMBER, p_super_seg_stf_seq_id IN NUMBER, p_cntnr_proc_stat_cd_id IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_OVERPACK_MASTERS_VIEW
 WHERE (
nvl(compacted_ind,'Y') = 'Y' AND PARENT_DAUGHTER_TYPE_CD = 'PARENT'
)
   AND (:c1 IS NULL OR ovrpack_seq_id = :c2)
   AND (:c3 IS NULL OR prctrantyp_seq_id = :c4)
   AND (:c5 IS NULL OR cntnr_seq_id = :c6)
   AND (:c7 IS NULL OR (CASE WHEN INSTR(:c8, '%') + INSTR(:c9, '_') > 0 THEN CASE WHEN parent_daughter_type_cd LIKE :c10 THEN 1 END WHEN parent_daughter_type_cd = :c11 THEN 1 END) = 1)
   AND (:c12 IS NULL OR volume = :c13)
   AND (:c14 IS NULL OR empty_wgt = :c15)
   AND (:c16 IS NULL OR full_wgt = :c17)
   AND (:c18 IS NULL OR waste_wgt = :c19)
   AND (:c20 IS NULL OR void_space_amt = :c21)
   AND (:c22 IS NULL OR container_total_height = :c23)
   AND (:c24 IS NULL OR dose_rate_amt = :c25)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN dose_unit_cd_id LIKE :c29 THEN 1 END WHEN dose_unit_cd_id = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR (CASE WHEN INSTR(:c32, '%') + INSTR(:c33, '_') > 0 THEN CASE WHEN comment_txt LIKE :c34 THEN 1 END WHEN comment_txt = :c35 THEN 1 END) = 1)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN wgt_unit_cd_id LIKE :c39 THEN 1 END WHEN wgt_unit_cd_id = :c40 THEN 1 END) = 1)
   AND (:c41 IS NULL OR (CASE WHEN INSTR(:c42, '%') + INSTR(:c43, '_') > 0 THEN CASE WHEN void_unit_cd_id LIKE :c44 THEN 1 END WHEN void_unit_cd_id = :c45 THEN 1 END) = 1)
   AND (:c46 IS NULL OR (CASE WHEN INSTR(:c47, '%') + INSTR(:c48, '_') > 0 THEN CASE WHEN shift_cd LIKE :c49 THEN 1 END WHEN shift_cd = :c50 THEN 1 END) = 1)
   AND (:c51 IS NULL OR (CASE WHEN INSTR(:c52, '%') + INSTR(:c53, '_') > 0 THEN CASE WHEN overpack_complete_ind LIKE :c54 THEN 1 END WHEN overpack_complete_ind = :c55 THEN 1 END) = 1)
   AND (:c56 IS NULL OR difference_wgt = :c57)
   AND (:c58 IS NULL OR void_difference_amt = :c59)
   AND (:c60 IS NULL OR (CASE WHEN INSTR(:c61, '%') + INSTR(:c62, '_') > 0 THEN CASE WHEN vol_unit_cd_id LIKE :c63 THEN 1 END WHEN vol_unit_cd_id = :c64 THEN 1 END) = 1)
   AND (:c65 IS NULL OR seg_stf_seq_id = :c66)
   AND (:c67 IS NULL OR super_seg_stf_seq_id = :c68)
   AND (:c69 IS NULL OR (CASE WHEN INSTR(:c70, '%') + INSTR(:c71, '_') > 0 THEN CASE WHEN cntnr_proc_stat_cd_id LIKE :c72 THEN 1 END WHEN cntnr_proc_stat_cd_id = :c73 THEN 1 END) = 1)
   AND (:c74 IS NULL OR qc_seg_stf_seq_id = :c75)
 ORDER BY transaction_dt
) WHERE ROWNUM <= 5000~'
      USING p_ovrpack_seq_id, p_ovrpack_seq_id, p_prctrantyp_seq_id, p_prctrantyp_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_volume, p_volume, p_empty_wgt, p_empty_wgt, p_full_wgt, p_full_wgt, p_waste_wgt, p_waste_wgt, p_void_space_amt, p_void_space_amt, p_container_total_height, p_container_total_height, p_dose_rate_amt, p_dose_rate_amt, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_void_unit_cd_id, p_void_unit_cd_id, p_void_unit_cd_id, p_void_unit_cd_id, p_void_unit_cd_id, p_shift_cd, p_shift_cd, p_shift_cd, p_shift_cd, p_shift_cd, p_overpack_complete_ind, p_overpack_complete_ind, p_overpack_complete_ind, p_overpack_complete_ind, p_overpack_complete_ind, p_difference_wgt, p_difference_wgt, p_void_difference_amt, p_void_difference_amt, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_seg_stf_seq_id, p_seg_stf_seq_id, p_super_seg_stf_seq_id, p_super_seg_stf_seq_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_qc_seg_stf_seq_id, p_qc_seg_stf_seq_id;
  END;

  -- AT4225 COMPACTION_MASTERS: AT_SHIP_COMPACTION_MASTERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at4225_w_compaction_masters(p_cmpctn_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_innerpack_hgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_SHIP_COMPACTION_MASTERS
 WHERE (
not exists (select 'x' from at_process_trans_types c where c.prctrantyp_seq_id = at_ship_compaction_masters.prctrantyp_seq_id connect by prior c.prctrantyp_seq_id = c.within_prctrantyp_seq_id start with c.prctrantyp_seq_id = (select prctrantyp_seq_id from at_incinerate_process_view))
)
   AND (:c1 IS NULL OR cmpctn_seq_id = :c2)
   AND (:c3 IS NULL OR prctrantyp_seq_id = :c4)
   AND (:c5 IS NULL OR cntnr_seq_id = :c6)
   AND (:c7 IS NULL OR pre_compaction_wgt = :c8)
   AND (:c9 IS NULL OR (CASE WHEN INSTR(:c10, '%') + INSTR(:c11, '_') > 0 THEN CASE WHEN wgt_unit_cd_id LIKE :c12 THEN 1 END WHEN wgt_unit_cd_id = :c13 THEN 1 END) = 1)
   AND (:c14 IS NULL OR innerpack_hgt = :c15)
   AND (:c16 IS NULL OR innerpack_wgt = :c17)
   AND (:c18 IS NULL OR seg_stf_seq_id = :c19)
) WHERE ROWNUM <= 5000~'
      USING p_cmpctn_seq_id, p_cmpctn_seq_id, p_prctrantyp_seq_id, p_prctrantyp_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_pre_compaction_wgt, p_pre_compaction_wgt, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_innerpack_hgt, p_innerpack_hgt, p_innerpack_wgt, p_innerpack_wgt, p_seg_stf_seq_id, p_seg_stf_seq_id;
  END;

  -- AT4225 OVERPACK_MASTER: AT_OVERPACK_MASTERS_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at4225_w_overpack_master(p_ovrpack_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_parent_daughter_type_cd IN VARCHAR2, p_volume IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_waste_wgt IN NUMBER, p_void_space_amt IN NUMBER, p_container_total_height IN NUMBER, p_dose_rate_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_comment_txt IN VARCHAR2, p_wgt_unit_cd_id IN VARCHAR2, p_void_unit_cd_id IN VARCHAR2, p_shift_cd IN VARCHAR2, p_overpack_complete_ind IN VARCHAR2, p_difference_wgt IN NUMBER, p_void_difference_amt IN NUMBER, p_vol_unit_cd_id IN VARCHAR2, p_seg_stf_seq_id IN NUMBER, p_super_seg_stf_seq_id IN NUMBER, p_cntnr_proc_stat_cd_id IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_OVERPACK_MASTERS_VIEW
 WHERE (
nvl(compacted_ind,'Y') = 'Y' AND PARENT_DAUGHTER_TYPE_CD = 'PARENT'
)
   AND (:c1 IS NULL OR ovrpack_seq_id = :c2)
   AND (:c3 IS NULL OR prctrantyp_seq_id = :c4)
   AND (:c5 IS NULL OR cntnr_seq_id = :c6)
   AND (:c7 IS NULL OR (CASE WHEN INSTR(:c8, '%') + INSTR(:c9, '_') > 0 THEN CASE WHEN parent_daughter_type_cd LIKE :c10 THEN 1 END WHEN parent_daughter_type_cd = :c11 THEN 1 END) = 1)
   AND (:c12 IS NULL OR volume = :c13)
   AND (:c14 IS NULL OR empty_wgt = :c15)
   AND (:c16 IS NULL OR full_wgt = :c17)
   AND (:c18 IS NULL OR waste_wgt = :c19)
   AND (:c20 IS NULL OR void_space_amt = :c21)
   AND (:c22 IS NULL OR container_total_height = :c23)
   AND (:c24 IS NULL OR dose_rate_amt = :c25)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN dose_unit_cd_id LIKE :c29 THEN 1 END WHEN dose_unit_cd_id = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR (CASE WHEN INSTR(:c32, '%') + INSTR(:c33, '_') > 0 THEN CASE WHEN comment_txt LIKE :c34 THEN 1 END WHEN comment_txt = :c35 THEN 1 END) = 1)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN wgt_unit_cd_id LIKE :c39 THEN 1 END WHEN wgt_unit_cd_id = :c40 THEN 1 END) = 1)
   AND (:c41 IS NULL OR (CASE WHEN INSTR(:c42, '%') + INSTR(:c43, '_') > 0 THEN CASE WHEN void_unit_cd_id LIKE :c44 THEN 1 END WHEN void_unit_cd_id = :c45 THEN 1 END) = 1)
   AND (:c46 IS NULL OR (CASE WHEN INSTR(:c47, '%') + INSTR(:c48, '_') > 0 THEN CASE WHEN shift_cd LIKE :c49 THEN 1 END WHEN shift_cd = :c50 THEN 1 END) = 1)
   AND (:c51 IS NULL OR (CASE WHEN INSTR(:c52, '%') + INSTR(:c53, '_') > 0 THEN CASE WHEN overpack_complete_ind LIKE :c54 THEN 1 END WHEN overpack_complete_ind = :c55 THEN 1 END) = 1)
   AND (:c56 IS NULL OR difference_wgt = :c57)
   AND (:c58 IS NULL OR void_difference_amt = :c59)
   AND (:c60 IS NULL OR (CASE WHEN INSTR(:c61, '%') + INSTR(:c62, '_') > 0 THEN CASE WHEN vol_unit_cd_id LIKE :c63 THEN 1 END WHEN vol_unit_cd_id = :c64 THEN 1 END) = 1)
   AND (:c65 IS NULL OR seg_stf_seq_id = :c66)
   AND (:c67 IS NULL OR super_seg_stf_seq_id = :c68)
   AND (:c69 IS NULL OR (CASE WHEN INSTR(:c70, '%') + INSTR(:c71, '_') > 0 THEN CASE WHEN cntnr_proc_stat_cd_id LIKE :c72 THEN 1 END WHEN cntnr_proc_stat_cd_id = :c73 THEN 1 END) = 1)
   AND (:c74 IS NULL OR qc_seg_stf_seq_id = :c75)
 ORDER BY transaction_dt
) WHERE ROWNUM <= 5000~'
      USING p_ovrpack_seq_id, p_ovrpack_seq_id, p_prctrantyp_seq_id, p_prctrantyp_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_volume, p_volume, p_empty_wgt, p_empty_wgt, p_full_wgt, p_full_wgt, p_waste_wgt, p_waste_wgt, p_void_space_amt, p_void_space_amt, p_container_total_height, p_container_total_height, p_dose_rate_amt, p_dose_rate_amt, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_void_unit_cd_id, p_void_unit_cd_id, p_void_unit_cd_id, p_void_unit_cd_id, p_void_unit_cd_id, p_shift_cd, p_shift_cd, p_shift_cd, p_shift_cd, p_shift_cd, p_overpack_complete_ind, p_overpack_complete_ind, p_overpack_complete_ind, p_overpack_complete_ind, p_overpack_complete_ind, p_difference_wgt, p_difference_wgt, p_void_difference_amt, p_void_difference_amt, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_seg_stf_seq_id, p_seg_stf_seq_id, p_super_seg_stf_seq_id, p_super_seg_stf_seq_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_qc_seg_stf_seq_id, p_qc_seg_stf_seq_id;
  END;

  -- AT4230 CONTAINERS: AT_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at4230_w_containers(p_next_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_used_vol IN NUMBER, p_total_hgt IN NUMBER, p_gross_wgt_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINERS
 WHERE (
next_prctrantyp_seq_id in 
(select prctrantyp_seq_id
from at_process_trans_types
where prctrantyp_cd_id like '9%')
and cntnr_stat_cd_id='IN USE'
and cntnr_seq_id not in (select cntnr_seq_id 
from at_container_processes
where prctrantyp_seq_id = 790
and parent_daughter_type_cd = 'PARENT')
and cntnr_typ_seq_id not in (401,402,403)
)
   AND (:c1 IS NULL OR next_prctrantyp_seq_id = :c2)
   AND (:c3 IS NULL OR cntnr_seq_id = :c4)
   AND (:c5 IS NULL OR (CASE WHEN INSTR(:c6, '%') + INSTR(:c7, '_') > 0 THEN CASE WHEN wgt_unit_cd_id LIKE :c8 THEN 1 END WHEN wgt_unit_cd_id = :c9 THEN 1 END) = 1)
   AND (:c10 IS NULL OR used_vol = :c11)
   AND (:c12 IS NULL OR total_hgt = :c13)
   AND (:c14 IS NULL OR (CASE WHEN INSTR(:c15, '%') + INSTR(:c16, '_') > 0 THEN CASE WHEN gross_wgt_ind LIKE :c17 THEN 1 END WHEN gross_wgt_ind = :c18 THEN 1 END) = 1)
) WHERE ROWNUM <= 5000~'
      USING p_next_prctrantyp_seq_id, p_next_prctrantyp_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_used_vol, p_used_vol, p_total_hgt, p_total_hgt, p_gross_wgt_ind, p_gross_wgt_ind, p_gross_wgt_ind, p_gross_wgt_ind, p_gross_wgt_ind;
  END;

  -- AT4230 OVERPACK_MASTER: AT_OVERPACK_MASTERS_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at4230_w_overpack_master(p_ovrpack_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_parent_daughter_type_cd IN VARCHAR2, p_volume IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_waste_wgt IN NUMBER, p_void_space_amt IN NUMBER, p_dose_rate_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_comment_txt IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_void_unit_cd_id IN VARCHAR2, p_shift_cd IN VARCHAR2, p_overpack_complete_ind IN VARCHAR2, p_difference_wgt IN NUMBER, p_void_difference_amt IN NUMBER, p_vol_unit_cd_id IN VARCHAR2, p_super_seg_stf_seq_id IN NUMBER, p_cntnr_proc_stat_cd_id IN VARCHAR2, p_compacted_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_OVERPACK_MASTERS_VIEW
 WHERE (
NVL(COMPACTED_IND,'Y') = 'N'
)
   AND (:c1 IS NULL OR ovrpack_seq_id = :c2)
   AND (:c3 IS NULL OR prctrantyp_seq_id = :c4)
   AND (:c5 IS NULL OR cntnr_seq_id = :c6)
   AND (:c7 IS NULL OR (CASE WHEN INSTR(:c8, '%') + INSTR(:c9, '_') > 0 THEN CASE WHEN parent_daughter_type_cd LIKE :c10 THEN 1 END WHEN parent_daughter_type_cd = :c11 THEN 1 END) = 1)
   AND (:c12 IS NULL OR volume = :c13)
   AND (:c14 IS NULL OR empty_wgt = :c15)
   AND (:c16 IS NULL OR full_wgt = :c17)
   AND (:c18 IS NULL OR waste_wgt = :c19)
   AND (:c20 IS NULL OR void_space_amt = :c21)
   AND (:c22 IS NULL OR dose_rate_amt = :c23)
   AND (:c24 IS NULL OR (CASE WHEN INSTR(:c25, '%') + INSTR(:c26, '_') > 0 THEN CASE WHEN dose_unit_cd_id LIKE :c27 THEN 1 END WHEN dose_unit_cd_id = :c28 THEN 1 END) = 1)
   AND (:c29 IS NULL OR (CASE WHEN INSTR(:c30, '%') + INSTR(:c31, '_') > 0 THEN CASE WHEN comment_txt LIKE :c32 THEN 1 END WHEN comment_txt = :c33 THEN 1 END) = 1)
   AND (:c34 IS NULL OR qc_seg_stf_seq_id = :c35)
   AND (:c36 IS NULL OR seg_stf_seq_id = :c37)
   AND (:c38 IS NULL OR (CASE WHEN INSTR(:c39, '%') + INSTR(:c40, '_') > 0 THEN CASE WHEN wgt_unit_cd_id LIKE :c41 THEN 1 END WHEN wgt_unit_cd_id = :c42 THEN 1 END) = 1)
   AND (:c43 IS NULL OR (CASE WHEN INSTR(:c44, '%') + INSTR(:c45, '_') > 0 THEN CASE WHEN void_unit_cd_id LIKE :c46 THEN 1 END WHEN void_unit_cd_id = :c47 THEN 1 END) = 1)
   AND (:c48 IS NULL OR (CASE WHEN INSTR(:c49, '%') + INSTR(:c50, '_') > 0 THEN CASE WHEN shift_cd LIKE :c51 THEN 1 END WHEN shift_cd = :c52 THEN 1 END) = 1)
   AND (:c53 IS NULL OR (CASE WHEN INSTR(:c54, '%') + INSTR(:c55, '_') > 0 THEN CASE WHEN overpack_complete_ind LIKE :c56 THEN 1 END WHEN overpack_complete_ind = :c57 THEN 1 END) = 1)
   AND (:c58 IS NULL OR difference_wgt = :c59)
   AND (:c60 IS NULL OR void_difference_amt = :c61)
   AND (:c62 IS NULL OR (CASE WHEN INSTR(:c63, '%') + INSTR(:c64, '_') > 0 THEN CASE WHEN vol_unit_cd_id LIKE :c65 THEN 1 END WHEN vol_unit_cd_id = :c66 THEN 1 END) = 1)
   AND (:c67 IS NULL OR super_seg_stf_seq_id = :c68)
   AND (:c69 IS NULL OR (CASE WHEN INSTR(:c70, '%') + INSTR(:c71, '_') > 0 THEN CASE WHEN cntnr_proc_stat_cd_id LIKE :c72 THEN 1 END WHEN cntnr_proc_stat_cd_id = :c73 THEN 1 END) = 1)
   AND (:c74 IS NULL OR (CASE WHEN INSTR(:c75, '%') + INSTR(:c76, '_') > 0 THEN CASE WHEN compacted_ind LIKE :c77 THEN 1 END WHEN compacted_ind = :c78 THEN 1 END) = 1)
 ORDER BY transaction_dt
) WHERE ROWNUM <= 5000~'
      USING p_ovrpack_seq_id, p_ovrpack_seq_id, p_prctrantyp_seq_id, p_prctrantyp_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_parent_daughter_type_cd, p_volume, p_volume, p_empty_wgt, p_empty_wgt, p_full_wgt, p_full_wgt, p_waste_wgt, p_waste_wgt, p_void_space_amt, p_void_space_amt, p_dose_rate_amt, p_dose_rate_amt, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_qc_seg_stf_seq_id, p_qc_seg_stf_seq_id, p_seg_stf_seq_id, p_seg_stf_seq_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_void_unit_cd_id, p_void_unit_cd_id, p_void_unit_cd_id, p_void_unit_cd_id, p_void_unit_cd_id, p_shift_cd, p_shift_cd, p_shift_cd, p_shift_cd, p_shift_cd, p_overpack_complete_ind, p_overpack_complete_ind, p_overpack_complete_ind, p_overpack_complete_ind, p_overpack_complete_ind, p_difference_wgt, p_difference_wgt, p_void_difference_amt, p_void_difference_amt, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_super_seg_stf_seq_id, p_super_seg_stf_seq_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_cntnr_proc_stat_cd_id, p_compacted_ind, p_compacted_ind, p_compacted_ind, p_compacted_ind, p_compacted_ind;
  END;

  -- AT5160 CNTNR1: AT_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5160_w_cntnr1(p_container_id IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINERS
 WHERE (
AT_CONTAINERS.CNTNR_STAT_CD_ID IN ('AJ','WR','HOLD','TRU','RA','PERMIT',
'SITE CO-MINGLE','IN USE','ACTIVITY','LAB','EMPTY')
AND CNTNR_SEQ_ID NOT IN (SELECT CNTNR_SEQ_ID FROM AT_COMPACTION_MASTERS
WHERE AT_CONTAINERS.CNTNR_SEQ_ID=CNTNR_SEQ_ID)
/*
AND CNTNR_SEQ_ID NOT IN (SELECT CNTNR_SEQ_ID FROM AT_OVERPACK_MASTERS_VIEW
WHERE AT_CONTAINERS.CNTNR_SEQ_ID=CNTNR_SEQ_ID)
*/
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN container_id LIKE :c4 THEN 1 END WHEN container_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN cntnr_stat_cd_id LIKE :c9 THEN 1 END WHEN cntnr_stat_cd_id = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR cntnr_seq_id = :c12)
 ORDER BY CONTAINER_ID,CNTNR_STAT_CD_ID
) WHERE ROWNUM <= 5000~'
      USING p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_seq_id, p_cntnr_seq_id;
  END;

  -- AT5161 AT_SHIPMENTS: AT_SHIPMENTS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5161_w_at_shipments(p_shipment_nbr IN VARCHAR2, p_shipment_type_cd IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_SHIPMENTS
 WHERE (
received_dt is not null and shipment_nbr in 
(select shipment_nbr 
from at_incoming_manifests 
where advnotif_seq_id in 
(select advnotif_seq_id 
from at_materials 
where cntnr_seq_id in 
(select cntnr_seq_id 
from at_containers 
where cntnr_stat_cd_id = 'LAB')))
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN shipment_nbr LIKE :c4 THEN 1 END WHEN shipment_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN shipment_type_cd LIKE :c9 THEN 1 END WHEN shipment_type_cd = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR (CASE WHEN INSTR(:c12, '%') + INSTR(:c13, '_') > 0 THEN CASE WHEN shipment_id_nbr LIKE :c14 THEN 1 END WHEN shipment_id_nbr = :c15 THEN 1 END) = 1)
 ORDER BY received_dt desc
) WHERE ROWNUM <= 5000~'
      USING p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr;
  END;

  -- AT5161 CNTNR1: AT_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5161_w_cntnr1(b_at_shipments_shipment_nbr IN VARCHAR2, p_container_id IN VARCHAR2, p_notes IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINERS
 WHERE (
AT_CONTAINERS.CNTNR_STAT_CD_ID IN ('LAB')
AND AT_CONTAINERS.CNTNR_SEQ_ID IN 
    (SELECT CNTNR_SEQ_ID 
     FROM AT_MATERIALS
     WHERE ADVNOTIF_SEQ_ID IN 
        (SELECT ADVNOTIF_SEQ_ID 
         FROM AT_INCOMING_MANIFESTS 
         WHERE SHIPMENT_NBR = :w1
        )
    )
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN container_id LIKE :c4 THEN 1 END WHEN container_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN notes LIKE :c9 THEN 1 END WHEN notes = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR (CASE WHEN INSTR(:c12, '%') + INSTR(:c13, '_') > 0 THEN CASE WHEN cntnr_stat_cd_id LIKE :c14 THEN 1 END WHEN cntnr_stat_cd_id = :c15 THEN 1 END) = 1)
   AND (:c16 IS NULL OR cntnr_seq_id = :c17)
 ORDER BY CONTAINER_ID,CNTNR_STAT_CD_ID
) WHERE ROWNUM <= 5000~'
      USING b_at_shipments_shipment_nbr, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_notes, p_notes, p_notes, p_notes, p_notes, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_seq_id, p_cntnr_seq_id;
  END;

  -- AT5170 AT_CNTNR_LAB_RESULTS_VIEW: AT_CNTNR_LAB_RESULTS_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5170_w_at_cntnr_lab_res_b392(b_cntnr_cntnr_seq_id IN NUMBER, p_element_cd IN VARCHAR2, p_activity_amt IN NUMBER, p_activity_unit_cd_id IN VARCHAR2, p_container_id IN VARCHAR2, p_sample_id IN VARCHAR2, p_code IN VARCHAR2, p_pass_fail_ind IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_labtyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CNTNR_LAB_RESULTS_VIEW
 WHERE (
cntnr_seq_id = :w1 /*and
CODE = 'TCLP'*/
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN element_cd LIKE :c4 THEN 1 END WHEN element_cd = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR activity_amt = :c7)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN activity_unit_cd_id LIKE :c11 THEN 1 END WHEN activity_unit_cd_id = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN container_id LIKE :c16 THEN 1 END WHEN container_id = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN sample_id LIKE :c21 THEN 1 END WHEN sample_id = :c22 THEN 1 END) = 1)
   AND (:c23 IS NULL OR (CASE WHEN INSTR(:c24, '%') + INSTR(:c25, '_') > 0 THEN CASE WHEN code LIKE :c26 THEN 1 END WHEN code = :c27 THEN 1 END) = 1)
   AND (:c28 IS NULL OR (CASE WHEN INSTR(:c29, '%') + INSTR(:c30, '_') > 0 THEN CASE WHEN pass_fail_ind LIKE :c31 THEN 1 END WHEN pass_fail_ind = :c32 THEN 1 END) = 1)
   AND (:c33 IS NULL OR cntnr_seq_id = :c34)
   AND (:c35 IS NULL OR labtyp_seq_id = :c36)
) WHERE ROWNUM <= 5000~'
      USING b_cntnr_cntnr_seq_id, p_element_cd, p_element_cd, p_element_cd, p_element_cd, p_element_cd, p_activity_amt, p_activity_amt, p_activity_unit_cd_id, p_activity_unit_cd_id, p_activity_unit_cd_id, p_activity_unit_cd_id, p_activity_unit_cd_id, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_sample_id, p_sample_id, p_sample_id, p_sample_id, p_sample_id, p_code, p_code, p_code, p_code, p_code, p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_cntnr_seq_id, p_cntnr_seq_id, p_labtyp_seq_id, p_labtyp_seq_id;
  END;

  -- AT5170 CNTNR: AT_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5170_w_cntnr(b_cntnr_container_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_gross_wgt IN NUMBER, p_tare_wgt IN NUMBER, p_anchor_wgt IN NUMBER, p_used_vol IN NUMBER, p_void_space_amt IN NUMBER, p_description IN VARCHAR2, p_notes IN VARCHAR2, p_exterior_alpha_contam_amt IN NUMBER, p_exterior_bg_contam_amt IN NUMBER, p_exterior_contam_unit_cd_id IN VARCHAR2, p_exterior_dose_rate_amt IN NUMBER, p_exterior_dose_rate_1m_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_waste_class_cd IN VARCHAR2, p_waste_class_amt IN NUMBER, p_inc_waste_class_cd IN VARCHAR2, p_rebucket IN VARCHAR2, p_incinerator_box_nbr IN VARCHAR2, p_incinerator_factor_nbr IN NUMBER, p_density_pct IN NUMBER, p_transuranic_pct IN NUMBER, p_ra226_pct IN NUMBER, p_hazardous_cd IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_vol_unit_cd_id IN VARCHAR2, p_override_vol IN NUMBER, p_within_cntnr_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_next_prctrantyp_seq_id IN NUMBER, p_total_hgt IN NUMBER, p_used_hgt IN NUMBER, p_hgt_unit_cd_id IN VARCHAR2, p_agt_media_seq_id IN NUMBER, p_oowag_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINERS
 WHERE (
(:w1 IS NOT NULL AND NVL(TERMINAL_IND,'N') != 'Y')
)
   AND (:c1 IS NULL OR cntnr_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN container_id LIKE :c6 THEN 1 END WHEN container_id = :c7 THEN 1 END) = 1)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN cntnr_stat_cd_id LIKE :c11 THEN 1 END WHEN cntnr_stat_cd_id = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR gross_wgt = :c14)
   AND (:c15 IS NULL OR tare_wgt = :c16)
   AND (:c17 IS NULL OR anchor_wgt = :c18)
   AND (:c19 IS NULL OR used_vol = :c20)
   AND (:c21 IS NULL OR void_space_amt = :c22)
   AND (:c23 IS NULL OR (CASE WHEN INSTR(:c24, '%') + INSTR(:c25, '_') > 0 THEN CASE WHEN description LIKE :c26 THEN 1 END WHEN description = :c27 THEN 1 END) = 1)
   AND (:c28 IS NULL OR (CASE WHEN INSTR(:c29, '%') + INSTR(:c30, '_') > 0 THEN CASE WHEN notes LIKE :c31 THEN 1 END WHEN notes = :c32 THEN 1 END) = 1)
   AND (:c33 IS NULL OR exterior_alpha_contam_amt = :c34)
   AND (:c35 IS NULL OR exterior_bg_contam_amt = :c36)
   AND (:c37 IS NULL OR (CASE WHEN INSTR(:c38, '%') + INSTR(:c39, '_') > 0 THEN CASE WHEN exterior_contam_unit_cd_id LIKE :c40 THEN 1 END WHEN exterior_contam_unit_cd_id = :c41 THEN 1 END) = 1)
   AND (:c42 IS NULL OR exterior_dose_rate_amt = :c43)
   AND (:c44 IS NULL OR exterior_dose_rate_1m_amt = :c45)
   AND (:c46 IS NULL OR (CASE WHEN INSTR(:c47, '%') + INSTR(:c48, '_') > 0 THEN CASE WHEN dose_unit_cd_id LIKE :c49 THEN 1 END WHEN dose_unit_cd_id = :c50 THEN 1 END) = 1)
   AND (:c51 IS NULL OR (CASE WHEN INSTR(:c52, '%') + INSTR(:c53, '_') > 0 THEN CASE WHEN waste_class_cd LIKE :c54 THEN 1 END WHEN waste_class_cd = :c55 THEN 1 END) = 1)
   AND (:c56 IS NULL OR waste_class_amt = :c57)
   AND (:c58 IS NULL OR (CASE WHEN INSTR(:c59, '%') + INSTR(:c60, '_') > 0 THEN CASE WHEN inc_waste_class_cd LIKE :c61 THEN 1 END WHEN inc_waste_class_cd = :c62 THEN 1 END) = 1)
   AND (:c63 IS NULL OR (CASE WHEN INSTR(:c64, '%') + INSTR(:c65, '_') > 0 THEN CASE WHEN rebucket LIKE :c66 THEN 1 END WHEN rebucket = :c67 THEN 1 END) = 1)
   AND (:c68 IS NULL OR (CASE WHEN INSTR(:c69, '%') + INSTR(:c70, '_') > 0 THEN CASE WHEN incinerator_box_nbr LIKE :c71 THEN 1 END WHEN incinerator_box_nbr = :c72 THEN 1 END) = 1)
   AND (:c73 IS NULL OR incinerator_factor_nbr = :c74)
   AND (:c75 IS NULL OR density_pct = :c76)
   AND (:c77 IS NULL OR transuranic_pct = :c78)
   AND (:c79 IS NULL OR ra226_pct = :c80)
   AND (:c81 IS NULL OR (CASE WHEN INSTR(:c82, '%') + INSTR(:c83, '_') > 0 THEN CASE WHEN hazardous_cd LIKE :c84 THEN 1 END WHEN hazardous_cd = :c85 THEN 1 END) = 1)
   AND (:c86 IS NULL OR cntnr_typ_seq_id = :c87)
   AND (:c88 IS NULL OR (CASE WHEN INSTR(:c89, '%') + INSTR(:c90, '_') > 0 THEN CASE WHEN wgt_unit_cd_id LIKE :c91 THEN 1 END WHEN wgt_unit_cd_id = :c92 THEN 1 END) = 1)
   AND (:c93 IS NULL OR (CASE WHEN INSTR(:c94, '%') + INSTR(:c95, '_') > 0 THEN CASE WHEN vol_unit_cd_id LIKE :c96 THEN 1 END WHEN vol_unit_cd_id = :c97 THEN 1 END) = 1)
   AND (:c98 IS NULL OR override_vol = :c99)
   AND (:c100 IS NULL OR within_cntnr_seq_id = :c101)
   AND (:c102 IS NULL OR disp_site_seq_id = :c103)
   AND (:c104 IS NULL OR next_prctrantyp_seq_id = :c105)
   AND (:c106 IS NULL OR total_hgt = :c107)
   AND (:c108 IS NULL OR used_hgt = :c109)
   AND (:c110 IS NULL OR (CASE WHEN INSTR(:c111, '%') + INSTR(:c112, '_') > 0 THEN CASE WHEN hgt_unit_cd_id LIKE :c113 THEN 1 END WHEN hgt_unit_cd_id = :c114 THEN 1 END) = 1)
   AND (:c115 IS NULL OR agt_media_seq_id = :c116)
   AND (:c117 IS NULL OR (CASE WHEN INSTR(:c118, '%') + INSTR(:c119, '_') > 0 THEN CASE WHEN oowag_ind LIKE :c120 THEN 1 END WHEN oowag_ind = :c121 THEN 1 END) = 1)
) WHERE ROWNUM <= 5000~'
      USING b_cntnr_container_id, p_cntnr_seq_id, p_cntnr_seq_id, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_gross_wgt, p_gross_wgt, p_tare_wgt, p_tare_wgt, p_anchor_wgt, p_anchor_wgt, p_used_vol, p_used_vol, p_void_space_amt, p_void_space_amt, p_description, p_description, p_description, p_description, p_description, p_notes, p_notes, p_notes, p_notes, p_notes, p_exterior_alpha_contam_amt, p_exterior_alpha_contam_amt, p_exterior_bg_contam_amt, p_exterior_bg_contam_amt, p_exterior_contam_unit_cd_id, p_exterior_contam_unit_cd_id, p_exterior_contam_unit_cd_id, p_exterior_contam_unit_cd_id, p_exterior_contam_unit_cd_id, p_exterior_dose_rate_amt, p_exterior_dose_rate_amt, p_exterior_dose_rate_1m_amt, p_exterior_dose_rate_1m_amt, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_waste_class_cd, p_waste_class_cd, p_waste_class_cd, p_waste_class_cd, p_waste_class_cd, p_waste_class_amt, p_waste_class_amt, p_inc_waste_class_cd, p_inc_waste_class_cd, p_inc_waste_class_cd, p_inc_waste_class_cd, p_inc_waste_class_cd, p_rebucket, p_rebucket, p_rebucket, p_rebucket, p_rebucket, p_incinerator_box_nbr, p_incinerator_box_nbr, p_incinerator_box_nbr, p_incinerator_box_nbr, p_incinerator_box_nbr, p_incinerator_factor_nbr, p_incinerator_factor_nbr, p_density_pct, p_density_pct, p_transuranic_pct, p_transuranic_pct, p_ra226_pct, p_ra226_pct, p_hazardous_cd, p_hazardous_cd, p_hazardous_cd, p_hazardous_cd, p_hazardous_cd, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_override_vol, p_override_vol, p_within_cntnr_seq_id, p_within_cntnr_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_next_prctrantyp_seq_id, p_next_prctrantyp_seq_id, p_total_hgt, p_total_hgt, p_used_hgt, p_used_hgt, p_hgt_unit_cd_id, p_hgt_unit_cd_id, p_hgt_unit_cd_id, p_hgt_unit_cd_id, p_hgt_unit_cd_id, p_agt_media_seq_id, p_agt_media_seq_id, p_oowag_ind, p_oowag_ind, p_oowag_ind, p_oowag_ind, p_oowag_ind;
  END;

  -- AT5311 LABANLSMPL5: AT_LAB_ANALYSIS_SAMPLES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5311_w_labanlsmpl5(p_pass_fail_ind IN VARCHAR2, p_mnfststat_cd_id IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_labsample_seq_id IN NUMBER, p_labanlsmpl_seq_id IN NUMBER, p_labtyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_LAB_ANALYSIS_SAMPLES
 WHERE (
labtyp_seq_id =
(select labtyp_seq_id 
 from   at_lab_analysis_types
 where  code = 'GSPEC')
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN pass_fail_ind LIKE :c4 THEN 1 END WHEN pass_fail_ind = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN mnfststat_cd_id LIKE :c9 THEN 1 END WHEN mnfststat_cd_id = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR qc_seg_stf_seq_id = :c12)
   AND (:c13 IS NULL OR labsample_seq_id = :c14)
   AND (:c15 IS NULL OR labanlsmpl_seq_id = :c16)
   AND (:c17 IS NULL OR labtyp_seq_id = :c18)
) WHERE ROWNUM <= 5000~'
      USING p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_mnfststat_cd_id, p_mnfststat_cd_id, p_mnfststat_cd_id, p_mnfststat_cd_id, p_mnfststat_cd_id, p_qc_seg_stf_seq_id, p_qc_seg_stf_seq_id, p_labsample_seq_id, p_labsample_seq_id, p_labanlsmpl_seq_id, p_labanlsmpl_seq_id, p_labtyp_seq_id, p_labtyp_seq_id;
  END;

  -- AT5311 LABSAMPLE2: AT_LAB_SAMPLES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5311_w_labsample2(p_sample_id IN VARCHAR2, p_labsample_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_req_by_seg_stf_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_LAB_SAMPLES
 WHERE (
labsample_seq_id in (select distinct smpls.labsample_seq_id from at_lab_samples smpls, at_lab_analysis_samples smpl, at_lab_analysis_types typs where smpls.labsample_seq_id = smpl.labsample_seq_id and smpl.labtyp_seq_id = typs.labtyp_seq_id and typs.code = 'GSPEC')
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN sample_id LIKE :c4 THEN 1 END WHEN sample_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR labsample_seq_id = :c7)
   AND (:c8 IS NULL OR cntnr_seq_id = :c9)
   AND (:c10 IS NULL OR req_by_seg_stf_seq_id = :c11)
   AND (:c12 IS NULL OR seg_stf_seq_id = :c13)
) WHERE ROWNUM <= 5000~'
      USING p_sample_id, p_sample_id, p_sample_id, p_sample_id, p_sample_id, p_labsample_seq_id, p_labsample_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_req_by_seg_stf_seq_id, p_req_by_seg_stf_seq_id, p_seg_stf_seq_id, p_seg_stf_seq_id;
  END;

  -- AT5312 AT_ESPROFILE_SAMP_FREQ: AT_ESPROFILE_SAMP_FREQ with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5312_w_at_esprofile_sam_5d3f(b_labsample2_es_prof_seq_id IN NUMBER, p_esprofile_samp_freq_seq_id IN NUMBER, p_es_prof_seq_id IN NUMBER, p_site_seq_id IN NUMBER, p_shipment_nbr IN VARCHAR2, p_labsample_seq_id IN NUMBER, p_business_rule IN NUMBER, p_sample_type IN VARCHAR2, p_rule_type IN VARCHAR2, p_yd_marker IN NUMBER, p_create_user IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_ESPROFILE_SAMP_FREQ psf
 WHERE (
es_prof_seq_id = :w1
)
   AND (:c1 IS NULL OR esprofile_samp_freq_seq_id = :c2)
   AND (:c3 IS NULL OR es_prof_seq_id = :c4)
   AND (:c5 IS NULL OR site_seq_id = :c6)
   AND (:c7 IS NULL OR (CASE WHEN INSTR(:c8, '%') + INSTR(:c9, '_') > 0 THEN CASE WHEN shipment_nbr LIKE :c10 THEN 1 END WHEN shipment_nbr = :c11 THEN 1 END) = 1)
   AND (:c12 IS NULL OR labsample_seq_id = :c13)
   AND (:c14 IS NULL OR business_rule = :c15)
   AND (:c16 IS NULL OR (CASE WHEN INSTR(:c17, '%') + INSTR(:c18, '_') > 0 THEN CASE WHEN sample_type LIKE :c19 THEN 1 END WHEN sample_type = :c20 THEN 1 END) = 1)
   AND (:c21 IS NULL OR (CASE WHEN INSTR(:c22, '%') + INSTR(:c23, '_') > 0 THEN CASE WHEN rule_type LIKE :c24 THEN 1 END WHEN rule_type = :c25 THEN 1 END) = 1)
   AND (:c26 IS NULL OR yd_marker = :c27)
   AND (:c28 IS NULL OR (CASE WHEN INSTR(:c29, '%') + INSTR(:c30, '_') > 0 THEN CASE WHEN create_user LIKE :c31 THEN 1 END WHEN create_user = :c32 THEN 1 END) = 1)
 ORDER BY (SELECT ls2.clut_entry_nbr
  FROM   at_lab_samples ls2
  WHERE  ls2.shipment_nbr = psf.shipment_nbr) DESC
,business_rule
) WHERE ROWNUM <= 5000~'
      USING b_labsample2_es_prof_seq_id, p_esprofile_samp_freq_seq_id, p_esprofile_samp_freq_seq_id, p_es_prof_seq_id, p_es_prof_seq_id, p_site_seq_id, p_site_seq_id, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_labsample_seq_id, p_labsample_seq_id, p_business_rule, p_business_rule, p_sample_type, p_sample_type, p_sample_type, p_sample_type, p_sample_type, p_rule_type, p_rule_type, p_rule_type, p_rule_type, p_rule_type, p_yd_marker, p_yd_marker, p_create_user, p_create_user, p_create_user, p_create_user, p_create_user;
  END;

  -- AT5312 COMPOSITE: AT_LAB_SAMPLE_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5312_w_composite(b_labsample2_labsample_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_labsample_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_LAB_SAMPLE_CONTAINERS
 WHERE (
LABSAMPLE_SEQ_ID = :w1
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN container_id LIKE :c4 THEN 1 END WHEN container_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR cntnr_seq_id = :c7)
   AND (:c8 IS NULL OR labsample_seq_id = :c9)
 ORDER BY CONTAINER_ID
) WHERE ROWNUM <= 5000~'
      USING b_labsample2_labsample_seq_id, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_cntnr_seq_id, p_cntnr_seq_id, p_labsample_seq_id, p_labsample_seq_id;
  END;

  -- AT5316 LABANLSMPL5: AT_LAB_ANALYSIS_SAMPLES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5316_w_labanlsmpl5(p_pass_fail_ind IN VARCHAR2, p_mnfststat_cd_id IN VARCHAR2, p_adjust_reason_text IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_entry_seg_stf_seq_id IN NUMBER, p_labsample_seq_id IN NUMBER, p_labanlsmpl_seq_id IN NUMBER, p_labtyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_LAB_ANALYSIS_SAMPLES
 WHERE (
labtyp_seq_id =
(select labtyp_seq_id 
 from   at_lab_analysis_types
 where  code = 'NIA')
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN pass_fail_ind LIKE :c4 THEN 1 END WHEN pass_fail_ind = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN mnfststat_cd_id LIKE :c9 THEN 1 END WHEN mnfststat_cd_id = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR (CASE WHEN INSTR(:c12, '%') + INSTR(:c13, '_') > 0 THEN CASE WHEN adjust_reason_text LIKE :c14 THEN 1 END WHEN adjust_reason_text = :c15 THEN 1 END) = 1)
   AND (:c16 IS NULL OR qc_seg_stf_seq_id = :c17)
   AND (:c18 IS NULL OR entry_seg_stf_seq_id = :c19)
   AND (:c20 IS NULL OR labsample_seq_id = :c21)
   AND (:c22 IS NULL OR labanlsmpl_seq_id = :c23)
   AND (:c24 IS NULL OR labtyp_seq_id = :c25)
) WHERE ROWNUM <= 5000~'
      USING p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_mnfststat_cd_id, p_mnfststat_cd_id, p_mnfststat_cd_id, p_mnfststat_cd_id, p_mnfststat_cd_id, p_adjust_reason_text, p_adjust_reason_text, p_adjust_reason_text, p_adjust_reason_text, p_adjust_reason_text, p_qc_seg_stf_seq_id, p_qc_seg_stf_seq_id, p_entry_seg_stf_seq_id, p_entry_seg_stf_seq_id, p_labsample_seq_id, p_labsample_seq_id, p_labanlsmpl_seq_id, p_labanlsmpl_seq_id, p_labtyp_seq_id, p_labtyp_seq_id;
  END;

  -- AT5316 LABSAMPLE2: AT_LAB_SAMPLES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5316_w_labsample2(p_sample_id IN VARCHAR2, p_labsample_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_req_by_seg_stf_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_LAB_SAMPLES
 WHERE (
labsample_seq_id in (select distinct smpls.labsample_seq_id from at_lab_samples smpls, at_lab_analysis_samples smpl, at_lab_analysis_types typs where smpls.labsample_seq_id = smpl.labsample_seq_id and smpl.labtyp_seq_id = typs.labtyp_seq_id and nvl(typs.code,'NONE') = 'NIA')
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN sample_id LIKE :c4 THEN 1 END WHEN sample_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR labsample_seq_id = :c7)
   AND (:c8 IS NULL OR cntnr_seq_id = :c9)
   AND (:c10 IS NULL OR req_by_seg_stf_seq_id = :c11)
   AND (:c12 IS NULL OR seg_stf_seq_id = :c13)
) WHERE ROWNUM <= 5000~'
      USING p_sample_id, p_sample_id, p_sample_id, p_sample_id, p_sample_id, p_labsample_seq_id, p_labsample_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_req_by_seg_stf_seq_id, p_req_by_seg_stf_seq_id, p_seg_stf_seq_id, p_seg_stf_seq_id;
  END;

  -- AT5510 AT_OUTBOUND_SHIPMENTS: AT_OUTBOUND_SHIPMENTS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5510_w_at_outbound_shipments(p_outshipmt_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_shipment_nbr IN VARCHAR2, p_manifest_nbr IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_railcar_nbr IN VARCHAR2, p_epa_manifest_nbr IN VARCHAR2, p_es_prof_seq_id IN NUMBER, p_exclusive_use_ind IN VARCHAR2, p_cntnr_vol_ind IN VARCHAR2, p_cask_ind IN VARCHAR2, p_epa_regulated_waste_ind IN VARCHAR2, p_collector_ind IN VARCHAR2, p_processor_ind IN VARCHAR2, p_envirocare_cwf_ind IN VARCHAR2, p_qoc_cat2_ind IN VARCHAR2, p_electronic_541_ind IN VARCHAR2, p_electronic_542_ind IN VARCHAR2, p_electronic_add_notes_ind IN VARCHAR2, p_additional_notes IN VARCHAR2, p_shipment_status IN VARCHAR2, p_transport_permit_nbr IN VARCHAR2, p_generator_cd IN VARCHAR2, p_disp_purpose_cd IN VARCHAR2, p_disp_site_seq_id IN NUMBER, p_special_handling_instr IN VARCHAR2, p_shipper_seg_stf_seq_id IN NUMBER, p_man_addl_num_pgs IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_OUTBOUND_SHIPMENTS
 WHERE (
SHIPMENT_NBR IN (
SELECT SHIPMENT_NBR FROM AT_SHIPMENTS
WHERE SUBSTR(SHIPMENT_TYPE_CD,1,8) <> 'TRANSFER')
)
   AND (:c1 IS NULL OR outshipmt_seq_id = :c2)
   AND (:c3 IS NULL OR cust_seq_id = :c4)
   AND (:c5 IS NULL OR (CASE WHEN INSTR(:c6, '%') + INSTR(:c7, '_') > 0 THEN CASE WHEN shipment_nbr LIKE :c8 THEN 1 END WHEN shipment_nbr = :c9 THEN 1 END) = 1)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN manifest_nbr LIKE :c13 THEN 1 END WHEN manifest_nbr = :c14 THEN 1 END) = 1)
   AND (:c15 IS NULL OR (CASE WHEN INSTR(:c16, '%') + INSTR(:c17, '_') > 0 THEN CASE WHEN shipment_id_nbr LIKE :c18 THEN 1 END WHEN shipment_id_nbr = :c19 THEN 1 END) = 1)
   AND (:c20 IS NULL OR (CASE WHEN INSTR(:c21, '%') + INSTR(:c22, '_') > 0 THEN CASE WHEN railcar_nbr LIKE :c23 THEN 1 END WHEN railcar_nbr = :c24 THEN 1 END) = 1)
   AND (:c25 IS NULL OR (CASE WHEN INSTR(:c26, '%') + INSTR(:c27, '_') > 0 THEN CASE WHEN epa_manifest_nbr LIKE :c28 THEN 1 END WHEN epa_manifest_nbr = :c29 THEN 1 END) = 1)
   AND (:c30 IS NULL OR es_prof_seq_id = :c31)
   AND (:c32 IS NULL OR (CASE WHEN INSTR(:c33, '%') + INSTR(:c34, '_') > 0 THEN CASE WHEN exclusive_use_ind LIKE :c35 THEN 1 END WHEN exclusive_use_ind = :c36 THEN 1 END) = 1)
   AND (:c37 IS NULL OR (CASE WHEN INSTR(:c38, '%') + INSTR(:c39, '_') > 0 THEN CASE WHEN cntnr_vol_ind LIKE :c40 THEN 1 END WHEN cntnr_vol_ind = :c41 THEN 1 END) = 1)
   AND (:c42 IS NULL OR (CASE WHEN INSTR(:c43, '%') + INSTR(:c44, '_') > 0 THEN CASE WHEN cask_ind LIKE :c45 THEN 1 END WHEN cask_ind = :c46 THEN 1 END) = 1)
   AND (:c47 IS NULL OR (CASE WHEN INSTR(:c48, '%') + INSTR(:c49, '_') > 0 THEN CASE WHEN epa_regulated_waste_ind LIKE :c50 THEN 1 END WHEN epa_regulated_waste_ind = :c51 THEN 1 END) = 1)
   AND (:c52 IS NULL OR (CASE WHEN INSTR(:c53, '%') + INSTR(:c54, '_') > 0 THEN CASE WHEN collector_ind LIKE :c55 THEN 1 END WHEN collector_ind = :c56 THEN 1 END) = 1)
   AND (:c57 IS NULL OR (CASE WHEN INSTR(:c58, '%') + INSTR(:c59, '_') > 0 THEN CASE WHEN processor_ind LIKE :c60 THEN 1 END WHEN processor_ind = :c61 THEN 1 END) = 1)
   AND (:c62 IS NULL OR (CASE WHEN INSTR(:c63, '%') + INSTR(:c64, '_') > 0 THEN CASE WHEN envirocare_cwf_ind LIKE :c65 THEN 1 END WHEN envirocare_cwf_ind = :c66 THEN 1 END) = 1)
   AND (:c67 IS NULL OR (CASE WHEN INSTR(:c68, '%') + INSTR(:c69, '_') > 0 THEN CASE WHEN qoc_cat2_ind LIKE :c70 THEN 1 END WHEN qoc_cat2_ind = :c71 THEN 1 END) = 1)
   AND (:c72 IS NULL OR (CASE WHEN INSTR(:c73, '%') + INSTR(:c74, '_') > 0 THEN CASE WHEN electronic_541_ind LIKE :c75 THEN 1 END WHEN electronic_541_ind = :c76 THEN 1 END) = 1)
   AND (:c77 IS NULL OR (CASE WHEN INSTR(:c78, '%') + INSTR(:c79, '_') > 0 THEN CASE WHEN electronic_542_ind LIKE :c80 THEN 1 END WHEN electronic_542_ind = :c81 THEN 1 END) = 1)
   AND (:c82 IS NULL OR (CASE WHEN INSTR(:c83, '%') + INSTR(:c84, '_') > 0 THEN CASE WHEN electronic_add_notes_ind LIKE :c85 THEN 1 END WHEN electronic_add_notes_ind = :c86 THEN 1 END) = 1)
   AND (:c87 IS NULL OR (CASE WHEN INSTR(:c88, '%') + INSTR(:c89, '_') > 0 THEN CASE WHEN additional_notes LIKE :c90 THEN 1 END WHEN additional_notes = :c91 THEN 1 END) = 1)
   AND (:c92 IS NULL OR (CASE WHEN INSTR(:c93, '%') + INSTR(:c94, '_') > 0 THEN CASE WHEN shipment_status LIKE :c95 THEN 1 END WHEN shipment_status = :c96 THEN 1 END) = 1)
   AND (:c97 IS NULL OR (CASE WHEN INSTR(:c98, '%') + INSTR(:c99, '_') > 0 THEN CASE WHEN transport_permit_nbr LIKE :c100 THEN 1 END WHEN transport_permit_nbr = :c101 THEN 1 END) = 1)
   AND (:c102 IS NULL OR (CASE WHEN INSTR(:c103, '%') + INSTR(:c104, '_') > 0 THEN CASE WHEN generator_cd LIKE :c105 THEN 1 END WHEN generator_cd = :c106 THEN 1 END) = 1)
   AND (:c107 IS NULL OR (CASE WHEN INSTR(:c108, '%') + INSTR(:c109, '_') > 0 THEN CASE WHEN disp_purpose_cd LIKE :c110 THEN 1 END WHEN disp_purpose_cd = :c111 THEN 1 END) = 1)
   AND (:c112 IS NULL OR disp_site_seq_id = :c113)
   AND (:c114 IS NULL OR (CASE WHEN INSTR(:c115, '%') + INSTR(:c116, '_') > 0 THEN CASE WHEN special_handling_instr LIKE :c117 THEN 1 END WHEN special_handling_instr = :c118 THEN 1 END) = 1)
   AND (:c119 IS NULL OR shipper_seg_stf_seq_id = :c120)
   AND (:c121 IS NULL OR man_addl_num_pgs = :c122)
) WHERE ROWNUM <= 5000~'
      USING p_outshipmt_seq_id, p_outshipmt_seq_id, p_cust_seq_id, p_cust_seq_id, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_railcar_nbr, p_railcar_nbr, p_railcar_nbr, p_railcar_nbr, p_railcar_nbr, p_epa_manifest_nbr, p_epa_manifest_nbr, p_epa_manifest_nbr, p_epa_manifest_nbr, p_epa_manifest_nbr, p_es_prof_seq_id, p_es_prof_seq_id, p_exclusive_use_ind, p_exclusive_use_ind, p_exclusive_use_ind, p_exclusive_use_ind, p_exclusive_use_ind, p_cntnr_vol_ind, p_cntnr_vol_ind, p_cntnr_vol_ind, p_cntnr_vol_ind, p_cntnr_vol_ind, p_cask_ind, p_cask_ind, p_cask_ind, p_cask_ind, p_cask_ind, p_epa_regulated_waste_ind, p_epa_regulated_waste_ind, p_epa_regulated_waste_ind, p_epa_regulated_waste_ind, p_epa_regulated_waste_ind, p_collector_ind, p_collector_ind, p_collector_ind, p_collector_ind, p_collector_ind, p_processor_ind, p_processor_ind, p_processor_ind, p_processor_ind, p_processor_ind, p_envirocare_cwf_ind, p_envirocare_cwf_ind, p_envirocare_cwf_ind, p_envirocare_cwf_ind, p_envirocare_cwf_ind, p_qoc_cat2_ind, p_qoc_cat2_ind, p_qoc_cat2_ind, p_qoc_cat2_ind, p_qoc_cat2_ind, p_electronic_541_ind, p_electronic_541_ind, p_electronic_541_ind, p_electronic_541_ind, p_electronic_541_ind, p_electronic_542_ind, p_electronic_542_ind, p_electronic_542_ind, p_electronic_542_ind, p_electronic_542_ind, p_electronic_add_notes_ind, p_electronic_add_notes_ind, p_electronic_add_notes_ind, p_electronic_add_notes_ind, p_electronic_add_notes_ind, p_additional_notes, p_additional_notes, p_additional_notes, p_additional_notes, p_additional_notes, p_shipment_status, p_shipment_status, p_shipment_status, p_shipment_status, p_shipment_status, p_transport_permit_nbr, p_transport_permit_nbr, p_transport_permit_nbr, p_transport_permit_nbr, p_transport_permit_nbr, p_generator_cd, p_generator_cd, p_generator_cd, p_generator_cd, p_generator_cd, p_disp_purpose_cd, p_disp_purpose_cd, p_disp_purpose_cd, p_disp_purpose_cd, p_disp_purpose_cd, p_disp_site_seq_id, p_disp_site_seq_id, p_special_handling_instr, p_special_handling_instr, p_special_handling_instr, p_special_handling_instr, p_special_handling_instr, p_shipper_seg_stf_seq_id, p_shipper_seg_stf_seq_id, p_man_addl_num_pgs, p_man_addl_num_pgs;
  END;

  -- AT5511 OUTSHIPMT: AT_OUTBOUND_SHIPMENTS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5511_w_outshipmt(p_manifest_nbr IN VARCHAR2, p_shipment_nbr IN VARCHAR2, p_exclusive_use_ind IN VARCHAR2, p_shipment_status IN VARCHAR2, p_epa_regulated_waste_ind IN VARCHAR2, p_epa_manifest_nbr IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_transport_permit_nbr IN VARCHAR2, p_generator_cd IN VARCHAR2, p_collector_ind IN VARCHAR2, p_processor_ind IN VARCHAR2, p_outshipmt_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_shipper_seg_stf_seq_id IN NUMBER, p_cntnr_vol_ind IN VARCHAR2, p_additional_notes IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_OUTBOUND_SHIPMENTS
 WHERE (
SHIPMENT_NBR IN (
SELECT SHIPMENT_NBR FROM AT_SHIPMENTS
WHERE SUBSTR(SHIPMENT_TYPE_CD,1,8) = 'TRANSFER')
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN manifest_nbr LIKE :c4 THEN 1 END WHEN manifest_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN shipment_nbr LIKE :c9 THEN 1 END WHEN shipment_nbr = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR (CASE WHEN INSTR(:c12, '%') + INSTR(:c13, '_') > 0 THEN CASE WHEN exclusive_use_ind LIKE :c14 THEN 1 END WHEN exclusive_use_ind = :c15 THEN 1 END) = 1)
   AND (:c16 IS NULL OR (CASE WHEN INSTR(:c17, '%') + INSTR(:c18, '_') > 0 THEN CASE WHEN shipment_status LIKE :c19 THEN 1 END WHEN shipment_status = :c20 THEN 1 END) = 1)
   AND (:c21 IS NULL OR (CASE WHEN INSTR(:c22, '%') + INSTR(:c23, '_') > 0 THEN CASE WHEN epa_regulated_waste_ind LIKE :c24 THEN 1 END WHEN epa_regulated_waste_ind = :c25 THEN 1 END) = 1)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN epa_manifest_nbr LIKE :c29 THEN 1 END WHEN epa_manifest_nbr = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR (CASE WHEN INSTR(:c32, '%') + INSTR(:c33, '_') > 0 THEN CASE WHEN shipment_id_nbr LIKE :c34 THEN 1 END WHEN shipment_id_nbr = :c35 THEN 1 END) = 1)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN transport_permit_nbr LIKE :c39 THEN 1 END WHEN transport_permit_nbr = :c40 THEN 1 END) = 1)
   AND (:c41 IS NULL OR (CASE WHEN INSTR(:c42, '%') + INSTR(:c43, '_') > 0 THEN CASE WHEN generator_cd LIKE :c44 THEN 1 END WHEN generator_cd = :c45 THEN 1 END) = 1)
   AND (:c46 IS NULL OR (CASE WHEN INSTR(:c47, '%') + INSTR(:c48, '_') > 0 THEN CASE WHEN collector_ind LIKE :c49 THEN 1 END WHEN collector_ind = :c50 THEN 1 END) = 1)
   AND (:c51 IS NULL OR (CASE WHEN INSTR(:c52, '%') + INSTR(:c53, '_') > 0 THEN CASE WHEN processor_ind LIKE :c54 THEN 1 END WHEN processor_ind = :c55 THEN 1 END) = 1)
   AND (:c56 IS NULL OR outshipmt_seq_id = :c57)
   AND (:c58 IS NULL OR cust_seq_id = :c59)
   AND (:c60 IS NULL OR disp_site_seq_id = :c61)
   AND (:c62 IS NULL OR shipper_seg_stf_seq_id = :c63)
   AND (:c64 IS NULL OR (CASE WHEN INSTR(:c65, '%') + INSTR(:c66, '_') > 0 THEN CASE WHEN cntnr_vol_ind LIKE :c67 THEN 1 END WHEN cntnr_vol_ind = :c68 THEN 1 END) = 1)
   AND (:c69 IS NULL OR (CASE WHEN INSTR(:c70, '%') + INSTR(:c71, '_') > 0 THEN CASE WHEN additional_notes LIKE :c72 THEN 1 END WHEN additional_notes = :c73 THEN 1 END) = 1)
) WHERE ROWNUM <= 5000~'
      USING p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_exclusive_use_ind, p_exclusive_use_ind, p_exclusive_use_ind, p_exclusive_use_ind, p_exclusive_use_ind, p_shipment_status, p_shipment_status, p_shipment_status, p_shipment_status, p_shipment_status, p_epa_regulated_waste_ind, p_epa_regulated_waste_ind, p_epa_regulated_waste_ind, p_epa_regulated_waste_ind, p_epa_regulated_waste_ind, p_epa_manifest_nbr, p_epa_manifest_nbr, p_epa_manifest_nbr, p_epa_manifest_nbr, p_epa_manifest_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_transport_permit_nbr, p_transport_permit_nbr, p_transport_permit_nbr, p_transport_permit_nbr, p_transport_permit_nbr, p_generator_cd, p_generator_cd, p_generator_cd, p_generator_cd, p_generator_cd, p_collector_ind, p_collector_ind, p_collector_ind, p_collector_ind, p_collector_ind, p_processor_ind, p_processor_ind, p_processor_ind, p_processor_ind, p_processor_ind, p_outshipmt_seq_id, p_outshipmt_seq_id, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_shipper_seg_stf_seq_id, p_shipper_seg_stf_seq_id, p_cntnr_vol_ind, p_cntnr_vol_ind, p_cntnr_vol_ind, p_cntnr_vol_ind, p_cntnr_vol_ind, p_additional_notes, p_additional_notes, p_additional_notes, p_additional_notes, p_additional_notes;
  END;

  -- AT5514 OUTCNTNR: AT_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5514_w_outcntnr(b_landfill_headers_begin__b633 IN NUMBER, p_used_vol IN NUMBER, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINERS
 WHERE (
NVL(terminal_process_ind,'N') = 'Y' and get_current_location_seq(cntnr_seq_id) = :w1
)
   AND (:c1 IS NULL OR used_vol = :c2)
   AND (:c3 IS NULL OR cntnr_seq_id = :c4)
 ORDER BY cntnr_seq_id asc
) WHERE ROWNUM <= 5000~'
      USING b_landfill_headers_begin__b633, p_used_vol, p_used_vol, p_cntnr_seq_id, p_cntnr_seq_id;
  END;

  -- AT5520 OUTSHIPMT: AT_OUTBOUND_SHIPMENTS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5520_w_outshipmt(p_outshipmt_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_shipment_nbr IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_OUTBOUND_SHIPMENTS
 WHERE (
shipment_nbr in (
select shipment_nbr
from at_shipments
where (to_char(shipment_dt,'RRRR') = to_char(sysdate,'RRRR')
    or to_char(shipment_dt,'RRRR') = to_char(sysdate-180,'RRRR')))
and disp_SITE_SEQ_ID IN (select disp_site_seq_id from at_disp_site_acks)
)
   AND (:c1 IS NULL OR outshipmt_seq_id = :c2)
   AND (:c3 IS NULL OR disp_site_seq_id = :c4)
   AND (:c5 IS NULL OR (CASE WHEN INSTR(:c6, '%') + INSTR(:c7, '_') > 0 THEN CASE WHEN shipment_nbr LIKE :c8 THEN 1 END WHEN shipment_nbr = :c9 THEN 1 END) = 1)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN shipment_id_nbr LIKE :c13 THEN 1 END WHEN shipment_id_nbr = :c14 THEN 1 END) = 1)
 ORDER BY SHIPMENT_NBR DESC
) WHERE ROWNUM <= 5000~'
      USING p_outshipmt_seq_id, p_outshipmt_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr;
  END;

  -- AT5521 OUTSHIPMT: AT_OUTBOUND_SHIPMENTS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5521_w_outshipmt(p_outshipmt_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_shipment_nbr IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_OUTBOUND_SHIPMENTS
 WHERE (
DISP_SITE_SEQ_ID = 2 and shipment_nbr in (select shipment_nbr from at_shipments where shipment_dt is not null)
)
   AND (:c1 IS NULL OR outshipmt_seq_id = :c2)
   AND (:c3 IS NULL OR disp_site_seq_id = :c4)
   AND (:c5 IS NULL OR (CASE WHEN INSTR(:c6, '%') + INSTR(:c7, '_') > 0 THEN CASE WHEN shipment_nbr LIKE :c8 THEN 1 END WHEN shipment_nbr = :c9 THEN 1 END) = 1)
 ORDER BY SHIPMENT_NBR DESC
) WHERE ROWNUM <= 5000~'
      USING p_outshipmt_seq_id, p_outshipmt_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr;
  END;

  -- AT9999 AT_CUST_DOC_TRACKED_ITEMS: AT_CUST_DOC_TRACKED_ITEMS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at9999_w_at_cust_doc_trac_c339(b_at$ctrl_cntnr_seq IN NUMBER, p_custtrck_seq_id IN NUMBER, p_trkditm_seq_id IN NUMBER, p_cust_provided_ind IN VARCHAR2, p_activity_amt IN NUMBER, p_total_activity_pct IN NUMBER, p_inc_activity_amt IN NUMBER, p_snm_amt IN NUMBER, p_inc_snm_amt IN NUMBER, p_inc_source_material_amt IN NUMBER, p_source_material_amt IN NUMBER, p_accum_ind IN VARCHAR2, p_cust_seq_id IN NUMBER, p_matl_seq_id IN NUMBER, p_byprodhdrs_seq_id IN NUMBER, p_snm_741_ind IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CUST_DOC_TRACKED_ITEMS
 WHERE (
cntnr_seq_id = :w1 
/*
and cust_provided_ind = 'Y'
*/
)
   AND (:c1 IS NULL OR custtrck_seq_id = :c2)
   AND (:c3 IS NULL OR trkditm_seq_id = :c4)
   AND (:c5 IS NULL OR (CASE WHEN INSTR(:c6, '%') + INSTR(:c7, '_') > 0 THEN CASE WHEN cust_provided_ind LIKE :c8 THEN 1 END WHEN cust_provided_ind = :c9 THEN 1 END) = 1)
   AND (:c10 IS NULL OR activity_amt = :c11)
   AND (:c12 IS NULL OR total_activity_pct = :c13)
   AND (:c14 IS NULL OR inc_activity_amt = :c15)
   AND (:c16 IS NULL OR snm_amt = :c17)
   AND (:c18 IS NULL OR inc_snm_amt = :c19)
   AND (:c20 IS NULL OR inc_source_material_amt = :c21)
   AND (:c22 IS NULL OR source_material_amt = :c23)
   AND (:c24 IS NULL OR (CASE WHEN INSTR(:c25, '%') + INSTR(:c26, '_') > 0 THEN CASE WHEN accum_ind LIKE :c27 THEN 1 END WHEN accum_ind = :c28 THEN 1 END) = 1)
   AND (:c29 IS NULL OR cust_seq_id = :c30)
   AND (:c31 IS NULL OR matl_seq_id = :c32)
   AND (:c33 IS NULL OR byprodhdrs_seq_id = :c34)
   AND (:c35 IS NULL OR (CASE WHEN INSTR(:c36, '%') + INSTR(:c37, '_') > 0 THEN CASE WHEN snm_741_ind LIKE :c38 THEN 1 END WHEN snm_741_ind = :c39 THEN 1 END) = 1)
   AND (:c40 IS NULL OR cntnr_seq_id = :c41)
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_cntnr_seq, p_custtrck_seq_id, p_custtrck_seq_id, p_trkditm_seq_id, p_trkditm_seq_id, p_cust_provided_ind, p_cust_provided_ind, p_cust_provided_ind, p_cust_provided_ind, p_cust_provided_ind, p_activity_amt, p_activity_amt, p_total_activity_pct, p_total_activity_pct, p_inc_activity_amt, p_inc_activity_amt, p_snm_amt, p_snm_amt, p_inc_snm_amt, p_inc_snm_amt, p_inc_source_material_amt, p_inc_source_material_amt, p_source_material_amt, p_source_material_amt, p_accum_ind, p_accum_ind, p_accum_ind, p_accum_ind, p_accum_ind, p_cust_seq_id, p_cust_seq_id, p_matl_seq_id, p_matl_seq_id, p_byprodhdrs_seq_id, p_byprodhdrs_seq_id, p_snm_741_ind, p_snm_741_ind, p_snm_741_ind, p_snm_741_ind, p_snm_741_ind, p_cntnr_seq_id, p_cntnr_seq_id;
  END;

  -- AT9999 AT_CUST_DOC_TRACKED_ITEMS_N: AT_CUST_DOC_TRACKED_ITEMS_N with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at9999_w_at_cust_doc_trac_5461(b_at$ctrl_cntnr_seq_n IN NUMBER, b_at$ctrl_matl_seq_n IN NUMBER, p_activity_amt IN NUMBER, p_snm_amt IN NUMBER, p_source_material_amt IN NUMBER, p_lld_activity_amt IN NUMBER, p_custtrck_seq_id IN NUMBER, p_trkditm_seq_id IN NUMBER, p_cust_provided_ind IN VARCHAR2, p_total_activity_pct IN NUMBER, p_inc_activity_amt IN NUMBER, p_inc_snm_amt IN NUMBER, p_inc_source_material_amt IN NUMBER, p_accum_ind IN VARCHAR2, p_cust_seq_id IN NUMBER, p_matl_seq_id IN NUMBER, p_byprodhdrs_seq_id IN NUMBER, p_snm_741_ind IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CUST_DOC_TRACKED_ITEMS_N
 WHERE (
cntnr_seq_id in (select cntnr_seq_id from at_container_processes where parent_cntnr_seq_id  = :w1) 
and cust_provided_ind = 'N'
and matl_seq_id = :w2
)
   AND (:c1 IS NULL OR activity_amt = :c2)
   AND (:c3 IS NULL OR snm_amt = :c4)
   AND (:c5 IS NULL OR source_material_amt = :c6)
   AND (:c7 IS NULL OR lld_activity_amt = :c8)
   AND (:c9 IS NULL OR custtrck_seq_id = :c10)
   AND (:c11 IS NULL OR trkditm_seq_id = :c12)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN cust_provided_ind LIKE :c16 THEN 1 END WHEN cust_provided_ind = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR total_activity_pct = :c19)
   AND (:c20 IS NULL OR inc_activity_amt = :c21)
   AND (:c22 IS NULL OR inc_snm_amt = :c23)
   AND (:c24 IS NULL OR inc_source_material_amt = :c25)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN accum_ind LIKE :c29 THEN 1 END WHEN accum_ind = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR cust_seq_id = :c32)
   AND (:c33 IS NULL OR matl_seq_id = :c34)
   AND (:c35 IS NULL OR byprodhdrs_seq_id = :c36)
   AND (:c37 IS NULL OR (CASE WHEN INSTR(:c38, '%') + INSTR(:c39, '_') > 0 THEN CASE WHEN snm_741_ind LIKE :c40 THEN 1 END WHEN snm_741_ind = :c41 THEN 1 END) = 1)
   AND (:c42 IS NULL OR cntnr_seq_id = :c43)
 ORDER BY cntnr_seq_id,get_nuclide(trkditm_seq_id) asc
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_cntnr_seq_n, b_at$ctrl_matl_seq_n, p_activity_amt, p_activity_amt, p_snm_amt, p_snm_amt, p_source_material_amt, p_source_material_amt, p_lld_activity_amt, p_lld_activity_amt, p_custtrck_seq_id, p_custtrck_seq_id, p_trkditm_seq_id, p_trkditm_seq_id, p_cust_provided_ind, p_cust_provided_ind, p_cust_provided_ind, p_cust_provided_ind, p_cust_provided_ind, p_total_activity_pct, p_total_activity_pct, p_inc_activity_amt, p_inc_activity_amt, p_inc_snm_amt, p_inc_snm_amt, p_inc_source_material_amt, p_inc_source_material_amt, p_accum_ind, p_accum_ind, p_accum_ind, p_accum_ind, p_accum_ind, p_cust_seq_id, p_cust_seq_id, p_matl_seq_id, p_matl_seq_id, p_byprodhdrs_seq_id, p_byprodhdrs_seq_id, p_snm_741_ind, p_snm_741_ind, p_snm_741_ind, p_snm_741_ind, p_snm_741_ind, p_cntnr_seq_id, p_cntnr_seq_id;
  END;

  -- AT9999 DAUGHTERS: AT_CONTAINER_PROCESSES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at9999_w_daughters(b_at_anchor_retro_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_anchor_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINER_PROCESSES
 WHERE (
PARENT_CNTNR_SEQ_ID =:w1
)
   AND (:c1 IS NULL OR cntnr_seq_id = :c2)
   AND (:c3 IS NULL OR anchor_wgt = :c4)
) WHERE ROWNUM <= 5000~'
      USING b_at_anchor_retro_cntnr_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_anchor_wgt, p_anchor_wgt;
  END;

  -- WB1000 SEGORDLITM: AT_SEG_ORDER_LINE_ITEMS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb1000_w_segordlitm(b_mnfst_advnotif_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_line_item_nbr IN NUMBER, p_status_cd IN VARCHAR2, p_segordlitm_seq_id IN NUMBER, p_cnprodserv_seq_id IN NUMBER, p_grp_cnprodserv_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_SEG_ORDER_LINE_ITEMS
 WHERE (
ADVNOTIF_SEQ_ID = :w1
)
   AND (:c1 IS NULL OR advnotif_seq_id = :c2)
   AND (:c3 IS NULL OR line_item_nbr = :c4)
   AND (:c5 IS NULL OR (CASE WHEN INSTR(:c6, '%') + INSTR(:c7, '_') > 0 THEN CASE WHEN status_cd LIKE :c8 THEN 1 END WHEN status_cd = :c9 THEN 1 END) = 1)
   AND (:c10 IS NULL OR segordlitm_seq_id = :c11)
   AND (:c12 IS NULL OR cnprodserv_seq_id = :c13)
   AND (:c14 IS NULL OR grp_cnprodserv_seq_id = :c15)
) WHERE ROWNUM <= 5000~'
      USING b_mnfst_advnotif_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_line_item_nbr, p_line_item_nbr, p_status_cd, p_status_cd, p_status_cd, p_status_cd, p_status_cd, p_segordlitm_seq_id, p_segordlitm_seq_id, p_cnprodserv_seq_id, p_cnprodserv_seq_id, p_grp_cnprodserv_seq_id, p_grp_cnprodserv_seq_id;
  END;

  -- WB1000 WB_CONT_NUC_VIEW: WB_CONT_NUC_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb1000_w_wb_cont_nuc_view(p_trkditm_cd IN VARCHAR2, p_trkditm_seq_id IN NUMBER, p_inc_man_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_CONT_NUC_VIEW
 WHERE (
trkditm_cd not in (select code from at_tracked_items)
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN trkditm_cd LIKE :c4 THEN 1 END WHEN trkditm_cd = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR trkditm_seq_id = :c7)
   AND (:c8 IS NULL OR inc_man_seq_id = :c9)
) WHERE ROWNUM <= 5000~'
      USING p_trkditm_cd, p_trkditm_cd, p_trkditm_cd, p_trkditm_cd, p_trkditm_cd, p_trkditm_seq_id, p_trkditm_seq_id, p_inc_man_seq_id, p_inc_man_seq_id;
  END;

  -- WB1100 DOUBLE_CONTAINMENT: WB_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb1100_w_double_containment(b_wb_incoming_manifests_a_0f8f IN NUMBER, p_incoming_barcode IN VARCHAR2, p_container_id IN VARCHAR2, p_gross_wgt IN NUMBER, p_tare_wgt IN NUMBER, p_used_vol IN NUMBER, p_cntnr_seq_id IN NUMBER, p_within_cntnr_seq_id IN NUMBER, p_next_prctrantyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_CONTAINERS
 WHERE (
CNTNR_SEQ_ID IN (SELECT CNTNR_SEQ_ID FROM WB_MATERIALS WHERE ADVNOTIF_SEQ_ID = :w1 AND PARENT_MATL_SEQ_ID IS NULL)
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN incoming_barcode LIKE :c4 THEN 1 END WHEN incoming_barcode = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN container_id LIKE :c9 THEN 1 END WHEN container_id = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR gross_wgt = :c12)
   AND (:c13 IS NULL OR tare_wgt = :c14)
   AND (:c15 IS NULL OR used_vol = :c16)
   AND (:c17 IS NULL OR cntnr_seq_id = :c18)
   AND (:c19 IS NULL OR within_cntnr_seq_id = :c20)
   AND (:c21 IS NULL OR next_prctrantyp_seq_id = :c22)
) WHERE ROWNUM <= 5000~'
      USING b_wb_incoming_manifests_a_0f8f, p_incoming_barcode, p_incoming_barcode, p_incoming_barcode, p_incoming_barcode, p_incoming_barcode, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_gross_wgt, p_gross_wgt, p_tare_wgt, p_tare_wgt, p_used_vol, p_used_vol, p_cntnr_seq_id, p_cntnr_seq_id, p_within_cntnr_seq_id, p_within_cntnr_seq_id, p_next_prctrantyp_seq_id, p_next_prctrantyp_seq_id;
  END;

  -- WB2002 AT_COMPACTION_MASTERS: AT_COMPACTION_MASTERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb2002_w_at_compaction_masters(p_cmpctn_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_innerpack_hgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_COMPACTION_MASTERS
 WHERE (
not exists (select 'x' from at_process_trans_types c where c.prctrantyp_seq_id = at_compaction_masters.prctrantyp_seq_id connect by prior c.prctrantyp_seq_id = c.within_prctrantyp_seq_id start with c.prctrantyp_seq_id = (select prctrantyp_seq_id from at_incinerate_process_view))
and NVL(hold_ind,'N') = 'N'
)
   AND (:c1 IS NULL OR cmpctn_seq_id = :c2)
   AND (:c3 IS NULL OR cntnr_seq_id = :c4)
   AND (:c5 IS NULL OR pre_compaction_wgt = :c6)
   AND (:c7 IS NULL OR innerpack_hgt = :c8)
   AND (:c9 IS NULL OR innerpack_wgt = :c10)
 ORDER BY CMPCTN_SEQ_ID
) WHERE ROWNUM <= 5000~'
      USING p_cmpctn_seq_id, p_cmpctn_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_pre_compaction_wgt, p_pre_compaction_wgt, p_innerpack_hgt, p_innerpack_hgt, p_innerpack_wgt, p_innerpack_wgt;
  END;

  -- WB2002 AT_COMPACTION_MASTERS2: AT_COMPACTION_MASTERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb2002_w_at_compaction_ma_f0a9(p_cntnr_seq_id IN NUMBER, p_innerpack_hgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_COMPACTION_MASTERS
 WHERE (
not exists (select 'x' from at_process_trans_types c where c.prctrantyp_seq_id = at_compaction_masters.prctrantyp_seq_id connect by prior c.prctrantyp_seq_id = c.within_prctrantyp_seq_id start with c.prctrantyp_seq_id = (select prctrantyp_seq_id from at_incinerate_process_view))
and NVL(hold_ind,'N') = 'Y'
)
   AND (:c1 IS NULL OR cntnr_seq_id = :c2)
   AND (:c3 IS NULL OR innerpack_hgt = :c4)
   AND (:c5 IS NULL OR innerpack_wgt = :c6)
) WHERE ROWNUM <= 5000~'
      USING p_cntnr_seq_id, p_cntnr_seq_id, p_innerpack_hgt, p_innerpack_hgt, p_innerpack_wgt, p_innerpack_wgt;
  END;

  -- WB2002 AT_CONTAINER_PROCESSES: AT_CONTAINER_PROCESSES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb2002_w_at_container_pro_2fad(b_at_overpacks_cntnr_seq_id IN NUMBER, p_parent_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_innerpack_wgt IN NUMBER, p_innerpack_hgt IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM at_container_processes
 WHERE (
PRCTRANTYP_SEQ_ID = 790 AND CNTNR_SEQ_ID IS NOT NULL AND PARENT_CNTNR_SEQ_ID = :w1
)
   AND (:c1 IS NULL OR parent_cntnr_seq_id = :c2)
   AND (:c3 IS NULL OR cntnr_seq_id = :c4)
   AND (:c5 IS NULL OR innerpack_wgt = :c6)
   AND (:c7 IS NULL OR innerpack_hgt = :c8)
   AND (:c9 IS NULL OR prctrantyp_seq_id = :c10)
 ORDER BY cntnr_proc_seq_id desc
) WHERE ROWNUM <= 5000~'
      USING b_at_overpacks_cntnr_seq_id, p_parent_cntnr_seq_id, p_parent_cntnr_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_innerpack_wgt, p_innerpack_wgt, p_innerpack_hgt, p_innerpack_hgt, p_prctrantyp_seq_id, p_prctrantyp_seq_id;
  END;

  -- WB2002 AT_OVERPACKS: AT_OVERPACKS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb2002_w_at_overpacks(p_cntnr_seq_id IN NUMBER, p_underfill_amt IN NUMBER, p_rank IN NUMBER, p_rad_greater_0_ind IN VARCHAR2, p_rad_greater_180_ind IN VARCHAR2, p_ash_ind IN VARCHAR2, p_rad_greater_500_ind IN VARCHAR2, p_baghouse_dust_ind IN VARCHAR2, p_fly_ash_ind IN VARCHAR2, p_rad_greater_1000_ind IN VARCHAR2, p_treated_ash_ind IN VARCHAR2, p_full_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_OVERPACKS
 WHERE (
rank > 0
and NVL(full_ind,'N') = 'N'
)
   AND (:c1 IS NULL OR cntnr_seq_id = :c2)
   AND (:c3 IS NULL OR underfill_amt = :c4)
   AND (:c5 IS NULL OR rank = :c6)
   AND (:c7 IS NULL OR (CASE WHEN INSTR(:c8, '%') + INSTR(:c9, '_') > 0 THEN CASE WHEN rad_greater_0_ind LIKE :c10 THEN 1 END WHEN rad_greater_0_ind = :c11 THEN 1 END) = 1)
   AND (:c12 IS NULL OR (CASE WHEN INSTR(:c13, '%') + INSTR(:c14, '_') > 0 THEN CASE WHEN rad_greater_180_ind LIKE :c15 THEN 1 END WHEN rad_greater_180_ind = :c16 THEN 1 END) = 1)
   AND (:c17 IS NULL OR (CASE WHEN INSTR(:c18, '%') + INSTR(:c19, '_') > 0 THEN CASE WHEN ash_ind LIKE :c20 THEN 1 END WHEN ash_ind = :c21 THEN 1 END) = 1)
   AND (:c22 IS NULL OR (CASE WHEN INSTR(:c23, '%') + INSTR(:c24, '_') > 0 THEN CASE WHEN rad_greater_500_ind LIKE :c25 THEN 1 END WHEN rad_greater_500_ind = :c26 THEN 1 END) = 1)
   AND (:c27 IS NULL OR (CASE WHEN INSTR(:c28, '%') + INSTR(:c29, '_') > 0 THEN CASE WHEN baghouse_dust_ind LIKE :c30 THEN 1 END WHEN baghouse_dust_ind = :c31 THEN 1 END) = 1)
   AND (:c32 IS NULL OR (CASE WHEN INSTR(:c33, '%') + INSTR(:c34, '_') > 0 THEN CASE WHEN fly_ash_ind LIKE :c35 THEN 1 END WHEN fly_ash_ind = :c36 THEN 1 END) = 1)
   AND (:c37 IS NULL OR (CASE WHEN INSTR(:c38, '%') + INSTR(:c39, '_') > 0 THEN CASE WHEN rad_greater_1000_ind LIKE :c40 THEN 1 END WHEN rad_greater_1000_ind = :c41 THEN 1 END) = 1)
   AND (:c42 IS NULL OR (CASE WHEN INSTR(:c43, '%') + INSTR(:c44, '_') > 0 THEN CASE WHEN treated_ash_ind LIKE :c45 THEN 1 END WHEN treated_ash_ind = :c46 THEN 1 END) = 1)
   AND (:c47 IS NULL OR (CASE WHEN INSTR(:c48, '%') + INSTR(:c49, '_') > 0 THEN CASE WHEN full_ind LIKE :c50 THEN 1 END WHEN full_ind = :c51 THEN 1 END) = 1)
 ORDER BY rank
) WHERE ROWNUM <= 5000~'
      USING p_cntnr_seq_id, p_cntnr_seq_id, p_underfill_amt, p_underfill_amt, p_rank, p_rank, p_rad_greater_0_ind, p_rad_greater_0_ind, p_rad_greater_0_ind, p_rad_greater_0_ind, p_rad_greater_0_ind, p_rad_greater_180_ind, p_rad_greater_180_ind, p_rad_greater_180_ind, p_rad_greater_180_ind, p_rad_greater_180_ind, p_ash_ind, p_ash_ind, p_ash_ind, p_ash_ind, p_ash_ind, p_rad_greater_500_ind, p_rad_greater_500_ind, p_rad_greater_500_ind, p_rad_greater_500_ind, p_rad_greater_500_ind, p_baghouse_dust_ind, p_baghouse_dust_ind, p_baghouse_dust_ind, p_baghouse_dust_ind, p_baghouse_dust_ind, p_fly_ash_ind, p_fly_ash_ind, p_fly_ash_ind, p_fly_ash_ind, p_fly_ash_ind, p_rad_greater_1000_ind, p_rad_greater_1000_ind, p_rad_greater_1000_ind, p_rad_greater_1000_ind, p_rad_greater_1000_ind, p_treated_ash_ind, p_treated_ash_ind, p_treated_ash_ind, p_treated_ash_ind, p_treated_ash_ind, p_full_ind, p_full_ind, p_full_ind, p_full_ind, p_full_ind;
  END;

  -- WB2003 AT_CONTAINER_PROCESSES: AT_CONTAINER_PROCESSES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb2003_w_at_container_pro_4055(b_op_cntnr_seq_id IN NUMBER, p_parent_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_innerpack_hgt IN NUMBER, p_volume IN NUMBER, p_innerpack_waste_vol IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM at_container_processes
 WHERE (
PRCTRANTYP_SEQ_ID = 790 AND CNTNR_SEQ_ID IS NOT NULL AND PARENT_CNTNR_SEQ_ID = :w1
)
   AND (:c1 IS NULL OR parent_cntnr_seq_id = :c2)
   AND (:c3 IS NULL OR cntnr_seq_id = :c4)
   AND (:c5 IS NULL OR pre_compaction_wgt = :c6)
   AND (:c7 IS NULL OR innerpack_wgt = :c8)
   AND (:c9 IS NULL OR innerpack_hgt = :c10)
   AND (:c11 IS NULL OR volume = :c12)
   AND (:c13 IS NULL OR innerpack_waste_vol = :c14)
   AND (:c15 IS NULL OR prctrantyp_seq_id = :c16)
) WHERE ROWNUM <= 5000~'
      USING b_op_cntnr_seq_id, p_parent_cntnr_seq_id, p_parent_cntnr_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_pre_compaction_wgt, p_pre_compaction_wgt, p_innerpack_wgt, p_innerpack_wgt, p_innerpack_hgt, p_innerpack_hgt, p_volume, p_volume, p_innerpack_waste_vol, p_innerpack_waste_vol, p_prctrantyp_seq_id, p_prctrantyp_seq_id;
  END;

  -- WB3000 SEARCH: the block's own FROM-clause query (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3000_q_search(p_parent_container_id IN VARCHAR2, p_daughter_barcode IN VARCHAR2, p_customer_nbr IN NUMBER, p_customer_name IN VARCHAR2, p_full_wt IN VARCHAR2, p_empty_wgt IN VARCHAR2, p_npc IN VARCHAR2, p_sort_dt IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM (
SELECT id.ibox_seq_id
       ,id.parent_container_id
       ,id.daughter_barcode
       ,(SELECT c2.customer_nbr
         FROM   at_incoming_manifests im2
               ,at_customers c2
         WHERE      im2.cust_seq_id = c2.cust_seq_id
                AND im2.advnotif_seq_id = id.advnotif_seq_id)
            customer_nbr
       ,(SELECT c2.name
         FROM   at_incoming_manifests im2
               ,at_customers c2
         WHERE      im2.cust_seq_id = c2.cust_seq_id
                AND im2.advnotif_seq_id = id.advnotif_seq_id)
            customer_name
       ,id.full_wt
       ,id.empty_wgt
       ,ptt.prctrantyp_cd_id
            npc
       ,id.sort_dt
       ,id.transaction_area_name
 FROM   wb_ibox_details id
       ,at_process_trans_types ptt
 WHERE      id.prctrantyp_seq_id = ptt.prctrantyp_seq_id(+)
        AND id.parent_daughter_type_cd = 'DAUGHTER'
        AND id.daughter_barcode <> id.parent_container_id
) q
 WHERE (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN q.parent_container_id LIKE :c4 THEN 1 END WHEN q.parent_container_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN q.daughter_barcode LIKE :c9 THEN 1 END WHEN q.daughter_barcode = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR q.customer_nbr = :c12)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN q.customer_name LIKE :c16 THEN 1 END WHEN q.customer_name = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN q.full_wt LIKE :c21 THEN 1 END WHEN q.full_wt = :c22 THEN 1 END) = 1)
   AND (:c23 IS NULL OR (CASE WHEN INSTR(:c24, '%') + INSTR(:c25, '_') > 0 THEN CASE WHEN q.empty_wgt LIKE :c26 THEN 1 END WHEN q.empty_wgt = :c27 THEN 1 END) = 1)
   AND (:c28 IS NULL OR (CASE WHEN INSTR(:c29, '%') + INSTR(:c30, '_') > 0 THEN CASE WHEN q.npc LIKE :c31 THEN 1 END WHEN q.npc = :c32 THEN 1 END) = 1)
   AND (:c33 IS NULL OR (CASE WHEN INSTR(:c34, '%') + INSTR(:c35, '_') > 0 THEN CASE WHEN q.sort_dt LIKE :c36 THEN 1 END WHEN q.sort_dt = :c37 THEN 1 END) = 1)
 ORDER BY sort_dt DESC, daughter_barcode DESC, parent_container_id DESC
) WHERE ROWNUM <= 5000~'
      USING p_parent_container_id, p_parent_container_id, p_parent_container_id, p_parent_container_id, p_parent_container_id, p_daughter_barcode, p_daughter_barcode, p_daughter_barcode, p_daughter_barcode, p_daughter_barcode, p_customer_nbr, p_customer_nbr, p_customer_name, p_customer_name, p_customer_name, p_customer_name, p_customer_name, p_full_wt, p_full_wt, p_full_wt, p_full_wt, p_full_wt, p_empty_wgt, p_empty_wgt, p_empty_wgt, p_empty_wgt, p_empty_wgt, p_npc, p_npc, p_npc, p_npc, p_npc, p_sort_dt, p_sort_dt, p_sort_dt, p_sort_dt, p_sort_dt;
  END;

  -- WB3100 LOAD_IBOX: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3100_w_load_ibox(b_at$ctrl_incinerator_id IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_online_status IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_IBOX_CONTAINERS
 WHERE (
INCINERATION_STATUS='ON-LINE' AND SORT_STATUS='ON-LINE' AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN ibox_nbr LIKE :c4 THEN 1 END WHEN ibox_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR ibox_seq_id = :c7)
   AND (:c8 IS NULL OR cust_seq_id = :c9)
   AND (:c10 IS NULL OR disp_site_seq_id = :c11)
   AND (:c12 IS NULL OR sequence = :c13)
   AND (:c14 IS NULL OR (CASE WHEN INSTR(:c15, '%') + INSTR(:c16, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c17 THEN 1 END WHEN ibox_barcode = :c18 THEN 1 END) = 1)
   AND (:c19 IS NULL OR (CASE WHEN INSTR(:c20, '%') + INSTR(:c21, '_') > 0 THEN CASE WHEN online_status LIKE :c22 THEN 1 END WHEN online_status = :c23 THEN 1 END) = 1)
   AND (:c24 IS NULL OR (CASE WHEN INSTR(:c25, '%') + INSTR(:c26, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c27 THEN 1 END WHEN incinerator_id = :c28 THEN 1 END) = 1)
 ORDER BY sequence desc
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_incinerator_id, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_seq_id, p_ibox_seq_id, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_online_status, p_online_status, p_online_status, p_online_status, p_online_status, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id;
  END;

  -- WB3200 ACTIVITY_BURNED: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_activity_burned(b_burn_incinerator_incin IN VARCHAR2, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_ibox_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_void_indicator IN VARCHAR2, p_online_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_burn_reason IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_IBOX_CONTAINERS
 WHERE (
INCINERATION_STATUS='BURN' AND SORT_STATUS='EMPTY' AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR empty_wgt = :c2)
   AND (:c3 IS NULL OR full_wgt = :c4)
   AND (:c5 IS NULL OR ibox_seq_id = :c6)
   AND (:c7 IS NULL OR sequence = :c8)
   AND (:c9 IS NULL OR (CASE WHEN INSTR(:c10, '%') + INSTR(:c11, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c12 THEN 1 END WHEN ibox_barcode = :c13 THEN 1 END) = 1)
   AND (:c14 IS NULL OR (CASE WHEN INSTR(:c15, '%') + INSTR(:c16, '_') > 0 THEN CASE WHEN ibox_nbr LIKE :c17 THEN 1 END WHEN ibox_nbr = :c18 THEN 1 END) = 1)
   AND (:c19 IS NULL OR total_activity = :c20)
   AND (:c21 IS NULL OR proj_ash_wgt = :c22)
   AND (:c23 IS NULL OR proj_ash_uncomp_volume = :c24)
   AND (:c25 IS NULL OR (CASE WHEN INSTR(:c26, '%') + INSTR(:c27, '_') > 0 THEN CASE WHEN proj_waste_class LIKE :c28 THEN 1 END WHEN proj_waste_class = :c29 THEN 1 END) = 1)
   AND (:c30 IS NULL OR (CASE WHEN INSTR(:c31, '%') + INSTR(:c32, '_') > 0 THEN CASE WHEN incineration_status LIKE :c33 THEN 1 END WHEN incineration_status = :c34 THEN 1 END) = 1)
   AND (:c35 IS NULL OR (CASE WHEN INSTR(:c36, '%') + INSTR(:c37, '_') > 0 THEN CASE WHEN sort_status LIKE :c38 THEN 1 END WHEN sort_status = :c39 THEN 1 END) = 1)
   AND (:c40 IS NULL OR (CASE WHEN INSTR(:c41, '%') + INSTR(:c42, '_') > 0 THEN CASE WHEN void_indicator LIKE :c43 THEN 1 END WHEN void_indicator = :c44 THEN 1 END) = 1)
   AND (:c45 IS NULL OR (CASE WHEN INSTR(:c46, '%') + INSTR(:c47, '_') > 0 THEN CASE WHEN online_status LIKE :c48 THEN 1 END WHEN online_status = :c49 THEN 1 END) = 1)
   AND (:c50 IS NULL OR cust_seq_id = :c51)
   AND (:c52 IS NULL OR disp_site_seq_id = :c53)
   AND (:c54 IS NULL OR advnotif_seq_id = :c55)
   AND (:c56 IS NULL OR (CASE WHEN INSTR(:c57, '%') + INSTR(:c58, '_') > 0 THEN CASE WHEN burn_reason LIKE :c59 THEN 1 END WHEN burn_reason = :c60 THEN 1 END) = 1)
 ORDER BY BURN_DT ASC
) WHERE ROWNUM <= 5000~'
      USING b_burn_incinerator_incin, p_empty_wgt, p_empty_wgt, p_full_wgt, p_full_wgt, p_ibox_seq_id, p_ibox_seq_id, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_total_activity, p_total_activity, p_proj_ash_wgt, p_proj_ash_wgt, p_proj_ash_uncomp_volume, p_proj_ash_uncomp_volume, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_void_indicator, p_void_indicator, p_void_indicator, p_void_indicator, p_void_indicator, p_online_status, p_online_status, p_online_status, p_online_status, p_online_status, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_burn_reason, p_burn_reason, p_burn_reason, p_burn_reason, p_burn_reason;
  END;

  -- WB3200 ASHBOX_ACTIVITY: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_ashbox_activity(b_ashbox_incinerator_inci_45a5 IN VARCHAR2, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_ashdrum_seq_id IN NUMBER, p_ashdrum_seq_id_secondary IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_removed_ind IN VARCHAR2, p_ash_sequence IN NUMBER, p_incinerator_id IN VARCHAR2, p_online_status IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM wb_ibox_containers
 WHERE (
SORT_STATUS='EMPTY' AND INCINERATION_STATUS='BURN' AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR empty_wgt = :c2)
   AND (:c3 IS NULL OR full_wgt = :c4)
   AND (:c5 IS NULL OR ashdrum_seq_id = :c6)
   AND (:c7 IS NULL OR ashdrum_seq_id_secondary = :c8)
   AND (:c9 IS NULL OR sequence = :c10)
   AND (:c11 IS NULL OR (CASE WHEN INSTR(:c12, '%') + INSTR(:c13, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c14 THEN 1 END WHEN ibox_barcode = :c15 THEN 1 END) = 1)
   AND (:c16 IS NULL OR (CASE WHEN INSTR(:c17, '%') + INSTR(:c18, '_') > 0 THEN CASE WHEN ibox_nbr LIKE :c19 THEN 1 END WHEN ibox_nbr = :c20 THEN 1 END) = 1)
   AND (:c21 IS NULL OR total_activity = :c22)
   AND (:c23 IS NULL OR proj_ash_wgt = :c24)
   AND (:c25 IS NULL OR proj_ash_uncomp_volume = :c26)
   AND (:c27 IS NULL OR (CASE WHEN INSTR(:c28, '%') + INSTR(:c29, '_') > 0 THEN CASE WHEN proj_waste_class LIKE :c30 THEN 1 END WHEN proj_waste_class = :c31 THEN 1 END) = 1)
   AND (:c32 IS NULL OR (CASE WHEN INSTR(:c33, '%') + INSTR(:c34, '_') > 0 THEN CASE WHEN incineration_status LIKE :c35 THEN 1 END WHEN incineration_status = :c36 THEN 1 END) = 1)
   AND (:c37 IS NULL OR (CASE WHEN INSTR(:c38, '%') + INSTR(:c39, '_') > 0 THEN CASE WHEN sort_status LIKE :c40 THEN 1 END WHEN sort_status = :c41 THEN 1 END) = 1)
   AND (:c42 IS NULL OR ibox_seq_id = :c43)
   AND (:c44 IS NULL OR cust_seq_id = :c45)
   AND (:c46 IS NULL OR disp_site_seq_id = :c47)
   AND (:c48 IS NULL OR advnotif_seq_id = :c49)
   AND (:c50 IS NULL OR (CASE WHEN INSTR(:c51, '%') + INSTR(:c52, '_') > 0 THEN CASE WHEN removed_ind LIKE :c53 THEN 1 END WHEN removed_ind = :c54 THEN 1 END) = 1)
   AND (:c55 IS NULL OR ash_sequence = :c56)
   AND (:c57 IS NULL OR (CASE WHEN INSTR(:c58, '%') + INSTR(:c59, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c60 THEN 1 END WHEN incinerator_id = :c61 THEN 1 END) = 1)
   AND (:c62 IS NULL OR (CASE WHEN INSTR(:c63, '%') + INSTR(:c64, '_') > 0 THEN CASE WHEN online_status LIKE :c65 THEN 1 END WHEN online_status = :c66 THEN 1 END) = 1)
 ORDER BY BURN_DT ASC
) WHERE ROWNUM <= 5000~'
      USING b_ashbox_incinerator_inci_45a5, p_empty_wgt, p_empty_wgt, p_full_wgt, p_full_wgt, p_ashdrum_seq_id, p_ashdrum_seq_id, p_ashdrum_seq_id_secondary, p_ashdrum_seq_id_secondary, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_total_activity, p_total_activity, p_proj_ash_wgt, p_proj_ash_wgt, p_proj_ash_uncomp_volume, p_proj_ash_uncomp_volume, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_ibox_seq_id, p_ibox_seq_id, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_removed_ind, p_removed_ind, p_removed_ind, p_removed_ind, p_removed_ind, p_ash_sequence, p_ash_sequence, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_online_status, p_online_status, p_online_status, p_online_status, p_online_status;
  END;

  -- WB3200 BURNED: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_burned(b_ashbox_incinerator_inci_45a5 IN VARCHAR2, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_ibox_seq_id IN NUMBER, p_ashdrum_seq_id IN NUMBER, p_ashdrum_seq_id_secondary IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_void_indicator IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_ash_sequence IN NUMBER, p_incinerator_id IN VARCHAR2, p_removed_ind IN VARCHAR2, p_online_status IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM wb_ibox_containers
 WHERE (
SORT_STATUS='EMPTY' AND INCINERATION_STATUS='ASH'  AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR empty_wgt = :c2)
   AND (:c3 IS NULL OR full_wgt = :c4)
   AND (:c5 IS NULL OR ibox_seq_id = :c6)
   AND (:c7 IS NULL OR ashdrum_seq_id = :c8)
   AND (:c9 IS NULL OR ashdrum_seq_id_secondary = :c10)
   AND (:c11 IS NULL OR sequence = :c12)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c16 THEN 1 END WHEN ibox_barcode = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN ibox_nbr LIKE :c21 THEN 1 END WHEN ibox_nbr = :c22 THEN 1 END) = 1)
   AND (:c23 IS NULL OR total_activity = :c24)
   AND (:c25 IS NULL OR proj_ash_wgt = :c26)
   AND (:c27 IS NULL OR proj_ash_uncomp_volume = :c28)
   AND (:c29 IS NULL OR (CASE WHEN INSTR(:c30, '%') + INSTR(:c31, '_') > 0 THEN CASE WHEN proj_waste_class LIKE :c32 THEN 1 END WHEN proj_waste_class = :c33 THEN 1 END) = 1)
   AND (:c34 IS NULL OR (CASE WHEN INSTR(:c35, '%') + INSTR(:c36, '_') > 0 THEN CASE WHEN incineration_status LIKE :c37 THEN 1 END WHEN incineration_status = :c38 THEN 1 END) = 1)
   AND (:c39 IS NULL OR (CASE WHEN INSTR(:c40, '%') + INSTR(:c41, '_') > 0 THEN CASE WHEN sort_status LIKE :c42 THEN 1 END WHEN sort_status = :c43 THEN 1 END) = 1)
   AND (:c44 IS NULL OR (CASE WHEN INSTR(:c45, '%') + INSTR(:c46, '_') > 0 THEN CASE WHEN void_indicator LIKE :c47 THEN 1 END WHEN void_indicator = :c48 THEN 1 END) = 1)
   AND (:c49 IS NULL OR cust_seq_id = :c50)
   AND (:c51 IS NULL OR disp_site_seq_id = :c52)
   AND (:c53 IS NULL OR advnotif_seq_id = :c54)
   AND (:c55 IS NULL OR ash_sequence = :c56)
   AND (:c57 IS NULL OR (CASE WHEN INSTR(:c58, '%') + INSTR(:c59, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c60 THEN 1 END WHEN incinerator_id = :c61 THEN 1 END) = 1)
   AND (:c62 IS NULL OR (CASE WHEN INSTR(:c63, '%') + INSTR(:c64, '_') > 0 THEN CASE WHEN removed_ind LIKE :c65 THEN 1 END WHEN removed_ind = :c66 THEN 1 END) = 1)
   AND (:c67 IS NULL OR (CASE WHEN INSTR(:c68, '%') + INSTR(:c69, '_') > 0 THEN CASE WHEN online_status LIKE :c70 THEN 1 END WHEN online_status = :c71 THEN 1 END) = 1)
 ORDER BY ASH_DT
) WHERE ROWNUM <= 5000~'
      USING b_ashbox_incinerator_inci_45a5, p_empty_wgt, p_empty_wgt, p_full_wgt, p_full_wgt, p_ibox_seq_id, p_ibox_seq_id, p_ashdrum_seq_id, p_ashdrum_seq_id, p_ashdrum_seq_id_secondary, p_ashdrum_seq_id_secondary, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_total_activity, p_total_activity, p_proj_ash_wgt, p_proj_ash_wgt, p_proj_ash_uncomp_volume, p_proj_ash_uncomp_volume, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_void_indicator, p_void_indicator, p_void_indicator, p_void_indicator, p_void_indicator, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_ash_sequence, p_ash_sequence, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_removed_ind, p_removed_ind, p_removed_ind, p_removed_ind, p_removed_ind, p_online_status, p_online_status, p_online_status, p_online_status, p_online_status;
  END;

  -- WB3200 BURN_ACTIVITY_VIEW: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_burn_activity_view(b_burn_incinerator_incin IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_online_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_burn_reason IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_IBOX_CONTAINERS
 WHERE (
SORT_STATUS = 'ON-LINE' AND INCINERATION_STATUS = 'ON-LINE' AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR ibox_seq_id = :c2)
   AND (:c3 IS NULL OR sequence = :c4)
   AND (:c5 IS NULL OR (CASE WHEN INSTR(:c6, '%') + INSTR(:c7, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c8 THEN 1 END WHEN ibox_barcode = :c9 THEN 1 END) = 1)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN ibox_nbr LIKE :c13 THEN 1 END WHEN ibox_nbr = :c14 THEN 1 END) = 1)
   AND (:c15 IS NULL OR total_activity = :c16)
   AND (:c17 IS NULL OR proj_ash_wgt = :c18)
   AND (:c19 IS NULL OR proj_ash_uncomp_volume = :c20)
   AND (:c21 IS NULL OR (CASE WHEN INSTR(:c22, '%') + INSTR(:c23, '_') > 0 THEN CASE WHEN proj_waste_class LIKE :c24 THEN 1 END WHEN proj_waste_class = :c25 THEN 1 END) = 1)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN incineration_status LIKE :c29 THEN 1 END WHEN incineration_status = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR (CASE WHEN INSTR(:c32, '%') + INSTR(:c33, '_') > 0 THEN CASE WHEN sort_status LIKE :c34 THEN 1 END WHEN sort_status = :c35 THEN 1 END) = 1)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN online_status LIKE :c39 THEN 1 END WHEN online_status = :c40 THEN 1 END) = 1)
   AND (:c41 IS NULL OR cust_seq_id = :c42)
   AND (:c43 IS NULL OR disp_site_seq_id = :c44)
   AND (:c45 IS NULL OR advnotif_seq_id = :c46)
   AND (:c47 IS NULL OR empty_wgt = :c48)
   AND (:c49 IS NULL OR full_wgt = :c50)
   AND (:c51 IS NULL OR (CASE WHEN INSTR(:c52, '%') + INSTR(:c53, '_') > 0 THEN CASE WHEN burn_reason LIKE :c54 THEN 1 END WHEN burn_reason = :c55 THEN 1 END) = 1)
 ORDER BY SEQUENCE
) WHERE ROWNUM <= 5000~'
      USING b_burn_incinerator_incin, p_ibox_seq_id, p_ibox_seq_id, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_total_activity, p_total_activity, p_proj_ash_wgt, p_proj_ash_wgt, p_proj_ash_uncomp_volume, p_proj_ash_uncomp_volume, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_online_status, p_online_status, p_online_status, p_online_status, p_online_status, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_empty_wgt, p_empty_wgt, p_full_wgt, p_full_wgt, p_burn_reason, p_burn_reason, p_burn_reason, p_burn_reason, p_burn_reason;
  END;

  -- WB3200 LOAD_IBOX: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_load_ibox(b_at$ctrl_incinerator_id IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_online_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM wb_ibox_containers
 WHERE (
INCINERATION_STATUS = 'ON-LINE' AND SORT_STATUS='ON-LINE' AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c4 THEN 1 END WHEN incinerator_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR ibox_seq_id = :c7)
   AND (:c8 IS NULL OR sequence = :c9)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c13 THEN 1 END WHEN ibox_barcode = :c14 THEN 1 END) = 1)
   AND (:c15 IS NULL OR total_activity = :c16)
   AND (:c17 IS NULL OR proj_ash_wgt = :c18)
   AND (:c19 IS NULL OR proj_ash_uncomp_volume = :c20)
   AND (:c21 IS NULL OR (CASE WHEN INSTR(:c22, '%') + INSTR(:c23, '_') > 0 THEN CASE WHEN proj_waste_class LIKE :c24 THEN 1 END WHEN proj_waste_class = :c25 THEN 1 END) = 1)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN incineration_status LIKE :c29 THEN 1 END WHEN incineration_status = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR (CASE WHEN INSTR(:c32, '%') + INSTR(:c33, '_') > 0 THEN CASE WHEN sort_status LIKE :c34 THEN 1 END WHEN sort_status = :c35 THEN 1 END) = 1)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN online_status LIKE :c39 THEN 1 END WHEN online_status = :c40 THEN 1 END) = 1)
   AND (:c41 IS NULL OR cust_seq_id = :c42)
   AND (:c43 IS NULL OR disp_site_seq_id = :c44)
 ORDER BY SEQUENCE DESC
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_ibox_seq_id, p_ibox_seq_id, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_total_activity, p_total_activity, p_proj_ash_wgt, p_proj_ash_wgt, p_proj_ash_uncomp_volume, p_proj_ash_uncomp_volume, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_online_status, p_online_status, p_online_status, p_online_status, p_online_status, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id;
  END;

  -- WB3200 SUMMARY: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_summary(b_at$ctrl_incin_summary IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_incinerator_id IN VARCHAR2, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_void_indicator IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM wb_ibox_containers
 WHERE (
SORT_STATUS='EMPTY' AND INCINERATION_STATUS='ASH'  AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR ibox_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c6 THEN 1 END WHEN incinerator_id = :c7 THEN 1 END) = 1)
   AND (:c8 IS NULL OR sequence = :c9)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c13 THEN 1 END WHEN ibox_barcode = :c14 THEN 1 END) = 1)
   AND (:c15 IS NULL OR (CASE WHEN INSTR(:c16, '%') + INSTR(:c17, '_') > 0 THEN CASE WHEN ibox_nbr LIKE :c18 THEN 1 END WHEN ibox_nbr = :c19 THEN 1 END) = 1)
   AND (:c20 IS NULL OR total_activity = :c21)
   AND (:c22 IS NULL OR proj_ash_wgt = :c23)
   AND (:c24 IS NULL OR proj_ash_uncomp_volume = :c25)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN proj_waste_class LIKE :c29 THEN 1 END WHEN proj_waste_class = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR (CASE WHEN INSTR(:c32, '%') + INSTR(:c33, '_') > 0 THEN CASE WHEN incineration_status LIKE :c34 THEN 1 END WHEN incineration_status = :c35 THEN 1 END) = 1)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN sort_status LIKE :c39 THEN 1 END WHEN sort_status = :c40 THEN 1 END) = 1)
   AND (:c41 IS NULL OR cust_seq_id = :c42)
   AND (:c43 IS NULL OR disp_site_seq_id = :c44)
   AND (:c45 IS NULL OR advnotif_seq_id = :c46)
   AND (:c47 IS NULL OR empty_wgt = :c48)
   AND (:c49 IS NULL OR full_wgt = :c50)
   AND (:c51 IS NULL OR (CASE WHEN INSTR(:c52, '%') + INSTR(:c53, '_') > 0 THEN CASE WHEN void_indicator LIKE :c54 THEN 1 END WHEN void_indicator = :c55 THEN 1 END) = 1)
   AND (:c56 IS NULL OR cntnr_typ_seq_id = :c57)
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_incin_summary, p_ibox_seq_id, p_ibox_seq_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_total_activity, p_total_activity, p_proj_ash_wgt, p_proj_ash_wgt, p_proj_ash_uncomp_volume, p_proj_ash_uncomp_volume, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_empty_wgt, p_empty_wgt, p_full_wgt, p_full_wgt, p_void_indicator, p_void_indicator, p_void_indicator, p_void_indicator, p_void_indicator, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id;
  END;

  -- WB3200 WB_ASHDRUM1: WB_ASHDRUM with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_wb_ashdrum1(b_at$ctrl_incinerator_id IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_ashdrum_seq_id IN NUMBER, p_ashdrum_barcode IN VARCHAR2, p_empty_wt IN NUMBER, p_full_wt IN NUMBER, p_waste_wt IN NUMBER, p_final_void IN NUMBER, p_dose_rate IN NUMBER, p_dose_rate_30cm IN NUMBER, p_dose_unit IN VARCHAR2, p_sample_amt IN NUMBER, p_sample_unit IN VARCHAR2, p_sample_reason IN VARCHAR2, p_comments IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM wb_ashdrum
 WHERE (
ASHDRUM_SEQ_ID = (SELECT MIN(ASHDRUM_SEQ_ID) FROM WB_ASHDRUM WHERE ACTIVE_INDICATOR='Y' AND INCINERATOR_ID=:w1)
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c4 THEN 1 END WHEN incinerator_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR ashdrum_seq_id = :c7)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN ashdrum_barcode LIKE :c11 THEN 1 END WHEN ashdrum_barcode = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR empty_wt = :c14)
   AND (:c15 IS NULL OR full_wt = :c16)
   AND (:c17 IS NULL OR waste_wt = :c18)
   AND (:c19 IS NULL OR final_void = :c20)
   AND (:c21 IS NULL OR dose_rate = :c22)
   AND (:c23 IS NULL OR dose_rate_30cm = :c24)
   AND (:c25 IS NULL OR (CASE WHEN INSTR(:c26, '%') + INSTR(:c27, '_') > 0 THEN CASE WHEN dose_unit LIKE :c28 THEN 1 END WHEN dose_unit = :c29 THEN 1 END) = 1)
   AND (:c30 IS NULL OR sample_amt = :c31)
   AND (:c32 IS NULL OR (CASE WHEN INSTR(:c33, '%') + INSTR(:c34, '_') > 0 THEN CASE WHEN sample_unit LIKE :c35 THEN 1 END WHEN sample_unit = :c36 THEN 1 END) = 1)
   AND (:c37 IS NULL OR (CASE WHEN INSTR(:c38, '%') + INSTR(:c39, '_') > 0 THEN CASE WHEN sample_reason LIKE :c40 THEN 1 END WHEN sample_reason = :c41 THEN 1 END) = 1)
   AND (:c42 IS NULL OR (CASE WHEN INSTR(:c43, '%') + INSTR(:c44, '_') > 0 THEN CASE WHEN comments LIKE :c45 THEN 1 END WHEN comments = :c46 THEN 1 END) = 1)
   AND (:c47 IS NULL OR cntnr_typ_seq_id = :c48)
   AND (:c49 IS NULL OR prctrantyp_seq_id = :c50)
   AND (:c51 IS NULL OR prodserv_seq_id = :c52)
   AND (:c53 IS NULL OR disp_site_seq_id = :c54)
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_ashdrum_seq_id, p_ashdrum_seq_id, p_ashdrum_barcode, p_ashdrum_barcode, p_ashdrum_barcode, p_ashdrum_barcode, p_ashdrum_barcode, p_empty_wt, p_empty_wt, p_full_wt, p_full_wt, p_waste_wt, p_waste_wt, p_final_void, p_final_void, p_dose_rate, p_dose_rate, p_dose_rate_30cm, p_dose_rate_30cm, p_dose_unit, p_dose_unit, p_dose_unit, p_dose_unit, p_dose_unit, p_sample_amt, p_sample_amt, p_sample_unit, p_sample_unit, p_sample_unit, p_sample_unit, p_sample_unit, p_sample_reason, p_sample_reason, p_sample_reason, p_sample_reason, p_sample_reason, p_comments, p_comments, p_comments, p_comments, p_comments, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id, p_prctrantyp_seq_id, p_prctrantyp_seq_id, p_prodserv_seq_id, p_prodserv_seq_id, p_disp_site_seq_id, p_disp_site_seq_id;
  END;

  -- WB3200 WB_ASHDRUM2: WB_ASHDRUM with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_wb_ashdrum2(b_at$ctrl_incinerator_id IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_ashdrum_seq_id IN NUMBER, p_ashdrum_barcode IN VARCHAR2, p_empty_wt IN NUMBER, p_full_wt IN NUMBER, p_waste_wt IN NUMBER, p_final_void IN NUMBER, p_dose_rate IN NUMBER, p_dose_rate_30cm IN NUMBER, p_dose_unit IN VARCHAR2, p_sample_amt IN NUMBER, p_sample_unit IN VARCHAR2, p_sample_reason IN VARCHAR2, p_comments IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM wb_ashdrum
 WHERE (
ASHDRUM_SEQ_ID = (SELECT MAX(ASHDRUM_SEQ_ID) FROM WB_ASHDRUM WHERE ACTIVE_INDICATOR='Y' AND INCINERATOR_ID=:w1)
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c4 THEN 1 END WHEN incinerator_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR ashdrum_seq_id = :c7)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN ashdrum_barcode LIKE :c11 THEN 1 END WHEN ashdrum_barcode = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR empty_wt = :c14)
   AND (:c15 IS NULL OR full_wt = :c16)
   AND (:c17 IS NULL OR waste_wt = :c18)
   AND (:c19 IS NULL OR final_void = :c20)
   AND (:c21 IS NULL OR dose_rate = :c22)
   AND (:c23 IS NULL OR dose_rate_30cm = :c24)
   AND (:c25 IS NULL OR (CASE WHEN INSTR(:c26, '%') + INSTR(:c27, '_') > 0 THEN CASE WHEN dose_unit LIKE :c28 THEN 1 END WHEN dose_unit = :c29 THEN 1 END) = 1)
   AND (:c30 IS NULL OR sample_amt = :c31)
   AND (:c32 IS NULL OR (CASE WHEN INSTR(:c33, '%') + INSTR(:c34, '_') > 0 THEN CASE WHEN sample_unit LIKE :c35 THEN 1 END WHEN sample_unit = :c36 THEN 1 END) = 1)
   AND (:c37 IS NULL OR (CASE WHEN INSTR(:c38, '%') + INSTR(:c39, '_') > 0 THEN CASE WHEN sample_reason LIKE :c40 THEN 1 END WHEN sample_reason = :c41 THEN 1 END) = 1)
   AND (:c42 IS NULL OR (CASE WHEN INSTR(:c43, '%') + INSTR(:c44, '_') > 0 THEN CASE WHEN comments LIKE :c45 THEN 1 END WHEN comments = :c46 THEN 1 END) = 1)
   AND (:c47 IS NULL OR cntnr_typ_seq_id = :c48)
   AND (:c49 IS NULL OR prctrantyp_seq_id = :c50)
   AND (:c51 IS NULL OR prodserv_seq_id = :c52)
   AND (:c53 IS NULL OR disp_site_seq_id = :c54)
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_ashdrum_seq_id, p_ashdrum_seq_id, p_ashdrum_barcode, p_ashdrum_barcode, p_ashdrum_barcode, p_ashdrum_barcode, p_ashdrum_barcode, p_empty_wt, p_empty_wt, p_full_wt, p_full_wt, p_waste_wt, p_waste_wt, p_final_void, p_final_void, p_dose_rate, p_dose_rate, p_dose_rate_30cm, p_dose_rate_30cm, p_dose_unit, p_dose_unit, p_dose_unit, p_dose_unit, p_dose_unit, p_sample_amt, p_sample_amt, p_sample_unit, p_sample_unit, p_sample_unit, p_sample_unit, p_sample_unit, p_sample_reason, p_sample_reason, p_sample_reason, p_sample_reason, p_sample_reason, p_comments, p_comments, p_comments, p_comments, p_comments, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id, p_prctrantyp_seq_id, p_prctrantyp_seq_id, p_prodserv_seq_id, p_prodserv_seq_id, p_disp_site_seq_id, p_disp_site_seq_id;
  END;

  -- WB4000 OPEN_PARENTS: WB_QTB_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb4000_w_open_parents(p_parent_empty_ind IN VARCHAR2, p_parent_container_id IN VARCHAR2, p_parent_full_wgt IN NUMBER, p_parent_empty_wgt IN NUMBER, p_psc IN VARCHAR2, p_advnotif_seq_id IN NUMBER, p_qtb_seq_id IN NUMBER, p_parent_cntnr_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_pseudo_parent_container_id IN VARCHAR2, p_parent_container_type IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_QTB_CONTAINERS
 WHERE (
NVL(PARENT_EMPTY_IND,'N') = 'N'
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN parent_empty_ind LIKE :c4 THEN 1 END WHEN parent_empty_ind = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN parent_container_id LIKE :c9 THEN 1 END WHEN parent_container_id = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR parent_full_wgt = :c12)
   AND (:c13 IS NULL OR parent_empty_wgt = :c14)
   AND (:c15 IS NULL OR (CASE WHEN INSTR(:c16, '%') + INSTR(:c17, '_') > 0 THEN CASE WHEN psc LIKE :c18 THEN 1 END WHEN psc = :c19 THEN 1 END) = 1)
   AND (:c20 IS NULL OR advnotif_seq_id = :c21)
   AND (:c22 IS NULL OR qtb_seq_id = :c23)
   AND (:c24 IS NULL OR parent_cntnr_seq_id = :c25)
   AND (:c26 IS NULL OR prodserv_seq_id = :c27)
   AND (:c28 IS NULL OR disp_site_seq_id = :c29)
   AND (:c30 IS NULL OR cust_seq_id = :c31)
   AND (:c32 IS NULL OR (CASE WHEN INSTR(:c33, '%') + INSTR(:c34, '_') > 0 THEN CASE WHEN pseudo_parent_container_id LIKE :c35 THEN 1 END WHEN pseudo_parent_container_id = :c36 THEN 1 END) = 1)
   AND (:c37 IS NULL OR (CASE WHEN INSTR(:c38, '%') + INSTR(:c39, '_') > 0 THEN CASE WHEN parent_container_type LIKE :c40 THEN 1 END WHEN parent_container_type = :c41 THEN 1 END) = 1)
 ORDER BY SORT_DT DESC
) WHERE ROWNUM <= 5000~'
      USING p_parent_empty_ind, p_parent_empty_ind, p_parent_empty_ind, p_parent_empty_ind, p_parent_empty_ind, p_parent_container_id, p_parent_container_id, p_parent_container_id, p_parent_container_id, p_parent_container_id, p_parent_full_wgt, p_parent_full_wgt, p_parent_empty_wgt, p_parent_empty_wgt, p_psc, p_psc, p_psc, p_psc, p_psc, p_advnotif_seq_id, p_advnotif_seq_id, p_qtb_seq_id, p_qtb_seq_id, p_parent_cntnr_seq_id, p_parent_cntnr_seq_id, p_prodserv_seq_id, p_prodserv_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_cust_seq_id, p_cust_seq_id, p_pseudo_parent_container_id, p_pseudo_parent_container_id, p_pseudo_parent_container_id, p_pseudo_parent_container_id, p_pseudo_parent_container_id, p_parent_container_type, p_parent_container_type, p_parent_container_type, p_parent_container_type, p_parent_container_type;
  END;

  -- WB4000 OPEN_QTB: WB_QTB_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb4000_w_open_qtb(p_qtb_closed_ind IN VARCHAR2, p_qtb_barcode IN VARCHAR2, p_full_wgt IN NUMBER, p_empty_wgt IN NUMBER, p_container_type IN VARCHAR2, p_qtb_seq_id IN NUMBER, p_qtb_cntnr_seq_id IN NUMBER, p_cntnr_typ_seq_id IN NUMBER, p_sort_area IN VARCHAR2, p_alt_container_type IN VARCHAR2, p_sort_status IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_QTB_CONTAINERS
 WHERE (
NVL(QTB_CLOSED_IND,'S') = 'N'
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN qtb_closed_ind LIKE :c4 THEN 1 END WHEN qtb_closed_ind = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN qtb_barcode LIKE :c9 THEN 1 END WHEN qtb_barcode = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR full_wgt = :c12)
   AND (:c13 IS NULL OR empty_wgt = :c14)
   AND (:c15 IS NULL OR (CASE WHEN INSTR(:c16, '%') + INSTR(:c17, '_') > 0 THEN CASE WHEN container_type LIKE :c18 THEN 1 END WHEN container_type = :c19 THEN 1 END) = 1)
   AND (:c20 IS NULL OR qtb_seq_id = :c21)
   AND (:c22 IS NULL OR qtb_cntnr_seq_id = :c23)
   AND (:c24 IS NULL OR cntnr_typ_seq_id = :c25)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN sort_area LIKE :c29 THEN 1 END WHEN sort_area = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR (CASE WHEN INSTR(:c32, '%') + INSTR(:c33, '_') > 0 THEN CASE WHEN alt_container_type LIKE :c34 THEN 1 END WHEN alt_container_type = :c35 THEN 1 END) = 1)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN sort_status LIKE :c39 THEN 1 END WHEN sort_status = :c40 THEN 1 END) = 1)
 ORDER BY SORT_DT DESC
) WHERE ROWNUM <= 5000~'
      USING p_qtb_closed_ind, p_qtb_closed_ind, p_qtb_closed_ind, p_qtb_closed_ind, p_qtb_closed_ind, p_qtb_barcode, p_qtb_barcode, p_qtb_barcode, p_qtb_barcode, p_qtb_barcode, p_full_wgt, p_full_wgt, p_empty_wgt, p_empty_wgt, p_container_type, p_container_type, p_container_type, p_container_type, p_container_type, p_qtb_seq_id, p_qtb_seq_id, p_qtb_cntnr_seq_id, p_qtb_cntnr_seq_id, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id, p_sort_area, p_sort_area, p_sort_area, p_sort_area, p_sort_area, p_alt_container_type, p_alt_container_type, p_alt_container_type, p_alt_container_type, p_alt_container_type, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status;
  END;

  -- WB4000 WB_INCOMING_MANIFESTS: AT_INCOMING_MANIFESTS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb4000_w_wb_incoming_manifests(p_advnotif_seq_id IN NUMBER, p_manifest_nbr IN VARCHAR2, p_cust_seq_id IN NUMBER, p_processing_hold_ind IN VARCHAR2, p_brokered_shipment_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_INCOMING_MANIFESTS
 WHERE (
MNFSTSTAT_CD_ID = 'QC RELEASE' AND ADVNOTIF_SEQ_ID = NO_MANIFEST_DAUGHTERS(ADVNOTIF_SEQ_ID)
)
   AND (:c1 IS NULL OR advnotif_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN manifest_nbr LIKE :c6 THEN 1 END WHEN manifest_nbr = :c7 THEN 1 END) = 1)
   AND (:c8 IS NULL OR cust_seq_id = :c9)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN processing_hold_ind LIKE :c13 THEN 1 END WHEN processing_hold_ind = :c14 THEN 1 END) = 1)
   AND (:c15 IS NULL OR (CASE WHEN INSTR(:c16, '%') + INSTR(:c17, '_') > 0 THEN CASE WHEN brokered_shipment_ind LIKE :c18 THEN 1 END WHEN brokered_shipment_ind = :c19 THEN 1 END) = 1)
 ORDER BY ADVNOTIF_EXPECTED_RECPT_DT DESC
) WHERE ROWNUM <= 5000~'
      USING p_advnotif_seq_id, p_advnotif_seq_id, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_cust_seq_id, p_cust_seq_id, p_processing_hold_ind, p_processing_hold_ind, p_processing_hold_ind, p_processing_hold_ind, p_processing_hold_ind, p_brokered_shipment_ind, p_brokered_shipment_ind, p_brokered_shipment_ind, p_brokered_shipment_ind, p_brokered_shipment_ind;
  END;

  -- WB4100 WB_QTB_CONTAINERS_DAU: WB_QTB_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb4100_w_wb_qtb_containers_dau(p_qtb_seq_id IN NUMBER, p_parent_container_id IN VARCHAR2, p_qtb_barcode IN VARCHAR2, p_pseudo_parent_container_id IN VARCHAR2, p_full_wgt IN NUMBER, p_empty_wgt IN NUMBER, p_cntnr_typ_seq_id IN NUMBER, p_container_type IN VARCHAR2, p_incinerator_box_nbr IN VARCHAR2, p_next_process_cd IN VARCHAR2, p_psc IN VARCHAR2, p_exterior_dose_rate_amt IN NUMBER, p_dose_rate_30cm IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_QTB_CONTAINERS
 WHERE (
NVL(full_wgt, 0) > 0
)
   AND (:c1 IS NULL OR qtb_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN parent_container_id LIKE :c6 THEN 1 END WHEN parent_container_id = :c7 THEN 1 END) = 1)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN qtb_barcode LIKE :c11 THEN 1 END WHEN qtb_barcode = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN pseudo_parent_container_id LIKE :c16 THEN 1 END WHEN pseudo_parent_container_id = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR full_wgt = :c19)
   AND (:c20 IS NULL OR empty_wgt = :c21)
   AND (:c22 IS NULL OR cntnr_typ_seq_id = :c23)
   AND (:c24 IS NULL OR (CASE WHEN INSTR(:c25, '%') + INSTR(:c26, '_') > 0 THEN CASE WHEN container_type LIKE :c27 THEN 1 END WHEN container_type = :c28 THEN 1 END) = 1)
   AND (:c29 IS NULL OR (CASE WHEN INSTR(:c30, '%') + INSTR(:c31, '_') > 0 THEN CASE WHEN incinerator_box_nbr LIKE :c32 THEN 1 END WHEN incinerator_box_nbr = :c33 THEN 1 END) = 1)
   AND (:c34 IS NULL OR (CASE WHEN INSTR(:c35, '%') + INSTR(:c36, '_') > 0 THEN CASE WHEN next_process_cd LIKE :c37 THEN 1 END WHEN next_process_cd = :c38 THEN 1 END) = 1)
   AND (:c39 IS NULL OR (CASE WHEN INSTR(:c40, '%') + INSTR(:c41, '_') > 0 THEN CASE WHEN psc LIKE :c42 THEN 1 END WHEN psc = :c43 THEN 1 END) = 1)
   AND (:c44 IS NULL OR exterior_dose_rate_amt = :c45)
   AND (:c46 IS NULL OR dose_rate_30cm = :c47)
 ORDER BY EMPTY_WGT
) WHERE ROWNUM <= 5000~'
      USING p_qtb_seq_id, p_qtb_seq_id, p_parent_container_id, p_parent_container_id, p_parent_container_id, p_parent_container_id, p_parent_container_id, p_qtb_barcode, p_qtb_barcode, p_qtb_barcode, p_qtb_barcode, p_qtb_barcode, p_pseudo_parent_container_id, p_pseudo_parent_container_id, p_pseudo_parent_container_id, p_pseudo_parent_container_id, p_pseudo_parent_container_id, p_full_wgt, p_full_wgt, p_empty_wgt, p_empty_wgt, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id, p_container_type, p_container_type, p_container_type, p_container_type, p_container_type, p_incinerator_box_nbr, p_incinerator_box_nbr, p_incinerator_box_nbr, p_incinerator_box_nbr, p_incinerator_box_nbr, p_next_process_cd, p_next_process_cd, p_next_process_cd, p_next_process_cd, p_next_process_cd, p_psc, p_psc, p_psc, p_psc, p_psc, p_exterior_dose_rate_amt, p_exterior_dose_rate_amt, p_dose_rate_30cm, p_dose_rate_30cm;
  END;
  -- <<< end of generated query blocks

END ewt_ui;
/
