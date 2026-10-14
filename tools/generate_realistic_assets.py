"""Generate the complete East Valley realistic asset kit with Blender 4.x.

Output stays under M:/NewGames/TheEast/godot/assets/realistic.
Entrances face Blender -Y and therefore Godot +Z after glTF Y-up conversion.
Every asset uses meters and has its root at ground center.
"""

import json
import math
import os
import random
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_DIR = Path(os.environ.get("THE_EAST_PROJECT", r"M:\NewGames\TheEast"))
ROOT_DIR = PROJECT_DIR / "godot" / "assets" / "realistic"
MODEL_DIR = ROOT_DIR / "models"
MATERIAL_DIR = ROOT_DIR / "materials"
SOURCE_DIR = ROOT_DIR / "source"
PREVIEW_DIR = ROOT_DIR / "previews"
for directory in (MODEL_DIR, MATERIAL_DIR, SOURCE_DIR, PREVIEW_DIR):
    directory.mkdir(parents=True, exist_ok=True)

RNG = random.Random(240927)
MATERIALS = {}
ASSET_RECORDS = []

SURFACES = {
    "plaster": {"color": (0.64, 0.55, 0.43), "rough": 0.84, "pattern": "plaster", "scale": 1.0},
    "wood_dark": {"color": (0.22, 0.105, 0.055), "rough": 0.66, "pattern": "wood", "scale": 3.0},
    "wood_warm": {"color": (0.43, 0.20, 0.075), "rough": 0.70, "pattern": "wood", "scale": 2.5},
    "roof_tile": {"color": (0.15, 0.22, 0.235), "rough": 0.60, "pattern": "tile", "scale": 4.0},
    "stone": {"color": (0.31, 0.32, 0.29), "rough": 0.88, "pattern": "stone", "scale": 2.0},
    "rock": {"color": (0.23, 0.255, 0.24), "rough": 0.91, "pattern": "rock", "scale": 1.7},
    "paint_red": {"color": (0.47, 0.055, 0.03), "rough": 0.52, "pattern": "paint", "scale": 2.0},
    "lantern_paper": {"color": (0.72, 0.10, 0.045), "rough": 0.48, "pattern": "paper", "scale": 1.0, "emission": 0.35},
    "brass": {"color": (0.47, 0.25, 0.055), "rough": 0.40, "pattern": "metal", "scale": 2.0, "metallic": 0.68},
    "bark": {"color": (0.20, 0.095, 0.035), "rough": 0.93, "pattern": "bark", "scale": 2.8},
    "leaf": {"color": (0.12, 0.31, 0.105), "rough": 0.78, "pattern": "leaf", "scale": 2.0},
    "leaf_light": {"color": (0.23, 0.43, 0.16), "rough": 0.76, "pattern": "leaf", "scale": 2.0},
    "cloth": {"color": (0.35, 0.08, 0.045), "rough": 0.92, "pattern": "cloth", "scale": 3.0},
    "cloth_blue": {"color": (0.12, 0.28, 0.32), "rough": 0.92, "pattern": "cloth", "scale": 3.0},
    "skin": {"color": (0.63, 0.38, 0.20), "rough": 0.72, "pattern": "skin", "scale": 1.0},
    "hair": {"color": (0.035, 0.022, 0.016), "rough": 0.72, "pattern": "hair", "scale": 3.0},
    "rope": {"color": (0.34, 0.23, 0.10), "rough": 0.96, "pattern": "rope", "scale": 5.0},
    "soil": {"color": (0.24, 0.115, 0.045), "rough": 0.94, "pattern": "stone", "scale": 2.8},
    "wet_soil": {"color": (0.105, 0.065, 0.035), "rough": 0.62, "pattern": "stone", "scale": 2.5},
    "crop": {"color": (0.24, 0.43, 0.105), "rough": 0.82, "pattern": "leaf", "scale": 2.2},
    "grain": {"color": (0.66, 0.43, 0.085), "rough": 0.86, "pattern": "rope", "scale": 4.0},
    "brick": {"color": (0.42, 0.14, 0.065), "rough": 0.88, "pattern": "tile", "scale": 2.0},
    "iron": {"color": (0.095, 0.10, 0.095), "rough": 0.43, "pattern": "metal", "scale": 2.0, "metallic": 0.88},
    "water": {"color": (0.12, 0.29, 0.31), "rough": 0.24, "pattern": "paper", "scale": 1.5},
}


def clamp(value):
    return max(0.0, min(1.0, value))


def noise2(x, y, seed):
    return math.sin(x * 12.9898 + y * 78.233 + seed * 37.719) * 43758.5453 % 1.0


def texture_height(pattern, u, v, seed):
    n = noise2(int(u * 128), int(v * 128), seed)
    fine = noise2(int(u * 512), int(v * 512), seed + 11)
    if pattern in ("wood", "bark"):
        grain = 0.5 + 0.5 * math.sin((u * 17.0 + math.sin(v * 8.0) * 0.7) * math.pi)
        cracks = 1.0 if noise2(int(u * 42), int(v * 9), seed + 4) > 0.94 else 0.0
        return clamp(0.26 * grain + 0.44 * n + 0.16 * fine - cracks * 0.32)
    if pattern == "tile":
        seam = 0.0 if (u % 0.25) < 0.018 or (v % 0.25) < 0.018 else 0.58
        return clamp(seam + n * 0.16)
    if pattern in ("stone", "rock"):
        veins = 0.5 + 0.5 * math.sin((u * 8 + v * 5 + n * 2.0) * math.pi)
        return clamp(n * 0.48 + fine * 0.15 + veins * 0.18)
    if pattern == "plaster":
        return clamp(0.46 + (n - 0.5) * 0.18 + (fine - 0.5) * 0.08)
    if pattern == "cloth":
        weave = (0.5 + 0.5 * math.sin(u * 180 * math.pi)) * (0.5 + 0.5 * math.sin(v * 180 * math.pi))
        return clamp(0.38 + weave * 0.28 + n * 0.08)
    if pattern == "rope":
        return clamp(0.42 + 0.25 * math.sin((u * 24 + v * 4) * math.pi) + n * 0.12)
    if pattern == "leaf":
        veins = abs(math.sin((u - 0.5) * 18 * math.pi)) * (1.0 - abs(v - 0.5))
        return clamp(0.38 + veins * 0.22 + n * 0.20)
    if pattern == "metal":
        return clamp(0.52 + n * 0.12 + fine * 0.04)
    if pattern == "hair":
        return clamp(0.32 + 0.22 * math.sin(u * 100 * math.pi) + n * 0.08)
    if pattern == "paper":
        fiber = 0.5 + 0.5 * math.sin((u * 75 + n * 3) * math.pi)
        return clamp(0.44 + fiber * 0.10 + fine * 0.10)
    return clamp(0.48 + n * 0.12)


def create_texture_set(name, spec, size=256):
    seed = sum(ord(char) for char in name)
    heights = []
    for y in range(size):
        v = y / (size - 1)
        for x in range(size):
            u = x / (size - 1)
            heights.append(texture_height(spec["pattern"], u, v, seed))

    base_pixels = []
    rough_pixels = []
    normal_pixels = []
    base = spec["color"]
    for y in range(size):
        for x in range(size):
            index = y * size + x
            h = heights[index]
            variation = 0.74 + h * 0.46
            base_pixels.extend((clamp(base[0] * variation), clamp(base[1] * variation), clamp(base[2] * variation), 1.0))
            rough_value = clamp(spec["rough"] + (h - 0.5) * 0.15)
            rough_pixels.extend((rough_value, rough_value, rough_value, 1.0))
            left = heights[y * size + max(0, x - 1)]
            right = heights[y * size + min(size - 1, x + 1)]
            down = heights[max(0, y - 1) * size + x]
            up = heights[min(size - 1, y + 1) * size + x]
            strength = 3.2
            nx = (left - right) * strength
            ny = (down - up) * strength
            nz = 1.0
            length = math.sqrt(nx * nx + ny * ny + nz * nz)
            normal_pixels.extend((nx / length * 0.5 + 0.5, ny / length * 0.5 + 0.5, nz / length * 0.5 + 0.5, 1.0))

    paths = {}
    for suffix, pixels, colorspace in (
        ("basecolor", base_pixels, "sRGB"),
        ("roughness", rough_pixels, "Non-Color"),
        ("normal", normal_pixels, "Non-Color"),
    ):
        image = bpy.data.images.new("T_%s_%s" % (name, suffix), width=size, height=size, alpha=True)
        image.pixels.foreach_set(pixels)
        image.file_format = "PNG"
        path = MATERIAL_DIR / ("%s_%s.png" % (name, suffix))
        image.filepath_raw = str(path)
        image.save()
        image.colorspace_settings.name = colorspace
        paths[suffix] = path
    return paths


def build_material(name, spec):
    paths = create_texture_set(name, spec)
    mat = bpy.data.materials.new("MR_%s" % name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    for node in list(nodes):
        nodes.remove(node)
    output = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    base_tex = nodes.new("ShaderNodeTexImage")
    rough_tex = nodes.new("ShaderNodeTexImage")
    normal_tex = nodes.new("ShaderNodeTexImage")
    normal_map = nodes.new("ShaderNodeNormalMap")
    texcoord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    base_tex.image = bpy.data.images.load(str(paths["basecolor"]), check_existing=True)
    rough_tex.image = bpy.data.images.load(str(paths["roughness"]), check_existing=True)
    normal_tex.image = bpy.data.images.load(str(paths["normal"]), check_existing=True)
    rough_tex.image.colorspace_settings.name = "Non-Color"
    normal_tex.image.colorspace_settings.name = "Non-Color"
    mapping.inputs["Scale"].default_value = (spec["scale"], spec["scale"], spec["scale"])
    normal_map.inputs["Strength"].default_value = 0.62
    bsdf.inputs["Metallic"].default_value = spec.get("metallic", 0.0)
    bsdf.inputs["Roughness"].default_value = spec["rough"]
    if spec.get("emission", 0.0) > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*spec["color"], 1.0)
        bsdf.inputs["Emission Strength"].default_value = spec["emission"]
    links.new(texcoord.outputs["UV"], mapping.inputs["Vector"])
    for texture in (base_tex, rough_tex, normal_tex):
        links.new(mapping.outputs["Vector"], texture.inputs["Vector"])
    links.new(base_tex.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(rough_tex.outputs["Color"], bsdf.inputs["Roughness"])
    links.new(normal_tex.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    MATERIALS[name] = mat


def setup_materials():
    for name, spec in SURFACES.items():
        build_material(name, spec)


def root(name, asset_type, fallback_key):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj["asset_type"] = asset_type
    obj["art_tier"] = "realistic_r0"
    obj["art_version"] = 1
    obj["tile_meters"] = 2.0
    obj["fallback_key"] = fallback_key
    return obj


def attach(obj, parent):
    if parent is not None:
        obj.parent = parent
    return obj


def smart_uv(obj):
    if obj.type != "MESH":
        return
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


def finish_mesh(obj, mat_name, bevel=0.0, shade_smooth=False):
    obj.data.materials.append(MATERIALS[mat_name])
    if bevel > 0.0:
        modifier = obj.modifiers.new("EdgeBevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    if shade_smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    smart_uv(obj)
    return obj


def cube(name, size, location, mat_name, parent=None, rotation=(0, 0, 0), bevel=0.012):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish_mesh(obj, mat_name, bevel)
    return attach(obj, parent)


def cylinder(name, radius, depth, location, mat_name, parent=None, vertices=16, rotation=(0, 0, 0), top_radius=None, bevel=0.008):
    if top_radius is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=top_radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    finish_mesh(obj, mat_name, bevel, True)
    return attach(obj, parent)


def uv_sphere(name, radius, location, mat_name, parent=None, segments=24, rings=12, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish_mesh(obj, mat_name, 0.0, True)
    return attach(obj, parent)


def ico(name, radius, location, mat_name, parent=None, subdivisions=2, scale=(1, 1, 1), irregular=0.0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if irregular > 0:
        for vertex in obj.data.vertices:
            direction = vertex.co.normalized()
            variation = 1.0 + irregular * math.sin(direction.x * 8.3 + direction.y * 13.7 + direction.z * 5.9)
            vertex.co *= variation
    finish_mesh(obj, mat_name, 0.01, True)
    return attach(obj, parent)


def curve_tube(name, points, radius, mat_name, parent=None, resolution=2):
    curve_data = bpy.data.curves.new(name + "Curve", "CURVE")
    curve_data.dimensions = "3D"
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = resolution
    spline = curve_data.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, coordinate in zip(spline.bezier_points, points):
        point.co = coordinate
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve_data)
    bpy.context.scene.collection.objects.link(obj)
    attach(obj, parent)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    finish_mesh(obj, mat_name, 0.0, True)
    obj.select_set(False)
    return obj


def marker(name, location, parent):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    attach(obj, parent)
    return obj


def make_roof_tile(name, location, rotation, parent, length=0.46, width=0.13):
    # Build each tile as a closed curved shell. The previous open prism left the
    # underside non-manifold; Blender's bevel modifier could then stretch edge
    # vertices into long spikes when the mesh was exported to glTF.
    segments = 8
    vertices = []
    faces = []
    start_angle = math.pi * 0.12
    arc_span = math.pi * 0.76
    outer_x_radius = width * 0.55
    outer_z_radius = width * 0.22
    shell_thickness = min(0.012, outer_z_radius * 0.35)
    inner_x_radius = outer_x_radius - shell_thickness
    inner_z_radius = outer_z_radius - shell_thickness

    for side_y in (-length / 2, length / 2):
        for i in range(segments + 1):
            angle = start_angle + arc_span * i / segments
            x = math.cos(angle) * outer_x_radius
            z = math.sin(angle) * outer_z_radius
            vertices.append((x, side_y, z))
        for i in range(segments + 1):
            angle = start_angle + arc_span * i / segments
            x = math.cos(angle) * inner_x_radius
            z = math.sin(angle) * inner_z_radius
            vertices.append((x, side_y, z))

    ring = segments + 1
    section = ring * 2
    front_outer = 0
    front_inner = ring
    back_outer = section
    back_inner = section + ring

    for i in range(segments):
        faces.append((front_outer + i, back_outer + i, back_outer + i + 1, front_outer + i + 1))
        faces.append((front_inner + i + 1, back_inner + i + 1, back_inner + i, front_inner + i))
        faces.append((front_outer + i + 1, front_outer + i, front_inner + i, front_inner + i + 1))
        faces.append((back_outer + i, back_outer + i + 1, back_inner + i + 1, back_inner + i))

    faces.append((front_outer, back_outer, back_inner, front_inner))
    faces.append((front_outer + segments, front_inner + segments, back_inner + segments, back_outer + segments))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = rotation
    finish_mesh(obj, "roof_tile", 0.0, True)
    return attach(obj, parent)


def build_house():
    r = root("Realistic_House", "building", "house")
    r["building_type"] = "house"
    r["entrance_axis_godot"] = "+Z"
    r["bounds_m"] = "2.20,2.55,2.05"

    cube("StoneFoundation", (1.94, 1.72, 0.22), (0, 0, 0.11), "stone", r, bevel=0.035)
    cube("RaisedFloor", (1.74, 1.52, 0.16), (0, 0, 0.27), "wood_warm", r, bevel=0.018)
    cube("PlasterWall", (1.58, 1.36, 1.08), (0, 0.03, 0.83), "plaster", r, bevel=0.025)
    for x in (-0.79, 0.79):
        for y in (-0.67, 0.67):
            cylinder("TimberPost", 0.065, 1.44, (x, y, 0.86), "wood_dark", r, 12, bevel=0.006)
    for y in (-0.69, 0.69):
        cube("TopBeam", (1.80, 0.12, 0.13), (0, y, 1.53), "wood_dark", r, bevel=0.012)
        cube("SillBeam", (1.78, 0.10, 0.11), (0, y, 0.38), "wood_dark", r, bevel=0.010)
    for x in (-0.88, 0.88):
        cube("SideBeam", (0.11, 1.46, 0.12), (x, 0, 1.52), "wood_dark", r, bevel=0.01)

    cube("FrontDoor", (0.54, 0.075, 0.94), (0, -0.715, 0.82), "wood_dark", r, bevel=0.014)
    for offset in (-0.18, 0.0, 0.18):
        cube("DoorPlank", (0.025, 0.083, 0.88), (offset, -0.722, 0.82), "wood_warm", r, bevel=0.004)
    cylinder("DoorRing", 0.055, 0.018, (0.16, -0.77, 0.85), "brass", r, 18, rotation=(math.radians(90), 0, 0), bevel=0.003)

    for side in (-1, 1):
        x = side * 0.54
        cube("WindowFrame", (0.46, 0.07, 0.46), (x, -0.718, 0.91), "wood_dark", r, bevel=0.01)
        cube("WindowPaper", (0.38, 0.012, 0.38), (x, -0.759, 0.91), "plaster", r, bevel=0.002)
        for line in (-0.12, 0.0, 0.12):
            cube("LatticeV", (0.018, 0.026, 0.39), (x + line, -0.77, 0.91), "wood_warm", r, bevel=0.002)
            cube("LatticeH", (0.39, 0.026, 0.018), (x, -0.77, 0.91 + line), "wood_warm", r, bevel=0.002)

    # Brackets and eaves create a readable traditional timber silhouette.
    for x in (-0.78, -0.39, 0.0, 0.39, 0.78):
        for y in (-0.76, 0.76):
            cube("EaveBracket", (0.18, 0.30, 0.08), (x, y, 1.43), "paint_red", r, bevel=0.012)
            cube("BracketBlock", (0.12, 0.15, 0.15), (x, y * 0.96, 1.50), "wood_dark", r, bevel=0.01)

    roof_angle = math.radians(30)
    columns = 15
    rows = 4
    for side in (-1, 1):
        for column in range(columns):
            x = -1.01 + column * (2.02 / (columns - 1))
            for row in range(rows):
                distance = 0.16 + row * 0.22
                y = side * distance
                z = 1.86 - distance * math.tan(roof_angle)
                # Local Y runs along the tile. Its pitch must descend away from
                # the ridge on both roof sides; using the same sign as `side`
                # inverted that slope and exposed each row edge through the wall.
                make_roof_tile("RoofTile", (x, y, z), (-side * roof_angle, 0, 0), r, 0.50, 0.145)

    cylinder("RoofRidge", 0.085, 2.28, (0, 0, 1.94), "roof_tile", r, 20, rotation=(0, math.radians(90), 0), bevel=0.004)
    for x in (-1.08, 1.08):
        cylinder("RidgeEnd", 0.12, 0.13, (x, 0, 1.94), "roof_tile", r, 18, rotation=(0, math.radians(90), 0), top_radius=0.07)

    marker("Door", (0, -1.05, 0), r)
    return r


def add_tiled_gable_roof(parent, width, half_run, ridge_z, angle_degrees=30, columns=15, rows=4):
    """Add a closed, overlapping tile roof with a supported ridge."""
    angle = math.radians(angle_degrees)
    first_distance = 0.15
    last_distance = half_run
    spacing = (last_distance - first_distance) / max(1, rows - 1)
    tile_length = max(0.38, spacing * 2.25)
    tile_width = width / max(1, columns - 1)
    for side in (-1, 1):
        for column in range(columns):
            x = -width * 0.5 + column * (width / max(1, columns - 1))
            for row in range(rows):
                distance = first_distance + row * spacing
                z = ridge_z - distance * math.tan(angle)
                make_roof_tile(
                    "RoofTile", (x, side * distance, z), (-side * angle, 0, 0),
                    parent, tile_length, tile_width,
                )
    cylinder("RoofRidge", 0.085, width + 0.22, (0, 0, ridge_z + 0.03), "roof_tile", parent,
             20, rotation=(0, math.radians(90), 0), bevel=0.004)
    for x in (-width * 0.5 - 0.07, width * 0.5 + 0.07):
        cylinder("RidgeEnd", 0.115, 0.13, (x, 0, ridge_z + 0.03), "roof_tile", parent, 18,
                 rotation=(0, math.radians(90), 0), top_radius=0.065, bevel=0.003)


def add_log_stack(parent, center, levels=3, logs_per_level=3, length=1.10):
    cx, cy, cz = center
    for level in range(levels):
        count = logs_per_level - (level % 2)
        for index in range(count):
            y = cy + (index - (count - 1) * 0.5) * 0.22
            z = cz + level * 0.19
            cylinder("StackedLog", 0.095, length, (cx, y, z), "bark", parent, 14,
                     rotation=(0, math.radians(90), 0), bevel=0.004)
            for side in (-1, 1):
                cylinder("LogEnd", 0.083, 0.014, (cx + side * (length * 0.5 + 0.006), y, z),
                         "wood_warm", parent, 14, rotation=(0, math.radians(90), 0), bevel=0.001)


def build_lumber():
    r = root("Realistic_Lumber", "building", "lumber")
    r["building_type"] = "lumber"
    r["entrance_axis_godot"] = "+Z"
    r["bounds_m"] = "2.45,2.30,2.25"

    cube("StonePad", (2.18, 1.92, 0.18), (0, 0, 0.09), "stone", r, bevel=0.035)
    cube("TimberDeck", (2.04, 1.76, 0.14), (0, 0, 0.24), "wood_warm", r, bevel=0.018)
    for x in (-0.86, 0.86):
        for y in (-0.68, 0.68):
            cylinder("MortisedPost", 0.075, 1.65, (x, y, 1.05), "wood_dark", r, 14, bevel=0.006)
            cube("StonePostFoot", (0.22, 0.22, 0.17), (x, y, 0.26), "stone", r, bevel=0.025)
    for y in (-0.70, 0.70):
        cube("TieBeam", (1.98, 0.12, 0.14), (0, y, 1.78), "wood_dark", r, bevel=0.012)
    add_tiled_gable_roof(r, 2.18, 0.90, 2.20, 25, 15, 4)

    add_log_stack(r, (-0.45, 0.46, 0.42), 3, 3, 1.08)
    cube("SawBenchTop", (0.92, 0.44, 0.10), (0.48, -0.35, 0.69), "wood_warm", r, bevel=0.012)
    for x in (0.16, 0.80):
        for y in (-0.49, -0.21):
            cube("SawBenchLeg", (0.08, 0.08, 0.56), (x, y, 0.43), "wood_dark", r, bevel=0.006)
    cylinder("SawBlade", 0.245, 0.030, (0.48, -0.35, 0.83), "iron", r, 28,
             rotation=(math.radians(90), 0, 0), bevel=0.002)
    cylinder("SawHub", 0.052, 0.05, (0.48, -0.37, 0.83), "brass", r, 16,
             rotation=(math.radians(90), 0, 0), bevel=0.002)
    cube("AxeHandle", (0.045, 0.045, 0.78), (-0.74, -0.70, 0.70), "wood_warm", r,
         rotation=(0, math.radians(-18), math.radians(7)), bevel=0.006)
    cube("AxeHead", (0.30, 0.07, 0.20), (-0.86, -0.70, 1.04), "iron", r,
         rotation=(0, math.radians(-18), 0), bevel=0.018)
    marker("Door", (0, -1.10, 0), r)
    return r


def add_field_plant(parent, x, y, base_z, index, mature=True):
    height = 0.44 + 0.045 * (index % 3)
    tip = Vector((x + (0.018 if index % 2 else -0.018), y, base_z + height))
    stalk = branch(parent, "FieldStem_%02d" % index, (x, y, base_z), tip, 0.015)
    stalk.data.materials.clear()
    stalk.data.materials.append(MATERIALS["crop"])
    for leaf_index, (dx, dy, dz) in enumerate(((-0.11, 0.02, 0.23), (0.10, -0.03, 0.29), (0.02, 0.11, 0.34))):
        leaf = branch(parent, "FieldLeaf_%02d_%02d" % (index, leaf_index),
                      (x, y, base_z + 0.06), (x + dx, y + dy, base_z + dz), 0.010)
        leaf.data.materials.clear()
        leaf.data.materials.append(MATERIALS["crop"])
    if mature:
        for grain_index in range(4):
            ico("FieldGrain_%02d_%02d" % (index, grain_index), 0.030,
                (tip.x + (0.022 if grain_index % 2 else -0.022), tip.y, tip.z - grain_index * 0.05),
                "grain", parent, 1, (0.72, 0.58, 1.35), 0.02)


def build_farm():
    r = root("Realistic_Farm", "building", "farm")
    r["building_type"] = "farm"
    r["entrance_axis_godot"] = "+Z"
    r["bounds_m"] = "2.35,1.70,2.20"

    cube("FarmPlot", (2.20, 1.92, 0.10), (0, 0, 0.05), "wet_soil", r, bevel=0.025)
    ridge_x = (-0.73, 0.0, 0.73)
    for ridge_index, x in enumerate(ridge_x):
        cube("SoilRidge_%02d" % ridge_index, (0.52, 1.70, 0.20), (x, 0, 0.17), "soil", r, bevel=0.075)
        for row_index, y in enumerate((-0.60, -0.20, 0.20, 0.60)):
            add_field_plant(r, x, y, 0.29, ridge_index * 4 + row_index, True)
    for x in (-0.37, 0.37):
        cube("IrrigationChannel", (0.16, 1.78, 0.035), (x, 0, 0.115), "water", r, bevel=0.012)
        for edge in (-0.11, 0.11):
            cube("ChannelStone", (0.06, 1.84, 0.12), (x + edge, 0, 0.14), "stone", r, bevel=0.025)

    # Scarecrow, straw hat, and tied sleeves are readable from the planning camera.
    cylinder("ScarecrowPost", 0.040, 1.38, (0.73, 0.30, 0.91), "wood_dark", r, 10, bevel=0.004)
    cylinder("ScarecrowArms", 0.035, 0.82, (0.73, 0.30, 1.12), "wood_dark", r, 10,
             rotation=(0, math.radians(90), 0), bevel=0.004)
    cube("ScarecrowCoat", (0.48, 0.18, 0.45), (0.73, 0.30, 0.91), "cloth", r, bevel=0.035)
    uv_sphere("ScarecrowHead", 0.13, (0.73, 0.30, 1.35), "rope", r, 16, 8, (0.90, 0.90, 1.0))
    cylinder("ScarecrowHatBrim", 0.22, 0.035, (0.73, 0.30, 1.47), "grain", r, 18, bevel=0.003)
    cylinder("ScarecrowHat", 0.13, 0.13, (0.73, 0.30, 1.54), "grain", r, 16, top_radius=0.04, bevel=0.003)
    marker("Door", (0, -1.08, 0), r)
    return r


def build_warehouse():
    r = root("Realistic_Warehouse", "building", "warehouse")
    r["building_type"] = "warehouse"
    r["entrance_axis_godot"] = "+Z"
    r["bounds_m"] = "2.45,2.65,2.30"

    cube("HighStonePlinth", (2.15, 1.92, 0.34), (0, 0, 0.17), "stone", r, bevel=0.045)
    cube("WarehouseFloor", (1.94, 1.70, 0.16), (0, 0, 0.41), "wood_warm", r, bevel=0.018)
    cube("ThickPlasterWalls", (1.82, 1.58, 1.35), (0, 0.04, 1.12), "plaster", r, bevel=0.028)
    for x in (-0.91, 0.91):
        for y in (-0.73, 0.73):
            cylinder("LoadPost", 0.075, 1.62, (x, y, 1.19), "wood_dark", r, 14, bevel=0.006)
    for y in (-0.76, 0.76):
        cube("WarehouseTieBeam", (2.03, 0.13, 0.15), (0, y, 1.78), "wood_dark", r, bevel=0.012)

    # Double loading doors, iron straps, and raised ramp make the storage use explicit.
    for side in (-1, 1):
        door_x = side * 0.37
        cube("DoubleDoor", (0.70, 0.085, 1.18), (door_x, -0.795, 1.03), "wood_dark", r, bevel=0.016)
        for z in (0.64, 1.03, 1.42):
            cube("DoorIronStrap", (0.62, 0.025, 0.045), (door_x, -0.845, z), "iron", r, bevel=0.006)
        cylinder("DoorRing", 0.055, 0.025, (side * 0.10, -0.86, 1.04), "brass", r, 16,
                 rotation=(math.radians(90), 0, 0), bevel=0.002)
    cube("LoadingRamp", (1.36, 0.74, 0.12), (0, -1.12, 0.28), "wood_warm", r,
         rotation=(math.radians(-11), 0, 0), bevel=0.012)
    for x in (-0.64, 0.64):
        cube("RampRail", (0.08, 0.78, 0.18), (x, -1.10, 0.39), "wood_dark", r,
             rotation=(math.radians(-11), 0, 0), bevel=0.008)

    for side in (-1, 1):
        cube("VentFrame", (0.38, 0.06, 0.32), (side * 0.54, 0.835, 1.33), "wood_dark", r, bevel=0.010)
        for slit in (-0.09, 0.0, 0.09):
            cube("VentSlat", (0.028, 0.07, 0.26), (side * 0.54 + slit, 0.87, 1.33), "wood_warm", r, bevel=0.003)
    add_tiled_gable_roof(r, 2.25, 0.94, 2.42, 31, 16, 5)

    for index, (x, y, z, scale) in enumerate(((-0.73, -0.95, 0.55, 0.28), (0.72, -0.96, 0.52, 0.25))):
        uv_sphere("GrainSack_%02d" % index, scale, (x, y, z), "rope", r, 18, 10, (0.74, 0.48, 1.12))
    cube("WarehouseSign", (0.58, 0.08, 0.25), (0, -0.84, 1.73), "wood_warm", r, bevel=0.018)
    marker("Door", (0, -1.53, 0), r)
    return r


def build_workshop():
    r = root("Realistic_Workshop", "building", "workshop")
    r["building_type"] = "workshop"
    r["entrance_axis_godot"] = "+Z"
    r["bounds_m"] = "2.55,3.05,2.35"

    cube("WorkshopFoundation", (2.12, 1.92, 0.24), (0, 0, 0.12), "stone", r, bevel=0.040)
    cube("FireproofFloor", (1.94, 1.74, 0.14), (0, 0, 0.29), "brick", r, bevel=0.018)
    cube("WorkshopWalls", (1.80, 1.58, 1.32), (0, 0.03, 1.05), "brick", r, bevel=0.026)
    for x in (-0.91, 0.91):
        for y in (-0.73, 0.73):
            cylinder("WorkshopPost", 0.070, 1.60, (x, y, 1.10), "wood_dark", r, 14, bevel=0.006)

    cube("WorkshopDoor", (0.62, 0.08, 1.05), (-0.45, -0.80, 0.91), "wood_dark", r, bevel=0.014)
    cube("WorkshopWindow", (0.52, 0.055, 0.43), (0.48, -0.815, 1.15), "iron", r, bevel=0.015)
    for line in (-0.15, 0.0, 0.15):
        cube("WindowBar", (0.022, 0.075, 0.39), (0.48 + line, -0.855, 1.15), "brass", r, bevel=0.002)
    add_tiled_gable_roof(r, 2.22, 0.92, 2.32, 29, 15, 5)

    # Brick forge, glowing firebox, hood and tall flue form the vertical workshop landmark.
    cube("ForgeBody", (0.66, 0.54, 0.72), (0.54, 0.34, 0.67), "brick", r, bevel=0.025)
    cube("Firebox", (0.42, 0.08, 0.29), (0.54, 0.055, 0.66), "iron", r, bevel=0.025)
    uv_sphere("ForgeGlow", 0.15, (0.54, 0.005, 0.64), "lantern_paper", r, 18, 9, (1.0, 0.38, 0.72))
    cylinder("Chimney", 0.18, 1.55, (0.58, 0.40, 2.15), "brick", r, 16, top_radius=0.15, bevel=0.008)
    cylinder("ChimneyCap", 0.24, 0.08, (0.58, 0.40, 2.94), "roof_tile", r, 18, bevel=0.005)
    marker("Smoke", (0.58, 0.40, 3.03), r)

    cube("WorkBench", (0.92, 0.42, 0.12), (-0.39, -0.32, 0.71), "wood_warm", r, bevel=0.014)
    for x in (-0.75, -0.03):
        for y in (-0.46, -0.18):
            cube("BenchLeg", (0.08, 0.08, 0.54), (x, y, 0.45), "wood_dark", r, bevel=0.006)
    cube("AnvilBase", (0.28, 0.30, 0.46), (0.52, -0.45, 0.49), "wood_dark", r, bevel=0.025)
    cube("AnvilBody", (0.52, 0.24, 0.18), (0.52, -0.45, 0.79), "iron", r, bevel=0.035)
    cube("AnvilHorn", (0.30, 0.16, 0.11), (0.86, -0.45, 0.80), "iron", r,
         rotation=(0, math.radians(8), 0), bevel=0.035)
    cube("ToolRack", (0.64, 0.07, 0.72), (-0.47, 0.825, 1.04), "wood_dark", r, bevel=0.012)
    for index, x in enumerate((-0.68, -0.47, -0.26)):
        cylinder("HangingTool", 0.020, 0.47, (x, 0.79, 1.05), "iron", r, 8, bevel=0.002)
        cube("ToolHead", (0.18, 0.05, 0.10), (x, 0.79, 0.82 + 0.04 * index), "iron", r, bevel=0.012)
    cube("WorkshopSign", (0.52, 0.08, 0.24), (0, -0.84, 1.76), "wood_warm", r, bevel=0.018)
    marker("Door", (-0.45, -1.07, 0), r)
    return r


def branch(parent, name, start, end, radius):
    midpoint = (Vector(start) + Vector(end)) * 0.5
    direction = Vector(end) - Vector(start)
    obj = cylinder(name, radius, direction.length, midpoint, "bark", parent, 12, top_radius=radius * 0.55, bevel=0.004)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return obj


def build_tree():
    r = root("Realistic_Tree_01", "tree", "tree")
    r["bounds_m"] = "2.50,4.80,2.50"
    cylinder("Trunk", 0.24, 2.65, (0, 0, 1.325), "bark", r, 18, top_radius=0.14, bevel=0.012)
    branch_specs = [
        ((0, 0, 1.55), (0.78, 0.18, 2.65), 0.11),
        ((0, 0, 1.85), (-0.72, -0.24, 3.05), 0.10),
        ((0, 0, 2.10), (0.32, -0.72, 3.38), 0.085),
        ((0, 0, 2.28), (-0.20, 0.58, 3.62), 0.08),
    ]
    for index, (start, end, radius) in enumerate(branch_specs):
        branch(r, "Branch_%02d" % index, start, end, radius)
        endpoint = Vector(end)
        tangent = endpoint.normalized() * 0.1
        branch(r, "Twig_%02dA" % index, endpoint, endpoint + Vector((((-1) ** index) * 0.36, 0.22, 0.55)), radius * 0.45)
        branch(r, "Twig_%02dB" % index, endpoint, endpoint + Vector((0.16, ((-1) ** (index + 1)) * 0.34, 0.48)), radius * 0.40)
    clusters = [
        (-0.86, -0.18, 3.25, 0.78, "leaf"), (0.78, 0.22, 2.93, 0.82, "leaf_light"),
        (0.28, -0.74, 3.48, 0.75, "leaf"), (-0.18, 0.64, 3.72, 0.70, "leaf_light"),
        (0.05, 0.02, 4.05, 0.88, "leaf"), (0.64, -0.34, 3.88, 0.64, "leaf_light"),
        (-0.60, 0.42, 3.78, 0.68, "leaf"),
    ]
    for index, (x, y, z, radius, mat) in enumerate(clusters):
        ico("LeafCluster_%02d" % index, radius, (x, y, z), mat, r, 2, (1.0, 0.84, 0.78), 0.10)
    return r


def build_rock():
    r = root("Realistic_Rock_01", "rock", "rock")
    main = ico("MainRock", 0.62, (0, 0, 0.46), "rock", r, 3, (1.18, 0.88, 0.78), 0.14)
    main.rotation_euler = (math.radians(5), math.radians(-12), math.radians(8))
    chip = ico("SecondaryRock", 0.34, (-0.55, 0.24, 0.23), "stone", r, 2, (1.0, 0.82, 0.72), 0.12)
    chip.rotation_euler = (0, math.radians(24), math.radians(-8))
    for index in range(5):
        angle = index * 1.23
        ico("Pebble_%02d" % index, 0.09 + index * 0.008, (math.cos(angle) * 0.82, math.sin(angle) * 0.55, 0.07), "stone", r, 1, (1.2, 0.8, 0.6), 0.10)
    return r


def build_tree_02():
    """A low, wide willow with a split trunk and visibly drooping branch curtains."""
    r = root("Realistic_Tree_02", "tree", "tree")
    r["bounds_m"] = "3.80,4.30,3.60"
    r["species_style"] = "weeping_willow"

    # Broad roots and an off-axis, forked trunk keep the silhouette distinct from Tree 01.
    root_specs = [
        ((0.00, 0.00, 0.14), (0.64, 0.20, 0.03), 0.11),
        ((0.00, 0.00, 0.13), (-0.58, 0.34, 0.03), 0.10),
        ((0.00, 0.00, 0.12), (0.22, -0.68, 0.025), 0.095),
        ((0.00, 0.00, 0.12), (-0.30, -0.54, 0.025), 0.085),
    ]
    for index, (start, end, radius) in enumerate(root_specs):
        branch(r, "WillowRoot_%02d" % index, start, end, radius)

    trunk_segments = [
        ((0.00, 0.00, 0.05), (0.04, 0.00, 0.98), 0.29),
        ((0.04, 0.00, 0.88), (-0.10, 0.04, 1.82), 0.24),
        ((-0.10, 0.04, 1.72), (0.02, 0.02, 2.48), 0.18),
    ]
    for index, (start, end, radius) in enumerate(trunk_segments):
        branch(r, "WillowTrunk_%02d" % index, start, end, radius)

    crown_branches = [
        ((-0.04, 0.03, 1.35), (0.92, 0.20, 2.42), 0.14),
        ((-0.08, 0.04, 1.55), (-0.92, -0.12, 2.52), 0.13),
        ((-0.04, 0.03, 1.78), (0.26, -0.92, 2.72), 0.12),
        ((-0.02, 0.03, 1.92), (-0.34, 0.86, 2.82), 0.11),
        ((0.00, 0.02, 2.22), (0.72, 0.72, 3.05), 0.09),
        ((0.00, 0.02, 2.28), (-0.68, 0.58, 3.16), 0.09),
    ]
    for index, (start, end, radius) in enumerate(crown_branches):
        branch(r, "WillowBough_%02d" % index, start, end, radius)
        endpoint = Vector(end)
        side = -1.0 if index % 2 else 1.0
        branch(r, "WillowFork_%02dA" % index, endpoint, endpoint + Vector((side * 0.50, 0.18, 0.26)), radius * 0.48)
        branch(r, "WillowFork_%02dB" % index, endpoint, endpoint + Vector((-side * 0.18, -0.46, 0.22)), radius * 0.42)

    # Long curved whips and vertically stretched leaf masses form a willow curtain.
    hanging_specs = [
        ((1.28, 0.36, 2.82), (1.58, 0.46, 1.28), "leaf_light"),
        ((0.82, 0.94, 3.05), (1.02, 1.18, 1.58), "leaf"),
        ((-0.88, 0.78, 3.12), (-1.24, 0.92, 1.44), "leaf_light"),
        ((-1.26, -0.24, 2.88), (-1.55, -0.42, 1.22), "leaf"),
        ((-0.36, -1.04, 2.84), (-0.52, -1.36, 1.30), "leaf_light"),
        ((0.72, -0.94, 2.82), (1.08, -1.22, 1.34), "leaf"),
        ((1.42, -0.28, 2.70), (1.64, -0.38, 1.22), "leaf_light"),
        ((0.10, 1.26, 2.86), (0.18, 1.54, 1.36), "leaf"),
    ]
    for index, (start, end, mat_name) in enumerate(hanging_specs):
        middle = ((start[0] + end[0]) * 0.5 + (0.10 if index % 2 else -0.10),
                  (start[1] + end[1]) * 0.5,
                  (start[2] + end[2]) * 0.5 + 0.10)
        curve_tube("WillowWhip_%02d" % index, [start, middle, end], 0.018, "bark", r, 1)
        for cluster_index, factor in enumerate((0.18, 0.46, 0.73)):
            x = start[0] + (end[0] - start[0]) * factor
            y = start[1] + (end[1] - start[1]) * factor
            z = start[2] + (end[2] - start[2]) * factor
            ico("WillowLeaf_%02d_%02d" % (index, cluster_index), 0.34, (x, y, z), mat_name, r, 2,
                (0.72, 0.56, 1.28), 0.13)

    canopy = [
        (-0.72, 0.05, 3.18, 0.72, "leaf"),
        (0.62, 0.12, 3.12, 0.76, "leaf_light"),
        (0.02, -0.62, 3.18, 0.68, "leaf"),
        (0.02, 0.62, 3.28, 0.70, "leaf_light"),
        (0.02, 0.00, 3.58, 0.78, "leaf"),
    ]
    for index, (x, y, z, radius, mat_name) in enumerate(canopy):
        ico("WillowCanopy_%02d" % index, radius, (x, y, z), mat_name, r, 2, (1.18, 0.92, 0.72), 0.11)
    return r


def build_tree_03():
    """A tall pine whose open tiered crown reads clearly against the broad deciduous trees."""
    r = root("Realistic_Tree_03", "tree", "tree")
    r["bounds_m"] = "3.10,5.60,3.00"
    r["species_style"] = "mountain_pine"

    # Exposed roots and segmented taper produce a rugged highland trunk.
    for index, angle in enumerate((0.15, 1.72, 3.18, 4.86)):
        start = (0.0, 0.0, 0.13)
        end = (math.cos(angle) * 0.62, math.sin(angle) * 0.62, 0.025)
        branch(r, "PineRoot_%02d" % index, start, end, 0.085)
    trunk_segments = [
        ((0.00, 0.00, 0.04), (0.02, 0.00, 1.52), 0.23),
        ((0.02, 0.00, 1.42), (-0.03, 0.02, 2.90), 0.18),
        ((-0.03, 0.02, 2.80), (0.04, -0.02, 4.18), 0.13),
        ((0.04, -0.02, 4.08), (0.00, 0.00, 5.16), 0.085),
    ]
    for index, (start, end, radius) in enumerate(trunk_segments):
        branch(r, "PineTrunk_%02d" % index, start, end, radius)

    tiers = [
        (2.10, 1.32, 7, 0.10),
        (2.82, 1.18, 6, 0.085),
        (3.48, 0.96, 5, 0.070),
        (4.06, 0.72, 4, 0.055),
        (4.56, 0.46, 3, 0.045),
    ]
    for tier_index, (height, reach, count, radius) in enumerate(tiers):
        phase = tier_index * 0.63
        for branch_index in range(count):
            angle = phase + branch_index * math.tau / count
            upward = 0.10 + 0.08 * ((branch_index + tier_index) % 3)
            start = (0.0, 0.0, height)
            knee = (math.cos(angle) * reach * 0.56, math.sin(angle) * reach * 0.56, height + upward)
            end = (math.cos(angle) * reach, math.sin(angle) * reach, height + upward * 0.42)
            branch(r, "PineLimb_%02d_%02dA" % (tier_index, branch_index), start, knee, radius)
            branch(r, "PineLimb_%02d_%02dB" % (tier_index, branch_index), knee, end, radius * 0.62)
            # Needle masses run along each limb instead of merging into a round canopy.
            for cluster_index, factor in enumerate((0.48, 0.76, 1.0)):
                x = math.cos(angle) * reach * factor
                y = math.sin(angle) * reach * factor
                z = height + upward * (1.0 - abs(factor - 0.58)) + 0.10
                mat_name = "leaf_light" if (branch_index + cluster_index + tier_index) % 4 == 0 else "leaf"
                cluster = ico("PineNeedles_%02d_%02d_%02d" % (tier_index, branch_index, cluster_index),
                              0.34 if tier_index < 2 else 0.29, (x, y, z), mat_name, r, 2,
                              (1.35, 0.50, 0.44), 0.12)
                cluster.rotation_euler[2] = angle

    for index, z in enumerate((4.72, 5.00, 5.28)):
        ico("PineCrown_%02d" % index, 0.36 - index * 0.045, (0, 0, z),
            "leaf_light" if index == 1 else "leaf", r, 2, (0.82, 0.82, 1.28), 0.10)
    return r


def build_rock_02():
    """A tall, fractured scholar stone assembled from offset strata and scree."""
    r = root("Realistic_Rock_02", "rock", "rock")
    r["bounds_m"] = "1.85,2.65,1.55"
    r["formation_style"] = "standing_strata"

    strata = [
        ((0.00, 0.00, 0.28), 0.52, (1.30, 0.92, 0.60), (2, -7, 5), "stone"),
        ((-0.10, 0.02, 0.74), 0.55, (1.02, 0.76, 0.92), (-5, 9, -6), "rock"),
        ((0.08, -0.03, 1.22), 0.50, (0.86, 0.70, 1.04), (7, -12, 8), "rock"),
        ((-0.03, 0.00, 1.69), 0.43, (0.72, 0.61, 1.08), (-8, 6, -9), "stone"),
        ((0.06, 0.01, 2.08), 0.35, (0.58, 0.55, 0.96), (4, -16, 11), "rock"),
    ]
    for index, (location, radius, scale, rotation_degrees, mat_name) in enumerate(strata):
        slab = ico("StandingStratum_%02d" % index, radius, location, mat_name, r, 2 if index else 3,
                   scale, 0.17)
        slab.rotation_euler = tuple(math.radians(value) for value in rotation_degrees)

    # Thin ledges break the vertical mass and make the layered formation readable.
    ledges = [
        ((-0.13, 0.00, 0.53), 0.44, (1.30, 0.78, 0.18), 7),
        ((0.09, -0.02, 1.01), 0.39, (1.18, 0.72, 0.16), -9),
        ((-0.06, 0.01, 1.48), 0.33, (1.05, 0.66, 0.14), 11),
        ((0.04, 0.00, 1.89), 0.27, (0.90, 0.60, 0.13), -13),
    ]
    for index, (location, radius, scale, angle) in enumerate(ledges):
        ledge = ico("RockLedge_%02d" % index, radius, location, "stone", r, 2, scale, 0.10)
        ledge.rotation_euler[2] = math.radians(angle)

    for index, (x, y, scale) in enumerate((
        (-0.64, -0.26, (1.25, 0.80, 0.58)),
        (0.58, 0.22, (1.00, 0.76, 0.66)),
        (-0.42, 0.47, (0.92, 0.72, 0.54)),
        (0.46, -0.42, (1.15, 0.66, 0.48)),
    )):
        ico("StrataScree_%02d" % index, 0.18, (x, y, 0.105), "stone", r, 1, scale, 0.14)
    return r


def build_rock_03():
    """A low river-boulder family with a crescent footprint and polished silhouettes."""
    r = root("Realistic_Rock_03", "rock", "rock")
    r["bounds_m"] = "3.10,1.25,2.25"
    r["formation_style"] = "river_boulder_cluster"

    boulders = [
        ((-0.66, 0.02, 0.34), 0.62, (1.35, 0.90, 0.58), (2, 13, -7), "rock"),
        ((0.28, 0.12, 0.46), 0.72, (1.22, 0.86, 0.68), (-4, -11, 9), "stone"),
        ((0.92, -0.08, 0.29), 0.48, (1.18, 0.82, 0.54), (3, 8, -12), "rock"),
        ((0.34, 0.66, 0.22), 0.37, (1.18, 0.88, 0.52), (-2, 10, 16), "rock"),
        ((-0.58, 0.63, 0.20), 0.34, (1.12, 0.82, 0.50), (4, -7, -16), "stone"),
    ]
    for index, (location, radius, scale, rotation_degrees, mat_name) in enumerate(boulders):
        boulder = ico("RiverBoulder_%02d" % index, radius, location, mat_name, r, 3 if index < 3 else 2,
                      scale, 0.075)
        boulder.rotation_euler = tuple(math.radians(value) for value in rotation_degrees)

    # A scatter of flatter stones widens the crescent and distinguishes it from Rock 01.
    pebbles = [
        (-1.30, -0.12, 0.16, 1.20, 0.72), (-1.05, 0.54, 0.13, 1.08, 0.68),
        (-0.18, 0.92, 0.14, 1.18, 0.62), (0.68, 0.88, 0.12, 1.02, 0.72),
        (1.22, 0.48, 0.15, 1.14, 0.66), (1.35, -0.30, 0.13, 1.20, 0.60),
        (0.68, -0.66, 0.11, 1.06, 0.62), (-0.20, -0.58, 0.10, 1.14, 0.66),
    ]
    for index, (x, y, radius, sx, sy) in enumerate(pebbles):
        pebble = ico("RiverPebble_%02d" % index, radius, (x, y, radius * 0.48),
                     "stone" if index % 3 == 0 else "rock", r, 2, (sx, sy, 0.48), 0.06)
        pebble.rotation_euler[2] = math.radians(index * 29 - 18)
    return r


def build_crops():
    """A compact irrigated crop plot with readable rows, seedlings, sluice, and hoe."""
    r = root("Realistic_Crops", "crops", "crops")
    r["bounds_m"] = "3.80,1.25,3.00"
    r["crop_style"] = "irrigated_grain_plot"

    # Raised soil beds and a blue-grey recessed strip establish the field layout.
    cube("FieldBase", (3.60, 2.78, 0.10), (0, 0, 0.05), "rock", r, bevel=0.025)
    bed_centers = (-1.20, -0.40, 0.40, 1.20)
    for index, x in enumerate(bed_centers):
        cube("RaisedBed_%02d" % index, (0.58, 2.48, 0.18), (x, 0.04, 0.16),
             "rock" if index % 2 else "stone", r, bevel=0.075)
    cube("IrrigationWater", (0.22, 2.66, 0.035), (0.0, -0.02, 0.125), "roof_tile", r, bevel=0.012)
    for x in (-0.17, 0.17):
        cube("ChannelLining", (0.10, 2.78, 0.15), (x, -0.02, 0.15), "stone", r, bevel=0.035)
    for y in (-1.34, 1.34):
        cube("FieldEdge", (3.72, 0.12, 0.20), (0, y, 0.13), "stone", r, bevel=0.045)

    # Each plant is individually built with a central stalk, splayed leaves, and grain head.
    plant_index = 0
    for bed_index, x in enumerate(bed_centers):
        if abs(x) < 0.55:
            # Preserve a visual gap beside the central channel.
            x += -0.08 if x < 0 else 0.08
        for row_index, y in enumerate((-1.04, -0.68, -0.32, 0.06, 0.44, 0.82, 1.12)):
            z_base = 0.25
            height = 0.52 + 0.06 * ((bed_index + row_index) % 3)
            lean = 0.05 * (-1 if (bed_index + row_index) % 2 else 1)
            stem_end = (x + lean, y, z_base + height)
            stem = branch(r, "CropStem_%03d" % plant_index, (x, y, z_base), stem_end, 0.016)
            stem.data.materials.clear()
            stem.data.materials.append(MATERIALS["leaf_light"])
            for leaf_index, (dx, dy, dz) in enumerate((
                (-0.12, 0.03, 0.32), (0.12, -0.02, 0.36),
                (-0.04, 0.12, 0.42), (0.05, -0.11, 0.38),
            )):
                leaf_end = (x + dx, y + dy, z_base + dz)
                leaf = branch(r, "CropLeaf_%03d_%02d" % (plant_index, leaf_index),
                              (x, y, z_base + 0.05), leaf_end, 0.011)
                leaf.data.materials.clear()
                leaf.data.materials.append(MATERIALS["leaf" if leaf_index % 2 else "leaf_light"])
            grain_x, grain_y, grain_z = stem_end
            for grain_index in range(4):
                offset_z = grain_z - grain_index * 0.055
                side = -1 if grain_index % 2 else 1
                ico("Grain_%03d_%02d" % (plant_index, grain_index), 0.032,
                    (grain_x + side * 0.026, grain_y, offset_z), "rope", r, 1,
                    (0.72, 0.62, 1.45), 0.02)
            plant_index += 1

    # Wooden sluice at the channel head plus a field hoe create an unmistakable work area.
    for x in (-0.24, 0.24):
        cube("SluicePost", (0.09, 0.10, 0.70), (x, -1.08, 0.47), "wood_dark", r, bevel=0.012)
    cube("SluiceGate", (0.42, 0.08, 0.38), (0, -1.08, 0.34), "wood_warm", r, bevel=0.016)
    cylinder("SluiceHandle", 0.027, 0.62, (0, -1.08, 0.92), "wood_dark", r, 10, bevel=0.003)
    cylinder("HoeHandle", 0.028, 1.32, (1.56, 0.72, 0.63), "wood_warm", r, 12,
             rotation=(math.radians(-18), math.radians(20), math.radians(8)), bevel=0.004)
    cube("HoeBlade", (0.36, 0.08, 0.18), (1.39, 0.64, 0.16), "brass", r,
         rotation=(math.radians(8), math.radians(-16), math.radians(-10)), bevel=0.012)
    return r


def build_lantern():
    r = root("Realistic_Lantern", "lantern", "lantern")
    cylinder("Post", 0.055, 1.55, (0, 0, 0.775), "wood_dark", r, 16, top_radius=0.045, bevel=0.006)
    cube("StoneFoot", (0.26, 0.26, 0.18), (0, 0, 0.09), "stone", r, bevel=0.03)
    curve_tube("Hook", [(0, 0, 1.48), (0.18, 0, 1.58), (0.42, 0, 1.50), (0.45, 0, 1.38)], 0.026, "brass", r, 2)
    for link_index in range(3):
        cylinder("ChainLink", 0.032, 0.075, (0.45, 0, 1.34 - link_index * 0.07), "brass", r, 12, bevel=0.002)
    cylinder("LanternPaper", 0.19, 0.48, (0.45, 0, 0.99), "lantern_paper", r, 24, top_radius=0.17, bevel=0.004)
    for z in (0.73, 1.25):
        cylinder("LanternCap", 0.23, 0.055, (0.45, 0, z), "brass", r, 20, bevel=0.004)
    for angle in range(0, 360, 90):
        radians = math.radians(angle)
        x = 0.45 + math.cos(radians) * 0.185
        y = math.sin(radians) * 0.185
        cylinder("FrameBar", 0.012, 0.47, (x, y, 0.99), "brass", r, 8, bevel=0.001)
    curve_tube("TasselCord", [(0.45, 0, 0.70), (0.45, 0.01, 0.57), (0.46, -0.01, 0.43)], 0.012, "rope", r, 1)
    for index in range(9):
        angle = index * math.tau / 9
        curve_tube("TasselThread_%02d" % index, [(0.46, 0, 0.45), (0.46 + math.cos(angle) * 0.05, math.sin(angle) * 0.05, 0.23)], 0.006, "paint_red", r, 1)
    return r


def build_bridge():
    r = root("Realistic_Bridge", "bridge", "bridge")
    r["bounds_m"] = "4.40,1.65,1.35"
    for index in range(14):
        x = -2.02 + index * (4.04 / 13)
        arch = 0.22 * (1.0 - (x / 2.15) ** 2)
        plank = cube("DeckPlank_%02d" % index, (0.285, 1.28, 0.12), (x, 0, 0.32 + arch), "wood_warm", r, bevel=0.018)
        plank.rotation_euler[1] = math.radians(-x * 4.0)
        for side in (-1, 1):
            cylinder("Nail", 0.014, 0.018, (x, side * 0.46, 0.40 + arch), "brass", r, 10, bevel=0.001)
    for x in (-1.92, -0.98, 0.0, 0.98, 1.92):
        arch = 0.22 * (1.0 - (x / 2.15) ** 2)
        for side in (-1, 1):
            cylinder("RailPost", 0.055, 0.72, (x, side * 0.58, 0.70 + arch), "wood_dark", r, 12, top_radius=0.045, bevel=0.005)
    for side in (-1, 1):
        points = []
        for index in range(9):
            x = -2.02 + index * 0.505
            arch = 0.22 * (1.0 - (x / 2.15) ** 2)
            points.append((x, side * 0.58, 1.05 + arch))
        curve_tube("Handrail", points, 0.045, "wood_dark", r, 2)
        curve_tube("LowerRail", [(x, side * 0.58, 0.73 + 0.16 * (1.0 - (x / 2.15) ** 2)) for x in (-2.0, -1.0, 0, 1.0, 2.0)], 0.027, "rope", r, 2)
    for x in (-1.55, 1.55):
        cube("StonePier", (0.34, 1.48, 0.62), (x, 0, 0.12), "stone", r, bevel=0.05)
    return r


def build_citizen():
    r = root("Realistic_Citizen", "citizen", "citizen")
    r["height_m"] = 1.62
    # Feet, legs and robe layers make a grounded human silhouette without requiring a rig.
    for side in (-1, 1):
        cube("Shoe", (0.17, 0.32, 0.09), (side * 0.10, -0.045, 0.07), "hair", r, bevel=0.025)
        cylinder("LowerLeg", 0.075, 0.44, (side * 0.10, 0, 0.30), "cloth_blue", r, 14, top_radius=0.085, bevel=0.004)
    cylinder("RobeLower", 0.29, 0.64, (0, 0, 0.59), "cloth_blue", r, 20, top_radius=0.22, bevel=0.006)
    cylinder("Torso", 0.23, 0.52, (0, 0, 1.02), "cloth", r, 20, top_radius=0.18, bevel=0.007)
    cube("Sash", (0.48, 0.36, 0.09), (0, 0, 0.80), "brass", r, bevel=0.012)
    cylinder("Neck", 0.065, 0.12, (0, 0, 1.33), "skin", r, 16, bevel=0.003)
    uv_sphere("Head", 0.18, (0, -0.012, 1.49), "skin", r, 24, 12, (0.94, 0.92, 1.05))
    uv_sphere("HairCap", 0.185, (0, 0.005, 1.56), "hair", r, 24, 10, (0.96, 0.96, 0.62))
    cylinder("HatBrim", 0.31, 0.045, (0, 0, 1.67), "rope", r, 24, bevel=0.004)
    cylinder("HatCrown", 0.20, 0.17, (0, 0, 1.76), "rope", r, 20, top_radius=0.055, bevel=0.004)
    for side in (-1, 1):
        shoulder = Vector((side * 0.24, 0, 1.19))
        elbow = Vector((side * 0.32, -0.05, 0.92))
        hand = Vector((side * 0.28, -0.12, 0.70))
        branch(r, "UpperArm", shoulder, elbow, 0.07).data.materials.clear()
        r.children[-1].data.materials.append(MATERIALS["cloth"])
        branch(r, "Forearm", elbow, hand, 0.055).data.materials.clear()
        r.children[-1].data.materials.append(MATERIALS["skin"])
        uv_sphere("Hand", 0.065, hand, "skin", r, 16, 8, (0.85, 0.75, 1.0))
    # Woven market basket gives the character a readable occupation prop.
    cylinder("Basket", 0.20, 0.30, (0.36, -0.12, 0.58), "rope", r, 18, top_radius=0.25, bevel=0.004)
    curve_tube("BasketHandle", [(0.16, -0.12, 0.68), (0.36, -0.12, 0.91), (0.56, -0.12, 0.68)], 0.018, "rope", r, 2)
    return r


def descendants(obj):
    result = [obj]
    for child in obj.children:
        result.extend(descendants(child))
    return result


def export_asset(asset_root, filename, entrance_axis="n/a"):
    bpy.ops.object.select_all(action="DESELECT")
    objects = descendants(asset_root)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = asset_root
    output_path = MODEL_DIR / filename
    bpy.ops.export_scene.gltf(
        filepath=str(output_path), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=True, export_materials="EXPORT",
        export_extras=True, export_cameras=False, export_lights=False,
        export_image_format="AUTO",
    )
    mesh_objects = [obj for obj in objects if obj.type == "MESH"]
    triangle_count = sum(sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons) for obj in mesh_objects)
    material_names = sorted({slot.material.name for obj in mesh_objects for slot in obj.material_slots if slot.material})
    ASSET_RECORDS.append({
        "file": filename,
        "root": asset_root.name,
        "asset_type": asset_root.get("asset_type", "prop"),
        "fallback_key": asset_root.get("fallback_key", ""),
        "origin": "ground_center",
        "godot_entrance_axis": entrance_axis,
        "mesh_parts": len(mesh_objects),
        "triangles_before_modifiers": triangle_count,
        "materials": material_names,
    })


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def build_preview(roots):
    placement = {
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
    for obj in roots:
        obj.location = placement[obj.name]
    cube("PreviewGround", (15.5, 13.8, 0.16), (0, 0, -0.10), "stone", bevel=0.05)
    bpy.ops.object.light_add(type="AREA", location=(-6.0, -7.5, 10.5))
    key = bpy.context.object
    key.name = "KeyLight"
    key.data.energy = 1050
    key.data.shape = "DISK"
    key.data.size = 6.0
    key.data.color = (1.0, 0.72, 0.48)
    aim(key, (0, 0, 1.0))
    bpy.ops.object.light_add(type="AREA", location=(7.0, 2.5, 8.0))
    fill = bpy.context.object
    fill.name = "FillLight"
    fill.data.energy = 650
    fill.data.size = 7.0
    fill.data.color = (0.48, 0.68, 0.78)
    aim(fill, (0, 0, 1.2))
    bpy.ops.object.light_add(type="AREA", location=(0, 5.0, 3.5))
    rim = bpy.context.object
    rim.name = "RimLight"
    rim.data.energy = 500
    rim.data.size = 3.0
    rim.data.color = (0.82, 0.90, 1.0)
    aim(rim, (0, 0, 1.4))
    bpy.ops.object.camera_add(location=(0, -25.0, 12.5))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 15.8
    aim(camera, (0, 0.15, 1.55))
    bpy.context.scene.camera = camera
    world = bpy.context.scene.world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.055, 0.075, 0.075, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.32
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 2200
    scene.render.resolution_y = 1400
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_DIR / "realistic_full_asset_sheet.png")
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / "east_valley_realistic_full.blend"))
    bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    setup_materials()
    builders = [
        (build_house, "building_house.glb", "+Z"),
        (build_lumber, "building_lumber.glb", "+Z"),
        (build_farm, "building_farm.glb", "+Z"),
        (build_warehouse, "building_warehouse.glb", "+Z"),
        (build_workshop, "building_workshop.glb", "+Z"),
        (build_tree, "prop_tree_01.glb", "n/a"),
        (build_tree_02, "prop_tree_02.glb", "n/a"),
        (build_tree_03, "prop_tree_03.glb", "n/a"),
        (build_rock, "prop_rock_01.glb", "n/a"),
        (build_rock_02, "prop_rock_02.glb", "n/a"),
        (build_rock_03, "prop_rock_03.glb", "n/a"),
        (build_lantern, "prop_lantern.glb", "n/a"),
        (build_bridge, "prop_bridge.glb", "n/a"),
        (build_crops, "prop_crops.glb", "n/a"),
        (build_citizen, "character_citizen.glb", "n/a"),
    ]
    roots = []
    for builder, filename, entrance_axis in builders:
        asset_root = builder()
        roots.append(asset_root)
        export_asset(asset_root, filename, entrance_axis)
    manifest = {
        "generator": "tools/generate_realistic_assets.py",
        "tier": "realistic_full_v1",
        "art_version": 2,
        "tile_meters": 2.0,
        "coordinate_contract": "meters; ground center origin; Godot +Z building entrance",
        "pbr_channels": ["basecolor", "roughness", "normal"],
        "texture_resolution": 256,
        "coverage": "15/15",
        "preview": "godot/assets/realistic/previews/realistic_full_asset_sheet.png",
        "source": "godot/assets/realistic/source/east_valley_realistic_full.blend",
        "assets": ASSET_RECORDS,
    }
    (MODEL_DIR / "realistic_manifest.json").write_text(json.dumps(manifest, ensure_ascii=True, indent=2), encoding="utf-8")
    (SOURCE_DIR / ".gdignore").write_text("# Blender source is intentionally excluded from Godot import.\n", encoding="ascii")
    build_preview(roots)
    print("REALISTIC_FULL_OK", len(ASSET_RECORDS), MODEL_DIR)


if __name__ == "__main__":
    main()
