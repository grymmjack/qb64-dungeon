$INCLUDEONCE
'' DICE3D_GAME.bi -- dungeon-side globals for the 3D dice.
'  Included right AFTER include/DICE3D/_ALL.BI, since these arrays use DICE3D_CONFIG.
'  DSET3D / MSET3D are 7-slot dice sets (d4 d6 d8 d10 d12 d20 d100), indexed by
'  dice3d_set_index%(sides). Loaded from assets/data/diceset*.txt (see DICE3D_GAME.bas).

DIM SHARED DSET3D(0 TO 6) AS DICE3D_CONFIG   ' the player's 3D dice set
DIM SHARED MSET3D(0 TO 6) AS DICE3D_CONFIG   ' the monster's 3D dice set
DIM SHARED dice3d_ready AS INTEGER           ' TRUE once a set loaded OK (else 3D silently falls back to font dice)
' the selectable dice-set manifest (assets/data/dicesets.txt): display name + file
DIM SHARED DSET_NAME(1 TO 40) AS STRING, DSET_FILE(1 TO 40) AS STRING, DSET_COUNT AS INTEGER
