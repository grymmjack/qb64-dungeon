$CONSOLE:ONLY
'$INCLUDE:'TESTLIB.bi'
'$INCLUDE:'../engine/ENGINE.BI'

' ============================================================================
'  engine/MARKDOWN.bas -- the md -> text-mode renderer's pure half.
'
'  This drives the in-game Rules screen, which reads DUNGEON-RULES.md. The two
'  parts worth pinning:
'
'  - Utf8ToAscii$ / RulesStrip$: the CP437 grid font renders each UTF-8 BYTE as
'    its own DOS glyph, so an em-dash arrives as three garbage characters. These
'    fold the typographic punctuation the rules file actually uses down to ASCII.
'    A regression here is mojibake, not a crash.
'  - MdBlock%: classifies each line (heading / bullet / rule / table / quote).
'    Its return codes are positional magic numbers, so they are easy to break.
'
'  MdInline/EmitTable also exercise the locals renamed by the shadow audit
'  (c -> chx / col), so this suite guards that refactor too.
' ============================================================================

T_Begin "engine/MARKDOWN.bas"

DIM E3 AS STRING, E2 AS STRING
E3 = CHR$(226) + CHR$(128)                       ' UTF-8 lead bytes for the U+20xx punctuation
E2 = CHR$(194)

T_Group "SubstAll$"
T_EqS "single hit", SubstAll$("a.b", ".", "-"), "a-b"
T_EqS "every occurrence", SubstAll$("a.b.c", ".", "-"), "a-b-c"
T_EqS "no match is a no-op", SubstAll$("abc", "z", "y"), "abc"
T_EqS "delete by replacing with empty", SubstAll$("a**b**c", "**", ""), "abc"
T_EqS "empty needle returns input (no infinite loop)", SubstAll$("abc", "", "x"), "abc"
T_EqS "multi-char needle", SubstAll$("xxaayyaazz", "aa", "-"), "xx-yy-zz"
T_EqS "replacement containing the needle terminates", SubstAll$("a", "a", "aa"), "aa"

T_Group "Utf8ToAscii$ (CP437 grid font shows raw UTF-8 bytes as garbage)"
T_EqS "em dash -> --", Utf8ToAscii$("a" + E3 + CHR$(148) + "b"), "a--b"
T_EqS "en dash -> -", Utf8ToAscii$("a" + E3 + CHR$(147) + "b"), "a-b"
T_EqS "rightwards arrow -> ->", Utf8ToAscii$("a" + CHR$(226) + CHR$(134) + CHR$(146) + "b"), "a->b"
T_EqS "ellipsis -> ...", Utf8ToAscii$("a" + E3 + CHR$(166)), "a..."
T_EqS "copyright -> (c)", Utf8ToAscii$(E2 + CHR$(169) + " TSR"), "(c) TSR"
T_EqS "plain ASCII untouched", Utf8ToAscii$("plain - text"), "plain - text"
T_EqS "several in one line", Utf8ToAscii$(E3 + CHR$(148) + E3 + CHR$(166)), "--..."

T_Group "RulesStrip$"
T_EqS "drops leading heading hashes", RulesStrip$("## Combat"), "Combat"
T_EqS "drops bold markers", RulesStrip$("roll **2d6** vs"), "roll 2d6 vs"
T_EqS "drops code ticks", RulesStrip$("see `opt_oldschool`"), "see opt_oldschool"
T_EqS "trims", RulesStrip$("   spaced   "), "spaced"
T_EqS "folds UTF-8 too", RulesStrip$("move" + E3 + CHR$(148) + "then"), "move--then"
T_EqS "combined", RulesStrip$("# **Level 3** `x`"), "Level 3 x"

T_Group "MdBlock% (line classification)"
DIM ct AS STRING
T_EqI "blank -> 7", MdBlock%("", ct), 7
T_EqI "blank (spaces) -> 7", MdBlock%("   ", ct), 7
T_EqI "h1 -> 1", MdBlock%("# Title", ct), 1
T_EqS "  h1 content", ct, "Title"
T_EqI "h2 -> 2", MdBlock%("## Sub", ct), 2
T_EqI "h3 -> 3", MdBlock%("### Deep", ct), 3
T_EqI "h4+ clamps to 3", MdBlock%("##### Deeper", ct), 3
T_EqI "dash bullet -> 4", MdBlock%("- item", ct), 4
T_EqS "  bullet content", ct, "item"
T_EqI "star bullet -> 4", MdBlock%("* item", ct), 4
T_EqI "horizontal rule -> 5", MdBlock%("---", ct), 5
T_EqI "long rule -> 5", MdBlock%("--------", ct), 5
T_EqI "table row -> 6", MdBlock%("| a | b |", ct), 6
T_EqI "block quote -> 8", MdBlock%("> noted", ct), 8
T_EqS "  quote content", ct, "noted"
T_EqI "plain paragraph -> 0", MdBlock%("just words", ct), 0
T_EqI "two dashes is NOT a rule (needs 3)", MdBlock%("--", ct), 0

T_Group "IsDashes% (table separator row)"
T_True "all dashes", IsDashes%("---")
T_True "dashes with colons (alignment)", IsDashes%(":---:")
T_True "dashes with spaces", IsDashes%(" --- ")
T_False "empty is not a separator", IsDashes%("")
T_False "letters are not", IsDashes%("abc")
T_False "mixed content is not", IsDashes%("--a--")

T_Group "StyOf% (style byte)"
T_EqI "plain", StyOf%(0, 0), 0
T_EqI "bold", StyOf%(-1, 0), 1
T_EqI "code", StyOf%(0, -1), 2
T_EqI "code beats bold", StyOf%(-1, -1), 2

T_Group "MdInline$ (bold / code / links)"
DIM vis AS STRING, sty AS STRING, lnk AS STRING, nurl AS INTEGER
REDIM urls(1 TO 32) AS STRING
nurl = 0
MdInline "plain text", vis, sty, lnk, urls(), nurl
T_EqS "plain passes through", vis, "plain text"
T_EqI "no links collected", nurl, 0

nurl = 0
MdInline "a **bold** b", vis, sty, lnk, urls(), nurl
T_EqS "bold markers removed from visible text", vis, "a bold b"
T_EqI "bold chars carry style 1", ASC(sty, 3), 1

nurl = 0
MdInline "use `code` now", vis, sty, lnk, urls(), nurl
T_EqS "backticks removed", vis, "use code now"
T_EqI "code chars carry style 2", ASC(sty, 5), 2

nurl = 0
MdInline "see [the rules](http://x.y) ok", vis, sty, lnk, urls(), nurl
T_EqS "link shows its TEXT, not the url", vis, "see the rules ok"
T_EqI "one url collected", nurl, 1
T_EqS "  url captured", urls(1), "http://x.y"

T_Group "AddURL%"
REDIM u2(1 TO 3) AS STRING
DIM n2 AS INTEGER
n2 = 0
T_EqI "first id is 1", AddURL%("a", u2(), n2), 1
T_EqI "second id is 2", AddURL%("b", u2(), n2), 2
T_EqS "stored trimmed", u2(1), "a"
n2 = 3
T_EqI "refuses past the bound (returns 0)", AddURL%("z", u2(), n2), 0

T_Done

'$INCLUDE:'TESTLIB.bas'
'$INCLUDE:'../engine/TEXT.bas'
'$INCLUDE:'../engine/MARKDOWN.bas'
