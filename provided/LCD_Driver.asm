;***************************************************************
; PROGRAM: LCD Driver
; NAME: Andrew Jones
; DATE: 10/08/21, updated 10/16/25
; FUNCTION: Provided code to control the LCD module
;     Assumes 4 bit communication interface (PortK)
;     No handshaking, only delays between commands
;     24MHz clock - if not, adjust Wait1us subroutine
;  Dragon12-Light.
;  D-Bug12v4.x.x
;***************************************************************
;
;  Callable routines:   
;              LCD_Init - initialize the LCD module
;              LCDCMD  - send a command  to LCD (in A)
;              LCDDATA - send data to LCD (in A)
;              Wait1us - delay (X) microseconds (kill 24X clocks) 
;
;
;  This sample program uses 4-bit transfer via port K:
;  PK0 ------- RS ( register select, 0 = register transfer, 1 = data transfer).
;  PK1 ------- Enable ( write pulse )
;  PK2 ------- Data Bit 4 of LCD
;  PK3 ------- Data Bit 5 of LCD
;  PK4 ------- Data Bit 6 of LCD
;  PK5 ------- Data Bit 7 of LCD
;
; Timing of 4-bit data transfer is shown on page 44 of the Hantronix
; application notes included in "standard_LCD.pdf" handout
;    
;  Code located at $3A00 - $3A7F
;
;***************************************************************
; Include External Subroutine Files
;***************************************************************
#ifndef PORTA
#include "Reg9s12.inc"
#endif


;************************************************************
; MAIN - example code to call routine
;************************************************************

;        ORG  $2000
;Main   
;        JSR  LCD_INIT	; initialize the LCD module
;        LDAA #$88
;        JSR  LCDCMD	; move cursor to middle, top line
;        LDAA #'G'
;        JSR  LCDDATA	; output "Go"
;        LDAA #'o'
;        JSR  LCDDATA	 
;
;        SWI
		

	 ORG $3A00	
;***************************************************************
; LCD_INIT - initialize LCD port and device (4 bit access)
;  Modifies: D
;  Uses: N_LCDOUT, LCDCMD, DELAY5ms
;  returns nothing (LCD display - portK) is active
;***************************************************************
LCD_INIT:
	MOVB #$3F,ddrk	; portK [5-0] output
	CLR  portk	; all output GND

	LDAA #$30	; using upper nibble of (A)
	LDAB #$02	; set for command
	JSR  _N_LCDOUT	; nibble reset 
	JSR  _DELAY5ms
	JSR  _N_LCDOUT	; nibble reset
	JSR  _DELAY5ms
	LDAA #$32	; reset (last command of three)
	BSR  LCDCMD
	LDAA #$2C	; Function set: 
	BSR  LCDCMD     ;     4 bit mode, multiple line, 5X7 dot
	LDAA #$0C	; Display control: 
	BSR  LCDCMD	;     display on, cursor off, no blinking
	LDAA #$01	; Clear display:
	BSR  LCDCMD	;     fill spaces, cursor to pos 0, clears I/D flag
	JSR  _DELAY5ms	; 1.64ms after clear screen
	LDAA #$06	; Entry Mode:
	BSR  LCDCMD	;     cursor move right, screen not shifted
	RTS
	

;***************************************************************
; LCDCMD - send command (in register A) to LCD (byte)
;  Modifies none
;  Uses: LCDOUT
;  returns nothing
;***************************************************************
LCDCMD:	PSHB
	LDAB #$02	; set for Command (RS) low
	BSR  _LCDOUT
	PULB
	RTS

;***************************************************************
; LCDDATA - send data (in register A) to LCD (byte)
;  Modifies none
;  Uses: _LCDOUT
;  returns nothing
;***************************************************************
LCDDATA:PSHB
	LDAB #$03	; set for Data (RS) high
	BSR  _LCDOUT
	PULB
	RTS

;***************************************************************
; _LCDOUT - send byte to LCD (nibble by nibble)
;  (A) contains the byte to send, (B)=$02 data, $03 command
;  Modifies A
;  Uses: N_LCDOUT, DELAY50us
;  returns nothing
;***************************************************************
_LCDOUT:
 	PSHA
	JSR  _N_LCDOUT	; send upper nibble
	PULA
	LSLA
	LSLA
	LSLA
	LSLA
	JSR  _N_LCDOUT	; send lower nibble
	JSR  _DELAY50us
	RTS

;***************************************************************
; _N_LCDOUT - send nibble to LCD
;  (A) upper nibble contains the nibble to send
;  (B)=$02 data, $03 command
;  Modifies A
;  returns nothing
;***************************************************************
_N_LCDOUT:
	ANDA #$F0	; mask off lower nibble
	LSRA
	LSRA		; shift upper nibble into [5-2] bits
	ANDB #$03
	PSHB		; (B) = $03 for data, $02 for command
	ORAA 1,sp+	; set (E)nable high
	STAA portk	; send to LCD
	PSHA
	PULA		; kill 5 clock cycles
	ANDA #$FD	; clear (E)nable low
	STAA portk	; require 230ns from previous STAA instruction
	RTS
	


;***************************************************************
; DELAY routines - DELAY5ms, DELAY50us
;  calls WAIT1us (instruction delay) for 1microsecond delay
;  Modifies none
;  returns nothing
;***************************************************************
_Delay5ms:
        PSHX
        LDX  #5000
        BSR  Wait1us
        PULX
        RTS

_Delay50us:
        PSHX
        LDX  #50
        BSR  Wait1us
        PULX
        RTS

;***************************************************************
; WAIT1us - use instructions to kill time
;  (X) contains number of micro seconds to delay
;  Modifies (X)
;  Assume 24 MHz instruction clock
;  returns nothing 
;***************************************************************
WAIT1us:PSHX		; pair: [5]
	PULX
	PSHX		; pair: [5]
	PULX
	PSHX		; pair: [5]
	PULX	
	PSHX		; pair: [5]
	PULX
	DEX		; [1]
	BNE  WAIT1us	; [3]
	RTS		
