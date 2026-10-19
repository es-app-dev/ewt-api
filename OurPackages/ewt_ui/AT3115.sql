-- EWT_UI fragment: AT3115
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT3115 CGFK$CNTNR_DSP_PRCTRANTYP_CD_I (record group PRCTRANS_TYPES_BY_ORDER); not OData: a join
  PROCEDURE at3115_lov_cgfk_cntnr_dsp_prct(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT3115 CUST_DISP (record group CUST_DISP); not OData: a join
  PROCEDURE at3115_lov_cust_disp(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT3115 LOV_COST (record group RG_COST$); not OData: a join
  PROCEDURE at3115_lov_lov_cost(p1 IN VARCHAR2, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT3115 CNTNR: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at3115_w_cntnr(b_parameter_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_disp_site_seq_id IN NUMBER, p_cntnr_stat_cd_id IN VARCHAR2, p_next_prctrantyp_seq_id IN NUMBER, p_cntnr_typ_seq_id IN NUMBER, p_disp_site_lock_ind IN VARCHAR2, p_exterior_dose_rate_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_agt_media_seq_id IN NUMBER, p_incinerator_factor_nbr IN NUMBER, p_anchor_wgt_source_cd IN VARCHAR2, p_anchor_wgt IN NUMBER, p_waste_vol IN NUMBER, p_waste_vol_unit_cd IN VARCHAR2, p_hazardous_cd IN VARCHAR2, p_notes IN VARCHAR2, p_source_ind IN VARCHAR2, p_source_manufacturer IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

--#BODY
  -- AT3115 CGFK$CNTNR_DSP_PRCTRANTYP_CD_I: the record group's own query; P1 = :PARAMETER.ADVNOTIF_SEQ_ID
  PROCEDURE at3115_lov_cgfk_cntnr_dsp_prct(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select distinct ptt.prctrantyp_cd_id dsp_prctrantyp_cd_id
, ptt.description dsp_description
,ptt.prctrantyp_seq_id next_prctrantyp_seq_id
, 'Map Required' map
, ptt.map_ind 
FROM AT_PRODUCT_SERVICES PS
, AT_CONTRACT_PROD_SERVICES CPS
, AT_SEG_ORDER_LINE_ITEMS SOLI
, AT_PROCESS_TRANS_SERVICES NS
, AT_PROCESS_TRANS_TYPES PTT
WHERE PS.PRODSERV_SEQ_ID = CPS.PRODSERV_SEQ_ID
  AND CPS.CNPRODSERV_SEQ_ID = SOLI.CNPRODSERV_SEQ_ID
  AND PTT.PRCTRANTYP_SEQ_ID = NS.PRCTRANTYP_SEQ_ID
  AND NS.PRODSERV_SEQ_ID = PS.PRODSERV_SEQ_ID
  AND SOLI.ADVNOTIF_SEQ_ID = :b1 
  AND SOLI.STATUS_CD = 'OPEN'
  AND NVL(PTT.OBSOLETE_FLAG,'Y') = 'N'
order by ptt.prctrantyp_cd_id
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT3115 CUST_DISP: the record group's own query; P1 = :CNTNR.CUST_SEQ_ID, P2 = :CONTROL_BLOCK.DSP_SHIP_NBR
  PROCEDURE at3115_lov_cust_disp(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.code, a.description, a.disp_site_seq_id from at_disp_sites a,
at_customer_disp_sites b where a.disp_site_seq_id = b.disp_site_seq_id and b.cust_seq_id = :b1 and nvl(b.allowed_ind,'N') = 'Y' and exists (select c.disp_site_seq_id from at_incoming_manifests c where nvl(c.brokered_shipment_ind,'N') = 'Y' and c.advnotif_seq_id = :b2)
union
select a.code, a.description, a.disp_site_seq_id from at_disp_sites a,
at_order_disp_sites b, at_incoming_manifests c  where a.disp_site_seq_id = b.disp_site_seq_id and b.advnotif_seq_id = c.advnotif_seq_id and nvl(c.brokered_shipment_ind,'N') = 'N' and
b.advnotif_seq_id = :b3
) WHERE ROWNUM <= 5000~'
      USING p1, p2, p2;
  END;

  -- AT3115 LOV_COST: the record group's own query; P1 = :PARAMETER.ADVNOTIF_SEQ_ID, P2 = :CNTNR.DSP_PRCTRANTYP_CD_ID
  PROCEDURE at3115_lov_lov_cost(p1 IN VARCHAR2, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT PS.PRODSERV_CD PRODSERV_CD
       , CPS.COST COST
       , CPS.UNIT_CD_ID UNIT_CD_ID
       , NVL(SOLI.ORDERED_QTY,0) ORDERED_QTY
       , SOLI.SEGORDLITM_SEQ_ID  SEGORDLITM_SEQ_ID
       ,  'A' COST_TYPE 
       , CPS.description CNPRODSERV_DESC
       , PS.DESCRIPTION         PRODSERV_DESC      
  FROM AT_PRODUCT_SERVICES PS
     , AT_CONTRACT_PROD_SERVICES CPS
     , AT_SEG_ORDER_LINE_ITEMS SOLI
     , AT_PROCESS_TRANS_SERVICES NS
     , AT_PROCESS_TRANS_TYPES PTT
  WHERE PS.PRODSERV_SEQ_ID = CPS.PRODSERV_SEQ_ID
    AND PS.PRODSERV_SEQ_ID = NS.PRODSERV_SEQ_ID
    AND CPS.CNPRODSERV_SEQ_ID = SOLI.CNPRODSERV_SEQ_ID
    AND PTT.PRCTRANTYP_SEQ_ID = NS.PRCTRANTYP_SEQ_ID
    AND SOLI.ADVNOTIF_SEQ_ID = :b1
    AND PTT.PRCTRANTYP_CD_ID = :b2
    AND SOLI.STATUS_CD = 'OPEN'
    AND NVL(PS.INCLUDE_MAP_IND,'N') = 'Y' 
    AND (NVL(CPS.GROUP_NBR,0) = 0 OR
        (NVL(CPS.GROUP_NBR,0) <> 0
        AND NVL(CPS.SUBGROUP_NBR,0) <> 0))
  ORDER BY PS.PRODSERV_CD, CPS.UNIT_CD_ID, CPS.COST
) WHERE ROWNUM <= 5000~'
      USING p1, p2;
  END;

  -- AT3115 CNTNR: AT_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at3115_w_cntnr(b_parameter_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_disp_site_seq_id IN NUMBER, p_cntnr_stat_cd_id IN VARCHAR2, p_next_prctrantyp_seq_id IN NUMBER, p_cntnr_typ_seq_id IN NUMBER, p_disp_site_lock_ind IN VARCHAR2, p_exterior_dose_rate_amt IN NUMBER, p_dose_unit_cd_id IN VARCHAR2, p_agt_media_seq_id IN NUMBER, p_incinerator_factor_nbr IN NUMBER, p_anchor_wgt_source_cd IN VARCHAR2, p_anchor_wgt IN NUMBER, p_waste_vol IN NUMBER, p_waste_vol_unit_cd IN VARCHAR2, p_hazardous_cd IN VARCHAR2, p_notes IN VARCHAR2, p_source_ind IN VARCHAR2, p_source_manufacturer IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINERS
 WHERE (
cntnr_seq_id = :w1
)
   AND (:c1 IS NULL OR cntnr_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN container_id LIKE :c6 THEN 1 END WHEN container_id = :c7 THEN 1 END) = 1)
   AND (:c8 IS NULL OR disp_site_seq_id = :c9)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN cntnr_stat_cd_id LIKE :c13 THEN 1 END WHEN cntnr_stat_cd_id = :c14 THEN 1 END) = 1)
   AND (:c15 IS NULL OR next_prctrantyp_seq_id = :c16)
   AND (:c17 IS NULL OR cntnr_typ_seq_id = :c18)
   AND (:c19 IS NULL OR (CASE WHEN INSTR(:c20, '%') + INSTR(:c21, '_') > 0 THEN CASE WHEN disp_site_lock_ind LIKE :c22 THEN 1 END WHEN disp_site_lock_ind = :c23 THEN 1 END) = 1)
   AND (:c24 IS NULL OR exterior_dose_rate_amt = :c25)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN dose_unit_cd_id LIKE :c29 THEN 1 END WHEN dose_unit_cd_id = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR agt_media_seq_id = :c32)
   AND (:c33 IS NULL OR incinerator_factor_nbr = :c34)
   AND (:c35 IS NULL OR (CASE WHEN INSTR(:c36, '%') + INSTR(:c37, '_') > 0 THEN CASE WHEN anchor_wgt_source_cd LIKE :c38 THEN 1 END WHEN anchor_wgt_source_cd = :c39 THEN 1 END) = 1)
   AND (:c40 IS NULL OR anchor_wgt = :c41)
   AND (:c42 IS NULL OR waste_vol = :c43)
   AND (:c44 IS NULL OR (CASE WHEN INSTR(:c45, '%') + INSTR(:c46, '_') > 0 THEN CASE WHEN waste_vol_unit_cd LIKE :c47 THEN 1 END WHEN waste_vol_unit_cd = :c48 THEN 1 END) = 1)
   AND (:c49 IS NULL OR (CASE WHEN INSTR(:c50, '%') + INSTR(:c51, '_') > 0 THEN CASE WHEN hazardous_cd LIKE :c52 THEN 1 END WHEN hazardous_cd = :c53 THEN 1 END) = 1)
   AND (:c54 IS NULL OR (CASE WHEN INSTR(:c55, '%') + INSTR(:c56, '_') > 0 THEN CASE WHEN notes LIKE :c57 THEN 1 END WHEN notes = :c58 THEN 1 END) = 1)
   AND (:c59 IS NULL OR (CASE WHEN INSTR(:c60, '%') + INSTR(:c61, '_') > 0 THEN CASE WHEN source_ind LIKE :c62 THEN 1 END WHEN source_ind = :c63 THEN 1 END) = 1)
   AND (:c64 IS NULL OR (CASE WHEN INSTR(:c65, '%') + INSTR(:c66, '_') > 0 THEN CASE WHEN source_manufacturer LIKE :c67 THEN 1 END WHEN source_manufacturer = :c68 THEN 1 END) = 1)
) WHERE ROWNUM <= 5000~'
      USING b_parameter_cntnr_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_disp_site_seq_id, p_disp_site_seq_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_next_prctrantyp_seq_id, p_next_prctrantyp_seq_id, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id, p_disp_site_lock_ind, p_disp_site_lock_ind, p_disp_site_lock_ind, p_disp_site_lock_ind, p_disp_site_lock_ind, p_exterior_dose_rate_amt, p_exterior_dose_rate_amt, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_dose_unit_cd_id, p_agt_media_seq_id, p_agt_media_seq_id, p_incinerator_factor_nbr, p_incinerator_factor_nbr, p_anchor_wgt_source_cd, p_anchor_wgt_source_cd, p_anchor_wgt_source_cd, p_anchor_wgt_source_cd, p_anchor_wgt_source_cd, p_anchor_wgt, p_anchor_wgt, p_waste_vol, p_waste_vol, p_waste_vol_unit_cd, p_waste_vol_unit_cd, p_waste_vol_unit_cd, p_waste_vol_unit_cd, p_waste_vol_unit_cd, p_hazardous_cd, p_hazardous_cd, p_hazardous_cd, p_hazardous_cd, p_hazardous_cd, p_notes, p_notes, p_notes, p_notes, p_notes, p_source_ind, p_source_ind, p_source_ind, p_source_ind, p_source_ind, p_source_manufacturer, p_source_manufacturer, p_source_manufacturer, p_source_manufacturer, p_source_manufacturer;
  END;

