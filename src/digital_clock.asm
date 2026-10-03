;***********************************************************************
;
; EGEE 250 - Lab ______ - Fall 2025
;
;***********************************************************************
;
; Completed by: Dylan Bollone, Nick Wingling
; 
;
; Academic Honesty Statement:  In signing this statement, I hereby 
; certify that I am the individual who created this 9S12 source file
; and that I have not copied the work of any other student (past or
; present) while completing it. I understand that if I fail to honor
; this agreement, I will receive a grade of ZERO and be subject to
; possible disciplinary action.
;
;
; Signature: ___________________________________   Date: ____________
;
;
; Signature: ___________________________________   Date: ____________
;
;
; NOTE: The printed hard copy of this file you submit for evaluation
;       must be signed in order to receive credit.
;
;***********************************************************************
;  Declarations - constants and global variables (ORG as needed)
;***********************************************************************

; include file with 
#include "Reg9s12.inc"
#include "LCD_Driver.asm"
#include "LED_Display.asm"

OC7_VEQ_NUM EQU 48	; OC7 vector number for setting user vector

; d-bug 12 subroutines used in program
SetUserVector EQU $EEA4	
Printf	EQU $EE88	
GetCmdLine EQU $EE8A	
GetChar	EQU $EE84	

; string const chars
NULL	EQU $00
LF	EQU $0A
RET	EQU $0D

	ORG $1000
; global variables
t_hrs	DCB 1	; clock hours in military time
t_mins	DCB 1	; clock minutes
t_secs	DCB 1	; clock seconds
a_hrs	DCB 1	; alarm hours in military time
a_mins	DCB 1	; alarm minutes
a_secs	DCB 1	; alarm seconds
t_buff	DCB 6	; input buffer of size 6 for getting user input for start time "hhmmss"
a_buff	DCB 6	; input buffer of size 6 for getting user input for alarm time "hhmmss"
oc7cnt	DCB 1	; counting number of time OC7 interrupt occured
d_type	DCB 1	; char for how to format output to user
lcd_flg DCB 1	; flag for how to output to user every second

; strings used in program subroutines, to prompt user input
tPrompt	DC.B "Input time: ",NULL
aPrompt DC.B "Alarm time:",NULL

; current time strings for output to lcd screen
ctimeL1	DC.B "  Current Time",NULL
ctimeL2	DC.B "00:00:00 AM  A",NULL

;***********************************************************************
; Subroutine: main
;
; Inputs: none
;
; Function: Prompt user for time, change output format d_type when needed
;
; Subroutines called: Printf, GetCmdLine, GetChar
;
; Modifies registers: D, X, Y, CCR
;
; Returns: none
;***********************************************************************
	ORG $2000
main
; enable on board pullup for PORTA, which is where the keypad is connected
	BSET PUCR,$01
	MOVB #$0F,DDRA

; initialize the LCD display
	JSR LCD_INIT
; initialize ECT interrupt on ch7
	JSR ECT_INIT
; initialize LED_display
	JSR LED_Init
	MOVB #$84,LEDctl ; no colon displayed, 4 digits

; Prompt the user and accept a valid current time and alarm time
	LDX #t_buff	; put pointer to input buffer on stack
	PSHX
	LDX #tPrompt	; prompt 1 = "Input time:" - prompt user for start clock time
	JSR P_User
	LDY #t_hrs	; hrs, mins, and secs are stored in memory consectutively
	LDX #t_buff
	JSR ascii_to_bin
	PULX		; reset stack
	; clear the display
	LDAA #$01
	JSR LCDCMD
	JSR _DELAY5ms

; initialize 9th char in LCD line 2 output string, and load d_type with the appropriate value
	LDAA t_hrs	; load a with inputted hours
	CMPA #12	; if greater than or = 12, store P in lcd output str
	BGE its_pm	; else: store A
	; modify lcd output str to end with AM, and alter d_type
	MOVB #'A',ctimeL2+9
	MOVB #'a',d_type
	BRA havoc
	; modify lcd output str to end with PM, and change d_type
its_pm	MOVB #'P',ctimeL2+9	
	MOVB #'p',d_type

;unmask interrupts and initialize d_type to m (clock initially outputs in military time - same as default input)
havoc	;MOVB #'m',d_type
	BSET TIE,$80
	CLI
; Get a char from user to change output or quit program loop
floop	JSR GETKEY

	; 'A' - selects to (re)enter the alarm time
	CMPA #'A'
	BNE chkC
	MOVB #1,lcd_flg	; set lcd output flag to 1, output 'enter alarm' string
	; clear the display
	LDAA #$01
	JSR LCDCMD
	JSR _DELAY5ms
	; output for alarm time
	LDX #a_buff	; pointer to input buffer on stack
	PSHX
	LDX #aPrompt	; prompt 2 = "Alarm time:" - prompt user to enter alarm time
	JSR P_User
	LDY #a_hrs	; hrs, mins, and secs are stored in memory consectutively
	LDX #a_buff
	JSR ascii_to_bin
	PULX		; reset stack

	CLR lcd_flg	; reset lcd output flag to default output
	BRA doNot

	; 'C' - selects to re-enter current time
chkC	CMPA #'C'
	BNE chkD
	
	; 'D' - display alarm time (instead ofclock time)
chkD	CMPA #'D'
	BNE chkstar
	
	; '*' - turns off the alarm if the alarm is sounded
chkstar	CMPA #'*'
	BNE chkhsh
	
	; '#' - toggles the alarm enable/disable clock mode
chkhsh	CMPA #'#'
	BNE doNot

doNot	BRA floop

;***********************************************************************
; Subroutine: ECT_INIT
;
; Inputs: none
;
; Function: Initialize ECT interrupts, and enable OC interrupt on CH7
;
; Subroutines called: SetUserVector
;
; Modifies registers: D
;
; Returns: user interrupt vector set up & oc7cnt cleared
;***********************************************************************
ECT_INIT
; step 1 - clear counter
	CLR oc7cnt
; step 2 - timer on
	MOVB #$80, TSCR1
; step 3 - all OC interrupts disabled
	CLR TIE
; step 4 - channel 7 is Output compare
	MOVB #$80, TIOS
; step 5 -timer prescale of 16, reset counter on event
	;MOVB #$0C, TSCR2
	MOVB #$0D, TSCR2 ;testing with prescale of 32
; step 6 - setup ch7 to interrupt every 10ms
	;MOVW #15000, TC7
	MOVW #7500, TC7 ;testing with prescale of 32
; step 7 - set up user vector for ISR
	LDD #OC7_ISR
	PSHD
	LDD #OC7_VEQ_NUM
	JSR [SetUserVector,PCR]
	LEAS 2,SP

	RTS

;***********************************************************************
; Subroutine: OC7_ISR
;
; Inputs: none
;
; Function: Service routine for OC7 interrupt
;
; Subroutines called: INC_TIME, OUTPUT
;
; Modifies registers: none
;
; Returns: Modified variables: hrs, mins, secs & changed clock output to user
;***********************************************************************
OC7_ISR
; step 1 - clear the device flag
	BSET TFLG1,$80
; step 2 - increment counter
	INC oc7cnt
; step 3 - Check if we've reached desired oc7cnt value
	LDAA oc7cnt
	CMPA #100
	BLT oc7_exit
; step 4 - Clear counter, update time, and output
	CLR oc7cnt
	JSR INC_TIME	; in lab 9 these 2 subroutine calls were in main loop

	JSR UPDATE_7_SEGs	
	BRSET LEDctl, $80, clrBit
	BSET LEDctl, $80
	BRA o2lcd
clrBit	BCLR LEDctl, $80

o2lcd	LDAA lcd_flg
	BNE oc7_exit	; if flag is not zero, dont update lcd screen
	JSR LCD_OUTPUT

oc7_exit RTI

;***********************************************************************
; Subroutine: INC_TIME
;
; Inputs: d_type
;
; Function: Increment time
;
; Subroutines called: none
;
; Modifies registers: A, B
;
; Returns: modifies: hrs, mins, secs & updates d_type on AM/PM rollovers
;***********************************************************************
INC_TIME
	INC t_secs 	; increment seconds
	
	LDAA t_secs
	CMPA #60	; if secs < 60: done incrementing time
	BLT incdone
	CLR t_secs	; else: clr secs and inc mins

	INC t_mins

	LDAA t_mins
	CMPA #60	; if mins < 60: done incrementing time
	BLT incdone
	CLR t_mins	; else: clr mins and inc hrs

	INC t_hrs

	LDAA t_hrs
	CMPA #12	; if hrs < 12: done incrementing time
	BLT incdone
			; else:
	LDAB d_type	; load in data type
	CMPB #'m'
	BEQ check24	; if d_type == 'm' move to check if hrs < 24
			; else: d_type was == 'a', change to 'p'
	MOVB #'p',d_type
	; modify lcd output str to end with PM
	MOVB #'P',ctimeL2+9	


check24	CMPA #24	; if hrs < 24: done incrementing time
	BLT incdone
	CLR t_hrs		; else: clear hrs and change d_type if needed

	CMPB #'m'
	BEQ incdone	; if d_type == 'm': no change
			; else: d_type was == 'p', change to 'a'
	MOVB #'a',d_type
	; modify lcd output str to end with AM
	MOVB #'A',ctimeL2+9	

; at end of increment time we need to update the string that is going to be output to the LCD screen
incdone	LDAB t_hrs	; load in value at current times hours
	BEQ zCase	; hours == 0 edge case
	CMPB #12	; if <=12 then dont modify, else subtract 12
	BLE dmodh	; dmodh - dont modify hours
	SUBB #12	; this effectively brings the value that will be output to lcd to hourrs modulo 12
	BRA dmodh
zCase	ADDB #12	; if hrs == 0 then add 12 (for 12am case)
dmodh	LDY #ctimeL2	; start of time output str
	JSR bin_to_ascii	; convert the binary value in register B to a 2 character ascii set



	LDAB t_mins	; load in value at current time minutes
	LDY #ctimeL2+3	; second set of XX (number values) in ctimeL2
	JSR bin_to_ascii

	LDAB t_secs	; val at seconds
	LDY #ctimeL2+6	; last set of XX in ctimeL2
	JSR bin_to_ascii

	RTS

;***********************************************************************
; Subroutine: LCD_OUTPUT
;
; Inputs: d_type
;
; Function: Output a formatted clock string
;
; Subroutines called: Printf
;
; Modifies registers: A, B
;
; Returns: Deletes old output string and outputs new time string (with updated time and format)
;***********************************************************************
LCD_OUTPUT
	; clear the display
	LDAA #$01
	JSR LCDCMD
	LDAA #33	; delay for ~1.65ms (wait for LCD screen to be ready after running clear disp. instruction)
twomslp	JSR _Delay50us	; 33*50us = 1.65ms
	DBNE A,twomslp
; output ctimeL1 to LCD screen
	LDX #ctimeL1
	
ctloop1	LDAA 1,X+
	BEQ mvcursor
	JSR LCDDATA
	BRA ctloop1

mvcursor
	LDAA #$C2
	JSR LCDCMD

	LDX #ctimeL2
ctloop2	LDAA 1,X+
	BEQ lcd_o_done
	JSR LCDDATA
	BRA ctloop2	; THIS IS THE LINE THAT WAS BREAKING THE CODE (still had prloop here instead of ctloop2)
lcd_o_done
	RTS

;***********************************************************************
; Subroutine: P_USER
;
; Inputs: X points to an output string
;
; Function: Prompt the user and accept a valid current time
;
; Subroutines: 
;
; Modifies registers: 
;
; Returns: 
;***********************************************************************
P_USER
prloop	LDAA 1,X+
	BEQ user
	JSR LCDDATA
	BRA prloop
; get user input for time
; using the LCD screen
user	; set DD ram address to first block on second line
	LDY #$C0	; sets ddram addr to $40, need leading 1 in bit 7, hence $C0
	TFR Y,A		; LCDCMD needs data in A, but we are using Y to keep track of where lcd is on screen
	JSR LCDCMD	
	LDX 2,SP	; load x with start of input buffer, this subroutine requires that 
			; X be pushed onto stack before brancing/jumping

	; get key press from keypad
g_time	JSR GETKEY
	; validate user input
		; Check for 'B' (backspace)
	CMPA #'B'
	BEQ bspace	; if button == 'B' then do a backspace
	BRA check0_9
bspace	DEY
	CPY #$C0
	BGE b
	LDY #$C0
	BRA g_time
b	TFR Y,A
	JSR LCDCMD
	LDAA #$FE
	JSR LCDDATA
	TFR Y,A
	JSR LCDCMD	
	PSHB
	JSR WAIT
	PULB
	DEX
	BRA g_time
		; check for '0' to '9'
check0_9
	CMPA #'0'
	BGE check9
	BRA g_time
check9	CMPA #'9'
	BLE oUserChar
	BRA g_time	; else just loop back to g_time
	; output keypress to LCD
oUserChar
	PSHA
	JSR LCDDATA	; A already contains ascii val from GETKEY
	; wait for key to be released
	PSHB
	JSR WAIT
	PULB
	; store val in time buffer
	INY	; move ddram addr tracker as accordingly?
	PULA
	STAA 1,X+
	CPY #$C6
	BLT g_time	
		
; convert user input from ascii string to binary vals
;	LDY #t_hrs	; hrs, mins, and secs are stored in memory consectutively
;	LDX #t_buff
;	JSR ascii_to_bin
;	LDY #a_hrs	; hrs, mins, and secs are stored in memory consectutively
;	LDX #a_buff
;	JSR ascii_to_bin
	
	LDX #t_hrs
	JSR V_TIME	; Turn the converted times into a valid range
	LDX #a_hrs
	JSR V_TIME	; Turn the converted times into a valid range	
	RTS

;***********************************************************************
; Subroutine: V_TIME
;
; Inputs: X points to hrs variable (either for time or alarm)
;
; Function: bring time values into a valid range
;
; Subroutines called: 
;
; Modifies registers: 
;
; Returns: 
;***********************************************************************
V_TIME	PSHA
	PSHX
	LDAA 0,X
hLoop	CMPA #24
	BGE shrs
	BRA vmins
shrs	SUBA #24
	BRA hLoop
vmins	STAA 1,X+
	LDAA 0,X
	CMPA #60
	BLE vsecs
	SUBA #60
vsecs	STAA 1,X+
	LDAA 0,X
	CMPA #60
	BLE d_valid
	SUBA #60
d_valid	STAA 1,X+
	PULX
	PULA
	RTS

;***********************************************************************
; Subroutine: ascii_to_bin
;
; Inputs: Y contains address of hrs/mins/secs continuous memory segments
;         X contains address of numbers to be converted
;
; Function: 
;
; Subroutines called: 
;
; Modifies registers: 
;
; Returns: 
;***********************************************************************
ascii_to_bin
	PSHY		; will compare 1 to y+2 later in subroutine
	INC 1,SP	; in order to know when to stop converting
	INC 1,SP
	
convert	LDAA 1,X+	; Load A with first byte of number to be converted
	SUBA #'0'	
	LDAB #10	; first sub the ascii val of 0 from char, then multiply by 10
	MUL		; first byte contains 10's digit of numbers
	ADDB 1,X+	; 2nd byte to current val, and sub ascii for 0 again
	SUBB #'0'
	STAB 1,Y+	; move on to next number to be converted (mins/secs)
	
	CPY 0,SP	; if Y is indexing past where seconds is held in memory we are done
	BLE convert	; if Y is still less than or equal to secs addr, then continue

	LEAS 2,SP	; reset stack

	RTS

;***********************************************************************
; Subroutine: bin_to_ascii
;
; Inputs: Y contains addr of string being modified (pointer to first of
; 	   2 bytes), B contains binary information being converted
;
; Function: bring time values into a valid range
;
; Subroutines called: none
;
; Modifies registers: X,D
;
; Returns: values stored in y str are updated
;***********************************************************************
bin_to_ascii
	CLRA		; Division uses all of register D, Since B is the only information we care about, clear A
	LDX #10		; numbers are in base 10
	IDIV		; (D) / (X) => X, D has remainder (D =~ hrs, mins, seconds) / 10
			; X will contain 10's place, D will contain ones place
	ADDD #$30	; change our binary result to the ascii val
	STAB 1,Y	; store ones digit result at 2nd byte of the str, str ptr is passed by value to this func.
	TFR X,D		; Move tens place result into D
	ADDD #$30	; Move to ascii representation of binary value
	STAB 0,Y	; store 10's digit in first byte of str

	RTS

;***********************************************************************
; Subroutine: GETKEY
;
; Inputs: none
;
; Function: return ascii value of key pressed
;
; Subroutines called: _Delay5ms, GETSWNU
;
; Modifies registers: A
;
; Returns: (A) = ASCII value of keypad key press
;***********************************************************************
GETKEY	PSHY 		; Preserves Register Y
	PSHB 		; Preserves Register B
	
KEYSCAN CLR PORTA 	; All Coulmns active low
	LDAB PORTA
	COMB
	ANDB #$F0 	; Masked off unknown bits
	BEQ KEYSCAN

	JSR _Delay5ms
;step 2
	CLRB
	MOVB #$07, PORTA
	JSR GETSWNU
	BPL KEYVALUE
;step 3
	LDAB #$04
	MOVB #$0B, PORTA
	JSR GETSWNU
	BPL KEYVALUE
;step 4
	LDAB #$08
	MOVB #$0D, PORTA
	JSR GETSWNU
	BPL KEYVALUE
;step 5
	LDAB #$0C
	MOVB #$0E, PORTA
	JSR GETSWNU
	BPL KEYVALUE
;step 6
	BRA KEYSCAN
;step 7
keys	DC.B "ABCD369F2580147E"
KEYVALUE LDY #keys
	ABA
	LDAA A,Y
	PULB
	PULY
	RTS
	
;***********************************************************************
; Subroutine: GETSWNU
;
; Inputs: none
;
; Function: return row # (0-3) or $FF if no key
;
; Subroutines called: none
;
; Modifies registers: A
;
; Returns: (A) = row # or $FF
;***********************************************************************
GETSWNU
	PSHB
	LDAB PORTA
	LDAA #$04

GETNXT	LSLB
	BCC GETDONE
	DBNE A,GETNXT
	CLRA
GETDONE DECA
	PULB
	RTS

;***********************************************************************
; Subroutine: WAIT
;
; Inputs: 
;
; Function: wait until keys are released
;
; Subroutines called: 
;
; Modifies registers: 
;
; Returns: 
;***********************************************************************
WAIT	CLR PORTA
	LDAB PORTA
	CMPB #$F0
	BNE WAIT
	RTS
;***********************************************************************
; Subroutine: UPDATE_7_SEGs
;
; Inputs: 
;
; Function: 
;
; Subroutines: 
;
; Modifies registers: 
;
; Returns: 
;***********************************************************************
UPDATE_7_SEGs
	LDAB t_hrs
	LDY #LEDdigs
	JSR bin_to_ascii
	
	LDAB LEDdigs
	SUBB #$30
	STAB LEDdigs
	LDAB LEDdigs+1
	SUBB #$30
	STAB LEDdigs+1

	LDAB t_mins
	LDY #LEDdigs+2
	JSR bin_to_ascii

	LDAB LEDdigs+2
	SUBB #$30
	STAB LEDdigs+2
	LDAB LEDdigs+3
	SUBB #$30
	STAB LEDdigs+3

	RTS 
