-- EWT_UI fragment: AT1552
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT1552 DAUGHTER_CONTAINERS (record group DAUGHTER_CONTAINERS); not OData: a join
  PROCEDURE at1552_lov_daughter_containers(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT1552 LOV_COST (record group RG_COST); not OData: a join
  PROCEDURE at1552_lov_lov_cost(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1552 UNMAPPED_ORDERS: AT_BARCODE_ORDER_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at1552_w_unmapped_orders(b_at_containers_cntnr_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_manifest_nbr IN VARCHAR2, p_cust_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

--#BODY
  -- AT1552 DAUGHTER_CONTAINERS: the record group's own query; P1 = :AT_CONTAINERS.CONTAINER_ID
  PROCEDURE at1552_lov_daughter_containers(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select DISTINCT ac.cntnr_seq_id, ac.container_id from at_containers ac, at_container_processes acp where acp.cntnr_seq_id = ac.cntnr_seq_id and acp.parent_daughter_type_cd = 'DAUGHTER' and ac.cntnr_stat_cd_id <> 'SHIPPED' and ac.container_id like :b1 order by ac.container_id
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1552 LOV_COST: the record group's own query; P1 = :LICPROC.ADVNOTIF_SEQ_ID
  PROCEDURE at1552_lov_lov_cost(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT CPS.COST COST,CPS.UNIT_CD_ID UNIT_CD_ID,NVL(SOLI.ORDERED_QTY,0) ORDERED_QTY,SOLI.SEGORDLITM_SEQ_ID SEGORDLITM_SEQ_ID,PS.PRODSERV_CD PRODSERV_CD,'A' COST_TYPE,SUBSTR(PS.DESCRIPTION,1,40) PRODSERV_DESC, PS.PRODSERV_SEQ_ID PRODSERV_SEQ_ID, SUBSTR(CPS.DESCRIPTION,1,65) SPECIAL_INS,DS.CODE DISP_SITE FROM AT_PRODUCT_SERVICES PS,AT_CONTRACT_PROD_SERVICES CPS, AT_SEG_ORDER_LINE_ITEMS SOLI,AT_DISP_SITES DS WHERE PS.PRODSERV_SEQ_ID = CPS.PRODSERV_SEQ_ID AND CPS.DISP_SITE_SEQ_ID = DS.DISP_SITE_SEQ_ID AND CPS.CNPRODSERV_SEQ_ID = SOLI.CNPRODSERV_SEQ_ID AND SOLI.ADVNOTIF_SEQ_ID = :b1 AND NVL(PS.INCLUDE_MAP_IND,'N') = 'Y' AND SOLI.STATUS_CD = 'OPEN' 
AND (NVL(CPS.GROUP_NBR,0) = 0 OR
    (NVL(CPS.GROUP_NBR,0) <> 0 AND NVL(CPS.SUBGROUP_NBR,0) <> 0))
ORDER BY PS.PRODSERV_CD, CPS.UNIT_CD_ID,CPS.COST
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1552 UNMAPPED_ORDERS: AT_BARCODE_ORDER_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1552_w_unmapped_orders(b_at_containers_cntnr_seq_id IN NUMBER, p_advnotif_seq_id IN NUMBER, p_manifest_nbr IN VARCHAR2, p_cust_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_BARCODE_ORDER_VIEW
 WHERE (
cntnr_seq_id = :w1
)
   AND (:c1 IS NULL OR advnotif_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN manifest_nbr LIKE :c6 THEN 1 END WHEN manifest_nbr = :c7 THEN 1 END) = 1)
   AND (:c8 IS NULL OR cust_seq_id = :c9)
 ORDER BY advnotif_seq_id
) WHERE ROWNUM <= 5000~'
      USING b_at_containers_cntnr_seq_id, p_advnotif_seq_id, p_advnotif_seq_id, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_cust_seq_id, p_cust_seq_id;
  END;

