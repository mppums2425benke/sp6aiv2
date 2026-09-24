        IDENTIFICATION DIVISION.
        PROGRAM-ID.   FMDBLRULE.

      * MAINTAIN AI DYNAMIC RULES & RBAC POLICIES (AUTO-ORDERING)
      * AUTHOR       DATE     TYPE   A/C  NOTES
      * SD,AL,SS,YT  15/09/26   -      PAA  SP6 - Maintain AI Dynamic Rules

       ENVIRONMENT DIVISION.
        INPUT-OUTPUT SECTION.
         FILE-CONTROL.
           COPY '/z/sp6ai/v2/lib/fd/fcdblrule'.

       DATA DIVISION.
        FILE SECTION.
           COPY '/z/sp6ai/v2/lib/fd/fddblrule'.

        WORKING-STORAGE SECTION.
           COPY '/z/sp6ai/v2/lib/fd/dbdblrule'.
           COPY '/v/cps/lib/std/stdvar.def'.
           COPY '/v/cps/lib/std/fkey.def'.
           COPY RESOURCE '/v/cps/lib/icon/help.jpg'.

        01 WS-ACTIVE-OPT        PIC 9(01) VALUE 1.

        LINKAGE SECTION.
        01 LINK-PROG-KEY        PIC X(30).

       SCREEN SECTION.
        01 SELECT-SCR.
           COPY '/v/cps/lib/std/fmmode.scr'.
           03 LABEL LINE 02 COL 04 'Rule ID:'.
           03 ENTRY-FIELD 3-D ID 101 COL 14 PIC X(06)
              USING DBLRULE-ID UPPER.
           03 PUSH-BUTTON 'F10 - Help Table' NO-TAB
              LINE - 0.05 COL + 1.5 LINES 19 SIZE 19 BITMAP NO-TAB FLAT
              BITMAP-HANDLE S-BITMAP
              BITMAP-NUMBER     = 1
              TERMINATION-VALUE = 101.

        01 PROCESS-SCR.
           COPY '/v/cps/lib/std/fmmode.scr'.
           03 LABEL LINE 02 COL 04 'Rule ID:'.
           03 ENTRY-FIELD 3-D ENABLED 0 COL 20 PIC X(06)
              USING DBLRULE-ID.

           03 LABEL LINE + 1.3 COL 04 'Category:'.
           03 ENTRY-FIELD 3-D ID 102 COL 20 PIC X(10)
              USING DBLRULE-CATEGORY UPPER.
           03 LABEL COL + 2 '(PROMPT / SECURITY / FORMAT)'.

           03 LABEL LINE + 1.3 COL 04 'Execution Order:'.
           03 ENTRY-FIELD 3-D ENABLED 0 COL 20 PIC 9(03)
              USING DBLRULE-ORDER.
           03 LABEL COL + 2 '(Auto-assigned by Category)'.

           03 LABEL LINE + 1.3 COL 04 'Active Status:'.
           03 RADIO-BUTTON ID 105 LINE + 0.2 COL 20 GROUP-VALUE 1
              GROUP 1 VALUE WS-ACTIVE-OPT TITLE 'Yes (Active)'.
           03 RADIO-BUTTON ID 106 COL + 3 GROUP-VALUE 2
              GROUP 1 VALUE WS-ACTIVE-OPT TITLE 'No (Disabled)'.

           03 LABEL LINE + 1.5 COL 04 'Rule Content:'.
           03 ENTRY-FIELD 3-D ID 107 MULTILINE LINES 6.5
              COL 20 SIZE 84 PIC X(350)
              USING DBLRULE-TEXT.

      ******************************************************************
       PROCEDURE DIVISION USING LINK-PROG-KEY.

        DECLARATIVES.
           COPY '/z/sp6ai/v2/lib/fd/dcdblrule'.
        END DECLARATIVES.

      ******************************************************************
        BEGIN.
           MOVE 'N' TO S-RUN.
           MOVE 'N' TO S-STATUS-CHECK.

           OPEN I-O DBLRULE-FILE.
           IF DBLRULE-STATUS = '35'
              OPEN OUTPUT DBLRULE-FILE
              CLOSE DBLRULE-FILE
              OPEN I-O DBLRULE-FILE
           END-IF.

           MOVE 'AI Dynamic Rule Maintenance' TO S-WINDOW-TITLE.
           COPY '/v/cps/lib/std/floatwin.prd'.

           CALL 'W$BITMAP' USING WBITMAP-LOAD, 'help.jpg'
                GIVING S-BITMAP.

           MOVE 'Y' TO S-RUN.
           INITIALIZE DBLRULE-REC.
           PERFORM 0100-MAIN THRU 0199-END UNTIL S-RUN = 'N'.

       TERMINATION.
          CLOSE WINDOW S-WINDOW.
          CLOSE DBLRULE-FILE.
          EXIT PROGRAM.
          STOP RUN.

      ******************************************************************
        0100-MAIN.
           MOVE 'S' TO S-PRS-MODE.
           PERFORM FKEY-RTN THRU FKEY-END.

        0110-MAIN.
           UNLOCK DBLRULE-FILE.
           PERFORM ERROR-RTN THRU ERROR-END.
           DISPLAY SELECT-SCR.
           ACCEPT  SELECT-SCR.
           MOVE 4 TO ACCEPT-CONTROL.

           IF K-ESCAPE
              MOVE 'N' TO S-RUN GO TO 0199-END.

           IF K-F2
              PERFORM GET-NEXT THRU GET-NEXT-END
              IF S-STATUS-CHECK = 'Y' OR S-ERROR-CODE NOT = ZEROS
                 GO TO 0110-MAIN
              ELSE
                 GO TO 0120-MAIN.

           IF K-F3
              PERFORM GET-PREV THRU GET-PREV-END
              IF S-STATUS-CHECK = 'Y' OR S-ERROR-CODE NOT = ZEROS
                 GO TO 0110-MAIN
              ELSE
                 GO TO 0120-MAIN.

           IF K-F6 OR K-F5
              CALL   '/z/sp6ai/v2/prg/ptdblrule'
                     USING LINK-PROG-KEY
              CANCEL '/z/sp6ai/v2/prg/ptdblrule'
              GO TO 0110-MAIN.

           IF K-F7
              CALL   '/z/sp6ai/v2/prg/vwdblrule'
                     USING LINK-PROG-KEY
              CANCEL '/z/sp6ai/v2/prg/vwdblrule'
              GO TO 0110-MAIN.

           IF K-F1 OR (K-F10 AND S-CONTROL-ID = 101) OR KEY-STATUS = 101
              CALL   '/z/sp6ai/v2/prg/hpdblrule'
                     USING DBLRULE-ID, S-OK
              CANCEL '/z/sp6ai/v2/prg/hpdblrule'
              MOVE 101 TO S-CONTROL-ID
              IF S-OK = 'Y'
                 DISPLAY SELECT-SCR
                 GO TO 0120-MAIN
              ELSE
                 GO TO 0110-MAIN
              END-IF.

           IF NOT K-ENTER GO TO 0110-MAIN.

           IF DBLRULE-ID = SPACES
              MOVE 200005 TO S-ERROR-CODE
              MOVE 101    TO S-CONTROL-ID
              GO TO 0110-MAIN.

        0120-MAIN.
           MOVE 'N' TO S-STATUS-CHECK.
           MOVE 'R' TO S-PRS-MODE.
           READ DBLRULE-FILE INVALID
                MOVE 'A' TO S-PRS-MODE
                INITIALIZE DBLRULE-DETAILS
                MOVE 'Y' TO DBLRULE-ACTIVE
                MOVE 'PROMPT' TO DBLRULE-CATEGORY.

           IF S-STATUS-CHECK = 'Y' GO TO 0190-MAIN.

           IF DBLRULE-ACTIVE = 'N'
              MOVE 2 TO WS-ACTIVE-OPT
           ELSE
              MOVE 1 TO WS-ACTIVE-OPT.

           DESTROY SELECT-SCR.
           PERFORM FKEY-RTN THRU FKEY-END.

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
              GO TO 0120-MAIN.

           IF K-F3
              PERFORM GET-PREV THRU GET-PREV-END
              GO TO 0120-MAIN.

           IF K-F4
              IF S-PRS-MODE = 'A'
                 GO TO 0190-MAIN
              ELSE
                 PERFORM CONFIRM-RTN THRU CONFIRM-END
                 IF S-CONFIRM = 'Y'
                    DELETE DBLRULE-FILE
                    GO TO 0190-MAIN
                 ELSE
                    GO TO 0130-MAIN
                 END-IF
              END-IF.

           IF NOT (K-F8 OR K-ENTER) GO TO 0130-MAIN.

           IF DBLRULE-TEXT = SPACES
              MOVE 200015 TO S-ERROR-CODE
              MOVE 107    TO S-CONTROL-ID
              GO TO 0130-MAIN.

      * AUTO ASSIGN EXECUTION ORDER BASED ON CATEGORY
           EVALUATE FUNCTION UPPER-CASE(DBLRULE-CATEGORY)
            WHEN 'PROMPT'   MOVE 010 TO DBLRULE-ORDER
            WHEN 'SECURITY' MOVE 020 TO DBLRULE-ORDER
            WHEN 'FORMAT'   MOVE 030 TO DBLRULE-ORDER
            WHEN OTHER      MOVE 050 TO DBLRULE-ORDER
           END-EVALUATE.

           PERFORM CONFIRM-RTN THRU CONFIRM-END.
           IF S-CONFIRM NOT = 'Y'
              GO TO 0130-MAIN.

           IF WS-ACTIVE-OPT = 2
              MOVE 'N' TO DBLRULE-ACTIVE
           ELSE
              MOVE 'Y' TO DBLRULE-ACTIVE.

           IF S-PRS-MODE = 'A' WRITE DBLRULE-REC.
           IF S-PRS-MODE = 'R' REWRITE DBLRULE-REC.

        0190-MAIN.
           DESTROY PROCESS-SCR.

        0199-END. EXIT.

      ******************************************************************
        GET-NEXT.
           START DBLRULE-FILE KEY > DBLRULE-KEY INVALID
                 MOVE 100010 TO S-ERROR-CODE
                 NOT INVALID
                     READ DBLRULE-FILE NEXT END
                          MOVE 100010 TO S-ERROR-CODE
                     END-READ.
        GET-NEXT-END. EXIT.

      ******************************************************************
        GET-PREV.
           START DBLRULE-FILE KEY < DBLRULE-KEY INVALID
                 MOVE 100005 TO S-ERROR-CODE
                 NOT INVALID
                     READ DBLRULE-FILE BACKWARD END
                          MOVE 100005 TO S-ERROR-CODE
                     END-READ.
        GET-PREV-END. EXIT.

      ******************************************************************
        FKEY-RTN.
           EVALUATE S-PRS-MODE
            WHEN 'S' MOVE '1yy456y89012y4567890' TO S-ACTIVE-FKEY
            WHEN 'A' MOVE 'yyyy567y9012y4567890' TO S-ACTIVE-FKEY
            WHEN 'R' MOVE 'yyyy567y9012y4567890' TO S-ACTIVE-FKEY
           END-EVALUATE.

           CALL   '/v/cps/lib/std/x-fkey' USING
                  S-ACTIVE-FKEY, S-TOOLBAR, S-BUTTON.
           CANCEL '/v/cps/lib/std/x-fkey'.
           COPY   '/v/cps/lib/std/fmmode.prd'.
        FKEY-END. EXIT.

      ******************************************************************
           COPY '/v/cps/lib/std/cfirm.prd'.
           COPY '/z/sp6ai/v2/lib/std/errmsg.prd'.
