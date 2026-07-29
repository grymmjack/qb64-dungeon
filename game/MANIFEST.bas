' ============================================================================
'  MANIFEST.bas -- the GAME's audio content manifest (`dungeon.run audiomanifest`).
'
'  Moved out of engine/MUSIC.bas: a manifest is a listing of THIS game's content, so
'  it necessarily names the game's flavor tables (REG_FLAV / SP_* / CHM_FLAV_* / CURIOS)
'  and its spoken lines. Keeping it engine-side was the last symbol leak in MUSIC.bas.
'
'  (game/SPRITES.bas holds the sibling DumpImageManifest / DumpUiManifest dumps; they are
'  already game-side, so they are not boundary debt -- consolidating all three here later
'  would be tidiness, not a boundary fix.)
' ============================================================================

' The full roster of themeable effect names, space-separated -- GAME content: these are this
' dungeon's effects (fireball, monster-pain, ...). The engine asks for the roster via this hook
' and registers each (loads a file if one exists, else the beeper covers it); `audiomanifest`
' dumps the same list, so it stays one source of truth.
FUNCTION Game_SfxNames$
    Game_SfxNames$ = "move bump door strongdoor breakdoor secret secretpass key idle treasure trap hit miss crit fumble search win lose saveok savebad chest boom hiss fizzle alarm select levelup voice diceroll diceland dice_edge dice_settle dice-math-1 dice-math-2 monster-pain player-pain death monster-death maxhit heartbeat curio poison-proc frost-proc teleport fireball lightning-bolt"
END FUNCTION

' Look up want in the parallel keys()/vals() arrays (case-insensitive), or a placeholder.
FUNCTION LookupDesc$ (dkey() AS STRING, dval() AS STRING, dn AS INTEGER, want AS STRING)
    DIM i AS INTEGER
    LookupDesc$ = "(no description -- add one)"
    FOR i = 1 TO dn
        IF dkey(i) = UCASE$(want) THEN LookupDesc$ = dval(i): EXIT FUNCTION
    NEXT i
END FUNCTION

' `dungeon.run audiomanifest` -- print EVERY audio asset as  path | description-or-text  so the
' AI generators self-serve: SFX/MUSIC get their generation PROMPT (from assets/{sfx,music}/
' descriptions.txt), NARRATION gets the LINE TO SPEAK (from the loaded flavor/data, always in
' sync with what the game shows). Path is under assets/, sans .ogg/.mp3/.wav/.flac; a pack
' subfolder overrides. regular/chamber/curio lines are the exact on-screen text; room lines are a
' representative sample; intro/titles are clean spoken versions.
SUB DumpAudioManifest
    DIM i AS INTEGER, lvl AS INTEGER, si AS INTEGER, lst AS STRING, p AS INTEGER, nm AS STRING, seen AS STRING
    DIM dkey(1 TO 300) AS STRING, dval(1 TO 300) AS STRING, dn AS INTEGER
    _DEST _CONSOLE
    PRINT "# DUNGEON! audio manifest  -- feed to the generators. path is under assets/ , add"
    PRINT "# .ogg/.mp3/.wav/.flac ; a pack subfolder overrides. sfx/music: path | length | prompt"
    PRINT "# (length is a TARGET/MAX -- keep sfx at or under it); narration: path | line to speak."
    PRINT

    PRINT "# --- SFX (assets/sfx/[pack]/) : path | max-seconds | generation prompt ---"
    dn = 0: ReadDataFile "assets/sfx/descriptions.txt"
    FOR i = 1 TO DLINE_N
        IF dn < 300 THEN dn = dn + 1: dkey(dn) = UCASE$(_TRIM$(DField$(DLINE(i), 1))): dval(dn) = _TRIM$(DField$(DLINE(i), 2)) + " | " + _TRIM$(DField$(DLINE(i), 3))
    NEXT i
    lst = Game_SfxNames$ + " ": p = 1
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN
            nm = _TRIM$(MID$(lst, p, i - p)): p = i + 1
            IF LEN(nm) > 0 THEN PRINT "sfx/" + nm + " | " + LookupDesc$(dkey(), dval(), dn, nm)
        END IF
    NEXT i
    PRINT

    PRINT "# --- MUSIC (assets/music/[pack]/) : path | length | generation prompt ---"
    dn = 0: ReadDataFile "assets/music/descriptions.txt"
    FOR i = 1 TO DLINE_N
        IF dn < 300 THEN dn = dn + 1: dkey(dn) = UCASE$(_TRIM$(DField$(DLINE(i), 1))): dval(dn) = _TRIM$(DField$(DLINE(i), 2)) + " | " + _TRIM$(DField$(DLINE(i), 3))
    NEXT i
    seen = " "
    FOR lvl = 1 TO 9                                    ' per-level tracks (unique bare names from playlist)
        nm = _TRIM$(MUSIC_FILE(lvl))
        IF LEN(nm) > 0 AND INSTR(seen, " " + nm + " ") = 0 THEN PRINT "music/" + nm + " | " + LookupDesc$(dkey(), dval(), dn, nm): seen = seen + nm + " "
    NEXT lvl
    lst = "vr-theme introsplash everdark victory lose combat-low combat-high combat-intense settings chargen treasury bestiary curio lords gamemenu ": p = 1
    FOR i = 1 TO LEN(lst)                               ' fixed intro/menu/cue tracks (deduped vs level names)
        IF MID$(lst, i, 1) = " " THEN
            nm = _TRIM$(MID$(lst, p, i - p)): p = i + 1
            IF LEN(nm) > 0 AND INSTR(seen, " " + nm + " ") = 0 THEN PRINT "music/" + nm + " | " + LookupDesc$(dkey(), dval(), dn, nm): seen = seen + nm + " "
        END IF
    NEXT i
    PRINT

    PRINT "# --- NARRATION (assets/narration/[pack]/) : path | line to speak ---"
    PRINT "narration/intro.descent | Torchlight gutters as you cross the threshold into the ancient dungeon. Nine levels coil below, each darker and deadlier than the last. Somewhere in the depths lies the Level Key -- claim it, gather a fortune in gold, and return alive to this entrance. Few ever escape. Let the delving begin."
    PRINT "narration/win.title | Victory."
    PRINT "narration/win.subtitle | " + _TRIM$(Say$("win.subtitle"))
    PRINT "narration/lose.title | You died."
    PRINT "narration/lose.subtitle | " + _TRIM$(Say$("lose.subtitle"))
    FOR lvl = 1 TO 9                                    ' ambient one-liners: exact per-line text
        FOR i = 1 TO REG_N(lvl)
            PRINT "narration/regular." + LTRIM$(STR$(lvl)) + "." + LTRIM$(STR$(i)) + " | " + _TRIM$(REG_FLAV(lvl, i))
        NEXT i
    NEXT lvl
    FOR si = 1 TO SP_N                                  ' named rooms (representative line)
        IF SP_FN(si) > 0 THEN PRINT "narration/room." + NarrSlug$(_TRIM$(SP_KEY(si))) + " | " + _TRIM$(SP_FLAV(si, 1))
    NEXT si
    FOR i = 1 TO CHM_FLAV_N: PRINT "narration/chamber." + NarrSlug$(_TRIM$(CHM_FLAV_NAME(i))) + " | " + _TRIM$(CHM_FLAV_TXT(i)): NEXT i
    FOR i = 1 TO NCURIO: PRINT "narration/curio." + _TRIM$(CURIOS(i).kind) + " | " + _TRIM$(CURIOS(i).prompt): NEXT i
    ' combat narration -- generic per-event voiced lines (Combat tier; see NarrateT / game/COMBAT.bas).
    ' Keep them short and atmospheric; they play OVER the combat banners, so they set mood, not detail.
    PRINT "narration/combat.encounter | A monstrous shape rears up from the dark, barring your path. Steel yourself."
    PRINT "narration/combat.reface | The creature still stands between you and your goal. You must face it."
    PRINT "narration/combat.slay | Your foe crumples and falls still. The way is clear."
    PRINT "narration/combat.flee | You break away and slip back into the shadows, the fight unfinished."
    PRINT "narration/combat.hurt | Pain sears through you as the blow lands. Blood runs."
    PRINT "narration/combat.downed | Your strength fails you. The world tilts, darkens -- and you fall."
END SUB
