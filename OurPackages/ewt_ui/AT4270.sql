-- EWT_UI fragment: AT4270
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4270 BINS (record group BINS); not OData: function EXISTS
  PROCEDURE at4270_lov_bins(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT4270 BINS: the record group's own query
  PROCEDURE at4270_lov_bins(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.container_id from at_containers  a 
where  nvl(a.terminal_ind,'N') = 'Y'
and a.container_id like 'BIN%'
and  exists (select 1 from at_containers b 
where b.melted_dt is null
and nvl(b.terminal_process_ind,'N') = 'Y'
and b.container_id like '%' || a.container_id || '%')
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

