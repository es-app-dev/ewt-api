-- EWT_UI fragment: AT1410
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT1410 AT_CNTRCT_CUST_VIEW: AT_CNTRCT_CUST_VIEW with the block's own WHERE; one optional criterion per column
  PROCEDURE at1410_w_at_cntrct_cust_view(b_at_contracts_contract_nbr IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_parent_cntrct_seq_id IN NUMBER, p_contract_nbr IN VARCHAR2, p_mod_cntrct_id IN NUMBER, p_customer_nbr IN NUMBER, p_name IN VARCHAR2, p_rows OUT SYS_REFCURSOR);

  -- AT1410 CLONE_PROD_SERVICES: AT_CONTRACT_PROD_SERVICES with the block's own WHERE; one optional criterion per column
  PROCEDURE at1410_w_clone_prod_services(b_at_contracts_cntrct_seq_id IN NUMBER, b_at_contracts_cust_seq_id IN NUMBER, p_group_nbr IN VARCHAR2, p_subgroup_nbr IN VARCHAR2, p_cost IN NUMBER, p_unit_cd_id IN VARCHAR2, p_description IN VARCHAR2, p_prodserv_seq_id IN NUMBER, p_prodserv_prodcat_seq_id IN NUMBER, p_cnprodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_cntrct_seq_id IN NUMBER, p_contract_line_nbr IN VARCHAR2, p_current_available_amt IN NUMBER, p_sales_received_amt IN NUMBER, p_overestimate_limit_pct IN NUMBER, p_quantity IN NUMBER, p_prof_seq_id IN NUMBER, p_basis IN VARCHAR2, p_basis_pct IN NUMBER, p_min_charge IN NUMBER, p_density_min IN NUMBER, p_density_max IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT1410 CUST_DISP_SITES_LOV (record group CUST_DISP_SITES_RG); not OData: function EXISTS
  PROCEDURE at1410_lov_cust_disp_sites_lov(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1410 CUSTOMER_LOV (record group CUSTOMER_RG); not OData: function TO_CHAR
  PROCEDURE at1410_lov_customer_lov(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1410 SHIPPING_LOCATIONS_LOV (record group SHIPPING_LOCATIONS_RG); not OData: could not read the query (unexpected "NOT" in WHERE)
  PROCEDURE at1410_lov_shipping_locations_(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR);
  -- AT1410 STATE_LOV (record group STATE_RG); not OData: a join
  PROCEDURE at1410_lov_state_lov(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY




  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT1410 AT_CNTRCT_CUST_VIEW: AT_CNTRCT_CUST_VIEW with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1410_w_at_cntrct_cust_view(b_at_contracts_contract_nbr IN VARCHAR2, p_cntrct_seq_id IN NUMBER, p_parent_cntrct_seq_id IN NUMBER, p_contract_nbr IN VARCHAR2, p_mod_cntrct_id IN NUMBER, p_customer_nbr IN NUMBER, p_name IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CNTRCT_CUST_VIEW
 WHERE (
contract_nbr = :w1
)
   AND (:c1 IS NULL OR cntrct_seq_id = :c2)
   AND (:c3 IS NULL OR parent_cntrct_seq_id = :c4)
   AND (:c5 IS NULL OR (CASE WHEN INSTR(:c6, '%') + INSTR(:c7, '_') > 0 THEN CASE WHEN contract_nbr LIKE :c8 THEN 1 END WHEN contract_nbr = :c9 THEN 1 END) = 1)
   AND (:c10 IS NULL OR mod_cntrct_id = :c11)
   AND (:c12 IS NULL OR customer_nbr = :c13)
   AND (:c14 IS NULL OR (CASE WHEN INSTR(:c15, '%') + INSTR(:c16, '_') > 0 THEN CASE WHEN name LIKE :c17 THEN 1 END WHEN name = :c18 THEN 1 END) = 1)
 ORDER BY CUSTOMER_NBR
) WHERE ROWNUM <= 5000~'
      USING b_at_contracts_contract_nbr, p_cntrct_seq_id, p_cntrct_seq_id, p_parent_cntrct_seq_id, p_parent_cntrct_seq_id, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_contract_nbr, p_mod_cntrct_id, p_mod_cntrct_id, p_customer_nbr, p_customer_nbr, p_name, p_name, p_name, p_name, p_name;
  END;

  -- AT1410 CLONE_PROD_SERVICES: AT_CONTRACT_PROD_SERVICES with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at1410_w_clone_prod_services(b_at_contracts_cntrct_seq_id IN NUMBER, b_at_contracts_cust_seq_id IN NUMBER, p_group_nbr IN VARCHAR2, p_subgroup_nbr IN VARCHAR2, p_cost IN NUMBER, p_unit_cd_id IN VARCHAR2, p_description IN VARCHAR2, p_prodserv_seq_id IN NUMBER, p_prodserv_prodcat_seq_id IN NUMBER, p_cnprodserv_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_cntrct_seq_id IN NUMBER, p_contract_line_nbr IN VARCHAR2, p_current_available_amt IN NUMBER, p_sales_received_amt IN NUMBER, p_overestimate_limit_pct IN NUMBER, p_quantity IN NUMBER, p_prof_seq_id IN NUMBER, p_basis IN VARCHAR2, p_basis_pct IN NUMBER, p_min_charge IN NUMBER, p_density_min IN NUMBER, p_density_max IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_CONTRACT_PROD_SERVICES
 WHERE (
cntrct_seq_id = :w1 and cust_seq_id = :w2
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN group_nbr LIKE :c4 THEN 1 END WHEN group_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN subgroup_nbr LIKE :c9 THEN 1 END WHEN subgroup_nbr = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR cost = :c12)
   AND (:c13 IS NULL OR (CASE WHEN INSTR(:c14, '%') + INSTR(:c15, '_') > 0 THEN CASE WHEN unit_cd_id LIKE :c16 THEN 1 END WHEN unit_cd_id = :c17 THEN 1 END) = 1)
   AND (:c18 IS NULL OR (CASE WHEN INSTR(:c19, '%') + INSTR(:c20, '_') > 0 THEN CASE WHEN description LIKE :c21 THEN 1 END WHEN description = :c22 THEN 1 END) = 1)
   AND (:c23 IS NULL OR prodserv_seq_id = :c24)
   AND (:c25 IS NULL OR prodserv_prodcat_seq_id = :c26)
   AND (:c27 IS NULL OR cnprodserv_seq_id = :c28)
   AND (:c29 IS NULL OR disp_site_seq_id = :c30)
   AND (:c31 IS NULL OR cntrct_seq_id = :c32)
   AND (:c33 IS NULL OR (CASE WHEN INSTR(:c34, '%') + INSTR(:c35, '_') > 0 THEN CASE WHEN contract_line_nbr LIKE :c36 THEN 1 END WHEN contract_line_nbr = :c37 THEN 1 END) = 1)
   AND (:c38 IS NULL OR current_available_amt = :c39)
   AND (:c40 IS NULL OR sales_received_amt = :c41)
   AND (:c42 IS NULL OR overestimate_limit_pct = :c43)
   AND (:c44 IS NULL OR quantity = :c45)
   AND (:c46 IS NULL OR prof_seq_id = :c47)
   AND (:c48 IS NULL OR (CASE WHEN INSTR(:c49, '%') + INSTR(:c50, '_') > 0 THEN CASE WHEN basis LIKE :c51 THEN 1 END WHEN basis = :c52 THEN 1 END) = 1)
   AND (:c53 IS NULL OR basis_pct = :c54)
   AND (:c55 IS NULL OR min_charge = :c56)
   AND (:c57 IS NULL OR density_min = :c58)
   AND (:c59 IS NULL OR density_max = :c60)
 ORDER BY group_nbr, nvl(subgroup_nbr,0), get_the_code(prodserv_seq_id)
) WHERE ROWNUM <= 5000~'
      USING b_at_contracts_cntrct_seq_id, b_at_contracts_cust_seq_id, p_group_nbr, p_group_nbr, p_group_nbr, p_group_nbr, p_group_nbr, p_subgroup_nbr, p_subgroup_nbr, p_subgroup_nbr, p_subgroup_nbr, p_subgroup_nbr, p_cost, p_cost, p_unit_cd_id, p_unit_cd_id, p_unit_cd_id, p_unit_cd_id, p_unit_cd_id, p_description, p_description, p_description, p_description, p_description, p_prodserv_seq_id, p_prodserv_seq_id, p_prodserv_prodcat_seq_id, p_prodserv_prodcat_seq_id, p_cnprodserv_seq_id, p_cnprodserv_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_cntrct_seq_id, p_cntrct_seq_id, p_contract_line_nbr, p_contract_line_nbr, p_contract_line_nbr, p_contract_line_nbr, p_contract_line_nbr, p_current_available_amt, p_current_available_amt, p_sales_received_amt, p_sales_received_amt, p_overestimate_limit_pct, p_overestimate_limit_pct, p_quantity, p_quantity, p_prof_seq_id, p_prof_seq_id, p_basis, p_basis, p_basis, p_basis, p_basis, p_basis_pct, p_basis_pct, p_min_charge, p_min_charge, p_density_min, p_density_min, p_density_max, p_density_max;
  END;
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT1410 CUST_DISP_SITES_LOV: the record group's own query; P1 = :AT_CONTRACTS.CUST_SEQ_ID
  PROCEDURE at1410_lov_cust_disp_sites_lov(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   ds.code dsp_code
        ,ds.description dsp_description
        ,ds.operated_by_name dsp_operated_by_name
        ,ds.disp_site_seq_id
FROM     at_disp_sites ds
WHERE    EXISTS
             (SELECT cds.disp_site_seq_id
              FROM   at_customer_disp_sites cds
              WHERE      ds.disp_site_seq_id = cds.disp_site_seq_id
                     AND cds.cust_seq_id = :b1)
ORDER BY ds.code
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1410 CUSTOMER_LOV: the record group's own query; P1 = :AT_CONTRACTS.CUSTOMER_NBR
  PROCEDURE at1410_lov_customer_lov(p1 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   name
        ,customer_nbr
        ,cust_seq_id
FROM     at_customers
WHERE    TO_CHAR(customer_nbr) LIKE (TO_CHAR(:b1) || '%')
ORDER BY name
) WHERE ROWNUM <= 5000~'
      USING p1;
  END;

  -- AT1410 SHIPPING_LOCATIONS_LOV: the record group's own query; P1 = :AT_CONTRACTS.CNTRCT_SEQ_ID, P2 = :AT_CONTRACTS.CUST_SEQ_ID
  PROCEDURE at1410_lov_shipping_locations_(p1 IN NUMBER, p2 IN NUMBER, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   cu.customer_nbr
        ,cu.name
        , :b1
        ,cu.cust_seq_id
FROM     at_customers cu
WHERE    cu.cust_seq_id NOT IN (SELECT csl.cust_seq_id
                                FROM   at_contract_shipping_locs csl
                                WHERE  csl.cntrct_seq_id = :b2)
ORDER BY CASE
             WHEN cu.cust_seq_id = :b3 THEN 0
             ELSE 1
         END
        ,cu.name
) WHERE ROWNUM <= 5000~'
      USING p1, p1, p2;
  END;

  -- AT1410 STATE_LOV: the record group's own query
  PROCEDURE at1410_lov_state_lov(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
SELECT   sp.st_prvnc_abbr_id
        ,sp.name
        ,sp.cntry_postal_id
FROM     at_state_provinces sp
        ,at_countries c
WHERE    sp.cntry_postal_id = c.cntry_postal_id
ORDER BY sp.cntry_postal_id DESC, sp.st_prvnc_abbr_id
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

