-- EWT_UI fragment: WB3100
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- WB3100 LOAD_IBOX: WB_IBOX_CONTAINERS with the block's own WHERE; one optional criterion per column
  PROCEDURE wb3100_w_load_ibox(b_at$ctrl_incinerator_id IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_online_status IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

--#BODY
  -- WB3100 LOAD_IBOX: WB_IBOX_CONTAINERS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3100_w_load_ibox(b_at$ctrl_incinerator_id IN VARCHAR2, p_ibox_nbr IN VARCHAR2, p_ibox_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_sequence IN NUMBER, p_ibox_barcode IN VARCHAR2, p_online_status IN VARCHAR2, p_incinerator_id IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM WB_IBOX_CONTAINERS
 WHERE (
INCINERATION_STATUS='ON-LINE' AND SORT_STATUS='ON-LINE' AND INCINERATOR_ID = :w1
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN ibox_nbr LIKE :c4 THEN 1 END WHEN ibox_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR ibox_seq_id = :c7)
   AND (:c8 IS NULL OR cust_seq_id = :c9)
   AND (:c10 IS NULL OR disp_site_seq_id = :c11)
   AND (:c12 IS NULL OR sequence = :c13)
   AND (:c14 IS NULL OR (CASE WHEN INSTR(:c15, '%') + INSTR(:c16, '_') > 0 THEN CASE WHEN ibox_barcode LIKE :c17 THEN 1 END WHEN ibox_barcode = :c18 THEN 1 END) = 1)
   AND (:c19 IS NULL OR (CASE WHEN INSTR(:c20, '%') + INSTR(:c21, '_') > 0 THEN CASE WHEN online_status LIKE :c22 THEN 1 END WHEN online_status = :c23 THEN 1 END) = 1)
   AND (:c24 IS NULL OR (CASE WHEN INSTR(:c25, '%') + INSTR(:c26, '_') > 0 THEN CASE WHEN incinerator_id LIKE :c27 THEN 1 END WHEN incinerator_id = :c28 THEN 1 END) = 1)
 ORDER BY sequence desc
) WHERE ROWNUM <= 5000~'
      USING b_at$ctrl_incinerator_id, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_nbr, p_ibox_seq_id, p_ibox_seq_id, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_sequence, p_sequence, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_ibox_barcode, p_online_status, p_online_status, p_online_status, p_online_status, p_online_status, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id, p_incinerator_id;
  END;

