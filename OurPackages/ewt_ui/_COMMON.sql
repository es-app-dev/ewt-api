-- EWT_UI fragment: _COMMON
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
--#BODY
  /* The form showed a message and abandoned the trigger.  Same message, same
   * effect: the caller gets the operator's wording and nothing is committed. */
  PROCEDURE rule_error(p_msg IN VARCHAR2) IS
  BEGIN
    RAISE_APPLICATION_ERROR(c_rule_error, p_msg);
  END rule_error;

