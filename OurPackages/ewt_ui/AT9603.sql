-- EWT_UI fragment: AT9603
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT9603 PARENT_NPC_LOV (record group NPC); not OData: could not read the query (expected ) at "prctrantyp_cd_id FROM at_process_trans_types ptt2")
  PROCEDURE at9603_lov_parent_npc_lov(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT9603 PARENT_NPC_LOV: the record group's own query
  PROCEDURE at9603_lov_parent_npc_lov(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   prctrantyp_cd_id
             npc
        ,description
             npc_descr
        ,(SELECT prctrantyp_cd_id
          FROM   at_process_trans_types ptt2
          WHERE  ptt.within_prctrantyp_seq_id = ptt2.prctrantyp_seq_id)
             parent_npc
        ,(SELECT description
          FROM   at_process_trans_types ptt2
          WHERE  ptt.within_prctrantyp_seq_id = ptt2.prctrantyp_seq_id)
             parent_npc_descr
        ,DECODE(process_cd,  'X', 'Sort / Transfer',  'C', 'Compaction',  'I', 'Incineration',  'S', 'Shipping')
             process_cd
        ,(SELECT description
          FROM   at_waste_process_types wpt2
          WHERE  wpt2.code = ptt.waste_proc_cd)
             waste_process_cd
        ,prctrantyp_seq_id
FROM     at_process_trans_types ptt
ORDER BY prctrantyp_cd_id
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

