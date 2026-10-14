"""Generate the original East Valley low-poly kit with Blender 4.x.

Run:
  blender.exe --background --python tools/generate_lowpoly_assets.py

All dimensions are meters. In Blender, entrances face -Y; after glTF Y-up export
they face Godot +Z. Every asset root is at ground center.
"""

import json
import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_DIR = Path(os.environ.get("THE_EAST_PROJECT", r"M:\NewGames\TheEast"))
MODEL_DIR = PROJECT_DIR / "godot" / "assets" / "models"
PREVIEW_DIR = PROJECT_DIR / "godot" / "assets" / "previews"
SOURCE_DIR = PROJECT_DIR / "godot" / "assets" / "source"

MODEL_DIR.mkdir(parents=True, exist_ok=True)
PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
SOURCE_DIR.mkdir(parents=True, exist_ok=True)

PALETTE = {
    "ink": "#2f3433",
    "plaster": "#d7c29e",
    "warm_plaster": "#c98963",
    "wood": "#8a5c3b",
    "dark_wood": "#51392d",
    "thatch": "#b79a61",
    "tile": "#536c73",
    "tile_light": "#698187",
    "brick": "#9b6048",
    "stone": "#747872",
    "stone_light": "#96998f",
    "soil": "#805e3d",
    "crop": "#769154",
    "grain": "#d6a74a",
    "leaf": "#506f51",
    "leaf_light": "#66825e",
    "lantern": "#b94a42",
    "lantern_light": "#f2b45b",
    "skin": "#e2b889",
    "cloth_blue": "#5d8792",
    "cloth_rust": "#b8684b",
    "cloth_green": "#708c62",
    "cloth_gold": "#c8973e",
}

MATERIALS = {}
ASSETS = []


def rgba(value):
    value = value.lstrip("#")
    srgb = tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    rgb = tuple(channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4 for channel in srgb)
    return (*rgb, 1.0)


def material(name, color, roughness=0.86, emission=0.0):
    key = (name, color, roughness, emission)
    if key in MATERIALS:
        return MATERIALS[key]
    mat = bpy.data.materials.new("M_" + name)
    mat.diffuse_color = rgba(color)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba(color)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = roughness
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = rgba(color)
        bsdf.inputs["Emission Strength"].default_value = emission
    MATERIALS[key] = mat
    return mat


def setup_materials():
    for key, value in PALETTE.items():
        emission = 0.6 if key == "lantern_light" else 0.0
        roughness = 0.72 if key in ("tile", "stone_light") else 0.88
        material(key, value, roughness, emission)


def set_material(obj, key):
    obj.data.materials.append(MATERIALS[(key, PALETTE[key], 0.72 if key in ("tile", "stone_light") else 0.88, 0.6 if key == "lantern_light" else 0.0)])


def root(name, asset_type):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj["asset_type"] = asset_type
    obj["art_version"] = 1
    obj["tile_meters"] = 2.0
    return obj


def parent_to(obj, parent):
    obj.parent = parent
    return obj


def cube(name, size, location, mat_key, parent=None, rotation=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        modifier = obj.modifiers.new("SoftEdges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
    set_material(obj, mat_key)
    if parent:
        parent_to(obj, parent)
    return obj


def cylinder(name, radius, depth, location, mat_key, parent=None, vertices=8, rotation=(0, 0, 0), radius_top=None):
    if radius_top is None or abs(radius_top - radius) < 0.0001:
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=radius_top, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    set_material(obj, mat_key)
    if parent:
        parent_to(obj, parent)
    return obj


def sphere(name, radius, location, mat_key, parent=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    set_material(obj, mat_key)
    if parent:
        parent_to(obj, parent)
    return obj


def empty(name, location, parent):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    parent_to(obj, parent)
    return obj


def posts(parent, half_x, half_y, height, base_z=0.20):
    for x in (-half_x, half_x):
        for y in (-half_y, half_y):
            cube("CornerPost", (0.075, 0.075, height), (x, y, base_z + height / 2), "dark_wood", parent, bevel=0.015)


def gabled_roof(parent, prefix, width, depth, ridge_z, mat_key):
    panel_depth = depth * 0.56
    angle = math.radians(27)
    for side in (-1, 1):
        cube(prefix + ("_Front" if side < 0 else "_Back"), (width, panel_depth, 0.11), (0, side * depth * 0.225, ridge_z), mat_key, parent, rotation=(side * angle, 0, 0), bevel=0.025)
    cylinder(prefix + "_Ridge", 0.055, width * 1.04, (0, 0, ridge_z + 0.20), "dark_wood", parent, 8, rotation=(0, math.radians(90), 0))


def window(parent, name, x, y, z):
    cube(name, (0.27, 0.055, 0.26), (x, y, z), "ink", parent)
    cube(name + "_V", (0.025, 0.062, 0.24), (x, y - 0.006, z), "thatch", parent)
    cube(name + "_H", (0.25, 0.062, 0.025), (x, y - 0.006, z), "thatch", parent)


def lantern(parent=None, location=(0, 0, 0), name="LanternPost"):
    r = root(name, "lantern") if parent is None else empty(name, location, parent)
    if parent is None:
        r.location = location
    cylinder("Post", 0.045, 1.28, (0, 0, 0.64), "dark_wood", r, 6, radius_top=0.035)
    cube("Crossbar", (0.42, 0.045, 0.045), (0.15, 0, 1.21), "dark_wood", r)
    cylinder("LanternBody", 0.14, 0.32, (0.31, 0, 0.99), "lantern", r, 8)
    cylinder("LanternGlow", 0.085, 0.25, (0.31, -0.002, 0.99), "lantern_light", r, 8)
    cylinder("LanternCapTop", 0.18, 0.08, (0.31, 0, 1.19), "grain", r, 8, radius_top=0.08)
    cylinder("LanternCapBottom", 0.18, 0.08, (0.31, 0, 0.79), "grain", r, 8, radius_top=0.08)
    cube("Tassel", (0.025, 0.025, 0.20), (0.31, 0, 0.65), "lantern", r)
    return r


def create_house():
    r = root("Building_House", "building")
    r["building_type"] = "house"
    cube("StonePlinth", (1.58, 1.48, 0.18), (0, 0, 0.09), "stone", r, bevel=0.035)
    cube("PlasterWalls", (1.34, 1.22, 0.82), (0, 0, 0.59), "warm_plaster", r, bevel=0.025)
    posts(r, 0.66, 0.60, 1.08)
    gabled_roof(r, "ThatchRoof", 1.68, 1.52, 1.10, "thatch")
    cube("FrontDoor", (0.32, 0.06, 0.56), (0, -0.64, 0.49), "dark_wood", r, bevel=0.015)
    window(r, "WindowLeft", -0.42, -0.64, 0.67)
    window(r, "WindowRight", 0.42, -0.64, 0.67)
    cylinder("Chimney", 0.095, 0.42, (-0.50, 0.20, 1.44), "brick", r, 6, radius_top=0.075)
    lantern(r, (0.54, -0.76, 0.02), "DoorLantern")
    empty("Door", (0, -0.92, 0), r)
    return r


def create_lumber():
    r = root("Building_Lumber", "building")
    r["building_type"] = "lumber"
    cube("PackedEarth", (1.72, 1.55, 0.14), (0, 0, 0.07), "soil", r, bevel=0.03)
    for x in (-0.68, 0.68):
        for y in (-0.54, 0.54):
            cylinder("ShedPost", 0.075, 1.24, (x, y, 0.70), "dark_wood", r, 6, radius_top=0.06)
    gabled_roof(r, "ShedRoof", 1.82, 1.58, 1.28, "tile_light")
    for i in range(6):
        cylinder("Log_%02d" % i, 0.105, 1.18, (-0.30 + (i % 3) * 0.28, 0.44, 0.22 + (i // 3) * 0.19), "wood", r, 7, rotation=(0, math.radians(90), 0))
    cube("CuttingBench", (0.86, 0.38, 0.12), (0.34, -0.24, 0.52), "wood", r, bevel=0.02)
    cylinder("SawBlade", 0.23, 0.035, (0.34, -0.25, 0.75), "stone_light", r, 12, rotation=(math.radians(90), 0, 0))
    cube("AxeHandle", (0.035, 0.035, 0.52), (0.63, -0.45, 0.54), "thatch", r, rotation=(0, math.radians(-18), 0))
    cube("AxeHead", (0.22, 0.06, 0.13), (0.54, -0.45, 0.77), "ink", r)
    empty("Door", (0, -0.92, 0), r)
    return r


def crop_patch(parent=None, name="CropPatch"):
    r = root(name, "crops") if parent is None else empty(name, (0, 0, 0), parent)
    for row in range(3):
        y = -0.48 + row * 0.48
        cube("SoilRow_%02d" % row, (1.48, 0.25, 0.10), (0, y, 0.10), "soil", r, bevel=0.025)
        for plant in range(4):
            x = -0.56 + plant * 0.38
            cylinder("Stem_%02d_%02d" % (row, plant), 0.025, 0.34, (x, y, 0.31), "crop", r, 5, radius_top=0.018)
            cylinder("Grain_%02d_%02d" % (row, plant), 0.045, 0.14, (x, y, 0.52), "grain", r, 6, radius_top=0.025)
    return r


def create_farm():
    r = root("Building_Farm", "building")
    r["building_type"] = "farm"
    cube("FieldEdge", (1.72, 1.72, 0.12), (0, 0, 0.06), "thatch", r, bevel=0.03)
    crop_patch(r, "CropRows")
    cylinder("ScarecrowPost", 0.04, 0.92, (0.56, 0.52, 0.55), "dark_wood", r, 5, radius_top=0.03)
    cube("ScarecrowArms", (0.55, 0.045, 0.045), (0.56, 0.52, 0.78), "dark_wood", r)
    sphere("ScarecrowHead", 0.10, (0.56, 0.52, 0.96), "thatch", r, scale=(0.9, 0.9, 1.1))
    cylinder("ScarecrowHat", 0.18, 0.14, (0.56, 0.52, 1.09), "thatch", r, 7, radius_top=0.04)
    empty("Door", (0, -0.92, 0), r)
    return r


def create_warehouse():
    r = root("Building_Warehouse", "building")
    r["building_type"] = "warehouse"
    cube("StonePlinth", (1.70, 1.68, 0.28), (0, 0, 0.14), "stone", r, bevel=0.04)
    cube("WarehouseWalls", (1.48, 1.40, 1.16), (0, 0, 0.83), "plaster", r, bevel=0.025)
    posts(r, 0.72, 0.67, 1.38)
    gabled_roof(r, "TileRoof", 1.82, 1.72, 1.50, "tile")
    cube("DoubleDoor", (0.66, 0.07, 0.76), (0, -0.73, 0.66), "dark_wood", r, bevel=0.015)
    cube("DoorSeam", (0.025, 0.075, 0.72), (0, -0.77, 0.66), "thatch", r)
    for i in range(3):
        cube("Crate_%02d" % i, (0.30, 0.30, 0.28), (-0.46 + i * 0.33, 0.79, 0.30), "wood", r, bevel=0.025)
    cube("WarehouseSign", (0.48, 0.06, 0.24), (0, -0.79, 1.38), "brick", r, bevel=0.018)
    empty("Door", (0, -0.94, 0), r)
    return r


def create_workshop():
    r = root("Building_Workshop", "building")
    r["building_type"] = "workshop"
    cube("StoneFloor", (1.70, 1.60, 0.18), (0, 0, 0.09), "stone", r, bevel=0.035)
    cube("WorkshopWalls", (1.42, 1.30, 1.02), (0, 0.05, 0.69), "brick", r, bevel=0.025)
    posts(r, 0.69, 0.62, 1.22)
    gabled_roof(r, "WorkshopRoof", 1.78, 1.62, 1.32, "tile")
    cube("WorkshopDoor", (0.42, 0.06, 0.68), (-0.27, -0.63, 0.57), "dark_wood", r, bevel=0.015)
    awning = cube("Awning", (0.74, 0.44, 0.08), (0.34, -0.79, 1.08), "thatch", r, rotation=(math.radians(12), 0, 0), bevel=0.02)
    cylinder("Chimney", 0.15, 0.88, (0.50, 0.34, 1.64), "ink", r, 7, radius_top=0.11)
    cube("AnvilBase", (0.22, 0.22, 0.34), (0.52, -0.67, 0.32), "dark_wood", r)
    cube("Anvil", (0.42, 0.20, 0.15), (0.52, -0.67, 0.55), "stone_light", r, bevel=0.025)
    cylinder("ForgeBowl", 0.24, 0.16, (0.58, 0.48, 0.42), "ink", r, 8, radius_top=0.18)
    cylinder("ForgeGlow", 0.14, 0.04, (0.58, 0.48, 0.52), "lantern_light", r, 8)
    empty("Door", (0, -0.92, 0), r)
    return r


def create_bridge():
    r = root("Bridge_Wood_01", "bridge")
    for i in range(8):
        x = -1.75 + i * 0.5
        rise = 0.12 * (1.0 - abs(x) / 2.0)
        cube("DeckPlank_%02d" % i, (0.46, 1.38, 0.12), (x, 0, 0.26 + rise), "wood", r, bevel=0.02)
    for side in (-1, 1):
        for i in range(5):
            x = -1.8 + i * 0.9
            cylinder("RailPost", 0.055, 0.62, (x, side * 0.63, 0.65), "dark_wood", r, 6, radius_top=0.045)
        cube("Handrail", (3.9, 0.07, 0.07), (0, side * 0.63, 0.94), "dark_wood", r, bevel=0.015)
    for x in (-1.45, 1.45):
        cube("StonePier", (0.28, 1.66, 0.52), (x, 0, 0.02), "stone", r, bevel=0.035)
    return r


def create_tree(variant):
    r = root("Tree_%02d" % variant, "tree")
    height_scale = (0.92, 1.08, 1.0)[variant]
    cylinder("Trunk", 0.16, 1.18 * height_scale, (0, 0, 0.62 * height_scale), "dark_wood", r, 6, radius_top=0.10)
    cylinder("CrownLower", 0.72, 0.95, (0, 0, 1.42 * height_scale), "leaf", r, 7, radius_top=0.48)
    cylinder("CrownUpper", 0.54, 0.90, (0.06 * (variant % 2), 0, 2.08 * height_scale), "leaf_light", r, 7, radius_top=0.10)
    if variant == 2:
        sphere("CrownAccent", 0.35, (-0.34, -0.08, 1.72), "leaf", r, scale=(1.0, 0.9, 0.82))
    return r


def create_rock(variant):
    r = root("Rock_%02d" % variant, "rock")
    scales = ((0.68, 0.52, 0.42), (0.46, 0.55, 0.66), (0.78, 0.66, 0.36))
    sphere("MainStone", 0.5, (0, 0, 0.30), "stone", r, scale=scales[variant])
    sphere("LightFace", 0.24, (-0.26, -0.18, 0.31), "stone_light", r, scale=(0.9, 0.75, 0.55))
    return r


def create_citizen():
    r = root("Citizen_01", "citizen")
    cylinder("Body", 0.24, 0.58, (0, 0, 0.47), "cloth_rust", r, 7, radius_top=0.15)
    sphere("Head", 0.17, (0, 0, 0.91), "skin", r)
    cylinder("HatBrim", 0.25, 0.045, (0, 0, 1.08), "thatch", r, 10)
    cylinder("HatCrown", 0.17, 0.14, (0, 0, 1.16), "thatch", r, 8, radius_top=0.04)
    for side in (-1, 1):
        arm = cylinder("Arm_L" if side < 0 else "Arm_R", 0.055, 0.40, (side * 0.22, 0, 0.52), "cloth_rust", r, 6, radius_top=0.045)
        arm.rotation_euler[1] = math.radians(side * 12)
    cube("Feet", (0.32, 0.22, 0.08), (0, 0.02, 0.13), "dark_wood", r, bevel=0.015)
    return r


def descendants(obj):
    result = [obj]
    for child in obj.children:
        result.extend(descendants(child))
    return result


def export_asset(asset_root, filename, godot_entry_z=0.0):
    bpy.ops.object.select_all(action="DESELECT")
    objects = descendants(asset_root)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = asset_root
    path = MODEL_DIR / filename
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_materials="EXPORT",
        export_extras=True,
        export_cameras=False,
        export_lights=False,
    )
    mesh_objects = [obj for obj in objects if obj.type == "MESH"]
    triangles = 0
    for obj in mesh_objects:
        triangles += sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons)
    ASSETS.append({
        "file": filename,
        "root": asset_root.name,
        "asset_type": asset_root.get("asset_type", "prop"),
        "building_type": asset_root.get("building_type", ""),
        "mesh_parts": len(mesh_objects),
        "triangles_unmodified": triangles,
        "origin": "ground_center",
        "godot_entrance_axis": "+Z" if godot_entry_z > 0 else "n/a",
    })


def point_camera(camera, target):
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def add_label(text, location):
    bpy.ops.object.text_add(location=location, rotation=(math.radians(67), 0, 0))
    obj = bpy.context.object
    obj.data.body = text
    obj.data.align_x = "CENTER"
    obj.data.size = 0.32
    obj.data.extrude = 0.006
    obj.data.materials.append(MATERIALS[("ink", PALETTE["ink"], 0.88, 0.0)])


def build_preview(asset_roots):
    layout = {
        "Building_House": (-4.4, 2.1, 0),
        "Building_Lumber": (-2.2, 2.1, 0),
        "Building_Farm": (0, 2.1, 0),
        "Building_Warehouse": (2.2, 2.1, 0),
        "Building_Workshop": (4.4, 2.1, 0),
        "Bridge_Wood_01": (-3.2, -2.3, 0),
        "Tree_00": (-5.0, -2.3, 0),
        "Rock_00": (-0.9, -2.3, 0),
        "LanternPost": (0.1, -2.3, 0),
        "CropPatch": (1.5, -2.3, 0),
        "Citizen_01": (3.7, -2.3, 0),
    }
    labels = {
        "Building_House": "HOUSE",
        "Building_Lumber": "LUMBER",
        "Building_Farm": "FARM",
        "Building_Warehouse": "WAREHOUSE",
        "Building_Workshop": "WORKSHOP",
    }
    for obj in asset_roots:
        if obj.name in layout:
            obj.location = layout[obj.name]
        else:
            for hidden in descendants(obj):
                hidden.hide_render = True
    for name, text in labels.items():
        x, y, _ = layout[name]
        add_label(text, (x, y - 1.05, 0.025))

    cube("PreviewGround", (12.5, 7.2, 0.08), (0, 0, -0.06), "plaster", bevel=0.08)
    bpy.ops.object.light_add(type="AREA", location=(-4, -5, 9))
    key = bpy.context.object
    key.name = "PreviewKey"
    key.data.energy = 900
    key.data.shape = "DISK"
    key.data.size = 5.5
    key.data.color = (1.0, 0.82, 0.62)
    point_camera(key, (0, 0, 0))
    bpy.ops.object.light_add(type="AREA", location=(5, 1, 6))
    fill = bpy.context.object
    fill.name = "PreviewFill"
    fill.data.energy = 500
    fill.data.size = 6.0
    fill.data.color = (0.65, 0.82, 0.84)
    point_camera(fill, (0, 0, 0.7))
    bpy.ops.object.camera_add(location=(7.4, -14.5, 13.2))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 13.5
    point_camera(camera, (0, 0, 0.65))
    bpy.context.scene.camera = camera

    world = bpy.context.scene.world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = rgba("#b9d7d5")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.42
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 820
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_DIR / "asset_sheet.png")
    scene.render.film_transparent = False
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / "east_valley_art_kit.blend"))
    bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        pass
    setup_materials()

    builders = [
        (create_house, "building_house.glb", 1.0),
        (create_lumber, "building_lumber.glb", 1.0),
        (create_farm, "building_farm.glb", 1.0),
        (create_warehouse, "building_warehouse.glb", 1.0),
        (create_workshop, "building_workshop.glb", 1.0),
        (create_bridge, "prop_bridge.glb", 0.0),
        (lambda: create_tree(0), "prop_tree_01.glb", 0.0),
        (lambda: create_tree(1), "prop_tree_02.glb", 0.0),
        (lambda: create_tree(2), "prop_tree_03.glb", 0.0),
        (lambda: create_rock(0), "prop_rock_01.glb", 0.0),
        (lambda: create_rock(1), "prop_rock_02.glb", 0.0),
        (lambda: create_rock(2), "prop_rock_03.glb", 0.0),
        (lantern, "prop_lantern.glb", 0.0),
        (crop_patch, "prop_crops.glb", 0.0),
        (create_citizen, "character_citizen.glb", 0.0),
    ]
    roots = []
    for builder, filename, has_entry in builders:
        asset_root = builder()
        roots.append(asset_root)
        export_asset(asset_root, filename, has_entry)

    manifest = {
        "generator": "tools/generate_lowpoly_assets.py",
        "art_version": 1,
        "tile_meters": 2.0,
        "coordinate_contract": "ground center origin; Godot +Z building entrance",
        "palette": PALETTE,
        "assets": ASSETS,
    }
    (MODEL_DIR / "asset_manifest.json").write_text(json.dumps(manifest, ensure_ascii=True, indent=2), encoding="utf-8")
    build_preview(roots)
    print("EAST_VALLEY_ASSETS_OK", len(ASSETS), MODEL_DIR)


if __name__ == "__main__":
    main()
