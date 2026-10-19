-- EWT_UI fragment: AT1553
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT1553 LOV_ORDER (record group RG_ORDER); not OData: a join
  PROCEDURE at1553_lov_lov_order(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT1553 LOV_ORDER: the record group's own query
  PROCEDURE at1553_lov_lov_order(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select DISTINCT a.advnotif_seq_id, b.manifest_nbr from at_line_item_containers a, at_incoming_manifests b where a.advnotif_seq_id = b.advnotif_seq_id  and a.advnotif_seq_id <> '1086' order by a.advnotif_seq_id
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

