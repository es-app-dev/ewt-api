-- EWT_UI fragment: AT4420
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4420 SURVEYS (record group SURVEYS); not OData: a join
  PROCEDURE at4420_lov_surveys(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4420 SURVEYS: the record group's own query
  PROCEDURE at4420_lov_surveys(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select distinct ac.survey_nbr,ac.survey_bin_nbr,ac.container_id,ac.cntnr_seq_id,cust.name,im.manifest_nbr
from at_materials mat, at_processed_amounts pa, at_customers cust, at_incoming_manifests im, at_containers ac
where pa.matl_seq_id = mat.matl_seq_id
and mat.advnotif_seq_id = im.advnotif_seq_id
and im.cust_seq_id = cust.cust_seq_id
and pa.cntnr_seq_id = ac.cntnr_seq_id
and ac.cntnr_stat_cd_id <> 'SHIPPED'
and ac.survey_nbr is not null
and ac.survey_bin_nbr IS NULL 
and not exists
 (select * from at_survey_bins sb 
   where sb.survey_bin_nbr = ac.survey_bin_nbr) 
order by ac.survey_nbr
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

