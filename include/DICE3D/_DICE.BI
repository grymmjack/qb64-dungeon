$INCLUDEONCE
''
' DICE3D - Core types + engine-global state
'
' Orientation is a unit quaternion so any polyhedron face can be snapped to the
' camera with a clean slerp. Meshes are generated generically from a vertex list
' (see _GEO.BM), so one pipeline serves D4..D20.
'
' @author Rick Christy <grymmjack@gmail.com>

TYPE DICE3D_VEC3
    X AS SINGLE
    Y AS SINGLE
    Z AS SINGLE
END TYPE

TYPE DICE3D_QUAT
    W AS SINGLE
    X AS SINGLE
    Y AS SINGLE
    Z AS SINGLE
END TYPE

''
' One physical die instance for the duration of a roll.
TYPE DICE3D_DIE
    SIDES AS INTEGER
    VALUE AS INTEGER
    '--- orientation (quaternion) + angular velocity (deg/frame vector) ---
    Q AS DICE3D_QUAT
    WX AS SINGLE
    WY AS SINGLE
    WZ AS SINGLE
    '--- position in box pixels (center) + height, and velocity ---
    PX AS SINGLE
    PY AS SINGLE
    PZ AS SINGLE
    VX AS SINGLE
    VY AS SINGLE
    VZ AS SINGLE
    '--- settle state ---
    SETTLED AS INTEGER
    SETTLING AS INTEGER
    SLOW_FRAMES AS INTEGER
    HIT_WALL AS INTEGER
    TQ AS DICE3D_QUAT '                  target orientation for the rolled VALUE
    '--- drop-lowest FX ---
    DROPPED AS INTEGER
    FADE AS SINGLE '                     1 = fully visible .. 0 = gone
    DROP_T AS SINGLE '                   drop FX progress 0..1
    '--- misc ---
    ROLE AS INTEGER '                    DICE3D_ROLE_*
    BODY_KOLOR AS _UNSIGNED LONG '       per-die body override (percentile hi/lo)
    ATLAS AS LONG '                      baked face texture handle
    OFFSET AS INTEGER '                  atlas tile row offset (for shared atlases)
END TYPE

'--- Engine globals ------------------------------------------------------------
DIM SHARED DICE3D_BOXBUF AS LONG '        off-screen 32-bit box compositing buffer
REDIM SHARED DICE3D_DICE(0) AS DICE3D_DIE

'--- Current mesh (shared by all dice of one type in a single roll) ------------
DIM SHARED DICE3D_NV AS INTEGER '         unique vertex count
REDIM SHARED DICE3D_MV(0) AS DICE3D_VEC3 ' model-space vertices (unit-ish)
DIM SHARED DICE3D_NT AS INTEGER '         triangle count
REDIM SHARED DICE3D_TA(0) AS INTEGER '    triangle vertex indices
REDIM SHARED DICE3D_TB(0) AS INTEGER
REDIM SHARED DICE3D_TC(0) AS INTEGER
REDIM SHARED DICE3D_TUX(0, 2) AS SINGLE ' per-triangle-vertex atlas UVs (pixels)
REDIM SHARED DICE3D_TUY(0, 2) AS SINGLE
REDIM SHARED DICE3D_TFACE(0) AS INTEGER ' logical face id per triangle

'--- Per-face data -------------------------------------------------------------
DIM SHARED DICE3D_NF AS INTEGER '         face count (= sides)
REDIM SHARED DICE3D_FACE_Q(0) AS DICE3D_QUAT '  "this face at camera" pose
REDIM SHARED DICE3D_FACE_N(0) AS DICE3D_VEC3 '  outward face normal (model space)
REDIM SHARED DICE3D_FACE_VAL(0) AS INTEGER '    numeric value on each face
REDIM SHARED DICE3D_FACE_LABEL(0) AS STRING '   text stamped on each face
REDIM SHARED DICE3D_VAL2FACE(0) AS INTEGER '    value -> face index
REDIM SHARED DICE3D_CORNERVAL(0, 2) AS INTEGER '  D4 top-read: value at each triangle corner
REDIM SHARED DICE3D_FVN(0) AS INTEGER '         vertex count of each face polygon
REDIM SHARED DICE3D_FVIDX(0, 7) AS INTEGER '    ordered polygon vertex indices (for wireframe)

'--- Custom face sprite map: value -> sheet cell index (-1 = use number/pip) ---
REDIM SHARED DICE3D_FACE_CELL_MAP(0 TO 128) AS INTEGER
DIM SHARED DICE3D_FACE_MAP_READY AS INTEGER

'--- Result of the most recent roll -------------------------------------------
DIM SHARED DICE3D_LAST_TOTAL AS INTEGER '  sum of kept dice + flat modifier
DIM SHARED DICE3D_LAST_COUNT AS INTEGER '  number of result entries
DIM SHARED DICE3D_LAST_SIDES AS INTEGER '  die type rolled (100 = percentile)
REDIM SHARED DICE3D_LAST_VALUE(0) AS INTEGER '   per-entry value (1-based)
REDIM SHARED DICE3D_LAST_DROPPED(0) AS INTEGER '  per-entry dropped flag (1-based)

'--- Optional supersample anti-aliasing: render the box buffer at N x the on-screen
'    size, then smooth-downscale in dice3d_present. 0/1 = off. The caller sizes the
'    box (BOX_W/H, DIE_SIZE, physics) at N x and sets BOX_X/Y to the on-screen origin.
DIM SHARED DICE3D_SSDIV AS INTEGER

'--- Optional frame capture (debugging / recording; 0 = off) -------------------
DIM SHARED DICE3D_SHOT_EVERY AS INTEGER '  save box buffer every N frames
DIM SHARED DICE3D_SHOT_DIR AS STRING
DIM SHARED DICE3D_FRAME AS LONG
