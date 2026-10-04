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

OC7_VEC_NUM EQU 48	; OC7 vector number for setting user vector
IRQ_VEC_NUM EQU 38	; IRG vector number

; d-bug 12 subroutines used in program
SetUserVector EQU $EEA4		

; string const chars
NULL	EQU $00

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
snoozeC	DCB 1	; snooze counter
d_type	DCB 1	; char for how to format output to user - NOT SURE IF WE CAN GET RID OF IT (USED IN INC_TIME LOGIC)
lcd_flg DCB 1	; flag for how to output to user every second
aflg	DCB 1	; alarm flag register 
;Bit0: Display Alarm time Bit2: Alarm enalbe/disable Bit3: Alarm is sounded Bit4: snoozing

; strings used in program subroutines, to prompt user input
tPrompt	DC.B "Input time: ",NULL
aPrompt DC.B "Alarm time:",NULL
Ascreen DC.B "   ",$EF,"ALARM!",$EF,$3A,$28,NULL

; current time and alarm time strings for output to lcd screen
ctimeL1	DC.B "  Current Time",NULL
ctimeL2	DC.B "00:00:00 AM   ",NULL
atimeL1	DC.B "  Alarm Time",NULL
atimeL2	DC.B "00:00:00 AM   ",NULL

currDay	DCB 1
dPrompt	DC.B "What day?(1-7)", NULL
days	DC.B "MTWRFSU"

;***********************************************************************
; Subroutine: main
;
; Inputs: none
;
; Function: main loop of alarm clock final project
;
; Subroutines called: LCD_INIT, ECT_INIT, LED_Init, INPUT_CURR_TIME, 
;			GETKEY, WAIT, CLR_LCD, P_User, ascii_to_bin, 
;			V_TIME, bin_to_ascii, PRINT_TO_LCD, LCDCMD
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
; initialize button press interrupt
	JSR PTH_INIT

; Get current time
	JSR INPUT_CURR_TIME

;unmask interrupts and initialize d_type to m (clock initially outputs in military time - same as default input)
	;MOVB #'m',d_type
	BSET TIE,$80
	CLR aflg	; clear alarm flag register
	CLI

; NOW WE ENTER THE INFINITE LOOP
; Get a char from user to change output or quit program loop
floop	JSR GETKEY
	JSR WAIT	; get user input and wait for key to be released

; 'A' - selects to (re)enter the alarm time
	CMPA #'A'
	BNE chkB

	INC lcd_flg	; set lcd output flag to 1, output 'enter alarm' string
	; clear the display
	JSR CLR_LCD
	; output for alarm time
	LDX #a_buff	; pointer to input buffer on stack
	PSHX
	LDX #aPrompt	; prompt 2 = "Alarm time:" - prompt user to enter alarm time
	JSR P_User
	LDY #a_hrs	; hrs, mins, and secs are stored in memory consectutively
	LDX #a_buff
	JSR ascii_to_bin
	; validate the inputted alarm time
	LDX #a_hrs
	JSR V_TIME	; Turn the converted times into a valid range	
	PULX		; reset stack
	; convert the alarm time to output str chars
	LDY #atimeL2
	LDAB a_hrs	; Logic for outputting correct hrs in AM/PM format
	BEQ a12a	; if hrs = 0, add 12
	CMPB #12
	BGT s12a	; if hrs > 12 subtract 12
	BRA b2a		; else: 0<hrs<=12 ie. a valid number
a12a	ADDB #12
	BRA b2a
s12a	SUBB #12

b2a	JSR bin_to_ascii	; convert alarm hrs val to 2 ascii chars, store in hrs portion of Alarm time string
	LDY #atimeL2+3
	LDAB a_mins
	JSR bin_to_ascii	; convert alarm mins val to 2 ascii chars, store in minutes portion of Alarm time string
	LDY #atimeL2+6
	LDAB a_secs
	JSR bin_to_ascii	; convert alarm secs val to 2 ascii chars, store in seconds portion of Alarm time string

	; initialize 9th char in LCD line 2 output string
	LDAA a_hrs	; load a with inputted hours
	CMPA #12	; if greater than or = 12, store P in lcd output str
	BGE a_pm	; else: store A
	; modify lcd output str to end with AM
	MOVB #'A',atimeL2+9
	BRA aDone
	; modify lcd output str to end with PM
a_pm	MOVB #'P',atimeL2+9	

aDone	CLR lcd_flg	; reset lcd output flag to default output

	BRA floop	; we are done with this key presses logic - branch to next key press

; 'B' - selects to snooze the alarm if sounded
chkB	CMPA #'B'
	BNE chkC
	LDAA aflg	; if bit 3 is clear do nothing (alarm is disabled)
	ANDA #$08
	BEQ floop	; do nothing, get next user input
	; if alarm is set
	MOVB #60,snoozeC	; set snooze counter to 60 (seconds)
	BSET aflg, $10	; set snooze flag
	BCLR aflg, $08	; clear alarm flag
	CLR lcd_flg	; allow ECT interrupt to change lcd screen

	LBRA floop	; go to next key press

; 'C' - selects to re-enter current time
chkC	CMPA #'C'
	BNE chkD
	INC lcd_flg	; disable ECT interrupt from updating screen

	; clear the display
	JSR CLR_LCD

	JSR INPUT_CURR_TIME	; re-prompt the user for current time
	CLR lcd_flg		; INPUT_CURRENT_TIME handles logic for us, just need to enable ECT interrupt to update LCD screen
	BRA doNot
	
; 'D' - display alarm time (instead ofclock time)
chkD	CMPA #'D'
	BNE chkstar

	INC lcd_flg	; disable ECT interrupt from updating screen

	LDAA aflg	; Alarm display flag
	ANDA #$01	; checks bit 0 ^
	BEQ iaflg	; Toggle bit zero on 'D' key-press
	BCLR aflg, $01
	BRA havoc	; after clearing Alarm disp. flg - tell the interrupt it can change the screen
iaflg	BSET aflg, $01	; Set the flag and output alarm time
	; clear the display
	JSR CLR_LCD

	LDX #atimeL1	; print out first line of alarm time screen
	JSR PRINT_TO_LCD

	LDAA #$C2	; sets the cursor to LCD line 2 col 3
	JSR LCDCMD

	LDX #atimeL2
	JSR PRINT_TO_LCD	; print out second line of alarm time screen

	BRA doNot
havoc	CLR lcd_flg
	BRA doNot

; '*' - turns off the alarm if the alarm is sounded
chkstar	CMPA #'*'
	BNE chkhsh
	BRCLR aflg, $08, doNot	; if alarm not sounded do nothing
	BCLR aflg, $08		; else: clear alarm is sounded flag
	CLR lcd_flg	; clear the flag that is stopping the lcd from being updated in the ECT ISR
	BRA doNot

; '#' - toggles the alarm enable/disable in clock mode and updates output string
chkhsh	CMPA #'#'
	BNE doNot
	
	JSR TOGGLE_A

doNot	LBRA floop

;***********************************************************************
; Subroutine: PTH_INIT
;
; Inputs: none
;
; Function: set up interrupts for button presses through port H
;
; Subroutines called: SetUserVector
;
; Modifies registers: D
;
; Returns: interrupt vector set for port h button presses
;***********************************************************************
PTH_INIT
	CLR DDRH	; push buttons will be inputs
	BSET PERH, $0E	; enable pull up on port h pins 3, 2, 1
	BCLR PERH, $0E
	BSET PIEH, $0E	; enable interrupts on portH pin 3, 2, 1

; set the interrupt vector for portH key-wake-ups
	LDD #button_press
	PSHD
	LDD #IRQ_VEC_NUM
	JSR [SetUserVector,PCR]
	LEAS 2,SP

	RTS
;***********************************************************************
; Subroutine: button_press
;
; Inputs: 
;
; Function: Interrupt service routine for port h button presses
;
; Subroutines called: TOGGLE_A
;
; Modifies registers: 
;
; Returns: Action associated to each button press (if valid for machine state)
;***********************************************************************
button_press
	BSET PIFH, $0E	; clear all interrupt flags that could be set
; allow for preemption - so that the clock can keep updating	
	CLI
; de-code to which button is pressed
	BRCLR PTH, $08, h3loop	; if push button 3 is pressed do logic for snooze
	BRCLR PTH, $04, h2loop	; if push button 2 is pressed do logic for turning off alarm
	BRCLR PTH, $02, h1loop	; if push button 1 is pressed do logic for toggling alarm enable
	BRA doneI

; wait for button to be released
h3loop	BRCLR PTIH, $08, h3loop
	BRCLR aflg, $08, doneI	; if alarm is not sounded do nothing
	; if alarm is set
	MOVB #60,snoozeC	; set snooze counter to 60 (seconds)
	BSET aflg, $10	; set snooze flag
	BCLR aflg, $08	; clear alarm flag
	CLR lcd_flg	; allow ECT interrupt to change lcd screen
	BRA doneI

; wait for button to be released
h2loop	BRCLR PTIH, $04, h2loop

	BRCLR aflg, $08, doneI	; if alarm not sounded do nothing
	BCLR aflg, $08		; else: clear alarm is sounded flag
	CLR lcd_flg	; clear the flag that is stopping the lcd from being updated in the ECT ISR

	BRA doneI

; wait for button to be released
h1loop	BRCLR PTIH, $02, h1loop

	JSR TOGGLE_A

	BRA doneI

doneI	RTI
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
	LDD #OC7_VEC_NUM
	JSR [SetUserVector,PCR]
	LEAS 2,SP

	RTS

;***********************************************************************
; Subroutine: OC7_ISR
;
; Inputs: aflg (bit 4 - snoozing & bit 3 - alarm enable), lcd_flg, 
;		LEDctl (toggling colon on 7-seg)
;
; Function: Service routine for OC7 interrupt. Every second it handles
;		alarm checking, updating the LCD (sometimes), snoozing
;		and updating values for the 7 segment displays
;
; Subroutines called: INC_TIME, LCDCMD, _DELAY5ms, PRINT_TO_LCD, 
;			UPDATE_7_SEGs, LCD_OUTPUT
;
; Modifies registers: none
;
; Returns: Modifies current time every second, changes the output to LCD screen
;		toggles the semicolon ouput for 7-seg displays, updates 
;		values for 7-seg display interrupt routine
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
	JSR INC_TIME

	; check bit 4 of aflg - we are snoozing
	BRCLR aflg, $10, acheck	; if not snoozing dont do anything
	BRCLR aflg, $04, cancel ; check if alarms are enabled
	DEC snoozeC	; else, dec counter
	BEQ goAlarm	; if counter = zero set off alarm
	BRA u7s		; else: update 7 segment displays

	; set flag so ECT interrupt does not update screen
goAlarm	INC lcd_flg
	BSET aflg, $08	; set bit corresponding to alarm is sounded
	BCLR aflg, $10
	; clear LCD screen
	JSR CLR_LCD
	; print 'ALARM!!!' to LCD
	LDX #Ascreen
	JSR PRINT_TO_LCD
	BRA u7s

cancel	BCLR aflg, $10	; clear alarm flag - so the alarm does not go off
	CLR snoozeC	; clear counter
	BRA u7s		; update 7-segment displays

acheck	BRCLR aflg, $04, u7s ; check if alarms are enabled
			; if disabled, skip to updating 7 segments displays
	JSR ALARM	; see if new current time = alarm time, changes LCD display

u7s	JSR UPDATE_7_SEGs	
	BRSET LEDctl, $80, clrBit	; toggle the big for colon on 7 seg disp
	BSET LEDctl, $80		; if clr: set the bit
	BRA o2lcd
clrBit	BCLR LEDctl, $80		; if set: clr the bit

o2lcd	LDAA lcd_flg
	BNE oc7_exit	; if flag is not zero, dont update lcd screen
	JSR LCD_OUTPUT

oc7_exit RTI

;***********************************************************************
; Subroutine: INPUT_CURR_TIME
;
; Inputs: t_hrs (for initialzing d_type)
;
; Function: Prompt user to input the current time. Convert and validate input,
;		and initialize AM/PM output in output array and d_type
;
; Subroutines called: 
;
; Modifies registers: X, Y, A
;
; Returns: User inputted time is updated/initialized, converted, and validated.
;		Output is in correct formats. Clears screen before return
;***********************************************************************
INPUT_CURR_TIME
; Prompt the user and accept a valid current time
	LDX #t_buff	; put pointer to input buffer on stack
	PSHX
	LDX #tPrompt	; prompt 1 = "Input time:" - prompt user for start clock time
	JSR P_User
	PULX		; reset stack?

	JSR GET_DAY

	LDY #t_hrs	; hrs, mins, and secs are stored in memory consectutively
	LDX #t_buff
	JSR ascii_to_bin

; validate time
	LDX #t_hrs
	JSR V_TIME	; Turn the converted times into a valid range

	; clear the display
	JSR CLR_LCD

; initialize 9th char in LCD line 2 output string, and load d_type with the appropriate value
	LDAA t_hrs	; load a with inputted hours
	CMPA #12	; if greater than or = 12, store P in lcd output str
	BGE its_pm	; else: store A
	; modify lcd output str to end with AM, and alter d_type
	MOVB #'A',ctimeL2+9
	MOVB #'a',d_type
	BRA tDone
	; modify lcd output str to end with PM, and change d_type
its_pm	MOVB #'P',ctimeL2+9	
	MOVB #'p',d_type

tDone	RTS

;***********************************************************************
; Subroutine: INC_TIME
;
; Inputs: d_type, and t_hrs, t_mins, t_secs (for checking rollovers and
;		updating output string)
;
; Function: Increment time, and update the characters in the current time
;		output string
;
; Subroutines called: bin_to_ascii
;
; Modifies registers: A, B, Y, CCR
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
	JSR UPDATE_DAY

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
; Inputs: current time output strings
;
; Function: Output the current time to the LCD screen
;
; Subroutines called: CLR_LCD, PRINT_TO_LCD
;
; Modifies registers: A, B
;
; Returns: Current time is outputted on the LCD screen
;***********************************************************************
LCD_OUTPUT
	JSR CLR_LCD
; output ctimeL1 to LCD screen
	LDX #ctimeL1
	
	JSR PRINT_TO_LCD

;move cursor
	LDAA #$C2
	JSR LCDCMD

; output ctimeL2 to LCD screen
	LDX #ctimeL2
	JSR PRINT_TO_LCD

	RTS

;***********************************************************************
; Subroutine: P_USER
;
; Inputs: X contains a string to print to LCD, a pointer to an input buffer 
;		is on the stack.
;	  Key-presses from keypad (user input)
;
; Function: Prompt the user for a time. Store ascii values of valid key
;		presses into an input buffer.
;
; Subroutines called: PRINT_TO_LCD, LCDCMD, LCDDATA, GETKEY, WAIT
;
; Modifies registers: D, CCR, X, Y
;
; Returns: User key presses are stored in the input buffer
;***********************************************************************
P_USER
	JSR PRINT_TO_LCD
; get user input for time
; using the LCD screen
	; set DD ram address to first block on second line
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
bspace	DEY		; move cursor tracker backwards
	CPY #$C0	; is overstepped -> reset to $C0, and do nothing (get next key)
	BGE b
	LDY #$C0
	BRA g_time

b	TFR Y,A		; else: move cursor to that location
	JSR LCDCMD	; needs data in (A)
	LDAA #$FE
	JSR LCDDATA	; ouput a space (essentially deletes the char in that space on LCD)
	TFR Y,A
	JSR LCDCMD	; move the cursor back again
	PSHB
	JSR WAIT	; wait for key to be released
	PULB
	DEX		; decrement index into input buffer 
	BRA g_time	; get next key press

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
	PSHA	; there was some weird stuff going on with registers (hence the following pushing and pulling)
	JSR LCDDATA	; A already contains ascii val from GETKEY

	PSHB
	JSR WAIT	; wait for key to be released
	PULB

	INY	; move ddram addr tracker as accordingly
	PULA		; A was getting modified somewhere, push and pull around problem area
	STAA 1,X+	; store val in time buffer
	CPY #$C6	; once ddram addr passes 6 chars, we have filled the input buffer (we are done)
	BLT g_time	; if not passed 6 key press inputs, get more
			
	RTS

;***********************************************************************
; Subroutine: V_TIME
;
; Inputs: X points to hrs variable (either for time or alarm)
;
; Function: bring time values into a valid range
;
; Subroutines called: none
;
; Modifies registers: none
;
; Returns: time values are modulo'd into a valid range
;***********************************************************************
V_TIME	PSHA
	PSHX
	LDAA 0,X	; load in hours
hLoop	CMPA #24
	BGE shrs	; if >= 24, sub 24
	BRA vmins	; else: hrs is valid
shrs	SUBA #24	; sub 24 then check again
	BRA hLoop	; input hrs could be up to 99 -> may need to sub 24 multiple times

vmins	STAA 1,X+	; store hrs value, load in minutes value
	LDAA 0,X
	CMPA #60	; if mins < 60 - valid
	BLT vsecs
	SUBA #60	; else: sub 60

vsecs	STAA 1,X+	; store mins val, load in seconds
	LDAA 0,X
	CMPA #60	; same logic as minutes
	BLT d_valid
	SUBA #60

d_valid	STAA 1,X+	; store seconds val
	PULX
	PULA
	RTS
;***********************************************************************
; Subroutine: ALARM
;
; Inputs: t_hrs, t_mins, t_secs and a_hrs, a_mins, a_secs for comparing
;		current and alarm times
;
; Function: compares current time to alarm time
;
; Subroutines called: CLR_LCD, PRINT_TO_LCD
;
; Modifies registers: A
;
; Returns: if alarm is sounded, the LCD screen is updated, and the
;		corresponding flags are set (aflg bit 3 and lcd_flg)
;***********************************************************************
ALARM
	PSHA
; load in current hrs, compare with alarm hours
	LDAA t_hrs
	CMPA a_hrs
	BNE no_alarm
; load in current minutes, compare with alarm minutes
	LDAA t_mins
	CMPA a_mins
	BNE no_alarm
; load in current seconds, compare with alarm seconds
	LDAA t_secs
	CMPA a_secs
	BNE no_alarm
; if all are equal then do stuff
	; set flag so ECT interrupt does not update screen
	INC lcd_flg
	BSET aflg, $08	; set bit corresponding to alarm is sounded
	; clear LCD screen
	JSR CLR_LCD
	; print 'ALARM!!!' to LCD
	LDX #Ascreen
	JSR PRINT_TO_LCD

no_alarm
	; clear alarm flag - bit3 of aflg
	PULA
	RTS

;***********************************************************************
; Subroutine: ascii_to_bin
;
; Inputs: Y contains address of hrs/mins/secs continuous memory segments
;         X contains address of numbers to be converted
;
; Function: Convert a series of ascii valued numbers (3 consecutive 2-byte pairs)
;		into a single binary (byte) value.
;
; Subroutines called: none
;
; Modifies registers: Y, X, D, CCR
;
; Returns: numbers are converted and stored in memory
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
; Inputs: PORTA (Keypad presses - user input)
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
keys	DC.B "ABCD369#2580147*"
KEYVALUE LDY #keys
	ABA
	LDAA A,Y
	PULB
	PULY
	RTS
	
;***********************************************************************
; Subroutine: GETSWNU
;
; Inputs: PORTA
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
; Inputs: PORTA
;
; Function: wait until keys are released
;
; Subroutines called: none
;
; Modifies registers: B
;
; Returns: when the button is released
;***********************************************************************
WAIT	CLR PORTA
	LDAB PORTA
	CMPB #$F0
	BNE WAIT
	RTS

;***********************************************************************
; Subroutine: UPDATE_7_SEGs
;
; Inputs: t_hrs (current hours), t_mins (curr mins)
;
; Function: update the values stored in the register used by RTI interrupt
;		that manages the 7 segment displays
;
; Subroutines called: bin_to_ascii
;
; Modifies registers: B, Y
;
; Returns: values stored in LEDdigs memory segment are updated
;***********************************************************************
UPDATE_7_SEGs
	LDAB t_hrs	; Convert the binary value for current time hrs to 2 ascii characters
	LDY #LEDdigs
	JSR bin_to_ascii
	
	LDAB LEDdigs	; the bin_to_ascii function stores ascii values, we need them in binary
	SUBB #$30
	STAB LEDdigs	; store back in correlated LEDdigs memory location
	LDAB LEDdigs+1
	SUBB #$30
	STAB LEDdigs+1

	LDAB t_mins	; Convert the binary value for current time minutes to 2 ascii characters
	LDY #LEDdigs+2
	JSR bin_to_ascii

	LDAB LEDdigs+2	; tens digit values
	SUBB #$30
	STAB LEDdigs+2
	LDAB LEDdigs+3	; ones digit value
	SUBB #$30
	STAB LEDdigs+3

	RTS 

;***********************************************************************
; Subroutine: CLR_LCD
;
; Inputs: none
;
; Function: clear the LCD display
;
; Subroutines: LCDCMD
;
; Modifies registers: none 
;
; Returns: LCD display is cleared
;***********************************************************************
CLR_LCD
	PSHA
	; clear the display
	LDAA #$01
	JSR LCDCMD
	LDAA #33	; delay for ~1.65ms (wait for LCD screen to be ready after running clear disp. instruction)
twomslp	JSR _Delay50us	; 33*50us = 1.65ms
	DBNE A,twomslp

	PULA
	RTS

;***********************************************************************
; Subroutine: PRINT_TO_LCD
;
; Inputs: X points to string (NULL terminated) to output to LCD screen
;
; Function: Print the string to the LCD screen 
;
; Subroutines: LCDDATA
;
; Modifies registers: none
;
; Returns: The string is output to the LCD screen
;***********************************************************************
PRINT_TO_LCD
	PSHA
	PSHX

prloop	LDAA 1,X+
	BEQ prdone
	JSR LCDDATA
	BRA prloop

prdone	PULX
	PULA
	RTS

;***********************************************************************
; Subroutine: TOGGLE_A
;
; Inputs: aflg bit 2 (alarm enable)
;
; Function: Toggle alarm enable bit in aflg and corresponding char in
;		output string 
;
; Subroutines: none
;
; Modifies registers: A
;
; Returns: Char in output str is either 'A' or ' '
;***********************************************************************
TOGGLE_A
	; check the bit 2 in aflg - Alarm enable/disable
	LDAA aflg
	ANDA #$04
	BEQ del_A
	; if set, clr the bit and modify last char in ctimeL2 to ' '
	BCLR aflg, $04	; clrs bit 2
	MOVB #' ',ctimeL2+13
	BRA tog_done
	; if clr, set bit and change last char in ctimeL2 to 'A'
del_A	BSET aflg, $04	; sets bit 2
	MOVB #'A',ctimeL2+13
tog_done
	RTS

;***********************************************************************
; Subroutine: GET_DAY
;
; Inputs: Y contains to day variable pointer
;
; Function: get the day of the week from user
;
; Subroutines caleed: 
;
; Modifies registers: 
;
; Returns: 
;***********************************************************************
GET_DAY
	JSR CLR_LCD
	
	LDX #dPrompt
	JSR PRINT_TO_LCD

gNUM	JSR GETKEY
	JSR WAIT

	CMPA #'1'
	BLT gNUM
	CMPA #'7'
	BGT gNUM

	SUBA #'2'
	STAA currDay
	JSR UPDATE_DAY

	RTS
;***********************************************************************
; Subroutine: UPDATE_DAY
;
; Inputs: 
;
; Function: Update day in current time output string
;
; Subroutines caleed: 
;
; Modifies registers: 
;
; Returns: 
;***********************************************************************
UPDATE_DAY
	PSHA
	PSHX

	LDAA currDay	; load in number for current day
	INCA		; increment
	CMPA #6		; max day num = 7
	BGT sub7
	BRA chgDay
sub7	SUBA #7
chgDay	STAA currDay
	LDX #days
	LDAA A,X
	STAA ctimeL2+12

	PULX
	PULA
	RTS
