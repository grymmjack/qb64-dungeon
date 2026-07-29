$CONSOLE:ONLY
'$INCLUDE:'TESTLIB.bi'
'$INCLUDE:'../engine/ENGINE.BI'

' ============================================================================
'  engine/ARTPACK.bas -- pack resolution + the keyword matcher.
'
'  ArtFile$ / AnsiFile$ are what make a PARTIAL pack work: each asset is looked up
'  in the selected pack first and falls back to default/ per FILE, so a pack that
'  ships three sprites overrides exactly those three. If the fallback ever broke,
'  a partial pack would show missing art instead of the base game's -- and only
'  for the assets it happens not to ship, which is a miserable thing to notice by
'  eye. These assert against real files in the repo.
'
'  InStrAny% backs the treasure-sprite keyword fallback (gems/cups/coffers/coins).
' ============================================================================

T_Begin "engine/ARTPACK.bas"

T_Group "InStrAny% (keyword fallback matcher)"
T_True "single word present", InStrAny%("a ruby gem", "gem")
T_True "one of several present", InStrAny%("a ruby gem", "coin cup gem")
T_False "none present", InStrAny%("a plain rock", "coin cup gem")
T_False "empty needle list", InStrAny%("anything", "")
T_True "matches inside a word (substring, by design)", InStrAny%("gemstone", "gem")
T_True "first word of the list matches", InStrAny%("gold coin", "coin cup")
T_True "last word of the list matches", InStrAny%("gold cup", "coin cup")
T_False "empty haystack", InStrAny%("", "gem")
T_True "extra spaces in the list are tolerated", InStrAny%("a gem", "  coin   gem  ")

T_Group "ArtFile$ -- default pack resolves a real sprite"
opt_artpack = "default"
DIM p AS STRING
p = ArtFile$("classes/hero.png")
T_True "found something for classes/hero.png", LEN(p) > 0
T_EqS "resolved under the default pack", p, "assets/pixel-art/default/classes/hero.png"
T_True "and the file really exists", _FILEEXISTS(p) <> 0

T_Group "ArtFile$ -- unknown pack falls back to default PER FILE"
opt_artpack = "no-such-pack-xyz"
p = ArtFile$("classes/hero.png")
T_EqS "missing pack file -> default", p, "assets/pixel-art/default/classes/hero.png"
T_True "still a real file", _FILEEXISTS(p) <> 0

T_Group "ArtFile$ -- a genuinely absent asset returns empty, not a bogus path"
opt_artpack = "default"
T_EqS "no such sprite anywhere", ArtFile$("classes/definitely-not-here.png"), ""

T_Group "AnsiFile$ -- the board art (collision map) must resolve"
opt_ansipack = "default"
p = AnsiFile$("board-132x50-no-labels.ans")
T_EqS "resolved under the default ANSI pack", p, "assets/ansi-art/default/board-132x50-no-labels.ans"
T_True "board art exists (the game cannot start without it)", _FILEEXISTS(p) <> 0
opt_ansipack = "no-such-pack-xyz"
T_EqS "unknown ANSI pack falls back to default", AnsiFile$("board-132x50-no-labels.ans"), "assets/ansi-art/default/board-132x50-no-labels.ans"
opt_ansipack = "default"
T_EqS "absent ANSI asset -> empty", AnsiFile$("no-such-art.ans"), ""

T_Done

' --- stubbed collaborators --------------------------------------------------
' ScanArtPacks/CycleArtPack reach for PackIndex% (engine/MUSIC.bas) and Sfx
' (engine/UI.bas); the sprite/box drawers reach for UI primitives. None are on the
' path under test, so stub rather than drag the audio + dice stack in. As in
' TEST-DATA, the stub list is an honest record of this module's real dependencies.
FUNCTION PackIndex% (packs() AS STRING, cnt AS INTEGER, want AS STRING)
    DIM i AS INTEGER
    PackIndex = 0
    FOR i = 1 TO cnt
        IF packs(i) = want THEN PackIndex = i: EXIT FUNCTION
    NEXT i
END FUNCTION

SUB Sfx (kind AS STRING)
END SUB

'$INCLUDE:'TESTLIB.bas'
'$INCLUDE:'../engine/TEXT.bas'
'$INCLUDE:'../engine/ARTPACK.bas'
