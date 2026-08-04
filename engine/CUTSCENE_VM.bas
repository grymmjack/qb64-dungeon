' ============================================================================
'  CUTVM.bas -- the step machine.
'
'  THE ONE IDEA IN THIS FILE
'  ------------------------
'  CutStep executes opcodes back to back until an op DECLARES A WAIT, then
'  returns. It never loops waiting for anything. The frame loop calls it once
'  per frame after advancing the tweens, so "wait for this pan to finish"
'  costs no special machinery: the pan is a tween, and the VM simply parks on
'  it.
'
'  That is what buys `async` for free. A blocking op and an async op run the
'  SAME code -- the only difference is whether the op also sets CUT_WAIT. So
'  there is no second code path to keep in sync, and no command that works
'  blocking but is subtly broken when made async.
'
'  THE RUNAWAY GUARD IS NOT OPTIONAL
'  --------------------------------
'      label spin
'      jump spin
'
'  ...is two legal lines that would spin CutStep forever inside one frame,
'  with no window update and no way to press anything -- the exact hang the
'  QB64 modal-error-dialog note in CLAUDE.md is about, arrived at from the
'  other direction. CUT_BUDGET bounds the ops executed per frame and reports a
'  real diagnostic instead.
' ============================================================================

CONST CUT_BUDGET = 4000

' ----------------------------------------------------------------------------
'  Easing. t comes in 0..1, comes out 0..1 (mostly -- back and bounce
'  deliberately leave the range, which is the whole point of them).
' ----------------------------------------------------------------------------
FUNCTION CutEase! (tt AS SINGLE, kind AS INTEGER)
    DIM t AS SINGLE, s AS SINGLE, n AS SINGLE
    t = tt
    IF t < 0 THEN t = 0
    IF t > 1 THEN t = 1

    SELECT CASE kind
        CASE EASE_LINEAR
            CutEase! = t
        CASE EASE_IN
            CutEase! = t * t
        CASE EASE_OUT
            CutEase! = 1 - (1 - t) * (1 - t)
        CASE EASE_INOUT
            IF t < 0.5 THEN
                CutEase! = 2 * t * t
            ELSE
                CutEase! = 1 - 2 * (1 - t) * (1 - t)
            END IF
        CASE EASE_INCUBIC
            CutEase! = t * t * t
        CASE EASE_OUTCUBIC
            s = 1 - t
            CutEase! = 1 - s * s * s
        CASE EASE_INOUTCUBIC
            IF t < 0.5 THEN
                CutEase! = 4 * t * t * t
            ELSE
                s = 1 - t
                CutEase! = 1 - 4 * s * s * s
            END IF
        CASE EASE_BACK
            '--- overshoots past the target and settles back: the little
            '    "snap" that makes a camera move read as deliberate. ---
            s = 1.70158
            n = t - 1
            CutEase! = n * n * ((s + 1) * n + s) + 1
        CASE EASE_BOUNCE
            CutEase! = CutBounce!(t)
        CASE ELSE
            CutEase! = t
    END SELECT
END FUNCTION

FUNCTION CutBounce! (tt AS SINGLE)
    DIM t AS SINGLE
    t = tt
    IF t < 0.363636 THEN
        CutBounce! = 7.5625 * t * t
    ELSEIF t < 0.727273 THEN
        t = t - 0.545454
        CutBounce! = 7.5625 * t * t + 0.75
    ELSEIF t < 0.909091 THEN
        t = t - 0.818182
        CutBounce! = 7.5625 * t * t + 0.9375
    ELSE
        t = t - 0.954545
        CutBounce! = 7.5625 * t * t + 0.984375
    END IF
END FUNCTION

' ----------------------------------------------------------------------------
'  Tweens
' ----------------------------------------------------------------------------
FUNCTION CutTweenStart% (what AS INTEGER, lay AS INTEGER, fromv AS SINGLE, tov AS SINGLE, dur AS SINGLE, ease AS INTEGER)
    DIM i AS INTEGER, slot AS INTEGER

    '--- a new tween on the same target REPLACES the old one. Two tweens
    '    fighting over one value is not a blend, it is whichever ran last
    '    winning by a frame -- a bug that looks like jitter. ---
    FOR i = 1 TO CUT_MAXTWEEN
        IF CUT_TWN(i).active THEN
            IF CUT_TWN(i).what = what THEN
                IF CUT_TWN(i).lay = lay THEN CUT_TWN(i).active = FALSE
            END IF
        END IF
    NEXT i

    slot = 0
    FOR i = 1 TO CUT_MAXTWEEN
        IF CUT_TWN(i).active = 0 THEN slot = i: EXIT FOR
    NEXT i
    IF slot = 0 THEN CutTweenStart% = 0: EXIT FUNCTION

    CUT_TWN(slot).active = TRUE
    CUT_TWN(slot).what = what
    CUT_TWN(slot).lay = lay
    CUT_TWN(slot).fromv = fromv
    CUT_TWN(slot).tov = tov
    CUT_TWN(slot).t0 = CUT_NOW
    CUT_TWN(slot).dur = dur
    CUT_TWN(slot).ease = ease
    CUT_TWN(slot).blocking = FALSE

    '--- a zero-length tween still runs for exactly one apply, so `at 0.5,0.5`
    '    and `move ... over 0` land on the value instead of being dropped. ---
    IF dur <= 0 THEN
        CUT_TWN(slot).dur = 0
        CutTweenApply slot, 1
        CUT_TWN(slot).active = FALSE
        CutTweenStart% = 0
        EXIT FUNCTION
    END IF

    CutTweenStart% = slot
END FUNCTION

SUB CutTweenApply (i AS INTEGER, prog AS SINGLE)
    DIM v AS SINGLE, e AS SINGLE, L AS INTEGER
    e = CutEase!(prog, CUT_TWN(i).ease)
    v = CUT_TWN(i).fromv + (CUT_TWN(i).tov - CUT_TWN(i).fromv) * e
    L = CUT_TWN(i).lay

    SELECT CASE CUT_TWN(i).what
        CASE TWN_CAMX: CUT_CAMX = v
        CASE TWN_CAMY: CUT_CAMY = v
        CASE TWN_CAMZ: CUT_CAMZ = v
        CASE TWN_SHAKE: CUT_SHAKEAMP = v
        CASE TWN_LAYALPHA
            IF L >= 1 THEN CUT_LAY(L).alpha = v
        CASE TWN_LAYX
            IF L >= 1 THEN CUT_LAY(L).x = v
        CASE TWN_LAYY
            IF L >= 1 THEN CUT_LAY(L).y = v
        CASE TWN_LAYSCALE
            IF L >= 1 THEN CUT_LAY(L).scale = v
    END SELECT
END SUB

'--- advance every tween one frame; returns how many are still running ---
FUNCTION CutTweensTick% ()
    DIM i AS INTEGER, prog AS SINGLE, alive AS INTEGER
    FOR i = 1 TO CUT_MAXTWEEN
        IF CUT_TWN(i).active THEN
            prog = (CUT_NOW - CUT_TWN(i).t0) / CUT_TWN(i).dur
            IF prog >= 1 THEN
                CutTweenApply i, 1
                CUT_TWN(i).active = FALSE
            ELSE
                CutTweenApply i, prog
                alive = alive + 1
            END IF
        END IF
    NEXT i
    CutTweensTick% = alive
END FUNCTION

SUB CutTweensStopAll (jumptoend AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO CUT_MAXTWEEN
        IF CUT_TWN(i).active THEN
            '--- skipping must LAND the tween, not abandon it half way: a
            '    skipped scene should leave the picture where the author said
            '    it ends up, so whatever follows sees a finished state. ---
            IF jumptoend THEN CutTweenApply i, 1
            CUT_TWN(i).active = FALSE
        END IF
    NEXT i
END SUB

FUNCTION CutTweenActive% (slot AS INTEGER)
    IF slot < 1 _ORELSE slot > CUT_MAXTWEEN THEN CutTweenActive% = FALSE: EXIT FUNCTION
    CutTweenActive% = CUT_TWN(slot).active
END FUNCTION

' ----------------------------------------------------------------------------
'  Conditions.
'
'  Evaluated from the stored text. See the header note in CUTPARSE.bas for
'  why. Grammar:
'
'      cond  := term { (and|or) term }
'      term  := [not] key [ op value ]
'      op    := == != = <> < <= > >=
'
'  A bare `key` is true when non-zero. A non-numeric value compares as a
'  STRING against Game_CutStateStr$, which is what makes `class == wizard` work
'  without the author quoting anything.
'
'  Chains evaluate strictly LEFT TO RIGHT with no precedence: `a and b or chcode`
'  is `(a and b) or chcode`. Precedence without parentheses would be a trap, and
'  parentheses are more language than this needs.
' ----------------------------------------------------------------------------
FUNCTION CutCondEval% (cond AS STRING)
    DIM res AS INTEGER
    res = CutCondRun%(cond, FALSE)
    CutCondEval% = res
END FUNCTION

SUB CutCondCheck (cond AS STRING, ln AS INTEGER)
    DIM r AS INTEGER
    CUT_CONDLN = ln
    r = CutCondRun%(cond, TRUE)
    CUT_CONDLN = 0
END SUB

FUNCTION CutCondRun% (cond AS STRING, validate AS INTEGER)
    DIM ct(0 TO 63) AS STRING
    DIM n AS INTEGER, i AS INTEGER
    DIM acc AS INTEGER, term AS INTEGER, joiner AS STRING
    DIM k AS STRING, o AS STRING, v AS STRING, neg AS INTEGER

    n = CutCondSplit%(cond, ct())
    IF n = 0 THEN
        IF validate THEN CutErrAdd 2, CUT_CONDLN, "empty condition"
        CutCondRun% = FALSE
        EXIT FUNCTION
    END IF

    acc = FALSE
    joiner = ""
    i = 1
    DO WHILE i <= n
        neg = FALSE
        IF LCASE$(ct(i)) = "not" THEN
            neg = TRUE
            i = i + 1
        END IF
        IF i > n THEN
            IF validate THEN CutErrAdd 2, CUT_CONDLN, "condition ends after 'not'"
            EXIT DO
        END IF

        k = ct(i)
        o = ""
        v = ""
        IF i + 1 <= n THEN
            IF CutIsCmpOp%(ct(i + 1)) THEN
                o = ct(i + 1)
                IF i + 2 > n THEN
                    IF validate THEN CutErrAdd 2, CUT_CONDLN, "'" + o + "' with nothing to compare to"
                    EXIT DO
                END IF
                v = ct(i + 2)
                i = i + 2
            END IF
        END IF

        IF validate THEN
            term = FALSE
        ELSE
            term = CutCondTerm%(k, o, v)
            IF neg THEN term = NOT term
        END IF

        IF LEN(joiner) = 0 THEN
            acc = term
        ELSEIF joiner = "and" THEN
            IF acc THEN
                IF term THEN acc = TRUE ELSE acc = FALSE
            ELSE
                acc = FALSE
            END IF
        ELSE
            IF acc THEN acc = TRUE ELSE acc = term
        END IF

        i = i + 1
        joiner = ""
        IF i <= n THEN
            joiner = LCASE$(ct(i))
            IF joiner <> "and" THEN
                IF joiner <> "or" THEN
                    IF validate THEN CutErrAdd 2, CUT_CONDLN, "expected 'and' or 'or', got '" + ct(i) + "'"
                    EXIT DO
                END IF
            END IF
            i = i + 1
            IF i > n THEN
                IF validate THEN CutErrAdd 2, CUT_CONDLN, "condition ends after '" + joiner + "'"
                EXIT DO
            END IF
        END IF
    LOOP

    CutCondRun% = acc
END FUNCTION

FUNCTION CutIsCmpOp% (s AS STRING)
    SELECT CASE s
        CASE "==", "!=", "=", "<>", "<", "<=", ">", ">=": CutIsCmpOp% = TRUE
        CASE ELSE: CutIsCmpOp% = FALSE
    END SELECT
END FUNCTION

'--- one comparison. Numeric when the right side looks numeric, string
'    otherwise; a bare key is a truth test. ---
FUNCTION CutCondTerm% (k AS STRING, o AS STRING, v AS STRING)
    DIM lhsn AS DOUBLE, rhsn AS DOUBLE, lhss AS STRING, rhss AS STRING
    DIM r AS INTEGER

    IF LEN(o) = 0 THEN
        IF Game_CutState#(k) <> 0 THEN CutCondTerm% = TRUE ELSE CutCondTerm% = FALSE
        EXIT FUNCTION
    END IF

    IF CutIsNum%(v) THEN
        lhsn = Game_CutState#(k)
        rhsn = VAL(v)
        SELECT CASE o
            CASE "==", "=": r = (lhsn = rhsn)
            CASE "!=", "<>": r = (lhsn <> rhsn)
            CASE "<": r = (lhsn < rhsn)
            CASE "<=": r = (lhsn <= rhsn)
            CASE ">": r = (lhsn > rhsn)
            CASE ">=": r = (lhsn >= rhsn)
        END SELECT
    ELSE
        lhss = LCASE$(_TRIM$(Game_CutStateStr$(k)))
        rhss = LCASE$(_TRIM$(v))
        SELECT CASE o
            CASE "==", "=": r = (lhss = rhss)
            CASE "!=", "<>": r = (lhss <> rhss)
            CASE "<": r = (lhss < rhss)
            CASE "<=": r = (lhss <= rhss)
            CASE ">": r = (lhss > rhss)
            CASE ">=": r = (lhss >= rhss)
        END SELECT
    END IF

    CutCondTerm% = r
END FUNCTION

'--- a private splitter: CutTokenize writes shared parser state, and a
'    condition is checked from INSIDE the compile loop, which would clobber
'    the line being compiled. ---
FUNCTION CutCondSplit% (cond AS STRING, ct() AS STRING)
    DIM i AS INTEGER, chcode AS INTEGER, cur AS STRING, n AS INTEGER, inq AS INTEGER

    FOR i = 1 TO LEN(cond)
        chcode = ASC(cond, i)

        IF inq THEN
            IF chcode = 34 THEN
                inq = FALSE
                IF n < 63 THEN n = n + 1: ct(n) = cur
                cur = ""
            ELSE
                cur = cur + CHR$(chcode)
            END IF
            _CONTINUE
        END IF

        IF chcode = 34 THEN
            IF LEN(cur) > 0 THEN
                IF n < 63 THEN n = n + 1: ct(n) = cur
                cur = ""
            END IF
            inq = TRUE
            _CONTINUE
        END IF

        IF chcode = 32 _ORELSE chcode = 9 THEN
            IF LEN(cur) > 0 THEN
                IF n < 63 THEN n = n + 1: ct(n) = cur
                cur = ""
            END IF
            _CONTINUE
        END IF

        '--- operators glue to their neighbours as often as not (`gold>=100`),
        '    so they break out as their own tokens the way `=` does in the
        '    main tokeniser. ---
        IF chcode = 60 _ORELSE chcode = 62 _ORELSE chcode = 61 _ORELSE chcode = 33 THEN
            IF LEN(cur) > 0 THEN
                IF CutIsCmpChar%(ASC(cur, LEN(cur))) = 0 THEN
                    IF n < 63 THEN n = n + 1: ct(n) = cur
                    cur = ""
                END IF
            END IF
            cur = cur + CHR$(chcode)
            _CONTINUE
        END IF

        IF LEN(cur) > 0 THEN
            IF CutIsCmpChar%(ASC(cur, LEN(cur))) THEN
                IF n < 63 THEN n = n + 1: ct(n) = cur
                cur = ""
            END IF
        END IF
        cur = cur + CHR$(chcode)
    NEXT i

    IF LEN(cur) > 0 THEN
        IF n < 63 THEN n = n + 1: ct(n) = cur
    END IF
    CutCondSplit% = n
END FUNCTION

FUNCTION CutIsCmpChar% (chcode AS INTEGER)
    IF chcode = 60 _ORELSE chcode = 62 _ORELSE chcode = 61 _ORELSE chcode = 33 THEN
        CutIsCmpChar% = TRUE
    ELSE
        CutIsCmpChar% = FALSE
    END IF
END FUNCTION

' ----------------------------------------------------------------------------
'  Layers
' ----------------------------------------------------------------------------
FUNCTION CutLayerFind% (nm AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO CUT_MAXLAYER
        IF CUT_LAY(i).used THEN
            IF LCASE$(_TRIM$(CUT_LAY(i).nm)) = LCASE$(_TRIM$(nm)) THEN
                CutLayerFind% = i
                EXIT FUNCTION
            END IF
        END IF
    NEXT i
    CutLayerFind% = 0
END FUNCTION

'--- find or create. New layers stack in declaration order, which is the
'    least surprising default: the first thing you `show` is the backdrop. ---
FUNCTION CutLayerGet% (nm AS STRING)
    DIM i AS INTEGER, f AS INTEGER, maxz AS INTEGER
    f = CutLayerFind%(nm)
    IF f > 0 THEN CutLayerGet% = f: EXIT FUNCTION

    FOR i = 1 TO CUT_MAXLAYER
        IF CUT_LAY(i).used THEN
            IF CUT_LAY(i).z > maxz THEN maxz = CUT_LAY(i).z
        END IF
    NEXT i

    FOR i = 1 TO CUT_MAXLAYER
        IF CUT_LAY(i).used = 0 THEN
            CUT_LAY(i).used = TRUE
            CUT_LAY(i).nm = nm
            CUT_LAY(i).src = 0
            CUT_LAY(i).work = 0
            CUT_LAY(i).workstep = -1
            CUT_LAY(i).x = 0.5
            CUT_LAY(i).y = 0.5
            CUT_LAY(i).scale = 1
            CUT_LAY(i).alpha = 1
            CUT_LAY(i).parallax = 1
            CUT_LAY(i).z = maxz + 1
            CUT_LAY(i).isanim = FALSE
            CUT_LAY(i).nframes = 0
            CUT_LAY(i).frame = 1
            CUT_LAY(i).adone = FALSE
            CutLayerGet% = i
            EXIT FUNCTION
        END IF
    NEXT i

    CutErrAdd 1, 0, "out of layers (max" + STR$(CUT_MAXLAYER) + "); '" + nm + "' ignored"
    CutLayerGet% = 0
END FUNCTION

SUB CutLayerFree (i AS INTEGER)
    IF i < 1 THEN EXIT SUB
    IF CUT_LAY(i).src > 0 THEN _FREEIMAGE CUT_LAY(i).src
    IF CUT_LAY(i).work > 0 THEN _FREEIMAGE CUT_LAY(i).work
    CUT_LAY(i).src = 0
    CUT_LAY(i).work = 0
    CUT_LAY(i).workstep = -1
    CUT_LAY(i).used = FALSE
    CUT_LAY(i).isanim = FALSE
END SUB

SUB CutLayersFreeAll
    DIM i AS INTEGER
    FOR i = 1 TO CUT_MAXLAYER
        CutLayerFree i
    NEXT i
END SUB
