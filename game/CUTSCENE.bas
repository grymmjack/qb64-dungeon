' ============================================================================
'  game/CUTSCENE.bas -- the DUNGEON! side of the cut-scene engine.
'
'  The engine names no game symbol. Everything it needs about the running game
'  arrives through the eleven Game_Cut* hooks below, and everything the GAME
'  needs from the engine goes through PlayCutscene.
'
'  SEEN-FLAGS are the load-bearing bit. A scene records that it finished, that
'  record survives into the save, and the Storybook screen reads it to decide
'  whether a row is a title or a row of question marks. One list, three uses.
' ============================================================================

' ----------------------------------------------------------------------------
'  PLAYING A SCENE
'
'  ONE entry point, and scenes are addressed by NAME. That is what keeps a
'  future board-position trigger table (level + cell -> scene) a data file
'  rather than an engine change, and it is what lets the Storybook replay
'  anything without knowing what it is replaying.
'
'  Returns TRUE if the scene actually played.
' ----------------------------------------------------------------------------
FUNCTION PlayCutscene% (nm AS STRING)
    PlayCutscene% = PlayCutsceneEx%(nm, TRUE)
END FUNCTION

'--- record = FALSE replays without re-marking anything, which is what the
'    Storybook wants: watching a scene again should not change the record. ---
FUNCTION PlayCutsceneEx% (nm AS STRING, record AS INTEGER)
    DIM p AS STRING, r AS INTEGER, k AS STRING
    DIM olddest AS LONG, oldmusic AS STRING

    '--- the player can switch cut-scenes off entirely ---
    IF opt_cutscenes = CUT_OFF THEN
        IF record THEN MarkCutsceneSeen nm
        PlayCutsceneEx% = FALSE
        EXIT FUNCTION
    END IF

    p = CutscenePath$(nm)
    IF LEN(p) = 0 THEN PlayCutsceneEx% = FALSE: EXIT FUNCTION

    IF CutCompile%(p) = 0 THEN
        '--- A BROKEN SCENE MUST NOT TAKE THE GAME WITH IT. The diagnostics go
        '    to the dev console's telemetry, the player sees nothing, and the
        '    run carries on -- the same call the fatal-error handler makes when
        '    a window is up. `cutplay.run lint all` is where a scene is meant
        '    to fail, loudly, before it ever ships. ---
        LogCutsceneErrors nm
        PlayCutsceneEx% = FALSE
        EXIT FUNCTION
    END IF

    CUT_MODE = opt_cutscenes
    CUT_TEXTSPEED = 45
    CUT_QUIET = audio_muted
    CUT_ASSETROOT = "assets/"
    CUT_GRIDFONT = CH                 ' the engine must not reach for CH itself

    olddest = _DEST
    _DEST CANVAS

    CutBegin
    DO
        r = CutTick%
        Present                       ' the game's one per-frame chokepoint

        DO
            k = INKEY$
            IF LEN(k) = 0 THEN EXIT DO
            CutKeyFeed k
        LOOP

        _LIMIT 60
    LOOP WHILE r = CUT_RUNNING

    CutEnd
    _DEST olddest

    '--- a SKIPPED scene still counts as seen. The player watched enough of it
    '    to decide, and locking the Storybook entry behind sitting through it
    '    would punish exactly the people who already know how it goes. ---
    IF record THEN MarkCutsceneSeen nm

    '--- the scene owned the screen; give the board back ---
    cursor_erase
    cursor_draw
    DrawHUD

    PlayCutsceneEx% = TRUE
END FUNCTION

'--- pack-resolved, per file: the selected data pack first, then default ---
FUNCTION CutscenePath$ (nm AS STRING)
    DIM p AS STRING
    p = "assets/cutscenes/" + _TRIM$(opt_datapack) + "/" + nm + ".cut"
    IF _FILEEXISTS(p) THEN CutscenePath$ = p: EXIT FUNCTION
    p = "assets/cutscenes/default/" + nm + ".cut"
    IF _FILEEXISTS(p) THEN CutscenePath$ = p: EXIT FUNCTION
    CutscenePath$ = ""
END FUNCTION

SUB LogCutsceneErrors (nm AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO CUT_NERR
        IF CUT_ERRSEV(i) = 2 THEN
            LogEvent "cutscene " + nm + " line" + STR$(CUT_ERRLINE(i)) + ": " + CUT_ERR(i)
        END IF
    NEXT i
END SUB

' ----------------------------------------------------------------------------
'  SEEN-FLAGS
'
'  Kept as a flat list of names rather than a bitmask against a fixed roster:
'  a data pack can ship scenes the base game has never heard of, and a bitmask
'  would silently mis-index the moment the roster changed length.
' ----------------------------------------------------------------------------
SUB MarkCutsceneSeen (nm AS STRING)
    DIM i AS INTEGER
    IF LEN(_TRIM$(nm)) = 0 THEN EXIT SUB
    FOR i = 1 TO CUTSEEN_N
        IF LCASE$(_TRIM$(CUTSEEN(i))) = LCASE$(_TRIM$(nm)) THEN EXIT SUB
    NEXT i
    IF CUTSEEN_N >= CUTSEEN_MAX THEN EXIT SUB
    CUTSEEN_N = CUTSEEN_N + 1
    CUTSEEN(CUTSEEN_N) = nm
END SUB

FUNCTION CutsceneSeen% (nm AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO CUTSEEN_N
        IF LCASE$(_TRIM$(CUTSEEN(i))) = LCASE$(_TRIM$(nm)) THEN
            CutsceneSeen% = TRUE
            EXIT FUNCTION
        END IF
    NEXT i
    CutsceneSeen% = FALSE
END FUNCTION

' ============================================================================
'  THE HOOKS
' ============================================================================

'--- Numeric state. An unknown key is 0, never an error: a scene written
'    against a key this game does not publish reads as false rather than
'    killing the run mid-scene. ---
FUNCTION Game_CutState# (k AS STRING)
    DIM kk AS STRING, nm AS STRING
    kk = LCASE$(_TRIM$(k))

    IF LEFT$(kk, 5) = "flag." THEN
        nm = MID$(kk, 6)
        IF CutsceneSeen%("flag:" + nm) THEN Game_CutState# = 1 ELSE Game_CutState# = 0
        EXIT FUNCTION
    END IF
    IF LEFT$(kk, 5) = "seen." THEN
        IF CutsceneSeen%(MID$(kk, 6)) THEN Game_CutState# = 1 ELSE Game_CutState# = 0
        EXIT FUNCTION
    END IF

    SELECT CASE kk
        CASE "gold": Game_CutState# = gold
        CASE "hp": Game_CutState# = player_hp
        CASE "maxhp": Game_CutState# = player_maxhp
        CASE "level", "depth": Game_CutState# = PlayerLevel%
        CASE "deaths": Game_CutState# = deaths(cur_player)
        CASE "kills": Game_CutState# = g_monsters_slain
        CASE "rooms": Game_CutState# = g_rooms_explored
        CASE "crits": Game_CutState# = g_crits
        CASE "players": Game_CutState# = num_players
        CASE "has_key", "key": Game_CutState# = ABS(has_key <> 0)
        CASE "classnum": Game_CutState# = player_class
        CASE "goal": Game_CutState# = target_gold
        CASE ELSE: Game_CutState# = 0
    END SELECT
END FUNCTION

'--- String state, for `if class == wizard` and friends. ---
FUNCTION Game_CutStateStr$ (k AS STRING)
    DIM kk AS STRING
    kk = LCASE$(_TRIM$(k))
    SELECT CASE kk
        CASE "class"
            IF player_class >= 1 THEN
                IF player_class <= 4 THEN Game_CutStateStr$ = LCASE$(_TRIM$(CLASSES(player_class).name))
            END IF
        CASE "name": Game_CutStateStr$ = _TRIM$(player_name)
        CASE ELSE: Game_CutStateStr$ = ""
    END SELECT
END FUNCTION

'--- Story flags live in the SAME list as the seen-scenes, prefixed, so one
'    save line carries both and neither can drift out of sync with the other. ---
SUB Game_CutSetFlag (nm AS STRING, v AS DOUBLE)
    IF v <> 0 THEN MarkCutsceneSeen "flag:" + LCASE$(_TRIM$(nm))
    LogEvent "story flag " + _TRIM$(nm)
END SUB

SUB Game_CutGrant (what AS STRING, amount AS DOUBLE)
    DIM w AS STRING, n AS INTEGER
    w = LCASE$(_TRIM$(what))
    n = INT(amount)

    SELECT CASE w
        CASE "gold"
            gold = gold + n
            IF gold < 0 THEN gold = 0
            IF n > 0 THEN LogTreasure "Cut-scene", n
        CASE "hp"
            player_hp = player_hp + n
            IF player_hp > player_maxhp THEN player_hp = player_maxhp
            IF player_hp < 1 THEN player_hp = 1
        CASE "key"
            has_key = TRUE
        CASE ELSE
            '--- `grant item <name>` arrives as "item:<name>" ---
            IF LEFT$(w, 5) = "item:" THEN LogEvent "gained " + MID$(w, 6)
    END SELECT
END SUB

' ----------------------------------------------------------------------------
'  Asset resolution -- the game's real pack ladders.
' ----------------------------------------------------------------------------
FUNCTION Game_CutArtPath$ (subpath AS STRING)
    DIM p AS STRING

    '--- art shipped WITH the scenes comes first, so a cut-scene pack can hold
    '    its own backdrops without polluting the sprite tree ---
    p = "assets/cutscenes/" + _TRIM$(opt_datapack) + "/art/" + subpath
    IF _FILEEXISTS(p) THEN Game_CutArtPath$ = p: EXIT FUNCTION
    p = "assets/cutscenes/default/art/" + subpath
    IF _FILEEXISTS(p) THEN Game_CutArtPath$ = p: EXIT FUNCTION

    '--- then the ordinary sprite and ANSI ladders, which are already
    '    pack-aware, so a cut-scene can name any sprite the game owns ---
    p = PixelArtFile$(subpath)
    IF LEN(p) > 0 THEN Game_CutArtPath$ = p: EXIT FUNCTION
    p = AnsiArtFile$(subpath)
    IF LEN(p) > 0 THEN Game_CutArtPath$ = p: EXIT FUNCTION

    Game_CutArtPath$ = ""
END FUNCTION

FUNCTION Game_CutAudioPath$ (kind AS STRING, nm AS STRING)
    SELECT CASE LCASE$(_TRIM$(kind))
        CASE "music", "cue": Game_CutAudioPath$ = ResolveMusic$(nm)
        CASE "narration": Game_CutAudioPath$ = NarratePath$(nm)
        CASE ELSE: Game_CutAudioPath$ = ""      ' sfx go through Sfx by NAME
    END SELECT
END FUNCTION

' ----------------------------------------------------------------------------
'  Audio -- straight onto the game's existing machinery, so cut-scene sound
'  obeys the volume sliders, the packs and the mute exactly like everything
'  else. Nothing here opens its own handle.
' ----------------------------------------------------------------------------
SUB Game_CutMusic (path AS STRING, fadein AS SINGLE, doloop AS INTEGER)
    IF audio_muted THEN EXIT SUB
    IF LEN(path) = 0 THEN EXIT SUB
    BeginTrack path, doloop
END SUB

'--- EndCue is the game's "stop overriding the level music" -- a cut-scene's
'    music is a CUE, not a new level track, so ending it restores whatever the
'    board was playing rather than leaving silence behind. ---
SUB Game_CutMusicStop (fade AS SINGLE)
    IF audio_muted THEN EXIT SUB
    EndCue
END SUB

'--- by NAME, so it lands in the Sfx dispatcher and inherits the sample-or-
'    beeper fallback and the pack override every other effect gets ---
SUB Game_CutSfx (nm AS STRING)
    Sfx nm
END SUB

SUB Game_CutNarrate (k AS STRING)
    Narrate k
END SUB

'--- music crossfades and narration fades are FRAME-ticked. A loop that plays
'    audio without calling this freezes the fade part-way; the engine calls it
'    from CutTick so this host cannot forget. ---
SUB Game_CutAudioTick
    AudioTick
END SUB


' ============================================================================
'  BOARD-POSITION TRIGGERS
' ============================================================================

'--- Load assets/data/<pack>/triggers.txt. Absent or empty is normal and
'    silent: most packs will ship no triggers at all. ---
SUB LoadCutTriggers
    DIM f AS STRING, i AS INTEGER, nm AS STRING

    TRIG_N = 0
    f = DataPath$("assets/data/triggers.txt")
    IF NOT _FILEEXISTS(f) THEN EXIT SUB

    ReadDataFile f
    FOR i = 1 TO DLINE_N
        nm = _TRIM$(DField$(DLINE(i), 4))
        IF LEN(nm) = 0 THEN _CONTINUE
        IF TRIG_N >= TRIG_MAX THEN EXIT FOR
        TRIG_N = TRIG_N + 1
        TRIG_LVL(TRIG_N) = VAL(DField$(DLINE(i), 1))
        TRIG_COL(TRIG_N) = VAL(DField$(DLINE(i), 2))
        TRIG_ROW(TRIG_N) = VAL(DField$(DLINE(i), 3))
        TRIG_SCENE(TRIG_N) = nm
        TRIG_ONCE(TRIG_N) = (VAL(DField$(DLINE(i), 5)) <> 0)
    NEXT i
END SUB

'--- Step on a cell: does anything fire? Returns TRUE if a scene played.
'
'    A `once` trigger is remembered by SCENE **and CELL**, not by scene alone:
'    the same scene may legitimately be placed on several cells, and keying on
'    the name would let the first one fired silence all the others. ---
FUNCTION CheckCutTrigger% (cx AS INTEGER, cy AS INTEGER)
    DIM i AS INTEGER, lv AS INTEGER, nm AS STRING, k AS STRING

    CheckCutTrigger% = FALSE
    IF TRIG_N < 1 THEN EXIT FUNCTION

    lv = PlayerLevel%
    FOR i = 1 TO TRIG_N
        IF TRIG_COL(i) <> cx THEN _CONTINUE
        IF TRIG_ROW(i) <> cy THEN _CONTINUE
        IF TRIG_LVL(i) <> 0 THEN
            IF TRIG_LVL(i) <> lv THEN _CONTINUE
        END IF

        nm = _TRIM$(TRIG_SCENE(i))
        k = "trig:" + nm + "@" + LTRIM$(STR$(cx)) + "," + LTRIM$(STR$(cy))
        IF TRIG_ONCE(i) THEN
            IF CutsceneSeen%(k) THEN _CONTINUE
        END IF

        IF PlayCutscene%(nm) THEN
            IF TRIG_ONCE(i) THEN MarkCutsceneSeen k
            CheckCutTrigger% = TRUE
            EXIT FUNCTION
        END IF
    NEXT i
END FUNCTION
