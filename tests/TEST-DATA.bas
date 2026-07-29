$CONSOLE:ONLY
'$INCLUDE:'TESTLIB.bi'
'$INCLUDE:'../engine/ENGINE.BI'

' ============================================================================
'  engine/DATA.bas -- the game-free half: field parsing, mask normalisation,
'  pipe colours, hex colours, SAUCE, and data-pack path resolution.
'
'  MaskNormalize$ is the one that most deserves a test: the board masks are
'  art-as-data, and TWO things an ANSI editor emits silently corrupt them --
'  CRLF line endings (each row is exactly SW columns, so the wrap PLUS the CRLF
'  double-advances and every other row reads black) and sticky SGR attributes (a
'  bright iCE background stays set when the next run only changes colour, so a
'  level reads as the wrong level). Both are repaired at load here; a regression
'  would not crash, it would quietly mis-map dungeon levels.
' ============================================================================

DIM SHARED ESCC AS STRING
ESCC = CHR$(27)

T_Begin "engine/DATA.bas"

T_Group "DField$"
T_EqS "first field", DField$("a|b|c", 1), "a"
T_EqS "middle field", DField$("a|b|c", 2), "b"
T_EqS "last field", DField$("a|b|c", 3), "c"
T_EqS "past the end -> empty", DField$("a|b|c", 4), ""
T_EqS "trims padding (columns may be aligned)", DField$("  a  |  b  ", 1), "a"
T_EqS "trims the middle too", DField$("  a  |  b  ", 2), "b"
T_EqS "single field, no delimiter", DField$("solo", 1), "solo"
T_EqS "empty field stays empty", DField$("a||c", 2), ""
T_EqS "keeps inner spaces", DField$("GIANT RATS|7", 1), "GIANT RATS"

T_Group "HexRGB~&"
T_EqS "plain hex", HEX$(HexRGB~&("FF8000")), HEX$(_RGB32(255, 128, 0))
T_EqS "leading # accepted", HEX$(HexRGB~&("#FF8000")), HEX$(_RGB32(255, 128, 0))
T_EqS "surrounding space trimmed", HEX$(HexRGB~&("  00FF00  ")), HEX$(_RGB32(0, 255, 0))
T_EqS "lowercase hex", HEX$(HexRGB~&("ff8000")), HEX$(_RGB32(255, 128, 0))
T_EqS "black", HEX$(HexRGB~&("000000")), HEX$(_RGB32(0, 0, 0))
T_EqS "too short -> black, not garbage", HEX$(HexRGB~&("FFF")), HEX$(_RGB32(0, 0, 0))
T_EqS "empty -> black", HEX$(HexRGB~&("")), HEX$(_RGB32(0, 0, 0))

'--- the art-as-data repair: strip CR/LF, self-contain every SGR run, stop at EOF ---
T_Group "MaskNormalize$"
T_EqS "plain text untouched", MaskNormalize$("ABC"), "ABC"
T_EqS "CRLF stripped (rows must auto-wrap)", MaskNormalize$("AB" + CHR$(13) + CHR$(10) + "CD"), "ABCD"
T_EqS "bare LF stripped too", MaskNormalize$("AB" + CHR$(10) + "CD"), "ABCD"
T_EqS "reset injected before an SGR run", MaskNormalize$(ESCC + "[41m"), ESCC + "[0m" + ESCC + "[41m"
T_EqS "reset before EVERY run (no attribute leak)", MaskNormalize$(ESCC + "[5;42mX" + ESCC + "[46mY"), ESCC + "[0m" + ESCC + "[5;42mX" + ESCC + "[0m" + ESCC + "[46mY"
T_EqS "stops at 0x1A so SAUCE is not rendered", MaskNormalize$("ART" + CHR$(26) + "SAUCE00junk"), "ART"
T_EqS "CRLF + SGR together", MaskNormalize$("A" + CHR$(13) + CHR$(10) + ESCC + "[41mB"), "A" + ESCC + "[0m" + ESCC + "[41mB"
T_EqS "empty in, empty out", MaskNormalize$(""), ""

T_Group "PipeCol$ (CLI_COLOR off -> codes stripped)"
CLI_COLOR = 0
T_EqS "code removed, text kept", PipeCol$("|10OK"), "OK"
T_EqS "multiple codes removed", PipeCol$("|10OK |12BAD"), "OK BAD"
T_EqS "literal pipe escape", PipeCol$("a|PIb"), "a|b"
T_EqS "unknown code passes through", PipeCol$("|ZZx"), "|ZZx"
T_EqS "bare trailing pipe kept", PipeCol$("a|"), "a|"
T_EqS "no codes -> unchanged", PipeCol$("plain text"), "plain text"

T_Group "PipeCol$ (CLI_COLOR on -> SGR emitted)"
CLI_COLOR = -1
T_EqS "green + reset appended", PipeCol$("|10OK"), ESCC + "[92m" + "OK" + ESCC + "[0m"
T_EqS "literal pipe still literal", PipeCol$("|PI"), "|" + ESCC + "[0m"
CLI_COLOR = 0

T_Group "SauceRecord$"
T_EqI "SAUCE record is 128 bytes", LEN(SauceRecord$("t", 132, 50, 1000)), 128
T_EqS "starts with the SAUCE id + version", LEFT$(SauceRecord$("t", 132, 50, 1000), 7), "SAUCE00"
T_EqS "title is padded into the record", MID$(SauceRecord$("MASK", 132, 50, 0), 8, 4), "MASK"
T_EqI "cols round-trip (TInfo1)", CVI(MID$(SauceRecord$("t", 132, 50, 0), 97, 2)), 132
T_EqI "rows round-trip (TInfo2)", CVI(MID$(SauceRecord$("t", 132, 50, 0), 99, 2)), 50
T_EqI "datalen round-trip (FileSize)", CVL(MID$(SauceRecord$("t", 132, 50, 4321), 91, 4)), 4321

'--- pack resolution: per-file fallback to default/ is what makes a PARTIAL pack work ---
T_Group "DataPath$"
opt_datapack = "default"
T_EqS "data path -> default pack", DataPath$("assets/data/monsters.txt"), "assets/data/default/monsters.txt"
T_EqS "flavor path -> default pack", DataPath$("assets/flavor/maxhit.txt"), "assets/flavor/default/maxhit.txt"
T_EqS "non-data path untouched", DataPath$("assets/music/theme.rad"), "assets/music/theme.rad"
T_EqS "unrelated path untouched", DataPath$("dungeon.bas"), "dungeon.bas"
opt_datapack = ""
T_EqS "empty pack behaves as default", DataPath$("assets/data/monsters.txt"), "assets/data/default/monsters.txt"
opt_datapack = "no-such-pack"
T_EqS "missing pack file falls back to default", DataPath$("assets/data/monsters.txt"), "assets/data/default/monsters.txt"
opt_datapack = "default"

T_Done

' --- stubbed collaborators -------------------------------------------------
' engine/DATA.bas is not fully self-contained: ScanDataPacks/CycleDataPack reach for
' Sfx (engine/UI.bas). engine->engine, so not boundary debt -- but pulling UI in would
' drag the whole audio stack into a string-parsing test. Stub it; nothing under test
' calls it. (PackIndex% used to be stubbed here too; it moved to engine/TEXT.bas.)
SUB Sfx (kind AS STRING)
END SUB

'$INCLUDE:'TESTLIB.bas'
'$INCLUDE:'../engine/TEXT.bas'
'$INCLUDE:'../engine/DATA.bas'
