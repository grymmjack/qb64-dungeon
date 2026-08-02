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
' inradius/maxab per face: how much room the SHAPE gives a numeral once fitted to its tile.
' ~0.5 for a triangle, ~0.71 a square, ~0.81 a pentagon. The atlas scales numerals by it so
' the same digit reads the same size on every die (see dice3d_make_atlas).
REDIM SHARED DICE3D_FACE_ROOM(0) AS SINGLE
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

'--- Optional readable-result showcase: after the physics settle, turn each die so its
'    winning face is flat-on with the number UPRIGHT (physics can leave it sideways or
'    upside-down). 0 = off (pure physics rest). Set by the caller before dice3d_roll.
DIM SHARED DICE3D_UPRIGHT AS INTEGER

'--- Optional HARDWARE render: present the dice via 3D _MAPTRIANGLE on the OpenGL layer
'    (native display resolution, hardware texture filtering = genuinely smooth, unaffected
'    by any software-canvas fullscreen scaling). The caller draws the tray/background on
'    the software screen, sets these params + a hardware-copy atlas, then rolls. 0 = the
'    software box-buffer renderer. present() branches on this.
DIM SHARED DICE3D_HW AS INTEGER
DIM SHARED DICE3D_HWATLAS AS LONG   ' hardware (_COPYIMAGE ,33) atlas; built lazily, freed by the caller
DIM SHARED DICE3D_HL AS LONG        ' hardware white sheen tile for the read-face highlight (built lazily)
DIM SHARED DICE3D_HL_SW AS LONG     ' software white sheen tile (software render path)

'--- Directional-light shading: baked into the atlas as opaque brightness COLUMNS (see
'    dice3d_make_atlas). Column 0 = full bright, column NLEV-1 = darkest (MAXDARK black over
'    it). The renderer picks a per-face level and offsets the source U by level*DICE3D_TILE.
'    Opaque pixels only -- NO translucent overlays, which some GL drivers drop when a
'    semi-transparent tile is uploaded via _COPYIMAGE(,33) (they render invisible).
CONST DICE3D_LIGHT_NLEV = 12 '      brightness columns (finer = smoother gradient across a rounded bevel)
CONST DICE3D_LIGHT_MAXDARK = .62
CONST DICE3D_LIGHT_TINT = .55 '     max colour wash on the most-lit column (scaled by LIGHT_KOLOR saturation)
DIM SHARED DICE3D_HW_S AS SINGLE    ' GPU units per model unit (die on-screen size)
DIM SHARED DICE3D_HW_Z AS SINGLE    ' base view depth (negative; ~-5)
DIM SHARED DICE3D_HW_CX AS SINGLE   ' GPU x of the tray centre (0 = screen centre)
DIM SHARED DICE3D_HW_CY AS SINGLE   ' GPU y of the tray centre (0 = screen centre; +up)
DIM SHARED DICE3D_HW_PXK AS SINGLE  ' GPU units per box-pixel (maps die scatter positions)

'--- Fallback sound: when SOUND_ENABLED but no SND_EDGE_H / SND_SETTLE_H file is given,
'    the physics plays built-in tone beeps/boops at this volume (0..1). 0 = silent fallback.
DIM SHARED DICE3D_SND_VOL AS SINGLE

'--- Optional atlas resolution override: bake the face texture at this DIE_SIZE (px) even
'    if the die renders smaller (e.g. hardware dice render small but want a crisp hi-res
'    atlas so numbers stay sharp). 0 = bake at the config's DIE_SIZE.
DIM SHARED DICE3D_ATLAS_DIE AS SINGLE

'--- Geometric edge bevel (rounded dice): 0 = sharp polyhedron (original mesh). > 0 insets each
'    numbered face toward its centroid by this fraction and fills the frame with real bevel-strip
'    + vertex-cap geometry, so the EDGES are physically chamfered (not a texture trick). Set by
'    the caller before dice3d_build (it rebuilds the mesh). ~0.12-0.22 reads as a nice round. ---
DIM SHARED DICE3D_BEVEL AS SINGLE

'--- Optional frame capture (debugging / recording; 0 = off) -------------------
DIM SHARED DICE3D_SHOT_EVERY AS INTEGER '  save box buffer every N frames
DIM SHARED DICE3D_SHOT_DIR AS STRING
DIM SHARED DICE3D_FRAME AS LONG
