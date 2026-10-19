-- EWT_UI fragment: AT5132
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
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

--#BODY
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

