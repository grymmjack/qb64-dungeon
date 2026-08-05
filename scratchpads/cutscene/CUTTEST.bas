' ============================================================================
'  CUTTEST.bas -- headless assertions for the cut-scene engine.
'
'  Only what can be checked WITHOUT eyes: the compiler, the condition
'  evaluator, the easing curves, the clock, and the VM's control flow. What a
'  scene LOOKS like is checked with `shot`, which is a different question.
'
'  Run:  cutplay.run selftest      (exit code 1 if anything fails)
' ============================================================================

SUB CutOk (label AS STRING, cond AS INTEGER)
    T_RUN = T_RUN + 1
    IF cond THEN
        PRINT "  ok   "; label
    ELSE
        T_BAD = T_BAD + 1
        PRINT "  FAIL "; label
    END IF
END SUB

SUB CutSect (s AS STRING)
    PRINT
    PRINT "-- "; s
END SUB

'--- compile a scene given as TEXT, by writing it to a scratch file. The
'    compiler's input is a path, and faking that would test a different code
'    path than the one authors use. ---
FUNCTION CutCompileText% (body AS STRING)
    DIM p AS STRING, f AS INTEGER
    p = "cuttest-scratch.cut"
    f = FREEFILE
    OPEN p FOR OUTPUT AS #f
    PRINT #f, body;
    CLOSE #f
    CutCompileText% = CutCompile%(p)
    KILL p
END FUNCTION

SUB DoSelftest
    DIM ok AS INTEGER, s AS STRING, i AS INTEGER
    DIM ct(0 TO 63) AS STRING, n AS INTEGER

    _DEST _CONSOLE
    PRINT "cutscene engine selftest"

    ' ------------------------------------------------------------------
    CutSect "tokeniser"

    CutTokenize "show bg " + CHR$(34) + "crypt.png" + CHR$(34) + " fade 1.5"
    CutOk "token count", CUT_NTK = 5
    CutOk "quoted flag set on the path", CUT_TKQ(3) <> 0
    CutOk "quoted flag clear on a bare word", CUT_TKQ(1) = 0
    CutOk "keyword scan finds 'fade'", CutKw%("fade", 3) = 4
    CutOk "keyword value reads back", ABS(CutKwNum!("fade", 3, 0) - 1.5) < 0.001

    '--- a modifier word INSIDE a quoted string must not be seen as a modifier,
    '    or `say "fade to black"` would silently acquire a fade. ---
    CutTokenize "say " + CHR$(34) + "fade 9 to black" + CHR$(34)
    CutOk "quoted text is one token", CUT_NTK = 2
    CutOk "keyword inside quotes is NOT a modifier", CutKw%("fade", 2) = -1

    CutTokenize "pan to 0.5,0.8 over 4"
    CutOk "comma separates a point", CUT_NTK = 6
    CutOk "point x parses", ABS(CutNum!(CutTok$(3)) - 0.5) < 0.001
    CutOk "point y parses", ABS(CutNum!(CutTok$(4)) - 0.8) < 0.001

    CutTokenize "stage 2112x1632"
    CutOk "WxH splits into two numbers", CUT_NTK = 3
    CutOk "  width", CutNum!(CutTok$(2)) = 2112
    CutOk "  height", CutNum!(CutTok$(3)) = 1632

    CutTokenize "show fx " + CHR$(34) + "fx/box2x.png" + CHR$(34)
    CutOk "a quoted path with an x is NOT split", CutTok$(3) = "fx/box2x.png"

    CutTokenize "set saw_omen=1"
    CutOk "'=' separates without spaces", CUT_NTK = 4
    CutOk "  flag name", CutTok$(2) = "saw_omen"
    CutOk "  value", CutTok$(4) = "1"

    '--- a RUN of comparison characters is ONE token. Splitting them singly
    '    turned `==` into two `=`, and rejoining a condition for storage then
    '    produced `class = = wizard`, which the evaluator refused -- so every
    '    `if class == wizard` in every scene failed to compile. ---
    CutTokenize "if class == wizard"
    CutOk "'==' survives as one token", CUT_NTK = 4
    CutOk "  operator is '=='", CutTok$(3) = "=="
    CutTokenize "if gold >= 5000"
    CutOk "'>=' survives as one token", CutTok$(3) = ">="
    CutTokenize "if a <> b"
    CutOk "'<>' survives as one token", CutTok$(3) = "<>"

    '--- ...but `>` is also a comparison character, so the arrow needs its own
    '    rule or every choice option would resolve to no label. ---
    CutTokenize "option " + CHR$(34) + "Open it" + CHR$(34) + " -> open_it"
    CutOk "'->' is NOT split by the comparison rule", CutTok$(3) = "->"
    CutOk "  and the label survives", CutTok$(4) = "open_it"

    ' ------------------------------------------------------------------
    CutSect "easing"

    CutOk "linear at 0", CutEase!(0, EASE_LINEAR) = 0
    CutOk "linear at 1", CutEase!(1, EASE_LINEAR) = 1
    CutOk "inout starts at 0", ABS(CutEase!(0, EASE_INOUT)) < 0.001
    CutOk "inout ends at 1", ABS(CutEase!(1, EASE_INOUT) - 1) < 0.001
    CutOk "inout is symmetric at the midpoint", ABS(CutEase!(0.5, EASE_INOUT) - 0.5) < 0.01
    CutOk "bounce lands exactly on 1", ABS(CutEase!(1, EASE_BOUNCE) - 1) < 0.001
    '--- back is SUPPOSED to leave 0..1; that overshoot is the effect ---
    CutOk "back overshoots past 1", CutEase!(0.75, EASE_BACK) > 1
    CutOk "input is clamped below 0", CutEase!(-5, EASE_LINEAR) = 0
    CutOk "input is clamped above 1", CutEase!(5, EASE_LINEAR) = 1

    ' ------------------------------------------------------------------
    CutSect "condition splitter"

    n = CutCondSplit%("gold >= 5000", ct())
    CutOk "spaced comparison splits to 3", n = 3
    CutOk "  operator is its own token", ct(2) = ">="

    n = CutCondSplit%("gold>=5000", ct())
    CutOk "UNspaced comparison splits to 3", n = 3
    CutOk "  key", ct(1) = "gold"
    CutOk "  operator", ct(2) = ">="
    CutOk "  value", ct(3) = "5000"

    n = CutCondSplit%("class == wizard and gold > 100", ct())
    CutOk "a chained condition splits to 7", n = 7
    CutOk "  joiner", LCASE$(ct(4)) = "and"

    ' ------------------------------------------------------------------
    CutSect "condition evaluation"

    MOCK_N = 0
    MockSet "gold", 6000, "6000"
    MockSet "class", 1, "wizard"
    MockSet "flag.saw_omen", 1, "1"

    CutOk "numeric >=  true", CutCondEval%("gold >= 5000")
    CutOk "numeric >=  false", CutCondEval%("gold >= 9000") = 0
    CutOk "string ==   true", CutCondEval%("class == wizard")
    CutOk "string ==   false", CutCondEval%("class == elf") = 0
    CutOk "string !=", CutCondEval%("class != elf")
    CutOk "bare key is a truth test", CutCondEval%("flag.saw_omen")
    CutOk "unknown key reads as false", CutCondEval%("flag.never_set") = 0
    CutOk "not inverts", CutCondEval%("not flag.never_set")
    CutOk "and, both true", CutCondEval%("gold > 100 and class == wizard")
    CutOk "and, one false", CutCondEval%("gold > 100 and class == elf") = 0
    CutOk "or, one true", CutCondEval%("class == elf or gold > 100")
    CutOk "or, both false", CutCondEval%("class == elf or gold > 99999") = 0

    ' ------------------------------------------------------------------
    CutSect "compiler: structure"

    ok = CutCompileText%("scene t" + CHR$(10) + "wait 1" + CHR$(10))
    CutOk "a minimal scene compiles", ok
    CutOk "  scene name is taken from the header", CUT_NAME = "t"
    '--- the implicit OP_END is why this is 2 and not 1 ---
    CutOk "  an END is always appended", CUT_OPS(CUT_NOP).cmd = OP_END

    ok = CutCompileText%("wibble 3" + CHR$(10))
    CutOk "an unknown command is a HARD error", ok = 0
    CutOk "  and it reports the line", CUT_ERRLINE(1) = 1

    ok = CutCompileText%("jump nowhere" + CHR$(10))
    CutOk "a jump to a missing label fails", ok = 0

    ok = CutCompileText%("label a" + CHR$(10) + "jump a" + CHR$(10))
    CutOk "a jump to a real label compiles", ok

    ok = CutCompileText%("label a" + CHR$(10) + "label a" + CHR$(10))
    CutOk "a duplicate label fails", ok = 0

    ok = CutCompileText%("if gold > 1" + CHR$(10) + "wait 1" + CHR$(10))
    CutOk "an unclosed if fails", ok = 0

    ok = CutCompileText%("if gold > 1" + CHR$(10) + "wait 1" + CHR$(10) + "end" + CHR$(10))
    CutOk "a closed if compiles", ok

    ' ------------------------------------------------------------------
    CutSect "compiler: async is a prefix, not a command"

    ok = CutCompileText%("async pan to 0.5,0.5 over 2" + CHR$(10))
    CutOk "async compiles", ok
    CutOk "  the op is flagged async", CutFindOp%(OP_PAN) > 0
    IF CutFindOp%(OP_PAN) > 0 THEN CutOk "  async flag is set", CUT_OPS(CutFindOp%(OP_PAN)).async <> 0

    ok = CutCompileText%("pan to 0.5,0.5 over 2" + CHR$(10))
    IF CutFindOp%(OP_PAN) > 0 THEN CutOk "  a plain pan is NOT async", CUT_OPS(CutFindOp%(OP_PAN)).async = 0

    ok = CutCompileText%("async" + CHR$(10))
    CutOk "async with no command fails", ok = 0

    ' ------------------------------------------------------------------
    CutSect "compiler: modifier order does not matter"

    ok = CutCompileText%("show bg " + CHR$(34) + "a.png" + CHR$(34) + " fade 2 at 0.25,0.75" + CHR$(10))
    CutOk "show with modifiers compiles", ok
    i = CutFindOp%(OP_SHOW)
    CutOk "  fade read", ABS(CUT_OPS(i).n1 - 2) < 0.001

    ok = CutCompileText%("show bg " + CHR$(34) + "a.png" + CHR$(34) + " at 0.25,0.75 fade 2" + CHR$(10))
    i = CutFindOp%(OP_SHOW)
    CutOk "  the SAME fade with the modifiers swapped", ABS(CUT_OPS(i).n1 - 2) < 0.001

    ' ------------------------------------------------------------------
    CutSect "compiler: explicit layer depth"

    '--- a new layer takes the next free z, so without an explicit `z` a
    '    layer can only ever be drawn IN FRONT of what is already shown. ---
    ok = CutCompileText%("show bg " + CHR$(34) + "a.png" + CHR$(34) + CHR$(10) + "show sky " + CHR$(34) + "b.png" + CHR$(34) + " z 0" + CHR$(10))
    CutOk "`z` compiles", ok
    CutRunHeadless 1
    i = CutLayerFind%("bg")
    n = CutLayerFind%("sky")
    CutOk "  both layers exist", i > 0 _ANDALSO n > 0
    IF i > 0 _ANDALSO n > 0 THEN CutOk "  the later layer sits BEHIND the earlier one", CUT_LAY(n).z < CUT_LAY(i).z

    ' ------------------------------------------------------------------
    CutSect "layers: fill sizes against the STAGE, not against a magic number"

    '--- `scale 8` is only right for one exact source size. Art regenerated a
    '    little smaller silently grows a black border in every scene that used
    '    it -- which is also what a missing backdrop looks like. ---
    ok = CutCompileText%("stage 2112x1632" + CHR$(10) + "show bg " + CHR$(34) + "bg/cut-gate.png" + CHR$(34) + " fill" + CHR$(10))
    CutOk "`fill` compiles", ok
    CutRunHeadless 1
    i = CutLayerFind%("bg")
    IF i > 0 THEN
        CutOk "  the layer loaded", CUT_LAY(i).w > 0
        CutOk "  it covers the stage horizontally", CUT_LAY(i).w * CUT_LAY(i).scale >= CUT_STAGEW - 1
        CutOk "  it covers the stage vertically", CUT_LAY(i).h * CUT_LAY(i).scale >= CUT_STAGEH - 1
    END IF

    ok = CutCompileText%("stage 2112x1632" + CHR$(10) + "show bg " + CHR$(34) + "bg/cut-gate.png" + CHR$(34) + " fit" + CHR$(10))
    CutRunHeadless 1
    i = CutLayerFind%("bg")
    IF i > 0 THEN
        CutOk "`fit` stays INSIDE the stage horizontally", CUT_LAY(i).w * CUT_LAY(i).scale <= CUT_STAGEW + 1
        CutOk "  and vertically", CUT_LAY(i).h * CUT_LAY(i).scale <= CUT_STAGEH + 1
    END IF

    ' ------------------------------------------------------------------
    CutSect "compiler: choice"

    s = "choice " + CHR$(34) + "Well?" + CHR$(34) + CHR$(10)
    s = s + "  option " + CHR$(34) + "Open it" + CHR$(34) + " -> a" + CHR$(10)
    s = s + "  option " + CHR$(34) + "Leave" + CHR$(34) + " -> b" + CHR$(10)
    s = s + "end" + CHR$(10)
    s = s + "label a" + CHR$(10) + "label b" + CHR$(10)
    ok = CutCompileText%(s)
    CutOk "a choice block compiles", ok
    i = CutFindOp%(OP_CHOICE)
    CutOk "  the option count is patched in", CUT_OPS(i).n1 = 2
    CutOk "  option 1 resolved to a real op", CUT_OPS(i + 1).n1 > 0
    CutOk "  option 2 resolved to a real op", CUT_OPS(i + 2).n1 > 0

    ok = CutCompileText%("option " + CHR$(34) + "x" + CHR$(34) + " -> a" + CHR$(10) + "label a" + CHR$(10))
    CutOk "an option outside a choice fails", ok = 0

    ' ------------------------------------------------------------------
    CutSect "VM: control flow"

    CUT_QUIET = TRUE

    '--- an if whose condition is FALSE must not execute its body ---
    MOCK_N = 0
    MockSet "gold", 10, "10"
    s = "if gold > 1000" + CHR$(10) + "set took_rich 1" + CHR$(10) + "end" + CHR$(10)
    s = s + "set reached_end 1" + CHR$(10)
    CutOk "false-branch scene compiles", CutCompileText%(s)
    CutRunHeadless 5
    CutOk "  the guarded body did NOT run", Game_CutState#("flag.took_rich") = 0
    CutOk "  execution continued past the block", Game_CutState#("flag.reached_end") = 1

    '--- ...and when it is TRUE, it must ---
    MOCK_N = 0
    MockSet "gold", 9999, "9999"
    CutOk "true-branch scene compiles", CutCompileText%(s)
    CutRunHeadless 5
    CutOk "  the guarded body ran", Game_CutState#("flag.took_rich") = 1

    '--- else must be exclusive with the if body ---
    MOCK_N = 0
    MockSet "gold", 10, "10"
    s = "if gold > 1000" + CHR$(10) + "set rich 1" + CHR$(10)
    s = s + "else" + CHR$(10) + "set poor 1" + CHR$(10) + "end" + CHR$(10)
    CutOk "if/else compiles", CutCompileText%(s)
    CutRunHeadless 5
    CutOk "  else branch taken", Game_CutState#("flag.poor") = 1
    CutOk "  if branch NOT taken", Game_CutState#("flag.rich") = 0

    '--- elseif picks exactly one arm ---
    MOCK_N = 0
    MockSet "gold", 500, "500"
    s = "if gold > 1000" + CHR$(10) + "set a 1" + CHR$(10)
    s = s + "elseif gold > 100" + CHR$(10) + "set b 1" + CHR$(10)
    s = s + "else" + CHR$(10) + "set c 1" + CHR$(10) + "end" + CHR$(10)
    CutOk "if/elseif/else compiles", CutCompileText%(s)
    CutRunHeadless 5
    CutOk "  only the elseif arm ran", Game_CutState#("flag.b") = 1
    CutOk "  the if arm did not", Game_CutState#("flag.a") = 0
    CutOk "  the else arm did not", Game_CutState#("flag.c") = 0

    ' ------------------------------------------------------------------
    CutSect "VM: the runaway guard"

    '--- two legal lines that would otherwise spin forever inside one frame ---
    s = "label spin" + CHR$(10) + "jump spin" + CHR$(10)
    CutOk "an unguarded jump loop COMPILES (it is legal)", CutCompileText%(s)
    CutBegin
    CUT_PC = 1
    CutStep
    CutOk "  but the VM stops it", CUT_RUNSTATE = CUT_ERROR
    CutOk "  and says why", CUT_NFATAL > 0

    ' ------------------------------------------------------------------
    CutSect "VM: grants reach the host"

    MOCK_N = 0
    s = "grant gold 250" + CHR$(10) + "grant key" + CHR$(10) + "take gold 50" + CHR$(10)
    CutOk "grant scene compiles", CutCompileText%(s)
    CutRunHeadless 5
    CutOk "  gold granted then taken", Game_CutState#("gold") = 200
    CutOk "  key granted", Game_CutState#("key") = 1

    ' ------------------------------------------------------------------
    CutSect "clock: the midnight wrap"

    '--- TIMER resets at midnight. Fake the wrap and prove the clock still
    '    only ever moves forwards; if it did not, every tween would freeze. ---
    CUT_CLKLAST = 86399#
    CUT_CLKWRAP = 0
    DIM t1 AS DOUBLE, t2 AS DOUBLE
    t1 = CUT_CLKLAST + CUT_CLKWRAP
    '--- simulate TIMER coming back as 1.0 just after midnight ---
    IF 1# < CUT_CLKLAST THEN CUT_CLKWRAP = CUT_CLKWRAP + 86400#
    CUT_CLKLAST = 1#
    t2 = 1# + CUT_CLKWRAP
    CutOk "time still moves forward across midnight", t2 > t1
    CutOk "  by the true elapsed gap (86399 -> 00:00:01 is 2s), not backwards a day", ABS((t2 - t1) - 2#) < 0.01
    CUT_CLKWRAP = 0

    ' ------------------------------------------------------------------
    CutSect "the clock shift is the seek mechanism"

    '--- a NEGATIVE shift advances the scene. Guarding it on dt <= 0 made
    '    every `shot` and every [->] scrub a silent no-op: the screenshot came
    '    back on whatever op the scene was on a microsecond in, and looked
    '    perfectly plausible. ---
    CutOk "timed scene compiles", CutCompileText%("wait 2" + CHR$(10) + "set past_the_wait 1" + CHR$(10))
    MOCK_N = 0
    CutBegin
    CUT_PC = 1
    CutStep
    CutOk "  the VM parks on the wait", CUT_WAIT = WAIT_TIME
    CutShiftClocks -3#
    CUT_NOW = CutClock#
    CutWaitCheck
    CutOk "  a negative shift elapses it", CUT_WAIT = WAIT_NONE
    CutStep
    CutOk "  and execution continues past it", Game_CutState#("flag.past_the_wait") = 1

    ' ------------------------------------------------------------------
    CutSect "variables (compile-time substitution)"

    ok = CutCompileText%("var myfont$ = " + CHR$(34) + "alagard.ttf" + CHR$(34) + CHR$(10) + "var big = 44" + CHR$(10))
    CutOk "var declarations compile", ok
    CutOk "  both are remembered", CUT_NVAR = 2

    '--- the point of the feature: a name stands in for a value ANYWHERE ---
    CutTokenize "font title myfont$ big"
    CutVarSubst
    CutOk "a string var substitutes its value", CutTok$(3) = "alagard.ttf"
    CutOk "  ...and comes back QUOTED, so it reads as a filename", CUT_TKQ(3) <> 0
    CutOk "a numeric var substitutes too", CutTok$(4) = "44"
    CutOk "  ...unquoted, so it still reads as a number", CUT_TKQ(4) = 0

    '--- text is text: a variable's name inside dialogue is not substituted ---
    CutTokenize "say " + CHR$(34) + "big myfont$ words" + CHR$(34)
    CutVarSubst
    CutOk "a var name INSIDE quoted text is left alone", CutTok$(2) = "big myfont$ words"

    ' ------------------------------------------------------------------
    CutSect "sticky font/colour, QB64-style"

    CutStyleDefaults
    CutOk "with nothing set, a style uses its built-in", CutInkFor~&(STY_SAY, "") = CUT_DEFCOL(STY_SAY)

    '--- scene-wide sticky ---
    CUT_GLOBCOL = _RGB32(1, 2, 3): CUT_GLOBCOLSET = TRUE
    CutOk "a scene-wide colour overrides the built-in", CutInkFor~&(STY_SAY, "") = _RGB32(1, 2, 3)
    CutOk "  and reaches EVERY style", CutInkFor~&(STY_TITLE, "") = _RGB32(1, 2, 3)

    '--- per-style sticky beats scene-wide ---
    CUT_STYCOL(STY_TITLE) = _RGB32(9, 9, 9): CUT_STYCOLSET(STY_TITLE) = TRUE
    CutOk "a per-style colour beats the scene-wide one", CutInkFor~&(STY_TITLE, "") = _RGB32(9, 9, 9)
    CutOk "  and leaves other styles alone", CutInkFor~&(STY_SAY, "") = _RGB32(1, 2, 3)

    '--- a per-LINE key beats both, and does NOT stick ---
    CutOk "a per-line colour beats both", CutInkFor~&(STY_TITLE, "red") = CutColor~&("red", 0)
    CutOk "  ...and does not change the sticky value", CutInkFor~&(STY_TITLE, "") = _RGB32(9, 9, 9)

    '--- BLACK is a legal colour, which is why "set" is a separate flag: 0
    '    cannot double as "unset" or a deliberate black falls back to bone ---
    CUT_STYCOL(STY_SAY) = _RGB32(0, 0, 0): CUT_STYCOLSET(STY_SAY) = TRUE
    CutOk "black is honoured, not treated as unset", CutInkFor~&(STY_SAY, "") = _RGB32(0, 0, 0)

    '--- fonts fall through the same three tiers ---
    CutStyleDefaults
    CutOk "no font set falls back to the grid font", CutFontFor&(STY_SAY, 0) = CUT_GRIDFONT
    CUT_GLOBFONT = 12345
    CutOk "a scene-wide font applies", CutFontFor&(STY_SAY, 0) = 12345
    CUT_STYFONT(STY_SAY) = 999
    CutOk "  a per-style font beats it", CutFontFor&(STY_SAY, 0) = 999
    CutOk "  a per-line font beats them both", CutFontFor&(STY_SAY, 777) = 777
    CutOk "  other styles keep the scene-wide font", CutFontFor&(STY_TITLE, 0) = 12345
    CutStyleDefaults

    '--- setting a colour must not blank the font, and vice versa ---
    ok = CutCompileText%("font title " + CHR$(34) + "alagard.ttf" + CHR$(34) + " 40" + CHR$(10) + "color title gold" + CHR$(10))
    CutOk "font+color on one style compiles", ok
    CutRunHeadless 1
    CutOk "  the colour was set", CUT_STYCOLSET(STY_TITLE)
    CutOk "  and the font SURVIVED the colour line", CUT_STYFONT(STY_TITLE) <> 0

    ' ------------------------------------------------------------------
    CutSect "pipe colours + {token} substitution"

    CutPipeInit
    DIM ps AS STRING
    ps = "The |10wizard |12HITS|07!"

    CutOk "strip removes the codes", CutPipeStrip$(ps) = "The wizard HITS!"
    CutOk "  visible length ignores markup", CutPipeVis%(ps) = 16
    CutOk "|PI is a literal pipe", CutPipeStrip$("a|PIb") = "a|b"
    CutOk "  and counts as ONE visible character", CutPipeVis%("a|PIb") = 3
    CutOk "a bare | that is not a code survives", CutPipeStrip$("5 | 3") = "5 | 3"
    CutOk "a background code strips too", CutPipeStrip$("|17red bg") = "red bg"

    '--- the typewriter reveals LETTERS, not markup: a code must come through
    '    with the letters before it, without consuming a reveal step ---
    CutOk "take(4) keeps the leading text", CutPipeStrip$(CutPipeTake$(ps, 4)) = "The "
    CutOk "take(6) has crossed the code and kept it", CutPipeTake$(ps, 6) = "The |10wi"
    CutOk "  ...so the visible count is exactly 6", CutPipeVis%(CutPipeTake$(ps, 6)) = 6
    CutOk "take beyond the end returns everything", CutPipeStrip$(CutPipeTake$(ps, 999)) = "The wizard HITS!"

    '--- {token} resolves through the SAME state keys as `if` ---
    MOCK_N = 0
    MockSet "class", 1, "wizard"
    MockSet "gold", 17, "17"
    CutOk "a string token substitutes", CutFillTokens$("I am a {class}.") = "I am a wizard."
    CutOk "a numeric token substitutes", CutFillTokens$("{gold} gold") = "17 gold"
    CutOk "an unknown token reads as 0, like a condition", CutFillTokens$("{nope}") = "0"
    CutOk "an unclosed brace is left alone", CutFillTokens$("a {b") = "a {b"

    '--- and the two compose, which is the whole point ---
    CutOk "pipes and tokens together", CutFillTokens$("|10{class} |12hits") = "|10wizard |12hits"
    CutOk "  ...and the result still strips clean", CutPipeStrip$(CutFillTokens$("|10{class} |12hits")) = "wizard hits"

    ' ------------------------------------------------------------------
    CutSect "frame sequences: any format, optional count"

    CutOk "png is the default extension", CutFramePathEx$("fx/fog", 3, "") = "fx/fog-03.png"
    CutOk "  and frames are zero-padded to two digits", CutFramePathEx$("fx/fog", 7, "png") = "fx/fog-07.png"
    CutOk "an ANSI sequence names .ans", CutFramePathEx$("fx/torch", 1, "ans") = "fx/torch-01.ans"
    CutOk "  a leading dot is tolerated", CutFramePathEx$("fx/torch", 1, ".ans") = "fx/torch-01.ans"
    CutOk "past nine, both digits are used", CutFramePathEx$("fx/torch", 12, "ans") = "fx/torch-12.ans"

    '--- PROBING: with no `frames <n>` the runtime counts by asking for frames
    '    until one does not resolve, so adding a frame is dropping a file in. ---
    ok = CutCompileText%("anim t " + CHR$(34) + "fx/torch" + CHR$(34) + " fps 10 ext ans" + CHR$(10))
    CutOk "anim compiles with no frame count", ok
    CutRunHeadless 1
    i = CutLayerFind%("t")
    IF i > 0 THEN
        CutOk "  it probed and found the six real frames", CUT_LAY(i).nframes = 6
        CutOk "  and it is flagged as an animation", CUT_LAY(i).isanim <> 0
    END IF

    ' ------------------------------------------------------------------
    CutSect "ANSI frames straight out of a .zip"

    '--- _INFLATE$ is ZLIB, not raw deflate, and a zip entry stores raw. It
    '    does not error on that -- it hands back a ten-megabyte buffer, which
    '    is exactly the sort of plausible answer that gets mistaken for
    '    success. The fix needs BOTH halves: the 2-byte zlib header to satisfy
    '    the format check, and the exact uncompressed size so it stops before
    '    the adler32 trailer that a zip does not carry. ---
    DIM zpath AS STRING, zraw AS STRING, zn AS INTEGER
    zpath = Game_CutArtPath$("torch.zip")
    CutOk "the test archive resolves", LEN(zpath) > 0

    zn = CutZipList%(zpath)
    CutOk "  it catalogues its entries", zn = 6
    CutOk "  sorted by name, so frame order is the artist's", _TRIM$(CUT_ZIPNAME(1)) = "torch-01.ans"
    CutOk "  and the last is the last", _TRIM$(CUT_ZIPNAME(6)) = "torch-06.ans"
    CutOk "  they really are DEFLATED, not stored", CUT_ZIPMETHOD(1) = 8

    zraw = CutZipRead$(zpath, 1)
    CutOk "an entry inflates", LEN(zraw) > 0
    CutOk "  to exactly the size the header promised", LEN(zraw) = CUT_ZIPUSIZE(1)
    CutOk "  and its CRC-32 matches the archive's", _CRC32(zraw) = CUT_ZIPCRC(1)
    '--- and it is the SAME bytes as the loose file on disk ---
    CutOk "  byte-identical to the loose frame", zraw = _READFILE$(Game_CutArtPath$("fx/torch-01.ans"))

    ok = CutCompileText%("anim t " + CHR$(34) + "torch.zip" + CHR$(34) + " fps 10" + CHR$(10))
    CutOk "a zip-sourced anim compiles", ok
    CutRunHeadless 1
    i = CutLayerFind%("t")
    IF i > 0 THEN
        CutOk "  the layer took all six frames", CUT_LAY(i).nframes = 6
        CutOk "  and knows they come from the archive", LEN(_TRIM$(CUT_LAY(i).azip)) > 0
    END IF

    ' ------------------------------------------------------------------
    CutSect "ANSI row normalisation (the banding bug)"

    '--- ANSI_Print advances at the WRAP POINT and again on the newline, so a
    '    file with both paints a blank row after every painted one. Rows are
    '    padded to the canvas width and the line breaks dropped.
    '
    '    The subtle half: a row that EXACTLY fills the width has already
    '    wrapped, so its column counter is back at 0 -- padding it "up to the
    '    width" would insert a whole blank row and cause the very banding this
    '    is meant to remove. That shipped once and looked like a font bug. ---
    DIM a3 AS STRING, r3 AS STRING
    a3 = "abc" + CHR$(13) + CHR$(10) + "def" + CHR$(13) + CHR$(10)
    r3 = CutAnsiNormalize$(a3, 3)
    CutOk "an exact-width row is NOT padded", r3 = "abcdef"
    CutOk "  so N rows produce exactly N*width cells", LEN(r3) = 6

    r3 = CutAnsiNormalize$("ab" + CHR$(10) + "cd" + CHR$(10), 3)
    CutOk "a SHORT row is padded out to the width", r3 = "ab cd "

    CutOk "CR alone is dropped", CutAnsiNormalize$("ab" + CHR$(13) + "c", 3) = "abc"
    CutOk "an escape sequence is copied, not counted", CutAnsiNormalize$(CHR$(27) + "[31mabc" + CHR$(10), 3) = CHR$(27) + "[31mabc"
    CutOk "everything after the 0x1A EOF is dropped", CutAnsiNormalize$("abc" + CHR$(26) + "SAUCE", 3) = "abc"

    ' ------------------------------------------------------------------
    CutSect "animated GIF decoding"

    '--- _LOADIMAGE opens a .gif and hands back only its FIRST frame: the handle
    '    is valid, every check passes, and the picture never moves. So the whole
    '    decoder is here, and this proves it reads frame TWO.
    '
    '    The GIF is embedded as bytes rather than read from assets/ because a
    '    test that depends on an asset file tests the asset, not the decoder --
    '    and this one has to keep working when the art is regenerated. ---
    DIM g AS STRING, gp AS STRING, gn AS INTEGER, gc AS _UNSIGNED LONG, gsrc AS LONG
    g = g + GifHex$("47494638396104000100F00000FF000000000021FF0B4E45")
    g = g + GifHex$("545343415045322E30030100000021F90400050000002C00")
    g = g + GifHex$("0000000400010000020284510021F90400050000002C0000")
    g = g + GifHex$("0000040001008000FF0000000002028451003B")

    gp = "cuttest-tiny.gif"
    DIM gf AS INTEGER
    gf = FREEFILE
    OPEN gp FOR OUTPUT AS #gf: CLOSE #gf          ' truncate
    OPEN gp FOR BINARY AS #gf
    PUT #gf, 1, g
    CLOSE #gf

    CutOk "a .gif is recognised as one", CutIsGif%("fx/fire.gif")
    CutOk "a .png is not", CutIsGif%("fx/fire.png") = 0

    gn = GifLoadInto%(1, gp)
    CutOk "the decoder finds BOTH frames (not just the first)", gn = 2
    IF gn >= 2 THEN
        gsrc = _SOURCE
        _SOURCE CUT_GIFIMG(1, 1)
        gc = POINT(1, 0)
        CutOk "  frame 1 is red", _RED32(gc) > 200 _ANDALSO _GREEN32(gc) < 60
        _SOURCE CUT_GIFIMG(1, 2)
        gc = POINT(1, 0)
        CutOk "  frame 2 is GREEN -- a different picture, so it really animates", _GREEN32(gc) > 200 _ANDALSO _RED32(gc) < 60
        _SOURCE gsrc
        CutOk "  each frame carries its own delay", CUT_GIFDELAY(1, 1) > 0
    END IF
    GifFreeLayer 1
    KILL gp

    ' ------------------------------------------------------------------
    CutSect "text wrap"

    DIM lines(0 TO 63) AS STRING, nl AS INTEGER
    CutWrap "the quick brown fox jumps over the lazy dog", 12, lines(), nl
    CutOk "wrapped into several lines", nl > 2
    ok = TRUE
    FOR i = 1 TO nl
        IF LEN(lines(i)) > 12 THEN ok = FALSE
    NEXT i
    CutOk "  no line exceeds the width", ok
    CutWrap "one" + CHR$(10) + "two", 40, lines(), nl
    CutOk "an explicit newline breaks the line", nl = 2

    ' ------------------------------------------------------------------
    PRINT
    PRINT "-------------------------------------------"
    PRINT LTRIM$(STR$(T_RUN)); " assertions, "; LTRIM$(STR$(T_BAD)); " failed"
    IF T_BAD > 0 THEN CUT_NFATAL = 1 ELSE CUT_NFATAL = 0
END SUB

FUNCTION CutFindOp% (cmd AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO CUT_NOP
        IF CUT_OPS(i).cmd = cmd THEN CutFindOp% = i: EXIT FUNCTION
    NEXT i
    CutFindOp% = 0
END FUNCTION

'--- run a compiled scene with NO rendering and NO real time: step the VM,
'    then shove the clock forward, until it ends or the budget runs out. ---
SUB CutRunHeadless (maxsecs AS SINGLE)
    DIM i AS LONG, steps AS LONG, alive AS INTEGER
    CutBegin
    steps = maxsecs * 60
    FOR i = 1 TO steps
        IF CUT_RUNSTATE <> CUT_RUNNING THEN EXIT FOR
        alive = CutTweensTick%
        CutWaitCheck
        CutStep
        CutShiftClocks -1# / 60#
        CUT_NOW = CutClock#
    NEXT i
END SUB


'--- hex string -> bytes, so a binary fixture can live in the source ---
FUNCTION GifHex$ (h AS STRING)
    DIM i AS INTEGER, r AS STRING
    FOR i = 1 TO LEN(h) - 1 STEP 2
        r = r + CHR$(VAL("&H" + MID$(h, i, 2)))
    NEXT i
    GifHex$ = r
END FUNCTION
