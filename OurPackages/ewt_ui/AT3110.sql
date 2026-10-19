-- EWT_UI fragment: AT3110
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT3110 AT_ESPROFILE_EPA: AT_ESPROFILE_EPA with the block's own WHERE; one optional criterion per column
  PROCEDURE at3110_w_at_esprofile_epa(b_matl_matl_seq_id IN NUMBER, b_matl_cntnr_seq_id IN NUMBER, p_es_prof_seq_id IN NUMBER, p_haz_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT3110 AT_ESPROFILE_EPA_I: AT_ESPROFILE_EPA with the block's own WHERE; one optional criterion per column
  PROCEDURE at3110_w_at_esprofile_epa_i(b_matl1_matl_seq_id IN NUMBER, b_matl1_cntnr_seq_id IN NUMBER, p_es_prof_seq_id IN NUMBER, p_haz_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);

  -- AT3110 CNTNR: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at3110_w_cntnr(b_matl_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT3110 CGFK$CUSTTRCK_DSP_CODE2 (record group CGFK$CUSTTRCK_DSP_CODE2); not OData: could not read the query (unexpected "not" in WHERE)
  PROCEDURE at3110_lov_cgfk_custtrck_ds_02(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT3110 CGFK$CUSTTRCK_DSP_CODE (record group CGFK$CUSTTRCK_DSP_CODE); not OData: could not read the query (unexpected "not" in WHERE)
  PROCEDURE at3110_lov_cgfk_custtrck_dsp_c(p1 IN NUMBER, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT3110 CGFK$MATLMATL_DSP_MATERIAL_TYP (record group CGFK$MATLMATL_DSP_MATERIAL_TYP); not OData: NOT / a subquery in WHERE
  PROCEDURE at3110_lov_cgfk_matlmatl_dsp_m(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT3110 CGFK$MATLMATL1_DSP_MATERIAL_TY (record group CGFK$MATLMATL1_DSP_MATERIAL_TY); not OData: NOT / a subquery in WHERE
  PROCEDURE at3110_lov_cgfk_matlmatl1_dsp_(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT3110 LOV_ACTIVITY (record group RG_ACTIVITY); not OData: UNION
  PROCEDURE at3110_lov_lov_activity(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT3110 LOV_ACTIVITY1 (record group RG_ACTIVITY); not OData: UNION
  PROCEDURE at3110_lov_lov_activity1(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- AT3110 ORDER_DISP_SITES (record group ORDER_DISP_SITES); not OData: a join
  PROCEDURE at3110_lov_order_disp_sites(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY







  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT3110 AT_ESPROFILE_EPA: AT_ESPROFILE_EPA with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at3110_w_at_esprofile_epa(b_matl_matl_seq_id IN NUMBER, b_matl_cntnr_seq_id IN NUMBER, p_es_prof_seq_id IN NUMBER, p_haz_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM at_esprofile_epa pe
 WHERE (
NOT EXISTS (SELECT 1
            FROM   at_barcode_haz_waste_codes bhwc2
            WHERE  bhwc2.matl_seq_id = :w1
            AND    bhwc2.cntnr_seq_id = :w2
            AND    bhwc2.haz_seq_id = pe.haz_seq_id)
)
   AND (:c1 IS NULL OR es_prof_seq_id = :c2)
   AND (:c3 IS NULL OR haz_seq_id = :c4)
 ORDER BY (SELECT haz_waste_cd
 FROM   at_haz_waste_codes hwc2
 WHERE  hwc2.haz_seq_id = pe.haz_seq_id)
) WHERE ROWNUM <= 5000~'
      USING b_matl_matl_seq_id, b_matl_cntnr_seq_id, p_es_prof_seq_id, p_es_prof_seq_id, p_haz_seq_id, p_haz_seq_id;
  END;

  -- AT3110 AT_ESPROFILE_EPA_I: AT_ESPROFILE_EPA with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at3110_w_at_esprofile_epa_i(b_matl1_matl_seq_id IN NUMBER, b_matl1_cntnr_seq_id IN NUMBER, p_es_prof_seq_id IN NUMBER, p_haz_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM at_esprofile_epa pe
 WHERE (
NOT EXISTS (SELECT 1
            FROM   at_barcode_haz_waste_codes bhwc2
            WHERE  bhwc2.matl_seq_id = :w1
            AND    bhwc2.cntnr_seq_id = :w2
            AND    bhwc2.haz_seq_id = pe.haz_seq_id)
)
   AND (:c1 IS NULL OR es_prof_seq_id = :c2)
   AND (:c3 IS NULL OR haz_seq_id = :c4)
 ORDER BY (SELECT haz_waste_cd
 FROM   at_haz_waste_codes hwc2
 WHERE  hwc2.haz_seq_id = pe.haz_seq_id)
) WHERE ROWNUM <= 5000~'
      USING b_matl1_matl_seq_id, b_matl1_cntnr_seq_id, p_es_prof_seq_id, p_es_prof_seq_id, p_haz_seq_id, p_haz_seq_id;
  END;

  -- AT3110 CNTNR: AT_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at3110_w_cntnr(b_matl_cntnr_seq_id IN NUMBER, p_cntnr_seq_id IN NUMBER, p_container_id IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINERS
 WHERE (
CNTNR_SEQ_ID = :w1
)
   AND (:c1 IS NULL OR cntnr_seq_id = :c2)
   AND (:c3 IS NULL OR (CASE WHEN INSTR(:c4, '%') + INSTR(:c5, '_') > 0 THEN CASE WHEN container_id LIKE :c6 THEN 1 END WHEN container_id = :c7 THEN 1 END) = 1)
) WHERE ROWNUM <= 5000~'
      USING b_matl_cntnr_seq_id, p_cntnr_seq_id, p_cntnr_seq_id, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id;
  END;
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT3110 CGFK$CUSTTRCK_DSP_CODE2: the record group's own query; P1 = :MATL1.MATL_SEQ_ID
  PROCEDURE at3110_lov_cgfk_custtrck_ds_02(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select trkditm.code dsp_code /* cg$fk */ ,trkditm.description dsp_description4 ,trkditm.snm_ind dsp_snm_ind ,trkditm.source_material_ind dsp_source_material_ind ,trkditm.trkditm_seq_id trkditm_seq_id, trkditm.snm_sm_convt_fctr_amt snm_sm_convt_fctr_amt from at_tracked_items trkditm where trkditm.trkditm_seq_id not in (select trkditm_seq_id from at_cust_doc_tracked_items where matl_seq_id = :b1)
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT3110 CGFK$CUSTTRCK_DSP_CODE: the record group's own query; P1 = :MATL.MATL_SEQ_ID, P2 = :MATL.HLD_NUCLIDE_CODE
  PROCEDURE at3110_lov_cgfk_custtrck_dsp_c(p1 IN NUMBER, p2 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select trkditm.code dsp_code /* cg$fk */ ,trkditm.description dsp_description4 ,trkditm.snm_ind dsp_snm_ind ,trkditm.source_material_ind dsp_source_material_ind ,trkditm.trkditm_seq_id trkditm_seq_id, trkditm.snm_sm_convt_fctr_amt snm_sm_convt_fctr_amt from at_tracked_items trkditm where trkditm.trkditm_seq_id not in (select trkditm_seq_id from at_cust_doc_tracked_items where matl_seq_id = :b1) and trkditm.code not in (:b2||nvl(:b3,' '))
) WHERE ROWNUM <= 5000~'
      USING p1, p2, p2;
  END;

  -- AT3110 CGFK$MATLMATL_DSP_MATERIAL_TYP: the record group's own query; P1 = :MATL.MATL_SEQ_ID
  PROCEDURE at3110_lov_cgfk_matlmatl_dsp_m(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   matl_typ.material_type_cd dsp_material_type_cd
        ,matl_typ.description dsp_description
        ,matl_typ.matl_typ_seq_id matl_typ_seq_id
        ,NVL(order_by_nbr, 1000) order_by_nbr        
FROM     at_material_types matl_typ
WHERE        NOT EXISTS
                 (SELECT 'x'
                  FROM   at_material_to_material_types types
                  WHERE      types.matl_typ_seq_id = matl_typ.matl_typ_seq_id
                         AND types.matl_seq_id = :b1)
         AND matl_typ.show_in_lov = 'Y'
ORDER BY order_by_nbr, material_type_cd
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT3110 CGFK$MATLMATL1_DSP_MATERIAL_TY: the record group's own query; P1 = :MATL1.MATL_SEQ_ID
  PROCEDURE at3110_lov_cgfk_matlmatl1_dsp_(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   matl_typ1.material_type_cd dsp_material_type_cd
        ,matl_typ1.description dsp_description
        ,matl_typ1.matl_typ_seq_id matl_typ_seq_id
        ,NVL(order_by_nbr, 1000) order_by_nbr
FROM     at_material_types matl_typ1
WHERE        NOT EXISTS
                 (SELECT 'x'
                  FROM   at_material_to_material_types types
                  WHERE      types.matl_typ_seq_id = matl_typ1.matl_typ_seq_id
                         AND types.matl_seq_id = :b1)
         AND matl_typ1.show_in_lov = 'Y'
ORDER BY order_by_nbr, material_type_cd
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT3110 LOV_ACTIVITY: the record group's own query; P1 = :PARAMETER.ACTIVITY
  PROCEDURE at3110_lov_lov_activity(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select unit2.unit_cd_id activity_unit_cd_id /* cg$fk */ ,unit2.description dsp_description3 from at_unit_of_measures unit2 where unit2.category_cd = :b1 union select '%' ,'Percentage' from dual order by 1
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT3110 LOV_ACTIVITY1: the record group's own query; P1 = :PARAMETER.ACTIVITY
  PROCEDURE at3110_lov_lov_activity1(p1 IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select unit2.unit_cd_id activity_unit_cd_id /* cg$fk */ ,unit2.description dsp_description3 from at_unit_of_measures unit2 where unit2.category_cd = :b1 union select '%' ,'Percentage' from dual order by 1
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT3110 ORDER_DISP_SITES: the record group's own query; P1 = :MNFST.ADVNOTIF_SEQ_ID
  PROCEDURE at3110_lov_order_disp_sites(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select a.code, a.description,a.disp_site_seq_id from at_disp_sites a, at_order_disp_sites b where advnotif_seq_id = :b1 and b.disp_site_seq_id = a.disp_site_seq_id
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

