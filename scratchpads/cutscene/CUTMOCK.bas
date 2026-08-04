' ============================================================================
'  CUTMOCK.bas -- host hooks for the STANDALONE player.
'
'  The engine reaches the game through eleven Cut_* hooks and nothing else.
'  This file is the proof that the boundary holds: a second, complete "host"
'  that has no dungeon in it at all -- the same argument examples/minimal
'  makes for engine/.
'
'  It also does real work for authoring. State comes from the command line:
'
'      cutplay.run descend-5.cut class=wizard gold=6000 flag.saw_omen=1
'
'  ...so every branch of a conditional scene can be watched without playing
'  the game into that state, which is the difference between testing a branch
'  and hoping about it.
' ============================================================================

FUNCTION Game_CutState# (k AS STRING)
    DIM i AS INTEGER, kk AS STRING
    kk = LCASE$(_TRIM$(k))
    FOR i = 1 TO MOCK_N
        IF LCASE$(_TRIM$(MOCK_K(i))) = kk THEN
            Game_CutState# = MOCK_V(i)
            EXIT FUNCTION
        END IF
    NEXT i
    '--- an unknown key is 0, not an error. A scene written against a state
    '    key the host does not publish should read as "false", not crash the
    '    player mid-scene: same "missing means unchanged" rule as Thm~&. ---
    Game_CutState# = 0
END FUNCTION

FUNCTION Game_CutStateStr$ (k AS STRING)
    DIM i AS INTEGER, kk AS STRING
    kk = LCASE$(_TRIM$(k))
    FOR i = 1 TO MOCK_N
        IF LCASE$(_TRIM$(MOCK_K(i))) = kk THEN
            Game_CutStateStr$ = MOCK_S(i)
            EXIT FUNCTION
        END IF
    NEXT i
    Game_CutStateStr$ = ""
END FUNCTION

SUB Game_CutSetFlag (nm AS STRING, v AS DOUBLE)
    MockSet "flag." + nm, v, LTRIM$(STR$(v))
    MOCK_LOG = MOCK_LOG + "set " + nm + "=" + LTRIM$(STR$(v)) + CHR$(10)
END SUB

SUB Game_CutGrant (what AS STRING, amount AS DOUBLE)
    DIM w AS STRING
    w = LCASE$(_TRIM$(what))
    IF LEFT$(w, 5) = "item:" THEN
        MockSet "item." + MID$(w, 6), 1, "1"
    ELSE
        MockSet w, Game_CutState#(w) + amount, ""
    END IF
    MOCK_LOG = MOCK_LOG + "grant " + w + " " + LTRIM$(STR$(amount)) + CHR$(10)
END SUB

SUB MockSet (k AS STRING, v AS DOUBLE, s AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO MOCK_N
        IF LCASE$(_TRIM$(MOCK_K(i))) = LCASE$(_TRIM$(k)) THEN
            MOCK_V(i) = v
            IF LEN(s) > 0 THEN MOCK_S(i) = s
            EXIT SUB
        END IF
    NEXT i
    IF MOCK_N >= 63 THEN EXIT SUB
    MOCK_N = MOCK_N + 1
    MOCK_K(MOCK_N) = k
    MOCK_V(MOCK_N) = v
    MOCK_S(MOCK_N) = s
END SUB

'--- `class=wizard` / `gold=6000` / `flag.saw_omen=1` ---
SUB MockSetFromArg (a AS STRING)
    DIM p AS INTEGER, k AS STRING, v AS STRING
    p = INSTR(a, "=")
    IF p < 2 THEN EXIT SUB
    k = LEFT$(a, p - 1)
    v = MID$(a, p + 1)
    IF CutIsNum%(v) THEN
        MockSet k, VAL(v), v
    ELSE
        MockSet k, 1, v
    END IF
END SUB

' ----------------------------------------------------------------------------
'  Asset resolution.
'
'  Deliberately the SAME shape as the game's pack resolvers: try the selected
'  pack, then `default`, per FILE -- so a partial pack overrides only what it
'  ships. The last resort is the path exactly as written, which is what makes
'  a scratch scene with a relative path work before any pack exists.
' ----------------------------------------------------------------------------
FUNCTION Game_CutArtPath$ (subpath AS STRING)
    DIM c(1 TO 8) AS STRING, i AS INTEGER, n AS INTEGER, pk AS STRING
    pk = MOCK_PACK
    IF LEN(pk) = 0 THEN pk = "default"

    n = 0
    n = n + 1: c(n) = CUT_ASSETROOT + "cutscenes/" + pk + "/art/" + subpath
    n = n + 1: c(n) = CUT_ASSETROOT + "cutscenes/default/art/" + subpath
    n = n + 1: c(n) = CUT_ASSETROOT + "pixel-art/" + pk + "/" + subpath
    n = n + 1: c(n) = CUT_ASSETROOT + "pixel-art/default/" + subpath
    n = n + 1: c(n) = CUT_ASSETROOT + "ansi-art/" + pk + "/" + subpath
    n = n + 1: c(n) = CUT_ASSETROOT + "ansi-art/default/" + subpath
    n = n + 1: c(n) = CUT_ASSETROOT + subpath
    n = n + 1: c(n) = subpath

    FOR i = 1 TO n
        IF _FILEEXISTS(c(i)) THEN Game_CutArtPath$ = c(i): EXIT FUNCTION
    NEXT i
    Game_CutArtPath$ = ""
END FUNCTION

FUNCTION Game_CutAudioPath$ (kind AS STRING, nm AS STRING)
    DIM ext(1 TO 5) AS STRING, dpath(1 TO 3) AS STRING
    DIM i AS INTEGER, j AS INTEGER, nd AS INTEGER, p AS STRING

    ext(1) = ".ogg": ext(2) = ".flac": ext(3) = ".wav": ext(4) = ".mp3": ext(5) = ".rad"

    SELECT CASE LCASE$(kind)
        CASE "music", "cue"
            nd = 2
            dpath(1) = CUT_ASSETROOT + "music/" + MOCK_PACK + "/"
            dpath(2) = CUT_ASSETROOT + "music/"
        CASE "narration"
            nd = 2
            dpath(1) = CUT_ASSETROOT + "narration/" + MOCK_PACK + "/"
            dpath(2) = CUT_ASSETROOT + "narration/"
        CASE ELSE
            nd = 2
            dpath(1) = CUT_ASSETROOT + "sfx/" + MOCK_PACK + "/"
            dpath(2) = CUT_ASSETROOT + "sfx/"
    END SELECT

    FOR i = 1 TO nd
        FOR j = 1 TO 5
            p = dpath(i) + nm + ext(j)
            IF _FILEEXISTS(p) THEN Game_CutAudioPath$ = p: EXIT FUNCTION
        NEXT j
    NEXT i
    Game_CutAudioPath$ = ""
END FUNCTION

' ----------------------------------------------------------------------------
'  Audio.
'
'  EVERY path here is gated on CUT_QUIET, including the _SNDOPEN itself and
'  not merely the playback. Opening a handle and never playing it still hangs
'  a node on miniaudio's mixing graph, and the teardown race that produces is
'  documented in CLAUDE.md as aborting roughly one headless run in ten with a
'  varying message. A silent run must open nothing.
' ----------------------------------------------------------------------------
SUB Game_CutMusic (path AS STRING, fadein AS SINGLE, doloop AS INTEGER)
    IF CUT_QUIET THEN
        MOCK_LOG = MOCK_LOG + "music " + path + CHR$(10)
        EXIT SUB
    END IF
    IF LEN(path) = 0 THEN EXIT SUB
    IF NOT _FILEEXISTS(path) THEN EXIT SUB

    IF MOCK_MUS < -1 THEN
        _SNDVOL MOCK_MUS, 0
        _SNDSTOP MOCK_MUS
        _SNDCLOSE MOCK_MUS
        MOCK_MUS = 0
    END IF

    MOCK_MUS = _SNDOPEN(path)
    IF MOCK_MUS < -1 THEN
        MOCK_MUSTARGET = 1
        IF fadein > 0 THEN
            MOCK_MUSVOL = 0
            MOCK_MUSFADE = fadein
        ELSE
            MOCK_MUSVOL = 1
            MOCK_MUSFADE = 0
        END IF
        _SNDVOL MOCK_MUS, MOCK_MUSVOL
        IF doloop THEN _SNDLOOP MOCK_MUS ELSE _SNDPLAY MOCK_MUS
    END IF
END SUB

SUB Game_CutMusicStop (fade AS SINGLE)
    IF CUT_QUIET THEN EXIT SUB
    IF MOCK_MUS >= -1 THEN EXIT SUB
    IF fade <= 0 THEN
        _SNDVOL MOCK_MUS, 0
        _SNDSTOP MOCK_MUS
        _SNDCLOSE MOCK_MUS
        MOCK_MUS = 0
        EXIT SUB
    END IF
    MOCK_MUSTARGET = 0
    MOCK_MUSFADE = fade
END SUB

SUB Game_CutSfx (nm AS STRING)
    DIM p AS STRING, h AS LONG
    MOCK_LOG = MOCK_LOG + "sfx " + nm + CHR$(10)
    IF CUT_QUIET THEN EXIT SUB
    p = Game_CutAudioPath$("sfx", nm)
    IF LEN(p) = 0 THEN EXIT SUB
    h = _SNDOPEN(p)
    IF h < -1 THEN
        _SNDPLAY h
        MockRetire h
    END IF
END SUB

SUB Game_CutNarrate (k AS STRING)
    DIM p AS STRING, h AS LONG
    MOCK_LOG = MOCK_LOG + "narrate " + k + CHR$(10)
    IF CUT_QUIET THEN EXIT SUB
    p = Game_CutAudioPath$("narration", k)
    IF LEN(p) = 0 THEN EXIT SUB
    h = _SNDOPEN(p)
    IF h < -1 THEN
        _SNDPLAY h
        MockRetire h
    END IF
END SUB

'--- NOTHING closes a handle the mixer might be mid-read of. Park it, and let
'    MockReap free it once it has actually stopped. This mirrors the game's
'    RetireSound/ReapSounds pair, and it exists for the same reason: freeing a
'    node the device thread is walking corrupts the heap, and the crash lands
'    somewhere else entirely. ---
SUB MockRetire (h AS LONG)
    DIM i AS INTEGER
    FOR i = 1 TO 16
        IF MOCK_RET(i) = 0 THEN
            MOCK_RET(i) = h
            MOCK_RETT(i) = CUT_NOW
            EXIT SUB
        END IF
    NEXT i
    '--- queue full: this one has certainly outlived its sound ---
    IF MOCK_RET(1) < -1 THEN _SNDCLOSE MOCK_RET(1)
    MOCK_RET(1) = h
    MOCK_RETT(1) = CUT_NOW
END SUB

SUB MockReap
    DIM i AS INTEGER
    FOR i = 1 TO 16
        IF MOCK_RET(i) < -1 THEN
            IF CUT_NOW - MOCK_RETT(i) > 2 THEN
                IF _SNDPLAYING(MOCK_RET(i)) = 0 _ORELSE CUT_NOW - MOCK_RETT(i) > 30 THEN
                    _SNDCLOSE MOCK_RET(i)
                    MOCK_RET(i) = 0
                END IF
            END IF
        END IF
    NEXT i
END SUB

'--- fades are FRAME-TICKED, so any loop that plays audio has to call this or
'    the fade simply freezes part-way. That lesson is already in CLAUDE.md as
'    "AudioTick must be in every loop"; here there is only one loop, and the
'    engine calls it from CutTick so a host cannot forget. ---
SUB Game_CutAudioTick
    DIM dt AS SINGLE
    IF CUT_QUIET THEN EXIT SUB

    MockReap

    IF MOCK_MUS >= -1 THEN EXIT SUB
    IF MOCK_MUSFADE <= 0 THEN EXIT SUB

    dt = CUT_NOW - MOCK_MUSLAST
    MOCK_MUSLAST = CUT_NOW
    IF dt <= 0 _ORELSE dt > 0.5 THEN EXIT SUB

    IF MOCK_MUSVOL < MOCK_MUSTARGET THEN
        MOCK_MUSVOL = MOCK_MUSVOL + dt / MOCK_MUSFADE
        IF MOCK_MUSVOL >= MOCK_MUSTARGET THEN
            MOCK_MUSVOL = MOCK_MUSTARGET
            MOCK_MUSFADE = 0
        END IF
    ELSEIF MOCK_MUSVOL > MOCK_MUSTARGET THEN
        MOCK_MUSVOL = MOCK_MUSVOL - dt / MOCK_MUSFADE
        IF MOCK_MUSVOL <= MOCK_MUSTARGET THEN
            MOCK_MUSVOL = MOCK_MUSTARGET
            MOCK_MUSFADE = 0
            _SNDSTOP MOCK_MUS
        END IF
    END IF
    _SNDVOL MOCK_MUS, MOCK_MUSVOL
END SUB

SUB MockAudioShutdown
    DIM i AS INTEGER
    IF MOCK_MUS < -1 THEN
        _SNDVOL MOCK_MUS, 0
        _SNDSTOP MOCK_MUS
        _SNDCLOSE MOCK_MUS
        MOCK_MUS = 0
    END IF
    FOR i = 1 TO 16
        IF MOCK_RET(i) < -1 THEN
            _SNDSTOP MOCK_RET(i)
            _SNDCLOSE MOCK_RET(i)
            MOCK_RET(i) = 0
        END IF
    NEXT i
END SUB
