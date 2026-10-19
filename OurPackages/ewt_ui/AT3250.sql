-- EWT_UI fragment: AT3250
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
/* NOT PUBLIC, and deliberately so
 *   at5510_overpack_exists, at5510_storage_cntnr_exists, at5510_update_movement
 * are form units that portspec classed for the application tier ('reads' and
 * 'calls-pkg').  They are private in the body instead, because a database
 * package cannot call application code.  Anything a writing unit calls has to
 * come into the package with it.  See rules/common/PORTING-RULES.md. */

/* ===========================================================================
 * AT3250 - Maintain Container Rental Status.  Ported from at3250.fmb, block
 * RNCNTNRST, trigger KEY-DELREC (the whole trigger):
 *
 *   if not rental_container_status.status_ok_to_delete(:rncntnrst.rncntnrstat_cd_id) then
 *     seg_msgs('This status cannot be deleted as it is required by the Order Shipments module','E',TRUE);
 *     raise form_trigger_failure;
 *   else
 *     delete_record;
 *   end if;
 *
 * Why here: the guard is a database FUNCTION returning a PL/SQL BOOLEAN.  The
 * API cannot call a function (OPEN-32) and nothing outside PL/SQL binds a
 * BOOLEAN.  delete_record (a Forms built-in: mark the record for deletion) stays
 * with the screen: it calls this when Delete Record is pressed, and marks the
 * record if this returns quietly.  The delete itself goes at Save as any other.
 * =========================================================================== */

  /* May this status be deleted?  Quiet when it may; -20510 "This status cannot be
   * deleted as it is required by the Order Shipments module" when it may not. */
  PROCEDURE at3250_key_delrec(p_rncntnrstat_cd_id IN VARCHAR2);

--#BODY
/* ===========================================================================
 * AT3250 - Maintain Container Rental Status
 * =========================================================================== */

  PROCEDURE at3250_key_delrec(p_rncntnrstat_cd_id IN VARCHAR2) IS
  BEGIN
    IF NOT rental_container_status.status_ok_to_delete(p_rncntnrstat_cd_id) THEN
      rule_error('This status cannot be deleted as it is required by the Order Shipments module');
    END IF;
  EXCEPTION
    WHEN e_abort THEN
      RAISE;
    WHEN OTHERS THEN
      -- the trigger has no handler: an Oracle error would reach the operator as
      -- FRM-40735 with the ORA- text.  The text is kept, the unit is named.
      RAISE_APPLICATION_ERROR(c_unexpected, 'Error: KEY-DELREC RNCNTNRST. ' || SQLERRM);
  END at3250_key_delrec;

