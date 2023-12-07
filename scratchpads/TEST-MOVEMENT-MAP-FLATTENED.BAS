$Debug
        '-----------------------------------------------------------------------------------------------------------------------
        ' File, path and filesystem operations
        ' Copyright (c) 2023 Samuel Gomes
        '-----------------------------------------------------------------------------------------------------------------------
        
        '-----------------------------------------------------------------------------------------------------------------------
        ' HEADER FILES
        '-----------------------------------------------------------------------------------------------------------------------
        '-----------------------------------------------------------------------------------------------------------------------
        
        $If FILEOPS_BI = UNDEFINED Then
            $Let FILEOPS_BI = TRUE
        
            '-------------------------------------------------------------------------------------------------------------------
            ' METACOMMANDS
            '-------------------------------------------------------------------------------------------------------------------
            $Unstable:Http
            '-------------------------------------------------------------------------------------------------------------------
        
            '-------------------------------------------------------------------------------------------------------------------
            ' CONSTANTS
            '-------------------------------------------------------------------------------------------------------------------
            Const __HTTP_UPDATES_PER_SECOND = 60
            '-------------------------------------------------------------------------------------------------------------------
        $End If
        '-----------------------------------------------------------------------------------------------------------------------
        '---------------------------------------------------------------------------------------------------------------------------------------------------------------
        ' ANSI Escape Sequence Emulator
        ' Copyright (c) 2023 Samuel Gomes
        '---------------------------------------------------------------------------------------------------------------------------------------------------------------
        
        '---------------------------------------------------------------------------------------------------------------------------------------------------------------
        ' HEADER FILES
        '---------------------------------------------------------------------------------------------------------------------------------------------------------------
        '---------------------------------------------------------------------------------------------------------------------------------------------------------------
        
        $If ANSIPRINT_BI = UNDEFINED Then
            $Let ANSIPRINT_BI = TRUE
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
            ' CONSTANTS
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
            ' ANSI constants (not an exhaustive list)
            Const ANSI_NUL = 0 ' Null
            Const ANSI_SOH = 1 ' Start of Heading
            Const ANSI_STX = 2 ' Start of Text
            Const ANSI_ETX = 3 ' End of Text
            Const ANSI_EOT = 4 ' End of Transmission
            Const ANSI_ENQ = 5 ' Enquiry
            Const ANSI_ACK = 6 ' Acknowledgement
            Const ANSI_BEL = 7 ' Bell
            Const ANSI_BS = 8 ' Backspace
            Const ANSI_HT = 9 ' Horizontal Tab
            Const ANSI_LF = 10 ' Line Feed
            Const ANSI_VT = 11 ' Vertical Tab
            Const ANSI_FF = 12 ' Form Feed
            Const ANSI_CR = 13 ' Carriage Return
            Const ANSI_SO = 14 ' Shift Out
            Const ANSI_SI = 15 ' Shift In
            Const ANSI_DLE = 16 ' Data Link Escape
            Const ANSI_DC1 = 17 ' Device Control 1
            Const ANSI_DC2 = 18 ' Device Control 2
            Const ANSI_DC3 = 19 ' Device Control 3
            Const ANSI_DC4 = 20 ' Device Control 4
            Const ANSI_NAK = 21 ' Negative Acknowledgement
            Const ANSI_SYN = 22 ' Synchronous Idle
            Const ANSI_ETB = 23 ' End of Transmission Block
            Const ANSI_CAN = 24 ' Cancel
            Const ANSI_EM = 25 ' End of Medium
            Const ANSI_SUB = 26 ' Substitute
            Const ANSI_ESC = 27 ' Escape
            Const ANSI_FS = 28 ' File Separator
            Const ANSI_GS = 29 ' Group Separator
            Const ANSI_RS = 30 ' Record Separator
            Const ANSI_US = 31 ' Unit Separator
            Const ANSI_SP = 32 ' Space
            Const ANSI_SLASH = 47 ' /
            Const ANSI_0 = 48 ' 0
            Const ANSI_ESC_DECSC = 55 ' Save Cursor Position in Memory
            Const ANSI_ESC_DECSR = 56 ' Restore Cursor Position from Memory
            Const ANSI_9 = 57 ' 9
            Const ANSI_COLON = 58 ' :
            Const ANSI_SEMICOLON = 59 ' ;
            Const ANSI_LESS_THAN_SIGN = 60 ' <
            Const ANSI_EQUALS_SIGN = 61 ' =
            Const ANSI_GREATER_THAN_SIGN = 62 ' >
            Const ANSI_QUESTION_MARK = 63 ' ?
            Const ANSI_AT_SIGN = 64 ' @
            Const ANSI_ESC_CSI_CUU = 65 ' Cursor Up
            Const ANSI_ESC_CSI_CUD = 66 ' Cursor Down
            Const ANSI_ESC_CSI_CUF = 67 ' Cursor Forward/Right
            Const ANSI_ESC_CSI_CUB = 68 ' Cursor Back/Left
            Const ANSI_ESC_CSI_CNL = 69 ' Cursor Next Line
            Const ANSI_ESC_CSI_CPL = 70 ' Cursor Previous Line
            Const ANSI_ESC_CSI_CHA = 71 ' Cursor Horizontal Absolute
            Const ANSI_ESC_CSI_CUP = 72 ' Cursor Position
            Const ANSI_ESC_CSI_ED = 74 ' Erase in Display
            Const ANSI_ESC_CSI_EL = 75 ' Erase in Line
            Const ANSI_ESC_CSI_IL = 76 ' ANSI.SYS: Insert line
            Const ANSI_ESC_CSI_DL = 77 ' ANSI.SYS: Delete line
            Const ANSI_ESC_RI = 77 ' Reverse Index
            Const ANSI_ESC_SS2 = 78 ' Single Shift Two
            Const ANSI_ESC_SS3 = 79 ' Single Shift Three
            Const ANSI_ESC_DCS = 80 ' Device Control String
            Const ANSI_ESC_CSI_SU = 83 ' Scroll Up
            Const ANSI_ESC_CSI_SD = 84 ' Scroll Down
            Const ANSI_ESC_SOS = 88 ' Start of String
            Const ANSI_ESC_CSI = 91 ' Control Sequence Introducer
            Const ANSI_ESC_ST = 92 ' String Terminator
            Const ANSI_ESC_OSC = 93 ' Operating System Command
            Const ANSI_ESC_PM = 94 ' Privacy Message
            Const ANSI_ESC_APC = 95 ' Application Program Command
            Const ANSI_ESC_CSI_VPA = 100 ' Vertical Line Position Absolute
            Const ANSI_ESC_CSI_HVP = 102 ' Horizontal Vertical Position
            Const ANSI_ESC_CSI_SM = 104 ' ANSI.SYS: Set screen mode
            Const ANSI_ESC_CSI_RM = 108 ' ANSI.SYS: Reset screen mode
            Const ANSI_ESC_CSI_SGR = 109 ' Select Graphic Rendition
            Const ANSI_ESC_CSI_DSR = 110 ' Device status report
            Const ANSI_ESC_CSI_DECSCUSR = 113 ' Cursor Shape
            Const ANSI_ESC_CSI_SCP = 115 ' Save Current Cursor Position
            Const ANSI_ESC_CSI_PABLODRAW_24BPP = 116 ' PabloDraw 24-bit ANSI sequences
            Const ANSI_ESC_CSI_RCP = 117 ' Restore Saved Cursor Position
            Const ANSI_TILDE = 126 ' ~
            Const ANSI_DEL = 127 ' Delete
            ' Parser state
            Const ANSI_STATE_TEXT = 0 ' when parsing regular text & control characters
            Const ANSI_STATE_BEGIN = 1 ' when beginning an escape sequence
            Const ANSI_STATE_SEQUENCE = 2 ' when parsing a control sequence introducer
            Const ANSI_STATE_END = 3 ' when the end of the character stream has been reached
            ' Some defaults
            Const ANSI_DEFAULT_COLOR_FOREGROUND = 7
            Const ANSI_DEFAULT_COLOR_BACKGROUND = 0
            Const ANSI_ARG_COUNT = 10 ' number of argument slots that we'll start with
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
        
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
            ' USER DEFINED TYPES
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
            Type ANSIEmulatorType
                isInitialized As Long ' was the library initialized?
                state As Long ' the current parser state
                argIndex As Long ' the current CSI argument index & count; 0 means no arguments
                fC As _Unsigned Long ' foreground color
                bC As _Unsigned Long ' background color
                isBold As Long ' text attributes - high intensity bg color
                isBlink As Long ' text attributes - we make this high intensity as well
                isInvert As Long ' text attributes - inverted colors (fg <> bg)
                posDEC As Vector2DType ' DEC saved cursor position
                posSCO As Vector2DType ' SCO saved cursor position
                CPS As Long ' characters / second
            End Type
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
        
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
            ' GLOBAL VARIABLES
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
            Dim __ANSIEmu As ANSIEmulatorType ' emulator state
            Dim __ANSIColorLUT(0 To 255) As _Unsigned Long ' this table is used to get the RGB for legacy ANSI colors
            ReDim __ANSIArg(1 To ANSI_ARG_COUNT) As Long ' CSI dynamic argument list
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
        $End If
        '---------------------------------------------------------------------------------------------------------------------------------------------------------------

CONST TRUE = -1, FALSE = NOT TRUE

DIM AS STRING BOARD_ANSI, BOARD_ANSI_NO_LABELS, BOARD_ANSI_LEVEL_SECTORS
BOARD_ANSI$ = LoadFileFromDisk$("../assets/ansi/board-132x50-no-secrets.ans")
BOARD_ANSI_LEVEL_SECTORS$ = LoadFileFromDisk$("../assets/ansi/board-132x50-no-secrets.ans")

DIM SHARED AS _UNSIGNED LONG YELLOW, BLACK, BROWN, BRIGHT_BLUE
YELLOW~&      = _RGB32(&HFF, &HFF, &H55)
BLACK~&       = _RGB32(&H00, &H00, &H00)
BROWN~&       = _RGB32(&HAA, &H55, &H00)
BRIGHT_BLUE~& = _RGB32(&H55, &H55, &HFF)

DIM SHARED AS LONG CANVAS, CANVAS_COPY, LEVEL_SECTORS

CONST SW = 132  ' SCREEN WIDTH IN CHARACTERS
CONST SH = 50   ' SCREEN HEIGHT IN CHARACTERS + 1 MORE TO PREVENT SCOLLING OFF
CONST CW = 8    ' WIDTH OF 1 CHARACTER
CONST CH = 16   ' HEIGHT OF 1 CHARACTER

$RESIZE:ON
$RESIZE:STRETCH
CANVAS& = _NEWIMAGE(SW * CW, SH * CH, 32)
CANVAS_COPY& = _NEWIMAGE(SW * CW, SH * CH, 32)
LEVEL_SECTORS& = _NEWIMAGE(SW * CW, SH * CH, 32)
_FONT CH
_FULLSCREEN _SQUAREPIXELS, _SMOOTH

' clear canvas
SCREEN CANVAS&
_DEST CANVAS&
_SOURCE CANVAS&
CLS , BLACK~&
ANSI_Print(BOARD_ANSI$)

' copy canvas to the copy
_DEST CANVAS_COPY&
CLS , BLACK~&
ANSI_Print(BOARD_ANSI$)
_DEST CANVAS&

' load level sectors
_DEST LEVEL_SECTORS&
CLS , BLACK~&
ANSI_Print(BOARD_ANSI_LEVEL_SECTORS$)
_DEST CANVAS&

TYPE SECTOR
    start_x AS INTEGER
    start_y AS INTEGER
    end_x   AS INTEGER
    end_y   AS INTEGER
    w       AS INTEGER
    h       AS INTEGER
    kolor   AS _UNSIGNED LONG
    label   AS STRING
END TYPE
DIM SHARED SECTORS(1 TO 9) AS SECTOR

TYPE CURSOR
    x              AS INTEGER
    y              AS INTEGER
    prev_x         AS INTEGER
    prev_y         AS INTEGER
    cursor_color   AS _UNSIGNED LONG
    in_sector      AS INTEGER
    in_room        AS INTEGER
    on_path        AS INTEGER
    on_door        AS INTEGER
    on_secret_door AS INTEGER
END TYPE
DIM SHARED c AS CURSOR

' setup CURSOR
c.x% = 59*CW
c.y% = 24*CH
c.cursor_color~& = _RGB32(&HFF, &H00, &H00, &HAA)
c.prev_x% = c.x%
c.prev_y% = c.y%

' setup SECTORS
' LEVEL 1
SECTORS(1).kolor~&  = _RGB32(&H55, &HFF, &H55) ' BRIGHT GREEN
SECTORS(1).label$   = "LEVEL 1 - MAIN GALLERY"
SECTORS(1).start_x% = 41
SECTORS(1).start_y% = 17
SECTORS(1).end_x%   = 79
SECTORS(1).end_y%   = 32
SECTORS(1).w%       = SECTORS(1).end_x% - SECTORS(1).start_x%
SECTORS(1).h%       = SECTORS(1).end_y% - SECTORS(1).start_y%

' LEVEL 2
SECTORS(2).kolor~&  = _RGB32(&H00, &HAA, &H00) ' DARK GREEN
SECTORS(2).label$   = "LEVEL 2 - GUARD ROOM + KITCHEN"
SECTORS(2).start_x% = 1
SECTORS(2).start_y% = 17
SECTORS(2).end_x%   = 40
SECTORS(2).end_y%   = 33
SECTORS(2).w%       = SECTORS(2).end_x% - SECTORS(2).start_x%
SECTORS(2).h%       = SECTORS(2).end_y% - SECTORS(2).start_y%

' LEVEL 3
SECTORS(3).kolor~& = _RGB32(&HAA, &H00, &H00) ' DARK RED
SECTORS(3).label$   = "LEVEL 3 - ARMORY"
SECTORS(3).start_x% = 1
SECTORS(3).start_y% = 1
SECTORS(3).end_x%   = 34
SECTORS(3).end_y%   = 16
SECTORS(3).w%       = SECTORS(3).end_x% - SECTORS(3).start_x%
SECTORS(3).h%       = SECTORS(3).end_y% - SECTORS(3).start_y%

' LEVEL 4
SECTORS(4).kolor~& = _RGB32(&HFF, &H55, &H55) ' BRIGHT RED
SECTORS(4).label$   = "LEVEL 4 - STORE ROOM"
SECTORS(4).start_x% = 1
SECTORS(4).start_y% = 34
SECTORS(4).end_x%   = 40
SECTORS(4).end_y%   = 50
SECTORS(4).w%       = SECTORS(4).end_x% - SECTORS(4).start_x%
SECTORS(4).h%       = SECTORS(4).end_y% - SECTORS(4).start_y%

' LEVEL 5
SECTORS(5).kolor~& = _RGB32(&HFF, &H55, &HFF) ' BRIGHT PURPLE
SECTORS(5).label$   = "LEVEL 5 - TORTURE CHAMBER"
SECTORS(5).start_x% = 41
SECTORS(5).start_y% = 33
SECTORS(5).end_x%   = 80
SECTORS(5).end_y%   = 50
SECTORS(5).w%       = SECTORS(5).end_x% - SECTORS(5).start_x%
SECTORS(5).h%       = SECTORS(5).end_y% - SECTORS(5).start_y%

' LEVEL 6
SECTORS(6).kolor~& = _RGB32(&H00, &HAA, &HAA) ' DARK CYAN
SECTORS(6).label$   = "LEVEL 6 - KING'S QUARTERS"
SECTORS(6).start_x% = 80
SECTORS(6).start_y% = 17
SECTORS(6).end_x%   = 117
SECTORS(6).end_y%   = 32
SECTORS(6).w%       = SECTORS(6).end_x% - SECTORS(6).start_x%
SECTORS(6).h%       = SECTORS(6).end_y% - SECTORS(6).start_y%

' LEVEL 7
SECTORS(7).kolor~& = _RGB32(&H55, &HFF, &HFF) ' BRIGHT CYAN
SECTORS(7).label$   = "LEVEL 7 - WIZ'S QUARTERS"
SECTORS(7).start_x% = 79
SECTORS(7).start_y% = 1
SECTORS(7).end_x%   = 117
SECTORS(7).end_y%   = 16
SECTORS(7).w%       = SECTORS(7).end_x% - SECTORS(7).start_x%
SECTORS(7).h%       = SECTORS(7).end_y% - SECTORS(7).start_y%

' LEVEL 8
SECTORS(8).kolor~& = _RGB32(&H55, &H55, &H55) ' BRIGHT BLACK
SECTORS(8).label$   = "LEVEL 8 - QUEEN'S QUARTERS"
SECTORS(8).start_x% = 81
SECTORS(8).start_y% = 33
SECTORS(8).end_x%   = 117
SECTORS(8).end_y%   = 50
SECTORS(8).w%       = SECTORS(8).end_x% - SECTORS(8).start_x%
SECTORS(8).h%       = SECTORS(8).end_y% - SECTORS(8).start_y%

' LEVEL 9
SECTORS(9).kolor~& = _RGB32(&HAA, &H00, &HAA) ' DARK PURPLE
SECTORS(9).label$   = "LEVEL 9 - THE CRYPT"
SECTORS(9).start_x% = 35
SECTORS(9).start_y% = 1
SECTORS(9).end_x%   = 78
SECTORS(9).end_y%   = 16
SECTORS(9).w%       = SECTORS(9).end_x% - SECTORS(9).start_x%
SECTORS(9).h%       = SECTORS(9).end_y% - SECTORS(9).start_y%

' render initial labels for board
render_room_labels

' draw CURSOR one time to start
CURSOR.draw

' loop waiting for input to move CURSOR
DIM k AS STRING
DIM p AS INTEGER
DIM cur_sector AS INTEGER
DO:
    _LIMIT 30
    k$ = UCASE$(INKEY$)
    IF k$ = "" THEN k$ = CHR$(0)
    p% = INSTR("WASD", k$)
    IF p% <> 0 THEN
        CURSOR.move k$
    END IF
    CURSOR.update_state
    _DISPLAY
LOOP UNTIL k$=CHR$(27)

_FULLSCREEN _OFF
SCREEN 0 : _DEST 0
_DELAY 1
_FREEIMAGE CANVAS&
_FREEIMAGE CANVAS_COPY&
_FREEIMAGE LEVEL_SECTORS&
SYSTEM


SUB CURSOR.move (k AS STRING)
    c.prev_x% = c.x%
    c.prev_y% = c.y%
    IF k$ = "A" THEN c.x% = c.x% - CW
    IF k$ = "D" THEN c.x% = c.x% + CW
    IF k$ = "W" THEN c.y% = c.y% - CH
    IF k$ = "S" THEN c.y% = c.y% + CH
    CURSOR.keep_in_bounds
    IF CURSOR.can_move = TRUE THEN
        CURSOR.erase
        CURSOR.draw
        SOUND 350, 0.1
    ELSE
        c.x% = c.prev_x%
        c.y% = c.prev_y%
        SOUND 200, 0.1
    END IF
END SUB


SUB CURSOR.keep_in_bounds
    IF c.x% + CW > SW * CW THEN c.x% = SW-CW
    IF c.y% + CH > SH * CH THEN c.y% = SH-CH
    IF c.x% - CW < 0 THEN c.x% = 0
    IF c.y% - CH < 0 THEN c.y% = 0
    IF c.x% > SW * CW THEN c.x% = SW-CW
    IF c.y% > SH * CH THEN c.y% = SH-CH
    IF c.x% < 0 THEN c.x% = 0
    IF c.y% < 0 THEN c.y% = 0
END SUB


SUB CURSOR.update_state
    DIM AS LONG img_box
    DIM cur_sector AS INTEGER
    DIM in_sector AS SECTOR
    DIM state AS STRING
    state$ = ""
    img_box& = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY&, img_box&, (c.x%, c.y%)-(c.x%+CW, c.y%+CH)
    c.on_path%        = is_path(img_box&)
    c.in_room%        = in_room(img_box&)
    c.on_door%        = is_door(img_box&)
    c.on_secret_door% = is_secret_door(img_box&)
    COLOR _RGB32(&HFF, &HFF, &HFF), _RGB32(&H00, &H00, &H00)
    cur_sector%  = SECTOR.get_by_xy(c.x%, c.y%)
    in_sector    = SECTORS(cur_sector%)
    _PRINTSTRING(0, 50 * CH), "SECTOR(" + _TRIM$(STR$(cur_sector%)) + "): " + in_sector.label$
    ' show state
    IF c.on_path% = TRUE THEN state$ = state$ + " ON PATH"
    IF c.in_room% = TRUE THEN state$ = state$ + " IN ROOM"
    IF c.on_door% = TRUE THEN state$ = state$ + " ON DOOR"
    IF c.on_secret_door% = TRUE THEN state$ = state$ + " ON SECRET DOOR"
    _PRINTSTRING(80 * CW, 50 * CH), "                                             "
    _PRINTSTRING(80 * CW, 50 * CH), state$
    _FREEIMAGE img_box&
END SUB


FUNCTION CURSOR.can_move%
    DIM AS LONG img_box
    DIM AS INTEGER __on_path, __in_room, __on_door, __on_secret_door
    img_box& = _NEWIMAGE(CW, CH, 32)
    _PUTIMAGE (0, 0)-(CW, CH), CANVAS_COPY&, img_box&, (c.x%, c.y%)-(c.x%+CW, c.y%+CH)
    __on_path%        = is_path(img_box&)
    __in_room%        = in_room(img_box&)
    __on_door%        = is_door(img_box&)
    __on_secret_door% = is_secret_door(img_box&)
    _FREEIMAGE img_box&
    CURSOR.can_move = __on_path% OR __in_room% OR __on_door% OR __on_secret_door%
END FUNCTION


SUB CURSOR.erase
    _SOURCE CANVAS_COPY&
    _DEST CANVAS&
    _PUTIMAGE
    _SOURCE CANVAS&
    render_room_labels
END SUB


SUB CURSOR.draw
    LINE (c.x%, c.y%)-(c.x%+CW-1, c.y%+CH-1), c.cursor_color~&, BF
END SUB


FUNCTION image_is_monochromatic% (img AS LONG, kolor AS _UNSIGNED LONG)
    DIM AS INTEGER x, y, has_kolor
    DIM AS _UNSIGNED LONG check_color
    DIM AS LONG old_source
    old_source& = _SOURCE
    _SOURCE img&
    FOR y% = 0 TO _HEIGHT(img&) - 1
        FOR x% = 0 TO _WIDTH(img&) - 1
            check_color~& = POINT(x%, y%)
            IF (check_color~& <> kolor~&) THEN
                _SOURCE old_source&
                image_is_monochromatic = FALSE
                EXIT FUNCTION
            ELSE
                IF check_color~& = kolor~& THEN has_kolor% = TRUE
            END IF
        NEXT x%
    NEXT y%
    _SOURCE old_source&
    image_is_monochromatic = has_kolor%
END FUNCTION


FUNCTION image_is_diachromatic% (img AS LONG, kolor1 AS _UNSIGNED LONG, kolor2 AS _UNSIGNED LONG)
    DIM AS INTEGER x, y, has_kolor1, has_kolor2
    DIM AS _UNSIGNED LONG check_color
    DIM AS LONG old_source
    old_source& = _SOURCE
    _SOURCE img&
    FOR y% = 0 TO _HEIGHT(img&) - 1
        FOR x% = 0 TO _WIDTH(img&) - 1 
            check_color~& = POINT(x%, y%)
            IF (check_color~& <> kolor1~&) AND (check_color~& <> kolor2~&) THEN
                _SOURCE old_source&
                image_is_diachromatic = FALSE
                EXIT FUNCTION
            ELSE
                IF check_color~& = kolor1~& THEN has_kolor1% = TRUE
                IF check_color~& = kolor2~& THEN has_kolor2% = TRUE
            END IF
        NEXT x%
    NEXT y%
    _SOURCE old_source&
    image_is_diachromatic = has_kolor1% AND has_kolor2%
END FUNCTION


FUNCTION is_path% (img AS LONG)
    c.on_path% = image_is_monochromatic(img&, YELLOW~&)
    is_path = c.on_path%
END FUNCTION

FUNCTION in_room% (img AS LONG)
    DIM sector_color AS _UNSIGNED LONG
    DIM sector AS INTEGER
    sector% = SECTOR.get_by_xy(c.x%, c.y%)
    sector_color~& = SECTORS(sector%).kolor~&
    c.in_room% = ( _
           image_is_diachromatic(img&, sector_color~&, BROWN~&) _
        OR image_is_diachromatic(img&, sector_color~&, BRIGHT_BLUE~&) _
        OR image_is_monochromatic(img&, sector_color~&) _
    )
    in_room = c.in_room%
END FUNCTION

FUNCTION is_door% (img AS LONG)
    DIM AS INTEGER is_door_on_path, is_door_in_room, is_door_fullblock, sector
    DIM sector_color AS _UNSIGNED LONG
    sector%            = SECTOR.get_by_xy(c.x%, c.y%)
    sector_color~&     = SECTORS(sector%).kolor~&
    is_door_on_path%   = image_is_diachromatic(img&, YELLOW~&, BROWN~&)
    is_door_in_room%   = image_is_diachromatic(img&, sector_color~&, BROWN~&)
    is_door_fullblock% = image_is_monochromatic(img&, BROWN~&)
    c.on_door%         = is_door_on_path% OR is_door_in_room% OR is_door_fullblock%
    is_door = c.on_door%
END FUNCTION


FUNCTION is_secret_door% (img AS LONG)
    DIM AS INTEGER is_secret_door_on_path, is_secret_door_in_room, is_secret_door_fullblock, sector
    DIM sector_color AS _UNSIGNED LONG
    sector%                   = SECTOR.get_by_xy(c.x%, c.y%)
    sector_color~&            = SECTORS(sector%).kolor~&
    is_secret_door_on_path%   = image_is_diachromatic(img&, YELLOW~&, BRIGHT_BLUE~&)
    is_secret_door_in_room%   = image_is_diachromatic(img&, sector_color~&, BRIGHT_BLUE~&)
    is_secret_door_fullblock% = image_is_monochromatic(img&, BRIGHT_BLUE~&)
    c.on_secret_door%         = is_secret_door_on_path% OR is_secret_door_in_room% OR is_secret_door_fullblock%
    is_secret_door = c.on_secret_door%
END FUNCTION



SUB render_room_labels
    DIM AS _UNSIGNED LONG fg_color_blue, fg_color_red
    fg_color_blue~& = _RGB32(&H00, &H00, &HAA)
    fg_color_red~&  = _RGB32(&HFF, &H55, &H55)

    COLOR fg_color_red~&, YELLOW~&
    _PRINTSTRING(57*CW,23*CH), "START"

    COLOR fg_color_blue~&, YELLOW~&

    _PRINTSTRING(57*CW,25*CH), "MAIN"
    _PRINTSTRING(56*CW,26*CH), "GALLERY"

    _PRINTSTRING(14*CW,10*CH), "ARMORY"

    _PRINTSTRING(47*CW,7*CH), "THE"
    _PRINTSTRING(47*CW,8*CH), "CRYPT"

    _PRINTSTRING(83*CW,9*CH), "WIZ'S"
    _PRINTSTRING(84*CW,10*CH), "LAB"

    _PRINTSTRING(93*CW,7*CH), "WIZ'S"
    _PRINTSTRING(93*CW,8*CH), "TREASURE"

    _PRINTSTRING(3*CW,26*CH), "KITCHEN"

    _PRINTSTRING(18*CW,23*CH), "GUARD"
    _PRINTSTRING(18*CW,24*CH), "ROOM"

    _PRINTSTRING(18*CW,41*CH), "STORE"
    _PRINTSTRING(18*CW,42*CH), "ROOM"

    _PRINTSTRING(49*CW,39*CH), "TORTURE"
    _PRINTSTRING(49*CW,40*CH), "CHAMBER"

    _PRINTSTRING(88*CW,42*CH), "QUEEN'S"
    _PRINTSTRING(88*CW,43*CH), "ANNEX"

    _PRINTSTRING(87*CW,34*CH), "QUEEN'S"
    _PRINTSTRING(87*CW,35*CH), "TREASURE"

    _PRINTSTRING(90*CW,27*CH), "KING'S"
    _PRINTSTRING(88*CW,28*CH), "LIBRARY"

    _PRINTSTRING(104*CW,21*CH), "KING'S"
    _PRINTSTRING(104*CW,22*CH), "TREASURE"
END SUB


' gets sector
FUNCTION SECTOR.get_by_xy% (x AS INTEGER, y AS INTEGER)
    DIM i AS INTEGER
    DIM s AS SECTOR
    DIM AS INTEGER sx, ex, sy, ey
    FOR i% = 1 TO 9
        s = SECTORS(i%)
        sx% = (s.start_x% - 1) * CW
        ex% = (s.end_x% - 1) * CW
        sy% = (s.start_y% - 1) * CH
        ey% = (s.end_y% - 1) * CH
        IF x% >= sx% AND x% <= ex% AND y% >= sy% AND y% <= ey% THEN
            SECTOR.get_by_xy% = i%
            EXIT FUNCTION
        END IF
    NEXT i%
    SECTOR.get_by_xy% = 0
END FUNCTION


        '-----------------------------------------------------------------------------------------------------------------------
        ' File, path and filesystem operations
        ' Copyright (c) 2023 Samuel Gomes
        '-----------------------------------------------------------------------------------------------------------------------
        
        '-----------------------------------------------------------------------------------------------------------------------
        ' HEADER FILES
        '-----------------------------------------------------------------------------------------------------------------------
        '-----------------------------------------------------------------------------------------------------------------------
        
        $If FILEOPS_BAS = UNDEFINED Then
            $Let FILEOPS_BAS = TRUE
        
            '-------------------------------------------------------------------------------------------------------------------
            ' FUNCTIONS & SUBROUTINES
            '-------------------------------------------------------------------------------------------------------------------
            ' Return true if path name is an absolute path (i.e. starts from the root)
            Function IsAbsolutePath%% (pathName As String)
                $If WIN Then
                    IsAbsolutePath = Asc(pathName, 1) = KEY_SLASH Or Asc(pathName, 1) = KEY_BACKSLASH Or Asc(pathName, 3) = KEY_SLASH Or Asc(pathName, 3) = KEY_BACKSLASH ' either / or \ or x:/ or x:\
                $Else
                        IsAbsolutePath = Asc(pathName, 1) = KEY_SLASH ' /
                $End If
            End Function
        
        
            ' Adds a trailing / to a directory name if needed
            ' TODO: This needs to be more platform specific (i.e. \ should not be checked on non-windows platforms)
            Function FixPathDirectoryName$ (PathOrURL As String)
                If Len(PathOrURL) > 0 And (Asc(PathOrURL, Len(PathOrURL)) <> KEY_SLASH Or Asc(PathOrURL, Len(PathOrURL)) <> KEY_BACKSLASH) Then
                    FixPathDirectoryName = PathOrURL + Chr$(KEY_SLASH)
                Else
                    FixPathDirectoryName = PathOrURL
                End If
            End Function
        
        
            ' Gets the filename portion from a file path or URL
            ' If no part seperator is found it assumes the whole string is a filename
            Function GetFileNameFromPathOrURL$ (PathOrURL As String)
                Dim As _Unsigned Long i, j: j = Len(PathOrURL)
        
                ' Retrieve the position of the first / or \ in the parameter from the
                For i = j To 1 Step -1
                    Select Case Asc(PathOrURL, i)
                        Case KEY_SLASH, KEY_BACKSLASH
                            Exit For
                    End Select
                Next
        
                ' Return the full string if pathsep was not found
                If i = NULL Then
                    GetFileNameFromPathOrURL = PathOrURL
                Else
                    GetFileNameFromPathOrURL = Right$(PathOrURL, j - i)
                End If
            End Function
        
        
            ' Returns the pathname portion from a file path or URL
            ' If no path seperator is found it return an empty string
            Function GetFilePathFromPathOrURL$ (PathOrURL As String)
                Dim As _Unsigned Long i, j: j = Len(PathOrURL)
                For i = j To 1 Step -1
                    Select Case Asc(PathOrURL, i)
                        Case KEY_SLASH, KEY_BACKSLASH
                            Exit For
                    End Select
                Next
        
                If i <> NULL Then GetFilePathFromPathOrURL = Left$(PathOrURL, i)
            End Function
        
        
            ' Get the file extension from a path name (ex. .doc, .so etc.)
            ' Note this will return anything after a dot if the URL/path is just a directory name
            Function GetFileExtensionFromPathOrURL$ (PathOrURL As String)
                Dim fileName As String: fileName = GetFileNameFromPathOrURL(PathOrURL)
                Dim i As _Unsigned Long: i = _InStrRev(fileName, Chr$(KEY_DOT))
        
                If i <> NULL Then
                    GetFileExtensionFromPathOrURL = Right$(fileName, Len(fileName) - i + 1)
                End If
            End Function
        
        
            ' Gets the drive or scheme from a path name (ex. C:, HTTPS: etc.)
            Function GetDriveOrSchemeFromPathOrURL$ (PathOrURL As String)
                Dim i As _Unsigned Long: i = InStr(PathOrURL, Chr$(KEY_COLON))
        
                If i <> NULL Then
                    GetDriveOrSchemeFromPathOrURL = Left$(PathOrURL, i)
                End If
            End Function
        
        
            ' Load a file from a file or URL
            Function LoadFile$ (PathOrURL As String)
                Select Case UCase$(GetDriveOrSchemeFromPathOrURL(PathOrURL))
                    Case "HTTP:", "HTTPS:", "FTP:"
                        LoadFile = LoadFileFromURL(PathOrURL)
        
                    Case Else
                        LoadFile = LoadFileFromDisk(PathOrURL)
                End Select
            End Function
        
        
            ' Loads a whole file from disk into memory
            Function LoadFileFromDisk$ (path As String)
                If _FileExists(path) Then
                    Dim As Long fh: fh = FreeFile
        
                    Open path For Binary Access Read As fh
        
                    LoadFileFromDisk = Input$(LOF(fh), fh)
        
                    Close fh
                End If
            End Function
        
        
            ' Loads a whole file from a URL into memory
            Function LoadFileFromURL$ (url As String)
                Dim h As Long: h = _OpenClient("HTTP:" + url)
        
                If h <> NULL Then
                    Dim As String content, buffer
        
                    While Not EOF(h)
                        _Limit __HTTP_UPDATES_PER_SECOND
                        Get h, , buffer
                        content = content + buffer
                    Wend
        
                    Close h
        
                    LoadFileFromURL = content
                End If
            End Function
        
        
            ' Copies file src to dst. Src file must exist and dst file must not
            Function CopyFile%% (fileSrc As String, fileDst As String, overwrite As _Byte)
                ' Check if source file exists
                If _FileExists(fileSrc) Then
                    ' Check if dest file exists
                    If _FileExists(fileDst) And Not overwrite Then
                        Exit Function
                    End If
        
                    Dim sfh As Long: sfh = FreeFile: Open fileSrc For Binary Access Read As sfh ' open source
                    Dim dfh As Long: dfh = FreeFile: Open fileDst For Binary Access Write As dfh ' open destination
        
                    Dim buffer As String: buffer = Space$(LOF(sfh)) ' allocate buffer memory to read the file in one go
        
                    Get sfh, , buffer ' load the whole file into memory
                    Put dfh, , buffer ' write the buffer to the new file
        
                    Close sfh, dfh ' close source and destination
        
                    CopyFile = TRUE ' success
                End If
            End Function
            '-------------------------------------------------------------------------------------------------------------------
        $End If
        '-----------------------------------------------------------------------------------------------------------------------
        '---------------------------------------------------------------------------------------------------------------------------------------------------------------
        ' ANSI Escape Sequence Emulator
        ' Copyright (c) 2023 Samuel Gomes
        '
        ' TODO:
        '   https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences#screen-colors
        '   https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences#window-title
        '   https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences#soft-reset
        '   https://github.com/a740g/ANSIPrint/blob/master/docs/ansimtech.txt
        '---------------------------------------------------------------------------------------------------------------------------------------------------------------
        
        '---------------------------------------------------------------------------------------------------------------------------------------------------------------
        ' HEADER FILES
        '---------------------------------------------------------------------------------------------------------------------------------------------------------------
        '---------------------------------------------------------------------------------------------------------------------------------------------------------------
        
        $If ANSIPRINT_BAS = UNDEFINED Then
            $Let ANSIPRINT_BAS = TRUE
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
            ' Small test code for debugging the library
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
            '$Debug
            'Screen NewImage(8 * 80, 16 * 25, 32)
            'Font 16
        
            'Do
            '    Dim ansFile As String: ansFile = OpenFileDialog$("Open", "", "*.ans|*.asc|*.diz|*.nfo|*.txt", "ANSI Art Files")
            '    If Not FileExists(ansFile) Then Exit Do
        
            '    Dim fh As Long: fh = FreeFile
            '    Open ansFile For Binary Access Read As fh
            '    Color DarkGray, Black
            '    Cls
            '    ResetANSIEmulator
            '    ANSI_Print Input$(LOF(fh), fh)
            '    Close fh
            '    Title "Press any key to open another file...": Sleep 3600
            'Loop
        
            'End
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
        
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
            ' FUNCTIONS & SUBROUTINES
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
            ' Initializes library global variables and tables and then sets the init flag to true
            Sub InitializeANSIEmulator
                Shared __ANSIEmu As ANSIEmulatorType
                Shared __ANSIColorLUT() As _Unsigned Long
                Shared __ANSIArg() As Long
        
                If __ANSIEmu.isInitialized Then Exit Sub ' leave if we have already initialized
        
                If _PixelSize < 4 Then Error ERROR_FEATURE_UNAVAILABLE ' we only support rendering to 32bpp images
        
                Dim As Long c, i, r, g, b
        
                ' The first 16 are the standard 16 ANSI colors (VGA style)
                __ANSIColorLUT(0) = _RGB32(0, 0, 0) ' 0 black
                __ANSIColorLUT(1) = _RGB32(170, 0, 0) '  1 red
                __ANSIColorLUT(2) = _RGB32(0, 170, 0) '  2 green
                __ANSIColorLUT(3) = _RGB32(170, 85, 0) '  3 yellow (not really yellow; oh well)
                __ANSIColorLUT(4) = _RGB32(0, 0, 170) '  4 blue
                __ANSIColorLUT(5) = _RGB32(170, 0, 170) '  5 magenta
                __ANSIColorLUT(6) = _RGB32(0, 170, 170) '  6 cyan
                __ANSIColorLUT(7) = _RGB32(170, 170, 170) ' white
                __ANSIColorLUT(8) = _RGB32(85, 85, 85) '  8 grey
                __ANSIColorLUT(9) = _RGB32(255, 85, 85) '  9 bright red
                __ANSIColorLUT(10) = _RGB32(85, 255, 85) ' 10 bright green
                __ANSIColorLUT(11) = _RGB32(255, 255, 85) ' 11 bright yellow
                __ANSIColorLUT(12) = _RGB32(85, 85, 255) ' 12 bright blue
                __ANSIColorLUT(13) = _RGB32(255, 85, 255) ' 13 bright magenta
                __ANSIColorLUT(14) = _RGB32(85, 255, 255) ' 14 bright cyan
                __ANSIColorLUT(15) = _RGB32(255, 255, 255) ' 15 bright white
        
                ' The next 216 colors (16-231) are formed by a 3bpc RGB value offset by 16, packed into a single value
                For c = 16 To 231
                    i = ((c - 16) \ 36) Mod 6
                    If i = 0 Then r = 0 Else r = (14135 + 10280 * i) \ 256
        
                    i = ((c - 16) \ 6) Mod 6
                    If i = 0 Then g = 0 Else g = (14135 + 10280 * i) \ 256
        
                    i = ((c - 16) \ 1) Mod 6
                    If i = 0 Then b = 0 Else b = (14135 + 10280 * i) \ 256
        
                    __ANSIColorLUT(c) = _RGB32(r, g, b)
                Next
        
                ' The final 24 colors (232-255) are grayscale starting from a shade slighly lighter than black, ranging up to shade slightly darker than white
                For c = 232 To 255
                    g = (2056 + 2570 * (c - 232)) \ 256
                    __ANSIColorLUT(c) = _RGB32(g, g, g)
                Next
        
                ReDim __ANSIArg(1 To UBound(__ANSIArg)) As Long ' reset the CSI arg list
        
                __ANSIEmu.state = ANSI_STATE_TEXT ' we will start parsing regular text by default
                __ANSIEmu.argIndex = 0 ' reset argument index
        
                ' Reset the foreground and background color
                __ANSIEmu.fC = ANSI_DEFAULT_COLOR_FOREGROUND
                SetANSICanvasColor __ANSIEmu.fC, FALSE, TRUE
                __ANSIEmu.bC = ANSI_DEFAULT_COLOR_BACKGROUND
                SetANSICanvasColor __ANSIEmu.bC, TRUE, TRUE
        
                ' Reset text attributes
                __ANSIEmu.isBold = FALSE
                __ANSIEmu.isBlink = FALSE
                __ANSIEmu.isInvert = FALSE
        
                ' Get the current cursor position
                __ANSIEmu.posDEC.x = Pos(0)
                __ANSIEmu.posDEC.y = CsrLin
                __ANSIEmu.posSCO = __ANSIEmu.posDEC
        
                __ANSIEmu.CPS = 0 ' disable any speed control
        
                _ControlChr On ' get assist from QB64's control character handling (only for tabs; we are pretty much doing the rest ourselves)
        
                __ANSIEmu.isInitialized = TRUE ' set to true to indicate init is done
            End Sub
        
        
            ' This simply resets the emulator to a clean state
            Sub ResetANSIEmulator
                Shared __ANSIEmu As ANSIEmulatorType
        
                __ANSIEmu.isInitialized = FALSE ' set the init flag to false
                InitializeANSIEmulator ' call the init routine
            End Sub
        
        
            ' Sets the emulation speed
            ' nCPS - characters / second (bigger numbers means faster; <= 0 to disable)
            Sub SetANSIEmulationSpeed (nCPS As Long)
                Shared __ANSIEmu As ANSIEmulatorType
        
                __ANSIEmu.CPS = nCPS
            End Sub
        
        
            ' Processes a single byte and decides what to do with it based on the current emulation state
            Function ANSI_PrintCharacter& (ch As _Unsigned _Byte)
                Shared __ANSIEmu As ANSIEmulatorType
                Shared __ANSIArg() As Long
        
                ANSI_PrintCharacter& = TRUE ' by default we will return true to tell the caller to keep going
        
                Dim As Long x, y, z ' temp variables used in many places (usually as counter / index)
        
                Select Case __ANSIEmu.state
                    Case ANSI_STATE_TEXT ' handle normal characters (including some control characters)
                        Select Case ch
                            Case ANSI_SUB ' stop processing and exit loop on EOF (usually put by SAUCE blocks)
                                __ANSIEmu.state = ANSI_STATE_END
        
                            Case ANSI_BEL ' handle Bell - because QB64 does not (even with ControlChr On)
                                Beep
        
                            Case ANSI_BS ' handle Backspace - because QB64 does not (even with ControlChr On)
                                x = Pos(0) - 1
                                If x > 0 Then Locate , x ' move to the left only if we are not on the edge
        
                                'Case ANSI_LF ' handle Line Feed because QB64 screws this up and moves the cursor to the beginning of the next line
                                '    x = Pos(0) ' save old x pos
                                '    Print Chr$(ch); ' use QB64 to handle the LF and then correct the mistake
                                '    Locate , x ' set the cursor to the old x pos
        
                            Case ANSI_FF ' handle Form Feed - because QB64 does not (even with ControlChr On)
                                Locate 1, 1
        
                            Case ANSI_CR ' handle Carriage Return because QB64 screws this up and moves the cursor to the beginning of the next line
                                Locate , 1
        
                                'Case ANSI_DEL ' TODO: Check what to do with this
        
                            Case ANSI_ESC ' handle escape character
                                __ANSIEmu.state = ANSI_STATE_BEGIN ' beginning a new escape sequence
        
                            Case ANSI_RS, ANSI_US ' QB64 does non-ANSI stuff with these two when ControlChar is On
                                _ControlChr Off
                                Print Chr$(ch); ' print escaped ESC character
                                _ControlChr On
                                If __ANSIEmu.CPS > 0 Then _Limit __ANSIEmu.CPS ' limit the loop speed if char/sec is a positive value
        
                            Case Else ' print the character
                                Print Chr$(ch);
                                If __ANSIEmu.CPS > 0 Then _Limit __ANSIEmu.CPS ' limit the loop speed if char/sec is a positive value
        
                        End Select
        
                    Case ANSI_STATE_BEGIN ' handle escape sequence
                        Select Case ch
                            Case Is < ANSI_SP ' handle escaped character
                                _ControlChr Off
                                Print Chr$(ch); ' print escaped ESC character
                                _ControlChr On
                                If __ANSIEmu.CPS > 0 Then _Limit __ANSIEmu.CPS ' limit the loop speed if char/sec is a positive value
                                __ANSIEmu.state = ANSI_STATE_TEXT
        
                            Case ANSI_ESC_DECSC ' Save Cursor Position in Memory
                                __ANSIEmu.posDEC.x = Pos(0)
                                __ANSIEmu.posDEC.y = CsrLin
                                __ANSIEmu.state = ANSI_STATE_TEXT
        
                            Case ANSI_ESC_DECSR ' Restore Cursor Position from Memory
                                Locate __ANSIEmu.posDEC.y, __ANSIEmu.posDEC.x
                                __ANSIEmu.state = ANSI_STATE_TEXT
        
                            Case ANSI_ESC_RI ' Reverse Index
                                y = CsrLin - 1
                                If y > 0 Then Locate y
                                __ANSIEmu.state = ANSI_STATE_TEXT
        
                            Case ANSI_ESC_CSI ' handle CSI
                                ReDim __ANSIArg(1 To UBound(__ANSIArg)) As Long ' reset the control sequence arguments, but don't loose the allocated memory
                                __ANSIEmu.argIndex = 0 ' reset argument index
                                'leadInPrefix = 0 ' reset lead-in prefix
                                __ANSIEmu.state = ANSI_STATE_SEQUENCE
        
                            Case Else ' throw an error for stuff we are not handling
                                Error ERROR_FEATURE_UNAVAILABLE
        
                        End Select
        
                    Case ANSI_STATE_SEQUENCE ' handle CSI sequence
                        Select Case ch
                            Case ANSI_0 To ANSI_QUESTION_MARK ' argument bytes
                                If __ANSIEmu.argIndex < 1 Then __ANSIEmu.argIndex = 1 ' set the argument index to one if this is the first time
        
                                Select Case ch
                                    Case ANSI_0 To ANSI_9 ' handle sequence numeric arguments
                                        __ANSIArg(__ANSIEmu.argIndex) = __ANSIArg(__ANSIEmu.argIndex) * 10 + ch - ANSI_0
        
                                    Case ANSI_SEMICOLON ' handle sequence argument seperators
                                        __ANSIEmu.argIndex = __ANSIEmu.argIndex + 1 ' increment the argument index
                                        If __ANSIEmu.argIndex > UBound(__ANSIArg) Then ReDim _Preserve __ANSIArg(1 To __ANSIEmu.argIndex) As Long ' dynamically expand the argument list if needed
        
                                    Case ANSI_EQUALS_SIGN, ANSI_GREATER_THAN_SIGN, ANSI_QUESTION_MARK ' handle lead-in prefix
                                        ' NOP: leadInPrefix = ch ' just save the prefix type
        
                                    Case Else ' throw an error for stuff we are not handling
                                        Error ERROR_FEATURE_UNAVAILABLE
        
                                End Select
        
                            Case ANSI_SP To ANSI_SLASH ' intermediate bytes
                                Select Case ch
                                    Case ANSI_SP ' ignore spaces
                                        ' NOP
        
                                    Case Else ' throw an error for stuff we are not handling
                                        Error ERROR_FEATURE_UNAVAILABLE
        
                                End Select
        
                            Case ANSI_AT_SIGN To ANSI_TILDE ' final byte
                                Select Case ch
                                    Case ANSI_ESC_CSI_SM, ANSI_ESC_CSI_RM ' Set and reset screen mode
                                        If __ANSIEmu.argIndex > 1 Then Error ERROR_CANNOT_CONTINUE ' was not expecting more than 1 arg
        
                                        Select Case __ANSIArg(1)
                                            Case 0 To 6, 14 To 18 ' all mode changes are ignored. the screen type must be set by the caller
                                                ' NOP
        
                                            Case 7 ' Enable / disable line wrapping
                                                ' NOP: QB64 does line wrapping by default
                                                If ANSI_ESC_CSI_RM = ch Then ' ANSI_ESC_CSI_RM disable line wrapping unsupported
                                                    Error ERROR_FEATURE_UNAVAILABLE
                                                End If
        
                                            Case 12 ' Text Cursor Enable / Disable Blinking
                                                ' NOP
        
                                            Case 25 ' make cursor visible / invisible
                                                If ANSI_ESC_CSI_SM = ch Then ' ANSI_ESC_CSI_SM make cursor visible
                                                    Locate , , 1
                                                Else ' ANSI_ESC_CSI_RM make cursor invisible
                                                    Locate , , 0
                                                End If
        
                                            Case Else ' throw an error for stuff we are not handling
                                                Error ERROR_FEATURE_UNAVAILABLE
        
                                        End Select
        
                                    Case ANSI_ESC_CSI_ED ' Erase in Display
                                        If __ANSIEmu.argIndex > 1 Then Error ERROR_CANNOT_CONTINUE ' was not expecting more than 1 arg
        
                                        Select Case __ANSIArg(1)
                                            Case 0 ' clear from cursor to end of screen
                                                ClearANSICanvasArea Pos(0), CsrLin, GetANSICanvasWidth, CsrLin ' first clear till the end of the line starting from the cursor
                                                ClearANSICanvasArea 1, CsrLin + 1, GetANSICanvasWidth, GetANSICanvasHeight ' next clear the whole canvas below the cursor
        
                                            Case 1 ' clear from cursor to beginning of the screen
                                                ClearANSICanvasArea 1, CsrLin, Pos(0), CsrLin ' first clear from the beginning of the line till the cursor
                                                ClearANSICanvasArea 1, 1, GetANSICanvasWidth, CsrLin - 1 ' next clear the whole canvas above the cursor
        
                                            Case 2 ' clear entire screen (and moves cursor to upper left like ANSI.SYS)
                                                Cls
        
                                            Case 3 ' clear entire screen and delete all lines saved in the scrollback buffer (scrollback stuff not supported)
                                                ClearANSICanvasArea 1, 1, GetANSICanvasWidth, GetANSICanvasHeight
        
                                            Case Else ' throw an error for stuff we are not handling
                                                Error ERROR_FEATURE_UNAVAILABLE
        
                                        End Select
        
                                    Case ANSI_ESC_CSI_EL ' Erase in Line
                                        If __ANSIEmu.argIndex > 1 Then Error ERROR_CANNOT_CONTINUE ' was not expecting more than 1 arg
        
                                        Select Case __ANSIArg(1)
                                            Case 0 ' erase from cursor to end of line
                                                ClearANSICanvasArea Pos(0), CsrLin, GetANSICanvasWidth, CsrLin
        
                                            Case 1 ' erase start of line to the cursor
                                                ClearANSICanvasArea 1, CsrLin, Pos(0), CsrLin
        
                                            Case 2 ' erase the entire line
                                                ClearANSICanvasArea 1, CsrLin, GetANSICanvasWidth, CsrLin
        
                                            Case Else ' throw an error for stuff we are not handling
                                                Error ERROR_FEATURE_UNAVAILABLE
        
                                        End Select
        
                                    Case ANSI_ESC_CSI_SGR ' Select Graphic Rendition
                                        x = 1 ' start with the first argument
                                        If __ANSIEmu.argIndex < 1 Then __ANSIEmu.argIndex = 1 ' this allows '[m' to be treated as [0m
                                        Do While x <= __ANSIEmu.argIndex ' loop through the argument list and process each argument
                                            Select Case __ANSIArg(x)
                                                Case 0 ' reset all modes (styles and colors)
                                                    __ANSIEmu.fC = ANSI_DEFAULT_COLOR_FOREGROUND
                                                    __ANSIEmu.bC = ANSI_DEFAULT_COLOR_BACKGROUND
                                                    __ANSIEmu.isBold = FALSE
                                                    __ANSIEmu.isBlink = FALSE
                                                    __ANSIEmu.isInvert = FALSE
                                                    SetANSICanvasColor __ANSIEmu.fC, __ANSIEmu.isInvert, TRUE
                                                    SetANSICanvasColor __ANSIEmu.bC, Not __ANSIEmu.isInvert, TRUE
        
                                                Case 1 ' enable high intensity colors
                                                    If __ANSIEmu.fC < 8 Then __ANSIEmu.fC = __ANSIEmu.fC + 8
                                                    __ANSIEmu.isBold = TRUE
                                                    SetANSICanvasColor __ANSIEmu.fC, __ANSIEmu.isInvert, TRUE
        
                                                Case 2, 22 ' enable low intensity, disable high intensity colors
                                                    If __ANSIEmu.fC > 7 Then __ANSIEmu.fC = __ANSIEmu.fC - 8
                                                    __ANSIEmu.isBold = FALSE
                                                    SetANSICanvasColor __ANSIEmu.fC, __ANSIEmu.isInvert, TRUE
        
                                                Case 3, 4, 23, 24 ' set / reset italic & underline mode ignored
                                                    ' NOP: This can be used if we load monospaced TTF fonts using 'italics', 'underline' properties
        
                                                Case 5, 6 ' turn blinking on
                                                    If __ANSIEmu.bC < 8 Then __ANSIEmu.bC = __ANSIEmu.bC + 8
                                                    __ANSIEmu.isBlink = TRUE
                                                    SetANSICanvasColor __ANSIEmu.bC, Not __ANSIEmu.isInvert, TRUE
        
                                                Case 7 ' enable reverse video
                                                    If Not __ANSIEmu.isInvert Then
                                                        __ANSIEmu.isInvert = TRUE
                                                        SetANSICanvasColor __ANSIEmu.fC, __ANSIEmu.isInvert, TRUE
                                                        SetANSICanvasColor __ANSIEmu.bC, Not __ANSIEmu.isInvert, TRUE
                                                    End If
        
                                                Case 25 ' turn blinking off
                                                    If __ANSIEmu.bC > 7 Then __ANSIEmu.bC = __ANSIEmu.bC - 8
                                                    __ANSIEmu.isBlink = FALSE
                                                    SetANSICanvasColor __ANSIEmu.bC, Not __ANSIEmu.isInvert, TRUE
        
                                                Case 27 ' disable reverse video
                                                    If __ANSIEmu.isInvert Then
                                                        __ANSIEmu.isInvert = FALSE
                                                        SetANSICanvasColor __ANSIEmu.fC, __ANSIEmu.isInvert, TRUE
                                                        SetANSICanvasColor __ANSIEmu.bC, Not __ANSIEmu.isInvert, TRUE
                                                    End If
        
                                                Case 30 To 37 ' set foreground color
                                                    __ANSIEmu.fC = __ANSIArg(x) - 30
                                                    If __ANSIEmu.isBold Then __ANSIEmu.fC = __ANSIEmu.fC + 8
                                                    SetANSICanvasColor __ANSIEmu.fC, __ANSIEmu.isInvert, TRUE
        
                                                Case 38 ' set 8-bit 256 or 24-bit RGB foreground color
                                                    z = __ANSIEmu.argIndex - x ' get the number of arguments remaining
        
                                                    If __ANSIArg(x + 1) = 2 And z >= 4 Then ' 32bpp color with 5 arguments
                                                        __ANSIEmu.fC = _RGB32(__ANSIArg(x + 2) And &HFF, __ANSIArg(x + 3) And &HFF, __ANSIArg(x + 4) And &HFF)
                                                        SetANSICanvasColor __ANSIEmu.fC, __ANSIEmu.isInvert, FALSE
        
                                                        x = x + 4 ' skip to last used arg
        
                                                    ElseIf __ANSIArg(x + 1) = 5 And z >= 2 Then ' 256 color with 3 arguments
                                                        __ANSIEmu.fC = __ANSIArg(x + 2)
                                                        SetANSICanvasColor __ANSIEmu.fC, __ANSIEmu.isInvert, TRUE
        
                                                        x = x + 2 ' skip to last used arg
        
                                                    Else
                                                        Error ERROR_CANNOT_CONTINUE
        
                                                    End If
        
                                                Case 39 ' set default foreground color
                                                    __ANSIEmu.fC = ANSI_DEFAULT_COLOR_FOREGROUND
                                                    SetANSICanvasColor __ANSIEmu.fC, __ANSIEmu.isInvert, TRUE
        
                                                Case 40 To 47 ' set background color
                                                    __ANSIEmu.bC = __ANSIArg(x) - 40
                                                    If __ANSIEmu.isBlink Then __ANSIEmu.bC = __ANSIEmu.bC + 8
                                                    SetANSICanvasColor __ANSIEmu.bC, Not __ANSIEmu.isInvert, TRUE
        
                                                Case 48 ' set 8-bit 256 or 24-bit RGB background color
                                                    z = __ANSIEmu.argIndex - x ' get the number of arguments remaining
        
                                                    If __ANSIArg(x + 1) = 2 And z >= 4 Then ' 32bpp color with 5 arguments
                                                        __ANSIEmu.bC = _RGB32(__ANSIArg(x + 2) And &HFF, __ANSIArg(x + 3) And &HFF, __ANSIArg(x + 4) And &HFF)
                                                        SetANSICanvasColor __ANSIEmu.bC, Not __ANSIEmu.isInvert, FALSE
        
                                                        x = x + 4 ' skip to last used arg
        
                                                    ElseIf __ANSIArg(x + 1) = 5 And z >= 2 Then ' 256 color with 3 arguments
                                                        __ANSIEmu.bC = __ANSIArg(x + 2)
                                                        SetANSICanvasColor __ANSIEmu.bC, Not __ANSIEmu.isInvert, TRUE
        
                                                        x = x + 2 ' skip to last used arg
        
                                                    Else
                                                        Error ERROR_CANNOT_CONTINUE
        
                                                    End If
        
                                                Case 49 ' set default background color
                                                    __ANSIEmu.bC = ANSI_DEFAULT_COLOR_BACKGROUND
                                                    SetANSICanvasColor __ANSIEmu.bC, Not __ANSIEmu.isInvert, TRUE
        
                                                Case 90 To 97 ' set high intensity foreground color
                                                    __ANSIEmu.fC = 8 + __ANSIArg(x) - 90
                                                    SetANSICanvasColor __ANSIEmu.fC, __ANSIEmu.isInvert, TRUE
        
                                                Case 100 To 107 ' set high intensity background color
                                                    __ANSIEmu.bC = 8 + __ANSIArg(x) - 100
                                                    SetANSICanvasColor __ANSIEmu.bC, Not __ANSIEmu.isInvert, TRUE
        
                                                Case Else ' throw an error for stuff we are not handling
                                                    Error ERROR_FEATURE_UNAVAILABLE
        
                                            End Select
        
                                            x = x + 1 ' move to the next argument
                                        Loop
        
                                    Case ANSI_ESC_CSI_SCP ' Save Current Cursor Position (SCO)
                                        If __ANSIEmu.argIndex > 0 Then Error ERROR_CANNOT_CONTINUE ' was not expecting args
        
                                        __ANSIEmu.posSCO.x = Pos(0)
                                        __ANSIEmu.posSCO.y = CsrLin
        
                                    Case ANSI_ESC_CSI_RCP ' Restore Saved Cursor Position (SCO)
                                        If __ANSIEmu.argIndex > 0 Then Error ERROR_CANNOT_CONTINUE ' was not expecting args
        
                                        Locate __ANSIEmu.posSCO.y, __ANSIEmu.posSCO.x
        
                                    Case ANSI_ESC_CSI_PABLODRAW_24BPP ' PabloDraw 24-bit ANSI sequences
                                        If __ANSIEmu.argIndex <> 4 Then Error ERROR_CANNOT_CONTINUE ' we need 4 arguments
        
                                        SetANSICanvasColor _RGB32(__ANSIArg(2) And &HFF, __ANSIArg(3) And &HFF, __ANSIArg(4) And &HFF), __ANSIArg(1) = FALSE, FALSE
        
                                    Case ANSI_ESC_CSI_CUP, ANSI_ESC_CSI_HVP ' Cursor position or Horizontal and vertical position
                                        If __ANSIEmu.argIndex > 2 Then Error ERROR_CANNOT_CONTINUE ' was not expecting more than 2 args
        
                                        y = GetANSICanvasHeight
                                        If __ANSIArg(1) < 1 Then
                                            __ANSIArg(1) = 1
                                        ElseIf __ANSIArg(1) > y Then
                                            __ANSIArg(1) = y
                                        End If
        
                                        x = GetANSICanvasWidth
                                        If __ANSIArg(2) < 1 Then
                                            __ANSIArg(2) = 1
                                        ElseIf __ANSIArg(2) > x Then
                                            __ANSIArg(2) = x
                                        End If
        
                                        Locate __ANSIArg(1), __ANSIArg(2) ' line #, column #
        
                                    Case ANSI_ESC_CSI_CUU ' Cursor up
                                        If __ANSIEmu.argIndex > 1 Then Error ERROR_CANNOT_CONTINUE ' was not expecting more than 1 arg
        
                                        If __ANSIArg(1) < 1 Then __ANSIArg(1) = 1
                                        y = CsrLin - __ANSIArg(1)
                                        If y < 1 Then __ANSIArg(1) = 1
                                        Locate y
        
                                    Case ANSI_ESC_CSI_CUD ' Cursor down
                                        If __ANSIEmu.argIndex > 1 Then Error ERROR_CANNOT_CONTINUE ' was not expecting more than 1 arg
        
                                        If __ANSIArg(1) < 1 Then __ANSIArg(1) = 1
                                        y = CsrLin + __ANSIArg(1)
                                        z = GetANSICanvasHeight
                                        If y > z Then y = z
                                        Locate y
        
                                    Case ANSI_ESC_CSI_CUF ' Cursor forward
                                        If __ANSIEmu.argIndex > 1 Then Error ERROR_CANNOT_CONTINUE ' was not expecting more than 1 arg
        
                                        If __ANSIArg(1) < 1 Then __ANSIArg(1) = 1
                                        x = Pos(0) + __ANSIArg(1)
                                        z = GetANSICanvasWidth
                                        If x > z Then x = z
                                        Locate , x
        
                                    Case ANSI_ESC_CSI_CUB ' Cursor back
                                        If __ANSIEmu.argIndex > 1 Then Error ERROR_CANNOT_CONTINUE ' was not expecting more than 1 arg
        
                                        If __ANSIArg(1) < 1 Then __ANSIArg(1) = 1
                                        x = Pos(0) - __ANSIArg(1)
                                        If x < 1 Then x = 1
                                        Locate , x
        
                                    Case ANSI_ESC_CSI_CNL ' Cursor Next Line
                                        If __ANSIEmu.argIndex > 1 Then Error ERROR_CANNOT_CONTINUE ' was not expecting more than 1 arg
        
                                        If __ANSIArg(1) < 1 Then __ANSIArg(1) = 1
                                        y = CsrLin + __ANSIArg(1)
                                        z = GetANSICanvasHeight
                                        If y > z Then y = z
                                        Locate y, 1
        
                                    Case ANSI_ESC_CSI_CPL ' Cursor Previous Line
                                        If __ANSIEmu.argIndex > 1 Then Error ERROR_CANNOT_CONTINUE ' was not expecting more than 1 arg
        
                                        If __ANSIArg(1) < 1 Then __ANSIArg(1) = 1
                                        y = CsrLin - __ANSIArg(1)
                                        If y < 1 Then y = 1
                                        Locate y, 1
        
                                    Case ANSI_ESC_CSI_CHA ' Cursor Horizontal Absolute
                                        If __ANSIEmu.argIndex > 1 Then Error ERROR_CANNOT_CONTINUE ' was not expecting more than 1 arg
        
                                        x = GetANSICanvasWidth
                                        If __ANSIArg(1) < 1 Then
                                            __ANSIArg(1) = 1
                                        ElseIf __ANSIArg(1) > x Then
                                            __ANSIArg(1) = x
                                        End If
                                        Locate , __ANSIArg(1)
        
                                    Case ANSI_ESC_CSI_VPA ' Vertical Line Position Absolute
                                        If __ANSIEmu.argIndex > 1 Then Error ERROR_CANNOT_CONTINUE ' was not expecting more than 1 arg
        
                                        y = GetANSICanvasHeight
                                        If __ANSIArg(1) < 1 Then
                                            __ANSIArg(1) = 1
                                        ElseIf __ANSIArg(1) > y Then
                                            __ANSIArg(1) = y
                                        End If
                                        Locate __ANSIArg(1)
        
                                    Case ANSI_ESC_CSI_DECSCUSR
                                        If __ANSIEmu.argIndex > 1 Then Error ERROR_CANNOT_CONTINUE ' was not expecting more than 1 arg
        
                                        Select Case __ANSIArg(1)
                                            Case 0, 3, 4 ' Default, Blinking & Steady underline cursor shape
                                                Locate , , , 29, 31 ' this should give a nice underline cursor
        
                                            Case 1, 2 ' Blinking & Steady block cursor shape
                                                Locate , , , 0, 31 ' this should give a full block cursor
        
                                            Case 5, 6 ' Blinking & Steady bar cursor shape
                                                Locate , , , 16, 31 ' since we cannot get a bar cursor in QB64, we'll just use a half-block cursor
        
                                            Case Else ' throw an error for stuff we are not handling
                                                Error ERROR_FEATURE_UNAVAILABLE
        
                                        End Select
        
                                    Case Else ' throw an error for stuff we are not handling
                                        Error ERROR_FEATURE_UNAVAILABLE
        
                                End Select
        
                                ' End of sequence
                                __ANSIEmu.state = ANSI_STATE_TEXT
        
                            Case Else ' throw an error for stuff we are not handling
                                Error ERROR_FEATURE_UNAVAILABLE
        
                        End Select
        
                    Case ANSI_STATE_END ' end of the stream has been reached
                        ANSI_PrintCharacter& = FALSE ' tell the caller the we should stop processing the rest of the stream
                        Exit Function ' and then leave
        
                    Case Else ' this should never happen
                        Error ERROR_CANNOT_CONTINUE
        
                End Select
            End Function
        
        
            ' Processes the whole string instead of a character like ANSI_PrintCharacter()
            ' This simply wraps ANSI_PrintCharacter()
            Function ANSI_PrintString& (s As String)
                Dim As Long i
        
                ANSI_PrintString = TRUE
        
                For i = 1 To Len(s)
                    If Not ANSI_PrintCharacter(Asc(s, i)) Then
                        ANSI_PrintString = FALSE ' signal end of stream
                        Exit Function
                    End If
                Next
            End Function
        
        
            ' A simple routine that wraps pretty much the whole library
            ' It will reset the library, do the setup and then render the whole ANSI string in one go
            ' ControlChr is properly restored
            Sub ANSI_Print (sANSI As String)
                Dim As Long oldControlChr ' to save old ContolChr
        
                ' Save the old ControlChr state
                oldControlChr = _ControlChr
        
                ResetANSIEmulator ' reset the emulator
        
                Dim dummy As Long: dummy = ANSI_PrintString(sANSI) ' print the ANSI string and ignore the return value
        
                ' Set ControlChr the way we found it
                If oldControlChr Then
                    _ControlChr Off
                Else
                    _ControlChr On
                End If
            End Sub
        
        
            ' Set the foreground or background color
            Sub SetANSICanvasColor (c As _Unsigned Long, isBackground As Long, isLegacy As Long)
                Shared __ANSIColorLUT() As _Unsigned Long
        
                Dim nRGB As _Unsigned Long
        
                If isLegacy Then
                    nRGB = __ANSIColorLUT(c)
                Else
                    nRGB = c
                End If
        
                If isBackground Then
                    ' Echo "Background color" + Str$(c) + " (" + Hex$(nRGB) + ")"
                    Color , nRGB
                Else
                    ' Echo "Foreground color" + Str$(c) + " (" + Hex$(nRGB) + ")"
                    Color nRGB
                End If
            End Sub
        
        
            ' Returns the number of characters per line
            Function GetANSICanvasWidth&
                GetANSICanvasWidth = _Width \ _FontWidth ' this will cause a divide by zero if a variable width font is used; use monospaced fonts to avoid this
            End Function
        
        
            ' Returns the number of lines
            Function GetANSICanvasHeight&
                GetANSICanvasHeight = _Height \ _FontHeight
            End Function
        
        
            ' Clears a given portion of screen without disturbing the cursor location and colors
            Sub ClearANSICanvasArea (l As Long, t As Long, r As Long, b As Long)
                Dim As Long i, w, x, y
                Dim As _Unsigned Long fc, bc
        
                w = 1 + r - l ' calculate width
        
                If w > 0 And t <= b Then ' only proceed is width is > 0 and height is > 0
                    ' Save some stuff
                    fc = _DefaultColor
                    bc = _BackgroundColor
                    x = Pos(0)
                    y = CsrLin
        
                    Color &HFF000000, &HFF000000 ' lights out
        
                    For i = t To b
                        Locate i, l: Print Space$(w); ' fill with SPACE
                    Next
        
                    ' Restore saved stuff
                    Color fc, bc
                    Locate y, x
                End If
            End Sub
            '-----------------------------------------------------------------------------------------------------------------------------------------------------------
        $End If
        '---------------------------------------------------------------------------------------------------------------------------------------------------------------
