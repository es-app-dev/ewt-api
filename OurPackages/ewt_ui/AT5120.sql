-- EWT_UI fragment: AT5120
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT5120 CGFK$CNTNR_DSP_CONTAINER_ID (record group CGFK$CNTNR_CONTAINER_ID); not OData: a join
  PROCEDURE at5120_lov_cgfk_cntnr_dsp_cont(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY
  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT5120 CGFK$CNTNR_DSP_CONTAINER_ID: the record group's own query
  PROCEDURE at5120_lov_cgfk_cntnr_dsp_cont(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   DISTINCT cntnr1.container_id container_id
                 ,cntnr1.cntnr_seq_id cntnr_seq_id
                 ,cntnr1.cntnr_typ_seq_id cntnr_typ_seq_id
                 ,cntnr_typ1.container_type_cd container_type_cd
                 ,cntnr1.cntnr_stat_cd_id
FROM     at_containers cntnr1
        ,at_container_types cntnr_typ1
WHERE        cntnr_typ1.cntnr_typ_seq_id = cntnr1.cntnr_typ_seq_id
         AND (   cntnr1.cntnr_stat_cd_id IN ('STORAGE CONTAINER'
                                            ,'EMPTY STORAGE CONT.'
                                            ,'HOLD STORAGE CONT.'
                                            ,'LAB STORAGE CONT.')
              OR (    cntnr1.cntnr_stat_cd_id IN ('LOADED', 'SHIPPED')
                  AND EXISTS
                          (SELECT cntnr.cntnr_seq_id
                           FROM   at_containers cntnr
                           WHERE  cntnr.within_cntnr_seq_id = cntnr1.cntnr_seq_id)))
         AND cntnr1.within_cntnr_seq_id IS NULL
         AND NVL(cntnr1.terminal_ind, 'N') = 'N'
ORDER BY cntnr1.container_id
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

