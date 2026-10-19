-- EWT_UI fragment: AT5170
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT5170 AT_CNTNR_LAB_RESULTS_VIEW: AT_CNTNR_LAB_RESULTS_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at5170_w_at_cntnr_lab_res_b392(b_cntnr_cntnr_seq_id IN NUMBER, p_element_cd IN VARCHAR2, p_activity_amt IN NUMBER, p_activity_unit_cd_id IN VARCHAR2, p_container_id IN VARCHAR2, p_sample_id IN VARCHAR2, p_code IN VARCHAR2, p_pass_fail_ind IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_labtyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT5170 CNTNR: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5170_w_cntnr(b_cntnr_container_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_gross_wgt IN NUMBER, p_tare_wgt IN NUMBER, p_anchor_wgt IN NUMBER, p_used_vol IN NUMBER, p_void_space_amt IN NUMBER, p_description IN VARCHAR2, p_notes IN VARCHAR2, p_exterior_alpha_contam_amt IN NUMBER, p_exterior_bg_contam_amt IN NUMBER, p_exterior_contam_unit_cd_id IN VARCHAR2, p_exterior_dose_rate_amt IN NUMBER, p_exterior_dose_rate_1m_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_waste_class_cd IN VARCHAR2, p_waste_class_amt IN NUMBER, p_inc_waste_class_cd IN VARCHAR2, p_rebucket IN VARCHAR2, p_incinerator_box_nbr IN VARCHAR2, p_incinerator_factor_nbr IN NUMBER, p_density_pct IN NUMBER, p_transuranic_pct IN NUMBER, p_ra226_pct IN NUMBER, p_hazardous_cd IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_vol_unit_cd_id IN VARCHAR2, p_override_vol IN NUMBER, p_within_cntnr_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_next_prctrantyp_seq_id IN NUMBER, p_total_hgt IN NUMBER, p_used_hgt IN NUMBER, p_hgt_unit_cd_id IN VARCHAR2, p_agt_media_seq_id IN NUMBER, p_oowag_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

--#BODY
  -- AT5170 AT_CNTNR_LAB_RESULTS_VIEW: AT_CNTNR_LAB_RESULTS_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5170_w_at_cntnr_lab_res_b392(b_cntnr_cntnr_seq_id IN NUMBER, p_element_cd IN VARCHAR2, p_activity_amt IN NUMBER, p_activity_unit_cd_id IN VARCHAR2, p_container_id IN VARCHAR2, p_sample_id IN VARCHAR2, p_code IN VARCHAR2, p_pass_fail_ind IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_labtyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CNTNR_LAB_RESULTS_VIEW
 WHERE (
cntnr_seq_id = :w1 /*and
CODE = 'TCLP'*/
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN element_cd LIKE :c4 THEN 1 END WHEN element_cd = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR activity_amt = :c7)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN activity_unit_cd_id LIKE :c11 THEN 1 END WHEN activity_unit_cd_id = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN container_id LIKE :c16 THEN 1 END WHEN container_id = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN sample_id LIKE :c21 THEN 1 END WHEN sample_id = :c22 THEN 1 END) = 1)
   AND (:c23 IS NULL OR (CASE WHEN INSTR(:c24, '%') + INSTR(:c25, '_') > 0 THEN CASE WHEN code LIKE :c26 THEN 1 END WHEN code = :c27 THEN 1 END) = 1)
   AND (:c28 IS NULL OR (CASE WHEN INSTR(:c29, '%') + INSTR(:c30, '_') > 0 THEN CASE WHEN pass_fail_ind LIKE :c31 THEN 1 END WHEN pass_fail_ind = :c32 THEN 1 END) = 1)
   AND (:c33 IS NULL OR cntnr_seq_id = :c34)
   AND (:c35 IS NULL OR labtyp_seq_id = :c36)
) WHERE ROWNUM <= 5000~'
      USING b_cntnr_cntnr_seq_id, p_element_cd, p_element_cd, p_element_cd, p_element_cd, p_element_cd, p_activity_amt, p_activity_amt, p_activity_unit_cd_id, p_activity_unit_cd_id, p_activity_unit_cd_id, p_activity_unit_cd_id, p_activity_unit_cd_id, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_sample_id, p_sample_id, p_sample_id, p_sample_id, p_sample_id, p_code, p_code, p_code, p_code, p_code, p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_cntnr_seq_id, p_cntnr_seq_id, p_labtyp_seq_id, p_labtyp_seq_id;
  END;

  -- AT5170 CNTNR: AT_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5170_w_cntnr(b_cntnr_container_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_gross_wgt IN NUMBER, p_tare_wgt IN NUMBER, p_anchor_wgt IN NUMBER, p_used_vol IN NUMBER, p_void_space_amt IN NUMBER, p_description IN VARCHAR2, p_notes IN VARCHAR2, p_exterior_alpha_contam_amt IN NUMBER, p_exterior_bg_contam_amt IN NUMBER, p_exterior_contam_unit_cd_id IN VARCHAR2, p_exterior_dose_rate_amt IN NUMBER, p_exterior_dose_rate_1m_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_waste_class_cd IN VARCHAR2, p_waste_class_amt IN NUMBER, p_inc_waste_class_cd IN VARCHAR2, p_rebucket IN VARCHAR2, p_incinerator_box_nbr IN VARCHAR2, p_incinerator_factor_nbr IN NUMBER, p_density_pct IN NUMBER, p_transuranic_pct IN NUMBER, p_ra226_pct IN NUMBER, p_hazardous_cd IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_vol_unit_cd_id IN VARCHAR2, p_override_vol IN NUMBER, p_within_cntnr_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_next_prctrantyp_seq_id IN NUMBER, p_total_hgt IN NUMBER, p_used_hgt IN NUMBER, p_hgt_unit_cd_id IN VARCHAR2, p_agt_media_seq_id IN NUMBER, p_oowag_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINERS
 WHERE (
(:w1 IS NOT NULL AND NVL(TERMINAL_IND,'N') != 'Y')
)
   AND (:c1 IS NULL OR cntnr_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN container_id LIKE :c6 THEN 1 END WHEN container_id = :c7 THEN 1 END) = 1)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN cntnr_stat_cd_id LIKE :c11 THEN 1 END WHEN cntnr_stat_cd_id = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR gross_wgt = :c14)
   AND (:c15 IS NULL OR tare_wgt = :c16)
   AND (:c17 IS NULL OR anchor_wgt = :c18)
   AND (:c19 IS NULL OR used_vol = :c20)
   AND (:c21 IS NULL OR void_space_amt = :c22)
   AND (:c23 IS NULL OR (CASE WHEN INSTR(:c24, '%') + INSTR(:c25, '_') > 0 THEN CASE WHEN description LIKE :c26 THEN 1 END WHEN description = :c27 THEN 1 END) = 1)
   AND (:c28 IS NULL OR (CASE WHEN INSTR(:c29, '%') + INSTR(:c30, '_') > 0 THEN CASE WHEN notes LIKE :c31 THEN 1 END WHEN notes = :c32 THEN 1 END) = 1)
   AND (:c33 IS NULL OR exterior_alpha_contam_amt = :c34)
   AND (:c35 IS NULL OR exterior_bg_contam_amt = :c36)
   AND (:c37 IS NULL OR (CASE WHEN INSTR(:c38, '%') + INSTR(:c39, '_') > 0 THEN CASE WHEN exterior_contam_unit_cd_id LIKE :c40 THEN 1 END WHEN exterior_contam_unit_cd_id = :c41 THEN 1 END) = 1)
   AND (:c42 IS NULL OR exterior_dose_rate_amt = :c43)
   AND (:c44 IS NULL OR exterior_dose_rate_1m_amt = :c45)
   AND (:c46 IS NULL OR (CASE WHEN INSTR(:c47, '%') + INSTR(:c48, '_') > 0 THEN CASE WHEN dose_unit_cd_id LIKE :c49 THEN 1 END WHEN dose_unit_cd_id = :c50 THEN 1 END) = 1)
   AND (:c51 IS NULL OR (CASE WHEN INSTR(:c52, '%') + INSTR(:c53, '_') > 0 THEN CASE WHEN waste_class_cd LIKE :c54 THEN 1 END WHEN waste_class_cd = :c55 THEN 1 END) = 1)
   AND (:c56 IS NULL OR waste_class_amt = :c57)
   AND (:c58 IS NULL OR (CASE WHEN INSTR(:c59, '%') + INSTR(:c60, '_') > 0 THEN CASE WHEN inc_waste_class_cd LIKE :c61 THEN 1 END WHEN inc_waste_class_cd = :c62 THEN 1 END) = 1)
   AND (:c63 IS NULL OR (CASE WHEN INSTR(:c64, '%') + INSTR(:c65, '_') > 0 THEN CASE WHEN rebucket LIKE :c66 THEN 1 END WHEN rebucket = :c67 THEN 1 END) = 1)
   AND (:c68 IS NULL OR (CASE WHEN INSTR(:c69, '%') + INSTR(:c70, '_') > 0 THEN CASE WHEN incinerator_box_nbr LIKE :c71 THEN 1 END WHEN incinerator_box_nbr = :c72 THEN 1 END) = 1)
   AND (:c73 IS NULL OR incinerator_factor_nbr = :c74)
   AND (:c75 IS NULL OR density_pct = :c76)
   AND (:c77 IS NULL OR transuranic_pct = :c78)
   AND (:c79 IS NULL OR ra226_pct = :c80)
   AND (:c81 IS NULL OR (CASE WHEN INSTR(:c82, '%') + INSTR(:c83, '_') > 0 THEN CASE WHEN hazardous_cd LIKE :c84 THEN 1 END WHEN hazardous_cd = :c85 THEN 1 END) = 1)
   AND (:c86 IS NULL OR cntnr_typ_seq_id = :c87)
   AND (:c88 IS NULL OR (CASE WHEN INSTR(:c89, '%') + INSTR(:c90, '_') > 0 THEN CASE WHEN wgt_unit_cd_id LIKE :c91 THEN 1 END WHEN wgt_unit_cd_id = :c92 THEN 1 END) = 1)
   AND (:c93 IS NULL OR (CASE WHEN INSTR(:c94, '%') + INSTR(:c95, '_') > 0 THEN CASE WHEN vol_unit_cd_id LIKE :c96 THEN 1 END WHEN vol_unit_cd_id = :c97 THEN 1 END) = 1)
   AND (:c98 IS NULL OR override_vol = :c99)
   AND (:c100 IS NULL OR within_cntnr_seq_id = :c101)
   AND (:c102 IS NULL OR disp_site_seq_id = :c103)
   AND (:c104 IS NULL OR next_prctrantyp_seq_id = :c105)
   AND (:c106 IS NULL OR total_hgt = :c107)
   AND (:c108 IS NULL OR used_hgt = :c109)
   AND (:c110 IS NULL OR (CASE WHEN INSTR(:c111, '%') + INSTR(:c112, '_') > 0 THEN CASE WHEN hgt_unit_cd_id LIKE :c113 THEN 1 END WHEN hgt_unit_cd_id = :c114 THEN 1 END) = 1)
   AND (:c115 IS NULL OR agt_media_seq_id = :c116)
   AND (:c117 IS NULL OR (CASE WHEN INSTR(:c118, '%') + INSTR(:c119, '_') > 0 THEN CASE WHEN oowag_ind LIKE :c120 THEN 1 END WHEN oowag_ind = :c121 THEN 1 END) = 1)
) WHERE ROWNUM <= 5000~'
      USING b_cntnr_container_id, p_cntnr_seq_id, p_cntnr_seq_id, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_gross_wgt, p_gross_wgt, p_tare_wgt, p_tare_wgt, p_anchor_wgt, p_anchor_wgt, p_used_vol, p_used_vol, p_void_space_amt, p_void_space_amt, p_description, p_description, p_description, p_description, p_description, p_notes, p_notes, p_notes, p_notes, p_notes, p_exterior_alpha_contam_amt, p_exterior_alpha_contam_amt, p_exterior_bg_contam_amt, p_exterior_bg_contam_amt, p_exterior_contam_unit_cd_id, p_exterior_contam_unit_cd_id, p_exterior_contam_unit_cd_id, p_exterior_contam_unit_cd_id, p_exterior_contam_unit_cd_id, p_exterior_dose_rate_amt, p_exterior_dose_rate_amt, p_exterior_dose_rate_1m_amt, p_exterior_dose_rate_1m_amt, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_waste_class_cd, p_waste_class_cd, p_waste_class_cd, p_waste_class_cd, p_waste_class_cd, p_waste_class_amt, p_waste_class_amt, p_inc_waste_class_cd, p_inc_waste_class_cd, p_inc_waste_class_cd, p_inc_waste_class_cd, p_inc_waste_class_cd, p_rebucket, p_rebucket, p_rebucket, p_rebucket, p_rebucket, p_incinerator_box_nbr, p_incinerator_box_nbr, p_incinerator_box_nbr, p_incinerator_box_nbr, p_incinerator_box_nbr, p_incinerator_factor_nbr, p_incinerator_factor_nbr, p_density_pct, p_density_pct, p_transuranic_pct, p_transuranic_pct, p_ra226_pct, p_ra226_pct, p_hazardous_cd, p_hazardous_cd, p_hazardous_cd, p_hazardous_cd, p_hazardous_cd, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_vol_unit_cd_id, p_override_vol, p_override_vol, p_within_cntnr_seq_id, p_within_cntnr_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_next_prctrantyp_seq_id, p_next_prctrantyp_seq_id, p_total_hgt, p_total_hgt, p_used_hgt, p_used_hgt, p_hgt_unit_cd_id, p_hgt_unit_cd_id, p_hgt_unit_cd_id, p_hgt_unit_cd_id, p_hgt_unit_cd_id, p_agt_media_seq_id, p_agt_media_seq_id, p_oowag_ind, p_oowag_ind, p_oowag_ind, p_oowag_ind, p_oowag_ind;
  END;

