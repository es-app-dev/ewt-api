-- EWT_UI fragment: AT4151
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT4151 LINER_CREATE: AT_CONTAINER_PROCESSES with the block's own WHERE; one optional criterion per column
  PROCEDURE at4151_w_liner_create(p_batch_seq_id IN NUMBER, p_sealand_seq_id IN NUMBER, p_hic_seq_id IN NUMBER, p_liner_rtc_ind IN VARCHAR2, p_comment_txt IN VARCHAR2, p_liner_complete_ind IN VARCHAR2, p_filter_amt IN NUMBER, p_cntnr_proc_seq_id IN NUMBER, p_parent_daughter_type_cd IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_void_space_amt IN NUMBER, p_empty_wgt IN NUMBER, p_activity_pct IN NUMBER, p_difference_wgt IN NUMBER, p_full_wgt IN NUMBER, p_innerpack_wgt IN NUMBER, p_innerpack_hgt IN NUMBER, p_void_difference_amt IN NUMBER, p_waste_wgt IN NUMBER, p_dose_rate_amt IN NUMBER, p_volume IN NUMBER, p_shift_cd IN VARCHAR2, p_anchor_wgt IN NUMBER, p_height IN NUMBER, p_locks_qty IN NUMBER, p_pre_sorted_ind IN VARCHAR2, p_assignment_method_cd IN VARCHAR2, p_incineration_factor_nbr IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_overpack_complete_ind IN VARCHAR2, p_overpack_full_ind IN VARCHAR2, p_highest_contact_amt IN NUMBER, p_average_contact_amt IN NUMBER, p_average_at_3ft_amt IN NUMBER, p_created_by_name IN VARCHAR2, p_modified_by_name IN VARCHAR2, p_slag_ind IN VARCHAR2, p_supervisor_seg_stf_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_hgt_unit_cd_id IN VARCHAR2, p_wgt_unit_cd_id IN VARCHAR2, p_vol_unit_cd_id IN VARCHAR2, p_parent_cntnr_seq_id IN NUMBER, p_pre_cmpctn_wgt_unit_cd_id IN VARCHAR2, p_byprodhdrs_seq_id IN NUMBER, p_db_trigger_ind IN VARCHAR2, p_part_cntnr_seq_id IN NUMBER, p_tclp_ind IN VARCHAR2, p_cntnr_proc_stat_cd_id IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_ash_volume IN NUMBER, p_ash_waste_wgt IN NUMBER, p_gross_wgt_ind IN VARCHAR2, p_compacted_ind IN VARCHAR2, p_innerpack_waste_vol IN NUMBER, p_ash_cntnr_seq_id IN NUMBER, p_original_vol IN NUMBER, p_original_wgt IN NUMBER, p_process_vol_pct IN NUMBER, p_non_processed_ind IN VARCHAR2, p_volume_processed IN NUMBER, p_wgt_processed IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

--#BODY
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
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
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

