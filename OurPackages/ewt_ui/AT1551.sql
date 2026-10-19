-- EWT_UI fragment: AT1551
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT1551 CGFK$CNTNR_DSP_PRCTRANTYP_CD_I (record group PRCTRANS_TYPES_BY_ORDER); not OData: a join
  PROCEDURE at1551_lov_cgfk_cntnr_dsp_prct(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1551 LOV_COST (record group RG_COST); not OData: a join
  PROCEDURE at1551_lov_lov_cost(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1551 UNMAPPED_BARCODES: AT_ORDER_BARCODE_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at1551_w_unmapped_barcodes(b_at_incoming_manifests_o_621d IN NUMBER, p_container_id IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_next_prctrantyp_seq_id IN NUMBER, p_source IN VARCHAR2, p_prctrantyp_cd_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_description IN VARCHAR2, p_anchor_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR);

--#BODY
  -- AT1551 CGFK$CNTNR_DSP_PRCTRANTYP_CD_I: the record group's own query; P1 = :AT_INCOMING_MANIFESTS.ORD_NUM
  PROCEDURE at1551_lov_cgfk_cntnr_dsp_prct(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select DISTINCT ptt.prctrantyp_cd_id dsp_npc_code
     , ptt.description dsp_npc_description
     , ptt.prctrantyp_seq_id next_prctrantyp_seq_id 
from at_product_services ps
   , at_process_trans_services ppg
   , at_contract_prod_services cps
   , at_process_trans_types ptt
   , at_process_trans_types ptt_b 
where ptt.within_prctrantyp_seq_id = ptt_b.prctrantyp_seq_id(+)   and cps.cnprodserv_seq_id in 
    (select distinct cnprodserv_seq_id 
     from at_seg_order_line_items 
     where advnotif_seq_id = :b1 and      status_cd = 'OPEN') 
  and cps.prodserv_seq_id = ps.prodserv_seq_id
  and cps.prodserv_prodcat_seq_id = ps.prodcat_seq_id 
  and ps.prodserv_seq_id = ppg.prodserv_seq_id 
  and ppg.prctrantyp_seq_id = ptt.prctrantyp_seq_id 
    AND (NVL(CPS.GROUP_NBR,0) = 0 OR
        (NVL(CPS.GROUP_NBR,0) <> 0 
    AND NVL(CPS.SUBGROUP_NBR,0) <> 0))
order by ptt.prctrantyp_cd_id
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1551 LOV_COST: the record group's own query; P1 = :AT_INCOMING_MANIFESTS.ORD_NUM
  PROCEDURE at1551_lov_lov_cost(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT CPS.COST COST, CPS.UNIT_CD_ID UNIT_CD_ID, NVL(SOLI.ORDERED_QTY,0) ORDERED_QTY, SOLI.SEGORDLITM_SEQ_ID SEGORDLITM_SEQ_ID, PS.PRODSERV_CD PRODSERV_CD,'A' COST_TYPE, SUBSTR(PS.DESCRIPTION,1,40) PRODSERV_DESC, PS.PRODSERV_SEQ_ID PRODSERV_SEQ,SUBSTR(CPS.DESCRIPTION,1,60) SPECIAL_INS ,DS.CODE DISP_SITE
  FROM AT_PRODUCT_SERVICES PS
     , AT_CONTRACT_PROD_SERVICES CPS
     , AT_SEG_ORDER_LINE_ITEMS SOLI
     , AT_DISP_SITES DS
  WHERE PS.PRODSERV_SEQ_ID = CPS.PRODSERV_SEQ_ID
    AND CPS.DISP_SITE_SEQ_ID = DS.DISP_SITE_SEQ_ID
    AND CPS.CNPRODSERV_SEQ_ID = SOLI.CNPRODSERV_SEQ_ID
    AND SOLI.ADVNOTIF_SEQ_ID = :b1
    AND NVL(PS.INCLUDE_MAP_IND,'N') = 'Y' 
    AND SOLI.STATUS_CD = 'OPEN'
    AND (NVL(CPS.GROUP_NBR,0) = 0 OR
        (NVL(CPS.GROUP_NBR,0) <> 0 
    AND NVL(CPS.SUBGROUP_NBR,0) <> 0))
  ORDER BY PS.PRODSERV_CD, CPS.UNIT_CD_ID, CPS.COST
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1551 UNMAPPED_BARCODES: AT_ORDER_BARCODE_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1551_w_unmapped_barcodes(b_at_incoming_manifests_o_621d IN NUMBER, p_container_id IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_next_prctrantyp_seq_id IN NUMBER, p_source IN VARCHAR2, p_prctrantyp_cd_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_description IN VARCHAR2, p_anchor_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_ORDER_BARCODE_VIEW
 WHERE (
advnotif_seq_id = :w1
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN container_id LIKE :c4 THEN 1 END WHEN container_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN cntnr_stat_cd_id LIKE :c9 THEN 1 END WHEN cntnr_stat_cd_id = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR next_prctrantyp_seq_id = :c12)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN source LIKE :c16 THEN 1 END WHEN source = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN prctrantyp_cd_id LIKE :c21 THEN 1 END WHEN prctrantyp_cd_id = :c22 THEN 1 END) = 1)
   AND (:c23 IS NULL OR cntnr_seq_id = :c24)
   AND (:c25 IS NULL OR advnotif_seq_id = :c26)
   AND (:c27 IS NULL OR (CASE WHEN INSTR(:c28, '%') + INSTR(:c29, '_') > 0 THEN CASE WHEN description LIKE :c30 THEN 1 END WHEN description = :c31 THEN 1 END) = 1)
   AND (:c32 IS NULL OR anchor_wgt = :c33)
 ORDER BY container_id
) WHERE ROWNUM <= 5000~'
      USING b_at_incoming_manifests_o_621d, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_next_prctrantyp_seq_id, p_next_prctrantyp_seq_id, p_source, p_source, p_source, p_source, p_source, p_prctrantyp_cd_id, p_prctrantyp_cd_id, p_prctrantyp_cd_id, p_prctrantyp_cd_id, p_prctrantyp_cd_id, p_cntnr_seq_id, p_cntnr_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_description, p_description, p_description, p_description, p_description, p_anchor_wgt, p_anchor_wgt;
  END;

