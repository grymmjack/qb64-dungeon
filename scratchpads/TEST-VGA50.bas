$Debug
'$INCLUDE:'../include/QB64_GJ_LIB/_GJ_LIB.BI'
'$INCLUDE:'../include/Toolbox64/FileOps.bi'
'$INCLUDE:'../include/Toolbox64/ANSIPrint.bi'

CONST TRUE = -1, FALSE = NOT TRUE

DIM TEST_ANSI AS STRING

' setup the screen
$RESIZE:ON
$RESIZE:STRETCH
_FONT 8
_FULLSCREEN _SQUAREPIXELS, _SMOOTH

' setup canvas
SCREEN 0 'CANVAS&

' load the ansi
TEST_ANSI$ = LoadFile$("../assets/ansi/Gnoll.ans")

' print the ansi to all the images
PrintANSI(TEST_ANSI$)

'$INCLUDE:'../include/QB64_GJ_LIB/_GJ_LIB.BM'
'$INCLUDE:'../include/Toolbox64/FileOps.bas'
'$INCLUDE:'../include/Toolbox64/ANSIPrint.bas'