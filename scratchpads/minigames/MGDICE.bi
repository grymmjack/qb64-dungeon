' ============================================================================
'  MGDICE.bi -- the dice contract, and the REAL 3D dice.
'
'  Included only by prototypes that roll dice a player would recognise as dice.
'  Everything here is named EXACTLY as engine/UI.bas names it, so integration is
'  DELETING this layer rather than rewriting call sites.
'
'  The split mirrors the game's own: engine/UI.bas holds the roll contract and
'  engine/DICE3D_GAME.bas is the presentation layer over the vendored DICE3D
'  module. Here MGDICE is both, and it pulls in the SAME module the game uses --
'  ../../engine/DICE3D -- rather than a copy, so what you see in a prototype is
'  what the game will show.
'
'  DICE3D turned out to have exactly ONE dependency on its host: PresentNoFlip,
'  which lays the host's canvas down before the GL triangles go over it. The
'  prototypes draw straight to the screen, so the stub in MGDICE.bas is a no-op
'  with a note saying why.
' ============================================================================
'$INCLUDE:'../../engine/DICE3D/_ALL.BI'

'--- the SETTINGS this honours. Same names as ENGINE.BI. ---
DIM SHARED opt_realdice AS INTEGER   ' the player rolls physical dice and types the result
DIM SHARED opt_dicemath AS INTEGER   ' ...and adds the modifier themselves
DIM SHARED opt_dice3d AS INTEGER     ' animate real 3D polyhedra
DIM SHARED opt_d6pips AS INTEGER     ' a d6 shows pips rather than a numbered face

DIM SHARED dice3d_ready AS INTEGER   ' the module loaded and has a usable set
DIM SHARED DICE_CFG AS DICE3D_CONFIG

CONST MG_MAXDICE = 16

'--- faces of the last animated roll. EMPTY under Real Dice: the player rolled
'    physical dice and the game never saw them. See GameRoll%. ---
DIM SHARED DIE_FACE(1 TO MG_MAXDICE) AS INTEGER
DIM SHARED DIE_FACE_N AS INTEGER
DIM SHARED rollseq_on AS INTEGER

'--- selftest only: pretend the player typed this, so the Real Dice path can be
'    driven headlessly instead of blocking on a keyboard nobody is at. ---
DIM SHARED MG_FAKEROLL AS INTEGER
