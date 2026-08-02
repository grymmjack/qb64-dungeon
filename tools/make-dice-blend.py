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
import bpy, os, math, glob, mathutils

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

# --- size them like a real dice set --------------------------------------------------------
#
# The meshes all come out of the exporter at unit circumradius, which is NOT how a physical set
# looks: a dodecahedron at unit circumradius reads BIGGER than an icosahedron, because its faces
# are broader and it fills more of its own sphere. In a real set the d20 is the largest piece and
# the d4 the smallest.
#
# These are display scales, applied per die, purely so the row reads as a set.
# Everything stays at the exporter's own scale EXCEPT the d12. At unit circumradius a
# dodecahedron reads bigger than an icosahedron -- broad pentagons fill more of the sphere than
# narrow triangles -- so the d12 out-bulked the d20, which no real set does. Only that one is
# corrected; the rest were already right.
# Mirrors DieSetScale! in engine/DICE3D_GAME.bas -- the same correction the GAME applies, so a
# render and a roll show the same set. Change one, change the other.
SET_SCALE = {"d12": 0.90, "d10": 0.96, "d6": 0.94}
for m in placed:
    k = SET_SCALE.get(m.name, 1.0)
    m.scale = (k, k, k)
bpy.context.view_layer.update()

# --- turn each die so its HIGHEST value reads --------------------------------------------
#
# A face carries no number in the geometry -- the numerals are in the atlas -- so the exporter
# writes dN-faces.txt, one value per face in face order. A polygon's face index comes back from
# its UV: the atlas stacks one tile per face, so V position IS the face index.
#
# The d4 is the exception, and deliberately: it is a TOP-READ tetra whose result sits on the
# HIDDEN BASE and repeats at the apex. So its value face goes DOWN, exactly as the game poses
# it. Every other die puts its value face UP and lands on the face opposite.
UP = mathutils.Vector((0, 0, 1))
for m in placed:
    vals = {}
    fpath = os.path.join(OBJDIR, m.name + "-faces.txt")
    if os.path.exists(fpath):
        for line in open(fpath):
            line = line.strip()
            if line and not line.startswith("#"):
                a_, b_ = line.split()
                vals[int(a_)] = int(b_)
    if not vals:
        continue
    nf = len(vals)
    # The face to put up. Highest number, EXCEPT the d10: DICE3D numbers it 0-9 on the
    # percentile convention, and the "0" face IS the ten -- the game remaps it on read. So the
    # top-value face there is the 0, not the 9, exactly as on a physical d10.
    if m.name == "d10" and 0 in vals.values():
        want = [f for f in vals if vals[f] == 0][0]
    else:
        want = max(vals, key=lambda f: vals[f])
    ev = m.evaluated_get(bpy.context.evaluated_depsgraph_get())
    uv = ev.data.uv_layers.active
    biggest = max(p.area for p in ev.data.polygons)
    target = None
    for poly in ev.data.polygons:
        if poly.area <= biggest * 0.25:           # skip bevel slivers
            continue
        v = sum(uv.data[li].uv[1] for li in poly.loop_indices) / poly.loop_total
        if int((1.0 - v) * nf) == want:           # atlas row -> face index
            target = (m.matrix_world.to_quaternion() @ poly.normal).normalized()
            break
    if target is None:
        continue
    goal = mathutils.Vector((0, 0, -1)) if m.name == "d4" else UP
    m.rotation_euler = (target.rotation_difference(goal) @ m.matrix_world.to_quaternion()).to_euler()
bpy.context.view_layer.update()

# --- settle every die: flat on a face, then down onto the floor ----------------------------
#
# A die that has stopped rolling rests on a FACE. Posing one by angle alone almost never does --
# it balances on a point or an edge, which still reads as wrong even once the height is right.
#
# The rotation applied is the MINIMAL one: whichever face is already nearest to facing down gets
# laid flat, so the die keeps the orientation it was posed with -- its yaw, and which numbers
# face the camera -- and only stops leaning. That is also what settling physically does: a die
# tips onto the face it was already closest to.
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
DOWN = mathutils.Vector((0, 0, -1))
for m in placed:
    ev = m.evaluated_get(dg)
    rot = m.matrix_world.to_quaternion()
    # ONLY REAL FACES -- the mesh is bevelled, and a narrow bevel strip is often "nearer to
    # down" than any true face. Laying one flat IS resting on an edge, which is what left the
    # d8 and d10 on their points. A bevel poly is a sliver next to a face, so area separates them.
    biggest = max(p.area for p in ev.data.polygons)
    best, bestdot = None, -2.0
    for poly in ev.data.polygons:                # normals are LOCAL: rotate before comparing
        if poly.area <= biggest * 0.25: continue
        n = (rot @ poly.normal).normalized()
        if n.dot(DOWN) > bestdot:
            bestdot, best = n.dot(DOWN), n
    if best is not None:
        m.rotation_euler = (best.rotation_difference(DOWN) @ rot).to_euler()
bpy.context.view_layer.update()                  # the drop below must see the NEW rotations

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
# Higher and tilted down, so the TOP faces -- the ones showing each die's value -- are readable
# rather than edge-on. Pulled back a little further to keep the whole row in frame from up here.
cam.location = (0, -(len(dice) * SPACING) / 0.60, 11.0)
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
