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
    DIM lvl AS INTEGER, sl AS INTEGER, i AS INTEGER, nm AS STRING, seen AS STRING
    DIM pcell AS STRING, ppix AS STRING, fcell AS STRING, fpix AS STRING

    _DEST _CONSOLE
    IF LoadLayout%("assets/data/ui-fight-layout.txt", 8, 8) = 0 THEN
        PRINT "fightmanifest: assets/data/ui-fight-layout.txt missing or empty -- nothing to size against."
        EXIT SUB
    END IF
    IF LayHas%("enemy1.art") = 0 THEN PRINT "fightmanifest: layout has no 'enemy1.art' region.": EXIT SUB

    pcell = CellSize$("enemy1.art"): ppix = PixSize$("enemy1.art")
    fcell = CellSize$("screen"): fpix = PixSize$("screen")

    PRINT "# DUNGEON! strategic-combat art manifest   (path | kind | size | prompt)"
    PRINT "# tag: strategic-combat   -- `grep strategic-combat` selects every line below."
    PRINT "#"
    PRINT "# kind `ansi`  -> size is CHARACTER cols x rows (with the font cell it is drawn on)."
    PRINT "#                 Author CP437 16-colour, CRLF line endings, exactly that many columns."
    PRINT "# kind `pixel` -> size is PIXELS, the region's exact on-screen box. 1:1, no scaling,"
    PRINT "#                 no letterboxing, no aspect to reconcile."
    PRINT "#"
    PRINT "# The fight screen is " + fcell + " cells @8x8 = " + fpix + " px. The board canvas is 132x51"
    PRINT "# @8x16 = 1056x816, so this is exactly as WIDE and 16px shorter -- it fits inside the"
    PRINT "# existing canvas, and entering a fight is a redraw, not a window resize."
    PRINT "# EVERY portrait (player and all four foes) is " + pcell + " cells / " + ppix + " px."
    PRINT "# Sizes derive from assets/data/ui-fight-layout.txt -- edit the layout, not this list."
    PRINT

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

    PRINT "# --- foe portraits (fill enemy1..4.art, and reusable for player.art) ---"
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
    PRINT

    PRINT "# --- player portraits (one per class) ---"
    FOR i = 1 TO 4
        nm = _TRIM$(CLASSES(i).name)
        IF LEN(nm) > 0 THEN PutFightArt "classes", SpriteBase$(nm), pcell, ppix, "a " + LCASE$(nm) + " adventurer -- heroic front-facing battle portrait", seen
    NEXT i
    PRINT

    PRINT "# --- treasures (shown in a portrait slot on a reward reveal) ---"
    FOR lvl = 1 TO 9
        FOR sl = 1 TO 3
            nm = _TRIM$(TRE_NAME(lvl, sl))
            IF LEN(nm) > 0 THEN PutFightArt "treasures", TreBase$(nm), pcell, ppix, LCASE$(nm) + " -- dungeon treasure presented as a hoard", seen
        NEXT sl
    NEXT lvl
    PRINT

    ' SPECIAL ITEMS live in the ITM_* weighted pool (assets/data/items.txt), NOT in the
    ' treasures table -- treasures.txt carries no item-code column in the current format. The
    ' old `IF TRE_ITEM(lvl, sl) > 0` test therefore never fired, and every item went unlisted.
    PRINT "# --- special items (also shown in a portrait slot on a reward reveal) ---"
    FOR lvl = 1 TO 9
        FOR sl = 1 TO ITM_N(lvl)
            nm = _TRIM$(ITM_NAME(lvl, sl))
            IF LEN(nm) > 0 THEN PutFightArt "items", TreBase$(nm), pcell, ppix, LCASE$(nm) + " -- a magic item presented on a pedestal", seen
        NEXT sl
    NEXT lvl
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
    PRINT "ansi-art/" + p + ".ans | ansi | " + pcell + " chars @8x8 | ANSI " + pcell + " CP437 16-colour portrait of " + subject + ", filling the frame edge to edge, dark dungeon palette, no border and no text"
    PRINT "pixel-art/" + p + ".png | pixel | " + ppix + " px | pixel-art portrait of " + subject + ", filling the frame edge to edge, dark dungeon palette, transparent or black background, no border and no text"
END SUB
