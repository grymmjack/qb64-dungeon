$Debug
'$INCLUDE:'../include/Toolbox64/FileOps.bi'
'$INCLUDE:'../include/Toolbox64/ANSIPrint.bi'

CONST TRUE = -1, FALSE = NOT TRUE

DIM AS LONG CANVAS, GNOLL
DIM TEST_ANSI AS STRING

CONST SW = 132  ' SCREEN WIDTH IN CHARACTERS
CONST SH = 100  ' SCREEN HEIGHT IN CHARACTERS + 1 MORE TO PREVENT SCOLLING OFF
CONST CW = 8    ' WIDTH OF 1 CHARACTER
CONST CH = 8    ' HEIGHT OF 1 CHARACTER

' setup the screen
$RESIZE:ON
$RESIZE:SMOOTH
_FONT CH
_FULLSCREEN _SQUAREPIXELS, _SMOOTH
CANVAS& = _NEWIMAGE(SW * CW, SH * CH, 32)

' setup canvas
SCREEN CANVAS&
LINE (0, 0)-(SW * CW, SH *SH), _RGB32(0, 0, 80), BF
GNOLL& = _NEWIMAGE(33 * CW, 25 * CH, 32)
TEST_ANSI$ = LoadFile$("../assets/ansi/monsters/gnoll.ans")

' print the ansi to all the images
_DEST GNOLL&
_FONT CH
ANSI_Print(TEST_ANSI$)
_DEST CANVAS&
_SOURCE GNOLL&
_PUTIMAGE (0, 0)

SLEEP

'$INCLUDE:'../include/Toolbox64/FileOps.bas'
'$INCLUDE:'../include/Toolbox64/ANSIPrint.bas'