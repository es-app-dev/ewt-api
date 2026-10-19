-- EWT_UI fragment: AT3212
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT3212 CGFK$RNCNTNR_DSP_CONTAINER_TYP (record group CGFK$RNCNTNR_DSP_CONTAINER_TYP); not OData: a subquery in WHERE
  PROCEDURE at3212_lov_cgfk_rncntnr_dsp_co(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT3212 CGFK$RNCNTNR_DSP_CONTAINER_TYP: the record group's own query
  PROCEDURE at3212_lov_cgfk_rncntnr_dsp_co(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select cntnr_typ.container_type_cd dsp_container_type_cd /* cg$fk */ ,cntnr_typ.description dsp_description ,cntnr_typ.cntnr_typ_seq_id cntnr_typ_seq_id ,cntnr_typ.loading_type_cd from at_container_types cntnr_typ where cntnr_typ.cntnr_typ_seq_id in (select rc.cntnr_typ_seq_id from at_rental_containers rc)
order by cntnr_typ.container_type_cd
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

