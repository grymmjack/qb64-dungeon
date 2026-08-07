' ============================================================================
'  game/ASSETTREE.bas -- WHERE DUNGEON! KEEPS ITS FUEL.
'
'  The engine asks for KINDS and never for paths (engine/ASSETS.bas). This is
'  the one place this game's asset layout is written down. A different game on
'  this engine writes a different one of these and changes nothing in engine/.
'
'  It is a SUB rather than lines in dungeon.bas so that the unit suites can
'  declare the same tree the game does. Three of them exercise routines that
'  resolve asset paths, and a second hand-copied declaration in each would be
'  three more copies to drift -- which is the exact failure the registry exists
'  to end.
'
'  PACKED kinds live under a named pack subfolder and fall back to `default`
'  per file, so a partial pack overrides only what it ships.
' ============================================================================
SUB DeclareAssetTree
    AssetRoot "assets/"
    AssetDefaultPack "default"

    AssetKindPacked "data", "data/"          ' the content tables
    AssetKindPacked "flavor", "flavor/"      ' the prose that goes with them

    AssetKindPacked "pixelart", "pixel-art/"
    AssetKindPacked "ansiart", "ansi-art/"
    AssetKindPacked "sfx", "sfx/"
    AssetKindPacked "music", "music/"
    AssetKindPacked "narration", "narration/"
    AssetKindPacked "cutscenes", "cutscenes/"
    AssetKind "fonts", "fonts/"
END SUB
