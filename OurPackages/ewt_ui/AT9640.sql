-- EWT_UI fragment: AT9640
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT9640 GROUPS_LOV (record group GROUPS_RG); not OData: a join
  PROCEDURE at9640_lov_groups_lov(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT9640 GROUPS_LOV: the record group's own query
  PROCEDURE at9640_lov_groups_lov(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   lcg.group_name
        ,lcg.group_desc
        ,lcg.level_type
        ,lcg.active_ind
        ,ss.site_cd_id
        ,lcg.lcg_seq_id
FROM     at_license_condition_groups lcg
        ,at_seg_sites ss
WHERE    lcg.site_seq_id = ss.site_seq_id
ORDER BY lcg.group_name, lcg.level_type
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

