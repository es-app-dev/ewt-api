-- EWT_UI fragment: AT1710
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT1710 AT_RENTAL_CNTNR_SHIPMENTS_VIEW: AT_RENTAL_CNTNR_SHIPMENTS_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at1710_w_at_rental_cntnr__50a1(b_inv_ship_to_cust_seq_id IN NUMBER, b_at$ctrl_end_dt IN DATE, b_at$ctrl_begin_dt IN DATE, p_out_shipment_nbr IN VARCHAR2, p_rncntnr_seq_id IN NUMBER, p_rental_container_id IN VARCHAR2, p_old_sl_nbr IN VARCHAR2, p_tare_wgt IN NUMBER, p_seg_owned_ind IN VARCHAR2, p_rncntnrstat_cd_id IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_billing_cust_seq_id IN NUMBER, p_owned_by_cust_seq_id IN NUMBER, p_comment_txt IN VARCHAR2, p_storage_loc_sl_ind IN VARCHAR2, p_current_site_seq_id IN NUMBER, p_in_shipment_nbr IN VARCHAR2, p_in_cust_seq IN VARCHAR2, p_segordlitm_seq_id IN NUMBER, p_shipment_type_cd IN VARCHAR2, p_consignee_cust_seq_id IN NUMBER, p_pick_up_cust_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT1710 AT_SHIP_TRANS: AT_SHIP_TRANS with the block's own WHERE; one optional criterion per column
  PROCEDURE at1710_w_at_ship_trans(b_at_invoice_line_shipmen_da18 IN VARCHAR2, p_shipment_nbr IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_hittman_nbr IN VARCHAR2, p_contract_nbr IN VARCHAR2, p_notes IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT1710 PREV_INV: AT_INVOICE_LINE_CNTNR with the block's own WHERE; one optional criterion per column
  PROCEDURE at1710_w_prev_inv(b_at$ctrl_prev_cntnr_seq IN NUMBER, b_at$ctrl_advnotif_seq_id IN NUMBER, p_invc_seq_id IN NUMBER, p_invlitm_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_anchor_wgt IN NUMBER, p_inv_wgt IN NUMBER, p_advnotif_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT1710 SRC: AT_OPPORTUNITIES_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at1710_w_src(b_inv_charge_to_cust_seq_id IN NUMBER, b_wksht_prodserv_cd IN VARCHAR2, b_wksht_disp_site_alias IN VARCHAR2, b_wksht_advnotif_seq_id IN NUMBER, p_invoppty_seq_id IN NUMBER, p_contract_nbr IN VARCHAR2, p_manifest_nbr IN VARCHAR2, p_qty IN NUMBER, p_container_id IN VARCHAR2, p_invoppty_description IN VARCHAR2, p_prodserv_cd IN VARCHAR2, p_disp_site_alias IN VARCHAR2, p_disp_site_code IN VARCHAR2, p_description IN VARCHAR2, p_advnotif_seq_id IN NUMBER, p_cost IN NUMBER, p_invoiced_ind IN VARCHAR2, p_ordered_qty IN NUMBER, p_segordlitm_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT1710 CHARGE_TO_CUST_LOV (record group CHARGE_TO_CUST_RG); not OData: a subquery in WHERE
  PROCEDURE at1710_lov_charge_to_cust_lov(p_rows OUT SYS_REFCURSOR);
  -- AT1710 INV_CONTRACT_NBR (record group INV_CONTRACT_NBR); not OData: a subquery in WHERE
  PROCEDURE at1710_lov_inv_contract_nbr(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1710 INV_SEG_STAFF (record group INV_SEG_STAFF); not OData: a subquery in WHERE
  PROCEDURE at1710_lov_inv_seg_staff(p_rows OUT SYS_REFCURSOR);
  -- AT1710 LV_BARCODE (record group RG_BARCODE); not OData: a join
  PROCEDURE at1710_lov_lv_barcode(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1710 LV_SHIPMENTS (record group RG_SHIPMENTS); not OData: a join
  PROCEDURE at1710_lov_lv_shipments(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1710 LV_WKSHT_MNFSTS (record group RG_WKSHT_MNFSTS); not OData: a join
  PROCEDURE at1710_lov_lv_wksht_mnfsts(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY






  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT1710 AT_RENTAL_CNTNR_SHIPMENTS_VIEW: AT_RENTAL_CNTNR_SHIPMENTS_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1710_w_at_rental_cntnr__50a1(b_inv_ship_to_cust_seq_id IN NUMBER, b_at$ctrl_end_dt IN DATE, b_at$ctrl_begin_dt IN DATE, p_out_shipment_nbr IN VARCHAR2, p_rncntnr_seq_id IN NUMBER, p_rental_container_id IN VARCHAR2, p_old_sl_nbr IN VARCHAR2, p_tare_wgt IN NUMBER, p_seg_owned_ind IN VARCHAR2, p_rncntnrstat_cd_id IN VARCHAR2, p_cntnr_typ_seq_id IN NUMBER, p_billing_cust_seq_id IN NUMBER, p_owned_by_cust_seq_id IN NUMBER, p_comment_txt IN VARCHAR2, p_storage_loc_sl_ind IN VARCHAR2, p_current_site_seq_id IN NUMBER, p_in_shipment_nbr IN VARCHAR2, p_in_cust_seq IN VARCHAR2, p_segordlitm_seq_id IN NUMBER, p_shipment_type_cd IN VARCHAR2, p_consignee_cust_seq_id IN NUMBER, p_pick_up_cust_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_RENTAL_CNTNR_SHIPMENTS_VIEW
 WHERE (
consignee_cust_seq_id = :w1
and (owned_by_cust_seq_id in (1296,3382,1202) or rented_by_cust_seq_id in (1296,3382,1202))
and (
    (out_dt <= :w2 and NVL(in_dt,:w3) >= :w4) 
    or
    (
    NVL(in_dt,:w5) >= :w6 and NVL(out_dt,:w7) <= :w8
    )
    )
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN out_shipment_nbr LIKE :c4 THEN 1 END WHEN out_shipment_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR rncntnr_seq_id = :c7)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN rental_container_id LIKE :c11 THEN 1 END WHEN rental_container_id = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN old_sl_nbr LIKE :c16 THEN 1 END WHEN old_sl_nbr = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR tare_wgt = :c19)
   AND (:c20 IS NULL OR (CASE WHEN INSTR(:c21, '%') + INSTR(:c22, '_') > 0 THEN CASE WHEN seg_owned_ind LIKE :c23 THEN 1 END WHEN seg_owned_ind = :c24 THEN 1 END) = 1)
   AND (:c25 IS NULL OR (CASE WHEN INSTR(:c26, '%') + INSTR(:c27, '_') > 0 THEN CASE WHEN rncntnrstat_cd_id LIKE :c28 THEN 1 END WHEN rncntnrstat_cd_id = :c29 THEN 1 END) = 1)
   AND (:c30 IS NULL OR cntnr_typ_seq_id = :c31)
   AND (:c32 IS NULL OR billing_cust_seq_id = :c33)
   AND (:c34 IS NULL OR owned_by_cust_seq_id = :c35)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN comment_txt LIKE :c39 THEN 1 END WHEN comment_txt = :c40 THEN 1 END) = 1)
   AND (:c41 IS NULL OR (CASE WHEN INSTR(:c42, '%') + INSTR(:c43, '_') > 0 THEN CASE WHEN storage_loc_sl_ind LIKE :c44 THEN 1 END WHEN storage_loc_sl_ind = :c45 THEN 1 END) = 1)
   AND (:c46 IS NULL OR current_site_seq_id = :c47)
   AND (:c48 IS NULL OR (CASE WHEN INSTR(:c49, '%') + INSTR(:c50, '_') > 0 THEN CASE WHEN in_shipment_nbr LIKE :c51 THEN 1 END WHEN in_shipment_nbr = :c52 THEN 1 END) = 1)
   AND (:c53 IS NULL OR (CASE WHEN INSTR(:c54, '%') + INSTR(:c55, '_') > 0 THEN CASE WHEN in_cust_seq LIKE :c56 THEN 1 END WHEN in_cust_seq = :c57 THEN 1 END) = 1)
   AND (:c58 IS NULL OR segordlitm_seq_id = :c59)
   AND (:c60 IS NULL OR (CASE WHEN INSTR(:c61, '%') + INSTR(:c62, '_') > 0 THEN CASE WHEN shipment_type_cd LIKE :c63 THEN 1 END WHEN shipment_type_cd = :c64 THEN 1 END) = 1)
   AND (:c65 IS NULL OR consignee_cust_seq_id = :c66)
   AND (:c67 IS NULL OR pick_up_cust_seq_id = :c68)
 ORDER BY /*get_cntnr_type(rental_container_id)*/ rental_container_id
) WHERE ROWNUM <= 5000~'
      USING b_inv_ship_to_cust_seq_id, b_at$ctrl_end_dt, b_at$ctrl_begin_dt, b_at$ctrl_begin_dt, b_at$ctrl_end_dt, b_at$ctrl_end_dt, b_at$ctrl_end_dt, b_at$ctrl_end_dt, p_out_shipment_nbr, p_out_shipment_nbr, p_out_shipment_nbr, p_out_shipment_nbr, p_out_shipment_nbr, p_rncntnr_seq_id, p_rncntnr_seq_id, p_rental_container_id, p_rental_container_id, p_rental_container_id, p_rental_container_id, p_rental_container_id, p_old_sl_nbr, p_old_sl_nbr, p_old_sl_nbr, p_old_sl_nbr, p_old_sl_nbr, p_tare_wgt, p_tare_wgt, p_seg_owned_ind, p_seg_owned_ind, p_seg_owned_ind, p_seg_owned_ind, p_seg_owned_ind, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_rncntnrstat_cd_id, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id, p_billing_cust_seq_id, p_billing_cust_seq_id, p_owned_by_cust_seq_id, p_owned_by_cust_seq_id, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_comment_txt, p_storage_loc_sl_ind, p_storage_loc_sl_ind, p_storage_loc_sl_ind, p_storage_loc_sl_ind, p_storage_loc_sl_ind, p_current_site_seq_id, p_current_site_seq_id, p_in_shipment_nbr, p_in_shipment_nbr, p_in_shipment_nbr, p_in_shipment_nbr, p_in_shipment_nbr, p_in_cust_seq, p_in_cust_seq, p_in_cust_seq, p_in_cust_seq, p_in_cust_seq, p_segordlitm_seq_id, p_segordlitm_seq_id, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_consignee_cust_seq_id, p_consignee_cust_seq_id, p_pick_up_cust_seq_id, p_pick_up_cust_seq_id;
  END;

  -- AT1710 AT_SHIP_TRANS: AT_SHIP_TRANS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1710_w_at_ship_trans(b_at_invoice_line_shipmen_da18 IN VARCHAR2, p_shipment_nbr IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_hittman_nbr IN VARCHAR2, p_contract_nbr IN VARCHAR2, p_notes IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_SHIP_TRANS
 WHERE (
shipment_nbr = /*'000057'*/:w1
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN shipment_nbr LIKE :c4 THEN 1 END WHEN shipment_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR cntrct_seq_id = :c7)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN hittman_nbr LIKE :c11 THEN 1 END WHEN hittman_nbr = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN contract_nbr LIKE :c16 THEN 1 END WHEN contract_nbr = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN notes LIKE :c21 THEN 1 END WHEN notes = :c22 THEN 1 END) = 1)
) WHERE ROWNUM <= 5000~'
      USING b_at_invoice_line_shipmen_da18, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_cntrct_seq_id, p_cntrct_seq_id, p_hittman_nbr, p_hittman_nbr, p_hittman_nbr, p_hittman_nbr, p_hittman_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_notes, p_notes, p_notes, p_notes, p_notes;
  END;

  -- AT1710 PREV_INV: AT_INVOICE_LINE_CNTNR with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1710_w_prev_inv(b_at$ctrl_prev_cntnr_seq IN NUMBER, b_at$ctrl_advnotif_seq_id IN NUMBER, p_invc_seq_id IN NUMBER, p_invlitm_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_anchor_wgt IN NUMBER, p_inv_wgt IN NUMBER, p_advnotif_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_INVOICE_LINE_CNTNR
 WHERE (
CNTNR_SEQ_ID = NVL(:w1,0)
and advnotif_seq_id = :w2
)
   AND (:c1 IS NULL OR invc_seq_id = :c2)
   AND (:c3 IS NULL OR invlitm_seq_id = :c4)
   AND (:c5 IS NULL OR cntnr_seq_id = :c6)
   AND (:c7 IS NULL OR anchor_wgt = :c8)
   AND (:c9 IS NULL OR inv_wgt = :c10)
   AND (:c11 IS NULL OR advnotif_seq_id = :c12)
 ORDER BY INVC_SEQ_ID
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_prev_cntnr_seq, b_at$ctrl_advnotif_seq_id, p_invc_seq_id, p_invc_seq_id, p_invlitm_seq_id, p_invlitm_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_anchor_wgt, p_anchor_wgt, p_inv_wgt, p_inv_wgt, p_advnotif_seq_id, p_advnotif_seq_id;
  END;

  -- AT1710 SRC: AT_OPPORTUNITIES_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1710_w_src(b_inv_charge_to_cust_seq_id IN NUMBER, b_wksht_prodserv_cd IN VARCHAR2, b_wksht_disp_site_alias IN VARCHAR2, b_wksht_advnotif_seq_id IN NUMBER, p_invoppty_seq_id IN NUMBER, p_contract_nbr IN VARCHAR2, p_manifest_nbr IN VARCHAR2, p_qty IN NUMBER, p_container_id IN VARCHAR2, p_invoppty_description IN VARCHAR2, p_prodserv_cd IN VARCHAR2, p_disp_site_alias IN VARCHAR2, p_disp_site_code IN VARCHAR2, p_description IN VARCHAR2, p_advnotif_seq_id IN NUMBER, p_cost IN NUMBER, p_invoiced_ind IN VARCHAR2, p_ordered_qty IN NUMBER, p_segordlitm_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_OPPORTUNITIES_VIEW
 WHERE (
  AT_OPPORTUNITIES_VIEW.CUST_SEQ_ID = :w1 and
AT_OPPORTUNITIES_VIEW.PRODSERV_CD = :w2 and
NVL(AT_OPPORTUNITIES_VIEW.DISP_SITE_ALIAS,' ') = nvl(:w3,' ') and
AT_OPPORTUNITIES_VIEW.ADVNOTIF_SEQ_ID = :w4 and
AT_OPPORTUNITIES_VIEW.INVOICED_IND = 'N'

)
   AND (:c1 IS NULL OR invoppty_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN contract_nbr LIKE :c6 THEN 1 END WHEN contract_nbr = :c7 THEN 1 END) = 1)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN manifest_nbr LIKE :c11 THEN 1 END WHEN manifest_nbr = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR qty = :c14)
   AND (:c15 IS NULL OR (CASE WHEN INSTR(:c16, '%') + INSTR(:c17, '_') > 0 THEN CASE WHEN container_id LIKE :c18 THEN 1 END WHEN container_id = :c19 THEN 1 END) = 1)
   AND (:c20 IS NULL OR (CASE WHEN INSTR(:c21, '%') + INSTR(:c22, '_') > 0 THEN CASE WHEN invoppty_description LIKE :c23 THEN 1 END WHEN invoppty_description = :c24 THEN 1 END) = 1)
   AND (:c25 IS NULL OR (CASE WHEN INSTR(:c26, '%') + INSTR(:c27, '_') > 0 THEN CASE WHEN prodserv_cd LIKE :c28 THEN 1 END WHEN prodserv_cd = :c29 THEN 1 END) = 1)
   AND (:c30 IS NULL OR (CASE WHEN INSTR(:c31, '%') + INSTR(:c32, '_') > 0 THEN CASE WHEN disp_site_alias LIKE :c33 THEN 1 END WHEN disp_site_alias = :c34 THEN 1 END) = 1)
   AND (:c35 IS NULL OR (CASE WHEN INSTR(:c36, '%') + INSTR(:c37, '_') > 0 THEN CASE WHEN disp_site_code LIKE :c38 THEN 1 END WHEN disp_site_code = :c39 THEN 1 END) = 1)
   AND (:c40 IS NULL OR (CASE WHEN INSTR(:c41, '%') + INSTR(:c42, '_') > 0 THEN CASE WHEN description LIKE :c43 THEN 1 END WHEN description = :c44 THEN 1 END) = 1)
   AND (:c45 IS NULL OR advnotif_seq_id = :c46)
   AND (:c47 IS NULL OR cost = :c48)
   AND (:c49 IS NULL OR (CASE WHEN INSTR(:c50, '%') + INSTR(:c51, '_') > 0 THEN CASE WHEN invoiced_ind LIKE :c52 THEN 1 END WHEN invoiced_ind = :c53 THEN 1 END) = 1)
   AND (:c54 IS NULL OR ordered_qty = :c55)
   AND (:c56 IS NULL OR segordlitm_seq_id = :c57)
   AND (:c58 IS NULL OR cust_seq_id = :c59)
 ORDER BY invoppty_seq_id
) WHERE ROWNUM <= 5000~'
      USING b_inv_charge_to_cust_seq_id, b_wksht_prodserv_cd, b_wksht_disp_site_alias, b_wksht_advnotif_seq_id, p_invoppty_seq_id, p_invoppty_seq_id, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_qty, p_qty, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_invoppty_description, p_invoppty_description, p_invoppty_description, p_invoppty_description, p_invoppty_description, p_prodserv_cd, p_prodserv_cd, p_prodserv_cd, p_prodserv_cd, p_prodserv_cd, p_disp_site_alias, p_disp_site_alias, p_disp_site_alias, p_disp_site_alias, p_disp_site_alias, p_disp_site_code, p_disp_site_code, p_disp_site_code, p_disp_site_code, p_disp_site_code, p_description, p_description, p_description, p_description, p_description, p_advnotif_seq_id, p_advnotif_seq_id, p_cost, p_cost, p_invoiced_ind, p_invoiced_ind, p_invoiced_ind, p_invoiced_ind, p_invoiced_ind, p_ordered_qty, p_ordered_qty, p_segordlitm_seq_id, p_segordlitm_seq_id, p_cust_seq_id, p_cust_seq_id;
  END;
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT1710 CHARGE_TO_CUST_LOV: the record group's own query
  PROCEDURE at1710_lov_charge_to_cust_lov(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   name dsp_name
        ,customer_nbr dsp_customer_nbr
        ,cust_seq_id charge_to_cust_seq_id
FROM     at_customers
WHERE    cust_seq_id IN (SELECT cust_seq_id
                         FROM   at_contracts)
ORDER BY name
) WHERE ROWNUM <= 5000~';
  END;

  -- AT1710 INV_CONTRACT_NBR: the record group's own query; P1 = :INV.CHARGE_TO_CUST_SEQ_ID
  PROCEDURE at1710_lov_inv_contract_nbr(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   c.inv_contract_nbr
        ,c.inv_deliv_ord_cust_mod
        ,c.contract_nbr
        ,NVL(c.payment_terms_txt, 'NET 30 Days') payment_terms_txt
        ,c.cntrct_seq_id
        ,c.effective_dt
        ,c.expiration_dt
FROM     at_contracts c
WHERE        c.cust_seq_id = :b1
         AND c.mod_cntrct_id IN (SELECT MAX(c1.mod_cntrct_id)
                                 FROM   at_contracts c1
                                 WHERE      c1.contract_nbr = c.contract_nbr
                                        AND NVL(approved_ind, 'N') = 'Y'
                                        AND c1.cust_seq_id = :b2)
ORDER BY inv_contract_nbr, contract_nbr, inv_deliv_ord_cust_mod
) WHERE ROWNUM <= 5000~'
      USING p1, p1;
  END;

  -- AT1710 INV_SEG_STAFF: the record group's own query
  PROCEDURE at1710_lov_inv_seg_staff(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT seg_stf_seq_id
      ,first_name
      ,SUBSTR(middle_name, 1, 1) middle_name
      ,last_name
FROM   at_seg_staff
WHERE      seg_dept_seq_id IN (SELECT seg_dept_seq_id
                               FROM   at_seg_departments
                               WHERE  code = 'INVOICING')
       AND status_cd = 'A'
) WHERE ROWNUM <= 5000~';
  END;

  -- AT1710 LV_BARCODE: the record group's own query; P1 = :INV.CHARGE_TO_CUST_SEQ_ID
  PROCEDURE at1710_lov_lv_barcode(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT DISTINCT c.container_id
               ,c.cntnr_seq_id
               ,c.anchor_wgt
               ,c.anchor_wgt inv_wgt
FROM   at_containers c
      ,at_cust_doc_tracked_items cdti
WHERE      cdti.cntnr_seq_id = c.cntnr_seq_id
       AND cdti.cust_seq_id = :b1
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1710 LV_SHIPMENTS: the record group's own query; P1 = :INV.CHARGE_TO_CUST_SEQ_ID
  PROCEDURE at1710_lov_lv_shipments(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT s.shipment_nbr
      ,s.scheduled_shipment_dt
      ,s.scheduled_delivery_dt
      ,s.shipment_type_cd
      ,s.round_trip_shipment_nbr
      ,s.waste_contents_txt
      ,s.shipment_dt
      ,s.received_dt
      ,im.manifest_nbr
FROM   at_shipments s
      ,at_shipments s1
      ,at_incoming_manifests im
WHERE      NVL(s.round_trip_shipment_nbr, 0) = s1.shipment_nbr(+)
       AND s.shipment_nbr = im.shipment_nbr(+)
       AND s.shipment_nbr IN (SELECT shipment_nbr
                              FROM   at_shipments
                              WHERE     consignee_cust_seq_id = :b1
                                     OR pick_up_cust_seq_id = :b2)
) WHERE ROWNUM <= 5000~'
      USING p1, p1;
  END;

  -- AT1710 LV_WKSHT_MNFSTS: the record group's own query; P1 = :INV.CHARGE_TO_CUST_SEQ_ID, P2 = :INV.CNTRCT_SEQ_ID
  PROCEDURE at1710_lov_lv_wksht_mnfsts(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   DISTINCT im.manifest_nbr
                 ,im.advnotif_seq_id
                 ,pc.description
                 ,cps.cost
                 ,cps.cost_currency_code
                 ,cps.unit_cd_id units
FROM     at_incoming_manifests im
        ,at_seg_order_line_items soli
        ,at_contract_prod_services cps
        ,at_product_categories pc
        ,at_contracts c
WHERE        im.cust_seq_id = :b1
         AND c.cntrct_seq_id = cps.cntrct_seq_id
         AND c.cntrct_seq_id = :b2
         AND cps.cnprodserv_seq_id = soli.cnprodserv_seq_id
         AND soli.advnotif_seq_id = im.advnotif_seq_id
         AND soli.status_cd = 'OPEN'
         AND cps.prodserv_prodcat_seq_id = pc.prodcat_seq_id
ORDER BY im.manifest_nbr
) WHERE ROWNUM <= 5000~'
      USING p1, p2;
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

