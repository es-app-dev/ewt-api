-- EWT_UI fragment: AT4230
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT4230 CONTAINERS: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at4230_w_containers(p_next_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_used_vol IN NUMBER, p_total_hgt IN NUMBER, p_gross_wgt_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT4230 OVERPACK_MASTER: AT_OVERPACK_MASTERS_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at4230_w_overpack_master(p_ovrpack_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_parent_daughter_type_cd IN VARCHAR2, p_volume IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_waste_wgt IN NUMBER, p_void_space_amt IN NUMBER, p_dose_rate_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_comment_txt IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_void_unit_cd_id IN VARCHAR2, p_shift_cd IN VARCHAR2, p_overpack_complete_ind IN VARCHAR2, p_difference_wgt IN NUMBER, p_void_difference_amt IN NUMBER, p_vol_unit_cd_id IN VARCHAR2, p_super_seg_stf_seq_id IN NUMBER, p_cntnr_proc_stat_cd_id IN VARCHAR2, p_compacted_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4230 PARTIAL_OVERPACKS (record group PARTIAL_OVERPACKS); not OData: a join
  PROCEDURE at4230_lov_partial_overpacks(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
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
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4230 PARTIAL_OVERPACKS: the record group's own query
  PROCEDURE at4230_lov_partial_overpacks(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select distinct ovrpk.cntnr_seq_id, ovrpk.transaction_dt, cont.container_id, cnttyp.container_type_cd, 'Partial Overpack' status from at_overpack_masters ovrpk, at_containers cont, at_container_types cnttyp where ovrpk.cntnr_seq_id = cont.cntnr_seq_id and cont.cntnr_typ_seq_id = cnttyp.cntnr_typ_seq_id and ( ovrpk.overpack_complete_ind is null or ovrpk.overpack_complete_ind = 'N') union select c.cntnr_seq_id, cp.transaction_dt, c.container_id, typ.container_type_cd, 'Solidified Container' from at_containers c, at_container_processes cp, at_container_types typ where c.cntnr_seq_id = cp.cntnr_seq_id and c.cntnr_typ_seq_id = typ.cntnr_typ_seq_id and c.agt_media_seq_id is not null and not exists (select 'x' from at_overpack_masters op2 where op2.cntnr_seq_id = cp.cntnr_seq_id and (op2.overpack_complete_ind is null or op2.overpack_complete_ind = 'N')) and not exists (select 'x' from at_overpack_details opd where opd.cntnr_seq_id = cp.cntnr_seq_id) order by 5,3
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

