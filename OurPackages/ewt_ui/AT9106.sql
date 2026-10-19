-- EWT_UI fragment: AT9106
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT9106 CGFK$CONTSTR_DSP_CODE (record group CGFK$CONTSTR_DSP_CODE); not OData: function TO_CHAR
  PROCEDURE at9106_lov_cgfk_contstr_dsp_co(p_rows OUT SYS_REFCURSOR);
  -- AT9106 LV_LIC_REST_LST (record group RG_LIC_REST_LST); not OData: could not read the query (expected ) at "= 'AT_CUSTOMER_LICENSES.LICENSE_RESTRICTION_CD' ) order")
  PROCEDURE at9106_lov_lv_lic_rest_lst(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT9106 CGFK$CONTSTR_DSP_CODE: the record group's own query
  PROCEDURE at9106_lov_cgfk_contstr_dsp_co(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT to_char(AGT_MEDIA.CODE)  DSP_CODE  /* CG$FK */
      ,AGT_MEDIA.NAME  DSP_NAME
      ,AGT_MEDIA.MEDIA_CD  DSP_MEDIA_CD
      ,AGT_MEDIA.AGT_MEDIA_SEQ_ID  AGT_MEDIA_SEQ_ID
FROM   AT_AGENTS_AND_MEDIAS AGT_MEDIA
ORDER BY  to_char(AGT_MEDIA.CODE) ASC
) WHERE ROWNUM <= 5000~';
  END;

  -- AT9106 LV_LIC_REST_LST: the record group's own query
  PROCEDURE at9106_lov_lv_lic_rest_lst(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select substr(rv_low_value,1,1) rv_low_value, substr(rv_meaning,1,100) rv_meaning from cg_ref_codes where (rv_domain = 'AT_CUSTOMER_LICENSES.LICENSE_RESTRICTION_CD') order by rv_low_value
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

