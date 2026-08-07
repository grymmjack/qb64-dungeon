$CONSOLE:ONLY
'$INCLUDE:'TESTLIB.bi'
'$INCLUDE:'../engine/ENGINE.BI'

' ============================================================================
'  engine/LAYOUT.bas -- named screen regions loaded from data.
'
'  Two halves, and the second is the one that earns its keep:
'
'  (1) The API contract. The important clause is that EVERY accessor returns 0 for an
'      unknown region. A typo'd region name is the most likely layout error there is, and
'      the failure mode is silent: the caller draws at (0,0) with size 0 and simply sees
'      nothing. So "unknown name yields 0, never a crash and never a wrong rectangle" is
'      asserted for all eight accessors, not assumed.
'
'  (2) The REAL shipped layout's invariants. assets/data/default/ui-fight-layout.txt is
'      the contract between the code and the hand-drawn art -- `dungeon.run fightmanifest`
'      derives its generation sizes from it, so if a future edit desyncs the four enemy
'      panels or pushes a region off-screen, art gets authored to a size that cannot fit
'      and NOTHING reports it until a portrait draws wrong on screen. The `fightlayout`
'      lint catches that too, but only if someone runs it -- these assertions run in the
'      gate whether anyone remembers or not.
'
'  Paths here are REPO-ROOT-relative because T_Begin normalises the cwd to the repo root
'  (TESTLIB.bas: `IF _FILEEXISTS("dungeon.bas") = 0 THEN CHDIR ".."`). That is deliberate:
'  a suite then names assets exactly as the game does, so the real layout is loaded through
'  its LOGICAL path and DataPath$ resolves the pack -- the same code path as a real launch.
' ============================================================================

T_Begin "engine/LAYOUT.bas"

DIM n AS INTEGER, i AS INTEGER, bad AS INTEGER, f AS INTEGER
DIM fx AS STRING, pw AS INTEGER, ph AS INTEGER

'--- a tiny fixture, so the API tests do not depend on the game's real layout ---
fx = "tests/tmp/layout-fixture.txt"
IF NOT _DIREXISTS("tests/tmp") THEN MKDIR "tests/tmp"
f = FREEFILE
OPEN fx FOR OUTPUT AS #f
PRINT #f, "# comment line, must be skipped"
PRINT #f, ""
PRINT #f, "hero.art   |  4 |  2 | 10 |  6 | art  | a portrait box"
PRINT #f, "MixedCase  | 20 | 30 |  5 |  1 | text | name lookup is case-insensitive"
PRINT #f, "  padded   |  1 |  1 |  2 |  2 | bar  | fields may be space-padded"
CLOSE #f

T_Group "LoadLayout% -- reads the file, skips comments and blanks"
n = LoadLayout%(fx, 8, 8)
T_EqI "3 regions loaded (comment + blank skipped)", n, 3
T_EqI "  LAY_N agrees with the return value", LAY_N, 3

T_Group "LayFind% -- lookup is case-insensitive and whitespace-tolerant"
T_True "exact name found", LayFind%("hero.art") > 0
T_True "lookup by different case", LayFind%("HERO.ART") > 0
T_True "region authored MixedCase found lowercase", LayFind%("mixedcase") > 0
T_True "name with surrounding spaces found", LayFind%("  hero.art  ") > 0
T_True "space-padded FIELD was trimmed on load", LayFind%("padded") > 0
T_EqI "unknown name returns 0, not a match", LayFind%("nope.nothing"), 0

T_Group "cell accessors return what was authored"
T_EqI "col", LayC%("hero.art"), 4
T_EqI "row", LayR%("hero.art"), 2
T_EqI "cols", LayCols%("hero.art"), 10
T_EqI "rows", LayRows%("hero.art"), 6

T_Group "pixel accessors scale by the region's OWN cell size"
T_EqI "px = col * cellw", LayPX%("hero.art"), 32
T_EqI "py = row * cellh", LayPY%("hero.art"), 16
T_EqI "pw = cols * cellw", LayPW%("hero.art"), 80
T_EqI "ph = rows * cellh", LayPH%("hero.art"), 48
' Reload on a 8x16 cell: the SAME layout must report different pixels, which is the whole
' reason cell size is stored per-region rather than assumed globally.
n = LoadLayout%(fx, 8, 16)
T_EqI "same region on a 8x16 cell doubles py", LayPY%("hero.art"), 32
T_EqI "  and doubles ph", LayPH%("hero.art"), 96
T_EqI "  but leaves px alone (width unchanged)", LayPX%("hero.art"), 32
n = LoadLayout%(fx, 8, 8)

T_Group "an unknown region yields 0 from EVERY accessor (no crash, no phantom rect)"
bad = 0
IF LayC%("ghost") <> 0 THEN bad = -1
IF LayR%("ghost") <> 0 THEN bad = -1
IF LayCols%("ghost") <> 0 THEN bad = -1
IF LayRows%("ghost") <> 0 THEN bad = -1
IF LayPX%("ghost") <> 0 THEN bad = -1
IF LayPY%("ghost") <> 0 THEN bad = -1
IF LayPW%("ghost") <> 0 THEN bad = -1
IF LayPH%("ghost") <> 0 THEN bad = -1
T_False "all 8 accessors return 0 for a name that is not there", bad
T_False "LayHas% is FALSE for an unknown region", LayHas%("ghost")
T_True "LayHas% is TRUE for a known region", LayHas%("hero.art")

T_Group "LayN$ -- one loop can drive N indexed panels"
T_EqS "# becomes the index", LayN$("enemy#.art", 3), "enemy3.art"
T_EqS "every # is substituted", LayN$("p#.slot#", 2), "p2.slot2"
T_EqS "a pattern with no # is unchanged", LayN$("log.body", 1), "log.body"

T_Group "a missing file degrades to 0 regions instead of dying"
' The documented contract: a data pack that ships no layout must not crash the game.
n = LoadLayout%("tests/tmp/definitely-not-here.txt", 8, 8)
T_EqI "missing file loads 0 regions", n, 0
T_EqI "  and clears LAY_N", LAY_N, 0
T_EqI "  so every lookup misses cleanly", LayFind%("hero.art"), 0

' ============================================================================
'  The real shipped fight layout. These are the assertions that protect the ART.
' ============================================================================
'--- The REAL layout, resolved exactly as the game resolves it. DeclareAssetTree
'    has to run first: the engine keeps no built-in idea of where assets live, so
'    with nothing declared DataPath$ correctly passes the path straight through
'    and the file is looked for one directory above where packs actually put it. ---
DeclareAssetTree
T_Group "assets/data/ui-fight-layout.txt -- the real layout loads (via DataPath$)"
opt_datapack = "default"
n = LoadLayout%("assets/data/ui-fight-layout.txt", 8, 8)
T_True "the shipped fight layout loads regions (" + _TRIM$(STR$(n)) + ")", n > 0
T_True "it declares a 'screen' region", LayHas%("screen")
T_EqI "screen is 132 cols", LayCols%("screen"), 132
T_EqI "screen is 100 rows", LayRows%("screen"), 100
' The fight screen must FIT INSIDE the existing board canvas, or entering a fight would need
' a window resize / re-fullscreen instead of just a redraw. Board CANVAS is 132x51 @8x16 =
' 1056x816; the fight screen is 132x100 @8x8 = 1056x800 -- exactly as wide, and 16px SHORTER
' (two 8px rows spare at the bottom). Same width is what matters most: a differing width would
' letterbox horizontally, where the four 33-col panels are pitched.
T_EqI "screen is 1056 px wide -- exactly the board canvas width", LayPW%("screen"), 1056
T_EqI "screen is 800 px tall", LayPH%("screen"), 800
T_True "fight screen fits inside the 1056x816 board canvas", LayPW%("screen") <= 1056 AND LayPH%("screen") <= 816

T_Group "every region fits entirely inside the screen"
bad = 0
FOR i = 1 TO LAY_N
    IF LAY_W(i) <= 0 OR LAY_H(i) <= 0 THEN bad = -1
    IF LAY_COL(i) < 0 OR LAY_ROW(i) < 0 THEN bad = -1
    IF LAY_COL(i) + LAY_W(i) > 132 THEN bad = -1
    IF LAY_ROW(i) + LAY_H(i) > 100 THEN bad = -1
NEXT i
T_False "no region is off-screen or zero-sized", bad

T_Group "all four enemy panels are identical in size and evenly pitched"
' The manifest publishes ONE portrait size for all four foes. If the panels ever differ,
' generated art fits some slots and not others -- and the manifest would not know.
bad = 0
FOR i = 1 TO 4
    IF LayHas%(LayN$("enemy#.art", i)) = 0 THEN bad = -1
NEXT i
T_False "enemy1..4.art all exist", bad
bad = 0
pw = LayCols%("enemy1.art"): ph = LayRows%("enemy1.art")
FOR i = 2 TO 4
    IF LayCols%(LayN$("enemy#.art", i)) <> pw THEN bad = -1
    IF LayRows%(LayN$("enemy#.art", i)) <> ph THEN bad = -1
    IF LayR%(LayN$("enemy#.art", i)) <> LayR%("enemy1.art") THEN bad = -1
NEXT i
T_False "all four foe portraits are the same size and on the same row", bad
T_EqI "the panels are on a 33-col pitch (2)", LayC%("enemy2.art") - LayC%("enemy1.art"), 33
T_EqI "the panels are on a 33-col pitch (3)", LayC%("enemy3.art") - LayC%("enemy2.art"), 33
T_EqI "the panels are on a 33-col pitch (4)", LayC%("enemy4.art") - LayC%("enemy3.art"), 33
T_EqI "4 panels x 33 cols exactly fills 132", 4 * 33, 132

T_Group "the player portrait matches a foe portrait, so art is interchangeable"
T_True "player.art exists", LayHas%("player.art")
T_EqI "player portrait is the same width as a foe's", LayCols%("player.art"), pw
T_EqI "player portrait is the same height as a foe's", LayRows%("player.art"), ph
T_EqI "  which the manifest publishes as 33 cols", pw, 33
T_EqI "  and 25 rows", ph, 25
T_EqI "  = 264 px wide", LayPW%("player.art"), 264
T_EqI "  = 200 px tall", LayPH%("player.art"), 200

T_Group "no two ART regions overlap (one portrait would paint over another)"
bad = 0
FOR i = 1 TO LAY_N
    IF LAY_KIND(i) = "art" THEN
        FOR f = i + 1 TO LAY_N
            IF LAY_KIND(f) = "art" THEN
                IF LAY_COL(i) < LAY_COL(f) + LAY_W(f) AND LAY_COL(f) < LAY_COL(i) + LAY_W(i) THEN
                    IF LAY_ROW(i) < LAY_ROW(f) + LAY_H(f) AND LAY_ROW(f) < LAY_ROW(i) + LAY_H(i) THEN bad = -1
                END IF
            END IF
        NEXT f
    END IF
NEXT i
T_False "art regions are mutually exclusive", bad

T_Group "the regions the fight renderer and manifest depend on by name all exist"
' A missing name here draws nothing and reports nothing -- so name them explicitly.
bad = 0
IF LayHas%("top.round") = 0 THEN bad = -1
IF LayHas%("top.init") = 0 THEN bad = -1
IF LayHas%("menu.root") = 0 THEN bad = -1
IF LayHas%("menu.sub") = 0 THEN bad = -1
IF LayHas%("log.body") = 0 THEN bad = -1
IF LayHas%("dice.tray") = 0 THEN bad = -1
IF LayHas%("player.gauge") = 0 THEN bad = -1
IF LayHas%("player.name") = 0 THEN bad = -1
IF LayHas%("player.stats") = 0 THEN bad = -1
IF LayHas%("banner") = 0 THEN bad = -1
T_False "all named-by-code regions present", bad
bad = 0
FOR i = 1 TO 4
    IF LayHas%(LayN$("enemy#.name", i)) = 0 THEN bad = -1
    IF LayHas%(LayN$("enemy#.hpbar", i)) = 0 THEN bad = -1
    IF LayHas%(LayN$("enemy#.gauge", i)) = 0 THEN bad = -1
NEXT i
T_False "per-foe name/hpbar/gauge present for all 4 seats", bad

T_Group "every region carries a known kind"
' `fightlayout` draws an unknown kind in red; here it is an outright failure, since a
' misspelt kind silently opts a region out of the art-overlap check above.
bad = 0
FOR i = 1 TO LAY_N
    SELECT CASE LAY_KIND(i)
        CASE "art", "text", "box", "bar", "menu", "log"      ' the documented set
        CASE ELSE: bad = -1
    END SELECT
NEXT i
T_False "no region has a misspelt or missing kind", bad

T_Done

' --- stubbed collaborator ---------------------------------------------------
' LAYOUT.bas loads through engine/DATA.bas's ReadDataFile, and DATA.bas's pack-cycling
' half reaches for Sfx (engine/UI.bas). engine->engine, so not boundary debt -- but
' pulling UI in would drag the whole audio stack into a geometry test. Nothing under
' test calls it. (Same stub as TEST-DATA.bas.)
SUB Sfx (kind AS STRING)
END SUB

'$INCLUDE:'TESTLIB.bas'
'$INCLUDE:'../engine/ASSETS.bas'
'$INCLUDE:'../game/ASSETTREE.bas'   ' the game's own tree, so the suite resolves paths as the game does   ' the path registry -- DATA/ARTPACK/UI all ask it for kinds
'$INCLUDE:'../engine/TEXT.bas'
'$INCLUDE:'../engine/DATA.bas'
'$INCLUDE:'../engine/LAYOUT.bas'
