' ============================================================================
'  DUNGEON  -  a QB64PE adaptation of TSR's DUNGEON! (1975) board game
'  Vertical slice: INTRO -> MENU -> PLAY (turn/dice movement + combat) -> END
'
'  Build:  qb64pe -w -x dungeon.bas -o dungeon.run   (run from repo root)
'  Run `dungeon.run --help` for command-line modes.
' ============================================================================
' a console (hidden in normal play) so `dungeon.run --help` can print to the terminal:
$CONSOLE
'$INCLUDE:'include/ansi/ANSIPrint.bi'   ' vendored ANSI renderer (decoupled from Toolbox64 submodule); file reads use _READFILE$

'$INCLUDE:'engine/ENGINE.BI'    ' reusable engine globals/types/consts (must load first)
'$INCLUDE:'game/GAME.BI'        ' DUNGEON!-specific globals/types/consts (the swappable layer)
'$INCLUDE:'include/DICE3D/_ALL.BI'      ' 3D polyhedral dice (types + globals; bodies at bottom)
'$INCLUDE:'include/DICE3D_GAME.bi'      ' dungeon-side 3D dice sets (needs DICE3D_CONFIG from _ALL.BI)
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
    PRINT PipeCol$("  |10maskgen|07       starter secret-door mask from the flood -> assets/ansi/board-132x50-secret-mask.ans")
    PRINT PipeCol$("  |10sectorgen|07     starter sector mask from the rects     -> assets/ansi/board-132x50-sector-mask.ans")
    PRINT PipeCol$("  |10ansilint|07 |14[f]|07  lint a mask ANSI (line endings, row width, colours->sectors, SAUCE);")
    PRINT PipeCol$("                no file = check both board masks. Read-only.")
    PRINT PipeCol$("  |10ansifix|07 |14<f>|07   rewrite a mask ANSI clean (strip CR/LF blanks, reset SGR); backs up to <f>.bak")
    PRINT PipeCol$("  |10audiomanifest|07 dump |14path | prompt-or-text|07 for every sfx/music/narration asset (feed the AI generators)")
    PRINT PipeCol$("  |10imagemanifest|07 dump |14path | prompt|07 for every entity as pixel-art (.png) AND ansi-art (.ans)")
    PRINT PipeCol$("  |10uimanifest|07    dump |14path | prompt|07 for the decorative ANSI UI chrome (logos, menu pieces)")
    PRINT PipeCol$("  |10--help|07, |10-h|07    show this help    |08(append |15nocolor|08 to any mode to disable colour)")
    PRINT
    PRINT PipeCol$("Everything is data: edit |11assets/data/*.txt|07 and |11assets/ansi/*-mask.ans|07, then rebuild (F5).")
    SYSTEM
END IF
_CONSOLE OFF                            ' normal run: hide the console, go graphics
' CLI dev modes (manifests / dumps / mask tools) are console-only -- keep the graphics
' window HIDDEN and skip fullscreen so they never flash a black screen over the terminal.
DIM devmode AS INTEGER
devmode = (INSTR(UCASE$(COMMAND$), "MANIFEST") > 0) OR (INSTR(UCASE$(COMMAND$), "DUMP") > 0)
devmode = devmode OR (INSTR(UCASE$(COMMAND$), "MASKGEN") > 0) OR (INSTR(UCASE$(COMMAND$), "SECTORGEN") > 0)
devmode = devmode OR (INSTR(UCASE$(COMMAND$), "ANSILINT") > 0) OR (INSTR(UCASE$(COMMAND$), "ANSIFIX") > 0)

' collision palette (must match the board ANSI art exactly)
YELLOW = _RGB32(&HFF, &HFF, &H55)
BLACK = _RGB32(&H00, &H00, &H00)
BROWN = _RGB32(&HAA, &H55, &H00)
BRIGHT_BLUE = _RGB32(&H55, &H55, &HFF)
' UI palette
WHITE = _RGB32(&HFF, &HFF, &HFF)
GREY = _RGB32(&HAA, &HAA, &HAA)
REDU = _RGB32(&HFF, &H55, &H55)
GREENU = _RGB32(&H55, &HFF, &H55)
YELLOWU = _RGB32(&HFF, &HFF, &H55)
CYANU = _RGB32(&H55, &HFF, &HFF)
BOXBG = _RGB32(&H20, &H00, &H00)

RANDOMIZE TIMER

' window starts HIDDEN (no black flash); _SCREENSHOW reveals it for play only (dev modes never do)
$SCREENHIDE
$RESIZE:ON
$RESIZE:STRETCH
CANVAS = _NEWIMAGE(SW * CW, SH * CH, 32)
CANVAS_COPY = _NEWIMAGE(SW * CW, SH * CH, 32)
FULL_BOARD = _NEWIMAGE(SW * CW, SH * CH, 32)
_TITLE "DUNGEON"
_FONT CH
SCREEN CANVAS
IF NOT devmode THEN _FULLSCREEN _SQUAREPIXELS, _SMOOTH

opt_music = TRUE: opt_sfx = TRUE: opt_showdice = TRUE: opt_fullscreen = TRUE
opt_voice = TRUE                              ' typewriter text speaks in blips
opt_musicvol = 4: opt_sfxvol = 4: opt_voicevol = 10  ' 0..10 volume sliders (maintainer's mix)
opt_duckamt = 6                                      ' music ducks to 40% under narration (0 off .. 10 silent)
opt_sfxpack = "found-on-disk-dnd-from-claude"        ' default SFX pack (assets/sfx/); "" = flat main dir
opt_musicpack = "soundmon-orchestral"                ' default music pack (assets/music/); "" = flat main dir
opt_narration = TRUE: opt_narrationpack = "grymmjack"           ' default: narration ON, the maintainer's recorded voice pack
opt_narrfreq = NARR_COMBAT                           ' default: narrate everything (flavor + events + combat)
opt_artpack = ""                                     ' default pixel-art = flat main dir
opt_realdice = FALSE: opt_dicemath = FALSE   ' default: the computer rolls + does the math
opt_oldschool = FALSE                         ' default: D&D d20/HP combat (on = classic Dungeon! 2d6)
opt_heroicstats = TRUE                        ' default: 4d6-drop-lowest ability rolls (off = straight 3d6)
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
opt_smooth = TRUE                             ' default: bilinear-smoothed fullscreen (off = crisp pixel-doubled)
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
opt_solomode = 0: opt_solomins = 25           ' solo challenge: 0 off / 1 Time / 2 Item / 3 Prey; Time-Limit budget 25 min
LoadSettings                                  ' restore the player's saved preferences (overrides defaults)
IF NOT devmode THEN ApplyDisplay              ' fullscreen + smoothing per settings (skipped for CLI dev modes)
BOARD_ANSI = _READFILE$("assets/ansi/board-132x50-no-labels.ans")   ' same map, with secret doors
LoadTuning                       ' gameplay balance knobs (assets/data/tuning.txt) -- before any play
LoadDiceColors                   ' the 6 dice palettes (assets/data/dice-colors.txt)
LoadStrings                      ' UI text lookup (assets/data/strings.txt) -- Say$("key")
InitSectors
InitClasses
InitMonsterTables
InitDice
InitJuice                        ' build the screen-shake buffer + the near-death blood-grime pattern
LoadUIFonts                      ' per-region TTF UI fonts (assets/data/ui-fonts.txt)
InitLabels                       ' build the room-label table + the label-cell mask (keeps monsters off labels)
InitEffects                      ' load the crit/fumble effect tables (assets/data/effects.txt)
LoadTraps                        ' load the curio-chest traps (assets/data/traps.txt)
LoadCurios                        ' load the curio event deck (assets/data/curios.txt)
InitFlavor                       ' load the room + combat flavor text (assets/flavor/*.txt)
InitCombatText                   ' load per-monster + per-class combat event text (assets/flavor/*_events.txt)
ScanAllPacks                     ' find sfx/music PACK subdirs (themes); validate the saved pick
LoadPlaylist                     ' load the per-level music map (assets/music/playlist.txt)

' text-only manifests exit HERE -- after the data they need, before the heavy graphics init
' (dice atlases / fonts / vignette). Window stays hidden ($SCREENHIDE), so no black flash.
IF INSTR(UCASE$(COMMAND$), "AUDIOMANIFEST") > 0 THEN DumpAudioManifest: SYSTEM
IF INSTR(UCASE$(COMMAND$), "IMAGEMANIFEST") > 0 THEN DumpImageManifest: SYSTEM
IF INSTR(UCASE$(COMMAND$), "UIMANIFEST") > 0 THEN DumpUiManifest: SYSTEM

InitSfxFiles                     ' preload any real sound-effect files (assets/sfx/[pack]/*); beeper covers the rest
MixerInit                        ' unity channel gains + music duck open (before any AudioTick)
LoadDiceSets                     ' load the 3D dice sets (assets/data/diceset.txt); font dice if it fails
LoadDiceFonts                    ' load the selectable 3D-dice numeral fonts (assets/fonts/dicefonts.txt)
player_class = 1                 ' default HERO until the player creates a character
InitDefaultChar 1                ' baseline stats so D&D combat works even without CREATE A CHARACTER

'--- dev: `dungeon.run settingsshot` renders the SETTINGS screen to a PNG and exits (layout check) ---
IF INSTR(UCASE$(COMMAND$), "SETTINGSSHOT") > 0 THEN settingsshot_on = -1: RunSettings: SYSTEM

'--- dev: `dungeon.run chamberdump` renders the detected CHAMBER regions to a PNG and exits ---
IF INSTR(UCASE$(COMMAND$), "CHAMBERDUMP") > 0 THEN
    DIM AS INTEGER ddx, ddy, ddc
    _DEST FULL_BOARD: _FONT CH: CLS , BLACK: ANSI_Print (BOARD_ANSI)
    DetectSecretDoors
    DetectRooms
    DetectChambers
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
    ddf = FREEFILE: OPEN "chamberdump.txt" FOR OUTPUT AS #ddf
    PRINT #ddf, "# secret doors detected: " + _TRIM$(STR$(SD_N)) + " | rooms: " + _TRIM$(STR$(ROOM_N)) + " | chambers: " + _TRIM$(STR$(NCHAMBER))
    FOR ddi = 1 TO NCHAMBER
        ddminx = 999: ddminy = 999: ddmaxx = -1: ddmaxy = -1
        FOR ddy = 0 TO 60
            FOR ddx = 0 TO 131
                IF CHAMBERAT(ddx, ddy) = ddi THEN
                    IF ddx < ddminx THEN ddminx = ddx
                    IF ddx > ddmaxx THEN ddmaxx = ddx
                    IF ddy < ddminy THEN ddminy = ddy
                    IF ddy > ddmaxy THEN ddmaxy = ddy
                END IF
            NEXT
        NEXT
        PRINT #ddf, _TRIM$(CHM_NAME(ddi)) + " | " + _TRIM$(STR$(ddminx)) + " | " + _TRIM$(STR$(ddminy)) + " | " + _TRIM$(STR$(ddmaxx)) + " | " + _TRIM$(STR$(ddmaxy)) + "   # sec " + _TRIM$(STR$(CHM_SEC(ddi))) + ", " + _TRIM$(STR$(CHM_CELLS(ddi))) + " cells"
    NEXT
    CLOSE #ddf
    SYSTEM
END IF

'--- dev: `dungeon.run fogdump` composes the fogged board (secret rooms + specks blacked) ---
IF INSTR(UCASE$(COMMAND$), "FOGDUMP") > 0 THEN
    _DEST FULL_BOARD: _FONT CH: CLS , BLACK: ANSI_Print (BOARD_ANSI)
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
    CLOSE #fdf
    SYSTEM
END IF

'--- dev: `dungeon.run maskgen` writes a STARTER secret-mask .ans from the current flood
'    (magenta block = secret cell). Only runs the flood (mask absent -> InitFog floods);
'    delete the mask first to regenerate. Then hand-refine it in your ANSI editor. ---
IF INSTR(UCASE$(COMMAND$), "MASKGEN") > 0 THEN
    IF _FILEEXISTS("assets/ansi/board-132x50-secret-mask.ans") THEN
        _DEST _CONSOLE
        PRINT PipeCol$("|14board-132x50-secret-mask.ans already exists -- NOT regenerating|07 (would clobber your")
        PRINT PipeCol$("hand-painted mask). |12Delete the file first|07 if you really want a fresh starter.")
        SYSTEM
    END IF
    _DEST FULL_BOARD: _FONT CH: CLS , BLACK: ANSI_Print (BOARD_ANSI)
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
    OPEN "assets/ansi/board-132x50-secret-mask.ans" FOR BINARY AS #mgf
    PUT #mgf, 1, mgs
    PUT #mgf, , eofc
    PUT #mgf, , sauce
    CLOSE #mgf
    SYSTEM
END IF

'--- dev: `dungeon.run sectorgen` writes a STARTER sector-mask .ans from the rects (each
'    cell filled with its level's colour). Delete the file first to regenerate; then
'    hand-refine it to your art in an ANSI editor. (Named SECTORGEN, not SECTORMASKGEN,
'    so it doesn't contain the substring "MASKGEN" and trigger the secret-mask maskgen.) ---
IF INSTR(UCASE$(COMMAND$), "SECTORGEN") > 0 THEN
    IF _FILEEXISTS("assets/ansi/board-132x50-sector-mask.ans") THEN
        _DEST _CONSOLE
        PRINT PipeCol$("|14board-132x50-sector-mask.ans already exists -- NOT regenerating|07 (would clobber your")
        PRINT PipeCol$("hand-painted mask). |12Delete the file first|07 if you really want a fresh starter.")
        SYSTEM
    END IF
    SECTORMASK_ON = FALSE                       ' force get_by_xy to use the sectors.txt RECTS
    DIM smf AS INTEGER, smy AS INTEGER, smx AS INTEGER, sms AS STRING, smid AS INTEGER, smlast AS INTEGER, smeof AS STRING
    sms = "": smlast = -999
    FOR smy = 0 TO SH - 2
        FOR smx = 0 TO SW - 1
            smid = SECTOR.get_by_xy(smx * CW, smy * CH)
            IF smid <> smlast THEN
                IF smid = 0 THEN sms = sms + CHR$(27) + "[0m" ELSE sms = sms + CHR$(27) + "[" + SGRBgForColor$(SECTORS(smid).kolor) + "m"
                smlast = smid
            END IF
            sms = sms + " "                       ' bg colour fills the whole cell (no block-glyph gap)
        NEXT smx
        sms = sms + CHR$(27) + "[0m" + CHR$(13) + CHR$(10): smlast = -999
    NEXT smy
    smeof = CHR$(26)
    DIM smsauce AS STRING
    smsauce = SauceRecord$("DUNGEON! sector mask", SW, SH - 1, LEN(sms))
    smf = FREEFILE
    OPEN "assets/ansi/board-132x50-sector-mask.ans" FOR BINARY AS #smf
    PUT #smf, 1, sms
    PUT #smf, , smeof
    PUT #smf, , smsauce
    CLOSE #smf
    SYSTEM
END IF

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
        AnsiLint alpath
    ELSE
        AnsiLint "assets/ansi/board-132x50-sector-mask.ans"
        AnsiLint "assets/ansi/board-132x50-secret-mask.ans"
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
_SCREENSHOW                            ' normal play only (dev modes SYSTEM'd already): reveal the window
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
            o = PlayGame
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
IF FX_BUF <> 0 THEN _FREEIMAGE FX_BUF
SYSTEM

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
        LoadActivePlayer cur_player      ' player 1 becomes the active player (pos / colour / stats)
        StartTurnMove                    ' set turn 1's move budget (roll 1d6 / up-to-5 / free)
        loiter = 0                       ' fresh danger meter for lingering
        curio_cool = 0                   ' path curios may start turning up right away
        FOR i = 1 TO 9: lvl_kills(i) = 0: lvl_gold(i) = 0: lvl_reached(i) = FALSE: lvl_cleared(i) = FALSE: NEXT i   ' fresh chronicle
        lvl_reached(1) = TRUE            ' you start on the 1st level
        char_level = 1: char_xp = 0      ' fresh D&D level + XP for this run
        item_potion_small = 0: item_potion_large = 0
        item_armor = 0: item_shield = 0: item_bow = FALSE: item_boots = FALSE: item_teleport = 0   ' newer items aren't in PLAYER type -- clear them so nothing leaks between games
        spell_fire = 0: spell_bolt = 0                                       ' clear Wizard spell charges between games
        IF player_class = 4 THEN spell_fire = 3: spell_bolt = 3: item_teleport = 2   ' the WIZARD opens with a spellbook (3 Fire Ball / 3 Lightning / 2 Teleport)
        poison_turns = 0: fire_turns = 0: frost_turns = 0: siren_turns = 0   ' no lingering trap effects
        deaths(1) = 0: deaths(2) = 0: deaths(3) = 0: deaths(4) = 0           ' fresh skull tally
        player_out = FALSE                                                  ' nobody has forfeited yet

        DIM ident AS STRING                                                 ' "Grognard the Fast, a HERO" (or "the HERO" if unnamed)
        IF _TRIM$(player_name) <> "" THEN ident = _TRIM$(player_name) + ", a " + class_name ELSE ident = "the " + class_name

        IF num_players > 1 THEN
            ScrollTextVO "THE DESCENT", "Torchlight gutters as " + _TRIM$(STR$(num_players)) + " rivals cross the threshold into the ancient dungeon. Nine levels coil below, each darker and deadlier than the last. The Level Key is said to lie on the " + Ordinal$(key_level) + " level. Whoever is first to claim its key, a fortune in gold, and return alive to this entrance wins eternal glory. Let the delving begin.", "intro.descent"
        ELSE
            ScrollTextVO "THE DESCENT", "Torchlight gutters as you, " + ident + ", cross the threshold into the ancient dungeon. Nine levels coil below, each darker and deadlier than the last. The Level Key is rumoured to lie on the " + Ordinal$(key_level) + " level -- take it, gather " + _TRIM$(STR$(target_gold)) + " gold, and return alive to this entrance. A Crystal Ball would reveal exactly which room hides it. Few ever escape.", "intro.descent"
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
    DrawHUD: _DISPLAY

    DIM startlvl AS INTEGER                        ' start this level's music before the first step
    StopLevelMusic                                 ' kill any leftover track (last run/menu) so it can't linger if the start sector has none
    startlvl = SECTOR.get_by_xy(c.x, c.y): IF startlvl < 1 THEN startlvl = 1
    IF LEN(_TRIM$(MUSIC_FILE(startlvl))) = 0 THEN startlvl = 1   ' start sector has no track -> fall back to level 1's
    PlayLevelMusic startlvl

    DO
        _LIMIT 60
        AudioTick                                 ' advance music crossfade + narration fade each frame
        IF player_out THEN                        ' the active player has spent their last life
            ' solo (or last one standing) -> the run is over for good. Delete the save so a
            ' permadeath run can never be "continued" back to life.
            IF HandleForfeit THEN DeleteSave: PlayGame = OUT_LOSE: EXIT FUNCTION
        END IF
        k = UCASE$(INKEY$)
        k = NormKey$(k)              ' fold arrow keys + numpad into WASD + diagonals

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
        IF k = "H" THEN UsePotion FALSE: cursor_erase: cursor_draw: DrawHUD: _DISPLAY
        IF k = "P" THEN PauseGame: idle_ticks = 0
        IF k = "G" AND num_players = 1 THEN SaveAndToast: idle_ticks = 0
        IF k = "?" OR k = "/" THEN ShowKeys
        IF k = "M" THEN GameMenu: cursor_erase: cursor_draw: DrawHUD: _DISPLAY
        IF k = "~" OR k = "`" THEN
            dbg_on = NOT dbg_on
            IF NOT dbg_on THEN cursor_erase: cursor_draw: DrawHUD: _DISPLAY   ' wipe the frozen debug overlay off the board
        END IF
        IF dbg_on AND k = "0" THEN DebugTestMenu   ' [~] on -> [0] opens the cheat/test panel

        IF k = "T" AND item_teleport > 0 THEN     ' Teleport Scroll -- whisk back to START
            item_teleport = item_teleport - 1
            Sfx "teleport"
            PopArt "Teleport Scroll", "TELEPORT SCROLL"       ' show the scroll art as you use it
            Banner "You read a TELEPORT SCROLL -- reality folds around you!", "You reappear at the entrance.   [ press any key ]"
            WaitKey
            c.x = START_CX * CW: c.y = START_CY * CH: c.prev_x = c.x: c.prev_y = c.y
            player_hp = player_maxhp: loiter = 0
            StartTurnMove                    ' fresh move budget after reviving
            cursor_erase: cursor_draw: FadeInCurrent: DrawHUD: _DISPLAY
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
                cursor_erase: cursor_draw: DrawHUD: _DISPLAY
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
                    curlvl = SECTOR.get_by_xy(c.x, c.y)   ' chronicle the levels you tread
                    IF curlvl >= 1 AND curlvl <= 9 THEN
                        IF NOT lvl_reached(curlvl) THEN
                            lvl_reached(curlvl) = TRUE
                            IF player_class = 4 THEN                    ' a WIZARD's power grows as they descend
                                spell_fire = spell_fire + 1: spell_bolt = spell_bolt + 1
                                Sfx "levelup"
                                Banner "The deeper magic answers you.", "You gain a Fire Ball and a Lightning Bolt.   [ press any key ]"
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
        _DISPLAY
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
'$INCLUDE:'engine/DATA.bas'
'$INCLUDE:'game/SECTOR.bas'
'$INCLUDE:'game/HOOKS.bas'      ' engine<->game contract: Game_OnEnterCell% / Game_WinReached% / Game_WinReady%
'$INCLUDE:'game/LOADERS.bas'    ' game data-table loaders (Load*), moved out of engine/DATA.bas
'$INCLUDE:'game/COMBAT.bas'    ' combat + spells + treasure + potions + turn/revive (was in dungeon.bas)
'$INCLUDE:'game/PLAY.bas'      ' loot drops + loiter/danger + wander + chamber encounters (was in dungeon.bas)
'$INCLUDE:'engine/BOARD.bas'
'$INCLUDE:'engine/CURSOR.bas'
'$INCLUDE:'engine/UI.bas'       ' engine presentation: fades + UI primitives + sound + dice subsystem
'$INCLUDE:'game/MENU.bas'       ' game screens: class-select, char-gen, intro, menu/settings, HUD
'$INCLUDE:'engine/TEXT.bas'     ' reusable string/format utils (NthField$/PadR$/MMSS$)
'$INCLUDE:'game/LORDS.bas'      ' hall of fame + LOAD A CHARACTER + settings persistence
'$INCLUDE:'engine/PLAYERS.bas'
'$INCLUDE:'game/EFFECTS.bas'
'$INCLUDE:'game/CURIO.bas'
'$INCLUDE:'engine/ARTPACK.bas'  ' engine pixel-art layer: load/cache/fit sprites + art-pack resolution
'$INCLUDE:'game/SPRITES.bas'    ' game entity->sprite mapping + popups + manifests
'$INCLUDE:'engine/GESTURE.bas'
'$INCLUDE:'engine/JUICE.bas'
'$INCLUDE:'engine/STATS.bas'
'$INCLUDE:'engine/MARKDOWN.bas' ' reusable markdown -> text-mode renderer (was inside CHRONICLE.bas)
'$INCLUDE:'game/CHRONICLE.bas'  ' per-run journal + Bestiary/Treasury/Rules/Game Menu
'$INCLUDE:'game/SOLO.bas'
'$INCLUDE:'engine/SAVEIO.bas'   ' engine save-file plumbing (HasSave/DeleteSave/AskContinue/TokLoad/Next*)
'$INCLUDE:'game/SAVEGAME.bas'   ' game save payload (SaveGame/LoadGameApply/SaveAndToast)
'$INCLUDE:'game/FLAVOR.bas'
'$INCLUDE:'game/CTEXT.bas'
'$INCLUDE:'engine/MUSIC.bas'

'$INCLUDE:'include/DICE3D/_ALL.BM'      ' 3D dice implementation (bottom, per the module's contract)
'$INCLUDE:'include/DICE3D_GAME.bas'     ' dungeon<->DICE3D glue (LoadDiceSets, Show3DRoll)

'$INCLUDE:'include/ansi/ANSIPrint.bas'  ' vendored ANSI renderer bodies (Toolbox64 8c5d57d, works on 4.4.0/4.5.0)

