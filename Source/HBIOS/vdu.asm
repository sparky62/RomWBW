;======================================================================
;	VDU DRIVER FOR ECB-VDU PROJECT
;
;	ORIGINALLY WRITTEN BY: ANDREW LYNCH
;	REVISED/ENHANCED BY DAN WERNER -- 11/7/2009
;	ROMWBW ADAPTATION BY: WAYNE WARTHEN -- 11/9/2012
;	80X25, 80X30 AND MODE INFO AT BOOT ADDED BY: PHIL SUMMERS -- 2/3/2019
;	ADD CURSOR STYLE OPTIONS, IMPLEMENT VDU_VDASCS FUNCTION : PHIL SUMMERS -- 19/10/2019
;======================================================================
;
;	VDU-DW.ZIP IS THE DEFAULY 10X8 FONT THAT SUITS 80X25 AND 80X26 MODE.
;	IN 80X30 MODE THE DESCENDERS ARE MISSING. AN ALTERNATE 8x8 FONT MAY
;	DISPLAY BETTER. THIS CAN BE ADDED TO THE ECB-VDU FONT EPROM AND
;	SELECTED VIA ONBOARD JUMPERS. THE FONT ROM CAN CONTAIN EIGHT 2Kb FONTS.
;
; TODO:
;   - ADD REMAINING REGISTERS TO INIT
;   - IMPLEMENT ALTERNATE DISPLAY MODES?
;
;======================================================================
; VDU DRIVER - CONSTANTS
;======================================================================
;
VDU_BASE	.EQU	$F0
;
VDU_RAMRD	.EQU	VDU_BASE + $00	; READ VDU
VDU_RAMWR	.EQU	VDU_BASE + $01	; WRITE VDU
VDU_STAT	.EQU	VDU_BASE + $02	; VDU STATUS/REGISTER
VDU_REG		.EQU	VDU_BASE + $02	; VDU STATUS/REGISTER
VDU_DATA	.EQU	VDU_BASE + $03	; VDU DATA REGISTER
VDU_PPIA	.EQU	VDU_BASE + $04	; PPI PORT A
VDU_PPIB	.EQU	VDU_BASE + $05	; PPI PORT B
VDU_PPIC	.EQU	VDU_BASE + $06	; PPI PORT C
VDU_PPIX	.EQU	VDU_BASE + $07	; PPI CONTROL PORT
;
VDU_NOBL	.EQU	00000000B	; NO BLINK
VDU_NOCU	.EQU	00100000B	; NO CURSOR
VDU_BFAS	.EQU	01000000B	; BLINK AT X16 RATE
VDU_BSLO	.EQU	01100000B	; BLINK AT X32 RATE
;
VDU_BLOK	.EQU	0		; BLOCK CURSOR
VDU_ULIN	.EQU	1		; UNDERLINE CURSOR
;
VDU_CSTY	.EQU	VDU_BLOK	; DEFAULT CURSOR STYLE
VDU_BLNK	.EQU	VDU_NOBL	; DEFAULT BLINK RATE
;
TERMENABLE	.SET	TRUE		; INCLUDE TERMINAL PSEUDODEVICE DRIVER
;
#IF (VDUSIZ=V80X24)
DLINES		.EQU	24
DROWS		.EQU	80
DSCANL		.EQU	10
#ENDIF
#IF (VDUSIZ=V80X25)
DLINES		.EQU	25
DROWS		.EQU	80
DSCANL		.EQU	10
#ENDIF
#IF (VDUSIZ=V80X30)
DLINES		.EQU	30
DROWS		.EQU	80
DSCANL		.EQU	8
#ENDIF
#IF (VDUSIZ=V80X25B)
DLINES		.EQU	25
DROWS		.EQU	80
DSCANL		.EQU	12
#ENDIF
#IF (VDUSIZ=V80X24B)
DLINES		.EQU	24
DROWS		.EQU	80
DSCANL		.EQU	12
#ENDIF
;
#IF VDU_CSTY=VDU_BLOK
VDU_R10		.EQU	(VDU_BLNK + $00)
VDU_R11		.EQU	DSCANL-1
#ENDIF
;
#IF VDU_CSTY=VDU_ULIN
VDU_R10		.EQU	(VDU_BLNK + DSCANL-1)
VDU_R11		.EQU	DSCANL-1
#ENDIF
;
;======================================================================
; VDU DRIVER - INITIALIZATION
;======================================================================
;
VDU_INIT:
	LD	IY,VDU_IDAT		; POINTER TO INSTANCE DATA
;
	CALL	NEWLINE			; FORMATTING
	PRTS("VDU: IO=0x$")
	LD	A,VDU_RAMRD
	CALL	PRTHEXBYTE

	PRTS(" MODE=$")			; OUTPUT DISPLAY FORMAT
	LD	A,DROWS
	CALL	PRTDECB
	PRTS("X$")
	LD	A,DLINES
	CALL	PRTDECB

	CALL	VDU_PROBE		; CHECK FOR HW EXISTENCE
	JR	Z,VDU_INIT1		; CONTINUE IF HW PRESENT
;
	; HARDWARE NOT PRESENT
	PRTS(" NOT PRESENT$")
	OR	$FF			; SIGNAL FAILURE
	RET
;
VDU_INIT1:
	CALL 	VDU_CRTINIT		; INIT SY6845 VDU CHIP
	CALL	VDU_VDARES
	CALL	PPK_INIT		; INITIALIZE KEYBOARD DRIVER
;
	; ADD OURSELVES TO VDA DISPATCH TABLE
	LD	BC,VDU_FNTBL		; BC := FUNCTION TABLE ADDRESS
	LD	DE,VDU_IDAT		; DE := VDU INSTANCE DATA PTR
	CALL	VDA_ADDENT		; ADD ENTRY, A := UNIT ASSIGNED
;
	; INITIALIZE EMULATION
	LD	C,A			; ASSIGNED VIDEO UNIT IN C
	LD	DE,VDU_FNTBL		; DE := FUNCTION TABLE ADDRESS
	LD	HL,VDU_IDAT		; HL := VDU INSTANCE DATA PTR
	CALL	TERM_ATTACH		; DO IT

	XOR	A			; SIGNAL SUCCESS
	RET
;
;======================================================================
; VDU DRIVER - VIDEO DISPLAY ADAPTER (VDA) FUNCTIONS
;======================================================================
;
VDU_FNTBL:
	.DW	VDU_VDAINI
	.DW	VDU_VDAQRY
	.DW	VDU_VDARES
	.DW	VDU_VDADEV
	.DW	VDU_VDASCS
	.DW	VDU_VDASCP
	.DW	VDU_VDASAT
	.DW	VDU_VDASCO
	.DW	VDU_VDAWRC
	.DW	VDU_VDAFIL
	.DW	VDU_VDACPY
	.DW	VDU_VDASCR
	.DW	PPK_STAT
	.DW	PPK_FLUSH
	.DW	PPK_READ
	.DW	VDU_VDARDC
#IF (($ - VDU_FNTBL) != (VDA_FNCNT * 2))
	.ECHO	"*** INVALID VDU FUNCTION TABLE ***\n"
	!!!!!
#ENDIF
;
VDU_VDAINI:
	; RESET VDA
	; CURRENTLY IGNORES VIDEO MODE AND BITMAP DATA
	CALL	VDU_VDARES		; RESET VDA
	XOR	A			; SIGNAL SUCCESS
	RET

VDU_VDAQRY:
	LD	C,$00			; MODE ZERO IS ALL WE KNOW
	LD	DE,(DLINES*256)+DROWS	; D=DLINES, E=DROWS
	LD	HL,0			; EXTRACTION OF CURRENT BITMAP DATA NOT SUPPORTED
	XOR	A			; SIGNAL SUCCESS
	RET

VDU_VDARES:
	LD	DE,0
	LD	(VDU_OFFSET),DE
	CALL	VDU_XY
	LD	A,' '
	LD	DE,1024*16
	CALL	VDU_FILL

	XOR	A
	RET

VDU_VDADEV:
	LD	D,VDADEV_VDU	; D := DEVICE TYPE
	LD	E,0		; E := PHYSICAL UNIT IS ALWAYS ZERO
	LD	H,0		; H := 0, DRIVER HAS NO MODES
	LD	L,VDU_BASE	; L := BASE I/O ADDRESS
	XOR	A		; SIGNAL SUCCESS
	RET

VDU_VDASCS:
	LD	A,D		; GET CURSOR FINISH.
	AND	00001111B	; BOTTOM NIBBLE OF D
	LD	L,A		; SAVE IN L FOR R11

	LD	A,D		; GET CURSOR START.
	AND	11110000B	; TOP NIBBLE IF D
	RRCA
	RRCA
	RRCA			; COMBINE CURSOR START
	RRCA			; AND CURSOR STYLE AND
	OR	VDU_CSTY	; SAVE IN H FOR R10
	LD	H,A

	LD	C,10
	CALL	VDU_WRREGX	; UPDATE CURSOR

	XOR	A
	RET

VDU_VDASCP:
	CALL	VDU_XY
	XOR	A
	RET

VDU_VDASAT:
	XOR	A
	RET

VDU_VDASCO:
	XOR	A
	RET

VDU_VDAWRC:
	LD	A,E
	CALL	VDU_PUTCHAR
	XOR	A
	RET

VDU_VDAFIL:
	LD	A,E		; FILL CHARACTER GOES IN A
	EX	DE,HL		; FILL LENGTH GOES IN DE
	CALL	VDU_FILL	; DO THE FILL
	XOR	A		; SIGNAL SUCCESS
	RET

VDU_VDACPY:
	; LENGTH IN HL, SOURCE ROW/COL IN DE, DEST IS VDU_POS
	PUSH	HL		; SAVE LENGTH
	CALL	VDU_XY2IDX	; ROW/COL IN DE -> SOURCE ADR IN HL
	POP	BC		; RECOVER LENGTH IN BC
	LD	DE,(VDU_POS)	; PUT DEST IN DE
	JP	VDU_BLKCPY	; DO A BLOCK COPY

	RET

VDU_VDASCR:
	LD	A,E		; LOAD E INTO A
	OR	A		; SET FLAGS
	RET	Z		; IF ZERO, WE ARE DONE
	PUSH	DE		; SAVE E
	JP	M,VDU_VDASCR1	; E IS NEGATIVE, REVERSE SCROLL
	CALL	VDU_SCROLL	; SCROLL FORWARD ONE LINE
	POP	DE		; RECOVER E
	DEC	E		; DECREMENT IT
	JR	VDU_VDASCR	; LOOP
VDU_VDASCR1:
	CALL	VDU_RSCROLL	; SCROLL REVERSE ONE LINE
	POP	DE		; RECOVER E
	INC	E		; INCREMENT IT
	JR	VDU_VDASCR	; LOOP
;
;----------------------------------------------------------------------
; READ VALUE AT CURRENT VDU BUFFER POSITION
; RETURN E = CHARACTER, B = COLOUR, C = ATTRIBUTES
;----------------------------------------------------------------------
;
VDU_VDARDC:
	LD	HL,(VDU_OFFSET)	; SET BUFFER READ POSITION
	LD	DE,(VDU_POS)
	ADD	HL,DE

	LD	C,18		; SET SOURCE ADDRESS IN VDU (HL)
	CALL	VDU_WRREGX	; DO IT

   	LD 	A,31		; PREP VDU FOR DATA R/W
    	OUT 	(VDU_REG),A	; DO IT

	CALL	VDU_WAITRDY	; WAIT FOR VDU TO BE READY

	LD	C,VDU_RAMRD	; LOAD C WITH VDU READ REGISTER
	IN	E,(C)

	LD	B,$F0		; WHITE FG. BLACK BG
	LD	C,$00		; NO ATTRIBUTES
	XOR	A
	RET
;
;======================================================================
; VDU DRIVER - PRIVATE DRIVER FUNCTIONS
;======================================================================
;
;----------------------------------------------------------------------
; WAIT FOR VDU TO BE READY FOR A DATA READ/WRITE
;----------------------------------------------------------------------
;
VDU_WAITRDY:
   	IN 	A,(VDU_STAT)	; READ STATUS
	OR	A		; SET FLAGS
	RET	M		; IF BIT 7 SET, THEN READY!
	JR	VDU_WAITRDY	; KEEP CHECKING
;
;----------------------------------------------------------------------
; UPDATE SY6845 REGISTERS
;   VDU_WRREG WRITES VALUE IN A TO VDU REGISTER SPECIFIED IN C
;   VDU_WRREGX WRITES VALUE IN HL TO VDU REGISTER PAIR IN C, C+1
;----------------------------------------------------------------------
;
VDU_WRREG:
	PUSH	AF			; SAVE VALUE TO WRITE
	LD	A,C			; SET A TO VDU REGISTER TO SELECT
	OUT	(VDU_REG),A		; WRITE IT TO SELECT THE REGISTER
	POP	AF			; RECOVER VALUE TO WRITE
	OUT	(VDU_DATA),A		; WRITE IT
	RET
;
VDU_WRREGX:
	LD	A,H			; SETUP MSB TO WRITE
	CALL	VDU_WRREG		; DO IT
	INC	C			; NEXT VDU REGISTER
	LD	A,L			; SETUP LSB TO WRITE
	JR	VDU_WRREG		; DO IT & RETURN
;
;----------------------------------------------------------------------
; READ SY6845 REGISTERS
;   VDU_RDREG READS VDU REGISTER SPECIFIED IN C AND RETURNS VALUE IN A
;   VDU_RDREGX READS VDU REGISTER PAIR SPECIFIED BY C, C+1
;     AND RETURNS VALUE IN HL
;----------------------------------------------------------------------
;
VDU_RDREG:
	LD	A,C			; SET A TO VDU REGISTER TO SELECT
	OUT	(VDU_REG),A		; WRITE IT TO SELECT THE REGISTER
	IN	A,(VDU_DATA)		; READ IT
	RET
;
VDU_RDREGX:
	CALL	VDU_RDREG		; GET VALUE FROM REGISTER IN C
	LD	H,A			; SAVE IN H
	INC	C			; BUMP TO NEXT REGISTER OF PAIR
	CALL	VDU_RDREG		; READ THE VALUE
	LD	L,A			; SAVE IT IN L
	RET
;
;----------------------------------------------------------------------
; PROBE FOR VDU HARDWARE
;----------------------------------------------------------------------
;
; ON RETURN, ZF SET INDICATES HARDWARE FOUND
;
VDU_PROBE:
	; WRITE TEST PATTERN $A5 $5A TO VRAM ADDRESS POINTER
	LD	HL,$A55A		; POINT TO FIRST BYTE OF VRAM
	LD	C,14			; ADDRESS REGISTER PAIR
	CALL	VDU_WRREGX		; UPDATE VRAM ADDRESS POINTER
	LD	C,14			; ADDRESS REGISTER PAIR
	CALL	VDU_RDREGX		; READ IT BACK
	; TOP TWO BITS ARE ZEROED IN COMPARE BECAUSE THE CRTC
	; STORES ONLY A 14 BIT VALUE FOR REGISTER PAIR 14/15
	LD	A,$A5 & $3F		; FIRST BYTE TEST VALUE
	CP	H			; COMPARE
	RET	NZ			; ABORT IF NOT EQUAL
	LD	A,$5A			; SECOND BYTE TEST VALUE
	CP	L			; COMPARE
	RET				; RETURN WITH COMPARE RESULTS
;
;----------------------------------------------------------------------
; SY6845 DISPLAY CONTROLLER CHIP INITIALIZATION
;----------------------------------------------------------------------
;
VDU_CRTINIT:
    	LD 	C,0			; START WITH REGISTER 0
	LD	B,16			; INIT 16 REGISTERS
    	LD 	HL,VDU_INIT6845		; HL = POINTER TO THE DEFAULT VALUES
VDU_CRTINIT1:
	LD	A,(HL)			; GET VALUE
	CALL	VDU_WRREG		; WRITE IT
	INC	HL			; POINT TO NEXT VALUE
	INC	C			; POINT TO NEXT REGISTER
	DJNZ	VDU_CRTINIT1		; LOOP
    	RET
;
;----------------------------------------------------------------------
; CONVERT XY COORDINATES IN DE INTO LINEAR INDEX IN HL
; D=ROW, E=COL
;----------------------------------------------------------------------
;
VDU_XY2IDX:
	LD	A,E			; SAVE COLUMN NUMBER IN A
	LD	H,D			; SET H TO ROW NUMBER
	LD	E,DROWS			; SET E TO ROW LENGTH
	CALL	MULT8			; MULTIPLY TO GET ROW OFFSET
	LD	E,A			; GET COLUMN BACK
	ADD	HL,DE			; ADD IT IN
	RET				; RETURN
;
;----------------------------------------------------------------------
; SET CURSOR POSITION TO ROW IN D AND COLUMN IN E
;----------------------------------------------------------------------
;
VDU_XY:
	LD	A,E			; SAVE COLUMN NUMBER IN A
	LD	H,D			; SET H TO ROW NUMBER
	LD	E,DROWS			; SET E TO ROW LENGTH
	CALL	MULT8			; MULTIPLY TO GET ROW OFFSET
	LD	E,A			; GET COLUMN BACK
	ADD	HL,DE			; ADD IT IN
	LD	(VDU_POS),HL		; SAVE THE RESULT (DISPLAY POSITION)
	LD	DE,(VDU_OFFSET)		; NOW GET THE BUFFER OFFSET
	ADD	HL,DE			; AND ADD THAT IN
    	LD 	C,14			; CURSOR POSITION REGISTER PAIR
	JP	VDU_WRREGX		; DO IT AND RETURN
;
;----------------------------------------------------------------------
; WRITE VALUE IN A TO CURRENT VDU BUFFER POSITION, ADVANCE CURSOR
;----------------------------------------------------------------------
;
VDU_PUTCHAR:
	LD	B,A		; SAVE THE CHARACTER

	; SET BUFFER WRITE POSITION
	LD	HL,(VDU_OFFSET)
	LD	DE,(VDU_POS)
	ADD	HL,DE
	INC	DE		; INC
	LD	(VDU_POS),DE	; SAVE NEW SCREEN POSITION
	LD	C,18		; UPDATE ADDRESS REGISTER PAIR
	CALL	VDU_WRREGX	; DO IT
	INC	HL		; NEW CURSOR POSITION
	LD	C,14		; CURSOR POSITION REGISTER PAIR
	CALL	VDU_WRREGX	; DO IT

    	LD 	A,31		; PREP VDU FOR DATA R/W
    	OUT 	(VDU_REG),A
	CALL	VDU_WAITRDY	; WAIT FOR VDU TO BE READY
	LD	A,B
    	OUT 	(VDU_RAMWR),A	; OUTPUT CHAR TO VDU

	RET
;
;----------------------------------------------------------------------
; FILL AREA IN BUFFER WITH SPECIFIED CHARACTER AND CURRENT COLOR/ATTRIBUTE
; STARTING AT THE CURRENT FRAME BUFFER POSITION
;   A: FILL CHARACTER
;   DE: NUMBER OF CHARACTERS TO FILL
;----------------------------------------------------------------------
;
VDU_FILL:
	LD	B,A		; SAVE THE FILL CHARACTER

	; SET FILL START POSITION
	PUSH	DE
	LD	HL,(VDU_OFFSET)
	LD	DE,(VDU_POS)
	ADD	HL,DE
	LD	C,18
	CALL	VDU_WRREGX
	POP	DE

	; FILL LOOP
    	LD 	A,31		; PREP VDU FOR DATA R/W
    	OUT 	(VDU_REG),A
VDU_FILL1:
	LD	A,D		; CHECK NUMBER OF FILL CHARS LEFT
	OR	E
	RET	Z		; ALL DONE, RETURN
	CALL	VDU_WAITRDY	; WAIT FOR VDU TO BE READY
	LD	A,B
    	OUT 	(VDU_RAMWR),A	; OUTPUT CHAR TO VDU
	DEC	DE		; DECREMENT COUNT
	JR	VDU_FILL1	; LOOP
;
;----------------------------------------------------------------------
; COPY A BLOCK (UP TO 255 BYTES) FROM HL TO FRAME BUFFER POSITION
;   BC: NUMBER OF BYTES TO COPY
;   HL: SOURCE POSITION
;   DE: DESTINATION POSITION
;----------------------------------------------------------------------
;
VDU_BLKCPY:
	; SETUP TO COPY FROM VDU SOURCE TO WORK BUFFER
	PUSH	DE		; SAVE VDU DESTINATION ADR
	PUSH	HL		; SAVE VDU SOURCE ADDRESS
	LD	HL,(VDU_OFFSET)	; GET THE CURRENT OFFSET
	POP	DE		; RECOVER SOURCE ADDRESS
	ADD	HL,DE		; HL HAS TRUE SOURCE ADR OF VIDEO BUF W/ OFFSET
	LD	DE,VDU_BUF	; POINT DE TO WORK BUFFER
	PUSH	BC		; SAVE COPY LENGTH FOR LATER
	LD	B,C		; NOW USE B FOR LENGTH (MAX COPY IS 255)
	LD	C,18		; SET SOURCE ADDRESS IN VDU (HL)
	CALL	VDU_WRREGX	; DO IT
    	LD 	A,31		; PREP VDU FOR DATA R/W
    	OUT 	(VDU_REG),A	; DO IT
	LD	HL,VDU_BUF	; HL POINTS TO WORK BUFFER
	LD	C,VDU_RAMRD	; LOAD C WITH VDU READ REGISTER

VDU_BLKCPY1:	; VIDEO RAM -> BUFFER COPY LOOP
	CALL	VDU_WAITRDY	; WAIT FOR VDU
	INI			; READ BYTE, DEC B, INC HL
	IN	A,(VDU_DATA)	; BOGUS READ TO INCREMENT VDU RAM ADDRESS!!!
	JR	NZ,VDU_BLKCPY1	; LOOP TILL DONE

	; SETUP TO COPY FROM WORK BUFFER TO VDU DEST
	POP	BC		; RECOVER THE COPY LENGTH
	LD	HL,(VDU_OFFSET)	; GET THE CURRENT VDU OFFSET
	POP	DE		; RECOVER THE DEST ADDRESS
	ADD	HL,DE		; HL HAS TRUE DEST ADR OF VIDEO BUF W/ OFFSET
	LD	B,C		; NOW USE B FOR LENGTH (MAX COPY IS 255)
	LD	C,18		; SET DEST ADDRESS IN VDU (HL)
	CALL	VDU_WRREGX	; DO IT
    	LD 	A,31		; PREP VDU FOR DATA R/W
    	OUT 	(VDU_REG),A	; DO IT
	LD	HL,VDU_BUF	; HL POINTS TO WORK BUFFER
	LD	C,VDU_RAMWR	; LOAD C WITH VDU WRITE REGISTER

VDU_BLKCPY2:	; BUFFER -> VIDEO RAM COPY LOOP
	CALL	VDU_WAITRDY	; WAIT FOR VDU
	OUTI			; WRITE BYTE, DEC B, INC HL
	JR	NZ,VDU_BLKCPY2	; LOOP TILL DONE
;
	RET			; RETURN
;
;----------------------------------------------------------------------
; SCROLL ENTIRE SCREEN FORWARD BY ONE LINE (CURSOR POSITION UNCHANGED)
;----------------------------------------------------------------------
;
VDU_SCROLL:
	; SCROLL FORWARD BY ADDING ONE ROW TO DISPLAY START ADDRESS
	LD	HL,(VDU_OFFSET)
	LD	DE,DROWS
	ADD	HL,DE
	LD	(VDU_OFFSET),HL
	LD	C,12
	CALL	VDU_WRREGX

	; FILL EXPOSED LINE
	LD	HL,(VDU_POS)
	PUSH	HL
	LD	HL,(DLINES-1)*DROWS
	LD	(VDU_POS),HL
	LD	DE,DROWS
	LD	A,' '
	CALL	VDU_FILL
	POP	HL
	LD	(VDU_POS),HL

	; ADJUST CURSOR POSITION AND RETURN
	LD	HL,(VDU_OFFSET)
	LD	DE,(VDU_POS)
	ADD	HL,DE
	LD	C,14
	JP	VDU_WRREGX
;
;----------------------------------------------------------------------
; REVERSE SCROLL ENTIRE SCREEN BY ONE LINE (CURSOR POSITION UNCHANGED)
;----------------------------------------------------------------------
;
VDU_RSCROLL:
	; SCROLL BACKWARD BY SUBTRACTING ONE ROW FROM DISPLAY START ADDRESS
	LD	HL,(VDU_OFFSET)
	LD	DE,-DROWS
	ADD	HL,DE
	LD	(VDU_OFFSET),HL
	LD	C,12
	CALL	VDU_WRREGX

	; FILL EXPOSED LINE
	LD	HL,(VDU_POS)
	PUSH	HL
	LD	HL,0
	LD	(VDU_POS),HL
	LD	DE,DROWS
	LD	A,' '
	CALL	VDU_FILL
	POP	HL
	LD	(VDU_POS),HL

	; ADJUST CURSOR POSITION AND RETURN
	LD	HL,(VDU_OFFSET)
	LD	DE,(VDU_POS)
	ADD	HL,DE
	LD	C,14
	JP	VDU_WRREGX
;
;==================================================================================================
;   VDU DRIVER - DATA
;==================================================================================================
;
VDU_POS		.DW 	0		; CURRENT DISPLAY POSITION
VDU_OFFSET	.DW 	0		; CURRENT DISPLAY POSITION
VDU_BUF		.FILL	256,0		; COPY BUFFER
;
;==================================================================================================
;   ECB-VDU VIDEO MODE DESCRIPTION
;==================================================================================================\
;
; CCIR 625/50 VERSION (USED IN MOST OF THE WORLD)
; JUMPER K1 2-3, K2 1-2 FOR 2MHz CHAR CLOCK
;
; THE CCIR 625/50 TELEVISION STANDARD HAS 625 LINES INTERLACED AT 50 FIELDS PER SECOND.  THIS WORKS
; OUT AS 50 FIELDS OF 312.5 LINES PER SECOND NON-INTERLACED AS USED HERE.
; HORIZONTAL LINE WIDTH IS 64uS.  FOR A 2 MHz CHARACTER CLOCK (R0+1)/2000000 = 64uS
; NEAREST NUMBER OF LINES IS 312 = (R4+1) * (R9+1) + R5.
; 15625 / 312 = 50.08 FIELDS PER SECOND (NEAR ENOUGH-DGG)
;
;
;	.DB	078H			; R8 MODE	B7=0	TRANSPARENT UPDATE DURING BLANKING
;					;		B6=1	PIN 34 IS UPDATE STROBE
;					;		B5=1	DELAY CURSOR 1 CHARACTER
;					;		B4=1	DELAY DISPLAY ENABLE 1 CHARACTER
;					;		B3=1	TRANSPARENT MEMORY ADDRESSING
;					;		B2=0	RAM STRAIGHT BINARY ADDRESSING
;					;		B1,B0=0	NON-INTERLACE
VDU_INIT6845:
#IF	(VDUSIZ=V80X24)
;==================================================================================================
;   VDU DRIVER - SY6845 REGISTER INITIALIZATION -80x24 10x8
;==================================================================================================
;
	.DB	07FH			; R0 TOTAL NUMBER OF HORIZONTAL CHARACTERS (DETERMINES HSYNC)
	.DB	DROWS			; R1 NUMBER OF HORIZONTAL CHARACTERS DISPLAYED (80 COLUMNS)
	.DB	060H			; R2 HORIZONTAL SYNC POSITION
	.DB	00CH			; R3 SYNC WIDTHS
	.DB	01EH			; R4 VERTICAL TOTAL (TOTAL CHARS IN A FRAME 30-1)
	.DB	002H			; R5 VERTICAL TOTAL ADJUST (
	.DB	DLINES			; R6 VERTICAL DISPLAYED (24 ROWS)
	.DB	01AH			; R7 VERTICAL SYNC
	.DB	078H			; R8 MODE
	.DB	DSCANL-1		; R9 SCAN LINE (LINES PER CHAR AND SPACING -1)
	.DB	VDU_R10			; R10 CURSOR START RASTER
	.DB	VDU_R11			; R11 CURSOR END RASTER
	.DB	00H			; R12 START ADDRESS HI
	.DB	00H			; R13 START ADDRESS LO
	.DB	00H			; R14 CURSOR ADDRESS HI
	.DB	00H			; R15 CURSOR ADDRESS LO
#ENDIF
#IF	(VDUSIZ=V80X25)
;==================================================================================================
;   VDU DRIVER - SY6845 REGISTER INITIALIZATION -80x25 10x8
;==================================================================================================
;
	.DB	07FH			; R0 TOTAL NUMBER OF HORIZONTAL CHARACTERS (DETERMINES HSYNC)
	.DB	DROWS			; R1 NUMBER OF HORIZONTAL CHARACTERS DISPLAYED =80
	.DB	060H			; R2 HORIZONTAL SYNC POSITION
	.DB	00CH			; R3 SYNC WIDTHS
	.DB	01EH			; R4 VERTICAL TOTAL (TOTAL CHARS IN A FRAME 30-1)
	.DB	002H			; R5 VERTICAL TOTAL ADJUST (
	.DB	DLINES			; R6 VERTICAL DISPLAYED (25 ROWS)
	.DB	01BH			; R7 VERTICAL SYNC
	.DB	078H			; R8 MODE
	.DB	DSCANL-1		; R9 SCAN LINE (LINES PER CHAR AND SPACING -1)
	.DB	VDU_R10			; R10 CURSOR START RASTER
	.DB	VDU_R11			; R11 CURSOR END RASTER
	.DB	00H			; R12 START ADDRESS HI
	.DB	00H			; R13 START ADDRESS LO
	.DB	00H			; R14 CURSOR ADDRESS HI
	.DB	00H			; R15 CURSOR ADDRESS LO
#ENDIF
#IF	(VDUSIZ=V80X30)
;==================================================================================================
;   VDU DRIVER - SY6845 REGISTER INITIALIZATION -80x30 8x8
;==================================================================================================
;
	.DB	07FH			; R0 TOTAL NUMBER OF HORIZONTAL CHARACTERS (DETERMINES HSYNC)
	.DB	DROWS			; R1 NUMBER OF HORIZONTAL CHARACTERS DISPLAYED =80
	.DB	060H			; R2 HORIZONTAL SYNC POSITION
	.DB	00CH			; R3 SYNC WIDTHS
	.DB	26H			; R4 VERTICAL TOTAL (TOTAL CHARS IN A FRAME -1) (39-1)
	.DB	00H			; R5 VERTICAL TOTAL ADJUST (
	.DB	DLINES			; R6 VERTICAL DISPLAYED (30 ROWS)
	.DB	22H			; R7 VERTICAL SYNC
	.DB	078H			; R8 MODE
	.DB	DSCANL-1		; R9 SCAN LINE (LINES PER CHAR AND SPACING -1)
	.DB	VDU_R10			; R10 CURSOR START RASTER
	.DB	VDU_R11			; R11 CURSOR END RASTER
	.DB	00H			; R12 START ADDRESS HI
	.DB	00H			; R13 START ADDRESS LO
	.DB	00H			; R14 CURSOR ADDRESS HI
	.DB	00H			; R15 CURSOR ADDRESS LO
#ENDIF
#IF	(VDUSIZ=V80X25B)
;==================================================================================================
;   VDU DRIVER - SY6845 REGISTER INITIALIZATION -80x25 12x8 TO SUIT BLOCK GRAPHICS
;==================================================================================================
;
	.DB	07FH			; R0 TOTAL NUMBER OF HORIZONTAL CHARACTERS (DETERMINES HSYNC)
	.DB	DROWS			; R1 NUMBER OF HORIZONTAL CHARACTERS DISPLAYED =80
	.DB	060H			; R2 HORIZONTAL SYNC POSITION
	.DB	00CH			; R3 SYNC WIDTHS
	.DB	19H			; R4 VERTICAL TOTAL (TOTAL CHARS IN A FRAME -1) (312/DLINES)-1
	.DB	00H			; R5 VERTICAL TOTAL ADJUST (312-(R4+1)*DSCANL)
	.DB	DLINES			; R6 VERTICAL DISPLAY
	.DB	019H			; R7 VERTICAL SYNC  (DLINES .. R4)
	.DB	078H			; R8 MODE
	.DB	DSCANL-1		; R9 SCAN LINE (LINES PER CHAR AND SPACING -1)
	.DB	VDU_R10			; R10 CURSOR START RASTER
	.DB	VDU_R11			; R11 CURSOR END RASTER
	.DB	00H			; R12 START ADDRESS HI
	.DB	00H			; R13 START ADDRESS LO
	.DB	00H			; R14 CURSOR ADDRESS HI
	.DB	00H			; R15 CURSOR ADDRESS LO
#ENDIF
#IF	(VDUSIZ=V80X24B)
;==================================================================================================
;   VDU DRIVER - SY6845 REGISTER INITIALIZATION -80x24 12x8 TO SUIT BLOCK GRAPHICS
;==================================================================================================
;
	.DB	07FH			; R0 TOTAL NUMBER OF HORIZONTAL CHARACTERS (DETERMINES HSYNC)
	.DB	DROWS			; R1 NUMBER OF HORIZONTAL CHARACTERS DISPLAYED =80
	.DB	060H			; R2 HORIZONTAL SYNC POSITION
	.DB	00CH			; R3 SYNC WIDTHS
	.DB	19H			; R4 VERTICAL TOTAL (TOTAL CHARS IN A FRAME -1) (312/DLINES)-1
	.DB	00H			; R5 VERTICAL TOTAL ADJUST (312-(R4+1)*DSCANL)
	.DB	DLINES			; R6 VERTICAL DISPLAY
	.DB	018H			; R7 VERTICAL SYNC  (DLINES .. R4)
	.DB	078H			; R8 MODE
	.DB	DSCANL-1		; R9 SCAN LINE (LINES PER CHAR AND SPACING -1)
	.DB	VDU_R10			; R10 CURSOR START RASTER
	.DB	VDU_R11			; R11 CURSOR END RASTER
	.DB	00H			; R12 START ADDRESS HI
	.DB	00H			; R13 START ADDRESS LO
	.DB	00H			; R14 CURSOR ADDRESS HI
	.DB	00H			; R15 CURSOR ADDRESS LO
;
#ENDIF
;
;;==================================================================================================
;   VDU DRIVER - INSTANCE DATA
;==================================================================================================
;
VDU_IDAT:
	.DB	VDU_PPIA
	.DB	VDU_PPIB
	.DB	VDU_PPIC
	.DB	VDU_PPIX
