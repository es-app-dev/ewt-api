-- EWT_UI fragment: AT5520
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT5520 OUTSHIPMT: AT_OUTBOUND_SHIPMENTS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5520_w_outshipmt(p_outshipmt_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_shipment_nbr IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

--#BODY
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT5520 OUTSHIPMT: AT_OUTBOUND_SHIPMENTS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5520_w_outshipmt(p_outshipmt_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_shipment_nbr IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_OUTBOUND_SHIPMENTS
 WHERE (
shipment_nbr in (
select shipment_nbr
from at_shipments
where (to_char(shipment_dt,'RRRR') = to_char(sysdate,'RRRR')
    or to_char(shipment_dt,'RRRR') = to_char(sysdate-180,'RRRR')))
and disp_SITE_SEQ_ID IN (select disp_site_seq_id from at_disp_site_acks)
)
   AND (:c1 IS NULL OR outshipmt_seq_id = :c2)
   AND (:c3 IS NULL OR disp_site_seq_id = :c4)
   AND (:c5 IS NULL OR (CASE WHEN INSTR(:c6, '%') + INSTR(:c7, '_') > 0 THEN CASE WHEN shipment_nbr LIKE :c8 THEN 1 END WHEN shipment_nbr = :c9 THEN 1 END) = 1)
   AND (:c10 IS NULL OR (CASE WHEN INSTR(:c11, '%') + INSTR(:c12, '_') > 0 THEN CASE WHEN shipment_id_nbr LIKE :c13 THEN 1 END WHEN shipment_id_nbr = :c14 THEN 1 END) = 1)
 ORDER BY SHIPMENT_NBR DESC
) WHERE ROWNUM <= 5000~'
      USING p_outshipmt_seq_id, p_outshipmt_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr;
  END;
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

