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
    CutOk "  the guarded body did NOT run", Cut_State#("flag.took_rich") = 0
    CutOk "  execution continued past the block", Cut_State#("flag.reached_end") = 1

    '--- ...and when it is TRUE, it must ---
    MOCK_N = 0
    MockSet "gold", 9999, "9999"
    CutOk "true-branch scene compiles", CutCompileText%(s)
    CutRunHeadless 5
    CutOk "  the guarded body ran", Cut_State#("flag.took_rich") = 1

    '--- else must be exclusive with the if body ---
    MOCK_N = 0
    MockSet "gold", 10, "10"
    s = "if gold > 1000" + CHR$(10) + "set rich 1" + CHR$(10)
    s = s + "else" + CHR$(10) + "set poor 1" + CHR$(10) + "end" + CHR$(10)
    CutOk "if/else compiles", CutCompileText%(s)
    CutRunHeadless 5
    CutOk "  else branch taken", Cut_State#("flag.poor") = 1
    CutOk "  if branch NOT taken", Cut_State#("flag.rich") = 0

    '--- elseif picks exactly one arm ---
    MOCK_N = 0
    MockSet "gold", 500, "500"
    s = "if gold > 1000" + CHR$(10) + "set a 1" + CHR$(10)
    s = s + "elseif gold > 100" + CHR$(10) + "set b 1" + CHR$(10)
    s = s + "else" + CHR$(10) + "set c 1" + CHR$(10) + "end" + CHR$(10)
    CutOk "if/elseif/else compiles", CutCompileText%(s)
    CutRunHeadless 5
    CutOk "  only the elseif arm ran", Cut_State#("flag.b") = 1
    CutOk "  the if arm did not", Cut_State#("flag.a") = 0
    CutOk "  the else arm did not", Cut_State#("flag.c") = 0

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
    CutOk "  gold granted then taken", Cut_State#("gold") = 200
    CutOk "  key granted", Cut_State#("key") = 1

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
    CutOk "  and execution continues past it", Cut_State#("flag.past_the_wait") = 1

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
