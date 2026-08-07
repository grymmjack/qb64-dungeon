' ============================================================================
'  MINIMAL -- a second game on the DUNGEON! engine. Walk around the board. That's it.
'
'  PURPOSE: this is the separability PROOF for engine/. It includes engine/ENGINE.BI
'  and every engine/*.bas module, plus the vendored ANSI renderer and 3D dice, and
'  NOTHING from game/. If it compiles and runs, the engine carries no hidden
'  DUNGEON! dependency; if someone reaches into ROOMS() from engine code, this
'  stops building -- a louder alarm than any doc.
'
'  Build:  qb64pe -w -x examples/minimal/minimal.bas -o examples/minimal/minimal.run
'  Or:     tests/run-tests.sh   (builds it as part of the suite)
'
'  Keys: WASD / arrows to move, ESC to quit.
' ============================================================================
$CONSOLE:ONLY

'$INCLUDE:'../../_ALL.BI'   ' ALL engine headers, one line -- if this roll-up ever
'                                   pulls in game/, this demo stops building.

' QB64 chdirs to the EXECUTABLE's dir at startup, so "assets/..." would resolve
' under examples/minimal/. Fix cwd to the repo root once, up front (same trick as
' tests/TESTLIB.bas T_RepoRoot).
IF _FILEEXISTS("dungeon.bas") = 0 THEN CHDIR "../.."

' ---------------------------------------------------------------- WHERE THE FUEL IS
' The engine asks for KINDS and never for paths (engine/ASSETS.bas), so every
' host declares its own tree. THIS is the part that proves the engine carries no
' idea of DUNGEON!'s layout: a second game writes its own eleven lines and the
' engine is unchanged.
'
' ITS OWN TREE. Not the repo's -- examples/minimal/assets/ holds a board this
' game drew for itself, and nothing else. That is what makes the separability
' proof mean something: the engine cannot be assuming DUNGEON!'s layout, because
' this program has no access to one.
'
' The root is written relative to the REPO ROOT rather than to this file: a QB64
' binary here resolves relative paths against neither its own directory nor the
' shell's. Declaring the root explicitly is exactly how a host stops having to
' care what the answer is.
'--- LOOK for the tree rather than assuming where it is. This demo gets run
'    from its own directory by a person and from the repo root by the test
'    gate, and no single relative root is correct for both. ---
'    MOST SPECIFIC FIRST. A bare "assets/" is checked last and on purpose: from
'    a game's repo root it matches THAT GAME'S tree, and this demo would
'    silently load somebody else's board and report it as its own.
'    ALL THREE ARE _STARTDIR$-BASED. A bare relative candidate ("assets/")
'    resolves against something this program cannot predict -- not its own
'    directory, not the shell's -- so it matched in one layout and silently
'    missed in another. _STARTDIR$ is the one thing that behaves.
'
'    The three places this demo genuinely gets run from:
'      engine/ inside a game   -> <root>/engine/examples/minimal/assets/
'      the engine's own repo   -> <root>/examples/minimal/assets/
'      its own directory       -> <root>/assets/
IF AssetRootFind%("ansi-art/default/board-132x50-no-labels.ans", _
                  _STARTDIR$ + "engine/examples/minimal/assets/", _
                  _STARTDIR$ + "examples/minimal/assets/", _
                  _STARTDIR$ + "assets/") = 0 THEN
    PRINT "minimal: cannot find my assets/ tree from here"
    SYSTEM 2
END IF
AssetDefaultPack "default"
AssetKindPacked "data", "data/"
AssetKindPacked "flavor", "flavor/"
AssetKindPacked "pixelart", "pixel-art/"
AssetKindPacked "ansiart", "ansi-art/"
AssetKindPacked "sfx", "sfx/"
AssetKindPacked "music", "music/"
AssetKindPacked "narration", "narration/"
AssetKindPacked "cutscenes", "cutscenes/"
AssetKind "fonts", "fonts/"

SW = 132: SH = 51: CW = 8: CH = 16
CLI_COLOR = 0

' collision palette -- must match the board art exactly (engine convention)
YELLOW = _RGB32(&HFF, &HFF, &H55)
BLACK = _RGB32(&H00, &H00, &H00)
BROWN = _RGB32(&HAA, &H55, &H00)
BRIGHT_BLUE = _RGB32(&H55, &H55, &HFF)
WHITE = _RGB32(&HFF, &HFF, &HFF)
GREY = _RGB32(&HAA, &HAA, &HAA)
REDU = _RGB32(&HFF, &H55, &H55)
GREENU = _RGB32(&H55, &HFF, &H55)
YELLOWU = _RGB32(&HFF, &HFF, &H55)
CYANU = _RGB32(&H55, &HFF, &HFF)
BOXBG = _RGB32(&H20, &H00, &H00)

RANDOMIZE TIMER

$RESIZE:ON
' No $RESIZE:STRETCH -- the engine's Present owns the canvas->window scaling (see engine/UI.bas).
CANVAS = _NEWIMAGE(SW * CW, SH * CH, 32)
CANVAS_COPY = _NEWIMAGE(SW * CW, SH * CH, 32)
FULL_BOARD = _NEWIMAGE(SW * CW, SH * CH, 32)
_TITLE "MINIMAL -- engine separability demo"
SCREEN _NEWIMAGE(SW * CW, SH * CH, 32)
_DEST CANVAS
_FONT CH

' engine defaults this demo cares about (no settings file, no SETTINGS screen)
opt_music = FALSE: opt_sfx = FALSE: opt_voice = FALSE
opt_fov = FALSE: opt_juice = FALSE: opt_smoothamt = 0
opt_artpack = "default": opt_ansipack = "default": opt_datapack = "default"

BOARD_ANSI = _READFILE$(AnsiFile$("board-132x50-no-labels.ans"))
IF LEN(BOARD_ANSI) = 0 THEN PRINT "minimal: board art not found (run from the repo root)": SYSTEM 2

InitJuice                        ' engine: screen-shake buffer + near-death bake
StartBoard                       ' engine: paint FULL_BOARD, build the fog, place the cursor, render

' Headless self-check: `minimal.run selftest` proves the engine came up under a
' non-DUNGEON! game and exits, so CI can assert separability without a display.
IF INSTR(UCASE$(COMMAND$), "SELFTEST") > 0 THEN
    _DEST _CONSOLE
    PRINT "minimal: engine booted under a non-DUNGEON! game"
    PRINT "  board bytes : " + _TRIM$(STR$(LEN(BOARD_ANSI)))
    PRINT "  board path  : " + AnsiFile$("board-132x50-no-labels.ans")
    PRINT "  secret doors: " + _TRIM$(STR$(SD_N)) + "   regular doors: " + _TRIM$(STR$(DOOR_N))
    PRINT "  cursor cell : " + _TRIM$(STR$(c.x \ CW)) + "," + _TRIM$(STR$(c.y \ CH))
    PRINT "  zones       : " + _TRIM$(STR$(Game_ZoneCount%)) + " (" + Game_ZoneName$(1) + ")"
    '--- independent brown-door count, using a counter NOT named after the colour ---
    ' (DetectDoors' own counter is `brown`, which case-insensitively shadows the shared
    '  BROWN constant -- this recount is the control that proves it.)
    DIM AS INTEGER pcx, pcy, ppx, ppy, hits, ndoor
    DIM oldsrc AS LONG: oldsrc = _SOURCE: _SOURCE FULL_BOARD
    FOR pcy = 1 TO SH - 4
        FOR pcx = 1 TO SW - 2
            hits = 0
            FOR ppy = 1 TO CH - 1 STEP 2
                FOR ppx = 1 TO CW - 1 STEP 2
                    IF POINT(pcx * CW + ppx, pcy * CH + ppy) = BROWN THEN hits = hits + 1
                NEXT ppx
            NEXT ppy
            IF hits >= 2 THEN ndoor = ndoor + 1
        NEXT pcx
    NEXT pcy
    _SOURCE oldsrc
    PRINT "  brown doors : DetectDoors=" + _TRIM$(STR$(DOOR_N)) + "  independent recount=" + _TRIM$(STR$(ndoor))
    IF SD_N > 0 AND DOOR_N > 0 THEN PRINT "OK": SYSTEM 0
    PRINT "FAIL: board detection produced nothing": SYSTEM 1
END IF

_SCREENSHOW
_FULLSCREEN _SQUAREPIXELS

DIM k AS STRING, nk AS STRING
DO
    _LIMIT 60
    k = INKEY$
    IF k = CHR$(27) THEN EXIT DO
    nk = NormKey$(k)                     ' engine: WASD / arrows / numpad -> direction
    IF IsMoveKey%(nk) THEN
        IF TryMove%(nk) THEN              ' engine: collision-checked step
            cursor_erase
            cursor_draw
        END IF
    END IF
    Present
LOOP
SYSTEM

'$INCLUDE:'HOOKS.bas'             ' this game's 11 Game_* hooks -- the whole contract
'$INCLUDE:'../../_ALL.BM'  ' ALL engine bodies, one line
