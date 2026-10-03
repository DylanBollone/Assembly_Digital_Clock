;***************************************************************
; PROGRAM: LED_DISPLAY
; NAME: Andrew Jones
; DATE: 10/24/25
; FUNCTION: Provided code to control the 4 digit, 7-seg LEDs
;     Uses time multiplexing over 4 digits
;     Real Timer Interrupt (RTI) used to maintain timing
;  Dragon12-Light.
;  D-Bug12v4.x.x
;***************************************************************
;
;  Callable routine:   LED_Init
;  Global memory for control ($10FB - $10FF):
;     LEDdigs:  4 byte block, each byte contain digit to display
;                 values should be 0 to 9 for each digit
;                 the LED bit pattern is decoded in routine
;     LEDctl:   LED display control (bit control)
;                [7] - display colon between digits 2 and 3 
;                      0 = no colon, 1 = colon
;                [2-0] - 3 bit value for how many LEDs are on
;                  example, %100 would have all 4 LEDs being used
;  Works with RTI, PORTB and PORTP
;  Must clear the I flag for proper operation (functional RTI)
;
;  Code/tables located at $3A80 - $3AFE - do not use this space!
;
;***************************************************************
; Include External Subroutine Files
;***************************************************************
#ifndef PORTA
#include "Reg9s12.inc"
#endif

;
;All hardware on Dragon12-Light
;

; Port B [0-7] connects to 7-seg LEDs (4 multiplexed) PB.0 = segA... PB.7 = dp  (1=LED on)
; Port P [0-3] connects to 7-seg LEDs (common cathode) (0=LED digit is on)

 

; D-Bug12 subroutines
#ifndef _SetUVector
_SetUVector EQU  $EEA4
#endif

; interrupt information, other constants
_RTI_VEC_NO	EQU 56	;RTI vector number


         ORG  $3A80  ; start of all memory (variables and code)	
 ; global variables
LEDdigs  DCB  4		; set values for each digit to display
LEDctl   DCB  1


;************************************************************
;Example code to display 1234 on LED, no Colon:
;        ORG  $2000
;example   
;        JSR  LED_INIT	; initialize the 4 7-seg LEDs
;        MOVB #1,LEDdigs
;        MOVB #2,LEDdigs+1		
;        MOVB #3,LEDdigs+2
;        MOVB #4,LEDdigs+3 ; move 1234 into memory for display
;        MOVB #$04,LEDctl ; no colon displayed, 4 digits
		
;        CLI		; start the RTI, display
;lp      BRA  lp

		
		
;************************************************************
; LED_INIT - initialize ports for LED (x4 7-seg LEDs) 
;  All LEDs off
;  Assumes OSCCLK is 8MHz to interrupt at 4.096ms
;  Modifies: X and D
;************************************************************
LED_Init
        MOVB #$FF,DDRB	; PORTB all outputs (LEDs off)
        LDAA #$0F
        STAA PTP	; all digits disabled
        STAA DDRP	; enable all cathodes (outputs)
        CLRA
        STAA PORTB
        CLRB
        STD  LEDdigs
        STD  LEDdigs+2	; initially display 0000 on LEDs
        CLR  _led_dg	; start on digit 0
		
        MOVB #$60,RTICTL	; divide 2^15
        BSET CRGINT,$80		; enable RTI interrupt
        LDD  #_RTIisr
        PSHD
        LDD  #_RTI_VEC_NO
        JSR  [_SetUVector,PCR]
        PULD
        RTS


; global variables used by LED routines
_led_dg  DCB  1	; which digit currently active in display?


; global contants, look-up arrays
_DIG_LUT DC.B  $0E, $0D, $0B, $07	; digit 3,2,1,0 (left to right)
_7SEGLUT DC.B $3F,$06,$5B,$4F,$66,$6D,$7D,$07,$7F,$6F	; 0123456789 (7-seg)

;***************************************************************
; Subroutine: _RTI_ISR
; Inputs: none, called by RTI (once I flag is cleared)
; Function: periodic interrupt 4.096ms
; Subroutines called:  _DLDout
; Modifies registers:  none
; Returns: nothing
;***********************************************************************				
_RTIisr	BSET CRGFLG,$80	; clear device flag

        LDX  #LEDdigs
        LDAB _led_dg
        LDAA b,x	; get value of digit to display
        BSR  _DLDout	; display digit at correct spot
        INCB		; update led_dig to next digit
        LDAA LEDctl
        ANDA #$07	; obtain number of digits to display
        CBA
        BNE  _L_OUT1	; MOD # of digits
        CLRB		
_L_OUT1 STAB _led_dg	; store updated value

_rtiend	RTI



;***************************************************************
; _DLDout - output Hex to 7seg LED display
;  (A) contains the number [0-9]
;  (B) contains which digit [0-3]
;  Modifies register X
;  returns nothing (7seg display - portB/P) is active
;***************************************************************
_DLDout PSHD

        LDX  #_7SEGLUT
        LDAA a,x	; obtain 7-seg value for digit
        BRCLR LEDctl,$80,_DLD_p2
        TSTB
        BEQ  _DLD_p2	; if digit 1,2; add DP (colon)
        CMPB #3
        BEQ  _DLD_p2
        ORAA #$80	; add DP to digit

_DLD_p2 STAA PORTB	; set LED (7-seg) data 

        LDX  #_DIG_LUT
        LDAA b,x
        STAA PTP	; set which digit [0-3]

        PULD		; restore register
        RTS
		
