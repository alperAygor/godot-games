"""Seçili modelleri yan yana, hafif yukarıdan render eder (hızlı görsel kontrol).
blender -b --python tools/blender/render_preview.py -- çıktı.png ship.glb,ship_storm.glb [ölçek]
"""
import math
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
OUT = os.path.abspath(args[0])
NAMES = args[1].split(",")
SCALE = float(args[2]) if len(args) > 2 else 1.0
GAP = float(args[3]) if len(args) > 3 else 3.2 * SCALE
TOP = len(args) > 4 and args[4] == "top"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELS = os.path.join(ROOT, "assets", "models")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, -0.6))
mat = bpy.data.materials.new("floor")
mat.use_nodes = True
mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.02, 0.028, 0.045, 1)
bpy.context.object.data.materials.append(mat)

gap = GAP
x0 = -gap * (len(NAMES) - 1) / 2.0
for i, name in enumerate(NAMES):
    path = os.path.join(MODELS, name)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    for obj in [o for o in bpy.data.objects if o not in before]:
        if obj.parent is None:
            obj.location.x += x0 + i * gap
            obj.rotation_euler.z = math.radians(205)
            obj.scale *= SCALE

cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
cam.location = (0.0, -9.0 * SCALE - len(NAMES) * 1.6, 7.5 * SCALE + len(NAMES) * 0.6)
if TOP:
    cam.location = (0.0, -0.66 * GAP * len(NAMES), 1.0 * GAP * len(NAMES))
cam_data.lens = 40
scene.camera = cam
target = bpy.data.objects.new("target", None)
scene.collection.objects.link(target)
con = cam.constraints.new("TRACK_TO")
con.target = target
con.track_axis = "TRACK_NEGATIVE_Z"
con.up_axis = "UP_Y"
for loc, color, power in [((0, -6, 9), (0.6, 0.75, 1.0), 2600), ((6, -4, 3), (0.2, 0.8, 1.0), 900), ((-6, -4, 3), (1.0, 0.3, 0.6), 800)]:
    ld = bpy.data.lights.new("l", type="POINT")
    ld.color = color
    ld.energy = power
    ld.shadow_soft_size = 2.5
    lo = bpy.data.objects.new("l", ld)
    scene.collection.objects.link(lo)
    lo.location = loc
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.01, 0.014, 0.03, 1)
scene.render.resolution_x = 1400
scene.render.resolution_y = 560
try:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE"
scene.eevee.taa_render_samples = 32
scene.view_settings.view_transform = "Standard"
scene.render.filepath = OUT
scene.render.image_settings.file_format = "PNG"
bpy.ops.render.render(write_still=True)
print("RENDER", OUT)
