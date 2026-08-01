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
    Game_SfxNames$ = "move bump door strongdoor breakdoor secret secretpass key idle treasure trap hit miss crit fumble search win lose saveok savebad chest boom hiss fizzle alarm select levelup voice diceroll diceland dice_edge dice_settle dice-math-1 dice-math-2 monster-pain player-pain death monster-death maxhit heartbeat curio poison-proc frost-proc teleport fireball lightning-bolt" + _
        " amb-thump amb-hinge amb-slam amb-chains amb-wind amb-drone amb-scream" + _
        " amb-squeak amb-hiss amb-gibber amb-growl amb-slither amb-laugh amb-howl" + _
        " amb-bark amb-moan amb-whisper"
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
    ManReset
    DIM i AS INTEGER, lvl AS INTEGER, si AS INTEGER, lst AS STRING, p AS INTEGER, nm AS STRING, seen AS STRING
    DIM dkey(1 TO 300) AS STRING, dval(1 TO 300) AS STRING, dn AS INTEGER
    _DEST _CONSOLE
    ManOut "# DUNGEON! audio manifest  -- feed to the generators. path is under assets/ , add"
    ManOut "# .ogg/.mp3/.wav/.flac ; a pack subfolder overrides. sfx/music: path | length | prompt"
    ManOut "# (length is a TARGET/MAX -- keep sfx at or under it); narration: path | line to speak."
    ManOut ""

    ManOut "# --- SFX (assets/sfx/[pack]/) : path | max-seconds | generation prompt ---"
    dn = 0: ReadDataFile "assets/sfx/descriptions.txt"
    FOR i = 1 TO DLINE_N
        IF dn < 300 THEN dn = dn + 1: dkey(dn) = UCASE$(_TRIM$(DField$(DLINE(i), 1))): dval(dn) = _TRIM$(DField$(DLINE(i), 2)) + " | " + _TRIM$(DField$(DLINE(i), 3))
    NEXT i
    lst = Game_SfxNames$ + " ": p = 1
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN
            nm = _TRIM$(MID$(lst, p, i - p)): p = i + 1
            IF LEN(nm) > 0 THEN ManAsset "sfx/" + nm + " | " + LookupDesc$(dkey(), dval(), dn, nm)
        END IF
    NEXT i
    ManOut ""

    ManOut "# --- MUSIC (assets/music/[pack]/) : path | length | generation prompt ---"
    dn = 0: ReadDataFile "assets/music/descriptions.txt"
    FOR i = 1 TO DLINE_N
        IF dn < 300 THEN dn = dn + 1: dkey(dn) = UCASE$(_TRIM$(DField$(DLINE(i), 1))): dval(dn) = _TRIM$(DField$(DLINE(i), 2)) + " | " + _TRIM$(DField$(DLINE(i), 3))
    NEXT i
    seen = " "
    FOR lvl = 1 TO 9                                    ' per-level tracks (unique bare names from playlist)
        nm = _TRIM$(MUSIC_FILE(lvl))
        IF LEN(nm) > 0 AND INSTR(seen, " " + nm + " ") = 0 THEN ManAsset "music/" + nm + " | " + LookupDesc$(dkey(), dval(), dn, nm): seen = seen + nm + " "
    NEXT lvl
    lst = "vr-theme introsplash everdark victory lose combat-low combat-high combat-intense settings chargen treasury bestiary curio lords gamemenu ": p = 1
    FOR i = 1 TO LEN(lst)                               ' fixed intro/menu/cue tracks (deduped vs level names)
        IF MID$(lst, i, 1) = " " THEN
            nm = _TRIM$(MID$(lst, p, i - p)): p = i + 1
            IF LEN(nm) > 0 AND INSTR(seen, " " + nm + " ") = 0 THEN ManAsset "music/" + nm + " | " + LookupDesc$(dkey(), dval(), dn, nm): seen = seen + nm + " "
        END IF
    NEXT i
    ManOut ""

    ManOut "# --- NARRATION (assets/narration/[pack]/) : path | line to speak ---"
    ManAsset "narration/intro.descent | Torchlight gutters as you cross the threshold into the ancient dungeon. Nine levels coil below, each darker and deadlier than the last. Somewhere in the depths lies the Level Key -- claim it, gather a fortune in gold, and return alive to this entrance. Few ever escape. Let the delving begin."
    ManAsset "narration/win.title | Victory."
    ManAsset "narration/win.subtitle | " + _TRIM$(Say$("win.subtitle"))
    ManAsset "narration/lose.title | You died."
    ManAsset "narration/lose.subtitle | " + _TRIM$(Say$("lose.subtitle"))
    FOR lvl = 1 TO 9                                    ' ambient one-liners: exact per-line text
        FOR i = 1 TO REG_N(lvl)
            ManAsset "narration/regular." + LTRIM$(STR$(lvl)) + "." + LTRIM$(STR$(i)) + " | " + _TRIM$(REG_FLAV(lvl, i))
        NEXT i
    NEXT lvl
    FOR si = 1 TO SP_N                                  ' named rooms (representative line)
        IF SP_FN(si) > 0 THEN ManAsset "narration/room." + NarrSlug$(_TRIM$(SP_KEY(si))) + " | " + _TRIM$(SP_FLAV(si, 1))
    NEXT si
    FOR i = 1 TO CHM_FLAV_N: ManAsset "narration/chamber." + NarrSlug$(_TRIM$(CHM_FLAV_NAME(i))) + " | " + _TRIM$(CHM_FLAV_TXT(i)): NEXT i
    FOR i = 1 TO NCURIO: ManAsset "narration/curio." + _TRIM$(CURIOS(i).kind) + " | " + _TRIM$(CURIOS(i).prompt): NEXT i
    ' combat narration -- generic per-event voiced lines (Combat tier; see NarrateT / game/COMBAT.bas).
    ' Keep them short and atmospheric; they play OVER the combat banners, so they set mood, not detail.
    ManAsset "narration/combat.encounter | A monstrous shape rears up from the dark, barring your path. Steel yourself."
    ManAsset "narration/combat.reface | The creature still stands between you and your goal. You must face it."
    ManAsset "narration/combat.slay | Your foe crumples and falls still. The way is clear."
    ManAsset "narration/combat.flee | You break away and slip back into the shadows, the fight unfinished."
    ManAsset "narration/combat.hurt | Pain sears through you as the blow lands. Blood runs."
    ManAsset "narration/combat.downed | Your strength fails you. The world tilts, darkens -- and you fall."
    ManHeader "DUNGEON! audio manifest"
    ManFlush
END SUB


' `dungeon.run fightmanifest` -- every art asset the TACTICAL COMBAT screen needs, emitted as
'   path | kind | size | prompt
' with everything under a `strategic-combat/` subfolder, so the generators can select the whole
' set with a single `grep strategic-combat`.
'
' ANSI art and PIXEL art are DIFFERENT MEDIA and are listed as separate entries with the `kind`
' column stating which, because their sizes are not even in the same unit:
'   * kind `ansi`  -- size in CHARACTER cols x rows, plus the cell metric it is drawn on (@8x8).
'                     ANSI is a fixed grid; the file must be exactly that many columns wide.
'   * kind `pixel` -- size in PIXELS, given as the region's EXACT on-screen box (cols*8 x rows*8).
'                     1:1, so the .png is blitted with no scaling and no letterboxing -- there is
'                     no aspect to reconcile and no conversion for a generator to guess at.
'
' The numbers come from assets/data/ui-fight-layout.txt via engine/LAYOUT.bas rather than being
' restated here, so moving a box in the layout moves the generation targets with it and art can
' never be authored to a stale size. (Same principle as DumpAudioManifest reading the flavor
' tables instead of duplicating the lines.)
'
' One portrait size covers EVERY actor -- the mockup's four foe panels and its player box are all
' 33x25 -- so a monster portrait drops straight into the player slot and vice versa.
SUB DumpFightManifest
    ManReset
    DIM lvl AS INTEGER, sl AS INTEGER, i AS INTEGER, nm AS STRING, seen AS STRING
    DIM pcell AS STRING, ppix AS STRING, fcell AS STRING, fpix AS STRING

    _DEST _CONSOLE
    IF LoadLayout%("assets/data/ui-fight-layout.txt", 8, 8) = 0 THEN
        ManOut "fightmanifest: assets/data/ui-fight-layout.txt missing or empty -- nothing to size against."
        EXIT SUB
    END IF
    IF LayHas%("enemy1.art") = 0 THEN ManOut "fightmanifest: layout has no 'enemy1.art' region.": EXIT SUB

    pcell = CellSize$("enemy1.art"): ppix = PixSize$("enemy1.art")
    fcell = CellSize$("screen"): fpix = PixSize$("screen")

    ManOut "# DUNGEON! strategic-combat art manifest   (path | kind | size | prompt)"
    ManOut "# tag: strategic-combat   -- `grep strategic-combat` selects every line below."
    ManOut "#"
    ManOut "# FORMAT: path | style | size | prompt   (same shape as imagemanifest)"
    ManOut "#   ansi-art size = CHARACTER cols x rows, authored at exactly that (blits 1:1)."
    ManOut "#   pixel-art size = a SQUARE dimension; the renderer FITS it into the 33x25 box"
    ManOut "#   preserving aspect, so a square source is correct rather than a compromise."
    ManOut "#                 Author CP437 16-colour, CRLF line endings, exactly that many columns."
    ManOut "# kind `pixel` -> size is PIXELS, the region's exact on-screen box. 1:1, no scaling,"
    ManOut "#                 no letterboxing, no aspect to reconcile."
    ManOut "#"
    ManOut "# The fight screen is " + fcell + " cells @8x8 = " + fpix + " px. The board canvas is 132x51"
    ManOut "# @8x16 = 1056x816, so this is exactly as WIDE and 16px shorter -- it fits inside the"
    ManOut "# existing canvas, and entering a fight is a redraw, not a window resize."
    ManOut "# EVERY portrait (player and all four foes) is " + pcell + " cells / " + ppix + " px."
    ManOut "# Sizes derive from assets/data/ui-fight-layout.txt -- edit the layout, not this list."
    ManOut ""

    ' NO frame.ans ENTRY, ON PURPOSE.
    '
    ' A 132x100 UI frame is the wrong thing to ask a diffusion model for. It needs pixel-exact
    ' rules at rows 29/42 and column 35, and large regions left deliberately EMPTY for the log,
    ' the menu and the dice tray. What a generator returns instead is plausible "carved stone"
    ' TEXTURE across the whole screen -- which the renderer then draws UNDER everything, so the
    ' log and menu become unreadable noise. (Observed exactly that with the first generated pack.)
    '
    ' engine/FIGHT.bas draws this chrome itself (FightDrawChrome), precisely, from the layout.
    ' It still LOADS strategic-combat/frame.ans if one exists, because a HAND-authored frame in an
    ' ANSI editor is a fine thing to want -- it is just not a generator job. Delete a generated
    ' frame.ans rather than shipping it.

    ManOut "# --- foe portraits (fill enemy1..4.art, and reusable for player.art) ---"
    seen = " "
    FOR lvl = 1 TO 9
        FOR sl = 1 TO 3
            nm = _TRIM$(MON_NAME(lvl, sl))
            IF LEN(nm) > 0 THEN PutFightArt "monsters/" + MonsterCat$(nm), SpriteBase$(nm), pcell, ppix, LCASE$(nm) + " -- a dungeon monster of level " + LTRIM$(STR$(lvl)), seen
        NEXT sl
    NEXT lvl
    FOR i = 1 TO 4
        nm = _TRIM$(BOSS_NAME(i))
        IF LEN(nm) > 0 THEN PutFightArt "monsters/" + MonsterCat$(nm), SpriteBase$(nm), pcell, ppix, LCASE$(nm) + " -- a fearsome dungeon boss", seen
    NEXT i
    ' Transforming curios fight too, and they are in no monster table -- a mimic is a row in
    ' curios.txt that sets ROOMS().monster when opened. Its portrait slot needs fight-sized art
    ' like any other foe, so derive it from the same place the reveal art comes from.
    FOR i = 1 TO NCURIO
        IF CurioBecomesMonster%(CURIOS(i).kind) THEN
            nm = LCASE$(_TRIM$(CURIOS(i).kind))
            PutFightArt "events", nm, pcell, ppix, nm + " -- a treasure chest lunging open mid-ambush, rows of teeth inside the lid", seen
        END IF
    NEXT i
    ManOut ""

    ManOut "# --- player portraits (one per class) ---"
    FOR i = 1 TO 4
        nm = _TRIM$(CLASSES(i).name)
        IF LEN(nm) > 0 THEN PutFightArt "classes", SpriteBase$(nm), pcell, ppix, "a " + LCASE$(nm) + " adventurer -- heroic front-facing battle portrait", seen
    NEXT i
    ManOut ""

    ManOut "# --- treasures (shown in a portrait slot on a reward reveal) ---"
    FOR lvl = 1 TO 9
        FOR sl = 1 TO 3
            nm = _TRIM$(TRE_NAME(lvl, sl))
            IF LEN(nm) > 0 THEN PutFightArt "treasures", TreBase$(nm), pcell, ppix, LCASE$(nm) + " -- dungeon treasure presented as a hoard", seen
        NEXT sl
    NEXT lvl
    ManOut ""

    ' SPECIAL ITEMS live in the ITM_* weighted pool (assets/data/items.txt), NOT in the
    ' treasures table -- treasures.txt carries no item-code column in the current format. The
    ' old `IF TRE_ITEM(lvl, sl) > 0` test therefore never fired, and every item went unlisted.
    ManOut "# --- special items (also shown in a portrait slot on a reward reveal) ---"
    FOR lvl = 1 TO 9
        FOR sl = 1 TO ITM_N(lvl)
            nm = _TRIM$(ITM_NAME(lvl, sl))
            IF LEN(nm) > 0 THEN PutFightArt "items", TreBase$(nm), pcell, ppix, LCASE$(nm) + " -- a magic item presented on a pedestal", seen
        NEXT sl
    NEXT lvl
    ManHeader "DUNGEON! strategic-combat art manifest"
    ManFlush
END SUB

' "COLSxROWS" for a layout region -- the unit ANSI art is authored in.
FUNCTION CellSize$ (rgn AS STRING)
    CellSize$ = LTRIM$(STR$(LayCols%(rgn))) + "x" + LTRIM$(STR$(LayRows%(rgn)))
END FUNCTION

' "WxH" in PIXELS for a layout region -- the unit pixel art is authored in. Uses the region's
' OWN cell metric (LayPW%/LayPH%), so a region on a different font cell still reports correctly.
FUNCTION PixSize$ (rgn AS STRING)
    PixSize$ = LTRIM$(STR$(LayPW%(rgn))) + "x" + LTRIM$(STR$(LayPH%(rgn)))
END FUNCTION

' Emit the ansi AND pixel entries for one piece of strategic-combat art, deduped by
' category+base (the same monster recurs across levels, and TRE_NAME repeats "(spare)" rows).
SUB PutFightArt (cat AS STRING, artbase AS STRING, pcell AS STRING, ppix AS STRING, subject AS STRING, seen AS STRING)
    DIM tag AS STRING, p AS STRING
    IF LEN(_TRIM$(artbase)) = 0 THEN EXIT SUB
    tag = " " + cat + "/" + artbase + " "
    IF INSTR(seen, tag) > 0 THEN EXIT SUB
    seen = seen + _TRIM$(tag) + " "
    p = "strategic-combat/" + cat + "/" + artbase
    ' Same `path | style | size | prompt` shape as imagemanifest, so one parser reads both.
    ' ANSI size is the exact cell box (it blits 1:1). PIXEL size is a SQUARE, because the
    ' generators produce square sprites -- the renderer FITS it into the 33x25 box preserving
    ' aspect rather than stretching, so a square source is correct, not a compromise.
    ManAsset "ansi-art/" + p + ".ans | darkest | " + pcell + " | ANSI " + pcell + " CP437 16-colour portrait of " + subject + ", filling the frame edge to edge, dark dungeon palette, no border and no text"
    ManAsset "pixel-art/" + p + ".png | darkest | 320 | pixel-art portrait of " + subject + ", dark dungeon palette, transparent background, centered, crisp pixels"
END SUB

' ============================================================================
'  Manifest output buffering.
'
'  Every manifest prints its TOTAL as the first line so a generator can read one line and decide
'  whether anything changed -- `grep -m1 '^# ENTRIES:'` -- instead of a human diffing two runs.
'  The total is only known after walking the content tables, so the body appends here and the
'  header is printed in front of it. ONE pass, so the number can never disagree with the list.
' ============================================================================

SUB ManReset
    MAN_N = 0: MAN_ENTRIES = 0
END SUB

' A comment / blank / section line: buffered, NOT counted.
SUB ManOut (s AS STRING)
    IF MAN_N >= MAN_MAX THEN EXIT SUB
    MAN_N = MAN_N + 1: MAN_BUF(MAN_N) = s
END SUB

' An ASSET line: buffered AND counted. Only these are entries a generator has to make.
' ============================================================================
'  PACK AUDIT -- `dungeon.run <any>manifest audit`
'
'  A manifest lists every asset the game WANTS. Audit mode prints only the ones the
'  selected packs do not actually have, in the same format, with the count on line 1.
'  So the same command that feeds a generator also tells you what is still missing:
'
'      dungeon.run audiomanifest        # everything the game wants
'      dungeon.run audiomanifest audit  # ...only what is missing, ready to generate
'
'  Resolution mirrors the loaders exactly -- selected pack first, then `default/`,
'  per file -- because a partial pack is legal and only the files it actually ships
'  should count as present.
' ============================================================================

' Which pack directory does this manifest category resolve through?
FUNCTION ManPackFor$ (cat AS STRING)
    SELECT CASE cat
        CASE "sfx": ManPackFor$ = opt_sfxpack
        CASE "music": ManPackFor$ = opt_musicpack
        CASE "narration": ManPackFor$ = opt_narrationpack
        CASE "pixel-art": ManPackFor$ = opt_artpack
        CASE "ansi-art": ManPackFor$ = opt_ansipack
        CASE ELSE: ManPackFor$ = ""
    END SELECT
END FUNCTION

' Does the asset named by a manifest line exist in the selected pack or in default/?
' A path with no extension is AUDIO (the manifest writes `sfx/move`, and the loader picks
' the extension), so every audio extension is tried before calling it missing.
FUNCTION ManAssetPresent% (ln AS STRING)
    DIM pth AS STRING, cat AS STRING, rest AS STRING, sl AS INTEGER, bar AS INTEGER
    DIM pk AS STRING, e AS INTEGER
    ManAssetPresent% = -1                       ' unknown shapes count as PRESENT, never as a false alarm
    bar = INSTR(ln, "|")
    IF bar > 0 THEN pth = _TRIM$(LEFT$(ln, bar - 1)) ELSE pth = _TRIM$(ln)
    IF LEN(pth) = 0 THEN EXIT FUNCTION
    sl = INSTR(pth, "/")
    IF sl <= 0 THEN EXIT FUNCTION
    cat = LEFT$(pth, sl - 1): rest = MID$(pth, sl + 1)
    pk = ManPackFor$(cat)
    IF LEN(pk) = 0 THEN pk = "default"
    IF INSTR(rest, ".") > 0 THEN                ' an explicit extension: a straight two-place check
        IF _FILEEXISTS("assets/" + cat + "/" + pk + "/" + rest) THEN EXIT FUNCTION
        IF _FILEEXISTS("assets/" + cat + "/default/" + rest) THEN EXIT FUNCTION
        ManAssetPresent% = 0
        EXIT FUNCTION
    END IF
    ' AudioExt$ already carries the leading dot (".ogg"), so do NOT add one here.
    FOR e = 1 TO AUDIOPREF_N                    ' no extension: audio, try each in preference order
        IF _FILEEXISTS("assets/" + cat + "/" + pk + "/" + rest + AudioExt$(e)) THEN EXIT FUNCTION
        IF _FILEEXISTS("assets/" + cat + "/default/" + rest + AudioExt$(e)) THEN EXIT FUNCTION
    NEXT e
    ManAssetPresent% = 0
END FUNCTION


SUB ManAsset (s AS STRING)
    ' In AUDIT mode a present asset is not an entry at all -- it is neither counted nor
    ' printed, so `head -1` gives the number still to make and the body is a work list.
    IF man_audit THEN
        IF ManAssetPresent%(s) THEN EXIT SUB
    END IF
    MAN_ENTRIES = MAN_ENTRIES + 1
    ManOut s
END SUB

' Print the machine-readable header. FIRST LINE IS THE COUNT, deliberately: fetchable with
' `head -1`, comparable with a stored value, no parsing required.
SUB ManHeader (title AS STRING)
    IF man_audit THEN
        PRINT "# MISSING: " + LTRIM$(STR$(MAN_ENTRIES))
    ELSE
        PRINT "# ENTRIES: " + LTRIM$(STR$(MAN_ENTRIES))
    END IF
    PRINT "# " + title
    IF MAN_N >= MAN_MAX THEN PRINT "# !! TRUNCATED at " + LTRIM$(STR$(MAN_MAX)) + " lines -- raise MAN_MAX in ENGINE.BI"
END SUB

SUB ManFlush
    DIM i AS INTEGER
    FOR i = 1 TO MAN_N
        PRINT MAN_BUF(i)
    NEXT i
    MAN_N = 0
END SUB
