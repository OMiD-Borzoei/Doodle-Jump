.MODEL MEDIUM
.STACK 128

.DATA
    SCORE_COLOR             DB 13   ; L_MAGNETA
    BACKGROUND_COLOR        DB 15   ; WHITE
    BALL_COLOR              DB 9    ; L_BLUE
    STEP_COLOR              DB 10   ; L_GREEN
    SPRING_COLOR            DB 232    ; BLACK
    BROKEN_COLOR            DB 6    ; BROWN
    MONSTER_COLOR           DB 41   ; L_RED     
    
    BALL_X                  DW ?
    BALL_Y                  DW ?
    BALL_SIZE               DW 13   
    BALL_VELOCITY_X         DW 12
    BALL_VELOCITY_Y         DW 6

    MONSTER_X               DW ?
    MONSTER_Y               DW ?
    MONSTER_SIZE_X          DW 30 
    MONSTER_SIZE_Y          DW 35    
    MONSTER_SPEED           DW 2    ; Only Moves In X Axis

    STEP_SIZE_X             DW 60
    STEP_SIZE_Y             DW 7  
    SCROLL_STEPS            DW 1    ; steps shown in each scroll
    FIRST_STEPS             DW 6    ; Steps shown in the beginning
    STEPS_TO_DRAW           DW ?

    BREAK_POINT             DW ?
    BREAK_SLOPE             DW 3    
    BREAK_WIDTH             DW 14

    SPRING_SIZE_X           DW 10
    SPRING_SIZE_Y           DW 12
    SPRING_BREAK_SIZE       DW  2
    SPRING_BREAK_POINT      DW  ?

    MIN_GENERATED_Y         DW 50   ; minimum height of the generated things
    MAX_GENERATED_Y         DW ?    ; maximum ...
    MAX_GENERATED_X         DW ?    ; maximum width ...

    WINDOW_WIDTH            DW 320
    WINDOW_HEIGHT           DW 200

    SPRING_JUMP_HEIGHT      DW 45
    JUMP_HEIGHT             DW 15   
    JUMP_HEIGHT_IT          DW ?
    JUMP                    DB 0    ; if = 1, we are moving upwards

    SCORE                   DW ?
    SCORE_POSITION          DW 180

    IS_OVER                 DW ?
    GAME_OVER_MESSAGE       DB 'GAME OVER!$'

    SHOULD_GENERATE         DB 1    ; if = 0, no steps would be generated
    GEN_FREQ                DW 5    ; the higher it gets, the more steps will be generated in scrolling
    SCROLL_LINES            DB 1    ; how many lines will be scrolled each time
    SHOULD_SCROLL           DB 0    ; if = 0, no scrolling would happen
    DONE_SCROLLING          DB 0    ; if = 1, the ball must start falling down
    FIRST_SCROLL            DB 1    ; if = 1, a new step must be generated
    JAYI_KE_QAM_NABASHE     DW 100  ; the height which the ball must reach for us to start scrolling   

    SEED                    DW 812h ; u can set it as literally anything, it will change throughout the code semi-randomly  
    SAVED_BALL_IDX          DW ?    ; base index of the ball array
    SAVED_MONSTER_IDX       DW ?    ; base index of the monster array

    WHEN_DRAW_BROKEN        DW 23   ; Show Broken every 23 Score
    WHEN_DRAW_SPRING        DW 41   ; Show Spring every 41 Score
    WHEN_DRAW_MONSTER       DW 63   ; Show Monster every 57 Score
    
    BROKEN_GENERATED_IN     DW 0    ; saves the score which we generated the broken step in
    SPRING_GENERATED_IN     DW 0    ; ... spring ...
    MONSTER_GENERATED_IN    DW 0    ; ... monster ...
    IS_MONSTER_IN           DB ?    ; if = 1, we need to check for monster collision, also we should move the monster
    NUMBER_TO_SHOW          DW ?    ; For debugging
    
.CODE  
    

    ;   Useful Procedures:

    GET_COLOR PROC FAR      ; AL = OUTPUT, CX = Input Col, DX = Input Row
        MOV AH, 0Dh
        INT 10H
        RET
    GET_COLOR ENDP

    SET_COLOR PROC FAR      ; AL = INPUT, CX = Col, DX = Row
        MOV AH, 0Ch
        MOV BH, 0
        INT 10H        
        RET
    SET_COLOR ENDP
    
    SET_CURSOR PROC FAR     ; DX as Input, DH Row, DL Col
        MOV AH, 2
        MOV BH, 0
        INT 10h
        RET 
    SET_CURSOR ENDP
    
    SHOW_CHAR PROC FAR      ; AL = input Char, CX = Number, Bl = Color
        MOV AH, 9
        MOV BH, 0
        INT 10h
        RET
    SHOW_CHAR ENDP
    
    DELAY PROC FAR
        MOV AH, 2Ch 	;get the system time
    	INT 21h         ;DL = 1/100 seconds
    	MOV BL, DL  			     
        DELAY_LOOP:
            MOV AH, 2Ch     ;get the system time
    	    INT 21h         ;DL = 1/100 seconds  
            CMP DL, BL
            JE DELAY_LOOP   ; Stay here until we move to the next 1/100 seconds     
        RET
    DELAY ENDP    

    CLEAR_SCREEN PROC FAR               
        MOV AH, 6
        MOV AL, 0
        MOV BH, BACKGROUND_COLOR
        MOV CX, 0200h
        MOV DX, 0184Fh 
        INT 10h    					 ;execute the configuration    
        RET    
    CLEAR_SCREEN ENDP    

    GENERATE_RANDOM PROC FAR   ; CX INPUT AND DX OUTPUT, DX = A random number in [0, CX) Interval, AX as 2nd Input
        PUSH CX
        PUSH AX
        MOV AH, 0
        INT 1Ah                 ; CX:DX = NUMBER OF CLOCKS
        POP AX
        MOV CX, 5               ; the loop will run 5 times
        RANDOM_LOOP:            ; this will generate a semi-random number in AX
            MUL DX              ; AX *= DX 
            ADD SEED, AX        ; seed will be updated    
            ADD AX, SEED        ; AX will be updated
            SUB DX, AX          ; DX will be updated
            LOOP RANDOM_LOOP
        XOR DX, DX              ; DX = 0
        POP CX          
        DIV CX                  ; DX = AX % CX
        RET
    GENERATE_RANDOM ENDP

    GENERATE_RANDOM_COORDINATES PROC FAR    ; CX = X, DX = Y, OUTPUT
        MOV CX, MAX_GENERATED_X         
        CALL GENERATE_RANDOM
        PUSH DX                         ; DX = rand(0, MAX_GENERATED_x)   
        MOV CX, MAX_GENERATED_Y         
        SUB CX, MIN_GENERATED_Y
        CALL GENERATE_RANDOM                      
        ADD DX, MIN_GENERATED_Y         ; DX = rand(0, MAX_GENERATED_Y - MIN_GENERATED_Y) + MAX_GENERATED_Y 
        POP CX                          ; CX = rand(0, MAX_GENERATED_X)
        RET
    GENERATE_RANDOM_COORDINATES ENDP 
    
    ITERATE_RECT PROC FAR   ; CX = START_X, BX = SIZE_Y, DX = START_Y, BP = SIZE_X, AL = COLOR, AH = MODE, OUTPUT = AX
        PUSH CX                 ; AH = 0, DRAW A RECT COLORED IN AL
        PUSH DX                 ; AH = 1, SAVE COLOR OF THE RECT IN ES:[SI]
        PUSH BX                 ; AH = 2, LOAD ES:[SI] TO THE RECT COLOR
        PUSH BP                 ; AH = 3, CHANGE COLOR OF PIXELS WITH COLOR AL FROM THIS RECT TO BACKGROUND
        PUSH SI                 ; AH = 4, IF there's any pixel with any color other than background_color in this rectangle return 1, else 0              
        Horizontal:             ; AH = 5, If there's any pixel colored in AL in this rectangle return 1, else 0         
            PUSH BX                         
            PUSH CX             
            PUSH BP            
            Vertical:
                PUSH AX         ; MODE IS SAVED
                CMP AH, 1
                JE GET_RECT
                CMP AH, 0
                JE DRAW_IN_AL
                CMP AH, 2
                JE LOAD_RECT
                CMP AH, 3
                JE MODE3
                CMP AH, 4
                JE MODE4
                MODE5:
                    PUSH AX
                    CALL GET_COLOR
                    POP BX
                    CMP AL, BL
                    JNE UPDATE
                    JMP RETURN_1
                MODE4:
                    MOV AL, BACKGROUND_COLOR
                    PUSH AX
                    CALL GET_COLOR  ; GET COLOR OF PIXEL IN Col CX & Row DX
                    POP BX
                    CMP AL, BL
                    JE UPDATE
                    RETURN_1:    
                        POP AX
                        POP AX
                        POP AX
                        POP AX
                        MOV AX, 1
                        JMP ITERATE_RECT_RET
                MODE3:
                    PUSH AX
                    CALL GET_COLOR  ; GET COLOR OF PIXEL IN Col CX & Row DX
                    POP BX
                    CMP AL, BL
                    JNE UPDATE                
                    MOV AL, BACKGROUND_COLOR
                    CALL SET_COLOR
                    JMP UPDATE 
                LOAD_RECT:    
                    MOV AL, ES:[SI] 
                DRAW_IN_AL:
                    CALL SET_COLOR                
                    JMP UPDATE
                GET_RECT:
                    CALL GET_COLOR
                    MOV ES:[SI], AL
                UPDATE:
                    POP AX          ; MODE IS POPED
                    INC SI
                    INC CX         ; Next Column
                    DEC BP         ; Iterator
                    JNZ Vertical
            POP BP
            POP CX              ; Base Column Is Restored
            POP BX              ; Row Iterator Restored        
            INC DX              ; Next Row  
            DEC BX              
            JNZ Horizontal 
        MOV AX, 0
        ITERATE_RECT_RET: 
            POP SI
            POP BP   
            POP BX
            POP DX
            POP CX
            RET
    ITERATE_RECT ENDP



    ; BackGround Procedures:

    DRAW_STEP PROC FAR           ; CX = NUMBER
        CMP SHOULD_GENERATE, 1   
        JNE DRAW_STEP_RET 
        GENERATE_STEP:         
            PUSH CX
            MOV BX, STEP_SIZE_Y
            MOV BP, STEP_SIZE_X
            GENERATE_COORD:
                CALL GENERATE_RANDOM_COORDINATES      
                CALL CHECK_EXISTS               ; check if anything already exists in those coordinates
                CMP AX, 1
                JE GENERATE_COORD               ; if exists, generated another random coordinates
            MOV AL, STEP_COLOR
            MOV AH, 0
            CALL ITERATE_RECT                     
            POP CX
            LOOP GENERATE_STEP    
        DRAW_STEP_RET:
            MOV SHOULD_GENERATE, 0
            RET   
    DRAW_STEP ENDP

    DRAW_BROKEN_STEP PROC FAR   ; CX = NUMBER
        MOV BX, STEP_SIZE_Y
        MOV BP, STEP_SIZE_X        
        GEN_COORD:
            CALL GENERATE_RANDOM_COORDINATES
            CALL CHECK_EXISTS
            CMP AX, 1
            JE GEN_COORD
        MOV AL, BROKEN_COLOR
        MOV AH, 0
        CALL ITERATE_RECT
        ADD CX, BREAK_POINT
        MOV BX, STEP_SIZE_Y
        DIAGONAL_LOOP:
            PUSH BX    
            PUSH CX
            MOV BX, BREAK_WIDTH
            DIAG2:
                PUSH BX
                MOV AL, BACKGROUND_COLOR 
                CALL SET_COLOR
                INC CX
                POP BX
                DEC BX
                JNZ DIAG2
            INC DX
            POP CX
            ADD CX, BREAK_SLOPE
            POP BX
            DEC BX
            JNZ DIAGONAL_LOOP    
        RET
    DRAW_BROKEN_STEP ENDP

    REMOVE_BROKEN_STEP PROC FAR
        MOV CX, BALL_X                 
        SUB CX, STEP_SIZE_X     
        SUB CX, BALL_SIZE       ; START_X = BALL_X - STEP_SIZE_X - BALL_SIZE 
        MOV DX, BALL_Y          ; START_Y = BALL_Y
        MOV BX, STEP_SIZE_Y
        SHL BX, 1
        SHL BX, 1               ; SIZE_Y = STEP_SIZE_Y * 4
        MOV BP, STEP_SIZE_X
        ADD BP, STEP_SIZE_X
        ADD BP, STEP_SIZE_X     ; SIZE_X = STEP_SIZE_X * 3
        MOV AL, BROKEN_COLOR
        MOV AH, 3
        CALL ITERATE_RECT 
        RET
    REMOVE_BROKEN_STEP ENDP

    DRAW_SPRING PROC FAR
        MOV BX, STEP_SIZE_Y
        ADD BX, SPRING_SIZE_Y
        MOV BP, STEP_SIZE_X
        GEN_COORDINATES:        ; Does not Work Correctly Yet
            CALL GENERATE_RANDOM_COORDINATES
            CALL CHECK_EXISTS
            CMP AX, 1
            JE GEN_COORDINATES
        MOV BX, SPRING_SIZE_Y
        MOV BP, SPRING_BREAK_POINT
        MOV AL, SPRING_COLOR
        MOV AH, 0
        CALL ITERATE_RECT
        PUSH DX
        PUSH CX
        ADD CX, SPRING_BREAK_POINT
        ADD CX, SPRING_BREAK_SIZE
        MOV BX, SPRING_SIZE_Y
        MOV BP, SPRING_SIZE_X
        SUB BP, SPRING_BREAK_POINT
        SUB BP, SPRING_BREAK_SIZE
        MOV AL, SPRING_COLOR
        MOV AH, 0
        CALL ITERATE_RECT
        MOV CX, STEP_SIZE_X
        SUB CX, SPRING_SIZE_X
        CALL GENERATE_RANDOM
        POP CX
        SUB CX, DX    
        POP DX
        ADD DX, SPRING_SIZE_Y
        MOV BX, STEP_SIZE_Y
        MOV BP, STEP_SIZE_X
        MOV AL, STEP_COLOR
        MOV AH, 0
        CALL ITERATE_RECT
        RET
    DRAW_SPRING ENDP

    DRAW_MONSTER PROC FAR   ; AX = 0 generate, else draw
        CMP AX, 0
        JNE SAVE_PIXELS
            MOV IS_MONSTER_IN, 1
            NEG MONSTER_SPEED
            CALL GENERATE_RANDOM_COORDINATES
            MOV MONSTER_X, CX
            MOV MONSTER_Y, DX
        SAVE_PIXELS:
            MOV CX, MONSTER_X
            MOV DX, MONSTER_Y
            MOV BX, MONSTER_SIZE_Y
            MOV BP, MONSTER_SIZE_X
            MOV AH, 1
            MOV SI, SAVED_MONSTER_IDX
            CALL ITERATE_RECT        
        MOV AL, MONSTER_COLOR
        MOV AH, 0
        CALL ITERATE_RECT       
        RET
    DRAW_MONSTER ENDP

    REMOVE_MONSTER PROC FAR
        MOV CX, MONSTER_X
        MOV DX, MONSTER_Y
        MOV BX, MONSTER_SIZE_Y
        MOV BP, MONSTER_SIZE_X
        MOV AH, 2
        MOV SI, SAVED_MONSTER_IDX
        CALL ITERATE_RECT
        RET
    REMOVE_MONSTER ENDP 

    DRAW_ADDITIONALS PROC FAR
        MOV AX, SCORE
        CMP AX, 0
        JE ADDITIONALS_RET
        MOV DX, 0
        DIV WHEN_DRAW_BROKEN
        CMP DX, 0
        JNE CHECK_SPRING
        DRAW_BROKEN:
                MOV AX, SCORE
                CMP AX, BROKEN_GENERATED_IN                
                JE CHECK_SPRING
                    MOV BROKEN_GENERATED_IN, AX
                    CALL DRAW_BROKEN_STEP
        CHECK_SPRING:
        MOV AX, SCORE
        MOV DX, 0
        DIV WHEN_DRAW_SPRING
        CMP DX, 0
        JNE CHECK_MONSTER
            MOV AX, SCORE
            CMP AX, SPRING_GENERATED_IN
            JE CHECK_MONSTER
                MOV SPRING_GENERATED_IN, AX
                CALL DRAW_SPRING
        CHECK_MONSTER:
        MOV AX, SCORE
        MOV DX, 0
        DIV WHEN_DRAW_MONSTER
        CMP DX, 0
        JNE ADDITIONALS_RET            
            MOV AX, SCORE
            CMP AX, MONSTER_GENERATED_IN
            JE ADDITIONALS_RET
                MOV MONSTER_GENERATED_IN, AX
                MOV AX, 0
                CALL DRAW_MONSTER
        ADDITIONALS_RET:
            CMP IS_MONSTER_IN, 1
            JNE SERIOUSLY_RET
                CALL REMOVE_MONSTER
                MOV AX, MONSTER_SPEED
                ADD MONSTER_X, AX       ; Moving The Monster  
                CALL DRAW_MONSTER  ; ==>  For Non_Step_Eater Monsters
            SERIOUSLY_RET:
                RET    
    DRAW_ADDITIONALS ENDP

    CHECK_EXISTS PROC FAR
        PUSH CX
        PUSH DX
        PUSH BX
        PUSH BP
        MOV AH, 4
        CALL ITERATE_RECT        
        POP BP
        POP BX
        POP DX
        POP CX
        RET 
    CHECK_EXISTS ENDP



    ; Ball Procedures:

    MOVE_BALL PROC FAR
        CHECK_KEY_STROKE:
            MOV AH, 1
            INT 16h                 ; Check If KeyBoard Buffer Is Empty
            JZ CHECK_INPUT          ; Jmp if Buffer Is Empty
            MOV AH, 0       
            INT 16h                 ; AL = Read Keyboard Buffer    
            JMP CHECK_KEY_STROKE    ; Repeat Till Buffer is empty
        CHECK_INPUT:
            MOV BX, BALL_VELOCITY_X
            CMP AL, 74       ;J
            JE MOVE_LEFT
            CMP AL, 106      ;j
            JE MOVE_LEFT
            CMP AL, 75       ;K
            JE MOVE_RIGHT
            CMP AL, 107      ;k
            JE MOVE_RIGHT
            JMP DECIDE_UP_OR_DOWN

        MOVE_LEFT:
            NEG BX          ; Ball_velocity_x = - Ball_velocity_x
        MOVE_RIGHT:         
            ADD BALL_X, BX  ; Ball_x += Ball_velocity_x

        DECIDE_UP_OR_DOWN:

        CMP JUMP, 1        
        JNE ORDINARY        ; If Jump = 0, Ball Must Fall Down  

            MOV AX, BALL_Y
            MOV DX, 0
            MOV BX, WINDOW_HEIGHT
            DIV BX                  ; DX now holds actual height
            CMP DX, JAYI_KE_QAM_NABASHE

            JGE NO_SCROLLING            ; If We Reached Jayi_ke_qam_nabashe, we need to scroll screen
                CMP DONE_SCROLLING, 1   
                JNE START_SCROLL
                    MOV JUMP, 0             ; Stop Jump
                    NEG BALL_VELOCITY_Y
                    MOV SHOULD_SCROLL, 0    ; if scrolling is over
                    MOV DONE_SCROLLING, 0
                    MOV FIRST_SCROLL, 1
                    JMP ORDINARY

                START_SCROLL:
                    MOV SHOULD_SCROLL, 1 
                    CMP FIRST_SCROLL, 1     ; If we've already started 
                    JNE GEN       ; scrolling procedure we don't need to do anything here
                        MOV SHOULD_GENERATE, 1  
                        MOV FIRST_SCROLL, 0
                        SHR JUMP_HEIGHT_IT, 1
                        CMP JUMP_HEIGHT_IT, 2       
                        JGE CHECK_MONSTER       
                            MOV SHOULD_GENERATE, 0                    
                        JMP CHECK_MONSTER 

                    GEN:
                        MOV AX, JUMP_HEIGHT_IT
                        CMP AX, 0
                        JE CHECK_MONSTER 
                        MOV DX, 0
                        MOV BX, GEN_FREQ
                        DIV BX
                        CMP DX, 0
                        JNE CHECK_MONSTER 
                            MOV SHOULD_GENERATE, 1
                        JMP CHECK_MONSTER    


            NO_SCROLLING:
                DEC JUMP_HEIGHT_IT  ; JUMP TO A CERTAIN POINT
                JNZ ORDINARY
                MOV JUMP, 0         ; Stop Jump
                NEG BALL_VELOCITY_Y 

        
        ORDINARY: 
            MOV AX, BALL_VELOCITY_Y
            ADD BALL_Y, AX          ; MOVE BALL ON Y-AXIS  
            CMP JUMP, 1
            JE CHECK_MONSTER

        CALL CHECK_COLLISION
        CMP AL, STEP_COLOR
        JNE CHECK_SPRING 
            MOV AX, JUMP_HEIGHT
            MOV JUMP_HEIGHT_IT, AX
            MOV JUMP, 1             ; Start Jump
            NEG BALL_VELOCITY_Y
                    
        CHECK_SPRING:
        CMP AL, SPRING_COLOR
        JNE CHECK_BROKEN                
            MOV AX, SPRING_JUMP_HEIGHT
            MOV JUMP_HEIGHT_IT, AX
            MOV JUMP, 1             ; Start Jump
            NEG BALL_VELOCITY_Y

        CHECK_BROKEN:
        CMP AL, BROKEN_COLOR
        JNE CHECK_MONSTER
            CALL REMOVE_BROKEN_STEP
        
        CHECK_MONSTER:
            CMP IS_MONSTER_IN, 1
            JNE CHECK_BOUNDARY        
                MOV CX, BALL_X
                MOV DX, BALL_Y
                MOV BX, BALL_SIZE
                SUB CX, BX
                SUB DX, BX
                SHL BX, 1
                MOV BP, BX
                MOV AL, MONSTER_COLOR
                MOV AH, 5
                CALL ITERATE_RECT
                CMP AL, 1
                JNE CHECK_BOUNDARY
                    MOV IS_OVER, 1

        CHECK_BOUNDARY:
            MOV BX, BALL_SIZE
            ADD BX, BALL_Y
            CMP BX, WINDOW_HEIGHT
            JL RET_MOVE_BALL
                MOV IS_OVER, 1

        RET_MOVE_BALL:
            RET
    MOVE_BALL ENDP

    DRAW_BALL PROC FAR
        MOV CX, BALL_X
        MOV DX, BALL_Y
        MOV BX, BALL_SIZE
        SUB CX, BX
        SUB DX, BX
        SHL BX, 1
        MOV BP, BX
        MOV AL, BALL_COLOR
        MOV AH, 1
        MOV SI, SAVED_BALL_IDX
        CALL ITERATE_RECT 

        MOV BX, BALL_SIZE
        MOV CX, BALL_X
        MOV DX, BALL_Y
        FILL_CIRCLE:
            CALL DRAW_CIRCLE
            DEC BX
            CMP BX, 5
            JGE FILL_CIRCLE
             
        RET
    DRAW_BALL ENDP

    REMOVE_BALL PROC FAR
        MOV CX, BALL_X
        MOV DX, BALL_Y
        MOV BX, BALL_SIZE
        SUB CX, BX
        SUB DX, BX
        SHL BX, 1
        MOV BP, BX
        MOV AH, 2
        MOV SI, SAVED_BALL_IDX
        CALL ITERATE_RECT
        RET
    REMOVE_BALL ENDP
    
    CHECK_COLLISION PROC FAR               
        MOV CX, BALL_X
        MOV COMPARATOR, CX
        MOV AX, BALL_SIZE
        SUB COMPARATOR, AX
        ADD CX, AX
        MOV DX, BALL_Y 
        
        ADD DX, BALL_SIZE
        LAST_ROW_LOOP:
            CALL GET_COLOR
            CMP AL, BACKGROUND_COLOR
            JNE CHECK_COLLISION_RET
            DEC CX
            CMP CX, COMPARATOR
            JGE LAST_ROW_LOOP
        CHECK_COLLISION_RET:
            RET    
        COMPARATOR DW ?    
    CHECK_COLLISION ENDP

    DRAW_CIRCLE PROC FAR  ; CX = Col, DX = row, BX = Radius, AX = OUTPUT
        PUSH BX
        PUSH CX
        PUSH DX

        MOV AX, BX
        SHL AX, 1
        NEG AX
        ADD AX, 3
        MOV D, AX   ; D = 3 - (2 * r)
        
        DEC BX      
        MOV AX, 0   ; x = 0
        _WHILE:
            CALL PUT_8_PIXELS
            CMP BX, AX
            JL DRAW_CIRCLE_RET  ; If y < x Then End While
                INC AX          ; x++
                CMP D, 0        
                JLE _ELSE
                _IF:            ; If d > 0 ==>
                    DEC BX      ; y--
                    MOV DI, AX
                    SUB DI, BX  ; DI = X - Y
                    SHL DI, 1   ; DI *= 2
                    SHL DI, 1   ; DI *= 2
                    ADD DI, 10  
                    ADD D, DI   ; D += 4*(X-Y)+10
                    JMP _WHILE
                _ELSE:
                    MOV DI, AX
                    SHL DI, 1
                    SHL DI, 1
                    ADD DI, 6
                    ADD D, DI
                    JMP _WHILE
        DRAW_CIRCLE_RET:
            POP DX
            POP CX
            POP BX
            RET
        D DW ?
    DRAW_CIRCLE ENDP
    
    PUT_8_PIXELS PROC FAR ; CX = xc, DX = yc, AX = x, BX = y
        PUSH AX
        PUSH BX
        PUSH DX
        PUSH CX
        MOV x, AX
        MOV y, BX
        MOV AL, BALL_COLOR
        MOV AH, 0Ch
        MOV BH, 0
        
        ADD DX, y
        ADD CX, x
        PUSH CX
        INT 10H  ; xc+x, yc+y
        SUB CX, x
        SUB CX, x
        INT 10H  ; xc-x, yc+y
        SUB DX, y
        SUB DX, y
        INT 10H  ; xc-x, yc-y
        POP CX
        INT 10H  ; xc+x, yc-y
    
        SUB CX, x 
        ADD CX, y 
        ADD DX, y 
        ADD DX, x
        PUSH CX
        INT 10H  ; xc+y, yc+x
        SUB CX, y 
        SUB CX, y
        INT 10H  ; xc-y, yc+x
        SUB DX, x 
        SUB DX, x
        INT 10H  ; xc-y, yc-x
        POP CX
        INT 10H  ; xc+y, yc-x
        
        POP CX
        POP DX
        POP BX
        POP AX
        RET
        x DW ?
        y DW ? 
    PUT_8_PIXELS ENDP    
     


    ; Others:

    SHOW_SCORE PROC FAR       ; SHOWS AX, In DI Position
        MOV DI, SCORE_POSITION
        MOV DX, DI
        CALL SET_CURSOR        ; Set cursor at Row 0, Col 100
        MOV CX, 1
     
         
        CMP SCORE, 0
        JE INPUT_IS_ZERO
        MOV AX, SCORE
        SHOW_SCORE_LOOP:
            MOV DX, 0
            MOV BX, 10        
            DIV BX
            PUSH AX
  
            MOV AL, DL
            ADD AL, 30h 
            MOV BL, SCORE_COLOR
            CALL SHOW_CHAR
            
            DEC DI          ; Col--
            MOV DX, DI
            CALL SET_CURSOR         ; Set cursor at Row 0, Col

            POP AX  
            CMP AX, 0
            JE SHOW_SCORE_RET
            JMP SHOW_SCORE_LOOP

        INPUT_IS_ZERO:
            MOV AL, '0'
            MOV BL, SCORE_COLOR
            CALL SHOW_CHAR

        SHOW_SCORE_RET:
            RET
    SHOW_SCORE ENDP

    MANAGE_SCROLL PROC FAR
        CMP SHOULD_SCROLL, 1
        JNE RET_MANAGE_SCROLL

        CMP JUMP_HEIGHT_IT, 0
        JE END_SCROLL
            SCROLL_DOWN:
                MOV AH, 7
                MOV AL, SCROLL_LINES
                MOV BH, BACKGROUND_COLOR
                MOV CX, 0200h
                MOV DX, 0184Fh 
                INT 10h    					 ;execute the configuration 
                CMP IS_MONSTER_IN, 0
                JE SCROLL_END                
                    ADD MONSTER_Y, 8
                    MOV AX, WINDOW_HEIGHT
                    SUB AX, MONSTER_SIZE_Y
                    CMP AX, MONSTER_Y
                    JGE SCROLL_END
                        MOV IS_MONSTER_IN, 0    
            SCROLL_END:
                DEC JUMP_HEIGHT_IT
                INC SCORE
                JMP RET_MANAGE_SCROLL
        END_SCROLL:
            MOV DONE_SCROLLING, 1

        RET_MANAGE_SCROLL:      
            RET
    MANAGE_SCROLL ENDP
    
    INIT PROC NEAR
        MOV IS_MONSTER_IN, 0
        MOV IS_OVER, 0
        MOV BALL_X, 160
        MOV BALL_Y, 70
        MOV SCORE, 0

        MOV AX, JUMP_HEIGHT
        MOV JUMP_HEIGHT_IT, AX 

        MOV AX, BALL_SIZE
        SHL AX, 1
        MOV BX, AX
        MUL BX
        MOV SI, AX
        INC AX
        MOV SAVED_MONSTER_IDX, AX

        MOV AX, MONSTER_SIZE_X
        MOV BX, MONSTER_SIZE_Y
        MUL BX
        ADD SI, AX

        MOV DL, BACKGROUND_COLOR
        FILL_ARRAY:
            MOV ES:[SI], DL
            DEC SI
            JNZ FILL_ARRAY
        INC SI
        MOV SAVED_BALL_IDX, SI

        MOV AH,00h                   ;set the configuration to video mode
        MOV AL,13h                    ;choose the video mode
        INT 10h    					 ;execute the configuration 

        MOV AX, WINDOW_HEIGHT
        SUB AX, STEP_SIZE_Y
        MOV MAX_GENERATED_Y, AX

        MOV AX, WINDOW_WIDTH
        SUB AX, STEP_SIZE_X
        MOV MAX_GENERATED_X, AX
        ; Getting Break_Point: (See Break_point_formula.txt)
        MOV DX, 0        
        MOV AX, STEP_SIZE_Y
        DEC AX
        MOV BX, BREAK_SLOPE
        MUL BX
        ADD AX, BREAK_WIDTH
        MOV CX, STEP_SIZE_X
        SUB CX, AX
        SHR CX, 1
        MOV BREAK_POINT, CX    

        MOV AX, SPRING_SIZE_X
        MOV BX, SPRING_BREAK_SIZE
        SHR AX, 1
        SHR BX, 1
        SUB AX, BX
        MOV SPRING_BREAK_POINT, AX
        RET
    INIT ENDP

    MAIN    PROC 
        MOV AX, @DATA
        MOV DS, AX      ; Setting Data Segment
        ADD AX, 1000h   ; Extra Segment is far away from Data Segment 
        MOV ES, AX      ; Setting Extra Segment
    
        START_NEW_GAME:
            CALL INIT
            CALL CLEAR_SCREEN

            MOV CX, FIRST_STEPS
            MOV SHOULD_GENERATE, 1
            CALL DRAW_STEP

            MOV MIN_GENERATED_Y, 16
            MOV MAX_GENERATED_Y, 20

            GAME_RUNNING:
                CALL DELAY

                CMP IS_OVER, 1              ; Set By MOVE_BALL Proc
                JE GAME_OVER                ; CAUSES GAME TO STOP

                MOV CX, SCROLL_STEPS
                CALL DRAW_STEP
                CALL DRAW_ADDITIONALS

                CALL REMOVE_BALL
                CALL MANAGE_SCROLL
                CALL MOVE_BALL 
                CALL DRAW_BALL

                CALL SHOW_SCORE 

                JMP GAME_RUNNING 

        GAME_OVER:
            MOV DX, 0660h
            CALL SET_CURSOR
            MOV DX, OFFSET GAME_OVER_MESSAGE
            MOV AH, 9
            INT 21h

            MOV CX, 50
            W8_FOR_RESTART:
                PUSH CX
                CALL DELAY
                POP CX
                LOOP W8_FOR_RESTART
            JMP START_NEW_GAME
            RET
    MAIN    ENDP
            END MAIN