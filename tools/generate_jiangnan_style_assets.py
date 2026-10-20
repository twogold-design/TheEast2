"""Build the Jiangnan ink-wash building set for The East.

The generator deliberately writes to a new asset tier.  Existing realistic assets
remain untouched and can still be used as a fallback.  Buildings are designed for
the game's high isometric camera: their front edge is open, the roof only covers
the rear half, and the work area is visible from above.

Run with Blender 4.x in background mode from ``M:\\NewGames\\TheEast``.
"""

from __future__ import annotations

import json
import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT = Path(os.environ.get("THE_EAST_PROJECT", r"M:\\NewGames\\TheEast"))
ROOT = PROJECT / "godot" / "assets" / "jiangnan_style_v2"
MODEL_DIR = ROOT / "models"
SOURCE_DIR = ROOT / "source"
PREVIEW_DIR = ROOT / "previews"
for path in (MODEL_DIR, SOURCE_DIR, PREVIEW_DIR):
    path.mkdir(parents=True, exist_ok=True)

MATS: dict[str, bpy.types.Material] = {}
RECORDS: list[dict] = []


PALETTE = {
    "plaster": ((0.78, 0.73, 0.61), 0.90),
    "plaster_warm": ((0.67, 0.57, 0.43), 0.92),
    "wood": ((0.24, 0.12, 0.06), 0.84),
    "wood_light": ((0.50, 0.29, 0.12), 0.82),
    "wood_red": ((0.39, 0.12, 0.08), 0.75),
    "roof": ((0.17, 0.26, 0.26), 0.80),
    "roof_edge": ((0.10, 0.16, 0.17), 0.86),
    "stone": ((0.38, 0.40, 0.36), 0.95),
    "stone_light": ((0.58, 0.56, 0.45), 0.95),
    "brick": ((0.46, 0.22, 0.13), 0.92),
    "iron": ((0.10, 0.11, 0.10), 0.66),
    "gold": ((0.62, 0.37, 0.10), 0.48),
    "cloth_red": ((0.52, 0.11, 0.08), 0.92),
    "cloth_blue": ((0.16, 0.30, 0.33), 0.91),
    "cloth_cream": ((0.76, 0.67, 0.48), 0.90),
    "paper": ((0.86, 0.80, 0.64), 0.88),
    "water": ((0.18, 0.39, 0.42), 0.28),
    "soil": ((0.25, 0.14, 0.07), 0.98),
    "crop": ((0.25, 0.46, 0.16), 0.88),
    "leaf": ((0.20, 0.39, 0.19), 0.86),
    "bamboo": ((0.43, 0.48, 0.20), 0.88),
    "ink": ((0.035, 0.045, 0.042), 0.92),
    "warm": ((0.86, 0.28, 0.08), 0.52),
}


def make_material(name: str, color: tuple[float, float, float], roughness: float) -> bpy.types.Material:
    material = bpy.data.materials.new("JNV2_%s" % name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    for node in list(nodes):
        nodes.remove(node)
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Specular IOR Level"].default_value = 0.25
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def setup_materials() -> None:
    for name, (color, roughness) in PALETTE.items():
        MATS[name] = make_material(name, color, roughness)


def root(name: str, building_type: str, bounds: tuple[float, float, float]) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj["asset_type"] = "building"
    obj["building_type"] = building_type
    obj["art_style"] = "jiangnan_ink_wash"
    obj["art_version"] = 2
    obj["tile_meters"] = 2.0
    obj["entrance_axis_godot"] = "+Z"
    obj["bounds_m"] = "%.2f,%.2f,%.2f" % bounds
    obj["fallback_key"] = building_type
    return obj


def attach(obj: bpy.types.Object, parent: bpy.types.Object | None) -> bpy.types.Object:
    if parent:
        obj.parent = parent
    return obj


def finish(obj: bpy.types.Object, material: str, bevel: float = 0.0, smooth: bool = False) -> bpy.types.Object:
    obj.data.materials.append(MATS[material])
    if bevel:
        modifier = obj.modifiers.new("Soft ink-wash edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    # Smart UV keeps exported geometry editable while preserving material scale.
    if obj.type == "MESH":
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(70), island_margin=0.025)
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.select_set(False)
    return obj


def cube(name: str, size: tuple[float, float, float], location: tuple[float, float, float], material: str,
         parent: bpy.types.Object | None = None, rotation: tuple[float, float, float] = (0, 0, 0),
         bevel: float = 0.0) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return attach(finish(obj, material, bevel), parent)


def cylinder(name: str, radius: float, depth: float, location: tuple[float, float, float], material: str,
             parent: bpy.types.Object | None = None, vertices: int = 16,
             rotation: tuple[float, float, float] = (0, 0, 0), top_radius: float | None = None,
             bevel: float = 0.0) -> bpy.types.Object:
    if top_radius is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                            location=location, rotation=rotation)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=top_radius,
                                        depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    return attach(finish(obj, material, bevel, True), parent)


def sphere(name: str, radius: float, location: tuple[float, float, float], material: str,
           parent: bpy.types.Object | None = None, scale: tuple[float, float, float] = (1, 1, 1)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return attach(finish(obj, material, 0.006, True), parent)


def marker(name: str, location: tuple[float, float, float], parent: bpy.types.Object) -> None:
    node = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(node)
    node.location = location
    node.parent = parent


def beam_between(name: str, start: tuple[float, float, float], end: tuple[float, float, float], radius: float,
                material: str, parent: bpy.types.Object) -> bpy.types.Object:
    a, b = Vector(start), Vector(end)
    obj = cylinder(name, radius, (b - a).length, tuple((a + b) * 0.5), material, parent, 12)
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return obj


def roof(parent: bpy.types.Object, width: float, depth: float, ridge_z: float, angle: float = 27.0,
         rows: int = 4, columns: int = 13) -> None:
    """Rear half roof, leaving the front courtyard open to the camera."""
    radians = math.radians(angle)
    first_y, last_y = 0.00, depth
    spacing = depth / max(1, rows)
    tile_width = width / columns
    for row in range(rows):
        y = first_y + spacing * (row + 0.5)
        z = ridge_z - y * math.tan(radians)
        for col in range(columns):
            x = -width / 2 + tile_width * (col + 0.5)
            cube("RoofTile_%02d_%02d" % (row, col), (tile_width * 1.16, spacing * 1.22, 0.10),
                 (x, y, z), "roof", parent, rotation=(-radians, 0, 0), bevel=0.012)
    cylinder("RoofRidge", 0.075, width + 0.16, (0, 0.00, ridge_z + 0.035), "roof_edge", parent,
             18, rotation=(0, math.radians(90), 0), bevel=0.004)
    # A dark rear fascia makes the open/closed boundary readable from the planning camera.
    eave_z = ridge_z - depth * math.tan(radians)
    cube("RearEave", (width + 0.15, 0.13, 0.12), (0, depth + 0.03, eave_z - 0.02), "roof_edge", parent,
         rotation=(-radians, 0, 0), bevel=0.014)


def front_awning(parent: bpy.types.Object, width: float, y: float, z: float, material: str = "roof") -> None:
    # One shallow canopy above the entrance; it does not hide the interior work area.
    angle = math.radians(12)
    cube("FrontAwning", (width, 0.58, 0.09), (0, y, z), material, parent, rotation=(angle, 0, 0), bevel=0.010)
    for x in (-width * 0.42, width * 0.42):
        cylinder("AwningPost", 0.045, z - 0.25, (x, y - 0.18, (z - 0.25) / 2), "wood", parent, 12, bevel=0.004)


def foundation(parent: bpy.types.Object, width: float, depth: float) -> None:
    cube("Foundation", (width, depth, 0.18), (0, 0, 0.09), "stone", parent, bevel=0.035)
    cube("RaisedFloor", (width - 0.16, depth - 0.16, 0.12), (0, 0, 0.24), "wood_light", parent, bevel=0.014)


def post_set(parent: bpy.types.Object, width: float, y_front: float, y_back: float, z: float = 1.10) -> None:
    for x in (-width / 2, width / 2):
        for y in (y_front, y_back):
            cylinder("TimberPost", 0.065, z * 2, (x, y, z), "wood", parent, 14, bevel=0.005)
    for y in (y_front, y_back):
        cube("TopBeam", (width + 0.18, 0.12, 0.12), (0, y, z * 2 - 0.05), "wood_red", parent, bevel=0.010)


def lattice_window(parent: bpy.types.Object, x: float, y: float, z: float, width: float = 0.42) -> None:
    cube("WindowPaper", (width, 0.025, 0.38), (x, y, z), "paper", parent, bevel=0.004)
    for offset in (-width * 0.30, 0, width * 0.30):
        cube("WindowLatticeV", (0.024, 0.035, 0.38), (x + offset, y - 0.025, z), "wood_red", parent, bevel=0.003)
    cube("WindowFrameTop", (width + 0.10, 0.06, 0.05), (x, y - 0.02, z + 0.22), "wood", parent, bevel=0.004)


def add_lantern(parent: bpy.types.Object, x: float, y: float, z: float = 1.55) -> None:
    cylinder("LanternFrame", 0.13, 0.22, (x, y, z), "cloth_red", parent, 12, top_radius=0.10, bevel=0.004)
    cylinder("LanternCap", 0.15, 0.035, (x, y, z + 0.14), "wood", parent, 12, bevel=0.003)
    cylinder("LanternTassel", 0.012, 0.22, (x, y, z - 0.20), "gold", parent, 8, bevel=0.001)


def add_table(parent: bpy.types.Object, x: float, y: float, z: float = 0.53, width: float = 0.65, depth: float = 0.38) -> None:
    cube("WorkTableTop", (width, depth, 0.09), (x, y, z), "wood_light", parent, bevel=0.012)
    for dx in (-width * 0.38, width * 0.38):
        for dy in (-depth * 0.34, depth * 0.34):
            cube("WorkTableLeg", (0.06, 0.06, z - 0.08), (x + dx, y + dy, (z - 0.08) / 2), "wood", parent, bevel=0.003)


def add_crate(parent: bpy.types.Object, x: float, y: float, z: float = 0.44, size: float = 0.32) -> None:
    cube("Crate", (size, size, size), (x, y, z), "wood_light", parent, bevel=0.018)
    for axis in (-1, 1):
        cube("CrateBand", (size * 0.78, 0.025, 0.035), (x, y + axis * size * 0.51, z), "wood", parent, bevel=0.004)
    cube("CrateMark", (size * 0.08, 0.03, size * 0.30), (x, y - size * 0.53, z), "ink", parent, bevel=0.002)


def add_sack(parent: bpy.types.Object, x: float, y: float, z: float = 0.40, scale: float = 1.0) -> None:
    sphere("GrainSack", 0.24 * scale, (x, y, z), "cloth_cream", parent, (0.76, 0.58, 1.18))
    cylinder("SackTie", 0.035 * scale, 0.12 * scale, (x, y, z + 0.24 * scale), "rope" if "rope" in MATS else "wood", parent, 8)


def add_bamboo(parent: bpy.types.Object, x: float, y: float, height: float = 1.7) -> None:
    cylinder("BambooStem", 0.035, height, (x, y, height / 2 + 0.25), "bamboo", parent, 10, top_radius=0.028, bevel=0.003)
    for z in (0.62, 1.05, 1.48):
        cylinder("BambooJoint", 0.050, 0.05, (x, y, z), "bamboo", parent, 10, bevel=0.002)
    for dx, dz in ((0.24, 0.26), (-0.20, 0.42), (0.18, 0.68)):
        beam_between("BambooLeaf", (x, y, height * 0.56), (x + dx, y, height * 0.56 + dz), 0.018,
                     "leaf", parent)


def build_house() -> bpy.types.Object:
    r = root("Jiangnan_House_Open", "house", (2.30, 2.20, 2.25))
    foundation(r, 2.10, 1.80)
    post_set(r, 1.78, -0.72, 0.62, 1.00)
    # Rear white wall and side screens keep the silhouette while preserving a visible courtyard.
    cube("RearPlasterWall", (1.62, 0.10, 1.15), (0, 0.58, 0.89), "plaster", r, bevel=0.018)
    cube("LeftScreenWall", (0.10, 1.24, 0.90), (-0.84, -0.02, 0.82), "plaster", r, bevel=0.014)
    cube("RightScreenWall", (0.10, 1.24, 0.90), (0.84, -0.02, 0.82), "plaster", r, bevel=0.014)
    lattice_window(r, -0.48, 0.515, 1.05, 0.42)
    lattice_window(r, 0.48, 0.515, 1.05, 0.42)
    cube("FrontThreshold", (0.86, 0.12, 0.08), (0, -0.78, 0.32), "stone_light", r, bevel=0.008)
    add_table(r, 0.0, 0.20, 0.55, 0.62, 0.38)
    for x in (-0.40, 0.40):
        cylinder("CourtyardJar", 0.13, 0.25, (x, -0.28, 0.43), "stone_light", r, 14, top_radius=0.10, bevel=0.006)
    add_lantern(r, -0.63, 0.47, 1.58)
    add_bamboo(r, 0.67, 0.36, 1.50)
    roof(r, 2.10, 0.98, 2.14, 27, 4, 14)
    front_awning(r, 1.58, -0.69, 1.56)
    marker("Door", (0, -1.02, 0), r)
    return r


def build_farm() -> bpy.types.Object:
    r = root("Jiangnan_Farm_Open", "farm", (2.50, 2.15, 2.15))
    foundation(r, 2.28, 1.88)
    cube("WetPaddy", (2.08, 1.68, 0.05), (0, 0.02, 0.34), "water", r, bevel=0.012)
    for x in (-0.68, 0, 0.68):
        cube("PaddyRidge", (0.50, 1.42, 0.16), (x, 0.05, 0.44), "soil", r, bevel=0.040)
        for row, y in enumerate((-0.52, -0.17, 0.18, 0.53)):
            for i in range(3):
                xx = x - 0.12 + i * 0.12
                beam_between("RiceStem", (xx, y, 0.52), (xx + (0.02 if i % 2 else -0.015), y, 0.84), 0.012, "crop", r)
                sphere("RiceHead", 0.028, (xx + 0.01, y, 0.84), "cloth_cream", r, (0.60, 0.60, 1.35))
    # Open farm shed at the back, with visible tools and a short rear roof.
    post_set(r, 1.30, 0.24, 0.70, 0.92)
    cube("FarmBackWall", (1.34, 0.08, 0.82), (0, 0.68, 0.76), "wood_light", r, bevel=0.014)
    roof(r, 1.52, 0.72, 1.87, 24, 3, 10)
    add_crate(r, -0.40, 0.24, 0.48, 0.25)
    add_crate(r, -0.10, 0.25, 0.48, 0.25)
    cylinder("WaterWheel", 0.30, 0.08, (0.43, 0.48, 0.72), "wood", r, 16, rotation=(math.radians(90), 0, 0), bevel=0.006)
    for angle in range(0, 360, 45):
        rad = math.radians(angle)
        beam_between("WaterWheelSpoke", (0.43, 0.43, 0.72), (0.43 + math.cos(rad) * 0.27, 0.43, 0.72 + math.sin(rad) * 0.27), 0.018, "wood_light", r)
    add_bamboo(r, -0.92, 0.57, 1.55)
    marker("Door", (0, -1.06, 0), r)
    return r


def build_lumber() -> bpy.types.Object:
    r = root("Jiangnan_Lumber_Open", "lumber", (2.55, 2.28, 2.25))
    foundation(r, 2.32, 1.94)
    post_set(r, 2.02, -0.72, 0.72, 1.05)
    roof(r, 2.32, 1.03, 2.15, 26, 4, 14)
    # Stacks and saw bench remain fully visible because the front roof half is omitted.
    for level in range(3):
        for index in range(3 - level % 2):
            y = 0.33 + (index - 1) * 0.22
            cylinder("LogStack", 0.095, 1.02, (-0.62, y, 0.46 + level * 0.19), "wood_light", r, 14,
                     rotation=(0, math.radians(90), 0), bevel=0.004)
    add_table(r, 0.44, -0.30, 0.69, 0.90, 0.44)
    cylinder("SawBlade", 0.24, 0.035, (0.44, -0.54, 0.84), "iron", r, 24, rotation=(math.radians(90), 0, 0), bevel=0.002)
    cylinder("SawHub", 0.05, 0.05, (0.44, -0.57, 0.84), "gold", r, 12, rotation=(math.radians(90), 0, 0), bevel=0.002)
    cube("AxeHandle", (0.05, 0.05, 0.78), (-0.82, -0.68, 0.72), "wood_light", r, rotation=(0, math.radians(-18), 0), bevel=0.005)
    cube("AxeHead", (0.28, 0.08, 0.18), (-0.95, -0.68, 1.05), "iron", r, rotation=(0, math.radians(-18), 0), bevel=0.014)
    add_lantern(r, 0.84, 0.63, 1.60)
    marker("Door", (0, -1.06, 0), r)
    return r


def build_warehouse() -> bpy.types.Object:
    r = root("Jiangnan_Warehouse_Open", "warehouse", (2.65, 2.55, 2.40))
    foundation(r, 2.42, 2.05)
    post_set(r, 2.12, -0.78, 0.78, 1.16)
    cube("RearWarehouseWall", (2.05, 0.11, 1.46), (0, 0.76, 1.04), "plaster_warm", r, bevel=0.024)
    roof(r, 2.42, 1.06, 2.38, 29, 4, 15)
    cube("LoadingRamp", (1.48, 0.68, 0.12), (0, -1.08, 0.35), "wood_light", r, rotation=(math.radians(-10), 0, 0), bevel=0.012)
    for x in (-0.72, 0.72):
        add_sack(r, x, 0.12, 0.55, 1.0)
        add_sack(r, x + 0.17, 0.37, 0.48, 0.82)
    add_crate(r, -0.55, -0.40, 0.50, 0.36)
    add_crate(r, -0.11, -0.40, 0.50, 0.36)
    cube("WarehouseSign", (0.72, 0.07, 0.25), (0, -0.84, 1.82), "wood_red", r, bevel=0.015)
    for x in (-0.22, 0, 0.22):
        cube("SignBrushMark", (0.05, 0.02, 0.13), (x, -0.89, 1.82), "gold", r, bevel=0.002)
    marker("Door", (0, -1.45, 0), r)
    return r


def build_workshop() -> bpy.types.Object:
    r = root("Jiangnan_Workshop_Open", "workshop", (2.65, 2.45, 2.80))
    foundation(r, 2.40, 1.98)
    post_set(r, 2.08, -0.75, 0.70, 1.10)
    cube("RearBrickWall", (2.04, 0.10, 1.42), (0, 0.70, 1.08), "brick", r, bevel=0.020)
    roof(r, 2.38, 1.00, 2.32, 28, 4, 15)
    # Forge and anvil form the readable production core from the top-down view.
    cube("ForgeBody", (0.65, 0.50, 0.70), (0.53, 0.27, 0.67), "brick", r, bevel=0.025)
    cube("Firebox", (0.40, 0.08, 0.28), (0.53, -0.01, 0.67), "iron", r, bevel=0.022)
    sphere("ForgeEmber", 0.14, (0.53, -0.06, 0.67), "warm", r, (1.0, 0.35, 0.65))
    cylinder("Chimney", 0.16, 1.42, (0.53, 0.30, 2.00), "brick", r, 14, top_radius=0.13, bevel=0.008)
    cylinder("ChimneyCap", 0.21, 0.08, (0.53, 0.30, 2.73), "roof_edge", r, 16, bevel=0.004)
    add_table(r, -0.42, -0.26, 0.70, 0.92, 0.42)
    cube("AnvilBase", (0.28, 0.29, 0.43), (0.48, -0.48, 0.48), "wood", r, bevel=0.020)
    cube("AnvilTop", (0.52, 0.25, 0.16), (0.48, -0.48, 0.77), "iron", r, bevel=0.030)
    cube("ToolRack", (0.72, 0.06, 0.62), (-0.53, 0.64, 1.04), "wood", r, bevel=0.010)
    for x in (-0.75, -0.53, -0.31):
        cylinder("HangingTool", 0.02, 0.45, (x, 0.60, 1.04), "iron", r, 8, bevel=0.002)
    add_lantern(r, 0.82, 0.60, 1.60)
    marker("Door", (-0.45, -1.06, 0), r)
    return r


def build_market() -> bpy.types.Object:
    r = root("Jiangnan_Market_Open", "market", (2.75, 2.35, 2.20))
    foundation(r, 2.50, 2.02)
    # Two open stalls share a ridge; only light cloth canopies sit above the goods.
    for x, cloth in ((-0.62, "cloth_red"), (0.62, "cloth_blue")):
        for y in (-0.64, 0.62):
            cylinder("MarketPost", 0.055, 1.60, (x, y, 1.04), "wood", r, 12, bevel=0.004)
        cube("MarketCanopy", (1.08, 1.12, 0.08), (x, 0.0, 1.88), cloth, r, rotation=(math.radians(4), 0, 0), bevel=0.014)
        add_table(r, x, -0.18, 0.62, 0.98, 0.42)
        for i in range(3):
            sphere("MarketBasket", 0.12, (x - 0.30 + i * 0.30, -0.20, 0.77), "wood_light", r, (1.0, 0.72, 0.68))
    for x in (-0.88, -0.56, 0.56, 0.88):
        add_sack(r, x, 0.42, 0.52, 0.74)
    cube("MarketSign", (0.74, 0.06, 0.24), (0, -0.79, 1.75), "wood_red", r, bevel=0.012)
    add_lantern(r, 0, 0.66, 1.55)
    marker("Door", (0, -1.14, 0), r)
    return r


def build_tea_pavilion() -> bpy.types.Object:
    r = root("Jiangnan_Tea_Pavilion_Open", "tea_pavilion", (2.45, 2.35, 2.30))
    foundation(r, 2.22, 1.98)
    for x in (-0.87, 0.87):
        for y in (-0.73, 0.73):
            cylinder("PavilionPost", 0.065, 1.72, (x, y, 1.10), "wood_red", r, 14, bevel=0.005)
    # Four-sided back roof with a generous open front; the table remains visible.
    roof(r, 2.18, 0.96, 2.20, 26, 4, 13)
    cube("PavilionBackScreen", (1.96, 0.08, 0.84), (0, 0.66, 0.75), "paper", r, bevel=0.010)
    add_table(r, 0, -0.02, 0.67, 0.84, 0.52)
    for x in (-0.48, 0.48):
        cylinder("TeaStool", 0.15, 0.28, (x, -0.02, 0.41), "wood_light", r, 14, top_radius=0.13, bevel=0.006)
    for x in (-0.22, 0.22):
        cylinder("TeaCup", 0.075, 0.07, (x, -0.02, 0.76), "paper", r, 14, top_radius=0.06, bevel=0.003)
    add_bamboo(r, -1.02, 0.42, 1.62)
    add_lantern(r, 0.00, 0.70, 1.62)
    marker("Door", (0, -1.02, 0), r)
    return r


def descendants(obj: bpy.types.Object) -> list[bpy.types.Object]:
    result = [obj]
    for child in obj.children:
        result.extend(descendants(child))
    return result


def export_asset(asset_root: bpy.types.Object, filename: str) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    objects = descendants(asset_root)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = asset_root
    output = MODEL_DIR / filename
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True, export_materials="EXPORT",
                              export_extras=True, export_cameras=False, export_lights=False,
                              export_image_format="AUTO")
    meshes = [obj for obj in objects if obj.type == "MESH"]
    tris = sum(sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons) for obj in meshes)
    RECORDS.append({
        "file": filename,
        "root": asset_root.name,
        "asset_type": asset_root.get("asset_type", "building"),
        "building_type": asset_root.get("building_type", ""),
        "fallback_key": asset_root.get("fallback_key", ""),
        "godot_entrance_axis": "+Z",
        "art_style": "jiangnan_ink_wash",
        "mesh_parts": len(meshes),
        "triangles_before_modifiers": tris,
        "functional_read": "open_front_visible_work_area",
    })


def aim(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def build_preview(roots: list[bpy.types.Object]) -> None:
    positions = {
        "Jiangnan_House_Open": (-4.7, 2.15, 0),
        "Jiangnan_Farm_Open": (-1.55, 2.15, 0),
        "Jiangnan_Lumber_Open": (1.65, 2.15, 0),
        "Jiangnan_Warehouse_Open": (4.85, 2.15, 0),
        "Jiangnan_Workshop_Open": (-3.15, -1.65, 0),
        "Jiangnan_Market_Open": (0.0, -1.65, 0),
        "Jiangnan_Tea_Pavilion_Open": (3.25, -1.65, 0),
    }
    for obj in roots:
        obj.location = positions[obj.name]
    cube("GalleryGround", (14.4, 9.2, 0.14), (0, 0.25, -0.10), "stone", bevel=0.04)
    bpy.ops.object.light_add(type="AREA", location=(-6.5, -7.0, 10.5))
    key = bpy.context.object
    key.data.energy = 950
    key.data.shape = "DISK"
    key.data.size = 5.0
    key.data.color = (1.0, 0.75, 0.53)
    aim(key, (0, 0, 0.8))
    bpy.ops.object.light_add(type="AREA", location=(6.0, 3.0, 8.0))
    fill = bpy.context.object
    fill.data.energy = 650
    fill.data.size = 6.0
    fill.data.color = (0.50, 0.68, 0.78)
    aim(fill, (0, 0, 1.2))
    bpy.ops.object.camera_add(location=(0, -18.0, 11.2))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 13.2
    aim(camera, (0, 0.25, 1.1))
    bpy.context.scene.camera = camera
    world = bpy.context.scene.world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.07, 0.10, 0.095, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.38
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 2200
    scene.render.resolution_y = 1400
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(PREVIEW_DIR / "jiangnan_style_v2_gallery.png")
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / "jiangnan_style_v2_gallery.blend"))
    bpy.ops.render.render(write_still=True)


def main() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    setup_materials()
    builders = [
        (build_house, "building_house_open.glb"),
        (build_farm, "building_farm_open.glb"),
        (build_lumber, "building_lumber_open.glb"),
        (build_warehouse, "building_warehouse_open.glb"),
        (build_workshop, "building_workshop_open.glb"),
        (build_market, "building_market_open.glb"),
        (build_tea_pavilion, "building_tea_pavilion_open.glb"),
    ]
    roots: list[bpy.types.Object] = []
    for builder, filename in builders:
        asset_root = builder()
        roots.append(asset_root)
        export_asset(asset_root, filename)
    manifest = {
        "generator": "tools/generate_jiangnan_style_assets.py",
        "tier": "jiangnan_style_v2",
        "art_version": 2,
        "style": "ink-wash Jiangnan water-town, open-front readable buildings",
        "tile_meters": 2.0,
        "coordinate_contract": "meters; ground-center origin; Godot +Z building entrance",
        "coverage": "%d/%d" % (len(RECORDS), len(builders)),
        "preview": "godot/assets/jiangnan_style_v2/previews/jiangnan_style_v2_gallery.png",
        "source": "godot/assets/jiangnan_style_v2/source/jiangnan_style_v2_gallery.blend",
        "legacy_assets_preserved": "godot/assets/realistic",
        "assets": RECORDS,
    }
    (MODEL_DIR / "jiangnan_style_v2_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    (SOURCE_DIR / ".gdignore").write_text("# Blender source is intentionally excluded from Godot import.\n", encoding="ascii")
    build_preview(roots)
    print("JIANGNAN_STYLE_V2_OK %d %s" % (len(RECORDS), MODEL_DIR))


if __name__ == "__main__":
    main()
