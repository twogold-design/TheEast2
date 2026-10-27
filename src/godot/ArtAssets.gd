class_name ArtAssets
extends RefCounted

## Procedural low-poly art kit. One logical tile is 2 m; +Z is the entrance side.

const PALETTE := {
	"ink": Color("2f3433"),
	"plaster": Color("d7c29e"),
	"warm_plaster": Color("c98963"),
	"wood": Color("8a5c3b"),
	"dark_wood": Color("51392d"),
	"thatch": Color("b79a61"),
	"tile": Color("536c73"),
	"tile_light": Color("698187"),
	"brick": Color("9b6048"),
	"stone": Color("747872"),
	"stone_light": Color("96998f"),
	"soil": Color("805e3d"),
	"crop": Color("769154"),
	"grain": Color("d6a74a"),
	"leaf": Color("506f51"),
	"leaf_light": Color("66825e"),
	"lantern": Color("b94a42"),
	"lantern_light": Color("f2b45b"),
	"skin": Color("e2b889"),
	"cloth_blue": Color("5d8792"),
	"cloth_rust": Color("b8684b"),
	"cloth_green": Color("708c62"),
	"cloth_gold": Color("c8973e"),
	"water": Color("5d9da7"),
	"preview_valid": Color("d6a74a"),
	"preview_invalid": Color("b94a42"),
}

const BUILDING_BOUNDS := {
	"house": Vector3(1.70, 1.85, 1.65),
	"lumber": Vector3(1.82, 1.72, 1.72),
	"farm": Vector3(1.72, 1.28, 1.72),
	"warehouse": Vector3(1.82, 2.12, 1.82),
	"workshop": Vector3(1.78, 2.22, 1.72),
}

const MODEL_PATHS := {
	"house": "res://godot/assets/models/building_house.glb",
	"lumber": "res://godot/assets/models/building_lumber.glb",
	"farm": "res://godot/assets/models/building_farm.glb",
	"warehouse": "res://godot/assets/models/building_warehouse.glb",
	"workshop": "res://godot/assets/models/building_workshop.glb",
	"bridge": "res://godot/assets/models/prop_bridge.glb",
	"lantern": "res://godot/assets/models/prop_lantern.glb",
	"crops": "res://godot/assets/models/prop_crops.glb",
	"citizen": "res://godot/assets/models/character_citizen.glb",
}

static var _materials: Dictionary = {}
static var _boxes: Dictionary = {}
static var _cylinders: Dictionary = {}
static var _spheres: Dictionary = {}
static var _packed_scenes: Dictionary = {}


static func apply_preview_tint(root: Node3D, valid: bool) -> void:
	var tint: Color = PALETTE.preview_valid if valid else PALETTE.preview_invalid
	var preview_material := _material(tint, 0.46, true)
	_apply_material_recursive(root, preview_material)


static func _apply_material_recursive(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_material_recursive(child, material)


static func create_building(type: String, preview: bool = false) -> Node3D:
	var imported := _instantiate_model(str(MODEL_PATHS.get(type, "")))
	if imported:
		var imported_bounds: Vector3 = BUILDING_BOUNDS.get(type, Vector3(1.7, 1.8, 1.7))
		imported.name = "Building_%s" % type.capitalize()
		imported.set_meta("building_type", type)
		imported.set_meta("art_bounds", imported_bounds)
		imported.set_meta("art_version", 1)
		if imported.find_child("Door", true, false) == null:
			var imported_door := Marker3D.new()
			imported_door.name = "Door"
			imported_door.position = Vector3(0, 0, 0.92)
			imported.add_child(imported_door)
		if preview:
			apply_preview_tint(imported, true)
		else:
			_add_box_collision(imported, imported_bounds, "AssetCollision")
		return imported
	var root := Node3D.new()
	root.name = "Building_%s" % type.capitalize()
	root.set_meta("building_type", type)
	root.set_meta("art_bounds", BUILDING_BOUNDS.get(type, Vector3(1.7, 1.8, 1.7)))
	root.set_meta("art_version", 1)

	match type:
		"house":
			_build_house(root, preview)
		"lumber":
			_build_lumber(root, preview)
		"farm":
			_build_farm(root, preview)
		"warehouse":
			_build_warehouse(root, preview)
		"workshop":
			_build_workshop(root, preview)
		_:
			_add_box(root, "FallbackBody", Vector3(1.5, 0.8, 1.5), Vector3(0, 0.48, 0), PALETTE.plaster, preview)

	var door := Marker3D.new()
	door.name = "Door"
	door.position = Vector3(0, 0, 0.92)
	root.add_child(door)
	if not preview:
		_add_box_collision(root, BUILDING_BOUNDS.get(type, Vector3(1.7, 1.8, 1.7)), "AssetCollision")
	return root


static func create_tree(variant: int = 0) -> Node3D:
	var tree_path := "res://godot/assets/models/prop_tree_%02d.glb" % (posmod(variant, 3) + 1)
	var imported := _instantiate_model(tree_path)
	if imported:
		imported.name = "Tree_%02d" % posmod(variant, 3)
		imported.set_meta("asset_type", "tree")
		return imported
	var root := Node3D.new()
	root.name = "Tree_%02d" % posmod(variant, 3)
	root.set_meta("asset_type", "tree")
	var height_scale := [0.92, 1.08, 1.0][posmod(variant, 3)] as float
	_add_cylinder(root, "Trunk", 0.10, 0.16, 1.18 * height_scale, Vector3(0, 0.62 * height_scale, 0), PALETTE.dark_wood, false, 6)
	_add_cylinder(root, "CrownLower", 0.48, 0.72, 0.95, Vector3(0, 1.42 * height_scale, 0), PALETTE.leaf, false, 7)
	_add_cylinder(root, "CrownUpper", 0.10, 0.54, 0.90, Vector3(0.06 * (variant % 2), 2.08 * height_scale, -0.03), PALETTE.leaf_light, false, 7)
	if posmod(variant, 3) == 2:
		_add_sphere(root, "CrownAccent", 0.35, Vector3(-0.34, 1.72, 0.08), PALETTE.leaf, false, Vector3(1.0, 0.82, 0.9), true)
	return root


static func create_rock(variant: int = 0) -> Node3D:
	var rock_path := "res://godot/assets/models/prop_rock_%02d.glb" % (posmod(variant, 3) + 1)
	var imported := _instantiate_model(rock_path)
	if imported:
		imported.name = "Rock_%02d" % posmod(variant, 3)
		imported.set_meta("asset_type", "rock")
		return imported
	var root := Node3D.new()
	root.name = "Rock_%02d" % posmod(variant, 3)
	root.set_meta("asset_type", "rock")
	var scale_variants := [Vector3(0.68, 0.42, 0.52), Vector3(0.46, 0.66, 0.55), Vector3(0.78, 0.36, 0.66)]
	_add_sphere(root, "MainStone", 0.5, Vector3(0, 0.30, 0), PALETTE.stone, false, scale_variants[posmod(variant, 3)], false)
	_add_sphere(root, "LightFace", 0.24, Vector3(-0.26, 0.31, 0.18), PALETTE.stone_light, false, Vector3(0.9, 0.55, 0.75), true)
	return root


static func create_lantern() -> Node3D:
	var imported := _instantiate_model(MODEL_PATHS.lantern)
	if imported:
		imported.name = "LanternPost"
		imported.set_meta("asset_type", "lantern")
		return imported
	var root := Node3D.new()
	root.name = "LanternPost"
	root.set_meta("asset_type", "lantern")
	_add_cylinder(root, "Post", 0.035, 0.045, 1.28, Vector3(0, 0.64, 0), PALETTE.dark_wood, false, 6)
	_add_box(root, "Crossbar", Vector3(0.42, 0.045, 0.045), Vector3(0.15, 1.21, 0), PALETTE.dark_wood)
	_add_cylinder(root, "LanternBody", 0.14, 0.14, 0.32, Vector3(0.31, 0.99, 0), PALETTE.lantern, false, 8, true)
	_add_cylinder(root, "LanternCapTop", 0.08, 0.18, 0.08, Vector3(0.31, 1.19, 0), PALETTE.grain, false, 8)
	_add_cylinder(root, "LanternCapBottom", 0.18, 0.08, 0.08, Vector3(0.31, 0.79, 0), PALETTE.grain, false, 8)
	_add_box(root, "Tassel", Vector3(0.025, 0.20, 0.025), Vector3(0.31, 0.65, 0), PALETTE.lantern)
	return root


static func create_bridge() -> Node3D:
	var imported := _instantiate_model(MODEL_PATHS.bridge)
	if imported:
		imported.name = "Bridge_Wood_01"
		imported.set_meta("asset_type", "bridge")
		_add_box_collision(imported, Vector3(4.0, 0.24, 1.42), "BridgeDeckCollision", 0.38)
		return imported
	var root := Node3D.new()
	root.name = "Bridge_Wood_01"
	root.set_meta("asset_type", "bridge")
	# Length follows X to span the two-cell river in the current map.
	for plank_index in range(8):
		var x := -1.75 + plank_index * 0.5
		var rise := 0.12 * (1.0 - absf(x) / 2.0)
		_add_box(root, "DeckPlank_%02d" % plank_index, Vector3(0.46, 0.12, 1.38), Vector3(x, 0.26 + rise, 0), PALETTE.wood)
	for side in [-1.0, 1.0]:
		for post_index in range(5):
			var x := -1.8 + post_index * 0.9
			_add_cylinder(root, "RailPost_%s_%02d" % ["N" if side < 0 else "S", post_index], 0.045, 0.055, 0.62, Vector3(x, 0.65, side * 0.63), PALETTE.dark_wood, false, 6, false, true)
		_add_box(root, "Handrail_%s" % ("N" if side < 0 else "S"), Vector3(3.9, 0.07, 0.07), Vector3(0, 0.94, side * 0.63), PALETTE.dark_wood)
	for x in [-1.45, 1.45]:
		_add_box(root, "StonePier_%s" % ("W" if x < 0 else "E"), Vector3(0.28, 0.52, 1.66), Vector3(x, 0.02, 0), PALETTE.stone)
	_add_box_collision(root, Vector3(4.0, 0.24, 1.42), "BridgeDeckCollision", 0.38)
	return root


static func create_crops(preview: bool = false) -> Node3D:
	var imported := _instantiate_model(MODEL_PATHS.crops)
	if imported:
		imported.name = "CropRows"
		imported.set_meta("asset_type", "crops")
		if preview:
			apply_preview_tint(imported, true)
		return imported
	var root := Node3D.new()
	root.name = "CropRows"
	root.set_meta("asset_type", "crops")
	for row_index in range(3):
		var z := -0.48 + row_index * 0.48
		_add_box(root, "SoilRow_%02d" % row_index, Vector3(1.48, 0.10, 0.25), Vector3(0, 0.10, z), PALETTE.soil, preview)
		for plant_index in range(4):
			var x := -0.56 + plant_index * 0.38
			_add_cylinder(root, "Stem_%02d_%02d" % [row_index, plant_index], 0.018, 0.025, 0.34, Vector3(x, 0.31, z), PALETTE.crop, preview, 5, false, true)
			_add_cylinder(root, "Grain_%02d_%02d" % [row_index, plant_index], 0.045, 0.025, 0.14, Vector3(x, 0.52, z), PALETTE.grain, preview, 6, false, true)
	return root


static func create_citizen(index: int) -> Node3D:
	var imported := _instantiate_model(MODEL_PATHS.citizen)
	if imported:
		imported.name = "Citizen_%03d" % index
		imported.set_meta("asset_type", "citizen")
		imported.set_meta("palette_variant", posmod(index, 4))
		_apply_citizen_variant(imported, posmod(index, 4))
		return imported
	var root := Node3D.new()
	root.name = "Citizen_%03d" % index
	root.set_meta("asset_type", "citizen")
	root.set_meta("palette_variant", posmod(index, 4))
	var cloth_colors := [PALETTE.cloth_rust, PALETTE.cloth_blue, PALETTE.cloth_gold, PALETTE.cloth_green]
	var cloth: Color = cloth_colors[posmod(index, cloth_colors.size())]
	_add_cylinder(root, "Body", 0.15, 0.24, 0.58, Vector3(0, 0.47, 0), cloth, false, 7)
	_add_sphere(root, "Head", 0.17, Vector3(0, 0.91, 0), PALETTE.skin, false, Vector3.ONE, false)
	_add_cylinder(root, "HatBrim", 0.25, 0.25, 0.045, Vector3(0, 1.08, 0), PALETTE.thatch, false, 10, false, true)
	_add_cylinder(root, "HatCrown", 0.04, 0.17, 0.14, Vector3(0, 1.16, 0), PALETTE.thatch, false, 8, false, true)
	for side in [-1.0, 1.0]:
		var arm := _add_cylinder(root, "Arm_%s" % ("L" if side < 0 else "R"), 0.045, 0.055, 0.40, Vector3(side * 0.22, 0.52, 0), cloth, false, 6, false, true)
		arm.rotation_degrees.z = side * -12.0
	_add_box(root, "Feet", Vector3(0.32, 0.08, 0.22), Vector3(0, 0.13, 0.02), PALETTE.dark_wood, false, true)
	return root


static func _instantiate_model(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = _packed_scenes.get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene
		if packed == null:
			return null
		_packed_scenes[path] = packed
	var instance := packed.instantiate()
	return instance as Node3D


static func _add_box_collision(root: Node3D, size: Vector3, name: String, center_y: float = -1.0) -> void:
	if root.get_node_or_null(name):
		return
	var body := StaticBody3D.new()
	body.name = name
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5 if center_y < 0.0 else center_y
	body.add_child(collision)
	root.add_child(body)


static func _apply_citizen_variant(root: Node3D, variant: int) -> void:
	var cloth_colors := [PALETTE.cloth_rust, PALETTE.cloth_blue, PALETTE.cloth_gold, PALETTE.cloth_green]
	var cloth_material := _material(cloth_colors[variant])
	_apply_named_material(root, ["Body", "Arm_L", "Arm_R"], cloth_material)


static func _apply_named_material(node: Node, names: Array, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D and node.name in names:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_apply_named_material(child, names, material)


static func _build_house(root: Node3D, preview: bool) -> void:
	_add_box(root, "StonePlinth", Vector3(1.58, 0.18, 1.48), Vector3(0, 0.09, 0), PALETTE.stone, preview)
	_add_box(root, "PlasterWalls", Vector3(1.34, 0.82, 1.22), Vector3(0, 0.59, 0), PALETTE.warm_plaster, preview)
	_add_posts(root, 0.66, 0.60, 1.08, preview)
	_add_gabled_roof(root, "ThatchRoof", 1.68, 1.52, 1.10, PALETTE.thatch, preview)
	_add_box(root, "FrontDoor", Vector3(0.32, 0.56, 0.06), Vector3(0, 0.49, 0.64), PALETTE.dark_wood, preview, true)
	_add_window(root, "WindowLeft", Vector3(-0.42, 0.67, 0.64), preview)
	_add_window(root, "WindowRight", Vector3(0.42, 0.67, 0.64), preview)
	_add_cylinder(root, "Chimney", 0.075, 0.095, 0.42, Vector3(-0.50, 1.44, -0.20), PALETTE.brick, preview, 6, false, true)


static func _build_lumber(root: Node3D, preview: bool) -> void:
	_add_box(root, "PackedEarth", Vector3(1.72, 0.14, 1.55), Vector3(0, 0.07, 0), PALETTE.soil, preview)
	for x in [-0.68, 0.68]:
		for z in [-0.54, 0.54]:
			_add_cylinder(root, "ShedPost_%s_%s" % [str(x), str(z)], 0.06, 0.075, 1.24, Vector3(x, 0.70, z), PALETTE.dark_wood, preview, 6)
	_add_gabled_roof(root, "ShedRoof", 1.82, 1.58, 1.28, PALETTE.tile_light, preview)
	for log_index in range(4):
		var log := _add_cylinder(root, "Log_%02d" % log_index, 0.105, 0.105, 1.18, Vector3(-0.28 + (log_index % 2) * 0.24, 0.25 + floori(log_index / 2.0) * 0.18, -0.44), PALETTE.wood, preview, 7, false, true)
		log.rotation_degrees.z = 90
	_add_box(root, "CuttingBench", Vector3(0.86, 0.12, 0.38), Vector3(0.34, 0.52, 0.24), PALETTE.wood, preview, true)
	_add_cylinder(root, "SawBlade", 0.23, 0.23, 0.035, Vector3(0.34, 0.75, 0.25), PALETTE.stone_light, preview, 12, false, true).rotation_degrees.x = 90


static func _build_farm(root: Node3D, preview: bool) -> void:
	_add_box(root, "FieldEdge", Vector3(1.72, 0.12, 1.72), Vector3(0, 0.06, 0), PALETTE.thatch, preview)
	root.add_child(create_crops(preview))
	_add_cylinder(root, "ScarecrowPost", 0.03, 0.04, 0.92, Vector3(0.56, 0.55, -0.52), PALETTE.dark_wood, preview, 5, false, true)
	_add_box(root, "ScarecrowArms", Vector3(0.55, 0.045, 0.045), Vector3(0.56, 0.78, -0.52), PALETTE.dark_wood, preview, true)
	_add_cylinder(root, "ScarecrowHat", 0.04, 0.18, 0.14, Vector3(0.56, 1.07, -0.52), PALETTE.thatch, preview, 7, false, true)


static func _build_warehouse(root: Node3D, preview: bool) -> void:
	_add_box(root, "StonePlinth", Vector3(1.70, 0.28, 1.68), Vector3(0, 0.14, 0), PALETTE.stone, preview)
	_add_box(root, "WarehouseWalls", Vector3(1.48, 1.16, 1.40), Vector3(0, 0.83, 0), PALETTE.plaster, preview)
	_add_posts(root, 0.72, 0.67, 1.38, preview)
	_add_gabled_roof(root, "TileRoof", 1.82, 1.72, 1.50, PALETTE.tile, preview)
	_add_box(root, "DoubleDoor", Vector3(0.66, 0.76, 0.07), Vector3(0, 0.66, 0.73), PALETTE.dark_wood, preview, true)
	_add_box(root, "DoorSeam", Vector3(0.025, 0.72, 0.075), Vector3(0, 0.66, 0.77), PALETTE.thatch, preview, true)
	for crate_index in range(3):
		_add_box(root, "Crate_%02d" % crate_index, Vector3(0.30, 0.28, 0.30), Vector3(-0.46 + crate_index * 0.33, 0.30, -0.79), PALETTE.wood, preview, true)
	_add_box(root, "WarehouseSign", Vector3(0.48, 0.24, 0.06), Vector3(0, 1.38, 0.79), PALETTE.brick, preview, true)


static func _build_workshop(root: Node3D, preview: bool) -> void:
	_add_box(root, "StoneFloor", Vector3(1.70, 0.18, 1.60), Vector3(0, 0.09, 0), PALETTE.stone, preview)
	_add_box(root, "WorkshopWalls", Vector3(1.42, 1.02, 1.30), Vector3(0, 0.69, -0.05), PALETTE.brick, preview)
	_add_posts(root, 0.69, 0.62, 1.22, preview)
	_add_gabled_roof(root, "WorkshopRoof", 1.78, 1.62, 1.32, PALETTE.tile, preview)
	_add_box(root, "WorkshopDoor", Vector3(0.42, 0.68, 0.06), Vector3(-0.27, 0.57, 0.63), PALETTE.dark_wood, preview, true)
	_add_box(root, "Awning", Vector3(0.74, 0.08, 0.44), Vector3(0.34, 1.08, 0.79), PALETTE.thatch, preview, true).rotation_degrees.x = -12
	_add_cylinder(root, "Chimney", 0.11, 0.15, 0.88, Vector3(0.50, 1.64, -0.34), PALETTE.ink, preview, 7)
	_add_box(root, "AnvilBase", Vector3(0.22, 0.34, 0.22), Vector3(0.52, 0.32, 0.67), PALETTE.dark_wood, preview, true)
	_add_box(root, "Anvil", Vector3(0.42, 0.15, 0.20), Vector3(0.52, 0.55, 0.67), PALETTE.stone_light, preview, true)


static func _add_posts(root: Node3D, half_x: float, half_z: float, height: float, preview: bool) -> void:
	for x in [-half_x, half_x]:
		for z in [-half_z, half_z]:
			_add_box(root, "CornerPost_%s_%s" % [str(x), str(z)], Vector3(0.075, height, 0.075), Vector3(x, 0.24 + height * 0.5, z), PALETTE.dark_wood, preview, true)


static func _add_gabled_roof(root: Node3D, prefix: String, width: float, depth: float, ridge_y: float, color: Color, preview: bool) -> void:
	var half_depth := depth * 0.53
	for side in [-1.0, 1.0]:
		var roof := _add_box(root, "%s_%s" % [prefix, "Front" if side > 0 else "Back"], Vector3(width, 0.11, half_depth), Vector3(0, ridge_y, side * depth * 0.225), color, preview)
		roof.rotation_degrees.x = side * 27.0
	_add_cylinder(root, "%s_Ridge" % prefix, 0.055, 0.055, width * 1.04, Vector3(0, ridge_y + 0.20, 0), PALETTE.dark_wood, preview, 8, false, true).rotation_degrees.z = 90


static func _add_window(root: Node3D, name: String, position: Vector3, preview: bool) -> void:
	_add_box(root, name, Vector3(0.27, 0.26, 0.055), position, PALETTE.ink, preview, true)
	_add_box(root, "%s_CrossV" % name, Vector3(0.025, 0.24, 0.06), position + Vector3(0, 0, 0.006), PALETTE.thatch, preview, true)
	_add_box(root, "%s_CrossH" % name, Vector3(0.25, 0.025, 0.06), position + Vector3(0, 0, 0.006), PALETTE.thatch, preview, true)


static func _add_box(root: Node3D, name: String, size: Vector3, position: Vector3, color: Color, preview: bool = false, detail: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = _box_mesh(size)
	instance.material_override = _material(color, 0.50 if preview else 1.0, preview)
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if preview else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if detail:
		instance.visibility_range_end = 58.0
	root.add_child(instance)
	return instance


static func _add_cylinder(root: Node3D, name: String, top_radius: float, bottom_radius: float, height: float, position: Vector3, color: Color, preview: bool = false, sides: int = 8, emissive: bool = false, detail: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = _cylinder_mesh(top_radius, bottom_radius, height, sides)
	instance.material_override = _material(color, 0.50 if preview else 1.0, preview, emissive)
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if preview else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if detail:
		instance.visibility_range_end = 58.0
	root.add_child(instance)
	return instance


static func _add_sphere(root: Node3D, name: String, radius: float, position: Vector3, color: Color, preview: bool = false, scale_value: Vector3 = Vector3.ONE, detail: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = _sphere_mesh(radius)
	instance.material_override = _material(color, 0.50 if preview else 1.0, preview)
	instance.position = position
	instance.scale = scale_value
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if preview else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if detail:
		instance.visibility_range_end = 58.0
	root.add_child(instance)
	return instance


static func _material(color: Color, alpha: float = 1.0, unshaded: bool = false, emissive: bool = false) -> StandardMaterial3D:
	var key := "%s_%.2f_%s_%s" % [color.to_html(false), alpha, str(unshaded), str(emissive)]
	if _materials.has(key):
		return _materials[key]
	var value := StandardMaterial3D.new()
	value.albedo_color = Color(color.r, color.g, color.b, alpha)
	value.metallic = 0.0
	value.roughness = 0.86
	if alpha < 1.0:
		value.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		value.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emissive:
		value.emission_enabled = true
		value.emission = color.lightened(0.18)
		value.emission_energy_multiplier = 0.65
	_materials[key] = value
	return value


static func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if _boxes.has(key):
		return _boxes[key]
	var value := BoxMesh.new()
	value.size = size
	_boxes[key] = value
	return value


static func _cylinder_mesh(top_radius: float, bottom_radius: float, height: float, sides: int) -> CylinderMesh:
	var key := "%.3f_%.3f_%.3f_%d" % [top_radius, bottom_radius, height, sides]
	if _cylinders.has(key):
		return _cylinders[key]
	var value := CylinderMesh.new()
	value.top_radius = top_radius
	value.bottom_radius = bottom_radius
	value.height = height
	value.radial_segments = sides
	_cylinders[key] = value
	return value


static func _sphere_mesh(radius: float) -> SphereMesh:
	var key := "%.3f" % radius
	if _spheres.has(key):
		return _spheres[key]
	var value := SphereMesh.new()
	value.radius = radius
	value.height = radius * 2.0
	value.radial_segments = 8
	value.rings = 4
	_spheres[key] = value
	return value
