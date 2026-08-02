' ============================================================================
'  TELEMETRY.bas -- ENGINE asset telemetry: "what is playing / showing RIGHT NOW".
'
'  Feeds the [`] dev console (engine/CONSOLE.bas) and the [Shift-TAB] bearings
'  overlay, and both read the SAME rings, so the two views can never disagree
'  about what the game is doing.
'
'  RECORDED AT THE CHOKEPOINTS, never at call sites: Sfx, Narrate, BeginTrack and
'  DrawSpriteFit% each log one line, so every future caller of those is covered
'  without anyone remembering to add a log. Same argument that puts the resize --
'  and the console hotkey -- in Present rather than in forty loops.
'
'  Deliberately SEPARATE from CONSOLE.bas and free of every dependency but QB64
'  built-ins and ENGINE.BI globals. DrawSpriteFit% logs through here, so anything
'  that compiles ARTPACK.bas has to be able to compile this too -- and the unit
'  suites compile single modules in isolation (tests/TEST-ARTPACK.bas does exactly
'  that). Pulling the whole console in behind a one-line log call would have made
'  that impossible; per tests/README.md, only modules that touch nothing but QB64
'  built-ins can be unit-tested at all.
'
'  Rings, not lists: a long session cannot grow them, and the newest entry is
'  always the interesting one.
' ============================================================================

' Record that sound effect `nm` just played. path = "" means it fell back to the Tone beeper,
' which is the case most worth SEEING -- "why is this a bleep instead of my sample" is exactly
' the question the console exists to answer without guesswork.
SUB LogSfxPlayed (nm AS STRING, path AS STRING)
    SFXLOG_W = SFXLOG_W + 1: IF SFXLOG_W > SNDLOG_MAX THEN SFXLOG_W = 1
    SFXLOG_NAME(SFXLOG_W) = nm
    SFXLOG_PATH(SFXLOG_W) = path
    SFXLOG_AT(SFXLOG_W) = TIMER
END SUB

' Record that a sprite was just blitted to the canvas.
SUB LogImageDrawn (path AS STRING)
    ' Collapse a repeat of the newest entry rather than filling the ring with 60 copies of the
    ' same portrait: a sprite redrawn every frame would otherwise evict everything else in a third
    ' of a second, and the ring would only ever show whatever the last frame happened to draw.
    IF IMGLOG_W >= 1 THEN
        IF IMGLOG_PATH(IMGLOG_W) = path THEN IMGLOG_AT(IMGLOG_W) = TIMER: EXIT SUB
    END IF
    IMGLOG_W = IMGLOG_W + 1: IF IMGLOG_W > IMGLOG_MAX THEN IMGLOG_W = 1
    IMGLOG_PATH(IMGLOG_W) = path
    IMGLOG_AT(IMGLOG_W) = TIMER
END SUB

' The file registered for sound effect nm, or "" if it has none (beeper fallback).
FUNCTION SfxPathFor$ (nm AS STRING)
    DIM i AS INTEGER
    SfxPathFor$ = ""
    FOR i = 1 TO SFX_N
        IF SFX_NAME(i) = nm THEN SfxPathFor$ = SFX_PATH(i): EXIT FUNCTION
    NEXT i
END FUNCTION

' Seconds since `t`, or a large number if `t` was never set. Used for the "recently" windows.
' TIMER wraps at midnight, so a negative age means the clock rolled over mid-session -- report it
' as stale rather than as a suspiciously fresh event.
FUNCTION AgeSecs# (t AS DOUBLE)
    DIM a AS DOUBLE
    IF t <= 0 THEN AgeSecs# = 999999: EXIT FUNCTION
    a = TIMER - t
    IF a < 0 THEN a = a + 86400#
    AgeSecs# = a
END FUNCTION

' "3.2s ago" / "now" -- a compact age for the console and the bearings overlay.
FUNCTION AgeText$ (t AS DOUBLE)
    DIM a AS DOUBLE
    a = AgeSecs#(t)
    IF a >= 999999 THEN AgeText$ = "-": EXIT FUNCTION
    IF a < .35 THEN AgeText$ = "now": EXIT FUNCTION
    AgeText$ = _TRIM$(STR$(INT(a * 10) / 10)) + "s ago"
END FUNCTION

' Is anything playing on the music channel right now?
FUNCTION MusicIsPlaying% ()
    MusicIsPlaying% = FALSE
    IF music_handle > 0 THEN IF _SNDPLAYING(music_handle) THEN MusicIsPlaying% = TRUE
END FUNCTION

' Is narration audible right now?
FUNCTION NarrIsPlaying% ()
    NarrIsPlaying% = FALSE
    IF narr_handle > 0 THEN IF _SNDPLAYING(narr_handle) THEN NarrIsPlaying% = TRUE
END FUNCTION


