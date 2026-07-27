' ============================================================================
'  STATS.bas -- append-only combat stats log for difficulty analysis
'
'  Every resolved fight appends one row to dungeon-stats.csv (git-ignored). Load
'  it in a spreadsheet to see how monsters/levels/rooms play out: kills, damage
'  dealt vs taken, rounds, HP + gold after, wandering vs lair, boss, and outcome.
'  A header row is written when the file is first created.
' ============================================================================

' Make a value safe for a CSV cell: trim, and turn commas/newlines into spaces.
FUNCTION CsvCell$ (s AS STRING)
    DIM t AS STRING, i AS INTEGER, ch2 AS STRING
    t = _TRIM$(s)
    IF t = "" THEN CsvCell$ = "?": EXIT FUNCTION
    FOR i = 1 TO LEN(t)
        ch2 = MID$(t, i, 1)
        IF ch2 = "," OR ch2 = CHR$(10) OR ch2 = CHR$(13) THEN MID$(t, i, 1) = " "
    NEXT i
    CsvCell$ = t
END FUNCTION

FUNCTION Bit$ (b AS INTEGER)
    IF b THEN Bit$ = "1" ELSE Bit$ = "0"
END FUNCTION

' Append one fight's outcome. dlevel = dungeon level, roomid = ROOMS() index,
' outcome = "killed"/"fled"/"died", dealt/taken = HP totals over the fight.
SUB StatLog (dlevel AS INTEGER, roomid AS INTEGER, mon AS STRING, boss AS INTEGER, wander AS INTEGER, outcome AS STRING, rounds AS INTEGER, dealt AS INTEGER, taken AS INTEGER)
    DIM f AS INTEGER, newfile AS INTEGER, mode AS STRING
    newfile = (_FILEEXISTS("dungeon-stats.csv") = 0)
    IF opt_oldschool THEN mode = "oldschool" ELSE mode = "dnd"
    f = FREEFILE
    OPEN "dungeon-stats.csv" FOR APPEND AS #f
    IF newfile THEN PRINT #f, "date,time,hero,class,mode,char_level,xp,dungeon_level,room,monster,boss,wandering,outcome,rounds,dmg_dealt,dmg_taken,hp_after,maxhp,gold_after"
    PRINT #f, DATE$ + "," + TIME$ + "," + CsvCell$(player_name) + "," + CsvCell$(class_name) + "," + mode + "," + _TRIM$(STR$(char_level)) + "," + _TRIM$(STR$(char_xp)) + "," + _TRIM$(STR$(dlevel)) + "," + _TRIM$(STR$(roomid)) + "," + CsvCell$(mon) + "," + Bit$(boss) + "," + Bit$(wander) + "," + outcome + "," + _TRIM$(STR$(rounds)) + "," + _TRIM$(STR$(dealt)) + "," + _TRIM$(STR$(taken)) + "," + _TRIM$(STR$(player_hp)) + "," + _TRIM$(STR$(player_maxhp)) + "," + _TRIM$(STR$(gold))
    CLOSE #f
END SUB
