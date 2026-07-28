' ============================================================================
'  SPRITES.bas -- GAME entity->sprite mapping + pixel-art popups + manifests.
'
'  Maps DUNGEON! entities (monsters/treasures/classes/rooms/curios) to sprite
'  paths and draws the combat/curio/treasure art, plus the imagemanifest /
'  uimanifest dumps (which enumerate the game tables). Rides the game-free
'  primitives in engine/ARTPACK.bas (Sprite&/DrawSpriteFit%/ArtFile$/CombatArtBox/
'  InStrAny%). Gated by opt_artstyle; graceful when art is absent.
' ============================================================================

' Normalise a name to a sprite base: lower-case, spaces/slashes -> hyphens, drop a
' trailing plural 's'. "GIANT RATS" -> "giant-rat", "BLACK PUDDING" -> "black-pudding".
FUNCTION SpriteBase$ (nm AS STRING)
    DIM s AS STRING, o AS STRING, i AS INTEGER, c AS STRING
    s = LCASE$(_TRIM$(nm))
    o = ""
    FOR i = 1 TO LEN(s)
        c = MID$(s, i, 1)
        IF c = " " OR c = "/" OR c = "'" THEN c = "-"
        o = o + c
    NEXT
    IF RIGHT$(o, 1) = "s" AND LEN(o) > 3 THEN o = LEFT$(o, LEN(o) - 1)
    SpriteBase$ = o
END FUNCTION

' Path to a monster's sprite (searches the six category folders). "" if none.
FUNCTION MonsterSprite$ (nm AS STRING)
    DIM sbase AS STRING, i AS INTEGER, p AS STRING
    DIM cats(1 TO 6) AS STRING
    cats(1) = "humanoids": cats(2) = "animals": cats(3) = "insects"
    cats(4) = "misc": cats(5) = "beasts": cats(6) = "undead"
    sbase = SpriteBase$(nm)
    MonsterSprite$ = ""
    FOR i = 1 TO 6
        p = ArtFile$("monsters/" + cats(i) + "/" + sbase + ".png")
        IF LEN(p) > 0 THEN MonsterSprite$ = p: EXIT FUNCTION
    NEXT
    ' fallback: a curio that turns INTO a fight (a MIMIC) uses its event-prop art
    p = ArtFile$("events/" + sbase + ".png")
    IF LEN(p) > 0 THEN MonsterSprite$ = p
END FUNCTION

' Filename base for a TREASURE/ITEM name: lowercase, drop any "(...)" qualifier
' (e.g. "Magic Sword (+1)" / "Elf Boots (spare)"), spaces & slashes -> '-'. Unlike
' SpriteBase$ this does NOT strip a trailing 's', because the treasure art is plural
' (silver-coins.png).
FUNCTION TreBase$ (nm AS STRING)
    DIM s AS STRING, o AS STRING, i AS INTEGER, c AS STRING, depth AS INTEGER
    s = LCASE$(_TRIM$(nm))
    o = "": depth = 0
    FOR i = 1 TO LEN(s)
        c = MID$(s, i, 1)
        IF c = "(" THEN depth = depth + 1
        IF depth = 0 THEN
            IF c = " " OR c = "/" OR c = "'" OR c = "+" THEN c = "-"
            o = o + c
        END IF
        IF c = ")" THEN depth = depth - 1
    NEXT
    DO WHILE INSTR(o, "--") > 0: o = StrSubst$(o, "--", "-"): LOOP   ' collapse runs
    DO WHILE RIGHT$(o, 1) = "-": o = LEFT$(o, LEN(o) - 1): LOOP
    DO WHILE LEFT$(o, 1) = "-": o = MID$(o, 2): LOOP
    TreBase$ = o
END FUNCTION

' Path to a treasure/item image for the Treasury, "" if nothing fits. Tries an exact
' filename in treasures/ then items/, then keyword fallbacks so every hoard, gem, and
' curio spoil (incl. names with no dedicated art -- HUGE RUBY, coins in the fountain)
' still gets a representative picture.
FUNCTION TreasureSprite$ (nm AS STRING)
    DIM tb AS STRING, u AS STRING, p AS STRING, fb AS STRING
    tb = TreBase$(nm)
    p = ArtFile$("treasures/" + tb + ".png"): IF LEN(p) > 0 THEN TreasureSprite$ = p: EXIT FUNCTION
    p = ArtFile$("items/" + tb + ".png"): IF LEN(p) > 0 THEN TreasureSprite$ = p: EXIT FUNCTION
    '--- keyword fallbacks (checked most-specific first) ---
    u = " " + UCASE$(_TRIM$(nm)) + " "
    fb = ""
    IF InStrAny%(u, "SWORD BLADE") THEN fb = "items/magic-sword-1"
    IF fb = "" AND InStrAny%(u, "RUBY") THEN fb = "treasures/ruby-ring"
    IF fb = "" AND InStrAny%(u, "EMERALD SAPPHIRE DIAMOND GEM JEWEL CRYSTAL") THEN fb = "treasures/ruby-necklace"
    IF fb = "" AND InStrAny%(u, "NECKLACE PENDANT AMULET") THEN fb = "treasures/gold-necklace"
    IF fb = "" AND InStrAny%(u, "RING EARRING") THEN fb = "treasures/gold-ring"
    IF fb = "" AND InStrAny%(u, "CUP GOBLET CHALICE") THEN fb = "treasures/gold-cup"
    IF fb = "" AND InStrAny%(u, "IDOL STATUE") THEN fb = "treasures/jade-idol"
    IF fb = "" AND InStrAny%(u, "SCROLL") THEN fb = "items/teleport-scroll"
    IF fb = "" AND InStrAny%(u, "BOW") THEN fb = "items/magic-bow"
    IF fb = "" AND InStrAny%(u, "ARMOR ARMOUR MAIL PLATE") THEN fb = "items/magic-armor"
    IF fb = "" AND InStrAny%(u, "SHIELD") THEN fb = "items/shield"
    IF fb = "" AND InStrAny%(u, "BOOT") THEN fb = "items/elf-boots"
    IF fb = "" AND InStrAny%(u, "ESP MEDALLION") THEN fb = "items/esp-medallion"
    IF fb = "" AND InStrAny%(u, "CRYSTAL BALL ORB") THEN fb = "items/crystal-ball"
    IF fb = "" AND InStrAny%(u, "KEY") THEN fb = "items/key-medallion"
    IF fb = "" AND InStrAny%(u, "COIN SILVER") THEN fb = "treasures/silver-coins"
    IF fb = "" THEN fb = "treasures/sack-of-gold"                    ' gold, chest, coffer, sack -> a hoard
    TreasureSprite$ = ArtFile$(fb + ".png")
END FUNCTION

' Path to a class portrait (1 Hero / 2 Elf / 3 Superhero / 4 Wizard). "" if none.
FUNCTION ClassSprite$ (pc AS INTEGER)
    DIM nm AS STRING
    SELECT CASE pc
        CASE 1: nm = "hero"
        CASE 2: nm = "elf"
        CASE 3: nm = "superhero"
        CASE 4: nm = "wizard"
        CASE ELSE: nm = ""
    END SELECT
    IF nm = "" THEN ClassSprite$ = "" ELSE ClassSprite$ = ArtFile$("classes/" + nm + ".png")
END FUNCTION

' The short room name for a level -- the part after "LEVEL n - " (e.g.
' "KING'S QUARTERS"), so a location caption fits its box. Falls back to whole label.
FUNCTION RoomShortName$ (sec AS INTEGER)
    DIM s AS STRING, p AS INTEGER
    IF sec < 1 OR sec > 9 THEN RoomShortName$ = "": EXIT FUNCTION
    s = _TRIM$(SECTORS(sec).label)
    p = INSTR(s, " - ")
    IF p > 0 THEN s = _TRIM$(MID$(s, p + 3))
    RoomShortName$ = s
END FUNCTION

' Path to a level's location/scene sprite (assets/pixel-art/rooms). The nine
' sectors don't name their sprites 1:1, so map each to its closest scene. "" if none.
FUNCTION LocationSprite$ (sec AS INTEGER)
    DIM nm AS STRING, p AS STRING
    SELECT CASE sec
        CASE 1: nm = "main-gallery"                 ' MAIN GALLERY
        CASE 2: nm = "barracks"                     ' GUARD ROOM
        CASE 3: nm = "armory"                       ' ARMORY
        CASE 4: nm = "stone-room"                   ' STORE ROOM
        CASE 5: nm = "torture-chamber"              ' TORTURE CHAMBER
        CASE 6: nm = "kings-treasure"               ' KING'S QUARTERS
        CASE 7: nm = "wizards-lab"                  ' WIZ'S QUARTERS
        CASE 8: nm = "queens-treasure"              ' QUEEN'S QUARTERS
        CASE 9: nm = "the-crypt"                    ' THE CRYPT
        CASE ELSE: nm = ""
    END SELECT
    IF nm = "" THEN LocationSprite$ = "": EXIT FUNCTION
    LocationSprite$ = ArtFile$("rooms/" + nm + ".png")
END FUNCTION

' Pop a framed piece of item/treasure ART into the middle of the screen for a beat
' (a quick scale-in, then a skippable hold), then restore the frame underneath. Shown
' when you USE an item or FIND treasure. Resolves art via TreasureSprite$; silent if
' the player turned pixel art off or nothing fits.
SUB PopArt (nm AS STRING, caption AS STRING)
    DIM sp AS STRING, buf AS LONG, i AS INTEGER, sc AS SINGLE, k AS STRING, junk AS INTEGER
    DIM bw AS INTEGER, bh AS INTEGER, cxp AS INTEGER, cyp AS INTEGER, dw AS INTEGER, dh AS INTEGER, bx AS INTEGER, by AS INTEGER
    IF opt_artstyle = 0 THEN EXIT SUB
    sp = TreasureSprite$(nm): IF LEN(sp) = 0 THEN EXIT SUB
    buf = _NEWIMAGE(SW * CW, SH * CH, 32): _PUTIMAGE (0, 0), CANVAS, buf
    bw = 24 * CW: bh = 16 * CH
    cxp = SW * CW \ 2: cyp = SH * CH \ 2 - CH
    _DEST CANVAS
    FOR i = 1 TO 8                                       ' quick scale-in pop (0.5 -> 1.0)
        sc = 0.5 + 0.5 * (i / 8)
        dw = INT(bw * sc): dh = INT(bh * sc): bx = cxp - dw \ 2: by = cyp - dh \ 2
        _PUTIMAGE (0, 0), buf, CANVAS
        LINE (bx, by)-(bx + dw, by + dh), BOXBG, BF
        LINE (bx, by)-(bx + dw, by + dh), YELLOWU, B
        junk = DrawSpriteFit%(sp, bx + CW, by + CH, dw - 2 * CW, dh - 3 * CH)
        _DISPLAY: _LIMIT 60
    NEXT
    dw = bw: dh = bh: bx = cxp - dw \ 2: by = cyp - dh \ 2   ' settled frame + caption
    _PUTIMAGE (0, 0), buf, CANVAS
    LINE (bx, by)-(bx + dw, by + dh), BOXBG, BF
    LINE (bx, by)-(bx + dw, by + dh), YELLOWU, B
    junk = DrawSpriteFit%(sp, bx + CW, by + CH, dw - 2 * CW, dh - 3 * CH)
    _FONT CH: COLOR YELLOWU, BOXBG
    _PRINTSTRING (cxp - (LEN(caption) * CW) \ 2, by + dh - CH - 4), caption
    _DISPLAY
    FOR i = 1 TO 42: _LIMIT 60: k = INKEY$: IF k <> "" THEN EXIT FOR
    NEXT
    _PUTIMAGE (0, 0), buf, CANVAS: _DISPLAY
    _FREEIMAGE buf
END SUB

' Draw the combat art -- the monster portrait framed top-LEFT and the location
' scene framed top-RIGHT -- on CANVAS. Positioned clear of the centre dice tray
' (rows ~9-22), the banner (rows 21-30), the D&D combat panel (rows 39-49) and the
' HUD (row 50), so it stays painted through a whole fight in BOTH combat modes.
' Pixel-art modes only; each half is skipped silently if its sprite is absent.
SUB DrawCombatArt (nm AS STRING, sec AS INTEGER)
    DIM mp AS STRING, lp AS STRING
    IF opt_artstyle = 0 THEN EXIT SUB
    mp = MonsterSprite$(nm)
    lp = LocationSprite$(sec)
    IF LEN(mp) > 0 THEN CombatArtBox mp, 1, 18, 4, 12, "-= " + _TRIM$(nm) + " =-", REDU
    IF LEN(lp) > 0 THEN CombatArtBox lp, SW - 19, 18, 4, 12, RoomShortName$(sec), CYANU
END SUB

' Back-compat shim: old call sites that only had a monster name.
SUB DrawMonsterArt (nm AS STRING)
    DrawCombatArt nm, 0
END SUB

' Path to a curio's event sprite (assets/pixel-art/events). The curio `kind`
' maps to a prop image; "" if there's no art for it.
FUNCTION CurioSprite$ (kd AS STRING)
    DIM nm AS STRING, p AS STRING
    SELECT CASE _TRIM$(kd)
        CASE "chest": nm = "curio-chest"
        CASE "fountain": nm = "fountain"
        CASE "shrine": nm = "shrine"
        CASE "gamble": nm = "gamblers-altar"
        CASE "peddler": nm = "hooded-peddler"
        CASE "idol": nm = "idol"
        CASE "corpse": nm = "fallen-adventurer"
        CASE "mushroom": nm = "glowing-mushrooms"
        CASE "obelisk": nm = "rune-obelisk"
        CASE "cache": nm = "weapon-cache"
        CASE "mimic": nm = "curio-chest"           ' DISGUISE: a mimic looks exactly like a chest until opened
        CASE ELSE: nm = ""
    END SELECT
    IF nm = "" THEN CurioSprite$ = "": EXIT FUNCTION
    CurioSprite$ = ArtFile$("events/" + nm + ".png")
END FUNCTION

' Draw a curio's prop framed top-LEFT on CANVAS -- same clear zone as the combat
' monster, so it persists behind the centre prompt banner. Gold frame marks it as
' a curio (vs the red combat frame). Pixel-art modes only; silent if no sprite.
SUB DrawCurioArt (kd AS STRING, caption AS STRING)
    DIM p AS STRING
    IF opt_artstyle = 0 THEN EXIT SUB
    p = CurioSprite$(kd)
    IF LEN(p) = 0 THEN EXIT SUB
    CombatArtBox p, 1, 18, 4, 12, "-= " + _TRIM$(caption) + " =-", YELLOWU
END SUB

' Path to a NAMED room's location scene (assets/pixel-art/rooms), by its flavor key.
' All 13 named rooms map 1:1 to a room sprite. "" if none / art absent.
FUNCTION SpecialSprite$ (ky AS STRING)
    DIM k AS STRING, nm AS STRING, p AS STRING
    k = UCASE$(_TRIM$(ky))
    SELECT CASE k
        CASE "MAIN GALLERY": nm = "main-gallery"
        CASE "ARMORY": nm = "armory"
        CASE "THE CRYPT": nm = "the-crypt"
        CASE "WIZ'S LAB": nm = "wizards-lab"
        CASE "WIZ'S TREASURE": nm = "wizards-treasure"
        CASE "KITCHEN": nm = "kitchen"
        CASE "GUARD ROOM": nm = "barracks"
        CASE "STORE ROOM": nm = "stone-room"
        CASE "TORTURE CHAMBER": nm = "torture-chamber"
        CASE "QUEEN'S ANNEX": nm = "queens-armor"
        CASE "QUEEN'S TREASURE": nm = "queens-treasure"
        CASE "KING'S LIBRARY": nm = "kings-library"
        CASE "KING'S TREASURE": nm = "kings-treasure"
        CASE ELSE: nm = ""
    END SELECT
    IF nm = "" THEN SpecialSprite$ = "": EXIT FUNCTION
    SpecialSprite$ = ArtFile$("rooms/" + nm + ".png")
END FUNCTION

' Named-room flavor crawl WITH an establishing shot: frame the location art centred
' above the ScrollText window (rows 1-11, which the crawl box at rows 12-38 never
' repaints, so it persists through the whole typewriter). Falls back to a plain crawl
' when art is off or the sprite is missing -- the words always show either way.
SUB ScrollTextArt (title AS STRING, body AS STRING, sprPath AS STRING)
    DIM bx AS INTEGER, by AS INTEGER, bw AS INTEGER, bh AS INTEGER
    IF opt_artstyle > 0 AND LEN(sprPath) > 0 THEN
        IF _FILEEXISTS(sprPath) THEN
            bw = 30 * CW: bh = 10 * CH
            bx = (SW * CW - bw) \ 2: by = 1 * CH
            _DEST CANVAS
            LINE (bx - 4, by - 4)-(bx + bw + 4, by + bh + 4), BOXBG, BF
            LINE (bx - 4, by - 4)-(bx + bw + 4, by + bh + 4), CYANU, B
            DIM drew AS INTEGER
            drew = DrawSpriteFit%(sprPath, bx, by, bw, bh)
        END IF
    END IF
    ScrollTextVO title, body, "room." + NarrSlug$(title)   ' narratable per named room (room.the-crypt, ...)
END SUB


' ============================================================================
'  ART MANIFESTS  (`dungeon.run imagemanifest` / `uimanifest`) -- like the audio
'  manifest, but for VISUAL assets: every path the engine looks for + a generation
'  prompt, so pixelmon / an ANSI generator can self-serve.
' ============================================================================

' A readable name from a slug ("gold-necklace" -> "gold necklace").
FUNCTION UnSlug$ (s AS STRING)
    DIM i AS INTEGER, o AS STRING, c AS STRING
    FOR i = 1 TO LEN(s): c = MID$(s, i, 1): IF c = "-" THEN c = " "
        o = o + c
    NEXT
    UnSlug$ = o
END FUNCTION

' Emit both the pixel-art (.png) and ansi-art (.ans) line for one entity, deduped by cat/slug
' via `seen`. Format: path | WxH | prompt -- pxdim in PIXELS, ansidim in CHARACTER cols x rows.
SUB PutArtBoth (cat AS STRING, slug AS STRING, nm AS STRING, kd AS STRING, pxdim AS STRING, ansidim AS STRING, seen AS STRING)
    DIM keyp AS STRING
    IF LEN(slug) = 0 THEN EXIT SUB
    keyp = cat + "/" + slug
    IF INSTR(seen, " " + keyp + " ") > 0 THEN EXIT SUB
    seen = seen + keyp + " "
    PRINT "pixel-art/" + keyp + ".png | " + pxdim + " | pixel-art sprite of " + nm + ", " + kd + ", dark-fantasy dungeon crawler, transparent background, centered, crisp pixels"
    PRINT "ansi-art/" + keyp + ".ans | " + ansidim + " | ANSI text-mode art of " + nm + ", " + kd + ", CP437 block characters, 16-colour DOS palette, on black"
END SUB

' `dungeon.run imagemanifest` -- pixel-art AND ansi-art paths + dimensions + prompts for every
' game entity, computed from the loaded tables with the SAME slug rules the engine loads by.
SUB DumpImageManifest
    DIM lvl AS INTEGER, sl AS INTEGER, i AS INTEGER, nm AS STRING, seen AS STRING, lst AS STRING, p AS INTEGER, w AS STRING
    _DEST _CONSOLE
    PRINT "# DUNGEON! image manifest  (path | WxH | prompt)  -- pixel art AND ansi art, same entities."
    PRINT "# WxH: pixel-art in PIXELS ; ansi-art in CHARACTER cols x rows (fit-scaled to its box in-game)."
    PRINT "# grep '^pixel-art/' for pixelmon (.png) ; '^ansi-art/' for the ANSI generator (.ans)."
    PRINT "# monster sprites go UNDER a category subfolder: humanoids|animals|insects|misc|beasts|undead."
    PRINT
    seen = " "
    PRINT "# --- monsters ---"
    FOR lvl = 1 TO 9
        FOR sl = 1 TO 3
            nm = _TRIM$(MON_NAME(lvl, sl)): IF LEN(nm) > 0 THEN PutArtBoth "monsters", SpriteBase$(nm), LCASE$(nm), "a dungeon monster", "512x512", "18x12", seen
        NEXT sl
    NEXT lvl
    FOR i = 1 TO 4: nm = _TRIM$(BOSS_NAME(i)): IF LEN(nm) > 0 THEN PutArtBoth "monsters", SpriteBase$(nm), LCASE$(nm), "a fearsome boss monster", "512x512", "18x12", seen
    NEXT i
    PRINT
    PRINT "# --- treasures & items ---"
    FOR lvl = 1 TO 9
        FOR sl = 1 TO 3
            nm = _TRIM$(TRE_NAME(lvl, sl))
            IF LEN(nm) > 0 THEN
                IF TRE_ITEM(lvl, sl) > 0 THEN PutArtBoth "items", TreBase$(nm), LCASE$(nm), "a magic item", "256x256", "16x12", seen ELSE PutArtBoth "treasures", TreBase$(nm), LCASE$(nm), "a treasure", "256x256", "16x12", seen
            END IF
        NEXT sl
    NEXT lvl
    PRINT
    PRINT "# --- classes (tall portraits) ---"
    PutArtBoth "classes", "hero", "a heroic warrior", "a fantasy hero character portrait", "512x768", "16x16", seen
    PutArtBoth "classes", "elf", "an elf ranger", "a fantasy elf character portrait", "512x768", "16x16", seen
    PutArtBoth "classes", "superhero", "a mighty superhero warrior", "a fantasy champion character portrait", "512x768", "16x16", seen
    PutArtBoth "classes", "wizard", "a robed wizard", "a fantasy wizard character portrait", "512x768", "16x16", seen
    PRINT
    PRINT "# --- rooms (wide location scenes) ---"
    lst = "main-gallery barracks armory stone-room store-room torture-chamber kitchen wizards-lab wizards-treasure kings-library kings-treasure queens-armor queens-treasure the-crypt ": p = 1
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN w = _TRIM$(MID$(lst, p, i - p)): p = i + 1: IF LEN(w) > 0 THEN PutArtBoth "rooms", w, "the " + UnSlug$(w), "a dungeon location scene, wide establishing shot", "512x320", "30x10", seen
    NEXT i
    PRINT
    PRINT "# --- events (curio props) ---"
    lst = "curio-chest fountain shrine gamblers-altar hooded-peddler idol fallen-adventurer glowing-mushrooms rune-obelisk weapon-cache ": p = 1
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN w = _TRIM$(MID$(lst, p, i - p)): p = i + 1: IF LEN(w) > 0 THEN PutArtBoth "events", w, "a " + UnSlug$(w), "a dungeon curio prop", "384x384", "18x12", seen
    NEXT i
END SUB

' `dungeon.run uimanifest` -- the decorative UI chrome in assets/ansi/ (logos, menu pieces),
' with each piece's EXACT character dimensions (cols x rows) from the menu layout. The board and
' *-mask .ans are FUNCTIONAL collision/data maps and are deliberately excluded.
SUB DumpUiManifest
    DIM i AS INTEGER
    _DEST _CONSOLE
    PRINT "# DUNGEON! UI manifest  (path | WxH-chars | prompt)  -- decorative ANSI chrome in assets/ansi/."
    PRINT "# WxH is CHARACTER cols x rows (author the .ans at exactly that size -- ANSI is a fixed grid)."
    PRINT "# EXCLUDED on purpose: board-*.ans and *-mask.ans are functional collision/data maps."
    PRINT
    PRINT "ansi/vermin-radioactive-logo.ans | 132x50 | ANSI full-screen splash for a studio logo, 'VERMIN RADIOACTIVE', dark and glitchy, CP437, 16-colour"
    PRINT "ansi/dungeon-menu-logo.ans | 102x15 | ANSI title logo reading 'DUNGEON', heavy stone-carved letters, torch-lit, CP437 block art, 16-colour"
    FOR i = 1 TO 4: PRINT "ansi/dungeon-menu-left-wall-" + LTRIM$(STR$(i)) + ".ans | 15x51 | ANSI dungeon wall border panel (left side), stone bricks and torches, full height, CP437, 16-colour": NEXT i
    FOR i = 1 TO 4: PRINT "ansi/dungeon-menu-right-wall-" + LTRIM$(STR$(i)) + ".ans | 16x51 | ANSI dungeon wall border panel (right side), stone bricks and torches, full height, CP437, 16-colour": NEXT i
    FOR i = 1 TO 6: PRINT "ansi/dungeon-menu-block-" + LTRIM$(STR$(i)) + ".ans | 95x31 | ANSI menu panel / plaque background for a menu item, carved stone, CP437, 16-colour": NEXT i
END SUB
