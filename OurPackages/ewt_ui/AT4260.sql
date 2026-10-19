-- EWT_UI fragment: AT4260
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
  -- AT4260 ADJ_CONTAINERS (record group ADJ_CONTAINERS); not OData: a join
  PROCEDURE at4260_lov_adj_containers(p_rows OUT SYS_REFCURSOR);
--#BODY
  -- AT4260 ADJ_CONTAINERS: the record group's own query
  PROCEDURE at4260_lov_adj_containers(p_rows OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_rows FOR q'~SELECT * FROM (
select DISTINCT b.cntnr_seq_id, b.container_id,b.next_prctrantyp_seq_id next_npc_seq_id,c.prctrantyp_cd_id dsp_npc_code,
b.cntnr_stat_cd_id cntnr_stat_cd_id from  at_containers b, at_process_trans_types c where b.next_prctrantyp_seq_id = c.prctrantyp_seq_id and c.prctrantyp_cd_id IN ('890','891') and b.cntnr_stat_cd_id not in ('EMPTY','SHIPPED')  order by b.container_id
) WHERE ROWNUM <= 5000~';
  END;

