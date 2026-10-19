-- EWT_UI fragment: WB3000
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- WB3000 SEARCH: the block's own FROM-clause query; one optional criterion per column
  PROCEDURE wb3000_q_search(p_parent_container_id IN VARCHAR2, p_daughter_barcode IN VARCHAR2, p_customer_nbr IN NUMBER, p_customer_name IN VARCHAR2, p_full_wt IN VARCHAR2, p_empty_wgt IN VARCHAR2, p_npc IN VARCHAR2, p_sort_dt IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

--#BODY
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- WB3000 SEARCH: the block's own FROM-clause query (JDAPI); binds and criteria bound; reads only
  PROCEDURE wb3000_q_search(p_parent_container_id IN VARCHAR2, p_daughter_barcode IN VARCHAR2, p_customer_nbr IN NUMBER, p_customer_name IN VARCHAR2, p_full_wt IN VARCHAR2, p_empty_wgt IN VARCHAR2, p_npc IN VARCHAR2, p_sort_dt IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM (
SELECT id.ibox_seq_id
       ,id.parent_container_id
       ,id.daughter_barcode
       ,(SELECT c2.customer_nbr
         FROM   at_incoming_manifests im2
               ,at_customers c2
         WHERE      im2.cust_seq_id = c2.cust_seq_id
                AND im2.advnotif_seq_id = id.advnotif_seq_id)
            customer_nbr
       ,(SELECT c2.name
         FROM   at_incoming_manifests im2
               ,at_customers c2
         WHERE      im2.cust_seq_id = c2.cust_seq_id
                AND im2.advnotif_seq_id = id.advnotif_seq_id)
            customer_name
       ,id.full_wt
       ,id.empty_wgt
       ,ptt.prctrantyp_cd_id
            npc
       ,id.sort_dt
       ,id.transaction_area_name
 FROM   wb_ibox_details id
       ,at_process_trans_types ptt
 WHERE      id.prctrantyp_seq_id = ptt.prctrantyp_seq_id(+)
        AND id.parent_daughter_type_cd = 'DAUGHTER'
        AND id.daughter_barcode <> id.parent_container_id
) q
 WHERE (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN q.parent_container_id LIKE :c4 THEN 1 END WHEN q.parent_container_id = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN q.daughter_barcode LIKE :c9 THEN 1 END WHEN q.daughter_barcode = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR q.customer_nbr = :c12)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN q.customer_name LIKE :c16 THEN 1 END WHEN q.customer_name = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN q.full_wt LIKE :c21 THEN 1 END WHEN q.full_wt = :c22 THEN 1 END) = 1)
   AND (:c23 IS NULL OR (CASE WHEN INSTR(:c24, '%') + INSTR(:c25, '_') > 0 THEN CASE WHEN q.empty_wgt LIKE :c26 THEN 1 END WHEN q.empty_wgt = :c27 THEN 1 END) = 1)
   AND (:c28 IS NULL OR (CASE WHEN INSTR(:c29, '%') + INSTR(:c30, '_') > 0 THEN CASE WHEN q.npc LIKE :c31 THEN 1 END WHEN q.npc = :c32 THEN 1 END) = 1)
   AND (:c33 IS NULL OR (CASE WHEN INSTR(:c34, '%') + INSTR(:c35, '_') > 0 THEN CASE WHEN q.sort_dt LIKE :c36 THEN 1 END WHEN q.sort_dt = :c37 THEN 1 END) = 1)
 ORDER BY sort_dt DESC, daughter_barcode DESC, parent_container_id DESC
) WHERE ROWNUM <= 5000~'
      USING p_parent_container_id, p_parent_container_id, p_parent_container_id, p_parent_container_id, p_parent_container_id, p_daughter_barcode, p_daughter_barcode, p_daughter_barcode, p_daughter_barcode, p_daughter_barcode, p_customer_nbr, p_customer_nbr, p_customer_name, p_customer_name, p_customer_name, p_customer_name, p_customer_name, p_full_wt, p_full_wt, p_full_wt, p_full_wt, p_full_wt, p_empty_wgt, p_empty_wgt, p_empty_wgt, p_empty_wgt, p_empty_wgt, p_npc, p_npc, p_npc, p_npc, p_npc, p_sort_dt, p_sort_dt, p_sort_dt, p_sort_dt, p_sort_dt;
  END;
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

