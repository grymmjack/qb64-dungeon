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

DIM SHARED opt_dicelight AS INTEGER  ' 0 off .. 3 strong
DIM SHARED opt_diceround AS INTEGER  ' edge bevel, tenths
DIM SHARED opt_dice3d_set AS INTEGER ' which set in dicesets.txt

DIM SHARED dice3d_ready AS INTEGER   ' the module loaded and has a usable set

'--- one config PER DIE SIZE, exactly as the game keeps DSET3D(). The SET is what
'    carries the style -- body, ink, finish, bevel, light -- so loading the same
'    file the game loads is what makes a prototype look like the game. ---
DIM SHARED DSET3D(0 TO 6) AS DICE3D_CONFIG

'--- the tray. Reserved by the prototype's layout and drawn EVERY frame, so the
'    dice have a home that is always on screen rather than a box that appears. ---
DIM SHARED AS INTEGER TRAY_X, TRAY_Y, TRAY_W, TRAY_H
DIM SHARED TRAY_CAP AS STRING

'--- the screen under the dice. dice3d_roll runs its own animation loop and only
'    draws DICE; without laying this back down every frame the rest of the screen
'    is whatever was last flipped, which is how a UI "disappears" mid-roll. ---
DIM SHARED MGD_SNAP AS LONG

'--- the settled dice. The hardware path draws its triangles STRAIGHT TO THE
'    WINDOW, so anything not re-issued is gone on the next flip -- which is why
'    dice vanish the instant a roll returns unless somebody keeps drawing them. ---
DIM SHARED MGD_HELD AS INTEGER
DIM SHARED MGD_CFG AS DICE3D_CONFIG

CONST MG_MAXDICE = 16

'--- faces of the last animated roll. EMPTY under Real Dice: the player rolled
'    physical dice and the game never saw them. See GameRoll%. ---
DIM SHARED DIE_FACE(1 TO MG_MAXDICE) AS INTEGER
DIM SHARED DIE_FACE_N AS INTEGER
DIM SHARED rollseq_on AS INTEGER

'--- selftest only: pretend the player typed this, so the Real Dice path can be
'    driven headlessly instead of blocking on a keyboard nobody is at. ---
DIM SHARED MG_FAKEROLL AS INTEGER

'--- `dicedemo`: drive the REAL dice path in a tool mode. MgDiceInit normally
'    disables 3D whenever MG_QUIET is set, which is right for a selftest and
'    wrong for the one thing that needs testing -- the roll-and-repost path that
'    a selftest can never reach. ---
DIM SHARED MG_FORCE3D AS INTEGER
