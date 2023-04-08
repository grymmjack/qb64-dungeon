'$Include:'./include/Toolbox64/ANSIPrint.bi'

DIM AS LONG CANVAS, TEMP_SCREEN, MAIN_SCREEN, BOARD_SCREEN, INTRO_SCREEN
DIM AS STRING MAIN_ANSI, BOARD_ANSI, INTRO_ANSI

BOARD_ANSI$ = LoadFileFromDisk$("assets/ansi/board-120x50.ans")

CANVAS& = _NEWIMAGE(120 * 8, 50 * 16, 32)
_FONT 16
SCREEN CANVAS&

BOARD_SCREEN& = _NEWIMAGE(120 * 8, 50 * 16, 32)
_DEST(BOARD_SCREEN&)
PrintANSI(BOARD_ANSI$)

SLEEP

SCREEN BOARD_SCREEN&

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
