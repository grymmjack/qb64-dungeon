' ============================================================================
'  engine/ASSETS.bas -- WHERE THE FUEL IS. The engine's path registry.
'
'  The game is the assembly of the engine's parts, driven by the gas of the
'  assets -- and a part that knows the shape of one particular fuel tank is not
'  a part, it is a fitting. Before this, engine/ hardcoded ~50 literal paths
'  into DUNGEON!'s tree: "assets/data/", "assets/pixel-art/",
'  "assets/music/default/playlist.txt". Copy engine/ into another project and it
'  goes looking for a tree that is not there.
'
'  Note that tests/audit-boundary.sh passed the whole time. It checks that
'  engine/ names no game SYMBOL, and a hardcoded path is the same violation
'  wearing different clothes -- the engine depending on something only this game
'  has. audit-paths.sh is the sibling rule.
'
'  So the ASSEMBLY declares its tree once, and the engine asks for KINDS:
'
'      AssetRoot "assets/"
'      AssetKind "data",     "data/"
'      AssetKind "pixelart", "pixel-art/"
'      AssetKind "music",    "music/"
'
'      ' ...and engine code only ever writes:
'      p = AssetPath$("data", "strings.txt")
'
'  A different game declares a different tree and not one line of engine/
'  changes.
'
'  NO DEFAULTS ON PURPOSE. It would be easy to have this fall back to "assets/"
'  and the names DUNGEON! happens to use, and everything would keep working --
'  which is exactly the problem: the engine would still know this game's layout,
'  and nobody would ever find out, because nothing would break. An undeclared
'  kind is recorded instead (see AssetMissing$) so `assetlint` and `dump assets`
'  can say so out loud.
'
'  Dependency-free by design: pure string work, no reader, no image, no sound.
'  ARTPACK and DATA are compiled IN ISOLATION by their unit suites and both need
'  this, so it can depend on nothing they do not already have -- the same
'  constraint that put PackIgnored% and Thm~& in TEXT.bas.
' ============================================================================

'--- The assembly's asset root. Everything a kind resolves to hangs off this. ---
SUB AssetRoot (p AS STRING)
    ASSET_ROOT = AssetSlash$(p)
END SUB

'--- Declare a kind of asset and the directory it lives in, relative to the
'    root. Re-declaring a kind REPLACES it, so a host can override one line of
'    a template without editing the template. ---
SUB AssetKind (nm AS STRING, d AS STRING)
    AssetKindEx nm, d, 0
END SUB

'--- A PACK-STRUCTURED kind: its files live under a named pack subfolder and
'    fall back to `default` per file. Marking it here rather than naming the
'    kinds in the router is what stops the engine knowing that THIS game's
'    packed trees happen to be called "data" and "flavor". ---
SUB AssetKindPacked (nm AS STRING, d AS STRING)
    AssetKindEx nm, d, -1
END SUB

SUB AssetKindEx (nm AS STRING, d AS STRING, packed AS INTEGER)
    DIM i AS INTEGER, k AS STRING
    k = LCASE$(_TRIM$(nm))
    IF LEN(k) = 0 THEN EXIT SUB
    FOR i = 1 TO AK_N
        IF AK_NAME(i) = k THEN AK_DIR(i) = AssetSlash$(d): AK_PACKED(i) = packed: EXIT SUB
    NEXT i
    IF AK_N >= UBOUND(AK_NAME) THEN EXIT SUB
    AK_N = AK_N + 1
    AK_NAME(AK_N) = k
    AK_DIR(AK_N) = AssetSlash$(d)
    AK_PACKED(AK_N) = packed
END SUB

'--- Route a path that lives under any PACKED kind through the selected pack,
'    falling back to `default` per file. A path under no packed kind passes
'    through untouched.
'
'    This used to be DataPath$ in DATA.bas, matching the literal prefixes
'    "assets/data/" and "assets/flavor/" -- i.e. the engine knowing both the
'    shape of this game's tree AND which two of its directories were packed.
'    Now it walks the declared kinds, so a game with three packed trees called
'    something else gets the same routing for free. ---
FUNCTION AssetRoute$ (p AS STRING, pack AS STRING)
    DIM i AS INTEGER, d AS STRING, rest AS STRING, pk AS STRING, cand AS STRING
    AssetRoute$ = p
    pk = _TRIM$(pack)
    IF LEN(pk) = 0 THEN pk = ASSET_DEFPACK
    FOR i = 1 TO AK_N
        IF AK_PACKED(i) = 0 THEN _CONTINUE
        d = ASSET_ROOT + AK_DIR(i)
        IF LEN(p) <= LEN(d) THEN _CONTINUE
        IF LEFT$(p, LEN(d)) <> d THEN _CONTINUE
        rest = MID$(p, LEN(d) + 1)
        IF pk <> ASSET_DEFPACK THEN
            cand = d + pk + "/" + rest
            IF _FILEEXISTS(cand) THEN AssetRoute$ = cand: EXIT FUNCTION
        END IF
        AssetRoute$ = d + ASSET_DEFPACK + "/" + rest
        EXIT FUNCTION
    NEXT i
END FUNCTION

'--- The directory a kind resolves to, with a trailing slash. An UNDECLARED kind
'    returns "" and is recorded -- a caller then finds no file, which is the
'    same outcome as a genuinely missing asset, and `assetlint` names the real
'    cause. Returning a guessed path instead would hide the omission forever. ---
FUNCTION AssetDir$ (kind AS STRING)
    DIM i AS INTEGER, k AS STRING
    k = LCASE$(_TRIM$(kind))
    FOR i = 1 TO AK_N
        IF AK_NAME(i) = k THEN AssetDir$ = ASSET_ROOT + AK_DIR(i): EXIT FUNCTION
    NEXT i
    AssetNoteMissing k
END FUNCTION

'--- A file inside a kind. ---
FUNCTION AssetPath$ (kind AS STRING, f AS STRING)
    DIM d AS STRING
    d = AssetDir$(kind)
    IF LEN(d) = 0 THEN EXIT FUNCTION
    AssetPath$ = d + f
END FUNCTION

'--- The PACK MODEL, which is the engine's and not any game's: a named pack
'    subfolder, falling back to `default` PER FILE, so a partial pack overrides
'    only what it ships. Returns "" when neither has it. ---
FUNCTION AssetPackFile$ (kind AS STRING, pack AS STRING, f AS STRING)
    DIM d AS STRING, p AS STRING, pk AS STRING
    d = AssetDir$(kind)
    IF LEN(d) = 0 THEN EXIT FUNCTION
    pk = _TRIM$(pack)
    IF LEN(pk) > 0 THEN
        p = d + pk + "/" + f
        IF _FILEEXISTS(p) THEN AssetPackFile$ = p: EXIT FUNCTION
    END IF
    p = d + ASSET_DEFPACK + "/" + f
    IF _FILEEXISTS(p) THEN AssetPackFile$ = p
END FUNCTION

'--- The directory of one pack of a kind, whether or not anything is in it
'    (scanners want this; resolvers want AssetPackFile$). ---
FUNCTION AssetPackDir$ (kind AS STRING, pack AS STRING)
    DIM d AS STRING, pk AS STRING
    d = AssetDir$(kind)
    IF LEN(d) = 0 THEN EXIT FUNCTION
    pk = _TRIM$(pack)
    IF LEN(pk) = 0 THEN pk = ASSET_DEFPACK
    AssetPackDir$ = d + pk + "/"
END FUNCTION

'--- what a pack folder is called when a game ships no override for it ---
SUB AssetDefaultPack (nm AS STRING)
    IF LEN(_TRIM$(nm)) > 0 THEN ASSET_DEFPACK = _TRIM$(nm)
END SUB

' ----------------------------------------------------------------------------
'  Reporting -- so an undeclared kind is loud rather than merely absent
' ----------------------------------------------------------------------------
SUB AssetNoteMissing (k AS STRING)
    DIM i AS INTEGER
    IF LEN(k) = 0 THEN EXIT SUB
    FOR i = 1 TO AK_MISS_N
        IF AK_MISS(i) = k THEN EXIT SUB
    NEXT i
    IF AK_MISS_N >= UBOUND(AK_MISS) THEN EXIT SUB
    AK_MISS_N = AK_MISS_N + 1
    AK_MISS(AK_MISS_N) = k
END SUB

'--- every kind the engine asked for that the assembly never declared ---
FUNCTION AssetMissing$
    DIM i AS INTEGER, s AS STRING
    FOR i = 1 TO AK_MISS_N
        IF LEN(s) > 0 THEN s = s + " "
        s = s + AK_MISS(i)
    NEXT i
    AssetMissing$ = s
END FUNCTION

'--- how many kinds are PACK-STRUCTURED, and which. The pack browser walks these
'    rather than carrying its own list of six: a host that declares a seventh
'    content tree gets it browsable for free. ---
FUNCTION AssetPackedCount%
    DIM i AS INTEGER, n AS INTEGER
    FOR i = 1 TO AK_N
        IF AK_PACKED(i) THEN n = n + 1
    NEXT i
    AssetPackedCount% = n
END FUNCTION

FUNCTION AssetPackedName$ (nth AS INTEGER)
    DIM i AS INTEGER, n AS INTEGER
    FOR i = 1 TO AK_N
        IF AK_PACKED(i) THEN
            n = n + 1
            IF n = nth THEN AssetPackedName$ = AK_NAME(i): EXIT FUNCTION
        END IF
    NEXT i
END FUNCTION

'--- every pack folder of a kind, as a space-separated list. `qb64-dungeon.ignore`
'    opts a folder out, which is how a DAW project sitting in assets/music/ stays
'    out of the player's pack list. ---
FUNCTION AssetPackList$ (kind AS STRING)
    DIM d AS STRING, e AS STRING, nm AS STRING, s AS STRING
    d = AssetDir$(kind)
    IF LEN(d) = 0 THEN EXIT FUNCTION
    IF _DIREXISTS(d) = 0 THEN EXIT FUNCTION
    e = _FILES$(d)
    DO WHILE LEN(e) > 0
        IF RIGHT$(e, 1) = "/" THEN
            nm = LEFT$(e, LEN(e) - 1)
            IF nm <> "." _ANDALSO nm <> ".." THEN
                IF PackIgnored%(d + nm) = 0 THEN
                    IF LEN(s) > 0 THEN s = s + " "
                    s = s + nm
                END IF
            END IF
        END IF
        e = _FILES$
    LOOP
    AssetPackList$ = s
END FUNCTION

'--- the declared tree, for `assetlint` and `dump assets` ---
FUNCTION AssetKindList$
    DIM i AS INTEGER, s AS STRING
    FOR i = 1 TO AK_N
        IF LEN(s) > 0 THEN s = s + CHR$(10)
        s = s + AK_NAME(i) + " -> " + ASSET_ROOT + AK_DIR(i)
    NEXT i
    AssetKindList$ = s
END FUNCTION

'--- a trailing slash, exactly one, and never on an empty string ---
FUNCTION AssetSlash$ (p AS STRING)
    DIM s AS STRING
    s = _TRIM$(p)
    IF LEN(s) = 0 THEN EXIT FUNCTION
    DO WHILE RIGHT$(s, 1) = "/": s = LEFT$(s, LEN(s) - 1): LOOP
    AssetSlash$ = s + "/"
END FUNCTION
