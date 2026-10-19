-- EWT_UI fragment: WB1100
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- WB1100 DOUBLE_CONTAINMENT: WB_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb1100_w_double_containment(b_wb_incoming_manifests_a_0f8f IN NUMBER, p_incoming_barcode IN VARCHAR2, p_container_id IN VARCHAR2, p_gross_wgt IN NUMBER, p_tare_wgt IN NUMBER, p_used_vol IN NUMBER, p_cntnr_seq_id IN NUMBER, p_within_cntnr_seq_id IN NUMBER, p_next_prctrantyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- WB1100 SURVEYORS (record group SURVEYORS); not OData: a subquery in WHERE
  PROCEDURE wb1100_lov_surveyors(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
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
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
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
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

