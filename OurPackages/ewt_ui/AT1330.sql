-- EWT_UI fragment: AT1330
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT1330 SEARCH: the block's own FROM-clause query; one optional criterion per column
  PROCEDURE at1330_q_search(p_waste_profile_number IN VARCHAR2, p_customer_nbr IN NUMBER, p_customer_name IN VARCHAR2, p_site_cd IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

--#BODY
  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT1330 SEARCH: the block's own FROM-clause query (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1330_q_search(p_waste_profile_number IN VARCHAR2, p_customer_nbr IN NUMBER, p_customer_name IN VARCHAR2, p_site_cd IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM (
SELECT p.waste_profile_number
       ,c.customer_nbr
       ,c.name customer_name
       ,p.site_cd
 FROM   at_esprofiles p
       ,at_customers c
 WHERE  p.gen_cust_seq_id = c.cust_seq_id
) q
 WHERE (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN q.waste_profile_number LIKE :c4 THEN 1 END WHEN q.waste_profile_number = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR q.customer_nbr = :c7)
   AND (:c8 IS NULL OR (CASE WHEN INSTR(:c9, '%') + INSTR(:c10, '_') > 0 THEN CASE WHEN q.customer_name LIKE :c11 THEN 1 END WHEN q.customer_name = :c12 THEN 1 END) = 1)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN q.site_cd LIKE :c16 THEN 1 END WHEN q.site_cd = :c17 THEN 1 END) = 1)
 ORDER BY waste_profile_number, customer_nbr
) WHERE ROWNUM <= 5000~'
      USING p_waste_profile_number, p_waste_profile_number, p_waste_profile_number, p_waste_profile_number, p_waste_profile_number, p_customer_nbr, p_customer_nbr, p_customer_name, p_customer_name, p_customer_name, p_customer_name, p_customer_name, p_site_cd, p_site_cd, p_site_cd, p_site_cd, p_site_cd;
  END;
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

