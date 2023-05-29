'$INCLUDE:'./include/QB64_GJ_LIB/_GJ_LIB.BI'
'$INCLUDE:'./include/Toolbox64/FileOps.bi'
'$INCLUDE:'./include/Toolbox64/ANSIPrint.bi'

DIM AS LONG CANVAS, TEMP_SCREEN, MAIN_SCREEN, BOARD_SCREEN, INTRO_SCREEN
DIM AS STRING MAIN_ANSI, BOARD_ANSI, INTRO_ANSI

DIM AS LONG MUSIC_INTRO, MUSIC_MAIN, MUSIC_FIGHT, MUSIC_TREASURE
DIM AS LONG SFX_DICE, SFX_MOVE, SFX_DOOR, SFX_SWORD, SFX_SPELL, SFX_HURT, SFX_DIE, SFX_TREASURE

INTRO_ANSI$ = LoadFile$("assets/ansi/vermin-radioactive-logo.ans")
BOARD_ANSI$ = LoadFile$("assets/ansi/board-132x50-no-secrets.ans")

CONST SW = 132  ' SCREEN WIDTH IN CHARACTERS
CONST SH = 51   ' SCREEN HEIGHT IN CHARACTERS
CONST CW = 8    ' WIDTH OF 1 CHARACTER
CONST CH = 16   ' HEIGHT OF 1 CHARACTER

$RESIZE:ON
$RESIZE:STRETCH
CANVAS& = _NEWIMAGE(SW * CW, SH * CH, 32)
_FONT CH
SCREEN CANVAS&
_FULLSCREEN _SQUAREPIXELS, _SMOOTH

MUSIC_INTRO& = _SNDOPEN("assets/music/vermin-radioactive-theme.rad")
IF MUSIC_INTRO& <= 0 THEN BEEP ELSE _SNDPLAY MUSIC_INTRO&

INTRO_SCREEN& = _NEWIMAGE(SW * CW, SH * CH, 32)
SetANSIEmulationSpeed(1)
_DEST(INTRO_SCREEN&)
PrintANSI(INTRO_ANSI$)
SCREEN INTRO_SCREEN&
SLEEP 
_SNDSTOP MUSIC_INTRO&
_SNDCLOSE MUSIC_INTRO&

BOARD_SCREEN& = _NEWIMAGE(SW * CW, SH * CH, 32)
_DEST(BOARD_SCREEN&)
PrintANSI(BOARD_ANSI$)
SCREEN BOARD_SCREEN&
MUSIC_MAIN& = _SNDOPEN("assets/music/everdark.rad")
IF MUSIC_MAIN& <= 0 THEN BEEP ELSE _SNDLOOP MUSIC_MAIN&

DO:
    _LIMIT 30
LOOP UNTIL _KEYHIT = 27

_SNDSTOP MUSIC_MAIN&
_SNDCLOSE MUSIC_MAIN&

'$INCLUDE:'./include/QB64_GJ_LIB/_GJ_LIB.BM'
'$INCLUDE:'./include/Toolbox64/FileOps.bas'
'$INCLUDE:'./include/Toolbox64/ANSIPrint.bas'