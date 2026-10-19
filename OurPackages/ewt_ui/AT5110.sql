-- EWT_UI fragment: AT5110
-- Assembled into the EWT_UI package by the API. No CREATE OR REPLACE here,
-- and no slash lines: the frame supplies those.
--#SPEC
/* ===========================================================================
 * AT5110 - Container Movement.  Ported from at5110.fmb: the Move button
 * (CONT$CTRL.CNTNR_MOVE_OK_BUTTON, WHEN-BUTTON-PRESSED) with the form units it
 * calls, STORAGE_CONTAINER_EXISTS, DOUBLE_CONTAINER_LOC and ADD_TIME_TO_DATE
 * (private in the body: they are not screen operations).
 *
 * WHAT THE LEGACY DOES
 *   For every record of the CONTAINER block, first to last: one AT_CONTAINER_MOVEMENTS
 *   row to the Move Location (the trigger's local function MOVEMENT), and when the
 *   container holds others, one row for each of them to the same location
 *   (DOUBLE_CONTAINER_LOC).  A stockpile or lift location adds a warning for the
 *   first container that CAN_CNTNR_GO_BURIAL refuses, and moves it anyway.  Then
 *   COMMIT_FORM.
 *
 * CHANGED, beyond fields becoming parameters
 *   - The CONTAINER block's records arrive as two lists in record order, one
 *     value per line (CHR(10)): p_cntnr_seq_ids and p_container_ids.  A blank
 *     record is an empty line.  p_blank_container is :CONT$CTRL.BLANK_CONTAINER:
 *     with 'Y', a last record with no container is dropped, as CLEAR_RECORD does.
 *   - MOVE_DATE and MOVE_TIME arrive as the items show them, and are converted
 *     with the items' own masks (MM/DD/RRRR, HH:MI PM), as Forms converts typed
 *     text.
 *   - alert_user(msg, 'I', 'NOFAIL') shows a message and carries on: here each
 *     one is a line of p_notices, in the order the legacy shows them, and the
 *     screen shows them when the call returns.  alert_user(.., 'FAIL') is
 *     rule_error.  BELL is dropped.
 *   - 'Moving all entered containers ... one moment please' is shown by the
 *     screen before the call, in that wording.
 *   - DO_KEY('COMMIT_FORM'): the call is one transaction, committed when it
 *     returns; an error rolls all of it back (the legacy's error path leaves the
 *     rows it inserted posted but uncommitted in the session).  Changes the user
 *     made to queried CONTAINER rows are not in it: the screen saves those
 *     through its own save first.
 *   - When every container moved (p_all_moved = 'Y') the screen clears Move
 *     Location, Date, Time and Operator; then it clears the CONTAINER block and
 *     goes to Move Location, as the legacy does.
 * KEPT AS THE LEGACY HAS THEM
 *   - A container CAN_CNTNR_GO_BURIAL refuses is moved anyway: the branch only
 *     adds the warning, and only once per press (msg_cnt).
 *   - MOVEMENT swallows every error and reports "Container X not moved".
 *   - MOVEMENT reads the location's LANDFILL_IND and LIFT_IND and the container's
 *     status, and fetches the next movement, and uses none of them.
 *   - DOUBLE_CONTAINER_LOC swallows every error, inserts with no operator, and
 *     stamps MOVED_TIME with today's time on Oracle's default date part.
 * =========================================================================== */

  /* The Move button.  p_moved is the count in "N Containers Moved"; p_all_moved
   * is 'Y' or 'N'; p_notices holds the NOFAIL messages, one per line.  -20510
   * 'Move Location, Date, Time and Operator must be entered' when one is empty. */
  PROCEDURE at5110_cntnr_move_ok(p_move_location          IN VARCHAR2
                                ,p_move_location_seq_id   IN NUMBER
                                ,p_move_date              IN VARCHAR2
                                ,p_move_time              IN VARCHAR2
                                ,p_move_operator          IN VARCHAR2
                                ,p_move_operator_seq_id   IN NUMBER
                                ,p_blank_container        IN VARCHAR2
                                ,p_cntnr_seq_ids          IN VARCHAR2
                                ,p_container_ids          IN VARCHAR2
                                ,p_moved                  OUT NUMBER
                                ,p_all_moved              OUT VARCHAR2
                                ,p_notices                OUT VARCHAR2);

--#BODY
/* ===========================================================================
 * AT5110 - Container Movement
 * =========================================================================== */

  /* ADD_TIME_TO_DATE, program unit of at5110.fmb, as it is (the RETURN NULL after
   * the RETURN is the legacy's, unreachable there too). */
  FUNCTION at5110_add_time_to_date ( P_DATE_ITEM   IN  DATE,
                                     P_TIME_ITEM   IN  DATE) RETURN DATE IS

  BEGIN

      RETURN( TO_DATE(TO_CHAR(P_DATE_ITEM,'DD/MM/YYYY')||' '||
                     TO_CHAR(P_TIME_ITEM,'HH:MI PM'),'DD/MM/YYYY HH:MI PM'));

      RETURN NULL; EXCEPTION
       WHEN VALUE_ERROR THEN
        RETURN (NULL);
  END at5110_add_time_to_date;

-- ---------------------------------------------------------------------------
  /* STORAGE_CONTAINER_EXISTS, program unit of at5110.fmb, as it is.  (AT5510's
   * unit of the same name differs: at5510_storage_cntnr_exists.) */
  FUNCTION at5110_storage_cntnr_exists(IN_CNTNR  IN  NUMBER)
  RETURN BOOLEAN
  IS
    STORAGE_CNT  NUMBER;
  BEGIN
     SELECT COUNT(CNTNR_SEQ_ID)
     INTO STORAGE_CNT
     FROM AT_CONTAINERS
     WHERE CNTNR_SEQ_ID IN (
           SELECT CNTNR_SEQ_ID
           FROM AT_CONTAINERS
           WHERE WITHIN_CNTNR_SEQ_ID = IN_CNTNR);
     --
     IF STORAGE_CNT > 0
     THEN
         RETURN(TRUE);
     ELSE
     	   RETURN(FALSE);
     END IF;
     --
  END at5110_storage_cntnr_exists;

-- ---------------------------------------------------------------------------
  /* DOUBLE_CONTAINER_LOC, program unit of at5110.fmb, as it is: every error is
   * swallowed, the operator is NULL, and MOVED_TIME is today's time on Oracle's
   * default date part (TO_DATE of 'HH24:MI:SS'). */
  PROCEDURE at5110_double_container_loc(IN_CNTNR  IN NUMBER)
  IS
  	  current_location_OUTER  NUMBER;
      current_date_moved    date;
      MOVEMENT_SEQ          NUMBER;
      append_sec_time       varchar2(20)  := null;
      STARTING_LOC_SEQ      NUMBER;
      ENDING_LOC_SEQ        NUMBER;
  --
      CURSOR INNER_CONTAINERS IS
         SELECT CNTNR_SEQ_ID
         FROM AT_CONTAINERS
         WHERE WITHIN_CNTNR_SEQ_ID = IN_CNTNR;
  --
  BEGIN
  --
  -- SET LOCATION OF THE CONTAINER INSIDE TO THE LOCATION OF THE
  -- OUTER CONTAINER (STORAGE CONTAINER)
  --
    BEGIN
      -- Retrieve current container FOR OUTER CONTAINER
      select  S1.STORLOC_SEQ_ID
        into  current_location_OUTER
        from  at_container_movements cntnrmov ,
              at_storage_locations S1
       where
              S1.storloc_seq_id = cntnrmov.ending_storloc_seq_id
          and CNTNRMOV.CNTNRMV_SEQ_ID = MAX_MOVE_DT(IN_CNTNR);
      --
      -- LOOP THROUGH INNER CONTAINERS AND SET THE INNER CONTAINER LOCATION TO THE OUTER CONTAINER
      --
      FOR REC IN INNER_CONTAINERS
      LOOP
      --
      -- GET CURRENT LOCATION FOR INNER CONTAINER
      --
       BEGIN
        select  S1.STORLOC_SEQ_ID
        into  STARTING_LOC_SEQ
        from  at_container_movements cntnrmov ,
              at_storage_locations S1
        where
              S1.storloc_seq_id = cntnrmov.ending_storloc_seq_id
          and CNTNRMOV.CNTNRMV_SEQ_ID = MAX_MOVE_DT(REC.CNTNR_SEQ_ID);
      --
        exception
        when others then
             STARTING_LOC_SEQ := NULL;
       --
       END;
      --
       BEGIN
        select cntnrmv_seq.nextval
        into movement_seq
        from dual;
      --
        append_sec_time := to_char(sysdate, 'HH24:MI:SS');
        insert into AT_CONTAINER_MOVEMENTs(CNTNRMV_SEQ_ID ,
                                          CNTNR_SEQ_ID,
                                          MOVED_DT,
                                          moved_time,
                                          STARTING_STORLOC_SEQ_ID,
                                          ENDING_STORLOC_SEQ_ID,
                                          seg_stf_seq_id)
                                  values (movement_seq,
                                          REC.CNTNR_SEQ_ID,
                                          SYSDATE,
                                          to_date(append_sec_time,'HH24:MI:SS'),
                                          STARTING_LOC_SEQ,
                                          CURRENT_LOCATION_OUTER,
                                          NULL);

        exception
          when others then
              NULL;
       END;

      END LOOP;

     exception
     when others then
        NULL;

    end;

  END at5110_double_container_loc;

-- ---------------------------------------------------------------------------
  /* WHEN-BUTTON-PRESSED on CONT$CTRL.CNTNR_MOVE_OK_BUTTON.  The trigger's text,
   * with :cont$ctrl.* as parameters and :container.* as the current record of the
   * two lists; what only moves the cursor or the screen is left as a comment. */
  PROCEDURE at5110_cntnr_move_ok(p_move_location          IN VARCHAR2
                                ,p_move_location_seq_id   IN NUMBER
                                ,p_move_date              IN VARCHAR2
                                ,p_move_time              IN VARCHAR2
                                ,p_move_operator          IN VARCHAR2
                                ,p_move_operator_seq_id   IN NUMBER
                                ,p_blank_container        IN VARCHAR2
                                ,p_cntnr_seq_ids          IN VARCHAR2
                                ,p_container_ids          IN VARCHAR2
                                ,p_moved                  OUT NUMBER
                                ,p_all_moved              OUT VARCHAR2
                                ,p_notices                OUT VARCHAR2) IS
      TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
      TYPE t_str IS TABLE OF VARCHAR2(4000) INDEX BY PLS_INTEGER;
      l_seqs           t_num;                -- the CONTAINER block's records, in order
      l_ids            t_str;
      l_count          PLS_INTEGER := 0;
      l_container_id   VARCHAR2(4000);       -- :container.container_id of the current record
      l_cntnr_seq_id   NUMBER;               -- :container.cntnr_seq_id of the current record
      l_move_date      DATE;                 -- :cont$ctrl.move_date
      l_move_time      DATE;                 -- :cont$ctrl.move_time
      l_notices        VARCHAR2(32767);

      counter          NUMBER := 0;
      seq_id           NUMBER;
      msg              VARCHAR2(2000);
      all_moved        BOOLEAN := TRUE;
      move_ok          VARCHAR2(10);
      valid            BOOLEAN
                           :=     (p_move_location IS NOT NULL)
                              AND (p_move_date IS NOT NULL)
                              AND (p_move_time IS NOT NULL)
                              AND (p_move_operator IS NOT NULL);

      msg_cnt          NUMBER := 0;
      reason           VARCHAR2(250);
      burial_loc1      VARCHAR2(1);
      stockpile_ind1   VARCHAR2(1);

      -- alert_user(msg, 'I', 'NOFAIL'): the message is shown and the trigger carries on
      PROCEDURE notice(p_msg IN VARCHAR2) IS
      BEGIN
          l_notices := SUBSTR(l_notices || CASE WHEN l_notices IS NOT NULL THEN CHR(10) END || p_msg, 1, 32767);
      END notice;

      -- one line of a CHR(10) list; an empty line is NULL
      FUNCTION line_of(p_list IN VARCHAR2, p_n IN PLS_INTEGER) RETURN VARCHAR2 IS
          l_from   PLS_INTEGER := 1;
          l_to     PLS_INTEGER;
      BEGIN
          FOR i IN 1 .. p_n - 1 LOOP
              l_from   := INSTR(p_list, CHR(10), l_from) + 1;
          END LOOP;
          l_to   := INSTR(p_list, CHR(10), l_from);
          RETURN CASE WHEN l_to = 0 THEN SUBSTR(p_list, l_from) ELSE SUBSTR(p_list, l_from, l_to - l_from) END;
      END line_of;

      FUNCTION movement(cntnr_sid IN at_containers.cntnr_seq_id%TYPE, container_id IN at_containers.container_id%TYPE)
          RETURN BOOLEAN IS
          CURSOR prior_mvmt IS
              SELECT   cntnrmv_seq_id
                      ,ending_storloc_seq_id
                      ,starting_storloc_seq_id
              FROM     at_container_movements
              WHERE        (   moved_dt < l_move_date
                            OR     moved_dt = l_move_date
                               AND moved_time < l_move_time)
                       AND cntnr_seq_id = cntnr_sid
              ORDER BY moved_dt DESC, moved_time DESC;

          CURSOR next_mvmt IS
              SELECT   cntnrmv_seq_id
                      ,ending_storloc_seq_id
                      ,starting_storloc_seq_id
              FROM     at_container_movements
              WHERE        (   moved_dt > l_move_date
                            OR     moved_dt = l_move_date
                               AND moved_time > l_move_time)
                       AND cntnr_seq_id = cntnr_sid
              ORDER BY moved_dt ASC, moved_time ASC;

          CURSOR offsite_sid IS
              SELECT storloc_seq_id
              FROM   at_storage_locations
              WHERE  storage_location_id = 'OFFSITE';

          the_time        DATE;
          next_move       next_mvmt%ROWTYPE;
          prior_move      prior_mvmt%ROWTYPE;
          offsite         at_storage_locations.storloc_seq_id%TYPE;
          inserted        BOOLEAN := FALSE;
          burial_loc      VARCHAR2(1);
          stockpile_ind   VARCHAR2(1);
          cntnr_stat      VARCHAR2(50);
      BEGIN
          BEGIN
              SELECT NVL(landfill_ind, 'N')
              INTO   stockpile_ind
              FROM   at_storage_locations
              WHERE  storloc_seq_id = p_move_location_seq_id;
          EXCEPTION
              WHEN OTHERS THEN
                  stockpile_ind   := 'N';
          END;

          BEGIN
              SELECT NVL(lift_ind, 'N')
              INTO   burial_loc
              FROM   at_storage_locations
              WHERE  storloc_seq_id = p_move_location_seq_id;
          EXCEPTION
              WHEN OTHERS THEN
                  burial_loc   := 'N';
          END;

          BEGIN
              SELECT cntnr_stat_cd_id
              INTO   cntnr_stat
              FROM   at_containers
              WHERE  cntnr_seq_id = cntnr_sid;
          EXCEPTION
              WHEN OTHERS THEN
                  cntnr_stat   := 'NONE';
          END;

          the_time   := at5110_add_time_to_date(l_move_date, l_move_time);

          OPEN prior_mvmt;

          FETCH prior_mvmt
              INTO prior_move;

          CLOSE prior_mvmt;

          OPEN next_mvmt;

          FETCH next_mvmt
              INTO next_move;

          CLOSE next_mvmt;

          IF prior_move.ending_storloc_seq_id = p_move_location_seq_id THEN
              msg        := 'Warning: New Location is same as Current Location for container ' || l_container_id || '.';
              notice(msg);
              -- BELL;
          END IF;

          SELECT cntnrmv_seq.NEXTVAL
          INTO   seq_id
          FROM   DUAL;

          INSERT INTO at_container_movements(cntnrmv_seq_id
                                            ,cntnr_seq_id
                                            ,moved_dt
                                            ,ending_storloc_seq_id
                                            ,starting_storloc_seq_id
                                            ,moved_time
                                            ,seg_stf_seq_id)
          VALUES      (seq_id
                      ,cntnr_sid
                      ,l_move_date
                      ,p_move_location_seq_id
                      ,p_move_location_seq_id
                      ,the_time
                      ,p_move_operator_seq_id);

          RETURN (TRUE);
      EXCEPTION
          WHEN OTHERS THEN
              RETURN (FALSE);
      END;
  BEGIN
      -- the items' own masks, as Forms converts what was typed
      l_move_date   := TO_DATE(p_move_date, 'MM/DD/RRRR');
      l_move_time   := TO_DATE(p_move_time, 'HH:MI PM');

      -- the CONTAINER block's records: one per line of each list, which must agree
      l_count   := CASE WHEN p_container_ids IS NULL THEN 1 ELSE LENGTH(p_container_ids) - LENGTH(REPLACE(p_container_ids, CHR(10))) + 1 END;
      IF l_count <> CASE WHEN p_cntnr_seq_ids IS NULL THEN 1 ELSE LENGTH(p_cntnr_seq_ids) - LENGTH(REPLACE(p_cntnr_seq_ids, CHR(10))) + 1 END THEN
          RAISE_APPLICATION_ERROR(c_unexpected, 'AT5110: the container lists do not have the same number of records.');
      END IF;
      FOR i IN 1 .. l_count LOOP
          l_ids(i)    := line_of(p_container_ids, i);
          l_seqs(i)   := TO_NUMBER(line_of(p_cntnr_seq_ids, i));
      END LOOP;

      IF valid THEN
          BEGIN
              SELECT NVL(landfill_ind, 'N')
              INTO   stockpile_ind1
              FROM   at_storage_locations
              WHERE  storloc_seq_id = p_move_location_seq_id;
          EXCEPTION
              WHEN OTHERS THEN
                  stockpile_ind1   := 'N';
          END;

          BEGIN
              SELECT NVL(lift_ind, 'N')
              INTO   burial_loc1
              FROM   at_storage_locations
              WHERE  storloc_seq_id = p_move_location_seq_id;
          EXCEPTION
              WHEN OTHERS THEN
                  burial_loc1   := 'N';
          END;

          -- response := alert_user('Moving all entered containers ... one moment please', 'I', 'NOFAIL');
          --   shown by the screen before the call

          -- GO_BLOCK('CONTAINER'); LAST_RECORD;
          IF     l_ids(l_count) IS NULL
             AND p_blank_container = 'Y' THEN
              -- CLEAR_RECORD; (:cont$ctrl.blank_container := 'N' is the screen's)
              l_count   := l_count - 1;
          END IF;

          -- Forms keeps one record in a block it has cleared: the loop below then runs once, on an
          -- empty record, which MOVEMENT cannot insert ("Container  not moved").  Kept.
          IF l_count = 0 THEN
              l_count     := 1;
              l_ids(1)    := NULL;
              l_seqs(1)   := NULL;
          END IF;

          -- FIRST_RECORD; LOOP ... IF :SYSTEM.LAST_RECORD = 'TRUE' THEN EXIT; ELSE NEXT_RECORD; END IF;
          FOR r IN 1 .. l_count LOOP
              l_container_id   := l_ids(r);
              l_cntnr_seq_id   := l_seqs(r);

              IF    stockpile_ind1 = 'Y'
                 OR burial_loc1 = 'Y' THEN
                  SELECT can_cntnr_go_burial(l_container_id)
                  INTO   move_ok
                  FROM   DUAL;

                  IF move_ok = 'FALSE' THEN
                      IF msg_cnt < 1 THEN
                          SELECT get_cntnr_nomove_reason(l_container_id)
                          INTO   reason
                          FROM   DUAL;

                          msg        := 'Error: The container ' || l_container_id || ' should not be moved to a stockpile or lift because ' || reason;
                          notice(msg);
                          msg_cnt    := msg_cnt + 1;
                          -- BELL;
                      END IF;

                      IF movement(l_cntnr_seq_id, l_container_id) THEN
                          counter   := counter + 1;

                          IF at5110_storage_cntnr_exists(l_cntnr_seq_id) THEN
                              at5110_double_container_loc(l_cntnr_seq_id);
                          END IF;
                      ELSE
                          all_moved   := FALSE;
                          msg         := 'Container ' || l_container_id || ' not moved';
                          notice(msg);
                      END IF;
                  ELSE
                      IF movement(l_cntnr_seq_id, l_container_id) THEN
                          counter   := counter + 1;

                          IF at5110_storage_cntnr_exists(l_cntnr_seq_id) THEN
                              at5110_double_container_loc(l_cntnr_seq_id);
                          END IF;
                      ELSE
                          all_moved   := FALSE;
                          msg         := 'Container ' || l_container_id || ' not moved';
                          notice(msg);
                      END IF;
                  END IF;
              ELSE  --not burial
                  IF movement(l_cntnr_seq_id, l_container_id) THEN
                      counter   := counter + 1;

                      IF at5110_storage_cntnr_exists(l_cntnr_seq_id) THEN
                          at5110_double_container_loc(l_cntnr_seq_id);
                      END IF;
                  ELSE
                      all_moved   := FALSE;
                      msg         := 'Container ' || l_container_id || ' not moved';
                      notice(msg);
                  END IF;
              END IF;
          END LOOP;

          msg                     := TO_CHAR(counter) || ' Containers Moved';
          notice(msg);

          -- IF all_moved THEN the screen clears :cont$ctrl.move_location, move_date, move_time and
          -- move_operator (p_all_moved).
          -- :SYSTEM.message_level := 5; DO_KEY('COMMIT_FORM'): this call is one transaction, committed
          -- when it returns.  GO_BLOCK('container'); CLEAR_BLOCK; GO_ITEM('CONT$CTRL.MOVE_LOCATION'):
          -- the screen's.
          p_moved       := counter;
          p_all_moved   := CASE WHEN all_moved THEN 'Y' ELSE 'N' END;
          p_notices     := l_notices;
      ELSE
          msg        := 'Move Location, Date, Time and Operator must be entered';
          rule_error(msg);   -- alert_user(msg, 'S', 'FAIL')
      END IF;
  EXCEPTION
      WHEN e_abort THEN
          RAISE;
      WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(c_unexpected, 'Error: WHEN-BUTTON-PRESSED CONT$CTRL.CNTNR_MOVE_OK_BUTTON. ' || SQLERRM);
  END at5110_cntnr_move_ok;

