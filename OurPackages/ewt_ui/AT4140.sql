-- EWT_UI fragment: AT4140
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4140 CONTAINERS (record group CONTAINERS); not OData: a join
  PROCEDURE at4140_lov_containers(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4140 CONTAINERS: the record group's own query
  PROCEDURE at4140_lov_containers(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select c.container_id,c.cntnr_stat_cd_id,cp.cntnr_proc_seq_id from at_containers c , at_container_processes cp where cp.prctrantyp_seq_id = 1 and cp.parent_daughter_type_cd = 'PARENT' and c.cntnr_seq_id=cp.cntnr_seq_id and cp.cntnr_proc_stat_cd_id not like 'QC%'
and c.cntnr_stat_cd_id = 'EMPTY' order by c.container_id
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

