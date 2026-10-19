-- EWT_UI fragment: WB4000
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- WB4000 OPEN_PARENTS: WB_QTB_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb4000_w_open_parents(p_parent_empty_ind IN VARCHAR2, p_parent_container_id IN VARCHAR2, p_parent_full_wgt IN NUMBER, p_parent_empty_wgt IN NUMBER, p_psc IN VARCHAR2, p_advnotif_seq_id IN NUMBER, p_qtb_seq_id IN NUMBER, p_parent_cntnr_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_pseudo_parent_container_id IN VARCHAR2, p_parent_container_type IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB4000 OPEN_QTB: WB_QTB_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb4000_w_open_qtb(p_qtb_closed_ind IN VARCHAR2, p_qtb_barcode IN VARCHAR2, p_full_wgt IN NUMBER, p_empty_wgt IN NUMBER, p_container_type IN VARCHAR2, p_qtb_seq_id IN NUMBER, p_qtb_cntnr_seq_id IN NUMBER, p_cntnr_typ_seq_id IN NUMBER, p_sort_area IN VARCHAR2, p_alt_container_type IN VARCHAR2, p_sort_status IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- WB4000 WB_INCOMING_MANIFESTS: AT_INCOMING_MANIFESTS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb4000_w_wb_incoming_manifests(p_advnotif_seq_id IN NUMBER, p_manifest_nbr IN VARCHAR2, p_cust_seq_id IN NUMBER, p_processing_hold_ind IN VARCHAR2, p_brokered_shipment_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- WB4000 ITEMS (record group ITEMS); not OData: a join
  PROCEDURE wb4000_lov_items(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- WB4000 MID_PSC (record group PSC); not OData: a join
  PROCEDURE wb4000_lov_mid_psc(p1 IN VARCHAR2, p2 IN VARCHAR2, p3 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- WB4000 QTB_BURIAL_PARENT_LV (record group QTB_BURIAL_PARENT_RG); not OData: could not read the query (expected FROM at "")
  PROCEDURE wb4000_lov_qtb_burial_parent_l(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- WB4000 VALID_NPC (record group VALID_NPC); not OData: a join
  PROCEDURE wb4000_lov_valid_npc(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY




  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- WB4000 OPEN_PARENTS: WB_QTB_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb4000_w_open_parents(p_parent_empty_ind IN VARCHAR2, p_parent_container_id IN VARCHAR2, p_parent_full_wgt IN NUMBER, p_parent_empty_wgt IN NUMBER, p_psc IN VARCHAR2, p_advnotif_seq_id IN NUMBER, p_qtb_seq_id IN NUMBER, p_parent_cntnr_seq_id IN NUMBER, p_prodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_pseudo_parent_container_id IN VARCHAR2, p_parent_container_type IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_QTB_CONTAINERS
 WHERE (
NVL(PARENT_EMPTY_IND,'N') = 'N'
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN parent_empty_ind LIKE :c4 THEN 1 END WHEN parent_empty_ind = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN parent_container_id LIKE :c9 THEN 1 END WHEN parent_container_id = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR parent_full_wgt = :c12)
   AND (:c13 IS NULL OR parent_empty_wgt = :c14)
   AND (:c15 IS NULL OR (CASE WHEN INSTR(:c16, '%') + INSTR(:c17, '_') > 0 THEN CASE WHEN psc LIKE :c18 THEN 1 END WHEN psc = :c19 THEN 1 END) = 1)
   AND (:c20 IS NULL OR advnotif_seq_id = :c21)
   AND (:c22 IS NULL OR qtb_seq_id = :c23)
   AND (:c24 IS NULL OR parent_cntnr_seq_id = :c25)
   AND (:c26 IS NULL OR prodserv_seq_id = :c27)
   AND (:c28 IS NULL OR disp_site_seq_id = :c29)
   AND (:c30 IS NULL OR cust_seq_id = :c31)
   AND (:c32 IS NULL OR (CASE WHEN INSTR(:c33, '%') + INSTR(:c34, '_') > 0 THEN CASE WHEN pseudo_parent_container_id LIKE :c35 THEN 1 END WHEN pseudo_parent_container_id = :c36 THEN 1 END) = 1)
   AND (:c37 IS NULL OR (CASE WHEN INSTR(:c38, '%') + INSTR(:c39, '_') > 0 THEN CASE WHEN parent_container_type LIKE :c40 THEN 1 END WHEN parent_container_type = :c41 THEN 1 END) = 1)
 ORDER BY SORT_DT DESC
) WHERE ROWNUM <= 5000~'
      USING p_parent_empty_ind, p_parent_empty_ind, p_parent_empty_ind, p_parent_empty_ind, p_parent_empty_ind, p_parent_container_id, p_parent_container_id, p_parent_container_id, p_parent_container_id, p_parent_container_id, p_parent_full_wgt, p_parent_full_wgt, p_parent_empty_wgt, p_parent_empty_wgt, p_psc, p_psc, p_psc, p_psc, p_psc, p_advnotif_seq_id, p_advnotif_seq_id, p_qtb_seq_id, p_qtb_seq_id, p_parent_cntnr_seq_id, p_parent_cntnr_seq_id, p_prodserv_seq_id, p_prodserv_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_cust_seq_id, p_cust_seq_id, p_pseudo_parent_container_id, p_pseudo_parent_container_id, p_pseudo_parent_container_id, p_pseudo_parent_container_id, p_pseudo_parent_container_id, p_parent_container_type, p_parent_container_type, p_parent_container_type, p_parent_container_type, p_parent_container_type;
  END;

  -- WB4000 OPEN_QTB: WB_QTB_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb4000_w_open_qtb(p_qtb_closed_ind IN VARCHAR2, p_qtb_barcode IN VARCHAR2, p_full_wgt IN NUMBER, p_empty_wgt IN NUMBER, p_container_type IN VARCHAR2, p_qtb_seq_id IN NUMBER, p_qtb_cntnr_seq_id IN NUMBER, p_cntnr_typ_seq_id IN NUMBER, p_sort_area IN VARCHAR2, p_alt_container_type IN VARCHAR2, p_sort_status IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_QTB_CONTAINERS
 WHERE (
NVL(QTB_CLOSED_IND,'S') = 'N'
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN qtb_closed_ind LIKE :c4 THEN 1 END WHEN qtb_closed_ind = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN qtb_barcode LIKE :c9 THEN 1 END WHEN qtb_barcode = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR full_wgt = :c12)
   AND (:c13 IS NULL OR empty_wgt = :c14)
   AND (:c15 IS NULL OR (CASE WHEN INSTR(:c16, '%') + INSTR(:c17, '_') > 0 THEN CASE WHEN container_type LIKE :c18 THEN 1 END WHEN container_type = :c19 THEN 1 END) = 1)
   AND (:c20 IS NULL OR qtb_seq_id = :c21)
   AND (:c22 IS NULL OR qtb_cntnr_seq_id = :c23)
   AND (:c24 IS NULL OR cntnr_typ_seq_id = :c25)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN sort_area LIKE :c29 THEN 1 END WHEN sort_area = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR (CASE WHEN INSTR(:c32, '%') + INSTR(:c33, '_') > 0 THEN CASE WHEN alt_container_type LIKE :c34 THEN 1 END WHEN alt_container_type = :c35 THEN 1 END) = 1)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN sort_status LIKE :c39 THEN 1 END WHEN sort_status = :c40 THEN 1 END) = 1)
 ORDER BY SORT_DT DESC
) WHERE ROWNUM <= 5000~'
      USING p_qtb_closed_ind, p_qtb_closed_ind, p_qtb_closed_ind, p_qtb_closed_ind, p_qtb_closed_ind, p_qtb_barcode, p_qtb_barcode, p_qtb_barcode, p_qtb_barcode, p_qtb_barcode, p_full_wgt, p_full_wgt, p_empty_wgt, p_empty_wgt, p_container_type, p_container_type, p_container_type, p_container_type, p_container_type, p_qtb_seq_id, p_qtb_seq_id, p_qtb_cntnr_seq_id, p_qtb_cntnr_seq_id, p_cntnr_typ_seq_id, p_cntnr_typ_seq_id, p_sort_area, p_sort_area, p_sort_area, p_sort_area, p_sort_area, p_alt_container_type, p_alt_container_type, p_alt_container_type, p_alt_container_type, p_alt_container_type, p_sort_status, p_sort_status, p_sort_status, p_sort_status, p_sort_status;
  END;

  -- WB4000 WB_INCOMING_MANIFESTS: AT_INCOMING_MANIFESTS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb4000_w_wb_incoming_manifests(p_advnotif_seq_id IN NUMBER, p_manifest_nbr IN VARCHAR2, p_cust_seq_id IN NUMBER, p_processing_hold_ind IN VARCHAR2, p_brokered_shipment_ind IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_INCOMING_MANIFESTS
 WHERE (
MNFSTSTAT_CD_ID = 'QC RELEASE' AND ADVNOTIF_SEQ_ID = NO_MANIFEST_DAUGHTERS(ADVNOTIF_SEQ_ID)
)
   AND (:c1 IS NULL OR advnotif_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN manifest_nbr LIKE :c6 THEN 1 END WHEN manifest_nbr = :c7 THEN 1 END) = 1)
   AND (:c8 IS NULL OR cust_seq_id = :c9)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN processing_hold_ind LIKE :c13 THEN 1 END WHEN processing_hold_ind = :c14 THEN 1 END) = 1)
   AND (:c15 IS NULL OR (CASE WHEN INSTR(:c16, '%') + INSTR(:c17, '_') > 0 THEN CASE WHEN brokered_shipment_ind LIKE :c18 THEN 1 END WHEN brokered_shipment_ind = :c19 THEN 1 END) = 1)
 ORDER BY ADVNOTIF_EXPECTED_RECPT_DT DESC
) WHERE ROWNUM <= 5000~'
      USING p_advnotif_seq_id, p_advnotif_seq_id, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_cust_seq_id, p_cust_seq_id, p_processing_hold_ind, p_processing_hold_ind, p_processing_hold_ind, p_processing_hold_ind, p_processing_hold_ind, p_brokered_shipment_ind, p_brokered_shipment_ind, p_brokered_shipment_ind, p_brokered_shipment_ind, p_brokered_shipment_ind;
  END;
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- WB4000 ITEMS: the record group's own query; P1 = :WB_QTB_CONTAINER.PARENT_CNTNR_SEQ_ID
  PROCEDURE wb4000_lov_items(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT a.manifested_line_item_nbr
      ,b.container_type_cd
      ,a.matl_seq_id
      ,a.advnotif_seq_id
FROM   at_materials a
      ,at_container_types b
      ,at_materials m2
WHERE      a.cntnr_typ_seq_id = b.cntnr_typ_seq_id
       AND a.parent_matl_seq_id = m2.matl_seq_id
       AND m2.cntnr_seq_id = :b1
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- WB4000 MID_PSC: the record group's own query; P1 = :FIRST_DAUGHTERS.NEXT_PROCESS_CD, P2 = :FIRST_DAUGHTERS.DSP_NEXT_PROCESS_CD, P3 = :WB_QTB_CONTAINER.ADVNOTIF_SEQ_ID
  PROCEDURE wb4000_lov_mid_psc(p1 IN VARCHAR2, p2 IN VARCHAR2, p3 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   DISTINCT ps.prodserv_cd psc
                 ,ds.alias
                 ,cps.description sp_instr
                 ,ps.description psc_desc
                 ,ps.prodserv_seq_id
                 ,cps.cnprodserv_seq_id
                 ,cps.cost
                 ,'A' cost_type
FROM     at_product_services ps
        ,at_process_trans_services ns
        ,at_process_trans_types ptt
        ,at_contract_prod_services cps
        ,at_seg_order_line_items soli
        ,at_disp_sites ds
WHERE        ptt.prctrantyp_seq_id = ns.prctrantyp_seq_id
         AND cps.prodserv_seq_id = ns.prodserv_seq_id
         AND cps.disp_site_seq_id = ds.disp_site_seq_id
         AND NVL(ps.include_map_ind, 'N') = 'Y'
         AND ptt.prctrantyp_cd_id = NVL( :b1, :b2)
         AND ps.prodserv_seq_id = cps.prodserv_seq_id
         AND cps.cnprodserv_seq_id = soli.cnprodserv_seq_id
         AND soli.advnotif_seq_id = :b3
         AND soli.status_cd = 'OPEN'
         AND NOT EXISTS
                 (SELECT 1
                  FROM   at_seg_order_line_items soli1
                  WHERE      soli1.grp_cnprodserv_seq_id = soli.cnprodserv_seq_id
                         AND soli1.advnotif_seq_id = :b4)
ORDER BY 1
) WHERE ROWNUM <= 5000~'
      USING p1, p2, p3, p3;
  END;

  -- WB4000 QTB_BURIAL_PARENT_LV: the record group's own query; P1 = :WB_QTB_CONTAINER.PARENT_CONTAINER_ID
  PROCEDURE wb4000_lov_qtb_burial_parent_l(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT t.qtb_barcode barcode
      ,t.full_wgt - t.empty_wgt full_wgt
      ,t.empty_wgt
      ,t.psc
      ,t.contents_pl
      ,t.contents_pa
      ,t.contents_cl
      ,t.contents_mt
      ,t.contents_wd
      ,t.contents_rb
      ,t.contents_as
      ,t.contents_al
      ,t.contents_ss
      ,t.contents_cp
      ,t.contents_ot
      ,t.contents_ot2
      ,t.qtb_cntnr_seq_id cntnr_seq_id
      ,t.other_contents_desc
      ,t.other_contents_desc2
      ,t.other_matl_typ_seq_id2
      ,t.other_matl_typ_seq_id
FROM   wb_qtb_containers t
WHERE      t.parent_container_id = :b1
       AND t.qtb_barcode IS NOT NULL
       AND NVL(t.full_wgt, 0) - NVL(t.empty_wgt, 0) <> 0
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- WB4000 VALID_NPC: the record group's own query; P1 = :WB_QTB_CONTAINER.ADVNOTIF_SEQ_ID
  PROCEDURE wb4000_lov_valid_npc(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   DISTINCT pt.prctrantyp_cd_id npc
                 ,ns.prctrantyp_seq_id next_npc_seq_id
                 ,pt.description
                 ,pt.rtc_ind
                 ,pt.prctrantyp_cd_id next_process_cd
FROM     at_product_services ps
        ,at_contract_prod_services cps
        ,at_seg_order_line_items soli
        ,at_process_trans_services ns
        ,at_process_trans_types pt
WHERE        ps.prodserv_seq_id = cps.prodserv_seq_id
         AND cps.cnprodserv_seq_id = soli.cnprodserv_seq_id
         AND pt.prctrantyp_seq_id = ns.prctrantyp_seq_id
         AND ns.prodserv_seq_id = ps.prodserv_seq_id
         AND soli.advnotif_seq_id = :b1
         AND soli.status_cd = 'OPEN'
         AND NVL(ps.include_map_ind, 'N') = 'Y'
         AND (   NVL(cps.group_nbr, 0) = 0
              OR (    NVL(cps.group_nbr, 0) <> 0
                  AND NVL(cps.subgroup_nbr, 0) <> 0))
         AND pt.show_in_lov = 'Y'
ORDER BY pt.prctrantyp_cd_id
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

