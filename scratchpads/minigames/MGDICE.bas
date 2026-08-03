' ============================================================================
'  MGDICE.bas -- see MGDICE.bi.
' ============================================================================

' DICE3D's only dependency on its host, and it is load-bearing.
'
' dice3d_roll runs its own animation loop and draws nothing but DICE. Whatever the
' rest of the screen was is simply whatever happens to be in the back buffer -- so
' without laying the host's picture down every frame, the game's UI vanishes the
' moment the dice start rolling and comes back when they stop. In the game this
' blits CANVAS; here it blits the snapshot MgRollHere took just before the roll.
'
' A no-op version linked fine and rolled dice on a screen that had gone blank,
' which is exactly what it looked like.
' GL calibration, from engine/DICE3D_GAME.bas: 1 model unit is about 103 screen
' pixels at the module's view depth. It lives in the game's presentation layer
' rather than in the module, so a host has to supply it -- this is that.
CONST MGD_PXPERUNIT = 103.0

SUB PresentNoFlip
    IF MGD_SNAP <> 0 THEN _PUTIMAGE , MGD_SNAP, 0
END SUB

' Bring the 3D dice up, using THE GAME'S OWN dice sets.
'
' The style -- body colour, ink, finish, bevel, light -- lives in the set FILE,
' not in code, which is why loading the same file the game loads is the whole of
' "make it look like the game". Reads assets/data/default/dicesets.txt for the
' manifest and loads the chosen set, falling back to the legacy single
' diceset.txt, exactly as the game's LoadDiceSets does.
'
' Safe to call when 3D cannot work: dice3d_ready stays FALSE and every roll falls
' back to the plain path, which is what the game does with a missing set.
SUB MgDiceInit
    DIM i AS INTEGER, fh AS INTEGER, n AS INTEGER
    DIM ln AS STRING, pick AS STRING, dpath AS STRING

    dpath = "../../assets/data/default/"    ' `dpath`, not `base`: BASE is taken
    dice3d_ready = FALSE
    FOR i = 0 TO 6
        dice3d_config_defaults DSET3D(i)
        dice3d_light_defaults DSET3D(i)
    NEXT i
    IF opt_dice3d_set < 1 THEN opt_dice3d_set = 1

    IF _FILEEXISTS(dpath + "dicesets.txt") THEN
        fh = FREEFILE
        OPEN dpath + "dicesets.txt" FOR INPUT AS #fh
        DO UNTIL EOF(fh)
            LINE INPUT #fh, ln
            ln = _TRIM$(ln)
            IF LEN(ln) > 0 _ANDALSO LEFT$(ln, 1) <> "#" THEN
                IF INSTR(ln, "|") > 0 THEN
                    n = n + 1
                    IF n = opt_dice3d_set THEN pick = _TRIM$(MID$(ln, INSTR(ln, "|") + 1))
                END IF
            END IF
        LOOP
        CLOSE #fh
    END IF

    IF LEN(pick) > 0 THEN
        IF dice3d_set_load%(DSET3D(), dpath + "dicesets/" + pick) THEN dice3d_ready = -1
    END IF
    IF NOT dice3d_ready THEN
        IF dice3d_set_load%(DSET3D(), dpath + "diceset.txt") THEN dice3d_ready = -1
    END IF

    ' the module draws on the GL layer, which does not exist without a window --
    ' and a headless run has no business animating anything
    IF MG_QUIET _ANDALSO NOT MG_FORCE3D THEN dice3d_ready = FALSE

    FOR i = 0 TO 6
        DSET3D(i).SOUND_ENABLED = 0   ' the prototype owns its noises, via MgBeep
    NEXT i
END SUB


' The player's SETTINGS applied ON TOP of the set, exactly as the game's
' ApplyDiceLight and its Dice Round row do. The SET is the style; these two are
' the knobs that override it.
SUB MgApplyDiceSettings (cfg AS DICE3D_CONFIG)
    SELECT CASE opt_dicelight
        CASE 0: cfg.LIGHT_ENABLED = 0
        CASE 1: cfg.LIGHT_ENABLED = -1: cfg.LIGHT_AMBIENT = 0.78: cfg.LIGHT_INTENSITY = 0.5
        CASE 2: cfg.LIGHT_ENABLED = -1: cfg.LIGHT_AMBIENT = 0.62: cfg.LIGHT_INTENSITY = 0.8
        CASE ELSE: cfg.LIGHT_ENABLED = -1: cfg.LIGHT_AMBIENT = 0.5: cfg.LIGHT_INTENSITY = 1!
    END SELECT
    IF opt_diceround > 0 THEN cfg.BEVEL = opt_diceround / 10
END SUB

' The prototype's flip, and the reason settled dice stay on the table.
'
' dice3d_roll animates and returns, and at that moment the dice exist only as GL
' triangles already issued -- the hardware layer goes straight to the window, so
' the very next _DISPLAY wipes them. The game has the same problem and solves it
' the same way (dice3d_repost, called every frame of its sum reveal).
'
' So a prototype ends its draw routine with THIS instead of _DISPLAY: the screen
' it just drew is on the back buffer, the settled dice go over it, and the flip
' happens once. Call _DISPLAY as well and the dice flicker.
' THE GUARD IS THE WHOLE THING. dice3d_roll frees the per-die atlas and the box
' buffer when it finishes, and it does NOT zero the atlas handle -- so afterwards
' DICE3D_DICE(i).ATLAS is a stale, non-zero, freed handle. Two ways that bites:
'
'   * the SOFTWARE path renders from those per-die atlases -> Invalid handle
'   * the HARDWARE path is safe ONLY once DICE3D_HWATLAS exists; while it is
'     still 0 it tries to build it by copying DICE3D_DICE(lo).ATLAS, i.e. the
'     same freed handle -> Invalid handle
'
' My first guard tested dice3d_force_soft, which is a manual OVERRIDE, not the
' dispatch. dice3d_present branches on DICE3D_HW. So on any machine where the
' hardware layer was not active, this took the software path and died -- which is
' exactly what "CRAPS is failing now, invalid handle" was.
'
' Repost only on hardware, and only once the hardware atlas is already built.
' Anything else falls through to a plain flip and the dice simply are not held,
' which is the old behaviour rather than a crash.
' THE FRAME. Every prototype ends its draw routine with this and nothing else.
'
' It is one name so that integration is one substitution: in qb64-dungeon this
' becomes `Present`, the game's single per-frame chokepoint -- the place the [`]
' dev-console hotkey is polled and _RESIZE is handled. A mini-game that calls
' _DISPLAY directly is a screen the console cannot open over and the window
' cannot be resized on, and there are ~40 nested blocking loops in that game for
' it to get that wrong in.
'
' It also happens to be where settled dice get re-issued, which is why it lives
' in the dice layer rather than in MG.bas -- but the reason every prototype calls
' it is the chokepoint, not the dice.
SUB MgPresent
    MgDicePresent
END SUB

SUB MgDicePresent
    IF MGD_HELD _ANDALSO dice3d_ready _ANDALSO DICE3D_HW _ANDALSO DICE3D_HWATLAS <> 0 THEN
        dice3d_present MGD_CFG      ' issues the triangles AND flips
        EXIT SUB
    END IF
    _DISPLAY
END SUB

' Smoke-test the live dice path: roll, hold, and repost, exactly as play does.
'
' A selftest cannot reach any of this -- it runs with 3D disabled -- which is how
' a repost reading handles that dice3d_roll had already freed got all the way to
' somebody running the game. It asserts no picture, only that rolling and then
' presenting for a hundred frames does not blow up.
'
' NEEDS A REAL GPU. Under Xvfb the hardware path dies on its first hardware
' _COPYIMAGE, and forcing the software renderer instead hits a separate failure
' inside the module that I have not isolated -- so this cannot run in the gate,
' and saying so is better than a version that passes by not testing anything.
' Run it on a machine with a display:  ./CRAPS.run dicedemo
SUB MgDiceSmoke (n AS INTEGER, sides AS INTEGER)
    DIM i AS INTEGER, t AS INTEGER
    ' Headless has no real GL, so the hardware path dies on the first
    ' _COPYIMAGE(,33). The game's rollshot has the same problem and the same
    ' answer: force the software renderer, which draws where a capture can see it.
    ' DICE3D_HW is the dispatch; dice3d_force_soft is only the intent.
    t = GameRoll%(n, sides, 0, "smoke")
    _DEST _CONSOLE
    PRINT "  rolled"; n; "d"; sides; "="; t; "  held ="; MGD_HELD; "  hw ="; DICE3D_HW; "  hwatlas ="; DICE3D_HWATLAS
    FOR i = 1 TO 100
        MgDicePresent
    NEXT i
    PRINT "  100 reposts survived"
END SUB

' Take the dice off the table -- between rounds, or when the screen moves on.
SUB MgDiceClear
    MGD_HELD = 0
END SUB

' Reserve a region of the prototype's layout for the dice, ONCE. Everything else
' is laid out around it: the tray is furniture, not a popup that appears over the
' game and takes the screen away while it is up.
SUB MgDiceTray (x AS INTEGER, y AS INTEGER, w AS INTEGER, h AS INTEGER, cap AS STRING)
    TRAY_X = x: TRAY_Y = y: TRAY_W = w
    TRAY_H = (h \ CH) * CH
    TRAY_CAP = cap
END SUB

' Draw the tray. The prototype calls this from its own draw routine EVERY frame,
' so it is on screen whether or not dice are in the air -- which is the point.
' Same visual language as the game: a plush violet box under a caption header.
SUB MgDrawTray
    DIM viol AS _UNSIGNED LONG, edge AS _UNSIGNED LONG
    DIM hb AS INTEGER, hw AS INTEGER, hx AS INTEGER
    IF TRAY_W <= 0 THEN EXIT SUB
    viol = _RGB32(&H34, &H22, &H7A)
    edge = _RGB32(&H8A, &H70, &HE0)

    hw = (LEN(TRAY_CAP) + 4) * CW
    IF hw < TRAY_W THEN hw = TRAY_W
    hx = TRAY_X + (TRAY_W - hw) \ 2
    hb = 2 * CH
    LINE (hx, TRAY_Y - hb)-(hx + hw, TRAY_Y), viol, BF
    LINE (hx, TRAY_Y - hb)-(hx + hw, TRAY_Y), edge, B
    COLOR C_TITLE, viol
    _PRINTSTRING (hx + (hw - LEN(TRAY_CAP) * CW) \ 2, TRAY_Y - hb + CH \ 2), TRAY_CAP

    LINE (TRAY_X, TRAY_Y)-(TRAY_X + TRAY_W, TRAY_Y + TRAY_H), viol, BF
    LINE (TRAY_X, TRAY_Y)-(TRAY_X + TRAY_W, TRAY_Y + TRAY_H), edge, B
    COLOR C_TEXT, 0
END SUB

' Fit the PHYSICS box inside the DRAWN tray, mirroring the game's geometry: inset
' from the painted edge so a die never settles half over the border, and anchored
' to the tray's BOTTOM so the floor cannot drift down into whatever is printed
' under it.
SUB MgFitBox (cfg AS DICE3D_CONFIG)
    DIM inset AS INTEGER, botinset AS INTEGER, minw AS INTEGER, minh AS INTEGER
    inset = 10
    botinset = dice3d_radius!(cfg) + 6
    minw = cfg.DIE_SIZE * 4: minh = cfg.DIE_SIZE * 3
    cfg.BOX_W = TRAY_W - inset * 2: IF cfg.BOX_W < minw THEN cfg.BOX_W = minw
    cfg.BOX_H = TRAY_H - inset * 2 - botinset: IF cfg.BOX_H < minh THEN cfg.BOX_H = minh
    cfg.BOX_X = TRAY_X + inset
    cfg.BOX_Y = TRAY_Y + TRAY_H - botinset - cfg.BOX_H
    IF cfg.BOX_Y < TRAY_Y THEN cfg.BOX_Y = TRAY_Y

    ' Where the tray sits in GL space. The game's GlX!/GlY! also account for its
    ' fullscreen present-scaling; a prototype draws 1:1 into its own window, so
    ' this is the unscaled form of the same expression -- offset from the window
    ' centre in model units, y flipped because GL counts upward.
    DICE3D_HW_CX = (cfg.BOX_X + cfg.BOX_W * 0.5 - SW * CW * 0.5) / MGD_PXPERUNIT
    DICE3D_HW_CY = -(cfg.BOX_Y + cfg.BOX_H * 0.5 - SH * CH * 0.5) / MGD_PXPERUNIT
    DICE3D_HW_PXK = 1! / MGD_PXPERUNIT
END SUB

'--- dice -------------------------------------------------------------------
'
'  Mirrors engine/UI.bas exactly. Read the header note in MG.bi before touching.

' Generalised roll: n dice of `sides` plus a modifier, honouring Real Dice and
' Dice Math.
'
' THE THING TO KNOW: under Real Dice this returns a total and publishes NO faces,
' because the player rolled physical dice on their table and the game genuinely
' cannot see them. So a mechanic that needs to know what EACH die showed --
' knucklebones busting on any single 1 is the example -- must roll its dice
' individually rather than rolling 2d6 and reading DieFace%. Roll them inside
' RollSeqBegin/RollSeqEnd and the animated path still shows one shared tray.
FUNCTION GameRoll% (n AS INTEGER, sides AS INTEGER, bonus AS INTEGER, what AS STRING)
    DIM raw AS INTEGER, t AS INTEGER
    IF opt_realdice THEN
        raw = PromptRoll%(n, sides, bonus, what)
        DIE_FACE_N = 0                       ' physical dice -- no faces to publish
        IF opt_dicemath THEN
            GameRoll% = raw                  ' the player already added it
        ELSE
            GameRoll% = raw + bonus
        END IF
        EXIT FUNCTION
    END IF
    t = AnimatedRoll%(n, sides, bonus, what)
    GameRoll% = t + bonus
END FUNCTION

' Roll for real and publish the faces, with whichever renderer the settings pick.
'
' This is the ONE seam between a mini-game and how dice look. A call site never
' knows whether it got tumbling 3D polyhedra, pip dice or a headless number -- it
' gets a total and a face table, which is all it depends on.
FUNCTION AnimatedRoll% (n AS INTEGER, sides AS INTEGER, bonus AS INTEGER, what AS STRING)
    DIM i AS INTEGER, t AS INTEGER
    DIM v(1 TO MG_MAXDICE) AS INTEGER
    DIM r(1 TO MG_MAXDICE) AS INTEGER
    DIM notation AS STRING
    DIM cfg AS DICE3D_CONFIG        ' at the top: a DIM inside the IF is a syntax error

    IF opt_dice3d _ANDALSO dice3d_ready _ANDALSO dice3d_supported%(sides) _ANDALSO n <= MG_MAXDICE THEN
        cfg = DSET3D(dice3d_set_index%(sides))     ' the SET carries the style
        MgApplyDiceSettings cfg                    ' the player's two overrides
        MgFitBox cfg                               ' into the tray the layout reserved

        ' photograph the screen so PresentNoFlip can lay it back down under every
        ' frame of the tumble -- without this the prototype's UI vanishes mid-roll
        IF MGD_SNAP <> 0 THEN _FREEIMAGE MGD_SNAP
        MGD_SNAP = _COPYIMAGE(0, 32)

        ' WHICH RENDERER. The module does not decide this -- the HOST does, and
        ' the prototypes never did, so DICE3D_HW sat at 0 and every roll went down
        ' the software path. That path composites into the canvas and cannot be
        ' re-posted afterwards (its atlases are freed on the way out), so the dice
        ' appeared while rolling and vanished the moment they settled.
        '
        ' Same line the game uses in Show3DRoll.
        IF dice3d_force_soft THEN DICE3D_HW = 0 ELSE DICE3D_HW = -1

        notation = _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides))
        dice3d_roll notation, cfg, r()             ' animates, returns settled faces

        ' the snapshot's job is done: from here the dice are re-issued over
        ' whatever the prototype draws, not over a photograph of the past
        IF MGD_SNAP <> 0 THEN _FREEIMAGE MGD_SNAP: MGD_SNAP = 0
        MGD_CFG = cfg: MGD_HELD = -1        ' keep them on the table
        FOR i = 1 TO n
            v(i) = r(i): t = t + v(i)
        NEXT i
        PublishFaces v(), n
        AnimatedRoll% = t
        EXIT FUNCTION
    END IF

    FOR i = 1 TO n
        IF i <= MG_MAXDICE THEN v(i) = MgRoll%(sides): t = t + v(i)
    NEXT i
    PublishFaces v(), n
    AnimatedRoll% = t
END FUNCTION

' Ask the player what their physical dice showed, and refuse an impossible answer.
' Range and the lone-d10-shows-zero rule match the engine's PromptRoll exactly.
FUNCTION PromptRoll% (n AS INTEGER, sides AS INTEGER, bonus AS INTEGER, what AS STRING)
    DIM entry AS STRING, k AS STRING, chcode AS INTEGER, v AS INTEGER
    DIM spec AS STRING, l1 AS STRING, msg AS STRING, lo AS INTEGER, hi AS INTEGER
    DIM od AS LONG

    spec = _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides))
    IF bonus > 0 _ANDALSO opt_dicemath THEN
        l1 = "Roll " + spec + ", add +" + _TRIM$(STR$(bonus)) + ", and enter the TOTAL:"
        lo = n + bonus: hi = n * sides + bonus
    ELSEIF bonus > 0 THEN
        l1 = "Roll " + spec + " (the game adds +" + _TRIM$(STR$(bonus)) + ") -- enter your DICE:"
        lo = n: hi = n * sides
    ELSE
        l1 = "Roll " + spec + " and enter the result:"
        lo = n: hi = n * sides
    END IF

    ' headless: the selftest drives this path without a keyboard
    IF MG_FAKEROLL > 0 THEN
        v = MG_FAKEROLL
        IF v < lo THEN v = lo
        IF v > hi THEN v = hi
        PromptRoll% = v
        EXIT FUNCTION
    END IF

    od = _DEST: _DEST 0
    entry = "": msg = ""
    DO
        _LIMIT 60
        LINE (24 * CW, 19 * CH)-(108 * CW, 31 * CH), _RGB32(16, 14, 22), BF
        LINE (24 * CW, 19 * CH)-(108 * CW, 31 * CH), C_COOL, B
        COLOR C_TITLE, 0: MgCenter 21, "-=  R E A L   D I C E  =-"
        COLOR C_COOL, 0: MgCenter 22, "(" + what + ")"
        COLOR C_TEXT, 0: MgCenter 25, l1
        COLOR C_GOOD, 0: MgCenter 28, "> " + entry + "_"
        IF LEN(msg) > 0 THEN COLOR C_BAD, 0: MgCenter 30, msg
        _DISPLAY
        k = INKEY$
        IF k <> "" THEN
            IF k = CHR$(13) THEN
                IF LEN(entry) > 0 THEN
                    v = VAL(entry)
                    IF sides = 10 _ANDALSO n = 1 _ANDALSO v = 0 THEN v = 10
                    IF v >= lo _ANDALSO v <= hi THEN
                        PromptRoll% = v: _DEST od: EXIT FUNCTION
                    ELSE
                        msg = "That's not possible -- enter " + _TRIM$(STR$(lo)) + " to " + _TRIM$(STR$(hi)): entry = ""
                    END IF
                END IF
            ELSEIF k = CHR$(8) THEN
                IF LEN(entry) > 0 THEN entry = LEFT$(entry, LEN(entry) - 1)
            ELSEIF LEN(k) = 1 THEN
                chcode = ASC(k)
                IF chcode >= 48 _ANDALSO chcode <= 57 _ANDALSO LEN(entry) < 3 THEN entry = entry + k
            END IF
        END IF
    LOOP
END FUNCTION

SUB PublishFaces (v() AS INTEGER, n AS INTEGER)
    DIM i AS INTEGER
    DIE_FACE_N = 0
    FOR i = 1 TO n
        IF i <= MG_MAXDICE THEN DIE_FACE(i) = v(i): DIE_FACE_N = i
    NEXT i
END SUB

' The face die `i` showed, or 0 if none were published (Real Dice).
FUNCTION DieFace% (i AS INTEGER)
    DieFace% = 0
    IF i >= 1 _ANDALSO i <= DIE_FACE_N THEN DieFace% = DIE_FACE(i)
END FUNCTION

' Multi-pass rolls share one tray in the engine. No-ops here, but present so the
' call sites are already correct when the shim goes away.
SUB RollSeqBegin
    rollseq_on = -1
END SUB

SUB RollSeqEnd
    rollseq_on = 0
END SUB

' Shared assertions for the dice contract. Called from the selftest of every
' prototype that rolls dice, so the contract is checked once and cannot drift
' apart between them.
SUB MgDiceSelfTest
    DIM i AS LONG, t AS INTEGER, lo AS INTEGER, hi AS INTEGER
    DIM AS LONG hits(1 TO 6), n
    DIM AS INTEGER wasreal, wasmath, sum, okk

    wasreal = opt_realdice: wasmath = opt_dicemath

    MgSection "the dice contract -- honoured exactly as qb64-dungeon does"
    opt_realdice = FALSE: opt_dicemath = FALSE

    lo = 999: hi = -999
    FOR i = 1 TO 60000
        t = GameRoll%(2, 6, 0, "test")
        IF t < lo THEN lo = t
        IF t > hi THEN hi = t
    NEXT i
    MgOk "2d6 stays inside 2..12", lo = 2 _ANDALSO hi = 12

    FOR i = 1 TO 60000
        t = GameRoll%(1, 6, 0, "test")
        hits(t) = hits(t) + 1
    NEXT i
    okk = TRUE
    FOR i = 1 TO 6
        IF ABS(hits(i) / 60000 - 1! / 6!) > 0.01 THEN okk = FALSE
    NEXT i
    MgOk "a d6 is uniform -- the shim adds no bias", okk

    t = GameRoll%(3, 6, 0, "test")
    sum = DieFace%(1) + DieFace%(2) + DieFace%(3)
    MgOk "published faces sum to the total", DIE_FACE_N = 3 _ANDALSO sum = t

    MgOk "the bonus is added exactly once", BonusAddedOnce%

    MgSection "...and under REAL DICE, which is the half that usually rots"
    opt_realdice = TRUE: opt_dicemath = FALSE
    MG_FAKEROLL = 7
    t = GameRoll%(2, 6, 3, "test")
    MgOk "with Dice Math OFF the game adds the modifier", t = 10
    MgOk "no faces are published -- the game never saw the dice", DIE_FACE_N = 0
    MgOk "...so DieFace% reports nothing rather than lying", DieFace%(1) = 0

    opt_dicemath = TRUE
    MG_FAKEROLL = 10
    t = GameRoll%(2, 6, 3, "test")
    MgOk "with Dice Math ON the player already added it", t = 10

    MG_FAKEROLL = 0
    opt_realdice = wasreal: opt_dicemath = wasmath
END SUB

' Rolled with no modifier and with one, the difference must be exactly the
' modifier -- not zero (never applied) and not twice it (applied in the renderer
' AND in GameRoll, which is the classic way this breaks).
FUNCTION BonusAddedOnce% ()
    DIM i AS LONG
    DIM AS LONG a, b
    FOR i = 1 TO 40000
        a = a + GameRoll%(1, 6, 0, "t")
        b = b + GameRoll%(1, 6, 5, "t")
    NEXT i
    BonusAddedOnce% = (ABS((b - a) / 40000! - 5!) < 0.15)
END FUNCTION


'$INCLUDE:'../../engine/DICE3D/_ALL.BM'
