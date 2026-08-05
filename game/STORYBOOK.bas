' ============================================================================
'  game/STORYBOOK.bas -- replay any cut-scene you have already seen.
'
'  Built on the Bestiary's pattern deliberately: a lightbar list on the left, a
'  detail panel on the right, and an UNSEEN row still takes a slot -- seeing
'  how much is left to find is half the point of a collection screen. An unseen
'  row shows the right NUMBER of question marks and nothing else, so it cannot
'  leak the title.
'
'  The roster is built by SCANNING the pack's .cut files, not from a hardcoded
'  list. A data pack that ships its own scenes gets its own Storybook for free,
'  and a scene deleted from a pack stops listing instead of becoming a row that
'  cannot be replayed.
' ============================================================================

' ----------------------------------------------------------------------------
'  Build the roster.
'
'  Each scene is COMPILED (not played) to read its `storybook` title/blurb and
'  to find its first `show`, which becomes the row's picture -- so every entry
'  illustrates itself with no extra authoring.
' ----------------------------------------------------------------------------
SUB StorybookScan
    DIM pk AS STRING, f AS STRING, i AS INTEGER

    STORY_N = 0

    '--- the selected pack first, then default. Scanning default SECOND and
    '    skipping duplicates is what makes a pack OVERRIDE a base scene rather
    '    than list alongside it. ---
    pk = _TRIM$(opt_datapack)
    IF LEN(pk) > 0 THEN
        IF LCASE$(pk) <> "default" THEN StorybookScanDir "assets/cutscenes/" + pk + "/"
    END IF
    StorybookScanDir "assets/cutscenes/default/"
    StorybookSort
END SUB

'--- _FILES$ hands back directory order, which reads as random to a player
'    looking for the one they just watched. Sorted by TITLE, not by filename,
'    because the title is what is on screen -- and an unseen row still sorts by
'    its hidden title, so the list does not reshuffle as scenes are unlocked. ---
SUB StorybookSort
    DIM i AS INTEGER, j AS INTEGER
    DIM tn AS STRING, tt AS STRING, tb AS STRING, ta AS STRING

    FOR i = 1 TO STORY_N - 1
        FOR j = 1 TO STORY_N - i
            IF UCASE$(_TRIM$(STORY_TITLE(j))) > UCASE$(_TRIM$(STORY_TITLE(j + 1))) THEN
                tn = STORY_NAME(j): STORY_NAME(j) = STORY_NAME(j + 1): STORY_NAME(j + 1) = tn
                tt = STORY_TITLE(j): STORY_TITLE(j) = STORY_TITLE(j + 1): STORY_TITLE(j + 1) = tt
                tb = STORY_BLURB(j): STORY_BLURB(j) = STORY_BLURB(j + 1): STORY_BLURB(j + 1) = tb
                ta = STORY_ART(j): STORY_ART(j) = STORY_ART(j + 1): STORY_ART(j + 1) = ta
            END IF
        NEXT j
    NEXT i
END SUB

SUB StorybookScanDir (dirpath AS STRING)
    DIM f AS STRING, nm AS STRING, i AS INTEGER, j AS INTEGER, dup AS INTEGER
    DIM names(1 TO STORY_MAX) AS STRING
    DIM n AS INTEGER

    IF NOT _DIREXISTS(dirpath) THEN EXIT SUB

    '--- collect the names FIRST. _FILES$ cannot be re-entered while its walk
    '    is being consumed, and compiling a scene reads files. ---
    f = _FILES$(dirpath + "*.cut")
    DO WHILE LEN(f) > 0
        '--- a leading underscore marks a FRAGMENT meant to be `include`d, not
        '    a scene. Listing one would put an unplayable row in the Storybook
        '    and, worse, a row that can never be un-mysteried. ---
        IF LEFT$(f, 1) <> "_" THEN
            IF n < STORY_MAX THEN n = n + 1: names(n) = f
        END IF
        f = _FILES$
    LOOP

    FOR i = 1 TO n
        nm = names(i)
        IF INSTR(LCASE$(nm), ".cut") > 1 THEN nm = LEFT$(nm, INSTR(LCASE$(nm), ".cut") - 1)

        '--- a separate flag, NOT the loop variable: after a FOR that never
        '    ran, the counter is still 0, and `0 <= STORY_N` would read as
        '    "duplicate" and skip the very first scene forever. ---
        dup = FALSE
        FOR j = 1 TO STORY_N
            IF LCASE$(_TRIM$(STORY_NAME(j))) = LCASE$(nm) THEN dup = TRUE: EXIT FOR
        NEXT j
        IF dup THEN _CONTINUE                     ' a pack already provided this one

        IF STORY_N >= STORY_MAX THEN EXIT FOR
        STORY_N = STORY_N + 1
        STORY_NAME(STORY_N) = nm

        IF CutCompile%(dirpath + names(i)) THEN
            '--- a `dev` scene is a showcase; it belongs in the repo and in the
            '    gate, not in a record of what happened to the player ---
            IF CUT_DEV THEN
                STORY_N = STORY_N - 1
                _CONTINUE
            END IF
            IF LEN(CUT_SBTITLE) > 0 THEN
                STORY_TITLE(STORY_N) = CUT_SBTITLE
            ELSE
                STORY_TITLE(STORY_N) = StoryPrettyName$(nm)
            END IF
            STORY_BLURB(STORY_N) = CUT_SBBLURB
            STORY_ART(STORY_N) = StoryFirstArt$
        ELSE
            '--- a scene that will not compile still LISTS, marked, rather than
            '    disappearing: a missing row is invisible, and invisible is
            '    exactly how a broken pack would hide from its author. ---
            STORY_TITLE(STORY_N) = StoryPrettyName$(nm)
            STORY_BLURB(STORY_N) = "(this scene has an error and cannot play)"
            STORY_ART(STORY_N) = ""
        END IF
    NEXT i
END SUB

'--- "chamber-the-crypt" -> "The Crypt";  "win" -> "Win" ---
FUNCTION StoryPrettyName$ (nm AS STRING)
    DIM s AS STRING, o AS STRING, i AS INTEGER, chx AS STRING, up AS INTEGER
    s = LCASE$(_TRIM$(nm))
    IF LEFT$(s, 8) = "chamber-" THEN s = MID$(s, 9)
    up = TRUE
    FOR i = 1 TO LEN(s)
        chx = MID$(s, i, 1)
        IF chx = "-" _ORELSE chx = "_" THEN
            o = o + " "
            up = TRUE
        ELSE
            IF up THEN o = o + UCASE$(chx) ELSE o = o + chx
            up = FALSE
        END IF
    NEXT i
    StoryPrettyName$ = o
END FUNCTION

'--- the first image the compiled scene shows, used as the row's picture ---
FUNCTION StoryFirstArt$
    DIM i AS INTEGER
    FOR i = 1 TO CUT_NOP
        IF CUT_OPS(i).cmd = OP_SHOW THEN
            StoryFirstArt$ = CutStrGet$(CUT_OPS(i).s2)
            EXIT FUNCTION
        END IF
    NEXT i
    StoryFirstArt$ = ""
END FUNCTION

' ----------------------------------------------------------------------------
'  The screen
' ----------------------------------------------------------------------------
SUB ShowStorybook
    DIM sel AS INTEGER, k AS STRING

    StorybookScan
    PlayCue "bestiary", -1                  ' same reflective cue as the Bestiary
    sel = 1

    DO
        StorybookPaint sel
        Present
        AudioTick

        k = NormKey$(UCASE$(INKEY$))
        IF k = "W" THEN sel = sel - 1: IF sel < 1 THEN sel = STORY_N
        IF k = "S" THEN sel = sel + 1: IF sel > STORY_N THEN sel = 1
        IF k = CHR$(27) THEN EndCue: EXIT SUB
        IF k = " " _ORELSE k = CHR$(13) THEN
            IF sel >= 1 _ANDALSO sel <= STORY_N THEN
                IF CutsceneSeen%(_TRIM$(STORY_NAME(sel))) THEN
                    StorybookReplay _TRIM$(STORY_NAME(sel))
                    sel = StoryIndexOf%(_TRIM$(STORY_NAME(sel)))
                    IF sel < 1 THEN sel = 1
                END IF
            END IF
        END IF
    LOOP
END SUB

'--- PAINT ONLY: no input, no waiting, no board repaint. Split out so the
'    screen can be shot headlessly (`dungeon.run storyshot`) -- a collection
'    screen only breaks when it is FULL, or when it is empty, and neither
'    state shows up by opening it once during a normal run. ---
SUB StorybookPaint (sel AS INTEGER)
    DIM i AS INTEGER, y AS INTEGER, seen AS INTEGER, nseen AS INTEGER
    DIM sp AS STRING, top AS INTEGER, rows AS INTEGER

    rows = 34
    _DEST CANVAS
    IF ListPanel%("storybook", 4, 3, 124, 44, CYANU) = 0 THEN
        LINE (4 * CW, 3 * CH)-(128 * CW, 47 * CH), BOXBG, BF
        LINE (4 * CW, 3 * CH)-(128 * CW, 47 * CH), CYANU, B
    END IF
    COLOR YELLOWU, BOXBG: PrintCentered 4, "-=  S T O R Y B O O K  =-"

    IF STORY_N = 0 THEN
        COLOR GREY, BOXBG
        PrintCentered 22, "This pack ships no cut-scenes."
        PrintCentered 24, "Drop a .cut file in assets/cutscenes/ and it will appear here."
        COLOR YELLOWU, BOXBG: PrintCentered 45, "[ESC] back"
        EXIT SUB
    END IF

    FOR i = 1 TO STORY_N
        IF CutsceneSeen%(_TRIM$(STORY_NAME(i))) THEN nseen = nseen + 1
    NEXT i

    '--- scroll so the selection stays visible once the roster outgrows the
    '    panel, which 12 chambers plus the set pieces already do ---
    top = 1
    IF sel > rows THEN top = sel - rows + 1

    FOR i = top TO STORY_N
        y = 7 + (i - top)
        IF y > 6 + rows THEN EXIT FOR
        seen = CutsceneSeen%(_TRIM$(STORY_NAME(i)))
        IF i = sel THEN
            COLOR WHITE, REDU
        ELSEIF seen THEN
            COLOR GREENU, BOXBG
        ELSE
            COLOR GREY, BOXBG
        END IF
        IF seen THEN
            _PRINTSTRING (7 * CW, y * CH), PadR$("  " + _TRIM$(STORY_TITLE(i)), 26)
        ELSE
            '--- the right NUMBER of question marks, never the title ---
            _PRINTSTRING (7 * CW, y * CH), PadR$("  " + STRING$(LEN(_TRIM$(STORY_TITLE(i))), 63), 26)
        END IF
    NEXT i

    IF sel >= 1 AND sel <= STORY_N THEN
        seen = CutsceneSeen%(_TRIM$(STORY_NAME(sel)))
        IF seen THEN
            sp = _TRIM$(STORY_ART(sel))
            IF LEN(sp) > 0 THEN
                sp = Game_CutArtPath$(sp)
                IF LEN(sp) > 0 THEN CombatArtBox sp, 38, 34, 7, 17, "-= " + _TRIM$(STORY_TITLE(sel)) + " =-", CYANU
            END IF
            y = 26
            COLOR CYANU, BOXBG: _PRINTSTRING (38 * CW, y * CH), _TRIM$(STORY_TITLE(sel))
            y = y + 2
            COLOR GREY, BOXBG
            IF LEN(_TRIM$(STORY_BLURB(sel))) > 0 THEN _PRINTSTRING (38 * CW, y * CH), _TRIM$(STORY_BLURB(sel))
            y = y + 3
            COLOR GREENU, BOXBG: _PRINTSTRING (38 * CW, y * CH), "SEEN"
            y = y + 2
            COLOR YELLOWU, BOXBG: _PRINTSTRING (38 * CW, y * CH), "[ENTER] watch it again"
        ELSE
            MysteryBox 38, 34, 7, 17
            y = 26
            COLOR GREY, BOXBG: _PRINTSTRING (38 * CW, y * CH), "NOT YET SEEN"
            y = y + 2
            _PRINTSTRING (38 * CW, y * CH), "This one has not happened to you."
            y = y + 2
            _PRINTSTRING (38 * CW, y * CH), "Play it in the dungeon and it will"
            y = y + 1
            _PRINTSTRING (38 * CW, y * CH), "be here afterwards, for good."
        END IF
    END IF

    COLOR GREY, BOXBG
    PrintCentered 43, LTRIM$(STR$(nseen)) + " of " + LTRIM$(STR$(STORY_N)) + " scenes remembered"
    COLOR YELLOWU, BOXBG: PrintCentered 45, "[Up/Down] browse   [ENTER] replay   [ESC] back"
END SUB

'--- playing a scene RECOMPILES over CUT_OPS, which is the same array the
'    roster was read from. Rebuild it afterwards rather than trusting what is
'    left behind. ---
SUB StorybookReplay (nm AS STRING)
    DIM ok AS INTEGER
    EndCue
    ok = PlayCutsceneEx%(nm, FALSE)
    StorybookScan
    PlayCue "bestiary", -1
END SUB

FUNCTION StoryIndexOf% (nm AS STRING)
    DIM i AS INTEGER
    FOR i = 1 TO STORY_N
        IF LCASE$(_TRIM$(STORY_NAME(i))) = LCASE$(_TRIM$(nm)) THEN StoryIndexOf% = i: EXIT FUNCTION
    NEXT i
    StoryIndexOf% = 0
END FUNCTION
