-- EWT_UI fragment: AT5514
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT5514 OUTCNTNR: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5514_w_outcntnr(b_landfill_headers_begin__b633 IN NUMBER, p_used_vol IN NUMBER, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT5514 LIFT_STOR_LOC_LV (record group LIFT_STOR_LOC_RG); not OData: could not read the query (Cannot read properties of undefined (reading 'toUpperCase'))
  PROCEDURE at5514_lov_lift_stor_loc_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT5514 OUTCNTNR: AT_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5514_w_outcntnr(b_landfill_headers_begin__b633 IN NUMBER, p_used_vol IN NUMBER, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINERS
 WHERE (
NVL(terminal_process_ind,'N') = 'Y' and get_current_location_seq(cntnr_seq_id) = :w1
)
   AND (:c1 IS NULL OR used_vol = :c2)
   AND (:c3 IS NULL OR cntnr_seq_id = :c4)
 ORDER BY cntnr_seq_id asc
) WHERE ROWNUM <= 5000~'
      USING b_landfill_headers_begin__b633, p_used_vol, p_used_vol, p_cntnr_seq_id, p_cntnr_seq_id;
  END;
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT5514 LIFT_STOR_LOC_LV: the record group's own query; P1 = :LANDFILL_HEADERS.DISP_STORLOC_SEQ_ID
  PROCEDURE at5514_lov_lift_stor_loc_lv(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select STORAGE_LOCATION_ID,DESCRIPTION,STORLOC_SEQ_ID
from AT_STORAGE_LOCATIONS
where nvl(active_ind,'N') = 'Y'
  and NVL(lift_ind,'N') = 'Y'
  and disp_storloc_seq = NVL(:b1,-1)
order by 1
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

