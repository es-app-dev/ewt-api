-- EWT_UI fragment: WB2003
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- WB2003 AT_CONTAINER_PROCESSES: AT_CONTAINER_PROCESSES with the block's own WHERE; one optional criterion per column
  PROCEDURE wb2003_w_at_container_pro_4055(b_op_cntnr_seq_id IN NUMBER, p_parent_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_innerpack_hgt IN NUMBER, p_volume IN NUMBER, p_innerpack_waste_vol IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

--#BODY
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
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
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

