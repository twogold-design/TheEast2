class_name RealisticAssets
extends RefCounted

## Independent high-detail asset registry. The low-poly ArtAssets kit is used only
## as an explicit fallback and the returned root always records its source.

const ArtKit = preload("res://godot/ArtAssets.gd")
const BASE_DIR := "res://godot/assets/realistic/models"
const MANIFEST_PATH := BASE_DIR + "/realistic_manifest.json"

const ASSETS := {
	"building.house": {"file": "building_house.glb", "fallback": "house", "bounds": Vector3(1.70, 1.85, 1.65)},
	"building.lumber": {"file": "building_lumber.glb", "fallback": "lumber", "bounds": Vector3(1.82, 1.72, 1.72)},
	"building.farm": {"file": "building_farm.glb", "fallback": "farm", "bounds": Vector3(1.72, 1.28, 1.72)},
	"building.warehouse": {"file": "building_warehouse.glb", "fallback": "warehouse", "bounds": Vector3(1.82, 2.12, 1.82)},
	"building.workshop": {"file": "building_workshop.glb", "fallback": "workshop", "bounds": Vector3(1.78, 2.22, 1.72)},
	"prop.bridge": {"file": "prop_bridge.glb", "fallback": "bridge", "bounds": Vector3(4.0, 1.05, 1.42)},
	"prop.tree.01": {"file": "prop_tree_01.glb", "fallback": "tree", "variant": 0},
	"prop.tree.02": {"file": "prop_tree_02.glb", "fallback": "tree", "variant": 1},
	"prop.tree.03": {"file": "prop_tree_03.glb", "fallback": "tree", "variant": 2},
	"prop.rock.01": {"file": "prop_rock_01.glb", "fallback": "rock", "variant": 0},
	"prop.rock.02": {"file": "prop_rock_02.glb", "fallback": "rock", "variant": 1},
	"prop.rock.03": {"file": "prop_rock_03.glb", "fallback": "rock", "variant": 2},
	"prop.lantern": {"file": "prop_lantern.glb", "fallback": "lantern"},
	"prop.crops": {"file": "prop_crops.glb", "fallback": "crops"},
	"character.citizen": {"file": "character_citizen.glb", "fallback": "citizen", "variant": 0},
}

static var _packed_scenes: Dictionary = {}
static var _warned_missing: Dictionary = {}

static func expected_path(key: String) -> String:
	if not ASSETS.has(key):
		return ""
	return "%s/%s" % [BASE_DIR, ASSETS[key].file]

static func has_realistic_asset(key: String) -> bool:
	var path := expected_path(key)
	return not path.is_empty() and ResourceLoader.exists(path)

static func get_missing_keys() -> Array[String]:
	var missing: Array[String] = []
	for key in ASSETS.keys():
		if not has_realistic_asset(key):
			missing.append(key)
	missing.sort()
	return missing

static func get_status() -> Dictionary:
	var available: Array[String] = []
	var missing := get_missing_keys()
	for key in ASSETS.keys():
		if key not in missing:
			available.append(key)
	available.sort()
	return {
		"base_dir": BASE_DIR,
		"manifest_exists": FileAccess.file_exists(MANIFEST_PATH),
		"expected": ASSETS.size(),
		"available": available,
		"missing": missing,
	}

static func create_asset(key: String, preview := false, allow_fallback := true, variant := 0) -> Node3D:
	if not ASSETS.has(key):
		push_error("RealisticAssets: unknown asset key '%s'" % key)
		return null
	var path := expected_path(key)
	var imported := _instantiate(path)
	if imported:
		_configure_root(imported, key, "realistic", path, preview)
		return imported
	if not allow_fallback:
		push_error("RealisticAssets: required model is missing: %s (%s)" % [key, path])
		return null
	if not _warned_missing.has(key):
		push_warning("RealisticAssets: %s is missing at %s; using low-poly fallback." % [key, path])
		_warned_missing[key] = true
	var fallback := _create_fallback(key, preview, variant)
	if fallback:
		_configure_root(fallback, key, "fallback", path, preview)
	return fallback

static func create_building(type: String, preview := false, allow_fallback := true) -> Node3D:
	if type in ["market", "clinic", "academy"]:
		# Regional buildings are composed from the verified core kit and do not
		# pretend to be additional imported GLBs in the 15-item asset manifest.
		var base_type: String = {"market": "warehouse", "clinic": "house", "academy": "workshop"}[type]
		var composite := create_asset("building.%s" % base_type, preview, allow_fallback)
		if composite:
			composite.name = "Realistic_Building_%s" % type.capitalize()
			composite.set_meta("building_type", type)
			composite.set_meta("composite_base", base_type)
			_add_regional_identity(composite, type)
			if preview:
				apply_preview_tint(composite, true)
		return composite
	return create_asset("building.%s" % type, preview, allow_fallback)

static func create_tree(variant := 0, allow_fallback := true) -> Node3D:
	var normalized := posmod(variant, 3)
	return create_asset("prop.tree.%02d" % (normalized + 1), false, allow_fallback, normalized)

static func create_rock(variant := 0, allow_fallback := true) -> Node3D:
	var normalized := posmod(variant, 3)
	return create_asset("prop.rock.%02d" % (normalized + 1), false, allow_fallback, normalized)

static func create_bridge(allow_fallback := true) -> Node3D:
	return create_asset("prop.bridge", false, allow_fallback)

static func create_lantern(allow_fallback := true) -> Node3D:
	return create_asset("prop.lantern", false, allow_fallback)

static func create_crops(preview := false, allow_fallback := true) -> Node3D:
	return create_asset("prop.crops", preview, allow_fallback)

static func create_citizen(index := 0, allow_fallback := true) -> Node3D:
	var citizen := create_asset("character.citizen", false, allow_fallback, index)
	if citizen:
		citizen.name = "RealisticCitizen_%03d" % index
		citizen.set_meta("palette_variant", posmod(index, 4))
	return citizen

static func apply_preview_tint(root: Node3D, valid: bool) -> void:
	ArtKit.apply_preview_tint(root, valid)

static func read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

static func _instantiate(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var packed := _packed_scenes.get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene
		if packed == null:
			push_error("RealisticAssets: Godot could not import %s" % path)
			return null
		_packed_scenes[path] = packed
	return packed.instantiate() as Node3D

static func _create_fallback(key: String, preview: bool, variant: int) -> Node3D:
	var definition: Dictionary = ASSETS[key]
	match str(definition.fallback):
		"house", "lumber", "farm", "warehouse", "workshop":
			return ArtKit.create_building(str(definition.fallback), preview)
		"bridge":
			return ArtKit.create_bridge()
		"tree":
			return ArtKit.create_tree(int(definition.get("variant", variant)))
		"rock":
			return ArtKit.create_rock(int(definition.get("variant", variant)))
		"lantern":
			return ArtKit.create_lantern()
		"crops":
			return ArtKit.create_crops(preview)
		"citizen":
			return ArtKit.create_citizen(variant)
	return null

static func _add_regional_identity(root: Node3D, type: String) -> void:
	var identity := Node3D.new()
	identity.name = "RegionalIdentity_%s" % type.capitalize()
	root.add_child(identity)
	match type:
		"market":
			# A broad vermilion street canopy, hanging sign and roof pennants read as
			# commerce even at the normal high camera angle.
			_add_box(identity, "MarketCanopy", Vector3(1.72, 0.10, 0.52), Vector3(0.0, 0.78, 0.94), Color("b94f3f"))
			_add_box(identity, "MarketValance", Vector3(1.72, 0.32, 0.06), Vector3(0.0, 0.60, 1.18), Color("d6a74a"))
			_add_box(identity, "MarketCounter", Vector3(1.34, 0.38, 0.34), Vector3(0.0, 0.24, 0.92), Color("76513b"))
			_add_box(identity, "MarketRoofBanner", Vector3(0.66, 0.08, 0.28), Vector3(0.0, 1.92, 0.10), Color("c94f43"))
			_add_cylinder(identity, "MarketLanternLeft", 0.12, 0.28, Vector3(-0.66, 0.48, 1.20), Color("c85a3f"), 12)
			_add_cylinder(identity, "MarketLanternRight", 0.12, 0.28, Vector3(0.66, 0.48, 1.20), Color("c85a3f"), 12)
		"clinic":
			# The turquoise herb awning and oversized wooden medicine gourd create a
			# different roof silhouette without covering the readable front facade.
			_add_box(identity, "ClinicHerbAwning", Vector3(1.38, 0.10, 0.44), Vector3(0.0, 0.76, 0.95), Color("6f9982"))
			_add_box(identity, "ClinicMedicineCabinet", Vector3(0.48, 0.70, 0.24), Vector3(-0.58, 0.36, 0.94), Color("806044"))
			_add_cylinder(identity, "ClinicGourdLower", 0.18, 0.34, Vector3(0.42, 1.76, 0.16), Color("b6a064"), 14)
			_add_cylinder(identity, "ClinicGourdUpper", 0.12, 0.24, Vector3(0.42, 2.00, 0.16), Color("c5b274"), 14)
			_add_box(identity, "ClinicHerbSign", Vector3(0.50, 0.54, 0.08), Vector3(0.54, 0.90, 0.98), Color("496c5e"))
		"academy":
			# A blue scroll board across the ridge plus paired courtyard writing
			# desks makes the academy distinct from the workshop shell.
			_add_box(identity, "AcademyRoofScroll", Vector3(1.20, 0.12, 0.32), Vector3(0.0, 2.08, 0.04), Color("496b7a"))
			_add_box(identity, "AcademyGoldRidge", Vector3(1.48, 0.08, 0.10), Vector3(0.0, 2.20, 0.04), Color("c49a51"))
			_add_box(identity, "AcademyDeskLeft", Vector3(0.54, 0.12, 0.34), Vector3(-0.42, 0.34, 1.02), Color("725039"))
			_add_box(identity, "AcademyDeskRight", Vector3(0.54, 0.12, 0.34), Vector3(0.42, 0.34, 1.02), Color("725039"))
			_add_box(identity, "AcademyGateBoard", Vector3(0.92, 0.34, 0.09), Vector3(0.0, 1.08, 1.00), Color("3f6473"))

static func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _identity_material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)

static func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, color: Color, sides: int) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _identity_material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)

static func _identity_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material

static func _configure_root(root: Node3D, key: String, source: String, expected: String, preview: bool) -> void:
	root.name = "Realistic_%s" % key.replace(".", "_").capitalize()
	root.set_meta("asset_key", key)
	root.set_meta("asset_source", source)
	root.set_meta("expected_path", expected)
	root.set_meta("tile_meters", 2.0)
	if key.begins_with("building."):
		var type := key.trim_prefix("building.")
		root.set_meta("building_type", type)
		root.set_meta("art_bounds", ASSETS[key].bounds)
		_ensure_door(root)
		if not preview:
			_ensure_collision(root, ASSETS[key].bounds, "AssetCollision")
	elif key == "prop.bridge":
		_ensure_collision(root, Vector3(4.0, 0.24, 1.42), "BridgeDeckCollision", 0.38)
	if preview:
		apply_preview_tint(root, true)

static func _ensure_door(root: Node3D) -> void:
	if root.find_child("Door", true, false):
		return
	var door := Marker3D.new()
	door.name = "Door"
	door.position = Vector3(0, 0, 0.92)
	root.add_child(door)

static func _ensure_collision(root: Node3D, bounds: Vector3, collision_name: String, center_y := -1.0) -> void:
	if root.find_child(collision_name, true, false):
		return
	var body := StaticBody3D.new()
	body.name = collision_name
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	var shape := BoxShape3D.new()
	shape.size = bounds
	collision.shape = shape
	collision.position.y = bounds.y * 0.5 if center_y < 0.0 else center_y
	body.add_child(collision)
	root.add_child(body)

