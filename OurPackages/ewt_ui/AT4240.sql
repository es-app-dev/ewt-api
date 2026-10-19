-- EWT_UI fragment: AT4240
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4240 GIC_CONTAINERS (record group GIC_CONTAINERS); not OData: a join
  PROCEDURE at4240_lov_gic_containers(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT4240 LOV_COST (record group RG_COST); not OData: a join
  PROCEDURE at4240_lov_lov_cost(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4240 GIC_CONTAINERS: the record group's own query; P1 = :AT$CTRL.NPC
  PROCEDURE at4240_lov_gic_containers(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select DISTINCT b.cntnr_seq_id, b.container_id,b.next_prctrantyp_seq_id next_npc_seq_id,c.prctrantyp_cd_id dsp_npc_code from at_container_processes a, at_containers b, at_process_trans_types c where a.cntnr_seq_id = b.cntnr_seq_id and b.next_prctrantyp_seq_id = c.prctrantyp_seq_id and c.prctrantyp_cd_id = :b1 and b.cntnr_stat_cd_id = 'IN USE' and NOT EXISTS (SELECT * FROM at_container_processes d where d.parent_cntnr_seq_id = a.cntnr_seq_id) and NOT EXISTS (SELECT * FROM at_container_processes e where e.cntnr_seq_id = a.cntnr_seq_id and e.parent_daughter_type_cd = 'PARENT') order by b.container_id
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT4240 LOV_COST: the record group's own query; P1 = :AT_CONTAINERS.NEW_NPC_SEQ_ID, P2 = :AT_CONTAINERS.ADVNOTIF_SEQ_ID
  PROCEDURE at4240_lov_lov_cost(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT CPS.COST PRICE
     , CPS.UNIT_CD_ID PRICE_UNIT_CD_ID
     , PS.PRODSERV_CD PRODSERV_CD
     , SUBSTR(PS.DESCRIPTION,1,40) PRODSERV_DESC
     , PS.PRODSERV_SEQ_ID PRODSERV_SEQ,SUBSTR(CPS.DESCRIPTION,1,60) SPECIAL_INS 
     , DS.CODE DISP_SITE
     , SOLI.SEGORDLITM_SEQ_ID
         SEGORDLITM_SEQ_ID
  FROM AT_PRODUCT_SERVICES PS
     , AT_CONTRACT_PROD_SERVICES CPS
     , AT_SEG_ORDER_LINE_ITEMS SOLI
     , AT_DISP_SITES DS
     , AT_PROCESS_TRANS_SERVICES PTS
  WHERE PS.PRODSERV_SEQ_ID = CPS.PRODSERV_SEQ_ID
    AND CPS.DISP_SITE_SEQ_ID = DS.DISP_SITE_SEQ_ID
    AND CPS.CNPRODSERV_SEQ_ID = SOLI.CNPRODSERV_SEQ_ID
    AND CPS.PRODSERV_SEQ_ID = PTS.PRODSERV_SEQ_ID
    AND PTS.PRCTRANTYP_SEQ_ID = :b1
    AND SOLI.ADVNOTIF_SEQ_ID = :b2
    AND NVL(PS.INCLUDE_MAP_IND,'N') = 'Y' 
    AND SOLI.STATUS_CD = 'OPEN'
    AND (NVL(CPS.GROUP_NBR,0) = 0 OR
        (NVL(CPS.GROUP_NBR,0) <> 0 
      AND NVL(CPS.SUBGROUP_NBR,0) <> 0))
  ORDER BY PS.PRODSERV_CD, CPS.UNIT_CD_ID, CPS.COST
) WHERE ROWNUM <= 5000~'
      USING p1, p2;
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

