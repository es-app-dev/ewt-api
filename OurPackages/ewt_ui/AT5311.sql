-- EWT_UI fragment: AT5311
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT5311 CONTAINERS (record group CONTAINERS); not OData: a join
  PROCEDURE at5311_lov_containers(p_rows OUT SYS_REFCURSOR);
  -- AT5311 LABANLSMPL5: AT_LAB_ANALYSIS_SAMPLES with the block's own WHERE; one optional criterion per column
  PROCEDURE at5311_w_labanlsmpl5(p_pass_fail_ind IN VARCHAR2, p_mnfststat_cd_id IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_labsample_seq_id IN NUMBER, p_labanlsmpl_seq_id IN NUMBER, p_labtyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT5311 LABSAMPLE2: AT_LAB_SAMPLES with the block's own WHERE; one optional criterion per column
  PROCEDURE at5311_w_labsample2(p_sample_id IN VARCHAR2, p_labsample_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_req_by_seg_stf_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

--#BODY
  -- AT5311 CONTAINERS: the record group's own query
  PROCEDURE at5311_lov_containers(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select c.cntnr_seq_id, c.container_id from at_containers c,at_container_processes cp where cp.byprodhdrs_seq_id is not null and c.cntnr_seq_id = cp.cntnr_seq_id order by container_id
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5311 LABANLSMPL5: AT_LAB_ANALYSIS_SAMPLES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5311_w_labanlsmpl5(p_pass_fail_ind IN VARCHAR2, p_mnfststat_cd_id IN VARCHAR2, p_qc_seg_stf_seq_id IN NUMBER, p_labsample_seq_id IN NUMBER, p_labanlsmpl_seq_id IN NUMBER, p_labtyp_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_LAB_ANALYSIS_SAMPLES
 WHERE (
labtyp_seq_id =
(select labtyp_seq_id 
 from   at_lab_analysis_types
 where  code = 'GSPEC')
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN pass_fail_ind LIKE :c4 THEN 1 END WHEN pass_fail_ind = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN mnfststat_cd_id LIKE :c9 THEN 1 END WHEN mnfststat_cd_id = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR qc_seg_stf_seq_id = :c12)
   AND (:c13 IS NULL OR labsample_seq_id = :c14)
   AND (:c15 IS NULL OR labanlsmpl_seq_id = :c16)
   AND (:c17 IS NULL OR labtyp_seq_id = :c18)
) WHERE ROWNUM <= 5000~'
      USING p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_pass_fail_ind, p_mnfststat_cd_id, p_mnfststat_cd_id, p_mnfststat_cd_id, p_mnfststat_cd_id, p_mnfststat_cd_id, p_qc_seg_stf_seq_id, p_qc_seg_stf_seq_id, p_labsample_seq_id, p_labsample_seq_id, p_labanlsmpl_seq_id, p_labanlsmpl_seq_id, p_labtyp_seq_id, p_labtyp_seq_id;
  END;

  -- AT5311 LABSAMPLE2: AT_LAB_SAMPLES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5311_w_labsample2(p_sample_id IN VARCHAR2, p_labsample_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_req_by_seg_stf_seq_id IN NUMBER, p_seg_stf_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_LAB_SAMPLES
 WHERE (
labsample_seq_id in (select distinct smpls.labsample_seq_id from at_lab_samples smpls, at_lab_analysis_samples smpl, at_lab_analysis_types typs where smpls.labsample_seq_id = smpl.labsample_seq_id and smpl.labtyp_seq_id = typs.labtyp_seq_id and typs.code = 'GSPEC')
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN sample_id LIKE :c4 THEN 1 END WHEN sample_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR labsample_seq_id = :c7)
   AND (:c8 IS NULL OR cntnr_seq_id = :c9)
   AND (:c10 IS NULL OR req_by_seg_stf_seq_id = :c11)
   AND (:c12 IS NULL OR seg_stf_seq_id = :c13)
) WHERE ROWNUM <= 5000~'
      USING p_sample_id, p_sample_id, p_sample_id, p_sample_id, p_sample_id, p_labsample_seq_id, p_labsample_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_req_by_seg_stf_seq_id, p_req_by_seg_stf_seq_id, p_seg_stf_seq_id, p_seg_stf_seq_id;
  END;

