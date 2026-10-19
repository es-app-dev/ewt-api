-- EWT_UI fragment: AT5510
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
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

  -- AT5510 DISP_SITES_LOV (record group DISP_SITES_RG); not OData: function DECODE
  PROCEDURE at5510_lov_disp_sites_lov(p_rows OUT SYS_REFCURSOR);
  -- AT5510 WASTE_PROFILE_NUMBER_LOV (record group WASTE_PROFILE_NUMBER_RG); not OData: could not read the query (expected FROM at "EXTRACTVALUE ( cip .")
  PROCEDURE at5510_lov_waste_profile_numbe(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT5510 AT_OUTBOUND_SHIPMENTS: AT_OUTBOUND_SHIPMENTS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5510_w_at_outbound_shipments(p_outshipmt_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_shipment_nbr IN VARCHAR2, p_manifest_nbr IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_railcar_nbr IN VARCHAR2, p_epa_manifest_nbr IN VARCHAR2, p_es_prof_seq_id IN NUMBER, p_exclusive_use_ind IN VARCHAR2, p_cntnr_vol_ind IN VARCHAR2, p_cask_ind IN VARCHAR2, p_epa_regulated_waste_ind IN VARCHAR2, p_collector_ind IN VARCHAR2, p_processor_ind IN VARCHAR2, p_envirocare_cwf_ind IN VARCHAR2, p_qoc_cat2_ind IN VARCHAR2, p_electronic_541_ind IN VARCHAR2, p_electronic_542_ind IN VARCHAR2, p_electronic_add_notes_ind IN VARCHAR2, p_additional_notes IN VARCHAR2, p_shipment_status IN VARCHAR2, p_transport_permit_nbr IN VARCHAR2, p_generator_cd IN VARCHAR2, p_disp_purpose_cd IN VARCHAR2, p_disp_site_seq_id IN NUMBER, p_special_handling_instr IN VARCHAR2, p_shipper_seg_stf_seq_id IN NUMBER, p_man_addl_num_pgs IN NUMBER, p_rows OUT SYS_REFCURSOR);

--#BODY
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

