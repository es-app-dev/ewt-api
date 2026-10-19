-- EWT_UI fragment: WB3200
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- WB3200 ACTIVITY_BURNED: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_activity_burned(b_burn_incinerator_incin IN VARCHAR2, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_ibox_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_void_indicator IN VARCHAR2, p_online_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_burn_reason IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB3200 ASHBOX_ACTIVITY: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_ashbox_activity(b_ashbox_incinerator_inci_45a5 IN VARCHAR2, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_ashdrum_seq_id IN NUMBER, p_ashdrum_seq_id_secondary IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_removed_ind IN VARCHAR2, p_ash_sequence IN NUMBER, p_incinerator_id IN VARCHAR2, p_online_status IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB3200 BURNED: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_burned(b_ashbox_incinerator_inci_45a5 IN VARCHAR2, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_ibox_seq_id IN NUMBER, p_ashdrum_seq_id IN NUMBER, p_ashdrum_seq_id_secondary IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_void_indicator IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_ash_sequence IN NUMBER, p_incinerator_id IN VARCHAR2, p_removed_ind IN VARCHAR2, p_online_status IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB3200 BURN_ACTIVITY_VIEW: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_burn_activity_view(b_burn_incinerator_incin IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_online_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_burn_reason IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB3200 LOAD_IBOX: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_load_ibox(b_at$ctrl_incinerator_id IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_online_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB3200 SUMMARY: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_summary(b_at$ctrl_incin_summary IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_incinerator_id IN VARCHAR2, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_void_indicator IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB3200 WB_ASHDRUM1: WB_ASHDRUM with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_wb_ashdrum1(b_at$ctrl_incinerator_id IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_ashdrum_seq_id IN NUMBER, p_ashdrum_barcode IN VARCHAR2, p_empty_wt IN NUMBER, p_full_wt IN NUMBER, p_waste_wt IN NUMBER, p_final_void IN NUMBER, p_dose_rate IN NUMBER, p_dose_rate_30cm IN NUMBER, p_dose_unit IN VARCHAR2, p_sample_amt IN NUMBER, p_sample_unit IN VARCHAR2, p_sample_reason IN VARCHAR2, p_comments IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB3200 WB_ASHDRUM2: WB_ASHDRUM with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3200_w_wb_ashdrum2(b_at$ctrl_incinerator_id IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_ashdrum_seq_id IN NUMBER, p_ashdrum_barcode IN VARCHAR2, p_empty_wt IN NUMBER, p_full_wt IN NUMBER, p_waste_wt IN NUMBER, p_final_void IN NUMBER, p_dose_rate IN NUMBER, p_dose_rate_30cm IN NUMBER, p_dose_unit IN VARCHAR2, p_sample_amt IN NUMBER, p_sample_unit IN VARCHAR2, p_sample_reason IN VARCHAR2, p_comments IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

--#BODY
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- WB3200 ACTIVITY_BURNED: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_activity_burned(b_burn_incinerator_incin IN VARCHAR2, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_ibox_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_void_indicator IN VARCHAR2, p_online_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_burn_reason IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_IBOX_CONTAINERS
 WHERE (
INCINERATION_STATUS='BURN' AND SORT_STATUS='EMPTY' AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR empty_wgt = :c2)
   AND (:c3 IS NULL OR full_wgt = :c4)
   AND (:c5 IS NULL OR ibox_seq_id = :c6)
   AND (:c7 IS NULL OR sequence = :c8)
   AND (:c9 IS NULL OR (CASE WHEN INSTR(:c10, '%') + INSTR(:c11, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c12 THEN 1 END WHEN ibox_barcode = :c13 THEN 1 END) = 1)
   AND (:c14 IS NULL OR (CASE WHEN INSTR(:c15, '%') + INSTR(:c16, '_') > 0 THEN CASE WHEN ibox_nbr LIKE :c17 THEN 1 END WHEN ibox_nbr = :c18 THEN 1 END) = 1)
   AND (:c19 IS NULL OR total_activity = :c20)
   AND (:c21 IS NULL OR proj_ash_wgt = :c22)
   AND (:c23 IS NULL OR proj_ash_uncomp_volume = :c24)
   AND (:c25 IS NULL OR (CASE WHEN INSTR(:c26, '%') + INSTR(:c27, '_') > 0 THEN CASE WHEN proj_waste_class LIKE :c28 THEN 1 END WHEN proj_waste_class = :c29 THEN 1 END) = 1)
   AND (:c30 IS NULL OR (CASE WHEN INSTR(:c31, '%') + INSTR(:c32, '_') > 0 THEN CASE WHEN incineration_status LIKE :c33 THEN 1 END WHEN incineration_status = :c34 THEN 1 END) = 1)
   AND (:c35 IS NULL OR (CASE WHEN INSTR(:c36, '%') + INSTR(:c37, '_') > 0 THEN CASE WHEN sort_status LIKE :c38 THEN 1 END WHEN sort_status = :c39 THEN 1 END) = 1)
   AND (:c40 IS NULL OR (CASE WHEN INSTR(:c41, '%') + INSTR(:c42, '_') > 0 THEN CASE WHEN void_indicator LIKE :c43 THEN 1 END WHEN void_indicator = :c44 THEN 1 END) = 1)
   AND (:c45 IS NULL OR (CASE WHEN INSTR(:c46, '%') + INSTR(:c47, '_') > 0 THEN CASE WHEN online_status LIKE :c48 THEN 1 END WHEN online_status = :c49 THEN 1 END) = 1)
   AND (:c50 IS NULL OR cust_seq_id = :c51)
   AND (:c52 IS NULL OR disp_site_seq_id = :c53)
   AND (:c54 IS NULL OR advnotif_seq_id = :c55)
   AND (:c56 IS NULL OR (CASE WHEN INSTR(:c57, '%') + INSTR(:c58, '_') > 0 THEN CASE WHEN burn_reason LIKE :c59 THEN 1 END WHEN burn_reason = :c60 THEN 1 END) = 1)
 ORDER BY BURN_DT ASC
) WHERE ROWNUM <= 5000~'
      USING b_burn_incinerator_incin, p_empty_wgt, p_empty_wgt, p_full_wgt, p_full_wgt, p_ibox_seq_id, p_ibox_seq_id, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_total_activity, p_total_activity, p_proj_ash_wgt, p_proj_ash_wgt, p_proj_ash_uncomp_volume, p_proj_ash_uncomp_volume, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_void_indicator, p_void_indicator, p_void_indicator, p_void_indicator, p_void_indicator, p_online_status, p_online_status, p_online_status, p_online_status, p_online_status, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_burn_reason, p_burn_reason, p_burn_reason, p_burn_reason, p_burn_reason;
  END;

  -- WB3200 ASHBOX_ACTIVITY: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_ashbox_activity(b_ashbox_incinerator_inci_45a5 IN VARCHAR2, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_ashdrum_seq_id IN NUMBER, p_ashdrum_seq_id_secondary IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_removed_ind IN VARCHAR2, p_ash_sequence IN NUMBER, p_incinerator_id IN VARCHAR2, p_online_status IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM wb_ibox_containers
 WHERE (
SORT_STATUS='EMPTY' AND INCINERATION_STATUS='BURN' AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR empty_wgt = :c2)
   AND (:c3 IS NULL OR full_wgt = :c4)
   AND (:c5 IS NULL OR ashdrum_seq_id = :c6)
   AND (:c7 IS NULL OR ashdrum_seq_id_secondary = :c8)
   AND (:c9 IS NULL OR sequence = :c10)
   AND (:c11 IS NULL OR (CASE WHEN INSTR(:c12, '%') + INSTR(:c13, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c14 THEN 1 END WHEN ibox_barcode = :c15 THEN 1 END) = 1)
   AND (:c16 IS NULL OR (CASE WHEN INSTR(:c17, '%') + INSTR(:c18, '_') > 0 THEN CASE WHEN ibox_nbr LIKE :c19 THEN 1 END WHEN ibox_nbr = :c20 THEN 1 END) = 1)
   AND (:c21 IS NULL OR total_activity = :c22)
   AND (:c23 IS NULL OR proj_ash_wgt = :c24)
   AND (:c25 IS NULL OR proj_ash_uncomp_volume = :c26)
   AND (:c27 IS NULL OR (CASE WHEN INSTR(:c28, '%') + INSTR(:c29, '_') > 0 THEN CASE WHEN proj_waste_class LIKE :c30 THEN 1 END WHEN proj_waste_class = :c31 THEN 1 END) = 1)
   AND (:c32 IS NULL OR (CASE WHEN INSTR(:c33, '%') + INSTR(:c34, '_') > 0 THEN CASE WHEN incineration_status LIKE :c35 THEN 1 END WHEN incineration_status = :c36 THEN 1 END) = 1)
   AND (:c37 IS NULL OR (CASE WHEN INSTR(:c38, '%') + INSTR(:c39, '_') > 0 THEN CASE WHEN sort_status LIKE :c40 THEN 1 END WHEN sort_status = :c41 THEN 1 END) = 1)
   AND (:c42 IS NULL OR ibox_seq_id = :c43)
   AND (:c44 IS NULL OR cust_seq_id = :c45)
   AND (:c46 IS NULL OR disp_site_seq_id = :c47)
   AND (:c48 IS NULL OR advnotif_seq_id = :c49)
   AND (:c50 IS NULL OR (CASE WHEN INSTR(:c51, '%') + INSTR(:c52, '_') > 0 THEN CASE WHEN removed_ind LIKE :c53 THEN 1 END WHEN removed_ind = :c54 THEN 1 END) = 1)
   AND (:c55 IS NULL OR ash_sequence = :c56)
   AND (:c57 IS NULL OR (CASE WHEN INSTR(:c58, '%') + INSTR(:c59, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c60 THEN 1 END WHEN incinerator_id = :c61 THEN 1 END) = 1)
   AND (:c62 IS NULL OR (CASE WHEN INSTR(:c63, '%') + INSTR(:c64, '_') > 0 THEN CASE WHEN online_status LIKE :c65 THEN 1 END WHEN online_status = :c66 THEN 1 END) = 1)
 ORDER BY BURN_DT ASC
) WHERE ROWNUM <= 5000~'
      USING b_ashbox_incinerator_inci_45a5, p_empty_wgt, p_empty_wgt, p_full_wgt, p_full_wgt, p_ashdrum_seq_id, p_ashdrum_seq_id, p_ashdrum_seq_id_secondary, p_ashdrum_seq_id_secondary, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_total_activity, p_total_activity, p_proj_ash_wgt, p_proj_ash_wgt, p_proj_ash_uncomp_volume, p_proj_ash_uncomp_volume, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_ibox_seq_id, p_ibox_seq_id, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_removed_ind, p_removed_ind, p_removed_ind, p_removed_ind, p_removed_ind, p_ash_sequence, p_ash_sequence, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_online_status, p_online_status, p_online_status, p_online_status, p_online_status;
  END;

  -- WB3200 BURNED: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_burned(b_ashbox_incinerator_inci_45a5 IN VARCHAR2, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_ibox_seq_id IN NUMBER, p_ashdrum_seq_id IN NUMBER, p_ashdrum_seq_id_secondary IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_void_indicator IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_ash_sequence IN NUMBER, p_incinerator_id IN VARCHAR2, p_removed_ind IN VARCHAR2, p_online_status IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM wb_ibox_containers
 WHERE (
SORT_STATUS='EMPTY' AND INCINERATION_STATUS='ASH'  AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR empty_wgt = :c2)
   AND (:c3 IS NULL OR full_wgt = :c4)
   AND (:c5 IS NULL OR ibox_seq_id = :c6)
   AND (:c7 IS NULL OR ashdrum_seq_id = :c8)
   AND (:c9 IS NULL OR ashdrum_seq_id_secondary = :c10)
   AND (:c11 IS NULL OR sequence = :c12)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c16 THEN 1 END WHEN ibox_barcode = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN ibox_nbr LIKE :c21 THEN 1 END WHEN ibox_nbr = :c22 THEN 1 END) = 1)
   AND (:c23 IS NULL OR total_activity = :c24)
   AND (:c25 IS NULL OR proj_ash_wgt = :c26)
   AND (:c27 IS NULL OR proj_ash_uncomp_volume = :c28)
   AND (:c29 IS NULL OR (CASE WHEN INSTR(:c30, '%') + INSTR(:c31, '_') > 0 THEN CASE WHEN proj_waste_class LIKE :c32 THEN 1 END WHEN proj_waste_class = :c33 THEN 1 END) = 1)
   AND (:c34 IS NULL OR (CASE WHEN INSTR(:c35, '%') + INSTR(:c36, '_') > 0 THEN CASE WHEN incineration_status LIKE :c37 THEN 1 END WHEN incineration_status = :c38 THEN 1 END) = 1)
   AND (:c39 IS NULL OR (CASE WHEN INSTR(:c40, '%') + INSTR(:c41, '_') > 0 THEN CASE WHEN sort_status LIKE :c42 THEN 1 END WHEN sort_status = :c43 THEN 1 END) = 1)
   AND (:c44 IS NULL OR (CASE WHEN INSTR(:c45, '%') + INSTR(:c46, '_') > 0 THEN CASE WHEN void_indicator LIKE :c47 THEN 1 END WHEN void_indicator = :c48 THEN 1 END) = 1)
   AND (:c49 IS NULL OR cust_seq_id = :c50)
   AND (:c51 IS NULL OR disp_site_seq_id = :c52)
   AND (:c53 IS NULL OR advnotif_seq_id = :c54)
   AND (:c55 IS NULL OR ash_sequence = :c56)
   AND (:c57 IS NULL OR (CASE WHEN INSTR(:c58, '%') + INSTR(:c59, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c60 THEN 1 END WHEN incinerator_id = :c61 THEN 1 END) = 1)
   AND (:c62 IS NULL OR (CASE WHEN INSTR(:c63, '%') + INSTR(:c64, '_') > 0 THEN CASE WHEN removed_ind LIKE :c65 THEN 1 END WHEN removed_ind = :c66 THEN 1 END) = 1)
   AND (:c67 IS NULL OR (CASE WHEN INSTR(:c68, '%') + INSTR(:c69, '_') > 0 THEN CASE WHEN online_status LIKE :c70 THEN 1 END WHEN online_status = :c71 THEN 1 END) = 1)
 ORDER BY ASH_DT
) WHERE ROWNUM <= 5000~'
      USING b_ashbox_incinerator_inci_45a5, p_empty_wgt, p_empty_wgt, p_full_wgt, p_full_wgt, p_ibox_seq_id, p_ibox_seq_id, p_ashdrum_seq_id, p_ashdrum_seq_id, p_ashdrum_seq_id_secondary, p_ashdrum_seq_id_secondary, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_total_activity, p_total_activity, p_proj_ash_wgt, p_proj_ash_wgt, p_proj_ash_uncomp_volume, p_proj_ash_uncomp_volume, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_void_indicator, p_void_indicator, p_void_indicator, p_void_indicator, p_void_indicator, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_ash_sequence, p_ash_sequence, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_removed_ind, p_removed_ind, p_removed_ind, p_removed_ind, p_removed_ind, p_online_status, p_online_status, p_online_status, p_online_status, p_online_status;
  END;

  -- WB3200 BURN_ACTIVITY_VIEW: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_burn_activity_view(b_burn_incinerator_incin IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_online_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_burn_reason IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_IBOX_CONTAINERS
 WHERE (
SORT_STATUS = 'ON-LINE' AND INCINERATION_STATUS = 'ON-LINE' AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR ibox_seq_id = :c2)
   AND (:c3 IS NULL OR sequence = :c4)
   AND (:c5 IS NULL OR (CASE WHEN INSTR(:c6, '%') + INSTR(:c7, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c8 THEN 1 END WHEN ibox_barcode = :c9 THEN 1 END) = 1)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN ibox_nbr LIKE :c13 THEN 1 END WHEN ibox_nbr = :c14 THEN 1 END) = 1)
   AND (:c15 IS NULL OR total_activity = :c16)
   AND (:c17 IS NULL OR proj_ash_wgt = :c18)
   AND (:c19 IS NULL OR proj_ash_uncomp_volume = :c20)
   AND (:c21 IS NULL OR (CASE WHEN INSTR(:c22, '%') + INSTR(:c23, '_') > 0 THEN CASE WHEN proj_waste_class LIKE :c24 THEN 1 END WHEN proj_waste_class = :c25 THEN 1 END) = 1)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN incineration_status LIKE :c29 THEN 1 END WHEN incineration_status = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR (CASE WHEN INSTR(:c32, '%') + INSTR(:c33, '_') > 0 THEN CASE WHEN sort_status LIKE :c34 THEN 1 END WHEN sort_status = :c35 THEN 1 END) = 1)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN online_status LIKE :c39 THEN 1 END WHEN online_status = :c40 THEN 1 END) = 1)
   AND (:c41 IS NULL OR cust_seq_id = :c42)
   AND (:c43 IS NULL OR disp_site_seq_id = :c44)
   AND (:c45 IS NULL OR advnotif_seq_id = :c46)
   AND (:c47 IS NULL OR empty_wgt = :c48)
   AND (:c49 IS NULL OR full_wgt = :c50)
   AND (:c51 IS NULL OR (CASE WHEN INSTR(:c52, '%') + INSTR(:c53, '_') > 0 THEN CASE WHEN burn_reason LIKE :c54 THEN 1 END WHEN burn_reason = :c55 THEN 1 END) = 1)
 ORDER BY SEQUENCE
) WHERE ROWNUM <= 5000~'
      USING b_burn_incinerator_incin, p_ibox_seq_id, p_ibox_seq_id, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_total_activity, p_total_activity, p_proj_ash_wgt, p_proj_ash_wgt, p_proj_ash_uncomp_volume, p_proj_ash_uncomp_volume, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_online_status, p_online_status, p_online_status, p_online_status, p_online_status, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_empty_wgt, p_empty_wgt, p_full_wgt, p_full_wgt, p_burn_reason, p_burn_reason, p_burn_reason, p_burn_reason, p_burn_reason;
  END;

  -- WB3200 LOAD_IBOX: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_load_ibox(b_at$ctrl_incinerator_id IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_online_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM wb_ibox_containers
 WHERE (
INCINERATION_STATUS = 'ON-LINE' AND SORT_STATUS='ON-LINE' AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c4 THEN 1 END WHEN incinerator_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR ibox_seq_id = :c7)
   AND (:c8 IS NULL OR sequence = :c9)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c13 THEN 1 END WHEN ibox_barcode = :c14 THEN 1 END) = 1)
   AND (:c15 IS NULL OR total_activity = :c16)
   AND (:c17 IS NULL OR proj_ash_wgt = :c18)
   AND (:c19 IS NULL OR proj_ash_uncomp_volume = :c20)
   AND (:c21 IS NULL OR (CASE WHEN INSTR(:c22, '%') + INSTR(:c23, '_') > 0 THEN CASE WHEN proj_waste_class LIKE :c24 THEN 1 END WHEN proj_waste_class = :c25 THEN 1 END) = 1)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN incineration_status LIKE :c29 THEN 1 END WHEN incineration_status = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR (CASE WHEN INSTR(:c32, '%') + INSTR(:c33, '_') > 0 THEN CASE WHEN sort_status LIKE :c34 THEN 1 END WHEN sort_status = :c35 THEN 1 END) = 1)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN online_status LIKE :c39 THEN 1 END WHEN online_status = :c40 THEN 1 END) = 1)
   AND (:c41 IS NULL OR cust_seq_id = :c42)
   AND (:c43 IS NULL OR disp_site_seq_id = :c44)
 ORDER BY SEQUENCE DESC
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_ibox_seq_id, p_ibox_seq_id, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_total_activity, p_total_activity, p_proj_ash_wgt, p_proj_ash_wgt, p_proj_ash_uncomp_volume, p_proj_ash_uncomp_volume, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_online_status, p_online_status, p_online_status, p_online_status, p_online_status, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id;
  END;

  -- WB3200 SUMMARY: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_summary(b_at$ctrl_incin_summary IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_incinerator_id IN VARCHAR2, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_total_activity IN NUMBER, p_proj_ash_wgt IN NUMBER, p_proj_ash_uncomp_volume IN NUMBER, p_proj_waste_class IN VARCHAR2, p_incineration_status IN VARCHAR2, p_sort_status IN VARCHAR2, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_empty_wgt IN NUMBER, p_full_wgt IN NUMBER, p_void_indicator IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM wb_ibox_containers
 WHERE (
SORT_STATUS='EMPTY' AND INCINERATION_STATUS='ASH'  AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR ibox_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c6 THEN 1 END WHEN incinerator_id = :c7 THEN 1 END) = 1)
   AND (:c8 IS NULL OR sequence = :c9)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c13 THEN 1 END WHEN ibox_barcode = :c14 THEN 1 END) = 1)
   AND (:c15 IS NULL OR (CASE WHEN INSTR(:c16, '%') + INSTR(:c17, '_') > 0 THEN CASE WHEN ibox_nbr LIKE :c18 THEN 1 END WHEN ibox_nbr = :c19 THEN 1 END) = 1)
   AND (:c20 IS NULL OR total_activity = :c21)
   AND (:c22 IS NULL OR proj_ash_wgt = :c23)
   AND (:c24 IS NULL OR proj_ash_uncomp_volume = :c25)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN proj_waste_class LIKE :c29 THEN 1 END WHEN proj_waste_class = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR (CASE WHEN INSTR(:c32, '%') + INSTR(:c33, '_') > 0 THEN CASE WHEN incineration_status LIKE :c34 THEN 1 END WHEN incineration_status = :c35 THEN 1 END) = 1)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN sort_status LIKE :c39 THEN 1 END WHEN sort_status = :c40 THEN 1 END) = 1)
   AND (:c41 IS NULL OR cust_seq_id = :c42)
   AND (:c43 IS NULL OR disp_site_seq_id = :c44)
   AND (:c45 IS NULL OR advnotif_seq_id = :c46)
   AND (:c47 IS NULL OR empty_wgt = :c48)
   AND (:c49 IS NULL OR full_wgt = :c50)
   AND (:c51 IS NULL OR (CASE WHEN INSTR(:c52, '%') + INSTR(:c53, '_') > 0 THEN CASE WHEN void_indicator LIKE :c54 THEN 1 END WHEN void_indicator = :c55 THEN 1 END) = 1)
   AND (:c56 IS NULL OR cntnr_typ_seq_id = :c57)
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_incin_summary, p_ibox_seq_id, p_ibox_seq_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_total_activity, p_total_activity, p_proj_ash_wgt, p_proj_ash_wgt, p_proj_ash_uncomp_volume, p_proj_ash_uncomp_volume, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_proj_waste_class, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_incineration_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_empty_wgt, p_empty_wgt, p_full_wgt, p_full_wgt, p_void_indicator, p_void_indicator, p_void_indicator, p_void_indicator, p_void_indicator, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id;
  END;

  -- WB3200 WB_ASHDRUM1: WB_ASHDRUM with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_wb_ashdrum1(b_at$ctrl_incinerator_id IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_ashdrum_seq_id IN NUMBER, p_ashdrum_barcode IN VARCHAR2, p_empty_wt IN NUMBER, p_full_wt IN NUMBER, p_waste_wt IN NUMBER, p_final_void IN NUMBER, p_dose_rate IN NUMBER, p_dose_rate_30cm IN NUMBER, p_dose_unit IN VARCHAR2, p_sample_amt IN NUMBER, p_sample_unit IN VARCHAR2, p_sample_reason IN VARCHAR2, p_comments IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM wb_ashdrum
 WHERE (
ASHDRUM_SEQ_ID = (SELECT MIN(ASHDRUM_SEQ_ID) FROM WB_ASHDRUM WHERE ACTIVE_INDICATOR='Y' AND INCINERATOR_ID=:w1)
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c4 THEN 1 END WHEN incinerator_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR ashdrum_seq_id = :c7)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN ashdrum_barcode LIKE :c11 THEN 1 END WHEN ashdrum_barcode = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR empty_wt = :c14)
   AND (:c15 IS NULL OR full_wt = :c16)
   AND (:c17 IS NULL OR waste_wt = :c18)
   AND (:c19 IS NULL OR final_void = :c20)
   AND (:c21 IS NULL OR dose_rate = :c22)
   AND (:c23 IS NULL OR dose_rate_30cm = :c24)
   AND (:c25 IS NULL OR (CASE WHEN INSTR(:c26, '%') + INSTR(:c27, '_') > 0 THEN CASE WHEN dose_unit LIKE :c28 THEN 1 END WHEN dose_unit = :c29 THEN 1 END) = 1)
   AND (:c30 IS NULL OR sample_amt = :c31)
   AND (:c32 IS NULL OR (CASE WHEN INSTR(:c33, '%') + INSTR(:c34, '_') > 0 THEN CASE WHEN sample_unit LIKE :c35 THEN 1 END WHEN sample_unit = :c36 THEN 1 END) = 1)
   AND (:c37 IS NULL OR (CASE WHEN INSTR(:c38, '%') + INSTR(:c39, '_') > 0 THEN CASE WHEN sample_reason LIKE :c40 THEN 1 END WHEN sample_reason = :c41 THEN 1 END) = 1)
   AND (:c42 IS NULL OR (CASE WHEN INSTR(:c43, '%') + INSTR(:c44, '_') > 0 THEN CASE WHEN comments LIKE :c45 THEN 1 END WHEN comments = :c46 THEN 1 END) = 1)
   AND (:c47 IS NULL OR cntnr_typ_seq_id = :c48)
   AND (:c49 IS NULL OR prctrantyp_seq_id = :c50)
   AND (:c51 IS NULL OR prodserv_seq_id = :c52)
   AND (:c53 IS NULL OR disp_site_seq_id = :c54)
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_ashdrum_seq_id, p_ashdrum_seq_id, p_ashdrum_barcode, p_ashdrum_barcode, p_ashdrum_barcode, p_ashdrum_barcode, p_ashdrum_barcode, p_empty_wt, p_empty_wt, p_full_wt, p_full_wt, p_waste_wt, p_waste_wt, p_final_void, p_final_void, p_dose_rate, p_dose_rate, p_dose_rate_30cm, p_dose_rate_30cm, p_dose_unit, p_dose_unit, p_dose_unit, p_dose_unit, p_dose_unit, p_sample_amt, p_sample_amt, p_sample_unit, p_sample_unit, p_sample_unit, p_sample_unit, p_sample_unit, p_sample_reason, p_sample_reason, p_sample_reason, p_sample_reason, p_sample_reason, p_comments, p_comments, p_comments, p_comments, p_comments, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id, p_prctrantyp_seq_id, p_prctrantyp_seq_id, p_prodserv_seq_id, p_prodserv_seq_id, p_disp_site_seq_id, p_disp_site_seq_id;
  END;

  -- WB3200 WB_ASHDRUM2: WB_ASHDRUM with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3200_w_wb_ashdrum2(b_at$ctrl_incinerator_id IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_ashdrum_seq_id IN NUMBER, p_ashdrum_barcode IN VARCHAR2, p_empty_wt IN NUMBER, p_full_wt IN NUMBER, p_waste_wt IN NUMBER, p_final_void IN NUMBER, p_dose_rate IN NUMBER, p_dose_rate_30cm IN NUMBER, p_dose_unit IN VARCHAR2, p_sample_amt IN NUMBER, p_sample_unit IN VARCHAR2, p_sample_reason IN VARCHAR2, p_comments IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM wb_ashdrum
 WHERE (
ASHDRUM_SEQ_ID = (SELECT MAX(ASHDRUM_SEQ_ID) FROM WB_ASHDRUM WHERE ACTIVE_INDICATOR='Y' AND INCINERATOR_ID=:w1)
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c4 THEN 1 END WHEN incinerator_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR ashdrum_seq_id = :c7)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN ashdrum_barcode LIKE :c11 THEN 1 END WHEN ashdrum_barcode = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR empty_wt = :c14)
   AND (:c15 IS NULL OR full_wt = :c16)
   AND (:c17 IS NULL OR waste_wt = :c18)
   AND (:c19 IS NULL OR final_void = :c20)
   AND (:c21 IS NULL OR dose_rate = :c22)
   AND (:c23 IS NULL OR dose_rate_30cm = :c24)
   AND (:c25 IS NULL OR (CASE WHEN INSTR(:c26, '%') + INSTR(:c27, '_') > 0 THEN CASE WHEN dose_unit LIKE :c28 THEN 1 END WHEN dose_unit = :c29 THEN 1 END) = 1)
   AND (:c30 IS NULL OR sample_amt = :c31)
   AND (:c32 IS NULL OR (CASE WHEN INSTR(:c33, '%') + INSTR(:c34, '_') > 0 THEN CASE WHEN sample_unit LIKE :c35 THEN 1 END WHEN sample_unit = :c36 THEN 1 END) = 1)
   AND (:c37 IS NULL OR (CASE WHEN INSTR(:c38, '%') + INSTR(:c39, '_') > 0 THEN CASE WHEN sample_reason LIKE :c40 THEN 1 END WHEN sample_reason = :c41 THEN 1 END) = 1)
   AND (:c42 IS NULL OR (CASE WHEN INSTR(:c43, '%') + INSTR(:c44, '_') > 0 THEN CASE WHEN comments LIKE :c45 THEN 1 END WHEN comments = :c46 THEN 1 END) = 1)
   AND (:c47 IS NULL OR cntnr_typ_seq_id = :c48)
   AND (:c49 IS NULL OR prctrantyp_seq_id = :c50)
   AND (:c51 IS NULL OR prodserv_seq_id = :c52)
   AND (:c53 IS NULL OR disp_site_seq_id = :c54)
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_ashdrum_seq_id, p_ashdrum_seq_id, p_ashdrum_barcode, p_ashdrum_barcode, p_ashdrum_barcode, p_ashdrum_barcode, p_ashdrum_barcode, p_empty_wt, p_empty_wt, p_full_wt, p_full_wt, p_waste_wt, p_waste_wt, p_final_void, p_final_void, p_dose_rate, p_dose_rate, p_dose_rate_30cm, p_dose_rate_30cm, p_dose_unit, p_dose_unit, p_dose_unit, p_dose_unit, p_dose_unit, p_sample_amt, p_sample_amt, p_sample_unit, p_sample_unit, p_sample_unit, p_sample_unit, p_sample_unit, p_sample_reason, p_sample_reason, p_sample_reason, p_sample_reason, p_sample_reason, p_comments, p_comments, p_comments, p_comments, p_comments, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id, p_prctrantyp_seq_id, p_prctrantyp_seq_id, p_prodserv_seq_id, p_prodserv_seq_id, p_disp_site_seq_id, p_disp_site_seq_id;
  END;
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

