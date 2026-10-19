-- EWT_UI fragment: AT4215
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT4215 COMPACTION_MASTER: AT_COMPACTION_MASTERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at4215_w_compaction_master(p_cmpctn_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR);

--#BODY
  -- AT4215 COMPACTION_MASTER: AT_COMPACTION_MASTERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at4215_w_compaction_master(p_cmpctn_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_COMPACTION_MASTERS
 WHERE (
ALL_PARENTS_EMPTY(CNTNR_SEQ_ID)='TRUE' AND PRCTRANTYP_SEQ_ID IN (select PRCTRANTYP_SEQ_ID FROM AT_PROCESS_TRANS_TYPES 
where PRCTRANTYP_CD_ID like '2%')
)
   AND (:c1 IS NULL OR cmpctn_seq_id = :c2)
   AND (:c3 IS NULL OR cntnr_seq_id = :c4)
   AND (:c5 IS NULL OR pre_compaction_wgt = :c6)
) WHERE ROWNUM <= 5000~'
      USING p_cmpctn_seq_id, p_cmpctn_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_pre_compaction_wgt, p_pre_compaction_wgt;
  END;

