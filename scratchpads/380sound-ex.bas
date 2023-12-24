OPTION _EXPLICIT

DIM Q AS STRING

' Sound effects menu
DO
    CLS
    PRINT "Sound effects": PRINT
    COLOR 14, 0: PRINT "  B";: COLOR 7, 0: PRINT "ouncing"
    COLOR 14, 0: PRINT "  F";: COLOR 7, 0: PRINT "alling"
    COLOR 14, 0: PRINT "  K";: COLOR 7, 0: PRINT "laxon"
    COLOR 14, 0: PRINT "  S";: COLOR 7, 0: PRINT "iren"
    COLOR 14, 0: PRINT "  Q";: COLOR 7, 0: PRINT "uit"
    PRINT: PRINT "Select: ";

    ' Get valid key
    DO
        Q = UCASE$(INPUT$(1))
    LOOP WHILE INSTR("BFKSQ", Q) = 0

    ' Take action based on key
    CLS
    SELECT CASE Q
        CASE IS = "B"
            PRINT "Bouncing . . . "
            Bounce 32767, 246 ' the 32767 will make the PSG generate silence (exactly like QB45 does)
        CASE IS = "F"
            PRINT "Falling . . . "
            Fall 2000, 550, 500
        CASE IS = "S"
            PRINT "Wailing . . ."
            PRINT " . . . press any key to end."
            Siren 780, 650
        CASE IS = "K"
            PRINT "Oscillating . . ."
            PRINT " . . . press any key to end."
            Klaxon 987, 329
        CASE ELSE
    END SELECT
LOOP UNTIL Q = "Q"
END

' Loop two sounds down at decreasing time intervals
SUB Bounce (Hi AS LONG, Low AS LONG)
    DIM count AS LONG

    PLAY "Q0" ' turn off volume ramping

    FOR count = 60 TO 1 STEP -2
        SOUND Low - count / 2, count / 20, 1.0!, 0.0!, 1
        SOUND Hi, count / 15
    NEXT
END SUB

' Loop down from a high sound to a low sound
SUB Fall (Hi AS LONG, Low AS LONG, Del AS LONG)
    DIM vol AS SINGLE
    DIM count AS LONG

    PLAY "Q3" ' enable 3ms volume ramping

    FOR count = Hi TO Low STEP -10
        vol = 1.0! - vol
        SOUND count, Del / count, vol, 0.0!, 3 ' triangle wave
    NEXT
END SUB

' Alternate two sounds until a key is pressed
SUB Klaxon (Hi AS LONG, Low AS LONG)
    PLAY "Q5" ' enable 5ms volume ramping

    DO WHILE INKEY$ = ""
        SOUND Hi, 5!, 1.0!, -1.0!, 4
        SOUND Low, 5!, 1.0!, 1.0!, 4
    LOOP
END SUB

' Loop a sound from low to high to low
SUB Siren (Hi AS LONG, Range AS LONG)
    DIM count AS LONG, pan AS SINGLE
    DIM dir AS SINGLE: dir = 0.01!

    PLAY "Q0" ' disable volume ramping

    DO WHILE INKEY$ = ""
        FOR count = Range TO -Range STEP -4
            pan = pan + dir
            IF pan <= -1.0! THEN dir = 0.01!: pan = -1.0!
            IF pan >= 1.0! THEN dir = -0.01!: pan = 1.0!

            SOUND Hi - ABS(count), 0.3!, 1.0!, pan, 4 ' sine wave

            count = count - 2 / Range
        NEXT
    LOOP
END SUB
