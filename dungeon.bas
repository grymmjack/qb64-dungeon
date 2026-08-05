' ============================================================================
'  DUNGEON  -  a QB64PE adaptation of TSR's DUNGEON! (1975) board game
'  Vertical slice: INTRO -> MENU -> PLAY (turn/dice movement + combat) -> END
'
'  Build:  qb64pe -w -x dungeon.bas -o dungeon.run   (run from repo root)
'  Run `dungeon.run --help` for command-line modes.
' ============================================================================
' a console (hidden in normal play) so `dungeon.run --help` can print to the terminal:
$CONSOLE
'$INCLUDE:'engine/_ALL.BI'      ' ALL engine headers (globals/types/consts + vendored ansi/DICE3D) -- must load FIRST
'$INCLUDE:'game/_ALL.BI'        ' ALL game headers (the swappable DUNGEON! layer) -- engine before game
SW = 132: SH = 51: CW = 8: CH = 16

' --- CLI: `dungeon.run --help` (or -h) lists the command-line modes, then exits ---
' console colour on by default; off if NO_COLOR is set (standard) or a `nocolor` arg is passed
CLI_COLOR = -1
IF LEN(ENVIRON$("NO_COLOR")) > 0 THEN CLI_COLOR = 0
IF INSTR(UCASE$(COMMAND$), "NOCOLOR") > 0 THEN CLI_COLOR = 0
DIM cli AS INTEGER, wanthelp AS INTEGER
FOR cli = 1 TO _COMMANDCOUNT
    SELECT CASE UCASE$(COMMAND$(cli))
        CASE "--HELP", "-H", "HELP", "/?", "/H": wanthelp = -1
    END SELECT
NEXT cli
IF wanthelp THEN
    _DEST _CONSOLE
    PRINT PipeCol$("|15DUNGEON!|07  --  a QB64PE adaptation of TSR's |11DUNGEON!|07 (1975)")
    PRINT
    PRINT PipeCol$("usage: |15dungeon.run |14[MODE]")
    PRINT PipeCol$("  |08(no MODE launches the game)")
    PRINT
    PRINT PipeCol$("|11Dev / diagnostic modes|07 (render or write a file, then exit):")
    PRINT PipeCol$("  |10chamberdump|07   detected chambers -> chamberdump.png (+ .txt bounding boxes)")
    PRINT PipeCol$("  |10fogdump|07       fogged board + secret-region overlay -> fogdump.png / -regions.png (+ stats .txt)")
    PRINT PipeCol$("  |10maskgen|07       starter secret-door mask from the flood -> assets/ansi-art/default/board-132x50-secret-mask.ans")
    PRINT PipeCol$("  |10ansilint|07 |14[f]|07  lint a mask ANSI (line endings, row width, colours->sectors, SAUCE);")
    PRINT PipeCol$("                no file = check both board masks. Read-only.")
    PRINT PipeCol$("  |10ansifix|07 |14<f>|07   rewrite a mask ANSI clean (strip CR/LF blanks, reset SGR); backs up to <f>.bak")
    PRINT PipeCol$("  |10audiomanifest|07 dump |14path | prompt-or-text|07 for every sfx/music/narration asset (feed the AI generators)")
    PRINT PipeCol$("  |10imagemanifest|07 dump |14path | prompt|07 for every entity as pixel-art (.png) AND ansi-art (.ans)")
    PRINT PipeCol$("  |10uimanifest|07    dump |14path | prompt|07 for the decorative ANSI UI chrome (logos, menu pieces)")
    PRINT PipeCol$("  |10fightmanifest|07 dump |14path | kind | size | prompt|07 for the tactical-combat art (|14ansi|07 in chars, |14pixel|07 in px)")
    PRINT PipeCol$("                any manifest also takes |14audit|07 (only what is missing) and |14pack=<name>|07")
    PRINT PipeCol$("                |14pack=|07 names the pack to WRITE into (printed in the header) and makes")
    PRINT PipeCol$("                |14audit|07 STRICT -- art present only in |11default/|07 still counts as missing")
    PRINT PipeCol$("  |10fightlayout|07   render the named regions of |11ui-fight-layout.txt|07 as labelled boxes -> |14fightlayout.png|07")
    PRINT PipeCol$("  |10fightshot|07     render the tactical-combat screen with a synthetic 1-vs-4 encounter -> |14fightshot.png|07")
    PRINT PipeCol$("  |10placeholders|07 write a labelled stand-in for every MISSING art asset;  |10placeholders clean|07 removes them again")
    PRINT PipeCol$("  |10panelshot|07 |14[class]|07  render the D&D combat panel (portrait + weapon) -> panelshot.png")
    PRINT PipeCol$("  |10charsheet|07     render the [C] character sheet with a fully-kitted hero -> |14charsheet.png|07")
    PRINT PipeCol$("  |10storyshot|07     render the [M] Storybook at its three extremes -> |14storyshot-*.png|07")
    PRINT PipeCol$("  |10cutwire|07       every cut-scene the game can ask for, and whether this pack answers it")
    PRINT PipeCol$("  |10triggerlint|07   board-position cut-scene triggers: missing scene / unwalkable cell")
    PRINT PipeCol$("  |10overlaylint|07   board art: resolves, animates, and actually changes the board -> |14overlayshot.png|07")
    PRINT PipeCol$("  |10gifsprite|07 |14[f]|07 does an animated .gif animate through the ordinary sprite path?")
    PRINT PipeCol$("  |10gaugeshot|07 |14[depth] [hp]|07  render the action-gesture gauge, timed AND real-dice -> |14gaugeshot*.png|07")
    PRINT PipeCol$("  |10summaryshot|07   render the run scorecard: Game Summary panel + the [TAB] overlay")
    PRINT PipeCol$("  |10deathshot|07    run the animated death screen and capture it -> |14deathshot.png|07")
    PRINT PipeCol$("  |10automovetest|07 drive the auto-walker across the real board; asserts it makes progress")
    PRINT PipeCol$("  |10diceobj|07 |14[set]|07   export the 3D dice as OBJ + MTL + atlas PNG (Blender) -> |14diceobj/|07")
    PRINT PipeCol$("  |10framegen|07     write the GDK 9-grid UI frame (a plain 12x6 ANSI box you can redraw)")
    PRINT PipeCol$("  |10frameshot|07    render that frame at 6 sizes to prove the tiling -> |14frameshot.png|07")
    PRINT PipeCol$("  |10bannershot|07   render the message banner framed, narrow AND wide -> |14bannershot*.png|07")
    PRINT PipeCol$("  |10fight|07 |14[lvl] [foes] [pack]|07  PLAY a tactical fight now (interactive; default level 5, 4 foes)")
    PRINT PipeCol$("                |08fightshot/fight also accept an art-pack NAME to preview it (settings untouched)")
    PRINT PipeCol$("  |10savetest|07     round-trip a synthetic 4-player save (checks the positional stream); scratch file only")
    PRINT PipeCol$("  |10datalint|07     validate the loaded content tables (unreachable treasure slots, bad item codes)")
    PRINT PipeCol$("  |10ruleslint|07    print the GENERATED rules sections (your-game + what each ability does)")
    PRINT PipeCol$("  |10statroll|07 |14[n]|07  sample each ability-roll method; check range + that the fast path matches")
    PRINT PipeCol$("  |10themelint|07    list assets/data/theme/colors.txt and prove it drives the game's colours")
    PRINT PipeCol$("  |10packs|07        list the content packs SETTINGS will offer (scanned, not just on disk)")
    PRINT PipeCol$("  |10balancedump|07 |14[--includestats]|07  monster curve + player ascension, with hits-to-die vs hits-to-kill")
    PRINT PipeCol$("  |10econdump|07     expected gold economy + win pacing per class (after a balance change)")
    PRINT PipeCol$("  |10roomlint|07     rooms holding cells the player cannot stand on (half-block art vs collision)")
    PRINT PipeCol$("  |10sectorauto|07   derive each level's rect from the art colours; report overlaps")
    PRINT PipeCol$("  |10boardsplit|07   split the board art into |14layer-0-board-collisions.ans|07 + |14layer-1-board-decoration.ans|07")
    PRINT PipeCol$("  |10eventsaudit|07  sensory coverage of the flavor text (sight/sound/touch/smell/taste)")
    PRINT PipeCol$("  |10boardfix|07     re-spell half-block cells so the collision colour is the FOREGROUND (same pixels, verified); backs up to .bak")
    PRINT PipeCol$("  |10--help|07, |10-h|07    show this help    |08(append |15nocolor|08 to any mode to disable colour)")
    PRINT
    PRINT PipeCol$("Everything is data: edit |11assets/data/*.txt|07 and |11assets/ansi-art/default/*-mask.ans|07, then rebuild (F5).")
    SYSTEM
END IF
_CONSOLE OFF                            ' normal run: hide the console, go graphics
' SILENCE EVERY CLI RUN.
'
' Dev modes and tests still play through the real audio device -- xvfb hides the window, not the
' speakers -- so a full gate run is minutes of beeps and buzzes at whoever is sitting there.
'
' The test is "was this started with ARGUMENTS", not a list of mode names, for the same reason
' the error handler tests screen_shown rather than devmode: a curated list silently rots every
' time a mode is added, and the next person to add one will not know to update it. Launching the
' game to play it passes no arguments.
audio_muted = (_COMMANDCOUNT > 0)

' CLI dev modes (manifests / dumps / mask tools) are console-only -- keep the graphics
' window HIDDEN and skip fullscreen so they never flash a black screen over the terminal.
DIM devmode AS INTEGER
devmode = (INSTR(UCASE$(COMMAND$), "MANIFEST") > 0) OR (INSTR(UCASE$(COMMAND$), "DUMP") > 0)
devmode = devmode OR (INSTR(UCASE$(COMMAND$), "MASKGEN") > 0)
devmode = devmode OR (INSTR(UCASE$(COMMAND$), "ANSILINT") > 0) OR (INSTR(UCASE$(COMMAND$), "ANSIFIX") > 0)
devmode = devmode OR (INSTR(UCASE$(COMMAND$), "SAVETEST") > 0) OR (INSTR(UCASE$(COMMAND$), "DATALINT") > 0)
devmode = devmode OR (INSTR(UCASE$(COMMAND$), "FIGHTLAYOUT") > 0)   ' writes a PNG, never a window
devmode = devmode OR (INSTR(UCASE$(COMMAND$), "FIGHTSHOT") > 0)     ' ditto -- renders the fight screen

' collision palette (must match the board ANSI art exactly)
YELLOW = _RGB32(&HFF, &HFF, &H55)
BLACK = _RGB32(&H00, &H00, &H00)
BROWN = _RGB32(&HAA, &H55, &H00)
BRIGHT_BLUE = _RGB32(&H55, &H55, &HFF)
' UI palette
LoadTheme                                     ' fill the theme table BEFORE anything asks Thm~& for a colour
' UI INK -- themeable (assets/data/theme/colors.txt). The four board colours above are NOT:
' they are collision values the art has to match. See the note on THM_KEY in ENGINE.BI.
WHITE = Thm~&("ui.white", _RGB32(&HFF, &HFF, &HFF))
GREY = Thm~&("ui.grey", _RGB32(&HAA, &HAA, &HAA))
REDU = Thm~&("ui.red", _RGB32(&HFF, &H55, &H55))
GREENU = Thm~&("ui.green", _RGB32(&H55, &HFF, &H55))
YELLOWU = Thm~&("ui.yellow", _RGB32(&HFF, &HFF, &H55))
CYANU = Thm~&("ui.cyan", _RGB32(&H55, &HFF, &HFF))
BOXBG = Thm~&("ui.panel.bg", _RGB32(&H20, &H00, &H00))

RANDOMIZE TIMER

' window starts HIDDEN (no black flash); _SCREENSHOW reveals it for play only (dev modes never do)
$SCREENHIDE
$RESIZE:ON
' Arm the fatal handler BEFORE anything can fail: the first thing that errors is usually a
' missing asset, and that happens during startup.
ON ERROR GOTO DungeonFatal
CONST ERR_MAX = 20                            ' runtime errors tolerated in PLAY before giving up
DIM SHARED err_seen AS INTEGER
' TRUE once the window is actually on screen. The error handler asks THIS rather than the
' curated `devmode` list: "is a human looking at a window" is the real question, and a list of
' mode names has to be updated every time a dev mode is added -- which is how `settingsshot`
' ended up aborting-not-aborting and hanging on a dialog nobody could click.
' NO $RESIZE:STRETCH. The window surface is OURS (see Present in engine/UI.bas): CANVAS is an
' offscreen 132x51 character grid and screen 0 is a real window-sized image that Present blits
' into at an INTEGER scale. Letting the metacommand stretch a character grid by a fractional
' ratio is what made a resized window drop parts of the UI -- the same failure DRAW had.
CANVAS = _NEWIMAGE(SW * CW, SH * CH, 32)
CANVAS_COPY = _NEWIMAGE(SW * CW, SH * CH, 32)
FULL_BOARD = _NEWIMAGE(SW * CW, SH * CH, 32)
' The board is BOTH the picture and the collision map, so it is kept as two images: what the
' player sees (above) and what movement samples (below). See BuildBoardImages in engine/BOARD.bas.
FULL_COLLIDE = _NEWIMAGE(SW * CW, SH * CH, 32)
COLLIDE_BOARD = _NEWIMAGE(SW * CW, SH * CH, 32)
_TITLE "DUNGEON"
SCREEN _NEWIMAGE(SW * CW, SH * CH, 32)   ' the WINDOW -- starts at 1:1 with the canvas
_DISPLAYORDER _SOFTWARE , _HARDWARE      ' Present's smooth path draws on the HARDWARE layer,
'                                          which must composite OVER the software letterbox bars
_DEST CANVAS                             ' ...but everything draws to the canvas
_FONT CH
' NOTHING decides fullscreen here. This used to force `_FULLSCREEN _SQUAREPIXELS, _SMOOTH`
' unconditionally, BEFORE LoadSettings had even run -- so the game always came up fullscreen
' regardless of the player's saved Full Screen setting. ApplyDisplay (right after LoadSettings)
' is the single place that reads opt_fullscreen/opt_smooth, and there is no flash to guard
' against because $SCREENHIDE keeps the window hidden until _SCREENSHOW much later.

IF _DIREXISTS("gameplay-data-saves") = 0 THEN MKDIR "gameplay-data-saves"   ' all runtime saves/prefs/stats/maps live here (keeps the repo root clean); must exist before any load/save
SAVE_FILE = "gameplay-data-saves/dungeon-save.dat"   ' the save slot (engine reads this; `savetest` swaps it)

opt_music = TRUE: opt_sfx = TRUE: opt_showdice = TRUE: opt_fullscreen = TRUE
opt_voice = TRUE                              ' typewriter text speaks in blips
opt_musicvol = 4: opt_sfxvol = 4: opt_voicevol = 10  ' 0..10 volume sliders (maintainer's mix)
opt_duckamt = 6                                      ' music ducks to 40% under narration (0 off .. 10 silent)
opt_sfxpack = "found-on-disk-dnd-from-claude"        ' default SFX pack (assets/sfx/); falls back to the default pack
opt_musicpack = "soundmon-orchestral"                ' default music pack (assets/music/); falls back to the default pack
opt_narration = TRUE: opt_narrationpack = "grymmjack"           ' default: narration ON, the maintainer's recorded voice pack
opt_narrfreq = NARR_COMBAT                           ' default: narrate everything (flavor + events + combat)
opt_artpack = "default"                              ' default pixel-art pack (assets/pixel-art/default/); every pack is a named subfolder
opt_ansipack = "default"                             ' default ANSI-art pack (assets/ansi-art/default/); board + masks + menu art
opt_datapack = "default"                             ' default DATA pack (assets/data/default/ + assets/flavor/default/); a pack = a whole game's content
opt_realdice = FALSE: opt_dicemath = FALSE   ' default: the computer rolls + does the math
opt_oldschool = FALSE                         ' default: D&D d20/HP combat (on = classic Dungeon! 2d6)
opt_tactical = FALSE                          ' default off: the TACTICAL fight screen (1-vs-4, fuses + gestures)
opt_audiopref = AUDIOPREF_AUTO                ' which container wins when an asset ships in several (SETTINGS)
opt_statmethod = STAT_4D6DL                   ' default ability-roll method (see RollAbility%)
InitStatMethods                               ' the order the SETTINGS Stat Roll row presents them in
opt_luckfuse = 2                              ' default luck-prompt fuse, seconds (0 = untimed)
opt_flexstats = 2                             ' character build: 0 OFF (rolled) / 1 Assign roll / 2 Point distribution
opt_boardgame = FALSE                         ' default: free movement (single player); >1 player forces it ON
opt_movedice = TRUE                           ' default boardgame move: roll 1d6 (FALSE = DUNGEON! "up to 5, your choice")
opt_fov = FALSE                               ' default off: whole map visible (on = line-of-sight exploration)
num_players = 1                               ' hot-seat players (1..4); >1 forces Boardgame Mode
opt_dicecolor = 3                             ' dice palette: 0 Bone 1 Blood 2 Emerald 3 Sapphire 4 Gold 5 Amethyst
opt_dicesolid = TRUE                          ' filled die body with a contrasting number (off = hollow outline)
opt_d6pips = TRUE                             ' d6 rolls: TRUE = hand-drawn pips (default), FALSE = the font's numbered die
opt_dicespeed = 2                             ' dice tumble pacing: 0 Slow, 1 Normal, 2 Fast, 3 Instant
opt_dicelight = 3                             ' 3D dice top-light: 0 Off, 1 Soft, 2 Normal, 3 Strong
opt_diceround = 5                             ' 3D dice edge roundness 0 (sharp) .. 10 (very round)
opt_bloodstrength = 10                        ' near-death blood-grime intensity 0 (none) .. 10 (max)
opt_smoothamt = 2                             ' Smoothing: 0 off (crisp/integer) .. 3 full (softest)
opt_artstyle = 2                              ' default: Hybrid -- ANSI board + pixel-art portraits where they exist
opt_combatspeed = 1                           ' (legacy) superseded by opt_msgdelay
opt_msgdelay = 3                              ' message auto-advance hold: 1-5 seconds, or 0 = wait for a key
opt_hardcore = TRUE                           ' default on: time passes while idle (off = idling is safe)
opt_gestures = TRUE                           ' default on: Action Gestures (timing-bar second-wind + crit flourish, D&D mode)
opt_juice = TRUE                              ' default on: Screen Effects (hit-shake, blood/poison splatter, near-death vignette)
opt_critfumble = TRUE                         ' default on: the crit/fumble effects engine adds cinematics + swings
opt_mon_dicecolor = 1                         ' monster dice default to a menacing Blood red
opt_mon_dicesolid = TRUE: opt_mon_d6pips = TRUE: opt_mon_dicespeed = 1
opt_dice3d = TRUE: opt_mon_dice3d = TRUE      ' dice render: TRUE = 3D dice (default), FALSE = font/pip dice
opt_dice3d_set = 6: opt_mon_dice3d_set = 8    ' default 3D dice sets (overridden by save)
opt_dicefont = 4                              ' default dice numeral font index (overridden by save)
IF opt_oldschool THEN opt_lootrecovery = 0 ELSE opt_lootrecovery = 2   ' 0 OFF (lost), 1 NORMAL (always reclaim), 2 SOULS-LIKE (one chance)
opt_maxdeaths = 3                             ' lives before permadeath: reach 3 deaths and the run is forfeited (1..9)
opt_luck = TRUE                               ' CHA-funded re-rolls on combat rolls + saves (SETTINGS)
opt_startheal = TRUE                          ' returning to the entrance rests + heals you (SETTINGS)
opt_rest = TRUE                               ' [R] rests 1 HP at a time, at the risk of company
opt_solomode = 0: opt_solomins = 25           ' solo challenge: 0 off / 1 Time / 2 Item / 3 Prey; Time-Limit budget 25 min
LoadSettings                                  ' restore the player's saved preferences (overrides defaults)
IF NOT devmode THEN ApplyDisplay              ' fullscreen + smoothing per settings (skipped for CLI dev modes)
BOARD_ANSI = _READFILE$(AnsiFile$("board-132x50-no-labels.ans"))   ' same map, with secret doors (ANSI-pack aware)
' The collision + decoration LAYERS (`dungeon.run boardsplit` generates them from the board art).
' Fallback is per-file and deliberate: an art pack that ships only a combined board still plays,
' it just has no walk-over decoration. layer-1 alone is meaningless -- it would double-draw over
' a board that already contains it -- so a missing layer-0 discards both.
DIM lay0 AS STRING, lay1 AS STRING
lay0 = AnsiFile$("layer-0-board-collisions.ans")
lay1 = AnsiFile$("layer-1-board-decoration.ans")
IF LEN(lay0) > 0 THEN
    IF _FILEEXISTS(lay0) THEN COLLIDE_ANSI = _READFILE$(lay0)
END IF
IF LEN(lay1) > 0 THEN
    IF _FILEEXISTS(lay1) THEN DECOR_ANSI = _READFILE$(lay1)
END IF
IF LEN(COLLIDE_ANSI) = 0 THEN DECOR_ANSI = ""   ' no layer-0 -> layer-1 alone would double-draw
'                                                  (BuildBoardImages falls back to BOARD_ANSI)
LoadTuning                       ' gameplay balance knobs (assets/data/tuning.txt) -- before any play
LoadDiceColors                   ' the 6 dice palettes (assets/data/dice-colors.txt)
LoadStrings                      ' UI text lookup (assets/data/strings.txt) -- Say$("key")
LoadCutTriggers                  ' board-position cut-scene triggers (assets/data/triggers.txt)
LoadBoardOverlays                ' animated/still art placed on the board (assets/data/overlays.txt)
InitSectors
InitClasses
InitMonsterTables
LoadArtPrompts                   ' authored art direction merged into imagemanifest
InitDice
InitJuice                        ' build the screen-shake buffer + the near-death blood-grime pattern
LoadUIFonts                      ' per-region TTF UI fonts (assets/data/ui-fonts.txt)
LoadUIFrames                     ' 9-grid panel frames (assets/data/ui-frames.txt)
InitLabels                       ' build the room-label table + the label-cell mask (keeps monsters off labels)
InitEffects                      ' load the crit/fumble effect tables (assets/data/effects.txt)
LoadTraps                        ' load the curio-chest traps (assets/data/traps.txt)
LoadCurios                        ' load the curio event deck (assets/data/curios.txt)
LoadAmbience                      ' load the per-level ambient noise table (assets/data/ambience.txt)
LoadStatHelp                      ' what each ability DOES, for the character-creator panel
LoadMonsterEffects                ' poison/blight/curse/acid per monster (assets/data/monster-effects.txt)
LoadChamberEvents                 ' load the chamber event table (assets/data/chamber-events.txt)
InitFlavor                       ' load the room + combat flavor text (assets/flavor/*.txt)
InitCombatText                   ' load per-monster + per-class combat event text (assets/flavor/*_events.txt)
ScanAllPacks                     ' find sfx/music PACK subdirs (themes); validate the saved pick
LoadPlaylist                     ' load the per-level music map (assets/music/playlist.txt)

' text-only manifests exit HERE -- after the data they need, before the heavy graphics init
' (dice atlases / fonts / vignette). Window stays hidden ($SCREENHIDE), so no black flash.
' `audit` turns any manifest into a WORK LIST: only the assets the selected packs do not
' actually have. Matched as a WHOLE ARGUMENT, not with INSTR -- dev-mode names here are matched
' by substring and a sloppy test would fire on any mode whose name happened to contain it.
DIM mac AS INTEGER
FOR mac = 1 TO _COMMANDCOUNT
    IF UCASE$(_TRIM$(COMMAND$(mac))) = "AUDIT" THEN man_audit = TRUE
    ' pack=<name> -- which pack the manifest describes (audit target AND write path).
    IF UCASE$(LEFT$(_TRIM$(COMMAND$(mac)), 5)) = "PACK=" THEN man_pack = MID$(_TRIM$(COMMAND$(mac)), 6)
NEXT mac

IF INSTR(UCASE$(COMMAND$), "AUDIOMANIFEST") > 0 THEN DumpAudioManifest: SYSTEM
IF INSTR(UCASE$(COMMAND$), "IMAGEMANIFEST") > 0 THEN DumpImageManifest: SYSTEM
IF INSTR(UCASE$(COMMAND$), "CREATORSHOT") > 0 THEN
    DIM csArg AS INTEGER, csSel AS INTEGER
    csSel = 6
    FOR csArg = 1 TO _COMMANDCOUNT
        IF VAL(COMMAND$(csArg)) >= 1 AND VAL(COMMAND$(csArg)) <= 6 THEN csSel = VAL(COMMAND$(csArg)): EXIT FOR
    NEXT csArg
    DumpCreatorShot csSel
    SYSTEM
END IF

IF INSTR(UCASE$(COMMAND$), "STATSHOT") > 0 THEN
    BuildBoardImages
    DetectSecretDoors
    Game_PopulateBoard
    DumpStatPicker
    SYSTEM
END IF

IF INSTR(UCASE$(COMMAND$), "BALANCEDUMP") > 0 THEN
    DIM bdArg AS INTEGER, bdStats AS INTEGER
    FOR bdArg = 1 TO _COMMANDCOUNT
        IF INSTR(UCASE$(COMMAND$(bdArg)), "INCLUDESTATS") > 0 THEN bdStats = TRUE
    NEXT bdArg
    BalanceDump bdStats
    SYSTEM
END IF

IF INSTR(UCASE$(COMMAND$), "BESTIARYTEST") > 0 THEN BestiaryTest

IF INSTR(UCASE$(COMMAND$), "PLACEHOLDERS") > 0 THEN
    DIM phArg AS INTEGER, phClean AS INTEGER
    FOR phArg = 1 TO _COMMANDCOUNT
        IF UCASE$(_TRIM$(COMMAND$(phArg))) = "CLEAN" THEN phClean = TRUE
    NEXT phArg
    IF phClean THEN CleanPlaceholders ELSE MakePlaceholders
    SYSTEM
END IF
IF INSTR(UCASE$(COMMAND$), "UIMANIFEST") > 0 THEN DumpUiManifest: SYSTEM
IF INSTR(UCASE$(COMMAND$), "FIGHTMANIFEST") > 0 THEN DumpFightManifest: SYSTEM
IF INSTR(UCASE$(COMMAND$), "FIGHTLAYOUT") > 0 THEN DumpFightLayout: SYSTEM

InitSfxFiles                     ' preload any real sound-effect files (assets/sfx/[pack]/*); beeper covers the rest
MixerInit                        ' unity channel gains + music duck open (before any AudioTick)
LoadDiceSets                     ' load the 3D dice sets (assets/data/diceset.txt); font dice if it fails
LoadDiceFonts                    ' load the selectable 3D-dice numeral fonts (assets/fonts/dicefonts.txt)
player_class = 1                 ' default HERO until the player creates a character
InitDefaultChar 1                ' baseline stats so D&D combat works even without CREATE A CHARACTER

'--- dev: `dungeon.run settingsshot` renders the SETTINGS screen to a PNG and exits (layout check) ---
' `settingsshot [w] [h]` -- optional WINDOW size, so the canvas->window scaling Present does
' can be checked at a size that is NOT an exact multiple of the 1056x816 canvas. That case is
' precisely what a dragged/maximised window produces, and precisely what used to lose UI.
IF INSTR(UCASE$(COMMAND$), "SETTINGSSHOT") > 0 THEN
    DIM ssArg AS INTEGER, ssSeen AS INTEGER, ssW AS LONG, ssH AS LONG
    FOR ssArg = 1 TO _COMMANDCOUNT
        IF VAL(COMMAND$(ssArg)) > 0 THEN
            ssSeen = ssSeen + 1
            IF ssSeen = 1 THEN ssW = VAL(COMMAND$(ssArg))
            IF ssSeen = 2 THEN ssH = VAL(COMMAND$(ssArg))
        END IF
    NEXT ssArg
    IF ssW > 0 AND ssH > 0 THEN TakeWindowSize ssW, ssH: _DEST CANVAS: _FONT CH
    settingsshot_on = -1: RunSettings: SYSTEM
END IF

'--- dev: `dungeon.run fightshot` renders the TACTICAL COMBAT screen to a PNG and exits ---
' Seeds a synthetic 1-vs-4 encounter, so the screen and its art are verifiable with no
' combat loop in existence (see game/DEBUG.bas: DumpFightShot).
IF INSTR(UCASE$(COMMAND$), "FIGHTSHOT") > 0 THEN DumpFightShot: SYSTEM

'--- dev: `dungeon.run charsheet` renders the [C] CHARACTER sheet to a PNG and exits ---
' Seeds a MAXED-OUT hero, because that is the only state the sheet's layout can break in.
IF INSTR(UCASE$(COMMAND$), "CHARSHEET") > 0 THEN DumpCharSheet: SYSTEM

'--- dev: `dungeon.run storyshot` renders the [M] > Storybook at its extremes ---
IF INSTR(UCASE$(COMMAND$), "STORYSHOT") > 0 THEN DumpStorybook: SYSTEM DEV_FAIL

'--- dev: `dungeon.run gifsprite [file.gif]` -- does an animated GIF actually
'    animate through the ordinary Sprite& path every portrait already uses? ---
IF INSTR(UCASE$(COMMAND$), "GIFSPRITE") > 0 THEN DumpGifSprite: SYSTEM DEV_FAIL


'--- dev: `dungeon.run gaugeshot [depth] [hp]` renders the action-gesture gauge, BOTH forms ---
IF INSTR(UCASE$(COMMAND$), "GAUGESHOT") > 0 THEN DumpGaugeShot: SYSTEM

'--- dev: `dungeon.run summaryshot` renders the run scorecard (panel + TAB overlay) ---
IF INSTR(UCASE$(COMMAND$), "SUMMARYSHOT") > 0 THEN DumpSummaryShot: SYSTEM

'--- dev: `dungeon.run deathshot [class]` renders the animated death screen ---
IF INSTR(UCASE$(COMMAND$), "DEATHSHOT") > 0 THEN DumpDeathShot: SYSTEM

'--- dev: `dungeon.run automovetest` walks the real board and asserts progress ---
IF INSTR(UCASE$(COMMAND$), "FRAMEGEN") > 0 THEN DumpFrameGen: SYSTEM
IF INSTR(UCASE$(COMMAND$), "FRAMESHOT") > 0 THEN DumpFrameShot: SYSTEM
IF INSTR(UCASE$(COMMAND$), "BANNERSHOT") > 0 THEN DumpBannerShot: SYSTEM
IF INSTR(UCASE$(COMMAND$), "DICEOBJ") > 0 THEN DumpDiceObj: SYSTEM

IF INSTR(UCASE$(COMMAND$), "AUTOMOVETEST") > 0 THEN
    ' Same board a real run gets. Without this the cursor is at 0,0 on an unbuilt board and
    ' every path is trivially "unreachable" -- which is a broken TEST, not a broken walker.
    BuildBoardImages
    DetectSecretDoors
    DetectDoors
    Game_PopulateBoard
    RandomizeRooms
    InitFog
    c.x = START_CX * CW: c.y = START_CY * CH
    c.prev_x = c.x: c.prev_y = c.y
    DumpAutoMoveTest
    SYSTEM
END IF

'--- dev: `dungeon.run rollshot` shoots every dice style at its settled frame ---
' Needs the real board underneath (that is the check), so it takes the full board build.
IF INSTR(UCASE$(COMMAND$), "ROLLSHOT") > 0 THEN
    BuildBoardImages
    DetectSecretDoors
    Game_PopulateBoard
    RandomizeRooms
    DumpRollShot
    SYSTEM
END IF

'--- dev: `dungeon.run panelshot [class]` renders the D&D combat panel -> panelshot.png ---
IF INSTR(UCASE$(COMMAND$), "PANELSHOT") > 0 THEN
    DIM psArg AS INTEGER, psPc AS INTEGER
    psPc = 1
    FOR psArg = 1 TO _COMMANDCOUNT
        IF VAL(COMMAND$(psArg)) >= 1 AND VAL(COMMAND$(psArg)) <= 4 THEN psPc = VAL(COMMAND$(psArg)): EXIT FOR
    NEXT psArg
    BuildBoardImages
    DetectSecretDoors
    Game_PopulateBoard
    RandomizeRooms
    DumpCombatPanel psPc
    SYSTEM
END IF

'--- dev: `dungeon.run fight [lvl] [foes]` drops STRAIGHT into a playable tactical fight ---
' Unlike `fightshot` (which writes a PNG and exits) this is INTERACTIVE: it shows the window and
' runs the real loop, so the fight UI can be played and felt without walking the board to find an
' encounter first. Defaults to level 5 with 4 foes; `fight 9 2` overrides both.
'   dungeon.run fight        level 5, 4 foes
'   dungeon.run fight 1      level 1, 4 foes
'   dungeon.run fight 9 2    level 9, 2 foes
IF INSTR(UCASE$(COMMAND$), "FIGHT ") > 0 OR UCASE$(_TRIM$(COMMAND$)) = "FIGHT" THEN
    DIM AS INTEGER fgLvl, fgFoes, fgArg, fgSeen
    fgLvl = 5: fgFoes = 4: fgSeen = 0
    FOR fgArg = 1 TO _COMMANDCOUNT
        IF VAL(COMMAND$(fgArg)) > 0 THEN
            fgSeen = fgSeen + 1
            IF fgSeen = 1 THEN fgLvl = VAL(COMMAND$(fgArg))
            IF fgSeen = 2 THEN fgFoes = VAL(COMMAND$(fgArg))
        END IF
    NEXT fgArg
    IF fgLvl < 1 THEN fgLvl = 1
    IF fgLvl > 9 THEN fgLvl = 9
    IF fgFoes < 1 THEN fgFoes = 1
    IF fgFoes > FIGHT_MAXFOE THEN fgFoes = FIGHT_MAXFOE
    ' A fight needs a character. Nothing has rolled one on this path, so use the baseline HERO
    ' that InitDefaultChar already set up -- same stats a player gets before CREATE A CHARACTER.
    IF LEN(_TRIM$(player_name)) = 0 THEN player_name = "TESTER"
    IF player_maxhp < 1 THEN InitDefaultChar player_class
    player_hp = player_maxhp
    DevPackOverride                                       ' `fight 5 4 ansimon-1` previews a pack
    _SCREENSHOW: screen_shown = TRUE
    ApplyDisplay
    DIM AS INTEGER fgRes
    fgRes = RunFight%(fgLvl, fgFoes)                      ' QB64 needs a FUNCTION result consumed
    SYSTEM
END IF

'--- dev: `dungeon.run savetest` round-trips a synthetic 4-player save and exits ---
IF INSTR(UCASE$(COMMAND$), "SAVETEST") > 0 THEN SaveRoundTripTest

'--- dev: `dungeon.run datalint` validates the loaded content tables and exits ---
IF INSTR(UCASE$(COMMAND$), "DATALINT") > 0 THEN DataLint

'--- dev: `dungeon.run packs` lists the packs SETTINGS will actually offer ---
IF INSTR(UCASE$(COMMAND$), "PACKS") > 0 THEN PackList

'--- dev: `dungeon.run themelint` lists the theme colours and proves the file is being read ---
IF INSTR(UCASE$(COMMAND$), "THEMELINT") > 0 THEN ThemeLint

'--- dev: `dungeon.run statroll [n]` samples every ability-roll method and checks its shape ---
IF INSTR(UCASE$(COMMAND$), "STATROLL") > 0 THEN StatRollCheck VAL(NthField$(COMMAND$, " ", 2))

'--- dev: `dungeon.run ruleslint` prints the GENERATED half of the rules screen and exits ---
' The rules screen is assembled at display time from live settings + assets/data/stats.txt, so
' the parts a player reads most are the parts no file on disk contains. Nothing could check them
' headlessly. This prints exactly what ShowRules will prepend, and fails when the ability section
' is empty -- which is what a missing or mis-parsed stats.txt looks like from the player's side.
IF INSTR(UCASE$(COMMAND$), "RULESLINT") > 0 THEN RulesLint

'--- dev: `dungeon.run econdump` reports the expected gold economy + win pacing, then exits ---
IF INSTR(UCASE$(COMMAND$), "ECONDUMP") > 0 THEN EconDump

'--- dev: `dungeon.run boardsplit` writes the collision + decoration layers, then exits ---
IF INSTR(UCASE$(COMMAND$), "EVENTSAUDIT") > 0 THEN EventsAuditSensory: SYSTEM

IF INSTR(UCASE$(COMMAND$), "BOARDSPLIT") > 0 THEN BoardSplit

'--- dev: `dungeon.run boardfix [minsize]` repaints stray BROWN floor patches as path yellow ---
IF INSTR(UCASE$(COMMAND$), "BOARDFIX") > 0 THEN BoardFix

'--- dev: `dungeon.run sectorauto` derives each level's rect from the art and checks overlaps ---
IF INSTR(UCASE$(COMMAND$), "SECTORAUTO") > 0 THEN
    BuildBoardImages
    DeriveSectors                        ' geometry from the art -- measure what the GAME actually uses
    SectorAutoDerive
END IF

'--- dev: `dungeon.run roomlint` reports rooms holding cells the player cannot stand on ---
' Needs a built board (the art IS the map), so it runs the same setup chamberdump does.
IF INSTR(UCASE$(COMMAND$), "ROOMLINT") > 0 THEN
    BuildBoardImages
    DetectSecretDoors
    DetectDoors                     ' WalkLint tests every detected door by name -- without this DOOR_N is 0
    Game_PopulateBoard
    RandomizeRooms                  ' so the monster/treasure placement it reports is the real thing
    RoomLint
END IF

'--- dev: `dungeon.run triggerlint` validates board-position cut-scene triggers ---
' Needs a BUILT board, exactly as roomlint does: the walkability test reads the
' collision layer, and before BuildBoardImages that layer does not exist -- so
' every cell reads as solid and every trigger is reported as unreachable. A
' checker that confidently says "no" about everything is worse than no checker.
IF INSTR(UCASE$(COMMAND$), "TRIGGERLINT") > 0 THEN
    BuildBoardImages
    DetectSecretDoors
    DetectDoors
    Game_PopulateBoard
    DumpTriggerLint
    SYSTEM DEV_FAIL
END IF

'--- dev: `dungeon.run dataedit` -- the content tables as a grid. The files
'    stay hand-editable text; this only spares you counting columns by eye. ---
IF INSTR(UCASE$(COMMAND$), "DATAEDITTEST") > 0 THEN
    DEV_FAIL = DataEditSelfTest%("assets/data/" + opt_datapack + "/")
    IF DEV_FAIL > 0 THEN
        PRINT PipeCol$("|12" + LTRIM$(STR$(DEV_FAIL)) + " table(s) FAILED round-trip")
    ELSE
        PRINT PipeCol$("|10every table survives load -> save unchanged")
    END IF
    SYSTEM DEV_FAIL
END IF
IF INSTR(UCASE$(COMMAND$), "DATAEDITSHOT") > 0 THEN
    DataEditorShot DeArg$("assets/data/" + opt_datapack + "/monsters.txt", ".txt"), DeArg$("dataedit.png", ".png")
    SYSTEM
END IF
IF INSTR(UCASE$(COMMAND$), "DATAEDIT") > 0 THEN
    DataEditor "assets/data/" + opt_datapack + "/"
    SYSTEM
END IF

'--- dev: `dungeon.run mapdebug` -- the interactive map debugger. Every derived
'    layer (sectors, walkable, rooms, room-kind, doors, chambers, secret
'    regions, triggers/overlays, markers) toggleable on one screen, because the
'    questions are almost always about a RELATIONSHIP between two of them and a
'    PNG per layer cannot answer that. `mapdebugshot <layers> <out.png>` draws
'    one frame headlessly. ---
IF INSTR(UCASE$(COMMAND$), "MAPDEBUGSHOT") > 0 THEN
    BuildBoardImages
    DetectSecretDoors
    DetectDoors
    Game_PopulateBoard
    RandomizeRooms
    LoadCutTriggers
    LoadBoardOverlays
    InitFog
    DumpMapDebugShot MdArgMask$, MdArgOut$
    SYSTEM
END IF
IF INSTR(UCASE$(COMMAND$), "MAPDEBUG") > 0 THEN
    BuildBoardImages
    DetectSecretDoors
    DetectDoors
    Game_PopulateBoard
    RandomizeRooms
    LoadCutTriggers
    LoadBoardOverlays
    InitFog
    DumpMapDebug
    SYSTEM
END IF

'--- dev: `dungeon.run overlaylint` validates board overlays (same board setup) ---
IF INSTR(UCASE$(COMMAND$), "OVERLAYLINT") > 0 THEN
    BuildBoardImages
    DetectSecretDoors
    DetectDoors
    Game_PopulateBoard
    DumpOverlayLint
    SYSTEM DEV_FAIL
END IF

'--- dev: `dungeon.run cutwire` -- every scene the game can ask for ---
IF INSTR(UCASE$(COMMAND$), "CUTWIRE") > 0 THEN
    BuildBoardImages
    DetectSecretDoors
    Game_PopulateBoard
    LoadCutTriggers
    DumpCutWire
    SYSTEM DEV_FAIL
END IF

'--- dev: `dungeon.run chamberdump` renders the detected CHAMBER regions to a PNG and exits ---
IF INSTR(UCASE$(COMMAND$), "CHAMBERDUMP") > 0 THEN
    DIM AS INTEGER ddx, ddy, ddc
    BuildBoardImages
    DetectSecretDoors
    Game_PopulateBoard                   ' rooms + chambers (game hook #8)
    _DEST CANVAS: _PUTIMAGE (0, 0), FULL_BOARD, CANVAS
    FOR ddy = 0 TO 60
        FOR ddx = 0 TO 131
            IF CHAMBERAT(ddx, ddy) > 0 THEN LINE (ddx * CW, ddy * CH)-(ddx * CW + CW - 1, ddy * CH + CH - 1), _RGB32(255, 0, 255, 120), BF
        NEXT
    NEXT
    FOR ddc = 1 TO NCHAMBER
        COLOR _RGB32(&HFF, &HFF, &H00), _RGB32(0, 0, 0): _PRINTSTRING (CHM_CX(ddc) * CW, CHM_CY(ddc) * CH), _TRIM$(STR$(ddc)) + " " + _TRIM$(CHM_NAME(ddc)) + " (" + _TRIM$(STR$(CHM_CELLS(ddc))) + ")"
    NEXT
    _SAVEIMAGE "chamberdump.png", CANVAS
    '--- also dump each chamber's bounding box (cells) as text, for seeding chambers.txt ---
    DIM ddf AS INTEGER, ddi AS INTEGER, ddminx AS INTEGER, ddminy AS INTEGER, ddmaxx AS INTEGER, ddmaxy AS INTEGER
    DIM ddfree AS INTEGER, ddshadow AS INTEGER
    ddf = FREEFILE: OPEN "chamberdump.txt" FOR OUTPUT AS #ddf
    PRINT #ddf, "# secret doors detected: " + _TRIM$(STR$(SD_N)) + " | rooms: " + _TRIM$(STR$(ROOM_N)) + " | chambers: " + _TRIM$(STR$(NCHAMBER))
    PRINT #ddf, "# 'free' = chamber cells with NO room over them. Game_OnEnterCell suppresses the"
    PRINT #ddf, "# chamber trigger wherever ROOMAT<>0, so free = 0 means that hall can NEVER fire."
    FOR ddi = 1 TO NCHAMBER
        ddminx = 999: ddminy = 999: ddmaxx = -1: ddmaxy = -1: ddfree = 0: ddshadow = 0
        FOR ddy = 0 TO 60
            FOR ddx = 0 TO 131
                IF CHAMBERAT(ddx, ddy) = ddi THEN
                    IF ddx < ddminx THEN ddminx = ddx
                    IF ddx > ddmaxx THEN ddmaxx = ddx
                    IF ddy < ddminy THEN ddminy = ddy
                    IF ddy > ddmaxy THEN ddmaxy = ddy
                    IF ROOMAT(ddx, ddy) <> 0 THEN ddshadow = ddshadow + 1 ELSE ddfree = ddfree + 1
                END IF
            NEXT
        NEXT
        PRINT #ddf, _TRIM$(CHM_NAME(ddi)) + " | " + _TRIM$(STR$(ddminx)) + " | " + _TRIM$(STR$(ddminy)) + " | " + _TRIM$(STR$(ddmaxx)) + " | " + _TRIM$(STR$(ddmaxy)) + "   # sec " + _TRIM$(STR$(CHM_SEC(ddi))) + ", " + _TRIM$(STR$(CHM_CELLS(ddi))) + " cells, " + _TRIM$(STR$(ddfree)) + " free / " + _TRIM$(STR$(ddshadow)) + " room-shadowed"
    NEXT
    CLOSE #ddf
    SYSTEM
END IF

'--- dev: `dungeon.run fogdump` composes the fogged board (secret rooms + specks blacked) ---
IF INSTR(UCASE$(COMMAND$), "FOGDUMP") > 0 THEN
    BuildBoardImages
    InitFog
    _SAVEIMAGE "fogdump.png", CANVAS
    '--- region-overlay render (mimics the [~] mask view: per-region tint + level-coloured doors) ---
    DIM rvx AS INTEGER, rvy AS INTEGER
    _DEST CANVAS
    FOR rvy = 0 TO SH - 1
        FOR rvx = 0 TO SW - 1
            IF MASKREG(rvx, rvy) > 0 THEN LINE (rvx * CW, rvy * CH)-(rvx * CW + CW - 1, rvy * CH + CH - 1), MaskRegionColor~&(MASKREG(rvx, rvy), 150), BF
        NEXT
    NEXT
    IF MASK_ON THEN DrawMaskDoors
    _SAVEIMAGE "fogdump-regions.png", CANVAS
    '--- mask stats: secret cells, regions, and door->region mapping (0 = UNMAPPED = can't reveal) ---
    DIM fdx AS INTEGER, fdy AS INTEGER, fdsec AS LONG, fdreg AS INTEGER, fdunmap AS INTEGER, fdf AS INTEGER
    fdsec = 0: fdreg = 0
    FOR fdy = 0 TO SH - 1
        FOR fdx = 0 TO SW - 1
            IF SECRET(fdx, fdy) THEN fdsec = fdsec + 1
            IF MASKREG(fdx, fdy) > fdreg THEN fdreg = MASKREG(fdx, fdy)
        NEXT
    NEXT
    fdunmap = 0
    FOR fdx = 1 TO SD_N: IF DOOR_REGION(fdx) <= 0 THEN fdunmap = fdunmap + 1
    NEXT
    DIM fdsat AS LONG
    fdsat = 0
    FOR fdy = 0 TO SH - 1: FOR fdx = 0 TO SW - 1: IF SECTORAT(fdx, fdy) > 0 THEN fdsat = fdsat + 1
    NEXT: NEXT
    fdf = FREEFILE: OPEN "fogdump.txt" FOR OUTPUT AS #fdf
    PRINT #fdf, "SECTORMASK_ON= " + _TRIM$(STR$(SECTORMASK_ON)) + "   sector cells = " + _TRIM$(STR$(fdsat))
    PRINT #fdf, "MASK_ON      = " + _TRIM$(STR$(MASK_ON))
    PRINT #fdf, "secret cells = " + _TRIM$(STR$(fdsec))
    PRINT #fdf, "regions      = " + _TRIM$(STR$(fdreg))
    PRINT #fdf, "secret doors = " + _TRIM$(STR$(SD_N)) + "   (UNMAPPED to a region = " + _TRIM$(STR$(fdunmap)) + ")"
    PRINT #fdf, "region levels (id:lvl):"
    DIM fdl AS STRING, fdi AS INTEGER
    fdl = ""
    FOR fdi = 1 TO fdreg: fdl = fdl + " " + _TRIM$(STR$(fdi)) + ":" + _TRIM$(STR$(MASKLVL(fdi))): NEXT
    PRINT #fdf, fdl
    FOR fdx = 1 TO SD_N
        PRINT #fdf, "  door " + _TRIM$(STR$(fdx)) + " @ (" + _TRIM$(STR$(SD_X(fdx))) + "," + _TRIM$(STR$(SD_Y(fdx))) + ") -> region " + _TRIM$(STR$(DOOR_REGION(fdx))) + " lvl " + _TRIM$(STR$(MASKLVL(DOOR_REGION(fdx))))
    NEXT

    ' VERDICT, not just data. A secret REGION that no door opens is unreachable forever, and
    ' the mask is hand-painted ART -- an edit can orphan a region with no other symptom. That
    ' matters because killing the monster in key_room is the ONLY way to get the Level Key, so
    ' an orphaned region holding the key would make the run quietly unwinnable. RandomizeRooms
    ' now refuses to place the key in an unreachable room (RoomReachable%), but the region is
    ' still dead board -- its rooms, monsters and treasure can never be reached.
    DIM fdorph AS INTEGER, fdlist AS STRING, fdrooms AS INTEGER
    fdorph = 0: fdlist = ""
    FOR fdi = 1 TO fdreg
        IF NOT RegionHasDoor%(fdi) THEN fdorph = fdorph + 1: fdlist = fdlist + " " + _TRIM$(STR$(fdi))
    NEXT fdi
    fdrooms = 0
    FOR fdx = 1 TO ROOM_N
        IF NOT RoomReachable%(fdx) THEN fdrooms = fdrooms + 1
    NEXT fdx
    PRINT #fdf, ""
    IF fdorph > 0 THEN
        PRINT #fdf, "!! " + _TRIM$(STR$(fdorph)) + " ORPHANED region(s) -- no secret door opens them:" + fdlist
        PRINT #fdf, "!! " + _TRIM$(STR$(fdrooms)) + " room(s) inside them are unreachable (dead monsters + treasure)."
        PRINT #fdf, "!! Paint a door (bright blue) touching each, or repaint the region as public (black)."
        PRINT #fdf, "VERDICT: MASK HAS ORPHANED REGIONS"
    ELSE
        PRINT #fdf, "VERDICT: every secret region is opened by at least one door (" + _TRIM$(STR$(fdreg)) + " regions, " + _TRIM$(STR$(SD_N)) + " doors)"
    END IF
    CLOSE #fdf
    _DEST _CONSOLE
    IF fdorph > 0 THEN
        PRINT PipeCol$("|12fogdump: " + LTRIM$(STR$(fdorph)) + " ORPHANED secret region(s)|07 -- see fogdump.txt")
        SYSTEM 1
    END IF
    PRINT PipeCol$("|10fogdump: mask OK|07 -- all " + LTRIM$(STR$(fdreg)) + " secret regions have a door")
    SYSTEM 0
END IF

'--- dev: `dungeon.run maskgen` writes a STARTER secret-mask .ans from the current flood
'    (magenta block = secret cell). Only runs the flood (mask absent -> InitFog floods);
'    delete the mask first to regenerate. Then hand-refine it in your ANSI editor. ---
IF INSTR(UCASE$(COMMAND$), "MASKGEN") > 0 THEN
    IF _FILEEXISTS("assets/ansi-art/default/board-132x50-secret-mask.ans") THEN
        _DEST _CONSOLE
        PRINT PipeCol$("|14board-132x50-secret-mask.ans already exists -- NOT regenerating|07 (would clobber your")
        PRINT PipeCol$("hand-painted mask). |12Delete the file first|07 if you really want a fresh starter.")
        SYSTEM
    END IF
    BuildBoardImages
    InitFog                                   ' floods SECRET() (mask file not present yet)
    DIM mgf AS INTEGER, mgy AS INTEGER, mgx AS INTEGER, mgs AS STRING, sauce AS STRING, eofc AS STRING, mglast AS INTEGER
    mgs = "": mglast = -999
    FOR mgy = 0 TO SH - 2                      ' 50 board rows (row 50 = HUD line, never secret)
        FOR mgx = 0 TO SW - 1
            DIM mgsec AS INTEGER
            mgsec = (SECRET(mgx, mgy) <> 0)    ' magenta BACKGROUND for secret, black for public (bg+space fills the cell)
            IF mgsec <> mglast THEN
                IF mgsec THEN mgs = mgs + CHR$(27) + "[45m" ELSE mgs = mgs + CHR$(27) + "[0m"
                mglast = mgsec
            END IF
            mgs = mgs + " "
        NEXT mgx
        mgs = mgs + CHR$(27) + "[0m" + CHR$(13) + CHR$(10): mglast = -999
    NEXT mgy
    ' --- SAUCE record (128 bytes) so ANSI editors read the 132x50 dims + IBM VGA font
    '     (layout per ~/git/img2ans include/SAUCE/SAUCE.BI) ---
    sauce = "SAUCE" + "00"
    sauce = sauce + PadR$("DUNGEON! secret-door mask", 35)
    sauce = sauce + PadR$("grymmjack", 20)
    sauce = sauce + PadR$("", 20)
    sauce = sauce + MID$(DATE$, 7, 4) + MID$(DATE$, 1, 2) + MID$(DATE$, 4, 2)   ' Date CCYYMMDD
    sauce = sauce + MKL$(LEN(mgs))             ' FileSize = data length before the EOF marker
    sauce = sauce + CHR$(1) + CHR$(1)          ' DataType = Character, FileType = ANSi
    sauce = sauce + MKI$(SW) + MKI$(SH - 1)    ' TInfo1 = 132 cols, TInfo2 = 50 lines
    sauce = sauce + MKI$(0) + MKI$(0)          ' TInfo3 / TInfo4
    sauce = sauce + CHR$(0) + CHR$(0)          ' Comments = 0, TFlags = 0
    sauce = sauce + "IBM VGA" + STRING$(15, 0) ' TInfoS = font name, null-padded to 22
    eofc = CHR$(26)                            ' SAUCE sits after a 0x1A EOF marker
    mgf = FREEFILE
    OPEN "assets/ansi-art/default/board-132x50-secret-mask.ans" FOR BINARY AS #mgf
    PUT #mgf, 1, mgs
    PUT #mgf, , eofc
    PUT #mgf, , sauce
    CLOSE #mgf
    SYSTEM
END IF

' `dungeon.run sectorgen` is RETIRED along with the sector mask it wrote. Level geometry is
' derived from the board art by DeriveSectors (game/SECTOR.bas): tight per-colour boxes, then
' expanded until they meet. There is no second file to keep in step with the art any more.

'--- dev: `dungeon.run ansilint [file]` lints a mask ANSI for the art-as-data gotchas
'    (CRLF black bands, sticky-SGR/blink leaks, row width, SAUCE, colours->sectors). With no
'    file it checks both board masks. Read-only: it never writes. ---
IF INSTR(UCASE$(COMMAND$), "ANSILINT") > 0 THEN
    DIM alpath AS STRING, alc AS INTEGER
    FOR alc = 1 TO _COMMANDCOUNT
        IF UCASE$(COMMAND$(alc)) <> "ANSILINT" AND UCASE$(COMMAND$(alc)) <> "NOCOLOR" THEN alpath = COMMAND$(alc)
    NEXT alc
    _DEST _CONSOLE: PRINT
    IF LEN(alpath) > 0 THEN
        ' a collision LAYER is a different artefact from a mask -- it is checked for stray
        ' colours movement cannot read, not for colour->zone mapping
        IF INSTR(UCASE$(alpath), "COLLISION") > 0 THEN CollisionLayerLint alpath ELSE AnsiLint alpath
    ELSE
        AnsiLint "assets/ansi-art/default/board-132x50-secret-mask.ans"
        CollisionLayerLint AnsiFile$("layer-0-board-collisions.ans")
    END IF
    SYSTEM
END IF

'--- dev: `dungeon.run ansifix <file>` rewrites a mask ANSI to the clean canonical form
'    (strip CR/LF blanks + reset each SGR run + fresh SAUCE), backing up the original to
'    <file>.bak. The loaders already normalise at load; this cleans the STORED file. ---
IF INSTR(UCASE$(COMMAND$), "ANSIFIX") > 0 THEN
    DIM afpath AS STRING, afc AS INTEGER
    FOR afc = 1 TO _COMMANDCOUNT
        IF UCASE$(COMMAND$(afc)) <> "ANSIFIX" AND UCASE$(COMMAND$(afc)) <> "NOCOLOR" THEN afpath = COMMAND$(afc)
    NEXT afc
    _DEST _CONSOLE: PRINT
    IF LEN(afpath) = 0 THEN
        PRINT PipeCol$("|14usage:|07 dungeon.run ansifix <file.ans>   (rewrites it clean; backs up to <file>.bak)")
    ELSE
        AnsiFix afpath
    END IF
    SYSTEM
END IF

'--- dev: `dungeon.run audiomanifest` prints every sfx / music / narration file the engine
'    will look for (computed from the loaded data), so the audio generators know what to make. ---
' (audio/image/ui manifests already handled earlier -- they exit before the heavy init)

' ---------------------------------------------------------------- state machine
_SCREENSHOW: screen_shown = TRUE       ' normal play only (dev modes SYSTEM'd already): reveal the window
DIM game_state AS INTEGER, r AS INTEGER, o AS INTEGER
game_state = ST_INTRO
DO
    SELECT CASE game_state
        CASE ST_INTRO
            ShowIntro
            game_state = ST_MENU
        CASE ST_MENU
            r = RunMenu
            IF r = MENU_ENTER THEN game_state = ST_PLAY ELSE game_state = ST_QUIT
        CASE ST_PLAY
            hud_live = TRUE                      ' the board is the screen -> DrawHUD may paint
            o = PlayGame
            hud_live = FALSE                     ' ...and is not, once we are back in the menus
            StopLevelMusic                       ' silence the in-game track before the menu music resumes
            SELECT CASE o
                CASE OUT_WIN: game_state = ST_WIN
                CASE OUT_LOSE: game_state = ST_LOSE
                CASE ELSE: game_state = ST_MENU
            END SELECT
        CASE ST_WIN
            ShowEnd TRUE
            game_state = ST_MENU
        CASE ST_LOSE
            ShowEnd FALSE
            game_state = ST_MENU
        CASE ST_QUIT
            EXIT DO
    END SELECT
LOOP

_FULLSCREEN _OFF
SCREEN 0: _DEST 0
_DELAY 0.5
_FREEIMAGE CANVAS
_FREEIMAGE CANVAS_COPY
_FREEIMAGE FULL_BOARD
_FREEIMAGE FULL_COLLIDE
_FREEIMAGE COLLIDE_BOARD
IF FX_BUF <> 0 THEN _FREEIMAGE FX_BUF
SYSTEM

' ============================================================================
'  FATAL ERROR HANDLER -- print and die, never open a dialog.
'
'  An UNHANDLED QB64 runtime error opens a modal message box ("Line: 165 ... File not found /
'  Continue? [Yes] [No]") and waits for a click. Under xvfb -- every dev mode, every gate run,
'  every headless capture -- there is nobody to click it, so the process hangs until something
'  times it out, with no output saying why. That has cost real time more than once.
'
'  ON ERROR takes the dialog out of the picture entirely: the error goes to the CONSOLE in a
'  greppable form and the process exits NON-ZERO, which is what a script can actually act on.
'  No RESUME -- a runtime error here means an assumption broke, and limping on would turn one
'  clear failure into a confusing cascade.
' ============================================================================
DungeonFatal:
    err_seen = err_seen + 1
    _DEST _CONSOLE
    PRINT ""
    PRINT "!! QB64 RUNTIME ERROR " + LTRIM$(STR$(ERR)) + " at line " + LTRIM$(STR$(_ERRORLINE))
    PRINT "!! " + _ERRORMESSAGE$
    ' _ERRORLINE alone is nearly useless here: dungeon.bas is a thin assembly of ~40 included
    ' modules, so a line number with no file could be in any of them. _INCLERRORFILE$ names the
    ' include the error actually happened in (empty when it was dungeon.bas itself).
    IF LEN(_INCLERRORFILE$) > 0 THEN PRINT "!! in " + _INCLERRORFILE$ + ":" + LTRIM$(STR$(_INCLERRORLINE))
    ' What happens next depends on WHO is watching, and the two answers are opposites:
    '
    '   a DEV MODE / headless run has no player -- a script wants a clean, greppable failure and
    '   a non-zero exit, and limping on would turn one clear error into a confusing cascade.
    '
    '   a PLAYER mid-run does not want their expedition ended because one optional asset was
    '   missing. RESUME NEXT skips the broken statement and carries on, which for a missing
    '   sprite or sound is exactly right.
    '
    ' The cap is the safety net: an error inside the 60fps loop would otherwise print forever
    ' and never recover, so after ERR_MAX we stop pretending it is survivable.
    IF NOT screen_shown THEN
        PRINT "!! no window is up -- nobody can see or click anything, so aborting"
        PRINT "!! (a dialog here would hang a headless run forever; see ON ERROR in dungeon.bas)"
        SYSTEM 1
    END IF
    IF err_seen > ERR_MAX THEN
        PRINT "!! " + LTRIM$(STR$(err_seen)) + " runtime errors -- this is not survivable, aborting"
        SYSTEM 1
    END IF
    PRINT "!! continuing (RESUME NEXT) -- " + LTRIM$(STR$(ERR_MAX - err_seen)) + " more before abort"
    RESUME NEXT

' ============================================================================
'  CORE GAME LOOP
' ============================================================================

FUNCTION PlayGame%
    DIM k AS STRING
    DIM AS INTEGER sec, res, idle_ticks, sd, mvb, curlvl, heart_tick, hbeat

    DIM i AS INTEGER
    DIM hint AS STRING
    DIM didload AS INTEGER
    didload = FALSE
    SoloReset                        ' solo state off until a fresh run activates it (loaded games play normal)
    IF HasSave THEN                  ' a saved delve exists -- offer to continue it
        IF AskContinue THEN LoadGameApply: didload = TRUE
    END IF

    IF NOT didload THEN
        SetupPlayers                     ' build every player (multiplayer: class + 3d6 roll-up + name each)
        game_start = TIMER               ' start the run timer
        ChronicleReset                   ' fresh event log + per-run stats for the Game Menu screens
        moves_made = 0: turn_num = 0: steps_left = 0
        cur_player = 1
        run_seed = INT(RND * 2000000000) + 1   ' seed this dungeon so save/load can reproduce it exactly
        RANDOMIZE run_seed
        StartBoard                       ' build the board + fog + DetectRooms (resets the cursor to START)
        RandomizeRooms                   ' give every detected room its own monster + treasure (+ the key room)
        ' Per-SEAT run state (inventory, potions, spell charges, level/XP, status timers) is
        ' initialised inside SetupPlayers -- including a spellbook for EVERY Wizard seat -- and
        ' arrives in the working globals via LoadActivePlayer. It used to be reset HERE instead,
        ' i.e. once, after the active player was already loaded: so those values were shared by
        ' all hot-seat players and only seat 1 could ever be handed a spellbook.
        LoadActivePlayer cur_player      ' player 1 becomes the active player (kit / pos / colour / stats)
        StartTurnMove                    ' set turn 1's move budget (roll 1d6 / up-to-5 / free)
        ' --- genuinely run-wide state (NOT per seat) ---
        loiter = 0                       ' fresh danger meter for lingering
        curio_cool = 0                   ' path curios may start turning up right away
        FOR i = 1 TO 9: lvl_kills(i) = 0: lvl_gold(i) = 0: lvl_reached(i) = FALSE: lvl_cleared(i) = FALSE: NEXT i   ' fresh chronicle
        lvl_reached(1) = TRUE            ' you start on the 1st level
        deaths(1) = 0: deaths(2) = 0: deaths(3) = 0: deaths(4) = 0           ' fresh skull tally (already per-player)
        player_out = FALSE                                                  ' nobody has forfeited yet

        DIM ident AS STRING                                                 ' "Grognard the Fast, a HERO" (or "the HERO" if unnamed)
        IF _TRIM$(player_name) <> "" THEN ident = _TRIM$(player_name) + ", a " + class_name ELSE ident = "the " + class_name

        ' A CUT-SCENE takes precedence over the crawl, when the pack ships one.
        ' It keeps the SAME narration key, so a narration pack that already
        ' voices intro.descent voices the cut-scene too, unchanged -- and a pack
        ' with no intro.cut still gets the crawl it always had.
        IF PlayCutscene%("intro") = 0 THEN
        IF num_players > 1 THEN
            ScrollTextVO "THE DESCENT", "Torchlight gutters as " + _TRIM$(STR$(num_players)) + " rivals cross the threshold into the ancient dungeon. Nine levels coil below, each darker and deadlier than the last. The Level Key is said to lie on the " + Ordinal$(key_level) + " level. Whoever is first to claim its key, a fortune in gold, and return alive to this entrance wins eternal glory. Let the delving begin.", "intro.descent"
        ELSE
            ScrollTextVO "THE DESCENT", "Torchlight gutters as you, " + ident + ", cross the threshold into the ancient dungeon. Nine levels coil below, each darker and deadlier than the last. The Level Key is rumoured to lie on the " + Ordinal$(key_level) + " level -- take it, gather " + _TRIM$(STR$(target_gold)) + " gold, and return alive to this entrance. A Crystal Ball would reveal exactly which room hides it. Few ever escape.", "intro.descent"
        END IF
        END IF
    END IF

    cursor_erase: cursor_draw        ' clear the narration, reveal the board
    IF opt_boardgame THEN
        hint = "[SPACE] end turn  "
    ELSE
        hint = ""
    END IF
    IF didload THEN
        Banner "-- RESUMED --  " + _TRIM$(player_name) + " the " + class_name + " returns to the depths.", "[G] saves your progress anytime.   [ press any key ]"
    ELSE
        Banner "Gather " + _TRIM$(STR$(target_gold)) + " gold AND the Level Key, then return to START.", hint + "move  [F] search  [G] save  [?] keys  fight  ESC flee"
    END IF
    WaitKey
    IF NOT didload THEN AnnounceTurn cur_player   ' multiplayer: announce whose turn it is
    IF NOT didload THEN SoloBegin                 ' single-player: arm the chosen solo challenge
    cursor_erase: cursor_draw
    DrawHUD: Present

    DIM startlvl AS INTEGER                        ' start this level's music before the first step
    StopLevelMusic                                 ' kill any leftover track (last run/menu) so it can't linger if the start sector has none
    startlvl = PlayerLevel%
    ' SEED the deepest-level stat from where you are STANDING, not from the first step you take.
    ' RecordDepth was written but never called by anything, so `deepest level` sat at 0 for a whole
    ' run; and even once the play loop bumps it per move, a player who has not moved yet is still
    ' honestly ON level 1, not on level 0.
    RecordDepth startlvl
    IF LEN(_TRIM$(MUSIC_FILE(startlvl))) = 0 THEN startlvl = 1   ' start sector has no track -> fall back to level 1's
    PlayLevelMusic startlvl

    DO
        _LIMIT 60
        AudioTick                                 ' advance music crossfade + narration fade each frame
        AmbienceTick                              ' a distant noise now and then, chosen by the level you are on
        IF display_dirty THEN                     ' ...and repaint the whole board once it has settled
            display_dirty = 0
            cursor_erase: cursor_draw: DrawHUD: Present
        END IF
        IF player_out THEN                        ' the active player has spent their last life
            ' solo (or last one standing) -> the run is over for good. Delete the save so a
            ' permadeath run can never be "continued" back to life.
            IF HandleForfeit THEN DeleteSave: PlayGame = OUT_LOSE: EXIT FUNCTION
        END IF
        k = UCASE$(INKEY$)
        k = NormKey$(k)              ' fold arrow keys + numpad into WASD + diagonals

        ' AUTO-MOVE steers by synthesising a DIRECTION key, so the step goes through exactly
        ' the same TryMove a player drives -- door hops, room/chamber triggers, curio rolls and
        ' status ticks all still fire. A real keypress is read first and always wins, and ANY
        ' key stops the walker: taking the controls back should not require finding a menu.
        IF automove_run THEN
            IF LEN(k) > 0 THEN
                AutoMoveStop "You took the controls back."
            ELSE
                AutoMoveCheck
                IF automove_run THEN
                    IF TIMER - automove_t0 >= AUTOMOVE_STEP_SEC OR TIMER - automove_t0 < 0 THEN
                        automove_t0 = TIMER
                        DIM amgx AS INTEGER, amgy AS INTEGER, amdir AS STRING
                        IF AutoMoveGoal%(amgx, amgy) THEN
                            amdir = AutoMoveDir$(amgx, amgy)
                            IF LEN(amdir) > 0 THEN
                                k = amdir
                            ELSE
                                AutoMoveStop "There is no route from here."
                            END IF
                        ELSE
                            AutoMoveStop "Nothing left to walk to."
                        END IF
                    END IF
                END IF
            END IF
        END IF

        ' HARDCORE only: standing idle counts as lingering -- time passes, danger gathers.
        ' In casual mode (default) you can stand still and plan in perfect safety.
        IF k <> "" THEN
            idle_ticks = 0
        ELSEIF opt_hardcore THEN
            idle_ticks = idle_ticks + 1
            IF idle_ticks >= 600 THEN
                idle_ticks = 0
                IF NOT InRoomNow THEN LoiterTick   ' danger gathers only out in the open halls
            END IF
        END IF

        ' near-death heartbeat (D&D mode): a low thud that races as your HP runs out
        IF NOT opt_oldschool AND player_maxhp > 0 AND player_hp > 0 AND player_hp <= player_maxhp \ 4 THEN
            heart_tick = heart_tick + 1
            hbeat = 50: IF player_hp <= player_maxhp \ 10 THEN hbeat = 30   ' racing when critical
            IF heart_tick >= hbeat THEN heart_tick = 0: Sfx "heartbeat"
        ELSE
            heart_tick = 0
        END IF

        IF k = CHR$(27) THEN PlayGame = OUT_FLEE: EXIT FUNCTION
        IF k = "F" THEN DoSearch
        IF k = "C" THEN ShowCharSheet
        IF k = "V" THEN ScryView
        IF k = "H" THEN UsePotion FALSE: cursor_erase: cursor_draw: DrawHUD: Present
        IF k = "P" THEN PauseGame: idle_ticks = 0
        IF k = "G" THEN SaveAndToast: idle_ticks = 0   ' hot-seat saves too as of save v5 (PLRS block)
        IF k = "?" OR k = "/" THEN ShowKeys
        IF k = CHR$(9) THEN                                   ' [TAB] -- the scoreboard, as in any shooter
            opt_statsoverlay = NOT opt_statsoverlay
            Sfx "select": cursor_erase: cursor_draw: DrawHUD: Present
            idle_ticks = 0
        END IF
        ' [Shift-TAB] -- swap that same box between RUN STATS and BEARINGS (what is playing, what
        ' art is on screen, which sector/cell you are standing on). It SHOWS the box as well as
        ' swapping it, because pressing it while the box is hidden otherwise looks like a dead key.
        IF k = CHR$(0) + CHR$(15) THEN
            overlay_mode = 1 - overlay_mode
            opt_statsoverlay = TRUE
            Sfx "select": cursor_erase: cursor_draw: DrawHUD: Present
            idle_ticks = 0
        END IF
        IF k = "L" THEN FindPlayerFlash: idle_ticks = 0        ' [L] -- locate me (was TAB)
        IF k = "Z" AND opt_automove THEN                       ' [Z] -- let the walker take over
            AutoMoveBegin
            Banner "AUTO-MOVE", "Walking the dungeon, shallowest level first. Any key stops it.   [ press any key ]"
            WaitKey
            cursor_erase: cursor_draw: DrawHUD: Present
            idle_ticks = 0
        END IF
        IF k = "R" THEN DoRest: idle_ticks = 0                ' [R] -- rest a point, and roll for company
        IF k = "M" THEN GameMenu: cursor_erase: cursor_draw: DrawHUD: Present
        ' [~] only -- BACKTICK is the dev console now, and it is handled in Present so it opens
        ' from every screen, not just this loop.
        IF k = "~" THEN
            dbg_on = NOT dbg_on
            IF NOT dbg_on THEN cursor_erase: cursor_draw: DrawHUD: Present   ' wipe the frozen debug overlay off the board
        END IF
        IF dbg_on AND k = "0" THEN DebugTestMenu   ' [~] on -> [0] opens the cheat/test panel

        IF k = "T" AND item_teleport > 0 THEN     ' Teleport Scroll -- whisk back to START
            item_teleport = item_teleport - 1
            RecordItemUsed "teleport scroll"
            Sfx "teleport"
            PopArt "Teleport Scroll", "TELEPORT SCROLL"       ' show the scroll art as you use it
            Banner "You read a TELEPORT SCROLL -- reality folds around you!", "You reappear at the entrance.   [ press any key ]"
            WaitKey
            c.x = START_CX * CW: c.y = START_CY * CH: c.prev_x = c.x: c.prev_y = c.y
            ' NO free heal: a scroll is an ESCAPE, not a rest. It used to set player_hp =
            ' player_maxhp outright, which made [T] a full heal you could stock up on -- and
            ' the entrance heal would then hand it to you again on the next step anyway.
            start_heal_locked = TRUE
            loiter = 0
            StartTurnMove                    ' fresh move budget after the jump
            cursor_erase: cursor_draw: FadeInCurrent: DrawHUD: Present
        END IF

        IF need_roll THEN
            IF k = " " THEN
                turn_num = turn_num + 1
                mvb = 0: IF item_boots THEN mvb = 2       ' Elf Boots add to the movement roll
                steps_left = DoRoll(1, mvb, "your MOVEMENT roll")
                need_roll = FALSE
                cursor_erase             ' wipe the dice box, restore the board
                cursor_draw
            END IF
        ELSE
            ' Up-to-5 movement (Boardgame): SPACE ends your turn early -- you choose how far to
            ' go this turn (up to 5 spaces), no die.
            IF k = " " AND opt_boardgame THEN
                EndPlayerTurn: cursor_erase: cursor_draw
            ' frozen by a frost bomb? each move attempt just melts a turn off the ice
            ELSEIF IsMoveKey(k) AND frost_turns > 0 THEN
                frost_turns = frost_turns - 1
                Sfx "bump"
                Banner "You are frozen fast!", "The rime locks your limbs (" + _TRIM$(STR$(frost_turns)) + " turns of frost remain)."
                _DELAY 0.7
                cursor_erase: cursor_draw: DrawHUD: Present
            ' board-game mode gates movement on the dice roll + steps; free mode walks anytime
            ELSEIF IsMoveKey(k) AND (NOT opt_boardgame OR steps_left > 0) THEN
                sd = StrongDoorAhead(k)
                IF sd > 0 THEN
                    ' a reinforced door blocks the way -- spend the step trying to break it
                    IF opt_boardgame THEN steps_left = steps_left - 1
                    IF BreakDoorAttempt(sd) THEN
                        IF TryMove(k) THEN
                            moves_made = moves_made + 1
                            IF OnDoorNow THEN
                                DOOROPEN(c.x \ CW, c.y \ CH) = TRUE   ' broken door is now open (FOV)
                                IF TryMove(k) THEN moves_made = moves_made + 1
                            END IF
                        END IF
                    END IF
                    IF opt_boardgame AND steps_left <= 0 THEN EndPlayerTurn
                ELSEIF TryMove(k) THEN
                    IF opt_boardgame THEN steps_left = steps_left - 1
                    moves_made = moves_made + 1
                    loiter = 0                     ' moving on resets the lingering danger meter
                    ' out on the paths, a curio rarely turns up (D&D mode, corridors only, cooldown-gated)
                    IF curio_cool > 0 THEN curio_cool = curio_cool - 1
                    IF NOT opt_oldschool AND curio_cool <= 0 THEN
                        IF ROOMAT(c.x \ CW, c.y \ CH) = 0 THEN     ' on a corridor, not inside a room
                            IF RollDie(100) <= CURIO_PATH_PCT THEN curio_cool = CURIO_COOLDOWN: DoCurio 0
                        END IF
                    END IF
                    TickStatus                     ' poison/fire bite, siren winds down as a turn passes
                    IF siren_turns > 0 THEN         ' a wailing siren drags monsters to you as you move
                        IF RollDie(100) <= SIREN_MOVE_PCT THEN WanderEncounter
                    END IF
                    curlvl = PlayerLevel%                 ' chronicle the levels you tread (sticky in unclaimed corridors)
                    RecordDepth curlvl                    ' "deepest level reached" in the run stats
                    IF curlvl >= 1 AND curlvl <= 9 THEN
                        IF NOT lvl_reached(curlvl) THEN
                            lvl_reached(curlvl) = TRUE
                            ' The descent beat, the FIRST time each level is reached in a
                            ' run. Level 1 is skipped: the intro already covered arriving,
                            ' and two openings back to back is one too many.
                            IF curlvl >= 2 THEN
                                IF PlayCutscene%("descend") THEN cursor_erase: cursor_draw
                            END IF
                            IF player_class = 4 THEN                    ' a WIZARD's power grows as they descend
                                DIM rcl AS INTEGER
                                rcl = 1 + SpellRecallBonus%                 ' INT: a sharp Wizard recalls more
                                spell_fire = spell_fire + rcl: spell_bolt = spell_bolt + rcl
                                Sfx "levelup"
                                IF rcl > 1 THEN
                                    Banner "The deeper magic answers you.", "Your INTELLECT recalls " + _TRIM$(STR$(rcl)) + " of each spell.   [ press any key ]"
                                ELSE
                                    Banner "The deeper magic answers you.", "You gain a Fire Ball and a Lightning Bolt.   [ press any key ]"
                                END IF
                                WaitKey
                            END IF
                        END IF
                    END IF
                    PlayLevelMusic curlvl                 ' switch to this level's track (no-op if unchanged)
                    ' step THROUGH a door, don't stop on it: auto-advance one more cell
                    ' the same direction (a free hop -- costs no movement point)
                    IF OnDoorNow THEN
                        DOOROPEN(c.x \ CW, c.y \ CH) = TRUE   ' opening the door lets you see through it (FOV)
                        IF TryMove(k) THEN moves_made = moves_made + 1
                    END IF
                    ' hand off to the GAME: every consequence of arriving on this cell
                    ' (entrance heal, room/chamber encounter, loot pickup, the win check).
                    ' The engine owns "where the player is"; the game owns "what it means".
                    res = Game_OnEnterCell%(c.x \ CW, c.y \ CH)
                    IF res = OUT_WIN THEN PlayGame = OUT_WIN: EXIT FUNCTION
                    IF opt_boardgame AND steps_left <= 0 THEN EndPlayerTurn
                END IF
            END IF
        END IF

        IF solo_on THEN SoloTick                   ' solo challenge: timer / two-deaths / the hunter's step
        IF dbg_on OR solo_on THEN cursor_erase: cursor_draw   ' redraw each frame so the crosshair / hunter token can't ghost
        DrawHUD
        IF solo_on THEN DrawSoloHUD                 ' the solo status ribbon (timer / quest / hunter distance)
        IF dbg_on THEN DrawDebug
        Present
        IF solo_result = OUT_LOSE THEN
            Banner "SOLO CHALLENGE LOST", solo_msg + "   [ press any key ]"
            WaitKey
            DeleteSave: PlayGame = OUT_LOSE: EXIT FUNCTION
        ELSEIF solo_result = OUT_WIN THEN
            DeleteSave: PlayGame = OUT_WIN: EXIT FUNCTION
        END IF
    LOOP
END FUNCTION

' ============================================================================
'  MODULES
' ============================================================================
' --- module bodies. Order is irrelevant (QB64 resolves procedures globally and no body
'     declares anything at file scope); the roll-ups keep this assembly to two lines. ---
'$INCLUDE:'engine/_ALL.BM'      ' ALL engine bodies
'$INCLUDE:'game/_ALL.BM'        ' ALL game bodies

