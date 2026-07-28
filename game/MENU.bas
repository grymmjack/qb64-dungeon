' ============================================================================
'  MENU.bas -- intro, menu, class-select, dialogs, HUD, dice, sound
' ============================================================================

FUNCTION SelectClass%
    DIM sel AS INTEGER, k AS STRING, i AS INTEGER, yrow AS INTEGER
    sel = player_class: IF sel < 1 OR sel > 4 THEN sel = 1
    DO
        _LIMIT 60
        AudioTick                            ' chargen cue crossfade keeps ramping during class select
        k = NormKey$(UCASE$(INKEY$))         ' arrows / numpad -> WASD too
        IF k = "W" OR k = "A" THEN
            sel = sel - 1: IF sel < 1 THEN sel = 4
            Sfx "select"
        END IF
        IF k = "S" OR k = "D" THEN
            sel = sel + 1: IF sel > 4 THEN sel = 1
            Sfx "select"
        END IF
        IF k = CHR$(13) THEN SelectClass = sel: EXIT FUNCTION
        IF k = CHR$(27) THEN SelectClass = 0: EXIT FUNCTION

        _DEST CANVAS: CLS , BLACK
        COLOR YELLOWU, BLACK: PrintCentered 5, "C H O O S E   Y O U R   C H A M P I O N"
        FOR i = 1 TO 4
            yrow = 12 + (i - 1) * 7
            IF i = sel THEN
                LINE (28 * CW, (yrow - 1) * CH)-(104 * CW, (yrow + 3) * CH), BOXBG, BF
                LINE (28 * CW, (yrow - 1) * CH)-(104 * CW, (yrow + 3) * CH), REDU, B
                COLOR WHITE, BOXBG: PrintCentered yrow, CLASSES(i).name + "   (goal " + _TRIM$(STR$(CLASSES(i).gold_goal)) + " gold)"
                COLOR YELLOWU, BOXBG: PrintCentered yrow + 2, CLASSES(i).blurb
            ELSE
                COLOR GREY, BLACK: PrintCentered yrow, CLASSES(i).name + "   (goal " + _TRIM$(STR$(CLASSES(i).gold_goal)) + " gold)"
            END IF
        NEXT i
        COLOR CYANU, BLACK: PrintCentered 45, "[W/S] choose      [ENTER] confirm      [ESC] back"
        _DISPLAY
    LOOP
END FUNCTION


' ============================================================================
'  OLD-SCHOOL CHARACTER GENERATION (3d6 abilities + rolled hit points)
' ============================================================================

' Standard ability modifier: floor((score - 10) / 2).  Range -4..+4 for 3d6.
FUNCTION AbilMod% (score AS INTEGER)
    AbilMod = INT((score - 10) / 2)
END FUNCTION


' Format a modifier for display: "+2", "0", "-1".
FUNCTION ModStr$ (m AS INTEGER)
    IF m >= 0 THEN ModStr$ = "+" + _TRIM$(STR$(m)) ELSE ModStr$ = _TRIM$(STR$(m))
END FUNCTION


' A plain, un-rolled character: average scores, class-baseline combat stats.
' Used for the default HERO and for loaded champions (whose scores aren't saved).
SUB InitDefaultChar (pc AS INTEGER)
    player_str = 10: player_int = 10: player_wis = 10
    player_dex = 10: player_con = 10: player_cha = 10
    player_maxhp = CLASSES(pc).hp: player_hp = player_maxhp
    player_tohit = CLASSES(pc).tohit
    player_ac = CLASSES(pc).ac
    player_dmgdie = CLASSES(pc).dmg
    player_dmgbonus = 0
END SUB


' Draw the character-generation sheet. `rolled` = how many abilities are in
' (0..6); `done` = HP + derived stats are ready (final screen with the prompt).
' One line of the class's mechanical numbers.
FUNCTION ClassPerks$ (pc AS INTEGER)
    ClassPerks$ = "Hit die d" + _TRIM$(STR$(CLASSES(pc).hitdie)) + "     To-Hit base " + ModStr$(CLASSES(pc).tohit) + "     Damage d" + _TRIM$(STR$(CLASSES(pc).dmg)) + "     AC base " + _TRIM$(STR$(CLASSES(pc).ac))
END FUNCTION

' One line of the class's special ability (flavor + the mechanical edge).
FUNCTION ClassSpecial$ (pc AS INTEGER)
    SELECT CASE pc
        CASE 1: ClassSpecial$ = "HERO -- a stout, dependable all-rounder."
        CASE 2: ClassSpecial$ = "ELF -- doubles your odds of finding secret doors."
        CASE 3: ClassSpecial$ = "SUPERHERO -- mightiest in melee; strikes hardest."
        CASE 4: ClassSpecial$ = "WIZARD -- attacks with INT; cannot wield magic swords."
        CASE ELSE: ClassSpecial$ = ""
    END SELECT
END FUNCTION

' A colourful, humorous D&D-style name (a first name + an epithet).
FUNCTION RandomHeroName$
    DIM f(1 TO 20) AS STRING, s(1 TO 20) AS STRING
    f(1) = "Bort": f(2) = "Grimble": f(3) = "Sir Reginald": f(4) = "Fumblewick": f(5) = "Mungo"
    f(6) = "Grognak": f(7) = "Beans": f(8) = "Thistlewit": f(9) = "Piffle": f(10) = "Sir Lancelittle"
    f(11) = "Dungwold": f(12) = "Bumbershoot": f(13) = "Gorm": f(14) = "Snout": f(15) = "Wartleby"
    f(16) = "Higgs": f(17) = "Drizzle": f(18) = "Sniffles": f(19) = "Belch": f(20) = "Throg"
    s(1) = "the Unlucky": s(2) = "the Slightly Brave": s(3) = "Facepunch": s(4) = "Bumblesnatch": s(5) = "the Damp"
    s(6) = "Cheesewright": s(7) = "the Confused": s(8) = "Ironbottom": s(9) = "the Mostly Dead": s(10) = "Puddlejump"
    s(11) = "the Flatulent": s(12) = "Gutbuster": s(13) = "the Tardy": s(14) = "Noseworthy": s(15) = "the Perpetually Lost"
    s(16) = "Skullthumper": s(17) = "the Overconfident": s(18) = "Manytoes": s(19) = "the Sticky": s(20) = "Widdershins"
    RandomHeroName$ = f(RollDie(20)) + " " + s(RollDie(20))
END FUNCTION


SUB DrawCharGen (pc AS INTEGER, sc() AS INTEGER, rolled AS INTEGER, done AS INTEGER)
    DIM i AS INTEGER, y AS INTEGER, nm(1 TO 6) AS STRING, row AS STRING, fp AS STRING
    nm(1) = "STR": nm(2) = "INT": nm(3) = "WIS": nm(4) = "DEX": nm(5) = "CON": nm(6) = "CHA"
    _DEST CANVAS: CLS , BLACK
    COLOR YELLOWU, BLACK: PrintCentered 2, "C R E A T E   A   C H A R A C T E R"
    COLOR WHITE, BLACK: PrintCentered 4, "Name:  " + _TRIM$(player_name)
    COLOR CYANU, BLACK: PrintCentered 5, "Class:  " + _TRIM$(CLASSES(pc).name) + "        Win goal:  " + _TRIM$(STR$(CLASSES(pc).gold_goal)) + " gold"
    COLOR GREY, BLACK: PrintCentered 6, _TRIM$(CLASSES(pc).blurb)
    COLOR GREENU, BLACK: PrintCentered 7, ClassSpecial$(pc)
    COLOR CYANU, BLACK: PrintCentered 8, ClassPerks$(pc)
    FOR i = 1 TO 6
        y = 11 + (i - 1) * 2
        IF i <= rolled THEN
            row = nm(i) + "   " + RIGHT$("  " + _TRIM$(STR$(sc(i))), 2) + "   (" + ModStr$(AbilMod(sc(i))) + ")"
            IF i = rolled AND NOT done THEN COLOR WHITE, REDU ELSE COLOR WHITE, BLACK
        ELSE
            row = nm(i) + "   --"
            COLOR GREY, BLACK
        END IF
        PrintCentered y, "   " + row + "   "
    NEXT i
    IF done THEN
        COLOR GREENU, BLACK
        PrintCentered 24, "HIT POINTS  " + _TRIM$(STR$(player_maxhp))
        COLOR CYANU, BLACK
        PrintCentered 26, "AC " + _TRIM$(STR$(player_ac)) + "     To-Hit " + ModStr$(player_tohit) + "     Damage 1d" + _TRIM$(STR$(player_dmgdie)) + " " + ModStr$(player_dmgbonus)
        COLOR GREY, BLACK: PrintCentered 28, CombatDerivation$(pc)   ' where those bonuses come from
        fp = "[R] re-roll     [N] new name     "
        IF opt_flexstats = 1 THEN fp = fp + "[C] assign scores     "   ' rearrange the rolled scores
        fp = fp + "[ENTER] keep     [ESC] back"
        COLOR YELLOWU, BLACK: PrintCentered 44, fp
    ELSE
        COLOR CYANU, BLACK
        IF rolled < 6 THEN
            fp = "[ press a key ] roll " + nm(rolled + 1) + "      [A] auto-roll the rest      [N] new name      [ESC] back"
            IF rolled = 0 AND opt_flexstats = 2 THEN fp = "[P] point distribution      " + fp   ' build stats instead of rolling
            PrintCentered 44, fp
        ELSE
            PrintCentered 44, "[ press a key ] roll your HIT POINTS      [A] auto      [ESC] back"
        END IF
    END IF
    _DISPLAY
END SUB


' The full generation flow: roll 3d6 for six abilities, roll hit points on the
' class hit die, derive the D&D combat stats, and let the player re-roll.
' Honours Real Dice (each 3d6 becomes a PromptRoll when that setting is on).
' Name of ability i (1..6 -> STR/INT/WIS/DEX/CON/CHA).
FUNCTION StatName$ (i AS INTEGER)
    SELECT CASE i
        CASE 1: StatName$ = "STR"
        CASE 2: StatName$ = "INT"
        CASE 3: StatName$ = "WIS"
        CASE 4: StatName$ = "DEX"
        CASE 5: StatName$ = "CON"
        CASE ELSE: StatName$ = "CHA"
    END SELECT
END FUNCTION

' Re-derive the D&D combat stats from the current ability globals (STR/INT/DEX) + class.
SUB DeriveFromStats (pc AS INTEGER)
    DIM atkmod AS INTEGER
    IF pc = 4 THEN atkmod = AbilMod(player_int) ELSE atkmod = AbilMod(player_str)   ' Wizard swings with INT
    player_tohit = CLASSES(pc).tohit + atkmod
    player_dmgdie = CLASSES(pc).dmg
    player_dmgbonus = atkmod
    player_ac = CLASSES(pc).ac + AbilMod(player_dex)
END SUB

' Shared editor screen for the two flexible-stats modes. mode 2 = point distribution,
' 1 = assign/swap. cur = cursor row; moving = a picked-up row (assign; 0 = none).
' info = the pool/status line. Shows a LIVE combat preview computed off sc().
SUB DrawFlexStats (pc AS INTEGER, sc() AS INTEGER, cur AS INTEGER, moving AS INTEGER, mode AS INTEGER, info AS STRING)
    DIM i AS INTEGER, y AS INTEGER, arrow AS STRING, row AS STRING, atkm AS INTEGER, pac AS INTEGER, pth AS INTEGER
    _DEST CANVAS: _FONT CH: CLS , BLACK
    COLOR YELLOWU, BLACK
    IF mode = 2 THEN PrintCentered 2, "P O I N T   D I S T R I B U T I O N" ELSE PrintCentered 2, "A S S I G N   Y O U R   S C O R E S"
    COLOR WHITE, BLACK: PrintCentered 4, "Name:  " + _TRIM$(player_name) + "         Class:  " + _TRIM$(CLASSES(pc).name)
    FOR i = 1 TO 6
        y = 8 + (i - 1) * 2
        row = StatName$(i) + "   " + RIGHT$("  " + _TRIM$(STR$(sc(i))), 2) + "   (" + ModStr$(AbilMod(sc(i))) + ")"
        arrow = "  ": IF i = cur THEN arrow = "> "
        IF i = moving THEN
            COLOR BLACK, YELLOWU                       ' the score you picked up
        ELSEIF i = cur THEN
            COLOR WHITE, REDU                          ' the cursor
        ELSE
            COLOR WHITE, BLACK
        END IF
        PrintCentered y, "   " + arrow + row + "   "
    NEXT i
    DIM statn AS STRING
    IF pc = 4 THEN atkm = AbilMod(sc(2)): statn = "INT" ELSE atkm = AbilMod(sc(1)): statn = "STR"
    pac = CLASSES(pc).ac + AbilMod(sc(4)): pth = CLASSES(pc).tohit + atkm
    COLOR GREENU, BLACK: PrintCentered 20, "AC " + _TRIM$(STR$(pac)) + "  (" + _TRIM$(STR$(CLASSES(pc).ac)) + " class " + ModStr$(AbilMod(sc(4))) + " DEX)      To-Hit " + ModStr$(pth) + "  (" + ModStr$(CLASSES(pc).tohit) + " class " + ModStr$(atkm) + " " + statn + ")"
    COLOR GREY, BLACK: PrintCentered 21, "Damage 1d" + _TRIM$(STR$(CLASSES(pc).dmg)) + " " + ModStr$(atkm) + " " + statn + "      CON " + ModStr$(AbilMod(sc(5))) + " -> " + ModStr$(3 * AbilMod(sc(5))) + " HP      -- every +2 in a stat = +1 modifier --"
    COLOR CYANU, BLACK: PrintCentered 24, info
    COLOR YELLOWU, BLACK
    IF mode = 2 THEN
        PrintCentered 44, "[Up/Dn] pick stat     [Left] -1     [Right] +1     [ENTER] done     [ESC] cancel"
    ELSE
        PrintCentered 44, "[Up/Dn] move     [SPACE] pick up / drop (swap)     [ENTER] done     [ESC] cancel"
    END IF
    _DISPLAY
END SUB

' POINT DISTRIBUTION: every score starts at the floor (3); spend a pool up (max 18 each)
' so the six total 72. Returns TRUE (kept) / FALSE (cancelled).
FUNCTION PointBuyStats% (pc AS INTEGER, sc() AS INTEGER)
    DIM cur AS INTEGER, i AS INTEGER, pool AS INTEGER, used AS INTEGER, k AS STRING
    FOR i = 1 TO 6: sc(i) = 3: NEXT
    cur = 1
    DO
        used = 0: FOR i = 1 TO 6: used = used + sc(i): NEXT
        pool = 72 - used
        DrawFlexStats pc, sc(), cur, 0, 2, "POINTS LEFT: " + _TRIM$(STR$(pool)) + "     (each score 3 - 18)"
        k = "": DO: k = NormKey$(UCASE$(INKEY$)): _LIMIT 60: LOOP WHILE k = ""
        SELECT CASE k
            CASE "W": cur = cur - 1: IF cur < 1 THEN cur = 6
            CASE "S": cur = cur + 1: IF cur > 6 THEN cur = 1
            CASE "A": IF sc(cur) > 3 THEN sc(cur) = sc(cur) - 1: Sfx "select"
            CASE "D": IF sc(cur) < 18 AND pool > 0 THEN sc(cur) = sc(cur) + 1: Sfx "select"
            CASE CHR$(13): PointBuyStats% = -1: EXIT FUNCTION
            CASE CHR$(27): PointBuyStats% = 0: EXIT FUNCTION
        END SELECT
    LOOP
END FUNCTION

' ASSIGN ROLL: rearrange the rolled scores. [SPACE] picks up the cursor's score; move
' to another row and [SPACE] again swaps them. Returns TRUE (kept) / FALSE (cancelled).
FUNCTION AssignStats% (pc AS INTEGER, sc() AS INTEGER)
    DIM cur AS INTEGER, moving AS INTEGER, k AS STRING, tmp AS INTEGER, msg AS STRING
    cur = 1: moving = 0
    DO
        IF moving = 0 THEN
            msg = "Move to a score and press [SPACE] to pick it up."
        ELSE
            msg = "MOVING " + StatName$(moving) + " " + _TRIM$(STR$(sc(moving))) + "   --   [SPACE] swaps it with " + StatName$(cur) + " " + _TRIM$(STR$(sc(cur)))
        END IF
        DrawFlexStats pc, sc(), cur, moving, 1, msg
        k = "": DO: k = NormKey$(UCASE$(INKEY$)): _LIMIT 60: LOOP WHILE k = ""
        SELECT CASE k
            CASE "W": cur = cur - 1: IF cur < 1 THEN cur = 6
            CASE "S": cur = cur + 1: IF cur > 6 THEN cur = 1
            CASE " "
                IF moving = 0 THEN
                    moving = cur: Sfx "select"
                ELSE
                    tmp = sc(moving): sc(moving) = sc(cur): sc(cur) = tmp
                    moving = 0: Sfx "treasure"
                END IF
            CASE CHR$(13): AssignStats% = -1: EXIT FUNCTION
            CASE CHR$(27): AssignStats% = 0: EXIT FUNCTION
        END SELECT
    LOOP
END FUNCTION

SUB RollCharacter (pc AS INTEGER)
    DIM sc(1 TO 6) AS INTEGER, i AS INTEGER, hproll AS INTEGER, atkmod AS INTEGER, k AS STRING, auto AS INTEGER, stay_auto AS INTEGER, usedpoint AS INTEGER
    IF _TRIM$(player_name) = "" THEN player_name = RandomHeroName$   ' a colourful default to start
    IF opt_oldschool THEN RollCharacterClassic pc: EXIT SUB          ' Dungeon! board game: you PICK a class, no rolled stats
    DICE3D_YOFF = 14                                ' drop the 3D dice tray below the stat sheet so the scores stay visible
    stay_auto = FALSE                               ' once [A] is pressed it stays on through every re-roll
    DO
        auto = stay_auto
        usedpoint = FALSE
        FOR i = 1 TO 6
            DrawCharGen pc, sc(), i - 1, 0             ' show sheet + the prompt to roll this ability
            IF NOT auto THEN                           ' the player presses a key to roll each stat...
                DO
                    _LIMIT 60: k = UCASE$(INKEY$): _DISPLAY
                    IF k = "N" THEN player_name = RandomHeroName$: DrawCharGen pc, sc(), i - 1, 0: k = ""
                    IF k = CHR$(27) THEN DICE3D_YOFF = 0: EXIT SUB   ' one ESC aborts back to the menu
                    IF i = 1 AND opt_flexstats = 2 AND k = "P" THEN   ' point distribution instead of rolling
                        IF PointBuyStats%(pc, sc()) THEN
                            usedpoint = -1: k = CHR$(13)
                        ELSE
                            k = ""                    ' cancelled point-buy -> keep prompting to roll
                        END IF
                    END IF
                LOOP UNTIL k <> ""
                IF k = "A" THEN auto = -1: stay_auto = -1: Sfx "select"  ' ...or [A] to auto-roll the rest (and every re-roll after)
            ELSE
                IF INKEY$ = CHR$(27) THEN DICE3D_YOFF = 0: EXIT SUB  ' ESC bails out mid auto-roll too
            END IF
            IF usedpoint THEN EXIT FOR                 ' point-buy set all six -- skip the dice
            sc(i) = RollAbility                        ' 3d6 or 4d6-drop-low per the Stat-Roll setting
        NEXT i
        player_str = sc(1): player_int = sc(2): player_wis = sc(3)
        player_dex = sc(4): player_con = sc(5): player_cha = sc(6)
        ' hit points: three hit dice + 3x the CON modifier (a level-ish start), min 3
        DrawCharGen pc, sc(), 6, 0
        IF NOT auto THEN
            DO
                _LIMIT 60: k = UCASE$(INKEY$): _DISPLAY
                IF k = "N" THEN player_name = RandomHeroName$: DrawCharGen pc, sc(), 6, 0: k = ""
                IF k = CHR$(27) THEN DICE3D_YOFF = 0: EXIT SUB
            LOOP UNTIL k <> ""
        ELSE
            IF INKEY$ = CHR$(27) THEN DICE3D_YOFF = 0: EXIT SUB
        END IF
        hproll = GameRoll(3, CLASSES(pc).hitdie, 0, "HIT POINTS")
        player_maxhp = hproll + 3 * AbilMod(player_con)
        IF player_maxhp < 3 THEN player_maxhp = 3
        player_hp = player_maxhp
        DeriveFromStats pc                             ' to-hit / AC / damage from the ability scores
        DrawCharGen pc, sc(), 6, -1                    ' final sheet + reroll/name/keep prompt
        DO
            _LIMIT 60: k = UCASE$(INKEY$): _DISPLAY
            IF k = "N" THEN player_name = RandomHeroName$: DrawCharGen pc, sc(), 6, -1: k = ""
            IF k = "C" AND opt_flexstats = 1 THEN         ' rearrange the rolled scores
                IF AssignStats%(pc, sc()) THEN
                    player_str = sc(1): player_int = sc(2): player_wis = sc(3)
                    player_dex = sc(4): player_con = sc(5): player_cha = sc(6)
                    player_maxhp = hproll + 3 * AbilMod(player_con)   ' HP dice fixed; CON bonus re-derives
                    IF player_maxhp < 3 THEN player_maxhp = 3
                    player_hp = player_maxhp
                    DeriveFromStats pc
                END IF
                DrawCharGen pc, sc(), 6, -1: k = ""
            END IF
            IF k = CHR$(27) THEN DICE3D_YOFF = 0: EXIT SUB   ' ESC from the final prompt bails too
        LOOP UNTIL k = "R" OR k = CHR$(13)
        Sfx "select"
    LOOP UNTIL k = CHR$(13)
    DICE3D_YOFF = 0                                ' restore the normal dice position for combat / movement
END SUB


' -- OLD-SCHOOL (Dungeon! board game) character creation --
' In TSR's Dungeon! you do NOT roll attributes -- you simply PICK a class (a pawn).
' Confirm the class + name it; combat is a single 2d6 vs the monster's per-class number
' (no STR/INT/etc., no HP, no AC). InitDefaultChar sets harmless baseline combat stats the
' 2d6 path never reads, so the rest of the engine stays happy.
SUB RollCharacterClassic (pc AS INTEGER)
    DIM k AS STRING
    InitDefaultChar pc
    class_name = _TRIM$(CLASSES(pc).name)          ' keep the working globals in step with the pick
    target_gold = CLASSES(pc).gold_goal
    IF _TRIM$(player_name) = "" THEN player_name = RandomHeroName$
    DO
        DrawClassicCharGen pc
        _LIMIT 60: k = UCASE$(INKEY$): _DISPLAY
        IF k = "N" THEN player_name = RandomHeroName$
    LOOP UNTIL k = CHR$(13)
    Sfx "select"
END SUB

SUB DrawClassicCharGen (pc AS INTEGER)
    _DEST CANVAS: CLS , BLACK: _FONT CH
    COLOR YELLOWU, BLACK: PrintCentered 5, "-=  C H O O S E   Y O U R   A D V E N T U R E R  =-"
    COLOR WHITE, BLACK: PrintCentered 8, "You are " + _TRIM$(player_name) + " the " + _TRIM$(CLASSES(pc).name)
    COLOR CYANU, BLACK: PrintCentered 11, "Return to START with " + _TRIM$(STR$(CLASSES(pc).gold_goal)) + " gold to WIN."
    COLOR GREENU, BLACK: PrintCentered 13, ClassSpecial$(pc)
    COLOR GREY, BLACK
    PrintCentered 16, "The old rules: no attributes, no hit points, no armour class."
    PrintCentered 17, "Every fight is one roll of 2d6 against the monster's number for your class."
    COLOR YELLOWU, BLACK: PrintCentered 21, "[N] new name         [ENTER] begin your quest"
END SUB




' ============================================================================
'  INTRO
' ============================================================================

SUB ShowIntro
    DIM ansi AS STRING, mus AS LONG, k AS STRING, frames AS INTEGER
    ' Settle the display BEFORE the logo fade. The window's fullscreen transition is applied
    ' async by the compositor (Wayland) and only completes once we pump the event loop -- with
    ' the $CONSOLE build that landed mid-fade, flashing the logo to black and re-fading. Pump a
    ' few black frames here so it completes on black; the _DISPLAY also drops autodisplay, so the
    ' freshly-drawn logo can't flash at full brightness for a frame before FadeInCurrent starts.
    _DEST CANVAS: CLS , BLACK
    FOR frames = 1 TO 15: _DISPLAY: _LIMIT 60: NEXT
    ansi = _READFILE$("assets/ansi/vermin-radioactive-logo.ans")
    mus = _SNDOPEN(ResolveMusic$("vr-theme"))       ' best-quality file for this name (pack-aware)
    IF mus > 0 THEN _SNDVOL mus, opt_musicvol / 10
    IF mus > 0 AND opt_music THEN _SNDPLAY mus
    DIM splash AS LONG                              ' introsplash: a short (~3s) one-shot title sting at the intro
    splash = _SNDOPEN(ResolveMusic$("introsplash"))
    IF splash > 0 AND opt_music THEN _SNDVOL splash, opt_musicvol / 10: _SNDPLAY splash
    _DEST CANVAS: _FONT CH: CLS , BLACK
    ANSI_Print (ansi)
    FadeInCurrent                               ' fade the logo in from black
    frames = 0
    DO
        _LIMIT 30
        k = INKEY$
        frames = frames + 1
        _DISPLAY
    LOOP UNTIL k <> "" OR frames >= 150          ' auto-advance to the menu after ~5s idle
    FadeOut                                      ' fade to black before the menu
    IF mus > 0 THEN _SNDSTOP mus: _SNDCLOSE mus
    IF splash > 0 THEN _SNDSTOP splash: _SNDCLOSE splash
END SUB


' ============================================================================
'  MENU
' ============================================================================

FUNCTION RunMenu%
    DIM logo AS STRING
    DIM lw(1 TO 4) AS STRING, rw(1 TO 4) AS STRING, bl(1 TO 6) AS STRING
    DIM AS LONG iLogo, iLeft, iRight, iBlock, mus
    DIM AS INTEGER sel, i, result, chosen
    DIM AS LONG t
    DIM k AS STRING

    logo = _READFILE$("assets/ansi/dungeon-menu-logo.ans")
    FOR i = 1 TO 4: lw(i) = _READFILE$("assets/ansi/dungeon-menu-left-wall-" + _TRIM$(STR$(i)) + ".ans"): NEXT
    FOR i = 1 TO 4: rw(i) = _READFILE$("assets/ansi/dungeon-menu-right-wall-" + _TRIM$(STR$(i)) + ".ans"): NEXT
    FOR i = 1 TO 6: bl(i) = _READFILE$("assets/ansi/dungeon-menu-block-" + _TRIM$(STR$(i)) + ".ans"): NEXT

    iLogo = _NEWIMAGE(102 * CW, 15 * CH, 32)
    iLeft = _NEWIMAGE(15 * CW, 51 * CH, 32)
    iRight = _NEWIMAGE(16 * CW, 51 * CH, 32)
    iBlock = _NEWIMAGE(95 * CW, 31 * CH, 32)
    _DEST iLogo: _FONT CH: ANSI_Print (logo)
    _DEST iLeft: _FONT CH: ANSI_Print (lw(1))
    _DEST iRight: _FONT CH: ANSI_Print (rw(1))
    _DEST iBlock: _FONT CH: ANSI_Print (bl(1))

    PlayMenuMusic                                   ' the MAIN MENU theme (everdark), cue-aware so screens can override + restore it

    sel = 1: t = 0: result = 0
    bnr_l2 = ""                               ' no stale in-game banner should flash in the menu
    DIM firstframe AS INTEGER: firstframe = -1
    DO
        _LIMIT 60
        AudioTick                             ' menu-theme crossfade + any screen-cue fade-back
        k = NormKey$(UCASE$(INKEY$))          ' arrows/numpad -> WASD
        IF k = "A" OR k = "W" THEN sel = sel - 1: IF sel < 1 THEN sel = 6
        IF k = "D" OR k = "S" THEN sel = sel + 1: IF sel > 6 THEN sel = 1
        IF k = "A" OR k = "W" OR k = "S" OR k = "D" THEN Sfx "select"
        IF k = CHR$(13) THEN
            IF sel = 1 THEN
                result = MENU_ENTER: EXIT DO
            ELSEIF sel = 2 THEN
                PlayCue "chargen", -1                ' character-creation music (spans SelectClass + RollCharacter)
                chosen = SelectClass
                IF chosen > 0 THEN
                    player_class = chosen: player_name = ""
                    RollCharacter chosen             ' old-school 3d6 stats + rolled HP
                END IF
                EndCue                               ' back to the menu theme
            ELSEIF sel = 3 THEN
                LoadCharacter
            ELSEIF sel = 4 THEN
                ShowLords                            ' self-cues "lords" music internally
            ELSEIF sel = 5 THEN
                PlayCue "settings", -1
                RunSettings
                EndCue
                ' settings may have toggled music off or changed its volume -- resync the menu track
                IF opt_music THEN
                    IF music_handle > 0 THEN _SNDVOL music_handle, opt_musicvol / 10 ELSE PlayMenuMusic
                ELSEIF music_handle > 0 THEN
                    _SNDSTOP music_handle: _SNDCLOSE music_handle: music_handle = 0
                END IF
            ELSEIF sel = 6 THEN
                result = MENU_FLEE: EXIT DO
            END IF
        END IF
        IF k = CHR$(27) THEN result = MENU_FLEE: EXIT DO
        ' one-key presets: set combat + exploration style in a single pass
        IF k = "N" THEN
            opt_oldschool = FALSE: opt_fov = TRUE                  ' NEW SCHOOL: D&D dice + Field of View
            SaveSettings: Sfx "secret"
            Banner "NEW SCHOOL !", "D&D dice combat   +   Field of View exploration"
            _DELAY 0.9
        END IF
        IF k = "O" THEN
            opt_oldschool = TRUE: opt_fov = FALSE                  ' OLD SCHOOL: 2d6 + no FOV
            SaveSettings: Sfx "secret"
            Banner "OLD SCHOOL !", "Classic Dungeon! 2d6 combat   +   full map (no Field of View)"
            _DELAY 0.9
        END IF
        IF k = "R" THEN Sfx "select": ShowRules                    ' read the rules of the dungeon

        ' torch-flicker the walls now and then
        t = t + 1
        IF t MOD 10 = 0 THEN
            i = RollDie(5)
            IF i <= 4 THEN
                _DEST iLeft: CLS , BLACK: ANSI_Print (lw(i))
                _DEST iRight: CLS , BLACK: ANSI_Print (rw(i))
            END IF
        END IF

        ' compose the frame
        _DEST CANVAS: CLS , BLACK
        _PUTIMAGE (0, 0), iLeft
        _PUTIMAGE (116 * CW, 0), iRight
        _PUTIMAGE (14 * CW, 0), iLogo
        _DEST iBlock: CLS , BLACK: ANSI_Print (bl(sel))
        _DEST CANVAS: _PUTIMAGE (19 * CW, 15 * CH), iBlock
        COLOR CYANU, BLACK: PrintCentered 47, "CHAMPION: " + CLASSES(player_class).name
        DIM cmb AS STRING, fv AS STRING
        IF opt_oldschool THEN cmb = "2d6" ELSE cmb = "D&D"
        IF opt_fov THEN fv = "on" ELSE fv = "off"
        COLOR GREY, BLACK: PrintCentered 49, "[N] New School   [O] Old School   [R] Rules      (Combat " + cmb + "   FOV " + fv + ")"
        _DISPLAY
        IF firstframe THEN FadeInCurrent: firstframe = 0   ' fade the menu in on the first frame
    LOOP
    IF result = MENU_ENTER THEN BloodDrip ELSE FadeOut     ' blood-drip descent into the dungeon; plain fade otherwise

    IF music_handle > 0 THEN _SNDSTOP music_handle: _SNDCLOSE music_handle   ' stop the menu theme; PlayGame starts the level track
    IF music_fadeout > 0 THEN _SNDSTOP music_fadeout: _SNDCLOSE music_fadeout ' and any half-finished crossfade tail
    music_handle = 0: music_fadeout = 0: music_fading = 0
    _FREEIMAGE iLogo: _FREEIMAGE iLeft: _FREEIMAGE iRight: _FREEIMAGE iBlock
    RunMenu = result
END FUNCTION


FUNCTION OnOff$ (b AS INTEGER)
    IF b THEN OnOff$ = "ON" ELSE OnOff$ = "OFF"
END FUNCTION


' SETTINGS screen (menu option 5): toggle music / sfx / dice / fullscreen.
' A 0..10 volume bar, e.g. "[####------] 40%".
FUNCTION VolBar$ (v AS INTEGER)
    VolBar$ = "[" + STRING$(v, "#") + STRING$(10 - v, "-") + "] " + _TRIM$(STR$(v * 10)) + "%"
END FUNCTION


' Clamp a value to 0..10.
FUNCTION Clamp10% (v AS INTEGER)
    IF v < 0 THEN
        Clamp10 = 0
    ELSEIF v > 10 THEN
        Clamp10 = 10
    ELSE
        Clamp10 = v
    END IF
END FUNCTION


' Apply the Music on/off toggle the instant it's flipped in SETTINGS (the player expects
' silence NOW when they turn it off, not when they leave the screen). Off = stop whatever's
' playing but KEEP the level context (music_level) so turning it back on resumes the right
' track; On = restart the context track (level track in a delve, else the menu theme).
SUB ApplyMusicToggle
    IF opt_music THEN
        music_curfile = ""                          ' force an actual (re)start rather than the same-file skip
        IF music_level >= 1 AND music_level <= 9 THEN PlayLevelMusic music_level ELSE PlayMenuMusic
    ELSE
        IF music_handle > 0 THEN _SNDSTOP music_handle: _SNDCLOSE music_handle
        IF music_fadeout > 0 THEN _SNDSTOP music_fadeout: _SNDCLOSE music_fadeout
        music_handle = 0: music_fadeout = 0: music_fading = 0
        music_curfile = ""                          ' but leave music_level intact so re-enabling knows the context
    END IF
END SUB

SUB RunSettings
    CONST NSET = 48
    DIM sel AS INTEGER, k AS STRING, i AS INTEGER, y AS INTEGER, vtxt AS STRING, lbl AS STRING
    DIM slider AS INTEGER, delta AS INTEGER
    sel = 1
    ScanAllPacks                                    ' refresh the sfx/music pack lists (packs added on disk show up)
    Build3DPreviews                                 ' render the 3D dice previews once (rebuilt on set change)
    DO
        _LIMIT 60
        AudioTick                                   ' live music crossfade / toggle fade + narration fade
        k = NormKey$(UCASE$(INKEY$))
        IF k = "W" THEN sel = sel - 1: IF sel < 1 THEN sel = NSET
        IF k = "S" THEN sel = sel + 1: IF sel > NSET THEN sel = 1
        IF k = "W" OR k = "S" THEN Sfx "select"
        IF k = CHR$(27) THEN SaveSettings: Free3DPreviews: EXIT SUB

        ' A/D adjusts the sliders: volumes (2/4/6), dice colour (10), speed (13), players (16)
        IF k = "A" OR k = "D" THEN
            IF k = "A" THEN delta = -1 ELSE delta = 1
            SELECT CASE sel
                CASE 2: opt_musicvol = Clamp10(opt_musicvol + delta): IF music_handle > 0 THEN _SNDVOL music_handle, opt_musicvol / 10
                CASE 4: opt_sfxvol = Clamp10(opt_sfxvol + delta): Sfx "select"
                CASE 6: opt_voicevol = Clamp10(opt_voicevol + delta): VoiceBlip 700
                CASE 10
                    opt_dicecolor = opt_dicecolor + delta
                    IF opt_dicecolor < 0 THEN opt_dicecolor = 5
                    IF opt_dicecolor > 5 THEN opt_dicecolor = 0
                    Sfx "select"
                CASE 13
                    opt_dicespeed = opt_dicespeed + delta
                    IF opt_dicespeed < 0 THEN opt_dicespeed = 3
                    IF opt_dicespeed > 3 THEN opt_dicespeed = 0
                    Sfx "select"
                CASE 16
                    num_players = num_players + delta
                    IF num_players < 1 THEN num_players = 1
                    IF num_players > 4 THEN num_players = 4
                    IF num_players > 1 THEN opt_boardgame = TRUE ELSE opt_boardgame = FALSE
                    Sfx "select"
                CASE 21
                    opt_msgdelay = opt_msgdelay + delta
                    IF opt_msgdelay < 0 THEN opt_msgdelay = 5
                    IF opt_msgdelay > 5 THEN opt_msgdelay = 0
                    Sfx "select"
                CASE 24
                    opt_lootrecovery = opt_lootrecovery + delta
                    IF opt_lootrecovery < 0 THEN opt_lootrecovery = 2
                    IF opt_lootrecovery > 2 THEN opt_lootrecovery = 0
                    Sfx "select"
                CASE 25
                    opt_maxdeaths = opt_maxdeaths + delta
                    IF opt_maxdeaths < 1 THEN opt_maxdeaths = 9
                    IF opt_maxdeaths > 9 THEN opt_maxdeaths = 1
                    Sfx "select"
                CASE 26
                    opt_mon_dicecolor = opt_mon_dicecolor + delta
                    IF opt_mon_dicecolor < 0 THEN opt_mon_dicecolor = 5
                    IF opt_mon_dicecolor > 5 THEN opt_mon_dicecolor = 0
                    Sfx "select"
                CASE 29
                    opt_mon_dicespeed = opt_mon_dicespeed + delta
                    IF opt_mon_dicespeed < 0 THEN opt_mon_dicespeed = 3
                    IF opt_mon_dicespeed > 3 THEN opt_mon_dicespeed = 0
                    Sfx "select"
                CASE 30
                    opt_dice3d = NOT opt_dice3d: opt_mon_dice3d = opt_dice3d: Build3DPreviews: Sfx "select"
                CASE 31
                    opt_dice3d_set = opt_dice3d_set + delta
                    IF opt_dice3d_set < 1 THEN opt_dice3d_set = DSET_COUNT
                    IF opt_dice3d_set > DSET_COUNT THEN opt_dice3d_set = 1
                    LoadDiceSets: Build3DPreviews: Sfx "select"
                CASE 32
                    opt_mon_dice3d_set = opt_mon_dice3d_set + delta
                    IF opt_mon_dice3d_set < 1 THEN opt_mon_dice3d_set = DSET_COUNT
                    IF opt_mon_dice3d_set > DSET_COUNT THEN opt_mon_dice3d_set = 1
                    LoadDiceSets: Build3DPreviews: Sfx "select"
                CASE 33
                    opt_dicefont = opt_dicefont + delta
                    IF opt_dicefont < 1 THEN opt_dicefont = DICEFONT_N
                    IF opt_dicefont > DICEFONT_N THEN opt_dicefont = 1
                    Build3DPreviews: Sfx "select"
                CASE 38
                    opt_dicelight = opt_dicelight + delta
                    IF opt_dicelight < 0 THEN opt_dicelight = 3
                    IF opt_dicelight > 3 THEN opt_dicelight = 0
                    Sfx "select"
                CASE 39
                    opt_diceround = opt_diceround + delta
                    IF opt_diceround < 0 THEN opt_diceround = 10
                    IF opt_diceround > 10 THEN opt_diceround = 0
                    Build3DPreviews: Sfx "select"
                CASE 40
                    opt_bloodstrength = opt_bloodstrength + delta
                    IF opt_bloodstrength < 0 THEN opt_bloodstrength = 10
                    IF opt_bloodstrength > 10 THEN opt_bloodstrength = 0
                    Sfx "select"
                CASE 34
                    opt_flexstats = opt_flexstats + delta
                    IF opt_flexstats < 0 THEN opt_flexstats = 2
                    IF opt_flexstats > 2 THEN opt_flexstats = 0
                    Sfx "select"
                CASE 41
                    opt_solomode = opt_solomode + delta
                    IF opt_solomode < 0 THEN opt_solomode = 3
                    IF opt_solomode > 3 THEN opt_solomode = 0
                    Sfx "select"
                CASE 42
                    opt_solomins = opt_solomins + delta * 5
                    IF opt_solomins < 15 THEN opt_solomins = 30
                    IF opt_solomins > 30 THEN opt_solomins = 15
                    Sfx "select"
                CASE 43: CycleSfxPack delta
                CASE 44: CycleMusicPack delta
                CASE 45: CycleNarration delta
                CASE 46: CycleArtPack delta
                CASE 47
                    opt_narrfreq = opt_narrfreq + delta
                    IF opt_narrfreq < NARR_FLAVOR THEN opt_narrfreq = NARR_COMBAT
                    IF opt_narrfreq > NARR_COMBAT THEN opt_narrfreq = NARR_FLAVOR
                    Sfx "select"
            END SELECT
        END IF

        IF k = " " OR k = CHR$(13) THEN
            SELECT CASE sel
                CASE 1: opt_music = NOT opt_music: ApplyMusicToggle   ' take effect immediately (silence now / resume on)
                CASE 3: opt_sfx = NOT opt_sfx
                CASE 5: opt_voice = NOT opt_voice
                CASE 7: opt_showdice = NOT opt_showdice
                CASE 8: opt_realdice = NOT opt_realdice
                CASE 9: opt_dicemath = NOT opt_dicemath
                CASE 10
                    opt_dicecolor = opt_dicecolor + 1
                    IF opt_dicecolor > 5 THEN opt_dicecolor = 0
                CASE 11: opt_dicesolid = NOT opt_dicesolid
                CASE 12: opt_d6pips = NOT opt_d6pips
                CASE 13
                    opt_dicespeed = opt_dicespeed + 1
                    IF opt_dicespeed > 3 THEN opt_dicespeed = 0
                CASE 14: opt_oldschool = NOT opt_oldschool
                CASE 15
                    opt_boardgame = NOT opt_boardgame
                    IF num_players > 1 THEN opt_boardgame = TRUE   ' multiplayer requires it
                CASE 16
                    num_players = num_players + 1: IF num_players > 4 THEN num_players = 1
                    IF num_players > 1 THEN opt_boardgame = TRUE ELSE opt_boardgame = FALSE
                CASE 17: opt_heroicstats = NOT opt_heroicstats
                CASE 18
                    opt_fullscreen = NOT opt_fullscreen
                    ApplyDisplay
                CASE 19: opt_smooth = NOT opt_smooth: ApplyDisplay
                CASE 20: opt_fov = NOT opt_fov
                CASE 21
                    opt_msgdelay = opt_msgdelay + 1
                    IF opt_msgdelay > 5 THEN opt_msgdelay = 0
                CASE 22: opt_hardcore = NOT opt_hardcore
                CASE 23: opt_critfumble = NOT opt_critfumble
                CASE 24
                    opt_lootrecovery = opt_lootrecovery + 1
                    IF opt_lootrecovery > 2 THEN opt_lootrecovery = 0
                CASE 25
                    opt_maxdeaths = opt_maxdeaths + 1
                    IF opt_maxdeaths > 9 THEN opt_maxdeaths = 1
                CASE 26
                    opt_mon_dicecolor = opt_mon_dicecolor + 1
                    IF opt_mon_dicecolor > 5 THEN opt_mon_dicecolor = 0
                CASE 27: opt_mon_dicesolid = NOT opt_mon_dicesolid
                CASE 28: opt_mon_d6pips = NOT opt_mon_d6pips
                CASE 29
                    opt_mon_dicespeed = opt_mon_dicespeed + 1
                    IF opt_mon_dicespeed > 3 THEN opt_mon_dicespeed = 0
                CASE 30: opt_dice3d = NOT opt_dice3d: opt_mon_dice3d = opt_dice3d: Build3DPreviews
                CASE 31
                    opt_dice3d_set = opt_dice3d_set + 1
                    IF opt_dice3d_set > DSET_COUNT THEN opt_dice3d_set = 1
                    LoadDiceSets: Build3DPreviews
                CASE 32
                    opt_mon_dice3d_set = opt_mon_dice3d_set + 1
                    IF opt_mon_dice3d_set > DSET_COUNT THEN opt_mon_dice3d_set = 1
                    LoadDiceSets: Build3DPreviews
                CASE 33
                    opt_dicefont = opt_dicefont + 1
                    IF opt_dicefont > DICEFONT_N THEN opt_dicefont = 1
                    Build3DPreviews
                CASE 34: opt_flexstats = opt_flexstats + 1: IF opt_flexstats > 2 THEN opt_flexstats = 0
                CASE 35
                    opt_artstyle = opt_artstyle + 1: IF opt_artstyle > 2 THEN opt_artstyle = 0
                CASE 36: opt_gestures = NOT opt_gestures
                CASE 37: opt_juice = NOT opt_juice
                CASE 38
                    opt_dicelight = opt_dicelight + 1
                    IF opt_dicelight > 3 THEN opt_dicelight = 0
                CASE 39
                    opt_diceround = opt_diceround + 1
                    IF opt_diceround > 10 THEN opt_diceround = 0
                    Build3DPreviews
                CASE 40
                    opt_bloodstrength = opt_bloodstrength + 1
                    IF opt_bloodstrength > 10 THEN opt_bloodstrength = 0
                CASE 41
                    opt_solomode = opt_solomode + 1: IF opt_solomode > 3 THEN opt_solomode = 0
                CASE 42
                    opt_solomins = opt_solomins - 5: IF opt_solomins < 15 THEN opt_solomins = 30
                CASE 43: CycleSfxPack 1
                CASE 44: CycleMusicPack 1
                CASE 45: CycleNarration 1
                CASE 46: CycleArtPack 1
                CASE 47
                    opt_narrfreq = opt_narrfreq + 1: IF opt_narrfreq > NARR_COMBAT THEN opt_narrfreq = NARR_FLAVOR
                CASE 48: SaveSettings: Free3DPreviews: EXIT SUB
            END SELECT
            Sfx "select"
        END IF

        _DEST CANVAS: CLS , BLACK
        COLOR YELLOWU, BLACK: PrintCentered 1, "-=  S E T T I N G S  =-"
        FOR i = 1 TO NSET
            y = 2 + (i - 1)                     ' single-row list: title row 1, list rows 2..49, hint row 50
            slider = FALSE
            SELECT CASE i
                CASE 1: lbl = "Music": vtxt = OnOff$(opt_music)
                CASE 2: lbl = "  Music Vol": vtxt = VolBar$(opt_musicvol): slider = TRUE
                CASE 3: lbl = "Sound FX": vtxt = OnOff$(opt_sfx)
                CASE 4: lbl = "  SFX Vol": vtxt = VolBar$(opt_sfxvol): slider = TRUE
                CASE 5: lbl = "Voice": vtxt = OnOff$(opt_voice)
                CASE 6: lbl = "  Voice Vol": vtxt = VolBar$(opt_voicevol): slider = TRUE
                CASE 7: lbl = "Show Dice": vtxt = OnOff$(opt_showdice)
                CASE 8: lbl = "Real Dice": vtxt = OnOff$(opt_realdice)
                CASE 9
                    lbl = "Dice Math"
                    IF opt_dicemath THEN vtxt = "YOU add mods" ELSE vtxt = "GAME adds mods"
                CASE 10: lbl = "  Dice Colour": vtxt = DiceColorName$: slider = TRUE
                CASE 11
                    lbl = "  Dice Finish"
                    IF opt_dicesolid THEN vtxt = "solid" ELSE vtxt = "hollow outline"
                CASE 12
                    lbl = "  D6 Style"
                    IF opt_d6pips THEN vtxt = "pips" ELSE vtxt = "numbered"
                CASE 13
                    lbl = "  Dice Speed": slider = TRUE
                    SELECT CASE opt_dicespeed
                        CASE 0: vtxt = "slow"
                        CASE 2: vtxt = "fast"
                        CASE 3: vtxt = "instant"
                        CASE ELSE: vtxt = "normal"
                    END SELECT
                CASE 14
                    lbl = "Oldschool"
                    IF opt_oldschool THEN vtxt = "Dungeon! 2d6" ELSE vtxt = "D&D d20/HP"
                CASE 15
                    lbl = "Boardgame"
                    IF num_players > 1 THEN
                        vtxt = "roll to move (locked)"
                    ELSEIF opt_boardgame THEN
                        vtxt = "roll to move"
                    ELSE
                        vtxt = "free move"
                    END IF
                CASE 16
                    lbl = "Players": slider = TRUE
                    IF num_players > 1 THEN vtxt = _TRIM$(STR$(num_players)) + "  (hot-seat)" ELSE vtxt = "1  (solo)"
                CASE 17
                    lbl = "Stat Roll"
                    IF opt_heroicstats THEN vtxt = "4d6 drop-low" ELSE vtxt = "straight 3d6"
                CASE 18: lbl = "Full Screen": vtxt = OnOff$(opt_fullscreen)
                CASE 19
                    lbl = "Pixel Smoothing"
                    IF opt_smooth THEN vtxt = "smooth" ELSE vtxt = "crisp pixels"
                CASE 20: lbl = "Line of Sight": vtxt = OnOff$(opt_fov)
                CASE 21
                    lbl = "Message Delay": slider = TRUE
                    IF opt_msgdelay <= 0 THEN vtxt = "wait for key" ELSE vtxt = _TRIM$(STR$(opt_msgdelay)) + " sec"
                CASE 22
                    lbl = "Time Passes When Idle"
                    IF opt_hardcore THEN vtxt = "hardcore (yes)" ELSE vtxt = "casual (no)"
                CASE 23
                    lbl = "Crits & Fumbles"
                    IF opt_critfumble THEN vtxt = "cinematic" ELSE vtxt = "plain"
                CASE 24
                    lbl = "Loot on Death": slider = TRUE
                    SELECT CASE opt_lootrecovery
                        CASE 0: vtxt = "lost (classic)"
                        CASE 2: vtxt = "souls-like (1 try)"
                        CASE ELSE: vtxt = "reclaim (normal)"
                    END SELECT
                CASE 25
                    lbl = "Max Deaths": slider = TRUE
                    vtxt = _TRIM$(STR$(opt_maxdeaths)) + " lives"
                CASE 26: lbl = "  Monster Dice Colour": vtxt = ColorName$(opt_mon_dicecolor): slider = TRUE
                CASE 27
                    lbl = "  Monster Dice Finish"
                    IF opt_mon_dicesolid THEN vtxt = "solid" ELSE vtxt = "hollow outline"
                CASE 28
                    lbl = "  Monster D6 Style"
                    IF opt_mon_d6pips THEN vtxt = "pips" ELSE vtxt = "numbered"
                CASE 29
                    lbl = "  Monster Dice Speed": slider = TRUE
                    SELECT CASE opt_mon_dicespeed
                        CASE 0: vtxt = "slow"
                        CASE 2: vtxt = "fast"
                        CASE 3: vtxt = "instant"
                        CASE ELSE: vtxt = "normal"
                    END SELECT
                CASE 30
                    lbl = "Dice Style": slider = TRUE
                    IF opt_dice3d THEN vtxt = "3D dice" ELSE vtxt = "font dice (2D)"
                CASE 31
                    lbl = "  Player 3D Set": slider = TRUE
                    IF opt_dice3d_set >= 1 AND opt_dice3d_set <= DSET_COUNT THEN vtxt = _TRIM$(DSET_NAME(opt_dice3d_set)) ELSE vtxt = "-"
                CASE 32
                    lbl = "  Monster 3D Set": slider = TRUE
                    IF opt_mon_dice3d_set >= 1 AND opt_mon_dice3d_set <= DSET_COUNT THEN vtxt = _TRIM$(DSET_NAME(opt_mon_dice3d_set)) ELSE vtxt = "-"
                CASE 33
                    lbl = "  Dice Font": slider = TRUE
                    IF opt_dicefont >= 1 AND opt_dicefont <= DICEFONT_N THEN vtxt = _TRIM$(DICEFONT_NAME(opt_dicefont)) ELSE vtxt = "-"
                CASE 34
                    lbl = "Flexible Stats"
                    SELECT CASE opt_flexstats
                        CASE 1: vtxt = "assign roll"
                        CASE 2: vtxt = "point buy"
                        CASE ELSE: vtxt = "off (rolled)"
                    END SELECT
                CASE 35
                    lbl = "Art Style"
                    SELECT CASE opt_artstyle
                        CASE 1: vtxt = "Pixel Art"
                        CASE 2: vtxt = "Hybrid (ANSI + pixel)"
                        CASE ELSE: vtxt = "ANSI"
                    END SELECT
                CASE 36
                    lbl = "Action Gestures"
                    IF opt_gestures THEN vtxt = "on (timing bar)" ELSE vtxt = "off (dice only)"
                CASE 37
                    lbl = "Screen Effects"
                    IF opt_juice THEN vtxt = "on (shake + blood)" ELSE vtxt = "off"
                CASE 38
                    lbl = "  Dice Light": slider = TRUE
                    SELECT CASE opt_dicelight
                        CASE 0: vtxt = "off (flat)"
                        CASE 1: vtxt = "soft"
                        CASE 3: vtxt = "strong"
                        CASE ELSE: vtxt = "normal"
                    END SELECT
                CASE 39
                    lbl = "  Dice Round": slider = TRUE
                    IF opt_diceround <= 0 THEN vtxt = "sharp" ELSE vtxt = _TRIM$(STR$(opt_diceround)) + " / 10"
                CASE 40
                    lbl = "Blood": slider = TRUE
                    IF opt_bloodstrength <= 0 THEN vtxt = "none" ELSE vtxt = _TRIM$(STR$(opt_bloodstrength)) + " / 10"
                CASE 41
                    lbl = "Solo Mode"
                    SELECT CASE opt_solomode
                        CASE 1: vtxt = "Time Limit"
                        CASE 2: vtxt = "Item Search"
                        CASE 3: vtxt = "Monster Prey"
                        CASE ELSE: vtxt = "off (normal play)"
                    END SELECT
                    IF opt_solomode > 0 AND num_players > 1 THEN vtxt = vtxt + " (1 player only)"
                CASE 42
                    lbl = "  Solo Time": slider = TRUE
                    vtxt = _TRIM$(STR$(opt_solomins)) + " min"
                CASE 43
                    lbl = "SFX Pack": slider = TRUE
                    vtxt = PackLabel$(opt_sfxpack)
                    IF SFXPACK_N > 0 THEN vtxt = vtxt + "  (" + _TRIM$(STR$(PackIndex%(SFXPACKS(), SFXPACK_N, opt_sfxpack))) + "/" + _TRIM$(STR$(SFXPACK_N)) + ")"
                CASE 44
                    lbl = "Music Pack": slider = TRUE
                    vtxt = PackLabel$(opt_musicpack)
                    IF MUSICPACK_N > 0 THEN vtxt = vtxt + "  (" + _TRIM$(STR$(PackIndex%(MUSICPACKS(), MUSICPACK_N, opt_musicpack))) + "/" + _TRIM$(STR$(MUSICPACK_N)) + ")"
                CASE 45
                    lbl = "Narration": slider = TRUE
                    vtxt = NarrationLabel$
                    IF opt_narration AND NARRPACK_N > 0 THEN vtxt = vtxt + "  (" + _TRIM$(STR$(PackIndex%(NARRPACKS(), NARRPACK_N, opt_narrationpack))) + "/" + _TRIM$(STR$(NARRPACK_N)) + ")"
                CASE 46
                    lbl = "Art Pack": slider = TRUE
                    vtxt = PackLabel$(opt_artpack)
                    IF ARTPACK_N > 0 THEN vtxt = vtxt + "  (" + _TRIM$(STR$(PackIndex%(ARTPACKS(), ARTPACK_N, opt_artpack))) + "/" + _TRIM$(STR$(ARTPACK_N)) + ")"
                CASE 47
                    lbl = "  Narration Freq": slider = TRUE
                    vtxt = NarrFreqLabel$
                CASE ELSE: lbl = "<< Back": vtxt = ""
            END SELECT
            IF i = sel THEN COLOR WHITE, REDU ELSE IF slider THEN COLOR CYANU, BLACK ELSE COLOR GREY, BLACK
            IF i = NSET THEN PrintCentered y, "   " + lbl + "   " ELSE PrintCentered y, "   " + lbl + ":  " + vtxt + "   "
        NEXT i
        IF opt_dice3d THEN                                      ' 3D dice: live hardware previews of each set
            DrawDice3DPreviewAt 100, " your 3D dice", PREV3D_P, DSET3D(dice3d_set_index%(20))
            DrawDice3DPreviewAt 4, " monster 3D dice", PREV3D_M, MSET3D(dice3d_set_index%(20))
        ELSE                                                    ' font dice: the live 2x3 sample grid
            DrawDicePreview 100, " your dice"                   ' player dice on the right
            PushMonsterDice: DrawDicePreview 4, " monster dice": PopMonsterDice   ' monster dice on the left
        END IF
        COLOR CYANU, BLACK: PrintCentered 50, "[W/S] move   [A/D] adjust   [ENTER] toggle   [ESC] back"
        _DISPLAY
    LOOP
END SUB


' Live sample of the player's chosen dice, so the colour / finish / d6-style
' choices can be judged by eye. Drawn as a 2x3 grid on the RIGHT of the SETTINGS
' screen (the list is centred, so the right third is free) -- decoupled from the
' list length, which now runs too tall for a bottom row.
' Draw the live 2x3 sample grid using the CURRENT dice config, at cell-column
' `gxc`, headed by `lbl`. Called twice from SETTINGS: player dice (right) and --
' with the monster config swapped in -- monster dice (left).
SUB DrawDicePreview (gxc AS INTEGER, lbl AS STRING)
    DIM SD(1 TO 6) AS INTEGER, FV(1 TO 6) AS INTEGER
    DIM idx AS INTEGER, col AS INTEGER, rr AS INTEGER, px AS INTEGER, py AS INTEGER
    DIM gx AS INTEGER, gy AS INTEGER, cellw AS INTEGER, cellh AS INTEGER
    SD(1) = 20: FV(1) = 20
    SD(2) = 12: FV(2) = 12
    SD(3) = 10: FV(3) = 10
    SD(4) = 8: FV(4) = 8
    SD(5) = 4: FV(5) = 4
    SD(6) = 6: FV(6) = 6
    cellw = 84: cellh = 92
    gx = gxc * CW: gy = 15 * CH
    _DEST CANVAS
    COLOR GREY, BLACK: _PRINTSTRING (gx, gy - 3 * CH), lbl
    FOR idx = 1 TO 6
        col = (idx - 1) MOD 2
        rr = (idx - 1) \ 2
        px = gx + col * cellw
        py = gy + rr * cellh
        IF SD(idx) = 6 AND opt_d6pips THEN
            DrawDie px + 8, py + 16, 48, 6     ' pip d6, centred in its cell
        ELSE
            DrawFontDie px, py, SD(idx), FV(idx)
        END IF
    NEXT idx
    _FONT CH
END SUB


' Apply the fullscreen + pixel-smoothing preferences to the display. _SMOOTH gives
' bilinear-filtered scaling (soft, and it makes the tumbling dice shimmer); without
' it the canvas is pixel-doubled crisp -- better suited to the ANSI/text art.
SUB ApplyDisplay
    IF opt_fullscreen THEN
        IF opt_smooth THEN
            _FULLSCREEN _SQUAREPIXELS, _SMOOTH
        ELSE
            _FULLSCREEN _SQUAREPIXELS
        END IF
    ELSE
        _FULLSCREEN _OFF
    END IF
END SUB


' Spell out where the D&D combat bonuses come from: to-hit = class base + the
' attack stat's modifier (STR for fighters, INT for the Wizard), damage adds that
' same modifier, and AC = class base + the DEX modifier.
FUNCTION CombatDerivation$ (pc AS INTEGER)
    DIM baseth AS INTEGER, atkmod AS INTEGER, baseac AS INTEGER, dexmod AS INTEGER, statn AS STRING, s AS STRING
    baseth = CLASSES(pc).tohit
    atkmod = player_tohit - baseth
    baseac = CLASSES(pc).ac
    dexmod = player_ac - baseac
    IF pc = 4 THEN statn = "INT" ELSE statn = "STR"
    s = "To-Hit " + ModStr$(player_tohit) + " = " + ModStr$(baseth) + " class " + ModStr$(atkmod) + " " + statn
    s = s + "     Dmg " + ModStr$(player_dmgbonus) + " " + statn
    s = s + "     AC " + _TRIM$(STR$(player_ac)) + " = " + _TRIM$(STR$(baseac)) + " class " + ModStr$(dexmod) + " DEX"
    CombatDerivation$ = s
END FUNCTION


SUB ShowCharSheet
    DIM i AS INTEGER, y AS INTEGER, col AS INTEGER, nshow AS INTEGER, inv AS STRING, ln AS STRING
    DIM who AS STRING, effac AS INTEGER, efth AS INTEGER
    effac = player_ac + item_armor + item_shield                     ' AC + worn armor/shield
    efth = player_tohit: IF item_bow THEN efth = efth + 2   ' to-hit + Magic Bow
    _DEST CANVAS
    LINE (22 * CW, 3 * CH)-(110 * CW, 48 * CH), BOXBG, BF
    LINE (22 * CW, 3 * CH)-(110 * CW, 48 * CH), REDU, B
    ' pixel-art class portrait, top-right of the sheet (Hybrid/Pixel modes, if it exists)
    IF opt_artstyle > 0 THEN
        DIM csp AS STRING, ddrew AS INTEGER
        csp = ClassSprite$(player_class)
        IF LEN(csp) > 0 AND _FILEEXISTS(csp) THEN
            LINE (92 * CW - 3, 5 * CH - 3)-(108 * CW + 3, 21 * CH + 3), _RGB32(&H10, &H08, &H10), BF
            LINE (92 * CW - 3, 5 * CH - 3)-(108 * CW + 3, 21 * CH + 3), REDU, B
            ddrew = DrawSpriteFit%(csp, 92 * CW, 5 * CH, 16 * CW, 16 * CH)
        END IF
    END IF
    who = _TRIM$(player_name) + " the " + class_name
    IF _TRIM$(player_name) = "" THEN who = class_name
    COLOR YELLOWU, BOXBG: PrintCentered 4, "-=  C H A R A C T E R  =-"
    DIM chline AS STRING
    chline = "Champion:  " + who
    IF NOT opt_oldschool THEN chline = chline + "        Level " + _TRIM$(STR$(char_level)) + "    XP " + _TRIM$(STR$(char_xp))
    COLOR WHITE, BOXBG: PrintCentered 6, chline
    IF NOT opt_oldschool THEN
        COLOR CYANU, BOXBG
        PrintCentered 7, "STR " + _TRIM$(STR$(player_str)) + "  INT " + _TRIM$(STR$(player_int)) + "  WIS " + _TRIM$(STR$(player_wis)) + "  DEX " + _TRIM$(STR$(player_dex)) + "  CON " + _TRIM$(STR$(player_con)) + "  CHA " + _TRIM$(STR$(player_cha))
        COLOR GREENU, BOXBG
        PrintCentered 8, "HP " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + "    AC " + _TRIM$(STR$(effac)) + "    To-Hit " + ModStr$(efth) + "    Dmg 1d" + _TRIM$(STR$(player_dmgdie)) + " " + ModStr$(player_dmgbonus + item_sword)
        COLOR GREY, BOXBG: PrintCentered 9, CombatDerivation$(player_class)   ' where those bonuses come from
    ELSE
        COLOR GREENU, BOXBG: PrintCentered 8, ClassSpecial$(player_class)     ' Dungeon!: just the class + its edge -- no stats, HP, or AC
    END IF
    ' wealth line
    COLOR YELLOWU, BOXBG
    ln = "GOLD  " + _TRIM$(STR$(gold)) + " / " + _TRIM$(STR$(target_gold))
    IF has_key THEN ln = ln + "        LEVEL KEY: HELD" ELSE ln = ln + "        LEVEL KEY: on the " + Ordinal$(key_level) + " level"
    PrintCentered 10, ln
    ' special items held
    inv = ""
    IF item_sword > 0 THEN inv = inv + "Magic Sword +" + _TRIM$(STR$(item_sword)) + "    "
    IF item_armor > 0 THEN inv = inv + "Armor +" + _TRIM$(STR$(item_armor)) + " AC    "
    IF item_shield > 0 THEN inv = inv + "Shield +" + _TRIM$(STR$(item_shield)) + " AC    "
    IF item_bow THEN inv = inv + "Magic Bow (+2 hit)    "
    IF item_boots THEN inv = inv + "Elf Boots (+2 move, easy flee)    "
    IF item_teleport > 0 THEN inv = inv + "Teleport x" + _TRIM$(STR$(item_teleport)) + " [T]    "
    IF spell_fire > 0 THEN inv = inv + "Fire Ball x" + _TRIM$(STR$(spell_fire)) + " [F]    "
    IF spell_bolt > 0 THEN inv = inv + "Lightning x" + _TRIM$(STR$(spell_bolt)) + " [L]    "
    IF item_potion_small > 0 THEN inv = inv + "Sm Potion x" + _TRIM$(STR$(item_potion_small)) + " [H]    "
    IF item_potion_large > 0 THEN inv = inv + "Lg Potion x" + _TRIM$(STR$(item_potion_large)) + " [H]    "
    IF item_secret_card THEN inv = inv + "Secret Door Card    "
    IF item_esp THEN inv = inv + "ESP Medallion    "
    IF item_crystal THEN inv = inv + "Crystal Ball [V]    "
    IF inv = "" THEN inv = "(no magic items yet)"
    COLOR WHITE, BOXBG: PrintCentered 12, "MAGIC:  " + _TRIM$(inv)
    ' the treasures claimed
    COLOR REDU, BOXBG: PrintCentered 14, "-=  T R E A S U R E S   C L A I M E D  ( " + _TRIM$(STR$(LOOT_N(cur_player))) + " )  =-"
    COLOR WHITE, BOXBG
    IF LOOT_N(cur_player) = 0 THEN
        COLOR GREY, BOXBG: PrintCentered 18, "(none yet -- slay a monster to claim its hoard)"
    ELSE
        nshow = LOOT_N(cur_player)
        IF nshow > 60 THEN nshow = 60          ' two columns x 30 rows
        FOR i = 1 TO nshow
            IF (i AND 1) THEN col = 27 ELSE col = 68
            y = 16 + (i - 1) \ 2
            ln = PadR$(_TRIM$(LOOT_NAME(cur_player, i)), 18) + RIGHT$("      " + _TRIM$(STR$(LOOT_GOLD(cur_player, i))), 6) + "g"
            _PRINTSTRING (col * CW, y * CH), ln
        NEXT i
        IF LOOT_N(cur_player) > 60 THEN
            COLOR GREY, BOXBG: _PRINTSTRING (27 * CW, 47 * CH), "...and " + _TRIM$(STR$(LOOT_N(cur_player) - 60)) + " more"
        END IF
    END IF
    COLOR YELLOWU, BOXBG: PrintCentered 46, "[ press any key ]"
    _DISPLAY
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' [V] Crystal Ball: scry every level's guardian and the treasure it hides.

SUB ScryView
    DIM i AS INTEGER, y AS INTEGER, mons AS STRING, tre AS STRING
    IF NOT item_crystal THEN
        Banner "You have no way to scry the dungeon.", "Find the CRYSTAL BALL first.   [ press any key ]"
        WaitKey
        cursor_erase: cursor_draw: DrawHUD: _DISPLAY
        EXIT SUB
    END IF
    PopArt "Crystal Ball", "CRYSTAL BALL"                 ' show the orb as you gaze into it
    DIM r AS INTEGER, rtot(1 TO 9) AS INTEGER, rclr(1 TO 9) AS INTEGER, gleft(1 TO 9) AS LONG
    FOR i = 1 TO 9: rtot(i) = 0: rclr(i) = 0: gleft(i) = 0: NEXT i
    FOR r = 1 TO ROOM_N
        i = ROOMS(r).sec
        IF LEN(_TRIM$(ROOMS(r).monster)) > 0 THEN          ' an encounter room
            rtot(i) = rtot(i) + 1
            IF NOT ROOMS(r).malive THEN rclr(i) = rclr(i) + 1
            IF NOT ROOMS(r).looted THEN gleft(i) = gleft(i) + ROOMS(r).treasure
        END IF
    NEXT r
    _DEST CANVAS
    LINE (18 * CW, 6 * CH)-(114 * CW, 47 * CH), BOXBG, BF
    LINE (18 * CW, 6 * CH)-(114 * CW, 47 * CH), CYANU, B
    COLOR CYANU, BOXBG: PrintCentered 8, "-=  C R Y S T A L   B A L L  =-"
    FOR i = 1 TO 9
        y = 11 + (i - 1) * 3
        COLOR WHITE, BOXBG: PrintCentered y, SECTORS(i).label
        COLOR GREY, BOXBG: PrintCentered y + 1, _TRIM$(STR$(rclr(i))) + "/" + _TRIM$(STR$(rtot(i))) + " rooms cleared    " + _TRIM$(STR$(gleft(i))) + " gold still guarded"
    NEXT i
    ' the Crystal Ball's true gift: it pinpoints the room hiding the Level Key
    IF has_key THEN
        COLOR GREENU, BOXBG: PrintCentered 43, "You already hold the LEVEL KEY -- flee to the entrance!"
    ELSEIF key_room >= 1 THEN
        COLOR YELLOWU, BOXBG: PrintCentered 43, "The LEVEL KEY is guarded by the " + _TRIM$(ROOMS(key_room).monster) + " on the " + Ordinal$(key_level) + " level."
    END IF
    COLOR YELLOWU, BOXBG: PrintCentered 45, "[ press any key ]"
    _DISPLAY
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' [?] Controls: the single source of truth for key bindings, rendered as a table.
SUB ShowKeys
    DIM ky(1 TO 16) AS STRING, ds(1 TO 16) AS STRING, n AS INTEGER, i AS INTEGER, y AS INTEGER
    ky(1) = "WASD / Arrows": ds(1) = "Move up / left / down / right"
    ky(2) = "Numpad 7 9 1 3": ds(2) = "Move diagonally (NW/NE/SW/SE)"
    ky(3) = "SPACE": ds(3) = "End turn (boardgame) / Attack"
    ky(4) = "F": ds(4) = "Search for secret doors"
    ky(5) = "C": ds(5) = "Character sheet"
    ky(6) = "M": ds(6) = "Game Menu (log, bestiary, treasury, rules)"
    ky(7) = "V": ds(7) = "Scry the dungeon (Crystal Ball)"
    ky(8) = "T": ds(8) = "Read a Teleport Scroll -> START"
    ky(9) = "?": ds(9) = "This controls list"
    ky(10) = "~  or  `": ds(10) = "Debug overlay ([0] test menu, click = teleport)"
    ky(11) = "ESC": ds(11) = "Flee combat / quit to menu"
    ky(12) = "R": ds(12) = "Re-roll (during character creation)"
    ky(13) = "H": ds(13) = "Quaff a healing potion"
    ky(14) = "P": ds(14) = "Pause the game (bio break)"
    ky(15) = "G": ds(15) = "Save game (solo; CONTINUE on entry)"
    n = 15
    _DEST CANVAS
    LINE (22 * CW, 7 * CH)-(110 * CW, 46 * CH), BOXBG, BF
    LINE (22 * CW, 7 * CH)-(110 * CW, 46 * CH), CYANU, B
    COLOR YELLOWU, BOXBG: PrintCentered 9, "-=  C O N T R O L S  =-"
    FOR i = 1 TO n
        y = 13 + (i - 1) * 2
        COLOR GREENU, BOXBG: _PRINTSTRING (30 * CW, y * CH), PadR$(ky(i), 16)
        COLOR WHITE, BOXBG: _PRINTSTRING (48 * CW, y * CH), ds(i)
    NEXT i
    COLOR YELLOWU, BOXBG: PrintCentered 44, "[ press any key ]"
    _DISPLAY
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' [F] search for a hidden secret door within a couple of cells of the cursor.
' The Elf's secret_bonus makes the d6 check far more reliable. The first door
' found also yields the Level Key.

SUB ShowEnd (win AS INTEGER)
    DIM nm AS STRING, el AS LONG, mapid AS LONG
    IF win THEN
        Sfx "win"
        PlayCue "victory", TRUE                  ' victory music (if assets/music/victory.* exists), through name entry
        el = TIMER - game_start: IF el < 0 THEN el = el + 86400
        '--- snapshot the final board (explored state, labels, final position) BEFORE the
        '    name-entry screen overdraws it, keyed to a deterministic per-lord map id ---
        cursor_erase: cursor_draw
        mapid = ABS(gold) * 97 + el * 13 + player_str * 7 + player_dex * 3 + LEN(class_name) * 101
        IF mapid < 0 THEN mapid = -mapid
        IF _DIREXISTS("dungeon-lords-maps") = 0 THEN MKDIR "dungeon-lords-maps"   ' ensure the subdir exists before saving
        _SAVEIMAGE LordsMapPath$(_TRIM$(STR$(mapid))), CANVAS
        nm = EnterName$                         ' victory + name entry
        player_name = nm
        SaveLord nm, class_name, gold, el, mapid ' enshrine in the Legendary Lords
        _DEST CANVAS: _FONT CH: CLS , BLACK
        COLOR GREENU, BLACK: PrintCentered 20, Say$("win.title")
        COLOR WHITE, BLACK: PrintCentered 23, nm + " the " + class_name + " escapes with " + _TRIM$(STR$(gold)) + " gold!"
        COLOR CYANU, BLACK: PrintCentered 25, Say$("win.subtitle")
    ELSE
        Sfx "lose"
        PlayCue "lose", TRUE                     ' defeat music (if assets/music/lose.* exists)
        _DEST CANVAS: _FONT CH: CLS , BLACK
        COLOR REDU, BLACK: PrintCentered 20, Say$("lose.title")
        COLOR GREY, BLACK: PrintCentered 23, Say$("lose.subtitle")
    END IF
    COLOR YELLOWU, BLACK: PrintCentered 28, Say$("end.return")
    IF win THEN Narrate "win.title" ELSE Narrate "lose.title"   ' spoken line (if a narration pack has it)
    FadeInCurrent                               ' fade the end screen in
    WaitKey
    FadeOut                                      ' fade out before returning to the menu
    NarrateStop                                  ' stop any spoken line + the victory/lose cue before the menu music
    music_cue_active = FALSE: StopLevelMusic
END SUB


' ============================================================================
'  BOARD + CURSOR  (pixel-color collision, adapted from TEST-MOVEMENT-MAP.bas)
' ============================================================================

' Per-player death tally for the HUD. CHR$(15) is the closest ROM-font glyph to a
' skull/marker; solo shows one count, hot-seat shows all seats.
FUNCTION DeathTag$
    DIM s AS STRING, p AS INTEGER
    IF num_players <= 1 THEN
        DeathTag$ = "   " + CHR$(15) + " " + _TRIM$(STR$(deaths(1))) + "/" + _TRIM$(STR$(opt_maxdeaths))
    ELSE
        s = "   " + CHR$(15)
        FOR p = 1 TO num_players
            s = s + " P" + _TRIM$(STR$(p)) + ":" + _TRIM$(STR$(deaths(p))) + "/" + _TRIM$(STR$(opt_maxdeaths))
        NEXT p
        DeathTag$ = s
    END IF
END FUNCTION


' Compact readout of any active status effects, for the HUD (empty when clear).
FUNCTION StatusTag$
    DIM s AS STRING
    s = ""
    IF poison_turns > 0 THEN s = s + " {PSN" + _TRIM$(STR$(poison_turns)) + "}"
    IF fire_turns > 0 THEN s = s + " {FIRE" + _TRIM$(STR$(fire_turns)) + "}"
    IF frost_turns > 0 THEN s = s + " {FRZ" + _TRIM$(STR$(frost_turns)) + "}"
    IF siren_turns > 0 THEN s = s + " {SIREN" + _TRIM$(STR$(siren_turns)) + "}"
    StatusTag$ = s
END FUNCTION


SUB DrawHUD
    DIM sec AS INTEGER, lbl AS STRING, hud AS STRING
    _DEST CANVAS
    DIM keytag AS STRING
    sec = SECTOR.get_by_xy(c.x, c.y)
    IF sec >= 1 THEN lbl = SECTORS(sec).label ELSE lbl = "THE HALLS"
    IF has_key THEN keytag = "KEY" ELSE keytag = "no key"
    DIM inv AS STRING
    IF item_sword > 0 THEN inv = inv + "  SWD+" + _TRIM$(STR$(item_sword))
    IF item_secret_card THEN inv = inv + "  SDC"
    IF item_esp THEN inv = inv + "  ESP"
    IF item_crystal THEN inv = inv + "  CRY"
    IF item_potion_small + item_potion_large > 0 THEN inv = inv + "  POT" + _TRIM$(STR$(item_potion_small + item_potion_large))
    DIM el AS LONG, tmr AS STRING
    el = TIMER - game_start
    IF el < 0 THEN el = el + 86400
    tmr = _TRIM$(STR$(el \ 60)) + ":" + RIGHT$("0" + _TRIM$(STR$(el MOD 60)), 2)
    DIM hptag AS STRING, lvltag AS STRING
    IF NOT opt_oldschool THEN hptag = "   HP " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)): lvltag = " L" + _TRIM$(STR$(char_level))
    DIM movetag AS STRING, ptag AS STRING
    IF opt_boardgame THEN movetag = "   TURN " + _TRIM$(STR$(turn_num)) + "   STEPS " + _TRIM$(STR$(steps_left)) ELSE movetag = "   MOVES " + _TRIM$(STR$(moves_made))
    IF num_players > 1 THEN ptag = "P" + _TRIM$(STR$(cur_player)) + " " + player_name + "  " ELSE ptag = ""
    LINE (0, 50 * CH)-(SW * CW, 51 * CH), BLACK, BF
    COLOR WHITE, BLACK
    hud = " " + ptag + class_name + lvltag + hptag + "   GOLD " + _TRIM$(STR$(gold)) + "/" + _TRIM$(STR$(target_gold)) + "   " + keytag + inv + movetag + DeathTag$ + StatusTag$ + "   " + tmr + "   " + lbl
    _PRINTSTRING (0, 50 * CH), hud
    IF need_roll THEN
        ' prominent centred prompt -- the roll-to-move step is easy to miss otherwise
        DIM rp AS STRING, bx1 AS INTEGER, bx2 AS INTEGER
        rp = "[ SPACE ]  ROLL THE DICE TO MOVE"
        bx1 = (SW - LEN(rp)) \ 2 - 2: bx2 = (SW + LEN(rp)) \ 2 + 2
        IF (INT(TIMER * 2) MOD 2) = 0 THEN                          ' gentle pulse for attention
            LINE (bx1 * CW, 2 * CH)-(bx2 * CW, 5 * CH), _RGB32(&H35, &H22, &H00), BF
            LINE (bx1 * CW, 2 * CH)-(bx2 * CW, 5 * CH), YELLOWU, B
            COLOR YELLOWU, _RGB32(&H35, &H22, &H00)
        ELSE
            LINE (bx1 * CW, 2 * CH)-(bx2 * CW, 5 * CH), _RGB32(&H22, &H16, &H00), BF
            LINE (bx1 * CW, 2 * CH)-(bx2 * CW, 5 * CH), _RGB32(&HAA, &H88, &H00), B
            COLOR _RGB32(&HDD, &HBB, &H33), _RGB32(&H22, &H16, &H00)
        END IF
        PrintCentered 3, rp
        COLOR YELLOWU, BLACK
        _PRINTSTRING ((SW - 17) * CW, 50 * CH), "[SPACE] ROLL DICE"
    ELSEIF Game_WinReady% THEN
        COLOR GREENU, BLACK
        _PRINTSTRING ((SW - 23) * CW, 50 * CH), "RETURN TO START TO WIN!"
    ELSEIF opt_boardgame AND steps_left > 0 THEN
        COLOR YELLOWU, BLACK
        _PRINTSTRING ((SW - 29) * CW, 50 * CH), "move up to " + _TRIM$(STR$(steps_left)) + "   [SPACE] end turn"
    END IF
    ' Keep the combat panel constant through a fight: every roll's cleanup ends with a
    ' DrawHUD, so repainting the panel here means it never vanishes behind a dice roll or
    ' a result banner (the HUD line is row 50, the panel rows 39-49 -- no overlap).
    ' In combat the panel draws its own near-death vignette (+ _DISPLAY); on the board
    ' there's no panel, so draw the wounds overlay here. (Avoids a double-darken.)
    IF combat_active THEN DrawCombatPanel combat_rm, combat_mon, combat_lead   ' wounds now drawn in cursor_erase, under everything
END SUB



