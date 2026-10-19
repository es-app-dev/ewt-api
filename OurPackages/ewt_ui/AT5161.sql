-- EWT_UI fragment: AT5161
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT5161 AT_SHIPMENTS: AT_SHIPMENTS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5161_w_at_shipments(p_shipment_nbr IN VARCHAR2, p_shipment_type_cd IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT5161 CNTNR1: AT_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5161_w_cntnr1(b_at_shipments_shipment_nbr IN VARCHAR2, p_container_id IN VARCHAR2, p_notes IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

--#BODY
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT5161 AT_SHIPMENTS: AT_SHIPMENTS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5161_w_at_shipments(p_shipment_nbr IN VARCHAR2, p_shipment_type_cd IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_SHIPMENTS
 WHERE (
received_dt is not null and shipment_nbr in 
(select shipment_nbr 
from at_incoming_manifests 
where advnotif_seq_id in 
(select advnotif_seq_id 
from at_materials 
where cntnr_seq_id in 
(select cntnr_seq_id 
from at_containers 
where cntnr_stat_cd_id = 'LAB')))
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN shipment_nbr LIKE :c4 THEN 1 END WHEN shipment_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN shipment_type_cd LIKE :c9 THEN 1 END WHEN shipment_type_cd = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR (CASE WHEN INSTR(:c12, '%') + INSTR(:c13, '_') > 0 THEN CASE WHEN shipment_id_nbr LIKE :c14 THEN 1 END WHEN shipment_id_nbr = :c15 THEN 1 END) = 1)
 ORDER BY received_dt desc
) WHERE ROWNUM <= 5000~'
      USING p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_type_cd, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr;
  END;

  -- AT5161 CNTNR1: AT_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5161_w_cntnr1(b_at_shipments_shipment_nbr IN VARCHAR2, p_container_id IN VARCHAR2, p_notes IN VARCHAR2, p_cntnr_stat_cd_id IN VARCHAR2, p_cntnr_seq_id IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTAINERS
 WHERE (
AT_CONTAINERS.CNTNR_STAT_CD_ID IN ('LAB')
AND AT_CONTAINERS.CNTNR_SEQ_ID IN 
    (SELECT CNTNR_SEQ_ID 
     FROM AT_MATERIALS
     WHERE ADVNOTIF_SEQ_ID IN 
        (SELECT ADVNOTIF_SEQ_ID 
         FROM AT_INCOMING_MANIFESTS 
         WHERE SHIPMENT_NBR = :w1
        )
    )
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN container_id LIKE :c4 THEN 1 END WHEN container_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN notes LIKE :c9 THEN 1 END WHEN notes = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR (CASE WHEN INSTR(:c12, '%') + INSTR(:c13, '_') > 0 THEN CASE WHEN cntnr_stat_cd_id LIKE :c14 THEN 1 END WHEN cntnr_stat_cd_id = :c15 THEN 1 END) = 1)
   AND (:c16 IS NULL OR cntnr_seq_id = :c17)
 ORDER BY CONTAINER_ID,CNTNR_STAT_CD_ID
) WHERE ROWNUM <= 5000~'
      USING b_at_shipments_shipment_nbr, p_container_id, p_container_id, p_container_id, p_container_id, p_container_id, p_notes, p_notes, p_notes, p_notes, p_notes, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_stat_cd_id, p_cntnr_seq_id, p_cntnr_seq_id;
  END;
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

