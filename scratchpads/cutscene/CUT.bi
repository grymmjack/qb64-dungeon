' ============================================================================
'  CUT.bi -- the cut-scene engine's header: consts, types, shared globals and
'  the HOST HOOK contract.
'
'  WHAT THIS IS
'  ------------
'  A little-movie player. A .cut script is compiled once into an opcode array
'  and then STEPPED by CutTick% one frame at a time. It is deliberately NOT a
'  blocking loop like the rest of this codebase's interactive screens: a
'  blocking loop can never run two things at once, and a cut-scene's whole job
'  is to pan the camera WHILE the music swells WHILE the text types.
'
'  So: ops execute until one DECLARES A WAIT, then control returns to the
'  frame loop, which advances tweens and redraws. `async` is then free -- it
'  simply means "run this op but do not set the wait state".
'
'  THE PICTURE IS BUILT IN THREE STEPS, EVERY FRAME
'  ------------------------------------------------
'      LAYERS  (ansi blocks and png images, each with its own position,
'               scale, opacity and parallax)
'         |  composite, back to front
'         v
'      STAGE   (one 32-bit image, usually BIGGER than the screen -- that
'               headroom is what there is to pan around in)
'         |  camera: a source rectangle -> the whole screen
'         v
'      SCREEN  (then text, then any transition, then _DISPLAY)
'
'  Authoring in ANSI but moving in PIXELS is the point of the hybrid: an .ans
'  layer is rendered through ANSI_Print ONCE into an image, and from then on
'  the camera treats it like any other bitmap, so pan and zoom are smooth
'  instead of jumping a whole 8x16 cell at a time.
'
'  BOUNDARY
'  --------
'  This file names no game symbol. Everything the engine needs to know about
'  the running game arrives through the Cut_* host hooks declared at the
'  bottom -- the same discipline engine/ENGINE.md enforces for Game_*. The
'  standalone player supplies mock hooks; the game will supply real ones.
' ============================================================================

'--- BASIC truth ---
CONST TRUE = -1, FALSE = NOT TRUE

'--- the screen every scene is composed for: the game's own grid ---
'    132x51 cells at 8x16 px = 1056x816.
CONST CUT_SW = 132
CONST CUT_SH = 51
CONST CUT_CW = 8
CONST CUT_CH = 16
CONST CUT_PXW = CUT_SW * CUT_CW
CONST CUT_PXH = CUT_SH * CUT_CH

'--- capacities. Generous, but bounded: an unbounded parser is a parser that
'    crashes on a typo instead of reporting one. ---
CONST CUT_MAXOP = 4096
CONST CUT_MAXLAYER = 16
CONST CUT_MAXTWEEN = 64
CONST CUT_MAXLABEL = 256
CONST CUT_MAXCHOICE = 4
CONST CUT_MAXERR = 64
CONST CUT_MAXCOND = 4
CONST CUT_MAXCRAWL = 32
CONST CUT_MAXCAP = 8
CONST CUT_MAXINC = 8

'--- string-pool sentinel: "this op has no string in slot N" ---
CONST CUT_NOSTR = 0

' ============================================================================
'  OPCODES
'
'  Numbered in families with gaps, so a family can grow without renumbering
'  (a renumber silently changes the meaning of any compiled scene held in
'  memory, and the failure looks like a script bug rather than a build bug).
' ============================================================================

'--- 0-9 meta / flow control ---
CONST OP_NOP = 0
CONST OP_END = 1          ' end of scene
CONST OP_WAIT = 2         ' n1 = seconds
CONST OP_WAITALL = 3      ' join every running async tween
CONST OP_JUMP = 4         ' n1 = resolved op index
CONST OP_IFGOTO = 5       ' condition false -> jump to n1
CONST OP_LABEL = 6        ' no-op at runtime; a landing spot
CONST OP_STOPFX = 7       ' cancel running async tweens without waiting

'--- 10-19 layers & art ---
CONST OP_SHOW = 10        ' s1 layer, s2 path, n1 fade secs
CONST OP_HIDE = 11        ' s1 layer, n1 fade secs
CONST OP_ANIM = 12        ' s1 layer, s2 base path, n1 frames, n2 fps, n3 mode
CONST OP_CLEARLAY = 13    ' drop every layer
CONST OP_LAYSET = 14      ' s1 layer, n1 what, n2 value, n3 secs, n4 ease
CONST OP_STAGE = 15       ' n1 w, n2 h (stage size in px)

'--- 20-29 camera ---
CONST OP_PAN = 20         ' n1 x, n2 y (0..1 of stage), n3 secs, n4 ease
CONST OP_ZOOM = 21        ' n1 zoom, n2 secs, n3 ease
CONST OP_CAMSET = 22      ' n1 x, n2 y, n3 zoom -- instant, no tween
CONST OP_SHAKE = 23       ' n1 amplitude px, n2 secs

'--- 30-39 transitions ---
CONST OP_TRANS = 30       ' n1 kind (TR_*), n2 secs, n3/n4 dir or point, s1 colour key

'--- 40-49 text ---
CONST OP_SAY = 40         ' s1 text, s2 speaker (blank = subtitle bar)
CONST OP_TITLE = 41       ' s1 title, s2 subtitle, n1 secs
CONST OP_CRAWL = 42       ' s1 body (LF-separated), n1 secs
CONST OP_CAPTION = 43     ' s1 text, n1 col, n2 row, n3 anchor, n4 fade, s2 colour key
CONST OP_CLEARTEXT = 44
CONST OP_PORTRAIT = 45    ' s1 path, n1 side (0 left, 1 right)

'--- 50-59 audio ---
CONST OP_MUSIC = 50       ' s1 name, n1 fadein secs, n2 loop
CONST OP_MUSICSTOP = 51   ' n1 fade secs
CONST OP_SFX = 52         ' s1 name
CONST OP_NARRATE = 53     ' s1 strings.txt key
CONST OP_CUE = 54         ' s1 cue name, n1 loop

'--- 60-69 game state ---
CONST OP_SET = 60         ' s1 flag, n1 value
CONST OP_GRANT = 61       ' s1 what, n1 amount
CONST OP_CHOICE = 62      ' s1 prompt, n1 count, n2 first option op
CONST OP_OPTION = 63      ' s1 text, n1 resolved jump target
CONST OP_ENDCHOICE = 64

'--- layer properties for OP_LAYSET ---
CONST LS_X = 0
CONST LS_Y = 1
CONST LS_SCALE = 2
CONST LS_ALPHA = 3
CONST LS_PARALLAX = 4
CONST LS_Z = 5

'--- animation playback modes ---
CONST AM_LOOP = 0
CONST AM_ONCE = 1
CONST AM_PINGPONG = 2

'--- transition kinds ---
CONST TR_CUT = 0
CONST TR_FADE = 1         ' to a flat colour
CONST TR_DISSOLVE = 2     ' crossfade from the outgoing snapshot
CONST TR_WIPE = 3
CONST TR_PUSH = 4
CONST TR_SPLIT = 5
CONST TR_IRISIN = 6
CONST TR_IRISOUT = 7
CONST TR_SCATTER = 8      ' cell-by-cell in random order
CONST TR_SCAN = 9         ' scanline sweep
CONST TR_STATIC = 10      ' glyph noise
CONST TR_CRTOFF = 11      ' collapse to a line, then a dot
CONST TR_FLASH = 12

'--- directions (wipe / push) ---
CONST DIR_L = 0
CONST DIR_R = 1
CONST DIR_U = 2
CONST DIR_D = 3

'--- easing curves ---
CONST EASE_LINEAR = 0
CONST EASE_IN = 1
CONST EASE_OUT = 2
CONST EASE_INOUT = 3
CONST EASE_INCUBIC = 4
CONST EASE_OUTCUBIC = 5
CONST EASE_INOUTCUBIC = 6
CONST EASE_BACK = 7
CONST EASE_BOUNCE = 8

'--- text anchors ---
CONST ANC_L = 0
CONST ANC_C = 1
CONST ANC_R = 2

'--- what the VM is waiting for ---
CONST WAIT_NONE = 0
CONST WAIT_TIME = 1
CONST WAIT_TWEEN = 2      ' the blocking tween slot
CONST WAIT_TEXT = 3       ' typewriter running / holding for a keypress
CONST WAIT_ALL = 4        ' every async tween must finish
CONST WAIT_CHOICE = 5
CONST WAIT_TRANS = 6

'--- CutTick% return codes ---
CONST CUT_RUNNING = 0
CONST CUT_DONE = 1
CONST CUT_SKIPPED = 2
CONST CUT_ERROR = 3

'--- text presentation modes ---
CONST TX_NONE = 0
CONST TX_SUBTITLE = 1
CONST TX_SPEAKER = 2
CONST TX_TITLE = 3
CONST TX_CRAWL = 4

'--- how the player's advance-key behaves (a SETTING, not a script property) ---
CONST CUT_MANUAL = 0      ' hold each beat until a key
CONST CUT_AUTO = 1        ' hold for a computed reading time, then move on
CONST CUT_OFF = 2         ' skip cut-scenes entirely

'--- per-layer opacity is QUANTISED. See CutLayerWork in CUT.bas for why:
'    changing an image's alpha means rebuilding it, so a fade is rebuilt at
'    most this many times instead of once per frame. ---
CONST CUT_ALPHA_STEPS = 32

'--- how long an unattended choice menu waits before taking option 1 ---
CONST CUT_CHOICE_AUTOSEC = 4

' ============================================================================
'  TYPES
' ============================================================================

'--- one compiled instruction.
'    Strings live OUTSIDE the UDT in CUT_SPOOL$() and are referenced by index:
'    a UDT string must be fixed-length in QB64, and a fixed-length field wide
'    enough for a line of dialogue would be wasted on every path and still too
'    narrow for a crawl. ---
TYPE CUTOP
    cmd AS INTEGER
    s1 AS LONG              ' index into CUT_SPOOL$, or CUT_NOSTR
    s2 AS LONG
    s3 AS LONG              ' third string slot; set after CutEmit% returns
    n1 AS SINGLE
    n2 AS SINGLE
    n3 AS SINGLE
    n4 AS SINGLE
    async AS INTEGER        ' TRUE = launch and keep going
    srcline AS INTEGER      ' line in the .cut file, for error messages
END TYPE

'--- one composited layer ---
TYPE CUTLAYER
    used AS INTEGER
    nm AS STRING * 24
    src AS LONG             ' pristine image handle
    work AS LONG            ' alpha-adjusted copy actually blitted
    workstep AS INTEGER     ' which quantised alpha `work` was built at
    w AS INTEGER
    h AS INTEGER
    x AS SINGLE             ' stage position, 0..1 of stage, of the ANCHOR
    y AS SINGLE
    scale AS SINGLE
    alpha AS SINGLE         ' 0..1
    parallax AS SINGLE      ' 1 = moves with the camera, 0 = pinned
    z AS INTEGER            ' draw order, back to front

    ' frame-sequence animation
    isanim AS INTEGER
    abase AS STRING * 96     ' "fx/fog" -> fx/fog-01.png ...
    nframes AS INTEGER
    fps AS SINGLE
    amode AS INTEGER
    frame AS INTEGER
    atime AS DOUBLE         ' when the current frame started
    adone AS INTEGER        ' a `once` animation has finished
    adir AS INTEGER         ' +1 / -1, so pingpong needs no second state
END TYPE

'--- one running interpolation. Everything that moves over time is one of
'    these, so `async` needs no second code path: a blocking op simply also
'    sets vm_wait to the tween it just started. ---
TYPE CUTTWEEN
    active AS INTEGER
    what AS INTEGER         ' TWN_*
    lay AS INTEGER          ' layer index, for layer tweens
    fromv AS SINGLE
    tov AS SINGLE
    t0 AS DOUBLE
    dur AS SINGLE
    ease AS INTEGER
    blocking AS INTEGER     ' TRUE = the VM is parked on this one
END TYPE

'--- tween targets ---
CONST TWN_CAMX = 0
CONST TWN_CAMY = 1
CONST TWN_CAMZ = 2
CONST TWN_LAYALPHA = 3
CONST TWN_LAYX = 4
CONST TWN_LAYY = 5
CONST TWN_LAYSCALE = 6
CONST TWN_SHAKE = 7
CONST TWN_MUSICVOL = 8

'--- a free-placed caption, which unlike SAY does not block ---
TYPE CUTCAP
    used AS INTEGER
    txt AS STRING * 96
    col AS INTEGER
    row AS INTEGER
    anchor AS INTEGER
    kolor AS _UNSIGNED LONG
    alpha AS SINGLE
    born AS DOUBLE
    fade AS SINGLE
END TYPE

' ============================================================================
'  SHARED STATE
' ============================================================================

'--- the compiled program ---
DIM SHARED CUT_OPS(0 TO CUT_MAXOP) AS CUTOP
DIM SHARED CUT_NOP AS INTEGER
REDIM SHARED CUT_SPOOL(0 TO 0) AS STRING
DIM SHARED CUT_NSPOOL AS LONG

'--- labels, resolved after the whole file is read (a jump may point forward) ---
DIM SHARED CUT_LBLNAME(0 TO CUT_MAXLABEL) AS STRING * 32
DIM SHARED CUT_LBLOP(0 TO CUT_MAXLABEL) AS INTEGER
DIM SHARED CUT_NLBL AS INTEGER

'--- compile diagnostics. The linter prints these; the player refuses to run
'    with any error and plays anyway with only warnings. ---
DIM SHARED CUT_ERR(0 TO CUT_MAXERR) AS STRING
DIM SHARED CUT_ERRLINE(0 TO CUT_MAXERR) AS INTEGER
DIM SHARED CUT_ERRSEV(0 TO CUT_MAXERR) AS INTEGER   ' 2 = error, 1 = warning
DIM SHARED CUT_NERR AS INTEGER
DIM SHARED CUT_NFATAL AS INTEGER

'--- scene identity & options ---
DIM SHARED CUT_NAME AS STRING
DIM SHARED CUT_FILE AS STRING
DIM SHARED CUT_NOSKIP AS INTEGER
DIM SHARED CUT_STAGEW AS INTEGER
DIM SHARED CUT_STAGEH AS INTEGER

'--- images ---
DIM SHARED CUT_STAGE AS LONG        ' the composited world
DIM SHARED CUT_SNAP AS LONG         ' outgoing frame, for dissolves
DIM SHARED CUT_SCRATCH AS LONG      ' general-purpose screen-sized scratch

'--- layers & tweens ---
DIM SHARED CUT_LAY(0 TO CUT_MAXLAYER) AS CUTLAYER
DIM SHARED CUT_TWN(0 TO CUT_MAXTWEEN) AS CUTTWEEN
DIM SHARED CUT_CAP(0 TO CUT_MAXCAP) AS CUTCAP

'--- camera. cx/cy are the CENTRE of the view as a fraction of the stage;
'    zoom 1 fits the whole stage on screen, 2 shows half of it. ---
DIM SHARED CUT_CAMX AS SINGLE
DIM SHARED CUT_CAMY AS SINGLE
DIM SHARED CUT_CAMZ AS SINGLE
DIM SHARED CUT_SHAKEAMP AS SINGLE

'--- the virtual machine ---
DIM SHARED CUT_PC AS INTEGER
DIM SHARED CUT_WAIT AS INTEGER
DIM SHARED CUT_WAITT0 AS DOUBLE
DIM SHARED CUT_WAITDUR AS SINGLE
DIM SHARED CUT_WAITTWN AS INTEGER
DIM SHARED CUT_RUNSTATE AS INTEGER
DIM SHARED CUT_T0 AS DOUBLE         ' when the scene started
DIM SHARED CUT_NOW AS DOUBLE        ' this frame's timestamp, sampled ONCE
DIM SHARED CUT_LASTFRAME AS DOUBLE  ' previous frame, for the pause clock-shift

'--- TIMER resets at midnight; CutClock# folds that back out. See CUTEXEC.bas.
DIM SHARED CUT_CLKLAST AS DOUBLE
DIM SHARED CUT_CLKWRAP AS DOUBLE

'--- text presentation ---
DIM SHARED CUT_TXMODE AS INTEGER
DIM SHARED CUT_TXBODY AS STRING
DIM SHARED CUT_TXWHO AS STRING
DIM SHARED CUT_TXSUB AS STRING
DIM SHARED CUT_TXSHOWN AS INTEGER   ' glyphs revealed so far
DIM SHARED CUT_TXT0 AS DOUBLE
DIM SHARED CUT_TXHOLD AS INTEGER    ' TRUE = fully typed, waiting to advance
DIM SHARED CUT_TXHOLDT0 AS DOUBLE
DIM SHARED CUT_TXDONE AS INTEGER    ' this beat is finished with
DIM SHARED CUT_TXHOLDSECS AS SINGLE ' explicit `for <t>` on this beat, or 0
DIM SHARED CUT_PORTRAIT AS LONG
DIM SHARED CUT_PORTSIDE AS INTEGER

'--- transitions ---
DIM SHARED CUT_TRKIND AS INTEGER
DIM SHARED CUT_TRT0 AS DOUBLE
DIM SHARED CUT_TRDUR AS SINGLE
DIM SHARED CUT_TRN3 AS SINGLE
DIM SHARED CUT_TRN4 AS SINGLE
DIM SHARED CUT_TRCOL AS _UNSIGNED LONG
DIM SHARED CUT_TRACTIVE AS INTEGER
DIM SHARED CUT_TRSNAP AS INTEGER    ' this transition uses the outgoing frame

'--- one alpha-adjusted scratch, reused. Rebuilt only when the QUANTISED
'    alpha changes, which is what keeps a crossfade from rebuilding a
'    full-screen image 60 times a second. ---
DIM SHARED CUT_SCRSTEP AS INTEGER
DIM SHARED CUT_SCRSRC AS LONG
DIM SHARED CUT_NEWSHOT AS LONG      ' the incoming frame, for masked reveals

'--- scatter's per-cell reveal thresholds, rolled once per transition ---
REDIM SHARED CUT_SCAT(0 TO 0) AS SINGLE

'--- choices ---
DIM SHARED CUT_CHTEXT(0 TO CUT_MAXCHOICE) AS STRING
DIM SHARED CUT_CHTARGET(0 TO CUT_MAXCHOICE) AS INTEGER
DIM SHARED CUT_NCH AS INTEGER
DIM SHARED CUT_CHSEL AS INTEGER
DIM SHARED CUT_CHPROMPT AS STRING
DIM SHARED CUT_CHT0 AS DOUBLE       ' when the menu opened, for the auto-pick

'--- player-facing options (the host sets these) ---
DIM SHARED CUT_MODE AS INTEGER          ' CUT_MANUAL / CUT_AUTO / CUT_OFF
DIM SHARED CUT_TEXTSPEED AS SINGLE      ' glyphs per second
DIM SHARED CUT_QUIET AS INTEGER         ' headless: make no sound at all
DIM SHARED CUT_PAUSED AS INTEGER
DIM SHARED CUT_ASSETROOT AS STRING      ' where art/audio names resolve from

'--- diagnostics the player overlay reads ---
DIM SHARED CUT_LASTART AS STRING
DIM SHARED CUT_LASTMUSIC AS STRING
DIM SHARED CUT_LASTSFX AS STRING
DIM SHARED CUT_MISSING AS INTEGER       ' assets referenced but not on disk
DIM SHARED CUT_CONDLN AS INTEGER        ' line a condition is being validated for

' ============================================================================
'  PARSER STATE
'
'  Lives here rather than in CUTPARSE.bas because nothing in this codebase
'  declares at file scope in a .bas -- see the note in CLAUDE.md about the
'  four-line assembly. Body order is then irrelevant.
' ============================================================================
CONST CUT_MAXTOK = 48
CONST CUT_MAXLINE = 3000

REDIM SHARED CUT_TK(0 TO CUT_MAXTOK) AS STRING     ' this line's tokens
DIM SHARED CUT_TKQ(0 TO CUT_MAXTOK) AS INTEGER     ' was token i quoted?
DIM SHARED CUT_NTK AS INTEGER

REDIM SHARED CUT_SRC(0 TO CUT_MAXLINE) AS STRING   ' source after includes
DIM SHARED CUT_SRCLN(0 TO CUT_MAXLINE) AS INTEGER  ' original line number
REDIM SHARED CUT_SRCFILE(0 TO CUT_MAXLINE) AS STRING
DIM SHARED CUT_NSRC AS INTEGER

'--- the if/elseif/else/end patch stack. An IF cannot know where its ELSE is
'    until the ELSE is read, so each open block remembers the op whose jump
'    target is still blank. ---
CONST CUT_MAXNEST = 16
DIM SHARED CUT_FIXIF(0 TO CUT_MAXNEST) AS INTEGER     ' the OP_IFGOTO to patch
DIM SHARED CUT_FIXEND(0 TO CUT_MAXNEST, 0 TO 15) AS INTEGER  ' OP_JUMPs to the END
DIM SHARED CUT_NFIXEND(0 TO CUT_MAXNEST) AS INTEGER
DIM SHARED CUT_NEST AS INTEGER

'--- the open CHOICE block, patched the same way ---
DIM SHARED CUT_CHOP AS INTEGER
DIM SHARED CUT_CHN AS INTEGER

' ============================================================================
'  HOST HOOKS -- the ONLY way this engine reaches the game.
'
'  Declared here, defined by whoever embeds the engine. The standalone player
'  defines mocks (CUTMOCK.bas); the game will define real ones. Keeping the
'  set small is the whole point: it is what lets the engine be lifted into
'  engine/CUTSCENE.bas without dragging DUNGEON! along with it.
' ============================================================================
DECLARE FUNCTION Cut_State# (k AS STRING)                       ' read a state value
DECLARE FUNCTION Cut_StateStr$ (k AS STRING)                    ' read a state string
DECLARE SUB Cut_SetFlag (nm AS STRING, v AS DOUBLE)             ' write a persistent flag
DECLARE SUB Cut_Grant (what AS STRING, amount AS DOUBLE)        ' gold / hp / item / key
DECLARE FUNCTION Cut_ArtPath$ (subpath AS STRING)                  ' pack-resolve an image
DECLARE FUNCTION Cut_AudioPath$ (kind AS STRING, nm AS STRING)  ' pack-resolve audio
DECLARE SUB Cut_Music (path AS STRING, fadein AS SINGLE, doloop AS INTEGER)
DECLARE SUB Cut_MusicStop (fade AS SINGLE)
DECLARE SUB Cut_Sfx (nm AS STRING)
DECLARE SUB Cut_Narrate (k AS STRING)
DECLARE SUB Cut_AudioTick                                       ' fades are frame-ticked
