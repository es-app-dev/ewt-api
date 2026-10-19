-- EWT_UI fragment: AT5310
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT5310 CGFK$LABANLSMPL_DSP_SAMPLE_ID (record group CGFK$LABANLSMPL_DSP_SAMPLE_ID); not OData: a join
  PROCEDURE at5310_lov_cgfk_labanlsmpl_dsp(p1 IN VARCHAR2, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT5310 CONTAINERS (record group CONTAINERS); not OData: a join
  PROCEDURE at5310_lov_containers(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT5310 CGFK$LABANLSMPL_DSP_SAMPLE_ID: the record group's own query; P1 = :LABANLSMPL.DSP_CONTAINER_ID, P2 = :LABANLSMPL.LABSAMPLE_SEQ_ID
  PROCEDURE at5310_lov_cgfk_labanlsmpl_dsp(p1 IN VARCHAR2, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select labsample.sample_id dsp_sample_id, labsample.container_id dsp_container_id /* cg$fk */ ,labsample.cntnr_seq_id dsp_cntnr_seq_id ,labsample.labsample_seq_id labsample_seq_id from at_lab_samples labsample ,at_containers cntnr where labsample.container_id = :b1 and cntnr.cntnr_seq_id (+) = labsample.cntnr_seq_id and labsample.labsample_seq_id = :b2 order by labsample.sample_id,labsample.container_id asc
) WHERE ROWNUM <= 5000~'
      USING p1, p2;
  END;

  -- AT5310 CONTAINERS: the record group's own query
  PROCEDURE at5310_lov_containers(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select smpl.labsample_seq_id, smpl.container_id, cntnr.hazardous_cd from at_lab_samples smpl, at_containers cntnr where cntnr.cntnr_seq_id (+) = smpl.cntnr_seq_id order by smpl.container_id, smpl.labsample_seq_id asc
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

