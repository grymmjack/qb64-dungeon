$INCLUDEONCE
''
' DICE3D - Configuration type + public enums
'
' One CONFIG struct drives an entire roll. It is passed by reference into
' dice3d_roll(). Fill it once with dice3d_config_defaults() then tweak fields.
' Every eventual feature has a field here already so the public API stays
' stable as later milestones light each one up.
'
' @author Rick Christy <grymmjack@gmail.com>

'--- Material styles -----------------------------------------------------------
CONST DICE3D_MAT_SOLID = 0
CONST DICE3D_MAT_CRYSTAL = 1
CONST DICE3D_MAT_MARBLE = 2
CONST DICE3D_MAT_NOISE = 3

'--- D6 pip styles -------------------------------------------------------------
CONST DICE3D_PIP_DOT = 0
CONST DICE3D_PIP_SQUARE = 1
CONST DICE3D_PIP_SPRITE = 2

'--- Drop effect ---------------------------------------------------------------
CONST DICE3D_DROPFX_FADE = 0
CONST DICE3D_DROPFX_EXPLODE = 1

'--- Render backend ------------------------------------------------------------
CONST DICE3D_RENDER_SOFTWARE = 0
CONST DICE3D_RENDER_HARDWARE = 1

'--- Die roles (percentile d100 splits into a high + low die) ------------------
CONST DICE3D_ROLE_NORMAL = 0
CONST DICE3D_ROLE_PCT_HI = 1
CONST DICE3D_ROLE_PCT_LO = 2

TYPE DICE3D_CONFIG
    '--- Dice box: a top-down screen region, in pixels -------------------------
    BOX_X AS INTEGER
    BOX_Y AS INTEGER
    BOX_W AS INTEGER
    BOX_H AS INTEGER
    BOX_SHOW_OUTLINE AS INTEGER
    BOX_OUTLINE_KOLOR AS _UNSIGNED LONG
    BOX_SHOW_BACK AS INTEGER '           TRUE = opaque fill, FALSE = transparent overlay
    BOX_BACK_KOLOR AS _UNSIGNED LONG

    '--- Die appearance --------------------------------------------------------
    DIE_SIZE AS SINGLE '                 half-extent in box pixels (48 => ~96px die)
    CAM_TILT AS SINGLE '                 view pitch in degrees (0 = pure top-down)
    D4_LEAN AS SINGLE  '                 d4 read pose: degrees the value-base is tipped from
    '                                    square-on. NEGATIVE tips the base TOWARD the camera
    '                                    (you see a sliver of the bottom); POSITIVE tips it
    '                                    AWAY (the bottom is hidden and you see more of the
    '                                    upper faces). 0 = edge-on, which reads as a flat
    '                                    triangle and is the one thing to avoid.
    CAM_YAW AS SINGLE '                  view yaw in degrees (orbit left/right)
    FOV AS SINGLE '                      field of view in degrees (0 = orthographic)
    MATERIAL AS INTEGER
    BODY_KOLOR AS _UNSIGNED LONG
    NUM_KOLOR AS _UNSIGNED LONG
    EDGE_KOLOR AS _UNSIGNED LONG
    EDGE_TRANSPARENT AS INTEGER
    BEVEL AS SINGLE '                    0 = sharp .. 1 = very round
    NUMERIC AS INTEGER '                 TRUE = draw numbers on faces
    NUM_SCALE AS SINGLE '                number height as a fraction of the face tile
    FONT_HANDLE AS LONG '                _LOADFONT handle for antialiased numbers (0 = built-in)
    FONT_PX AS INTEGER '                 desired font size (metadata; saved in sets)
    '--- material parameters ---------------------------------------------------
    BODY_ALPHA AS SINGLE '               overall body opacity 0..1 (translucent bodies)
    TEX_OPACITY AS SINGLE '              marble/noise pattern strength vs flat body 0..1
    MARBLE_KOLOR AS _UNSIGNED LONG '     marble vein colour
    CRYSTAL_ALPHA AS SINGLE '            crystal transparency 0..1
    '--- directional (top) light -----------------------------------------------
    '   Shades each face by how much it faces the light (Lambert), so top-facing
    '   surfaces catch light and the die gains real 3D form. The light is in VIEW
    '   space (fixed to the top of the screen), so it reads as an overhead light
    '   whatever the camera yaw/tilt. Direction points FROM a surface TO the light.
    LIGHT_ENABLED AS INTEGER '           TRUE = apply directional shading
    LIGHT_X AS SINGLE '                  light direction (auto-normalised)
    LIGHT_Y AS SINGLE '                  +Y = from the top of the screen
    LIGHT_Z AS SINGLE '                  +Z = from the camera side
    LIGHT_AMBIENT AS SINGLE '            0..1 min brightness for faces facing away
    LIGHT_INTENSITY AS SINGLE '          0..1 shading strength (darkening amount)
    LIGHT_KOLOR AS _UNSIGNED LONG '      light colour: lit faces wash toward it (white = neutral).
    '                                    Tint scales with the colour's saturation, so white/grey
    '                                    stay pure brightness; a hue (torch, moonlight) tints.
    '--- wireframe overlay -----------------------------------------------------
    WIRE_ENABLED AS INTEGER
    WIRE_KOLOR AS _UNSIGNED LONG
    WIRE_OPACITY AS SINGLE '             0..1

    '--- D6 pips ---------------------------------------------------------------
    D6_PIPS AS INTEGER
    PIP_STYLE AS INTEGER
    PIP_SPRITE AS LONG '                 image handle used when PIP_STYLE = SPRITE

    '--- Custom face sprite sheet (per-value overrides) ------------------------
    FACE_SHEET AS LONG
    FACE_CELL_W AS INTEGER
    FACE_CELL_H AS INTEGER

    '--- Percentile (d100) per-die body colors --------------------------------
    PCT_HI_KOLOR AS _UNSIGNED LONG '     tens die
    PCT_LO_KOLOR AS _UNSIGNED LONG '     units die

    '--- Drop lowest -----------------------------------------------------------
    DROP_LOWEST AS INTEGER '             count of lowest dice to drop
    DROP_FX AS INTEGER

    '--- Sound (handles come from _SNDOPEN in the caller) ----------------------
    SOUND_ENABLED AS INTEGER
    SND_EDGE_H AS LONG
    SND_SETTLE_H AS LONG

    '--- Animation / physics feel ----------------------------------------------
    RENDER_MODE AS INTEGER
    FPS AS INTEGER
    MAX_ROLL_SECS AS SINGLE '            safety cap so a roll always returns
    GRAVITY AS SINGLE
    RESTITUTION AS SINGLE '              wall/floor bounciness 0..1
    FRICTION AS SINGLE '                 spin/velocity damping per frame 0..1
    SPIN_STRENGTH AS SINGLE '            initial tumble speed (deg/frame magnitude)
    THROW_STRENGTH AS SINGLE '           initial scatter/shake velocity (px/frame)
END TYPE

''
' Parsed dice notation: "XdY" plus optional modifiers
'   dlN drop lowest N   dhN drop highest N   khN keep highest N   klN keep lowest N
'   +N / -N flat modifier   (e.g. "4d6dl1", "2d20kh1+3")
TYPE DICE3D_SPEC
    CNT AS INTEGER
    SIDES AS INTEGER
    DROP_LOW AS INTEGER
    DROP_HIGH AS INTEGER
    FLATMOD AS INTEGER
END TYPE
