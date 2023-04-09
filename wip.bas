'$Include:'./include/Toolbox64/ANSIPrint.bi'

DIM AS LONG CANVAS, TEMP_SCREEN, MAIN_SCREEN, BOARD_SCREEN, INTRO_SCREEN
DIM AS STRING MAIN_ANSI, BOARD_ANSI, INTRO_ANSI

DIM AS LONG MUSIC_INTRO, MUSIC_MAIN, MUSIC_FIGHT, MUSIC_TREASURE
DIM AS LONG SFX_DICE, SFX_MOVE, SFX_DOOR, SFX_SWORD, SFX_SPELL, SFX_HURT, SFX_DIE, SFX_TREASURE


INTRO_ANSI$ = LoadFileFromDisk$("assets/ansi/vermin-radioactive-logo.ans")
BOARD_ANSI$ = LoadFileFromDisk$("assets/ansi/board-120x50.ans")

CANVAS& = _NEWIMAGE(120 * 8, 50 * 16, 32)
_FONT 16
SCREEN CANVAS&

MUSIC_INTRO& = _SNDOPEN("assets/music/vermin-radioactive-theme.rad")
IF MUSIC_INTRO& <= 0 THEN BEEP ELSE _SNDPLAY MUSIC_INTRO&

INTRO_SCREEN& = _NEWIMAGE(120 * 8, 50 * 16, 32)
_DEST(INTRO_SCREEN&)
PrintANSI(INTRO_ANSI$)
SCREEN INTRO_SCREEN&
SLEEP 
_SNDSTOP MUSIC_INTRO&
_SNDCLOSE MUSIC_INTRO&

BOARD_SCREEN& = _NEWIMAGE(120 * 8, 50 * 16, 32)
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


' Loads a whole file from disk into memory
Function LoadFileFromDisk$ (path As String)
    If FileExists(path) Then
        Dim As Long fh: fh = FreeFile

        Open path For Binary Access Read As fh

        LoadFileFromDisk = Input$(LOF(fh), fh)

        Close fh
    End If
End Function

'$Include:'./include/Toolbox64/ANSIPrint.bas'
