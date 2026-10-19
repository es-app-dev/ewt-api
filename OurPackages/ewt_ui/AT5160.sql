-- EWT_UI fragment: AT5160
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT5160 CNTNR1: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5160_w_cntnr1(p_container_id IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

--#BODY
  -- AT5160 CNTNR1: AT_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5160_w_cntnr1(p_container_id IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINERS
 WHERE (
AT_CONTAINERS.CNTNR_STAT_CD_ID IN ('AJ','WR','HOLD','TRU','RA','PERMIT',
'SITE CO-MINGLE','IN USE','ACTIVITY','LAB','EMPTY')
AND CNTNR_SEQ_ID NOT IN (SELECT CNTNR_SEQ_ID FROM AT_COMPACTION_MASTERS
WHERE AT_CONTAINERS.CNTNR_SEQ_ID=CNTNR_SEQ_ID)
/*
AND CNTNR_SEQ_ID NOT IN (SELECT CNTNR_SEQ_ID FROM AT_OVERPACK_MASTERS_VIEW
WHERE AT_CONTAINERS.CNTNR_SEQ_ID=CNTNR_SEQ_ID)
*/
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN container_id LIKE :c4 THEN 1 END WHEN container_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN cntnr_stat_cd_id LIKE :c9 THEN 1 END WHEN cntnr_stat_cd_id = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR cntnr_seq_id = :c12)
 ORDER BY CONTAINER_ID,CNTNR_STAT_CD_ID
) WHERE ROWNUM <= 5000~'
      USING p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_seq_id, p_cntnr_seq_id;
  END;

