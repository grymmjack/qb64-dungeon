$Debug
'$INCLUDE:'../include/QB64_GJ_LIB/_GJ_LIB.BI'
'$INCLUDE:'../include/Toolbox64/FileOps.bi'
'$INCLUDE:'../include/Toolbox64/ANSIPrint.bi'

CONST TRUE = -1, FALSE = NOT TRUE

CONST SW = 132  ' SCREEN WIDTH IN CHARACTERS
CONST SH = 51   ' SCREEN HEIGHT IN CHARACTERS + 1 MORE TO PREVENT SCOLLING OFF
CONST CW = 8    ' WIDTH OF 1 CHARACTER
CONST CH = 16   ' HEIGHT OF 1 CHARACTER

DIM AS STRING MENU_LOGO
DIM SHARED MENU_LEFT(1 TO 4) AS STRING
DIM SHARED MENU_RIGHT(1 TO 4) AS STRING
DIM SHARED MENU_BLOCK(1 TO 6) AS STRING
DIM SHARED AS LONG CANVAS, IMG_MENU_LEFT, IMG_MENU_RIGHT, IMG_MENU_LOGO, IMG_MENU_BLOCK

' setup the screen
$RESIZE:ON
$RESIZE:STRETCH
CANVAS& = _NEWIMAGE(SW * CW, SH * CH, 32)
_FONT CH
_FULLSCREEN _SQUAREPIXELS, _SMOOTH

' setup canvas
SCREEN CANVAS&

' load all the ansis
MENU_LOGO$     = LoadFile$("../assets/ansi/dungeon-menu-logo.ans")
MENU_LEFT$(1)  = LoadFile$("../assets/ansi/dungeon-menu-left-wall-1-pablo.ans")
MENU_LEFT$(2)  = LoadFile$("../assets/ansi/dungeon-menu-left-wall-2-pablo.ans")
MENU_LEFT$(3)  = LoadFile$("../assets/ansi/dungeon-menu-left-wall-3-pablo.ans")
MENU_LEFT$(4)  = LoadFile$("../assets/ansi/dungeon-menu-left-wall-4-pablo.ans")
MENU_RIGHT$(1) = LoadFile$("../assets/ansi/dungeon-menu-right-wall-1-pablo.ans")
MENU_RIGHT$(2) = LoadFile$("../assets/ansi/dungeon-menu-right-wall-2-pablo.ans")
MENU_RIGHT$(3) = LoadFile$("../assets/ansi/dungeon-menu-right-wall-3-pablo.ans")
MENU_RIGHT$(4) = LoadFile$("../assets/ansi/dungeon-menu-right-wall-4-pablo.ans")
MENU_BLOCK$(1) = LoadFile$("../assets/ansi/dungeon-menu-block-1.ans")
MENU_BLOCK$(2) = LoadFile$("../assets/ansi/dungeon-menu-block-2.ans")
MENU_BLOCK$(3) = LoadFile$("../assets/ansi/dungeon-menu-block-3.ans")
MENU_BLOCK$(4) = LoadFile$("../assets/ansi/dungeon-menu-block-4.ans")
MENU_BLOCK$(5) = LoadFile$("../assets/ansi/dungeon-menu-block-5.ans")
MENU_BLOCK$(6) = LoadFile$("../assets/ansi/dungeon-menu-block-6.ans")

' setup the images
IMG_MENU_LOGO&  = _NEWIMAGE(102 * CW, 15 * CH, 32)
IMG_MENU_LEFT&  = _NEWIMAGE(15  * CW, 51 * CH, 32)
IMG_MENU_RIGHT& = _NEWIMAGE(16  * CW, 51 * CH, 32)
IMG_MENU_BLOCK& = _NEWIMAGE(95  * CW, 31 * CH, 32)

' print the ansi to all the images
_DEST IMG_MENU_LOGO&  : PrintANSI(MENU_LOGO$)
_DEST IMG_MENU_LEFT&  : PrintANSI(MENU_LEFT$(1))
_DEST IMG_MENU_RIGHT& : PrintANSI(MENU_RIGHT$(1))
_DEST IMG_MENU_BLOCK& : PrintANSI(MENU_BLOCK$(1))

' layout the images
_DEST CANVAS&
_SOURCE IMG_MENU_LEFT&
_PUTIMAGE (0, 0)
_SOURCE IMG_MENU_RIGHT&
_PUTIMAGE (116 * CW, 0)
_SOURCE IMG_MENU_LOGO&
_PUTIMAGE (14 * CW, 0)
_SOURCE IMG_MENU_BLOCK&
_PUTIMAGE (19 * CW, 15 * CH)
_DISPLAY

' setup menu
TYPE MENU
    number      AS INTEGER
    ansi        AS STRING
END TYPE
DIM SHARED MAIN_MENU(1 TO 6) AS MENU
DIM i AS INTEGER
FOR i% = 1 TO 6
    MAIN_MENU(i%).number% = i%
    MAIN_MENU(i%).ansi$ = MENU_BLOCK$(i%)
NEXT i%
DIM SHARED menu_selected AS INTEGER
menu_selected% = 1

' loop waiting for input to move CURSOR
DIM k AS STRING
DIM p AS INTEGER
DIM t AS LONG
DO:
    _LIMIT 60
    k$ = UCASE$(INKEY$)
    IF k$ = "" THEN k$ = CHR$(0)
    p% = INSTR("WASD", k$)
    IF p% <> 0 THEN
        MENU.move k$
    END IF
    IF k$ = CHR$(13) THEN
        SOUND 50, 1
    END IF
    t& = t& + 1
    IF t& MOD 10 = 0 THEN MENU.flicker
    _DISPLAY
LOOP UNTIL k$=CHR$(27)

_FULLSCREEN _OFF
SCREEN 0 : _DEST 0
_DELAY 1
_FREEIMAGE CANVAS&
_FREEIMAGE IMG_MENU_BLOCK&
_FREEIMAGE IMG_MENU_LEFT&
_FREEIMAGE IMG_MENU_RIGHT&
_FREEIMAGE IMG_MENU_LOGO&
SYSTEM


SUB MENU.flicker
    DIM rand_num AS INTEGER
    rand_num% = rand_in_range(1, 5)
    IF rand_num% > 3 THEN EXIT SUB
    _DEST IMG_MENU_LEFT&  : PrintANSI(MENU_LEFT$(rand_num%))
    _DEST IMG_MENU_RIGHT& : PrintANSI(MENU_RIGHT$(rand_num%))
    _DEST CANVAS&
    _SOURCE IMG_MENU_LEFT&
    _PUTIMAGE (0, 0)
    _SOURCE IMG_MENU_RIGHT&
    _PUTIMAGE (116 * CW, 0)
END SUB

SUB MENU.move (k AS STRING)
    IF k$ = "A" THEN MENU.prev
    IF k$ = "D" THEN MENU.next
    IF k$ = "W" THEN MENU.prev
    IF k$ = "S" THEN MENU.next
    MENU.update
    SOUND 200, 0.1
END SUB

SUB MENU.update
    _DEST IMG_MENU_BLOCK&
    PrintANSI(MENU_BLOCK$(menu_selected%))    
    _DEST CANVAS&
    _SOURCE IMG_MENU_BLOCK&
    _PUTIMAGE (19 * CW, 15 * CH)
END SUB

SUB MENU.next
    DIM AS INTEGER next_option, total_options
    next_option% = menu_selected% + 1
    total_options% = UBOUND(MAIN_MENU)
    IF next_option% > total_options% THEN
        menu_selected% = 1
    ELSE
        menu_selected% = next_option%    
    END IF
END SUB

SUB MENU.prev
    DIM AS INTEGER prev_option
    prev_option% = menu_selected% - 1
    IF prev_option% <= 0 THEN
        menu_selected% = UBOUND(MAIN_MENU)
    ELSE
        menu_selected% = prev_option%    
    END IF
END SUB

FUNCTION rand_in_range% (minimum%, maximum%)
    rand_in_range% = INT(RND * (maximum% - minimum% + 1)) + 1
END FUNCTION


'$INCLUDE:'../include/QB64_GJ_LIB/_GJ_LIB.BM'
'$INCLUDE:'../include/Toolbox64/FileOps.bas'
'$INCLUDE:'../include/Toolbox64/ANSIPrint.bas'