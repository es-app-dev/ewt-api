-- EWT_UI fragment: WB1000
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- WB1000 SEGORDLITM: AT_SEG_ORDER_LINE_ITEMS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb1000_w_segordlitm(b_mnfst_advnotif_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_line_item_nbr IN NUMBER, p_status_cd IN VARCHAR2, p_segordlitm_seq_id IN NUMBER, p_cnprodserv_seq_id IN NUMBER, p_grp_cnprodserv_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- WB1000 WB_CONT_NUC_VIEW: WB_CONT_NUC_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE wb1000_w_wb_cont_nuc_view(p_trkditm_cd IN VARCHAR2, p_trkditm_seq_id IN NUMBER, p_inc_man_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- WB1000 CGFK$CUSTTRCK_DSP_CODE (record group CGFK$CUSTTRCK_DSP_CODE); not OData: could not read the query (unexpected "not" in WHERE)
  PROCEDURE wb1000_lov_cgfk_custtrck_dsp_c(p1 IN NUMBER, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- WB1000 CGFK$MATLMATL_DSP_MATERIAL_TYP (record group CGFK$MATLMATL_DSP_MATERIAL_TYP); not OData: NOT / a subquery in WHERE
  PROCEDURE wb1000_lov_cgfk_matlmatl_dsp_m(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- WB1000 CONTAINER_DISP_SITES (record group ORDER_DISP_SITES); not OData: a subquery in WHERE
  PROCEDURE wb1000_lov_container_disp_site(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- WB1000 CUST_VIEW_LV (record group CUST_VIEW_RG); not OData: a join
  PROCEDURE wb1000_lov_cust_view_lv(p_rows OUT SYS_REFCURSOR);
  -- WB1000 NPC_CODES (record group NPC_CODES); not OData: a join
  PROCEDURE wb1000_lov_npc_codes(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- WB1000 ORDER_DISP_SITES (record group ORDER_DISP_SITES); not OData: a subquery in WHERE
  PROCEDURE wb1000_lov_order_disp_sites(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- WB1000 PSC_LV (record group PSC_RG); not OData: a join
  PROCEDURE wb1000_lov_psc_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY







  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- WB1000 SEGORDLITM: AT_SEG_ORDER_LINE_ITEMS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb1000_w_segordlitm(b_mnfst_advnotif_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_line_item_nbr IN NUMBER, p_status_cd IN VARCHAR2, p_segordlitm_seq_id IN NUMBER, p_cnprodserv_seq_id IN NUMBER, p_grp_cnprodserv_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_SEG_ORDER_LINE_ITEMS
 WHERE (
ADVNOTIF_SEQ_ID = :w1
)
   AND (:c1 IS NULL OR advnotif_seq_id = :c2)
   AND (:c3 IS NULL OR line_item_nbr = :c4)
   AND (:c5 IS NULL OR (CASE WHEN INSTR(:c6, '%') + INSTR(:c7, '_') > 0 THEN CASE WHEN status_cd LIKE :c8 THEN 1 END WHEN status_cd = :c9 THEN 1 END) = 1)
   AND (:c10 IS NULL OR segordlitm_seq_id = :c11)
   AND (:c12 IS NULL OR cnprodserv_seq_id = :c13)
   AND (:c14 IS NULL OR grp_cnprodserv_seq_id = :c15)
) WHERE ROWNUM <= 5000~'
      USING b_mnfst_advnotif_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_line_item_nbr, p_line_item_nbr, p_status_cd, p_status_cd, p_status_cd, p_status_cd, p_status_cd, p_segordlitm_seq_id, p_segordlitm_seq_id, p_cnprodserv_seq_id, p_cnprodserv_seq_id, p_grp_cnprodserv_seq_id, p_grp_cnprodserv_seq_id;
  END;

  -- WB1000 WB_CONT_NUC_VIEW: WB_CONT_NUC_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb1000_w_wb_cont_nuc_view(p_trkditm_cd IN VARCHAR2, p_trkditm_seq_id IN NUMBER, p_inc_man_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_CONT_NUC_VIEW
 WHERE (
trkditm_cd not in (select code from at_tracked_items)
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN trkditm_cd LIKE :c4 THEN 1 END WHEN trkditm_cd = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR trkditm_seq_id = :c7)
   AND (:c8 IS NULL OR inc_man_seq_id = :c9)
) WHERE ROWNUM <= 5000~'
      USING p_trkditm_cd, p_trkditm_cd, p_trkditm_cd, p_trkditm_cd, p_trkditm_cd, p_trkditm_seq_id, p_trkditm_seq_id, p_inc_man_seq_id, p_inc_man_seq_id;
  END;
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- WB1000 CGFK$CUSTTRCK_DSP_CODE: the record group's own query; P1 = :MATL.MATL_SEQ_ID, P2 = :MATL.HLD_NUCLIDE_CODE
  PROCEDURE wb1000_lov_cgfk_custtrck_dsp_c(p1 IN NUMBER, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select trkditm.code dsp_code /* cg$fk */ ,trkditm.description dsp_description4 ,trkditm.snm_ind dsp_snm_ind ,trkditm.source_material_ind dsp_source_material_ind ,trkditm.trkditm_seq_id trkditm_seq_id, trkditm.snm_sm_convt_fctr_amt snm_sm_convt_fctr_amt from at_tracked_items trkditm where trkditm.trkditm_seq_id not in (select trkditm_seq_id from at_cust_doc_tracked_items where matl_seq_id = :b1) and trkditm.code not in (:b2||nvl(:b3,' '))
) WHERE ROWNUM <= 5000~'
      USING p1, p2, p2;
  END;

  -- WB1000 CGFK$MATLMATL_DSP_MATERIAL_TYP: the record group's own query; P1 = :MATL.MATL_SEQ_ID
  PROCEDURE wb1000_lov_cgfk_matlmatl_dsp_m(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select matl_typ.material_type_cd dsp_material_type_cd /* cg$fk */ 
,matl_typ.description dsp_description 
,matl_typ.matl_typ_seq_id matl_typ_seq_id
, nvl(order_by_nbr,1000) order_by_nbr
,matl_typ.agent_media_ind 
from at_material_types matl_typ 
where not exists 
(select 'x' 
from at_material_to_material_types types 
where types.matl_typ_seq_id = matl_typ.matl_typ_seq_id 
and types.matl_seq_id = :b1)
and NVL(matl_typ.show_in_lov,'N') = 'Y' 
order by order_by_nbr, material_type_cd
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- WB1000 CONTAINER_DISP_SITES: the record group's own query; P1 = :MNFST.ADVNOTIF_SEQ_ID
  PROCEDURE wb1000_lov_container_disp_site(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.code, a.description,a.disp_site_seq_id from at_disp_sites a
where a.disp_site_seq_id in (select b.disp_site_seq_id from at_order_disp_sites b
where b.advnotif_seq_id = :b1)
order by a.code
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- WB1000 CUST_VIEW_LV: the record group's own query
  PROCEDURE wb1000_lov_cust_view_lv(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select cust.customer_nbr cust_customer_nbr
, cust.abbreviated_name cust_abbreviated_name
, cust.name cust_name
, cust.cust_seq_id cust_cust_seq_id 
, a.street_addr street
, a.city_addr city
, a.st_prvnc_abbr_id state
from at_customers cust
    ,at_contacts c
    ,at_contacts_contact_types cct
    ,at_contact_types ct
    ,at_addresses a
where cust.cust_seq_id = c.cust_seq_id
  and c.cntct_seq_id = cct.cntct_seq_id
  and c.addr_seq_id = a.addr_seq_id
  and cct.cntct_typ_seq_id = ct.cntct_typ_seq_id
  and ct.code = 'SHIPPING'
order by cust_name
) WHERE ROWNUM <= 5000~';
  END;

  -- WB1000 NPC_CODES: the record group's own query; P1 = :MATL.ADVNOTIF_SEQ_ID
  PROCEDURE wb1000_lov_npc_codes(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT npc.PRCTRANTYP_CD_ID, npc.DESCRIPTION, npc.PRCTRANTYP_seq_id 
FROM at_process_trans_types npc,
  at_process_trans_services pts,
  at_product_services ps,
  at_contract_prod_services cps,
  at_seg_order_line_items soli
WHERE cps.prodserv_seq_id = ps.prodserv_seq_id
 AND cps.cnprodserv_seq_id = soli.cnprodserv_seq_id
 AND ps.prodserv_seq_id = pts.prodserv_seq_id
 AND pts.prctrantyp_seq_id = npc.prctrantyp_seq_id
 AND soli.status_cd = 'OPEN'
 AND(cps.group_nbr IS NULL OR(cps.group_nbr IS NOT NULL
 AND cps.subgroup_nbr IS NOT NULL))
 AND nvl(ps.include_map_ind,   'N') = 'Y'
 AND soli.advnotif_seq_id = :b1
 and NVL(npc.obsolete_flag,'Y') = 'N'
UNION
SELECT 'NONE','NONE SELECTED',0
FROM AT_PROCESS_TRANS_TYPES
ORDER BY PRCTRANTYP_CD_ID
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- WB1000 ORDER_DISP_SITES: the record group's own query; P1 = :MNFST.ADVNOTIF_SEQ_ID
  PROCEDURE wb1000_lov_order_disp_sites(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.code, a.description,a.disp_site_seq_id from at_disp_sites a
where a.disp_site_seq_id in (select b.disp_site_seq_id from at_order_disp_sites b
where b.advnotif_seq_id = :b1)
order by a.code
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- WB1000 PSC_LV: the record group's own query; P1 = :MNFST.ADVNOTIF_SEQ_ID
  PROCEDURE wb1000_lov_psc_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select soli.segordlitm_seq_id
,ps.prodserv_cd
,cps.description sp_instr
,ps.description description
from at_product_services ps
    ,at_contract_prod_services cps
    ,at_seg_order_line_items soli
where ps.prodserv_seq_id = cps.prodserv_seq_id
and cps.cnprodserv_seq_id = soli.cnprodserv_seq_id
and soli.advnotif_seq_id = :b1
and soli.status_cd = 'OPEN'
AND(cps.group_nbr IS NULL OR(cps.group_nbr IS NOT NULL
AND cps.subgroup_nbr IS NOT NULL))
and NVL(ps.include_map_ind,'N') = 'Y'
order by 2
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

