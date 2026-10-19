-- EWT_UI fragment: WB2002
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- WB2002 AT_COMPACTION_MASTERS: AT_COMPACTION_MASTERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb2002_w_at_compaction_masters(p_cmpctn_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_innerpack_hgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB2002 AT_COMPACTION_MASTERS2: AT_COMPACTION_MASTERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb2002_w_at_compaction_ma_f0a9(p_cntnr_seq_id IN NUMBER, p_innerpack_hgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB2002 AT_CONTAINER_PROCESSES: AT_CONTAINER_PROCESSES with the block's own WHERE; one optional criterion per column
  PROCEDURE wb2002_w_at_container_pro_2fad(b_at_overpacks_cntnr_seq_id IN NUMBER, p_parent_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_innerpack_wgt IN NUMBER, p_innerpack_hgt IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB2002 AT_OVERPACKS: AT_OVERPACKS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb2002_w_at_overpacks(p_cntnr_seq_id IN NUMBER, p_underfill_amt IN NUMBER, p_rank IN NUMBER, p_rad_greater_0_ind IN VARCHAR2, p_rad_greater_180_ind IN VARCHAR2, p_ash_ind IN VARCHAR2, p_rad_greater_500_ind IN VARCHAR2, p_baghouse_dust_ind IN VARCHAR2, p_fly_ash_ind IN VARCHAR2, p_rad_greater_1000_ind IN VARCHAR2, p_treated_ash_ind IN VARCHAR2, p_full_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

--#BODY
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
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
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

