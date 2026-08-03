' ============================================================================
'  MGDICE.bas -- see MGDICE.bi.
' ============================================================================

' DICE3D's only dependency on its host. In the game it lays CANVAS down before
' the GL triangles go over it, because the tray and caption are drawn to CANVAS
' and only reach the screen through the host's present step -- without it the
' dice roll on a black screen.
'
' The prototypes draw straight to the display page, so there is nothing to lay
' down and this is a no-op. It exists so the vendored module links unmodified:
' the moment a prototype grows a separate canvas, this is the one place to fix.
SUB PresentNoFlip
END SUB

' Bring the 3D dice up. Safe to call when they cannot work -- dice3d_ready stays
' FALSE and every roll falls back to the plain path, which is exactly what the
' game does with a missing or broken dice set.
SUB MgDiceInit
    dice3d_ready = FALSE
    dice3d_config_defaults DICE_CFG
    dice3d_light_defaults DICE_CFG
    IF _FILEEXISTS("../../assets/data/diceset.txt") THEN
        DIM cset(1 TO 8) AS DICE3D_CONFIG
        IF dice3d_set_load%(cset(), "../../assets/data/diceset.txt") THEN DICE_CFG = cset(1)
    END IF
    ' the module draws on the GL layer, which does not exist without a window --
    ' and a headless run has no business animating anything anyway
    IF NOT MG_QUIET THEN dice3d_ready = -1
    DICE_CFG.SOUND_ENABLED = 0        ' the prototype owns its own noises, via MgBeep
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

    IF opt_dice3d _ANDALSO dice3d_ready _ANDALSO dice3d_supported%(sides) _ANDALSO n <= MG_MAXDICE THEN
        notation = _TRIM$(STR$(n)) + "d" + _TRIM$(STR$(sides))
        dice3d_roll notation, DICE_CFG, r()        ' animates, returns settled faces
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
