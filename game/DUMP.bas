' ============================================================================
'  DUMP.bas -- the GAME's half of the [`] dev-console dump registry.
'
'  The engine owns the console, the scrollback, and the asset topics (audio /
'  music / sfx / narration / images / vars / sounds). Anything that needs to know
'  what DUNGEON! is -- your character, the board, the monsters, the run -- lives
'  here and is reached through exactly two hooks, so engine/ still names no game
'  symbol:
'
'      Game_RegisterDumps   declares this side's topics into the shared registry
'      Game_DevDump%(topic) runs one, TRUE if it was ours
'
'  THE STANDING RULE (enforced by tests/audit-dumps.sh, both directions):
'
'      topic `foo`  <->  SUB Dump_Foo  <->  a RegisterDump line
'
'  Add a dump by writing Dump_Thing and registering it. Forget either half and the
'  gate fails, which is the whole point -- these are meant to be maintained
'  alongside the game rather than accumulate as dead one-offs nobody trusts.
'  Output goes through the engine's ConHead / ConRow / ConRowOK / ConPrint so
'  every topic lines up the same way without inventing a layout.
' ============================================================================

SUB Game_RegisterDumps
    '           topic          owner   one-line help (shown by a bare `dump`)
    RegisterDump "game", "game", "run state: mode, turn, seat, options in force"
    RegisterDump "character", "game", "the active character sheet, abilities, kit, derived combat stats"
    RegisterDump "map", "game", "position, level, room, chamber, fog/secret state around you"
    RegisterDump "monster", "game", "the monster you are standing on / nearest live ones"
END SUB

FUNCTION Game_DevDump% (topic AS STRING)
    Game_DevDump% = TRUE
    SELECT CASE topic
        CASE "game": Dump_Game
        CASE "character": Dump_Character
        CASE "map": Dump_Map
        CASE "monster": Dump_Monster
        CASE "summary": DumpSummaryGamePart      ' the engine's `summary` asks us to append
        CASE ELSE: Game_DevDump% = FALSE
    END SELECT
END FUNCTION

' What the engine's Dump_Summary appends: where you are and how the run stands.
SUB DumpSummaryGamePart
    ConRow "position", "cell " + _TRIM$(STR$(c.x \ CW)) + "," + _TRIM$(STR$(c.y \ CH)) + "   level " + _TRIM$(STR$(PlayerLevel%))
    ConRow "room / chamber", RoomLabelHere$ + "   " + ChamberLabelHere$
    ConRow "gold / target", _TRIM$(STR$(gold)) + " / " + _TRIM$(STR$(target_gold)) + "   key: " + ConOnOff$(has_key)
    ConRow "hp", _TRIM$(STR$(player_hp)) + " / " + _TRIM$(STR$(player_maxhp))
END SUB

' "room 42 (Armory)" / "(corridor)" -- the room under the player, named.
FUNCTION RoomLabelHere$ ()
    DIM rm AS INTEGER, cx AS INTEGER, cy AS INTEGER
    cx = c.x \ CW: cy = c.y \ CH
    rm = 0
    IF cx >= 0 AND cx <= 131 THEN IF cy >= 0 AND cy <= 60 THEN rm = ROOMAT(cx, cy)
    IF rm <= 0 THEN RoomLabelHere$ = "(no room)": EXIT FUNCTION
    RoomLabelHere$ = "room " + _TRIM$(STR$(rm)) + " (L" + _TRIM$(STR$(ROOMS(rm).sec)) + ")"
END FUNCTION

FUNCTION ChamberLabelHere$ ()
    IF cur_chamber <= 0 THEN ChamberLabelHere$ = "(no chamber)": EXIT FUNCTION
    ChamberLabelHere$ = "chamber " + _TRIM$(STR$(cur_chamber)) + " " + _TRIM$(CHM_NAME(cur_chamber))
END FUNCTION

SUB Dump_Game
    ConHead "-- RUN --"
    ConRow "champion", QuotedOr$(player_name, "(unnamed)") + "   " + _TRIM$(CLASSES(player_class).name)
    ConRow "elapsed", RunTime$
    ConRow "seed", _TRIM$(STR$(run_seed))
    ConRow "moves made", _TRIM$(STR$(moves_made))
    ConRow "gold / target", _TRIM$(STR$(gold)) + " / " + _TRIM$(STR$(target_gold))
    ConRowOK "level key", ConOnOff$(has_key) + "   hidden on level " + _TRIM$(STR$(key_level)) + ", room " + _TRIM$(STR$(key_room)), has_key
    ConRow "deaths", _TRIM$(STR$(deaths(cur_player)))
    ConHead "-- SEATS --"
    ConRow "players", _TRIM$(STR$(num_players)) + "   active seat " + _TRIM$(STR$(cur_player))
    ConHead "-- RULES IN FORCE --"
    ConRow "combat", RulesWord$(opt_oldschool, "OLDSCHOOL 2d6-vs-target", "D&D (HP/AC, multi-round)")
    ConRow "movement", RulesWord$(opt_boardgame, "BOARDGAME (roll then step)", "FREE MOVE")
    ConRow "stat roll", RulesWord$(opt_heroicstats, "4d6 drop lowest", "straight 3d6")
    ConRow "flex stats", _TRIM$(STR$(opt_flexstats)) + "  (0 rolled order / 1 assign / 2 point buy)"
    ConRow "real dice", ConOnOff$(opt_realdice) + "   game does the math: " + ConOnOff$(opt_dicemath)
    ConRow "line of sight", ConOnOff$(opt_fov) + "   forced here: " + ConOnOff$(fov_forced)
    ConRow "hardcore idle", ConOnOff$(opt_hardcore) + "   loiter " + _TRIM$(STR$(loiter)) + "/" + _TRIM$(STR$(LOITER_THRESHOLD))
    ConRow "crit/fumble fx", ConOnOff$(opt_critfumble) + "   gestures " + ConOnOff$(opt_gestures)
    ConHead "-- SOLO --"
    IF NOT solo_on THEN
        ConPrint "  (not a solo challenge run)"
    ELSE
        ConRow "mode", _TRIM$(STR$(opt_solomode)) + "   result so far " + _TRIM$(STR$(solo_result))
        ConRow "quest item", QuotedOr$(solo_item_name, "(none)") + " in room " + _TRIM$(STR$(solo_item_room))
        ConRow "hunter", ConOnOff$(hunt_on) + "   " + _TRIM$(hunt_mon) + " at " + _TRIM$(STR$(hunt_cx)) + "," + _TRIM$(STR$(hunt_cy))
    END IF
    ConHead "-- STATUS EFFECTS --"
    ConRow "poison / fire", _TRIM$(STR$(poison_turns)) + " / " + _TRIM$(STR$(fire_turns)) + " turns"
    ConRow "frost / siren", _TRIM$(STR$(frost_turns)) + " / " + _TRIM$(STR$(siren_turns)) + " turns"
    ConRow "curse", _TRIM$(STR$(curse_turns)) + " turns"
END SUB

FUNCTION RulesWord$ (v AS INTEGER, yes AS STRING, no AS STRING)
    IF v THEN RulesWord$ = yes ELSE RulesWord$ = no
END FUNCTION

SUB Dump_Character
    ConHead "-- " + _TRIM$(player_name) + " the " + _TRIM$(CLASSES(player_class).name) + " --"
    ConRow "character level", _TRIM$(STR$(char_level)) + "   xp " + _TRIM$(STR$(char_xp))
    ConRow "hit points", _TRIM$(STR$(player_hp)) + " / " + _TRIM$(STR$(player_maxhp))
    ConHead "-- ABILITIES (score / modifier) --"
    DumpAbil "STR", player_str
    DumpAbil "INT", player_int
    DumpAbil "WIS", player_wis
    DumpAbil "DEX", player_dex
    DumpAbil "CON", player_con
    DumpAbil "CHA", player_cha
    ConHead "-- DERIVED COMBAT --"
    ConRow "to hit", SignStr$(player_tohit)
    ConRow "armour class", _TRIM$(STR$(player_ac)) + "   (armour " + SignStr$(item_armor) + ", shield " + SignStr$(item_shield) + ")"
    ConRow "damage", "d" + _TRIM$(STR$(player_dmgdie)) + " " + SignStr$(player_dmgbonus)
    ConHead "-- KIT --"
    ConRowOK "magic sword", SignStr$(item_sword), item_sword > 0
    ConRowOK "secret door card", ConOnOff$(item_secret_card), item_secret_card
    ConRowOK "esp medallion", ConOnOff$(item_esp), item_esp
    ConRowOK "crystal ball", ConOnOff$(item_crystal), item_crystal
    ConRowOK "magic bow", ConOnOff$(item_bow), item_bow
    ConRowOK "elf boots", ConOnOff$(item_boots), item_boots
    ConRow "teleport scrolls", _TRIM$(STR$(item_teleport))
    ConRow "potions", _TRIM$(STR$(item_potion_small)) + " small, " + _TRIM$(STR$(item_potion_large)) + " large"
    ConRow "spells", "fire " + _TRIM$(STR$(spell_fire)) + "   bolt " + _TRIM$(STR$(spell_bolt))
END SUB

' One ability row: score, its modifier, and what the ability actually DOES -- the same
' stats.txt text the character creator's side panel shows, so the console and the creator can
' never drift into describing the game differently.
SUB DumpAbil (nm AS STRING, score AS INTEGER)
    DIM i AS INTEGER, idx AS INTEGER, txt AS STRING
    idx = AbilIndexByName%(nm)
    txt = ""
    FOR i = 1 TO SH_N
        IF SH_STAT(i) = idx AND LEN(txt) = 0 THEN
            IF SH_LIVE(i) THEN txt = SH_TEXT(i)
        END IF
    NEXT i
    ConPrintC WHITE, "  " + PadR$(nm, 6) + PadR$(_TRIM$(STR$(score)), 4) + PadR$(SignStr$(AbilMod%(score)), 6) + txt
END SUB

FUNCTION AbilIndexByName% (nm AS STRING)
    SELECT CASE UCASE$(nm)
        CASE "STR": AbilIndexByName% = 1
        CASE "INT": AbilIndexByName% = 2
        CASE "WIS": AbilIndexByName% = 3
        CASE "DEX": AbilIndexByName% = 4
        CASE "CON": AbilIndexByName% = 5
        CASE "CHA": AbilIndexByName% = 6
        CASE ELSE: AbilIndexByName% = 0
    END SELECT
END FUNCTION

' "+2" / "-1" / "+0" -- STR$ already supplies the minus, so only a plus needs adding.
FUNCTION SignStr$ (v AS INTEGER)
    IF v >= 0 THEN SignStr$ = "+" + _TRIM$(STR$(v)) ELSE SignStr$ = _TRIM$(STR$(v))
END FUNCTION

SUB Dump_Map
    DIM cx AS INTEGER, cy AS INTEGER, rm AS INTEGER, i AS INTEGER, n AS INTEGER
    cx = c.x \ CW: cy = c.y \ CH
    ConHead "-- WHERE YOU ARE --"
    ConRow "cell", _TRIM$(STR$(cx)) + ", " + _TRIM$(STR$(cy)) + "   (pixel " + _TRIM$(STR$(c.x)) + ", " + _TRIM$(STR$(c.y)) + ")"
    ConRow "level", _TRIM$(STR$(PlayerLevel%)) + "   " + _TRIM$(SECTORS(ClampLevel%(PlayerLevel%)).label)
    ConRow "sector lookup", _TRIM$(STR$(SECTOR.get_by_xy(c.x, c.y))) + "   (0 = unclaimed cell; PlayerLevel% is sticky)"
    ConRow "room", RoomLabelHere$
    ConRow "chamber", ChamberLabelHere$
    rm = 0
    IF cx >= 0 AND cx <= 131 THEN IF cy >= 0 AND cy <= 60 THEN rm = ROOMAT(cx, cy)
    IF rm > 0 THEN
        ConHead "-- THIS ROOM --"
        ConRow "cells / floor", _TRIM$(STR$(ROOMS(rm).cells)) + " / " + _TRIM$(STR$(ROOMS(rm).floor_cells))
        ConRow "marker cell", _TRIM$(STR$(ROOMS(rm).cx)) + ", " + _TRIM$(STR$(ROOMS(rm).cy))
        ConRow "monster", _TRIM$(ROOMS(rm).monster) + "   alive: " + ConOnOff$(ROOMS(rm).malive)
        ConRow "treasure", _TRIM$(ROOMS(rm).treasure_name) + "  " + _TRIM$(STR$(ROOMS(rm).treasure)) + " gp   looted: " + ConOnOff$(ROOMS(rm).looted)
        ConRow "boss lair", ConOnOff$(ROOMS(rm).is_boss)
        ConRow "dropped loot", _TRIM$(STR$(ROOMS(rm).drop_gold)) + " gp waiting"
    END IF
    ConHead "-- BOARD --"
    ConRow "rooms detected", _TRIM$(STR$(ROOM_N))
    ConRow "chambers", _TRIM$(STR$(NCHAMBER))
    n = 0
    FOR i = 1 TO ROOM_N
        IF ROOMS(i).malive THEN n = n + 1
    NEXT i
    ConRow "monsters alive", _TRIM$(STR$(n)) + " of " + _TRIM$(STR$(ROOM_N)) + " rooms"
    n = 0
    FOR i = 1 TO ROOM_N
        IF ROOMS(i).seen THEN n = n + 1
    NEXT i
    ConRow "rooms entered", _TRIM$(STR$(n))
    ConHead "-- SECRETS --"
    ConRow "mask in use", ConOnOff$(MASK_ON)
    ConRow "fogged cells", _TRIM$(STR$(FoggedCellCount%))
END SUB

' SECTORS() is 1..9; PlayerLevel% can answer 0 on an unclaimed corridor before the sticky value
' has ever been seeded, and indexing SECTORS(0) is a hard Subscript out of range under $CHECKING.
FUNCTION ClampLevel% (lv AS INTEGER)
    ' NOT a single-line ELSEIF chain -- QB64 does not support one, and it compiles as
    ' "THEN without IF" rather than doing something subtle.
    ClampLevel% = lv
    IF lv < 1 THEN ClampLevel% = 1
    IF lv > 9 THEN ClampLevel% = 9
END FUNCTION

SUB Dump_Monster
    DIM cx AS INTEGER, cy AS INTEGER, rm AS INTEGER, i AS INTEGER, n AS INTEGER
    DIM bd AS LONG, d AS LONG, best AS INTEGER
    cx = c.x \ CW: cy = c.y \ CH
    rm = 0
    IF cx >= 0 AND cx <= 131 THEN IF cy >= 0 AND cy <= 60 THEN rm = ROOMAT(cx, cy)
    ConHead "-- MONSTER UNDER YOU --"
    IF rm > 0 THEN
        DumpMonsterRow rm
    ELSE
        ConPrint "  (not standing in a room)"
    END IF
    IF hunt_on THEN
        ConHead "-- THE HUNTER (solo Monster Prey) --"
        ConRow "monster", _TRIM$(hunt_mon) + "   level " + _TRIM$(STR$(hunt_lvl))
        ConRow "at cell", _TRIM$(STR$(hunt_cx)) + ", " + _TRIM$(STR$(hunt_cy))
    END IF
    ConHead "-- NEAREST LIVE MONSTERS --"
    n = 0
    DO
        best = 0: bd = 999999
        FOR i = 1 TO ROOM_N
            IF ROOMS(i).malive AND NOT RoomListed%(i) THEN
                d = ABS(ROOMS(i).cx - cx) + ABS(ROOMS(i).cy - cy)
                IF d < bd THEN bd = d: best = i
            END IF
        NEXT i
        IF best = 0 THEN EXIT DO
        MarkRoomListed best
        n = n + 1
        ConPrintC WHITE, "  " + PadR$(_TRIM$(STR$(bd)) + " cells", 10) + PadR$("L" + _TRIM$(STR$(ROOMS(best).sec)), 4) + PadR$(_TRIM$(ROOMS(best).monster), 20) + "hp " + _TRIM$(STR$(ROOMS(best).mhp)) + "  ac " + _TRIM$(STR$(ROOMS(best).mac))
    LOOP UNTIL n >= 10
    ClearRoomListed
    IF n = 0 THEN ConPrint "  (none left alive)"
END SUB

SUB DumpMonsterRow (rm AS INTEGER)
    ConRow "name", _TRIM$(ROOMS(rm).monster) + "   slot " + _TRIM$(STR$(ROOMS(rm).mslot))
    ConRow "level", _TRIM$(STR$(ROOMS(rm).sec)) + "   boss: " + ConOnOff$(ROOMS(rm).is_boss)
    ConRowOK "alive", ConOnOff$(ROOMS(rm).malive), ROOMS(rm).malive
    ConRow "hp", _TRIM$(STR$(ROOMS(rm).mhp_now)) + " / " + _TRIM$(STR$(ROOMS(rm).mhp)) + "   ac " + _TRIM$(STR$(ROOMS(rm).mac))
    ConRow "guarding", _TRIM$(ROOMS(rm).treasure_name) + "   " + _TRIM$(STR$(ROOMS(rm).treasure)) + " gp"
    ConRow "fought before", ConOnOff$(ROOMS(rm).monster_fought)
END SUB

' A tiny scratch mark used only by Dump_Monster's nearest-first walk, so the same room is not
' picked ten times. Kept as its own flag array rather than reusing any gameplay field -- a dump
' must never be able to change what it is describing.
SUB MarkRoomListed (rm AS INTEGER)
    IF rm >= 1 AND rm <= UBOUND(DUMPMARK) THEN DUMPMARK(rm) = TRUE
END SUB

FUNCTION RoomListed% (rm AS INTEGER)
    RoomListed% = FALSE
    IF rm >= 1 AND rm <= UBOUND(DUMPMARK) THEN RoomListed% = DUMPMARK(rm)
END FUNCTION

SUB ClearRoomListed
    DIM i AS INTEGER
    FOR i = 1 TO UBOUND(DUMPMARK): DUMPMARK(i) = FALSE: NEXT i
END SUB

' How many cells the secret fog still hides. A run where this never falls is a run where no
' secret door has been found -- which is worth being able to see at a glance rather than infer.
FUNCTION FoggedCellCount% ()
    DIM x AS INTEGER, y AS INTEGER, n AS INTEGER
    n = 0
    FOR y = 0 TO 60
        FOR x = 0 TO 131
            IF SECRET(x, y) THEN n = n + 1
        NEXT x
    NEXT y
    FoggedCellCount% = n
END FUNCTION


' ============================================================================
'  THE [Shift-TAB] BEARINGS OVERLAY
'
'  The dev console answers "tell me everything"; this answers "where am I and what is the game
'  doing" at a glance, without stopping play. Deliberately the SAME box [TAB] toggles -- one
'  key, one corner, two pages -- but drawn wide, because the whole point is showing full asset
'  PATHS and a 35-column strip cannot.
'
'  Everything here reads the engine's telemetry rings (see engine/CONSOLE.bas), so it can never
'  disagree with `dump audio` / `dump images` about what is playing: same source, two views.
' ============================================================================
SUB DrawBearingsOverlay
    DIM x AS INTEGER, y AS INTEGER, w AS INTEGER, cx AS INTEGER, cy AS INTEGER
    x = 30: y = 26: w = 100
    _DEST CANVAS
    LINE (x * CW - 4, y * CH)-((x + w) * CW, (y + 23) * CH), _RGBA32(0, 0, 0, 224), BF
    LINE (x * CW - 4, y * CH)-((x + w) * CW, (y + 23) * CH), CYANU, B
    _FONT CH
    COLOR YELLOWU, BLACK: _PRINTSTRING (x * CW, (y + 1) * CH), "-= BEARINGS =-   [Shift-TAB] run stats   [TAB] hide   [`] console"
    cx = c.x \ CW: cy = c.y \ CH
    BearRow y + 3, "music", BearMusic$
    BearRow y + 4, "  pack / entry", PackOrDefault$(opt_musicpack) + "   " + QuotedOr$(music_curfile, "(none)")
    BearRow y + 6, "sfx (last 10s)", BearRecentSfx$
    BearRow y + 8, "narration", BearNarration$
    BearRow y + 9, "  pack / key", PackOrDefault$(opt_narrationpack) + "   " + QuotedOr$(narr_key, "(none)")
    BearRow y + 11, "art (last 10s)", BearRecentArt$(0)
    BearRow y + 12, "", BearRecentArt$(1)
    BearRow y + 13, "", BearRecentArt$(2)
    BearRow y + 14, "  pack", PackOrDefault$(opt_artpack) + " / ansi " + PackOrDefault$(opt_ansipack)
    BearRow y + 16, "level", _TRIM$(STR$(PlayerLevel%)) + "   " + _TRIM$(SECTORS(ClampLevel%(PlayerLevel%)).label)
    BearRow y + 17, "position", "cell " + _TRIM$(STR$(cx)) + ", " + _TRIM$(STR$(cy)) + "   (px " + _TRIM$(STR$(c.x)) + ", " + _TRIM$(STR$(c.y)) + ")"
    BearRow y + 18, "room", RoomLabelHere$
    BearRow y + 19, "chamber", ChamberLabelHere$
    BearRow y + 21, "hp / gold", _TRIM$(STR$(player_hp)) + "/" + _TRIM$(STR$(player_maxhp)) + "   " + _TRIM$(STR$(gold)) + " gp of " + _TRIM$(STR$(target_gold))
END SUB

SUB BearRow (row AS INTEGER, label AS STRING, v AS STRING)
    COLOR GREY, BLACK: _PRINTSTRING (31 * CW, row * CH), PadR$(label, 16)
    COLOR WHITE, BLACK: _PRINTSTRING (47 * CW, row * CH), LEFT$(v, 80)
END SUB

' "playing  assets/music/soundmon-souls/everdark.ogg" -- or why there is silence.
FUNCTION BearMusic$ ()
    IF NOT opt_music THEN BearMusic$ = "(music off)": EXIT FUNCTION
    IF LEN(music_path) = 0 THEN BearMusic$ = "(silence -- no file resolved)": EXIT FUNCTION
    IF MusicIsPlaying% THEN
        BearMusic$ = "playing  " + music_path
    ELSE
        BearMusic$ = "stopped  " + music_path
    END IF
END FUNCTION

FUNCTION BearNarration$ ()
    IF NOT opt_narration THEN BearNarration$ = "(narration off)": EXIT FUNCTION
    IF LEN(narr_path) = 0 THEN BearNarration$ = "(nothing spoken yet)": EXIT FUNCTION
    IF NarrIsPlaying% THEN
        BearNarration$ = "speaking  " + narr_path
    ELSEIF AgeSecs#(narr_at) <= RECENT_SEC THEN
        BearNarration$ = PadR$(AgeText$(narr_at), 10) + narr_path
    ELSE
        BearNarration$ = "(idle)  last: " + narr_path
    END IF
END FUNCTION

' Effects played in the last RECENT_SEC seconds, newest first, "(beeper)" marked -- because the
' most common question this answers is "did that actually play my sample, or fall back to a bleep?"
FUNCTION BearRecentSfx$ ()
    DIM i AS INTEGER, k AS INTEGER, s AS STRING, n AS INTEGER
    s = "": n = 0
    FOR i = 1 TO SNDLOG_MAX
        k = SFXLOG_W - i + 1: IF k < 1 THEN k = k + SNDLOG_MAX
        IF LEN(SFXLOG_NAME(k)) > 0 THEN
            IF AgeSecs#(SFXLOG_AT(k)) <= RECENT_SEC THEN
                n = n + 1
                IF n <= 5 THEN
                    IF LEN(s) > 0 THEN s = s + ", "
                    s = s + SFXLOG_NAME(k)
                    IF LEN(SFXLOG_PATH(k)) = 0 THEN s = s + "(beeper)"
                END IF
            END IF
        END IF
    NEXT i
    IF n = 0 THEN s = "(quiet)"
    BearRecentSfx$ = s
END FUNCTION

' The nth-newest sprite drawn in the last RECENT_SEC seconds (n = 0 is newest), "" past the end.
FUNCTION BearRecentArt$ (nth AS INTEGER)
    DIM i AS INTEGER, k AS INTEGER, n AS INTEGER
    n = 0
    FOR i = 1 TO IMGLOG_MAX
        k = IMGLOG_W - i + 1: IF k < 1 THEN k = k + IMGLOG_MAX
        IF LEN(IMGLOG_PATH(k)) > 0 THEN
            IF AgeSecs#(IMGLOG_AT(k)) <= RECENT_SEC THEN
                IF n = nth THEN
                    BearRecentArt$ = PadR$(AgeText$(IMGLOG_AT(k)), 10) + IMGLOG_PATH(k)
                    EXIT FUNCTION
                END IF
                n = n + 1
            END IF
        END IF
    NEXT i
    IF nth = 0 THEN BearRecentArt$ = "(no art drawn recently)" ELSE BearRecentArt$ = ""
END FUNCTION
