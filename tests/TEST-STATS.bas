$CONSOLE:ONLY
'$INCLUDE:'TESTLIB.bi'

' ============================================================================
'  engine/STATS.bas -- CSV append plumbing + the schema-drift ROTATE policy.
'
'  The interesting behaviour is StatHeaderReady%: when an existing file's header
'  differs from the one about to be written, its columns mean something else, so
'  the stale file is renamed aside (.old, .old2, ...) and a clean one started.
'  Neither data nor logging is lost. These cases pin that down, including the two
'  edge cases that are easy to get wrong: an existing-but-EMPTY file (must NOT
'  rotate) and a rotation writing the header to the fresh file (it must, which
'  requires deciding "is this new?" AFTER the guard runs, not before).
' ============================================================================

DIM SHARED TMP AS STRING
TMP = "tests/tmp"

T_Begin "engine/STATS.bas"
IF _DIREXISTS(TMP) = 0 THEN MKDIR TMP    ' MKDIR on an existing dir is a runtime error, not a no-op
Clean

DIM P AS STRING
P = TMP + "/stats.csv"

'--- CsvCell$: commas/newlines would break the row; empty becomes a placeholder ---
T_Group "CsvCell$"
T_EqS "plain passes through", CsvCell$("GIANT RATS"), "GIANT RATS"
T_EqS "trims", CsvCell$("  ogre  "), "ogre"
T_EqS "comma -> space", CsvCell$("a,b"), "a b"
T_EqS "newline -> space", CsvCell$("a" + CHR$(10) + "b"), "a b"
T_EqS "CR -> space", CsvCell$("a" + CHR$(13) + "b"), "a b"
T_EqS "empty -> ?", CsvCell$(""), "?"
T_EqS "whitespace-only -> ?", CsvCell$("   "), "?"

T_Group "Bit$"
T_EqS "true -> 1", Bit$(-1), "1"
T_EqS "false -> 0", Bit$(0), "0"
T_EqS "nonzero -> 1", Bit$(7), "1"

'--- 1. a brand-new file gets the header, then the row ---
T_Group "fresh file"
StatAppend P, "a,b,c", "1,2,3"
T_EqS "header then row", T_ReadAll$(P), "a,b,c" + CHR$(10) + "1,2,3"
T_FileIs "no archive made", P + ".old", 0

'--- 2. same schema: append only, no second header, no rotation ---
T_Group "same schema"
StatAppend P, "a,b,c", "4,5,6"
T_EqS "one header, two rows", T_ReadAll$(P), "a,b,c" + CHR$(10) + "1,2,3" + CHR$(10) + "4,5,6"
T_FileIs "still no archive", P + ".old", 0

'--- 3. drift: the stale file is retired and a clean one started ---
T_Group "schema drift -> rotate"
StatAppend P, "a,b,c,d", "7,8,9,10"
T_EqS "new file has NEW header + row", T_ReadAll$(P), "a,b,c,d" + CHR$(10) + "7,8,9,10"
T_FileIs ".old created", P + ".old", -1
T_EqS ".old keeps the old rows intact", T_ReadAll$(P + ".old"), "a,b,c" + CHR$(10) + "1,2,3" + CHR$(10) + "4,5,6"

'--- 4. drift again: next free slot, the first archive untouched ---
T_Group "second drift -> .old2"
StatAppend P, "z", "99"
T_EqS "current file rebuilt again", T_ReadAll$(P), "z" + CHR$(10) + "99"
T_EqS ".old NOT clobbered", T_ReadAll$(P + ".old"), "a,b,c" + CHR$(10) + "1,2,3" + CHR$(10) + "4,5,6"
T_EqS ".old2 holds the 2nd schema", T_ReadAll$(P + ".old2"), "a,b,c,d" + CHR$(10) + "7,8,9,10"

'--- 5. an existing but EMPTY file: append the header, do NOT rotate ---
T_Group "existing empty file"
Clean
DIM f AS INTEGER
f = FREEFILE: OPEN P FOR OUTPUT AS #f: CLOSE #f
StatAppend P, "q,r", "11,12"
T_EqS "header written into the empty file", T_ReadAll$(P), "q,r" + CHR$(10) + "11,12"
T_FileIs "no spurious rotation", P + ".old", 0

'--- 6. a file whose header was written CRLF still matches (no needless rotate) ---
T_Group "CRLF-written header"
Clean
f = FREEFILE: OPEN P FOR OUTPUT AS #f
PRINT #f, "a,b,c" + CHR$(13);
CLOSE #f
StatAppend P, "a,b,c", "1,2,3"
T_FileIs "tolerated, not rotated", P + ".old", 0

Clean
T_Done

' Remove every scratch file this suite can create.
SUB Clean
    DIM i AS INTEGER, nm AS STRING
    T_Rm TMP + "/stats.csv"
    T_Rm TMP + "/stats.csv.old"
    FOR i = 2 TO 5
        T_Rm TMP + "/stats.csv.old" + _TRIM$(STR$(i))
    NEXT i
END SUB

'$INCLUDE:'TESTLIB.bas'
'$INCLUDE:'../engine/STATS.bas'
