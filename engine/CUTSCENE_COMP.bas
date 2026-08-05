' ============================================================================
'  CUTCOMP.bas -- the command table: one .cut source line -> one or more ops.
'
'  This is the whole surface of the language. If a command is not in the
'  SELECT CASE below, it does not exist -- and it reports itself as unknown at
'  compile time rather than being quietly ignored, which is the failure mode
'  every data format in this repo has been bitten by at least once (an
'  unplaced SETTINGS id simply does not draw; a missing dev-console CASE parses
'  as a label and never runs). An unknown command here is a hard error.
' ============================================================================

'--- `var name = value`. Stored verbatim; the QUOTED-ness is stored too, so
'    `var f$ = "alagard.ttf"` substitutes back in as a quoted token and still
'    reads as a filename rather than a keyword. ---
SUB CutVarSet (nm AS STRING, vv AS STRING, wasq AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO CUT_NVAR
        IF UCASE$(_TRIM$(CUT_VARNAME(i))) = UCASE$(_TRIM$(nm)) THEN
            CUT_VARVAL(i) = vv: CUT_VARQ(i) = wasq
            EXIT SUB
        END IF
    NEXT i
    IF CUT_NVAR >= CUT_MAXVAR THEN EXIT SUB
    CUT_NVAR = CUT_NVAR + 1
    REDIM _PRESERVE CUT_VARVAL(1 TO CUT_MAXVAR) AS STRING
    CUT_VARNAME(CUT_NVAR) = nm
    CUT_VARVAL(CUT_NVAR) = vv
    CUT_VARQ(CUT_NVAR) = wasq
END SUB

'--- replace any UNQUOTED token that is a declared variable. Runs on every
'    line after tokenising, so `font say myfont$ mysize` becomes
'    `font say "alagard.ttf" 24` before the command table ever sees it.
'
'    Quoted tokens are left alone: text is text, and a line of dialogue that
'    happens to contain a variable's name is dialogue. ---
SUB CutVarSubst
    DIM i AS INTEGER, j AS INTEGER
    FOR i = 1 TO CUT_NTK
        IF CUT_TKQ(i) THEN _CONTINUE
        FOR j = 1 TO CUT_NVAR
            IF UCASE$(CUT_TK(i)) = UCASE$(_TRIM$(CUT_VARNAME(j))) THEN
                CUT_TK(i) = CUT_VARVAL(j)
                CUT_TKQ(i) = CUT_VARQ(j)
                EXIT FOR
            END IF
        NEXT j
    NEXT i
END SUB

FUNCTION CutStyleCode% (nm AS STRING)
    SELECT CASE LCASE$(_TRIM$(nm))
        CASE "say", "text", "dialogue": CutStyleCode% = STY_SAY
        CASE "speaker", "name": CutStyleCode% = STY_SPEAKER
        CASE "title": CutStyleCode% = STY_TITLE
        CASE "sub", "subtitle": CutStyleCode% = STY_SUB
        CASE "crawl": CutStyleCode% = STY_CRAWL
        CASE "caption": CutStyleCode% = STY_CAPTION
        CASE "choice", "menu": CutStyleCode% = STY_CHOICE
        CASE "all", "": CutStyleCode% = -1          ' the whole-scene value
        CASE ELSE: CutStyleCode% = -2               ' not a style name
    END SELECT
END FUNCTION

'--- a per-LINE `color`/`font` override, which sets this op only and leaves the
'    sticky values alone ---
SUB CutLineStyleMods (op AS INTEGER, startat AS INTEGER, ln AS INTEGER)
    DIM t AS INTEGER, q AS INTEGER, fil AS STRING
    t = CutKw%("color", startat)
    IF t >= 0 THEN CUT_OPS(op).s3 = CutStr&(CutTok$(t + 1))
    t = CutKw%("font", startat)
    IF t >= 0 THEN
        fil = CutTok$(t + 1)
        CUT_OPS(op).fonth = CutFontGet&(fil, CINT(CutNum!(CutTok$(t + 2))))
        IF CUT_OPS(op).fonth = 0 THEN CutErrAdd 1, ln, "font not found: " + fil
    END IF
END SUB

FUNCTION CutJoinFrom$ (startat AS INTEGER)
    DIM i AS INTEGER, s AS STRING
    FOR i = startat TO CUT_NTK
        IF LEN(s) > 0 THEN s = s + " "
        IF CUT_TKQ(i) THEN
            s = s + CHR$(34) + CUT_TK(i) + CHR$(34)
        ELSE
            s = s + CUT_TK(i)
        END IF
    NEXT i
    CutJoinFrom$ = s
END FUNCTION

'--- the first QUOTED token at or after `startat` (the text of a say/title/
'    caption), so an author can put modifiers before or after the string. ---
FUNCTION CutFirstQuoted$ (startat AS INTEGER, foundat AS INTEGER)
    DIM i AS INTEGER
    FOR i = startat TO CUT_NTK
        IF CUT_TKQ(i) THEN
            foundat = i
            CutFirstQuoted$ = CUT_TK(i)
            EXIT FUNCTION
        END IF
    NEXT i
    foundat = -1
    CutFirstQuoted$ = ""
END FUNCTION

' ----------------------------------------------------------------------------
'  CutCompile -- read a .cut and fill CUT_OPS().
'  Returns TRUE when the scene is runnable (no severity-2 diagnostics).
' ----------------------------------------------------------------------------
FUNCTION CutCompile% (path AS STRING)
    DIM i AS INTEGER, ln AS INTEGER, cmd AS STRING, isasync AS INTEGER
    DIM a1 AS INTEGER, op AS INTEGER, j AS INTEGER, k AS INTEGER
    DIM t AS STRING, txt AS STRING, who AS STRING, qat AS INTEGER
    DIM nm AS STRING, sec AS SINGLE, ez AS INTEGER, dr AS INTEGER
    DIM px AS SINGLE, py AS SINGLE
    DIM body AS STRING, tgt AS INTEGER

    CutResetProgram
    CUT_FILE = path
    CUT_NAME = CutSceneNameFromPath$(path)

    CutLoadSource path, 0
    IF CUT_NFATAL > 0 THEN CutCompile% = FALSE: EXIT FUNCTION

    FOR i = 1 TO CUT_NSRC
        ln = CUT_SRCLN(i)
        CutTokenize CUT_SRC(i)
        IF CUT_NTK = 0 THEN _CONTINUE
        CutVarSubst

        '--- `async <cmd>` is a prefix, not a command: strip it and shift. ---
        isasync = FALSE
        IF CutTokL$(1) = "async" THEN
            isasync = TRUE
            CutShiftTokens
            IF CUT_NTK = 0 THEN
                CutErrAdd 2, ln, "async with no command"
                _CONTINUE
            END IF
        END IF

        cmd = CutTokL$(1)
        a1 = 2

        '--- `name:` at the start of a line is a label, the same shorthand
        '    BASIC itself uses. ---
        IF RIGHT$(cmd, 1) = ":" THEN
            IF CUT_NTK = 1 THEN
                CutAddLabel LEFT$(CutTok$(1), LEN(cmd) - 1), CUT_NOP + 1, ln
                _CONTINUE
            END IF
        END IF

        SELECT CASE cmd

            ' ---------------- meta ----------------
            CASE "scene"
                CUT_NAME = CutTok$(2)
                IF LEN(CUT_NAME) = 0 THEN CutErrAdd 1, ln, "scene needs a name"

            CASE "noskip"
                CUT_NOSKIP = TRUE

            CASE "var"
                '--- `var name = value` / `var name value` ---
                nm = CutTok$(2)
                IF LEN(nm) = 0 THEN
                    CutErrAdd 2, ln, "var needs a name"
                ELSE
                    tgt = CutKw%("=", 2)
                    IF tgt < 0 THEN tgt = 2
                    CutVarSet nm, CutTok$(tgt + 1), CUT_TKQ(tgt + 1)
                END IF

            CASE "font"
                '--- `font "<file>" <size>`  (whole scene, sticky)
                '    `font <style> "<file>" <size>`  (that kind of text) ---
                IF CUT_TKQ(2) THEN
                    k = -1
                    tgt = 2
                ELSE
                    k = CutStyleCode%(CutTok$(2))
                    tgt = 3
                    IF k = -2 THEN
                        CutErrAdd 2, ln, "unknown text style '" + CutTok$(2) + "' (say/speaker/title/sub/crawl/caption/choice/all)"
                        k = -1
                    END IF
                END IF
                nm = CutTok$(tgt)
                IF LEN(nm) = 0 THEN
                    CutErrAdd 2, ln, "font needs: font [<style>] " + CHR$(34) + "<file>" + CHR$(34) + " <size>"
                ELSE
                    op = CutEmit%(OP_STYLE, CUT_NOSTR, CUT_NOSTR, k, 1, 0, 0, ln, FALSE)
                    CUT_OPS(op).fonth = CutFontGet&(nm, CINT(CutNum!(CutTok$(tgt + 1))))
                    IF CUT_OPS(op).fonth = 0 THEN CutErrAdd 1, ln, "font not found: " + nm
                END IF

            CASE "color", "colour"
                '--- `color <colour>` (whole scene) / `color <style> <colour>` ---
                k = CutStyleCode%(CutTok$(2))
                IF k = -2 _ORELSE CUT_NTK < 3 THEN
                    k = -1
                    nm = CutTok$(2)
                ELSE
                    nm = CutTok$(3)
                END IF
                IF LEN(nm) = 0 THEN
                    CutErrAdd 2, ln, "color needs a colour name or #RRGGBB"
                ELSE
                    op = CutEmit%(OP_STYLE, CutStr&(nm), CUT_NOSTR, k, 0, 1, 0, ln, FALSE)
                END IF

            CASE "storybook"
                '--- how this scene presents itself in the Storybook. Optional:
                '    without it the screen falls back to the scene's own name,
                '    so an unlabelled scene still lists rather than vanishing. ---
                CUT_SBTITLE = CutFirstQuoted$(2, qat)
                IF qat > 0 THEN CUT_SBBLURB = CutFirstQuoted$(qat + 1, j)

            CASE "stage"
                CUT_STAGEW = CutNum!(CutTok$(2))
                CUT_STAGEH = CutNum!(CutTok$(3))
                IF CUT_STAGEW < CUT_PXW THEN
                    CutErrAdd 1, ln, "stage narrower than the screen; widened to" + STR$(CUT_PXW)
                    CUT_STAGEW = CUT_PXW
                END IF
                IF CUT_STAGEH < CUT_PXH THEN
                    CutErrAdd 1, ln, "stage shorter than the screen; heightened to" + STR$(CUT_PXH)
                    CUT_STAGEH = CUT_PXH
                END IF

            ' ---------------- layers & art ----------------
            CASE "show"
                nm = CutTok$(2)
                txt = CutFirstQuoted$(3, qat)
                IF LEN(nm) = 0 _ORELSE LEN(txt) = 0 THEN
                    CutErrAdd 2, ln, "show needs: show <layer> " + CHR$(34) + "<path>" + CHR$(34)
                ELSE
                    op = CutEmit%(OP_SHOW, CutStr&(nm), CutStr&(txt), CutKwNum!("fade", 3, 0), 0, 0, 0, ln, isasync)
                    CutEmitLayerMods nm, 3, ln
                END IF

            CASE "hide"
                nm = CutTok$(2)
                IF LEN(nm) = 0 THEN
                    CutErrAdd 2, ln, "hide needs a layer name"
                ELSE
                    op = CutEmit%(OP_HIDE, CutStr&(nm), CUT_NOSTR, CutKwNum!("fade", 3, 0), 0, 0, 0, ln, isasync)
                END IF

            CASE "clear"
                op = CutEmit%(OP_CLEARLAY, CUT_NOSTR, CUT_NOSTR, 0, 0, 0, 0, ln, isasync)

            CASE "anim"
                nm = CutTok$(2)
                txt = CutFirstQuoted$(3, qat)
                IF LEN(nm) = 0 _ORELSE LEN(txt) = 0 THEN
                    CutErrAdd 2, ln, "anim needs: anim <layer> " + CHR$(34) + "<base>" + CHR$(34) + " frames <n> fps <f>"
                ELSE
                    k = AM_LOOP
                    IF CutHasKw%("once", 3) THEN k = AM_ONCE
                    IF CutHasKw%("pingpong", 3) THEN k = AM_PINGPONG
                    '--- `frames` is OPTIONAL: with no count the runtime probes
                    '    until a frame is missing, so adding a frame to an
                    '    animation is dropping a file in and nothing else. ---
                    j = CutKwNum!("frames", 3, 0)
                    op = CutEmit%(OP_ANIM, CutStr&(nm), CutStr&(txt), j, CutKwNum!("fps", 3, 12), k, CutKwNum!("fade", 3, 0), ln, isasync)
                    '--- `ext ans` plays a sequence of full ANSI files. Each is
                    '    rendered through ANSI_Print once as it is loaded, so
                    '    from then on the camera treats a frame of ANSI exactly
                    '    like a frame of bitmap. ---
                    CUT_OPS(op).s3 = CutStr&(CutKwStr$("ext", 3, "png"))
                    CutEmitLayerMods nm, 3, ln
                END IF

            CASE "move"
                '--- move <layer> to <x>,<y> over <t> [ease <e>] ---
                nm = CutTok$(2)
                tgt = CutKw%("to", 3)
                IF LEN(nm) = 0 _ORELSE tgt < 0 THEN
                    CutErrAdd 2, ln, "move needs: move <layer> to <x>,<y> over <t>"
                ELSE
                    sec = CutKwNum!("over", 3, 0)
                    ez = CutEaseOr%(CutKwStr$("ease", 3, "inout"), ln)
                    op = CutEmit%(OP_LAYSET, CutStr&(nm), CUT_NOSTR, LS_X, CutNum!(CutTok$(tgt + 1)), sec, ez, ln, isasync)
                    op = CutEmit%(OP_LAYSET, CutStr&(nm), CUT_NOSTR, LS_Y, CutNum!(CutTok$(tgt + 2)), sec, ez, ln, TRUE)
                END IF

            CASE "fadelayer", "opacity"
                nm = CutTok$(2)
                tgt = CutKw%("to", 3)
                IF LEN(nm) = 0 _ORELSE tgt < 0 THEN
                    CutErrAdd 2, ln, "fadelayer needs: fadelayer <layer> to <0..1> over <t>"
                ELSE
                    op = CutEmit%(OP_LAYSET, CutStr&(nm), CUT_NOSTR, LS_ALPHA, CutNum!(CutTok$(tgt + 1)), CutKwNum!("over", 3, 0), CutEaseOr%(CutKwStr$("ease", 3, "linear"), ln), ln, isasync)
                END IF

            CASE "grow", "rescale"
                nm = CutTok$(2)
                tgt = CutKw%("to", 3)
                IF LEN(nm) = 0 _ORELSE tgt < 0 THEN
                    CutErrAdd 2, ln, "grow needs: grow <layer> to <scale> over <t>"
                ELSE
                    op = CutEmit%(OP_LAYSET, CutStr&(nm), CUT_NOSTR, LS_SCALE, CutNum!(CutTok$(tgt + 1)), CutKwNum!("over", 3, 0), CutEaseOr%(CutKwStr$("ease", 3, "inout"), ln), ln, isasync)
                END IF

            ' ---------------- camera ----------------
            CASE "pan"
                tgt = CutKw%("to", 2)
                IF tgt < 0 THEN
                    CutErrAdd 2, ln, "pan needs: pan to <x>,<y> over <t>"
                ELSE
                    op = CutEmit%(OP_PAN, CUT_NOSTR, CUT_NOSTR, CutNum!(CutTok$(tgt + 1)), CutNum!(CutTok$(tgt + 2)), CutKwNum!("over", 2, 1), CutEaseOr%(CutKwStr$("ease", 2, "inout"), ln), ln, isasync)
                END IF

            CASE "zoom"
                tgt = CutKw%("to", 2)
                IF tgt < 0 THEN
                    CutErrAdd 2, ln, "zoom needs: zoom to <factor> over <t>"
                ELSE
                    sec = CutNum!(CutTok$(tgt + 1))
                    IF sec <= 0 THEN CutErrAdd 2, ln, "zoom factor must be > 0"
                    op = CutEmit%(OP_ZOOM, CUT_NOSTR, CUT_NOSTR, sec, CutKwNum!("over", 2, 1), CutEaseOr%(CutKwStr$("ease", 2, "inout"), ln), 0, ln, isasync)
                END IF

            CASE "cam"
                op = CutEmit%(OP_CAMSET, CUT_NOSTR, CUT_NOSTR, CutNum!(CutTok$(2)), CutNum!(CutTok$(3)), CutKwNum!("zoom", 2, 1), 0, ln, isasync)

            CASE "shake"
                op = CutEmit%(OP_SHAKE, CUT_NOSTR, CUT_NOSTR, CutNum!(CutTok$(2)), CutKwNum!("for", 2, 0.4), 0, 0, ln, isasync)

            ' ---------------- transitions ----------------
            CASE "cut"
                op = CutEmit%(OP_TRANS, CUT_NOSTR, CUT_NOSTR, TR_CUT, 0, 0, 0, ln, isasync)
                CutTransTarget op, 2, ln

            CASE "fade"
                '--- fade to black over 1.0 | fade from black over 1.0 ---
                t = CutTokL$(2)
                nm = CutTok$(3)
                sec = CutKwNum!("over", 2, 1)
                IF t = "from" THEN
                    op = CutEmit%(OP_TRANS, CutStr&(nm), CUT_NOSTR, TR_FADE, sec, 1, 0, ln, isasync)
                ELSEIF t = "to" THEN
                    op = CutEmit%(OP_TRANS, CutStr&(nm), CUT_NOSTR, TR_FADE, sec, 0, 0, ln, isasync)
                ELSE
                    CutErrAdd 2, ln, "fade needs: fade to|from <colour> over <t>"
                END IF

            CASE "dissolve"
                op = CutEmit%(OP_TRANS, CUT_NOSTR, CUT_NOSTR, TR_DISSOLVE, CutKwNum!("over", 2, 1), 0, 0, ln, isasync)
                CutTransTarget op, 2, ln

            CASE "wipe", "push"
                dr = CutDirCode%(CutKwStr$("dir", 2, "left"))
                IF dr < 0 THEN
                    CutErrAdd 2, ln, "unknown direction '" + CutKwStr$("dir", 2, "") + "' (left/right/up/down)"
                    dr = DIR_L
                END IF
                IF cmd = "wipe" THEN k = TR_WIPE ELSE k = TR_PUSH
                op = CutEmit%(OP_TRANS, CUT_NOSTR, CUT_NOSTR, k, CutKwNum!("over", 2, 0.8), dr, 0, ln, isasync)
                CutTransTarget op, 2, ln

            CASE "split"
                op = CutEmit%(OP_TRANS, CUT_NOSTR, CUT_NOSTR, TR_SPLIT, CutKwNum!("over", 2, 0.9), 0, 0, ln, isasync)
                CutTransTarget op, 2, ln

            CASE "iris"
                '--- NOTE: a single-line IF cannot carry an ELSEIF chain in
                '    QB64 (see CLAUDE.md); this has to be a block IF. ---
                t = CutTokL$(2)
                tgt = CutKw%("at", 2)
                IF tgt < 0 THEN
                    px = 0.5
                    py = 0.5
                ELSE
                    px = CutNum!(CutTok$(tgt + 1))
                    py = CutNum!(CutTok$(tgt + 2))
                END IF
                IF t = "in" THEN
                    k = TR_IRISIN
                ELSEIF t = "out" THEN
                    k = TR_IRISOUT
                ELSE
                    CutErrAdd 2, ln, "iris needs: iris in|out [at <x>,<y>] over <t>"
                    k = TR_IRISOUT
                END IF
                op = CutEmit%(OP_TRANS, CUT_NOSTR, CUT_NOSTR, k, CutKwNum!("over", 2, 1), px, py, ln, isasync)
                CutTransTarget op, 2, ln

            CASE "scatter"
                op = CutEmit%(OP_TRANS, CUT_NOSTR, CUT_NOSTR, TR_SCATTER, CutKwNum!("over", 2, 1), 0, 0, ln, isasync)
                CutTransTarget op, 2, ln
            CASE "scan"
                op = CutEmit%(OP_TRANS, CUT_NOSTR, CUT_NOSTR, TR_SCAN, CutKwNum!("over", 2, 0.8), 0, 0, ln, isasync)
                CutTransTarget op, 2, ln
            CASE "static"
                op = CutEmit%(OP_TRANS, CUT_NOSTR, CUT_NOSTR, TR_STATIC, CutNum!(CutTok$(2)), 0, 0, ln, isasync)
            CASE "crtoff"
                op = CutEmit%(OP_TRANS, CUT_NOSTR, CUT_NOSTR, TR_CRTOFF, CutNum!(CutTok$(2)), 0, 0, ln, isasync)
                CutTransTarget op, 2, ln
            CASE "flash"
                nm = CutTok$(2)
                IF CutIsNum%(nm) THEN
                    op = CutEmit%(OP_TRANS, CutStr&("white"), CUT_NOSTR, TR_FLASH, CutNum!(nm), 0, 0, ln, isasync)
                ELSE
                    op = CutEmit%(OP_TRANS, CutStr&(nm), CUT_NOSTR, TR_FLASH, CutNum!(CutTok$(3)), 0, 0, ln, isasync)
                END IF

            ' ---------------- text ----------------
            CASE "say"
                txt = CutFirstQuoted$(2, qat)
                IF qat < 0 THEN
                    CutErrAdd 2, ln, "say needs quoted text"
                ELSE
                    who = ""
                    IF qat > 2 THEN
                        who = CutTok$(2)
                        IF RIGHT$(who, 1) = ":" THEN who = LEFT$(who, LEN(who) - 1)
                    END IF
                    op = CutEmit%(OP_SAY, CutStr&(txt), CutStr&(who), CutKwNum!("for", qat + 1, 0), 0, 0, 0, ln, isasync)
                    CutLineStyleMods op, qat + 1, ln
                END IF

            CASE "portrait"
                txt = CutFirstQuoted$(2, qat)
                IF qat < 0 THEN
                    op = CutEmit%(OP_PORTRAIT, CUT_NOSTR, CUT_NOSTR, 0, 0, 0, 0, ln, isasync)
                ELSE
                    k = 0
                    IF CutHasKw%("right", 2) THEN k = 1
                    op = CutEmit%(OP_PORTRAIT, CutStr&(txt), CUT_NOSTR, k, 0, 0, 0, ln, isasync)
                END IF

            CASE "title"
                txt = CutFirstQuoted$(2, qat)
                IF qat < 0 THEN
                    CutErrAdd 2, ln, "title needs quoted text"
                ELSE
                    body = CutFirstQuoted$(qat + 1, j)
                    op = CutEmit%(OP_TITLE, CutStr&(txt), CutStr&(body), CutKwNum!("for", 2, 2.5), 0, 0, 0, ln, isasync)
                    CutLineStyleMods op, 2, ln
                END IF

            CASE "crawl"
                body = ""
                FOR j = 2 TO CUT_NTK
                    IF CUT_TKQ(j) THEN
                        IF LEN(body) > 0 THEN body = body + CHR$(10)
                        body = body + CUT_TK(j)
                    END IF
                NEXT j
                IF LEN(body) = 0 THEN
                    CutErrAdd 2, ln, "crawl needs at least one quoted line"
                ELSE
                    op = CutEmit%(OP_CRAWL, CutStr&(body), CUT_NOSTR, CutKwNum!("for", 2, 6), 0, 0, 0, ln, isasync)
                    CutLineStyleMods op, 2, ln
                END IF

            CASE "caption"
                txt = CutFirstQuoted$(2, qat)
                tgt = CutKw%("at", 2)
                IF qat < 0 _ORELSE tgt < 0 THEN
                    CutErrAdd 2, ln, "caption needs: caption " + CHR$(34) + "text" + CHR$(34) + " at <col>,<row>"
                ELSE
                    op = CutEmit%(OP_CAPTION, CutStr&(txt), CutStr&(CutKwStr$("color", 2, "")), CutNum!(CutTok$(tgt + 1)), CutNum!(CutTok$(tgt + 2)), CutAnchorCode%(CutKwStr$("anchor", 2, "l")), CutKwNum!("fade", 2, 0.3), ln, isasync)
                    CutLineStyleMods op, 2, ln
                    '--- `from <c>,<r> over <t> [ease <e>]` makes the caption
                    '    ARRIVE at `at` from somewhere else: text that falls in,
                    '    slides on, or drops off the top of the screen. ---
                    j = CutKw%("from", 2)
                    IF j >= 0 THEN
                        CUT_OPS(op).s3 = CutStr&(CutTok$(j + 1) + "," + CutTok$(j + 2) + "," + _
                            _TRIM$(STR$(CutKwNum!("over", 2, 0.6))) + "," + _
                            _TRIM$(STR$(CutEaseOr%(CutKwStr$("ease", 2, "out"), ln))))
                    END IF
                END IF

            CASE "cleartext"
                op = CutEmit%(OP_CLEARTEXT, CUT_NOSTR, CUT_NOSTR, 0, 0, 0, 0, ln, isasync)

            ' ---------------- audio ----------------
            CASE "music"
                nm = CutFirstQuoted$(2, qat)
                IF qat < 0 THEN nm = CutTok$(2)
                IF LEN(nm) = 0 THEN
                    CutErrAdd 2, ln, "music needs a track name"
                ELSE
                    k = TRUE
                    IF CutHasKw%("once", 2) THEN k = FALSE
                    op = CutEmit%(OP_MUSIC, CutStr&(nm), CUT_NOSTR, CutKwNum!("fadein", 2, 0), k, 0, 0, ln, isasync)
                END IF

            CASE "musicstop"
                op = CutEmit%(OP_MUSICSTOP, CUT_NOSTR, CUT_NOSTR, CutKwNum!("fade", 2, 1), 0, 0, 0, ln, isasync)

            CASE "sfx"
                nm = CutFirstQuoted$(2, qat)
                IF qat < 0 THEN nm = CutTok$(2)
                IF LEN(nm) = 0 THEN
                    CutErrAdd 2, ln, "sfx needs a name"
                ELSE
                    op = CutEmit%(OP_SFX, CutStr&(nm), CUT_NOSTR, 0, 0, 0, 0, ln, isasync)
                END IF

            CASE "narrate"
                nm = CutFirstQuoted$(2, qat)
                IF qat < 0 THEN nm = CutTok$(2)
                IF LEN(nm) = 0 THEN
                    CutErrAdd 2, ln, "narrate needs a strings.txt key"
                ELSE
                    op = CutEmit%(OP_NARRATE, CutStr&(nm), CUT_NOSTR, 0, 0, 0, 0, ln, isasync)
                END IF

            CASE "cue"
                nm = CutFirstQuoted$(2, qat)
                IF qat < 0 THEN nm = CutTok$(2)
                op = CutEmit%(OP_CUE, CutStr&(nm), CUT_NOSTR, ABS(CutHasKw%("loop", 2)), 0, 0, 0, ln, isasync)

            ' ---------------- flow ----------------
            CASE "wait"
                op = CutEmit%(OP_WAIT, CUT_NOSTR, CUT_NOSTR, CutNum!(CutTok$(2)), 0, 0, 0, ln, isasync)

            CASE "waitall", "sync"
                op = CutEmit%(OP_WAITALL, CUT_NOSTR, CUT_NOSTR, 0, 0, 0, 0, ln, isasync)

            CASE "stopfx"
                op = CutEmit%(OP_STOPFX, CUT_NOSTR, CUT_NOSTR, 0, 0, 0, 0, ln, isasync)

            CASE "label"
                IF LEN(CutTok$(2)) = 0 THEN
                    CutErrAdd 2, ln, "label needs a name"
                ELSE
                    CutAddLabel CutTok$(2), CUT_NOP + 1, ln
                END IF

            CASE "jump", "goto"
                IF LEN(CutTok$(2)) = 0 THEN
                    CutErrAdd 2, ln, "jump needs a label"
                ELSE
                    op = CutEmit%(OP_JUMP, CUT_NOSTR, CutStr&(CutTok$(2)), 0, 0, 0, 0, ln, isasync)
                END IF

            CASE "stop"
                op = CutEmit%(OP_END, CUT_NOSTR, CUT_NOSTR, 0, 0, 0, 0, ln, isasync)

            CASE "if"
                body = CutJoinFrom$(2)
                IF LEN(body) = 0 THEN
                    CutErrAdd 2, ln, "if needs a condition"
                ELSE
                    CutCondCheck body, ln
                    op = CutEmit%(OP_IFGOTO, CutStr&(body), CUT_NOSTR, 0, 0, 0, 0, ln, FALSE)
                    CutPushNest op, ln
                END IF

            CASE "elseif"
                IF CUT_NEST < 1 THEN
                    CutErrAdd 2, ln, "elseif without if"
                ELSE
                    body = CutJoinFrom$(2)
                    CutCondCheck body, ln
                    op = CutEmit%(OP_JUMP, CUT_NOSTR, CUT_NOSTR, 0, 0, 0, 0, ln, FALSE)
                    CutAddEndFix op
                    CutPatchIf CUT_NOP + 1
                    op = CutEmit%(OP_IFGOTO, CutStr&(body), CUT_NOSTR, 0, 0, 0, 0, ln, FALSE)
                    CUT_FIXIF(CUT_NEST) = op
                END IF

            CASE "else"
                IF CUT_NEST < 1 THEN
                    CutErrAdd 2, ln, "else without if"
                ELSE
                    op = CutEmit%(OP_JUMP, CUT_NOSTR, CUT_NOSTR, 0, 0, 0, 0, ln, FALSE)
                    CutAddEndFix op
                    CutPatchIf CUT_NOP + 1
                    CUT_FIXIF(CUT_NEST) = -1
                END IF

            CASE "end", "endif", "endchoice"
                CutCloseBlock ln

            ' ---------------- game state ----------------
            CASE "set", "unset"
                nm = CutTok$(2)
                IF LEN(nm) = 0 THEN
                    CutErrAdd 2, ln, cmd + " needs a flag name"
                ELSE
                    IF cmd = "unset" THEN
                        sec = 0
                    ELSE
                        tgt = CutKw%("=", 2)
                        IF tgt >= 0 THEN
                            sec = CutNum!(CutTok$(tgt + 1))
                        ELSEIF CutIsNum%(CutTok$(3)) THEN
                            sec = CutNum!(CutTok$(3))
                        ELSE
                            sec = 1
                        END IF
                    END IF
                    op = CutEmit%(OP_SET, CutStr&(nm), CUT_NOSTR, sec, 0, 0, 0, ln, isasync)
                END IF

            CASE "grant", "take"
                nm = CutTokL$(2)
                IF LEN(nm) = 0 THEN
                    CutErrAdd 2, ln, cmd + " needs something to give (gold/hp/item/key)"
                ELSE
                    sec = CutNum!(CutTok$(3))
                    IF nm = "key" THEN sec = 1
                    IF nm = "item" THEN
                        op = CutEmit%(OP_GRANT, CutStr&("item:" + CutTok$(3)), CUT_NOSTR, 1, 0, 0, 0, ln, isasync)
                    ELSE
                        IF cmd = "take" THEN sec = -sec
                        op = CutEmit%(OP_GRANT, CutStr&(nm), CUT_NOSTR, sec, 0, 0, 0, ln, isasync)
                    END IF
                END IF

            CASE "choice"
                txt = CutFirstQuoted$(2, qat)
                op = CutEmit%(OP_CHOICE, CutStr&(txt), CUT_NOSTR, 0, 0, 0, 0, ln, FALSE)
                IF CUT_CHOP > 0 THEN CutErrAdd 2, ln, "choice inside choice"
                CUT_CHOP = op
                CUT_CHN = 0
                CutPushNest -1, ln

            CASE "option"
                txt = CutFirstQuoted$(2, qat)
                tgt = CutKw%("->", 2)
                IF tgt < 0 THEN tgt = CutKw%("goto", 2)
                IF tgt < 0 THEN tgt = CutKw%("jump", 2)
                IF CUT_CHOP < 1 THEN
                    CutErrAdd 2, ln, "option outside a choice block"
                ELSEIF qat < 0 _ORELSE tgt < 0 THEN
                    CutErrAdd 2, ln, "option needs: option " + CHR$(34) + "text" + CHR$(34) + " -> <label>"
                ELSEIF CUT_CHN >= CUT_MAXCHOICE THEN
                    CutErrAdd 2, ln, "at most" + STR$(CUT_MAXCHOICE) + " options per choice"
                ELSE
                    op = CutEmit%(OP_OPTION, CutStr&(txt), CutStr&(CutTok$(tgt + 1)), 0, 0, 0, 0, ln, FALSE)
                    CUT_CHN = CUT_CHN + 1
                END IF

            CASE ELSE
                CutErrAdd 2, ln, "unknown command '" + CutTok$(1) + "'"

        END SELECT
    NEXT i

    IF CUT_NEST > 0 THEN CutErrAdd 2, 0, "unclosed if/choice block (missing `end`)"

    '--- every scene ends, whether the author said so or not ---
    op = CutEmit%(OP_END, CUT_NOSTR, CUT_NOSTR, 0, 0, 0, 0, 0, FALSE)

    CutResolveLabels

    IF CUT_NFATAL > 0 THEN CutCompile% = FALSE ELSE CutCompile% = TRUE
END FUNCTION

' ----------------------------------------------------------------------------
'  Block bookkeeping
' ----------------------------------------------------------------------------
SUB CutPushNest (ifop AS INTEGER, ln AS INTEGER)
    IF CUT_NEST >= CUT_MAXNEST THEN
        CutErrAdd 2, ln, "blocks nested too deep"
        EXIT SUB
    END IF
    CUT_NEST = CUT_NEST + 1
    CUT_FIXIF(CUT_NEST) = ifop
    CUT_NFIXEND(CUT_NEST) = 0
END SUB

SUB CutAddEndFix (op AS INTEGER)
    IF CUT_NEST < 1 THEN EXIT SUB
    IF CUT_NFIXEND(CUT_NEST) > 15 THEN EXIT SUB
    CUT_FIXEND(CUT_NEST, CUT_NFIXEND(CUT_NEST)) = op
    CUT_NFIXEND(CUT_NEST) = CUT_NFIXEND(CUT_NEST) + 1
END SUB

'--- the pending OP_IFGOTO jumps HERE when its condition is false ---
SUB CutPatchIf (target AS INTEGER)
    IF CUT_NEST < 1 THEN EXIT SUB
    IF CUT_FIXIF(CUT_NEST) < 1 THEN EXIT SUB
    CUT_OPS(CUT_FIXIF(CUT_NEST)).n1 = target
END SUB

SUB CutCloseBlock (ln AS INTEGER)
    DIM j AS INTEGER, after AS INTEGER
    IF CUT_NEST < 1 THEN
        '--- `end` with nothing open ends the SCENE. Both spellings read
        '    naturally, and guessing wrong here would be worse than either. ---
        j = CutEmit%(OP_END, CUT_NOSTR, CUT_NOSTR, 0, 0, 0, 0, ln, FALSE)
        EXIT SUB
    END IF

    after = CUT_NOP + 1

    '--- closing a choice: the OP_CHOICE now knows how many options follow ---
    IF CUT_CHOP > 0 THEN
        IF CUT_FIXIF(CUT_NEST) = -1 THEN
            IF CUT_NFIXEND(CUT_NEST) = 0 THEN
                CUT_OPS(CUT_CHOP).n1 = CUT_CHN
                IF CUT_CHN = 0 THEN CutErrAdd 2, ln, "choice with no options"
                CUT_CHOP = 0
                CUT_NEST = CUT_NEST - 1
                EXIT SUB
            END IF
        END IF
    END IF

    CutPatchIf after
    FOR j = 0 TO CUT_NFIXEND(CUT_NEST) - 1
        CUT_OPS(CUT_FIXEND(CUT_NEST, j)).n1 = after
    NEXT j
    CUT_NEST = CUT_NEST - 1
END SUB

' ----------------------------------------------------------------------------
'  Fixups: jumps and options name a label that may not have been read yet.
' ----------------------------------------------------------------------------
SUB CutResolveLabels
    DIM i AS INTEGER, t AS INTEGER, nm AS STRING
    FOR i = 1 TO CUT_NOP
        IF CUT_OPS(i).cmd = OP_JUMP _ORELSE CUT_OPS(i).cmd = OP_OPTION THEN
            IF CUT_OPS(i).s2 > CUT_NOSTR THEN
                nm = CutStrGet$(CUT_OPS(i).s2)
                t = CutFindLabel%(nm)
                IF t < 0 THEN
                    CutErrAdd 2, CUT_OPS(i).srcline, "no such label '" + nm + "'"
                ELSE
                    CUT_OPS(i).n1 = t
                END IF
            END IF
        END IF
    NEXT i
END SUB

' ----------------------------------------------------------------------------
'  Shared modifier emitter: `at`, `scale`, `z`, `parallax` after a show/anim.
'  These are instant sets, not tweens -- an author animating them uses
'  move/grow/fadelayer.
' ----------------------------------------------------------------------------
SUB CutEmitLayerMods (lay AS STRING, startat AS INTEGER, ln AS INTEGER)
    DIM tgt AS INTEGER, op AS INTEGER
    tgt = CutKw%("at", startat)
    IF tgt >= 0 THEN
        op = CutEmit%(OP_LAYSET, CutStr&(lay), CUT_NOSTR, LS_X, CutNum!(CutTok$(tgt + 1)), 0, 0, ln, TRUE)
        op = CutEmit%(OP_LAYSET, CutStr&(lay), CUT_NOSTR, LS_Y, CutNum!(CutTok$(tgt + 2)), 0, 0, ln, TRUE)
    END IF
    tgt = CutKw%("scale", startat)
    IF tgt >= 0 THEN
        op = CutEmit%(OP_LAYSET, CutStr&(lay), CUT_NOSTR, LS_SCALE, CutNum!(CutTok$(tgt + 1)), 0, 0, ln, TRUE)
    END IF
    tgt = CutKw%("parallax", startat)
    IF tgt >= 0 THEN
        op = CutEmit%(OP_LAYSET, CutStr&(lay), CUT_NOSTR, LS_PARALLAX, CutNum!(CutTok$(tgt + 1)), 0, 0, ln, TRUE)
    END IF
    '--- explicit depth. Without this a layer can only ever go IN FRONT of
    '    everything already shown, because new layers take the next free z --
    '    so there is no way to slide a backdrop in behind a character who is
    '    already on screen. ---
    tgt = CutKw%("z", startat)
    IF tgt >= 0 THEN
        op = CutEmit%(OP_LAYSET, CutStr&(lay), CUT_NOSTR, LS_Z, CutNum!(CutTok$(tgt + 1)), 0, 0, ln, TRUE)
    END IF

    '--- `fill` / `fit` size a layer against the STAGE instead of against a
    '    number the author worked out from the art's dimensions.
    '
    '    That arithmetic is a trap: `scale 8` is only correct for one exact
    '    source size, so the day the art is regenerated a little smaller every
    '    scene using it silently grows a black border -- which is also exactly
    '    what a missing backdrop looks like. `fill` cannot go stale. ---
    '--- `fill`/`fit` size against the STAGE and therefore ignore `scale`. Both
    '    on one line is an authoring mistake with no error and a very visible
    '    result: a 128px sprite quietly blown up to fill the whole stage. ---
    IF CutHasKw%("scale", startat) THEN
        IF CutHasKw%("fill", startat) _ORELSE CutHasKw%("fit", startat) THEN
            CutErrAdd 1, ln, "`scale` is ignored when `fill`/`fit` is also given (they size against the stage)"
        END IF
    END IF

    IF CutHasKw%("fill", startat) THEN
        op = CutEmit%(OP_LAYSET, CutStr&(lay), CUT_NOSTR, LS_FILL, 0, 0, 0, ln, TRUE)
    END IF
    IF CutHasKw%("fit", startat) THEN
        op = CutEmit%(OP_LAYSET, CutStr&(lay), CUT_NOSTR, LS_FIT, 0, 0, 0, ln, TRUE)
    END IF
END SUB

'--- `dissolve to "crypt.png"` / `wipe to "gate.png" dir left`.
'
'  The swap has to happen INSIDE the transition op, after the outgoing frame
'  is photographed but before anything is drawn -- an author writing the swap
'  as a separate line before the transition would photograph the NEW picture
'  as the old one, and nothing would appear to happen. Layer and path share
'  one string slot separated by a pipe; a path cannot contain one.
SUB CutTransTarget (op AS INTEGER, startat AS INTEGER, ln AS INTEGER)
    DIM q AS INTEGER, pth AS STRING, lay AS STRING
    pth = CutFirstQuoted$(startat, q)
    IF q < 0 THEN EXIT SUB
    lay = CutKwStr$("layer", startat, "bg")
    CUT_OPS(op).s3 = CutStr&(lay + "|" + pth)
END SUB

FUNCTION CutEaseOr% (s AS STRING, ln AS INTEGER)
    DIM e AS INTEGER
    e = CutEaseCode%(s)
    IF e < 0 THEN
        CutErrAdd 1, ln, "unknown ease '" + s + "'; using linear"
        e = EASE_LINEAR
    END IF
    CutEaseOr% = e
END FUNCTION

SUB CutShiftTokens
    DIM i AS INTEGER
    FOR i = 1 TO CUT_NTK - 1
        CUT_TK(i) = CUT_TK(i + 1)
        CUT_TKQ(i) = CUT_TKQ(i + 1)
    NEXT i
    CUT_NTK = CUT_NTK - 1
END SUB

FUNCTION CutSceneNameFromPath$ (path AS STRING)
    DIM s AS STRING, i AS INTEGER
    s = path
    FOR i = LEN(s) TO 1 STEP -1
        IF MID$(s, i, 1) = "/" _ORELSE MID$(s, i, 1) = "\" THEN
            s = MID$(s, i + 1)
            EXIT FOR
        END IF
    NEXT i
    i = INSTR(LCASE$(s), ".cut")
    IF i > 1 THEN s = LEFT$(s, i - 1)
    CutSceneNameFromPath$ = s
END FUNCTION

' ----------------------------------------------------------------------------
'  Reset
' ----------------------------------------------------------------------------
SUB CutResetProgram
    DIM i AS INTEGER
    FOR i = 0 TO CUT_MAXOP
        CUT_OPS(i).cmd = OP_NOP
        CUT_OPS(i).s1 = CUT_NOSTR
        CUT_OPS(i).s2 = CUT_NOSTR
        CUT_OPS(i).s3 = CUT_NOSTR
        CUT_OPS(i).fonth = 0
        CUT_OPS(i).n1 = 0
        CUT_OPS(i).n2 = 0
        CUT_OPS(i).n3 = 0
        CUT_OPS(i).n4 = 0
        CUT_OPS(i).async = FALSE
        CUT_OPS(i).srcline = 0
    NEXT i
    CUT_NOP = 0
    CUT_NLBL = 0
    CUT_NERR = 0
    CUT_NFATAL = 0
    CUT_NSRC = 0
    CUT_NSPOOL = 0
    REDIM CUT_SPOOL(0 TO 0) AS STRING
    REDIM CUT_SRC(0 TO 0) AS STRING
    REDIM CUT_SRCFILE(0 TO 0) AS STRING
    CUT_NVAR = 0
    CUT_NEST = 0
    CUT_CHOP = 0
    CUT_CHN = 0
    CUT_NOSKIP = FALSE
    CUT_SBTITLE = ""
    CUT_SBBLURB = ""
    CUT_STAGEW = CUT_PXW
    CUT_STAGEH = CUT_PXH
    CUT_MISSING = 0
END SUB
