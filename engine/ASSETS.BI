$INCLUDEONCE
' ============================================================================
'  engine/ASSETS.BI -- state for the asset PATH REGISTRY (engine/ASSETS.bas).
'
'  Its own header rather than a corner of ENGINE.BI, because the registry is
'  used by hosts that do not include ENGINE.BI at all -- engine/cutplay is one,
'  and any future standalone tool is another. A part that other parts depend on
'  has to be includable on its own.
' ============================================================================
CONST AK_MAX = 24
DIM SHARED ASSET_ROOT AS STRING           ' where this host keeps its fuel
DIM SHARED ASSET_DEFPACK AS STRING        ' the fallback pack folder name ("default")
DIM SHARED AK_NAME(1 TO AK_MAX) AS STRING
DIM SHARED AK_DIR(1 TO AK_MAX) AS STRING
DIM SHARED AK_PACKED(1 TO AK_MAX) AS INTEGER   ' <kind>/<pack>/<file>, falling back to default
DIM SHARED AK_N AS INTEGER
'--- kinds the engine asked for that nobody declared: recorded, not guessed ---
DIM SHARED AK_MISS(1 TO AK_MAX) AS STRING
DIM SHARED AK_MISS_N AS INTEGER
