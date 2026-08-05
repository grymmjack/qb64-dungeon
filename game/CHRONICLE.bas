' ============================================================================
'  CHRONICLE.bas -- per-run stats, a single-line EVENT LOG, and the in-game
'  reference screens reached from the GAME MENU ([M]):
'      Game Summary   Event Log   Bestiary   Treasury   Rules   Character Sheet
'  All counters live in DUNGEON.BI and reset each run via ChronicleReset.
' ============================================================================

' short "trim STR$" helper
FUNCTION EvNum$ (v AS LONG)
    EvNum$ = _TRIM$(STR$(v))
END FUNCTION

' Reset all run stats + the event log, and seed the bestiary with the full roster
' (so monsters you haven't met yet still list, at 0). Call at the start of every run.
SUB ChronicleReset
    DIM i AS INTEGER, lv AS INTEGER, sl AS INTEGER, nm AS STRING, dummy AS INTEGER
    g_rooms_explored = 0: g_monsters_slain = 0: g_treasures_found = 0: start_heals = 0: g_rests = 0
    g_items_looted = 0: g_levels_completed = 0: g_secrets_found = 0
    g_crits = 0: g_fumbles = 0: g_wander_enc = 0: g_run_deaths = 0
    g_gold_found = 0: EVLOG_N = 0
    g_damage_done = 0: g_damage_taken = 0
    g_rooms_cleared = 0: g_chambers_cleared = 0
    g_max_level = 0: g_items_used = 0: g_flourishes = 0
    g_death_mon = "": g_death_lv = 0: g_saved = 0
    g_dmg_dealt = 0: g_dmg_healed = 0: g_streak = 0: g_streak_best = 0
    BEAST_N = 0
    FOR i = 1 TO MAXBEAST
        BEAST_NAME(i) = "": BEAST_ENC(i) = 0: BEAST_SLAIN(i) = 0: BEAST_FLED(i) = 0
        BEAST_KILLEDBY(i) = 0: BEAST_LOOTED(i) = 0
    NEXT
    FOR lv = 1 TO 9: FOR sl = 1 TO 3
            nm = _TRIM$(MON_NAME(lv, sl))
            IF LEN(nm) > 0 THEN dummy = BeastIdx%(nm)
    NEXT sl: NEXT lv
    TRE_STAT_N = 0
    FOR i = 1 TO MAXTRE: TRE_STATNAME(i) = "": TRE_FOUND(i) = 0: TRE_GP(i) = 0: NEXT
    ' AFTER the roster is seeded, never before: LoadBestiary resolves saved NAMES to row indices
    ' via BeastIdx%, so with BEAST_N still 0 every name would be silently discarded and the
    ' player's whole discovery history would evaporate on the first new game.
    '
    ' Note this is the one thing ChronicleReset does NOT reset -- per-run tallies start at zero,
    ' but what you have MET is knowledge you keep.
    LoadBestiary
END SUB

' Look up (or register) a monster in the bestiary tally. 0 if the name is blank/full.
FUNCTION BeastIdx% (nm AS STRING)
    DIM i AS INTEGER, t AS STRING
    t = UCASE$(_TRIM$(nm)): IF t = "" THEN BeastIdx% = 0: EXIT FUNCTION
    FOR i = 1 TO BEAST_N
        IF UCASE$(_TRIM$(BEAST_NAME(i))) = t THEN BeastIdx% = i: EXIT FUNCTION
    NEXT
    IF BEAST_N >= MAXBEAST THEN BeastIdx% = 0: EXIT FUNCTION
    BEAST_N = BEAST_N + 1: BEAST_NAME(BEAST_N) = _TRIM$(nm): BeastIdx% = BEAST_N
END FUNCTION

FUNCTION TreIdx% (nm AS STRING)
    DIM i AS INTEGER, t AS STRING
    t = UCASE$(_TRIM$(nm)): IF t = "" THEN TreIdx% = 0: EXIT FUNCTION
    FOR i = 1 TO TRE_STAT_N
        IF UCASE$(_TRIM$(TRE_STATNAME(i))) = t THEN TreIdx% = i: EXIT FUNCTION
    NEXT
    IF TRE_STAT_N >= MAXTRE THEN TreIdx% = 0: EXIT FUNCTION
    TRE_STAT_N = TRE_STAT_N + 1: TRE_STATNAME(TRE_STAT_N) = _TRIM$(nm): TreIdx% = TRE_STAT_N
END FUNCTION

SUB LogEvent (s AS STRING)
    IF EVLOG_N >= MAXEVLOG THEN EXIT SUB
    EVLOG_N = EVLOG_N + 1: EVLOG(EVLOG_N) = s
END SUB

' -------- recording helpers (called from the game at the right moments) --------
SUB RecordEnterRoom
    g_rooms_explored = g_rooms_explored + 1
END SUB

SUB RecordEncounter (mon AS STRING)              ' first face-off with a room's monster
    DIM i AS INTEGER
    i = BeastIdx%(mon)
    IF i > 0 THEN
        BEAST_ENC(i) = BEAST_ENC(i) + 1
        DiscoverBeast i                          ' meeting it is what unlocks its Bestiary page
    END IF
END SUB

' Mark a monster as MET, forever, and write it out immediately.
'
' Saved on the spot rather than at end-of-run on purpose: a player who meets a red dragon and is
' promptly eaten has still MET a red dragon, and losing that to a crash or a quit would be the
' one case where the feature matters most.
SUB DiscoverBeast (i AS INTEGER)
    IF i < 1 OR i > BEAST_N THEN EXIT SUB
    IF BEAST_EVER(i) THEN EXIT SUB               ' already known -- no rewrite
    BEAST_EVER(i) = TRUE
    SaveBestiary
END SUB

' Load the discovered-ever set. One monster NAME per line, so the file survives the roster being
' reordered or added to -- an index-based format would silently re-point every entry.
SUB LoadBestiary
    DIM f AS INTEGER, ln AS STRING, i AS INTEGER
    FOR i = 1 TO MAXBEAST: BEAST_EVER(i) = FALSE: NEXT i
    IF NOT _FILEEXISTS(BESTIARY_FILE) THEN EXIT SUB
    f = FREEFILE
    OPEN BESTIARY_FILE FOR INPUT AS #f
    DO UNTIL EOF(f)
        LINE INPUT #f, ln
        ln = _TRIM$(ln)
        IF LEN(ln) > 0 THEN
            i = BeastIdx%(ln)
            IF i > 0 THEN BEAST_EVER(i) = TRUE   ' a name no longer in the roster is simply ignored
        END IF
    LOOP
    CLOSE #f
END SUB

SUB SaveBestiary
    DIM f AS INTEGER, i AS INTEGER
    IF _DIREXISTS("gameplay-data-saves") = 0 THEN MKDIR "gameplay-data-saves"
    f = FREEFILE
    OPEN BESTIARY_FILE FOR OUTPUT AS #f
    FOR i = 1 TO BEAST_N
        IF BEAST_EVER(i) THEN PRINT #f, _TRIM$(BEAST_NAME(i))
    NEXT i
    CLOSE #f
END SUB

' TRUE if this Bestiary row has ever been met. Undiscovered rows still LIST -- the player should
' see how much is left to find -- but as a mystery slot with no name, art or tallies.
FUNCTION BeastKnown% (i AS INTEGER)
    BeastKnown% = 0
    IF i < 1 OR i > BEAST_N THEN EXIT FUNCTION
    BeastKnown% = (BEAST_EVER(i) <> 0)
END FUNCTION

SUB RecordKill (lv AS INTEGER, rm AS INTEGER, mon AS STRING, rounds AS INTEGER, gp AS LONG, itm AS STRING)
    DIM i AS INTEGER, s AS STRING
    i = BeastIdx%(mon)
    IF i > 0 THEN BEAST_SLAIN(i) = BEAST_SLAIN(i) + 1: DiscoverBeast i
    g_monsters_slain = g_monsters_slain + 1
    ' A room is CLEARED by killing the monster that lived in it. Chamber spawns and wandering
    ' monsters both come through here too and must not count: a chamber is cleared by its third
    ' kill (RecordChamberCleared), and a wanderer never belonged to a room at all.
    IF rm >= 1 AND rm <= ROOM_N THEN
        IF ROOMS(rm).is_chamber = 0 THEN g_rooms_cleared = g_rooms_cleared + 1
    END IF
    g_streak = g_streak + 1
    IF g_streak > g_streak_best THEN g_streak_best = g_streak
    s = _TRIM$(player_name) + " entered L" + EvNum$(lv) + "/R" + EvNum$(rm) + ", slew " + _TRIM$(mon) + " after " + EvNum$(rounds) + " round"
    IF rounds <> 1 THEN s = s + "s"
    IF gp > 0 THEN s = s + " -- found " + EvNum$(gp) + " GP"
    IF LEN(_TRIM$(itm)) > 0 THEN s = s + " + " + _TRIM$(itm)
    LogEvent s
END SUB

' -- scorecard hooks. Each is one line at its call site, so the counter cannot drift from the
'    event it counts, and a new call site is a one-liner rather than a bookkeeping puzzle. --

SUB RecordDepth (lv AS INTEGER)
    IF lv > g_max_level THEN g_max_level = lv
END SUB

SUB RecordItemUsed (nm AS STRING)
    g_items_used = g_items_used + 1
    LogEvent _TRIM$(player_name) + " used " + _TRIM$(nm) + "."
END SUB

SUB RecordFlourish
    g_flourishes = g_flourishes + 1
END SUB

SUB RecordDamage (dmg AS INTEGER)
    IF dmg > 0 THEN g_dmg_dealt = g_dmg_dealt + dmg
END SUB

SUB RecordHealed (hp AS INTEGER)
    IF hp > 0 THEN g_dmg_healed = g_dmg_healed + hp
END SUB

SUB RecordSaved
    g_saved = g_saved + 1
END SUB

SUB RecordChamberCleared
    g_chambers_cleared = g_chambers_cleared + 1
END SUB

' Fleeing breaks the streak. It is not a defeat, but it is not a kill either, and a "consecutive
' kills" number that survives running away would measure nothing.
SUB RecordFled (mon AS STRING)
    g_streak = 0
    DIM i AS INTEGER: i = BeastIdx%(mon): IF i > 0 THEN BEAST_FLED(i) = BEAST_FLED(i) + 1
    LogEvent _TRIM$(player_name) + " fled from " + _TRIM$(mon)
END SUB

SUB RecordDeath (lv AS INTEGER, rm AS INTEGER, mon AS STRING, rounds AS INTEGER, goldlost AS LONG)
    g_streak = 0
    g_death_mon = mon: g_death_lv = lv        ' the epitaph's "slain by X on level Y"
    DIM i AS INTEGER, s AS STRING
    i = BeastIdx%(mon): IF i > 0 THEN BEAST_KILLEDBY(i) = BEAST_KILLEDBY(i) + 1
    g_run_deaths = g_run_deaths + 1
    s = _TRIM$(player_name) + " DIED fighting " + _TRIM$(mon) + " in L" + EvNum$(lv) + "/R" + EvNum$(rm) + " after " + EvNum$(rounds) + " round"
    IF rounds <> 1 THEN s = s + "s"
    IF goldlost > 0 THEN s = s + " -- dropped " + EvNum$(goldlost) + " GP"
    LogEvent s
END SUB

SUB RecordLootRescue (mon AS STRING)
    DIM i AS INTEGER: i = BeastIdx%(mon): IF i > 0 THEN BEAST_LOOTED(i) = BEAST_LOOTED(i) + 1
END SUB

SUB RecordTreasure (nm AS STRING, gp AS LONG)
    DIM i AS INTEGER
    g_treasures_found = g_treasures_found + 1: g_gold_found = g_gold_found + gp
    i = TreIdx%(nm)
    IF i > 0 THEN TRE_FOUND(i) = TRE_FOUND(i) + 1: TRE_GP(i) = gp
END SUB

SUB RecordItem (nm AS STRING)
    g_items_looted = g_items_looted + 1
    LogEvent _TRIM$(player_name) + " looted " + _TRIM$(nm)
END SUB

SUB RecordSecret (lv AS INTEGER, rm AS INTEGER, attempts AS INTEGER)
    g_secrets_found = g_secrets_found + 1
    LogEvent _TRIM$(player_name) + " found a SECRET DOOR in L" + EvNum$(lv) + " near R" + EvNum$(rm) + " after " + EvNum$(attempts) + " attempt(s)"
END SUB

SUB RecordWander (mon AS STRING, lv AS INTEGER)
    ' the BEAST_ENC tally is bumped by RecordEncounter inside DoCombat -- don't double-count here
    g_wander_enc = g_wander_enc + 1
    LogEvent _TRIM$(player_name) + " was ambushed by a wandering " + _TRIM$(mon) + " in L" + EvNum$(lv)
END SUB

SUB RecordCrit (mon AS STRING, dmg AS INTEGER)
    g_crits = g_crits + 1
    combat_crits = combat_crits + 1                ' this fight's tally -> CritPotionReward
    IF dmg > 0 THEN
        LogEvent _TRIM$(player_name) + " CRITICALLY hit " + _TRIM$(mon) + " for " + EvNum$(dmg) + " damage"
    ELSE
        LogEvent _TRIM$(player_name) + " CRITICALLY slew " + _TRIM$(mon) + " in one blow"
    END IF
END SUB

SUB RecordFumble (mon AS STRING, rno AS INTEGER)
    g_fumbles = g_fumbles + 1
    IF rno > 0 THEN
        LogEvent _TRIM$(player_name) + " FUMBLED against " + _TRIM$(mon) + " in round " + EvNum$(rno)
    ELSE
        LogEvent _TRIM$(player_name) + " FUMBLED against " + _TRIM$(mon)
    END IF
END SUB

SUB RecordLevelDone (lv AS INTEGER)
    g_levels_completed = g_levels_completed + 1
    LogEvent _TRIM$(player_name) + " cleared every room on Level " + EvNum$(lv)
END SUB

' A curio / random-event gain: feed the per-player manifest (LogTreasure, as before)
' AND the chronicle Treasury tally + the Event Log, so curio spoils show up in the
' Game Menu screens like combat loot does.
SUB CurioGain (nm AS STRING, g AS LONG)
    LogTreasure nm, g
    RecordTreasure nm, g
    IF g > 0 THEN
        LogEvent _TRIM$(player_name) + " found " + _TRIM$(nm) + " (" + EvNum$(g) + " GP)"
    ELSE
        LogEvent _TRIM$(player_name) + " found " + _TRIM$(nm)
    END IF
END SUB

' A curio appeared (the prop kind, e.g. "fountain"/"chest"); note it in the log.
SUB RecordCurio (nm AS STRING)
    LogEvent _TRIM$(player_name) + " came upon a " + _TRIM$(nm)
END SUB

' A trap sprung -- lv/rm for context, saved TRUE if the save throw succeeded.
SUB RecordTrap (nm AS STRING, saved AS INTEGER)
    IF saved THEN
        LogEvent _TRIM$(player_name) + " evaded a " + _TRIM$(nm)
    ELSE
        LogEvent _TRIM$(player_name) + " was caught by a " + _TRIM$(nm)
    END IF
END SUB

' ---------------------------------------------------------------------------
'  VIEWERS
' ---------------------------------------------------------------------------

' A framed panel helper: fills rows y1..y2 (cols x1..x2) + a centred title.
' Open a Chronicle screen's panel. `frame` names its entry in ui-frames.txt, so each of these
' screens can be re-skinned on its own.
'
' Framed by GROWING OUTWARD (FrameOutset): every one of these screens lays its body out against
' the old one-cell border, so moving the contents inward would mean re-deriving coordinates in
' five separate SUBs. The content rect stays exactly where it was and the frame wraps around it.
'
' Sets _PRINTMODE _KEEPBACKGROUND while framed, and ChronicleClose restores it -- the callers
' draw dozens of lines with `COLOR x, BOXBG` after this returns, and each would otherwise stamp
' a dark cell through the artwork. The panel/close pairing is what makes that safe.
SUB ChroniclePanel (x1 AS INTEGER, y1 AS INTEGER, x2 AS INTEGER, y2 AS INTEGER, title AS STRING, frame AS STRING)
    DIM fx AS INTEGER, fy AS INTEGER, fw AS INTEGER, fh AS INTEGER, framed AS INTEGER
    DIM i AS INTEGER
    _DEST CANVAS
    i = FrameIdx%(frame)
    IF i > 0 THEN
        fx = x1 + 1 - UIFRAME_TW(i): fy = y1 + 1 - UIFRAME_TH(i)
        fw = (x2 - x1) - 2 + 2 * UIFRAME_TW(i): fh = (y2 - y1) - 2 + 2 * UIFRAME_TH(i)
        IF fx >= 0 AND fy >= 0 AND fx + fw <= SW AND fy + fh <= SH THEN framed = FrameBox%(frame, fx, fy, fw, fh)
    END IF
    IF NOT framed THEN
        LINE (x1 * CW, y1 * CH)-(x2 * CW, y2 * CH), BOXBG, BF
        LINE (x1 * CW, y1 * CH)-(x2 * CW, y2 * CH), CYANU, B
    END IF
    chron_framed = framed
    IF framed THEN _PRINTMODE _KEEPBACKGROUND
    COLOR YELLOWU, BOXBG: PrintCentered y1 + 1, "-=  " + title + "  =-"
END SUB

' A full-screen list panel: frame it by growing outward, and leave the caller's own layout
' untouched. Returns FALSE when there is no art or no room, so the caller keeps its LINE box.
'
' These are redrawn EVERY keypress as the lightbar moves, so the frame is redrawn with them --
' cheap, because NineGridLoad& caches the rendered art and the tiling is _PUTIMAGE calls.
FUNCTION ListPanel% (frame AS STRING, col AS INTEGER, row AS INTEGER, cols AS INTEGER, rows AS INTEGER, edge AS _UNSIGNED LONG)
    DIM i AS INTEGER, fx AS INTEGER, fy AS INTEGER, fw AS INTEGER, fh AS INTEGER
    i = FrameIdx%(frame): IF i = 0 THEN EXIT FUNCTION
    fx = col + 1 - UIFRAME_TW(i): fy = row + 1 - UIFRAME_TH(i)
    fw = cols - 2 + 2 * UIFRAME_TW(i): fh = rows - 2 + 2 * UIFRAME_TH(i)
    IF fx < 0 OR fy < 0 OR fx + fw > SW OR fy + fh > SH THEN EXIT FUNCTION
    DIM ok AS INTEGER
    ok = FrameBox%(frame, fx, fy, fw, fh)        ' a local, not the return slot: QB64 reads a bare
    ListPanel% = ok                              ' `ListPanel%` in an expression as a recursive CALL
    IF ok THEN chron_framed = -1: _PRINTMODE _KEEPBACKGROUND
END FUNCTION

SUB ChronicleClose
    _PRINTMODE _FILLBACKGROUND                   ' paired with ChroniclePanel -- see the note there
    chron_framed = 0
    cursor_erase: cursor_draw: DrawHUD: Present
END SUB

' GAME SUMMARY -- the run at a glance.
' How long this run has lasted, as "12m 04s". game_start is set when the run begins and the
' clock is wall time, so a paused game keeps counting -- which is the honest reading of
' "time played" for a game with no pause-the-world mechanic.
FUNCTION RunTime$ ()
    DIM el AS LONG
    el = TIMER - game_start: IF el < 0 THEN el = el + 86400   ' TIMER wraps at midnight
    RunTime$ = EvNum$(el \ 60) + "m " + EvNum$(el MOD 60) + "s"
END FUNCTION

FUNCTION RunMinutes& ()
    DIM el AS LONG
    el = TIMER - game_start: IF el < 0 THEN el = el + 86400
    RunMinutes& = el \ 60
END FUNCTION

' THE RUN SCORECARD -- ONE list, three consumers.
'
' The Game Summary, the TAB overlay and the death screen all show these numbers, and all three
' read them from here by index rather than each writing its own list. That is the whole point:
' three hand-maintained copies is how the overlay ends up saying something the summary does not,
' and adding a stat becomes three edits with two of them forgotten.
'
' `i` is 1..STATROW_N. Returns "" past the end.
FUNCTION StatRowLabel$ (i AS INTEGER)
    SELECT CASE i
        CASE 1: StatRowLabel$ = "Time elapsed"
        CASE 2: StatRowLabel$ = "Turns taken"
        CASE 3: StatRowLabel$ = "Distance travelled"
        CASE 4: StatRowLabel$ = "Rooms explored"
        CASE 5: StatRowLabel$ = "Rooms cleared"
        CASE 6: StatRowLabel$ = "Chambers cleared"
        CASE 7: StatRowLabel$ = "Deepest level"
        CASE 8: StatRowLabel$ = "Treasures found"
        CASE 9: StatRowLabel$ = "Gold recovered"
        CASE 10: StatRowLabel$ = "Magic items looted"
        CASE 11: StatRowLabel$ = "Items used"
        CASE 12: StatRowLabel$ = "Secret doors found"
        CASE 13: StatRowLabel$ = "Kills"
        CASE 14: StatRowLabel$ = "Best kill streak"
        CASE 15: StatRowLabel$ = "Critical hits"
        CASE 16: StatRowLabel$ = "Flourishes"
        CASE 17: StatRowLabel$ = "Fumbles"
        CASE 18: StatRowLabel$ = "Damage dealt"
        CASE 19: StatRowLabel$ = "Damage healed"
        CASE 20: StatRowLabel$ = "Wandering ambushes"
        CASE 21: StatRowLabel$ = "Levels completed"
        CASE 22: StatRowLabel$ = "Trips home to heal"
        CASE 23: StatRowLabel$ = "HP rested back"
        CASE 24: StatRowLabel$ = "Deaths this run"
        CASE 25: StatRowLabel$ = "Damage dealt"
        CASE 26: StatRowLabel$ = "Damage taken"
    END SELECT
END FUNCTION

FUNCTION StatRowValue$ (i AS INTEGER)
    SELECT CASE i
        CASE 1: StatRowValue$ = RunTime$
        CASE 2: StatRowValue$ = EvNum$(turn_num)
        CASE 3: StatRowValue$ = EvNum$(moves_made)
        CASE 4: StatRowValue$ = EvNum$(g_rooms_explored)
        CASE 5: StatRowValue$ = EvNum$(g_rooms_cleared)
        CASE 6: StatRowValue$ = EvNum$(g_chambers_cleared)
        CASE 7: StatRowValue$ = EvNum$(g_max_level)
        CASE 8: StatRowValue$ = EvNum$(g_treasures_found)
        CASE 9: StatRowValue$ = EvNum$(g_gold_found)
        CASE 10: StatRowValue$ = EvNum$(g_items_looted)
        CASE 11: StatRowValue$ = EvNum$(g_items_used)
        CASE 12: StatRowValue$ = EvNum$(g_secrets_found)
        CASE 13: StatRowValue$ = EvNum$(g_monsters_slain)
        CASE 14: StatRowValue$ = EvNum$(g_streak_best)
        CASE 15: StatRowValue$ = EvNum$(g_crits)
        CASE 16: StatRowValue$ = EvNum$(g_flourishes)
        CASE 17: StatRowValue$ = EvNum$(g_fumbles)
        CASE 18: StatRowValue$ = EvNum$(g_dmg_dealt)
        CASE 19: StatRowValue$ = EvNum$(g_dmg_healed)
        CASE 20: StatRowValue$ = EvNum$(g_wander_enc)
        CASE 21: StatRowValue$ = EvNum$(g_levels_completed)
        CASE 22: StatRowValue$ = EvNum$(start_heals)
        CASE 23: StatRowValue$ = EvNum$(g_rests)
        CASE 24: StatRowValue$ = EvNum$(g_run_deaths)
        CASE 25: StatRowValue$ = EvNum$(g_damage_done)
        CASE 26: StatRowValue$ = EvNum$(g_damage_taken)
    END SELECT
END FUNCTION

SUB ShowGameSummary
    DIM i AS INTEGER, y AS INTEGER, col AS INTEGER, per AS INTEGER, lx AS INTEGER
    ChroniclePanel 14, 3, 118, 40, "G A M E   S U M M A R Y", "summary"
    COLOR WHITE, BOXBG: PrintCentered 6, _TRIM$(player_name) + "  the  " + _TRIM$(class_name)
    COLOR GREY, BOXBG: PrintCentered 8, "Level " + EvNum$(char_level) + "    XP " + EvNum$(char_xp) + "    Gold " + EvNum$(gold) + " / " + EvNum$(target_gold)
    ' TWO COLUMNS. At 24 stats a single column at the old 2-row spacing needs 48 rows and the
    ' panel has 40 -- the list simply outgrew the layout it was written for.
    per = (STATROW_N + 1) \ 2
    FOR i = 1 TO STATROW_N
        IF i <= per THEN col = 0 ELSE col = 1
        y = 11 + ((i - 1) MOD per) * 2
        lx = 18 + col * 50
        COLOR CYANU, BOXBG: _PRINTSTRING (lx * CW, y * CH), PadR$(StatRowLabel$(i), 22)
        COLOR WHITE, BOXBG: _PRINTSTRING ((lx + 23) * CW, y * CH), StatRowValue$(i)
    NEXT i
    COLOR YELLOWU, BOXBG: PrintCentered 38, "[ press any key ]"
    Present: WaitKey: ChronicleClose
END SUB

' The live TAB overlay: the same rows, one column, down the right of the board.
' Deliberately terse and unframed-looking (a dim panel, no heading art) -- it is meant to be
' glanced at mid-run and dismissed, not read.
SUB DrawStatsOverlay
    DIM i AS INTEGER, x AS INTEGER, y AS INTEGER
    IF NOT opt_statsoverlay THEN EXIT SUB
    ' [Shift-TAB] swaps which view this box shows. Same key, same box -- BEARINGS is a second
    ' page of the scoreboard, not a second widget competing for the same corner.
    IF overlay_mode = 1 THEN DrawBearingsOverlay: EXIT SUB
    x = 96
    _DEST CANVAS
    ' Rows run 4..3+STATROW_N and a row drawn at y occupies y..y+1, so the frame closes TWO
    ' rows past the last origin -- otherwise the final stat sits outside its own box.
    LINE (x * CW - 4, 1 * CH)-((x + 35) * CW, (5 + STATROW_N) * CH), _RGBA32(0, 0, 0, 215), BF
    LINE (x * CW - 4, 1 * CH)-((x + 35) * CW, (5 + STATROW_N) * CH), CYANU, B
    _FONT CH
    COLOR YELLOWU, BLACK: _PRINTSTRING (x * CW, 2 * CH), "-= RUN STATS =-   [TAB]"
    FOR i = 1 TO STATROW_N
        y = 3 + i
        COLOR GREY, BLACK: _PRINTSTRING (x * CW, y * CH), PadR$(StatRowLabel$(i), 21)
        COLOR WHITE, BLACK: _PRINTSTRING ((x + 22) * CW, y * CH), StatRowValue$(i)
    NEXT i
END SUB

' EVENT LOG -- newest last; scroll with the arrows / PgUp-PgDn, ESC to leave.
SUB ShowEventLog
    DIM top AS INTEGER, per AS INTEGER, i AS INTEGER, y AS INTEGER, k AS STRING, ext AS INTEGER
    per = 30
    top = EVLOG_N - per + 1: IF top < 1 THEN top = 1     ' start at the newest page
    DO
        ChroniclePanel 6, 3, 126, 47, "E V E N T   L O G   (" + EvNum$(EVLOG_N) + " events)", "eventlog"
        IF EVLOG_N = 0 THEN
            COLOR GREY, BOXBG: PrintCentered 24, "Nothing has happened yet. Go make history."
        ELSE
            FOR i = 0 TO per - 1
                IF top + i <= EVLOG_N THEN
                    y = 6 + i
                    COLOR GREY, BOXBG: _PRINTSTRING (8 * CW, y * CH), PadR$(EvNum$(top + i), 4)
                    COLOR WHITE, BOXBG: _PRINTSTRING (12 * CW, y * CH), LEFT$(EVLOG(top + i), 112)
                END IF
            NEXT
        END IF
        COLOR YELLOWU, BOXBG: PrintCentered 45, "[Up/Down] scroll   [PgUp/PgDn] page   [ESC] back"
        Present
        k = "": ext = 0
        DO
            k = INKEY$: IF LEN(k) = 2 THEN ext = ASC(RIGHT$(k, 1))
            IF k <> "" THEN EXIT DO
            _LIMIT 60
        LOOP
        IF k = CHR$(27) THEN EXIT DO
        IF ext = 72 THEN top = top - 1                    ' up
        IF ext = 80 THEN top = top + 1                    ' down
        IF ext = 73 THEN top = top - per                  ' page up
        IF ext = 81 THEN top = top + per                  ' page down
        IF top > EVLOG_N - per + 1 THEN top = EVLOG_N - per + 1
        IF top < 1 THEN top = 1
    LOOP
    ChronicleClose
END SUB

' BESTIARY -- lightbar list on the left, portrait + tallies on the right.
SUB ShowBestiary
    DIM sel AS INTEGER, i AS INTEGER, y AS INTEGER, k AS STRING, ext AS INTEGER, sp AS STRING
    PlayCue "bestiary", -1                              ' bestiary music (restored to the level track on exit)
    sel = 1
    DO
        _DEST CANVAS
        IF ListPanel%("bestiary", 4, 3, 124, 44, CYANU) = 0 THEN
            LINE (4 * CW, 3 * CH)-(128 * CW, 47 * CH), BOXBG, BF
            LINE (4 * CW, 3 * CH)-(128 * CW, 47 * CH), CYANU, B
        END IF
        COLOR YELLOWU, BOXBG: PrintCentered 4, "-=  B E S T I A R Y  =-"
        '--- list ---
        ' Undiscovered monsters still take a ROW -- seeing how much is left to find is half the
        ' point of a bestiary -- but the row is a mystery slot: no name, no art, no tallies.
        FOR i = 1 TO BEAST_N
            y = 7 + (i - 1)
            IF i = sel THEN
                COLOR WHITE, REDU
            ELSEIF BeastKnown%(i) THEN
                COLOR GREENU, BOXBG
            ELSE
                COLOR GREY, BOXBG                    ' dim: something is there, you have not met it
            END IF
            IF BeastKnown%(i) THEN
                _PRINTSTRING (7 * CW, y * CH), PadR$("  " + _TRIM$(BEAST_NAME(i)), 24)
            ELSE
                _PRINTSTRING (7 * CW, y * CH), PadR$("  " + STRING$(LEN(_TRIM$(BEAST_NAME(i))), 63), 24)
            END IF
        NEXT
        '--- detail panel (right) ---
        IF sel >= 1 AND sel <= BEAST_N THEN
            IF BeastKnown%(sel) THEN
                sp = MonsterSprite$(BEAST_NAME(sel))
                IF LEN(sp) > 0 THEN CombatArtBox sp, 36, 34, 7, 17, "-= " + _TRIM$(BEAST_NAME(sel)) + " =-", REDU   ' no artstyle guard: ArtFile$ returns "" when the chosen style has no art for this subject
                y = 26
                COLOR CYANU, BOXBG: _PRINTSTRING (36 * CW, y * CH), _TRIM$(BEAST_NAME(sel))
                y = y + 1: COLOR GREY, BOXBG: _PRINTSTRING (36 * CW, y * CH), "Haunts: " + BeastHaunts$(BEAST_NAME(sel))
                y = y + 3
                BeastRow y, "Encountered", BEAST_ENC(sel): y = y + 2
                BeastRow y, "Slain", BEAST_SLAIN(sel): y = y + 2
                BeastRow y, "Fled from", BEAST_FLED(sel): y = y + 2
                BeastRow y, "Killed you", BEAST_KILLEDBY(sel): y = y + 2
                BeastRow y, "Loot rescued from", BEAST_LOOTED(sel): y = y + 2
            ELSE
                ' A mystery slot. Even the TALLIES are hidden: "Encountered 0" would confirm you
                ' have never met it, and "Haunts: level 9" would give away where to look.
                MysteryBox 36, 34, 7, 17
                y = 26
                COLOR GREY, BOXBG: _PRINTSTRING (36 * CW, y * CH), "UNDISCOVERED"
                y = y + 2: COLOR GREY, BOXBG
                _PRINTSTRING (36 * CW, y * CH), "You have never met this creature."
                y = y + 2
                _PRINTSTRING (36 * CW, y * CH), "Find it in the dungeon and its page"
                y = y + 1
                _PRINTSTRING (36 * CW, y * CH), "will fill itself in -- for good."
            END IF
        END IF
        COLOR YELLOWU, BOXBG: PrintCentered 45, "[Up/Down] browse   [ESC] back"
        Present
        k = ""
        DO
            k = NormKey$(UCASE$(INKEY$))
            IF k <> "" THEN EXIT DO
            AudioTick                           ' screen-cue crossfade must keep ramping here
            _LIMIT 60
        LOOP
        IF k = CHR$(27) THEN EXIT DO
        IF k = "W" THEN sel = sel - 1
        IF k = "S" THEN sel = sel + 1
        IF sel < 1 THEN sel = BEAST_N
        IF sel > BEAST_N THEN sel = 1
    LOOP
    EndCue                                              ' bestiary done -> back to the level track
    ChronicleClose
END SUB
SUB BeastRow (y AS INTEGER, lbl AS STRING, v AS INTEGER)
    COLOR CYANU, BOXBG: _PRINTSTRING (36 * CW, y * CH), PadR$(lbl, 22)
    COLOR WHITE, BOXBG: _PRINTSTRING (60 * CW, y * CH), EvNum$(v)
END SUB

' Which dungeon levels a monster appears on (from MON_NAME).
FUNCTION BeastHaunts$ (nm AS STRING)
    DIM lv AS INTEGER, sl AS INTEGER, s AS STRING, t AS STRING
    t = UCASE$(_TRIM$(nm))
    FOR lv = 1 TO 9: FOR sl = 1 TO 3
            IF UCASE$(_TRIM$(MON_NAME(lv, sl))) = t THEN
                IF INSTR(s, "L" + EvNum$(lv)) = 0 THEN s = s + "L" + EvNum$(lv) + " "
            END IF
    NEXT sl: NEXT lv
    IF LEN(s) = 0 THEN s = "wandering"
    BeastHaunts$ = _TRIM$(s)
END FUNCTION

' TREASURY -- what you've recovered this run. A browsable catalogue (like the
' Bestiary): a lightbar list on the left, a framed treasure IMAGE + tallies on the right.
SUB ShowTreasury
    DIM sel AS INTEGER, i AS INTEGER, y AS INTEGER, k AS STRING, sp AS STRING
    IF TRE_STAT_N = 0 THEN
        ChroniclePanel 16, 4, 116, 46, "T R E A S U R Y", "treasury"
        COLOR GREY, BOXBG: PrintCentered 24, "No treasure recovered yet. The hoard awaits."
        COLOR YELLOWU, BOXBG: PrintCentered 45, "[ press any key ]"
        Present: WaitKey: ChronicleClose: EXIT SUB
    END IF
    PlayCue "treasury", -1                              ' treasury music (restored to the level track on exit)
    sel = 1
    DO
        _DEST CANVAS
        IF ListPanel%("treasury", 4, 3, 124, 44, YELLOWU) = 0 THEN
            LINE (4 * CW, 3 * CH)-(128 * CW, 47 * CH), BOXBG, BF
            LINE (4 * CW, 3 * CH)-(128 * CW, 47 * CH), YELLOWU, B
        END IF
        COLOR YELLOWU, BOXBG: PrintCentered 4, "-=  T R E A S U R Y  =-"
        '--- list (left) ---
        FOR i = 1 TO TRE_STAT_N
            y = 7 + (i - 1)
            IF y > 43 THEN EXIT FOR
            IF i = sel THEN COLOR WHITE, REDU ELSE COLOR GREENU, BOXBG
            _PRINTSTRING (7 * CW, y * CH), PadR$("  " + _TRIM$(TRE_STATNAME(i)), 26)
        NEXT
        '--- detail panel (right) ---
        IF sel >= 1 AND sel <= TRE_STAT_N THEN
            sp = TreasureSprite$(TRE_STATNAME(sel))
            IF LEN(sp) > 0 THEN CombatArtBox sp, 36, 34, 7, 17, "-= " + _TRIM$(TRE_STATNAME(sel)) + " =-", YELLOWU   ' no artstyle guard: ArtFile$ returns "" when the chosen style has no art for this subject
            y = 26
            COLOR CYANU, BOXBG: _PRINTSTRING (36 * CW, y * CH), _TRIM$(TRE_STATNAME(sel))
            y = y + 3
            BeastRow y, "Times found", TRE_FOUND(sel): y = y + 2
            COLOR CYANU, BOXBG: _PRINTSTRING (36 * CW, y * CH), PadR$("GP each", 22)
            COLOR WHITE, BOXBG: _PRINTSTRING (60 * CW, y * CH), EvNum$(TRE_GP(sel))
        END IF
        COLOR GREENU, BOXBG: PrintCentered 44, "Total: " + EvNum$(g_gold_found) + " GP across " + EvNum$(g_treasures_found) + " finds"
        COLOR YELLOWU, BOXBG: PrintCentered 45, "[Up/Down] browse   [ESC] back"
        Present
        k = ""
        DO
            k = NormKey$(UCASE$(INKEY$))
            IF k <> "" THEN EXIT DO
            AudioTick                           ' screen-cue crossfade must keep ramping here
            _LIMIT 60
        LOOP
        IF k = CHR$(27) THEN EXIT DO
        IF k = "W" THEN sel = sel - 1
        IF k = "S" THEN sel = sel + 1
        IF sel < 1 THEN sel = TRE_STAT_N
        IF sel > TRE_STAT_N THEN sel = 1
    LOOP
    EndCue                                              ' treasury done -> back to the level track
    ChronicleClose
END SUB

' -- The MARKDOWN reader moved to engine/MARKDOWN.bas (reusable). RulesConfigBlock$
'    + ShowRules below still drive it via global SUB resolution (game -> engine). --


' Generate a markdown "your game, right now" section from the live SETTINGS, so the
' rules screen reflects how THIS run is actually configured (mode, movement, FOV, etc.).
FUNCTION RulesConfigBlock$ ()
    DIM s AS STRING, nl AS STRING, cb AS STRING
    nl = CHR$(10)
    s = "# Your game, right now" + nl + nl
    s = s + "How this run is configured -- change any of it in SETTINGS." + nl + nl
    s = s + "| Setting | Value |" + nl + "|---|---|" + nl
    IF opt_oldschool THEN
        s = s + "| Mode | Classic Dungeon! (Oldschool) |" + nl
        s = s + "| Combat | one 2d6 roll vs the monster's number -- no HP or AC |" + nl
    ELSE
        s = s + "| Mode | D&D (Newschool) |" + nl
        s = s + "| Combat | multi-round: d20 + to-hit vs AC, with HP & damage dice |" + nl
    END IF
    IF opt_boardgame THEN
        s = s + "| Movement | up to 5 spaces per turn, your choice (Dungeon!) |" + nl
    ELSE
        s = s + "| Movement | free walk (computer-game style) |" + nl
    END IF
    IF opt_fov THEN s = s + "| Field of View | on -- line of sight only |" + nl ELSE s = s + "| Field of View | off -- whole map visible |" + nl
    IF NOT opt_oldschool THEN
        cb = StatMethodName$
        IF opt_flexstats = 1 THEN
            cb = cb + " + assign where you want"
        ELSEIF opt_flexstats = 2 THEN
            cb = "point-buy (spend up from 3, max 18)"
        END IF
        s = s + "| Character build | " + cb + " |" + nl
    END IF
    SELECT CASE opt_lootrecovery
        CASE 0: s = s + "| Loot on death | lost forever |" + nl
        CASE 2: s = s + "| Loot on death | souls-like -- one chance to reclaim |" + nl
        CASE ELSE: s = s + "| Loot on death | reclaim it (trek back and kill for it) |" + nl
    END SELECT
    IF NOT opt_oldschool THEN
        s = s + "| Lives | " + _TRIM$(STR$(opt_maxdeaths)) + " before the run is forfeit |" + nl
        IF opt_gestures THEN s = s + "| Action gestures | on -- time the bar for second-wind / crit |" + nl ELSE s = s + "| Action gestures | off |" + nl
        IF opt_critfumble THEN s = s + "| Crits & fumbles | cinematic |" + nl ELSE s = s + "| Crits & fumbles | plain |" + nl
        IF opt_juice THEN s = s + "| Screen effects | on -- shake + blood + poison |" + nl ELSE s = s + "| Screen effects | off |" + nl
    END IF
    IF opt_hardcore THEN s = s + "| Idle danger | hardcore -- time passes while idle |" + nl ELSE s = s + "| Idle danger | casual -- idling is safe |" + nl
    IF opt_realdice THEN s = s + "| Dice | you roll real dice and type the result |" + nl ELSE s = s + "| Dice | the computer rolls |" + nl
    IF num_players > 1 THEN s = s + "| Players | " + _TRIM$(STR$(num_players)) + " (hot-seat) |" + nl ELSE s = s + "| Players | 1 (solo) |" + nl
    s = s + nl + "---" + nl + nl
    RulesConfigBlock$ = s
END FUNCTION

' The ability-score reference for the rules screen, GENERATED from assets/data/stats.txt --
' the same table the character creator's side panel reads.
'
' Generated rather than written into the .md on purpose. The creator already had this text and
' the rules screen did not, and two hand-maintained copies of "what CON does" is exactly the
' pair that drifts: the one you edit is never the one the player is reading. Now a line added to
' stats.txt appears in both, worded identically, with no second edit.
'
' The `live` flag carries through as well, so a mechanic that is designed but unbuilt is marked
' here too. A rules screen that promises something the game does not do is worse than silence.
' Oldschool mode has no ability scores at all, so the whole section is omitted there.
FUNCTION RulesAbilityBlock$ ()
    DIM s AS STRING, nl AS STRING, i AS INTEGER, st AS INTEGER, nplan AS INTEGER
    nl = CHR$(10)
    RulesAbilityBlock$ = ""
    IF opt_oldschool THEN EXIT FUNCTION              ' Dungeon! has no abilities to describe
    IF SH_N = 0 THEN EXIT FUNCTION                   ' stats.txt missing -- say nothing rather than lie
    s = "# What your abilities do" + nl + nl
    s = s + "Every ability feeds real mechanics. The modifier is what actually applies:" + nl
    s = s + "**(score - 10) / 2, rounded down** -- so it steps every 2 points, and 10-11 is +0." + nl + nl
    FOR st = 1 TO 6
        s = s + "## " + AbilFullName$(st) + " (" + StatName$(st) + ")" + nl + nl
        FOR i = 1 TO SH_N
            IF SH_STAT(i) = st THEN
                IF SH_LIVE(i) THEN
                    s = s + "- " + _TRIM$(SH_TEXT(i)) + nl
                ELSE
                    s = s + "- " + _TRIM$(SH_TEXT(i)) + "  *(planned -- not in the game yet)*" + nl
                    nplan = nplan + 1
                END IF
            END IF
        NEXT i
        s = s + nl
    NEXT st
    IF nplan > 0 THEN
        s = s + "*Lines marked planned are designed but not yet built -- they are listed so you can" + nl
        s = s + "see where a score is heading, but nothing in the game reads them today.*" + nl + nl
    END IF
    s = s + "---" + nl + nl
    RulesAbilityBlock$ = s
END FUNCTION

' "Strength" for "STR" -- the headings read as prose, the table stays terse.
FUNCTION AbilFullName$ (i AS INTEGER)
    SELECT CASE i
        CASE 1: AbilFullName$ = "Strength"
        CASE 2: AbilFullName$ = "Intelligence"
        CASE 3: AbilFullName$ = "Wisdom"
        CASE 4: AbilFullName$ = "Dexterity"
        CASE 5: AbilFullName$ = "Constitution"
        CASE ELSE: AbilFullName$ = "Charisma"
    END SELECT
END FUNCTION

SUB ShowRules
    DIM whole AS STRING, rest AS STRING, one AS STRING, content AS STRING, p AS LONG
    DIM kblk AS INTEGER, W AS INTEGER, per AS INTEGER, top AS INTEGER, leftcol AS INTEGER, toprow AS INTEGER
    REDIM vis(1 TO 6000) AS STRING, sty(1 TO 6000) AS STRING, lnk(1 TO 6000) AS STRING, knd(1 TO 6000) AS INTEGER
    REDIM url(1 TO 400) AS STRING
    REDIM hx1(1 TO 400) AS INTEGER, hx2(1 TO 400) AS INTEGER, hy(1 TO 400) AS INTEGER, hu(1 TO 400) AS INTEGER
    DIM n AS INTEGER, nurl AS INTEGER, tvis AS STRING, tsty AS STRING, tlnk AS STRING
    DIM nhit AS INTEGER, hovid AS INTEGER, i AS INTEGER, j AS INTEGER, row AS INTEGER, dl AS INTEGER
    DIM yy AS INTEGER, basecol AS INTEGER, runStartIdx AS INTEGER, curlnk AS INTEGER, linkStartCol AS INTEGER
    DIM styb AS INTEGER, lnkb AS INTEGER, runcol AS _UNSIGNED LONG, cc AS _UNSIGNED LONG, runstr AS STRING
    DIM k AS STRING, ext AS INTEGER, mx AS INTEGER, my AS INTEGER, mcx AS INTEGER, mcy AS INTEGER
    DIM prevdown AS INTEGER, wheel AS INTEGER, statusmsg AS STRING, statustimer AS INTEGER
    REDIM tbl(1 TO 120) AS STRING: DIM ntbl AS INTEGER
    W = 116: leftcol = 6: toprow = 5: per = 40

    DIM rulesfile AS STRING
    IF opt_oldschool THEN rulesfile = "assets/reference/DUNGEON-RULES.md" ELSE rulesfile = "assets/reference/DND-RULES.md"
    whole = RulesConfigBlock$                             ' live "your game" section first
    whole = whole + RulesAbilityBlock$                    ' then what each ability actually does
    IF _FILEEXISTS(rulesfile) THEN whole = whole + _READFILE$(rulesfile)
    IF LEN(_TRIM$(whole)) = 0 THEN whole = "# Rules" + CHR$(10) + "The rules scroll (" + rulesfile + ") is missing."
    '--- parse the whole document into wrapped, attributed display lines ---
    n = 0: nurl = 0: ntbl = 0: rest = whole
    DO WHILE LEN(rest) > 0
        IF n >= UBOUND(vis) - 4 THEN EXIT DO
        p = INSTR(rest, CHR$(10))
        IF p = 0 THEN one = rest: rest = "" ELSE one = LEFT$(rest, p - 1): rest = MID$(rest, p + 1)
        IF RIGHT$(one, 1) = CHR$(13) THEN one = LEFT$(one, LEN(one) - 1)
        one = Utf8ToAscii$(one)
        kblk = MdBlock%(one, content)
        IF kblk = 6 THEN                                   ' a table row -- buffer it for aligned layout
            IF ntbl < UBOUND(tbl) THEN ntbl = ntbl + 1: tbl(ntbl) = content
        ELSE
            IF ntbl > 0 THEN EmitTable tbl(), ntbl, url(), nurl, vis(), sty(), lnk(), knd(), n: ntbl = 0
            IF kblk = 5 THEN
                n = n + 1: vis(n) = "": sty(n) = "": lnk(n) = "": knd(n) = 5
            ELSE
                MdInline content, tvis, tsty, tlnk, url(), nurl
                WrapEmit tvis, tsty, tlnk, kblk, vis(), sty(), lnk(), knd(), n, W
            END IF
        END IF
    LOOP
    IF ntbl > 0 THEN EmitTable tbl(), ntbl, url(), nurl, vis(), sty(), lnk(), knd(), n   ' flush a trailing table

    top = 1: prevdown = 0: statustimer = 0: nhit = 0
    DO
        _LIMIT 60
        '--- mouse: hover-test against last frame's link rects ---
        wheel = 0
        DO WHILE _MOUSEINPUT: wheel = wheel + _MOUSEWHEEL: LOOP
        mx = _MOUSEX: my = _MOUSEY: mcx = mx \ CW: mcy = my \ CH
        hovid = 0
        FOR i = 1 TO nhit
            IF mcy = hy(i) AND mcx >= hx1(i) AND mcx <= hx2(i) THEN hovid = hu(i): EXIT FOR
        NEXT
        '--- input ---
        k = INKEY$: ext = 0: IF LEN(k) = 2 THEN ext = ASC(RIGHT$(k, 1))
        IF k = CHR$(27) THEN EXIT DO
        IF ext = 72 THEN top = top - 1
        IF ext = 80 THEN top = top + 1
        IF ext = 73 THEN top = top - per
        IF ext = 81 THEN top = top + per
        IF wheel <> 0 THEN top = top + wheel * 3   ' natural direction (wheel up scrolls up)
        IF _MOUSEBUTTON(1) THEN
            IF NOT prevdown AND hovid > 0 THEN
                MdOpenURL url(hovid): statusmsg = "Opening: " + url(hovid): statustimer = 150: Sfx "select"
            END IF
            prevdown = -1
        ELSE
            prevdown = 0
        END IF
        IF top > n - per + 1 THEN top = n - per + 1
        IF top < 1 THEN top = 1

        '--- render ---
        _DEST CANVAS: _FONT CH
        LINE (4 * CW, 2 * CH)-(128 * CW, 48 * CH), BOXBG, BF
        LINE (4 * CW, 2 * CH)-(128 * CW, 48 * CH), CYANU, B
        COLOR YELLOWU, BOXBG: PrintCentered 3, "-=  R U L E S   O F   T H E   D U N G E O N  =-"
        IF mcy >= 0 AND mcy <= 60 AND hovid > 0 THEN
            ' (cursor over a link -- the underline/colour already highlights it)
        END IF
        nhit = 0
        FOR row = 0 TO per - 1
            dl = top + row
            IF dl > n THEN EXIT FOR
            yy = toprow + row
            IF knd(dl) = 5 THEN
                LINE (leftcol * CW, yy * CH + CH \ 2)-(124 * CW, yy * CH + CH \ 2), GREY
            ELSE
                basecol = leftcol
                IF knd(dl) = 4 THEN COLOR YELLOWU, BOXBG: _PRINTSTRING (leftcol * CW, yy * CH), CHR$(249): basecol = leftcol + 2
                runstr = "": runStartIdx = 1: curlnk = 0: linkStartCol = 0
                FOR j = 1 TO LEN(vis(dl))
                    styb = ASC(MID$(sty(dl), j, 1)): lnkb = ASC(MID$(lnk(dl), j, 1))
                    cc = MdColor~&(knd(dl), styb, lnkb, hovid)
                    IF j = 1 THEN runcol = cc
                    IF cc <> runcol THEN
                        COLOR runcol, BOXBG: _PRINTSTRING ((basecol + runStartIdx - 1) * CW, yy * CH), runstr
                        runstr = "": runStartIdx = j: runcol = cc
                    END IF
                    runstr = runstr + MID$(vis(dl), j, 1)
                    IF lnkb <> curlnk THEN
                        IF curlnk > 0 THEN MdHit hx1(), hx2(), hy(), hu(), nhit, linkStartCol, basecol + j - 2, yy, curlnk, hovid
                        IF lnkb > 0 THEN linkStartCol = basecol + j - 1
                        curlnk = lnkb
                    END IF
                NEXT j
                IF LEN(runstr) > 0 THEN COLOR runcol, BOXBG: _PRINTSTRING ((basecol + runStartIdx - 1) * CW, yy * CH), runstr
                IF curlnk > 0 THEN MdHit hx1(), hx2(), hy(), hu(), nhit, linkStartCol, basecol + LEN(vis(dl)) - 1, yy, curlnk, hovid
            END IF
        NEXT row

        IF statustimer > 0 THEN
            COLOR GREENU, BOXBG: PrintCentered 46, LEFT$(_TRIM$(statusmsg), 116)
            statustimer = statustimer - 1
        ELSE
            COLOR YELLOWU, BOXBG: PrintCentered 46, "[Up/Dn] scroll   [wheel/PgUp/PgDn] page   click a link to open   [ESC] back   (" + EvNum$(top) + "/" + EvNum$(n) + ")"
        END IF
        Present
    LOOP
    ChronicleClose
END SUB

' ---------------------------------------------------------------------------
'  GAME MENU -- the in-run pause menu ([M]). Lists the chronicle screens.
' ---------------------------------------------------------------------------
SUB GameMenu
    DIM sel AS INTEGER, i AS INTEGER, y AS INTEGER, k AS STRING
    DIM lbl(1 TO 9) AS STRING
    lbl(1) = "Character Sheet"
    lbl(2) = "Game Summary"
    lbl(3) = "Event Log"
    lbl(4) = "Bestiary"
    lbl(5) = "Treasury"
    lbl(6) = "Storybook"
    lbl(7) = "Rules"
    lbl(8) = "Controls"
    lbl(9) = "Resume Game"
    sel = 1
    DO
        ChroniclePanel 44, 12, 88, 33, "G A M E   M E N U", "gamemenu"
        FOR i = 1 TO 9
            y = 15 + (i - 1) * 2
            IF i = sel THEN COLOR WHITE, REDU ELSE COLOR CYANU, BOXBG
            PrintCentered y, "   " + lbl(i) + "   "
        NEXT
        COLOR YELLOWU, BOXBG: PrintCentered 32, "[W/S] move   [ENTER] pick   [ESC] resume"
        Present
        AudioTick                             ' gamemenu cue crossfade / narration fade keeps ramping
        k = NormKey$(UCASE$(INKEY$))
        IF k = "W" THEN sel = sel - 1: IF sel < 1 THEN sel = 9
        IF k = "S" THEN sel = sel + 1: IF sel > 9 THEN sel = 1
        ' BOTH exits go through ChronicleClose. ChroniclePanel leaves _PRINTMODE _KEEPBACKGROUND
        ' set while a frame is up, and leaking that back into the play loop means every later
        ' _PRINTSTRING keeps whatever pixels are under it instead of filling its own background --
        ' which is why the player token came back as a bare white "1" floating on the board art,
        ' its blue cell never painted, until the next move redrew things some other way.
        IF k = CHR$(27) THEN ChronicleClose: EXIT SUB
        IF k = " " OR k = CHR$(13) THEN
            SELECT CASE sel
                CASE 1: ShowCharSheet
                CASE 2: ShowGameSummary
                CASE 3: ShowEventLog
                CASE 4: ShowBestiary
                CASE 5: ShowTreasury
                CASE 6: ShowStorybook
                CASE 7: ShowRules
                CASE 8: ShowKeys
                CASE 9: ChronicleClose: EXIT SUB
            END SELECT
        END IF
    LOOP
END SUB


' The framed "?" that stands in for a creature you have not met. Same box CombatArtBox draws,
' so a discovered and an undiscovered row occupy exactly the same space and the list does not
' jump as you scroll.
SUB MysteryBox (col AS INTEGER, cols AS INTEGER, row AS INTEGER, rows AS INTEGER)
    DIM bx AS INTEGER, by AS INTEGER, bw AS INTEGER, bh AS INTEGER, cap AS STRING, capx AS INTEGER
    bx = col * CW: by = row * CH: bw = cols * CW: bh = rows * CH
    _DEST CANVAS
    capx = by - 4 - CH
    LINE (bx - 4, capx - 2)-(bx + bw + 4, by - 4), BOXBG, BF
    LINE (bx - 4, capx - 2)-(bx + bw + 4, by - 4), GREY, B
    LINE (bx - 4, by - 4)-(bx + bw + 4, by + bh + 4), BOXBG, BF
    LINE (bx - 4, by - 4)-(bx + bw + 4, by + bh + 4), GREY, B
    cap = "-= ? ? ? =-"
    COLOR GREY, BOXBG
    _PRINTSTRING (bx + (bw - LEN(cap) * CW) \ 2, capx), cap
    _PRINTSTRING (bx + (bw - CW) \ 2, by + (bh - CH) \ 2), "?"
END SUB
