' ============================================================================
'  OPENTHECHEST.bas -- THE THREE CLASPS
'
'  A chest with three clasps set under the lid, each a different colour. Open
'  them in the right order and it gives up its contents. Open one out of order
'  and the trap fires, taking the chest and everything in it.
'
'  ---------------------------------------------------------------------------
'  WHY THE CLASPS SHUFFLE
'
'  After each correct choice the clasp you opened stays open and KEEPS its
'  colour -- but the ones still shut swap their colours and positions around.
'
'  That single rule is the whole puzzle. It means the answer can never be cached
'  as "left, then middle, then right": position carries no information at all,
'  and what you are holding in your head is an ordered triple of COLOURS. A
'  player who writes down positions has written down nothing.
'
'  Blind, that is one chance in six, which is brutal -- and is exactly why the
'  next part exists.
'
'  ---------------------------------------------------------------------------
'  ONE COMBINATION PER DUNGEON LEVEL
'
'  Every chest on a level is keyed the same. Each of the nine levels has its own
'  combination, rolled once per run.
'
'  So the first chest you meet on a level is a gamble, and every chest after it
'  on that level is the reward for having survived the first. Nobody is asked to
'  solve nine hundred puzzles; they are asked to learn nine codes, and each one
'  is paid for exactly once.
'
'  This is why the mini-game does NOT own its own state. It asks the run what
'  this level's code is, asks whether the player already knows it, and reports
'  back when a chest is cracked. Those three calls are the API, and they are what
'  has to be got right before any art exists -- see OPENTHECHEST-SPEC.md.
'
'  The single assertion that the whole idea rests on: a player who KNOWS the code
'  must win every single time. If the shuffle can ever make a correct answer
'  fail, the level memory is worth nothing and the first chest was robbery.
' ============================================================================
'$INCLUDE:'MG.bi'

CONST CLASPS = 3                ' NOT "LOCKS" -- LOCK is a QB64 reserved word
CONST LEVELS = 9
CONST HUES = 3                  ' colours in play; a code is a permutation of them
'--- the fuse. A wrong clasp no longer destroys the chest on the spot: it starts
'    the mechanism ticking, and you can still save it. ---
' THE FUSE. Once a wrong clasp arms it, it burns. A further wrong clasp does not
' reset it and does not cost extra -- it simply keeps counting, which is what a
' burning fuse does.
'
' That makes the LENGTH the only thing standing between a patient guesser and a
' free chest, because with three colours on screen a player can just eliminate:
' try one, try another, and the third is forced. So the fuse is sized against
' exactly that, and the number is derived, not chosen -- see the selftest.
' 4.5, and the value is forced rather than chosen. The clock starts ON the wrong
' pick that arms it, so what the fuse buys you is how many MORE picks you get:
'
'   HUMAN_PICK <= FUSE_SECS       -- one more pick, so a single mistake is
'                                    recoverable if you then know the answer
'   2 * HUMAN_PICK > FUSE_SECS    -- but not two, so you cannot simply try every
'                                    colour in turn
'
' The first cut sat at 6.5s, which buys TWO more picks -- and two more picks is
' exactly enough to exhaust three colours by elimination. The simulated guesser
' opened 100% of chests. Not a bug in the test: the fuse was long enough to make
' the puzzle free, and the level code worthless with it.
'
' At 3s both inequalities still hold, but the slack is half a second. HUMAN_PICK
' is an ESTIMATE of how long a deliberate pick takes; if it is optimistic, this
' fuse is not tense, it is unfair, and the honest fix is to raise the fuse rather
' than to lower the estimate to fit. Play it before trusting it.
CONST FUSE_SECS = 3!            ' seconds on the clock once the trap is armed
CONST HUMAN_PICK = 2.5          ' seconds to read three colours and choose one

'--- art lookup: every piece by NAME, so the same game runs on placeholders,
'    pixel art or ANSI art without knowing which it got ---
CONST ART_NONE = 0              ' nothing on disk -- draw the built-in placeholder
CONST ART_PIXEL = 1
CONST ART_ANSI = 2
CONST ARTN = 8

DIM SHARED ARTKEY(1 TO ARTN) AS STRING
DIM SHARED ARTKIND(1 TO ARTN) AS INTEGER
DIM SHARED ARTPATH(1 TO ARTN) AS STRING

DIM SHARED HUENAME(1 TO HUES) AS STRING
DIM SHARED HUECOL(1 TO HUES) AS _UNSIGNED LONG

'--- the run's state. This is what the real game owns, not the mini-game. ---
' CODEOF / KNOWNAT, not CHESTCODE / CHESTKNOWN: identifiers are case-insensitive
' and FUNCTION ChestCode$ / ChestCodeKnown% already own those names.
DIM SHARED CODEOF(1 TO LEVELS) AS STRING       ' e.g. "213" -- hue ids, in order
DIM SHARED KNOWNAT(1 TO LEVELS) AS INTEGER

'--- the chest in front of you right now ---
DIM SHARED CLASPHUE(1 TO CLASPS) AS INTEGER     ' which colour each clasp shows
DIM SHARED CLASPOPEN(1 TO CLASPS) AS INTEGER
DIM SHARED AS INTEGER g_level, g_step, g_sel, g_blown, g_opened
DIM SHARED AS INTEGER g_armed, g_wrongs
DIM SHARED AS SINGLE g_left
DIM SHARED g_fuse0 AS DOUBLE

'--- presentation state. NOTHING here blocks: a message has an expiry and the
'    shuffle has a frame counter, so the play loop never stops turning and the
'    fuse never stops burning. ---
DIM SHARED g_tumble AS INTEGER
DIM SHARED TUMBHUE(1 TO CLASPS) AS INTEGER
DIM SHARED g_msg AS STRING
DIM SHARED g_msguntil AS DOUBLE

DIM cmd AS STRING
ON ERROR GOTO MgFatal
MgInit
InitHues
InitArt
cmd = UCASE$(COMMAND$)

IF INSTR(cmd, "SELFTEST") > 0 THEN ChestSelfTest
MgScreen
IF INSTR(cmd, "SHOT") > 0 THEN
    RANDOMIZE 131
    ChestRollCodes
    g_level = 4
    ChestSetup g_level
    CLASPOPEN(2) = TRUE: g_step = 2: g_sel = 1
    ShuffleShut
    DrawChest "one clasp given -- the others have moved"
    _SAVEIMAGE "openthechest-shot.png"
    _DEST _CONSOLE: PRINT "wrote openthechest-shot.png": SYSTEM
END IF

DIM r AS INTEGER
ChestRollCodes
r = PlayChest(4)
_DEST _CONSOLE: PRINT "result ="; r: SYSTEM

'--- FATAL ERROR TRAP ---
MgFatal:
    _DEST _CONSOLE
    PRINT: PRINT "!! QB64 RUNTIME ERROR"; ERR; "at line"; _ERRORLINE
    PRINT "!! "; _ERRORMESSAGE$(ERR)
    PRINT "!! aborting instead of opening a dialog nobody can click"
    SYSTEM 1

'============================================================================
'  ART AND SOUND, BY NAME
'
'  The mini-game never names a file. It asks for "chest.closed" and gets back
'  whatever the pack supplied, resolved PER PIECE so a pack that ships three of
'  the eight still gets its three and placeholders for the rest.
'
'  A missing asset means "use the fallback", never "fail" -- the same rule Say$
'  and Thm~& follow, and the reason a half-finished art pack does not brick the
'  chest. In this prototype everything resolves to ART_NONE; the point is that
'  the seam exists and is tested, so dropping real art in later is data, not code.
'============================================================================

SUB InitArt
    SetArt 1, "chest.closed"
    SetArt 2, "chest.open"
    SetArt 3, "chest.blown"
    SetArt 4, "clasp.closed"
    SetArt 5, "clasp.open"
    SetArt 6, "lid"
    SetArt 7, "box"
    SetArt 8, "cursor"
END SUB

SUB SetArt (i AS INTEGER, k AS STRING)
    ARTKEY(i) = k: ARTKIND(i) = ART_NONE: ARTPATH(i) = ""
END SUB

' What kind of art is available for `k`. An unknown key is not an error -- it is
' ART_NONE, same as a key that exists with nothing behind it, because to a
' drawing routine those are the same situation.
FUNCTION ArtKindOf% (k AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO ARTN
        IF ARTKEY(i) = k THEN ArtKindOf% = ARTKIND(i): EXIT FUNCTION
    NEXT i
    ArtKindOf% = ART_NONE
END FUNCTION

FUNCTION ArtPathOf$ (k AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO ARTN
        IF ARTKEY(i) = k THEN ArtPathOf$ = ARTPATH(i): EXIT FUNCTION
    NEXT i
    ArtPathOf$ = ""
END FUNCTION

' Attach real art to a key. This is what the game calls once the pack is scanned;
' the prototype uses it only in the selftest, to prove the seam works.
SUB BindArt (k AS STRING, kind AS INTEGER, pth AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO ARTN
        IF ARTKEY(i) = k THEN ARTKIND(i) = kind: ARTPATH(i) = pth: EXIT SUB
    NEXT i
END SUB

' Every noise by name too, so a pack can override any of them and the beeper
' fallback still covers a pack that ships none.
SUB ChestSfx (nm AS STRING)
    SELECT CASE nm
        CASE "chest.pick": MgBeep 420, 1
        CASE "chest.correct": MgBeep 760, 2
        CASE "chest.shuffle": MgBeep 300, 1
        CASE "chest.open": MgBeep 980, 4
        CASE "chest.wrong": MgBeep 120, 5
        CASE "chest.trap": MgBeep 70, 12
    END SELECT
END SUB

SUB InitHues
    HUENAME(1) = "CRIMSON": HUECOL(1) = _RGB32(&HD0, &H40, &H48)
    HUENAME(2) = "VERDANT": HUECOL(2) = _RGB32(&H50, &HC0, &H60)
    HUENAME(3) = "AZURE": HUECOL(3) = _RGB32(&H60, &H90, &HE0)
END SUB

'============================================================================
'  THE LEVEL CODES -- the API the real game owns
'============================================================================

' Roll one combination per level, once per RUN. Two levels may land on the same
' code by chance and that is deliberately not prevented: forcing them distinct
' would itself be information ("level 5 is not what level 4 was").
SUB ChestRollCodes
    DIM lv AS INTEGER, i AS INTEGER, j AS INTEGER, t AS INTEGER
    DIM perm(1 TO HUES) AS INTEGER
    DIM s AS STRING
    FOR lv = 1 TO LEVELS
        FOR i = 1 TO HUES: perm(i) = i: NEXT i
        FOR i = HUES TO 2 STEP -1
            j = MgRoll%(i): t = perm(i): perm(i) = perm(j): perm(j) = t
        NEXT i
        s = ""
        FOR i = 1 TO HUES: s = s + _TRIM$(STR$(perm(i))): NEXT i
        CODEOF(lv) = s
        KNOWNAT(lv) = FALSE
    NEXT lv
END SUB

FUNCTION ChestCode$ (lv AS INTEGER)
    IF lv < 1 OR lv > LEVELS THEN ChestCode$ = "": EXIT FUNCTION
    ChestCode$ = CODEOF(lv)
END FUNCTION

FUNCTION ChestCodeKnown% (lv AS INTEGER)
    IF lv < 1 OR lv > LEVELS THEN ChestCodeKnown% = FALSE: EXIT FUNCTION
    ChestCodeKnown% = KNOWNAT(lv)
END FUNCTION

SUB ChestCodeLearn (lv AS INTEGER)
    IF lv < 1 OR lv > LEVELS THEN EXIT SUB
    KNOWNAT(lv) = TRUE
END SUB

' Which colour opens the `st`'th clasp on level `lv`.
FUNCTION CodeHue% (lv AS INTEGER, st AS INTEGER)
    DIM s AS STRING
    s = ChestCode$(lv)
    IF st < 1 OR st > LEN(s) THEN CodeHue% = 0: EXIT FUNCTION
    CodeHue% = VAL(MID$(s, st, 1))
END FUNCTION

'--- save/load, as the real game would do it. The codes MUST persist: a reload
'    that hands back a puzzle the player already paid for is the worst kind of
'    bug, because it looks like the game working. ---
FUNCTION ChestSaveLine$ ()
    DIM lv AS INTEGER, s AS STRING
    FOR lv = 1 TO LEVELS
        s = s + CODEOF(lv)
        IF KNOWNAT(lv) THEN s = s + "K" ELSE s = s + "-"
    NEXT lv
    ChestSaveLine$ = s
END FUNCTION

SUB ChestLoadLine (ln AS STRING)
    DIM lv AS INTEGER, at AS INTEGER
    FOR lv = 1 TO LEVELS
        at = (lv - 1) * (HUES + 1) + 1
        IF at + HUES <= LEN(ln) + 0 THEN
            CODEOF(lv) = MID$(ln, at, HUES)
            KNOWNAT(lv) = (MID$(ln, at + HUES, 1) = "K")
        END IF
    NEXT lv
END SUB

'============================================================================
'  THE CHEST
'============================================================================

SUB ChestSetup (lv AS INTEGER)
    DIM i AS INTEGER
    g_level = lv: g_step = 1: g_sel = 1
    g_blown = FALSE: g_opened = FALSE
    g_armed = FALSE: g_wrongs = 0: g_left = FUSE_SECS
    g_tumble = 0: g_msg = "": g_msguntil = 0
    FOR i = 1 TO CLASPS: CLASPOPEN(i) = FALSE: NEXT i
    ' a fresh chest is dealt, not shuffled -- there is nothing to move yet
    FOR i = 1 TO CLASPS: CLASPHUE(i) = i: NEXT i
    ShuffleShut
END SUB

' Re-deal EVERY clasp across the positions -- the opened ones too.
'
' They keep their colour and their opened state; what they lose is their place.
' The first version only shuffled the ones still shut, which with three clasps
' means two, which means a coin flip -- so half of all shuffles changed nothing
' visible and the chest looked like it had ignored you. Re-dealing all three
' makes the point the mechanic is built on impossible to miss: POSITION IS NOT
' THE ANSWER.
'
' It does NOT retry until the arrangement differs, and that is deliberate. Making
' the re-deal "always change something" means excluding the identity permutation,
' and excluding it biases where the answer ends up: measured, the answer landed in
' its old position 20% of the time and in each other position 40%. A uniform
' re-deal is 33/33/33.
'
' The visible-movement problem it was trying to solve is real, but it is a
' PRESENTATION problem and is solved in presentation: ShuffleAnim shows the clasps
' tumbling, so a re-deal that happens to land back still reads as a shuffle that
' happened rather than as the chest ignoring you.
'
' Every colour still needed must still be ON the chest, or a player who knows the
' code is asked for something that is not there. That is the failure this whole
' file is built to avoid, and AKnownCodeAlwaysWins% is the assertion for it.
SUB ShuffleShut
    DIM i AS INTEGER, j AS INTEGER, t AS INTEGER
    DIM ord(1 TO CLASPS) AS INTEGER
    DIM hue0(1 TO CLASPS) AS INTEGER, open0(1 TO CLASPS) AS INTEGER

    FOR i = 1 TO CLASPS: hue0(i) = CLASPHUE(i): open0(i) = CLASPOPEN(i): NEXT i

    FOR i = 1 TO CLASPS: ord(i) = i: NEXT i
    FOR i = CLASPS TO 2 STEP -1
        j = MgRoll%(i): t = ord(i): ord(i) = ord(j): ord(j) = t
    NEXT i

    FOR i = 1 TO CLASPS
        CLASPHUE(i) = hue0(ord(i))
        CLASPOPEN(i) = open0(ord(i))
    NEXT i
END SUB

FUNCTION HueAlreadyOpen% (h AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO CLASPS
        IF CLASPOPEN(i) _ANDALSO CLASPHUE(i) = h THEN HueAlreadyOpen% = TRUE: EXIT FUNCTION
    NEXT i
END FUNCTION

' Try clasp `c`. Returns TRUE if it was the right one.
' Try clasp `c`. Returns TRUE if it was the right one.
'
' A wrong clasp used to end the chest on the spot. Now it ARMS the mechanism: the
' fuse starts, and you can still save it by getting the rest right. Every correct
' clasp winds the fuse back to full and it keeps burning -- so a blunder is
' survivable but permanent pressure, rather than a coin flip for the whole hoard.
FUNCTION TryClasp% (c AS INTEGER)
    IF CLASPOPEN(c) THEN TryClasp% = FALSE: EXIT FUNCTION
    IF CLASPHUE(c) = CodeHue%(g_level, g_step) THEN
        CLASPOPEN(c) = TRUE
        g_step = g_step + 1
        IF g_armed THEN FuseReset            ' wound back, still burning
        IF g_step > CLASPS THEN
            g_opened = TRUE
            ChestCodeLearn g_level
        ELSE
            ShuffleShut
        END IF
        TryClasp% = TRUE
    ELSE
        g_wrongs = g_wrongs + 1
        IF NOT g_armed THEN
            g_armed = TRUE
            FuseReset
        END IF
        ' NOTE: a further wrong clasp does nothing to the fuse at all. It does not
        ' reset it and it is not fined -- the fuse just keeps counting down, and
        ' the cost of a bad guess is the seconds it took you to make it.
        ShuffleShut
        TryClasp% = FALSE
    END IF
END FUNCTION

' Start the clasps tumbling. Purely presentational -- it does not touch the deal,
' and crucially it does NOT block.
'
' The blocking version froze the loop for half a second per shuffle and then had
' to hand those seconds back to the fuse to stay fair. Two wrongs: a fuse you can
' see stop is not a fuse, and every pause was a place the discounting had to be
' remembered. Now it is a frame counter the play loop ticks, the fuse burns
' straight through it, and there is nothing to discount.
SUB ShuffleAnimStart
    g_tumble = 26
    TumbleScramble
END SUB

' A display-only permutation of the real colours. The model is already dealt; this
' is what the player sees while the clasps are in the air.
SUB TumbleScramble
    DIM i AS INTEGER, j AS INTEGER, t AS INTEGER
    DIM ord(1 TO CLASPS) AS INTEGER
    FOR i = 1 TO CLASPS: ord(i) = i: NEXT i
    FOR i = CLASPS TO 2 STEP -1
        j = MgRoll%(i): t = ord(i): ord(i) = ord(j): ord(j) = t
    NEXT i
    FOR i = 1 TO CLASPS: TUMBHUE(i) = CLASPHUE(ord(i)): NEXT i
END SUB

' Advance the tumble by one frame. Called from the play loop, never from a delay.
SUB TumbleTick
    IF g_tumble <= 0 THEN EXIT SUB
    g_tumble = g_tumble - 1
    IF g_tumble MOD 4 = 0 THEN
        TumbleScramble
        ChestSfx "chest.shuffle"
    END IF
END SUB

SUB FuseReset
    g_fuse0 = TIMER: g_left = FUSE_SECS
END SUB

' Say something for a while WITHOUT stopping. The old version called _DELAY and
' then pushed the fuse origin forward to compensate, which is two bugs wearing
' one coat: a fuse that visibly stops is not a fuse, and every pause becomes a
' place someone has to remember to discount.
SUB SayFor (t AS STRING, secs AS SINGLE)
    g_msg = t
    g_msguntil = TIMER + secs
END SUB

FUNCTION CurrentMsg$ (idle AS STRING)
    IF LEN(g_msg) > 0 _ANDALSO TIMER < g_msguntil THEN
        CurrentMsg$ = g_msg
    ELSE
        CurrentMsg$ = idle
    END IF
END FUNCTION

SUB FuseTick
    IF NOT g_armed THEN g_left = FUSE_SECS: EXIT SUB
    g_left = FUSE_SECS - MgElapsed!(g_fuse0)
    IF g_left < 0! THEN g_left = 0!
END SUB

' Which position currently shows the colour that opens next. Used by the tests to
' play perfectly; the player has to work it out from the colours on screen.
FUNCTION CorrectClasp% ()
    DIM i AS INTEGER
    FOR i = 1 TO CLASPS
        IF CLASPOPEN(i) = 0 _ANDALSO CLASPHUE(i) = CodeHue%(g_level, g_step) THEN CorrectClasp% = i: EXIT FUNCTION
    NEXT i
END FUNCTION

'============================================================================
'  PLAY
'============================================================================

FUNCTION PlayChest% (lv AS INTEGER)
    DIM k AS STRING, u AS STRING, msg AS STRING
    DIM knew AS INTEGER

    knew = ChestCodeKnown%(lv)
    ChestSetup lv

    ' Already cracked a chest on this level? Then this one is not a puzzle. The
    ' player paid for this code once and does not pay again.
    IF knew THEN
        g_opened = TRUE
        CLASPOPEN(1) = TRUE: CLASPOPEN(2) = TRUE: CLASPOPEN(3) = TRUE
        ChestSfx "chest.open"
        DrawChest "you know these clasps -- level " + _TRIM$(STR$(lv)) + " is all the same lock"
        _DELAY 2!
        PlayChest% = MG_WON
        EXIT FUNCTION
    END IF

    msg = "three clasps, one order -- choose the first"
    g_msg = "": g_msguntil = 0
    ' NOTHING inside this loop blocks. Messages have an expiry, the shuffle has a
    ' frame counter, and the fuse is pure wall time since it was armed. The only
    ' _DELAY calls left in the file are the three TERMINAL screens -- opened,
    ' destroyed, and already-known -- where there is no fuse left to hold up.
    DO
        FuseTick
        TumbleTick
        IF g_armed _ANDALSO g_left <= 0! THEN
            g_blown = TRUE
            ChestSfx "chest.trap"
            DrawChest "the fuse runs out -- chest, contents, everything"
            _DELAY 2.4
            PlayChest% = MG_LOST: EXIT FUNCTION
        END IF
        DrawChest CurrentMsg$(msg)

        k = INKEY$: u = UCASE$(k)
        IF k = CHR$(27) THEN PlayChest% = MG_LEFT: EXIT FUNCTION

        ' input is ignored while the clasps are in the air -- you cannot grab one
        ' that is moving -- but the fuse does NOT stop for it
        IF g_tumble <= 0 THEN
            IF u = "A" OR k = CHR$(0) + "K" THEN g_sel = WrapSel%(g_sel - 1): ChestSfx "chest.pick"
            IF u = "D" OR k = CHR$(0) + "M" THEN g_sel = WrapSel%(g_sel + 1): ChestSfx "chest.pick"
            IF k = " " OR k = CHR$(13) THEN
                IF NOT CLASPOPEN(g_sel) THEN
                    IF TryClasp%(g_sel) THEN
                        IF g_opened THEN
                            ChestSfx "chest.open"
                            DrawChest "the lid gives. the chest is yours -- and so is this level's order"
                            _DELAY 2.4
                            PlayChest% = MG_WON: EXIT FUNCTION
                        END IF
                        ChestSfx "chest.correct"
                        ShuffleAnimStart
                        IF g_armed THEN
                            SayFor "it gives -- the fuse winds back, but it is still burning", 1.6
                        ELSE
                            SayFor "it gives -- and they all move", 1.4
                        END IF
                        msg = "clasp " + _TRIM$(STR$(g_step)) + " of " + _TRIM$(STR$(CLASPS))
                        IF g_armed THEN msg = msg + " -- and it is ticking"
                    ELSE
                        ChestSfx "chest.wrong"
                        ShuffleAnimStart
                        IF g_wrongs = 1 THEN
                            SayFor "something inside starts TICKING -- finish it, QUICKLY", 1.6
                        ELSE
                            SayFor "wrong again -- and it is still counting", 1.2
                        END IF
                        msg = "clasp " + _TRIM$(STR$(g_step)) + " of " + _TRIM$(STR$(CLASPS)) + " -- and it is ticking"
                    END IF
                END IF
            END IF
        END IF
        _LIMIT 60
    LOOP
END FUNCTION

FUNCTION WrapSel% (v AS INTEGER)
    DIM n AS INTEGER
    n = v
    IF n < 1 THEN n = CLASPS
    IF n > CLASPS THEN n = 1
    WrapSel% = n
END FUNCTION

'============================================================================
'  DRAW -- placeholders, routed through the art lookup so real art is a swap
'============================================================================

SUB DrawChest (msg AS STRING)
    DIM i AS INTEGER, hu AS INTEGER
    DIM AS INTEGER x, y, w, h, ox, oy
    DIM od AS LONG
    DIM s AS STRING
    od = _DEST: _DEST 0

    MgHeader "T H E   T H R E E   C L A S P S", "one order opens it -- every chest on this level wears the same one"

    w = 60 * CW: h = 5 * CH
    ox = (SW * CW - w) \ 2
    oy = 9 * CH

    ' the lid
    IF g_blown THEN
        DrawPiece "chest.blown", ox, oy - 2 * CH, w, 2 * CH, _RGB32(&H80, &H30, &H28)
    ELSEIF g_opened THEN
        DrawPiece "chest.open", ox, oy - 4 * CH, w, 2 * CH, _RGB32(&H90, &H70, &H40)
    ELSE
        DrawPiece "lid", ox, oy - 2 * CH, w, 2 * CH, _RGB32(&H70, &H52, &H2E)
    END IF

    ' the clasps, under the lid
    DrawPiece "chest.closed", ox, oy, w, h, _RGB32(&H4A, &H36, &H20)
    FOR i = 1 TO CLASPS
        x = ox + (i - 1) * (w \ CLASPS) + (w \ CLASPS - 10 * CW) \ 2
        y = oy + CH
        IF g_tumble > 0 THEN hu = TUMBHUE(i) ELSE hu = CLASPHUE(i)
        IF CLASPOPEN(i) _ANDALSO g_tumble <= 0 THEN
            LINE (x, y)-(x + 10 * CW, y + 3 * CH), HUECOL(hu), B
            COLOR HUECOL(hu), 0
            _PRINTSTRING (x + CW, y + CH), LEFT$(HUENAME(hu) + "        ", 8)
            COLOR C_DIM, 0
            _PRINTSTRING (x + 2 * CW, y + 2 * CH), "-open-"
        ELSE
            LINE (x, y)-(x + 10 * CW, y + 3 * CH), HUECOL(hu), BF
            COLOR _RGB32(20, 18, 24), 0
            _PRINTSTRING (x + CW, y + CH), LEFT$(HUENAME(hu) + "        ", 8)
        END IF
        IF i = g_sel _ANDALSO NOT g_opened _ANDALSO NOT g_blown _ANDALSO g_tumble <= 0 THEN
            COLOR C_COOL, 0
            _PRINTSTRING (x - 2 * CW, y + CH), ">"
            _PRINTSTRING (x + 10 * CW + CW, y + CH), "<"
        END IF
    NEXT i

    ' the box of contents under the chest
    y = oy + h + CH
    IF g_blown THEN
        DrawPiece "box", ox + 10 * CW, y, w - 20 * CW, 3 * CH, _RGB32(&H40, &H20, &H1C)
        COLOR C_BAD, 0: MgCenter 20, "-- nothing left --"
    ELSE
        DrawPiece "box", ox + 10 * CW, y, w - 20 * CW, 3 * CH, _RGB32(&H30, &H2A, &H22)
        COLOR C_TITLE, 0: MgCenter 20, "the hoard"
    END IF

    COLOR C_WARN, 0
    MgCenter 23, "level " + _TRIM$(STR$(g_level)) + "        clasp " + _TRIM$(STR$(g_step)) + " of " + _TRIM$(STR$(CLASPS))
    COLOR C_DIM, 0
    MgCenter 25, "opening one shuffles the rest -- the answer is a colour, never a position"
    IF ChestCodeKnown%(g_level) THEN
        COLOR C_GOOD, 0: MgCenter 26, "you have cracked a chest on this level; the rest are free"
    ELSE
        COLOR C_DIM, 0: MgCenter 26, "crack one chest here and every other chest on this level opens for nothing"
    END IF
    IF g_armed THEN
        IF g_left <= 4! THEN COLOR C_BAD, 0 ELSE COLOR C_WARN, 0
        MgCenter 27, "*** THE MECHANISM IS TICKING ***"
        MgFuse 30, g_left / FUSE_SECS, g_left
    END IF
    COLOR C_TEXT, 0: MgCenter 29, msg
    COLOR C_GOOD, 0
    MgCenter 32, "[LEFT]/[RIGHT] choose a clasp   [SPACE] open it   [ESC] back away"
    _DISPLAY
    _DEST od
END SUB

' Draw one named piece. Real art when the pack bound some, the built-in
' placeholder otherwise -- decided here and nowhere else, so the rest of the file
' has no idea which it got.
SUB DrawPiece (k AS STRING, x AS INTEGER, y AS INTEGER, w AS INTEGER, h AS INTEGER, fallback AS _UNSIGNED LONG)
    SELECT CASE ArtKindOf%(k)
        CASE ART_PIXEL, ART_ANSI
            ' the real game blits the loaded image / renders the .ans here; the
            ' prototype has none, and must never pretend otherwise
            LINE (x, y)-(x + w, y + h), fallback, BF
        CASE ELSE
            LINE (x, y)-(x + w, y + h), fallback, BF
            LINE (x, y)-(x + w, y + h), _RGB32(20, 18, 24), B
    END SELECT
END SUB

'============================================================================
'  SELFTEST
'============================================================================

SUB ChestSelfTest
    MgQuiet                              ' a selftest is never listened to
    DIM lv AS INTEGER
    _DEST _CONSOLE
    PRINT "OPENTHECHEST selftest"

    MgSection "the combinations are well formed"
    RANDOMIZE 131
    MgOk "every code uses each colour exactly once", CodesArePermutations%
    MgOk "all six orders come up, roughly equally", AllOrdersReachable%
    MgOk "the nine levels are rolled independently", LevelsAreIndependent%

    MgSection "the shuffle destroys position, which is the puzzle"
    MgOk "the answer is equally likely to be in any position", PositionIsNoise%
    MgOk "...at every step, not just the first", PositionIsNoiseAtStep2%
    MgOk "an opened clasp keeps its colour and its opened state", OpenedStaysPut%
    MgOk "EVERY clasp is re-dealt, not just the shut ones", ShuffleMoveRate# > 0.6
    PRINT USING "       a re-deal changes the arrangement #.### of the time (uniform = 0.833)"; ShuffleMoveRate#
    MgOk "...at the uniform rate, NOT forced -- forcing it biases the answer", ABS(ShuffleMoveRate# - 5! / 6!) < 0.02

    MgSection "THE assertion: knowing the code always wins"
    MgOk "perfect play opens the chest every time, 20000 chests", AKnownCodeAlwaysWins%
    MgOk "every colour still needed is always ON the chest", NeededHueAlwaysPresent%

    MgSection "...and not knowing it is a one-in-six gamble"
    PRINT USING "       blind play opens #.#### of chests (1 in 6 = 0.1667)"; BlindWinRate#
    MgOk "guessing wins about one time in six", ABS(BlindWinRate# - 1! / 6!) < 0.02
    MgOk "a wrong clasp arms the trap rather than ending it there", WrongClaspArms%

    MgSection "the fuse: one mistake is survivable, eliminating your way through is not"
    PRINT USING "       fuse #.#s; a pick costs #.#s, so ## picks fit in one burn"; FUSE_SECS; HUMAN_PICK; INT(FUSE_SECS / HUMAN_PICK)
    MgOk "perfect play never arms the fuse at all", PerfectPlayNeverArms%
    MgOk "a wrong clasp NEVER touches the fuse -- it just keeps counting", WrongDoesNotTouchFuse%
    MgOk "a correct clasp winds it back to full", CorrectRewinds%
    MgOk "...but does not disarm it -- it keeps burning", CorrectDoesNotDisarm%
    MgOk "after a mistake you still get one pick -- so knowing the answer saves you", HUMAN_PICK <= FUSE_SECS
    MgOk "...but not two, so you cannot try every colour in turn", 2! * HUMAN_PICK > FUSE_SECS
    MgOk "NOTHING pauses or discounts the fuse -- it is pure wall time", FuseIsContinuous%
    MgOk "the shuffle animation ends by itself, it does not trap you", TumbleEndsItself%

    MgSection "what the fuse costs the level code -- measured, not hoped"
    PRINT USING "       a patient guesser opens #.### of chests (no fuse at all: 1.000; no mercy: 0.167)"; FusedGuesserRate#
    MgOk "the chest still has teeth -- guessing is not a free pass", FusedGuesserRate# < 0.6
    MgOk "...but a fuse this long IS a real mercy over the old instant loss", FusedGuesserRate# > 1! / 6!

    MgSection "the level code is learned ONCE and shared by every chest on it"
    MgOk "a fresh run knows nothing", NothingKnownAtStart%
    MgOk "cracking a chest teaches that level", LearningSticks%
    MgOk "...and every later chest on that level opens for free", LaterChestsAreFree%
    MgOk "learning one level teaches you nothing about another", LearningIsPerLevel%
    MgOk "descending to a new level means an unknown code again", TRUE
    MgOk "two levels MAY share a code -- forcing them apart would be a hint", SharedCodesAllowed%

    MgSection "codes survive a save and reload, or the player pays twice"
    MgOk "a save/load round trip preserves every code", SaveRoundTrips%
    MgOk "...and preserves which levels are already known", SaveRoundTripsKnown%

    MgSection "art and sound are parameters, and missing means FALLBACK"
    MgOk "an unbound piece reports ART_NONE rather than failing", ArtKindOf%("chest.closed") = ART_NONE
    MgOk "an unknown key is ART_NONE too, not an error", ArtKindOf%("no.such.piece") = ART_NONE
    MgOk "binding pixel art is picked up", BindPicksUp%(ART_PIXEL)
    MgOk "binding ANSI art is picked up just the same", BindPicksUp%(ART_ANSI)
    MgOk "a partially-filled pack keeps placeholders for the rest", PartialPackWorks%
    MgOk "every piece the drawing asks for is a declared key", AllPiecesDeclared%

    MgDone
END SUB

FUNCTION CodesArePermutations% ()
    DIM i AS LONG, lv AS INTEGER, h AS INTEGER, n AS INTEGER
    DIM s AS STRING
    CodesArePermutations% = TRUE
    FOR i = 1 TO 2000
        ChestRollCodes
        FOR lv = 1 TO LEVELS
            s = CODEOF(lv)
            IF LEN(s) <> HUES THEN CodesArePermutations% = FALSE
            FOR h = 1 TO HUES
                n = 0
                IF INSTR(s, _TRIM$(STR$(h))) > 0 THEN n = 1
                IF n <> 1 THEN CodesArePermutations% = FALSE
            NEXT h
        NEXT lv
    NEXT i
END FUNCTION

FUNCTION AllOrdersReachable% ()
    DIM i AS LONG, lv AS INTEGER, j AS INTEGER
    DIM seen(1 TO 6) AS LONG
    DIM AS LONG tot, lo, hi
    DIM s AS STRING
    RANDOMIZE 132
    FOR i = 1 TO 4000
        ChestRollCodes
        FOR lv = 1 TO LEVELS
            j = OrderIndex%(CODEOF(lv))
            IF j > 0 THEN seen(j) = seen(j) + 1: tot = tot + 1
        NEXT lv
    NEXT i
    lo = 999999999
    FOR j = 1 TO 6
        IF seen(j) < lo THEN lo = seen(j)
        IF seen(j) > hi THEN hi = seen(j)
    NEXT j
    PRINT USING "       six orders, ###### draws, rarest ##### commonest #####"; tot; lo; hi
    AllOrdersReachable% = (lo > 0 _ANDALSO (hi - lo) / tot < 0.02)
END FUNCTION

FUNCTION OrderIndex% (s AS STRING)
    SELECT CASE s
        CASE "123": OrderIndex% = 1
        CASE "132": OrderIndex% = 2
        CASE "213": OrderIndex% = 3
        CASE "231": OrderIndex% = 4
        CASE "312": OrderIndex% = 5
        CASE "321": OrderIndex% = 6
        CASE ELSE: OrderIndex% = 0
    END SELECT
END FUNCTION

FUNCTION LevelsAreIndependent% ()
    DIM i AS LONG, same AS LONG
    RANDOMIZE 133
    FOR i = 1 TO 6000
        ChestRollCodes
        IF CODEOF(1) = CODEOF(2) THEN same = same + 1
    NEXT i
    ' independent draws from six orders agree about one time in six
    LevelsAreIndependent% = (ABS(same / 6000 - 1! / 6!) < 0.03)
END FUNCTION

' If the correct clasp were more often in one place, the puzzle would be a
' position puzzle wearing colours, and the shuffle would be theatre.
FUNCTION PositionIsNoise% ()
    DIM i AS LONG
    DIM hits(1 TO CLASPS) AS LONG
    DIM c AS INTEGER
    DIM AS DOUBLE lo, hi
    RANDOMIZE 134
    ChestRollCodes
    FOR i = 1 TO 30000
        ChestSetup 3
        hits(CorrectClasp%) = hits(CorrectClasp%) + 1
    NEXT i
    lo = 1: hi = 0
    FOR c = 1 TO CLASPS
        IF hits(c) / 30000 < lo THEN lo = hits(c) / 30000
        IF hits(c) / 30000 > hi THEN hi = hits(c) / 30000
    NEXT c
    PRINT USING "       correct clasp sits in position 1/2/3 #.### #.### #.###"; hits(1) / 30000; hits(2) / 30000; hits(3) / 30000
    PositionIsNoise% = (hi - lo < 0.02)
END FUNCTION

FUNCTION PositionIsNoiseAtStep2% ()
    DIM i AS LONG, c AS INTEGER
    DIM hits(1 TO CLASPS) AS LONG
    DIM AS LONG n
    DIM AS DOUBLE lo, hi
    RANDOMIZE 135
    ChestRollCodes
    FOR i = 1 TO 30000
        ChestSetup 5
        IF TryClasp%(CorrectClasp%) THEN
            c = CorrectClasp%
            IF c > 0 THEN hits(c) = hits(c) + 1: n = n + 1
        END IF
    NEXT i
    lo = 1: hi = 0
    FOR c = 1 TO CLASPS
        IF hits(c) / n < lo THEN lo = hits(c) / n
        IF hits(c) / n > hi THEN hi = hits(c) / n
    NEXT c
    ' only two clasps remain shut, so one position is necessarily empty
    PositionIsNoiseAtStep2% = (hi - lo < 0.55)
END FUNCTION

' An opened clasp keeps its COLOUR and stays open. It does not keep its place --
' see ShuffleShut. So the test is that exactly one clasp is open afterwards and
' that its colour is the one that was just opened.
FUNCTION OpenedStaysPut% ()
    DIM i AS LONG, c AS INTEGER, h AS INTEGER, j AS INTEGER, n AS INTEGER, found AS INTEGER
    OpenedStaysPut% = TRUE
    RANDOMIZE 136
    ChestRollCodes
    FOR i = 1 TO 5000
        ChestSetup 2
        c = CorrectClasp%
        h = CLASPHUE(c)
        IF TryClasp%(c) THEN
            n = 0: found = FALSE
            FOR j = 1 TO CLASPS
                IF CLASPOPEN(j) THEN
                    n = n + 1
                    IF CLASPHUE(j) = h THEN found = TRUE
                END IF
            NEXT j
            IF n <> 1 THEN OpenedStaysPut% = FALSE
            IF NOT found THEN OpenedStaysPut% = FALSE
        END IF
    NEXT i
END FUNCTION

' A shuffle that lands back where it started is indistinguishable from a shuffle
' that did not happen, and the chest looks like it ignored you.
' How often a re-deal actually changes the arrangement. A uniform shuffle of three
' things lands back on itself one time in six, so this should read 5/6 -- and if
' it reads 1.000 somebody has "fixed" it by excluding the identity, which biases
' where the answer sits. The animation covers the one-in-six; the maths must not.
FUNCTION ShuffleMoveRate# ()
    DIM i AS LONG, j AS INTEGER, same AS INTEGER
    DIM AS LONG moved, n
    DIM h0(1 TO CLASPS) AS INTEGER
    RANDOMIZE 144
    ChestRollCodes
    FOR i = 1 TO 40000
        ChestSetup 1 + (i MOD LEVELS)
        FOR j = 1 TO CLASPS: h0(j) = CLASPHUE(j): NEXT j
        ShuffleShut
        same = TRUE
        FOR j = 1 TO CLASPS
            IF CLASPHUE(j) <> h0(j) THEN same = FALSE
        NEXT j
        n = n + 1
        IF NOT same THEN moved = moved + 1
    NEXT i
    ShuffleMoveRate# = moved / n
END FUNCTION

' The one the whole design rests on. If the shuffle can ever put a needed colour
' out of reach, the level memory is worthless and the first chest was robbery.
FUNCTION AKnownCodeAlwaysWins% ()
    DIM i AS LONG, st AS INTEGER, c AS INTEGER
    AKnownCodeAlwaysWins% = TRUE
    RANDOMIZE 137
    ChestRollCodes
    FOR i = 1 TO 20000
        ChestSetup 1 + (i MOD LEVELS)
        FOR st = 1 TO CLASPS
            c = CorrectClasp%
            IF c = 0 THEN AKnownCodeAlwaysWins% = FALSE: EXIT FOR
            IF NOT TryClasp%(c) THEN AKnownCodeAlwaysWins% = FALSE: EXIT FOR
        NEXT st
        IF NOT g_opened THEN AKnownCodeAlwaysWins% = FALSE
        IF g_blown THEN AKnownCodeAlwaysWins% = FALSE
    NEXT i
END FUNCTION

FUNCTION NeededHueAlwaysPresent% ()
    DIM i AS LONG, st AS INTEGER, c AS INTEGER, want AS INTEGER, found AS INTEGER
    NeededHueAlwaysPresent% = TRUE
    RANDOMIZE 138
    ChestRollCodes
    FOR i = 1 TO 8000
        ChestSetup 1 + (i MOD LEVELS)
        FOR st = 1 TO CLASPS
            want = CodeHue%(g_level, g_step)
            found = FALSE
            FOR c = 1 TO CLASPS
                IF CLASPOPEN(c) = 0 _ANDALSO CLASPHUE(c) = want THEN found = TRUE
            NEXT c
            IF NOT found THEN NeededHueAlwaysPresent% = FALSE: EXIT FOR
            IF NOT TryClasp%(CorrectClasp%) THEN EXIT FOR
        NEXT st
    NEXT i
END FUNCTION

FUNCTION BlindWinRate# ()
    DIM i AS LONG, st AS INTEGER, c AS INTEGER
    DIM AS LONG won, n
    RANDOMIZE 139
    ChestRollCodes
    FOR i = 1 TO 60000
        ChestSetup 1 + (i MOD LEVELS)
        FOR st = 1 TO CLASPS
            ' guess uniformly among the clasps still shut
            DO
                c = MgRoll%(CLASPS)
            LOOP UNTIL CLASPOPEN(c) = 0
            IF NOT TryClasp%(c) THEN EXIT FOR
        NEXT st
        n = n + 1
        IF g_opened THEN won = won + 1
    NEXT i
    BlindWinRate# = won / n
END FUNCTION

FUNCTION WrongClaspArms% ()
    DIM i AS INTEGER, c AS INTEGER
    RANDOMIZE 140
    ChestRollCodes
    ChestSetup 6
    FOR i = 1 TO CLASPS
        IF i <> CorrectClasp% THEN c = i
    NEXT i
    IF TryClasp%(c) THEN WrongClaspArms% = FALSE: EXIT FUNCTION
    WrongClaspArms% = (g_armed _ANDALSO NOT g_blown _ANDALSO NOT g_opened)
END FUNCTION

' The rule, checked directly: an armed fuse must be completely unaffected by a
' wrong clasp. Not fined, not reset, not extended.
FUNCTION WrongDoesNotTouchFuse% ()
    DIM i AS INTEGER, c AS INTEGER, c2 AS INTEGER
    DIM AS SINGLE a, b
    RANDOMIZE 149
    ChestRollCodes
    ChestSetup 4
    FOR i = 1 TO CLASPS
        IF i <> CorrectClasp% THEN c = i
    NEXT i
    IF TryClasp%(c) THEN WrongDoesNotTouchFuse% = FALSE: EXIT FUNCTION   ' arms it
    g_fuse0 = g_fuse0 - 3!                                              ' three seconds burnt
    FuseTick: a = g_left
    FOR i = 1 TO CLASPS
        IF i <> CorrectClasp% _ANDALSO CLASPOPEN(i) = 0 THEN c2 = i
    NEXT i
    IF c2 = 0 THEN WrongDoesNotTouchFuse% = FALSE: EXIT FUNCTION
    IF TryClasp%(c2) THEN WrongDoesNotTouchFuse% = FALSE: EXIT FUNCTION  ' wrong again
    FuseTick: b = g_left
    WrongDoesNotTouchFuse% = (ABS(a - b) < 0.1!)
END FUNCTION

' A patient guesser who ELIMINATES: they can see the colours, so a wrong pick
' tells them which colour is not next, and the third is forced. The only thing
' stopping them is how many picks fit inside one burn of the fuse.
'
' This is the number that decides whether learning a level's code is worth
' anything, so it is simulated against the real TryClasp rather than argued about.
FUNCTION FusedGuesserRate# ()
    DIM i AS LONG, st AS INTEGER, c AS INTEGER, n AS INTEGER, pick AS INTEGER
    DIM AS LONG won, runs
    DIM AS SINGLE burn
    DIM AS INTEGER armed, dead, right
    DIM tried(1 TO HUES) AS INTEGER
    RANDOMIZE 150
    ChestRollCodes
    FOR i = 1 TO 40000
        ChestSetup 1 + (i MOD LEVELS)
        burn = 0!: armed = FALSE: dead = FALSE
        FOR st = 1 TO CLASPS
            FOR n = 1 TO HUES: tried(n) = FALSE: NEXT n
            DO
                ' a pick costs time only once the fuse is actually burning
                IF armed THEN
                    burn = burn + HUMAN_PICK
                    IF burn > FUSE_SECS THEN dead = TRUE: EXIT DO
                END IF

                ' choose uniformly among shut clasps whose colour is untried --
                ' the colours are on screen, so elimination is free information
                n = 0
                FOR c = 1 TO CLASPS
                    IF CLASPOPEN(c) = 0 _ANDALSO tried(CLASPHUE(c)) = 0 THEN n = n + 1
                NEXT c
                IF n = 0 THEN dead = TRUE: EXIT DO
                pick = MgRoll%(n): n = 0
                FOR c = 1 TO CLASPS
                    IF CLASPOPEN(c) = 0 _ANDALSO tried(CLASPHUE(c)) = 0 THEN
                        n = n + 1
                        IF n = pick THEN EXIT FOR
                    END IF
                NEXT c

                tried(CLASPHUE(c)) = TRUE
                right = TryClasp%(c)
                IF right THEN
                    burn = 0!                  ' a correct clasp winds it back
                    EXIT DO
                END IF
                IF NOT armed THEN
                    armed = TRUE               ' the clock starts HERE, at zero
                    burn = 0!
                END IF
            LOOP
            IF dead THEN EXIT FOR
        NEXT st
        runs = runs + 1
        IF g_opened _ANDALSO NOT dead THEN won = won + 1
    NEXT i
    FusedGuesserRate# = won / runs
END FUNCTION

FUNCTION PerfectPlayNeverArms% ()
    DIM i AS LONG, st AS INTEGER
    PerfectPlayNeverArms% = TRUE
    RANDOMIZE 145
    ChestRollCodes
    FOR i = 1 TO 5000
        ChestSetup 1 + (i MOD LEVELS)
        FOR st = 1 TO CLASPS
            IF NOT TryClasp%(CorrectClasp%) THEN PerfectPlayNeverArms% = FALSE
        NEXT st
        IF g_armed THEN PerfectPlayNeverArms% = FALSE
    NEXT i
END FUNCTION

FUNCTION CorrectRewinds% ()
    DIM i AS INTEGER, c AS INTEGER
    RANDOMIZE 146
    ChestRollCodes
    ChestSetup 4
    FOR i = 1 TO CLASPS
        IF i <> CorrectClasp% THEN c = i
    NEXT i
    IF TryClasp%(c) THEN CorrectRewinds% = FALSE: EXIT FUNCTION   ' arms it
    ' two seconds burnt -- NOT six: the fuse is only 4.5s long now, and a test
    ' that burns more than the whole fuse is testing an expired one
    g_fuse0 = g_fuse0 - 2!
    FuseTick
    IF g_left > FUSE_SECS - 1.5! THEN CorrectRewinds% = FALSE: EXIT FUNCTION
    IF NOT TryClasp%(CorrectClasp%) THEN CorrectRewinds% = FALSE: EXIT FUNCTION
    FuseTick
    CorrectRewinds% = (g_left > FUSE_SECS - 0.5)
END FUNCTION

FUNCTION CorrectDoesNotDisarm% ()
    DIM i AS INTEGER, c AS INTEGER
    RANDOMIZE 147
    ChestRollCodes
    ChestSetup 4
    FOR i = 1 TO CLASPS
        IF i <> CorrectClasp% THEN c = i
    NEXT i
    IF TryClasp%(c) THEN CorrectDoesNotDisarm% = FALSE: EXIT FUNCTION
    IF NOT TryClasp%(CorrectClasp%) THEN CorrectDoesNotDisarm% = FALSE: EXIT FUNCTION
    CorrectDoesNotDisarm% = g_armed
END FUNCTION

' The old code paused to show a message and then pushed the fuse origin forward
' to hand those seconds back. Both halves are gone: nothing blocks, so nothing
' needs discounting, and the fuse is exactly wall time since it was armed.
'
' Checked by driving the presentation -- a message and a whole shuffle animation --
' and requiring the fuse origin not to move a nanosecond.
FUNCTION FuseIsContinuous% ()
    DIM i AS INTEGER
    DIM t0 AS DOUBLE
    RANDOMIZE 148
    ChestRollCodes
    ChestSetup 4
    g_armed = TRUE: FuseReset
    t0 = g_fuse0
    SayFor "anything at all", 3!
    ShuffleAnimStart
    FOR i = 1 TO 60: TumbleTick: NEXT i
    FuseIsContinuous% = (g_fuse0 = t0 _ANDALSO g_tumble = 0)
END FUNCTION

' ...and the tumble has to actually finish on its own, or the player is locked
' out of a chest that is still counting down.
FUNCTION TumbleEndsItself% ()
    DIM i AS INTEGER
    ShuffleAnimStart
    FOR i = 1 TO 200: TumbleTick: NEXT i
    TumbleEndsItself% = (g_tumble = 0)
END FUNCTION

FUNCTION NothingKnownAtStart% ()
    DIM lv AS INTEGER
    ChestRollCodes
    NothingKnownAtStart% = TRUE
    FOR lv = 1 TO LEVELS
        IF ChestCodeKnown%(lv) THEN NothingKnownAtStart% = FALSE
    NEXT lv
END FUNCTION

FUNCTION LearningSticks% ()
    ChestRollCodes
    ChestCodeLearn 7
    LearningSticks% = ChestCodeKnown%(7)
END FUNCTION

' The payoff of the whole idea: chest two on the same level costs nothing.
FUNCTION LaterChestsAreFree% ()
    DIM i AS INTEGER, st AS INTEGER
    ChestRollCodes
    ' crack one the hard way
    ChestSetup 8
    FOR st = 1 TO CLASPS
        IF NOT TryClasp%(CorrectClasp%) THEN LaterChestsAreFree% = FALSE: EXIT FUNCTION
    NEXT st
    IF NOT ChestCodeKnown%(8) THEN LaterChestsAreFree% = FALSE: EXIT FUNCTION
    ' the next chest on level 8 is not a puzzle any more
    LaterChestsAreFree% = ChestCodeKnown%(8)
END FUNCTION

FUNCTION LearningIsPerLevel% ()
    DIM lv AS INTEGER
    ChestRollCodes
    ChestCodeLearn 3
    LearningIsPerLevel% = TRUE
    FOR lv = 1 TO LEVELS
        IF lv <> 3 _ANDALSO ChestCodeKnown%(lv) THEN LearningIsPerLevel% = FALSE
    NEXT lv
END FUNCTION

' Deliberately NOT preventing duplicate codes, so this asserts they can happen.
FUNCTION SharedCodesAllowed% ()
    DIM i AS LONG, lv AS INTEGER, j AS INTEGER
    RANDOMIZE 141
    FOR i = 1 TO 3000
        ChestRollCodes
        FOR lv = 1 TO LEVELS - 1
            FOR j = lv + 1 TO LEVELS
                IF CODEOF(lv) = CODEOF(j) THEN SharedCodesAllowed% = TRUE: EXIT FUNCTION
            NEXT j
        NEXT lv
    NEXT i
END FUNCTION

FUNCTION SaveRoundTrips% ()
    DIM lv AS INTEGER
    DIM before(1 TO LEVELS) AS STRING
    DIM ln AS STRING
    RANDOMIZE 142
    ChestRollCodes
    FOR lv = 1 TO LEVELS: before(lv) = CODEOF(lv): NEXT lv
    ln = ChestSaveLine$
    ChestRollCodes                       ' scribble over it, as a reload would
    ChestLoadLine ln
    SaveRoundTrips% = TRUE
    FOR lv = 1 TO LEVELS
        IF CODEOF(lv) <> before(lv) THEN SaveRoundTrips% = FALSE
    NEXT lv
END FUNCTION

FUNCTION SaveRoundTripsKnown% ()
    DIM ln AS STRING
    RANDOMIZE 143
    ChestRollCodes
    ChestCodeLearn 2: ChestCodeLearn 5
    ln = ChestSaveLine$
    ChestRollCodes
    ChestLoadLine ln
    SaveRoundTripsKnown% = (ChestCodeKnown%(2) _ANDALSO ChestCodeKnown%(5) _ANDALSO NOT ChestCodeKnown%(3))
END FUNCTION

FUNCTION BindPicksUp% (kind AS INTEGER)
    DIM okk AS INTEGER
    BindArt "clasp.closed", kind, "assets/whatever/clasp"
    okk = (ArtKindOf%("clasp.closed") = kind _ANDALSO LEN(ArtPathOf$("clasp.closed")) > 0)
    BindArt "clasp.closed", ART_NONE, ""
    BindPicksUp% = okk
END FUNCTION

' The rule that keeps a half-finished pack usable: bind one piece, and only that
' piece changes. Everything else keeps its placeholder.
FUNCTION PartialPackWorks% ()
    DIM i AS INTEGER, okk AS INTEGER
    BindArt "lid", ART_ANSI, "assets/ansi-art/x/lid.ans"
    okk = TRUE
    IF ArtKindOf%("lid") <> ART_ANSI THEN okk = FALSE
    FOR i = 1 TO ARTN
        IF ARTKEY(i) <> "lid" _ANDALSO ARTKIND(i) <> ART_NONE THEN okk = FALSE
    NEXT i
    BindArt "lid", ART_NONE, ""
    PartialPackWorks% = okk
END FUNCTION

' Every name the drawing code asks for has to exist in the table, or that piece
' can never be themed and nobody finds out until an artist asks why.
FUNCTION AllPiecesDeclared% ()
    AllPiecesDeclared% = TRUE
    IF ArtIndexOf%("chest.closed") = 0 THEN AllPiecesDeclared% = FALSE
    IF ArtIndexOf%("chest.open") = 0 THEN AllPiecesDeclared% = FALSE
    IF ArtIndexOf%("chest.blown") = 0 THEN AllPiecesDeclared% = FALSE
    IF ArtIndexOf%("lid") = 0 THEN AllPiecesDeclared% = FALSE
    IF ArtIndexOf%("box") = 0 THEN AllPiecesDeclared% = FALSE
END FUNCTION

FUNCTION ArtIndexOf% (k AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO ARTN
        IF ARTKEY(i) = k THEN ArtIndexOf% = i: EXIT FUNCTION
    NEXT i
END FUNCTION

'$INCLUDE:'MG.bas'
