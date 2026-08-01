' ============================================================================
'  MINIMAL GAME -- the engine<->game contract, implemented by a game that is not
'  DUNGEON!. This file IS the proof that engine/ is separable: if the engine can
'  be driven by these ~40 lines, nothing DUNGEON!-specific is hiding inside it.
'
'  Every Game_* SUB/FUNCTION the engine calls must exist here.
'
'  DO NOT rely on "the demo stops compiling" to notice a new hook: a bare
'  `Game_Foo` statement whose SUB is undefined parses as a LABEL, not a call, so
'  it compiles clean and silently does nothing. That is exactly what happened when
'  Game_RenderHUD was added. tests/audit-boundary.sh is the real alarm -- it
'  set-differences the hooks engine/ CALLS against the ones this file DEFINES.
'  See engine/ENGINE.md.
' ============================================================================

' The engine asks the game to claim its board regions after the art is painted.
' A walk-around demo has none, so this is honestly empty.
SUB Game_PopulateBoard
END SUB

' Map-layer labels (drawn under the near-death overlay). None here.
SUB Game_RenderMapLabels
END SUB

' Repaint the game's HUD layer after the engine wipes an overlay off the board
' (the 3D dice roller needs this). This demo has no HUD.
SUB Game_RenderHUD
END SUB

' On-top overlays: entities, tokens, markers. This demo draws just the player.
SUB Game_RenderOverlays
    _DEST CANVAS
    _FONT CH
    COLOR _RGB32(&HFF, &HFF, &HFF), _RGB32(&H00, &H80, &H00)
    _PRINTSTRING (c.x, c.y), "@"
    COLOR _RGB32(&HFF, &HFF, &HFF), _RGB32(&H00, &H00, &H00)
END SUB

' Poison overlay intensity, 0..1. This game has no status effects.
FUNCTION Game_PoisonLevel!
    Game_PoisonLevel! = 0
END FUNCTION

' May the engine draw the near-death blood/vignette? Only if the ruleset tracks HP.
FUNCTION Game_ShowWounds%
    Game_ShowWounds% = 0
END FUNCTION

' The roster of themeable effect names the engine should register. A different
' game ships different sounds -- that is the whole point of this being a hook.
FUNCTION Game_SfxNames$
    Game_SfxNames$ = "move bump select"
END FUNCTION

' What colour counts as walkable room floor at this pixel? 0 = none here.
' DUNGEON! answers "the colour of whichever dungeon level owns this cell"; this
' demo has one uniform floor colour, which is the point -- the engine never knew
' about dungeon levels, only about a colour to compare.
FUNCTION Game_FloorColorAt~& (px AS INTEGER, py AS INTEGER)
    Game_FloorColorAt~& = _RGB32(&H00, &HAA, &H00)
END FUNCTION

' Zone identity, used by the engine's mask linter. One zone here.
FUNCTION Game_ZoneByColor% (col AS _UNSIGNED LONG)
    IF col = _RGB32(&H00, &HAA, &H00) THEN Game_ZoneByColor% = 1 ELSE Game_ZoneByColor% = 0
END FUNCTION

FUNCTION Game_ZoneName$ (id AS INTEGER)
    IF id = 1 THEN Game_ZoneName$ = "THE ONLY ZONE"
END FUNCTION

FUNCTION Game_ZoneCount%
    Game_ZoneCount% = 1
END FUNCTION


' No ability scores in this example -- a flat, sane sight radius.
FUNCTION Game_SightRadius%
    Game_SightRadius% = 10
END FUNCTION
