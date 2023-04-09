'$INCLUDE:'const.bas'
'$INCLUDE:'types.bas'
'$INCLUDE:'../include/Toolbox64/ANSIPrint.bi'

DIM CANVAS AS LONG
CANVAS& = _NEWIMAGE(SCREEN_WIDTH, SCREEN_HEIGHT, 32)
_FONT 16
SCREEN CANVAS&

DIM ansi AS STRING
ansi$ = LoadFileFromDisk$("../assets/ansi/board-120x50.ans")
PrintANSI(ansi$)

DO:
    _LIMIT 30
LOOP UNTIL _KEYHIT = 27


FUNCTION grid_x% (x AS INTEGER)
    grid_x = x% * CELL_WIDTH
END FUNCTION

FUNCTION grid_y% (y AS INTEGER)
    grid_y = y% * CELL_HEIGHT
END FUNCTION

' Loads a whole file from disk into memory
Function LoadFileFromDisk$ (path As String)
    If FileExists(path) Then
        Dim As Long fh: fh = FreeFile

        Open path For Binary Access Read As fh

        LoadFileFromDisk = Input$(LOF(fh), fh)

        Close fh
    End If
End Function

'$INCLUDE:'../include/Toolbox64/ANSIPrint.bas'
