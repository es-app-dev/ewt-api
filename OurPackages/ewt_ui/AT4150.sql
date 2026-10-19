-- EWT_UI fragment: AT4150
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4150 BATCH_PARENTS (record group BATCH_PARENTS); not OData: could not read the query (expected FROM at "")
  PROCEDURE at4150_lov_batch_parents(p_rows OUT SYS_REFCURSOR);
  -- AT4150 LOV_COST (record group RG_COST); not OData: a join
  PROCEDURE at4150_lov_lov_cost(p1 IN NUMBER, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT4150 MAP_NONMAP_NPC (record group MAP_NONMAP_NPC); not OData: a join
  PROCEDURE at4150_lov_map_nonmap_npc(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT4150 MATERIAL_TYPES (record group MATERIAL_TYPES); not OData: function TO_CHAR
  PROCEDURE at4150_lov_material_types(p_rows OUT SYS_REFCURSOR);
  -- AT4150 PARENT_CONTENTS (record group MATERIAL_TYPES); not OData: function TO_CHAR
  PROCEDURE at4150_lov_parent_contents(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4150 BATCH_PARENTS: the record group's own query
  PROCEDURE at4150_lov_batch_parents(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select ac.cntnr_seq_id, 
       ac.container_id, 
       ac.cntnr_stat_cd_id status_desc, 
       ac.description, 
       ac.gross_wgt, 
       ac.tare_wgt, 
       ac.gross_wgt - ac.tare_wgt waste_wgt,
       ac.used_vol,
       ac.VOID_SPACE_AMT,
       AC.NEXT_PRCTRANTYP_SEQ_ID, 
       ATT.PRCTRANTYP_CD_ID PRCTRANTYP_CD_ID,
       AC.DISP_SITE_LOCK_IND,
       AC.DISP_SITE_SEQ_ID,
       AC.ANCHOR_WGT,
       CT.CONTAINER_TYPE_CD
from at_containers ac, 
     AT_PROCESS_TRANS_TYPES ATT,
     AT_CONTAINER_TYPES CT
where AC.NEXT_PRCTRANTYP_SEQ_ID = ATT.PRCTRANTYP_SEQ_ID
  and ac.cntnr_stat_cd_id = 'IN USE'  
  AND AC.CNTNR_TYP_SEQ_ID = CT.CNTNR_TYP_SEQ_ID
  AND NOT EXISTS (SELECT BP.CNTNR_SEQ_ID FROM AT_CONTAINER_PROCESSES BP 
                  WHERE BP.CNTNR_SEQ_ID = AC.CNTNR_SEQ_ID AND                                                        BP.PARENT_DAUGHTER_TYPE_CD = 'PARENT' AND BP.BYPRODHDRS_SEQ_ID IS NULL) 
--      and
--      FAMILY_MAPPED(AC.CNTNR_SEQ_ID) > 0
      order by ac.container_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4150 LOV_COST: the record group's own query; P1 = :BATCH_PARENTS.ADVNOTIF_SEQ_ID, P2 = :XFER_DAUGHTER.DSP_NEXT_PRCTRANTYP_CD_ID
  PROCEDURE at4150_lov_lov_cost(p1 IN NUMBER, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT 
PS.PRODSERV_CD PRODSERV_CD
,DISP.ALIAS
,NVL(SOLI.ORDERED_QTY,0) ORDERED_QTY
,SOLI.SEGORDLITM_SEQ_ID SEGORDLITM_SEQ_ID
,'A' COST_TYPE
,CV.CNPRODSERV_DESCR
,SUBSTR(PS.DESCRIPTION,1,40) PRODSERV_DESC
FROM AT_PRODUCT_SERVICES PS,AT_CONTRACT_PROD_SERVICES CPS,AT_SEG_ORDER_LINE_ITEMS SOLI
,AT_PROCESS_TRANS_SERVICES NS,AT_PROCESS_TRANS_TYPES PTT,AT_DISP_SITES DISP,AT_CNPRODSERV_VIEW CV
WHERE PS.PRODSERV_SEQ_ID = CPS.PRODSERV_SEQ_ID
AND PS.PRODSERV_SEQ_ID = NS.PRODSERV_SEQ_ID
AND CPS.CNPRODSERV_SEQ_ID = SOLI.CNPRODSERV_SEQ_ID
AND CPS.CNPRODSERV_SEQ_ID = CV.CNPRODSERV_SEQ_ID
AND PTT.PRCTRANTYP_SEQ_ID = NS.PRCTRANTYP_SEQ_ID
AND CPS.DISP_SITE_SEQ_ID = DISP.DISP_SITE_SEQ_ID
AND SOLI.ADVNOTIF_SEQ_ID = :b1
AND PTT.PRCTRANTYP_CD_ID = :b2
AND NVL(PS.INCLUDE_MAP_IND,'N') = 'Y'
AND SOLI.STATUS_CD = 'OPEN'
ORDER BY PS.PRODSERV_CD
) WHERE ROWNUM <= 5000~'
      USING p1, p2;
  END;

  -- AT4150 MAP_NONMAP_NPC: the record group's own query; P1 = :BATCH_HDR.BATCH_SEQ_ID
  PROCEDURE at4150_lov_map_nonmap_npc(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT DISTINCT vnt.PRCTRANTYP_CD_ID PRCTRANTYP_CD_ID 
,vnt.PRCTRANTYP_SEQ_ID PRCTRANTYP_SEQ_ID
,vnt.MAP_IND MAP_IND
,vnt.DESCRIPTION DESCRIPTION
,'From Order' data_source
, ptt.rtc_ind
FROM AT_VALID_NPC_TMP vnt
    ,at_process_trans_types ptt
WHERE vnt.BATCH_NBR = :b1
  and vnt.prctrantyp_seq_id = ptt.prctrantyp_seq_id
  and NVL(ptt.obsolete_flag,'Y') = 'N'
UNION ALL
select 
ptt.prctrantyp_cd_id
,ptt.prctrantyp_seq_id
,'Map Not Required' map_ind
,ptt.description
,ptt.rtc_ind
,'Not from Order' data_source
from at_process_trans_types ptt_b,at_process_trans_types ptt
where ptt_b.prctrantyp_seq_id(+) = ptt.within_prctrantyp_seq_id
and NVL(ptt.map_ind,'N') = 'N'
and NVL(ptt.obsolete_flag,'Y') = 'N'
and ptt.prctrantyp_seq_id not in
 (select a.prctrantyp_seq_id from at_valid_npc_tmp A where A.BATCH_NBR = :b2)
ORDER BY 5,1
) WHERE ROWNUM <= 5000~'
      USING p1, p1;
  END;

  -- AT4150 MATERIAL_TYPES: the record group's own query
  PROCEDURE at4150_lov_material_types(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select material_type_cd, to_char(matl_typ_seq_id) matl_typ_seq_id, description, high_price_ind from at_material_types where NVL(SHOW_IN_LOV,'N') = 'Y' order by material_type_cd
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4150 PARENT_CONTENTS: the record group's own query
  PROCEDURE at4150_lov_parent_contents(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select material_type_cd, to_char(matl_typ_seq_id) matl_typ_seq_id, description, high_price_ind from at_material_types where NVL(SHOW_IN_LOV,'N') = 'Y' order by material_type_cd
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

