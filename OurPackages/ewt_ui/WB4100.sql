-- EWT_UI fragment: WB4100
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- WB4100 WB_QTB_CONTAINERS_DAU: WB_QTB_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb4100_w_wb_qtb_containers_dau(p_qtb_seq_id IN NUMBER, p_parent_container_id IN VARCHAR2, p_qtb_barcode IN VARCHAR2, p_pseudo_parent_container_id IN VARCHAR2, p_full_wgt IN NUMBER, p_empty_wgt IN NUMBER, p_cntnr_typ_seq_id IN NUMBER, p_container_type IN VARCHAR2, p_incinerator_box_nbr IN VARCHAR2, p_next_process_cd IN VARCHAR2, p_psc IN VARCHAR2, p_exterior_dose_rate_amt IN NUMBER, p_dose_rate_30cm IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

--#BODY
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
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
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

