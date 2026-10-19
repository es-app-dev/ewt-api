-- EWT_UI fragment: WB2001
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- WB2001 LOV_DISPSITES (record group DISPSITES); not OData: could not read the query (expected FROM at ". CODE , AT_DISP_SITES")
  PROCEDURE wb2001_lov_lov_dispsites(p_rows OUT SYS_REFCURSOR);
  -- WB2001 LOV_RAD_FLAG (record group RAD_FLAG); not OData: UNION
  PROCEDURE wb2001_lov_lov_rad_flag(p_rows OUT SYS_REFCURSOR);
  -- WB2001 LOV_WASTE_CD (record group WASTE_CLASS); not OData: UNION
  PROCEDURE wb2001_lov_lov_waste_cd(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- WB2001 LOV_DISPSITES: the record group's own query
  PROCEDURE wb2001_lov_lov_dispsites(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT ALL AT_DISP_SITES.CODE, 
AT_DISP_SITES.DISP_SITE_SEQ_ID, AT_DISP_SITES.DESCRIPTION,
NVL(AT_DISP_SITES.ENVIROCARE_IND,'N') ENVIROCARE_IND
FROM AT_DISP_SITES ORDER BY 2
) WHERE ROWNUM <= 5000~';
  END;

  -- WB2001 LOV_RAD_FLAG: the record group's own query
  PROCEDURE wb2001_lov_lov_rad_flag(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT 'L' RAD_FLAG FROM DUAL
UNION ALL
SELECT 'H' FROM DUAL
UNION ALL
SELECT 'E' FROM DUAL
) WHERE ROWNUM <= 5000~';
  END;

  -- WB2001 LOV_WASTE_CD: the record group's own query
  PROCEDURE wb2001_lov_lov_waste_cd(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT 'A' WASTE_CLASS FROM DUAL
UNION ALL
SELECT 'B' FROM DUAL
UNION ALL
SELECT 'C' FROM DUAL
UNION ALL
SELECT '>C' FROM DUAL
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

