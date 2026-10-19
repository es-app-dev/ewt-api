-- EWT_UI fragment: AT5210
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT5210 LV_MANIFESTS (record group RG_MANIFESTS); not OData: a join
  PROCEDURE at5210_lov_lv_manifests(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT5210 PARTITION_LOV (record group PARTITION_RG); not OData: UNION
  PROCEDURE at5210_lov_partition_lov(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT5210 PROCESSES (record group PROCESSES); not OData: could not read the query (unexpected "between" in WHERE)
  PROCEDURE at5210_lov_processes(p_rows OUT SYS_REFCURSOR);
  -- AT5210 PROJECT (record group PROJECT); not OData: a join
  PROCEDURE at5210_lov_project(p_rows OUT SYS_REFCURSOR);
--#BODY
  -- AT5210 LV_MANIFESTS: the record group's own query; P1 = :BYPRODHDRS.CUST_SEQ_ID
  PROCEDURE at5210_lov_lv_manifests(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT DISTINCT A.MANIFEST_NBR MANIFEST_NBR, A.ADVNOTIF_SEQ_ID ORDER_NUM
FROM AT_INCOMING_MANIFESTS A, AT_MATERIALS B
WHERE A.ADVNOTIF_SEQ_ID = B.ADVNOTIF_SEQ_ID
AND B.CUST_SEQ_ID = :b1
ORDER BY A.ADVNOTIF_SEQ_ID DESC
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT5210 PARTITION_LOV: the record group's own query; P1 = :CNTNR_PROC.PARTITION_BARCODE
  PROCEDURE at5210_lov_partition_lov(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select container_id, cntnr_seq_id from at_containers where cntnr_stat_cd_id = 'IN USE' union select container_id, cntnr_seq_id from at_containers where container_id = :b1
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT5210 PROCESSES: the record group's own query
  PROCEDURE at5210_lov_processes(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select prctrantyp_seq_id, prctrantyp_cd_id, description from at_process_trans_types ptt where substr(prctrantyp_cd_id,1,1) between '0' and '9' and within_prctrantyp_seq_id is null order by prctrantyp_cd_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5210 PROJECT: the record group's own query
  PROCEDURE at5210_lov_project(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select bp. proj_name, bp.description, bp.byprodproj_seq_id, im.cust_seq_id from at_byproduct_projects bp, at_incoming_manifests im where im. advnotif_seq_id(+) = bp.advnotif_seq_id
) WHERE ROWNUM <= 5000~';
  END;

