'$Include:'../ANSIPrint/include/ANSIPrint.bi'
'$Include:'../ANSIPrint/include/Base64.bi'


DIM AS LONG TEMP_SCREEN, MAIN_SCREEN, BOARD_SCREEN, INTRO_SCREEN
DIM AS STRING MAIN_ANSI, BOARD_ANSI, INTRO_ANSI

BOARD_ANSI$ = LoadFileFromDisk$("ansi/board.ans")

SCREEN 0
WIDTH 80, 43
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

'$Include:'../ANSIPrint/include/ANSIPrint.bas'
'$Include:'../ANSIPrint/include/Base64.bas'
