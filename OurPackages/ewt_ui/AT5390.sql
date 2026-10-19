-- EWT_UI fragment: AT5390
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT5390 FACILITY_LOV (record group FACILITY_RG); not OData: a join
  PROCEDURE at5390_lov_facility_lov(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT5390 FACILITY_LOV: the record group's own query
  PROCEDURE at5390_lov_facility_lov(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   sf.facility_cd
        ,sf.description
        ,ss.site_cd_id
        ,sf.fac_seq_id        
FROM     at_seg_facilities sf
        ,at_seg_sites ss
WHERE    sf.site_seq_id = ss.site_seq_id
ORDER BY sf.facility_cd
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

