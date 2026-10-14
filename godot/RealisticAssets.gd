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

