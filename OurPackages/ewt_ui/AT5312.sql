-- EWT_UI fragment: AT5312
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT5312 CGFK$LABSAMPLE2_DSP_BADGE_NBR (record group CGFK$LABSAMPLE2_DSP_BADGE_NBR); not OData: a subquery in WHERE
  PROCEDURE at5312_lov_cgfk_labsample2_dsp(p_rows OUT SYS_REFCURSOR);
  -- AT5312 FACILITY (record group FACILITY); not OData: a join
  PROCEDURE at5312_lov_facility(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT5312 REVIEWED_BY_STAFF (record group REVIEWED_BY_STAFF); not OData: a subquery in WHERE
  PROCEDURE at5312_lov_reviewed_by_staff(p_rows OUT SYS_REFCURSOR);
  -- AT5312 AT_ESPROFILE_SAMP_FREQ: AT_ESPROFILE_SAMP_FREQ with the block's own WHERE; one optional criterion per column
  PROCEDURE at5312_w_at_esprofile_sam_5d3f(b_labsample2_es_prof_seq_id IN NUMBER, p_esprofile_samp_freq_seq_id IN NUMBER, p_es_prof_seq_id IN NUMBER, p_site_seq_id IN NUMBER, p_shipment_nbr IN VARCHAR2, p_labsample_seq_id IN NUMBER, p_business_rule IN NUMBER, p_sample_type IN VARCHAR2, p_rule_type IN VARCHAR2, p_yd_marker IN NUMBER, p_create_user IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT5312 COMPOSITE: AT_LAB_SAMPLE_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5312_w_composite(b_labsample2_labsample_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_labsample_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

--#BODY
  -- AT5312 CGFK$LABSAMPLE2_DSP_BADGE_NBR: the record group's own query
  PROCEDURE at5312_lov_cgfk_labsample2_dsp(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   first_name dsp_first_name
        ,middle_name dsp_middle_name
        ,last_name dsp_last_name
        ,badge_nbr dsp_badge_nbr
        ,seg_stf_seq_id seg_stf_seq_id
FROM     at_seg_staff
WHERE        seg_dept_seq_id = (SELECT seg_dept_seq_id
                                FROM   at_seg_departments
                                WHERE  code = 'LAB')
         AND status_cd = 'A'
ORDER BY last_name, first_name, middle_name
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5312 FACILITY: the record group's own query; P1 = :CG$CTRL.SITE_IND
  PROCEDURE at5312_lov_facility(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.facility_cd ,a.description, a.fac_seq_id, b.site_cd_id from at_seg_facilities a, at_seg_sites b where a.site_seq_id = b.site_seq_id and substr(b.site_cd_id,1,1) = :b1 order by facility_cd
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT5312 REVIEWED_BY_STAFF: the record group's own query
  PROCEDURE at5312_lov_reviewed_by_staff(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   last_name dsp_last_name
        ,middle_name dsp_middle_name
        ,first_name dsp_first_name
        ,badge_nbr dsp_badge_nbr
        ,seg_stf_seq_id seg_stf_seq_id
FROM     at_seg_staff
WHERE        seg_dept_seq_id = (SELECT seg_dept_seq_id
                                FROM   at_seg_departments
                                WHERE  code = 'LAB')
         AND status_cd = 'A'
ORDER BY last_name, first_name
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5312 AT_ESPROFILE_SAMP_FREQ: AT_ESPROFILE_SAMP_FREQ with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5312_w_at_esprofile_sam_5d3f(b_labsample2_es_prof_seq_id IN NUMBER, p_esprofile_samp_freq_seq_id IN NUMBER, p_es_prof_seq_id IN NUMBER, p_site_seq_id IN NUMBER, p_shipment_nbr IN VARCHAR2, p_labsample_seq_id IN NUMBER, p_business_rule IN NUMBER, p_sample_type IN VARCHAR2, p_rule_type IN VARCHAR2, p_yd_marker IN NUMBER, p_create_user IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_ESPROFILE_SAMP_FREQ psf
 WHERE (
es_prof_seq_id = :w1
)
   AND (:c1 IS NULL OR esprofile_samp_freq_seq_id = :c2)
   AND (:c3 IS NULL OR es_prof_seq_id = :c4)
   AND (:c5 IS NULL OR site_seq_id = :c6)
   AND (:c7 IS NULL OR (CASE WHEN INSTR(:c8, '%') + INSTR(:c9, '_') > 0 THEN CASE WHEN shipment_nbr LIKE :c10 THEN 1 END WHEN shipment_nbr = :c11 THEN 1 END) = 1)
   AND (:c12 IS NULL OR labsample_seq_id = :c13)
   AND (:c14 IS NULL OR business_rule = :c15)
   AND (:c16 IS NULL OR (CASE WHEN INSTR(:c17, '%') + INSTR(:c18, '_') > 0 THEN CASE WHEN sample_type LIKE :c19 THEN 1 END WHEN sample_type = :c20 THEN 1 END) = 1)
   AND (:c21 IS NULL OR (CASE WHEN INSTR(:c22, '%') + INSTR(:c23, '_') > 0 THEN CASE WHEN rule_type LIKE :c24 THEN 1 END WHEN rule_type = :c25 THEN 1 END) = 1)
   AND (:c26 IS NULL OR yd_marker = :c27)
   AND (:c28 IS NULL OR (CASE WHEN INSTR(:c29, '%') + INSTR(:c30, '_') > 0 THEN CASE WHEN create_user LIKE :c31 THEN 1 END WHEN create_user = :c32 THEN 1 END) = 1)
 ORDER BY (SELECT ls2.clut_entry_nbr
  FROM   at_lab_samples ls2
  WHERE  ls2.shipment_nbr = psf.shipment_nbr) DESC
,business_rule
) WHERE ROWNUM <= 5000~'
      USING b_labsample2_es_prof_seq_id, p_esprofile_samp_freq_seq_id, p_esprofile_samp_freq_seq_id, p_es_prof_seq_id, p_es_prof_seq_id, p_site_seq_id, p_site_seq_id, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_labsample_seq_id, p_labsample_seq_id, p_business_rule, p_business_rule, p_sample_type, p_sample_type, p_sample_type, p_sample_type, p_sample_type, p_rule_type, p_rule_type, p_rule_type, p_rule_type, p_rule_type, p_yd_marker, p_yd_marker, p_create_user, p_create_user, p_create_user, p_create_user, p_create_user;
  END;

  -- AT5312 COMPOSITE: AT_LAB_SAMPLE_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5312_w_composite(b_labsample2_labsample_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_labsample_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_LAB_SAMPLE_CONTAINERS
 WHERE (
LABSAMPLE_SEQ_ID = :w1
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN container_id LIKE :c4 THEN 1 END WHEN container_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR cntnr_seq_id = :c7)
   AND (:c8 IS NULL OR labsample_seq_id = :c9)
 ORDER BY CONTAINER_ID
) WHERE ROWNUM <= 5000~'
      USING b_labsample2_labsample_seq_id, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_cntnr_seq_id, p_cntnr_seq_id, p_labsample_seq_id, p_labsample_seq_id;
  END;

