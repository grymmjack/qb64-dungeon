' Load the authored art direction (assets/data/art-prompts.txt) -- style / size / prompt keyed
' by asset path. Routed through DataPath$ like every other table, so a data pack can ship its own
' art direction alongside its own monsters.
SUB LoadArtPrompts
    DIM i AS INTEGER, k AS STRING
    AP_N = 0
    ReadDataFile "assets/data/art-prompts.txt"
    FOR i = 1 TO DLINE_N
        k = LCASE$(DField$(DLINE(i), 1))
        IF LEN(k) > 0 AND AP_N < APROMPT_MAX THEN
            AP_N = AP_N + 1
            AP_PATH(AP_N) = k
            AP_STYLE(AP_N) = DField$(DLINE(i), 2)
            AP_SIZE(AP_N) = DField$(DLINE(i), 3)
            AP_TEXT(AP_N) = DField$(DLINE(i), 4)
        END IF
    NEXT i
END SUB

' Row index for an asset path (no media prefix, no extension), or 0.
FUNCTION ArtPromptSlot% (pth AS STRING)
    DIM i AS INTEGER, t AS STRING
    t = LCASE$(_TRIM$(pth))
    FOR i = 1 TO AP_N
        IF _TRIM$(AP_PATH(i)) = t THEN ArtPromptSlot% = i: EXIT FUNCTION
    NEXT i
END FUNCTION

' Authored prompt for an asset, or "" -- callers fall back to their generic description.
FUNCTION ArtPromptText$ (pth AS STRING)
    DIM i AS INTEGER
    i = ArtPromptSlot%(pth): IF i > 0 THEN ArtPromptText$ = _TRIM$(AP_TEXT(i))
END FUNCTION

' Authored pixelmon style key, or the category default -- so a new asset with no row still gets a
' sensible look instead of an empty column the generator has to guess at.
FUNCTION ArtPromptStyle$ (pth AS STRING, cat AS STRING)
    DIM i AS INTEGER
    i = ArtPromptSlot%(pth)
    IF i > 0 THEN
        IF LEN(_TRIM$(AP_STYLE(i))) > 0 THEN ArtPromptStyle$ = _TRIM$(AP_STYLE(i)): EXIT FUNCTION
    END IF
    SELECT CASE LCASE$(cat)
        CASE "classes": ArtPromptStyle$ = "portrait"
        CASE "items", "treasures": ArtPromptStyle$ = "item"
        CASE "markers": ArtPromptStyle$ = "dark"
        CASE "rooms": ArtPromptStyle$ = "dosrpg"
        CASE "screens": ArtPromptStyle$ = "dosrpg"     ' full-screen banners, not portraits
        CASE ELSE: ArtPromptStyle$ = "darkest"
    END SELECT
END FUNCTION

' Authored pixelmon size, or the category default.
FUNCTION ArtPromptSize$ (pth AS STRING, cat AS STRING)
    DIM i AS INTEGER
    i = ArtPromptSlot%(pth)
    IF i > 0 THEN
        IF LEN(_TRIM$(AP_SIZE(i))) > 0 THEN ArtPromptSize$ = _TRIM$(AP_SIZE(i)): EXIT FUNCTION
    END IF
    IF LCASE$(cat) = "rooms" THEN ArtPromptSize$ = "192" ELSE ArtPromptSize$ = "128"
END FUNCTION

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
    DIM s AS STRING, o AS STRING, i AS INTEGER, chx AS STRING
    s = LCASE$(_TRIM$(nm))
    o = ""
    FOR i = 1 TO LEN(s)
        chx = MID$(s, i, 1)
        IF chx = " " OR chx = "/" OR chx = "'" THEN chx = "-"
        o = o + chx
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

' The art path fragment the TACTICAL fight screen resolves fight-sized art from, e.g.
' "monsters/beasts/werewolf". NOT a filename -- FightPortrait& appends .ans/.png and tries
' the strategic-combat/ folders through the pack layers.
'
' The category subfolder is the whole point. `"monsters/" + SpriteBase$(nm)` looks right and
' is wrong: every fight-sized monster sprite on disk lives under a CATEGORY, so that path
' matched nothing and all 20 of them were dead weight -- pixel style silently fell back to
' stretched general art, and ANSI style (which has no such fallback, by design) showed
' "[ no art ]" for every monster in the game. Same mistake the manifest made; see MonsterCat$.
FUNCTION MonsterArtBase$ (nm AS STRING)
    MonsterArtBase$ = "monsters/" + MonsterCat$(nm) + "/" + SpriteBase$(nm)
END FUNCTION

' TRUE if this curio kind turns into a FIGHT when opened, so it needs REVEAL art of its own
' on top of the disguise CurioSprite$ returns.
'
' The mimic is the case that exists today: curios.txt gives it the same name, prompt and art as
' an ordinary Curio Chest so it is indistinguishable until opened, then CurioMimic sets
' ROOMS().monster = "MIMIC" and a fight starts. MonsterSprite$ resolves that through its
' events/ fallback -- so the reveal slot is `events/<kind>.png`.
'
' Kept as an explicit list rather than inferred: "CurioSprite$ returned a different name" is
' true of nearly every kind (chest -> curio-chest) and would over-list. Adding another
' transforming curio is one entry here.
FUNCTION CurioBecomesMonster% (kd AS STRING)
    IF InStrAny%(LCASE$(_TRIM$(kd)), "mimic") THEN CurioBecomesMonster% = -1
END FUNCTION

' Which CATEGORY subfolder a monster's art belongs in.
'
' MonsterSprite$ SEARCHES all six categories at load time, so the game does not care which one
' a sprite sits in -- but a MANIFEST does: it has to tell the generator where to WRITE the file,
' and art written to `monsters/goblin.png` instead of `monsters/beasts/goblin.png` is invisible
' to the game forever. That was a real bug: the manifest emitted category-less monster paths, so
' every one of the 25 existing monster sprites looked orphaned and any newly generated monster
' would have landed somewhere nothing reads.
'
' Resolution order:
'   1. If art already exists in some category, USE THAT category -- never relocate existing art.
'   2. Otherwise classify by name, so a new monster lands somewhere sensible.
'   3. Otherwise "misc".
FUNCTION MonsterCat$ (nm AS STRING)
    DIM sbase AS STRING, i AS INTEGER
    DIM cats(1 TO 6) AS STRING
    cats(1) = "humanoids": cats(2) = "animals": cats(3) = "insects"
    cats(4) = "misc": cats(5) = "beasts": cats(6) = "undead"
    sbase = SpriteBase$(nm)
    ' 1. wherever it already lives
    FOR i = 1 TO 6
        IF LEN(ArtFile$("monsters/" + cats(i) + "/" + sbase + ".png")) > 0 THEN MonsterCat$ = cats(i): EXIT FUNCTION
        IF LEN(AnsiFile$("monsters/" + cats(i) + "/" + sbase + ".ans")) > 0 THEN MonsterCat$ = cats(i): EXIT FUNCTION
    NEXT i
    ' 2. classify by name
    IF InStrAny%(sbase, "skeleton zombie mummy vampire ghoul ghost wraith lich spectre specter wight") THEN MonsterCat$ = "undead": EXIT FUNCTION
    IF InStrAny%(sbase, "spider worm insect beetle centipede scorpion ant wasp") THEN MonsterCat$ = "insects": EXIT FUNCTION
    IF InStrAny%(sbase, "rat bat snake lizard wolf bear boar ape crocodile") THEN MonsterCat$ = "animals": EXIT FUNCTION
    IF InStrAny%(sbase, "hero wizard witch thief warrior knight vetch king queen priest") THEN MonsterCat$ = "humanoids": EXIT FUNCTION
    IF InStrAny%(sbase, "dragon troll ogre giant goblin kobold hobgoblin gargoyle werewolf minotaur hydra") THEN MonsterCat$ = "beasts": EXIT FUNCTION
    IF InStrAny%(sbase, "slime pudding blob ooze mold jelly") THEN MonsterCat$ = "misc": EXIT FUNCTION
    ' 3.
    MonsterCat$ = "misc"
END FUNCTION

' Filename base for a TREASURE/ITEM name: lowercase, drop any "(...)" qualifier
' (e.g. "Magic Sword (+1)" / "Elf Boots (spare)"), spaces & slashes -> '-'. Unlike
' SpriteBase$ this does NOT strip a trailing 's', because the treasure art is plural
' (silver-coins.png).
FUNCTION TreBase$ (nm AS STRING)
    DIM s AS STRING, o AS STRING, i AS INTEGER, chx AS STRING, depth AS INTEGER
    s = LCASE$(_TRIM$(nm))
    o = "": depth = 0
    FOR i = 1 TO LEN(s)
        chx = MID$(s, i, 1)
        IF chx = "(" THEN depth = depth + 1
        IF depth = 0 THEN
            IF chx = " " OR chx = "/" OR chx = "'" OR chx = "+" THEN chx = "-"
            o = o + chx
        END IF
        IF chx = ")" THEN depth = depth - 1
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
' nothing fits the subject in the selected art style.
SUB PopArt (nm AS STRING, caption AS STRING)
    DIM sp AS STRING, buf AS LONG, i AS INTEGER, sc AS SINGLE, k AS STRING, junk AS INTEGER
    DIM bw AS INTEGER, bh AS INTEGER, cxp AS INTEGER, cyp AS INTEGER, dw AS INTEGER, dh AS INTEGER, bx AS INTEGER, by AS INTEGER
    ' No artstyle gate. This used to be `IF opt_artstyle = 0 THEN EXIT SUB`, i.e. "in ANSI mode,
    ' draw nothing" -- which is why choosing ANSI showed no monsters, treasures or locations at
    ' all. ArtFile$ now resolves .png or .ans per opt_artstyle and returns "" when that style has
    ' no art for the subject, so the empty-path checks below are the only guard needed.
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
        Present: _LIMIT 60
    NEXT
    dw = bw: dh = bh: bx = cxp - dw \ 2: by = cyp - dh \ 2   ' settled frame + caption
    _PUTIMAGE (0, 0), buf, CANVAS
    LINE (bx, by)-(bx + dw, by + dh), BOXBG, BF
    LINE (bx, by)-(bx + dw, by + dh), YELLOWU, B
    junk = DrawSpriteFit%(sp, bx + CW, by + CH, dw - 2 * CW, dh - 3 * CH)
    _FONT CH: COLOR YELLOWU, BOXBG
    _PRINTSTRING (cxp - (LEN(caption) * CW) \ 2, by + dh - CH - 4), caption
    Present
    FOR i = 1 TO 42: _LIMIT 60: k = INKEY$: IF k <> "" THEN EXIT FOR
    NEXT
    _PUTIMAGE (0, 0), buf, CANVAS: Present
    _FREEIMAGE buf
END SUB

' Draw the combat art -- the monster portrait framed top-LEFT and the location
' scene framed top-RIGHT -- on CANVAS. Positioned clear of the centre dice tray
' (rows ~9-22), the banner (rows 21-30), the D&D combat panel (rows 39-49) and the
' HUD (row 50), so it stays painted through a whole fight in BOTH combat modes.
' Either art form; each half is skipped silently if its sprite is absent.
' `wound` is 0..1 -- how far this monster is from death, for the gore overlay. Pass 0 in
' Oldschool mode, which has no monster HP at all (a 2d6 roll either slays it or does not),
' so there is nothing to ramp and a splattered portrait would be a lie.
SUB DrawCombatArt (nm AS STRING, sec AS INTEGER, wound AS SINGLE)
    DIM mp AS STRING, lp AS STRING
    ' no artstyle gate -- see PopArt
    mp = MonsterSprite$(nm)
    lp = LocationSprite$(sec)
    IF LEN(mp) > 0 THEN
        CombatArtBox mp, 1, 18, 4, 12, "-= " + _TRIM$(nm) + " =-", REDU
        IF wound > 0 THEN GoreSplat 1 * CW, 4 * CH, 18 * CW, 12 * CH, wound, GoreColor~&(nm), NameSeed&(nm)
    END IF
    IF LEN(lp) > 0 THEN CombatArtBox lp, SW - 19, 18, 4, 12, RoomShortName$(sec), CYANU
END SUB

' Stable per-monster splatter seed, so a given monster's wounds stay put frame to frame
' AND two different monsters do not wear the same pattern.
FUNCTION NameSeed& (nm AS STRING)
    DIM i AS INTEGER, h AS LONG, t AS STRING
    t = _TRIM$(nm)
    h = 5381
    FOR i = 1 TO LEN(t)
        h = (h * 33 + ASC(t, i)) MOD 65521
    NEXT i
    NameSeed& = h
END FUNCTION

' Back-compat shim: old call sites that only had a monster name.
SUB DrawMonsterArt (nm AS STRING)
    DrawCombatArt nm, 0, 0
END SUB

' What a creature bleeds. Undead have no blood, so their wounds read as spreading
' BLACK rot instead of red -- which also stops a skeleton looking like it has a
' circulatory system. Anything else bleeds. Returning 0 would mean "never splatter";
' nothing does that today, but the engine honours it (FA_GORE = 0).
FUNCTION GoreColor~& (nm AS STRING)
    IF MonsterCat$(nm) = "undead" THEN
        GoreColor~& = _RGB32(20, 16, 22)          ' near-black; still reads on a lit sprite
    ELSE
        GoreColor~& = _RGB32(150, 12, 12)         ' blood
    END IF
END FUNCTION

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
' a curio (vs the red combat frame). Either art form; silent if no sprite.
SUB DrawCurioArt (kd AS STRING, caption AS STRING)
    DIM p AS STRING
    ' no artstyle gate -- see PopArt
    p = CurioSprite$(kd)
    IF LEN(p) = 0 THEN EXIT SUB
    CombatArtBox p, 1, 18, 4, 12, "-= " + _TRIM$(caption) + " =-", YELLOWU
END SUB

' Path to a NAMED room's location scene (assets/pixel-art/rooms), by its flavor key.
' All 13 named rooms map 1:1 to a room sprite. "" if none / art absent.
' The art for the weapon the player is actually swinging. A found Magic Sword outranks the
' class weapon, because that is what WeaponName$ says too -- the picture and the prose must
' agree or the panel contradicts itself.
FUNCTION WeaponSprite$
    DIM p AS STRING
    IF item_sword >= 2 THEN
        p = ArtFile$("items/magic-sword-2.png"): IF LEN(p) > 0 THEN WeaponSprite$ = p: EXIT FUNCTION
    END IF
    IF item_sword > 0 THEN
        p = ArtFile$("items/magic-sword-1.png"): IF LEN(p) > 0 THEN WeaponSprite$ = p: EXIT FUNCTION
    END IF
    SELECT CASE player_class
        CASE 4: p = ArtFile$("items/staff.png")
        CASE 2: p = ArtFile$("items/elven-blade.png")
        CASE ELSE: p = ArtFile$("items/sword.png")
    END SELECT
    IF LEN(p) = 0 THEN p = ArtFile$("items/magic-sword-1.png")   ' last resort: a sword is a sword
    WeaponSprite$ = p
END FUNCTION

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
    ScrollTextArtKey title, body, sprPath, "room." + NarrSlug$(title)   ' narratable per named room (room.the-crypt, ...)
END SUB

' As ScrollTextArt, but the caller names the narration key. CHAMBERS reuse the crawl with a
' chamber.<slug> key so a narration pack can voice a hall separately from the same-named room
' (they share names -- ARMORY, THE CRYPT, ...), which one hardcoded "room." prefix could not do.
SUB ScrollTextArtKey (title AS STRING, body AS STRING, sprPath AS STRING, narrkey AS STRING)
    DIM bx AS INTEGER, by AS INTEGER, bw AS INTEGER, bh AS INTEGER
    IF LEN(sprPath) > 0 THEN                 ' no artstyle gate -- see PopArt
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
    ScrollTextVO title, body, narrkey
END SUB


' ============================================================================
'  ART MANIFESTS  (`dungeon.run imagemanifest` / `uimanifest`) -- like the audio
'  manifest, but for VISUAL assets: every path the engine looks for + a generation
'  prompt, so pixelmon / an ANSI generator can self-serve.
' ============================================================================

' A readable name from a slug ("gold-necklace" -> "gold necklace").
FUNCTION UnSlug$ (s AS STRING)
    DIM i AS INTEGER, o AS STRING, chx AS STRING
    FOR i = 1 TO LEN(s): chx = MID$(s, i, 1): IF chx = "-" THEN chx = " "
        o = o + chx
    NEXT
    UnSlug$ = o
END FUNCTION

' Emit both the pixel-art (.png) and ansi-art (.ans) line for one entity, deduped by cat/slug
' via `seen`. Format: path | WxH | prompt -- pxdim in PIXELS, ansidim in CHARACTER cols x rows.
SUB PutArtBoth (cat AS STRING, slug AS STRING, nm AS STRING, kd AS STRING, pxdim AS STRING, ansidim AS STRING, seen AS STRING)
    DIM keyp AS STRING, sty AS STRING, psz AS STRING, pr AS STRING, cat0 AS STRING
    IF LEN(slug) = 0 THEN EXIT SUB
    keyp = cat + "/" + slug
    IF INSTR(seen, " " + keyp + " ") > 0 THEN EXIT SUB
    seen = seen + keyp + " "
    cat0 = cat
    IF INSTR(cat0, "/") > 0 THEN cat0 = LEFT$(cat0, INSTR(cat0, "/") - 1)   ' monsters/beasts -> monsters
    sty = ArtPromptStyle$(keyp, cat0)
    psz = ArtPromptSize$(keyp, cat0)
    pr = ArtPromptText$(keyp)
    ' The AUTHORED prompt wins; the derived generic one is only the fallback. That is the whole
    ' point of the split: canonical list, authored direction.
    IF LEN(pr) = 0 THEN pr = nm + ", " + kd
    ManAsset "pixel-art/" + keyp + ".png | " + sty + " | " + psz + " | " + pr + ", pixel art, dark-fantasy dungeon crawler, transparent background, centered, crisp pixels"
    ManAsset "ansi-art/" + keyp + ".ans | " + sty + " | " + ansidim + " | " + pr + ", ANSI text-mode art, CP437 block characters, 16-colour DOS palette, on black"
END SUB

' `dungeon.run imagemanifest` -- pixel-art AND ansi-art paths + dimensions + prompts for every
' game entity, computed from the loaded tables with the SAME slug rules the engine loads by.
SUB DumpImageManifest
    DIM lvl AS INTEGER, sl AS INTEGER, i AS INTEGER, nm AS STRING, seen AS STRING, lst AS STRING, p AS INTEGER, w AS STRING
    _DEST _CONSOLE
    ' The body fills MAN_BUF; the TOTAL is printed in front of it. Machine-readable first line,
    ' so a generator can `grep -m1 "^# ENTRIES:"` and skip the whole run when nothing has changed --
    ' no human comparing outputs.
    ManReset
    DumpImageBody
    ManHeader "DUNGEON! image manifest"
    ManFlush
END SUB

' The manifest body. Run twice: once with ART_COUNTING set (counts subjects, prints nothing) and
' once to emit. One code path, so the printed total can never disagree with the printed list.
SUB DumpImageBody
    DIM lvl AS INTEGER, sl AS INTEGER, i AS INTEGER, nm AS STRING, seen AS STRING, lst AS STRING, p AS INTEGER, w AS STRING
    ManOut "# FORMAT: path | style | size | prompt"
    ManOut "#   style = a pixelmon styles.json key.  size = pixelmon --size for pixel-art,"
    ManOut "#           CHARACTER cols x rows for ansi-art.  Both from assets/data/art-prompts.txt."
    ManOut "# grep '^pixel-art/' for pixelmon (.png) ; '^ansi-art/' for ansimon (.ans)."
    ManOut ""
    ManOut "# monster paths ALREADY INCLUDE their category subfolder (humanoids|animals|insects|misc|beasts|undead)."
    ManOut "# Write each file exactly at the path given -- the game only looks inside those subfolders."
    ManOut ""
    seen = " "
    ManOut "# --- monsters ---"
    FOR lvl = 1 TO 9
        FOR sl = 1 TO 3
            nm = _TRIM$(MON_NAME(lvl, sl)): IF LEN(nm) > 0 THEN PutArtBoth "monsters/" + MonsterCat$(nm), SpriteBase$(nm), LCASE$(nm), "a dungeon monster", "512x512", "18x12", seen
        NEXT sl
    NEXT lvl
    FOR i = 1 TO 4: nm = _TRIM$(BOSS_NAME(i)): IF LEN(nm) > 0 THEN PutArtBoth "monsters/" + MonsterCat$(nm), SpriteBase$(nm), LCASE$(nm), "a fearsome boss monster", "512x512", "18x12", seen
    NEXT i
    ManOut ""
    ManOut "# --- treasures & items ---"
    FOR lvl = 1 TO 9
        FOR sl = 1 TO 3
            nm = _TRIM$(TRE_NAME(lvl, sl))
            IF LEN(nm) > 0 THEN PutArtBoth "treasures", TreBase$(nm), LCASE$(nm), "a treasure", "256x256", "16x12", seen
        NEXT sl
    NEXT lvl
    ManOut ""
    ' SPECIAL ITEMS come from the ITM_* weighted pool (assets/data/items.txt), NOT from the
    ' treasures table. The old code asked `IF TRE_ITEM(lvl, sl) > 0`, but treasures.txt carries
    ' no item-code column in the current format, so that branch never fired and every item
    ' sprite went unlisted -- present on disk, invisible to the generators.
    ManOut "# --- special items (Magic Sword, ESP Medallion, scrolls, ...) ---"
    FOR lvl = 1 TO 9
        FOR sl = 1 TO ITM_N(lvl)
            nm = _TRIM$(ITM_NAME(lvl, sl))
            IF LEN(nm) > 0 THEN PutArtBoth "items", TreBase$(nm), LCASE$(nm), "a magic item", "256x256", "16x12", seen
        NEXT sl
    NEXT lvl
    ManOut ""
    ' MARKERS -- the board overlays (headstone on a cleared room, the body you dropped loot at,
    ' a cursed rune, a lost cache). Four sprites shipped in pixel-art/default/markers/ and NO
    ' manifest had ever mentioned them, so an art pack had no way to know they existed.
    ' The LEVEL KEY is not a row in items.txt -- it is granted by ClaimTreasure (item code 6) --
    ' but TreasureSprite$ resolves any name containing "KEY" to items/key-medallion. Real art the
    ' game uses, which no manifest had ever asked for.
    PutArtBoth "items", "key-medallion", "a level key medallion", "a magic item", "256x256", "16x12", seen
    ' The BASE WEAPONS. Art for the +1/+2 blades already existed, but an unarmed-of-magic hero
    ' carries "your sword" / "your staff" / "your elven blade" (WeaponName$) and no manifest had
    ' ever asked for those -- so the combat bar's weapon slot had nothing to draw for the most
    ' common case in the game: a character who has not found a Magic Sword yet.
    PutArtBoth "items", "sword", "a plain steel longsword", "a weapon", "256x256", "16x12", seen
    PutArtBoth "items", "staff", "a wizard's wooden staff", "a weapon", "256x256", "16x12", seen
    PutArtBoth "items", "elven-blade", "a slender elven blade", "a weapon", "256x256", "16x12", seen
    ' The REST set piece's image (see RestAtEntrance). Filed under events/ with the curio props
    ' because it is the same kind of thing -- a full-width scene behind scrawling text.
    PutArtBoth "events", "rest", "a weary adventurer resting safely at the dungeon entrance, bedroll by a small fire, clean water, morning light", "a quiet safe-haven scene", "384x384", "18x12", seen
    ManOut ""
    ManOut "# --- end screens (drawn behind the WIN / LOSE text) ---"
    ' Wider than they are tall: these sit BEHIND centred text on a full screen, so a square
    ' portrait crop would either letterbox or swallow the words.
    PutArtBoth "screens", "you-win", "a triumphant adventurer emerging from a dungeon doorway into dawn light, laden with treasure, banner-wide composition", "a victory banner", "512x256", "44x14", seen
    PutArtBoth "screens", "you-died", "a fallen adventurer's gear abandoned in a dark dungeon passage, guttering torch, banner-wide composition", "a defeat banner", "512x256", "44x14", seen
    ManOut ""
    ManOut "# --- markers (board overlays) ---"
    lst = "gravestone player-body lost-cache cursed-rune ": p = 1
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN w = _TRIM$(MID$(lst, p, i - p)): p = i + 1: IF LEN(w) > 0 THEN PutArtBoth "markers", w, "a " + UnSlug$(w), "a small board marker icon, top-down, transparent background", "128x128", "6x3", seen
    NEXT i
    ManOut ""
    ManOut "# --- classes (tall portraits) ---"
    PutArtBoth "classes", "hero", "a heroic warrior", "a fantasy hero character portrait", "512x768", "16x16", seen
    PutArtBoth "classes", "elf", "an elf ranger", "a fantasy elf character portrait", "512x768", "16x16", seen
    PutArtBoth "classes", "superhero", "a mighty superhero warrior", "a fantasy champion character portrait", "512x768", "16x16", seen
    PutArtBoth "classes", "wizard", "a robed wizard", "a fantasy wizard character portrait", "512x768", "16x16", seen
    ManOut ""
    ManOut "# --- rooms (wide location scenes) ---"
    lst = "main-gallery barracks armory stone-room store-room torture-chamber kitchen wizards-lab wizards-treasure kings-library kings-treasure queens-armor queens-treasure the-crypt ": p = 1
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN w = _TRIM$(MID$(lst, p, i - p)): p = i + 1: IF LEN(w) > 0 THEN PutArtBoth "rooms", w, "the " + UnSlug$(w), "a dungeon location scene, wide establishing shot", "512x320", "30x10", seen
    NEXT i
    ManOut ""
    ' EVENTS (curio props) are DERIVED from the loaded curio table through CurioSprite$ -- the
    ' same function the game resolves with -- rather than a hardcoded list. A data pack that adds
    ' a curio kind then gets its prop listed automatically, and a pack that removes one stops
    ' asking for art it will never draw. (CurioSprite$ maps `mimic` to curio-chest on purpose --
    ' a mimic must look exactly like a chest until opened -- and the `seen` dedupe collapses it,
    ' which is why deriving beats listing: the aliasing is expressed once, in the resolver.)
    ManOut "# --- events (curio props, derived from assets/data/curios.txt) ---"
    FOR i = 1 TO NCURIO
        w = CurioSprite$(_TRIM$(CURIOS(i).kind))
        ' CurioSprite$ returns a resolved PATH or "" -- reduce it to the bare basename.
        IF LEN(w) > 0 THEN
            w = MID$(w, _INSTRREV(w, "/") + 1)
            ' Strip WHATEVER extension came back, not just ".png". ArtFile$ is style-aware
            ' now, so in ANSI mode this resolves to a .ans path -- and stripping only .png
            ' left the basename as "curio-chest.ans", which the manifest then asked the
            ' generators to make as "curio-chest.ans.png". Every curio listed as missing.
            IF _INSTRREV(w, ".") > 0 THEN w = LEFT$(w, _INSTRREV(w, ".") - 1)
            PutArtBoth "events", w, "a " + UnSlug$(w), "a dungeon curio prop", "384x384", "18x12", seen
        ELSE
            ' No art mapping for this kind yet: still ask for one, named after the kind, so a new
            ' curio is visible as missing art instead of silently having none.
            w = _TRIM$(CURIOS(i).kind)
            IF LEN(w) > 0 THEN PutArtBoth "events", w, "a " + UnSlug$(w), "a dungeon curio prop", "384x384", "18x12", seen
        END IF
        ' A transforming curio also needs the thing it BECOMES -- a separate sprite from the
        ' disguise, and the one the fight draws. Prompted as the reveal, not as a prop.
        IF CurioBecomesMonster%(CURIOS(i).kind) THEN
            w = LCASE$(_TRIM$(CURIOS(i).kind))
            PutArtBoth "events", w, "a " + UnSlug$(w) + " revealing itself -- a treasure chest lunging open, rows of teeth inside the lid, tongue lashing out", "a dungeon monster mid-ambush", "384x384", "18x12", seen
        END IF
    NEXT i
END SUB

' `dungeon.run uimanifest` -- the decorative UI chrome in assets/ansi/ (logos, menu pieces),
' with each piece's EXACT character dimensions (cols x rows) from the menu layout. The board and
' *-mask .ans are FUNCTIONAL collision/data maps and are deliberately excluded.
SUB DumpUiManifest
    DIM i AS INTEGER
    _DEST _CONSOLE
    ManReset
    ManOut "# DUNGEON! UI manifest  (path | WxH-chars | prompt)  -- decorative ANSI chrome."
    ManOut "# Paths are ansi-art/<file>; the generator inserts the PACK dir -> assets/ansi-art/<pack>/<file>."
    ManOut "# WxH is CHARACTER cols x rows (author the .ans at exactly that size -- ANSI is a fixed grid)."
    ManOut "# EXCLUDED on purpose: board-*.ans and *-mask.ans are functional collision/data maps."
    ManOut ""
    ManAsset "ansi-art/vermin-radioactive-logo.ans | 132x50 | ANSI full-screen splash for a studio logo, 'VERMIN RADIOACTIVE', dark and glitchy, CP437, 16-colour"
    ManAsset "ansi-art/dungeon-menu-logo.ans | 102x15 | ANSI title logo reading 'DUNGEON', heavy stone-carved letters, torch-lit, CP437 block art, 16-colour"
    FOR i = 1 TO 4: ManAsset "ansi-art/dungeon-menu-left-wall-" + LTRIM$(STR$(i)) + ".ans | 15x51 | ANSI dungeon wall border panel (left side), stone bricks and torches, full height, CP437, 16-colour": NEXT i
    FOR i = 1 TO 4: ManAsset "ansi-art/dungeon-menu-right-wall-" + LTRIM$(STR$(i)) + ".ans | 16x51 | ANSI dungeon wall border panel (right side), stone bricks and torches, full height, CP437, 16-colour": NEXT i
    FOR i = 1 TO 6: ManAsset "ansi-art/dungeon-menu-block-" + LTRIM$(STR$(i)) + ".ans | 95x31 | ANSI menu panel / plaque background for a menu item, carved stone, CP437, 16-colour": NEXT i
    ManHeader "DUNGEON! UI manifest"
    ManFlush
END SUB
