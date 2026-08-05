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

' --- dev-console dump hooks. The engine's [`] console asks the game to declare and run its own
'     dump topics; a game with no game-specific state to show just declares none. Both must
'     exist even when empty -- an undefined Game_* called as a statement parses as a LABEL and
'     silently never runs (see the note at the top of this file).
SUB Game_RegisterDumps
END SUB

FUNCTION Game_DevDump% (topic AS STRING)
    Game_DevDump% = 0                            ' this game claims no topics
END FUNCTION

' The engine has stood the board up. This game draws no HUD, so there is nothing to enable --
' but the hook must exist: an undefined Game_* called as a statement parses as a LABEL.
SUB Game_BoardShown
END SUB

' ----------------------------------------------------------------------------
'  CUT-SCENE HOOKS
'
'  This game has no cut-scenes. The stubs exist because a bare `Game_Foo`
'  statement whose SUB is undefined parses as a LABEL, not a call -- it
'  compiles clean and silently does nothing, so "the demo still builds" proves
'  nothing at all. tests/audit-boundary.sh is the alarm; these are the answer.
'
'  Every one is the honest empty behaviour, not a placeholder: no state, no
'  assets, no sound. A cut-scene run against this host plays silently against
'  missing art, which is exactly what should happen.
' ----------------------------------------------------------------------------
FUNCTION Game_CutState# (k AS STRING)
    Game_CutState# = 0
END FUNCTION

FUNCTION Game_CutStateStr$ (k AS STRING)
    Game_CutStateStr$ = ""
END FUNCTION

SUB Game_CutSetFlag (nm AS STRING, v AS DOUBLE)
END SUB

SUB Game_CutGrant (what AS STRING, amount AS DOUBLE)
END SUB

FUNCTION Game_CutArtPath$ (subpath AS STRING)
    Game_CutArtPath$ = ""
END FUNCTION

FUNCTION Game_CutAudioPath$ (kind AS STRING, nm AS STRING)
    Game_CutAudioPath$ = ""
END FUNCTION

SUB Game_CutMusic (path AS STRING, fadein AS SINGLE, doloop AS INTEGER)
END SUB

SUB Game_CutMusicStop (fade AS SINGLE)
END SUB

SUB Game_CutSfx (nm AS STRING)
END SUB

SUB Game_CutNarrate (k AS STRING)
END SUB

SUB Game_CutAudioTick
END SUB


'--- one zone, one colour: a game with no levels still gets a 3D view ---
FUNCTION Game_FpsZone% (cx AS INTEGER, cy AS INTEGER)
    Game_FpsZone% = 1
END FUNCTION

FUNCTION Game_FpsZoneColor~& (z AS INTEGER)
    Game_FpsZoneColor~& = _RGB32(&H70, &H78, &H88)
END FUNCTION


'--- a game with nothing in its world still gets walls ---
SUB Game_FpsPopulate
END SUB
