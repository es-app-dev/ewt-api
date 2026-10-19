-- EWT_UI fragment: AT4280
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT4280 TANKS (record group TANKS); not OData: function EXISTS
  PROCEDURE at4280_lov_tanks(p_rows OUT SYS_REFCURSOR);
--#BODY
  -- AT4280 TANKS: the record group's own query
  PROCEDURE at4280_lov_tanks(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.container_id from at_containers  a 
where  nvl(a.terminal_ind,'N') = 'Y'
and a.container_id like 'TANK%'
and  exists (select 1 from at_containers b 
where b.melted_dt is null
and nvl(b.terminal_process_ind,'N') = 'Y'
and b.container_id like '%' || a.container_id || '%')
) WHERE ROWNUM <= 5000~';
  END;

