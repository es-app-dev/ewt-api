-- EWT_UI fragment: AT4225
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT4225 COMPACTION_MASTERS: AT_SHIP_COMPACTION_MASTERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at4225_w_compaction_masters(p_cmpctn_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_innerpack_hgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT4225 OVERPACK_MASTER: AT_OVERPACK_MASTERS_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at4225_w_overpack_master(p_ovrpack_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_parent_daughter_type_cd IN VARCHAR2, p_volume IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_waste_wgt IN NUMBER, p_void_space_amt IN NUMBER, p_container_total_height IN NUMBER, p_dose_rate_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_comment_txt IN VARCHAR2, p_wgt_unit_cd_id IN VARCHAR2, p_void_unit_cd_id IN VARCHAR2, p_shift_cd IN VARCHAR2, p_overpack_complete_ind IN VARCHAR2, p_difference_wgt IN NUMBER, p_void_difference_amt IN NUMBER, p_vol_unit_cd_id IN VARCHAR2, p_seg_stf_seq_id IN NUMBER, p_super_seg_stf_seq_id IN NUMBER, p_cntnr_proc_stat_cd_id IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4225 PARTIAL_OVERPACKS (record group PARTIAL_OVERPACKS); not OData: a join
  PROCEDURE at4225_lov_partial_overpacks(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
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
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4225 PARTIAL_OVERPACKS: the record group's own query
  PROCEDURE at4225_lov_partial_overpacks(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select distinct ovrpk.cntnr_seq_id, ovrpk.transaction_dt, cont.container_id , cnttyp.container_type_cd, 'Partial Overpack' status from at_overpack_masters ovrpk, at_containers cont, at_container_types cnttyp where ovrpk.cntnr_seq_id = cont.cntnr_seq_id and nvl(ovrpk.compacted_ind,'Y')='Y' and cont.cntnr_typ_seq_id = cnttyp.cntnr_typ_seq_id and ( ovrpk.overpack_complete_ind is null or ovrpk.overpack_complete_ind = 'N') union select c.cntnr_seq_id, cp.transaction_dt, c.container_id, typ.container_type_cd , 'Solidified Container' from at_containers c, at_container_processes cp, at_container_types typ where c.cntnr_seq_id = cp.cntnr_seq_id and c.cntnr_typ_seq_id = typ.cntnr_typ_seq_id and c.agt_media_seq_id is not null and nvl(cp.compacted_ind,'Y')='Y' and not exists (select 'x' from at_overpack_masters op2 where op2.cntnr_seq_id = cp.cntnr_seq_id and (op2.overpack_complete_ind is null or op2.overpack_complete_ind = 'N')) and not exists (select 'x' from at_overpack_details opd where opd.cntnr_seq_id = cp.cntnr_seq_id) order by 5,3
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

