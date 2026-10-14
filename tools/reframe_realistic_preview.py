"""Reframe and render the generated full asset source without rebuilding GLBs."""

from pathlib import Path

import bpy
from mathutils import Vector


PROJECT = Path(r"M:\NewGames\TheEast")
BLEND = PROJECT / "godot" / "assets" / "realistic" / "source" / "east_valley_realistic_full.blend"
PREVIEW = PROJECT / "godot" / "assets" / "realistic" / "previews" / "realistic_full_asset_sheet.png"

PLACEMENT = {
    "Realistic_Tree_01": (-4.5, 4.6, 0),
    "Realistic_Tree_02": (0.0, 4.6, 0),
    "Realistic_Tree_03": (4.5, 4.6, 0),
    "Realistic_House": (-5.6, 1.35, 0),
    "Realistic_Lumber": (-2.8, 1.35, 0),
    "Realistic_Farm": (0.0, 1.35, 0),
    "Realistic_Warehouse": (2.8, 1.35, 0),
    "Realistic_Workshop": (5.6, 1.35, 0),
    "Realistic_Rock_01": (-5.6, -1.55, 0),
    "Realistic_Rock_02": (-2.8, -1.55, 0),
    "Realistic_Rock_03": (0.0, -1.55, 0),
    "Realistic_Lantern": (2.8, -1.55, 0),
    "Realistic_Citizen": (5.6, -1.55, 0),
    "Realistic_Bridge": (-2.65, -4.55, 0),
    "Realistic_Crops": (2.25, -4.55, 0),
}


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


bpy.ops.wm.open_mainfile(filepath=str(BLEND))
for name, position in PLACEMENT.items():
    bpy.data.objects[name].location = position

ground = bpy.data.objects["PreviewGround"]
ground.dimensions = (15.5, 13.8, 0.16)
ground.location = (0, 0, -0.10)

camera = bpy.context.scene.camera
camera.location = (0, -25.0, 12.5)
camera.data.type = "ORTHO"
camera.data.ortho_scale = 15.8
aim(camera, (0, 0.15, 1.55))

bpy.context.scene.render.resolution_x = 2200
bpy.context.scene.render.resolution_y = 1400
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.filepath = str(PREVIEW)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.render.render(write_still=True)
print("REALISTIC_FULL_PREVIEW_OK", PREVIEW)
