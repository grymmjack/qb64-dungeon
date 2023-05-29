$Debug
'$INCLUDE:'./include/QB64_GJ_LIB/_GJ_LIB.BI'
'$INCLUDE:'./include/Toolbox64/FileOps.bi'
'$INCLUDE:'./include/Toolbox64/ANSIPrint.bi'

CONST TRUE = -1, FALSE = NOT TRUE

DIM AS STRING MENU_LOGO
DIM SHARED MENU_LEFT(1 TO 4) AS STRING
DIM SHARED MENU_RIGHT(1 TO 4) AS STRING
DIM SHARED MENU_BLOCK(1 TO 6) AS STRING
DIM SHARED AS LONG CANVAS, IMG_MENU_LEFT, IMG_MENU_RIGHT, IMG_MENU_LOGO, IMG_MENU_BLOCK

' load all the ansis
MENU_LOGO$     = LoadFileFromDisk$("assets/ansi/dungeon-menu-logo.ans")
MENU_LEFT$(1)  = LoadFileFromDisk$("assets/ansi/dungeon-menu-left-wall-1.ans")
MENU_LEFT$(2)  = LoadFileFromDisk$("assets/ansi/dungeon-menu-left-wall-1.ans")
MENU_LEFT$(3)  = LoadFileFromDisk$("assets/ansi/dungeon-menu-left-wall-1.ans")
MENU_LEFT$(4)  = LoadFileFromDisk$("assets/ansi/dungeon-menu-left-wall-1.ans")
MENU_RIGHT$(1) = LoadFileFromDisk$("assets/ansi/dungeon-menu-right-wall-1.ans")
MENU_RIGHT$(2) = LoadFileFromDisk$("assets/ansi/dungeon-menu-right-wall-1.ans")
MENU_RIGHT$(3) = LoadFileFromDisk$("assets/ansi/dungeon-menu-right-wall-1.ans")
MENU_RIGHT$(4) = LoadFileFromDisk$("assets/ansi/dungeon-menu-right-wall-1.ans")
MENU_BLOCK(1)  = LoadFileFromDisk$("assets/ansi/dungeon-menu-block-1.ans")
MENU_BLOCK(2)  = LoadFileFromDisk$("assets/ansi/dungeon-menu-block-2.ans")
MENU_BLOCK(3)  = LoadFileFromDisk$("assets/ansi/dungeon-menu-block-3.ans")
MENU_BLOCK(4)  = LoadFileFromDisk$("assets/ansi/dungeon-menu-block-4.ans")
MENU_BLOCK(5)  = LoadFileFromDisk$("assets/ansi/dungeon-menu-block-5.ans")
MENU_BLOCK(6)  = LoadFileFromDisk$("assets/ansi/dungeon-menu-block-6.ans")

' print the ansi to all the images
_DEST IMG_MENU_LOGO&  : PrintANSI(MENU_LOGO$)
_DEST IMG_MENU_LEFT&  : PrintANSI(MENU_LEFT$(1))
_DEST IMG_MENU_RIGHT& : PrintANSI(MENU_RIGHT$(1))
_DEST IMG_MENU_BLOCK& : PrintANSI(MENU_BLOCK$(1))

CONST SW = 132  ' SCREEN WIDTH IN CHARACTERS
CONST SH = 51   ' SCREEN HEIGHT IN CHARACTERS + 1 MORE TO PREVENT SCOLLING OFF
CONST CW = 8    ' WIDTH OF 1 CHARACTER
CONST CH = 16   ' HEIGHT OF 1 CHARACTER

$RESIZE:ON
$RESIZE:STRETCH
CANVAS& = _NEWIMAGE(SW * CW, SH * CH, 32)
_FONT CH
_FULLSCREEN _SQUAREPIXELS, _SMOOTH

' setup canvas
SCREEN CANVAS&

' layout the images
_DEST CANVAS&
_SOURCE IMG_MENU_LOGO&
_PUTIMAGE (17*CW, 0)

'$INCLUDE:'./include/QB64_GJ_LIB/_GJ_LIB.BM'
'$INCLUDE:'./include/Toolbox64/FileOps.bas'
'$INCLUDE:'./include/Toolbox64/ANSIPrint.bas'