-- EWT_UI fragment: AT9999
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT9999 AT_CUST_DOC_TRACKED_ITEMS: AT_CUST_DOC_TRACKED_ITEMS with the block's own WHERE; one optional criterion per column
  PROCEDURE at9999_w_at_cust_doc_trac_c339(b_at$ctrl_cntnr_seq IN NUMBER, p_custtrck_seq_id IN NUMBER, p_trkditm_seq_id IN NUMBER, p_cust_provided_ind IN VARCHAR2, p_activity_amt IN NUMBER, p_total_activity_pct IN NUMBER, p_inc_activity_amt IN NUMBER, p_snm_amt IN NUMBER, p_inc_snm_amt IN NUMBER, p_inc_source_material_amt IN NUMBER, p_source_material_amt IN NUMBER, p_accum_ind IN VARCHAR2, p_cust_seq_id IN NUMBER, p_matl_seq_id IN NUMBER, p_byprodhdrs_seq_id IN NUMBER, p_snm_741_ind IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT9999 AT_CUST_DOC_TRACKED_ITEMS_N: AT_CUST_DOC_TRACKED_ITEMS_N with the block's own WHERE; one optional criterion per column
  PROCEDURE at9999_w_at_cust_doc_trac_5461(b_at$ctrl_cntnr_seq_n IN NUMBER, b_at$ctrl_matl_seq_n IN NUMBER, p_activity_amt IN NUMBER, p_snm_amt IN NUMBER, p_source_material_amt IN NUMBER, p_lld_activity_amt IN NUMBER, p_custtrck_seq_id IN NUMBER, p_trkditm_seq_id IN NUMBER, p_cust_provided_ind IN VARCHAR2, p_total_activity_pct IN NUMBER, p_inc_activity_amt IN NUMBER, p_inc_snm_amt IN NUMBER, p_inc_source_material_amt IN NUMBER, p_accum_ind IN VARCHAR2, p_cust_seq_id IN NUMBER, p_matl_seq_id IN NUMBER, p_byprodhdrs_seq_id IN NUMBER, p_snm_741_ind IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT9999 DAUGHTERS: AT_CONTAINER_PROCESSES with the block's own WHERE; one optional criterion per column
  PROCEDURE at9999_w_daughters(b_at_anchor_retro_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_anchor_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR);

--#BODY
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

