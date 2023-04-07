'$Include:'./include/ANSIPrint/include/ANSIPrint.bi'

DIM AS LONG CANVAS, TEMP_SCREEN, MAIN_SCREEN, BOARD_SCREEN, INTRO_SCREEN
DIM AS STRING MAIN_ANSI, BOARD_ANSI, INTRO_ANSI

BOARD_ANSI$ = LoadFileFromDisk$("assets/ansi/board.ans")

CANVAS& = _NEWIMAGE(80 * 8, 43 * 16, 32)
_FONT 16
SCREEN CANVAS&

PrintANSI(BOARD_ANSI$)

' Loads a whole file from disk into memory
Function LoadFileFromDisk$ (path As String)
    If FileExists(path) Then
        Dim As Long fh: fh = FreeFile

        Open path For Binary Access Read As fh

        LoadFileFromDisk = Input$(LOF(fh), fh)

        Close fh
    End If
End Function

'$Include:'./include/ANSIPrint/include/ANSIPrint.bas'
