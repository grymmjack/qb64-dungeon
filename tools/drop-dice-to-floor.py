# Sit every die exactly on the floor, keeping whatever rotation it already has.
#
#   blender --background diceobj/qb64-dungeon-dice.blend --python tools/drop-dice-to-floor.py
#
# Uses the real VERTICES, not object.bound_box. bound_box is the LOCAL axis-aligned box, so
# rotating its eight corners gives the box's own AABB -- which sticks out past the mesh at any
# angle that is not axis-aligned, and lifts the die into the air by that overshoot. For a d20
# turned 25 degrees the error was a third of a unit, which is what "floating" looks like.
import bpy
from mathutils import Vector

dg = bpy.context.evaluated_depsgraph_get()
for o in sorted(bpy.context.scene.objects, key=lambda o: o.name):
    if o.type != "MESH" or not o.name.startswith("d"):
        continue
    ev = o.evaluated_get(dg)          # evaluated, so any modifier geometry counts too
    mw = o.matrix_world
    zmin = min((mw @ v.co)[2] for v in ev.data.vertices)
    before = o.location.z
    o.location.z -= zmin
    print("  %-5s z %.3f -> %.3f  (lowest vertex was %+.3f)" % (o.name, before, o.location.z, zmin))
bpy.ops.wm.save_mainfile()
print("saved")
