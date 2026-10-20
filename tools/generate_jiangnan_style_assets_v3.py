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
ROOT = PROJECT / "godot" / "assets" / "jiangnan_style_v3"
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
    material = bpy.data.materials.new("JNV3_%s" % name)
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
    obj["art_version"] = 3
    obj["roof_design"] = "complete_gable_roof_with_lifted_eaves"
    obj["view_design"] = "front_veranda_and_courtyard_visible"
    obj["detail_profile"] = "courtyard_beams_lattice_goods_tools"
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


def gable_roof(parent: bpy.types.Object, width: float, depth: float, ridge_z: float,
               center_y: float = 0.25, angle: float = 30.0, rows: int = 6,
               columns: int = 15, eave_lift: float = 0.10) -> None:
    """A complete, coherent Jiangnan gable roof.

    Both slopes are modelled with overlapping rows of tiles.  The front half is
    retained as a real roof and the veranda sits below its lifted eave, so the
    camera sees an intentional architectural section rather than a chopped roof.
    """
    radians = math.radians(angle)
    half_depth = depth * 0.5
    row_step = half_depth / rows
    tile_width = width / columns
    for side in (-1, 1):
        for row in range(rows):
            along = row_step * (row + 0.5)
            y = center_y + side * (along - half_depth * 0.02)
            z = ridge_z - along * math.tan(radians) + (eave_lift if row == rows - 1 else 0.0)
            rot_x = side * radians
            for col in range(columns):
                x = -width / 2 + tile_width * (col + 0.5)
                cube("RoofTile_%s_%02d_%02d" % ("F" if side < 0 else "B", row, col),
                     (tile_width * 1.12, row_step * 1.18, 0.105),
                     (x, y, z), "roof", parent, rotation=(rot_x, 0, 0), bevel=0.010)
    cylinder("RoofRidge", 0.080, width + 0.24, (0, center_y, ridge_z + 0.04), "roof_edge", parent,
             18, rotation=(0, math.radians(90), 0), bevel=0.005)
    eave_z = ridge_z - half_depth * math.tan(radians) + eave_lift
    for y in (center_y - half_depth, center_y + half_depth):
        cube("EaveBeam", (width + 0.22, 0.15, 0.13), (0, y, eave_z - 0.03), "roof_edge", parent,
             rotation=(0, 0, 0), bevel=0.014)
        # Upturned end ornaments give the silhouette the characteristic Jiangnan lift.
        for x in (-width * 0.51, width * 0.51):
            cube("EaveTip", (0.16, 0.18, 0.22), (x, y, eave_z + 0.07), "roof_edge", parent,
                 rotation=(0, 0, math.radians(-14 if x < 0 else 14)), bevel=0.018)


def veranda_roof(parent: bpy.types.Object, width: float, y: float, z: float,
                 depth: float = 0.62, material: str = "roof") -> None:
    """Shallow tiled canopy supported by a proper timber veranda."""
    cube("VerandaCanopy", (width, depth, 0.11), (0, y, z), material,
         parent, rotation=(math.radians(8), 0, 0), bevel=0.014)
    cube("VerandaGutter", (width + 0.12, 0.08, 0.08), (0, y - depth * 0.48, z - 0.05),
         "roof_edge", parent, bevel=0.008)
    for x in (-width * 0.43, width * 0.43):
        cylinder("VerandaPost", 0.055, z - 0.28, (x, y - depth * 0.25, (z - 0.28) / 2),
                 "wood", parent, 14, bevel=0.004)


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


def courtyard_wall(parent: bpy.types.Object, width: float, y: float, height: float = 0.85,
                   gate_width: float = 0.62, material: str = "plaster") -> None:
    """Low compound wall with a central moon gate and cap stones."""
    side = (width - gate_width) * 0.5
    for x in (-gate_width * 0.5 - side * 0.5, gate_width * 0.5 + side * 0.5):
        cube("CourtyardWall", (side, 0.13, height), (x, y, height * 0.5 + 0.30), material, parent,
             bevel=0.020)
    cube("WallCap", (width + 0.08, 0.18, 0.10), (0, y, height + 0.29), "stone_light", parent, bevel=0.012)
    cube("GatePillarL", (0.18, 0.20, height + 0.42), (-gate_width * 0.5, y, (height + 0.42) * 0.5 + 0.30),
         "brick", parent, bevel=0.018)
    cube("GatePillarR", (0.18, 0.20, height + 0.42), (gate_width * 0.5, y, (height + 0.42) * 0.5 + 0.30),
         "brick", parent, bevel=0.018)
    cube("GateLintel", (gate_width + 0.25, 0.22, 0.18), (0, y, height + 0.50), "wood_red", parent, bevel=0.018)
    cube("GateSign", (0.42, 0.05, 0.17), (0, y - 0.13, height + 0.67), "gold", parent, bevel=0.010)


def door_frame(parent: bpy.types.Object, x: float, y: float, z: float = 0.88,
               width: float = 0.54, height: float = 1.05, open_door: bool = False) -> None:
    """Traditional framed door; open doors expose the interior."""
    if not open_door:
        cube("DoorPanel", (width, 0.06, height), (x, y, z), "wood_red", parent, bevel=0.010)
        for dx in (-width * 0.27, width * 0.27):
            cube("DoorSlat", (0.035, 0.075, height * 0.94), (x + dx, y - 0.04, z), "wood", parent, bevel=0.003)
    for dx in (-width * 0.58, width * 0.58):
        cube("DoorJamb", (0.08, 0.09, height + 0.18), (x + dx, y, z), "wood", parent, bevel=0.006)
    cube("DoorHeader", (width + 0.20, 0.10, 0.10), (x, y, z + height * 0.55), "wood", parent, bevel=0.006)


def add_potted_plant(parent: bpy.types.Object, x: float, y: float, scale: float = 1.0) -> None:
    cylinder("PlantPot", 0.12 * scale, 0.20 * scale, (x, y, 0.39 * scale), "brick", parent, 14,
             top_radius=0.15 * scale, bevel=0.006)
    for dx, dz in ((0.10, 0.46), (-0.08, 0.58), (0.03, 0.70)):
        beam_between("PlantBranch", (x, y, 0.48 * scale), (x + dx * scale, y, dz * scale),
                     0.018 * scale, "bamboo", parent)
        sphere("PlantLeaf", 0.09 * scale, (x + dx * scale, y, dz * scale), "leaf", parent,
               (1.35, 0.70, 0.55))


def add_signboard(parent: bpy.types.Object, text_marks: int = 3, x: float = 0.0,
                  y: float = -0.92, z: float = 1.55, width: float = 0.72) -> None:
    cube("Signboard", (width, 0.07, 0.25), (x, y, z), "wood_red", parent, bevel=0.014)
    for i in range(text_marks):
        px = x - width * 0.27 + i * width * 0.27
        cube("BrushMark", (0.035, 0.018, 0.13), (px, y - 0.045, z), "gold", parent, bevel=0.002)


def build_house() -> bpy.types.Object:
    r = root("Jiangnan_House_V3", "house", (2.80, 2.75, 2.65))
    foundation(r, 2.55, 2.42)
    # Three-sided courtyard: the main hall has a full roof, while the open patio stays readable.
    cube("RearHallWall", (2.22, 0.14, 1.35), (0, 0.72, 1.03), "plaster", r, bevel=0.024)
    cube("WingWallL", (0.14, 1.25, 1.05), (-1.10, 0.12, 0.88), "plaster", r, bevel=0.018)
    cube("WingWallR", (0.14, 1.25, 1.05), (1.10, 0.12, 0.88), "plaster", r, bevel=0.018)
    post_set(r, 2.18, -0.65, 0.60, 1.08)
    for x in (-0.72, 0.0, 0.72):
        lattice_window(r, x, 0.63, 1.16, 0.44)
    door_frame(r, 0, 0.62, 0.88, 0.62, 1.08, True)
    courtyard_wall(r, 2.48, -1.03, 0.72, 0.68)
    veranda_roof(r, 2.18, -0.70, 1.62, 0.62)
    gable_roof(r, 2.42, 1.45, 2.48, 0.66, 30, 7, 17, 0.13)
    add_table(r, 0.0, -0.20, 0.58, 0.62, 0.42)
    add_potted_plant(r, -0.82, -0.42, 1.0)
    add_potted_plant(r, 0.82, -0.42, 0.90)
    add_lantern(r, -0.82, 0.51, 1.62)
    add_bamboo(r, 0.88, 0.42, 1.72)
    add_signboard(r, 2, y=-1.16, z=1.66, width=0.68)
    marker("Door", (0, -1.35, 0), r)
    return r


def build_farm() -> bpy.types.Object:
    r = root("Jiangnan_Farm_V3", "farm", (3.00, 2.75, 2.55))
    foundation(r, 2.78, 2.42)
    cube("IrrigationPool", (2.46, 2.05, 0.06), (0, 0.06, 0.34), "water", r, bevel=0.018)
    for x in (-0.78, 0, 0.78):
        cube("PaddyRidge", (0.56, 1.72, 0.17), (x, 0.02, 0.44), "soil", r, bevel=0.045)
        for y in (-0.63, -0.26, 0.11, 0.48):
            for i in range(3):
                xx = x - 0.13 + i * 0.13
                beam_between("RiceStem", (xx, y, 0.52), (xx + (-0.02 if i == 1 else 0.018), y, 0.88), 0.013, "crop", r)
                sphere("RiceHead", 0.030, (xx, y, 0.88), "cloth_cream", r, (0.58, 0.58, 1.35))
    # A proper rear farm house and covered tool veranda.
    cube("FarmHouseWall", (1.62, 0.12, 0.92), (0, 0.78, 0.82), "wood_light", r, bevel=0.018)
    post_set(r, 1.62, 0.20, 0.76, 0.92)
    gable_roof(r, 1.84, 0.90, 1.96, 0.56, 28, 4, 12, 0.09)
    veranda_roof(r, 1.50, 0.11, 1.45, 0.48)
    door_frame(r, 0, 0.77, 0.76, 0.44, 0.80, False)
    add_crate(r, -0.54, 0.04, 0.50, 0.28)
    add_crate(r, -0.18, 0.08, 0.50, 0.28)
    cylinder("WaterWheel", 0.31, 0.09, (0.62, 0.52, 0.74), "wood", r, 16, rotation=(math.radians(90), 0, 0), bevel=0.006)
    for angle in range(0, 360, 45):
        rad = math.radians(angle)
        beam_between("WaterWheelSpoke", (0.62, 0.47, 0.74), (0.62 + math.cos(rad) * 0.27, 0.47, 0.74 + math.sin(rad) * 0.27), 0.018, "wood_light", r)
    add_bamboo(r, -1.10, 0.70, 1.66)
    marker("Door", (0, -1.28, 0), r)
    return r


def build_lumber() -> bpy.types.Object:
    r = root("Jiangnan_Lumber_V3", "lumber", (3.00, 2.78, 2.65))
    foundation(r, 2.74, 2.42)
    post_set(r, 2.38, -0.68, 0.73, 1.12)
    cube("LumberBackWall", (2.26, 0.12, 1.30), (0, 0.75, 0.96), "wood_light", r, bevel=0.020)
    gable_roof(r, 2.54, 1.54, 2.48, 0.60, 30, 7, 17, 0.13)
    veranda_roof(r, 2.26, -0.68, 1.68, 0.60)
    for level in range(3):
        for index in range(3 - level % 2):
            y = 0.30 + (index - 1) * 0.23
            cylinder("LogStack", 0.10, 1.08, (-0.76, y, 0.47 + level * 0.20), "wood_light", r, 14,
                     rotation=(0, math.radians(90), 0), bevel=0.005)
    add_table(r, 0.46, -0.28, 0.70, 0.95, 0.45)
    cylinder("SawBlade", 0.25, 0.04, (0.46, -0.52, 0.86), "iron", r, 24, rotation=(math.radians(90), 0, 0), bevel=0.002)
    cylinder("SawHub", 0.055, 0.06, (0.46, -0.56, 0.86), "gold", r, 12, rotation=(math.radians(90), 0, 0), bevel=0.002)
    cube("AxeHandle", (0.06, 0.06, 0.80), (-0.95, -0.68, 0.72), "wood_light", r, rotation=(0, math.radians(-18), 0), bevel=0.005)
    cube("AxeHead", (0.30, 0.09, 0.19), (-1.07, -0.68, 1.06), "iron", r, rotation=(0, math.radians(-18), 0), bevel=0.014)
    add_lantern(r, 0.94, 0.66, 1.62)
    add_signboard(r, 2, y=-0.98, z=1.66)
    marker("Door", (0, -1.30, 0), r)
    return r


def build_warehouse() -> bpy.types.Object:
    r = root("Jiangnan_Warehouse_V3", "warehouse", (3.10, 2.90, 2.80))
    foundation(r, 2.84, 2.54)
    cube("WarehouseRearWall", (2.46, 0.14, 1.52), (0, 0.88, 1.08), "plaster_warm", r, bevel=0.026)
    post_set(r, 2.54, -0.78, 0.82, 1.18)
    gable_roof(r, 2.70, 1.72, 2.68, 0.66, 30, 8, 18, 0.15)
    veranda_roof(r, 2.42, -0.78, 1.78, 0.66)
    cube("LoadingRamp", (1.64, 0.72, 0.13), (0, -1.14, 0.35), "wood_light", r, rotation=(math.radians(-10), 0, 0), bevel=0.014)
    for x in (-0.82, 0.82):
        add_sack(r, x, 0.12, 0.55, 1.05)
        add_sack(r, x + 0.18, 0.40, 0.48, 0.86)
    add_crate(r, -0.64, -0.40, 0.50, 0.38)
    add_crate(r, -0.18, -0.40, 0.50, 0.38)
    add_signboard(r, 3, y=-0.94, z=1.92, width=0.86)
    door_frame(r, 0, 0.88, 0.98, 0.68, 1.30, True)
    add_lantern(r, 1.02, 0.76, 1.78)
    marker("Door", (0, -1.52, 0), r)
    return r


def build_workshop() -> bpy.types.Object:
    r = root("Jiangnan_Workshop_V3", "workshop", (3.10, 2.82, 3.10))
    foundation(r, 2.82, 2.46)
    cube("WorkshopRearWall", (2.46, 0.14, 1.58), (0, 0.82, 1.10), "brick", r, bevel=0.022)
    post_set(r, 2.46, -0.74, 0.76, 1.18)
    gable_roof(r, 2.68, 1.64, 2.70, 0.66, 30, 8, 18, 0.14)
    veranda_roof(r, 2.30, -0.72, 1.78, 0.62)
    cube("ForgeBody", (0.70, 0.52, 0.72), (0.58, 0.28, 0.68), "brick", r, bevel=0.028)
    cube("Firebox", (0.44, 0.09, 0.30), (0.58, -0.01, 0.69), "iron", r, bevel=0.022)
    sphere("ForgeEmber", 0.15, (0.58, -0.06, 0.70), "warm", r, (1.0, 0.35, 0.65))
    cylinder("Chimney", 0.17, 1.56, (0.58, 0.31, 2.03), "brick", r, 14, top_radius=0.13, bevel=0.008)
    cylinder("ChimneyCap", 0.22, 0.09, (0.58, 0.31, 2.83), "roof_edge", r, 16, bevel=0.004)
    add_table(r, -0.48, -0.28, 0.70, 0.95, 0.44)
    cube("AnvilBase", (0.30, 0.30, 0.45), (0.50, -0.52, 0.49), "wood", r, bevel=0.022)
    cube("AnvilTop", (0.56, 0.27, 0.17), (0.50, -0.52, 0.80), "iron", r, bevel=0.032)
    cube("ToolRack", (0.80, 0.07, 0.66), (-0.58, 0.70, 1.06), "wood", r, bevel=0.010)
    for x in (-0.83, -0.58, -0.33):
        cylinder("HangingTool", 0.022, 0.47, (x, 0.66, 1.07), "iron", r, 8, bevel=0.002)
    add_lantern(r, 1.01, 0.67, 1.70)
    add_signboard(r, 2, y=-1.02, z=1.72)
    marker("Door", (-0.48, -1.34, 0), r)
    return r


def build_market() -> bpy.types.Object:
    r = root("Jiangnan_Market_V3", "market", (3.20, 2.82, 2.55))
    foundation(r, 2.94, 2.48)
    # A timber market hall with a real central ridge and two visible shop bays.
    post_set(r, 2.62, -0.78, 0.72, 1.10)
    cube("MarketBackWall", (2.50, 0.12, 1.28), (0, 0.75, 0.96), "plaster_warm", r, bevel=0.020)
    gable_roof(r, 2.78, 1.60, 2.52, 0.62, 30, 8, 18, 0.13)
    veranda_roof(r, 2.44, -0.72, 1.72, 0.62)
    for x, cloth in ((-0.70, "cloth_red"), (0.70, "cloth_blue")):
        add_table(r, x, -0.18, 0.64, 1.03, 0.46)
        for i in range(3):
            sphere("MarketBasket", 0.12, (x - 0.30 + i * 0.30, -0.20, 0.80), "wood_light", r, (1.0, 0.72, 0.68))
        cube("ClothValance", (1.04, 0.07, 0.20), (x, -0.83, 1.48), cloth, r, bevel=0.010)
    for x in (-0.98, -0.68, 0.68, 0.98):
        add_sack(r, x, 0.43, 0.53, 0.76)
    add_signboard(r, 3, y=-1.01, z=1.76, width=0.92)
    add_lantern(r, 0, 0.67, 1.70)
    marker("Door", (0, -1.34, 0), r)
    return r


def build_tea_pavilion() -> bpy.types.Object:
    r = root("Jiangnan_Tea_Pavilion_V3", "tea_pavilion", (2.90, 2.72, 2.70))
    foundation(r, 2.60, 2.38)
    for x in (-0.98, 0.98):
        for y in (-0.82, 0.78):
            cylinder("PavilionPost", 0.070, 1.88, (x, y, 1.17), "wood_red", r, 14, bevel=0.006)
    gable_roof(r, 2.50, 1.86, 2.48, 0.02, 30, 8, 16, 0.14)
    # Open front bay with an ornamental side screen and a visible tea table.
    cube("PavilionBackScreen", (2.20, 0.09, 0.94), (0, 0.84, 0.82), "paper", r, bevel=0.012)
    for x in (-0.55, 0.55):
        lattice_window(r, x, 0.78, 1.00, 0.42)
    add_table(r, 0, -0.02, 0.70, 1.04, 0.58)
    for x in (-0.56, 0.56):
        cylinder("TeaStool", 0.16, 0.30, (x, -0.02, 0.43), "wood_light", r, 14, top_radius=0.13, bevel=0.007)
    for x in (-0.24, 0.0, 0.24):
        cylinder("TeaCup", 0.077, 0.07, (x, -0.02, 0.80), "paper", r, 14, top_radius=0.06, bevel=0.003)
    add_potted_plant(r, -1.10, 0.30, 1.08)
    add_bamboo(r, 1.10, 0.38, 1.74)
    add_lantern(r, 0.00, 0.74, 1.76)
    add_signboard(r, 2, y=-1.08, z=1.82)
    marker("Door", (0, -1.28, 0), r)
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
        "Jiangnan_House_V3": (-4.7, 2.15, 0),
        "Jiangnan_Farm_V3": (-1.55, 2.15, 0),
        "Jiangnan_Lumber_V3": (1.65, 2.15, 0),
        "Jiangnan_Warehouse_V3": (4.85, 2.15, 0),
        "Jiangnan_Workshop_V3": (-3.15, -1.65, 0),
        "Jiangnan_Market_V3": (0.0, -1.65, 0),
        "Jiangnan_Tea_Pavilion_V3": (3.25, -1.65, 0),
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
    scene.render.filepath = str(PREVIEW_DIR / "jiangnan_style_v3_gallery.png")
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / "jiangnan_style_v3_gallery.blend"))
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
        "generator": "tools/generate_jiangnan_style_assets_v3.py",
        "tier": "jiangnan_style_v3",
        "art_version": 3,
        "style": "ink-wash Jiangnan courtyard architecture with coherent gable roofs and visible verandas",
        "tile_meters": 2.0,
        "coordinate_contract": "meters; ground-center origin; Godot +Z building entrance",
        "coverage": "%d/%d" % (len(RECORDS), len(builders)),
        "preview": "godot/assets/jiangnan_style_v3/previews/jiangnan_style_v3_gallery.png",
        "source": "godot/assets/jiangnan_style_v3/source/jiangnan_style_v3_gallery.blend",
        "legacy_assets_preserved": "godot/assets/realistic",
        "assets": RECORDS,
    }
    (MODEL_DIR / "jiangnan_style_v3_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    (SOURCE_DIR / ".gdignore").write_text("# Blender source is intentionally excluded from Godot import.\n", encoding="ascii")
    build_preview(roots)
    print("JIANGNAN_STYLE_V3_OK %d %s" % (len(RECORDS), MODEL_DIR))


if __name__ == "__main__":
    main()
