       IDENTIFICATION DIVISION.
       PROGRAM-ID.    FMDBLCF.

      * MAINTAIN AI ENGINE CONFIGURATION FILE (DBLCF)
      * SD,AL,SS,YT   15/09/26   -     PAA   SP6AI

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
        FILE-CONTROL.
           COPY '/z/sp6ai/v2/lib/fd/fcdblcf'.

       DATA DIVISION.
       FILE SECTION.
           COPY '/z/sp6ai/v2/lib/fd/fddblcf'.

       WORKING-STORAGE SECTION.
           COPY '/z/sp6ai/v2/lib/fd/dbdblcf'.
           COPY '/v/cps/lib/std/stdvar.def'.
           COPY '/v/cps/lib/std/fkey.def'.

       01 WS-MISC.
          03 WS-OK               PIC X(01).

       LINKAGE SECTION.
       01 LINK-PROG-KEY          PIC X(30).

       SCREEN SECTION.
       01 MAIN-SCR.
          COPY '/v/cps/lib/std/fmmode.scr'.
          
      * --- OPENAI CONFIGURATION ---
          03 LABEL LINE 02 COL 04 'OPENAI CONFIGURATION' BOLD.
          03 LABEL LINE + 1 COL 04 'ACTIVATE AI:'.
          03 RADIO-BUTTON 'Yes' USING DBLCF-OPENAI-FLAG
             GROUP 1 GROUP-VALUE 'Y' COL 25.
          03 RADIO-BUTTON 'No'  USING DBLCF-OPENAI-FLAG
             GROUP 1 GROUP-VALUE 'N' COL + 3.

          03 LABEL LINE + 1 COL 04 'API ENDPOINT URL:'.
          03 ENTRY-FIELD 3-D ID 101 COL 25 PIC X(70)
             USING DBLCF-OPENAI-API-LINK.

          03 LABEL LINE + 1 COL 04 'API KEY:'.
          03 ENTRY-FIELD 3-D ID 102 COL 25 PIC X(70)
             USING DBLCF-OPENAI-API-KEY.

          03 LABEL LINE + 1 COL 04 'AI MODEL NAME:'.
          03 ENTRY-FIELD 3-D ID 103 COL 25 PIC X(50)
             USING DBLCF-OPENAI-API-MODEL.

      * --- META AI CONFIGURATION ---
          03 LABEL LINE + 2 COL 04 'META AI CONFIGURATION' BOLD.
          03 LABEL LINE + 1 COL 04 'ACTIVATE AI:'.
          03 RADIO-BUTTON 'Yes' USING DBLCF-META-FLAG
             GROUP 2 GROUP-VALUE 'Y' COL 25.
          03 RADIO-BUTTON 'No'  USING DBLCF-META-FLAG
             GROUP 2 GROUP-VALUE 'N' COL + 3.

          03 LABEL LINE + 1 COL 04 'API ENDPOINT URL:'.
          03 ENTRY-FIELD 3-D ID 104 COL 25 PIC X(70)
             USING DBLCF-META-API-LINK.

          03 LABEL LINE + 1 COL 04 'API KEY:'.
          03 ENTRY-FIELD 3-D ID 105 COL 25 PIC X(70)
             USING DBLCF-META-API-KEY.

          03 LABEL LINE + 1 COL 04 'AI MODEL NAME:'.
          03 ENTRY-FIELD 3-D ID 106 COL 25 PIC X(50)
             USING DBLCF-META-API-MODEL.

      * --- DEEPSEEK CONFIGURATION ---
          03 LABEL LINE + 2 COL 04 'DEEPSEEK CONFIGURATION' BOLD.
          03 LABEL LINE + 1 COL 04 'ACTIVATE AI:'.
          03 RADIO-BUTTON 'Yes' USING DBLCF-DS-FLAG
             GROUP 3 GROUP-VALUE 'Y' COL 25.
          03 RADIO-BUTTON 'No'  USING DBLCF-DS-FLAG
             GROUP 3 GROUP-VALUE 'N' COL + 3.

          03 LABEL LINE + 1 COL 04 'API ENDPOINT URL:'.
          03 ENTRY-FIELD 3-D ID 107 COL 25 PIC X(70)
             USING DBLCF-DS-API-LINK.

          03 LABEL LINE + 1 COL 04 'API KEY:'.
          03 ENTRY-FIELD 3-D ID 108 COL 25 PIC X(70)
             USING DBLCF-DS-API-KEY.

          03 LABEL LINE + 1 COL 04 'AI MODEL NAME:'.
          03 ENTRY-FIELD 3-D ID 109 COL 25 PIC X(50)
             USING DBLCF-DS-API-MODEL.

      * --- GEMINI (GOOGLE) CONFIGURATION ---
          03 LABEL LINE + 2 COL 04 'GEMINI (GOOGLE) CONFIGURATION' BOLD.
          03 LABEL LINE + 1 COL 04 'ACTIVATE AI:'.
          03 RADIO-BUTTON 'Yes' USING DBLCF-GM-FLAG
             GROUP 4 GROUP-VALUE 'Y' COL 25.
          03 RADIO-BUTTON 'No'  USING DBLCF-GM-FLAG
             GROUP 4 GROUP-VALUE 'N' COL + 3.

          03 LABEL LINE + 1 COL 04 'API ENDPOINT URL:'.
          03 ENTRY-FIELD 3-D ID 110 COL 25 PIC X(70)
             USING DBLCF-GM-API-LINK.

          03 LABEL LINE + 1 COL 04 'API KEY:'.
          03 ENTRY-FIELD 3-D ID 111 COL 25 PIC X(70)
             USING DBLCF-GM-API-KEY.

          03 LABEL LINE + 1 COL 04 'AI MODEL NAME:'.
          03 ENTRY-FIELD 3-D ID 112 COL 25 PIC X(50)
             USING DBLCF-GM-API-MODEL.

      ****************************************************************
       PROCEDURE DIVISION USING LINK-PROG-KEY.

       DECLARATIVES.
           COPY '/z/sp6ai/v2/lib/fd/dcdblcf'.
       END DECLARATIVES.

      ****************************************************************
       BEGIN.
           MOVE 'N' TO S-RUN.
           OPEN I-O DBLCF-FILE.

           MOVE 'AI ENGINE CONFIGURATION' TO S-WINDOW-TITLE.
      * Floating Window (800 x 600)
           DISPLAY FLOATING WINDOW
           LINES 25 SIZE 112 CELL SIZE = ENTRY-FIELD FONT SEPARATE
           TITLE-BAR MODAL NO SCROLL NO WRAP NO-CLOSE
           TITLE S-WINDOW-TITLE
           POP-UP S-WINDOW.
           DISPLAY TOOL-BAR, LINES 2.8 HANDLE S-TOOLBAR.
           DISPLAY FRAME AT 0102 LINES 24.7 CELL SIZE 110 RAISED.
           
           MOVE 'Y' TO S-RUN.
           MOVE '1' TO DBLCF-KEY.

           READ DBLCF-FILE INVALID
                MOVE 'A' TO S-PRS-MODE
                INITIALIZE DBLCF-DETAILS
                MOVE SPACE TO DBLCF-OPENAI-FLAG
                              DBLCF-META-FLAG
                              DBLCF-DS-FLAG
                              DBLCF-GM-FLAG
           NOT INVALID
                MOVE 'R' TO S-PRS-MODE.

           PERFORM 0100-MAIN THRU 0199-END UNTIL S-RUN = 'N'.

       TERMINATION.
           CLOSE WINDOW S-WINDOW.
           CLOSE DBLCF-FILE.
           EXIT PROGRAM.
           STOP RUN.

      ****************************************************************
       0100-MAIN.
           PERFORM FKEY-RTN THRU FKEY-END.
           DISPLAY MAIN-SCR.

       0110-MAIN.
           PERFORM ERROR-RTN THRU ERROR-END.
           DISPLAY MAIN-SCR.
           ACCEPT  MAIN-SCR.
           MOVE 4 TO ACCEPT-CONTROL.

           IF K-ESCAPE
              MOVE 'N' TO S-RUN
              GO TO 0199-END.

           IF NOT (K-F8 OR K-ENTER)
              GO TO 0110-MAIN.

      * --- RADIO BUTTON SELECTION VALIDATIONS ---
           IF DBLCF-OPENAI-FLAG NOT = 'Y' AND NOT = 'N'
              MOVE 100040 TO S-ERROR-CODE
              GO TO 0110-MAIN.

           IF DBLCF-META-FLAG NOT = 'Y' AND NOT = 'N'
              MOVE 100040 TO S-ERROR-CODE
              GO TO 0110-MAIN.

           IF DBLCF-DS-FLAG NOT = 'Y' AND NOT = 'N'
              MOVE 100040 TO S-ERROR-CODE
              GO TO 0110-MAIN.

           IF DBLCF-GM-FLAG NOT = 'Y' AND NOT = 'N'
              MOVE 100040 TO S-ERROR-CODE
              GO TO 0110-MAIN.

           PERFORM CONFIRM-RTN THRU CONFIRM-END.
           IF S-CONFIRM NOT = 'Y'
              GO TO 0110-MAIN.

           IF S-PRS-MODE = 'A'
              WRITE DBLCF-REC.

           IF S-PRS-MODE = 'R'
              REWRITE DBLCF-REC.

           MOVE 'N' TO S-RUN.

       0199-END. EXIT.
      ****************************************************************
       FKEY-RTN.
           EVALUATE S-PRS-MODE
            WHEN 'A' MOVE 'yyy4567y9012y4567890' TO S-ACTIVE-FKEY
            WHEN 'R' MOVE 'yyyy567y9012y4567890' TO S-ACTIVE-FKEY
           END-EVALUATE.

           CALL   '/v/cps/lib/std/x-fkey' USING
                  S-ACTIVE-FKEY, S-TOOLBAR, S-BUTTON.
           CANCEL '/v/cps/lib/std/x-fkey'.
           COPY   '/v/cps/lib/std/fmmode.prd'.
       FKEY-END. EXIT.

      ****************************************************************
           COPY '/v/cps/lib/std/cfirm.prd'.
           COPY '/v/cps/lib/std/errmsg.prd'.
