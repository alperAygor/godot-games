"""Model vitrini: üretilen .glb'leri geri yükleyip tek karede render eder.
blender -b --python tools/blender/render_models.py -- docs/_models_raw.png
"""
import math
import os
import sys

import bpy

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "docs/_models_raw.png")
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELS = os.path.join(ROOT, "assets", "models")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# Zemin
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
floor = bpy.context.object
mat = bpy.data.materials.new("floor")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (0.02, 0.028, 0.045, 1)
bsdf.inputs["Roughness"].default_value = 0.55
bsdf.inputs["Metallic"].default_value = 0.1
floor.data.materials.append(mat)

# Modelleri sırayla diz
order = [
    ("pillar.glb", -6.4, 0.8, 190, 1.6),
    ("crystal.glb", -4.9, 0.95, 200, 1.6),
    ("obelisk.glb", -3.4, 0.85, 200, 1.6),
    ("barrier.glb", -1.8, 0.95, 195, 1.6),
    ("boss.glb", 1.8, 0.8, 180, 1.3),
    ("ship.glb", -5.6, 1.0, 150, -1.2),
    ("chaser.glb", -4.2, 1.0, 160, -1.2),
    ("shooter.glb", -2.9, 1.0, 170, -1.2),
    ("tank.glb", -1.6, 1.0, 175, -1.2),
    ("swarmer.glb", -0.4, 1.1, 165, -1.2),
    ("bomber.glb", 0.8, 1.05, 170, -1.2),
    ("sniper.glb", 2.0, 1.05, 175, -1.2),
    ("orbiter.glb", 3.2, 1.15, 175, -1.2),
    ("crate.glb", 4.5, 1.0, 190, -1.2),
]
for name, x, s, yaw, depth in order:
    path = os.path.join(MODELS, name)
    if not os.path.exists(path):
        continue
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    imported = [o for o in bpy.data.objects if o not in before]
    for obj in imported:
        if obj.parent is None:
            obj.location.x += x
            obj.location.y += depth
            obj.rotation_euler.z = yaw
            obj.scale *= s

# Kasa önde
path = os.path.join(MODELS, "crate.glb")
if os.path.exists(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    for obj in [o for o in bpy.data.objects if o not in before]:
        if obj.parent is None:
            obj.location = (-1.2, -3.0, 0)
            obj.rotation_euler.z = math.radians(30)

cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
cam.location = (0.0, -16.0, 6.0)
cam_data.lens = 38
scene.camera = cam
target = bpy.data.objects.new("target", None)
scene.collection.objects.link(target)
target.location = (0.0, 0.0, 1.1)
con = cam.constraints.new("TRACK_TO")
con.target = target
con.track_axis = "TRACK_NEGATIVE_Z"
con.up_axis = "UP_Y"

ld0 = bpy.data.lights.new("key", type="AREA")
ld0.energy = 2200
ld0.size = 9.0
ld0.color = (0.55, 0.72, 1.0)
lo0 = bpy.data.objects.new("key", ld0)
scene.collection.objects.link(lo0)
lo0.location = (0, -7, 8)
lo0.rotation_euler = (math.radians(15), 0, 0)
for loc, color, power in [((4.5, -5, 3), (0.2, 0.8, 1.0), 700), ((-5, -4, 3), (1.0, 0.25, 0.55), 600),
                          ((0, 5, 4), (0.3, 0.5, 1.0), 500)]:
    ld = bpy.data.lights.new("l", type="POINT")
    ld.color = color
    ld.energy = power
    ld.shadow_soft_size = 2.0
    lo = bpy.data.objects.new("l", ld)
    scene.collection.objects.link(lo)
    lo.location = loc

world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.006, 0.009, 0.02, 1)

scene.render.resolution_x = 1600
scene.render.resolution_y = 700
try:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE"
scene.eevee.taa_render_samples = 64
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.render.filepath = OUT
scene.render.image_settings.file_format = "PNG"
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.render.render(write_still=True)
print("MODELS RENDER:", OUT)