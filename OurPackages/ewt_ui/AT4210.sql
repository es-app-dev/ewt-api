-- EWT_UI fragment: AT4210
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT4210 DSP_CONTAINER_ID (record group DSP_CONTAINER_ID); not OData: a join
  PROCEDURE at4210_lov_dsp_container_id(p_rows OUT SYS_REFCURSOR);
  -- AT4210 COMPACTION_MASTER: AT_COMPACTION_MASTERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at4210_w_compaction_master(p_cmpctn_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

--#BODY
  -- AT4210 DSP_CONTAINER_ID: the record group's own query
  PROCEDURE at4210_lov_dsp_container_id(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.cntnr_seq_id, a.container_id, b.container_type_cd, c.prctrantyp_cd_id, a.description, a.cntnr_typ_seq_id from at_containers a, at_container_types b, at_process_trans_types c where a.cntnr_typ_seq_id = b.cntnr_typ_seq_id and c.prctrantyp_seq_id = a.next_prctrantyp_seq_id and c.prctrantyp_cd_id like '2%' and all_parents_empty(a.cntnr_seq_id)='TRUE' and a.cntnr_seq_id not in (select d.cntnr_seq_id from at_compaction_masters d) and not exists (select 'x' from at_container_processes cp, at_process_trans_types ptt where cp.cntnr_seq_id = a.cntnr_seq_id and cp.prctrantyp_seq_id = ptt.prctrantyp_seq_id and ptt.prctrantyp_cd_id = 'OVERPACK') and cntnr_stat_cd_id = 'IN USE' order by a.container_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT4210 COMPACTION_MASTER: AT_COMPACTION_MASTERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at4210_w_compaction_master(p_cmpctn_seq_id IN NUMBER, p_prctrantyp_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_pre_compaction_wgt IN NUMBER, p_wgt_unit_cd_id IN VARCHAR2, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_COMPACTION_MASTERS
 WHERE (
ALL_PARENTS_EMPTY(CNTNR_SEQ_ID)='TRUE' AND PRCTRANTYP_SEQ_ID IN (select PRCTRANTYP_SEQ_ID FROM AT_PROCESS_TRANS_TYPES 
where PRCTRANTYP_CD_ID like '2%')
)
   AND (:c1 IS NULL OR cmpctn_seq_id = :c2)
   AND (:c3 IS NULL OR prctrantyp_seq_id = :c4)
   AND (:c5 IS NULL OR cntnr_seq_id = :c6)
   AND (:c7 IS NULL OR pre_compaction_wgt = :c8)
   AND (:c9 IS NULL OR (CASE WHEN INSTR(:c10, '%') + INSTR(:c11, '_') > 0 THEN CASE WHEN wgt_unit_cd_id LIKE :c12 THEN 1 END WHEN wgt_unit_cd_id = :c13 THEN 1 END) = 1)
   AND (:c14 IS NULL OR seg_stf_seq_id = :c15)
) WHERE ROWNUM <= 5000~'
      USING p_cmpctn_seq_id, p_cmpctn_seq_id, p_prctrantyp_seq_id, p_prctrantyp_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_pre_compaction_wgt, p_pre_compaction_wgt, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_wgt_unit_cd_id, p_seg_stf_seq_id, p_seg_stf_seq_id;
  END;

