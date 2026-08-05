' ============================================================================
'  CUTMOCK.bi -- globals for the standalone player's host hooks.
'  Separate from CUT.bi because none of this belongs to the ENGINE: a real
'  host (the game) supplies its own and includes only CUT.bi.
' ============================================================================

'--- the mock game state, seeded from the command line ---
DIM SHARED MOCK_K(0 TO 63) AS STRING * 40
DIM SHARED MOCK_S(0 TO 63) AS STRING * 40
DIM SHARED MOCK_V(0 TO 63) AS DOUBLE
DIM SHARED MOCK_N AS INTEGER

'--- which content pack to resolve assets through ---
DIM SHARED MOCK_PACK AS STRING

'--- what the scene DID: flags set, grants made, sfx fired. Printed after a
'    headless run, which is the only way to assert on a scene's side effects
'    without eyes on the screen. ---
DIM SHARED MOCK_LOG AS STRING

'--- music, with a frame-ticked fade ---
DIM SHARED MOCK_MUS AS LONG
DIM SHARED MOCK_MUSVOL AS SINGLE
DIM SHARED MOCK_MUSTARGET AS SINGLE
DIM SHARED MOCK_MUSFADE AS SINGLE
DIM SHARED MOCK_MUSLAST AS DOUBLE

'--- retire queue: a handle is parked here, never closed on the spot ---
DIM SHARED MOCK_RET(0 TO 16) AS LONG
DIM SHARED MOCK_RETT(0 TO 16) AS DOUBLE

'--- selftest counters (same shape as the mini-game prototypes' MG.bi) ---
DIM SHARED T_RUN AS INTEGER, T_BAD AS INTEGER
