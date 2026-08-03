' ============================================================================
'  MG.bi -- shared header for the mini-game prototypes.
'
'  The first four prototypes each carried their own copy of CenterText, RollDie%,
'  AbilMod%, the assert counters and a fuse bar. That is four places for the same
'  bug to live -- and one of them already did: BASIC binds `*` tighter than `\`,
'  so `(SW - LEN(s)) \ 2 * CW` centred every line at x=6, and it had to be found
'  and fixed per file.
'
'  Include MG.bi at the top and MG.bas at the bottom, exactly as the game does
'  with engine/_ALL.BI / _ALL.BM.
' ============================================================================
$CONSOLE
OPTION _EXPLICIT

CONST TRUE = -1, FALSE = NOT TRUE

'--- the screen every prototype draws on (the game's own grid) ---
DIM SHARED AS INTEGER SW, SH, CW, CH

'--- outcome codes, shared so the game can switch on them once ---
CONST MG_WON = 1
CONST MG_LOST = 2
CONST MG_LEFT = 3

'--- selftest counters ---
DIM SHARED T_RUN AS INTEGER, T_BAD AS INTEGER

'--- set by any headless mode (selftest, shot). The game learned this the hard
'    way: a raw SOUND bypasses every mute flag, so a test run chirps at whoever
'    is sitting there. Prototypes route tones through MgBeep, which obeys this. ---
DIM SHARED MG_QUIET AS INTEGER

'--- nesting counter for MgQuiet/MgLoud: silences the model being RUN rather than
'    played. See the note on MgQuiet in MG.bas. ---
DIM SHARED MG_SILENT AS INTEGER

'--- SOUND is a QUEUE, not a speaker. These bound how far ahead of real time that
'    queue is allowed to get; see MgBeep. ---
CONST MG_QMAX = 0.35            ' seconds of un-played audio tolerated
DIM SHARED MG_QDEPTH AS SINGLE
DIM SHARED MG_QLAST AS DOUBLE

'--- the palette these prototypes speak in. Mirrors the game's theme keys so the
'    move into the real UI is a rename, not a re-design. ---
DIM SHARED AS _UNSIGNED LONG C_TITLE, C_TEXT, C_DIM, C_GOOD, C_WARN, C_BAD, C_COOL, C_BG
