# Settle every die: lie it FLAT ON A FACE, then sit it exactly on the floor.
#
#   blender --background diceobj/qb64-dungeon-dice.blend --python tools/drop-dice-to-floor.py
#
# A die that has stopped rolling rests on a FACE. Placing one by eye almost never does that --
# it balances on a point or an edge, which is what "floating"/"not laying flat" looks like even
# after the height is correct.
#
# The rotation applied is the MINIMAL one: whichever face is already closest to facing down is
# the one laid flat, so the die keeps the orientation it was posed with (its yaw, and which
# numbers face the camera) and only stops leaning. That is also what real settling does -- a die
# tips onto the face it was already nearest.
#
# Height comes from the real VERTICES, not object.bound_box: bound_box is the LOCAL axis-aligned
# box, so rotating its corners gives that box's AABB, which sticks out past the mesh at any
# non-axis-aligned angle and lifts the die by the overshoot.
import bpy
from mathutils import Vector

DOWN = Vector((0, 0, -1))
# A real face is a large fraction of the biggest face; a bevel strip is a sliver.
FACE_MIN_AREA = 0.25

def settle(o, dg):
    ev = o.evaluated_get(dg)
    mw = o.matrix_world
    rot = mw.to_quaternion()
    # ONLY REAL FACES. The mesh is bevelled, so most polygons are narrow strips along the edges
    # -- and one of those is often "nearer to down" than any true face. Laying a bevel strip flat
    # IS resting on an edge, which is what left the d8 and d10 standing on their points.
    # A bevel poly is a fraction of a face's area, so the largest area sets a clean threshold.
    biggest = max(p.area for p in ev.data.polygons)
    faces = [p for p in ev.data.polygons if p.area > biggest * FACE_MIN_AREA]
    best, bestdot = None, -2.0
    for poly in faces:
        n = (rot @ poly.normal).normalized()     # normals are LOCAL -- rotate before comparing
        d = n.dot(DOWN)
        if d > bestdot:
            bestdot, best = d, n
    if best is None:
        return
    # Turn that face to point straight down, folded into the rotation it already has.
    o.rotation_euler = (best.rotation_difference(DOWN) @ rot).to_euler()

def drop(o, dg):
    ev = o.evaluated_get(dg)
    mw = o.matrix_world
    o.location.z -= min((mw @ v.co)[2] for v in ev.data.vertices)

dice = [o for o in sorted(bpy.context.scene.objects, key=lambda o: o.name)
        if o.type == "MESH" and o.name.startswith("d")]
dg = bpy.context.evaluated_depsgraph_get()
for o in dice:
    settle(o, dg)
    bpy.context.view_layer.update()          # the drop must see the NEW rotation
    drop(o, dg)
    print("  %-5s settled flat, z = %.3f" % (o.name, o.location.z))
bpy.ops.wm.save_mainfile()
print("saved")
