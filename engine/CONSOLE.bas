' ============================================================================
'  CONSOLE.bas -- the [`] DEV CONSOLE, the ASSET TELEMETRY it reports on, and
'  the DUMP REGISTRY that keeps both from rotting.
'
'  WHY IT HOOKS Present. "Open from anywhere, even in menus" is hard here for the
'  same reason _RESIZE was: there is no main loop. There are ~40 nested blocking
'  loops -- WaitKey, Banner, every menu, the dice tumble, the fades -- each owning
'  the screen for a while. Present is the one thing they ALL call every frame, and
'  the note at engine/UI.bas:430 already settled the argument: handle it there and
'  you reach every loop by construction, including ones written later.
'
'  WHY _KEYDOWN AND NOT INKEY$. Present must not consume input -- the host loop
'  owns the keyboard and stealing a keypress from it would break whatever screen
'  is up. _KEYDOWN reads the keyboard STATE, not the buffer, so the poll is
'  invisible to the host; _KEYCLEAR on the way out drops the backtick the host
'  would otherwise still find waiting for it.
'
'  WHY IT SNAPSHOTS THE CANVAS. The console draws over whatever screen invoked it,
'  and it has no idea what that screen was or how to repaint it (the play loop can
'  redraw itself; a half-finished fade cannot). So it photographs CANVAS on open
'  and puts the photograph back on close. Screen-agnostic by construction.
'
'  THE DUMP REGISTRY. Per the standing rule, a dump topic is not a one-off:
'
'      topic `foo`  <->  SUB Dump_Foo  <->  a RegisterDump line
'
'  tests/audit-dumps.sh enforces every arrow in both directions, so a topic with
'  no SUB, or a Dump_* nobody can reach, fails the gate rather than shipping. Game
'  topics live in game/DUMP.bas behind Game_RegisterDumps / Game_DevDump%, so the
'  engine still names no game symbol.
' ============================================================================


' ----------------------------------------------------------------------------
'  DUMP REGISTRY
' ----------------------------------------------------------------------------

' Declare a dump topic. `nm` is the word typed after `dump`; the implementing SUB MUST be
' named Dump_<Nm> (audit-dumps.sh checks both directions). owner is "engine" or "game".
SUB RegisterDump (nm AS STRING, owner AS STRING, desc AS STRING)
    IF DUMP_N >= DUMP_MAX THEN EXIT SUB
    DUMP_N = DUMP_N + 1
    DUMP_NAME(DUMP_N) = LCASE$(nm)
    DUMP_OWNER(DUMP_N) = owner
    DUMP_DESC(DUMP_N) = desc
END SUB

' Build the registry once. Lazy rather than called from startup on purpose: the console can be
' opened before, during or after any init, and examples/minimal has a different startup entirely.
SUB EnsureDumps
    IF dump_registered THEN EXIT SUB
    dump_registered = TRUE
    DUMP_N = 0
    '           topic         owner     one-line help (shown by a bare `dump`)
    RegisterDump "summary", "engine", "one-screen overview: audio, art, position, run state"
    RegisterDump "audio", "engine", "every audio channel at once: music, sfx, narration, mixer"
    RegisterDump "music", "engine", "track playing, resolved file, pack, playlist, crossfade state"
    RegisterDump "sfx", "engine", "loaded effects + which file each resolved to + recent plays"
    RegisterDump "narration", "engine", "narration pack, current line, queue, fade envelope"
    RegisterDump "images", "engine", "sprite cache (loaded + missing) and recently drawn art"
    RegisterDump "vars", "engine", "engine globals: screen, canvas, options, mixer, fog"
    RegisterDump "sounds", "engine", "the sound graveyard: handles parked awaiting _SNDCLOSE"
    Game_RegisterDumps                            ' the game appends its own topics
END SUB

' Run a topic. TRUE if it was known and produced output.
FUNCTION DumpRun% (topic AS STRING)
    DIM t AS STRING
    t = LCASE$(_TRIM$(topic))
    DumpRun% = TRUE
    SELECT CASE t
        CASE "summary": Dump_Summary
        CASE "audio": Dump_Audio
        CASE "music": Dump_Music
        CASE "sfx": Dump_Sfx
        CASE "narration": Dump_Narration
        CASE "images": Dump_Images
        CASE "vars": Dump_Vars
        CASE "sounds": Dump_Sounds
        CASE ELSE: DumpRun% = Game_DevDump%(t)    ' not ours -- offer it to the game
    END SELECT
END FUNCTION


' ----------------------------------------------------------------------------
'  CONSOLE OUTPUT BUFFER
' ----------------------------------------------------------------------------

' Append one line in colour `col`. The buffer is a ring: past CON_MAX the oldest scrolls off.
SUB ConPrintC (col AS _UNSIGNED LONG, s AS STRING)
    DIM i AS INTEGER
    IF CON_N >= CON_MAX THEN
        FOR i = 1 TO CON_MAX - 1
            CONBUF(i) = CONBUF(i + 1): CONCOL(i) = CONCOL(i + 1)
        NEXT i
        CON_N = CON_MAX - 1
    END IF
    CON_N = CON_N + 1
    CONBUF(CON_N) = s: CONCOL(CON_N) = col
END SUB

SUB ConPrint (s AS STRING)
    ConPrintC GREY, s
END SUB

' A "label: value" row, so every dump lines up the same way without each one inventing a layout.
SUB ConRow (label AS STRING, v AS STRING)
    ConPrintC WHITE, "  " + PadR$(label, 22) + v
END SUB

' A section heading inside a dump.
SUB ConHead (s AS STRING)
    ConPrintC YELLOWU, s
END SUB

' A value that is either fine (green) or worth noticing (red) -- e.g. a missing file.
SUB ConRowOK (label AS STRING, v AS STRING, ok AS INTEGER)
    IF ok THEN
        ConPrintC GREENU, "  " + PadR$(label, 22) + v
    ELSE
        ConPrintC REDU, "  " + PadR$(label, 22) + v
    END IF
END SUB

' A path, reported as MISSING (red) when it isn't on disk. "" prints as the given placeholder.
SUB ConRowPath (label AS STRING, path AS STRING, blank AS STRING)
    IF LEN(path) = 0 THEN
        ConPrintC GREY, "  " + PadR$(label, 22) + blank
    ELSEIF _FILEEXISTS(path) THEN
        ConPrintC GREENU, "  " + PadR$(label, 22) + path
    ELSE
        ConPrintC REDU, "  " + PadR$(label, 22) + path + "   << MISSING"
    END IF
END SUB

SUB ConClear
    CON_N = 0: con_scroll = 0
END SUB

FUNCTION ConOnOff$ (v AS INTEGER)
    IF v THEN ConOnOff$ = "ON" ELSE ConOnOff$ = "off"
END FUNCTION


' ----------------------------------------------------------------------------
'  ENGINE DUMP TOPICS
' ----------------------------------------------------------------------------

SUB Dump_Music
    ConHead "-- MUSIC --"
    ConRow "enabled", ConOnOff$(opt_music) + "   vol " + _TRIM$(STR$(opt_musicvol)) + "/10"
    ConRow "pack", PackOrDefault$(opt_musicpack)
    ConRow "format pref", FmtName$(opt_fmt_music) + "   inherited: " + AudioPrefName$(opt_audiopref)
    ConRow "level context", _TRIM$(STR$(music_level)) + "  (0 = menu / not in a delve)"
    ConRow "playlist entry", QuotedOr$(music_curfile, "(none)")
    ConRowPath "resolved file", music_path, "(silence)"
    ConRow "handle", _TRIM$(STR$(music_handle)) + "   playing: " + ConOnOff$(MusicIsPlaying%)
    IF music_fadeout > 0 THEN
        ConRowPath "crossfading out", music_fadeout_path, "(none)"
    END IF
    ConRow "crossfade", ConOnOff$(music_fading) + "   over " + _TRIM$(STR$(MUSIC_FADE_SEC)) + "s"
    ConRow "cue active", ConOnOff$(music_cue_active)
    ConRow "duck (under voice)", _TRIM$(STR$(INT(music_duck * 100))) + "%   depth " + _TRIM$(STR$(opt_duckamt)) + "/10"
    ConHead "-- PLAYLIST (level -> bare name -> file) --"
    DumpPlaylistRows
END SUB

' The per-level playlist rows, resolved. A HELPER, not a topic -- hence `DumpPlaylistRows` and
' not `DumpPlaylistRows`. The underscore is load-bearing: audit-dumps.sh reads `Dump_X` as a
' claim that topic X exists, so a helper wearing that prefix would fail the gate.
SUB DumpPlaylistRows
    DIM i AS INTEGER, p AS STRING
    FOR i = 1 TO 9
        p = ""
        IF LEN(_TRIM$(MUSIC_FILE(i))) > 0 THEN p = ResolveMusic$(MUSIC_FILE(i))
        ConRowPath "level " + _TRIM$(STR$(i)) + "  " + PadR$(_TRIM$(MUSIC_FILE(i)), 14), p, "(no track assigned)"
    NEXT i
END SUB

SUB Dump_Sfx
    DIM i AS INTEGER, n AS INTEGER, beeps AS INTEGER
    ConHead "-- SOUND EFFECTS --"
    ConRow "enabled", ConOnOff$(opt_sfx) + "   vol " + _TRIM$(STR$(opt_sfxvol)) + "/10"
    ConRow "pack", PackOrDefault$(opt_sfxpack)
    ConRow "format pref", FmtName$(opt_fmt_sfx) + "   inherited: " + AudioPrefName$(opt_audiopref)
    beeps = 0
    FOR i = 1 TO SFX_N
        IF LEN(SFX_PATH(i)) = 0 THEN beeps = beeps + 1
    NEXT i
    ConRow "registered", _TRIM$(STR$(SFX_N)) + " effects, " + _TRIM$(STR$(beeps)) + " on the beeper fallback"
    ConHead "-- LOADED FILES --"
    FOR i = 1 TO SFX_N
        ConRowPath SFX_NAME(i), SFX_PATH(i), "(beeper -- no sample in this pack)"
    NEXT i
    ConHead "-- RECENTLY PLAYED (newest first) --"
    n = 0
    FOR i = 1 TO SNDLOG_MAX
        DIM k AS INTEGER
        k = SFXLOG_W - i + 1: IF k < 1 THEN k = k + SNDLOG_MAX
        IF LEN(SFXLOG_NAME(k)) > 0 THEN
            n = n + 1
            IF LEN(SFXLOG_PATH(k)) > 0 THEN
                ConPrintC GREENU, "  " + PadR$(AgeText$(SFXLOG_AT(k)), 10) + PadR$(SFXLOG_NAME(k), 16) + SFXLOG_PATH(k)
            ELSE
                ConPrintC YELLOWU, "  " + PadR$(AgeText$(SFXLOG_AT(k)), 10) + PadR$(SFXLOG_NAME(k), 16) + "(beeper)"
            END IF
        END IF
    NEXT i
    IF n = 0 THEN ConPrint "  (nothing yet)"
END SUB

SUB Dump_Narration
    DIM i AS INTEGER
    ConHead "-- NARRATION --"
    ConRow "enabled", ConOnOff$(opt_narration) + "   voice vol " + _TRIM$(STR$(opt_voicevol)) + "/10"
    ConRow "pack", PackOrDefault$(opt_narrationpack)
    ConRow "frequency", _TRIM$(STR$(opt_narrfreq))
    ConRow "format pref", FmtName$(opt_fmt_narr) + "   inherited: " + AudioPrefName$(opt_audiopref)
    ConRow "current key", QuotedOr$(narr_key, "(none)")
    ConRowPath "resolved file", narr_path, "(none)"
    ConRow "playing", ConOnOff$(NarrIsPlaying%) + "   started " + AgeText$(narr_at)
    ConRow "clip length", _TRIM$(STR$(INT(narr_len * 100) / 100)) + "s"
    ConRow "fade envelope", "in " + _TRIM$(STR$(narr_fadein)) + "s / out " + _TRIM$(STR$(narr_fadeout)) + "s"
    ConHead "-- QUEUE --"
    IF narrq_n = 0 THEN
        ConPrint "  (empty)"
    ELSE
        FOR i = 1 TO narrq_n
            IF i <= narrq_i THEN
                ConPrintC GREY, "  " + PadR$(_TRIM$(STR$(i)), 4) + NARRQ(i) + "   (spoken)"
            ELSE
                ConPrintC WHITE, "  " + PadR$(_TRIM$(STR$(i)), 4) + NARRQ(i)
            END IF
        NEXT i
    END IF
END SUB

SUB Dump_Audio
    ConHead "== AUDIO -- ALL CHANNELS =="
    ConRow "muted (dev/headless)", ConOnOff$(audio_muted)
    ConRow "channel gains", "music " + _TRIM$(STR$(chgain_music)) + "  voice " + _TRIM$(STR$(chgain_voice)) + "  sfx " + _TRIM$(STR$(chgain_sfx))
    ConPrint ""
    Dump_Music
    ConPrint ""
    Dump_Sfx
    ConPrint ""
    Dump_Narration
END SUB

SUB Dump_Images
    DIM i AS INTEGER, n AS INTEGER, miss AS INTEGER, k AS INTEGER
    ConHead "-- ART --"
    ConRow "art pack", PackOrDefault$(opt_artpack)
    ConRow "ansi pack", PackOrDefault$(opt_ansipack)
    miss = 0
    FOR i = 1 TO SPR_N
        IF SPR_H(i) = 0 THEN miss = miss + 1
    NEXT i
    ConRow "sprite cache", _TRIM$(STR$(SPR_N)) + " probed, " + _TRIM$(STR$(SPR_N - miss)) + " loaded, " + _TRIM$(STR$(miss)) + " missing"
    ConRow "ansi sprite cache", _TRIM$(STR$(ASPR_N)) + " rendered"
    ConHead "-- ON SCREEN NOW / RECENTLY DRAWN (newest first) --"
    n = 0
    FOR i = 1 TO IMGLOG_MAX
        k = IMGLOG_W - i + 1: IF k < 1 THEN k = k + IMGLOG_MAX
        IF LEN(IMGLOG_PATH(k)) > 0 THEN
            n = n + 1
            ConPrintC WHITE, "  " + PadR$(AgeText$(IMGLOG_AT(k)), 10) + IMGLOG_PATH(k)
        END IF
    NEXT i
    IF n = 0 THEN ConPrint "  (nothing drawn yet)"
    ConHead "-- SPRITE CACHE (missing first) --"
    FOR i = 1 TO SPR_N
        IF SPR_H(i) = 0 THEN ConPrintC REDU, "  MISSING  " + SPR_PATH(i)
    NEXT i
    FOR i = 1 TO SPR_N
        IF SPR_H(i) <> 0 THEN ConPrintC GREENU, "  loaded   " + SPR_PATH(i)
    NEXT i
END SUB

SUB Dump_Sounds
    DIM i AS INTEGER, n AS INTEGER
    ConHead "-- SOUND GRAVEYARD (handles parked awaiting _SNDCLOSE) --"
    ConPrint "  Nothing calls _SNDCLOSE directly; RetireSound parks a handle and ReapSounds"
    ConPrint "  frees it once the mixer has provably moved on. A queue that never drains is a bug."
    ConRow "slots in use", _TRIM$(STR$(RETIRE_N)) + " of " + _TRIM$(STR$(SND_RETIRE_MAX))
    ConRow "hold / hard cap", _TRIM$(STR$(SND_RETIRE_SEC)) + "s / " + _TRIM$(STR$(SND_RETIRE_CAP_SEC)) + "s"
    n = 0
    FOR i = 1 TO RETIRE_N
        IF RETIRE_HND(i) > 0 THEN
            n = n + 1
            ConPrintC YELLOWU, "  handle " + PadR$(_TRIM$(STR$(RETIRE_HND(i))), 8) + "parked " + AgeText$(RETIRE_AT(i))
        END IF
    NEXT i
    IF n = 0 THEN ConPrintC GREENU, "  (empty -- everything retired has been freed)"
END SUB

SUB Dump_Vars
    ConHead "-- SCREEN / CANVAS --"
    ConRow "grid", _TRIM$(STR$(SW)) + " x " + _TRIM$(STR$(SH)) + " cells of " + _TRIM$(STR$(CW)) + " x " + _TRIM$(STR$(CH)) + " px"
    ConRow "canvas", _TRIM$(STR$(_WIDTH(CANVAS))) + " x " + _TRIM$(STR$(_HEIGHT(CANVAS))) + " px   handle " + _TRIM$(STR$(CANVAS))
    ConRow "present scale", _TRIM$(STR$(PresentScale!))
    ConRow "fullscreen", ConOnOff$(opt_fullscreen) + "   smoothing " + _TRIM$(STR$(opt_smoothamt))
    ConHead "-- SIGHT --"
    ConRow "line of sight", ConOnOff$(opt_fov) + "   forced by area: " + ConOnOff$(fov_forced)
    ConHead "-- DICE --"
    ConRow "show dice", ConOnOff$(opt_showdice) + "   real dice " + ConOnOff$(opt_realdice) + "   math " + ConOnOff$(opt_dicemath)
    ConRow "style", "colour " + _TRIM$(STR$(opt_dicecolor)) + "  solid " + ConOnOff$(opt_dicesolid) + "  pips " + ConOnOff$(opt_d6pips)
    ConRow "speed / light / round", _TRIM$(STR$(opt_dicespeed)) + " / " + _TRIM$(STR$(opt_dicelight)) + " / " + _TRIM$(STR$(opt_diceround))
    ConHead "-- CONTENT PACKS --"
    ConRow "data", PackOrDefault$(opt_datapack)
    ConRow "art / ansi", PackOrDefault$(opt_artpack) + " / " + PackOrDefault$(opt_ansipack)
    ConRow "sfx / music", PackOrDefault$(opt_sfxpack) + " / " + PackOrDefault$(opt_musicpack)
    ConRow "narration", PackOrDefault$(opt_narrationpack)
    ConHead "-- ENGINE STATE --"
    ConRow "audio muted", ConOnOff$(audio_muted)
    ConRow "screen shown", ConOnOff$(screen_shown)
    ConRow "sfx slots", _TRIM$(STR$(SFX_N)) + " / 48"
    ConRow "sprite slots", _TRIM$(STR$(SPR_N)) + " / 200"
END SUB

SUB Dump_Summary
    ConHead "== SUMMARY =="
    ConRowPath "music", music_path, "(silence)"
    ConRow "  entry / pack", QuotedOr$(music_curfile, "(none)") + "  from " + PackOrDefault$(opt_musicpack)
    ConRowPath "narration", narr_path, "(none)"
    ConRow "  key / playing", QuotedOr$(narr_key, "(none)") + "  " + ConOnOff$(NarrIsPlaying%)
    DumpSummaryRecent
    ConRow "art pack", PackOrDefault$(opt_artpack) + "   sprites cached " + _TRIM$(STR$(SPR_N))
    IF Game_DevDump%("summary") THEN                ' the game appends position / level / run state
    END IF
END SUB

' The "played in the last RECENT_SEC seconds" line shared by the summary. A helper, not a
' topic -- see the note on DumpPlaylistRows about the underscore.
SUB DumpSummaryRecent
    DIM i AS INTEGER, k AS INTEGER, n AS INTEGER, s AS STRING
    n = 0: s = ""
    FOR i = 1 TO SNDLOG_MAX
        k = SFXLOG_W - i + 1: IF k < 1 THEN k = k + SNDLOG_MAX
        IF LEN(SFXLOG_NAME(k)) > 0 THEN
            IF AgeSecs#(SFXLOG_AT(k)) <= RECENT_SEC THEN
                n = n + 1
                IF n <= 6 THEN
                    IF LEN(s) > 0 THEN s = s + ", "
                    s = s + SFXLOG_NAME(k)
                END IF
            END IF
        END IF
    NEXT i
    IF n = 0 THEN s = "(none)" ELSE IF n > 6 THEN s = s + " ... (" + _TRIM$(STR$(n)) + " total)"
    ConRow "sfx last 10s", s
END SUB


' ----------------------------------------------------------------------------
'  SMALL FORMATTERS
' ----------------------------------------------------------------------------

FUNCTION PackOrDefault$ (p AS STRING)
    IF LEN(_TRIM$(p)) = 0 THEN PackOrDefault$ = "default" ELSE PackOrDefault$ = _TRIM$(p)
END FUNCTION

FUNCTION QuotedOr$ (s AS STRING, blank AS STRING)
    IF LEN(_TRIM$(s)) = 0 THEN QuotedOr$ = blank ELSE QuotedOr$ = CHR$(34) + _TRIM$(s) + CHR$(34)
END FUNCTION


' ----------------------------------------------------------------------------
'  THE CONSOLE ITSELF
' ----------------------------------------------------------------------------

' Polled from Present every frame. Edge-detected so holding the key doesn't reopen it forever.
' Cheap enough to run unconditionally: one _KEYDOWN read.
SUB ConsoleHotkeyTick
    DIM downnow AS INTEGER
    IF con_active THEN EXIT SUB                     ' re-entry guard: the console's own Present calls this
    IF screen_shown = 0 THEN EXIT SUB               ' no window (a dev mode) -> no console
    downnow = 0
    IF _KEYDOWN(96) THEN downnow = -1               ' 96 = backtick. SHIFT-backtick is 126 ("~"),
    IF downnow AND (NOT con_down) THEN              ' which stays the board debug overlay.
        con_down = -1
        ConsoleOpen
    ELSEIF NOT downnow THEN
        con_down = 0
    END IF
END SUB

' Open the console over whatever is on screen and run it until dismissed.
SUB ConsoleOpen
    DIM k AS STRING, ext AS INTEGER, done AS INTEGER
    EnsureDumps
    con_active = -1
    con_snap = _COPYIMAGE(CANVAS, 32)               ' photograph the host screen; put it back on close
    con_scroll = 0
    IF CON_N = 0 THEN ConsoleBanner
    _KEYCLEAR                                        ' drop the backtick that opened us
    done = 0
    DO
        _LIMIT 60
        AudioTick                                    ' the console is a loop like any other: keep the
        ConsoleRender                                ' crossfade and narration envelope advancing
        k = INKEY$: ext = 0
        IF LEN(k) = 2 THEN ext = ASC(RIGHT$(k, 1)): k = ""
        SELECT CASE ext
            CASE 73: con_scroll = con_scroll + CON_ROWS - 2      ' PgUp
            CASE 81: con_scroll = con_scroll - CON_ROWS + 2      ' PgDn
            CASE 72: ConsoleHistory -1                            ' Up    -- previous command
            CASE 80: ConsoleHistory 1                             ' Down  -- next command
        END SELECT
        IF LEN(k) = 1 THEN
            SELECT CASE ASC(k)
                CASE 27: done = -1                                ' ESC closes
                CASE 96: done = -1                                ' backtick closes (as it opened)
                CASE 13: ConsoleSubmit                            ' Enter runs the line
                CASE 8: IF LEN(con_line) > 0 THEN con_line = LEFT$(con_line, LEN(con_line) - 1)
                CASE 9: ' TAB -- ignored; the console has no completion yet
                CASE ELSE
                    IF ASC(k) >= 32 AND ASC(k) < 127 THEN
                        IF LEN(con_line) < 100 THEN con_line = con_line + k
                    END IF
            END SELECT
        END IF
        IF con_scroll < 0 THEN con_scroll = 0
        IF con_scroll > CON_N - 1 THEN con_scroll = CON_N - 1
        IF con_scroll < 0 THEN con_scroll = 0
    LOOP UNTIL done
    _PUTIMAGE , con_snap, CANVAS                     ' restore the host's screen exactly as it was
    _FREEIMAGE con_snap: con_snap = 0
    con_active = 0
    _KEYCLEAR                                        ' don't hand the host loop our closing keypress
    Present
END SUB

SUB ConsoleBanner
    ConPrintC CYANU, "DUNGEON dev console.  Type `help` for commands, `dump` to list topics."
    ConPrintC GREY, "[Enter] run   [Up/Down] history   [PgUp/PgDn] scroll   [ESC] or [`] close"
END SUB

' Recall a previous command into the input line. d = -1 older, +1 newer.
SUB ConsoleHistory (d AS INTEGER)
    IF CONHIST_N = 0 THEN EXIT SUB
    CONHIST_I = CONHIST_I + d
    IF CONHIST_I < 1 THEN CONHIST_I = 1
    IF CONHIST_I > CONHIST_N THEN CONHIST_I = CONHIST_N + 1: con_line = "": EXIT SUB
    con_line = CONHIST(CONHIST_I)
END SUB

' Run whatever is on the input line.
SUB ConsoleSubmit
    DIM ln AS STRING, i AS INTEGER
    ln = _TRIM$(con_line)
    con_line = ""
    con_scroll = 0
    IF LEN(ln) = 0 THEN EXIT SUB
    ConPrintC CYANU, "> " + ln
    ' history (skip an immediate repeat -- nobody wants ten `dump audio`s to page through)
    IF CONHIST_N = 0 OR CONHIST(CONHIST_N) <> ln THEN
        IF CONHIST_N >= CON_HIST THEN
            FOR i = 1 TO CON_HIST - 1: CONHIST(i) = CONHIST(i + 1): NEXT i
            CONHIST_N = CON_HIST - 1
        END IF
        CONHIST_N = CONHIST_N + 1: CONHIST(CONHIST_N) = ln
    END IF
    CONHIST_I = CONHIST_N + 1
    ConsoleExec ln
END SUB

' Command dispatch. Deliberately tiny: this is a dump console, not a shell.
SUB ConsoleExec (ln AS STRING)
    DIM verb AS STRING, rest AS STRING, sp AS INTEGER
    sp = INSTR(ln, " ")
    IF sp = 0 THEN
        verb = LCASE$(ln): rest = ""
    ELSE
        verb = LCASE$(LEFT$(ln, sp - 1)): rest = _TRIM$(MID$(ln, sp + 1))
    END IF
    SELECT CASE verb
        CASE "help", "?": ConsoleHelp
        CASE "clear", "cls": ConClear
        CASE "close", "quit", "exit": con_line = "": ConPrint "(use [ESC] or [`] to close)"
        CASE "dump"
            IF LEN(rest) = 0 THEN
                ConsoleTopics
            ELSEIF NOT DumpRun%(rest) THEN
                ConPrintC REDU, "unknown dump topic: " + rest
                ConsoleTopics
            END IF
        CASE ELSE
            ' A bare topic name works too -- `audio` is `dump audio`. Typing the noun is what
            ' everyone tries first, and refusing it teaches nothing.
            IF DumpRun%(verb) THEN
            ELSE
                ConPrintC REDU, "unknown command: " + verb + "   (try `help`)"
            END IF
    END SELECT
END SUB

SUB ConsoleHelp
    ConHead "-- COMMANDS --"
    ConRow "dump", "list every registered dump topic"
    ConRow "dump <topic>", "run one (or just type the topic name)"
    ConRow "clear", "empty the scrollback"
    ConRow "help", "this"
    ConPrint ""
    ConHead "-- KEYS --"
    ConRow "[`]", "open / close this console (from ANY screen)"
    ConRow "[~]", "board debug overlay (unchanged)"
    ConRow "[TAB]", "show / hide the overlay box in play"
    ConRow "[Shift-TAB]", "swap that box between RUN STATS and BEARINGS"
    ConPrint ""
    ConsoleTopics
END SUB

SUB ConsoleTopics
    DIM i AS INTEGER
    EnsureDumps
    ConHead "-- DUMP TOPICS (" + _TRIM$(STR$(DUMP_N)) + ") --"
    FOR i = 1 TO DUMP_N
        ConPrintC WHITE, "  " + PadR$(DUMP_NAME(i), 12) + PadR$("[" + DUMP_OWNER(i) + "]", 10) + DUMP_DESC(i)
    NEXT i
END SUB

' Draw the drop-down panel over the snapshot and present it.
SUB ConsoleRender
    DIM olddest AS LONG, i AS INTEGER, row AS INTEGER, idx AS INTEGER, top AS INTEGER
    DIM ph AS INTEGER, caret AS STRING
    olddest = _DEST
    _DEST CANVAS
    _PUTIMAGE , con_snap, CANVAS                     ' repaint the host screen, then draw over it
    ph = CON_ROWS + 3                                ' panel height in rows (output + input + border)
    LINE (0, 0)-(SW * CW, ph * CH), _RGBA32(0, 0, 0, 232), BF
    LINE (0, ph * CH)-(SW * CW, ph * CH + 2), CYANU, BF
    _FONT CH
    COLOR CYANU, BLACK
    _PRINTSTRING (CW, 0), "-= DEV CONSOLE =-"
    COLOR GREY, BLACK
    _PRINTSTRING ((SW - 46) * CW, 0), "[Up/Dn] history  [PgUp/PgDn] scroll  [ESC] close"
    ' output rows, oldest at the top of the visible window
    top = CON_N - con_scroll - CON_ROWS + 1
    IF top < 1 THEN top = 1
    FOR i = 0 TO CON_ROWS - 1
        idx = top + i
        IF idx >= 1 AND idx <= CON_N - con_scroll THEN
            row = 1 + i
            COLOR CONCOL(idx), BLACK
            _PRINTSTRING (CW, row * CH), LEFT$(CONBUF(idx), SW - 2)
        END IF
    NEXT i
    IF con_scroll > 0 THEN
        COLOR YELLOWU, BLACK
        _PRINTSTRING ((SW - 20) * CW, CON_ROWS * CH), "^ " + _TRIM$(STR$(con_scroll)) + " more below"
    END IF
    ' input line -- a blinking block caret, so it reads as a prompt and not as static text
    caret = " "
    IF (INT(TIMER * 2.5) MOD 2) = 0 THEN caret = CHR$(219)
    COLOR GREENU, BLACK
    _PRINTSTRING (CW, (ph - 1) * CH), "] " + LEFT$(con_line, SW - 6) + caret
    _DEST olddest
    Present
END SUB
