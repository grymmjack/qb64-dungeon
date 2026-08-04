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
        Present
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
    hp_start_amount = player_maxhp                 ' what the entrance will restore, for the whole run
    LuckRefill                                     ' CHA modifier = luck re-rolls for this run
    FlourishRefill                                 ' DEX modifier = flourishes for this run
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
    ' WHAT THE ABILITY DOES, on the rolling screen too. The point-buy and assign editors have
    ' always shown this (DrawFlexStats), but rolling straight 3d6 / 4d6-drop-low is where a
    ' player is LEAST able to act on the information and MOST likely to want it -- you are
    ' watching a number land on a stat you may not know the use of.
    '
    ' It tracks the HIGHLIGHTED row -- the score just rolled -- not the one queued next. Keyed to
    ' the next one, the panel described INT while STR sat highlighted in red, which reads as the
    ' panel being wrong rather than as being one ahead.
    '
    ' Drawn on the LEFT, clear of everything: the scores run down the centre and the dice tray
    ' owns the bottom third (DICE3D_YOFF pushes it to ~row 26), so the first position tried put
    ' the text underneath the tray with only its last two lines poking out.
    DIM helpstat AS INTEGER
    helpstat = rolled                             ' the row currently highlighted
    IF helpstat < 1 THEN helpstat = 1             ' nothing rolled yet -> STR, the one coming up
    ' Width 48, not 38: DrawStatHelp truncates to wid-4, and stats.txt authors its lines to 44
    ' characters -- at 38 every longer line lost its last words ("barter: what you pay and what
    ' you"). Still ends at column 51, clear of the centred score column.
    IF NOT done THEN DrawStatHelp helpstat, 3, 11, 48
    IF done THEN
        COLOR GREENU, BLACK
        PrintCentered 24, "HIT POINTS  " + _TRIM$(STR$(player_maxhp))
        COLOR CYANU, BLACK
        PrintCentered 26, "AC " + _TRIM$(STR$(player_ac)) + "     To-Hit " + ModStr$(player_tohit) + "     Damage 1d" + _TRIM$(STR$(player_dmgdie)) + " " + ModStr$(player_dmgbonus)
        COLOR GREY, BLACK: PrintCentered 28, CombatDerivation$(pc)   ' where those bonuses come from
        fp = "[R] re-roll   [Shift-R] fast   [E] rename   [N] random name   "
        IF opt_flexstats = 1 THEN fp = fp + "[C] assign scores   "   ' rearrange the rolled scores
        fp = fp + "[ENTER] keep   [ESC] back"
        COLOR YELLOWU, BLACK: PrintCentered 44, fp
    ELSE
        COLOR CYANU, BLACK
        IF rolled < 6 THEN
            fp = "[ press a key ] roll " + nm(rolled + 1) + "   [A] auto-roll rest   [E] rename   [N] random name   [ESC] back"
            IF rolled = 0 AND opt_flexstats = 2 THEN fp = "[P] point distribution   " + fp   ' build stats instead of rolling
            PrintCentered 44, fp
        ELSE
            PrintCentered 44, "[ press a key ] roll your HIT POINTS      [A] auto      [ESC] back"
        END IF
    END IF
    Present
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
    DrawStatHelp cur, 42, 27, 48        ' what the stat under the cursor actually does
    COLOR YELLOWU, BLACK
    IF mode = 2 THEN
        PrintCentered 44, "[Up/Dn] pick stat     [Left] -1     [Right] +1     [ENTER] done     [ESC] cancel"
    ELSE
        PrintCentered 44, "[Up/Dn] move     [SPACE] pick up / drop (swap)     [ENTER] done     [ESC] cancel"
    END IF
    Present
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
    DIM kr AS STRING, fastroll AS INTEGER, j AS INTEGER, hpd AS INTEGER, hptr AS INTEGER
    IF _TRIM$(player_name) = "" THEN player_name = RandomHeroName$   ' a colourful default to start
    IF opt_oldschool THEN RollCharacterClassic pc: EXIT SUB          ' Dungeon! board game: you PICK a class, no rolled stats
    DICE3D_YOFF = 14                                ' drop the 3D dice tray below the stat sheet so the scores stay visible
    stay_auto = FALSE                               ' once [A] is pressed it stays on through every re-roll
    fastroll = FALSE                                ' [Shift-R] -- churn re-rolls with no dice animation at all
    DO
        auto = stay_auto
        usedpoint = FALSE
        IF fastroll THEN
            ' FAST RE-ROLL: fill all six straight off the RNG and show the finished sheet. Somebody
            ' re-rolling until they like the spread should not have to sit through six dice
            ' animations per attempt -- that is the whole request, so it skips the loop entirely.
            FOR i = 1 TO 6: sc(i) = RollAbilityFast%: NEXT i
        ELSE
        FOR i = 1 TO 6
            DrawCharGen pc, sc(), i - 1, 0             ' show sheet + the prompt to roll this ability
            IF NOT auto THEN                           ' the player presses a key to roll each stat...
                DO
                    _LIMIT 60: k = UCASE$(INKEY$): Present
                    IF k = "N" THEN player_name = RandomHeroName$: DrawCharGen pc, sc(), i - 1, 0: k = ""
                    IF k = "E" THEN RenameChampion: DrawCharGen pc, sc(), i - 1, 0: k = ""
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
            sc(i) = RollAbility                        ' per the Stat-Roll METHOD (RollAbility%)
        NEXT i
        END IF
        player_str = sc(1): player_int = sc(2): player_wis = sc(3)
        player_dex = sc(4): player_con = sc(5): player_cha = sc(6)
        ' hit points: three hit dice + 3x the CON modifier (a level-ish start), min 3
        IF NOT fastroll THEN
            DrawCharGen pc, sc(), 6, 0
            IF NOT auto THEN
                DO
                    _LIMIT 60: k = UCASE$(INKEY$): Present
                    IF k = "N" THEN player_name = RandomHeroName$: DrawCharGen pc, sc(), 6, 0: k = ""
                    IF k = "E" THEN RenameChampion: DrawCharGen pc, sc(), 6, 0: k = ""
                    IF k = CHR$(27) THEN DICE3D_YOFF = 0: EXIT SUB
                LOOP UNTIL k <> ""
            ELSE
                IF INKEY$ = CHR$(27) THEN DICE3D_YOFF = 0: EXIT SUB
            END IF
        END IF
        ' HIT POINTS follow the same re-roll rule as the abilities. They are three dice on the
        ' class hit die, rolled by the same character-generation method -- a player who chose
        ' "re-roll 1s" and then watched their HP land on three 1s would rightly ask what the
        ' setting was for. The floor is clamped against the hit die inside RollRerollLow%, so a
        ' d6 class is safe from a rule written with d6 abilities in mind.
        IF fastroll THEN
            hproll = 0
            FOR j = 1 TO 3
                hpd = RollDie(CLASSES(pc).hitdie)
                hptr = 0
                DO WHILE hpd <= RerollFloor% _ANDALSO RerollFloor% < CLASSES(pc).hitdie _ANDALSO hptr < RerollTries%
                    hpd = RollDie(CLASSES(pc).hitdie): hptr = hptr + 1
                LOOP
                hproll = hproll + hpd
            NEXT j
        ELSEIF RerollFloor% > 0 AND NOT opt_realdice THEN
            hproll = RollRerollLow%(3, CLASSES(pc).hitdie, RerollFloor%, "HIT POINTS -- re-roll " + RerollWord$)
        ELSE
            hproll = GameRoll(3, CLASSES(pc).hitdie, 0, "HIT POINTS")
        END IF
        player_maxhp = hproll + 3 * AbilMod(player_con)
        IF player_maxhp < 3 THEN player_maxhp = 3
        hp_start_amount = player_maxhp                 ' what the entrance will restore, for the whole run
        LuckRefill                                     ' CHA modifier = luck re-rolls for this run
    FlourishRefill                                 ' DEX modifier = flourishes for this run
        player_hp = player_maxhp
        DeriveFromStats pc                             ' to-hit / AC / damage from the ability scores
        DrawCharGen pc, sc(), 6, -1                    ' final sheet + reroll/name/keep prompt
        fastroll = FALSE                               ' each re-roll opts in again
        DO
            _LIMIT 60
            ' RAW key first, then the uppercased copy. [Shift-R] and [R] are the same letter to
            ' UCASE$, so telling them apart means reading what INKEY$ actually returned. (CapsLock
            ' therefore reads as Shift here -- an acceptable trade for one dev-comfort key.)
            kr = INKEY$: k = UCASE$(kr): Present
            IF kr = "R" THEN fastroll = -1             ' Shift-R: re-roll with no dice animation
            IF k = "N" THEN player_name = RandomHeroName$: DrawCharGen pc, sc(), 6, -1: k = ""
            IF k = "E" THEN RenameChampion: DrawCharGen pc, sc(), 6, -1: k = ""
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
        _LIMIT 60: k = UCASE$(INKEY$): Present
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
    ' few black frames here so it completes on black; the Present also drops autodisplay, so the
    ' freshly-drawn logo can't flash at full brightness for a frame before FadeInCurrent starts.
    _DEST CANVAS: CLS , BLACK
    FOR frames = 1 TO 15: Present: _LIMIT 60: NEXT
    ansi = _READFILE$(AnsiFile$("vermin-radioactive-logo.ans"))
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
        Present
    LOOP UNTIL k <> "" OR frames >= 150          ' auto-advance to the menu after ~5s idle
    FadeOut                                      ' fade to black before the menu
    RetireSound mus
    RetireSound splash
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

    logo = _READFILE$(AnsiFile$("dungeon-menu-logo.ans"))
    FOR i = 1 TO 4: lw(i) = _READFILE$(AnsiFile$("dungeon-menu-left-wall-" + _TRIM$(STR$(i)) + ".ans")): NEXT
    FOR i = 1 TO 4: rw(i) = _READFILE$(AnsiFile$("dungeon-menu-right-wall-" + _TRIM$(STR$(i)) + ".ans")): NEXT
    FOR i = 1 TO 6: bl(i) = _READFILE$(AnsiFile$("dungeon-menu-block-" + _TRIM$(STR$(i)) + ".ans")): NEXT

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
                    RetireSound music_handle: music_handle = 0
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
        Present
        IF firstframe THEN FadeInCurrent: firstframe = 0   ' fade the menu in on the first frame
    LOOP
    IF result = MENU_ENTER THEN BloodDrip ELSE FadeOut     ' blood-drip descent into the dungeon; plain fade otherwise

    RetireSound music_handle                    ' stop the menu theme; PlayGame starts the level track
    RetireSound music_fadeout                   ' and any half-finished crossfade tail
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


' Place a category header at the top of a group in column c (blank line before, except the
' first group in the column). Advances that column's pen row (prow -- "pen" is reserved).
SUB SetLayHdr (col AS INTEGER, txt AS STRING, prow() AS INTEGER)
    IF prow(col) > 2 THEN prow(col) = prow(col) + 1        ' one blank row between stacked groups
    SLH_N = SLH_N + 1
    SLH_COL(SLH_N) = col: SLH_ROW(SLH_N) = prow(col): SLH_TXT(SLH_N) = txt
    prow(col) = prow(col) + 1
END SUB

' Place option id at column c's current pen row; advance the pen. Also append to the
' reading-order list SORD (calls run col1 top-down, then col2, then col3) for up/down nav.
SUB SetLayRow (col AS INTEGER, id AS INTEGER, prow() AS INTEGER)
    ' Guard rather than scribble. An id past SETOPT_MAX used to run off the end of SL_COL/SL_ROW,
    ' and because the fatal handler RESUME NEXTs while a window is up, the symptom was not an
    ' error -- it was a settings row that quietly failed to appear.
    IF id < 1 OR id > SETOPT_MAX THEN EXIT SUB
    IF SORD_N >= SETOPT_MAX THEN EXIT SUB
    SL_COL(id) = col: SL_ROW(id) = prow(col)
    prow(col) = prow(col) + 1
    SORD_N = SORD_N + 1: SORD(SORD_N) = id
END SUB

' Build the columnar SETTINGS layout: assign every option id (1..49) to a column + screen
' row, grouped by category with a header before each group. The per-option label/value logic
' (the SELECT CASE i blocks) is unchanged -- this only decides WHERE each row draws + how the
' cursor moves. Rebuilt each time SETTINGS opens (cheap).
' The row the dice previews start on.
'
' From the bottom of columns 1 and 2 ONLY -- the two the previews sit under. Using the LONGEST
' column (3: RULES + DISPLAY & ART) pushed them to the floor of the screen and kept pushing as
' options were added, which is what "the dice are too far down" was.
FUNCTION DicePreviewRow% ()
    DIM b AS INTEGER
    b = SL_COLBOT(1)
    IF SL_COLBOT(2) > b THEN b = SL_COLBOT(2)
    DicePreviewRow% = b + 3
END FUNCTION

SUB BuildSetLayout
    DIM prow(1 TO NSCOL) AS INTEGER, col AS INTEGER
    SL_COLX(1) = 1: SL_COLX(2) = 45: SL_COLX(3) = 89
    FOR col = 1 TO NSCOL: prow(col) = 2: NEXT          ' title row 0, gap row 1, list from row 2
    SLH_N = 0: SORD_N = 0
    ' Column 1 -- SOUND
    SetLayHdr 1, "SOUND", prow()
    SetLayRow 1, 1, prow(): SetLayRow 1, 2, prow(): SetLayRow 1, 3, prow(): SetLayRow 1, 4, prow()
    SetLayRow 1, 5, prow(): SetLayRow 1, 6, prow(): SetLayRow 1, 48, prow()
    SetLayRow 1, 45, prow(): SetLayRow 1, 47, prow(): SetLayRow 1, 43, prow(): SetLayRow 1, 44, prow()
    SetLayRow 1, 53, prow()                          ' Audio Format -- the INHERITED order...
    SetLayRow 1, 64, prow(): SetLayRow 1, 65, prow(): SetLayRow 1, 66, prow()   ' ...and the per-category overrides
    ' Column 2 -- DICE, then MONSTER DICE
    SetLayHdr 2, "DICE", prow()
    SetLayRow 2, 7, prow(): SetLayRow 2, 30, prow(): SetLayRow 2, 10, prow(): SetLayRow 2, 11, prow()
    SetLayRow 2, 12, prow(): SetLayRow 2, 13, prow()
    SetLayRow 2, 38, prow(): SetLayRow 2, 39, prow()
    SetLayRow 2, 31, prow(): SetLayRow 2, 33, prow(): SetLayRow 2, 8, prow(): SetLayRow 2, 9, prow()
    SetLayRow 2, 36, prow()                          ' Action Gestures: a timing-bar mechanic, and
'                                                     column 3 ran into the 3D dice preview strip
    SetLayHdr 2, "MONSTER DICE", prow()
    SetLayRow 2, 26, prow(): SetLayRow 2, 27, prow(): SetLayRow 2, 28, prow(): SetLayRow 2, 29, prow(): SetLayRow 2, 32, prow()
    ' Column 3 -- RULES, then DISPLAY & ART, then Back
    SetLayHdr 3, "RULES", prow()
    SetLayRow 3, 14, prow(): SetLayRow 3, 52, prow(): SetLayRow 3, 15, prow(): SetLayRow 3, 16, prow()
    SetLayRow 3, 17, prow(): SetLayRow 3, 67, prow(): SetLayRow 3, 60, prow(): SetLayRow 3, 61, prow(): SetLayRow 3, 62, prow()
    SetLayRow 3, 34, prow(): SetLayRow 3, 25, prow(): SetLayRow 3, 24, prow(): SetLayRow 3, 22, prow()
    SetLayRow 3, 23, prow(): SetLayRow 3, 41, prow(): SetLayRow 3, 42, prow(): SetLayRow 3, 54, prow(): SetLayRow 3, 63, prow(): SetLayRow 3, 55, prow(): SetLayRow 3, 56, prow()
    SetLayHdr 3, "DISPLAY & ART", prow()
    SetLayRow 3, 18, prow(): SetLayRow 3, 19, prow(): SetLayRow 3, 20, prow(): SetLayRow 3, 35, prow()
    SetLayRow 3, 59, prow()                          ' Stats Overlay -- a DISPLAY choice, not a rule
    SetLayRow 3, 68, prow()                          ' Cut-scenes: pacing is a PLAYER choice, not a script property
    SetLayRow 3, 46, prow(): SetLayRow 3, 49, prow(): SetLayRow 3, 51, prow(): SetLayRow 3, 37, prow(): SetLayRow 3, 40, prow(): SetLayRow 3, 21, prow()
    prow(3) = prow(3) + 1
    SetLayRow 3, 50, prow()                         ' << Back at the foot of the last column
    SL_MAXROW = 0
    FOR col = 1 TO NSCOL
        SL_COLBOT(col) = prow(col)
        IF prow(col) > SL_MAXROW THEN SL_MAXROW = prow(col)
    NEXT col
END SUB

' Move option `cur` up (W / up-arrow) or down (S / down-arrow) through the reading-order
' list SORD (col1 top-down, then col2, then col3), wrapping at the ends. Left/right are NOT
' navigation -- they adjust the selected value (the universal slider convention).
FUNCTION SetOrdMove% (cur AS INTEGER, dir$)
    DIM i AS INTEGER, idx AS INTEGER
    idx = 1
    FOR i = 1 TO SORD_N
        IF SORD(i) = cur THEN idx = i: EXIT FOR
    NEXT
    IF dir$ = "W" THEN idx = idx - 1 ELSE idx = idx + 1
    IF idx < 1 THEN idx = SORD_N
    IF idx > SORD_N THEN idx = 1
    SetOrdMove% = SORD(idx)
END FUNCTION

' TAB (dir +1) / Shift-TAB (dir -1): jump to the next/prev COLUMN (wrapping), landing on the
' option nearest the current vertical position -- so you don't scroll a whole column to reach
' the next group. Returns the new option id.
FUNCTION SetColJump% (cur AS INTEGER, dir AS INTEGER)
    DIM i AS INTEGER, tcol AS INTEGER, best AS INTEGER, bestd AS INTEGER, crow AS INTEGER
    tcol = SL_COL(cur) + dir
    IF tcol < 1 THEN tcol = NSCOL
    IF tcol > NSCOL THEN tcol = 1
    best = cur: bestd = 9999: crow = SL_ROW(cur)
    FOR i = 1 TO SORD_N
        IF SL_COL(SORD(i)) = tcol THEN
            IF ABS(SL_ROW(SORD(i)) - crow) < bestd THEN bestd = ABS(SL_ROW(SORD(i)) - crow): best = SORD(i)
        END IF
    NEXT
    SetColJump% = best
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
        RetireSound music_handle
        RetireSound music_fadeout
        music_handle = 0: music_fadeout = 0: music_fading = 0
        music_curfile = ""                          ' but leave music_level intact so re-enabling knows the context
    END IF
END SUB

SUB RunSettings
    ' NSET now lives in game/GAME.BI beside SETOPT_MAX -- see the note there.
    DIM sel AS INTEGER, k AS STRING, i AS INTEGER, y AS INTEGER, vtxt AS STRING, lbl AS STRING
    DIM slider AS INTEGER, delta AS INTEGER
    DIM hh AS INTEGER, dsh AS INTEGER, cx0 AS INTEGER       ' columnar render scratch
    CONST SCOLW = 42                                        ' option-column width in cells
    sel = 1
    ScanAllPacks                                    ' refresh the sfx/music pack lists (packs added on disk show up)
    Build3DPreviews                                 ' render the 3D dice previews once (rebuilt on set change)
    BuildSetLayout                                  ' assign every option to its column + screen row (grouped)
    DO
        _LIMIT 60
        AudioTick                                   ' live music crossfade / toggle fade + narration fade
        k = NormKey$(UCASE$(INKEY$))
        IF k = "W" OR k = "S" THEN sel = SetOrdMove%(sel, k): Sfx "select"   ' up/down move (arrows too)
        IF k = CHR$(9) THEN sel = SetColJump%(sel, 1): Sfx "select"          ' TAB: jump to next column
        IF k = CHR$(0) + CHR$(15) THEN sel = SetColJump%(sel, -1): Sfx "select"   ' Shift-TAB: prev column
        IF k = CHR$(27) THEN SaveSettings: Free3DPreviews: EXIT SUB

        ' A/D (left/right arrows) adjust the selected slider/value -- the familiar convention
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
                CASE 61
                    opt_autodelay = opt_autodelay + delta
                    IF opt_autodelay < 1 THEN opt_autodelay = 3
                    IF opt_autodelay > 3 THEN opt_autodelay = 1
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
                CASE 17: CycleStatMethod delta: Sfx "select"
                CASE 67
                    opt_rerolltries = opt_rerolltries + delta
                    IF opt_rerolltries < 0 THEN opt_rerolltries = REROLL_TRIES_MAX
                    IF opt_rerolltries > REROLL_TRIES_MAX THEN opt_rerolltries = 0
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
                CASE 53
                    opt_audiopref = opt_audiopref + delta
                    IF opt_audiopref > AUDIOPREF_N THEN opt_audiopref = AUDIOPREF_AUTO
                    IF opt_audiopref < AUDIOPREF_AUTO THEN opt_audiopref = AUDIOPREF_N
                    ' SFX handles are already open, so re-resolve them now -- otherwise the
                    ' preference appears to do nothing until the next launch.
                    ReloadSfxPack
                    music_curfile = ""        ' force PlayLevelMusic to re-resolve the track
                CASE 68: CycleCutscenes delta
                CASE 45: CycleNarration delta
                CASE 46: CycleArtPack delta
                CASE 47
                    opt_narrfreq = opt_narrfreq + delta
                    IF opt_narrfreq < NARR_FLAVOR THEN opt_narrfreq = NARR_COMBAT
                    IF opt_narrfreq > NARR_COMBAT THEN opt_narrfreq = NARR_FLAVOR
                    Sfx "select"
                CASE 64: CycleCatFormat AUDCAT_MUSIC, delta: music_curfile = "": Sfx "select"
                CASE 65: CycleCatFormat AUDCAT_SFX, delta: ReloadSfxPack: Sfx "select"
                CASE 66: CycleCatFormat AUDCAT_NARR, delta: Sfx "select"
                CASE 63
                    opt_luckfuse = opt_luckfuse + delta
                    IF opt_luckfuse < 0 THEN opt_luckfuse = LUCKFUSE_MAX
                    IF opt_luckfuse > LUCKFUSE_MAX THEN opt_luckfuse = 0
                    Sfx "select"
                CASE 48: opt_duckamt = Clamp10(opt_duckamt + delta): Sfx "select"   ' music-under-voice ducking depth
                CASE 49: CycleAnsiPack delta                                        ' ANSI-art pack (board + masks + menu)
                CASE 51: CycleDataPack delta                                        ' DATA pack -- whole game (monsters/tuning/flavor); applies on restart
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
                CASE 59: opt_statsoverlay = NOT opt_statsoverlay
                CASE 60: opt_autocombat = NOT opt_autocombat
                CASE 62: opt_automove = NOT opt_automove
                CASE 61
                    opt_autodelay = opt_autodelay + 1
                    IF opt_autodelay > 3 THEN opt_autodelay = 1
                CASE 14: opt_oldschool = NOT opt_oldschool
                CASE 52: opt_tactical = NOT opt_tactical
                CASE 53
                    opt_audiopref = opt_audiopref + 1
                    IF opt_audiopref > AUDIOPREF_N THEN opt_audiopref = AUDIOPREF_AUTO
                    ReloadSfxPack
                    music_curfile = ""        ' force PlayLevelMusic to re-resolve the track
                CASE 15
                    opt_boardgame = NOT opt_boardgame
                    IF num_players > 1 THEN opt_boardgame = TRUE   ' multiplayer requires it
                CASE 16
                    num_players = num_players + 1: IF num_players > 4 THEN num_players = 1
                    IF num_players > 1 THEN opt_boardgame = TRUE ELSE opt_boardgame = FALSE
                CASE 17: CycleStatMethod 1
                CASE 67
                    opt_rerolltries = opt_rerolltries + 1
                    IF opt_rerolltries > REROLL_TRIES_MAX THEN opt_rerolltries = 0
                CASE 18
                    opt_fullscreen = NOT opt_fullscreen
                    ApplyDisplay
                CASE 19
                    opt_smoothamt = opt_smoothamt + delta
                    IF opt_smoothamt < 0 THEN opt_smoothamt = 3
                    IF opt_smoothamt > 3 THEN opt_smoothamt = 0
                    ApplyDisplay
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
                    ' the ANSI sprite cache is keyed by PATH, and switching style changes which
                    ' path every subject resolves to -- keeping it would show the old form
                    FreeAnsiSprites
                CASE 54: opt_luck = NOT opt_luck
                CASE 63
                    opt_luckfuse = opt_luckfuse + 1
                    IF opt_luckfuse > LUCKFUSE_MAX THEN opt_luckfuse = 0
                CASE 64: CycleCatFormat AUDCAT_MUSIC, 1: music_curfile = ""   ' re-resolve the current track
                CASE 65: CycleCatFormat AUDCAT_SFX, 1: ReloadSfxPack
                CASE 66: CycleCatFormat AUDCAT_NARR, 1
                CASE 55: opt_startheal = NOT opt_startheal
                CASE 56: opt_rest = NOT opt_rest
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
                CASE 68: CycleCutscenes 1
                CASE 45: CycleNarration 1
                CASE 46: CycleArtPack 1
                CASE 47
                    opt_narrfreq = opt_narrfreq + 1: IF opt_narrfreq > NARR_COMBAT THEN opt_narrfreq = NARR_FLAVOR
                CASE 48
                    opt_duckamt = opt_duckamt + 1: IF opt_duckamt > 10 THEN opt_duckamt = 0
                CASE 49: CycleAnsiPack 1
                CASE 51: CycleDataPack 1
                CASE 50: SaveSettings: Free3DPreviews: EXIT SUB
            END SELECT
            Sfx "select"
        END IF

        _DEST CANVAS: CLS , BLACK
        COLOR YELLOWU, BLACK: PrintCentered 0, "-=  S E T T I N G S  =-"
        FOR hh = 1 TO SLH_N                    ' category headers atop each group
            COLOR Thm~&("hud.warn", _RGB32(&HFF, &HC0, &H40)), BLACK
            dsh = 39 - LEN(SLH_TXT(hh)) - 3: IF dsh < 0 THEN dsh = 0
            _PRINTSTRING (SL_COLX(SLH_COL(hh)) * CW, SLH_ROW(hh) * CH), "- " + SLH_TXT(hh) + " " + STRING$(dsh, "-")
        NEXT hh
        FOR i = 1 TO NSET
            ' An id inside NSET that BuildSetLayout never PLACED has SL_COL = 0, and SL_COLX is
            ' dimensioned 1..NSCOL -- so drawing it indexes SL_COLX(0) and the whole screen dies
            ' with "Subscript out of range". That happens the moment an option is retired without
            ' also lowering NSET, which is exactly what removing Roll Style and Box Shake did.
            ' Skipping unplaced ids makes NSET a safe upper bound rather than an exact count.
            IF SL_COL(i) < 1 THEN GOTO nextSetRow
            y = SL_ROW(i)                      ' columnar grouped layout -- BuildSetLayout placed each option
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
                CASE 62
                    lbl = "Auto-Move"
                    IF opt_automove THEN vtxt = "ON ([Z] to walk)" ELSE vtxt = "off"
                CASE 60
                    lbl = "Auto-Combat"
                    IF opt_realdice THEN
                        vtxt = "n/a (Real Dice on)"
                    ELSEIF opt_autocombat THEN
                        vtxt = "ON (game plays)"
                    ELSE
                        vtxt = "off"
                    END IF
                CASE 61
                    lbl = "  Proceed Delay": slider = TRUE
                    vtxt = _TRIM$(STR$(opt_autodelay)) + " sec"
                CASE 59
                    lbl = "Stats Overlay"
                    IF opt_statsoverlay THEN vtxt = "ON ([TAB] in game)" ELSE vtxt = "off ([TAB] shows it)"
                CASE 14
                    lbl = "Oldschool"
                    IF opt_oldschool THEN vtxt = "Dungeon! 2d6" ELSE vtxt = "D&D d20/HP"
                CASE 53
                    lbl = "Audio Format"
                    vtxt = AudioPrefName$(opt_audiopref)
                CASE 52
                    lbl = "Tactical Screen"
                    IF opt_tactical THEN vtxt = "ON (1-vs-4)" ELSE vtxt = "off"
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
                    vtxt = StatMethodName$
                CASE 18: lbl = "Full Screen": vtxt = OnOff$(opt_fullscreen)
                CASE 19
                    ' Named for what it ACTUALLY does, which differs by display mode:
                    '   windowed   -- fit-to-window vs integer scale. BOTH are crisp: QB64's
                    '                 _PUTIMAGE never interpolates, so a software blit is always
                    '                 nearest-neighbour no matter what ratio it scales by.
                    '   fullscreen -- also selects _FULLSCREEN _SMOOTH, which IS real GPU
                    '                 filtering, because that scaling is done by the driver.
                    ' It was labelled "Pixel Smoothing / smooth" for both, which promised a
                    ' filtered window and delivered nearest-neighbour at a different size.
                    lbl = "Smoothing"
                    SELECT CASE opt_smoothamt
                        CASE 0: vtxt = "off (crisp, integer)"
                        CASE 1: vtxt = "light"
                        CASE 2: vtxt = "medium"
                        CASE ELSE: vtxt = "full (softest)"
                    END SELECT
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
                        CASE ARTSTYLE_PIXEL: vtxt = "Pixel Art only"
                        CASE ARTSTYLE_HYBRID: vtxt = "Hybrid (pixel, else ANSI)"
                        CASE ELSE: vtxt = "ANSI only"
                    END SELECT
                CASE 54
                    lbl = "Luck Re-rolls"
                    IF opt_luck THEN vtxt = "on (CHA buys re-rolls)" ELSE vtxt = "off"
                CASE 67
                    lbl = "  Re-roll Tries"
                    vtxt = RerollTriesName$
                CASE 64
                    lbl = "  Music Format"
                    vtxt = FmtName$(opt_fmt_music)
                CASE 65
                    lbl = "  SFX Format"
                    vtxt = FmtName$(opt_fmt_sfx)
                CASE 66
                    lbl = "  Voice Format"
                    vtxt = FmtName$(opt_fmt_narr)
                CASE 63
                    lbl = "Luck Prompt Time"
                    IF opt_luckfuse <= 0 THEN
                        vtxt = "off (waits for you)"
                    ELSE
                        vtxt = _TRIM$(STR$(opt_luckfuse)) + "s fuse"
                    END IF
                CASE 55
                    lbl = "Rest at Entrance"
                    IF opt_startheal THEN vtxt = "on (heals + rests)" ELSE vtxt = "off"
                CASE 56
                    lbl = "[R]est in Dungeon"
                    IF opt_rest THEN vtxt = "on (1 HP, risk company)" ELSE vtxt = "off"
                CASE 54
                    lbl = "Luck Re-rolls"
                    IF opt_luck THEN vtxt = "on (CHA buys re-rolls)" ELSE vtxt = "off"
                CASE 63
                    lbl = "Luck Prompt Time"
                    IF opt_luckfuse <= 0 THEN
                        vtxt = "off (waits for you)"
                    ELSE
                        vtxt = _TRIM$(STR$(opt_luckfuse)) + "s fuse"
                    END IF
                CASE 55
                    lbl = "Rest at Entrance"
                    IF opt_startheal THEN vtxt = "on (heals + rests)" ELSE vtxt = "off"
                CASE 56
                    lbl = "[R]est in Dungeon"
                    IF opt_rest THEN vtxt = "on (1 HP, risk company)" ELSE vtxt = "off"
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
                    ' (pack #/count counter dropped -- long pack names need the whole column width)
                CASE 44
                    lbl = "Music Pack": slider = TRUE
                    vtxt = PackLabel$(opt_musicpack)
                    ' (counter dropped -- see SFX Pack)
                CASE 68
                    lbl = "Cut-scenes": slider = TRUE
                    vtxt = CutsceneModeLabel$
                CASE 45
                    lbl = "Narration": slider = TRUE
                    vtxt = NarrationLabel$
                    ' (counter dropped -- see SFX Pack)
                CASE 46
                    lbl = "Art Pack": slider = TRUE
                    vtxt = PackLabel$(opt_artpack)
                    ' (counter dropped -- see SFX Pack)
                CASE 47
                    lbl = "  Narration Freq": slider = TRUE
                    vtxt = NarrFreqLabel$
                CASE 48
                    lbl = "  Music Ducking": slider = TRUE
                    IF opt_duckamt <= 0 THEN vtxt = "off" ELSE vtxt = _TRIM$(STR$(opt_duckamt)) + " / 10"
                CASE 49
                    lbl = "ANSI Art Pack": slider = TRUE
                    vtxt = PackLabel$(opt_ansipack)
                CASE 51
                    lbl = "Data Pack": slider = TRUE
                    vtxt = PackLabel$(opt_datapack)
                CASE ELSE: lbl = "<< Back": vtxt = ""
            END SELECT
            cx0 = SL_COLX(SL_COL(i))
            IF i = sel THEN LINE (cx0 * CW, y * CH)-((cx0 + SCOLW) * CW - 1, (y + 1) * CH - 1), REDU, BF   ' highlight bar
            IF i = sel THEN COLOR WHITE ELSE IF slider THEN COLOR CYANU ELSE COLOR GREY
            _PRINTMODE _KEEPBACKGROUND                     ' text over the bar; bg stays whatever's under it
            _PRINTSTRING ((cx0 + 1) * CW, y * CH), lbl     ' label left
            IF LEN(vtxt) > 0 THEN _PRINTSTRING ((cx0 + SCOLW - LEN(vtxt)) * CW, y * CH), vtxt   ' value right-aligned (Back has none)
            _PRINTMODE _FILLBACKGROUND
            nextSetRow:
        NEXT i
        ' live dice previews in the free strip BELOW the columns (repositioned to row 31)
        IF opt_dice3d THEN                                      ' 3D dice: live hardware previews
            ' Captions only here -- they are CANVAS. The dice themselves are GL and have to go
            ' on AFTER the canvas reaches the screen; see below.
            DrawDice3DPreviewLabel 52, "your 3D dice", DicePreviewRow%
            DrawDice3DPreviewLabel 80, "monster 3D dice", DicePreviewRow%
        ELSE                                                    ' font dice: the live 2x3 sample grid
            DrawDicePreview 4, " your dice", DicePreviewRow%
            PushMonsterDice: DrawDicePreview 46, " monster dice", DicePreviewRow%: PopMonsterDice
        END IF
        COLOR CYANU, BLACK: PrintCentered 50, "up/down move    left/right adjust    TAB/shift-TAB column    ENTER cycle    ESC back"
        IF opt_dice3d THEN
            ' Canvas down, dice over it, one flip. Calling plain Present here would blit the
            ' canvas straight over the GL dice -- which is exactly why they were invisible.
            PresentNoFlip
            DrawDice3DPreviewDie 52, DicePreviewRow%, PREV3D_P, DSET3D(dice3d_set_index%(20))
            DrawDice3DPreviewDie 80, DicePreviewRow%, PREV3D_M, MSET3D(dice3d_set_index%(20))
            _DISPLAY
        ELSE
            Present
        END IF
        IF settingsshot_on THEN
            ' Two shots: the CANVAS (what the game composed) and SCREEN 0 (what the player
            ' actually sees after Present scales it into the window). They differ the moment
            ' the window is not an exact multiple of the canvas -- which is the whole bug
            ' windowed resize had, so both are worth capturing.
            _SAVEIMAGE "settings-shot.png", CANVAS
            Present
            _SAVEIMAGE "settings-window.png", 0
            SettingsLayoutCheck                                     ' every option id actually placed?
            SYSTEM                                                  ' exits BEFORE any SaveSettings
        END IF
    LOOP
END SUB


' Live sample of the player's chosen dice, so the colour / finish / d6-style
' choices can be judged by eye. Drawn as a 2x3 grid on the RIGHT of the SETTINGS
' screen (the list is centred, so the right third is free) -- decoupled from the
' list length, which now runs too tall for a bottom row.
' Draw the live 2x3 sample grid using the CURRENT dice config, at cell-column
' `gxc`, headed by `lbl`. Called twice from SETTINGS: player dice (right) and --
' with the monster config swapped in -- monster dice (left).
SUB DrawDicePreview (gxc AS INTEGER, lbl AS STRING, growy AS INTEGER)
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
    gx = gxc * CW: gy = growy * CH                  ' strip below the columnar list (see SL_MAXROW)
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


' (ApplyDisplay moved to engine/UI.bas -- it only touches _FULLSCREEN + smoothing,
'  which is engine display config, and opt_fullscreen/opt_smooth live in ENGINE.BI.)


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
    ' 3-space gaps, not 5: at 5 this line is 70 columns and the span beside the class portrait
    ' is 67, so it wrapped (or, before that, printed straight over the art). Three still reads
    ' as three groups. PrintWrappedIn% remains the safety net if a value ever gets wider.
    s = s + "   Dmg " + ModStr$(player_dmgbonus) + " " + statn
    s = s + "   AC " + _TRIM$(STR$(player_ac)) + " = " + _TRIM$(STR$(baseac)) + " class " + ModStr$(dexmod) + " DEX"
    CombatDerivation$ = s
END FUNCTION


SUB ShowCharSheet
    ShowCharSheetPaint
    Present
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB


' Paint the sheet onto CANVAS and return -- no input, no board repaint. Split out so
' `dungeon.run charsheet` can render the REAL sheet to a PNG (see game/DEBUG.bas), which is
' the only way to check this layout without a playthrough: the failure mode is text overflowing
' the panel, and that only shows up with a fully-kitted hero.
SUB ShowCharSheetPaint
    DIM i AS INTEGER, y AS INTEGER, col AS INTEGER, nshow AS INTEGER, inv AS STRING, ln AS STRING
    DIM who AS STRING, effac AS INTEGER, efth AS INTEGER
    ' The sheet is a PANEL, but every line was centred on the whole 132-column SCREEN. That is
    ' invisible while the text is short and catastrophic once it isn't: a full MAGIC: line ran
    ' off both edges of the panel, and the header lines slid under the class portrait. tx1/tx2
    ' are the text column span, narrowed to the portrait's left edge for the rows it occupies.
    DIM tx1 AS INTEGER, tx2 AS INTEGER, hx2 AS INTEGER, portrait AS INTEGER, drow AS INTEGER
    DIM px1 AS INTEGER, py1 AS INTEGER, px2 AS INTEGER, py2 AS INTEGER
    effac = PlayerAC%                                                ' AC + worn armor/shield (STR-scaled; see GearAC%)
    efth = player_tohit: IF item_bow THEN efth = efth + 2   ' to-hit + Magic Bow
    _DEST CANVAS
    ' Framed by growing OUTWARD, like every other retrofitted panel: the sheet's whole body is
    ' laid out against these columns (tx1/tx2, the portrait rect, every row) and must not move.
    DIM cfx AS INTEGER, cfy AS INTEGER, cfw AS INTEGER, cfh AS INTEGER, csframed AS INTEGER
    DIM cfi AS INTEGER
    cfi = FrameIdx%("charsheet")
    IF cfi > 0 THEN
        cfx = 22 + 1 - UIFRAME_TW(cfi): cfy = 3 + 1 - UIFRAME_TH(cfi)
        cfw = (110 - 22) - 2 + 2 * UIFRAME_TW(cfi): cfh = (48 - 3) - 2 + 2 * UIFRAME_TH(cfi)
        IF cfx >= 0 AND cfy >= 0 AND cfx + cfw <= SW AND cfy + cfh <= SH THEN
            csframed = FrameBox%("charsheet", cfx, cfy, cfw, cfh)
        END IF
    END IF
    IF NOT csframed THEN
        LINE (22 * CW, 3 * CH)-(110 * CW, 48 * CH), BOXBG, BF
        LINE (22 * CW, 3 * CH)-(110 * CW, 48 * CH), REDU, B
    END IF
    IF csframed THEN _PRINTMODE _KEEPBACKGROUND   ' text sits ON the art, never stamps over it
    tx1 = 23: tx2 = 109                                              ' inside the panel border
    px1 = 92: py1 = 5: px2 = 108: py2 = 21                           ' the portrait frame, in cells
    ' class portrait, top-right of the sheet -- in WHICHEVER form opt_artstyle selects.
    ' ArtFile$ resolves .png or .ans and returns "" if that style has none, so no guard here.
    portrait = FALSE
    IF TRUE THEN
        DIM csp AS STRING, ddrew AS INTEGER
        csp = ClassSprite$(player_class)
        IF LEN(csp) > 0 THEN
            IF _FILEEXISTS(csp) THEN
                LINE (px1 * CW - 3, py1 * CH - 3)-(px2 * CW + 3, py2 * CH + 3), Thm~&("popup.shadow", _RGB32(&H10, &H08, &H10)), BF
                LINE (px1 * CW - 3, py1 * CH - 3)-(px2 * CW + 3, py2 * CH + 3), REDU, B
                ddrew = DrawSpriteFit%(csp, px1 * CW, py1 * CH, (px2 - px1) * CW, (py2 - py1) * CH)
                portrait = TRUE
            END IF
        END IF
    END IF
    ' Header rows (4..12) sit beside the portrait when there is one, so centre them over the
    ' free span only. Everything below py2 gets the full panel width back.
    hx2 = tx2
    IF portrait THEN hx2 = px1 - 2
    who = _TRIM$(player_name) + " the " + class_name
    IF _TRIM$(player_name) = "" THEN who = class_name
    COLOR YELLOWU, BOXBG: PrintCenteredIn 4, tx1, tx2, "-=  C H A R A C T E R  =-"
    DIM chline AS STRING
    chline = "Champion:  " + who
    IF NOT opt_oldschool THEN chline = chline + "        Level " + _TRIM$(STR$(char_level)) + "    XP " + _TRIM$(STR$(char_xp))
    ' Every header row goes through a running CURSOR, and any row that can grow goes through
    ' PrintWrappedIn% rather than being pinned to a fixed row. Two of these are player-sized and
    ' will not fit beside the portrait at their longest: the Champion line (a 28-character name
    ' plus level and XP) and the stat derivation (70 columns for a plain level-1 HERO against
    ' the 67 available). Pinned rows meant one of them had to lose -- either printing over the
    ' class art, or being cut off. Wrapping costs a row and loses nothing.
    COLOR WHITE, BOXBG: drow = PrintWrappedIn%(6, tx1, hx2, 2, chline)
    IF NOT opt_oldschool THEN
        COLOR CYANU, BOXBG
        drow = PrintWrappedIn%(drow + 1, tx1, hx2, 2, "STR " + _TRIM$(STR$(player_str)) + "  INT " + _TRIM$(STR$(player_int)) + "  WIS " + _TRIM$(STR$(player_wis)) + "  DEX " + _TRIM$(STR$(player_dex)) + "  CON " + _TRIM$(STR$(player_con)) + "  CHA " + _TRIM$(STR$(player_cha)))
        COLOR GREENU, BOXBG
        drow = PrintWrappedIn%(drow + 1, tx1, hx2, 2, "HP " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + "    AC " + _TRIM$(STR$(effac)) + "    To-Hit " + ModStr$(efth) + "    Dmg 1d" + _TRIM$(STR$(player_dmgdie)) + " " + ModStr$(player_dmgbonus + item_sword))
        COLOR GREY, BOXBG
        drow = PrintWrappedIn%(drow + 1, tx1, hx2, 2, CombatDerivation$(player_class))
    ELSE
        COLOR GREENU, BOXBG
        drow = PrintWrappedIn%(drow + 2, tx1, hx2, 2, ClassSpecial$(player_class))        ' Dungeon!: class + its edge -- no stats, HP, or AC
    END IF
    ' wealth line -- sits under however many rows the derivation needed
    COLOR YELLOWU, BOXBG
    ln = "GOLD  " + _TRIM$(STR$(gold)) + " / " + _TRIM$(STR$(target_gold))
    IF has_key THEN ln = ln + "        LEVEL KEY: HELD" ELSE ln = ln + "        LEVEL KEY: on the " + Ordinal$(key_level) + " level"
    PrintCenteredIn drow + 1, tx1, hx2, ln
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
    ' A fully kitted hero's MAGIC line is far wider than the panel, so WRAP it into the rows
    ' beside the portrait (12..20 while one is drawn, 12..13 otherwise) instead of letting one
    ' long centred line run off both edges of the sheet and across the art.
    DIM mlines AS STRING, mrows AS INTEGER, mp AS INTEGER, mnl AS INTEGER, mrow AS INTEGER
    DIM mtop AS INTEGER
    mtop = drow + 3                                 ' one blank row under the wealth line
    mrows = 2: IF portrait THEN mrows = py2 - mtop  ' rows mtop..(portrait bottom)
    IF mrows < 1 THEN mrows = 1
    COLOR WHITE, BOXBG
    _PRINTSTRING (tx1 * CW, mtop * CH), "MAGIC:"
    mlines = WrapLines$(_TRIM$(inv), hx2 - tx1 - 8, mrows)
    mrow = mtop: mp = 1
    DO WHILE mp <= LEN(mlines)
        mnl = INSTR(mp, mlines, CHR$(10))
        IF mnl = 0 THEN mnl = LEN(mlines) + 1
        _PRINTSTRING ((tx1 + 8) * CW, mrow * CH), MID$(mlines, mp, mnl - mp)
        mp = mnl + 1: mrow = mrow + 1
    LOOP
    ' The treasures start BELOW the portrait, so their two columns can use the full panel.
    DIM ty AS INTEGER
    ty = 14: IF portrait THEN ty = py2 + 1
    COLOR REDU, BOXBG: PrintCenteredIn ty, tx1, tx2, "-=  T R E A S U R E S   C L A I M E D  ( " + _TRIM$(STR$(LOOT_N(cur_player))) + " )  =-"
    COLOR WHITE, BOXBG
    IF LOOT_N(cur_player) = 0 THEN
        COLOR GREY, BOXBG: PrintCenteredIn ty + 4, tx1, tx2, "(none yet -- slay a monster to claim its hoard)"
    ELSE
        ' Rows are whatever fits between the heading and the '[ press any key ]' line -- the old
        ' fixed 30 could overrun the panel once the list started lower down the sheet.
        DIM rowsfit AS INTEGER
        rowsfit = 45 - (ty + 2): IF rowsfit < 1 THEN rowsfit = 1
        nshow = LOOT_N(cur_player)
        IF nshow > rowsfit * 2 THEN nshow = rowsfit * 2      ' two columns
        FOR i = 1 TO nshow
            IF (i AND 1) THEN col = 27 ELSE col = 68
            y = ty + 2 + (i - 1) \ 2
            ln = PadR$(_TRIM$(LOOT_NAME(cur_player, i)), 18) + RIGHT$("      " + _TRIM$(STR$(LOOT_GOLD(cur_player, i))), 6) + "g"
            _PRINTSTRING (col * CW, y * CH), ln
        NEXT i
        IF LOOT_N(cur_player) > nshow THEN
            COLOR GREY, BOXBG: _PRINTSTRING (27 * CW, 45 * CH), "...and " + _TRIM$(STR$(LOOT_N(cur_player) - nshow)) + " more"
        END IF
    END IF
    COLOR YELLOWU, BOXBG: PrintCenteredIn 46, tx1, tx2, "[ press any key ]"
    _PRINTMODE _FILLBACKGROUND                   ' paired with the KEEPBACKGROUND above
END SUB


' [V] Crystal Ball: scry every level's guardian and the treasure it hides.

SUB ScryView
    DIM i AS INTEGER, y AS INTEGER, mons AS STRING, tre AS STRING
    IF NOT item_crystal THEN
        Banner "You have no way to scry the dungeon.", "Find the CRYSTAL BALL first.   [ press any key ]"
        WaitKey
        cursor_erase: cursor_draw: DrawHUD: Present
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
    Present
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB


' [?] Controls: the single source of truth for key bindings, rendered as a table.
SUB ShowKeys
    DIM ky(1 TO 20) AS STRING, ds(1 TO 20) AS STRING, n AS INTEGER, i AS INTEGER, y AS INTEGER
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
    ky(16) = "TAB": ds(16) = "Run stats overlay (SETTINGS: Stats Overlay)"
    ky(17) = "R": ds(17) = "Rest: +1 HP, but something may find you"
    ky(18) = "L": ds(18) = "Locate me -- flashes a ring around you"
    ky(19) = "Z": ds(19) = "Auto-move (SETTINGS: Auto-Move); any key stops"
    n = 19
    _DEST CANVAS
    LINE (22 * CW, 7 * CH)-(110 * CW, 46 * CH), BOXBG, BF
    LINE (22 * CW, 7 * CH)-(110 * CW, 46 * CH), CYANU, B
    COLOR YELLOWU, BOXBG: PrintCentered 9, "-=  C O N T R O L S  =-"
    ' Single-row spacing: at 19 bindings the old 2-row layout ran to row 49 and the box ends
    ' at 46, so the last three would have been drawn straight through the frame.
    FOR i = 1 TO n
        y = 12 + (i - 1)
        COLOR GREENU, BOXBG: _PRINTSTRING (30 * CW, y * CH), PadR$(ky(i), 16)
        COLOR WHITE, BOXBG: _PRINTSTRING (48 * CW, y * CH), ds(i)
    NEXT i
    COLOR YELLOWU, BOXBG: PrintCentered 44, "[ press any key ]"
    Present
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: Present
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
        IF _DIREXISTS("gameplay-data-saves/dungeon-lords-maps") = 0 THEN MKDIR "gameplay-data-saves/dungeon-lords-maps"   ' ensure the subdir exists before saving
        _SAVEIMAGE LordsMapPath$(_TRIM$(STR$(mapid))), CANVAS
        nm = EnterName$                         ' victory + name entry
        player_name = nm
        SaveLord nm, class_name, gold, el, mapid ' enshrine in the Legendary Lords
        _DEST CANVAS: _FONT CH: CLS , BLACK
        EndScreenArt "you-win"                  ' banner art behind the text, if the pack has it
        COLOR GREENU, BLACK: PrintCentered 20, Say$("win.title")
        COLOR WHITE, BLACK: PrintCentered 23, nm + " the " + class_name + " escapes with " + _TRIM$(STR$(gold)) + " gold!"
        COLOR CYANU, BLACK: PrintCentered 25, Say$("win.subtitle")
    ELSE
        Sfx "lose"
        PlayCue "lose", TRUE                     ' defeat music (if assets/music/lose.* exists)
        Narrate "lose.title"                    ' spoken line runs UNDER the animation, not after it
        DeathScreen                             ' the animated epitaph: stone, carving, weapon, the pile
        WaitKey
        FadeOut
        NarrateStop
        music_cue_active = FALSE: StopLevelMusic
        ShowGameSummary                         ' "show stats from main screen" -- the same 24 rows
        EXIT SUB
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
    IF curse_turns > 0 THEN s = s + " {CRS" + _TRIM$(STR$(curse_turns)) + "}"   ' cursed: -1 hit/damage
    IF flourish_max > 0 THEN s = s + " {FLR" + _TRIM$(STR$(flourish_left)) + "}"   ' DEX flourishes left
    IF fire_turns > 0 THEN s = s + " {FIRE" + _TRIM$(STR$(fire_turns)) + "}"
    IF frost_turns > 0 THEN s = s + " {FRZ" + _TRIM$(STR$(frost_turns)) + "}"
    IF siren_turns > 0 THEN s = s + " {SIREN" + _TRIM$(STR$(siren_turns)) + "}"
    StatusTag$ = s
END FUNCTION


SUB DrawHUD
    DIM sec AS INTEGER, lbl AS STRING, hud AS STRING
    IF NOT hud_live THEN EXIT SUB                  ' no board on screen -> no HUD to draw (see hud_live)
    _DEST CANVAS
    DIM keytag AS STRING
    sec = PlayerLevel%
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
            LINE (bx1 * CW, 2 * CH)-(bx2 * CW, 5 * CH), Thm~&("rollprompt.bg.bright", _RGB32(&H35, &H22, &H00)), BF
            LINE (bx1 * CW, 2 * CH)-(bx2 * CW, 5 * CH), YELLOWU, B
            COLOR YELLOWU, Thm~&("rollprompt.bg.bright", _RGB32(&H35, &H22, &H00))
        ELSE
            LINE (bx1 * CW, 2 * CH)-(bx2 * CW, 5 * CH), Thm~&("rollprompt.bg.dim", _RGB32(&H22, &H16, &H00)), BF
            LINE (bx1 * CW, 2 * CH)-(bx2 * CW, 5 * CH), Thm~&("rollprompt.edge", _RGB32(&HAA, &H88, &H00)), B
            COLOR Thm~&("rollprompt.fg", _RGB32(&HDD, &HBB, &H33)), Thm~&("rollprompt.bg.dim", _RGB32(&H22, &H16, &H00))
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
    ' In combat the panel draws its own near-death vignette (+ Present); on the board
    ' there's no panel, so draw the wounds overlay here. (Avoids a double-darken.)
    IF combat_active THEN DrawCombatPanel combat_rm, combat_mon, combat_lead   ' wounds now drawn in cursor_erase, under everything
    ' The TAB scorecard goes on LAST so nothing paints over it -- and it is drawn here rather
    ' than in the play loop because every repaint in the game ends with a DrawHUD, so this is
    ' the one place that cannot be forgotten.
    DrawStatsOverlay
END SUB





' ============================================================================
'  LEVEL-UP: spend one point on an ability score (cap 18).
'
'  This is the moment the ability scores stop being a roll you got stuck with, so it is a
'  CHOICE, not an automatic bump -- the player picks where the character is growing.
'
'  Per the design call: the combat numbers re-derive IMMEDIATELY, except CON. A CON bump
'  improves every FUTURE level-up hit-die roll but does not retroactively grant max HP for
'  levels already gained -- otherwise one late point would pay out a lump of HP for a whole
'  career. DeriveFromStats does exactly the right thing here by only reading STR/INT/DEX.
'
'  When every score is already 18 there is nothing to buy, so the point converts: +1d4 max HP,
'  or a life back if the run allows more than one death and one has been spent.
' ============================================================================
SUB LevelUpStatPoint
    DIM sel AS INTEGER, i AS INTEGER, k AS STRING, y AS INTEGER, v AS INTEGER
    DIM anyroom AS INTEGER, gain AS INTEGER, canlife AS INTEGER
    IF opt_oldschool THEN EXIT SUB               ' Dungeon! has no ability scores to spend on
    FOR i = 1 TO 6
        IF StatValue%(i) < 18 THEN anyroom = -1
    NEXT i
    IF NOT anyroom THEN
        canlife = 0
        IF opt_maxdeaths > 1 THEN
            IF deaths(cur_player) > 0 THEN canlife = -1
        END IF
        LevelUpMaxedReward canlife
        EXIT SUB
    END IF
    sel = 1
    DO WHILE StatValue%(sel) >= 18: sel = sel + 1: IF sel > 6 THEN sel = 1
    LOOP
    DO
        LevelUpStatPaint sel
        Present
        k = ""
        DO
            k = NormKey$(UCASE$(INKEY$))
            IF k <> "" THEN EXIT DO
            _LIMIT 60
        LOOP
        ' NormKey$ folds the arrows into WASD -- it does NOT return "UP"/"DOWN". Matching those
        ' meant neither arm could ever fire, so the level-up picker took ENTER but would not
        ' MOVE: whatever stat it opened on was the only one you could spend the point in.
        SELECT CASE k
            CASE "W", "UP"
                DO
                    sel = sel - 1: IF sel < 1 THEN sel = 6
                LOOP WHILE StatValue%(sel) >= 18
            CASE "S", "DOWN"
                DO
                    sel = sel + 1: IF sel > 6 THEN sel = 1
                LOOP WHILE StatValue%(sel) >= 18
            CASE CHR$(13), " "
                SetStatValue sel, StatValue%(sel) + 1
                DeriveFromStats player_class     ' to-hit / damage / AC now; HP is NOT backfilled
                Sfx "levelup"
                Banner _TRIM$(StatName$(sel)) + " rises to " + _TRIM$(STR$(StatValue%(sel))) + "!", StatGainLine$(sel) + "   [ press any key ]"
                WaitKey
                LogEvent _TRIM$(player_name) + " grew: " + _TRIM$(StatName$(sel)) + " " + _TRIM$(STR$(StatValue%(sel)))
                EXIT SUB
        END SELECT
    LOOP
END SUB

' Nothing left to raise -- the point becomes HP, or a life back.
SUB LevelUpMaxedReward (canlife AS INTEGER)
    DIM gain AS INTEGER, k AS STRING
    IF canlife THEN
        _DEST CANVAS
        LINE (34 * CW, 18 * CH)-(98 * CW, 30 * CH), BOXBG, BF
        LINE (34 * CW, 18 * CH)-(98 * CW, 30 * CH), YELLOWU, B
        COLOR YELLOWU, BOXBG: PrintCentered 20, "-=  NOTHING LEFT TO LEARN  =-"
        COLOR GREY, BOXBG: PrintCentered 22, "Every ability stands at 18. Take instead:"
        COLOR GREENU, BOXBG: PrintCentered 25, "[H]  +1d4 maximum HP"
        COLOR CYANU, BOXBG: PrintCentered 27, "[L]  a LIFE back (one death forgiven)"
        Present
        DO
            k = UCASE$(INKEY$)
            IF k = "H" OR k = "L" THEN EXIT DO
            _LIMIT 60
        LOOP
        IF k = "L" THEN
            deaths(cur_player) = deaths(cur_player) - 1
            IF deaths(cur_player) < 0 THEN deaths(cur_player) = 0
            Sfx "levelup"
            Banner "A death is forgiven.", "The dungeon loosens its grip -- you have " + _TRIM$(STR$(opt_maxdeaths - deaths(cur_player))) + " life/lives left.   [ press any key ]"
            WaitKey
            LogEvent _TRIM$(player_name) + " bought back a life at level " + _TRIM$(STR$(char_level))
            EXIT SUB
        END IF
    END IF
    gain = RollDie(4)
    player_maxhp = player_maxhp + gain
    player_hp = player_maxhp
    Sfx "levelup"
    Banner "Every ability stands at 18.", "There is nothing left to raise -- the effort becomes flesh: +" + _TRIM$(STR$(gain)) + " max HP.   [ press any key ]"
    WaitKey
    LogEvent _TRIM$(player_name) + " gained +" + _TRIM$(STR$(gain)) + " max HP (all abilities maxed)"
END SUB

' The six ability globals behind one index, so the picker is a loop and not six copies.
FUNCTION StatValue% (i AS INTEGER)
    SELECT CASE i
        CASE 1: StatValue% = player_str
        CASE 2: StatValue% = player_int
        CASE 3: StatValue% = player_wis
        CASE 4: StatValue% = player_dex
        CASE 5: StatValue% = player_con
        CASE ELSE: StatValue% = player_cha
    END SELECT
END FUNCTION

SUB SetStatValue (i AS INTEGER, v AS INTEGER)
    SELECT CASE i
        CASE 1: player_str = v
        CASE 2: player_int = v
        CASE 3: player_wis = v
        CASE 4: player_dex = v
        CASE 5: player_con = v
        CASE ELSE: player_cha = v
    END SELECT
END SUB

' What this ability actually DOES, in a few words. Shown beside the choice so the decision is
' informed -- the fuller explanation is the character-creator side panel.
FUNCTION StatBlurb$ (i AS INTEGER)
    SELECT CASE i
        CASE 1: StatBlurb$ = "hit + damage, forcing doors"
        CASE 2: StatBlurb$ = "a Wizard's hit + damage"
        CASE 3: StatBlurb$ = "saves vs. curses"
        CASE 4: StatBlurb$ = "armour class, dodging traps"
        CASE 5: StatBlurb$ = "HP per level from here on"
        CASE ELSE: StatBlurb$ = "luck, and how the world reacts"
    END SELECT
END FUNCTION

' The consequence of THIS point, said plainly -- CON is called out because it is the one that
' does not pay out immediately, and a player who is not told will read that as a bug.
FUNCTION StatGainLine$ (i AS INTEGER)
    SELECT CASE i
        CASE 1: StatGainLine$ = "Your arm is surer: to hit " + ModStr$(AbilMod(player_str)) + ", damage " + ModStr$(AbilMod(player_str)) + "."
        CASE 2: StatGainLine$ = "Your mind sharpens -- a Wizard strikes by wit."
        CASE 3: StatGainLine$ = "Your will hardens against what the dark whispers."
        CASE 4: StatGainLine$ = "You move better: armour class " + _TRIM$(STR$(player_ac)) + "."
        CASE 5: StatGainLine$ = "You are hardier -- every level FROM HERE rolls better HP (past levels are not redone)."
        CASE ELSE: StatGainLine$ = "The world warms to you, and fortune leans a little your way."
    END SELECT
END FUNCTION


' Paint-only half of the level-up picker, so `dungeon.run statshot` can render it without an
' input loop -- the same split ShowCharSheet/ShowCharSheetPaint uses, and for the same reason:
' this layout only misbehaves when the blurbs are long and every row is filled.
SUB LevelUpStatPaint (sel AS INTEGER)
    DIM i AS INTEGER, y AS INTEGER, v AS INTEGER
    ' Panel cols 34..98. It was 38..94, and the longest blurb ("luck, and how the world
    ' reacts", 30 chars) starting at col 64 ran straight through the right border. The blurb
    ' column is also CLIPPED below, so adding a longer one later cannot reopen this.
    DIM bl AS STRING, room AS INTEGER
    _DEST CANVAS
    LINE (34 * CW, 14 * CH)-(98 * CW, 36 * CH), BOXBG, BF
    LINE (34 * CW, 14 * CH)-(98 * CW, 36 * CH), YELLOWU, B
    COLOR YELLOWU, BOXBG: PrintCentered 16, "-=  A POINT OF GROWTH  =-"
    COLOR GREY, BOXBG: PrintCentered 18, "Level " + _TRIM$(STR$(char_level)) + " -- raise one ability by 1 (max 18)"
    FOR i = 1 TO 6
        y = 21 + (i - 1) * 2
        v = StatValue%(i)
        IF v >= 18 THEN
            COLOR GREY, BOXBG                    ' already maxed -- shown, but not selectable
        ELSEIF i = sel THEN
            COLOR WHITE, REDU
        ELSE
            COLOR GREENU, BOXBG
        END IF
        _PRINTSTRING (38 * CW, y * CH), PadR$("  " + StatName$(i) + "  " + _TRIM$(STR$(v)), 14)
        room = 97 - 54                           ' columns available before the right border
        IF v < 18 THEN
            COLOR CYANU, BOXBG
            bl = "-> " + _TRIM$(STR$(v + 1)) + "   " + StatBlurb$(i)
            IF LEN(bl) > room THEN bl = LEFT$(bl, room)
            _PRINTSTRING (54 * CW, y * CH), bl
        ELSE
            COLOR GREY, BOXBG
            _PRINTSTRING (54 * CW, y * CH), "(maxed)"
        END IF
    NEXT i
    COLOR YELLOWU, BOXBG: PrintCentered 34, "[Up/Down] choose    [ENTER] spend the point"
END SUB


' ============================================================================
'  What the highlighted ability actually DOES -- the character-creator side panel.
'
'  Lines come from assets/data/<pack>/stats.txt, each flagged live or planned. LIVE lines print
'  normally; PLANNED ones print dim and marked "(soon)".
'
'  Showing the planned ones is deliberate. Hiding them would make WIS and CHA look like dump
'  stats when they are not -- they are simply early. Showing them WITHOUT the mark would be
'  worse than saying nothing at all: the player would spend points on a mechanic that does not
'  exist yet. The flag is what makes the panel honest either way.
' ============================================================================
SUB DrawStatHelp (stat AS INTEGER, col AS INTEGER, row AS INTEGER, wid AS INTEGER)
    DIM i AS INTEGER, y AS INTEGER, t AS STRING, nlive AS INTEGER
    IF stat < 1 OR stat > 6 THEN EXIT SUB
    _DEST CANVAS
    COLOR YELLOWU, BLACK
    _PRINTSTRING (col * CW, row * CH), StatName$(stat) + " -- what it does"
    LINE (col * CW, (row + 1) * CH - 2)-((col + wid) * CW, (row + 1) * CH - 1), CYANU, BF
    y = row + 2
    FOR i = 1 TO SH_N
        IF SH_STAT(i) = stat THEN
            t = _TRIM$(SH_TEXT(i))
            IF LEN(t) > wid - 4 THEN t = LEFT$(t, wid - 4)
            IF SH_LIVE(i) THEN
                COLOR GREENU, BLACK
                _PRINTSTRING (col * CW, y * CH), "  " + t
                nlive = nlive + 1
            ELSE
                COLOR GREY, BLACK
                _PRINTSTRING (col * CW, y * CH), "  " + t + "  (soon)"
            END IF
            y = y + 1
        END IF
    NEXT i
    IF SH_N = 0 THEN
        COLOR GREY, BLACK
        _PRINTSTRING (col * CW, y * CH), "  (assets/data/stats.txt is missing)"
    END IF
END SUB


' The WIN / LOSE banner art, drawn BEHIND the end-screen text.
'
' Sits high (rows 3..17) so the title at row 20 and everything under it stays clear -- the art
' frames the words rather than competing with them. Silent when the selected art style has
' nothing, which is the normal case until the screens are generated.
SUB EndScreenArt (nm AS STRING)
    DIM p AS STRING, bw AS INTEGER, bh AS INTEGER, bx AS INTEGER, by AS INTEGER
    p = ArtFile$("screens/" + nm + ".png")
    IF LEN(p) = 0 THEN EXIT SUB
    bw = 56 * CW: bh = 15 * CH
    bx = (SW * CW - bw) \ 2: by = 3 * CH
    _DEST CANVAS
    IF DrawSpriteFit%(p, bx, by, bw, bh) = 0 THEN EXIT SUB
END SUB


' ============================================================================
'  THE DEATH SCREEN -- an animated epitaph.
'
'  Four beats, in this order, because each one needs the previous one already on screen:
'    1. the gravestone rises out of the dark
'    2. the epitaph is carved onto it, a line at a time
'    3. your own weapon drives into the ground beside it
'    4. everything you killed rains down and piles at its base, level 1 first
'
'  Every beat is SKIPPABLE with a keypress and the whole thing is skippable at once, because
'  this plays on every death and a player on their fourth attempt does not want the ceremony.
'  DeathSkip% is checked between beats AND inside each loop for that reason.
' ============================================================================

' Has the player asked to get on with it? Latches, so one press skips the whole sequence
' rather than only the beat that happened to be running when the key was pressed.
FUNCTION DeathSkip% ()
    IF death_skipped THEN DeathSkip% = -1: EXIT FUNCTION
    IF LEN(INKEY$) > 0 THEN death_skipped = -1
    DeathSkip% = death_skipped
END FUNCTION

' The class's weapon, for the blade driven into the ground. Hero and Superhero get a sword,
' the Elf their bow, the Wizard the staff -- deliberately the CLASS weapon and not whatever
' happens to be equipped, because this is the character's icon, not their inventory.
FUNCTION DeathWeaponArt$ ()
    DIM p AS STRING, cl AS STRING
    cl = LCASE$(_TRIM$(class_name))
    IF INSTR(cl, "wizard") > 0 THEN
        p = ArtFile$("items/staff.png")
    ELSEIF INSTR(cl, "elf") > 0 THEN
        p = ArtFile$("items/magic-bow.png")
        IF LEN(p) = 0 THEN p = ArtFile$("items/elven-blade.png")
    ELSE
        p = ArtFile$("items/sword.png")
        IF LEN(p) = 0 THEN p = ArtFile$("items/magic-sword-1.png")
    END IF
    DeathWeaponArt$ = p
END FUNCTION

' The epitaph lines. Kept as a function so the shot and the screen cannot drift.
FUNCTION EpitaphLine$ (i AS INTEGER)
    SELECT CASE i
        CASE 1: EpitaphLine$ = "HERE LIES"
        CASE 2: EpitaphLine$ = _TRIM$(player_name)
        CASE 3: EpitaphLine$ = ""
        CASE 4
            IF LEN(_TRIM$(g_death_mon)) > 0 THEN
                EpitaphLine$ = "Slain by " + _TRIM$(g_death_mon) + " on level " + _TRIM$(STR$(g_death_lv))
            ELSE
                EpitaphLine$ = "Lost to the dark"      ' timed-out / starved solo runs have no killer
            END IF
        CASE 5: EpitaphLine$ = "Saved " + _TRIM$(STR$(g_saved)) + " time" + Plural$(g_saved)
        CASE 6: EpitaphLine$ = "Lasted " + _TRIM$(STR$(RunMinutes&)) + " minute" + Plural$(RunMinutes&)
        CASE 7: EpitaphLine$ = "Tried " + _TRIM$(STR$(g_run_deaths)) + " time" + Plural$(g_run_deaths)
    END SELECT
END FUNCTION

FUNCTION Plural$ (n AS LONG)
    IF n = 1 THEN Plural$ = "" ELSE Plural$ = "s"
END FUNCTION

' Draw the stone + however much of the epitaph has been carved so far (lines 1..upto).
'
' Only the NAME is carved on the stone; the detail lines go underneath it. That split is forced
' by the art, not chosen for looks: the stone fits by ASPECT, so it is drawn far narrower than
' its box, and "Slain by VAMPIRE on level 6" is simply wider than any gravestone. Carving the
' long lines onto it ran them off both edges. SpriteFitRect% is how the text finds the real
' stone rather than the box it was fitted into.
SUB DeathStone (sy AS INTEGER, upto AS INTEGER)
    DIM i AS INTEGER, p AS STRING, junk AS INTEGER, ln AS STRING
    DIM gx AS INTEGER, gw AS INTEGER, gh AS INTEGER
    DIM sx AS INTEGER, syy AS INTEGER, stw AS INTEGER, sth AS INTEGER
    DIM cxp AS INTEGER, ty AS INTEGER
    gw = 26 * CW: gh = 24 * CH
    gx = (SW * CW - gw) \ 2
    p = ArtFile$("markers/gravestone.png")
    IF LEN(p) > 0 THEN
        junk = SpriteFitRect%(p, gx, sy, gw, gh, sx, syy, stw, sth)
        junk = DrawSpriteFit%(p, gx, sy, gw, gh)
    ELSE
        ' No art: draw a stone. The epitaph is the point of this screen and must never be
        ' floating on a black field because one asset is missing.
        sx = gx + 4 * CW: syy = sy + 2 * CH: stw = gw - 8 * CW: sth = gh - 2 * CH
        LINE (sx, syy)-(sx + stw, syy + sth), Thm~&("grave.stone", _RGB32(&H4A, &H4A, &H52)), BF
        LINE (sx, syy)-(sx + stw, syy + sth), Thm~&("grave.stone.edge", _RGB32(&H6E, &H6E, &H78)), B
    END IF
    cxp = sx + stw \ 2
    _FONT CH
    _PRINTMODE _KEEPBACKGROUND
    FOR i = 1 TO upto
        ln = EpitaphLine$(i)
        IF LEN(ln) > 0 THEN
            IF i <= 2 THEN
                ' carved INTO the stone, in its upper third
                COLOR Thm~&("grave.carve.shadow", _RGB32(&H1A, &H18, &H16)), 0
                ty = syy + sth \ 5 + (i - 1) * CH * 2
                _PRINTSTRING (cxp - (LEN(ln) * CW) \ 2 + 1, ty + 1), ln      ' chiselled shadow
                COLOR Thm~&("grave.carve", _RGB32(&HEC, &HE8, &HDC)), 0
                _PRINTSTRING (cxp - (LEN(ln) * CW) \ 2, ty), ln
            ELSE
                ' the record, on the ground below the stone
                COLOR Thm~&("grave.record", _RGB32(&HA8, &HA4, &H98)), 0
                ty = syy + sth + (i - 3) * CH * 2
                _PRINTSTRING (SW * CW \ 2 - (LEN(ln) * CW) \ 2, ty), ln
            END IF
        END IF
    NEXT i
    _PRINTMODE _FILLBACKGROUND
    DEATH_STONE_X = sx: DEATH_STONE_Y = syy: DEATH_STONE_W = stw: DEATH_STONE_H = sth
END SUB

' Beat 4: everything you killed, raining down and piling at the stone's base.
'
' Walks the roster in LEVEL order so the pile reads as the descent itself -- level 1's kills
' land first and end up buried under level 9's. Capped: a long run can kill sixty monsters and
' sixty falling sprites is a screensaver, not a beat.
SUB DeathPile (baseY AS INTEGER)
    CONST PILE_MAX = 28
    DIM lv AS INTEGER, sl AS INTEGER, n AS INTEGER, i AS INTEGER, bi AS INTEGER
    DIM nm AS STRING, p AS STRING, junk AS INTEGER
    DIM px(1 TO PILE_MAX) AS INTEGER, py(1 TO PILE_MAX) AS INTEGER, pp(1 TO PILE_MAX) AS STRING
    DIM cnt AS INTEGER, f AS INTEGER, yy AS SINGLE, sz AS INTEGER
    sz = 5 * CW
    FOR lv = 1 TO 9
        FOR sl = 1 TO 3
            nm = _TRIM$(MON_NAME(lv, sl))
            IF LEN(nm) > 0 THEN
                bi = BeastIdx%(nm)
                IF bi > 0 THEN
                    n = BEAST_SLAIN(bi)
                    IF n > 3 THEN n = 3                 ' one monster cannot fill the whole pile
                    FOR i = 1 TO n
                        IF cnt < PILE_MAX THEN
                            p = MonsterSprite$(nm)
                            IF LEN(p) > 0 THEN
                                cnt = cnt + 1
                                pp(cnt) = p
                                ' spread across the stone's foot, stacking upward as it fills
                                px(cnt) = SW * CW \ 2 - 24 * CW + ((cnt - 1) MOD 10) * (sz - 6)
                                py(cnt) = baseY - ((cnt - 1) \ 10) * (sz \ 2)
                            END IF
                        END IF
                    NEXT i
                END IF
            END IF
        NEXT sl
    NEXT lv
    IF cnt = 0 THEN EXIT SUB                            ' killed nothing: no pile, and no empty beat
    FOR i = 1 TO cnt
        FOR f = 0 TO 9
            IF DeathSkip% THEN EXIT FOR
            yy = py(i) - (9 - f) * 26                   ' fall in from above the resting place
            _PUTIMAGE (0, 0), FX_BUF, CANVAS            ' the settled scene behind it
            FOR bi = 1 TO i - 1                         ' everything already landed
                junk = DrawSpriteFit%(pp(bi), px(bi), py(bi), sz, sz)
            NEXT bi
            junk = DrawSpriteFit%(pp(i), px(i), INT(yy), sz, sz)
            Present: _LIMIT 60
        NEXT f
        IF opt_sfx THEN Tone 90 + (i MOD 4) * 18, 0.03
        ' Bank the landed sprite into the backdrop so the next one does not redraw all of them.
        _PUTIMAGE (0, 0), FX_BUF, CANVAS
        FOR bi = 1 TO i
            junk = DrawSpriteFit%(pp(bi), px(bi), py(bi), sz, sz)
        NEXT bi
        _PUTIMAGE (0, 0), CANVAS, FX_BUF
    NEXT i
END SUB

' The whole sequence. `shotmode` writes PNGs of each beat instead of animating (deathshot).
SUB DeathScreen
    DIM i AS INTEGER, f AS INTEGER, sy AS INTEGER, wy AS SINGLE, junk AS INTEGER
    DIM p AS STRING, stoneY AS INTEGER, wx AS INTEGER, ww AS INTEGER
    death_skipped = FALSE
    stoneY = 8 * CH
    IF FX_BUF = 0 THEN FX_BUF = _NEWIMAGE(SW * CW, SH * CH, 32)
    _DEST CANVAS: _FONT CH: CLS , BLACK

    ' 1 -- the stone rises out of the dark
    FOR f = 0 TO 14
        IF DeathSkip% THEN EXIT FOR
        CLS , BLACK
        EndScreenArt "you-died"
        sy = stoneY + (14 - f) * 8
        DeathStone sy, 0
        Present: _LIMIT 45
    NEXT f
    CLS , BLACK: EndScreenArt "you-died": DeathStone stoneY, 0: Present

    ' 2 -- the epitaph is carved, a line at a time
    FOR i = 1 TO 7
        IF DeathSkip% THEN EXIT FOR
        CLS , BLACK: EndScreenArt "you-died"
        DeathStone stoneY, i
        Present
        IF opt_sfx AND LEN(EpitaphLine$(i)) > 0 THEN Tone 220 - i * 12, 0.05
        DelaySkippable 0.42
    NEXT i
    CLS , BLACK: EndScreenArt "you-died": DeathStone stoneY, 7: Present

    ' 3 -- the weapon drives into the ground beside the stone. Placed against the stone's REAL
    ' rect (DEATH_STONE_*), not the fit box, or it plants itself in mid-air next to nothing.
    p = DeathWeaponArt$
    IF LEN(p) > 0 THEN
        DIM wh AS INTEGER, restY AS INTEGER
        wh = 14 * CH: ww = 8 * CW
        wx = DEATH_STONE_X + DEATH_STONE_W + 2 * CW
        restY = DEATH_STONE_Y + DEATH_STONE_H - wh + 3 * CH   ' point buried at the stone's foot
        _PUTIMAGE (0, 0), CANVAS, FX_BUF                ' the settled stone, to redraw over
        FOR f = 0 TO 12
            IF DeathSkip% THEN EXIT FOR
            wy = restY - 22 * CH + f * ((22 * CH) / 12)
            _PUTIMAGE (0, 0), FX_BUF, CANVAS
            junk = DrawSpriteFit%(p, wx, INT(wy), ww, wh)
            Present: _LIMIT 60
        NEXT f
        _PUTIMAGE (0, 0), FX_BUF, CANVAS
        junk = DrawSpriteFit%(p, wx, restY, ww, wh)
        Sfx "bump"
        IF opt_juice THEN ImpactFX 7, 0                 ' the thud you feel
        Present
    END IF
    _PUTIMAGE (0, 0), CANVAS, FX_BUF

    ' 4 -- the dead pile up at its foot
    ' +16 rows, not +12: the pile STACKS UPWARD (that is what "piles on top of the previous
    ' level" means), so its highest row sits ~3 rows above this baseline and was landing on
    ' the last epitaph line.
    DeathPile DEATH_STONE_Y + DEATH_STONE_H + 16 * CH

    COLOR YELLOWU, BLACK: PrintCentered 47, Say$("end.return")
    Present
END SUB

' A _DELAY that a keypress can cut short, so the epitaph does not hold a player hostage.
SUB DelaySkippable (secs AS SINGLE)
    DIM t0 AS SINGLE
    t0 = TIMER
    DO
        IF DeathSkip% THEN EXIT SUB
        _LIMIT 60
    LOOP UNTIL TIMER - t0 >= secs OR TIMER - t0 < 0
END SUB


' Does every settings option actually have a place on the screen?
'
' BuildSetLayout assigns ids to columns by hand, and an id that is never assigned -- or one past
' the SL_* array bounds -- simply does not draw. There is no error: the screen looks completely
' normal, just missing a row, and you only notice if you go looking for that one setting. That is
' exactly how the three per-category audio-format rows vanished when NSET grew past the arrays'
' hardcoded 64. Run from `dungeon.run settingsshot`, so the gate sees it.
' Option ids that intentionally do not exist. The id space is not contiguous -- a setting that
' was removed leaves its number behind rather than renumbering everything after it, which would
' silently rewrite the meaning of every saved layout position and every CASE arm below it.
'
' Keeping the retired ones listed HERE, rather than loosening the check to "gaps are fine", is
' what keeps the check sharp: a genuinely lost row still fails. When you retire an id, add it.
FUNCTION SetIdRetired% (i AS INTEGER)
    SELECT CASE i
        CASE 57, 58: SetIdRetired% = -1      ' removed options; no label, no value, no CASE arm
        CASE ELSE: SetIdRetired% = 0
    END SELECT
END FUNCTION

SUB SettingsLayoutCheck
    DIM i AS INTEGER, missing AS INTEGER, lst AS STRING
    _DEST _CONSOLE
    FOR i = 1 TO NSET
        IF SL_ROW(i) = 0 AND NOT SetIdRetired%(i) THEN
            missing = missing + 1
            IF LEN(lst) > 0 THEN lst = lst + " "
            lst = lst + _TRIM$(STR$(i))
        END IF
    NEXT i
    PRINT PipeCol$("settingsshot: " + _TRIM$(STR$(SORD_N)) + " option row(s) laid out, max id " + _TRIM$(STR$(NSET)))
    IF missing > 0 THEN
        PRINT PipeCol$("|12BAD|07  " + _TRIM$(STR$(missing)) + " option id(s) never placed by BuildSetLayout: " + lst)
        PRINT PipeCol$("     they exist in the SELECT CASE blocks but draw nowhere -- add a SetLayRow, or raise SETOPT_MAX")
        SYSTEM 1
    END IF
    PRINT PipeCol$("  |10ok |07  every option id has a column and a row")
END SUB


' ----------------------------------------------------------------------------
'  Cut-scene pacing -- Manual / Auto / Off.
'
'  This is a SETTING and not a property of any script, on purpose: how long a
'  line of dialogue holds is the player's business, and a scene that hardcoded
'  it would be wrong for half the people who see it. `Auto` is also what an
'  attract loop and a headless screenshot need, so the same switch serves all
'  three.
' ----------------------------------------------------------------------------
FUNCTION CutsceneModeLabel$
    SELECT CASE opt_cutscenes
        CASE CUT_AUTO: CutsceneModeLabel$ = "auto"
        CASE CUT_OFF: CutsceneModeLabel$ = "off"
        CASE ELSE: CutsceneModeLabel$ = "manual"
    END SELECT
END FUNCTION

SUB CycleCutscenes (delta AS INTEGER)
    opt_cutscenes = opt_cutscenes + delta
    IF opt_cutscenes > CUT_OFF THEN opt_cutscenes = CUT_MANUAL
    IF opt_cutscenes < CUT_MANUAL THEN opt_cutscenes = CUT_OFF
END SUB
