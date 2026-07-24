' ============================================================================
'  MENU.bas -- intro, menu, class-select, dialogs, HUD, dice, sound
' ============================================================================

FUNCTION SelectClass%
    DIM sel AS INTEGER, k AS STRING, i AS INTEGER, yrow AS INTEGER
    sel = player_class: IF sel < 1 OR sel > 4 THEN sel = 1
    DO
        _LIMIT 60
        k = NormKey$(UCASE$(INKEY$))         ' arrows / numpad -> WASD too
        IF k = "W" OR k = "A" THEN
            sel = sel - 1: IF sel < 1 THEN sel = 4
            IF opt_sfx THEN Tone 200, 0.1
        END IF
        IF k = "S" OR k = "D" THEN
            sel = sel + 1: IF sel > 4 THEN sel = 1
            IF opt_sfx THEN Tone 200, 0.1
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
    DIM i AS INTEGER, y AS INTEGER, nm(1 TO 6) AS STRING, row AS STRING
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
        COLOR YELLOWU, BLACK: PrintCentered 44, "[R] re-roll hero     [N] new name     [ENTER] keep this one"
    ELSE
        COLOR CYANU, BLACK
        IF rolled < 6 THEN
            PrintCentered 44, "[ press a key ] roll " + nm(rolled + 1) + "        [A] auto-roll the rest        [N] new name"
        ELSE
            PrintCentered 44, "[ press a key ] roll your HIT POINTS        [A] auto"
        END IF
    END IF
    _DISPLAY
END SUB


' The full generation flow: roll 3d6 for six abilities, roll hit points on the
' class hit die, derive the D&D combat stats, and let the player re-roll.
' Honours Real Dice (each 3d6 becomes a PromptRoll when that setting is on).
SUB RollCharacter (pc AS INTEGER)
    DIM sc(1 TO 6) AS INTEGER, i AS INTEGER, hproll AS INTEGER, atkmod AS INTEGER, k AS STRING, auto AS INTEGER
    IF _TRIM$(player_name) = "" THEN player_name = RandomHeroName$   ' a colourful default to start
    DO
        auto = FALSE
        FOR i = 1 TO 6
            DrawCharGen pc, sc(), i - 1, 0             ' show sheet + the prompt to roll this ability
            IF NOT auto THEN                           ' the player presses a key to roll each stat...
                DO
                    _LIMIT 60: k = UCASE$(INKEY$): _DISPLAY
                    IF k = "N" THEN player_name = RandomHeroName$: DrawCharGen pc, sc(), i - 1, 0: k = ""
                LOOP UNTIL k <> ""
                IF k = "A" THEN auto = -1: Sfx "select"  ' ...or [A] to auto-roll the rest
            END IF
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
            LOOP UNTIL k <> ""
        END IF
        hproll = GameRoll(3, CLASSES(pc).hitdie, 0, "HIT POINTS")
        player_maxhp = hproll + 3 * AbilMod(player_con)
        IF player_maxhp < 3 THEN player_maxhp = 3
        player_hp = player_maxhp
        ' Wizards strike with INT (spells); everyone else with STR
        IF pc = 4 THEN atkmod = AbilMod(player_int) ELSE atkmod = AbilMod(player_str)
        player_tohit = CLASSES(pc).tohit + atkmod
        player_dmgdie = CLASSES(pc).dmg
        player_dmgbonus = atkmod
        player_ac = CLASSES(pc).ac + AbilMod(player_dex)
        DrawCharGen pc, sc(), 6, -1                    ' final sheet + reroll/name/keep prompt
        DO
            _LIMIT 60: k = UCASE$(INKEY$): _DISPLAY
            IF k = "N" THEN player_name = RandomHeroName$: DrawCharGen pc, sc(), 6, -1: k = ""
        LOOP UNTIL k = "R" OR k = CHR$(13)
        Sfx "select"
    LOOP UNTIL k = CHR$(13)
END SUB


' ============================================================================
'  SCREEN FADES
' ============================================================================

' Fade whatever is currently composed on CANVAS in from black.
SUB FadeInCurrent
    DIM scene AS LONG, a AS INTEGER
    scene = _NEWIMAGE(SW * CW, SH * CH, 32)
    _PUTIMAGE (0, 0), CANVAS, scene              ' snapshot the composed screen
    _DEST CANVAS
    FOR a = 255 TO 0 STEP -20
        _PUTIMAGE (0, 0), scene, CANVAS
        LINE (0, 0)-(SW * CW - 1, SH * CH - 1), _RGB32(&H00, &H00, &H00, a), BF
        _DISPLAY
        _LIMIT 60
    NEXT a
    _PUTIMAGE (0, 0), scene, CANVAS
    _DISPLAY
    _FREEIMAGE scene
END SUB

' Fade the current screen out to black (cumulative darkening -- no buffer needed).
SUB FadeOut
    DIM i AS INTEGER
    _DEST CANVAS
    FOR i = 1 TO 14
        LINE (0, 0)-(SW * CW - 1, SH * CH - 1), _RGB32(&H00, &H00, &H00, &H2C), BF
        _DISPLAY
        _LIMIT 60
    NEXT i
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), BLACK, BF
    _DISPLAY
END SUB


' Death transition: adjacent vertical strips of blood each run down on their own
' stagger + speed, piling up strip by strip until the whole screen is red -- then
' it slowly fades to black. (No sweeping rectangle -- the strips do the filling.)
SUB BloodDrip
    DIM strw AS INTEGER, ns AS INTEGER, i AS INTEGER, f AS INTEGER, px AS INTEGER, allfull AS INTEGER
    DIM slen(1 TO 220) AS INTEGER, sdelay(1 TO 220) AS INTEGER, ssp(1 TO 220) AS INTEGER
    DIM darkred AS _UNSIGNED LONG, brightred AS _UNSIGNED LONG
    darkred = _RGB32(&H90, &H00, &H00): brightred = _RGB32(&HDA, &H24, &H24)
    strw = 8                                     ' strip width (tile the full width -- no gaps)
    ns = (SW * CW) \ strw + 1
    IF ns > 220 THEN ns = 220
    FOR i = 1 TO ns
        sdelay(i) = INT(RND * 42)                ' each strip starts at its own moment
        ssp(i) = 13 + INT(RND * 22)              ' ...and runs at its own speed
        slen(i) = 0
    NEXT i
    _DEST CANVAS
    f = 0
    DO
        f = f + 1
        allfull = -1
        FOR i = 1 TO ns
            IF f >= sdelay(i) THEN
                slen(i) = slen(i) + ssp(i)
                IF slen(i) > SH * CH THEN slen(i) = SH * CH
                px = (i - 1) * strw
                LINE (px, 0)-(px + strw - 1, slen(i)), darkred, BF          ' the strip so far
                IF slen(i) < SH * CH THEN
                    LINE (px, slen(i) - 12)-(px + strw - 1, slen(i) + 4), brightred, BF   ' its running head
                    allfull = 0
                END IF
            ELSE
                allfull = 0
            END IF
        NEXT i
        _DISPLAY
        _LIMIT 60
    LOOP UNTIL allfull OR f > 220
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), darkred, BF   ' guarantee fully solid
    _DISPLAY
    _DELAY 0.35                                          ' hold the blood-soaked screen a beat
    ' slow fade from red to black
    FOR f = 1 TO 48
        LINE (0, 0)-(SW * CW - 1, SH * CH - 1), _RGB32(&H00, &H00, &H00, &H0E), BF
        _DISPLAY
        _LIMIT 60
    NEXT f
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), BLACK, BF
    _DISPLAY
END SUB


' Forfeit transition: the same falling-strips effect as BloodDrip, but drained of
' colour -- grey strips run down and pile into black. Used when a run ends for good
' (all lives spent). The user asked for "darkness fading down like blood but grey".
SUB DarknessFall
    DIM strw AS INTEGER, ns AS INTEGER, i AS INTEGER, f AS INTEGER, px AS INTEGER, allfull AS INTEGER
    DIM slen(1 TO 220) AS INTEGER, sdelay(1 TO 220) AS INTEGER, ssp(1 TO 220) AS INTEGER
    DIM darkgrey AS _UNSIGNED LONG, litegrey AS _UNSIGNED LONG
    darkgrey = _RGB32(&H1E, &H1E, &H1E): litegrey = _RGB32(&H55, &H55, &H55)
    strw = 8
    ns = (SW * CW) \ strw + 1
    IF ns > 220 THEN ns = 220
    FOR i = 1 TO ns
        sdelay(i) = INT(RND * 42)
        ssp(i) = 13 + INT(RND * 22)
        slen(i) = 0
    NEXT i
    _DEST CANVAS
    f = 0
    DO
        f = f + 1
        allfull = -1
        FOR i = 1 TO ns
            IF f >= sdelay(i) THEN
                slen(i) = slen(i) + ssp(i)
                IF slen(i) > SH * CH THEN slen(i) = SH * CH
                px = (i - 1) * strw
                LINE (px, 0)-(px + strw - 1, slen(i)), darkgrey, BF          ' the strip so far
                IF slen(i) < SH * CH THEN
                    LINE (px, slen(i) - 12)-(px + strw - 1, slen(i) + 4), litegrey, BF   ' its running head
                    allfull = 0
                END IF
            ELSE
                allfull = 0
            END IF
        NEXT i
        _DISPLAY
        _LIMIT 60
    LOOP UNTIL allfull OR f > 220
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), darkgrey, BF   ' guarantee fully solid grey
    _DISPLAY
    _DELAY 0.35                                            ' hold the ashen screen a beat
    FOR f = 1 TO 48                                        ' slow fade from grey to black
        LINE (0, 0)-(SW * CW - 1, SH * CH - 1), _RGB32(&H00, &H00, &H00, &H0E), BF
        _DISPLAY
        _LIMIT 60
    NEXT f
    LINE (0, 0)-(SW * CW - 1, SH * CH - 1), BLACK, BF
    _DISPLAY
END SUB


' ============================================================================
'  INTRO
' ============================================================================

SUB ShowIntro
    DIM ansi AS STRING, mus AS LONG, k AS STRING, frames AS INTEGER
    ansi = LoadFile$("assets/ansi/vermin-radioactive-logo.ans")
    mus = _SNDOPEN("assets/music/vr-theme.rad")
    IF mus > 0 THEN _SNDVOL mus, opt_musicvol / 10
    IF mus > 0 AND opt_music THEN _SNDPLAY mus
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

    logo = LoadFile$("assets/ansi/dungeon-menu-logo.ans")
    FOR i = 1 TO 4: lw(i) = LoadFile$("assets/ansi/dungeon-menu-left-wall-" + _TRIM$(STR$(i)) + ".ans"): NEXT
    FOR i = 1 TO 4: rw(i) = LoadFile$("assets/ansi/dungeon-menu-right-wall-" + _TRIM$(STR$(i)) + ".ans"): NEXT
    FOR i = 1 TO 6: bl(i) = LoadFile$("assets/ansi/dungeon-menu-block-" + _TRIM$(STR$(i)) + ".ans"): NEXT

    iLogo = _NEWIMAGE(102 * CW, 15 * CH, 32)
    iLeft = _NEWIMAGE(15 * CW, 51 * CH, 32)
    iRight = _NEWIMAGE(16 * CW, 51 * CH, 32)
    iBlock = _NEWIMAGE(95 * CW, 31 * CH, 32)
    _DEST iLogo: _FONT CH: ANSI_Print (logo)
    _DEST iLeft: _FONT CH: ANSI_Print (lw(1))
    _DEST iRight: _FONT CH: ANSI_Print (rw(1))
    _DEST iBlock: _FONT CH: ANSI_Print (bl(1))

    mus = _SNDOPEN("assets/music/everdark.rad")
    music_handle = mus
    IF mus > 0 THEN _SNDVOL mus, opt_musicvol / 10
    IF mus > 0 AND opt_music THEN _SNDLOOP mus

    sel = 1: t = 0: result = 0
    bnr_l2 = ""                               ' no stale in-game banner should flash in the menu
    DIM firstframe AS INTEGER: firstframe = -1
    DO
        _LIMIT 60
        k = NormKey$(UCASE$(INKEY$))          ' arrows/numpad -> WASD
        IF k = "A" OR k = "W" THEN sel = sel - 1: IF sel < 1 THEN sel = 6
        IF k = "D" OR k = "S" THEN sel = sel + 1: IF sel > 6 THEN sel = 1
        IF k = "A" OR k = "W" OR k = "S" OR k = "D" THEN Sfx "select"
        IF k = CHR$(13) THEN
            IF sel = 1 THEN
                result = MENU_ENTER: EXIT DO
            ELSEIF sel = 2 THEN
                chosen = SelectClass
                IF chosen > 0 THEN
                    player_class = chosen: player_name = ""
                    RollCharacter chosen             ' old-school 3d6 stats + rolled HP
                END IF
            ELSEIF sel = 3 THEN
                LoadCharacter
            ELSEIF sel = 4 THEN
                ShowLords
            ELSEIF sel = 5 THEN
                RunSettings
                IF mus > 0 THEN
                    _SNDVOL mus, opt_musicvol / 10
                    IF opt_music AND _SNDPLAYING(mus) = 0 THEN _SNDLOOP mus
                    IF NOT opt_music THEN _SNDSTOP mus
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
        COLOR GREY, BLACK: PrintCentered 49, "[N] New School   [O] Old School      (Combat " + cmb + "   FOV " + fv + ")"
        _DISPLAY
        IF firstframe THEN FadeInCurrent: firstframe = 0   ' fade the menu in on the first frame
    LOOP
    IF result = MENU_ENTER THEN BloodDrip ELSE FadeOut     ' blood-drip descent into the dungeon; plain fade otherwise

    IF mus > 0 THEN _SNDSTOP mus: _SNDCLOSE mus
    music_handle = 0
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


SUB RunSettings
    CONST NSET = 30
    DIM sel AS INTEGER, k AS STRING, i AS INTEGER, y AS INTEGER, vtxt AS STRING, lbl AS STRING
    DIM slider AS INTEGER, delta AS INTEGER
    sel = 1
    DO
        _LIMIT 60
        k = NormKey$(UCASE$(INKEY$))
        IF k = "W" THEN sel = sel - 1: IF sel < 1 THEN sel = NSET
        IF k = "S" THEN sel = sel + 1: IF sel > NSET THEN sel = 1
        IF k = "W" OR k = "S" THEN Sfx "select"
        IF k = CHR$(27) THEN SaveSettings: EXIT SUB

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
            END SELECT
        END IF

        IF k = " " OR k = CHR$(13) THEN
            SELECT CASE sel
                CASE 1: opt_music = NOT opt_music
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
                CASE 30: SaveSettings: EXIT SUB
            END SELECT
            Sfx "select"
        END IF

        _DEST CANVAS: CLS , BLACK
        COLOR YELLOWU, BLACK: PrintCentered 1, "-=  S E T T I N G S  =-"
        FOR i = 1 TO NSET
            y = 3 + (i - 1)                     ' single-row list (grown too long for double spacing)
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
                CASE ELSE: lbl = "<< Back": vtxt = ""
            END SELECT
            IF i = sel THEN COLOR WHITE, REDU ELSE IF slider THEN COLOR CYANU, BLACK ELSE COLOR GREY, BLACK
            IF i = NSET THEN PrintCentered y, "   " + lbl + "   " ELSE PrintCentered y, "   " + lbl + ":  " + vtxt + "   "
        NEXT i
        DrawDicePreview 100, " your dice"                       ' player dice on the right
        PushMonsterDice: DrawDicePreview 4, " monster dice": PopMonsterDice   ' monster dice on the left
        COLOR CYANU, BLACK: PrintCentered 49, "[W/S] move   [A/D] adjust   [ENTER] toggle   [ESC] back"
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
    effac = player_ac + item_armor                     ' AC + worn armor/shield
    efth = player_tohit: IF item_bow THEN efth = efth + 2   ' to-hit + Magic Bow
    _DEST CANVAS
    LINE (22 * CW, 3 * CH)-(110 * CW, 48 * CH), BOXBG, BF
    LINE (22 * CW, 3 * CH)-(110 * CW, 48 * CH), REDU, B
    who = _TRIM$(player_name) + " the " + class_name
    IF _TRIM$(player_name) = "" THEN who = class_name
    COLOR YELLOWU, BOXBG: PrintCentered 4, "-=  C H A R A C T E R  =-"
    DIM chline AS STRING
    chline = "Champion:  " + who
    IF NOT opt_oldschool THEN chline = chline + "        Level " + _TRIM$(STR$(char_level)) + "    XP " + _TRIM$(STR$(char_xp))
    COLOR WHITE, BOXBG: PrintCentered 6, chline
    COLOR CYANU, BOXBG
    PrintCentered 7, "STR " + _TRIM$(STR$(player_str)) + "  INT " + _TRIM$(STR$(player_int)) + "  WIS " + _TRIM$(STR$(player_wis)) + "  DEX " + _TRIM$(STR$(player_dex)) + "  CON " + _TRIM$(STR$(player_con)) + "  CHA " + _TRIM$(STR$(player_cha))
    IF NOT opt_oldschool THEN
        COLOR GREENU, BOXBG
        PrintCentered 8, "HP " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + "    AC " + _TRIM$(STR$(effac)) + "    To-Hit " + ModStr$(efth) + "    Dmg 1d" + _TRIM$(STR$(player_dmgdie)) + " " + ModStr$(player_dmgbonus + item_sword)
        COLOR GREY, BOXBG: PrintCentered 9, CombatDerivation$(player_class)   ' where those bonuses come from
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
    IF item_bow THEN inv = inv + "Magic Bow (+2 hit)    "
    IF item_boots THEN inv = inv + "Elf Boots (+2 move)    "
    IF item_teleport > 0 THEN inv = inv + "Teleport x" + _TRIM$(STR$(item_teleport)) + " [T]    "
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
    DIM ky(1 TO 14) AS STRING, ds(1 TO 14) AS STRING, n AS INTEGER, i AS INTEGER, y AS INTEGER
    ky(1) = "WASD / Arrows": ds(1) = "Move up / left / down / right"
    ky(2) = "Numpad 7 9 1 3": ds(2) = "Move diagonally (NW/NE/SW/SE)"
    ky(3) = "SPACE": ds(3) = "Roll movement dice / Attack"
    ky(4) = "F": ds(4) = "Search for secret doors"
    ky(5) = "C": ds(5) = "Character sheet"
    ky(6) = "V": ds(6) = "Scry the dungeon (Crystal Ball)"
    ky(7) = "T": ds(7) = "Read a Teleport Scroll -> START"
    ky(8) = "?": ds(8) = "This controls list"
    ky(9) = "~  or  `": ds(9) = "Toggle the debug overlay"
    ky(10) = "ESC": ds(10) = "Flee combat / quit to menu"
    ky(11) = "R": ds(11) = "Re-roll (during character creation)"
    ky(12) = "H": ds(12) = "Quaff a healing potion"
    ky(13) = "P": ds(13) = "Pause the game (bio break)"
    ky(14) = "G": ds(14) = "Save game (solo; CONTINUE on entry)"
    n = 14
    _DEST CANVAS
    LINE (22 * CW, 7 * CH)-(110 * CW, 44 * CH), BOXBG, BF
    LINE (22 * CW, 7 * CH)-(110 * CW, 44 * CH), CYANU, B
    COLOR YELLOWU, BOXBG: PrintCentered 9, "-=  C O N T R O L S  =-"
    FOR i = 1 TO n
        y = 13 + (i - 1) * 2
        COLOR GREENU, BOXBG: _PRINTSTRING (30 * CW, y * CH), PadR$(ky(i), 16)
        COLOR WHITE, BOXBG: _PRINTSTRING (48 * CW, y * CH), ds(i)
    NEXT i
    COLOR YELLOWU, BOXBG: PrintCentered 42, "[ press any key ]"
    _DISPLAY
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' [F] search for a hidden secret door within a couple of cells of the cursor.
' The Elf's secret_bonus makes the d6 check far more reliable. The first door
' found also yields the Level Key.

SUB ShowEnd (win AS INTEGER)
    DIM nm AS STRING, el AS LONG
    IF win THEN
        Sfx "win"
        nm = EnterName$                         ' victory + name entry
        player_name = nm
        el = TIMER - game_start: IF el < 0 THEN el = el + 86400
        SaveLord nm, class_name, gold, el       ' enshrine in the Legendary Lords
        _DEST CANVAS: _FONT CH: CLS , BLACK
        COLOR GREENU, BLACK: PrintCentered 20, "V I C T O R Y"
        COLOR WHITE, BLACK: PrintCentered 23, nm + " the " + class_name + " escapes with " + _TRIM$(STR$(gold)) + " gold!"
        COLOR CYANU, BLACK: PrintCentered 25, "You are now a Legendary Lord."
    ELSE
        Sfx "lose"
        _DEST CANVAS: _FONT CH: CLS , BLACK
        COLOR REDU, BLACK: PrintCentered 20, "Y O U   D I E D"
        COLOR GREY, BLACK: PrintCentered 23, "The dungeon claims another soul..."
    END IF
    COLOR YELLOWU, BLACK: PrintCentered 28, "[ press any key to return to the menu ]"
    FadeInCurrent                               ' fade the end screen in
    WaitKey
    FadeOut                                      ' fade out before returning to the menu
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
    ELSEIF gold >= target_gold AND has_key THEN
        COLOR GREENU, BLACK
        _PRINTSTRING ((SW - 23) * CW, 50 * CH), "RETURN TO START TO WIN!"
    END IF
END SUB



SUB Banner (l1 AS STRING, l2 AS STRING)
    DIM w AS INTEGER, bx1 AS INTEGER, bx2 AS INTEGER
    _DEST CANVAS
    ' auto-size the box to the widest line (min = the classic 96 cols, capped to
    ' the screen) so long lines never spill past the border
    w = LEN(l1): IF LEN(l2) > w THEN w = LEN(l2)
    w = w + 6
    IF w < 96 THEN w = 96
    IF w > 130 THEN w = 130
    bx1 = (SW - w) \ 2: bx2 = bx1 + w
    LINE (bx1 * CW, 21 * CH)-(bx2 * CW, 30 * CH), BOXBG, BF
    LINE (bx1 * CW, 21 * CH)-(bx2 * CW, 30 * CH), REDU, B
    COLOR WHITE, BOXBG: PrintCentered 24, l1
    COLOR YELLOWU, BOXBG: PrintCentered 27, l2
    bnr_l2 = l2: bnr_bx1 = bx1: bnr_bx2 = bx2      ' remembered so a keypress can flash the prompt
    _DISPLAY
END SUB



SUB PrintCentered (row AS INTEGER, t AS STRING)
    DIM x AS INTEGER
    x = (SW - LEN(t)) \ 2
    IF x < 0 THEN x = 0
    _PRINTSTRING (x * CW, row * CH), t
END SUB



SUB WaitKey
    DIM k AS STRING
    _KEYCLEAR              ' drain buffered keys
    DO: _LIMIT 60: k = INKEY$: _DISPLAY: LOOP UNTIL k <> ""
    FlashPrompt
END SUB


' Acknowledge a keypress at a '[ press any key ]' prompt: a soft click + a quick
' light-up of the last banner's prompt line (which the next redraw then clears).
SUB FlashPrompt
    DIM ff AS INTEGER
    Sfx "select"
    IF LEN(_TRIM$(bnr_l2)) = 0 THEN EXIT SUB
    _DEST CANVAS: _FONT CH
    FOR ff = 1 TO 4
        LINE ((bnr_bx1 + 1) * CW, 27 * CH)-((bnr_bx2 - 1) * CW, 28 * CH), BOXBG, BF
        IF ff MOD 2 = 1 THEN COLOR WHITE, REDU ELSE COLOR YELLOWU, BOXBG
        PrintCentered 27, bnr_l2
        _DISPLAY
        _LIMIT 30
    NEXT ff
    bnr_l2 = ""     ' one-shot: a banner flashes once, never again (no stale redraws elsewhere)
END SUB


' Pause after a combat action so the result is readable. Slow/Normal/Fast wait a
' fixed beat (a held key can't blow through, which is what made combat feel too
' fast); Wait-for-key falls back to WaitKey. Keys pressed during a timed pause are
' drained afterwards so they don't spill into the next prompt or trigger a round.
SUB CombatPause
    DIM f AS INTEGER, maxf AS INTEGER
    ' NOTE: do NOT drain the buffer up front -- a key you pressed while the dice
    ' were still rolling should advance THIS prompt (draining it here made every
    ' '[ press any key ]' need a second press). We only drain AFTER advancing so
    ' the advance key can't spill into the next attack.
    IF opt_msgdelay <= 0 THEN                       ' 0 = wait for a keypress (manual)
        DO: _LIMIT 60: _DISPLAY: LOOP UNTIL INKEY$ <> ""
        FlashPrompt: _KEYCLEAR: EXIT SUB
    END IF
    ' TIMED: this prompt will auto-advance, so '[ press any key ]' is misleading.
    ' Rewrite just the prompt line of the already-drawn banner to '[ press to skip ]'
    ' (same length -> the auto-sized box still fits). WaitKey prompts never call this,
    ' so their honest 'press any key' stays put.
    IF INSTR(bnr_l2, "[ press any key ]") > 0 THEN
        DIM l2s AS STRING
        l2s = StrSubst$(bnr_l2, "[ press any key ]", "[ press to skip ]")
        _DEST CANVAS: _FONT CH
        LINE ((bnr_bx1 + 1) * CW, 27 * CH)-((bnr_bx2 - 1) * CW, 28 * CH), BOXBG, BF
        COLOR YELLOWU, BOXBG: PrintCentered 27, l2s
        bnr_l2 = l2s
        _DISPLAY
    END IF
    maxf = opt_msgdelay * 60                        ' else auto-advance after the delay...
    FOR f = 1 TO maxf
        _LIMIT 60
        IF INKEY$ <> "" THEN FlashPrompt: EXIT FOR  ' ...or ANY key advances early (with feedback)
        _DISPLAY
    NEXT f
    _KEYCLEAR                      ' drain the advance key so it can't trigger the next round
END SUB



FUNCTION RollDie% (sides AS INTEGER)
    RollDie = INT(RND * sides) + 1
END FUNCTION


' One tone at the current SFX volume.  All effects route through here so the
' SFX Vol slider (opt_sfxvol, 0..10) scales every sound at once.
SUB Tone (freq AS INTEGER, dur AS SINGLE)
    SOUND freq, dur, opt_sfxvol / 10
END SUB


' Named sound effects (SOUND queues in the background, so short sequences play out).

SUB Sfx (kind AS STRING)
    IF NOT opt_sfx THEN EXIT SUB
    SELECT CASE kind
        CASE "move": Tone 350, 0.08
        CASE "bump": Tone 170, 0.12
        CASE "door": Tone 300, 0.06: Tone 520, 0.09
        CASE "strongdoor": Tone 120, 0.14: Tone 85, 0.12       ' heavy thud on a reinforced door
        CASE "breakdoor": Tone 300, 0.04: Tone 180, 0.05: Tone 500, 0.04: Tone 70, 0.22  ' splintering crash
        CASE "secret": Tone 700, 0.05: Tone 950, 0.05: Tone 1250, 0.12
        CASE "secretpass": Tone 1100, 0.04: Tone 820, 0.04: Tone 1300, 0.09
        CASE "key": Tone 660, 0.06: Tone 880, 0.06: Tone 1174, 0.06: Tone 1568, 0.18
        CASE "idle": Tone 130, 0.1: Tone 98, 0.16
        CASE "treasure": Tone 820, 0.05: Tone 1040, 0.05: Tone 1320, 0.12
        CASE "trap": Tone 240, 0.1: Tone 150, 0.14: Tone 90, 0.22
        CASE "hit": Tone 620, 0.05: Tone 320, 0.12
        CASE "miss": Tone 200, 0.14
        CASE "crit": Tone 700, 0.05: Tone 950, 0.05: Tone 1200, 0.05: Tone 1600, 0.14
        CASE "fumble": Tone 320, 0.08: Tone 210, 0.1: Tone 120, 0.18
        CASE "search": Tone 300, 0.05: Tone 260, 0.05
        CASE "win": Tone 523, 0.12: Tone 659, 0.12: Tone 784, 0.12: Tone 1046, 0.28
        CASE "lose": Tone 300, 0.16: Tone 220, 0.16: Tone 130, 0.34
        CASE "saveok": Tone 784, 0.07: Tone 1046, 0.07: Tone 1318, 0.18   ' bright rising -- saved!
        CASE "savebad": Tone 392, 0.12: Tone 294, 0.14: Tone 196, 0.28    ' sad descending -- failed
        CASE "chest": Tone 240, 0.05: Tone 190, 0.06: Tone 320, 0.05: Tone 150, 0.18   ' creak + clunk (lid opens)
        CASE "boom": Tone 130, 0.05: Tone 90, 0.10: Tone 60, 0.24         ' bomb -- low blast
        CASE "hiss": Tone 2000, 0.04: Tone 1700, 0.04: Tone 1450, 0.05: Tone 1200, 0.08   ' darts -- hiss
        CASE "fizzle": Tone 1000, 0.03: Tone 1300, 0.03: Tone 800, 0.03: Tone 1100, 0.03: Tone 700, 0.06   ' frost -- crackle
        CASE "alarm": Tone 800, 0.1: Tone 1050, 0.1: Tone 800, 0.1: Tone 1050, 0.16   ' siren -- wail
        CASE "select": Tone 220, 0.06
    END SELECT
END SUB


' A single "voice" blip for the typewriter text window, at the Voice volume.
SUB VoiceBlip (freq AS INTEGER)
    IF NOT opt_voice THEN EXIT SUB
    SOUND freq, 0.03, opt_voicevol / 10
END SUB


' Scrolling text window: type `body` out one character at a time (word-wrapped)
' inside a framed box, blipping the voice per glyph.  A keypress fast-forwards
' the reveal; another dismisses it.  Great for lore / narration.
SUB ScrollText (title AS STRING, body AS STRING)
    DIM AS INTEGER bx, by, bw, bh, i, maxcols, skip, ln, p, nl
    DIM word AS STRING, acc AS STRING, wrapped AS STRING, c1 AS STRING, k AS STRING
    DIM shown AS STRING, piece AS STRING
    bx = 20: by = 12: bw = 92: bh = 26
    maxcols = bw - 8
    ' greedy word-wrap into `wrapped` with CHR$(10) line breaks
    acc = "": wrapped = "": word = ""
    DIM src AS STRING: src = body + " "
    FOR i = 1 TO LEN(src)
        c1 = MID$(src, i, 1)
        IF c1 = " " THEN
            IF LEN(acc) + LEN(word) + 1 > maxcols THEN
                wrapped = wrapped + acc + CHR$(10): acc = word
            ELSEIF LEN(acc) = 0 THEN
                acc = word
            ELSE
                acc = acc + " " + word
            END IF
            word = ""
        ELSE
            word = word + c1
        END IF
    NEXT i
    IF LEN(acc) > 0 THEN wrapped = wrapped + acc

    skip = FALSE
    FOR i = 1 TO LEN(wrapped)
        c1 = MID$(wrapped, i, 1)
        _DEST CANVAS
        LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), BOXBG, BF
        LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + bh) * CH), CYANU, B
        COLOR YELLOWU, BOXBG: PrintCentered by + 2, "-=  " + title + "  =-"
        ' draw everything revealed so far, split on the wrap breaks
        shown = LEFT$(wrapped, i)
        ln = 0: p = 1
        COLOR WHITE, BOXBG
        DO
            nl = INSTR(p, shown, CHR$(10))
            IF nl = 0 THEN piece = MID$(shown, p) ELSE piece = MID$(shown, p, nl - p)
            _PRINTSTRING ((bx + 4) * CW, (by + 5 + ln) * CH), piece
            IF nl = 0 THEN EXIT DO
            p = nl + 1: ln = ln + 1
        LOOP
        COLOR CYANU, BOXBG: PrintCentered by + bh - 2, "[ any key to continue ]"
        _DISPLAY
        IF c1 <> CHR$(10) AND c1 <> " " THEN VoiceBlip 380 + (ASC(c1) MOD 12) * 40
        IF NOT skip THEN
            k = INKEY$
            IF k <> "" THEN skip = TRUE
            _LIMIT 45
        END IF
    NEXT i
    ' hold on the fully-revealed text
    _KEYCLEAR
    DO: _LIMIT 60: k = INKEY$: _DISPLAY: LOOP UNTIL k <> ""
END SUB


' A single square pip.

SUB Pip (x AS INTEGER, y AS INTEGER, r AS INTEGER, col AS _UNSIGNED LONG)
    LINE (x - r, y - r)-(x + r, y + r), col, BF
END SUB


' Draw one d6 face (value 1-6) as an sz x sz die at pixel (px,py).

SUB DrawDie (px AS INTEGER, py AS INTEGER, sz AS INTEGER, pips AS INTEGER)
    DIM AS INTEGER x2, y2, r, cxl, cxm, cxr, cyt, cym, cyb
    DIM AS _UNSIGNED LONG face, edge, pipc
    face = _RGB32(&HF0, &HF0, &HE6): edge = _RGB32(&H78, &H78, &H70): pipc = _RGB32(&H18, &H10, &H10)
    x2 = px + sz: y2 = py + sz
    LINE (px + 5, py + 5)-(x2 + 5, y2 + 5), _RGB32(&H00, &H00, &H00), BF   ' drop shadow
    LINE (px, py)-(x2, y2), face, BF
    LINE (px, py)-(x2, y2), edge, B
    r = sz \ 11
    cxl = px + sz \ 4: cxm = px + sz \ 2: cxr = x2 - sz \ 4
    cyt = py + sz \ 4: cym = py + sz \ 2: cyb = y2 - sz \ 4
    IF pips = 1 OR pips = 3 OR pips = 5 THEN Pip cxm, cym, r, pipc
    IF pips >= 2 THEN
        Pip cxl, cyt, r, pipc
        Pip cxr, cyb, r, pipc
    END IF
    IF pips >= 4 THEN
        Pip cxr, cyt, r, pipc
        Pip cxl, cyb, r, pipc
    END IF
    IF pips = 6 THEN
        Pip cxl, cym, r, pipc
        Pip cxr, cym, r, pipc
    END IF
END SUB


' Tumble n d6 on screen (with a rolling sound), settle on the result, and
' return the total. The individual faces land in die_a / die_b.

FUNCTION RollDiceShow% (n AS INTEGER)
    RollDiceShow = RollPips(n, FALSE, 0, "")
END FUNCTION


' The line drawn beneath a settled roll. With a modifier it spells out the maths
' so the player sees where the final number comes from ("5 + 3 = 8", "17 + 7 = 24");
' without one it's the plain "sum" of a multi-die roll, or nothing for a lone die.
' `dropped` prefixes the 4d6-drop-lowest note.
FUNCTION RollLineText$ (roll AS INTEGER, bonus AS INTEGER, ndice AS INTEGER, dropped AS INTEGER)
    DIM s AS STRING, bt AS STRING
    IF bonus > 0 THEN
        bt = " + " + _TRIM$(STR$(bonus))
    ELSEIF bonus < 0 THEN
        bt = " - " + _TRIM$(STR$(-bonus))
    END IF
    IF bonus <> 0 THEN
        s = _TRIM$(STR$(roll)) + bt + " = " + _TRIM$(STR$(roll + bonus))
    ELSEIF ndice > 1 THEN
        s = "sum  " + _TRIM$(STR$(roll))
    ELSE
        RollLineText$ = "": EXIT FUNCTION
    END IF
    IF dropped THEN s = "drop lowest -- " + s
    RollLineText$ = s
END FUNCTION


' Reveal the roll math one beat at a time inside the dice box -- roll ... + ...
' bonus ... = ... total -- with a rising tick per beat and a bright ding on the
' total. Builds tension. Any key skips the remaining delays. bx1/bx2 = box cols,
' mrow = the math row. Nothing to reveal for a single die with no bonus.
SUB RevealMath (bx1 AS INTEGER, bx2 AS INTEGER, mrow AS INTEGER, roll AS INTEGER, bonus AS INTEGER, ndice AS INTEGER, dropped AS INTEGER)
    DIM parts(1 TO 6) AS STRING, np AS INTEGER, i AS INTEGER, j AS INTEGER, acc AS STRING, skip AS INTEGER
    np = 0
    IF bonus <> 0 THEN
        np = 5
        parts(1) = _TRIM$(STR$(roll))
        IF bonus > 0 THEN parts(2) = "  +" ELSE parts(2) = "  -"
        parts(3) = "  " + _TRIM$(STR$(ABS(bonus)))
        parts(4) = "  ="
        parts(5) = "  " + _TRIM$(STR$(roll + bonus))
    ELSEIF ndice > 1 THEN
        np = 2
        parts(1) = "sum"
        parts(2) = "  " + _TRIM$(STR$(roll))
    ELSE
        EXIT SUB
    END IF
    acc = "": IF dropped THEN acc = "drop lowest -- "
    skip = FALSE
    _DEST CANVAS: _FONT CH
    FOR i = 1 TO np
        acc = acc + parts(i)
        LINE ((bx1 + 1) * CW, mrow * CH)-((bx2 - 1) * CW, (mrow + 1) * CH), BOXBG, BF
        COLOR YELLOWU, BOXBG: PrintCentered mrow, acc
        _DISPLAY
        IF opt_sfx THEN
            IF i = np THEN Tone 1100, 0.15 ELSE Tone 440 + i * 130, 0.06   ' rising ticks; bright ding on the total
        END IF
        IF NOT skip THEN
            FOR j = 1 TO 22                                       ' ~0.36s of suspense per beat
                _LIMIT 60
                IF INKEY$ <> "" THEN skip = -1: EXIT FOR
                _DISPLAY
            NEXT j
        END IF
    NEXT i
END SUB


' Tumble n pip d6 and return the total. `caption` (e.g. "attacking the GOBLINS")
' is shown atop the box so the player knows WHAT the roll is for. With `droplow`
' set, the lowest die is greyed out where it lands and left OUT of the total --
' exactly the 4d6-drop-lowest ability roll, shown honestly, not as a bare number.
FUNCTION RollPips% (n AS INTEGER, droplow AS INTEGER, bonus AS INTEGER, caption AS STRING)
    DIM AS INTEGER sz, gap, diceW, bx, by, f, j, tot, lo, drop
    DIM v(1 TO 8) AS INTEGER
    DIM frames AS INTEGER, rate AS INTEGER, settle AS INTEGER, hold AS SINGLE
    DIM cx AS INTEGER, boxw AS INTEGER, contentw AS INTEGER, textw AS INTEGER
    DIM x1 AS INTEGER, x2 AS INTEGER, ytop AS INTEGER, ybot AS INTEGER, hdr AS STRING, rln AS STRING
    DIM ff AS INTEGER, av AS INTEGER, dxp AS INTEGER
    IF n < 1 THEN n = 1
    IF n > 8 THEN n = 8
    sz = 52: gap = 18
    IF n > 3 THEN sz = 40: gap = 12          ' shrink so four dice still sit comfortably
    diceW = n * sz + (n - 1) * gap

    tot = 0
    FOR j = 1 TO n: v(j) = RollDie(6): tot = tot + v(j): NEXT j
    drop = 0
    IF droplow AND n > 1 THEN
        lo = v(1): drop = 1
        FOR j = 2 TO n
            IF v(j) < lo THEN lo = v(j): drop = j
        NEXT j
        tot = tot - lo
    END IF
    die_a = v(1): die_b = 0
    IF n >= 2 THEN die_b = v(2)
    rln = RollLineText$(tot, bonus, n, drop > 0)     ' "5 + 3 = 8", "sum 12", or ""

    IF opt_showdice THEN
        ' box sized to the wider of the dice row and the caption / result lines
        hdr = ""
        IF LEN(_TRIM$(caption)) > 0 THEN hdr = "-= " + _TRIM$(caption) + " =-"
        textw = LEN(hdr) * CW
        IF LEN(rln) * CW > textw THEN textw = LEN(rln) * CW
        contentw = diceW
        IF textw > contentw THEN contentw = textw
        boxw = contentw + 6 * CW
        cx = SW * CW \ 2
        x1 = cx - boxw \ 2: x2 = cx + boxw \ 2
        bx = cx - diceW \ 2                   ' dice centred within the box
        by = 33 * CH                          ' the row the dice settle into
        ytop = by - 9 * CH: ybot = by + sz + 2 * CH   ' tall box -- room to bounce

        ' physics: pip dice fall + bounce off the walls/floor, then ease into the row
        DIM px(1 TO 8) AS SINGLE, py(1 TO 8) AS SINGLE, vx(1 TO 8) AS SINGLE, vy(1 TO 8) AS SINGLE
        DIM sxp(1 TO 8) AS SINGLE, syp(1 TO 8) AS SINGLE, tt AS SINGLE
        DIM leftw AS INTEGER, rightw AS INTEGER, floory AS INTEGER
        leftw = x1 + 2 * CW: rightw = x2 - 2 * CW: floory = by
        FOR j = 1 TO n
            px(j) = leftw + RND * (rightw - leftw - sz)
            py(j) = ytop + 2 * CH + RND * CH
            vx(j) = (RND - 0.5) * 11: vy(j) = RND * 2
        NEXT j

        DiceTiming frames, rate, settle, hold
        FOR f = 1 TO frames
            _DEST CANVAS
            LINE (x1, ytop)-(x2, ybot), BOXBG, BF
            LINE (x1, ytop)-(x2, ybot), REDU, B
            IF LEN(hdr) > 0 THEN
                _FONT CH
                COLOR CYANU, BOXBG: PrintCentered ytop \ CH + 1, hdr
            END IF
            IF f = settle THEN
                FOR j = 1 TO n: sxp(j) = px(j): syp(j) = py(j): NEXT j
            END IF
            FOR j = 1 TO n
                IF f < settle THEN
                    vy(j) = vy(j) + 0.7
                    px(j) = px(j) + vx(j): py(j) = py(j) + vy(j)
                    IF px(j) < leftw THEN px(j) = leftw: vx(j) = -vx(j) * 0.6
                    IF px(j) > rightw - sz THEN px(j) = rightw - sz: vx(j) = -vx(j) * 0.6
                    IF py(j) > floory THEN py(j) = floory: vy(j) = -vy(j) * 0.55: vx(j) = vx(j) * 0.85
                    DrawDie px(j), py(j), sz, RollDie(6)
                ELSE
                    tt = (f - settle) / (frames - settle): IF tt > 1 THEN tt = 1
                    DrawDie sxp(j) + (bx + (j - 1) * (sz + gap) - sxp(j)) * tt, syp(j) + (by - syp(j)) * tt, sz, v(j)
                END IF
            NEXT j
            IF opt_sfx THEN
                IF f = settle THEN Tone 240, 0.09 ELSE Tone 300 + (f MOD 5) * 40, 0.04
            END IF
            _DISPLAY
            _LIMIT rate
        NEXT f
        ' fade the discarded die out -- it dissolves into the box, then the result
        ' line (with that die dropped) is revealed
        IF drop > 0 THEN
            dxp = bx + (drop - 1) * (sz + gap)
            FOR ff = 0 TO 12
                DrawDie dxp, by, sz, v(drop)
                av = ff * 22: IF av > 255 THEN av = 255
                LINE (dxp - 4, by - 4)-(dxp + sz + 9, by + sz + 9), _RGBA32(&H20, &H00, &H00, av), BF
                IF opt_sfx AND ff = 5 THEN Tone 170, 0.06
                _DISPLAY
                _LIMIT 40
            NEXT ff
            LINE (dxp - 4, by - 4)-(dxp + sz + 9, by + sz + 9), BOXBG, BF
            _DISPLAY
        END IF
        RevealMath x1 \ CW, x2 \ CW, ybot \ CH - 1, tot, bonus, n, drop > 0   ' slow, tense math reveal
        _DELAY hold                  ' hold so the settled dice are readable
    END IF

    RollPips = tot
END FUNCTION


' Unified roll: n d6 plus a modifier. In Real-Dice mode the player rolls their
' own dice and types the result (and, per the Dice-Math setting, either adds the
' modifier themselves or lets the game add it). Otherwise the game rolls on screen.
FUNCTION DoRoll% (n AS INTEGER, bonus AS INTEGER, what AS STRING)
    DoRoll = GameRoll(n, 6, bonus, what)
END FUNCTION


' Generalised roll: n dice of any size (d6 shows pips, others show a number
' tumbler) plus a modifier -- honouring Real-Dice / Dice-Math exactly like DoRoll.
' Used by D&D-mode combat for d20 to-hit and weapon damage dice.
FUNCTION GameRoll% (n AS INTEGER, sides AS INTEGER, bonus AS INTEGER, what AS STRING)
    DIM raw AS INTEGER, t AS INTEGER
    IF opt_realdice THEN
        raw = PromptRoll(n, sides, bonus, what)
        die_a = 0: die_b = 0
        IF opt_dicemath THEN
            GameRoll = raw: last_raw = raw - bonus
        ELSE
            GameRoll = raw + bonus: last_raw = raw
        END IF
    ELSEIF sides = 6 AND opt_d6pips THEN
        t = RollPips(n, FALSE, bonus, what)        ' every d6 roll shows the pip dice
        GameRoll = t + bonus: last_raw = t
    ELSE
        t = ShowRollText(n, sides, bonus, what)    ' polyhedra from the DPoly die fonts
        GameRoll = t + bonus: last_raw = t
    END IF
END FUNCTION


' ============================================================================
'  POLYHEDRON DICE -- rendered from the DPoly OTF dice fonts (assets/fonts/dpoly)
'
'  Every glyph in these fonts IS a die face, so a d20 showing 17 is literally the
'  character 'Q' printed in the d20 font. Two variants share each face:
'      UPPERCASE 'A'+n  -> the SOLID die (filled body, number knocked out)
'      lowercase 'a'+n  -> the OUTLINE die (hollow body, solid number)
'  Printing the solid variant in a body colour and then the outline variant on
'  top in an ink colour (with _PRINTMODE _KEEPBACKGROUND, so pass 2 doesn't erase
'  pass 1) gives a filled die with a CONTRASTING number -- which neither variant
'  produces on its own. See DrawFontDie.
'
'  NOTE: the fonts' own d6 is a numbered square, so d6 rolls default to the
'  hand-drawn pip dice (DrawDie) instead -- toggled by the D6 Style setting.
' ============================================================================

' Load the six DPoly die fonts. A handle of 0 means the font is missing, and the
' roll silently falls back to the number tumbler -- never a crash.
'
' Deliberately NOT loaded "monospace": that flag squeezes every glyph into a fixed
' cell narrower than the point size (d20 @56pt -> a 49px cell), which CLIPS the
' left and right points off the polyhedra. Proportional loading keeps each die
' whole; DieWidth measures the real advance with _PRINTWIDTH.
SUB InitDice
    CONST FP = "assets/fonts/dpoly/"
    CONST PT = 56
    DFONT(4) = _LOADFONT(FP + "DPoly Four-Sider.otf", PT)
    DFONT(6) = _LOADFONT(FP + "DPoly Six-Sider.otf", PT)
    DFONT(8) = _LOADFONT(FP + "DPoly Eight-Sider.otf", PT)
    DFONT(10) = _LOADFONT(FP + "DPoly Ten-Sider.otf", PT)
    DFONT(12) = _LOADFONT(FP + "DPoly Twelve-Sider.otf", PT)
    DFONT(20) = _LOADFONT(FP + "DPoly Twenty-Sider.otf", PT)
    DFROT = _NEWIMAGE(DFROT_W, DFROT_H, 32)      ' scratch for the tumble-spin rotation
END SUB


' Render a font die into the DFROT scratch image (transparent background), centred,
' so it can be rotate-blitted while it tumbles. Mirrors DrawFontDie's two-pass look.
SUB RenderDieToScratch (sides AS INTEGER, face AS INTEGER)
    DIM fh AS LONG, code AS INTEGER, body AS _UNSIGNED LONG, ink AS _UNSIGNED LONG
    DIM od AS LONG, ox AS INTEGER, oy AS INTEGER, dw AS INTEGER
    IF sides < 1 OR sides > 20 THEN EXIT SUB
    fh = DFONT(sides): IF fh <= 0 THEN EXIT SUB
    IF DFROT = 0 THEN EXIT SUB
    DiceColors body, ink
    code = DieGlyphCode(sides, face)
    dw = DieWidth(sides): IF dw < 8 THEN dw = 56
    od = _DEST
    _DEST DFROT
    CLS , _RGBA32(0, 0, 0, 0)                     ' transparent
    _FONT fh
    _PRINTMODE _KEEPBACKGROUND
    ox = (DFROT_W - dw) \ 2
    oy = (DFROT_H - _FONTHEIGHT(fh)) \ 2 + _FONTHEIGHT(fh) \ 4   ' nudge down (top vertex draws above pen)
    IF opt_dicesolid THEN
        COLOR body, _RGBA32(0, 0, 0, 0): _UPRINTSTRING (ox, oy), CHR$(65 + code)
        COLOR ink, _RGBA32(0, 0, 0, 0): _UPRINTSTRING (ox, oy), CHR$(97 + code)
    ELSE
        COLOR body, _RGBA32(0, 0, 0, 0): _UPRINTSTRING (ox, oy), CHR$(97 + code)
    END IF
    _PRINTMODE _FILLBACKGROUND
    _FONT CH
    _DEST od
END SUB


' Rotate the WxH image `src` around its own centre by `ang` radians and draw it
' centred at (cx,cy) on `dst`. Two _MAPTRIANGLEs = one textured quad (nearest-
' neighbour, so the die stays crisp/pixelated to match the ANSI art).
SUB RotoBlit (src AS LONG, w AS INTEGER, h AS INTEGER, cx AS SINGLE, cy AS SINGLE, ang AS SINGLE, dst AS LONG)
    DIM ca AS SINGLE, sa AS SINGLE, hw AS SINGLE, hh AS SINGLE, od AS LONG
    DIM x1 AS SINGLE, y1 AS SINGLE, x2 AS SINGLE, y2 AS SINGLE
    DIM x3 AS SINGLE, y3 AS SINGLE, x4 AS SINGLE, y4 AS SINGLE
    ca = COS(ang): sa = SIN(ang)
    hw = w / 2: hh = h / 2
    x1 = cx + (-hw) * ca - (-hh) * sa: y1 = cy + (-hw) * sa + (-hh) * ca   ' TL
    x2 = cx + (hw) * ca - (-hh) * sa: y2 = cy + (hw) * sa + (-hh) * ca     ' TR
    x3 = cx + (hw) * ca - (hh) * sa: y3 = cy + (hw) * sa + (hh) * ca       ' BR
    x4 = cx + (-hw) * ca - (hh) * sa: y4 = cy + (-hw) * sa + (hh) * ca     ' BL
    od = _DEST: _DEST dst
    _MAPTRIANGLE (0, 0)-(w - 1, 0)-(w - 1, h - 1), src TO (x1, y1)-(x2, y2)-(x3, y3)
    _MAPTRIANGLE (0, 0)-(w - 1, h - 1)-(0, h - 1), src TO (x1, y1)-(x3, y3)-(x4, y4)
    _DEST od
END SUB


' Actual on-screen width of one die face in `sides`' font (proportional fonts
' report _FONTWIDTH = 0, so the glyph has to be measured instead). Uses the
' Unicode metric to match _UPRINTSTRING, which is what DrawFontDie renders with.
FUNCTION DieWidth% (sides AS INTEGER)
    DIM fh AS LONG, w AS INTEGER
    DieWidth = 0
    IF sides < 1 OR sides > 20 THEN EXIT FUNCTION
    fh = DFONT(sides)
    IF fh <= 0 THEN EXIT FUNCTION
    _DEST CANVAS
    _FONT fh
    w = _UPRINTWIDTH("A")
    _FONT CH
    DieWidth = w
END FUNCTION


' Tumble pacing for the player's Dice Speed setting: how many frames the dice
' flicker, how fast those frames run, and how long the result is held.
' `settle` is the frame at which the dice stop being random and show the result.
SUB DiceTiming (frames AS INTEGER, rate AS INTEGER, settle AS INTEGER, hold AS SINGLE)
    SELECT CASE opt_dicespeed
        CASE 0: frames = 30: rate = 14: hold = 1.2      ' Slow -- watch them tumble
        CASE 2: frames = 11: rate = 36: hold = 0.45     ' Fast
        CASE 3: frames = 2: rate = 60: hold = 0.25      ' Instant -- barely a flicker
        CASE ELSE: frames = 17: rate = 22: hold = 0.7   ' Normal
    END SELECT
    settle = frames - 3
    IF settle < 1 THEN settle = 1
END SUB


' Which glyph slot (0-based, 0 = 'A'/'a') shows `face` on a `sides`-sided die.
' Every die starts at face 1 in slot 0 -- EXCEPT the d10, whose first glyph is the
' 0 face, so a rolled 10 draws that 0 exactly like a real ten-sider.
FUNCTION DieGlyphCode% (sides AS INTEGER, face AS INTEGER)
    IF sides = 10 THEN
        IF face >= 10 THEN DieGlyphCode = 0 ELSE DieGlyphCode = face
    ELSE
        DieGlyphCode = face - 1
    END IF
END FUNCTION


' The player's chosen dice palette: `body` fills the die, `ink` draws its number.
' Swap the working dice config to the MONSTER's look for the duration of a monster
' roll, then restore. Wrap each monster GameRoll/DoRoll in a Push/Pop pair so the
' player's dice look is never left swapped (even if combat exits mid-roll).
SUB PushMonsterDice
    sav_dicecolor = opt_dicecolor: sav_dicesolid = opt_dicesolid
    sav_d6pips = opt_d6pips: sav_dicespeed = opt_dicespeed
    opt_dicecolor = opt_mon_dicecolor: opt_dicesolid = opt_mon_dicesolid
    opt_d6pips = opt_mon_d6pips: opt_dicespeed = opt_mon_dicespeed
END SUB
SUB PopMonsterDice
    opt_dicecolor = sav_dicecolor: opt_dicesolid = sav_dicesolid
    opt_d6pips = sav_d6pips: opt_dicespeed = sav_dicespeed
END SUB


SUB DiceColors (body AS _UNSIGNED LONG, ink AS _UNSIGNED LONG)
    SELECT CASE opt_dicecolor
        CASE 0: body = _RGB32(&HEC, &HE4, &HD0): ink = _RGB32(&H1A, &H10, &H0C)   ' Bone
        CASE 1: body = _RGB32(&HC4, &H22, &H22): ink = _RGB32(&HFF, &HEE, &HEE)   ' Blood
        CASE 2: body = _RGB32(&H1E, &HA0, &H55): ink = _RGB32(&HF0, &HFF, &HF0)   ' Emerald
        CASE 3: body = _RGB32(&H36, &H72, &HD8): ink = _RGB32(&HF0, &HF6, &HFF)   ' Sapphire
        CASE 4: body = _RGB32(&HD8, &HA8, &H20): ink = _RGB32(&H24, &H1A, &H00)   ' Gold
        CASE ELSE: body = _RGB32(&H8A, &H4C, &HC8): ink = _RGB32(&HF8, &HF0, &HFF) ' Amethyst
    END SELECT
END SUB


FUNCTION ColorName$ (idx AS INTEGER)
    SELECT CASE idx
        CASE 0: ColorName$ = "Bone"
        CASE 1: ColorName$ = "Blood"
        CASE 2: ColorName$ = "Emerald"
        CASE 3: ColorName$ = "Sapphire"
        CASE 4: ColorName$ = "Gold"
        CASE ELSE: ColorName$ = "Amethyst"
    END SELECT
END FUNCTION

FUNCTION DiceColorName$ ()
    DiceColorName$ = ColorName$(opt_dicecolor)
END FUNCTION


' Draw one polyhedron at pixel (px,py) showing `face`. Solid finish = two passes
' (body then ink); outline finish = the hollow variant in the body colour.
SUB DrawFontDie (px AS INTEGER, py AS INTEGER, sides AS INTEGER, face AS INTEGER)
    DIM fh AS LONG, code AS INTEGER
    DIM body AS _UNSIGNED LONG, ink AS _UNSIGNED LONG
    IF sides < 1 OR sides > 20 THEN EXIT SUB
    fh = DFONT(sides)
    IF fh <= 0 THEN EXIT SUB
    DiceColors body, ink
    code = DieGlyphCode(sides, face)
    _DEST CANVAS
    _FONT fh
    _PRINTMODE _KEEPBACKGROUND          ' vital: pass 2 must not blank pass 1
    ' _UPRINTSTRING, not _PRINTSTRING: _PRINTSTRING clips each glyph to the font
    ' CELL, and these dice draw their top vertex ABOVE the cell -- so the point
    ' gets sliced flat. The Unicode printer renders the whole glyph, point intact.
    IF opt_dicesolid THEN
        COLOR body, BOXBG
        _UPRINTSTRING (px, py), CHR$(65 + code)      ' filled body
        COLOR ink, BOXBG
        _UPRINTSTRING (px, py), CHR$(97 + code)      ' outline + number over it
    ELSE
        COLOR body, BOXBG
        _UPRINTSTRING (px, py), CHR$(97 + code)      ' hollow die only
    END IF
    _PRINTMODE _FILLBACKGROUND
    _FONT CH                            ' back to the 8x16 game font
END SUB


' Tumble n polyhedra, settle on their rolled values, and return the sum.
FUNCTION ShowRollText% (n AS INTEGER, sides AS INTEGER, bonus AS INTEGER, what AS STRING)
    ShowRollText = ShowRollTextEx(n, sides, FALSE, bonus, what)
END FUNCTION


' As ShowRollText, but with `droplow` the lowest die FADES away after landing and
' is left OUT of the total -- the font-dice twin of RollPips' drop-lowest display,
' so 4d6-drop-lowest animates properly whichever D6 Style the player picked.
FUNCTION ShowRollTextEx% (n AS INTEGER, sides AS INTEGER, droplow AS INTEGER, bonus AS INTEGER, what AS STRING)
    DIM v(1 TO 12) AS INTEGER, i AS INTEGER, total AS INTEGER, f AS INTEGER, shown AS INTEGER, av AS INTEGER
    DIM fh AS LONG, dw AS INTEGER, dh AS INTEGER, gap AS INTEGER, rowW AS INTEGER
    DIM dx AS INTEGER, dy AS INTEGER, x1 AS INTEGER, y1 AS INTEGER, x2 AS INTEGER, y2 AS INTEGER
    DIM frames AS INTEGER, rate AS INTEGER, settle AS INTEGER, hold AS SINGLE
    DIM lo AS INTEGER, drop AS INTEGER, dxi AS INTEGER
    DIM hdr AS STRING, textw AS INTEGER, contentw AS INTEGER, boxw AS INTEGER, cx AS INTEGER, rln AS STRING
    IF n > 12 THEN n = 12
    total = 0
    FOR i = 1 TO n: v(i) = RollDie(sides): total = total + v(i): NEXT i
    drop = 0
    IF droplow AND n > 1 THEN
        lo = v(1): drop = 1
        FOR i = 2 TO n
            IF v(i) < lo THEN lo = v(i): drop = i
        NEXT i
        total = total - lo
    END IF
    rln = RollLineText$(total, bonus, n, drop > 0)     ' "5 + 3 = 8", "sum 12", or ""
    IF NOT opt_showdice THEN ShowRollTextEx = total: EXIT FUNCTION

    fh = 0
    IF sides >= 1 AND sides <= 20 THEN fh = DFONT(sides)
    IF fh <= 0 THEN                     ' no die font this size -- plain number tumbler
        ShowRollTextEx = ShowRollValue(total, n * sides, "rolling " + _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides)))
        EXIT FUNCTION
    END IF

    dw = DieWidth(sides): dh = _FONTHEIGHT(fh)
    IF dw < 8 THEN dw = 56
    gap = 14
    rowW = n * dw + (n - 1) * gap
    ' Caption: WHAT the roll is for (e.g. "to hit the GOBLINS"), falling back to
    ' the dice notation when no purpose was given. The box has to fit its widest
    ' TEXT line -- caption or result line -- else a single narrow die leaves the
    ' header spilling out both sides of the box.
    IF LEN(_TRIM$(what)) > 0 THEN
        hdr = "-= " + _TRIM$(what) + " =-"
    ELSE
        hdr = "-= rolling " + _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides)) + " =-"
    END IF
    textw = LEN(hdr) * CW
    IF LEN(rln) * CW > textw THEN textw = LEN(rln) * CW
    contentw = rowW
    IF textw > contentw THEN contentw = textw
    boxw = contentw + 6 * CW                 ' ~24px breathing room each side
    cx = SW * CW \ 2
    x1 = cx - boxw \ 2: x2 = cx + boxw \ 2
    dx = cx - rowW \ 2                        ' dice centred within the box
    dy = 33 * CH                              ' the row the dice settle into
    y1 = dy - 9 * CH: y2 = dy + dh + 2 * CH    ' tall box -- room to bounce down into the row

    ' physics: each die falls under gravity and bounces off the box walls/floor
    ' with damping, flashing random faces, then eases into its neat row slot.
    DIM px(1 TO 12) AS SINGLE, py(1 TO 12) AS SINGLE, vx(1 TO 12) AS SINGLE, vy(1 TO 12) AS SINGLE
    DIM sxp(1 TO 12) AS SINGLE, syp(1 TO 12) AS SINGLE, tt AS SINGLE
    DIM ang(1 TO 12) AS SINGLE, spin(1 TO 12) AS SINGLE
    DIM leftw AS INTEGER, rightw AS INTEGER, floory AS INTEGER
    leftw = x1 + 2 * CW: rightw = x2 - 2 * CW: floory = dy
    FOR i = 1 TO n
        px(i) = leftw + RND * (rightw - leftw - dw)
        py(i) = y1 + 2 * CH + RND * CH
        vx(i) = (RND - 0.5) * 11: vy(i) = RND * 2
        ang(i) = RND * 6.2832: spin(i) = (RND - 0.5) * 0.5   ' random start angle + spin (rad/frame)
    NEXT i

    DiceTiming frames, rate, settle, hold
    FOR f = 1 TO frames
        _DEST CANVAS
        LINE (x1, y1)-(x2, y2), BOXBG, BF
        LINE (x1, y1)-(x2, y2), REDU, B
        _FONT CH
        COLOR CYANU, BOXBG: PrintCentered y1 \ CH + 1, hdr
        IF f = settle THEN
            FOR i = 1 TO n: sxp(i) = px(i): syp(i) = py(i): NEXT i   ' freeze the bounce for the ease
        END IF
        FOR i = 1 TO n
            IF f < settle THEN
                vy(i) = vy(i) + 0.7                                  ' gravity
                px(i) = px(i) + vx(i): py(i) = py(i) + vy(i)
                IF px(i) < leftw THEN px(i) = leftw: vx(i) = -vx(i) * 0.6: spin(i) = -spin(i)
                IF px(i) > rightw - dw THEN px(i) = rightw - dw: vx(i) = -vx(i) * 0.6: spin(i) = -spin(i)
                IF py(i) > floory THEN py(i) = floory: vy(i) = -vy(i) * 0.55: vx(i) = vx(i) * 0.85
                ang(i) = ang(i) + spin(i)                            ' spin as it tumbles; walls reverse it
                RenderDieToScratch sides, RollDie(sides)
                RotoBlit DFROT, DFROT_W, DFROT_H, px(i) + dw \ 2, py(i) + dh \ 2, ang(i), CANVAS
            ELSE
                tt = (f - settle) / (frames - settle): IF tt > 1 THEN tt = 1
                dxi = dx + (i - 1) * (dw + gap)
                DrawFontDie sxp(i) + (dxi - sxp(i)) * tt, syp(i) + (dy - syp(i)) * tt, sides, v(i)
            END IF
        NEXT i
        IF opt_sfx THEN
            IF f = settle THEN Tone 240, 0.09 ELSE Tone 300 + (f MOD 5) * 40, 0.04
        END IF
        _DISPLAY
        _LIMIT rate
    NEXT f
    ' fade the discarded die out -- it dissolves into the box, then the result
    ' line (with that die dropped) is revealed
    IF drop > 0 THEN
        dxi = dx + (drop - 1) * (dw + gap)
        FOR f = 0 TO 12
            DrawFontDie dxi, dy, sides, v(drop)
            av = f * 22: IF av > 255 THEN av = 255
            LINE (dxi - 4, dy - CH)-(dxi + dw + 4, dy + dh + 4), _RGBA32(&H20, &H00, &H00, av), BF
            IF opt_sfx AND f = 5 THEN Tone 170, 0.06
            _DISPLAY
            _LIMIT 40
        NEXT f
        LINE (dxi - 4, dy - CH)-(dxi + dw + 4, dy + dh + 4), BOXBG, BF
        _DISPLAY
    END IF
    ' On a single d20 showing 1 or 20 the math is moot (nat-1 = fumble, nat-20 =
    ' crit, whatever the modifier) -- skip the reveal and let combat proceed.
    IF sides = 20 AND n = 1 AND (total = 1 OR total = 20) THEN
        ' no math -- the die face says it all
    ELSE
        RevealMath x1 \ CW, x2 \ CW, y2 \ CH - 1, total, bonus, n, drop > 0   ' slow, tense math reveal
    END IF
    _DELAY hold
    ShowRollTextEx = total
END FUNCTION


' Animate a number tumbler that flickers random values (1..hi) then settles on a
' KNOWN total -- lets callers (e.g. 4d6-drop-lowest) control what is summed.
FUNCTION ShowRollValue% (total AS INTEGER, hi AS INTEGER, caption AS STRING)
    DIM AS INTEGER f, bx, by, bw, shown
    DIM frames AS INTEGER, rate AS INTEGER, settle AS INTEGER, hold AS SINGLE
    IF opt_showdice THEN
        bw = 46
        bx = (SW - bw) \ 2: by = 32
        DiceTiming frames, rate, settle, hold
        FOR f = 1 TO frames
            IF f < settle THEN shown = INT(RND * hi) + 1 ELSE shown = total
            _DEST CANVAS
            LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + 6) * CH), BOXBG, BF
            LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + 6) * CH), REDU, B
            COLOR CYANU, BOXBG: PrintCentered by + 1, "-= " + caption + " =-"
            COLOR YELLOWU, BOXBG: PrintCentered by + 3, "[  " + _TRIM$(STR$(shown)) + "  ]"
            IF opt_sfx THEN
                IF f = settle THEN Tone 240, 0.09 ELSE Tone 380 + f * 28, 0.05
            END IF
            _DISPLAY
            _LIMIT rate
        NEXT f
        _DELAY hold
    END IF
    ShowRollValue = total
END FUNCTION


' Roll one ability score, honouring the Stat-Roll setting: straight 3d6, or
' 4d6-drop-lowest (the heroic method).  Respects Real Dice + Show Dice.
FUNCTION RollAbility% ()
    IF opt_heroicstats THEN
        IF opt_realdice THEN
            RollAbility = PromptRoll(3, 6, 0, "roll 4d6, DROP lowest, enter top 3")
        ELSEIF opt_d6pips THEN
            RollAbility = RollPips(4, TRUE, 0, "roll 4d6, drop lowest")   ' four pip dice, lowest discarded
        ELSE
            RollAbility = ShowRollTextEx(4, 6, TRUE, 0, "4d6 drop lowest")   ' same, on the font d6
        END IF
    ELSE
        RollAbility = GameRoll(3, 6, 0, "ability score")
    END IF
END FUNCTION


' Ask the player what they physically rolled; validates against the possible range.
FUNCTION PromptRoll% (n AS INTEGER, sides AS INTEGER, bonus AS INTEGER, what AS STRING)
    DIM entry AS STRING, k AS STRING, chcode AS INTEGER, v AS INTEGER   ' NOT "ch" -- shadows CH
    DIM spec AS STRING, l1 AS STRING, msg AS STRING, lo AS INTEGER, hi AS INTEGER
    spec = _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides))
    IF bonus > 0 AND opt_dicemath THEN
        l1 = "Roll " + spec + ", add +" + _TRIM$(STR$(bonus)) + ", and enter the TOTAL:"
        lo = n + bonus: hi = n * sides + bonus
    ELSEIF bonus > 0 THEN
        l1 = "Roll " + spec + " (the game adds +" + _TRIM$(STR$(bonus)) + ") -- enter your DICE:"
        lo = n: hi = n * sides
    ELSE
        l1 = "Roll " + spec + " and enter the result:"
        lo = n: hi = n * sides
    END IF
    entry = "": msg = ""
    DO
        _LIMIT 60
        _DEST CANVAS
        LINE (24 * CW, 19 * CH)-(108 * CW, 31 * CH), BOXBG, BF
        LINE (24 * CW, 19 * CH)-(108 * CW, 31 * CH), CYANU, B
        COLOR YELLOWU, BOXBG: PrintCentered 21, "-=  R E A L   D I C E  =-"
        COLOR CYANU, BOXBG: PrintCentered 22, "(" + what + ")"
        COLOR WHITE, BOXBG: PrintCentered 25, l1
        COLOR GREENU, BOXBG: PrintCentered 28, "> " + entry + "_"
        IF LEN(msg) > 0 THEN COLOR REDU, BOXBG: PrintCentered 30, msg
        _DISPLAY
        k = INKEY$
        IF k <> "" THEN
            IF k = CHR$(13) THEN
                IF LEN(entry) > 0 THEN
                    v = VAL(entry)
                    IF v >= lo AND v <= hi THEN
                        PromptRoll = v: EXIT FUNCTION
                    ELSE
                        msg = "That's not possible -- enter " + _TRIM$(STR$(lo)) + " to " + _TRIM$(STR$(hi)): entry = ""
                    END IF
                END IF
            ELSEIF k = CHR$(8) THEN
                IF LEN(entry) > 0 THEN entry = LEFT$(entry, LEN(entry) - 1)
            ELSEIF LEN(k) = 1 THEN
                chcode = ASC(k)
                IF chcode >= 48 AND chcode <= 57 AND LEN(entry) < 3 THEN entry = entry + k
            END IF
        END IF
    LOOP
END FUNCTION


