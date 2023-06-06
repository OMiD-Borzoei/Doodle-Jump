     .MODEL MEDIUM
.STACK 128

.DATA
    SCORE_COLOR         DB 13 
    BACKGROUND_COLOR    DB 15
    HEADER_COLOR        DB 0
    BALL_COLOR          DB 9    ; L_BLUE
    STEP_COLOR          DB 10   ; L_GREEN
    SPRING_COLOR        DB 0;232  ; BLACK
    BROKEN_COLOR        DB 6    ; BROWN
    MONSTER_COLOR       DB 41    ; RED     
   
    BALL_X          DW ?
    BALL_Y          DW ?
    LAST_BALL_X     DW ?
    LAST_BALL_Y     DW ?
    BALL_SIZE_X     DW 18   ; it's in pixel mode
    BALL_SIZE_Y     DW 14   ; screen = 320*200 pixel
    BALL_VELOCITY_Y DW 6
    BALL_VELOCITY_X DW 12

    MONSTER_X       DW ?
    MONSTER_Y       DW ?
    LAST_MONSTER_X  DW ?
    LAST_MONSTER_Y  DW ?
    MONSTER_SIZE_X  DW 25 
    MONSTER_SIZE_Y  DW 30    
    MONSTER_SPEED   DW 2    ; Only Moves In X Axis

    STEP_SIZE_X     DW 60
    STEP_SIZE_Y     DW 7  
    SCROLL_STEPS    DW 1 
    FIRST_STEPS     DW 6
    STEPS_TO_DRAW   DW ?

    BREAK_POINT     DW ?
    BREAK_SLOPE     DW 3
    BREAK_WIDTH     DW 14

    SPRING_SIZE_X   DW 10
    SPRING_SIZE_Y   DW 12
    SPRING_BREAK_POINT  DW  ?
    SPRING_BREAK_SIZE   DW  2

    MIN_GENERATED_Y DW 50
    MAX_GENERATED_Y DW ?  
    MAX_GENERATED_X DW ?
    
    WINDOW_WIDTH    DW 320
    WINDOW_HEIGHT   DW 200
    
    SPRING_JUMP_HEIGHT  DW  45
    JUMP_HEIGHT     DW 15
    JUMP_HEIGHT_IT  DW ?
    JUMP            DB 0

    SCORE           DW ?
    SCORE_POSITION  DW 180

    IS_OVER             DW ?
    GAME_OVER_MESSAGE   DB 'GAME OVER!$'
    
    SHOULD_GENERATE     DB 1
    GEN_FREQ            DW 5
    SCROLL_LINES        DB 1
    SHOULD_SCROLL       DB 0
    DONE_SCROLLING      DB 0
    FIRST_SCROLL        DB 1
    JAYI_KE_QAM_NABASHE DW 100 

    SEED                DW 8122h
    TIME_AUX            DB 0   
    SAVED_BALL_IDX      DW ?
    SAVED_MONSTER_IDX   DW ?
    SAVED_MONSTER_ROW   DW 0
    SAVED_MONSTER_IT    DW ?
    NUMBER_TO_SHOW      DW ?            ; For Debugging
    HEADER_LINES        DB 2 
    
    WHEN_DRAW_BROKEN    DW 23   ; Show Broken every 23 Score
    WHEN_DRAW_SPRING    DW 41   ; Show Spring every 41 Score
    WHEN_DRAW_MONSTER   DW 57   ; Show Monster every 57 Score
    
    BROKEN_GENERATED_IN     DW 0
    SPRING_GENERATED_IN     DW 0
    MONSTER_GENERATED_IN    DW 0
    IS_MONSTER_IN           DB ?   
.CODE  
    

    ;   Useful Procedures:

    GET_COLOR PROC FAR      ; AL = OUTPUT
        MOV AH, 0Dh
        INT 10H
        RET
    GET_COLOR ENDP

    SET_COLOR PROC FAR      ; AL = INPUT
        MOV AH, 0Ch
        MOV BH, 0
        INT 10H        
        RET
    SET_COLOR ENDP
    
    SET_CURSOR PROC FAR         ; DX as Input, DH Row, DL Col
        MOV AH, 2
        MOV BH, 0
        INT 10h
        RET 
    SET_CURSOR ENDP
    
    DELAY PROC FAR
        MOV AH,2Ch 					 ;get the system time
    	INT 21h    					 ;CH = hour CL = minute DH = second DL = 1/100 seconds
    	MOV BL, DL  			     ;is the current time equal to the previous one(TIME_AUX)?
        DELAY_LOOP:
            MOV AH,2Ch 					 ;get the system time
    	    INT 21h    					 ;CH = hour CL = minute DH = second DL = 1/100 seconds  
            CMP DL, BL
            JE DELAY_LOOP      
        RET
    DELAY ENDP    

    CLEAR_SCREEN PROC FAR               
        MOV AH, 6
        MOV AL, 0
        MOV BH, BACKGROUND_COLOR
        MOV CX, 0
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
        MOV CX, 5
        RANDOM_LOOP: 
            MUL DX
            ADD SEED, AX
            ADD AX, SEED
            SUB DX, AX
            LOOP RANDOM_LOOP
        XOR DX, DX
        POP CX
        DIV CX
        RET
    GENERATE_RANDOM ENDP

    GENERATE_RANDOM_COORDINATES PROC FAR    ; CX = X, DX = Y, OUTPUT
        MOV CX, MAX_GENERATED_X
        CALL GENERATE_RANDOM
        PUSH DX                         ;  X-AXIS
        MOV CX, MAX_GENERATED_Y
        SUB CX, MIN_GENERATED_Y
        CALL GENERATE_RANDOM                      
        ADD DX, MIN_GENERATED_Y         ; Y-AXIS
        POP CX
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



    ; Step Procedures:

    DRAW_STEP PROC FAR           ; CX = NUMBER
        CMP SHOULD_GENERATE, 1   
        JNE DRAW_STEP_RET 
        GENERATE_STEP:         
            PUSH CX
            MOV BX, STEP_SIZE_Y
            MOV BP, STEP_SIZE_X
            GENERATE_COORD:
                CALL GENERATE_RANDOM_COORDINATES  
                CALL CHECK_EXISTS
                CMP AX, 1
                JE GENERATE_COORD        
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
        MOV DX, BALL_Y
        MOV BX, STEP_SIZE_Y
        SHL BX, 1
        SHL BX, 1
        SUB CX, STEP_SIZE_X
        MOV BP, STEP_SIZE_X
        ADD BP, STEP_SIZE_X
        ADD BP, STEP_SIZE_X
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
                    CALL GENERATE_MONSTER
        ADDITIONALS_RET:
            CMP IS_MONSTER_IN, 1
            JNE SERIOUSLY_RET
                CALL MOVE_MONSTER
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
                    CALL STOP_JUMP          ; We should stop moving up
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
                CALL STOP_JUMP

        
        ORDINARY:  
        MOV AX, BALL_VELOCITY_Y
        ADD BALL_Y, AX          ; MOVE BALL ON Y-AXIS 
        CMP JUMP, 1
        JE CHECK_MONSTER

        CALL CHECK_COLLISION
        CMP AL, STEP_COLOR
        JNE CHECK_SPRING 
            MOV AX, JUMP_HEIGHT
            CALL START_JUMP
                    
        CHECK_SPRING:
        CMP AL, SPRING_COLOR
        JNE CHECK_BROKEN                
            MOV AX, SPRING_JUMP_HEIGHT
            CALL START_JUMP

        CHECK_BROKEN:
        CMP AL, BROKEN_COLOR
        JNE CHECK_MONSTER
            CALL REMOVE_BROKEN_STEP
        
        CHECK_MONSTER:
        MOV CX, BALL_X
        MOV DX, BALL_Y
        MOV BX, BALL_SIZE_Y
        MOV BP, BALL_SIZE_X
        MOV AL, MONSTER_COLOR
        MOV AH, 5
        CALL ITERATE_RECT
        CMP AL, 1
        JNE CHECK_BOUNDARY
            MOV IS_OVER, 1

        CHECK_BOUNDARY:
        MOV BX, BALL_SIZE_Y
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
        MOV LAST_BALL_X, CX
        MOV LAST_BALL_Y, DX
        MOV BX, BALL_SIZE_Y
        MOV BP, BALL_SIZE_X
        MOV AL, BALL_COLOR
        MOV AH, 1
        MOV SI, SAVED_BALL_IDX
        CALL ITERATE_RECT 
        MOV AL, BALL_COLOR
        MOV AH, 0
        CALL ITERATE_RECT                       
        RET
    DRAW_BALL ENDP

    REMOVE_BALL PROC FAR
        MOV CX, LAST_BALL_X
        MOV DX, LAST_BALL_Y
        MOV BX, BALL_SIZE_Y
        MOV BP, BALL_SIZE_X
        MOV AH, 2
        MOV SI, SAVED_BALL_IDX
        CALL ITERATE_RECT
        RET
    REMOVE_BALL ENDP



    ; Jump Procedures:

    CHECK_COLLISION PROC FAR               
        MOV CX, BALL_X
        MOV DX, BALL_Y 
        ADD CX, BALL_SIZE_X
        ADD DX, BALL_SIZE_Y
        LAST_ROW_LOOP:
            CALL GET_COLOR
            CMP AL, BACKGROUND_COLOR
            JNE CHECK_COLLISION_RET
            DEC CX
            CMP CX, BALL_X
            JGE LAST_ROW_LOOP
        CHECK_COLLISION_RET:
            RET    
    CHECK_COLLISION ENDP

    STOP_JUMP PROC FAR
        MOV JUMP, 0         ; If We Reached the max height, We need to fall down again, thus we'll set jump to 0
        CMP BALL_VELOCITY_Y, 0
        JGE STOP_JUMP_RET
            NEG BALL_VELOCITY_Y ; Ball_vel_y = - Ball_vel_y
        STOP_JUMP_RET:
            RET
    STOP_JUMP ENDP   

    START_JUMP PROC FAR         ; AX input
        MOV JUMP_HEIGHT_IT, AX
        MOV JUMP, 1
        CMP BALL_VELOCITY_Y, 0
        JLE START_JUMP_RET
            NEG BALL_VELOCITY_Y
        START_JUMP_RET:
            RET
    START_JUMP ENDP 


    ; Score Procedures:
    
    FILL_HEADER PROC FAR        
        MOV DX, 0
        MOV CX, 0
        CALL SET_CURSOR 
        MOV BL, HEADER_COLOR
        MOV CL, HEADER_LINES
        MOV CH, 0
        MOV AX, 40
        MUL CX
        MOV CX, AX
        MOV AX, 09DBh
        MOV BH, 0 
        INT 10h   
        RET
    FILL_HEADER ENDP

    SHOW_NUMBER PROC FAR       ; SHOWS AX, In DI Position
        PUSH AX

        MOV DX, DI
        CALL SET_CURSOR        ; Set cursor at Row 0, Col 100

        POP AX    
        CMP AX, 0
        JE INPUT_IS_ZERO
        SHOW_NUMBER_LOOP:
            MOV DX, 0
            MOV BX, 10        
            DIV BX
            PUSH AX
  
            MOV AH, 09h
            MOV BH, 0
            MOV CX, 1 
            MOV AL, DL
            ADD AL, 30h 
            MOV BL, SCORE_COLOR
            INT 10h         ; Show Char

            DEC DI          ; Col--
            MOV DX, DI
            CALL SET_CURSOR         ; Set cursor at Row 0, Col

            POP AX  
            CMP AX, 0
            JE SHOW_NUMBER_RET
            JMP SHOW_NUMBER_LOOP

        INPUT_IS_ZERO:
            MOV AH, 9
            MOV AL, '0'
            MOV BH, 0
            MOV BL, SCORE_COLOR
            MOV CX, 1
            INT 10h

        SHOW_NUMBER_RET:
            RET
    SHOW_NUMBER ENDP



    ; Scroll Procedures:

    MANAGE_SCROLL PROC FAR
        CMP SHOULD_SCROLL, 1
        JNE RET_MANAGE_SCROLL

        CMP JUMP_HEIGHT_IT, 0
        JE END_SCROLL
            SCROLL_DOWN:
                MOV AX, 0701h
                MOV BH, BACKGROUND_COLOR
                MOV CH, HEADER_LINES
                MOV CL, 0
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



    ; Monster Procedures:

    MOVE_MONSTER PROC FAR
        MOV CX, MONSTER_X
        MOV DX, MONSTER_Y
        MOV BX, MONSTEr_SIZE_Y
        MOV BP, MONSTER_SPEED
        MOV AL, BACKGROUND_COLOR
        MOV AH, 0
        CALL ITERATE_RECT

        ADD CX, MONSTER_SIZE_X
        MOV AL, MONSTER_COLOR
        MOV AH, 0
        CALL ITERATE_RECT

        MOV AX, MONSTER_SPEED
        ADD MONSTER_X, AX
        RET
    MOVE_MONSTER ENDP    

    GENERATE_MONSTER PROC FAR
        MOV IS_MONSTER_IN, 1
        CALL GENERATE_RANDOM_COORDINATES
        MOV MONSTER_X, CX
        MOV MONSTER_Y, DX
        SAVE_PIXELS:
            MOV CX, MONSTER_X
            MOV DX, MONSTER_Y
            MOV BX, MONSTER_SIZE_Y
            MOV BP, MONSTER_SIZE_X
            MOV LAST_MONSTER_X, CX
            MOV LAST_MONSTER_Y, DX
            MOV AH, 1
            MOV SI, SAVED_MONSTER_IDX
            CALL ITERATE_RECT        
        MOV AL, MONSTER_COLOR
        MOV AH, 0
        CALL ITERATE_RECT    
        RET
    GENERATE_MONSTER ENDP

    INIT PROC NEAR
        MOV IS_MONSTER_IN, 0
        MOV IS_OVER, 0
        MOV BALL_X, 160
        MOV BALL_Y, 30
        MOV SCORE, 0

        MOV AX, JUMP_HEIGHT
        MOV JUMP_HEIGHT_IT, AX 
    
        MOV AX, BALL_X
        MOV LAST_BALL_X, AX

        MOV AX, BALL_Y
        MOV LAST_BALL_Y, AX

        MOV AX, BALL_SIZE_X
        MOV BX, BALL_SIZE_Y
        MUL BX
        MOV SI, AX
        INC AX
        MOV SAVED_MONSTER_IDX, AX
        MOV SAVED_MONSTER_IT, AX

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
        ADD AX, 1000h
        MOV ES, AX      ; Setting Extra Segment
    
        START_GAME:

        CALL INIT

        CALL CLEAR_SCREEN
        CALL FILL_HEADER

        MOV CX, FIRST_STEPS
        MOV SHOULD_GENERATE, 1
        CALL DRAW_STEP

        MOV AL, HEADER_LINES
        MOV BL, 8
        MUL BL
        MOV AH, 0
        MOV MIN_GENERATED_Y, AX
        
        MOV MAX_GENERATED_Y, AX
        ADD MAX_GENERATED_Y, 3

        CHECK_TIME:
            CALL DELAY
            
            CMP IS_OVER, 1              ; Set By MOVE_BALL Proc
            JE GAME_OVER                ; CAUSES GAME TO STOP

            MOV CX, SCROLL_STEPS
            CALL DRAW_STEP
            CALL DRAW_ADDITIONALS

            CALL REMOVE_BALL

            CALL MANAGE_SCROLL

            MOV DI, SCORE_POSITION
            MOV AX, SCORE
            CALL SHOW_NUMBER 

            CALL MOVE_BALL 
            CALL DRAW_BALL
                            
            JMP CHECK_TIME        
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
            JMP START_GAME

            RET
    MAIN    ENDP
            END MAIN