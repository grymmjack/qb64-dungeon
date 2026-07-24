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
'  INTRO
' ============================================================================

SUB ShowIntro
    DIM ansi AS STRING, mus AS LONG, k AS STRING
    ansi = LoadFile$("assets/ansi/vermin-radioactive-logo.ans")
    mus = _SNDOPEN("assets/music/vr-theme.rad")
    IF mus > 0 THEN _SNDVOL mus, opt_musicvol / 10
    IF mus > 0 AND opt_music THEN _SNDPLAY mus
    _DEST CANVAS: _FONT CH: CLS , BLACK
    ANSI_Print (ansi)
    _DISPLAY
    DO: _LIMIT 30: k = INKEY$: _DISPLAY: LOOP UNTIL k <> ""
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
        _DISPLAY
    LOOP

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
    CONST NSET = 15
    DIM sel AS INTEGER, k AS STRING, i AS INTEGER, y AS INTEGER, vtxt AS STRING, lbl AS STRING
    DIM slider AS INTEGER, delta AS INTEGER
    sel = 1
    DO
        _LIMIT 60
        k = NormKey$(UCASE$(INKEY$))
        IF k = "W" THEN sel = sel - 1: IF sel < 1 THEN sel = NSET
        IF k = "S" THEN sel = sel + 1: IF sel > NSET THEN sel = 1
        IF k = "W" OR k = "S" THEN Sfx "select"
        IF k = CHR$(27) THEN EXIT SUB

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
                    IF num_players > 1 THEN opt_boardgame = TRUE
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
                    IF num_players > 1 THEN opt_boardgame = TRUE
                CASE 13: opt_heroicstats = NOT opt_heroicstats
                CASE 14
                    opt_fullscreen = NOT opt_fullscreen
                    IF opt_fullscreen THEN _FULLSCREEN _SQUAREPIXELS, _SMOOTH ELSE _FULLSCREEN _OFF
                CASE 15: EXIT SUB
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
                CASE ELSE: lbl = "<< Back": vtxt = ""
            END SELECT
            IF i = sel THEN COLOR WHITE, REDU ELSE IF slider THEN COLOR CYANU, BLACK ELSE COLOR GREY, BLACK
            IF i = NSET THEN PrintCentered y, "   " + lbl + "   " ELSE PrintCentered y, "   " + lbl + ":  " + vtxt + "   "
        NEXT i
        COLOR CYANU, BLACK: PrintCentered 47, "[W/S] move   [A/D] adjust   [ENTER] toggle   [ESC] back"
        _DISPLAY
    LOOP
END SUB


SUB ShowCharSheet
    DIM y AS INTEGER, swordtxt AS STRING
    _DEST CANVAS
    LINE (30 * CW, 14 * CH)-(102 * CW, 38 * CH), BOXBG, BF
    LINE (30 * CW, 14 * CH)-(102 * CW, 38 * CH), REDU, B
    COLOR YELLOWU, BOXBG: PrintCentered 16, "-=  C H A R A C T E R  =-"
    COLOR WHITE, BOXBG
    PrintCentered 19, "Champion:  " + class_name
    COLOR CYANU, BOXBG
    PrintCentered 20, "STR " + _TRIM$(STR$(player_str)) + "  INT " + _TRIM$(STR$(player_int)) + "  WIS " + _TRIM$(STR$(player_wis)) + "  DEX " + _TRIM$(STR$(player_dex)) + "  CON " + _TRIM$(STR$(player_con)) + "  CHA " + _TRIM$(STR$(player_cha))
    IF NOT opt_oldschool THEN
        COLOR GREENU, BOXBG
        PrintCentered 22, "HP " + _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + "    AC " + _TRIM$(STR$(player_ac)) + "    To-Hit " + ModStr$(player_tohit) + "    Dmg 1d" + _TRIM$(STR$(player_dmgdie)) + " " + ModStr$(player_dmgbonus)
    END IF
    COLOR WHITE, BOXBG
    PrintCentered 21, "Gold:  " + _TRIM$(STR$(gold)) + " / " + _TRIM$(STR$(target_gold))
    IF has_key THEN PrintCentered 23, "Level Key:  HELD" ELSE PrintCentered 23, "Level Key:  not yet found"
    IF item_sword > 0 THEN swordtxt = "Magic Sword +" + _TRIM$(STR$(item_sword)) ELSE swordtxt = "(none)"
    PrintCentered 25, "Magic Sword:  " + swordtxt
    IF item_secret_card THEN PrintCentered 27, "Secret Door Card:  HELD" ELSE PrintCentered 27, "Secret Door Card:  (none)"
    IF item_esp THEN PrintCentered 29, "ESP Medallion:  HELD" ELSE PrintCentered 29, "ESP Medallion:  (none)"
    IF item_crystal THEN PrintCentered 31, "Crystal Ball:  HELD  ([V] to scry)" ELSE PrintCentered 31, "Crystal Ball:  (none)"
    COLOR CYANU, BOXBG: PrintCentered 34, CLASSES(player_class).blurb
    COLOR YELLOWU, BOXBG: PrintCentered 37, "[ press any key ]"
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
    _DEST CANVAS
    LINE (20 * CW, 8 * CH)-(112 * CW, 45 * CH), BOXBG, BF
    LINE (20 * CW, 8 * CH)-(112 * CW, 45 * CH), CYANU, B
    COLOR CYANU, BOXBG: PrintCentered 10, "-=  C R Y S T A L   B A L L  =-"
    FOR i = 2 TO 9
        y = 12 + (i - 2) * 4
        IF SECTORS(i).malive THEN mons = SECTORS(i).monster ELSE mons = "(cleared)"
        IF SECTORS(i).looted THEN tre = "looted" ELSE tre = SECTORS(i).treasure_name
        COLOR WHITE, BOXBG: PrintCentered y, SECTORS(i).label
        COLOR GREY, BOXBG: PrintCentered y + 1, mons + "   guarding   " + tre
    NEXT i
    COLOR YELLOWU, BOXBG: PrintCentered 43, "[ press any key ]"
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
    _DISPLAY
    WaitKey
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


