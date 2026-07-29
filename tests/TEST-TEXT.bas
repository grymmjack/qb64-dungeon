$CONSOLE:ONLY
'$INCLUDE:'TESTLIB.bi'

' ============================================================================
'  engine/TEXT.bas -- the reusable string helpers. All pure, so all cheap to pin.
'
'  These are used across ~5 modules (PadR$ lays out every column in LORDS/CHRONICLE,
'  NthField$ parses chambers.txt, StrSubst$ re-labels banners), so a regression here
'  is quiet and widespread -- exactly what a unit test is for.
' ============================================================================

T_Begin "engine/TEXT.bas"

T_Group "NthField$"
T_EqS "first field", NthField$("a|b|c", "|", 1), "a"
T_EqS "middle field", NthField$("a|b|c", "|", 2), "b"
T_EqS "last field (no trailing delim)", NthField$("a|b|c", "|", 3), "c"
T_EqS "past the end -> empty", NthField$("a|b|c", "|", 4), ""
T_EqS "single field, no delim", NthField$("solo", "|", 1), "solo"
T_EqS "empty middle field", NthField$("a||c", "|", 2), ""
T_EqS "multi-char delimiter", NthField$("a ~~ b ~~ c", " ~~ ", 2), "b"
T_EqS "keeps inner spaces", NthField$("KING'S LIBRARY|86", "|", 1), "KING'S LIBRARY"

T_Group "PadR$"
T_EqS "pads to width", PadR$("ab", 5), "ab   "
T_EqS "exact width truncates to w-1 + space", PadR$("abcde", 5), "abcd "
T_EqS "over width truncates + trailing space", PadR$("abcdefgh", 5), "abcd "
T_EqS "empty pads fully", PadR$("", 3), "   "
T_EqI "result is always the requested width", LEN(PadR$("abcdefgh", 6)), 6
T_EqI "result width holds when short too", LEN(PadR$("x", 6)), 6

T_Group "MMSS$"
T_EqS "zero", MMSS$(0), "0:00"
T_EqS "seconds pad to 2", MMSS$(7), "0:07"
T_EqS "one minute", MMSS$(60), "1:00"
T_EqS "mixed", MMSS$(125), "2:05"
T_EqS "no cap at an hour", MMSS$(3661), "61:01"
T_EqS "solo 30-min limit", MMSS$(1800), "30:00"

T_Group "StrSubst$"
T_EqS "single hit", StrSubst$("hello world", "world", "there"), "hello there"
T_EqS "every occurrence", StrSubst$("a.b.c", ".", "-"), "a-b-c"
T_EqS "no match is a no-op", StrSubst$("abc", "z", "y"), "abc"
T_EqS "replace with empty", StrSubst$("a-b-c", "-", ""), "abc"
T_EqS "grows without looping forever", StrSubst$("aa", "a", "aa"), "aaaa"
T_EqS "replacement containing the needle terminates", StrSubst$("x", "x", "xx"), "xx"
T_EqS "flavor token fill", StrSubst$("the {mon} strikes", "{mon}", "OGRE"), "the OGRE strikes"

T_Done

'$INCLUDE:'TESTLIB.bas'
'$INCLUDE:'../engine/TEXT.bas'
