;
;==================================================================================================
;   SBC MAXIMUM CONFIGURATION
;==================================================================================================
;
; THIS CONFIGURATION FILE IS *NOT* MEANT TO GENERATE A FUNCTIONAL ROM.
; IT IS USED TO HELP TEST BUILDS WITH MOST FEATURES ENABLED.
;
; THE COMPLETE SET OF DEFAULT CONFIGURATION SETTINGS FOR THIS PLATFORM ARE FOUND IN THE
; CFG_<PLT>.ASM INCLUDED FILE WHICH IS FOUND IN THE PARENT DIRECTORY.  THIS FILE CONTAINS
; COMMON CONFIGURATION SETTINGS THAT OVERRIDE THE DEFAULTS.  IT IS INTENDED THAT YOU MAKE
; YOUR CUSTOMIZATIONS IN THIS FILE AND JUST INHERIT ALL OTHER SETTINGS FROM THE DEFAULTS.
; EVEN BETTER, YOU CAN MAKE A COPY OF THIS FILE WITH A NAME LIKE <PLT>_XXX.ASM AND SPECIFY
; YOUR FILE IN THE BUILD PROCESS.
;
; THE SETTINGS BELOW ARE THE SETTINGS THAT ARE MOST COMMONLY MODIFIED FOR THIS PLATFORM.
; MANY OF THEM ARE EQUAL TO THE SETTINGS IN THE INCLUDED FILE, SO THEY DON'T REALLY DO
; ANYTHING AS IS.  THEY ARE LISTED HERE TO MAKE IT EASY FOR YOU TO ADJUST THE MOST COMMON
; SETTINGS.
;
; N.B., SINCE THE SETTINGS BELOW ARE REDEFINING VALUES ALREADY SET IN THE INCLUDED FILE,
; TASM INSISTS THAT YOU USE THE .SET OPERATOR AND NOT THE .SET OPERATOR BELOW. ATTEMPTING
; TO REDEFINE A VALUE WITH .SET BELOW WILL CAUSE TASM ERRORS!
;
; PLEASE REFER TO THE CUSTOM BUILD INSTRUCTIONS (README.TXT) IN THE SOURCE DIRECTORY (TWO
; DIRECTORIES ABOVE THIS ONE).
;
#DEFINE	BOOT_DEFAULT	"H"		; DEFAULT BOOT LOADER CMD ON <CR> OR AUTO BOOT
;
#include "cfg_sbc.asm"
;
BATCOND		.SET	TRUE		; ENABLE LOW BATTERY WARNING MESSAGE
HBIOS_MUTEX	.SET	TRUE		; ENABLE REENTRANT CALLS TO HBIOS (ADDS OVERHEAD)
USELZSA2	.SET	TRUE		; ENABLE FONT COMPRESSION
;
KIOENABLE	.SET	TRUE		; ENABLE ZILOG KIO SUPPORT
;
DIAGENABLE	.SET	TRUE		; ENABLES OUTPUT TO 8 BIT LED DIAGNOSTIC PORT
;
DSKYENABLE	.SET	TRUE		; ENABLES DSKY (DO NOT COMBINE WITH PPIDE)
;
DSRTCENABLE	.SET	TRUE		; DSRTC: ENABLE DS-1302 CLOCK DRIVER (DSRTC.ASM)
;
UARTENABLE	.SET	TRUE		; UART: ENABLE 8250/16550-LIKE SERIAL DRIVER (UART.ASM)
;
SIOENABLE	.SET	TRUE		; SIO: ENABLE ZILOG SIO SERIAL DRIVER (SIO.ASM)
;
VDUENABLE	.SET	TRUE		; VDU: ENABLE VDU VIDEO/KBD DRIVER (VDU.ASM)
CVDUENABLE	.SET	TRUE		; CVDU: ENABLE CVDU VIDEO/KBD DRIVER (CVDU.ASM)
TMSENABLE	.SET	TRUE		; TMS: ENABLE TMS9918 VIDEO/KBD DRIVER (TMS.ASM)
VGAENABLE	.SET	TRUE		; VGA: ENABLE VGA VIDEO/KBD DRIVER (VGA.ASM)
;
FDENABLE	.SET	TRUE		; FD: ENABLE FLOPPY DISK DRIVER (FD.ASM)
;
RFENABLE	.SET	TRUE		; RF: ENABLE RAM FLOPPY DRIVER
;
IDEENABLE	.SET	TRUE		; IDE: ENABLE IDE DISK DRIVER (IDE.ASM)
;
PPIDEENABLE	.SET	TRUE		; PPIDE: ENABLE PARALLEL PORT IDE DISK DRIVER (PPIDE.ASM)
;
SDENABLE	.SET	TRUE		; SD: ENABLE SD CARD DISK DRIVER (SD.ASM)
;
PRPENABLE	.SET	TRUE		; PRP: ENABLE ECB PROPELLER IO BOARD DRIVER (PRP.ASM)
;
AY38910ENABLE	.SET	TRUE		; AY: AY-3-8910 / YM2149 SOUND DRIVER
;
SN7ENABLE	.SET	TRUE		; SN : SN76489 DRIVER
