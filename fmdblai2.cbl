       IDENTIFICATION DIVISION.
       PROGRAM-ID.    FMDBLAI2.

      * MAINTAIN AI DB FIELD METADATA (DBLAI2)
      * SD,AL,SS,YT   15/09/26   -     PAA   SP6AI

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY '/z/sp6ai/v2/lib/fd/fcdblai2'.
           COPY '/z/sp6ai/v2/lib/fd/fcdblai'.

       DATA DIVISION.
       FILE SECTION.
           COPY '/z/sp6ai/v2/lib/fd/fddblai2'.
           COPY '/z/sp6ai/v2/lib/fd/fddblai'.

       WORKING-STORAGE SECTION.
           COPY '/z/sp6ai/v2/lib/fd/dbdblai2'.
           COPY '/z/sp6ai/v2/lib/fd/dbdblai'.
           COPY '/v/cps/lib/std/stdvar.def'.
           COPY '/v/cps/lib/std/fkey.def'.
           COPY RESOURCE '/v/cps/lib/icon/help.jpg'.

       01 WS-LOOKUP-KEY.
          03 WS-LOOKUP-DB         PIC X(20).
          03 WS-LOOKUP-FIELD      PIC X(40).

       01 WS-MISC.
          03 WS-OK                PIC X(01).
          03 WS-ENABLE-LINK       PIC 9(01) VALUE 0.
          03 WS-DB-NAME           PIC X(80) VALUE SPACES.
          03 WS-LINK-DB-NAME      PIC X(80) VALUE SPACES.
          03 WS-ATTR-VAL          PIC 9(01) VALUE 1.

       LINKAGE SECTION.
       01 LINK-PROG-KEY          PIC X(30).

       SCREEN SECTION.
       01 SELECT-SCR.
          COPY '/v/cps/lib/std/fmmode.scr'.
          03 LABEL LINE 02 COL 04 'LINK DB:'.
          03 ENTRY-FIELD 3-D ID 101 COL 20 PIC X(20)
             USING DBLAI2-DB.
          03 PUSH-BUTTON 'F10 - Help Table' NO-TAB FLAT
             COL + 1.5 LINES 19 SIZE 19
             BITMAP-HANDLE S-BITMAP
             BITMAP-NUMBER   = 1
             TERMINATION-VALUE = 101.

          03 LABEL LINE + 1 COL 04 'DB NAME:'.
          03 ENTRY-FIELD 3-D ENABLED 0 COL 20 PIC X(80)
             USING WS-DB-NAME.

          03 LABEL LINE + 1 COL 04 'FIELD NAME:'.
          03 ENTRY-FIELD 3-D ID 102 COL 20 PIC X(40)
             USING DBLAI2-FIELD.
          03 PUSH-BUTTON 'F10 - Help Field' NO-TAB FLAT
             COL + 1.5 LINES 19 SIZE 19
             BITMAP-HANDLE S-BITMAP
             BITMAP-NUMBER   = 1
             TERMINATION-VALUE = 102.

       01 PROCESS-SCR.
      * File Maintenance Process Mode
         
          03 LABEL LINE 02 COL 04 'LINK DB:'.
          03 ENTRY-FIELD 3-D ENABLED 0 COL 25 PIC X(20)
             USING DBLAI2-DB.

          03 LABEL LINE + 1 COL 04 'DB NAME:'.
          03 ENTRY-FIELD 3-D ENABLED 0 COL 25 PIC X(80)
             USING WS-DB-NAME.

          03 LABEL LINE + 1 COL 04 'FIELD NAME:'.
          03 ENTRY-FIELD 3-D ENABLED 0 COL 25 PIC X(40)
             USING DBLAI2-FIELD.

          03 LABEL LINE + 1 COL 04 'ATTRIBUTE:'.
          03 RADIO-BUTTON 'PK (Primary Key)' ID 103 COL 25
             GROUP 1 GROUP-VALUE 1 
             VALUE WS-ATTR-VAL EXCEPTION-VALUE 103.
          03 RADIO-BUTTON 'FK (Foreign Key)' ID 103 COL + 2
             GROUP 1 GROUP-VALUE 2 
             VALUE WS-ATTR-VAL EXCEPTION-VALUE 103.
          03 RADIO-BUTTON 'DE (Detail)' ID 103 COL + 2
             GROUP 1 GROUP-VALUE 3 
             VALUE WS-ATTR-VAL EXCEPTION-VALUE 103.

          03 LABEL LINE + 1 COL 04 'DESC (ENGLISH):'.
          03 ENTRY-FIELD 3-D ID 104 COL 25 PIC X(80)
             USING DBLAI2-ORIGINAL(1).

          03 LABEL LINE + 1 COL 04 'DESC (BM):'.
          03 ENTRY-FIELD 3-D ID 105 COL 25 PIC X(80)
             USING DBLAI2-ORIGINAL(2).

          03 LABEL LINE + 1 COL 04 'DESC (INDO):'.
          03 ENTRY-FIELD 3-D ID 106 COL 25 PIC X(80)
             USING DBLAI2-ORIGINAL(3).

          03 LABEL LINE + 1 COL 04 'LINK DB (FK ONLY):'.
          03 ENTRY-FIELD 3-D ID 107 COL 25 PIC X(20)
             ENABLED WS-ENABLE-LINK USING DBLAI2-LINK-DB.
          03 PUSH-BUTTON 'F10 - Help Field' NO-TAB FLAT
             COL + 1.5 LINES 19 SIZE 19
             BITMAP-HANDLE S-BITMAP
             BITMAP-NUMBER   = 1
             TERMINATION-VALUE = 107.

          03 LABEL LINE + 1 COL 04 'LINK FIELD (FK ONLY):'.
          03 ENTRY-FIELD 3-D ID 108 COL 25 PIC X(40)
             ENABLED WS-ENABLE-LINK USING DBLAI2-LINK-FIELD.
          03 PUSH-BUTTON 'F10 - Help Field' NO-TAB FLAT
             COL + 1.5 LINES 19 SIZE 19
             BITMAP-HANDLE S-BITMAP
             BITMAP-NUMBER   = 1
             TERMINATION-VALUE = 108.


      ****************************************************************
       PROCEDURE DIVISION USING LINK-PROG-KEY.

       DECLARATIVES.
       DBLAI2-FILE-HANDLING SECTION.
           USE AFTER STANDARD ERROR PROCEDURE ON DBLAI2-FILE.
           CALL   '/v/cps/lib/std/f-status' USING 
                  DBLAI2-FILENAME, DBLAI2-DATANAME, DBLAI2-STATUS.
           CANCEL '/v/cps/lib/std/f-status'.
           IF S-RUN = 'Y' MOVE 'Y' TO S-STATUS-CHECK.
           IF S-RUN = 'N' EXIT PROGRAM STOP RUN.

           COPY '/z/sp6ai/v2/lib/fd/dcdblai'.
       END DECLARATIVES.
      ****************************************************************
       BEGIN.
           MOVE 'N' TO S-RUN.
           OPEN I-O DBLAI2-FILE.
           OPEN INPUT DBLAI-FILE.

           MOVE 'DEFINE AI DB METADATA' TO S-WINDOW-TITLE.
      * Floating Window (800 x 600)
           DISPLAY FLOATING WINDOW
           LINES 16 SIZE 116 CELL SIZE = ENTRY-FIELD FONT SEPARATE
           TITLE-BAR MODAL NO SCROLL NO WRAP NO-CLOSE
           TITLE S-WINDOW-TITLE
           POP-UP S-WINDOW.
           DISPLAY TOOL-BAR, LINES 2.8 HANDLE S-TOOLBAR.
           DISPLAY FRAME AT 0102 LINES 15.7 CELL SIZE 114 RAISED.

           CALL 'W$BITMAP' USING
                WBITMAP-LOAD, 'help.jpg' GIVING S-BITMAP.

           MOVE 'Y' TO S-RUN.
           INITIALIZE DBLAI2-REC WS-MISC.
           PERFORM 0100-MAIN THRU 0199-END UNTIL S-RUN = 'N'.

       TERMINATION.
           CLOSE WINDOW S-WINDOW.
           CLOSE DBLAI2-FILE.
           CLOSE DBLAI-FILE.
           EXIT PROGRAM.
           STOP RUN.

      ****************************************************************
       0100-MAIN.
           UNLOCK DBLAI2-FILE.
           PERFORM ERROR-RTN THRU ERROR-END.

           MOVE 'S' TO S-PRS-MODE.
           PERFORM FKEY-RTN THRU FKEY-END.

           PERFORM GET-DB-NAME THRU GET-DB-NAME-END.
           DISPLAY SELECT-SCR.
           ACCEPT  SELECT-SCR.
           MOVE 4 TO ACCEPT-CONTROL.

           IF K-ESCAPE
              MOVE 'N' TO S-RUN GO TO 0199-END.

      * --- HELP LOOKUPS (F10) FOR KEY FIELDS ---
           IF (K-F10 AND S-CONTROL-ID = 101) OR KEY-STATUS = 101
              CALL   '/z/sp6ai/v2/prg/hpdblai' USING
                     DBLAI2-DB, WS-OK
              CANCEL '/z/sp6ai/v2/prg/hpdblai'
              MOVE 101 TO S-CONTROL-ID
              PERFORM GET-DB-NAME THRU GET-DB-NAME-END
              IF WS-OK = 'Y'
                 GO TO 0110-MAIN
              ELSE
                 GO TO 0100-MAIN.

           IF (K-F10 AND S-CONTROL-ID = 102) OR KEY-STATUS = 102
              CALL   '/z/sp6ai/v2/prg/hpdblai2' USING
                        DBLAI2-KEY, WS-OK
              CANCEL '/z/sp6ai/v2/prg/hpdblai2'
              MOVE 102 TO S-CONTROL-ID
              IF WS-OK = 'Y'
                 GO TO 0120-MAIN
              ELSE
                 GO TO 0100-MAIN.

           IF K-F2
              PERFORM GET-NEXT THRU GET-NEXT-END
              IF S-STATUS-CHECK = 'Y' OR S-ERROR-CODE NOT = ZEROS
                 GO TO 0100-MAIN
              ELSE
                 GO TO 0120-MAIN.

           IF K-F3
              PERFORM GET-PREV THRU GET-PREV-END
              IF S-STATUS-CHECK = 'Y' OR S-ERROR-CODE NOT = ZEROS
                 GO TO 0100-MAIN
              ELSE
                 GO TO 0120-MAIN.
 
      * --- VIEW LIST CALL (F7) ---
           IF K-F7
              CALL   '/z/sp6ai/v2/prg/vwdblai2' USING LINK-PROG-KEY
              CANCEL '/z/sp6ai/v2/prg/vwdblai2'
              GO TO 0100-MAIN.

           IF NOT K-ENTER GO TO 0100-MAIN.

       0110-MAIN.
           IF DBLAI2-DB = SPACES
              MOVE 200005 TO S-ERROR-CODE
              MOVE 101    TO S-CONTROL-ID
              GO TO 0100-MAIN.

           PERFORM GET-DB-NAME THRU GET-DB-NAME-END.
      
      * IF CURSOR WAS ON DB NAME FIELD (101), RE-DISPLAY AND STAY ON SELECT-SCR
           IF S-CONTROL-ID = 101
              GO TO 0100-MAIN.
      
           IF DBLAI2-FIELD = SPACES
              MOVE 200005 TO S-ERROR-CODE
              MOVE 102    TO S-CONTROL-ID
              GO TO 0100-MAIN.

       0120-MAIN.
           MOVE 'N' TO S-STATUS-CHECK.
           MOVE 'R' TO S-PRS-MODE.
           READ DBLAI2-FILE INVALID
                MOVE 'A' TO S-PRS-MODE
                INITIALIZE DBLAI2-DETAILS.

           PERFORM SYNC-ATTR-TO-VAL.

           IF S-STATUS-CHECK = 'Y' GO TO 0190-MAIN.

           PERFORM GET-DB-NAME THRU GET-DB-NAME-END.
           DESTROY SELECT-SCR.
           PERFORM FKEY-RTN THRU FKEY-END.

        0130-MAIN.
           PERFORM SYNC-VAL-TO-ATTR.
           PERFORM CHECK-LINK-STATE.
           PERFORM GET-LINK-DB-NAME THRU GET-LINK-DB-NAME-END.
           PERFORM ERROR-RTN THRU ERROR-END.
           DISPLAY PROCESS-SCR.
           ACCEPT  PROCESS-SCR.
           MOVE 4 TO ACCEPT-CONTROL.

           IF K-ESCAPE
              MOVE 'N' TO S-RUN GO TO 0190-MAIN.

      * --- HELP LOOKUP FOR LINK DB (ID 107) ---
           IF (K-F10 AND S-CONTROL-ID = 107) OR KEY-STATUS = 107
              CALL   '/z/sp6ai/v2/prg/hpdblai' USING
                     DBLAI2-LINK-DB, WS-OK
              CANCEL '/z/sp6ai/v2/prg/hpdblai'
              MOVE 107 TO S-CONTROL-ID
              PERFORM GET-LINK-DB-NAME THRU GET-LINK-DB-NAME-END
              GO TO 0130-MAIN.

      * --- HELP LOOKUP FOR LINK FIELD (ID 108) ---
           IF (K-F10 AND S-CONTROL-ID = 108) OR KEY-STATUS = 108
              INITIALIZE WS-LOOKUP-KEY
              MOVE DBLAI2-LINK-DB    TO WS-LOOKUP-DB
              MOVE DBLAI2-LINK-FIELD TO WS-LOOKUP-FIELD
              CALL   '/z/sp6ai/v2/prg/hpdblai2' USING
                     WS-LOOKUP-KEY, WS-OK
              CANCEL '/z/sp6ai/v2/prg/hpdblai2'
              IF WS-OK = 'Y'
                 MOVE WS-LOOKUP-FIELD TO DBLAI2-LINK-FIELD
              END-IF
              MOVE 108 TO S-CONTROL-ID
              GO TO 0130-MAIN.

           IF K-F1 GO TO 0190-MAIN.

           IF K-F2
              PERFORM GET-NEXT THRU GET-NEXT-END
              IF S-STATUS-CHECK = 'Y' OR S-ERROR-CODE NOT = ZEROS
                 GO TO 0130-MAIN
              ELSE
                 GO TO 0120-MAIN.

           IF K-F3
              PERFORM GET-PREV THRU GET-PREV-END
              IF S-STATUS-CHECK = 'Y' OR S-ERROR-CODE NOT = ZEROS
                 GO TO 0130-MAIN
              ELSE
                 GO TO 0120-MAIN.

      * --- VIEW LIST CALL (F7) ---
           IF K-F7
              CALL   '/z/sp6ai/v2/prg/vwdblai2' USING LINK-PROG-KEY
              CANCEL '/z/sp6ai/v2/prg/vwdblai2'
              GO TO 0130-MAIN.

           IF K-F4 AND S-PRS-MODE = 'R'
              PERFORM CONFIRM-RTN THRU CONFIRM-END
              IF S-CONFIRM = 'Y'
                 DELETE DBLAI2-FILE
                 GO TO 0190-MAIN
              ELSE
                 GO TO 0130-MAIN.

           IF NOT (K-F8 OR K-ENTER) GO TO 0130-MAIN.

      * --- FIELD VALIDATIONS ---
           IF DBLAI2-ATTRIBUTE NOT = 'PK' AND NOT = 'FK' AND NOT = 'DE'
              MOVE 100040 TO S-ERROR-CODE
              MOVE 103    TO S-CONTROL-ID
              GO TO 0130-MAIN.

           IF DBLAI2-ATTRIBUTE = 'FK'
              IF DBLAI2-LINK-DB = SPACES
                 MOVE 200115 TO S-ERROR-CODE
                 MOVE 107    TO S-CONTROL-ID
                 GO TO 0130-MAIN
              END-IF

              IF DBLAI2-LINK-FIELD = SPACES
                 MOVE 200115 TO S-ERROR-CODE
                 MOVE 108    TO S-CONTROL-ID
                 GO TO 0130-MAIN
              END-IF

      * --- VALIDATE LINK DB EXISTS IN DBLAI-FILE ---
              MOVE DBLAI2-LINK-DB TO DBLAI-DB
              READ DBLAI-FILE INVALID
                 MOVE 100010 TO S-ERROR-CODE
                 MOVE 107    TO S-CONTROL-ID
                 GO TO 0130-MAIN
              END-READ

      * --- VALIDATE LINK FIELD EXISTS IN DBLAI2-FILE ---
              MOVE DBLAI2-REC TO WS-MISC
              MOVE DBLAI2-LINK-DB    TO DBLAI2-DB
              MOVE DBLAI2-LINK-FIELD TO DBLAI2-FIELD
              READ DBLAI2-FILE INVALID
                 MOVE 100010 TO S-ERROR-CODE
                 MOVE 108    TO S-CONTROL-ID
                 MOVE WS-MISC TO DBLAI2-REC
                 GO TO 0130-MAIN
              END-READ
              MOVE WS-MISC TO DBLAI2-REC
          ELSE
              MOVE SPACES TO DBLAI2-LINK-DB DBLAI2-LINK-FIELD
           END-IF.

          
           PERFORM CONFIRM-RTN THRU CONFIRM-END.
           IF S-CONFIRM NOT = 'Y'
              GO TO 0130-MAIN.

           IF S-PRS-MODE = 'A' WRITE DBLAI2-REC.
           IF S-PRS-MODE = 'R' REWRITE DBLAI2-REC.

       0190-MAIN.
           DESTROY PROCESS-SCR.

       0199-END. EXIT.

      ****************************************************************
       CHECK-LINK-STATE.
           IF DBLAI2-ATTRIBUTE = 'FK'
              MOVE 1 TO WS-ENABLE-LINK
           ELSE
              MOVE 0 TO WS-ENABLE-LINK
              MOVE SPACES TO DBLAI2-LINK-DB DBLAI2-LINK-FIELD
           END-IF.

       SYNC-ATTR-TO-VAL.
           EVALUATE DBLAI2-ATTRIBUTE
               WHEN 'FK' MOVE 2 TO WS-ATTR-VAL
               WHEN 'DE' MOVE 3 TO WS-ATTR-VAL
               WHEN OTHER MOVE 1 TO WS-ATTR-VAL
           END-EVALUATE.

       SYNC-VAL-TO-ATTR.
           EVALUATE WS-ATTR-VAL
               WHEN 1 MOVE 'PK' TO DBLAI2-ATTRIBUTE
               WHEN 2 MOVE 'FK' TO DBLAI2-ATTRIBUTE
               WHEN 3 MOVE 'DE' TO DBLAI2-ATTRIBUTE
               WHEN OTHER MOVE 'PK' TO DBLAI2-ATTRIBUTE
           END-EVALUATE.

      ****************************************************************
       GET-DB-NAME.
           MOVE SPACES TO WS-DB-NAME.
           IF DBLAI2-DB NOT = SPACES
              MOVE DBLAI2-DB TO DBLAI-DB
              READ DBLAI-FILE INVALID
                   MOVE 'NOT FOUND' TO WS-DB-NAME
              NOT INVALID
                   MOVE DBLAI-DB-NAME TO WS-DB-NAME
              END-READ
           END-IF.
       GET-DB-NAME-END. EXIT.

      ****************************************************************
       GET-LINK-DB-NAME.
           MOVE SPACES TO WS-LINK-DB-NAME.
           IF DBLAI2-LINK-DB NOT = SPACES
              MOVE DBLAI2-LINK-DB TO DBLAI-DB
              READ DBLAI-FILE INVALID
                   MOVE 'NOT FOUND' TO WS-LINK-DB-NAME
              NOT INVALID 
                   MOVE DBLAI-DB-NAME TO WS-LINK-DB-NAME
              END-READ
           END-IF.
       GET-LINK-DB-NAME-END. EXIT.

      ****************************************************************
       GET-NEXT.
           START DBLAI2-FILE KEY > DBLAI2-KEY INVALID
                 MOVE 100010 TO S-ERROR-CODE
           NOT INVALID
                 READ DBLAI2-FILE NEXT END
                      MOVE 100010 TO S-ERROR-CODE
                 END-READ.
       GET-NEXT-END. EXIT.

      ****************************************************************
       GET-PREV.
           START DBLAI2-FILE KEY < DBLAI2-KEY INVALID
                 MOVE 100005 TO S-ERROR-CODE
           NOT INVALID
                 READ DBLAI2-FILE PREVIOUS END
                      MOVE 100005 TO S-ERROR-CODE
                 END-READ.
       GET-PREV-END. EXIT.

      ****************************************************************
       FKEY-RTN.
           EVALUATE S-PRS-MODE
            WHEN 'S' MOVE '1yy456y89012y4567890' TO S-ACTIVE-FKEY
            WHEN 'A' MOVE 'yyy456yy9012y4567890' TO S-ACTIVE-FKEY
            WHEN 'R' MOVE 'yyyy56yy9012y4567890' TO S-ACTIVE-FKEY
           END-EVALUATE.

           CALL   '/v/cps/lib/std/x-fkey' USING
                  S-ACTIVE-FKEY, S-TOOLBAR, S-BUTTON.
           CANCEL '/v/cps/lib/std/x-fkey'.
           COPY   '/v/cps/lib/std/fmmode.prd'.
       FKEY-END. EXIT.

      ****************************************************************
           COPY '/v/cps/lib/std/cfirm.prd'.
           COPY '/v/cps/lib/std/errmsg.prd'.
