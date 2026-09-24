       IDENTIFICATION DIVISION.
       PROGRAM-ID.    FMDBLAIASK.

      * CHAT WITH AI
      * WITH STRICT UID PARENT-CHILD ACCESS CONTROL VIA FMPXUID2 (PXUID2.DB)
      * AUTHOR        DATE      TYPE   A/C   NOTES
      * SD,AL,SS,YT   15/09/26   -     PAA   SP6AI

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY '/z/sp6ai/v2/lib/fd/fcdblcf'.
           COPY '/z/sp6ai/v2/lib/fd/fcpxuid2'.

           SELECT OPTIONAL SQL-IN-FILE ASSIGN TO WS-SQL-FILE
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-SQL-STATUS.

           SELECT OPTIONAL RES-IN-FILE ASSIGN TO WS-RES-FILE
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-RES-STATUS.

           SELECT OPTIONAL CFG-OUT-FILE ASSIGN TO WS-CFG-FILE
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-CFG-STATUS.

           SELECT OPTIONAL PRT-OUT-FILE ASSIGN TO WS-PRT-FILE
                  ORGANIZATION IS LINE SEQUENTIAL
                  FILE STATUS IS WS-PRT-STATUS.

       DATA DIVISION.
       FILE SECTION.
           COPY '/z/sp6ai/v2/lib/fd/fddblcf'.
           COPY '/z/sp6ai/v2/lib/fd/fdpxuid2'.

       FD  SQL-IN-FILE.
       01  SQL-IN-REC             PIC X(500).

       FD  RES-IN-FILE.
       01  RES-IN-REC             PIC X(200).

       FD  CFG-OUT-FILE.
       01  CFG-OUT-REC            PIC X(800).

       FD  PRT-OUT-FILE.
       01  PRT-OUT-REC            PIC X(200).

       WORKING-STORAGE SECTION.
           COPY '/z/sp6ai/v2/lib/fd/dbdblcf'.
           COPY '/z/sp6ai/v2/lib/fd/dbpxuid2'.
           COPY '/v/cps/lib/std/stdvar.def'.
           COPY '/v/cps/lib/std/fkey.def'.
       77 FIXED-FONT-HANDLE       HANDLE OF FONT.

       01 WS-MISC.
          03 WS-OK                PIC X(01).
          03 WS-STATUS-CODE       PIC X(02)   VALUE '00'.
          03 WS-SQL-STATUS        PIC X(02)   VALUE '00'.
          03 WS-RES-STATUS        PIC X(02)   VALUE '00'.
          03 WS-CFG-STATUS        PIC X(02)   VALUE '00'.
          03 WS-PRT-STATUS        PIC X(02)   VALUE '00'.
          03 WS-AI-ACTIVATED      PIC X(01)   VALUE 'N'.
          03 WS-LEN               PIC 9(04)   VALUE 0.
          03 WS-I                 PIC 9(04)   VALUE 0.
          03 WS-ALLOWED-COUNT     PIC 9(04)   VALUE 0.
          03 WS-ALLOWED-STDS      PIC X(500)  VALUE SPACES.

       01 WS-ACTIVE-CFG.
          03 WS-ACT-PROVIDER      PIC X(20)   VALUE SPACES.
          03 WS-ACT-KEY           PIC X(200)  VALUE SPACES.
          03 WS-ACT-MODEL         PIC X(100)  VALUE SPACES.
          03 WS-ACT-URL           PIC X(100)  VALUE SPACES.

      * Fields matching exact screenshot
       01 WS-USER-ID              PIC X(10)    VALUE SPACES.
       01 WS-STATUS-MSG           PIC X(60)    VALUE 'OK'.
       01 WS-PROMPT-TEXT          PIC X(500)   VALUE SPACES.
       01 WS-SQL-QUERY            PIC X(500)   VALUE SPACES.
       01 WS-QUERY-RESULTS        PIC X(9900)  VALUE SPACES.

       01 WS-CMD                  PIC X(800)   VALUE SPACES.
       01 WS-SQL-FILE             PIC X(100)
          VALUE '/z/sp6ai/v2/temp/ai_sql.txt'.
       01 WS-RES-FILE             PIC X(100)
          VALUE '/z/sp6ai/v2/temp/ai_res.txt'.
       01 WS-CFG-FILE             PIC X(100)
          VALUE '/z/sp6ai/v2/temp/ai_cfg.txt'.
       01 WS-PRT-FILE             PIC X(100)
          VALUE '/z/sp6ai/v2/temp/ai_print.txt'.
       01 WS-PTR                  PIC 9(05)    VALUE 1.

       LINKAGE SECTION.
       01 LINK-PROG-KEY           PIC X(30).

       SCREEN SECTION.
       01 MAIN-SCR.
      * --- 1. ENTER USER ID (UID) ---
          03 LABEL LINE 01.8 COL 04 'Enter User ID (UID):'
             BOLD.
          03 ENTRY-FIELD 3-D ID 100 COL 20 LINE 1.8
             SIZE 10 UPPER
             USING WS-USER-ID.

      * --- 2. ASK A QUESTION ---
          03 LABEL LINE 03.0 COL 04 'Ask a question:'
             BOLD.
          03 ENTRY-FIELD 3-D ID 101 COL 04 LINE 4.0
             LINES 3.3 SIZE 88 MULTILINE
             USING WS-PROMPT-TEXT.

      * --- 3. THREE STACKED BUTTONS: ASK, CLEAR, PRINT ---
          03 PUSH-BUTTON 'Ask' ID 102 COL 94.5 LINE 4.0
             LINES 1.1 SIZE 14 EXCEPTION-VALUE 13.
          03 PUSH-BUTTON 'Clear' ID 103 COL 94.5 LINE 5.1
             LINES 1.1 SIZE 14 EXCEPTION-VALUE 1.
          03 PUSH-BUTTON 'Print' ID 104 COL 94.5 LINE 6.2
             LINES 1.1 SIZE 14 EXCEPTION-VALUE 6.

      * --- 4. STATUS ---
          03 LABEL LINE 7.6 COL 04 'Status:'
             BOLD.
          03 ENTRY-FIELD 3-D ID 105 COL 12 LINE 7.6
             LINES 1.0 SIZE 96 READ-ONLY
             USING WS-STATUS-MSG.

      * --- 5. ANSWER ---
          03 LABEL LINE 9.0 COL 04 'Answer:'
             BOLD.
          03 ENTRY-FIELD 3-D ID 106 COL 04 LINE 10.0
             LINES 19.0 SIZE 103 MULTILINE READ-ONLY
             VSCROLL-BAR NO-WRAP
             FONT IS FIXED-FONT-HANDLE
             USING WS-QUERY-RESULTS.

      * --- 6. SQL USED ---
          03 LABEL LINE 21.5 COL 04 'SQL used:'
             BOLD.
          03 ENTRY-FIELD 3-D ID 107 COL 04 LINE 22.5
             LINES 4.2 SIZE 104 MULTILINE
             USING WS-SQL-QUERY.

      ****************************************************************
       PROCEDURE DIVISION USING LINK-PROG-KEY.

        DECLARATIVES.
           COPY '/z/sp6ai/v2/lib/fd/dcdblcf'.
           COPY '/z/sp6ai/v2/lib/fd/dcpxuid2'.
        END DECLARATIVES.

      ****************************************************************
       BEGIN.
          ACCEPT FIXED-FONT-HANDLE FROM STANDARD OBJECT "FONT".
          SET FIXED-FONT-HANDLE TO "Courier New,10".
          MOVE 'N' TO S-RUN.
          MOVE 'Chat with AI' TO S-WINDOW-TITLE.

      * Floating Window with exact dimensions
          DISPLAY FLOATING WINDOW
             LINES 25 SIZE 112 CELL SIZE = ENTRY-FIELD FONT SEPARATE
             TITLE-BAR MODAL NO SCROLL NO WRAP NO-CLOSE
             TITLE S-WINDOW-TITLE
             POP-UP S-WINDOW.
          DISPLAY TOOL-BAR, LINES 2.8 HANDLE S-TOOLBAR.
          DISPLAY FRAME AT 0102 LINES 24.7 CELL SIZE 110 RAISED.

          MOVE 'Y' TO S-RUN.

          PERFORM 0100-MAIN THRU 0199-END UNTIL S-RUN = 'N'.

       TERMINATION.
          CLOSE WINDOW S-WINDOW.
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

      * 1. Esc - Exit
          IF K-ESCAPE OR KEY-STATUS = 27
             MOVE 'N' TO S-RUN
             GO TO 0199-END.

      * 2. Clear button (ID 103) or F1
          IF KEY-STATUS = 1 OR KEY-STATUS = 103 OR K-F1
             PERFORM 1000-CLEAR-FIELDS THRU 1000-CLEAR-END
             GO TO 0110-MAIN.

      * 3. Ask button (ID 102) or Enter / Return
          IF KEY-STATUS = 13 OR KEY-STATUS = 102 OR K-ENTER
             IF WS-PROMPT-TEXT NOT = SPACES
                MOVE 'Executing...' TO WS-STATUS-MSG
                DISPLAY MAIN-SCR
                PERFORM 2000-PROCESS-AI-QUERY THRU 2099-EXIT
                IF WS-STATUS-MSG = 'Executing...'
                   MOVE 'OK' TO WS-STATUS-MSG
                END-IF
                DISPLAY MAIN-SCR
             ELSE
                MOVE 'Please enter a question.' TO WS-STATUS-MSG
                DISPLAY MAIN-SCR
             END-IF
             GO TO 0110-MAIN.

      * 4. Print button (ID 104) or F6
          IF KEY-STATUS = 6 OR KEY-STATUS = 104 OR K-F6
             PERFORM 3000-PRINT-RESULTS THRU 3000-PRINT-END
             GO TO 0110-MAIN.

          GO TO 0110-MAIN.

       0199-END. EXIT.

      ****************************************************************
       FKEY-RTN.
      * Only activate Exit (Esc) and F1 (Clear)
          MOVE 'y00000000000y0000000' TO S-ACTIVE-FKEY.
          CALL   '/v/cps/lib/std/x-fkey' USING
                 S-ACTIVE-FKEY, S-TOOLBAR, S-BUTTON.
          CANCEL '/v/cps/lib/std/x-fkey'.
       FKEY-END. EXIT.

      ****************************************************************
       1000-CLEAR-FIELDS.
          MOVE SPACES TO WS-PROMPT-TEXT.
          MOVE SPACES TO WS-SQL-QUERY.
          MOVE SPACES TO WS-QUERY-RESULTS.
          MOVE 'OK'   TO WS-STATUS-MSG.
          DISPLAY MAIN-SCR.
          MOVE 101 TO ACCEPT-CONTROL.
       1000-CLEAR-END. EXIT.

      ****************************************************************
       2000-PROCESS-AI-QUERY.
      * 1. Check User ID and Enforce FMPXUID2 Parent-Child Security
          MOVE SPACES TO WS-ALLOWED-STDS.
          MOVE 0 TO WS-ALLOWED-COUNT.
          MOVE 1 TO WS-PTR.

      * If User ID is BLANK or ADMIN/ROOT/SYS/SUPER, allow ALL data access
          IF WS-USER-ID = SPACES
             OR WS-USER-ID = 'ADMIN' OR WS-USER-ID = 'ROOT'
             OR WS-USER-ID = 'SYS'   OR WS-USER-ID = 'SUPER'
             MOVE 'ALL' TO WS-ALLOWED-STDS
             MOVE 999   TO WS-ALLOWED-COUNT
          ELSE
             OPEN INPUT PXUID2-FILE
             IF PX-UID2-STATUS = '00'
                INITIALIZE PX-UID2-KEY
                MOVE WS-USER-ID TO PX-UID2-UID-KEY
                START PXUID2-FILE KEY >= PX-UID2-KEY
                   INVALID
                      CONTINUE
                   NOT INVALID
                      PERFORM UNTIL 1 = 2
                         READ PXUID2-FILE NEXT
                            AT END EXIT PERFORM
                         END-READ
                         IF PX-UID2-UID-KEY NOT = WS-USER-ID
                            EXIT PERFORM
                         END-IF
                         IF PX-UID2-STD-KEY NOT = SPACES
                            ADD 1 TO WS-ALLOWED-COUNT
                            IF WS-ALLOWED-COUNT = 1
                               STRING "'" DELIMITED SIZE
                                      PX-UID2-STD-KEY
                                         DELIMITED BY SPACE
                                      "'" DELIMITED SIZE
                                  INTO WS-ALLOWED-STDS
                                  WITH POINTER WS-PTR
                            ELSE
                               STRING ", '" DELIMITED SIZE
                                      PX-UID2-STD-KEY
                                         DELIMITED BY SPACE
                                      "'" DELIMITED SIZE
                                  INTO WS-ALLOWED-STDS
                                  WITH POINTER WS-PTR
                            END-IF
                         END-IF
                      END-PERFORM
                END-START
                CLOSE PXUID2-FILE
             END-IF

      * If a UID was provided but no linked children were found in FMPXUID2, reject
             IF WS-ALLOWED-COUNT = 0
                MOVE SPACES TO WS-SQL-QUERY
                MOVE 'Access Denied: No children linked to UID.'
                   TO WS-STATUS-MSG
                STRING 'ERROR: User ID [' WS-USER-ID '] has no '
                       'authorized children/students assigned in '
                       'FMPXUID2.'
                  INTO WS-QUERY-RESULTS
                DISPLAY MAIN-SCR
                GO TO 2099-EXIT
             END-IF
          END-IF.


      * If no authorized children found for this UID, block query!
          IF WS-ALLOWED-COUNT = 0
             MOVE SPACES TO WS-SQL-QUERY
             MOVE 'Access Denied: No children linked to UID.'
                  TO WS-STATUS-MSG
             STRING 'ERROR: User ID [' WS-USER-ID '] has no '
                    'authorized children/students assigned in '
                    'FMPXUID2.'
               INTO WS-QUERY-RESULTS
             DISPLAY MAIN-SCR
             GO TO 2099-EXIT
          END-IF.

      * 2. Check DBLCF-FILE for active AI provider
          MOVE 'N' TO WS-AI-ACTIVATED.
          MOVE SPACES TO WS-ACT-PROVIDER, WS-ACT-KEY,
                         WS-ACT-MODEL, WS-ACT-URL.

          OPEN INPUT DBLCF-FILE.
          IF DBLCF-STATUS = '00'
             MOVE '1' TO DBLCF-KEY
             READ DBLCF-FILE INVALID
                  CONTINUE
             NOT INVALID
                  EVALUATE TRUE
                     WHEN DBLCF-GM-FLAG = 'Y'
                          MOVE 'Y' TO WS-AI-ACTIVATED
                          MOVE 'gemini' TO WS-ACT-PROVIDER
                          MOVE DBLCF-GM-API-KEY TO WS-ACT-KEY
                          MOVE DBLCF-GM-API-MODEL TO WS-ACT-MODEL
                          MOVE DBLCF-GM-API-LINK TO WS-ACT-URL
                     WHEN DBLCF-META-FLAG = 'Y'
                          MOVE 'Y' TO WS-AI-ACTIVATED
                          MOVE 'meta' TO WS-ACT-PROVIDER
                          MOVE DBLCF-META-API-KEY TO WS-ACT-KEY
                          MOVE DBLCF-META-API-MODEL TO WS-ACT-MODEL
                          MOVE DBLCF-META-API-LINK TO WS-ACT-URL
                     WHEN DBLCF-DS-FLAG = 'Y'
                          MOVE 'Y' TO WS-AI-ACTIVATED
                          MOVE 'deepseek' TO WS-ACT-PROVIDER
                          MOVE DBLCF-DS-API-KEY TO WS-ACT-KEY
                          MOVE DBLCF-DS-API-MODEL TO WS-ACT-MODEL
                          MOVE DBLCF-DS-API-LINK TO WS-ACT-URL
                     WHEN DBLCF-OPENAI-FLAG = 'Y'
                          MOVE 'Y' TO WS-AI-ACTIVATED
                          MOVE 'openai' TO WS-ACT-PROVIDER
                          MOVE DBLCF-OPENAI-API-KEY TO WS-ACT-KEY
                          MOVE DBLCF-OPENAI-API-MODEL TO WS-ACT-MODEL
                          MOVE DBLCF-OPENAI-API-LINK TO WS-ACT-URL
                  END-EVALUATE
             END-READ
             CLOSE DBLCF-FILE
          END-IF.

      * 3. If NO AI is activated in FMDBLCF, reject immediately!
          IF WS-AI-ACTIVATED NOT = 'Y'
             MOVE SPACES TO WS-SQL-QUERY
             MOVE 'ERROR: No AI engine activated in FMDBLCF.'
                  TO WS-STATUS-MSG
             MOVE 'Please activate an AI engine in FMDBLCF.'
                  TO WS-QUERY-RESULTS
             DISPLAY MAIN-SCR
             GO TO 2099-EXIT
          END-IF.

      * 4. Write active AI config file including ALLOWED_STDS for AiBridge
          DISPLAY 'WS-CFG-FILE=[' WS-CFG-FILE ']'.
          OPEN OUTPUT CFG-OUT-FILE.
          IF WS-CFG-STATUS = '00'
             INITIALIZE CFG-OUT-REC
             STRING WS-ACT-PROVIDER DELIMITED BY SPACE
                    '|' DELIMITED BY SIZE
                    WS-ACT-KEY DELIMITED BY SPACE
                    '|' DELIMITED BY SIZE
                    WS-ACT-MODEL DELIMITED BY SPACE
                    '|' DELIMITED BY SIZE
                    WS-ACT-URL DELIMITED BY SPACE
                    '|' DELIMITED BY SIZE
                    WS-ALLOWED-STDS DELIMITED BY '  '
               INTO CFG-OUT-REC
             WRITE CFG-OUT-REC
             CLOSE CFG-OUT-FILE
          END-IF.

      * 5. Build command to run AiBridge with active config
          INITIALIZE WS-CMD.
          STRING 'cd /z/sp6ai/v2/prg && ' DELIMITED SIZE
                 'java -cp .:' DELIMITED SIZE
                 '/opt/c-treeRTG_v3.0.2/drivers/sql.jdbc/ctreeJDBC.jar'
                 DELIMITED SIZE
                 ' AiBridge "' DELIMITED SIZE
                 WS-PROMPT-TEXT DELIMITED BY '  '
                 '" ' DELIMITED SIZE
                 WS-SQL-FILE DELIMITED SPACE
                 ' ' DELIMITED SIZE
                 WS-RES-FILE DELIMITED SPACE
                 ' ' DELIMITED SIZE
                 WS-CFG-FILE DELIMITED SPACE
            INTO WS-CMD.

          CALL 'C$SYSTEM' USING WS-CMD, 2.

      * 6. Read Generated SQL
          MOVE SPACES TO WS-SQL-QUERY.
          OPEN INPUT SQL-IN-FILE.
          IF WS-SQL-STATUS = '00'
             READ SQL-IN-FILE
      /AT END CONTINUE
                  NOT AT END MOVE SQL-IN-REC TO WS-SQL-QUERY
             END-READ
             CLOSE SQL-IN-FILE
          END-IF.

      * 7. Read Query Results (Preserve entire line with spaces & numbers)
          MOVE SPACES TO WS-QUERY-RESULTS.
          MOVE 1 TO WS-PTR.
          OPEN INPUT RES-IN-FILE.
          IF WS-RES-STATUS = '00'
             PERFORM UNTIL WS-RES-STATUS NOT = '00' OR WS-PTR > 9700
                READ RES-IN-FILE
                   AT END
                      MOVE '10' TO WS-RES-STATUS
                   NOT AT END
                      PERFORM VARYING WS-I FROM 200 BY -1
                         UNTIL WS-I = 0
                            OR RES-IN-REC(WS-I:1) NOT = SPACE
                      END-PERFORM
                      MOVE WS-I TO WS-LEN
                      IF WS-LEN = 0
                         STRING x'0A' DELIMITED BY SIZE
                           INTO WS-QUERY-RESULTS
                           WITH POINTER WS-PTR
                      ELSE
                         STRING RES-IN-REC(1:WS-LEN) DELIMITED BY SIZE
                                x'0A' DELIMITED BY SIZE
                           INTO WS-QUERY-RESULTS
                           WITH POINTER WS-PTR
                      END-IF
                END-READ
             END-PERFORM
             CLOSE RES-IN-FILE
          ELSE
             MOVE 'No response received from AI engine.'
                  TO WS-QUERY-RESULTS
          END-IF.

       2099-EXIT. EXIT.

      ****************************************************************
       3000-PRINT-RESULTS.
      * Write current results to print file
          OPEN OUTPUT PRT-OUT-FILE.
          IF WS-PRT-STATUS = '00'
             WRITE PRT-OUT-REC FROM '=== CHAT WITH AI REPORT ==='
             WRITE PRT-OUT-REC FROM ' '
             STRING 'USER ID: ' WS-USER-ID INTO PRT-OUT-REC
             WRITE PRT-OUT-REC
             WRITE PRT-OUT-REC FROM ' '
             WRITE PRT-OUT-REC FROM 'QUESTION:'
             WRITE PRT-OUT-REC FROM WS-PROMPT-TEXT
             WRITE PRT-OUT-REC FROM ' '
             WRITE PRT-OUT-REC FROM 'SQL USED:'
             WRITE PRT-OUT-REC FROM WS-SQL-QUERY
             WRITE PRT-OUT-REC FROM ' '
             WRITE PRT-OUT-REC FROM 'ANSWER:'
             WRITE PRT-OUT-REC FROM WS-QUERY-RESULTS
             CLOSE PRT-OUT-FILE
             MOVE 'Printed to ai_print.txt' TO WS-STATUS-MSG
          ELSE
             MOVE 'Print failed.' TO WS-STATUS-MSG
          END-IF.
          DISPLAY MAIN-SCR.
       3000-PRINT-END. EXIT.

      ****************************************************************
          COPY '/v/cps/lib/std/cfirm.prd'.
          COPY '/z/sp6ai/v2/lib/std/errmsg.prd'.

