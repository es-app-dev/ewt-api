-- EWT_UI fragment: AT9612
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT9612 STATE_LOV (record group STATE_RG); not OData: a join
  PROCEDURE at9612_lov_state_lov(p_rows OUT SYS_REFCURSOR);
--#BODY
  -- AT9612 STATE_LOV: the record group's own query
  PROCEDURE at9612_lov_state_lov(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   sp.st_prvnc_abbr_id
        ,sp.name
        ,sp.cntry_postal_id
FROM     at_state_provinces sp
        ,at_countries c
WHERE    sp.cntry_postal_id = c.cntry_postal_id
ORDER BY sp.cntry_postal_id, sp.st_prvnc_abbr_id
) WHERE ROWNUM <= 5000~';
  END;

