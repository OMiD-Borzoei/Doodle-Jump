.MODEL MEDIUM
.STACK 64

.DATA
    ; COLORS :
    BLACK   DB 0
    BLUE    DB 1
    GREEN   DB 2
    CYAN    DB 3
    RED     DB 4
    MAGNETA DB 5
    BROWN   DB 6
    L_GRAY  DB 7
    D_GRAY  DB 8
    L_BLUE  DB 9
    L_GREEN DB 10
    L_CYAN  DB 11
    L_RED   DB 12
    YELLOW  DB 14
    WHITE   DB 15
    L_MAGNETA   DB 13 

    BACKGROUND_COLOR DB 15
    
    BALL_X DW 8Ah
    BALL_Y DW 1Fh
    BALL_SIZE_X DW 20
    BALL_SIZE_Y DW 16
    BALL_COLOR  DB 3    ; BLUE
    BALL_VELOCITY_Y DW  7
    BALL_VELOCITY_X DW  7

    STEP_X DW 8Ah
    STEP_Y DW 0AFh
    STEP_SIZE_X DW 50
    STEP_SIZE_Y DW 7
    STEP_COLOR  DB 10   ; L_GREEN
    
    TIME_AUX DB 0
    
    WINDOW_WIDTH DW 140h
    WINDOW_HEIGHT DW 0C8h
    WHERE_TO_SHOW_STEPS_U DW ?
    
    JUMP_HEIGHT DW 15
    JUMP_HEIGHT_IT DW ?
    JUMP DB 0
    SHOULD_GENERATE DB 0

    SCORE           DW 0
    SCORE_POSITION  DW 0064h
    NUMBER_TO_SHOW  DW ?            ; For Debugging 

    IS_OVER         DW 0
    GAME_OVER_MESSAGE DB 'GAME OVER!$'

.CODE  

GET_COLOR PROC FAR
    MOV AH, 0Dh
    INT 10H
    RET
GET_COLOR ENDP

DRAW_STEP PROC FAR
    CMP SHOULD_GENERATE, 1
    JNE normal

        MOV CX, WINDOW_WIDTH
        SUB CX, STEP_SIZE_X
        DEC CX
        CALL GENERATE_RANDOM
        MOV STEP_X, DX
    
        MOV CX, WHERE_TO_SHOW_STEPS_U
        SUB CX, STEP_SIZE_Y
        DEC CX
        ;MOV NUMBER_TO_SHOW, CX
        CALL GENERATE_RANDOM
        ADD DX, WHERE_TO_SHOW_STEPS_U
        MOV STEP_Y, DX
        ;MOV NUMBER_TO_SHOW, DX
    
    MOV SHOULD_GENERATE, 0
    JMP unnormal 
    normal:
    MOV CX, STEP_X
    MOV DX, STEP_Y
    unnormal: 
        
    MOV BX, STEP_SIZE_Y
    MOV BP, STEP_SIZE_X
    MOV AL, STEP_COLOR
    CALL DRAW_RECT                
    
    RET
DRAW_STEP ENDP

DRAW_BALL PROC FAR
    MOV CX, BALL_X
    MOV DX, BALL_Y
    MOV BX, BALL_SIZE_Y
    MOV BP, BALL_SIZE_X
    MOV AL, BALL_COLOR
    CALL DRAW_RECT                        
    RET
DRAW_BALL ENDP

DRAW_RECT PROC FAR       ; CX = START_X, BX = SIZE_Y, DX = START_Y, BP = SIZE_X, AL = COLOR
    Horizontal:
        PUSH BX
        PUSH CX
        PUSH BP 
        Vertical:
            MOV AH, 0Ch
            MOV BH, 0
            INT 10H        ; Color Pixel
            INC CX         ; Next Column
            DEC BP         ; Iterator
            JNZ Vertical
        POP BP
        POP CX              ; Base Column Is Restored
        POP BX              ; Row Iterator Restored        
        INC DX              ; Next Row  
        DEC BX              
        JNZ Horizontal   
    RET
DRAW_RECT ENDP

CLEAR_SCREEN PROC FAR               
    MOV AH, 6
    MOV AL, 0
    MOV BH, BACKGROUND_COLOR
    MOV CX, 0
    MOV DX, 0FFC8h 
    INT 10h    					 ;execute the configuration    
    RET    
CLEAR_SCREEN ENDP

CHECK_COLLISION PROC FAR
    MOV CX, BALL_X 
    ADD CX, BALL_SIZE_X
    MOV DX, BALL_Y
    ADD DX, BALL_SIZE_Y
    INC DX
    INC DX

    last_row:
        CALL GET_COLOR
        CMP AL, BACKGROUND_COLOR
        JNE CHECK_COLLISION_RET
        DEC CX
        CMP CX, BALL_X
        JGE last_row

    CHECK_COLLISION_RET:
        RET
CHECK_COLLISION ENDP

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
    JNE ordinary        ; If Jump = 0, Ball Must Fall Down  
    
        DEC JUMP_HEIGHT_IT  ; JUMP TO A CERTAIN POINT
        JNZ ordinary
        MOV JUMP, 0         ; If We Reached the max height, We need to fall down again, thus we'll set jump to 0
        NEG BALL_VELOCITY_Y ; Ball_vel_y = - Ball_vel_y
        MOV AX, JUMP_HEIGHT 
        MOV JUMP_HEIGHT_IT, AX ; Reset JUMP_HEIGHT_IT


    ordinary:  
    MOV AX, BALL_VELOCITY_Y
    ADD BALL_Y, AX          ; MOVE BALL ON Y-AXIS

    CALL CHECK_COLLISION
    CMP AL, STEP_COLOR
    JNE CHECK_BOUNDARY
        INC SCORE    
        CMP JUMP, 1
        JNE NEW_JUMP
            MOV AX, JUMP_HEIGHT
            MOV JUMP_HEIGHT_IT, AX
            JMP MUST_BE_DONE
        
            NEW_JUMP:
                MOV JUMP, 1 
                NEG BALL_VELOCITY_Y

        MUST_BE_DONE:
            MOV SHOULD_GENERATE, 1
        
    CHECK_BOUNDARY:
    MOV AX, WINDOW_HEIGHT
    CMP BALL_Y, AX
    JL RET_MOVE_BALL
    
    MOV IS_OVER, 1

    RET_MOVE_BALL:
        RET
MOVE_BALL ENDP

GENERATE_RANDOM PROC FAR   ; CX INPUT AND DX OUTPUT, DX = A random number in [0, CX) Interval
    PUSH CX
    MOV AH,2Ch 					 ;get the system time
	INT 21h    					 ;CH = hour CL = minute DH = second DL = 1/100 seconds
    MOV AL, DH
    MOV AH, 0
    MOV BL, DL
    MUL BL          ; AX = PSEDUO-RANDOM NUMBER
    POP CX
    CMP CX, 0
    JE GENERATE_RANDOM_RET
    MOV DX, 0 
    DIV CX          ; DX = RANDOM % CX 
    
    GENERATE_RANDOM_RET:
        RET
GENERATE_RANDOM ENDP

SET_CURSOR PROC FAR         ; DX as Input, DH Row, DL Col
    MOV AH, 2
    MOV BH, 0
    INT 10h
    RET 
SET_CURSOR ENDP

SHOW_NUMBER PROC FAR       ; SHOWS AX
    MOV DI, SCORE_POSITION
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

        MOV AL, 0DBh
        MOV BL, WHITE
        INT 10h  

        MOV AL, DL
        ADD AL, 30h 
        MOV BL, L_MAGNETA
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
        MOV BL, L_MAGNETA
        MOV CX, 1
        INT 10h

    SHOW_NUMBER_RET:
        RET
SHOW_NUMBER ENDP

MAIN    PROC 

    MOV AX, @DATA
    MOV DS, AX      ;Setting Data Segment
    
    MOV AX, JUMP_HEIGHT
    MOV JUMP_HEIGHT_IT, AX 

    MOV AX, WINDOW_HEIGHT
    MOV BL, 2
    DIV BL
    MOV AH, 0
    MOV WHERE_TO_SHOW_STEPS_U, AX   

    MOV AH,00h                   ;set the configuration to video mode
    MOV AL,13h                   ;choose the video mode
    INT 10h    					 ;execute the configuration 

    CHECK_TIME:
        MOV AH,2Ch 					 ;get the system time
	    INT 21h    					 ;CH = hour CL = minute DH = second DL = 1/100 seconds
	    CMP DL,TIME_AUX  			 ;is the current time equal to the previous one(TIME_AUX)?
	    JE CHECK_TIME    		     ;if it is the same, check again

        MOV TIME_AUX, DL        

        CALL CLEAR_SCREEN
        
        CMP IS_OVER, 1              ; Set By MOVE_BALL Proc
        JE GAME_OVER

        MOV AX, SCORE
        CALL SHOW_NUMBER
        
        CALL DRAW_STEP

        CALL MOVE_BALL
        CALL DRAW_BALL
        
        JMP CHECK_TIME

        GAME_OVER:
            MOV DX, 0660h
            CALL SET_CURSOR
            MOV DX, OFFSET GAME_OVER_MESSAGE
            MOV AH, 9
            INT 21h

        RET
MAIN    ENDP
        END MAIN