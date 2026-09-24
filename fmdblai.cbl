       IDENTIFICATION DIVISION.
       PROGRAM-ID.    FMBLAI.

      * DEFINE DB LINK TO AI (DBLAI)
      * SHIDAH   02/09/26   -     PAA   SP6AI

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
        FILE-CONTROL.
           COPY '/z/sp6ai/v2/lib/fd/fcdblai'.

       DATA DIVISION.
       FILE SECTION.
           COPY '/z/sp6ai/v2/lib/fd/fddblai'.

       WORKING-STORAGE SECTION.
           COPY '/z/sp6ai/v2/lib/fd/dbdblai'.
           COPY '/v/cps/lib/std/stdvar.def'.
           COPY '/v/cps/lib/std/fkey.def'.
           COPY RESOURCE '/v/cps/lib/icon/help.jpg'.

       01 WS-MISC.
          03 WS-OK               PIC X(01).

       LINKAGE SECTION.
       01 LINK-PROG-KEY          PIC X(30).

       SCREEN SECTION.
       01 SELECT-SCR.
          COPY '/v/cps/lib/std/fmmode.scr'.
          03 LABEL LINE 02 COL 04 'LINK DB:'.
          03 ENTRY-FIELD 3-D ID 101 COL 20 PIC X(20)
             USING DBLAI-DB.
          03 PUSH-BUTTON 'F10 - Help Table' NO-TAB FLAT
             COL + 1.5 LINES 19 SIZE 19
             BITMAP-HANDLE S-BITMAP
             BITMAP-NUMBER   = 1
             TERMINATION-VALUE = 101.

       01 PROCESS-SCR.
          COPY '/v/cps/lib/std/fmmode.scr'.
          03 LABEL LINE 02 COL 04 'LINK DB:'.
          03 ENTRY-FIELD 3-D ENABLED 0 COL 20 PIC X(20)
             USING DBLAI-DB.

          03 LABEL LINE + 1 COL 04 'LINK DB NAME:'.
          03 ENTRY-FIELD 3-D ID 102 COL 20 PIC X(60)
             USING DBLAI-DB-NAME.

          03 LABEL LINE + 1 COL 04 'ALLOW AI READ:'.
          03 RADIO-BUTTON 'Yes' USING DBLAI-READ-FLAG
             GROUP 1 GROUP-VALUE 'Y' COL 20.
          03 RADIO-BUTTON 'No'  USING DBLAI-READ-FLAG
             GROUP 1 GROUP-VALUE 'N' COL + 3.

      ****************************************************************
       PROCEDURE DIVISION USING LINK-PROG-KEY.

       DECLARATIVES.
           COPY '/z/sp6ai/v2/lib/fd/dcdblai'.
       END DECLARATIVES.

      ****************************************************************
       BEGIN.
           MOVE 'N' TO S-RUN.
           OPEN I-O DBLAI-FILE.

           MOVE 'DEFINE DB LINK TO AI' TO S-WINDOW-TITLE.
           COPY '/v/cps/lib/std/floatwin.prd'.

           CALL 'W$BITMAP' USING
                WBITMAP-LOAD, 'help.jpg' GIVING S-BITMAP.

           MOVE 'Y' TO S-RUN.
           INITIALIZE DBLAI-REC WS-MISC.
           PERFORM 0100-MAIN THRU 0199-END UNTIL S-RUN = 'N'.

       TERMINATION.
           CLOSE WINDOW S-WINDOW.
           CLOSE DBLAI-FILE.
           EXIT PROGRAM.
           STOP RUN.

      ****************************************************************
       0100-MAIN.
           UNLOCK DBLAI-FILE.
           PERFORM ERROR-RTN THRU ERROR-END.

           MOVE 'S' TO S-PRS-MODE.
           PERFORM FKEY-RTN THRU FKEY-END.

           DISPLAY SELECT-SCR.
           ACCEPT  SELECT-SCR.
           MOVE 4 TO ACCEPT-CONTROL.

           IF K-ESCAPE
              MOVE 'N' TO S-RUN GO TO 0199-END.

      * --- HELP LOOKUP (F10) FOR KEY ---
           IF (K-F10 AND S-CONTROL-ID = 101) OR KEY-STATUS = 101
              CALL   '/z/sp6ai/v2/prg/hpdblai' USING DBLAI-DB, WS-OK
              CANCEL '/z/sp6ai/v2/prg/hpdblai'
              MOVE 101 TO S-CONTROL-ID
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


           IF K-F7
              CALL   '/z/sp6ai/v2/prg/vwdblai' USING LINK-PROG-KEY
              CANCEL '/z/sp6ai/v2/prg/vwdblai'
              GO TO 0100-MAIN.

           IF NOT K-ENTER GO TO 0100-MAIN.

           IF DBLAI-DB = SPACES
              MOVE 200005 TO S-ERROR-CODE
              MOVE 101    TO S-CONTROL-ID
              GO TO 0100-MAIN.

       0120-MAIN.
           MOVE 'N' TO S-STATUS-CHECK.
           MOVE 'R' TO S-PRS-MODE.
           READ DBLAI-FILE INVALID
                MOVE 'A' TO S-PRS-MODE
                INITIALIZE DBLAI-DETAILS
                MOVE SPACE TO DBLAI-READ-FLAG.

           IF S-STATUS-CHECK = 'Y' GO TO 0190-MAIN.

           DESTROY SELECT-SCR.
           PERFORM FKEY-RTN THRU FKEY-END.
           DISPLAY PROCESS-SCR.

       0130-MAIN.
           PERFORM ERROR-RTN THRU ERROR-END.
           DISPLAY PROCESS-SCR.
           ACCEPT  PROCESS-SCR.
           MOVE 4 TO ACCEPT-CONTROL.

           IF K-ESCAPE
              MOVE 'N' TO S-RUN GO TO 0190-MAIN.

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
              CALL   '/z/sp6ai/v2/prg/vwdblai' USING LINK-PROG-KEY
              CANCEL '/z/sp6ai/v2/prg/vwdblai'
              GO TO 0100-MAIN.

           IF K-F4 AND S-PRS-MODE = 'R'
              PERFORM CONFIRM-RTN THRU CONFIRM-END
              IF S-CONFIRM = 'Y'
                 DELETE DBLAI-FILE
                 GO TO 0190-MAIN
              ELSE
                 GO TO 0130-MAIN.

           IF NOT (K-F8 OR K-ENTER) GO TO 0130-MAIN.

      * --- FIELD VALIDATIONS ---
           IF DBLAI-DB-NAME = SPACES
              MOVE 200115  TO S-ERROR-CODE
              MOVE 102     TO S-CONTROL-ID
              GO TO 0130-MAIN.

           IF DBLAI-READ-FLAG = SPACES
              MOVE 200020 TO S-ERROR-CODE
              GO TO 0130-MAIN.

           IF DBLAI-READ-FLAG NOT = 'Y' AND NOT = 'N'
              MOVE 100040  TO S-ERROR-CODE
              GO TO 0130-MAIN.

           PERFORM CONFIRM-RTN THRU CONFIRM-END.
           IF S-CONFIRM NOT = 'Y'
              GO TO 0130-MAIN.

           IF S-PRS-MODE = 'A' WRITE DBLAI-REC.
           IF S-PRS-MODE = 'R' REWRITE DBLAI-REC.

       0190-MAIN.
           DESTROY PROCESS-SCR.

       0199-END. EXIT.

      ****************************************************************
       GET-NEXT.
           START DBLAI-FILE KEY > DBLAI-DB INVALID
                 MOVE 100010 TO S-ERROR-CODE
           NOT INVALID
                 READ DBLAI-FILE NEXT END
                      MOVE 100010 TO S-ERROR-CODE
                 END-READ.
       GET-NEXT-END. EXIT.

      ****************************************************************
       GET-PREV.
           START DBLAI-FILE KEY < DBLAI-DB INVALID
                 MOVE 100005 TO S-ERROR-CODE
           NOT INVALID
                 READ DBLAI-FILE PREVIOUS END
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
