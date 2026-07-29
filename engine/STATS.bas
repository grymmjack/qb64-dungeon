' ============================================================================
'  STATS.bas -- ENGINE append-only CSV log plumbing (game-agnostic).
'
'  The engine owns the FILE: open/append/close, and writing a header row the first
'  time the file is created. It owns nothing about the COLUMNS -- the game builds its
'  own header + row (see StatLog in game/COMBAT.bas) and hands them over as strings.
'  That keeps this file free of the game's run schema (class, char level, gold...).
'
'  Used for dungeon-stats.csv: one row per resolved fight, for difficulty analysis.
'  Load it in a spreadsheet to see how monsters/levels/rooms play out.
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

' Append one pre-built row to a CSV, writing `header` first if the file is new.
' Pure plumbing: the caller owns what the columns mean.
'
' Schema drift: when the caller's column set changes, an existing file still carries the
' OLD header, so new rows would silently misalign under it. StatHeaderReady% guards that
' (see below) and may retire the stale file, so "is this file new?" must be decided AFTER
' the guard runs -- hence LOF(f) rather than a _FILEEXISTS captured up front. LOF is 0 for
' a file that was just created by this OPEN *and* for one the guard just rotated away.
SUB StatAppend (path AS STRING, header AS STRING, row AS STRING)
    DIM f AS INTEGER
    IF _FILEEXISTS(path) THEN
        IF NOT StatHeaderReady%(path, header) THEN EXIT SUB   ' guard declined the write
    END IF
    f = FREEFILE
    OPEN path FOR APPEND AS #f
    IF LOF(f) = 0 THEN PRINT #f, header      ' brand-new or freshly rotated -- lead with the header
    PRINT #f, row
    CLOSE #f
END SUB

' Schema-drift guard for an EXISTING csv at `path`. Returns TRUE if StatAppend may write.
'
' Policy: ROTATE. If the file's first line is not exactly `header`, its columns mean
' something different from what we are about to append, so the stale file is RENAMED aside
' (path + ".old", then ".old2", ".old3"... so repeated schema changes never clobber an
' earlier archive) and we return TRUE -- StatAppend then finds no file and starts a clean
' one with the current header. Nothing is lost: the old runs stay readable in the archive
' and new runs keep logging, which the two alternatives (append anyway = silently corrupt
' the analysis; skip = silently stop logging) each give up one half of.
'
' An existing-but-EMPTY file is fine to append to -- StatAppend's LOF check writes the header.
FUNCTION StatHeaderReady% (path AS STRING, header AS STRING)
    DIM f AS INTEGER, ln AS STRING, bak AS STRING, n AS INTEGER
    StatHeaderReady% = -1
    f = FREEFILE
    OPEN path FOR INPUT AS #f
    IF EOF(f) THEN CLOSE #f: EXIT FUNCTION           ' empty file -- append writes the header
    LINE INPUT #f, ln
    CLOSE #f
    IF RIGHT$(ln, 1) = CHR$(13) THEN ln = LEFT$(ln, LEN(ln) - 1)   ' tolerate a CRLF-written file
    IF _TRIM$(ln) = _TRIM$(header) THEN EXIT FUNCTION               ' same schema -- append

    '--- drift: retire the stale file to the first free .old slot ---
    bak = path + ".old": n = 1
    DO WHILE _FILEEXISTS(bak)
        n = n + 1
        IF n > 99 THEN StatHeaderReady% = 0: EXIT FUNCTION   ' archives exhausted: decline rather than clobber
        bak = path + ".old" + _TRIM$(STR$(n))
    LOOP
    NAME path AS bak
END FUNCTION
