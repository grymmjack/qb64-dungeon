# Build a .blend containing every DUNGEON! die, UV-mapped, lit, and camera-ready.
#
#   dungeon.run diceobj                 # export the meshes first (writes diceobj/)
#   blender --background --python tools/make-dice-blend.py
#
# Writes diceobj/qb64-dungeon-dice.blend
#
# WHY A SCRIPT AND NOT A CHECKED-IN .blend: the dice meshes are not fixed. Bevel is real
# geometry driven by the SETTINGS "Dice Round" value, and the face atlas is baked from the
# chosen dice set and numeral font. A .blend committed today is a snapshot of one combination;
# this rebuilds from whatever `diceobj` last exported, so the render always matches the game.
import bpy, os, math, glob

HERE = os.path.dirname(os.path.abspath(__file__))
OBJDIR = os.path.join(os.path.dirname(HERE), "diceobj")
OUT = os.path.join(OBJDIR, "qb64-dungeon-dice.blend")

# --- empty the default scene (cube, light, camera) --------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)

# The GAME's viewing angle, per die, read from the dice set rather than guessed.
#
# In game the die is posed with its result face readable and the CAMERA tilted by CAM_TILT --
# 21.5 degrees for most dice, but 85 for the d4, which is a TOP-READ tetra (its value sits on
# the hidden base and repeats at the apex, so it is viewed almost from above). Here the camera
# is fixed and the die is rotated instead, which is the same relationship seen from the other
# side.
def game_tilts(setfile):
    tilts, cur = {}, None
    if not os.path.exists(setfile):
        return tilts
    for line in open(setfile):
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            cur = line[1:-1].lower()
        elif line.upper().startswith("CAM_TILT=") and cur:
            try:
                tilts[cur] = float(line.split("=", 1)[1])
            except ValueError:
                pass
    return tilts

def import_obj(path):
    # Blender 4.x renamed the operator; support both so this is not version-locked.
    if hasattr(bpy.ops.wm, "obj_import"):
        bpy.ops.wm.obj_import(filepath=path)
    else:
        bpy.ops.import_scene.obj(filepath=path)
    return [o for o in bpy.context.selected_objects if o.type == "MESH"]

def make_material(name, atlas_png):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(atlas_png)
    # NEAREST, not linear. The numerals are baked pixel art on a tile atlas; smoothing blurs
    # them and bleeds neighbouring tiles across the face seams.
    tex.interpolation = "Closest"
    tex.extension = "CLIP"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.35
    # A little transmission-free sheen reads as moulded resin rather than plastic.
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.5
    return mat

dice = sorted(glob.glob(os.path.join(OBJDIR, "d*.obj")),
              key=lambda p: int(os.path.basename(p)[1:-4]))
if not dice:
    raise SystemExit("no diceobj/*.obj -- run `dungeon.run diceobj` first")

# Framing. The row is len(dice) * SPACING wide, and the camera has to see all of it -- the
# first version used a 65mm lens 14 units back, which framed three of the six.
SPACING = 2.4
TILTS = game_tilts(os.path.join(os.path.dirname(HERE), "assets", "data", "default",
                                "dicesets", "06-amethyst.txt"))
placed = []
for i, obj_path in enumerate(dice):
    base = os.path.splitext(os.path.basename(obj_path))[0]
    atlas = os.path.join(OBJDIR, base + "-atlas.png")
    meshes = import_obj(obj_path)
    for m in meshes:
        m.name = base
        # A row along X, evenly spaced, all sitting on Z=0 so the floor plane works.
        m.location = (i * SPACING - (len(dice) - 1) * SPACING * 0.5, 0, 1)
        # Rx by the game's own CAM_TILT for this die, then a small Y spin so the row does not
        # read as six identical silhouettes. The d4 comes out near-flat because that is exactly
        # how the game shows it.
        tilt = TILTS.get(base, 21.5)
        m.rotation_euler = (math.radians(tilt), 0, math.radians(-18 + i * 7))
        if os.path.exists(atlas):
            mat = make_material(base + "_mat", atlas)
            m.data.materials.clear()
            m.data.materials.append(mat)
        # Flat shading: these are faceted solids. Smooth shading rounds the edges visually and
        # fights the real bevel geometry that is already in the mesh.
        for poly in m.data.polygons:
            poly.use_smooth = False
        placed.append(m)

# --- sit every die on the floor -----------------------------------------------------------
#
# From the die's real VERTICES, not object.bound_box. bound_box is the LOCAL axis-aligned box,
# so rotating its eight corners gives that box's AABB -- which sticks out past the mesh at any
# angle that is not axis-aligned and lifts the die into the air by the overshoot. For a d20
# turned 25 degrees that error is a third of a unit, which is exactly what "floating" looks
# like. Vertices are exact at any rotation.
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
for m in placed:
    ev = m.evaluated_get(dg)
    mw = m.matrix_world
    m.location.z -= min((mw @ v.co)[2] for v in ev.data.vertices)

# --- floor ------------------------------------------------------------------------------
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
floor = bpy.context.active_object
floor.name = "floor"
fm = bpy.data.materials.new("floor_mat")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.02, 0.02, 0.03, 1)
fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
floor.data.materials.append(fm)

# --- three-point rig ---------------------------------------------------------------------
def add_light(name, kind, loc, energy, size=3.0):
    d = bpy.data.lights.new(name, type=kind)
    d.energy = energy
    if kind == "AREA":
        d.size = size
    o = bpy.data.objects.new(name, d)
    o.location = loc
    bpy.context.collection.objects.link(o)
    return o

key = add_light("key", "AREA", (-6, -7, 9), 900, 6)
fill = add_light("fill", "AREA", (8, -6, 5), 250, 8)
rim = add_light("rim", "AREA", (0, 8, 7), 400, 6)
for l in (key, fill, rim):
    c = l.constraints.new("TRACK_TO")
    c.target = placed[len(placed) // 2]

# --- camera ------------------------------------------------------------------------------
cam_data = bpy.data.cameras.new("camera")
cam_data.lens = 50
cam = bpy.data.objects.new("camera", cam_data)
# Pulled back far enough for the whole row plus margin: at 50mm the horizontal field is about
# 40 degrees, so the visible width is roughly 0.73 * distance.
cam.location = (0, -(len(dice) * SPACING) / 0.62, 6.5)
bpy.context.collection.objects.link(cam)
c = cam.constraints.new("TRACK_TO")
c.target = placed[len(placed) // 2]
bpy.context.scene.camera = cam

# --- render settings ---------------------------------------------------------------------
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = 128
sc.render.resolution_x = 1920
sc.render.resolution_y = 1080
sc.render.film_transparent = True      # PNGs with alpha, ready to drop into 2D art
sc.view_settings.view_transform = "Standard"   # not Filmic: keep the game's colours exact

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("wrote " + OUT)
