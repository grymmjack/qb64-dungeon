$INCLUDEONCE
' ============================================================================
'  engine/SCHEMA.BI -- state for the DATA TABLE REGISTRY (engine/SCHEMA.bas).
'
'  Its own header, like ASSETS.BI, so a standalone tool can use it without
'  pulling in ENGINE.BI.
' ============================================================================
CONST DT_MAX = 64
DIM SHARED DT_FILE(1 TO DT_MAX) AS STRING     ' the table's file name, as a loader names it
DIM SHARED DT_COLS(1 TO DT_MAX) AS STRING     ' "a|b|c" -- the column names, in order
DIM SHARED DT_NCOL(1 TO DT_MAX) AS INTEGER    ' how many, cached
DIM SHARED DT_SPLIT(1 TO DT_MAX) AS INTEGER   ' 0 = split on EVERY pipe; n = only the first n-1
DIM SHARED DT_N AS INTEGER
