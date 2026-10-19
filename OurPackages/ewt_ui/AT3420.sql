-- EWT_UI fragment: AT3420
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT3420 CGFK$PL_CNTNR_DSP_CONTAINER_ID (record group CGFK$PL_CNTNR_DSP_CONTAINER_ID); not OData: could not read the query (unexpected "not" in WHERE)
  PROCEDURE at3420_lov_cgfk_pl_cntnr_dsp_c(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT3420 CGFK$PL_CNTNR_DSP_CONTAINER_ID: the record group's own query
  PROCEDURE at3420_lov_cgfk_pl_cntnr_dsp_c(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select cntnr.container_id dsp_container_id /* cg$fk */ ,cntnr.cntnr_seq_id cntnr_seq_id from at_containers cntnr where cntnr.cntnr_stat_cd_id not in ('EMPTY','SHIPPED') and nvl(terminal_ind,'N') != 'Y'
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

