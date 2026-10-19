-- EWT_UI fragment: AT1510
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT1510 AT_CPS_VIEW: AT_CNPRODSERV_VIEW3@ATCORP.ENERGYSOLUTIONS.COM with the block's own WHERE; one optional criterion per column
  PROCEDURE at1510_w_at_cps_view(b_mnfst_cust_seq_id IN NUMBER, b_mnfst_advnotif_expected_e379 IN DATE, b_mnfst_es_prof_seq_id IN NUMBER, b_mnfst_disp_site_seq_id IN NUMBER, p_cntrct_contract_nbr IN VARCHAR2, p_cntrct_mod_cntrct_id IN NUMBER, p_cnprodserv_seq_id IN NUMBER, p_prodserv_cd IN VARCHAR2, p_prodserv_descr IN VARCHAR2, p_dispsite_alias IN VARCHAR2, p_cnprodserv_cost IN NUMBER, p_cnprodserv_unit_cd_id IN VARCHAR2, p_cnprodserv_descr IN VARCHAR2, p_cnprodserv_cust_seq_id IN NUMBER, p_prodserv_prodcat_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_group_nbr IN VARCHAR2, p_subgroup_nbr IN VARCHAR2, p_disposal_revenue_ind IN VARCHAR2, p_certification_prog_ind IN VARCHAR2, p_life_of_plant_ind IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_tax_included_ind IN VARCHAR2, p_dispsite_code IN VARCHAR2, p_min_charge IN NUMBER, p_seg_resp_dept_nm IN VARCHAR2, p_contract_line_nbr IN VARCHAR2, p_prodcat_descr IN VARCHAR2, p_classified_ind IN VARCHAR2, p_prof_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT1510 AT_INVOICES: AT_INVOICES with the block's own WHERE; one optional criterion per column
  PROCEDURE at1510_w_at_invoices(b_mnfst_advnotif_seq_id IN NUMBER, p_invoice_nbr IN VARCHAR2, p_invoice_type_cd IN VARCHAR2, p_invoice_category_cd IN VARCHAR2, p_invc_seq_id IN NUMBER, p_invoice_loc_cd IN VARCHAR2, p_ship_to_cust_seq_id IN NUMBER, p_charge_to_cust_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_face_sheeted IN VARCHAR2, p_notes IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_terms IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT1510 RNCNTNRS: AT_RENTAL_CNTNR_SHIPMENTS_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at1510_w_rncntnrs(p_rental_container_id IN VARCHAR2, p_rncntnrstat_cd_id IN VARCHAR2, p_seg_owned_ind IN VARCHAR2, p_out_shipment_nbr IN VARCHAR2, p_shipment_type_cd IN VARCHAR2, p_consignee_cust_seq_id IN NUMBER, p_pick_up_cust_seq_id IN NUMBER, p_rncntnr_seq_id IN NUMBER, p_segordlitm_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT1510 DISP_SITE_LV (record group DISP_SITE_RG); not OData: a subquery in WHERE
  PROCEDURE at1510_lov_disp_site_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1510 PROFILE_LV (record group PROFILE_RG); not OData: could not read the query (expected ) at "+ 1 ) <")
  PROCEDURE at1510_lov_profile_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY


  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT1510 AT_CPS_VIEW: AT_CNPRODSERV_VIEW3@ATCORP.ENERGYSOLUTIONS.COM with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1510_w_at_cps_view(b_mnfst_cust_seq_id IN NUMBER, b_mnfst_advnotif_expected_e379 IN DATE, b_mnfst_es_prof_seq_id IN NUMBER, b_mnfst_disp_site_seq_id IN NUMBER, p_cntrct_contract_nbr IN VARCHAR2, p_cntrct_mod_cntrct_id IN NUMBER, p_cnprodserv_seq_id IN NUMBER, p_prodserv_cd IN VARCHAR2, p_prodserv_descr IN VARCHAR2, p_dispsite_alias IN VARCHAR2, p_cnprodserv_cost IN NUMBER, p_cnprodserv_unit_cd_id IN VARCHAR2, p_cnprodserv_descr IN VARCHAR2, p_cnprodserv_cust_seq_id IN NUMBER, p_prodserv_prodcat_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_group_nbr IN VARCHAR2, p_subgroup_nbr IN VARCHAR2, p_disposal_revenue_ind IN VARCHAR2, p_certification_prog_ind IN VARCHAR2, p_life_of_plant_ind IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_tax_included_ind IN VARCHAR2, p_dispsite_code IN VARCHAR2, p_min_charge IN NUMBER, p_seg_resp_dept_nm IN VARCHAR2, p_contract_line_nbr IN VARCHAR2, p_prodcat_descr IN VARCHAR2, p_classified_ind IN VARCHAR2, p_prof_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM at_cnprodserv_view3@atcorp.energysolutions.com
 WHERE (
           cntrct_mod_cntrct_id =
               get_max_mod4@atcorp.energysolutions.com(cntrct_contract_nbr
                                                      , :w1
                                                      ,NVL( :w2, SYSDATE))
       AND cnprodserv_cust_seq_id = :w3
       AND prof_seq_id = NVL( :w4, prof_seq_id)
       AND disp_site_seq_id = NVL( :w5, disp_site_seq_id)
       AND NVL(subgroup_nbr, 0) = 0
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN cntrct_contract_nbr LIKE :c4 THEN 1 END WHEN cntrct_contract_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR cntrct_mod_cntrct_id = :c7)
   AND (:c8 IS NULL OR cnprodserv_seq_id = :c9)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN prodserv_cd LIKE :c13 THEN 1 END WHEN prodserv_cd = :c14 THEN 1 END) = 1)
   AND (:c15 IS NULL OR (CASE WHEN INSTR(:c16, '%') + INSTR(:c17, '_') > 0 THEN CASE WHEN prodserv_descr LIKE :c18 THEN 1 END WHEN prodserv_descr = :c19 THEN 1 END) = 1)
   AND (:c20 IS NULL OR (CASE WHEN INSTR(:c21, '%') + INSTR(:c22, '_') > 0 THEN CASE WHEN dispsite_alias LIKE :c23 THEN 1 END WHEN dispsite_alias = :c24 THEN 1 END) = 1)
   AND (:c25 IS NULL OR cnprodserv_cost = :c26)
   AND (:c27 IS NULL OR (CASE WHEN INSTR(:c28, '%') + INSTR(:c29, '_') > 0 THEN CASE WHEN cnprodserv_unit_cd_id LIKE :c30 THEN 1 END WHEN cnprodserv_unit_cd_id = :c31 THEN 1 END) = 1)
   AND (:c32 IS NULL OR (CASE WHEN INSTR(:c33, '%') + INSTR(:c34, '_') > 0 THEN CASE WHEN cnprodserv_descr LIKE :c35 THEN 1 END WHEN cnprodserv_descr = :c36 THEN 1 END) = 1)
   AND (:c37 IS NULL OR cnprodserv_cust_seq_id = :c38)
   AND (:c39 IS NULL OR prodserv_prodcat_seq_id = :c40)
   AND (:c41 IS NULL OR prodserv_seq_id = :c42)
   AND (:c43 IS NULL OR (CASE WHEN INSTR(:c44, '%') + INSTR(:c45, '_') > 0 THEN CASE WHEN group_nbr LIKE :c46 THEN 1 END WHEN group_nbr = :c47 THEN 1 END) = 1)
   AND (:c48 IS NULL OR (CASE WHEN INSTR(:c49, '%') + INSTR(:c50, '_') > 0 THEN CASE WHEN subgroup_nbr LIKE :c51 THEN 1 END WHEN subgroup_nbr = :c52 THEN 1 END) = 1)
   AND (:c53 IS NULL OR (CASE WHEN INSTR(:c54, '%') + INSTR(:c55, '_') > 0 THEN CASE WHEN disposal_revenue_ind LIKE :c56 THEN 1 END WHEN disposal_revenue_ind = :c57 THEN 1 END) = 1)
   AND (:c58 IS NULL OR (CASE WHEN INSTR(:c59, '%') + INSTR(:c60, '_') > 0 THEN CASE WHEN certification_prog_ind LIKE :c61 THEN 1 END WHEN certification_prog_ind = :c62 THEN 1 END) = 1)
   AND (:c63 IS NULL OR (CASE WHEN INSTR(:c64, '%') + INSTR(:c65, '_') > 0 THEN CASE WHEN life_of_plant_ind LIKE :c66 THEN 1 END WHEN life_of_plant_ind = :c67 THEN 1 END) = 1)
   AND (:c68 IS NULL OR cntrct_seq_id = :c69)
   AND (:c70 IS NULL OR (CASE WHEN INSTR(:c71, '%') + INSTR(:c72, '_') > 0 THEN CASE WHEN tax_included_ind LIKE :c73 THEN 1 END WHEN tax_included_ind = :c74 THEN 1 END) = 1)
   AND (:c75 IS NULL OR (CASE WHEN INSTR(:c76, '%') + INSTR(:c77, '_') > 0 THEN CASE WHEN dispsite_code LIKE :c78 THEN 1 END WHEN dispsite_code = :c79 THEN 1 END) = 1)
   AND (:c80 IS NULL OR min_charge = :c81)
   AND (:c82 IS NULL OR (CASE WHEN INSTR(:c83, '%') + INSTR(:c84, '_') > 0 THEN CASE WHEN seg_resp_dept_nm LIKE :c85 THEN 1 END WHEN seg_resp_dept_nm = :c86 THEN 1 END) = 1)
   AND (:c87 IS NULL OR (CASE WHEN INSTR(:c88, '%') + INSTR(:c89, '_') > 0 THEN CASE WHEN contract_line_nbr LIKE :c90 THEN 1 END WHEN contract_line_nbr = :c91 THEN 1 END) = 1)
   AND (:c92 IS NULL OR (CASE WHEN INSTR(:c93, '%') + INSTR(:c94, '_') > 0 THEN CASE WHEN prodcat_descr LIKE :c95 THEN 1 END WHEN prodcat_descr = :c96 THEN 1 END) = 1)
   AND (:c97 IS NULL OR (CASE WHEN INSTR(:c98, '%') + INSTR(:c99, '_') > 0 THEN CASE WHEN classified_ind LIKE :c100 THEN 1 END WHEN classified_ind = :c101 THEN 1 END) = 1)
   AND (:c102 IS NULL OR prof_seq_id = :c103)
   AND (:c104 IS NULL OR disp_site_seq_id = :c105)
 ORDER BY prodserv_cd asc, cntrct_contract_nbr asc
) WHERE ROWNUM <= 5000~'
      USING b_mnfst_cust_seq_id, b_mnfst_advnotif_expected_e379, b_mnfst_cust_seq_id, b_mnfst_es_prof_seq_id, b_mnfst_disp_site_seq_id, p_cntrct_contract_nbr, p_cntrct_contract_nbr, p_cntrct_contract_nbr, p_cntrct_contract_nbr, p_cntrct_contract_nbr, p_cntrct_mod_cntrct_id, p_cntrct_mod_cntrct_id, p_cnprodserv_seq_id, p_cnprodserv_seq_id, p_prodserv_cd, p_prodserv_cd, p_prodserv_cd, p_prodserv_cd, p_prodserv_cd, p_prodserv_descr, p_prodserv_descr, p_prodserv_descr, p_prodserv_descr, p_prodserv_descr, p_dispsite_alias, p_dispsite_alias, p_dispsite_alias, p_dispsite_alias, p_dispsite_alias, p_cnprodserv_cost, p_cnprodserv_cost, p_cnprodserv_unit_cd_id, p_cnprodserv_unit_cd_id, p_cnprodserv_unit_cd_id, p_cnprodserv_unit_cd_id, p_cnprodserv_unit_cd_id, p_cnprodserv_descr, p_cnprodserv_descr, p_cnprodserv_descr, p_cnprodserv_descr, p_cnprodserv_descr, p_cnprodserv_cust_seq_id, p_cnprodserv_cust_seq_id, p_prodserv_prodcat_seq_id, p_prodserv_prodcat_seq_id, p_prodserv_seq_id, p_prodserv_seq_id, p_group_nbr, p_group_nbr, p_group_nbr, p_group_nbr, p_group_nbr, p_subgroup_nbr, p_subgroup_nbr, p_subgroup_nbr, p_subgroup_nbr, p_subgroup_nbr, p_disposal_revenue_ind, p_disposal_revenue_ind, p_disposal_revenue_ind, p_disposal_revenue_ind, p_disposal_revenue_ind, p_certification_prog_ind, p_certification_prog_ind, p_certification_prog_ind, p_certification_prog_ind, p_certification_prog_ind, p_life_of_plant_ind, p_life_of_plant_ind, p_life_of_plant_ind, p_life_of_plant_ind, p_life_of_plant_ind, p_cntrct_seq_id, p_cntrct_seq_id, p_tax_included_ind, p_tax_included_ind, p_tax_included_ind, p_tax_included_ind, p_tax_included_ind, p_dispsite_code, p_dispsite_code, p_dispsite_code, p_dispsite_code, p_dispsite_code, p_min_charge, p_min_charge, p_seg_resp_dept_nm, p_seg_resp_dept_nm, p_seg_resp_dept_nm, p_seg_resp_dept_nm, p_seg_resp_dept_nm, p_contract_line_nbr, p_contract_line_nbr, p_contract_line_nbr, p_contract_line_nbr, p_contract_line_nbr, p_prodcat_descr, p_prodcat_descr, p_prodcat_descr, p_prodcat_descr, p_prodcat_descr, p_classified_ind, p_classified_ind, p_classified_ind, p_classified_ind, p_classified_ind, p_prof_seq_id, p_prof_seq_id, p_disp_site_seq_id, p_disp_site_seq_id;
  END;

  -- AT1510 AT_INVOICES: AT_INVOICES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1510_w_at_invoices(b_mnfst_advnotif_seq_id IN NUMBER, p_invoice_nbr IN VARCHAR2, p_invoice_type_cd IN VARCHAR2, p_invoice_category_cd IN VARCHAR2, p_invc_seq_id IN NUMBER, p_invoice_loc_cd IN VARCHAR2, p_ship_to_cust_seq_id IN NUMBER, p_charge_to_cust_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_face_sheeted IN VARCHAR2, p_notes IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_terms IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_INVOICES
 WHERE (
invc_seq_id in (
select invc_seq_id
from at_invoice_line_items
where advnotif_seq_id = :w1
union
select invc_seq_id
from at_invoice_line_shipments
where manifest_nbr in (
select manifest_nbr
from at_incoming_manifests
where advnotif_seq_id = :w2))
and advnotif_seq_id <> 1086
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN invoice_nbr LIKE :c4 THEN 1 END WHEN invoice_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN invoice_type_cd LIKE :c9 THEN 1 END WHEN invoice_type_cd = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR (CASE WHEN INSTR(:c12, '%') + INSTR(:c13, '_') > 0 THEN CASE WHEN invoice_category_cd LIKE :c14 THEN 1 END WHEN invoice_category_cd = :c15 THEN 1 END) = 1)
   AND (:c16 IS NULL OR invc_seq_id = :c17)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN invoice_loc_cd LIKE :c21 THEN 1 END WHEN invoice_loc_cd = :c22 THEN 1 END) = 1)
   AND (:c23 IS NULL OR ship_to_cust_seq_id = :c24)
   AND (:c25 IS NULL OR charge_to_cust_seq_id = :c26)
   AND (:c27 IS NULL OR seg_stf_seq_id = :c28)
   AND (:c29 IS NULL OR (CASE WHEN INSTR(:c30, '%') + INSTR(:c31, '_') > 0 THEN CASE WHEN face_sheeted LIKE :c32 THEN 1 END WHEN face_sheeted = :c33 THEN 1 END) = 1)
   AND (:c34 IS NULL OR (CASE WHEN INSTR(:c35, '%') + INSTR(:c36, '_') > 0 THEN CASE WHEN notes LIKE :c37 THEN 1 END WHEN notes = :c38 THEN 1 END) = 1)
   AND (:c39 IS NULL OR cntrct_seq_id = :c40)
   AND (:c41 IS NULL OR (CASE WHEN INSTR(:c42, '%') + INSTR(:c43, '_') > 0 THEN CASE WHEN terms LIKE :c44 THEN 1 END WHEN terms = :c45 THEN 1 END) = 1)
 ORDER BY invoice_nbr
) WHERE ROWNUM <= 5000~'
      USING b_mnfst_advnotif_seq_id, b_mnfst_advnotif_seq_id, p_invoice_nbr, p_invoice_nbr, p_invoice_nbr, p_invoice_nbr, p_invoice_nbr, p_invoice_type_cd, p_invoice_type_cd, p_invoice_type_cd, p_invoice_type_cd, p_invoice_type_cd, p_invoice_category_cd, p_invoice_category_cd, p_invoice_category_cd, p_invoice_category_cd, p_invoice_category_cd, p_invc_seq_id, p_invc_seq_id, p_invoice_loc_cd, p_invoice_loc_cd, p_invoice_loc_cd, p_invoice_loc_cd, p_invoice_loc_cd, p_ship_to_cust_seq_id, p_ship_to_cust_seq_id, p_charge_to_cust_seq_id, p_charge_to_cust_seq_id, p_seg_stf_seq_id, p_seg_stf_seq_id, p_face_sheeted, p_face_sheeted, p_face_sheeted, p_face_sheeted, p_face_sheeted, p_notes, p_notes, p_notes, p_notes, p_notes, p_cntrct_seq_id, p_cntrct_seq_id, p_terms, p_terms, p_terms, p_terms, p_terms;
  END;

  -- AT1510 RNCNTNRS: AT_RENTAL_CNTNR_SHIPMENTS_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1510_w_rncntnrs(p_rental_container_id IN VARCHAR2, p_rncntnrstat_cd_id IN VARCHAR2, p_seg_owned_ind IN VARCHAR2, p_out_shipment_nbr IN VARCHAR2, p_shipment_type_cd IN VARCHAR2, p_consignee_cust_seq_id IN NUMBER, p_pick_up_cust_seq_id IN NUMBER, p_rncntnr_seq_id IN NUMBER, p_segordlitm_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_RENTAL_CNTNR_SHIPMENTS_VIEW
 WHERE (
  AT_RENTAL_CNTNR_SHIPMENTS_VIEW.PICK_UP_CUST_SEQ_ID = (
       select c.cust_seq_id 
         from at_customers c
        where c.customer_nbr = 396 )

)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN rental_container_id LIKE :c4 THEN 1 END WHEN rental_container_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN rncntnrstat_cd_id LIKE :c9 THEN 1 END WHEN rncntnrstat_cd_id = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR (CASE WHEN INSTR(:c12, '%') + INSTR(:c13, '_') > 0 THEN CASE WHEN seg_owned_ind LIKE :c14 THEN 1 END WHEN seg_owned_ind = :c15 THEN 1 END) = 1)
   AND (:c16 IS NULL OR (CASE WHEN INSTR(:c17, '%') + INSTR(:c18, '_') > 0 THEN CASE WHEN out_shipment_nbr LIKE :c19 THEN 1 END WHEN out_shipment_nbr = :c20 THEN 1 END) = 1)
   AND (:c21 IS NULL OR (CASE WHEN INSTR(:c22, '%') + INSTR(:c23, '_') > 0 THEN CASE WHEN shipment_type_cd LIKE :c24 THEN 1 END WHEN shipment_type_cd = :c25 THEN 1 END) = 1)
   AND (:c26 IS NULL OR consignee_cust_seq_id = :c27)
   AND (:c28 IS NULL OR pick_up_cust_seq_id = :c29)
   AND (:c30 IS NULL OR rncntnr_seq_id = :c31)
   AND (:c32 IS NULL OR segordlitm_seq_id = :c33)
) WHERE ROWNUM <= 5000~'
      USING p_rental_container_id, p_rental_container_id, p_rental_container_id, p_rental_container_id, p_rental_container_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_seg_owned_ind, p_seg_owned_ind, p_seg_owned_ind, p_seg_owned_ind, p_seg_owned_ind, p_out_shipment_nbr, p_out_shipment_nbr, p_out_shipment_nbr, p_out_shipment_nbr, p_out_shipment_nbr, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_consignee_cust_seq_id, p_consignee_cust_seq_id, p_pick_up_cust_seq_id, p_pick_up_cust_seq_id, p_rncntnr_seq_id, p_rncntnr_seq_id, p_segordlitm_seq_id, p_segordlitm_seq_id;
  END;
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT1510 DISP_SITE_LV: the record group's own query; P1 = :MNFST.CUST_SEQ_ID
  PROCEDURE at1510_lov_disp_site_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select ds.disp_site_seq_id,ds.code,ds.description
from at_disp_sites ds where ds.disp_site_seq_id in (select cds.disp_site_seq_id from at_customer_disp_sites cds where cds.cust_seq_id = :b1 and NVL(cds.allowed_ind,'N') = 'Y')
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1510 PROFILE_LV: the record group's own query; P1 = :MNFST.CUST_SEQ_ID
  PROCEDURE at1510_lov_profile_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select es_prof_seq_id,waste_profile_number
from at_esprofiles
where gen_cust_seq_id = :b1
and NVL(waste_rev_dt,sysdate + 1) < sysdate
and waste_profile_status = 'QC RELEASED' 
and site_cd in (select site_name from at_corp_cust_sites@atcorp
where upper(instance_name) in (select upper(parameter_value) from at_parameters where parameter_name = 'DATABASE_PREFIX'))
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

