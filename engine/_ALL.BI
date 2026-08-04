$INCLUDEONCE
' ============================================================================
'  engine/_ALL.BI -- every ENGINE header, in one include.
'
'  Put this at the TOP of a program, before any executable line, then game/_ALL.BI --
'  engine primitives/types first; game types may build on engine ones, never the reverse.
'  The bodies are engine/_ALL.BM, included at the BOTTOM.
'
'  Paths here are relative to THIS file's directory (engine/), which is how QB64 resolves
'  a nested '$INCLUDE -- the same convention engine/DICE3D/_ALL.BI and engine/ansi/
'  already rely on. So engine/ stays copy-out-able as a directory.
' ============================================================================
'$INCLUDE:'ansi/ANSIPrint.bi'
'$INCLUDE:'ENGINE.BI'
'$INCLUDE:'CUTSCENE.BI'
'$INCLUDE:'DICE3D/_ALL.BI'
'$INCLUDE:'DICE3D_GAME.bi'
