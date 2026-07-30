' ============================================================================
'  LAYOUT.bas -- ENGINE named-region screen layout (game-agnostic).
'
'  A screen is described as DATA: a list of named rectangles in CHARACTER CELLS. Drawing
'  code asks for a region by NAME ("enemy1.art", "log.body") instead of hardcoding
'  coordinates, so the whole screen can be rearranged by editing a text file -- which is
'  what makes it practical to iterate on placement against a hand-drawn mockup.
'
'  Why cells and not pixels: the art is text-mode, so everything is naturally cell-aligned,
'  and a layout stays correct if the font cell changes. Each region carries its own
'  intended CELL SIZE (cw/ch) because one screen can mix metrics -- the tactical fight
'  screen is 132x100 on an 8x8 cell while the board is 132x51 on 8x16, both on the same
'  1056-wide canvas.
'
'  A `kind` column tags what belongs in a region (art / text / box / bar / menu / log).
'  The engine does not act on it -- it is for the renderer to dispatch on and for a linter
'  to sanity-check, exactly like the `kind` column in the game's trap/curio/chamber tables.
'
'  Reusable: nothing here knows about combat, monsters or DUNGEON!. Any screen can be
'  described this way.
' ============================================================================

' Load a layout file:  name | col | row | cols | rows | kind | note
' Blank lines and #-comments are skipped by ReadDataFile. Returns the region count.
' A missing file yields 0 regions -- callers should treat that as "no layout" rather than
' crashing, so a data pack shipping no layout degrades instead of dying.
' NOTE: params are cellw/cellh, NOT cw/ch -- those would case-insensitively shadow the
' shared CW/CH font metrics for this whole FUNCTION (tests/audit-shadow.sh caught it).
FUNCTION LoadLayout% (path AS STRING, cellw AS INTEGER, cellh AS INTEGER)
    DIM i AS INTEGER, nm AS STRING
    LAY_N = 0
    ReadDataFile path
    FOR i = 1 TO DLINE_N
        nm = DField$(DLINE(i), 1)
        IF LEN(nm) > 0 AND LAY_N < LAY_MAX THEN
            LAY_N = LAY_N + 1
            LAY_NAME(LAY_N) = LCASE$(nm)                  ' lookup is case-insensitive
            LAY_COL(LAY_N) = VAL(DField$(DLINE(i), 2))
            LAY_ROW(LAY_N) = VAL(DField$(DLINE(i), 3))
            LAY_W(LAY_N) = VAL(DField$(DLINE(i), 4))
            LAY_H(LAY_N) = VAL(DField$(DLINE(i), 5))
            LAY_KIND(LAY_N) = LCASE$(DField$(DLINE(i), 6))
            LAY_NOTE(LAY_N) = DField$(DLINE(i), 7)
            LAY_CW(LAY_N) = cellw: LAY_CH(LAY_N) = cellh
        END IF
    NEXT i
    LoadLayout% = LAY_N
END FUNCTION

' Index of a named region, or 0 if absent. Callers MUST handle 0 -- a typo'd region name
' is the most likely layout error, and silently drawing at (0,0) hides it.
FUNCTION LayFind% (nm AS STRING)
    DIM i AS INTEGER, t AS STRING
    LayFind% = 0
    t = LCASE$(_TRIM$(nm))
    FOR i = 1 TO LAY_N
        IF _TRIM$(LAY_NAME(i)) = t THEN LayFind% = i: EXIT FUNCTION
    NEXT i
END FUNCTION

' Region geometry in PIXELS, using that region's own cell size. 0 for an unknown region.
FUNCTION LayPX% (nm AS STRING)
    DIM i AS INTEGER
    i = LayFind%(nm): IF i > 0 THEN LayPX% = LAY_COL(i) * LAY_CW(i)
END FUNCTION

FUNCTION LayPY% (nm AS STRING)
    DIM i AS INTEGER
    i = LayFind%(nm): IF i > 0 THEN LayPY% = LAY_ROW(i) * LAY_CH(i)
END FUNCTION

FUNCTION LayPW% (nm AS STRING)
    DIM i AS INTEGER
    i = LayFind%(nm): IF i > 0 THEN LayPW% = LAY_W(i) * LAY_CW(i)
END FUNCTION

FUNCTION LayPH% (nm AS STRING)
    DIM i AS INTEGER
    i = LayFind%(nm): IF i > 0 THEN LayPH% = LAY_H(i) * LAY_CH(i)
END FUNCTION

' Region geometry in CELLS (for _PRINTSTRING-style placement).
FUNCTION LayC% (nm AS STRING)
    DIM i AS INTEGER
    i = LayFind%(nm): IF i > 0 THEN LayC% = LAY_COL(i)
END FUNCTION

FUNCTION LayR% (nm AS STRING)
    DIM i AS INTEGER
    i = LayFind%(nm): IF i > 0 THEN LayR% = LAY_ROW(i)
END FUNCTION

FUNCTION LayCols% (nm AS STRING)
    DIM i AS INTEGER
    i = LayFind%(nm): IF i > 0 THEN LayCols% = LAY_W(i)
END FUNCTION

FUNCTION LayRows% (nm AS STRING)
    DIM i AS INTEGER
    i = LayFind%(nm): IF i > 0 THEN LayRows% = LAY_H(i)
END FUNCTION

' A region name with an index substituted for '#' -- "enemy#.art" + 3 -> "enemy3.art".
' Lets one loop drive four enemy panels without four sets of hardcoded names.
FUNCTION LayN$ (pattern AS STRING, idx AS INTEGER)
    LayN$ = SubstAll$(pattern, "#", _TRIM$(STR$(idx)))
END FUNCTION

' Does this region exist? Sugar for readability at call sites.
FUNCTION LayHas% (nm AS STRING)
    IF LayFind%(nm) > 0 THEN LayHas% = -1 ELSE LayHas% = 0
END FUNCTION
