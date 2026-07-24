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
SUB DrawCharGen (pc AS INTEGER, sc() AS INTEGER, rolled AS INTEGER, done AS INTEGER)
    DIM i AS INTEGER, y AS INTEGER, nm(1 TO 6) AS STRING, row AS STRING
    nm(1) = "STR": nm(2) = "INT": nm(3) = "WIS": nm(4) = "DEX": nm(5) = "CON": nm(6) = "CHA"
    _DEST CANVAS: CLS , BLACK
    COLOR YELLOWU, BLACK: PrintCentered 3, "R O L L   U P   Y O U R   " + CLASSES(pc).name
    FOR i = 1 TO 6
        y = 9 + (i - 1) * 2
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
        PrintCentered 23, "HIT POINTS  " + _TRIM$(STR$(player_maxhp))
        COLOR CYANU, BLACK
        PrintCentered 25, "AC " + _TRIM$(STR$(player_ac)) + "     To-Hit " + ModStr$(player_tohit) + "     Damage 1d" + _TRIM$(STR$(player_dmgdie)) + " " + ModStr$(player_dmgbonus)
        COLOR YELLOWU, BLACK: PrintCentered 44, "[R] re-roll a new hero      [ENTER] keep this one"
    ELSE
        COLOR CYANU, BLACK: PrintCentered 44, "rolling 3d6 for each ability..."
    END IF
    _DISPLAY
END SUB


' The full generation flow: roll 3d6 for six abilities, roll hit points on the
' class hit die, derive the D&D combat stats, and let the player re-roll.
' Honours Real Dice (each 3d6 becomes a PromptRoll when that setting is on).
SUB RollCharacter (pc AS INTEGER)
    DIM sc(1 TO 6) AS INTEGER, i AS INTEGER, hproll AS INTEGER, atkmod AS INTEGER, k AS STRING
    DO
        FOR i = 1 TO 6
            DrawCharGen pc, sc(), i - 1, 0             ' show sheet, then tumble this ability
            sc(i) = RollAbility                        ' 3d6 or 4d6-drop-low per the Stat-Roll setting
        NEXT i
        player_str = sc(1): player_int = sc(2): player_wis = sc(3)
        player_dex = sc(4): player_con = sc(5): player_cha = sc(6)
        ' hit points: three hit dice + 3x the CON modifier (a level-ish start), min 3
        DrawCharGen pc, sc(), 6, 0
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
        DrawCharGen pc, sc(), 6, -1                    ' final sheet + reroll/keep prompt
        DO
            _LIMIT 60: k = UCASE$(INKEY$): _DISPLAY
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


' Death transition: streaks of blood run down the screen, the whole view reddens,
' then it fades to black.
SUB BloodDrip
    DIM nd AS INTEGER, i AS INTEGER, f AS INTEGER
    DIM dx(1 TO 80) AS INTEGER, dlen(1 TO 80) AS INTEGER, dsp(1 TO 80) AS INTEGER, dw(1 TO 80) AS INTEGER
    DIM dark AS _UNSIGNED LONG, bright AS _UNSIGNED LONG, tint AS _UNSIGNED LONG
    dark = _RGB32(&H72, &H00, &H00): bright = _RGB32(&HC8, &H1A, &H1A): tint = _RGB32(&H55, &H00, &H00, &H07)
    nd = 70
    FOR i = 1 TO nd
        dx(i) = INT(RND * (SW * CW))
        dlen(i) = -INT(RND * (SH * CH))          ' negative = staggered start delay
        dsp(i) = 9 + INT(RND * 18)               ' fall speed
        dw(i) = 3 + INT(RND * 10)                ' streak width
    NEXT i
    _DEST CANVAS
    FOR f = 1 TO 78
        LINE (0, 0)-(SW * CW - 1, SH * CH - 1), tint, BF     ' the view slowly reddens
        FOR i = 1 TO nd
            dlen(i) = dlen(i) + dsp(i)
            IF dlen(i) > 0 THEN
                LINE (dx(i), 0)-(dx(i) + dw(i), dlen(i)), dark, BF
                LINE (dx(i), dlen(i) - 12)-(dx(i) + dw(i), dlen(i) + 6), bright, BF   ' the running drip head
            END IF
        NEXT i
        _DISPLAY
        _LIMIT 60
    NEXT f
    FadeOut                                       ' then to black
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
    CONST NSET = 16
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

        ' A/D adjusts the volume sliders (items 2 / 4 / 6)
        IF k = "A" OR k = "D" THEN
            IF k = "A" THEN delta = -1 ELSE delta = 1
            SELECT CASE sel
                CASE 2: opt_musicvol = Clamp10(opt_musicvol + delta): IF music_handle > 0 THEN _SNDVOL music_handle, opt_musicvol / 10
                CASE 4: opt_sfxvol = Clamp10(opt_sfxvol + delta): Sfx "select"
                CASE 6: opt_voicevol = Clamp10(opt_voicevol + delta): VoiceBlip 700
                CASE 12
                    num_players = num_players + delta
                    IF num_players < 1 THEN num_players = 1
                    IF num_players > 4 THEN num_players = 4
                    IF num_players > 1 THEN opt_boardgame = TRUE ELSE opt_boardgame = FALSE
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
                CASE 10: opt_oldschool = NOT opt_oldschool
                CASE 11
                    opt_boardgame = NOT opt_boardgame
                    IF num_players > 1 THEN opt_boardgame = TRUE   ' multiplayer requires it
                CASE 12
                    num_players = num_players + 1: IF num_players > 4 THEN num_players = 1
                    IF num_players > 1 THEN opt_boardgame = TRUE ELSE opt_boardgame = FALSE
                CASE 13: opt_heroicstats = NOT opt_heroicstats
                CASE 14
                    opt_fullscreen = NOT opt_fullscreen
                    IF opt_fullscreen THEN _FULLSCREEN _SQUAREPIXELS, _SMOOTH ELSE _FULLSCREEN _OFF
                CASE 15: opt_fov = NOT opt_fov
                CASE 16: SaveSettings: EXIT SUB
            END SELECT
            Sfx "select"
        END IF

        _DEST CANVAS: CLS , BLACK
        COLOR YELLOWU, BLACK: PrintCentered 1, "-=  S E T T I N G S  =-"
        FOR i = 1 TO NSET
            y = 3 + (i - 1) * 3
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
                CASE 10
                    lbl = "Oldschool"
                    IF opt_oldschool THEN vtxt = "Dungeon! 2d6" ELSE vtxt = "D&D d20/HP"
                CASE 11
                    lbl = "Boardgame"
                    IF num_players > 1 THEN
                        vtxt = "roll to move (locked)"
                    ELSEIF opt_boardgame THEN
                        vtxt = "roll to move"
                    ELSE
                        vtxt = "free move"
                    END IF
                CASE 12
                    lbl = "Players": slider = TRUE
                    IF num_players > 1 THEN vtxt = _TRIM$(STR$(num_players)) + "  (hot-seat)" ELSE vtxt = "1  (solo)"
                CASE 13
                    lbl = "Stat Roll"
                    IF opt_heroicstats THEN vtxt = "4d6 drop-low" ELSE vtxt = "straight 3d6"
                CASE 14: lbl = "Full Screen": vtxt = OnOff$(opt_fullscreen)
                CASE 15: lbl = "Line of Sight": vtxt = OnOff$(opt_fov)
                CASE ELSE: lbl = "<< Back": vtxt = ""
            END SELECT
            IF i = sel THEN COLOR WHITE, REDU ELSE IF slider THEN COLOR CYANU, BLACK ELSE COLOR GREY, BLACK
            IF i = NSET THEN PrintCentered y, "   " + lbl + "   " ELSE PrintCentered y, "   " + lbl + ":  " + vtxt + "   "
        NEXT i
        COLOR CYANU, BLACK: PrintCentered 49, "[W/S] move   [A/D] adjust   [ENTER] toggle   [ESC] back"
        _DISPLAY
    LOOP
END SUB


SUB ShowCharSheet
    DIM i AS INTEGER, y AS INTEGER, col AS INTEGER, nshow AS INTEGER, inv AS STRING, ln AS STRING
    DIM who AS STRING
    _DEST CANVAS
    LINE (22 * CW, 3 * CH)-(110 * CW, 48 * CH), BOXBG, BF
    LINE (22 * CW, 3 * CH)-(110 * CW, 48 * CH), REDU, B
    who = class_name: IF num_players > 1 THEN who = _TRIM$(player_name) + " the " + class_name
    COLOR YELLOWU, BOXBG: PrintCentered 4, "-=  C H A R A C T E R  =-"
    COLOR WHITE, BOXBG: PrintCentered 6, "Champion:  " + who
    COLOR CYANU, BOXBG
    PrintCentered 7, "STR " + _TRIM$(STR$(player_str)) + "  INT " + _TRIM$(STR$(player_int)) + "  WIS " + _TRIM$(STR$(player_wis)) + "  DEX " + _TRIM$(STR$(player_dex)) + "  CON " + _TRIM$(STR$(player_con)) + "  CHA " + _TRIM$(STR$(player_cha))
    IF NOT opt_oldschool THEN
        COLOR GREENU, BOXBG
        PrintCentered 8, "HP " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + "    AC " + _TRIM$(STR$(player_ac)) + "    To-Hit " + ModStr$(player_tohit) + "    Dmg 1d" + _TRIM$(STR$(player_dmgdie)) + " " + ModStr$(player_dmgbonus)
    END IF
    ' wealth line
    COLOR YELLOWU, BOXBG
    ln = "GOLD  " + _TRIM$(STR$(gold)) + " / " + _TRIM$(STR$(target_gold))
    IF has_key THEN ln = ln + "        LEVEL KEY: HELD" ELSE ln = ln + "        LEVEL KEY: not found"
    PrintCentered 10, ln
    ' special items held
    inv = ""
    IF item_sword > 0 THEN inv = inv + "Magic Sword +" + _TRIM$(STR$(item_sword)) + "    "
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
    COLOR YELLOWU, BOXBG: PrintCentered 45, "[ press any key ]"
    _DISPLAY
    WaitKey
    cursor_erase: cursor_draw: DrawHUD: _DISPLAY
END SUB


' [?] Controls: the single source of truth for key bindings, rendered as a table.
SUB ShowKeys
    DIM ky(1 TO 12) AS STRING, ds(1 TO 12) AS STRING, n AS INTEGER, i AS INTEGER, y AS INTEGER
    ky(1) = "WASD / Arrows": ds(1) = "Move up / left / down / right"
    ky(2) = "Numpad 7 9 1 3": ds(2) = "Move diagonally (NW/NE/SW/SE)"
    ky(3) = "SPACE": ds(3) = "Roll movement dice / Attack"
    ky(4) = "F": ds(4) = "Search for secret doors"
    ky(5) = "C": ds(5) = "Character sheet"
    ky(6) = "V": ds(6) = "Scry the dungeon (Crystal Ball)"
    ky(7) = "?": ds(7) = "This controls list"
    ky(8) = "~  or  `": ds(8) = "Toggle the debug overlay"
    ky(9) = "ESC": ds(9) = "Flee combat / quit to menu"
    ky(10) = "R": ds(10) = "Re-roll (during character creation)"
    n = 10
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
    DIM el AS LONG, tmr AS STRING
    el = TIMER - game_start
    IF el < 0 THEN el = el + 86400
    tmr = _TRIM$(STR$(el \ 60)) + ":" + RIGHT$("0" + _TRIM$(STR$(el MOD 60)), 2)
    DIM hptag AS STRING
    IF NOT opt_oldschool THEN hptag = "   HP " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp))
    DIM movetag AS STRING, ptag AS STRING
    IF opt_boardgame THEN movetag = "   TURN " + _TRIM$(STR$(turn_num)) + "   STEPS " + _TRIM$(STR$(steps_left)) ELSE movetag = "   FREE MOVE"
    IF num_players > 1 THEN ptag = "P" + _TRIM$(STR$(cur_player)) + " " + player_name + "  " ELSE ptag = ""
    LINE (0, 50 * CH)-(SW * CW, 51 * CH), BLACK, BF
    COLOR WHITE, BLACK
    hud = " " + ptag + class_name + hptag + "   GOLD " + _TRIM$(STR$(gold)) + "/" + _TRIM$(STR$(target_gold)) + "   " + keytag + inv + movetag + "   " + tmr + "   " + lbl
    _PRINTSTRING (0, 50 * CH), hud
    IF need_roll THEN
        COLOR YELLOWU, BLACK
        _PRINTSTRING ((SW - 17) * CW, 50 * CH), "[SPACE] ROLL DICE"
    ELSEIF gold >= target_gold AND has_key THEN
        COLOR GREENU, BLACK
        _PRINTSTRING ((SW - 23) * CW, 50 * CH), "RETURN TO START TO WIN!"
    END IF
END SUB



SUB Banner (l1 AS STRING, l2 AS STRING)
    _DEST CANVAS
    LINE (18 * CW, 21 * CH)-(114 * CW, 30 * CH), BOXBG, BF
    LINE (18 * CW, 21 * CH)-(114 * CW, 30 * CH), REDU, B
    COLOR WHITE, BOXBG: PrintCentered 24, l1
    COLOR YELLOWU, BOXBG: PrintCentered 27, l2
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
    DO: k = INKEY$: LOOP UNTIL k = ""              ' drain buffered keys
    DO: _LIMIT 60: k = INKEY$: _DISPLAY: LOOP UNTIL k <> ""
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
    DO: k = INKEY$: LOOP UNTIL k = ""
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
    DIM AS INTEGER sz, gap, bw, bx, by, f, j
    sz = 52: gap = 18
    bw = n * sz + (n - 1) * gap
    bx = (SW * CW - bw) \ 2
    by = 33 * CH
    die_a = RollDie(6): die_b = 0
    IF n = 2 THEN die_b = RollDie(6)

    IF opt_showdice THEN
        FOR f = 1 TO 16
            _DEST CANVAS
            LINE (bx - gap, by - gap)-(bx + bw + gap, by + sz + gap), BOXBG, BF
            LINE (bx - gap, by - gap)-(bx + bw + gap, by + sz + gap), REDU, B
            FOR j = 0 TO n - 1
                IF f < 13 THEN
                    DrawDie bx + j * (sz + gap), by, sz, RollDie(6)
                ELSEIF j = 0 THEN
                    DrawDie bx, by, sz, die_a
                ELSE
                    DrawDie bx + sz + gap, by, sz, die_b
                END IF
            NEXT j
            IF opt_sfx THEN Tone 380 + f * 28, 0.05
            _DISPLAY
            _LIMIT 22
        NEXT f
        _DELAY 0.7                   ' hold so the settled dice are readable
    END IF

    IF n = 2 THEN RollDiceShow = die_a + die_b ELSE RollDiceShow = die_a
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
    ELSEIF sides = 6 AND n <= 2 THEN
        t = RollDiceShow(n)                        ' 1d6 / 2d6 show pip dice
        GameRoll = t + bonus: last_raw = t
    ELSE
        t = ShowRollText(n, sides, what)           ' 3d6 / polyhedral use the number tumbler
        GameRoll = t + bonus: last_raw = t
    END IF
END FUNCTION


' A number-tumbler for polyhedral dice (d8/d10/d20...) that d6 pips can't show.
' Flickers random totals, settles on the real one, and returns it.
FUNCTION ShowRollText% (n AS INTEGER, sides AS INTEGER, what AS STRING)
    DIM total AS INTEGER, i AS INTEGER
    total = 0
    FOR i = 1 TO n: total = total + RollDie(sides): NEXT i
    ShowRollText = ShowRollValue(total, n * sides, "rolling " + _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides)))
END FUNCTION


' Animate a number tumbler that flickers random values (1..hi) then settles on a
' KNOWN total -- lets callers (e.g. 4d6-drop-lowest) control what is summed.
FUNCTION ShowRollValue% (total AS INTEGER, hi AS INTEGER, caption AS STRING)
    DIM AS INTEGER f, bx, by, bw, shown
    IF opt_showdice THEN
        bw = 46
        bx = (SW - bw) \ 2: by = 32
        FOR f = 1 TO 16
            IF f < 13 THEN shown = INT(RND * hi) + 1 ELSE shown = total
            _DEST CANVAS
            LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + 6) * CH), BOXBG, BF
            LINE (bx * CW, by * CH)-((bx + bw) * CW, (by + 6) * CH), REDU, B
            COLOR CYANU, BOXBG: PrintCentered by + 1, "-= " + caption + " =-"
            COLOR YELLOWU, BOXBG: PrintCentered by + 3, "[  " + _TRIM$(STR$(shown)) + "  ]"
            IF opt_sfx THEN Tone 380 + f * 28, 0.05
            _DISPLAY
            _LIMIT 22
        NEXT f
        _DELAY 0.6
    END IF
    ShowRollValue = total
END FUNCTION


' Roll one ability score, honouring the Stat-Roll setting: straight 3d6, or
' 4d6-drop-lowest (the heroic method).  Respects Real Dice + Show Dice.
FUNCTION RollAbility% ()
    DIM d(1 TO 4) AS INTEGER, i AS INTEGER, lo AS INTEGER, sum AS INTEGER
    IF opt_heroicstats THEN
        IF opt_realdice THEN
            RollAbility = PromptRoll(3, 6, 0, "roll 4d6, DROP lowest, enter top 3")
        ELSE
            FOR i = 1 TO 4: d(i) = RollDie(6): NEXT i
            lo = d(1)
            FOR i = 2 TO 4: IF d(i) < lo THEN lo = d(i)
            NEXT i
            sum = d(1) + d(2) + d(3) + d(4) - lo
            RollAbility = ShowRollValue(sum, 18, "4d6 drop lowest")
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


