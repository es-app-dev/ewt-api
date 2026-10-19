-- EWT_UI fragment: AT5511
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC

  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT5511 OUTSHIPMT: AT_OUTBOUND_SHIPMENTS with the block's own WHERE; one optional criterion per column
  PROCEDURE at5511_w_outshipmt(p_manifest_nbr IN VARCHAR2, p_shipment_nbr IN VARCHAR2, p_exclusive_use_ind IN VARCHAR2, p_shipment_status IN VARCHAR2, p_epa_regulated_waste_ind IN VARCHAR2, p_epa_manifest_nbr IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_transport_permit_nbr IN VARCHAR2, p_generator_cd IN VARCHAR2, p_collector_ind IN VARCHAR2, p_processor_ind IN VARCHAR2, p_outshipmt_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_shipper_seg_stf_seq_id IN NUMBER, p_cntnr_vol_ind IN VARCHAR2, p_additional_notes IN VARCHAR2, p_rows OUT SYS_REFCURSOR);
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT5511 CGFK$OUTSHIPMT_DSP_CARRIER_NAM (record group CGFK$OUTSHIPMT_DSP_CARRIER_NAM); not OData: a join
  PROCEDURE at5511_lov_cgfk_outshipmt_dsp_(p_rows OUT SYS_REFCURSOR);
  -- AT5511 CONTAINERS (record group CONTAINERS); not OData: a join
  PROCEDURE at5511_lov_containers(p_rows OUT SYS_REFCURSOR);
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

--#BODY


  -- >>> generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)
  -- AT5511 OUTSHIPMT: AT_OUTBOUND_SHIPMENTS with the block's own WHERE (JDAPI); binds and criteria bound; reads only
  PROCEDURE at5511_w_outshipmt(p_manifest_nbr IN VARCHAR2, p_shipment_nbr IN VARCHAR2, p_exclusive_use_ind IN VARCHAR2, p_shipment_status IN VARCHAR2, p_epa_regulated_waste_ind IN VARCHAR2, p_epa_manifest_nbr IN VARCHAR2, p_shipment_id_nbr IN VARCHAR2, p_transport_permit_nbr IN VARCHAR2, p_generator_cd IN VARCHAR2, p_collector_ind IN VARCHAR2, p_processor_ind IN VARCHAR2, p_outshipmt_seq_id IN NUMBER, p_cust_seq_id IN NUMBER, p_disp_site_seq_id IN NUMBER, p_shipper_seg_stf_seq_id IN NUMBER, p_cntnr_vol_ind IN VARCHAR2, p_additional_notes IN VARCHAR2, p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (SELECT * FROM AT_OUTBOUND_SHIPMENTS
 WHERE (
SHIPMENT_NBR IN (
SELECT SHIPMENT_NBR FROM AT_SHIPMENTS
WHERE SUBSTR(SHIPMENT_TYPE_CD,1,8) = 'TRANSFER')
)
   AND (:c1 IS NULL OR (CASE WHEN INSTR(:c2, '%') + INSTR(:c3, '_') > 0 THEN CASE WHEN manifest_nbr LIKE :c4 THEN 1 END WHEN manifest_nbr = :c5 THEN 1 END) = 1)
   AND (:c6 IS NULL OR (CASE WHEN INSTR(:c7, '%') + INSTR(:c8, '_') > 0 THEN CASE WHEN shipment_nbr LIKE :c9 THEN 1 END WHEN shipment_nbr = :c10 THEN 1 END) = 1)
   AND (:c11 IS NULL OR (CASE WHEN INSTR(:c12, '%') + INSTR(:c13, '_') > 0 THEN CASE WHEN exclusive_use_ind LIKE :c14 THEN 1 END WHEN exclusive_use_ind = :c15 THEN 1 END) = 1)
   AND (:c16 IS NULL OR (CASE WHEN INSTR(:c17, '%') + INSTR(:c18, '_') > 0 THEN CASE WHEN shipment_status LIKE :c19 THEN 1 END WHEN shipment_status = :c20 THEN 1 END) = 1)
   AND (:c21 IS NULL OR (CASE WHEN INSTR(:c22, '%') + INSTR(:c23, '_') > 0 THEN CASE WHEN epa_regulated_waste_ind LIKE :c24 THEN 1 END WHEN epa_regulated_waste_ind = :c25 THEN 1 END) = 1)
   AND (:c26 IS NULL OR (CASE WHEN INSTR(:c27, '%') + INSTR(:c28, '_') > 0 THEN CASE WHEN epa_manifest_nbr LIKE :c29 THEN 1 END WHEN epa_manifest_nbr = :c30 THEN 1 END) = 1)
   AND (:c31 IS NULL OR (CASE WHEN INSTR(:c32, '%') + INSTR(:c33, '_') > 0 THEN CASE WHEN shipment_id_nbr LIKE :c34 THEN 1 END WHEN shipment_id_nbr = :c35 THEN 1 END) = 1)
   AND (:c36 IS NULL OR (CASE WHEN INSTR(:c37, '%') + INSTR(:c38, '_') > 0 THEN CASE WHEN transport_permit_nbr LIKE :c39 THEN 1 END WHEN transport_permit_nbr = :c40 THEN 1 END) = 1)
   AND (:c41 IS NULL OR (CASE WHEN INSTR(:c42, '%') + INSTR(:c43, '_') > 0 THEN CASE WHEN generator_cd LIKE :c44 THEN 1 END WHEN generator_cd = :c45 THEN 1 END) = 1)
   AND (:c46 IS NULL OR (CASE WHEN INSTR(:c47, '%') + INSTR(:c48, '_') > 0 THEN CASE WHEN collector_ind LIKE :c49 THEN 1 END WHEN collector_ind = :c50 THEN 1 END) = 1)
   AND (:c51 IS NULL OR (CASE WHEN INSTR(:c52, '%') + INSTR(:c53, '_') > 0 THEN CASE WHEN processor_ind LIKE :c54 THEN 1 END WHEN processor_ind = :c55 THEN 1 END) = 1)
   AND (:c56 IS NULL OR outshipmt_seq_id = :c57)
   AND (:c58 IS NULL OR cust_seq_id = :c59)
   AND (:c60 IS NULL OR disp_site_seq_id = :c61)
   AND (:c62 IS NULL OR shipper_seg_stf_seq_id = :c63)
   AND (:c64 IS NULL OR (CASE WHEN INSTR(:c65, '%') + INSTR(:c66, '_') > 0 THEN CASE WHEN cntnr_vol_ind LIKE :c67 THEN 1 END WHEN cntnr_vol_ind = :c68 THEN 1 END) = 1)
   AND (:c69 IS NULL OR (CASE WHEN INSTR(:c70, '%') + INSTR(:c71, '_') > 0 THEN CASE WHEN additional_notes LIKE :c72 THEN 1 END WHEN additional_notes = :c73 THEN 1 END) = 1)
) WHERE ROWNUM <= 5000~'
      USING p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_manifest_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_shipment_nbr, p_exclusive_use_ind, p_exclusive_use_ind, p_exclusive_use_ind, p_exclusive_use_ind, p_exclusive_use_ind, p_shipment_status, p_shipment_status, p_shipment_status, p_shipment_status, p_shipment_status, p_epa_regulated_waste_ind, p_epa_regulated_waste_ind, p_epa_regulated_waste_ind, p_epa_regulated_waste_ind, p_epa_regulated_waste_ind, p_epa_manifest_nbr, p_epa_manifest_nbr, p_epa_manifest_nbr, p_epa_manifest_nbr, p_epa_manifest_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_shipment_id_nbr, p_transport_permit_nbr, p_transport_permit_nbr, p_transport_permit_nbr, p_transport_permit_nbr, p_transport_permit_nbr, p_generator_cd, p_generator_cd, p_generator_cd, p_generator_cd, p_generator_cd, p_collector_ind, p_collector_ind, p_collector_ind, p_collector_ind, p_collector_ind, p_processor_ind, p_processor_ind, p_processor_ind, p_processor_ind, p_processor_ind, p_outshipmt_seq_id, p_outshipmt_seq_id, p_cust_seq_id, p_cust_seq_id, p_disp_site_seq_id, p_disp_site_seq_id, p_shipper_seg_stf_seq_id, p_shipper_seg_stf_seq_id, p_cntnr_vol_ind, p_cntnr_vol_ind, p_cntnr_vol_ind, p_cntnr_vol_ind, p_cntnr_vol_ind, p_additional_notes, p_additional_notes, p_additional_notes, p_additional_notes, p_additional_notes;
  END;
  -- <<< generated: query blocks run as the form wrote them (scripts/jdapi/block-package.cjs)

  -- >>> generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)
  -- AT5511 CGFK$OUTSHIPMT_DSP_CARRIER_NAM: the record group's own query
  PROCEDURE at5511_lov_cgfk_outshipmt_dsp_(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select distinct carrier.carrier_name dsp_carrier_name /* cg$fk */ ,carrier.carrier_abbreviated_name dsp_carrier_abbreviated_name ,carrier.carrier_contact_name dsp_carrier_contact_name ,carrier.epa_nbr dsp_epa_nbr ,carrier.carrier_contact_phone_nbr dsp_carrier_contact_phone_nb ,carrier.carrier_status_cd dsp_carrier_status_cd ,carrier.carrier_seq_id carrier_seq_id from at_carriers carrier, at_addresses addr
) WHERE ROWNUM <= 5000~';
  END;

  -- AT5511 CONTAINERS: the record group's own query
  PROCEDURE at5511_lov_containers(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select cnt.cntnr_seq_id,cnt.container_id,typ.container_type_cd,cnt.waste_class_cd
 from at_container_types typ,at_containers cnt
 where typ.cntnr_typ_seq_id = cnt.cntnr_typ_seq_id
 and cnt.cntnr_stat_cd_id = 'IN USE'
 and cnt.cntnr_seq_id not in
 (select osc.cntnr_seq_id from at_outshipment_containers osc where osc.cntnr_seq_id = cnt.cntnr_seq_id and osc.shipment_type_cd = 'B')
order by cnt.container_id
) WHERE ROWNUM <= 5000~';
  END;
  -- <<< generated: lists of values run as the form wrote them (scripts/jdapi/contract.cjs --lov-sql)

