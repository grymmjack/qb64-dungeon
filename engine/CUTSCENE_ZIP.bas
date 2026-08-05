' ============================================================================
'  CUTSCENE_ZIP.bas -- read ANSI frames straight out of a .zip.
'
'      anim torch "fx/torch.zip" fps 10
'
'  A zipped set of .ans files is how ANSI art has been shipped since the BBS
'  days, so an animation should be able to stay in that shape rather than being
'  unpacked into a folder of loose frames first.
'
'  ANSI ONLY, and that is a real constraint rather than a shortcut: a .ans is
'  just a string, so it decodes and renders entirely in memory. QB64's
'  _LOADIMAGE takes a PATH and nothing else, so a zipped .png would have to be
'  written to a temp file first -- side effects, cleanup, and a cache to get
'  wrong. Zipped PNGs are simply not supported; loose ones already are.
'
'  THE DECOMPRESSION IS QB64'S OWN, with one wrinkle worth writing down.
'  _INFLATE$ is ZLIB, not raw deflate: it wants a 2-byte header and validates
'  an adler32 trailer. A ZIP entry has neither -- it stores the raw deflate
'  stream on its own. Feeding that in unmodified does not error; it returns a
'  ten-megabyte buffer of nothing, which is exactly the kind of plausible
'  answer that gets mistaken for success. Both halves of the fix are needed:
'
'      _INFLATE$(CHR$(&H78) + CHR$(&H01) + raw, uncompressedSize)
'                \_____ satisfies the format check ____/   \_ stops before
'                                                             the missing
'                                                             adler32 _/
'
'  and the ZIP header hands us that uncompressed size for free.
' ============================================================================

'--- little-endian readers. p is 1-based, as everything in BASIC is. ---
FUNCTION ZipU16& (s AS STRING, p AS LONG)
    IF p < 1 _ORELSE p + 1 > LEN(s) THEN ZipU16& = 0: EXIT FUNCTION
    ZipU16& = ASC(s, p) + ASC(s, p + 1) * 256
END FUNCTION

'--- _UNSIGNED LONG, not LONG: a CRC or an offset with the high bit set is a
'    perfectly ordinary value here and would overflow a signed LONG. ---
FUNCTION ZipU32~& (s AS STRING, p AS LONG)
    IF p < 1 _ORELSE p + 3 > LEN(s) THEN ZipU32~& = 0: EXIT FUNCTION
    ZipU32~& = ASC(s, p) + ASC(s, p + 1) * 256~& + ASC(s, p + 2) * 65536~& + ASC(s, p + 3) * 16777216~&
END FUNCTION

'--- Hold ONE zip in memory. An animation reads a frame per tick, and
'    re-reading the whole archive from disk each time would be absurd. ---
FUNCTION CutZipLoad% (path AS STRING)
    IF _TRIM$(CUT_ZIPPATH) = _TRIM$(path) THEN
        IF LEN(CUT_ZIPDATA) > 0 THEN CutZipLoad% = TRUE: EXIT FUNCTION
    END IF
    IF NOT _FILEEXISTS(path) THEN CutZipLoad% = FALSE: EXIT FUNCTION
    CUT_ZIPDATA = _READFILE$(path)
    CUT_ZIPPATH = path
    CutZipLoad% = (LEN(CUT_ZIPDATA) > 0)
END FUNCTION

' ----------------------------------------------------------------------------
'  Catalogue the archive.
'
'  Read the CENTRAL DIRECTORY, not the local headers. When a zip is written by
'  a streaming tool, bit 3 of the local header's flags says "the sizes are not
'  here, they follow the data" -- and the local header carries zeroes. The
'  central directory always has the real numbers, and the uncompressed size is
'  precisely what _INFLATE$ needs.
'
'  Entries are sorted by NAME, so frame order is the file order an artist sees
'  and not whatever order the archiver happened to write.
' ----------------------------------------------------------------------------
FUNCTION CutZipList% (path AS STRING)
    DIM i AS LONG, eocd AS LONG, n AS INTEGER, cdoff AS LONG, p AS LONG
    DIM nlen AS INTEGER, elen AS INTEGER, clen AS INTEGER, nm AS STRING
    DIM total AS INTEGER, k AS INTEGER

    CUT_ZIPN = 0
    IF CutZipLoad%(path) = 0 THEN CutZipList% = 0: EXIT FUNCTION

    '--- find the End Of Central Directory record: "PK\5\6", scanning back from
    '    the tail because a zip comment of up to 64K may follow it ---
    eocd = 0
    FOR i = LEN(CUT_ZIPDATA) - 21 TO 1 STEP -1
        IF i < 1 THEN EXIT FOR
        IF ASC(CUT_ZIPDATA, i) = 80 THEN
            IF ASC(CUT_ZIPDATA, i + 1) = 75 _ANDALSO ASC(CUT_ZIPDATA, i + 2) = 5 _ANDALSO ASC(CUT_ZIPDATA, i + 3) = 6 THEN
                eocd = i
                EXIT FOR
            END IF
        END IF
    NEXT i
    IF eocd = 0 THEN
        CutErrAdd 2, 0, "not a zip (no end-of-central-directory): " + path
        CutZipList% = 0
        EXIT FUNCTION
    END IF

    total = ZipU16&(CUT_ZIPDATA, eocd + 10)
    cdoff = ZipU32~&(CUT_ZIPDATA, eocd + 16) + 1        ' file offset -> 1-based

    p = cdoff
    FOR k = 1 TO total
        IF p + 45 > LEN(CUT_ZIPDATA) THEN EXIT FOR
        '--- central directory entry: "PK\1\2" ---
        IF ZipU32~&(CUT_ZIPDATA, p) <> &H02014B50 THEN EXIT FOR

        nlen = ZipU16&(CUT_ZIPDATA, p + 28)
        elen = ZipU16&(CUT_ZIPDATA, p + 30)
        clen = ZipU16&(CUT_ZIPDATA, p + 32)
        nm = MID$(CUT_ZIPDATA, p + 46, nlen)

        '--- ANSI only, and no directory entries ---
        IF CutIsAnsi%(nm) THEN
            IF RIGHT$(nm, 1) <> "/" THEN
                IF CUT_ZIPN < CUT_MAXAFRAME THEN
                    CUT_ZIPN = CUT_ZIPN + 1
                    CUT_ZIPNAME(CUT_ZIPN) = nm
                    CUT_ZIPMETHOD(CUT_ZIPN) = ZipU16&(CUT_ZIPDATA, p + 10)
                    CUT_ZIPCSIZE(CUT_ZIPN) = ZipU32~&(CUT_ZIPDATA, p + 20)
                    CUT_ZIPUSIZE(CUT_ZIPN) = ZipU32~&(CUT_ZIPDATA, p + 24)
                    CUT_ZIPOFF(CUT_ZIPN) = ZipU32~&(CUT_ZIPDATA, p + 42)
                    CUT_ZIPCRC(CUT_ZIPN) = ZipU32~&(CUT_ZIPDATA, p + 16)
                END IF
            END IF
        END IF

        p = p + 46 + nlen + elen + clen
    NEXT k

    CutZipSort
    CutZipList% = CUT_ZIPN
END FUNCTION

'--- by name, so frame order is what the artist sees in the folder ---
SUB CutZipSort
    DIM i AS INTEGER, j AS INTEGER
    DIM tn AS STRING, tm AS LONG
    DIM tc AS _UNSIGNED LONG, tu AS _UNSIGNED LONG, tf AS _UNSIGNED LONG, tk AS _UNSIGNED LONG
    FOR i = 1 TO CUT_ZIPN - 1
        FOR j = 1 TO CUT_ZIPN - i
            IF UCASE$(_TRIM$(CUT_ZIPNAME(j))) > UCASE$(_TRIM$(CUT_ZIPNAME(j + 1))) THEN
                tn = CUT_ZIPNAME(j): CUT_ZIPNAME(j) = CUT_ZIPNAME(j + 1): CUT_ZIPNAME(j + 1) = tn
                tm = CUT_ZIPMETHOD(j): CUT_ZIPMETHOD(j) = CUT_ZIPMETHOD(j + 1): CUT_ZIPMETHOD(j + 1) = tm
                tc = CUT_ZIPCSIZE(j): CUT_ZIPCSIZE(j) = CUT_ZIPCSIZE(j + 1): CUT_ZIPCSIZE(j + 1) = tc
                tu = CUT_ZIPUSIZE(j): CUT_ZIPUSIZE(j) = CUT_ZIPUSIZE(j + 1): CUT_ZIPUSIZE(j + 1) = tu
                tf = CUT_ZIPOFF(j): CUT_ZIPOFF(j) = CUT_ZIPOFF(j + 1): CUT_ZIPOFF(j + 1) = tf
                tk = CUT_ZIPCRC(j): CUT_ZIPCRC(j) = CUT_ZIPCRC(j + 1): CUT_ZIPCRC(j + 1) = tk
            END IF
        NEXT j
    NEXT i
END SUB

' ----------------------------------------------------------------------------
'  Pull one entry out, decompressed.
' ----------------------------------------------------------------------------
FUNCTION CutZipRead$ (path AS STRING, idx AS INTEGER)
    DIM lo AS LONG, nlen AS INTEGER, elen AS INTEGER, dstart AS LONG
    DIM raw AS STRING

    CutZipRead$ = ""
    IF idx < 1 _ORELSE idx > CUT_ZIPN THEN EXIT FUNCTION
    IF CutZipLoad%(path) = 0 THEN EXIT FUNCTION

    lo = CUT_ZIPOFF(idx) + 1                            ' local header, 1-based
    IF ZipU32~&(CUT_ZIPDATA, lo) <> &H04034B50 THEN EXIT FUNCTION

    '--- the LOCAL header's name/extra lengths, which may differ from the
    '    central directory's; only the offsets here are trustworthy ---
    nlen = ZipU16&(CUT_ZIPDATA, lo + 26)
    elen = ZipU16&(CUT_ZIPDATA, lo + 28)
    dstart = lo + 30 + nlen + elen

    raw = MID$(CUT_ZIPDATA, dstart, CUT_ZIPCSIZE(idx))
    IF LEN(raw) = 0 THEN EXIT FUNCTION

    DIM got AS STRING
    SELECT CASE CUT_ZIPMETHOD(idx)
        CASE 0                                          ' stored
            got = raw
        CASE 8                                          ' deflate
            '--- see the header note: the zlib wrapper AND the exact size. ---
            got = _INFLATE$(CHR$(&H78) + CHR$(&H01) + raw, CUT_ZIPUSIZE(idx))
        CASE ELSE
            CutErrAdd 2, 0, "zip entry uses unsupported compression method" + STR$(CUT_ZIPMETHOD(idx)) + ": " + _TRIM$(CUT_ZIPNAME(idx))
            EXIT FUNCTION
    END SELECT

    '--- VERIFY. Every zip entry carries a CRC-32 of its uncompressed bytes,
    '    and QB64 has _CRC32, so a truncated or corrupt frame can be caught
    '    and named rather than rendered as garbage. This matters more than
    '    usual here: _INFLATE$ does not error on bad input, it returns a
    '    plausible-looking buffer, so the checksum is the only thing standing
    '    between a damaged archive and a frame of confetti. ---
    IF LEN(got) <> CUT_ZIPUSIZE(idx) THEN
        CutErrAdd 2, 0, "zip entry " + _TRIM$(CUT_ZIPNAME(idx)) + ": expected" + STR$(CUT_ZIPUSIZE(idx)) + " bytes, got" + STR$(LEN(got))
        EXIT FUNCTION
    END IF
    IF _CRC32(got) <> CUT_ZIPCRC(idx) THEN
        CutErrAdd 2, 0, "zip entry " + _TRIM$(CUT_ZIPNAME(idx)) + ": CRC mismatch (the archive is damaged)"
        EXIT FUNCTION
    END IF

    CutZipRead$ = got
END FUNCTION

FUNCTION CutIsZip% (path AS STRING)
    IF RIGHT$(LCASE$(_TRIM$(path)), 4) = ".zip" THEN CutIsZip% = TRUE ELSE CutIsZip% = FALSE
END FUNCTION
