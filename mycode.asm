DATA SEGMENT PARA 'DATA'
	
	WINDOW_WIDTH DW 140h                 ;the width of the window (320 pixels)
	WINDOW_HEIGHT DW 0C8h                ;the height of the window (200 pixels)
	WINDOW_BOUNDS DW 6                   ;variable used to check collisions early
	
	TIME_AUX DB 0                        ;variable used when checking if the time has changed
	GAME_ACTIVE DB 1                     ;is the game active? (1 -> Yes, 0 -> No (game over))
	EXITING_GAME DB 0
	WINNER_INDEX DB 0                    ;the index of the winner (1 -> player one, 2 -> player two)
	CURRENT_SCENE DB 0                   ;the index of the current scene (0 -> main menu, 1 -> game)
	
	TEXT_PLAYER_ONE_POINTS DB '0','$'    ;text with the player one points
	TEXT_PLAYER_TWO_POINTS DB '0','$'    ;text with the player two points
	TEXT_GAME_OVER_TITLE DB 'GAME OVER','$' ;text with the game over menu title
	TEXT_GAME_OVER_WINNER DB 'Player 0 won','$' ;text with the winner text
	TEXT_GAME_OVER_PLAY_AGAIN DB 'Press R to play again','$' ;text with the game over play again message
	TEXT_GAME_OVER_MAIN_MENU DB 'Press E to exit to main menu','$' ;text with the game over main menu message
	TEXT_MAIN_MENU_TITLE DB 'MAIN MENU','$' ;text with the main menu title
	TEXT_MAIN_MENU_SINGLEPLAYER DB 'SINGLEPLAYER - S KEY','$' ;text with the singleplayer message
	TEXT_MAIN_MENU_MULTIPLAYER DB 'MULTIPLAYER - M KEY','$' ;text with the multiplayer message
	TEXT_MAIN_MENU_EXIT DB 'EXIT GAME - E KEY','$' ;text with the exit game message
	
	BALL_ORIGINAL_X DW 0A0h              ;X position of the ball on the beginning of a game
	BALL_ORIGINAL_Y DW 64h               ;Y position of the ball on the beginning of a game
	BALL_X DW 0A0h                       ;current X position (column) of the ball
	BALL_Y DW 64h                        ;current Y position (line) of the ball
	BALL_SIZE DW 06h                     ;size of the ball (how many pixels does the ball have in width and height)
	BALL_VELOCITY_X DW 05h               ;X (horizontal) velocity of the ball
	BALL_VELOCITY_Y DW 02h               ;Y (vertical) velocity of the ball
	
	PADDLE_LEFT_X DW 0Ah                 ;current X position of the left paddle
	PADDLE_LEFT_Y DW 55h                 ;current Y position of the left paddle
	PLAYER_ONE_POINTS DB 0              ;current points of the left player (player one)
	
	PADDLE_RIGHT_X DW 130h               ;current X position of the right paddle
	PADDLE_RIGHT_Y DW 55h                ;current Y position of the right paddle
	PLAYER_TWO_POINTS DB 0             ;current points of the right player (player two)
	
	PADDLE_WIDTH DW 06h                  ;default paddle width
	PADDLE_HEIGHT DW 25h                 ;default paddle height
	PADDLE_VELOCITY DW 0Fh               ;default paddle velocity

DATA ENDS

w equ 20
h equ 1


DRAW_BALL PROC NEAR                  
		
		MOV CX,BALL_X                    ;set the initial column (X)
		MOV DX,BALL_Y                    ;set the initial line (Y)
		
		DRAW_BALL_HORIZONTAL:
			MOV AH,0Ch                   ;set the configuration to writing a pixel
			MOV AL,0Fh 					 ;choose white as color
			MOV BH,00h 					 ;set the page number 
			INT 10h    					 ;execute the configuration
			
			INC CX     					 ;CX = CX + 1
			MOV AX,CX          	  		 ;CX - BALL_X > BALL_SIZE (Y -> We go to the next line,N -> We continue to the next column
			SUB AX,BALL_X
			CMP AX,BALL_SIZE
			JNG DRAW_BALL_HORIZONTAL
			
			MOV CX,BALL_X 				 ;the CX register goes back to the initial column
			INC DX       				 ;we advance one line
			
			MOV AX,DX             		 ;DX - BALL_Y > BALL_SIZE (Y -> we exit this procedure,N -> we continue to the next line
			SUB AX,BALL_Y
			CMP AX,BALL_SIZE
			JNG DRAW_BALL_HORIZONTAL
		
		RET
DRAW_BALL ENDP
  



DRAWSTEP PROC   ; get cx and dx as input
    
    MOV BX, h
    hor:    
        PUSH CX ; First Col saved
        PUSH BX ; How many left saved
        
    
        MOV BX, w
        vert:  
              
            MOV AL, 2  ; Color = Green
            MOV AH, 12 ; Set Pixel
            INT 10H 
            
            INC CX
            DEC BX
            CMP BX, 0
            JG vert 
        
        INC DX
        POP BX
        POP CX
        DEC BX
        CMP BX, 0
        JG hor

    RET
DRAWSTEP ENDP




KEYBOARD PROC   ; ZF = 0 IF KEY AVAILABLE
    MOV AH, 1
    INT 16H
    RET
KEYBOARD ENDP




        
        
MAIN PROC FAR  
    
    MOV AL, 13H
    MOV AH, 0
    INT 10H
    
    MOV CX, 200 ;Col
    MOV DX, 20  ;Row
    
    CALL DRAW_BALL

 
    
    

 
    
    ;CALL DRAWSTEP

MAIN ENDP
    END MAIN


