class_name JiangnanStyleAssets
extends RefCounted

## Fourth-generation Jiangnan courtyard building tier.
##
## The original realistic pack remains the fallback used by the gallery and
## by props.  The game-facing ink-wash layer uses coherent gable roofs, covered
## verandas and visible courtyard/work areas without changing the old contract.

const ArtKit = preload("res://godot/ArtAssets.gd")
const BASE_DIR := "res://godot/assets/jiangnan_style_v4/models"
const V3_DIR := "res://godot/assets/jiangnan_style_v3/models"
const V2_DIR := "res://godot/assets/jiangnan_style_v2/models"

const ASSETS := {
	"house": {"file": "building_house_open.glb", "bounds": Vector3(2.80, 2.75, 2.65)},
	"farm": {"file": "building_farm_open.glb", "bounds": Vector3(3.00, 2.75, 2.55)},
	"lumber": {"file": "building_lumber_open.glb", "bounds": Vector3(3.00, 2.78, 2.65)},
	"warehouse": {"file": "building_warehouse_open.glb", "bounds": Vector3(3.10, 2.90, 2.80)},
	"workshop": {"file": "building_workshop_open.glb", "bounds": Vector3(3.10, 2.82, 3.10)},
	"market": {"file": "building_market_open.glb", "bounds": Vector3(3.20, 2.82, 2.55)},
	"tea_pavilion": {"file": "building_tea_pavilion_open.glb", "bounds": Vector3(2.90, 2.72, 2.70)},
}

const V2_BOUNDS := {
	"house": Vector3(2.30, 2.20, 2.25),
	"farm": Vector3(2.50, 2.15, 2.15),
	"lumber": Vector3(2.55, 2.28, 2.25),
	"warehouse": Vector3(2.65, 2.55, 2.40),
	"workshop": Vector3(2.65, 2.45, 2.80),
	"market": Vector3(2.75, 2.35, 2.20),
	"tea_pavilion": Vector3(2.45, 2.35, 2.30),
}

static var _packed_scenes: Dictionary = {}

static func path_for(type: String) -> String:
	if not ASSETS.has(type):
		return ""
	return "%s/%s" % [BASE_DIR, ASSETS[type].file]

static func has_asset(type: String) -> bool:
	return not _candidate_paths(type).is_empty()

static func create_building(type: String, preview := false) -> Node3D:
	var candidates := _candidate_paths(type)
	if candidates.is_empty():
		return null
	var path: String = candidates[0]
	var version := 4 if path.begins_with(BASE_DIR) else (3 if path.begins_with(V3_DIR) else 2)
	var packed := _packed_scenes.get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene
		if packed == null:
			push_error("JiangnanStyleAssets: Godot could not import %s" % path)
			return null
		_packed_scenes[path] = packed
	var root := packed.instantiate() as Node3D
	if root == null:
		return null
	root.name = "JiangnanStyleV%d_%s" % [version, type.capitalize()]
	root.set_meta("asset_key", "building.%s" % type)
	root.set_meta("asset_source", "jiangnan_style_v%d" % version)
	root.set_meta("expected_path", path)
	root.set_meta("building_type", type)
	root.set_meta("art_style", "jiangnan_ink_wash")
	root.set_meta("art_style_version", version)
	root.set_meta("art_bounds", ASSETS[type].bounds if version >= 3 else V2_BOUNDS[type])
	root.set_meta("tile_meters", 2.0)
	_ensure_door(root)
	if not preview:
		_ensure_collision(root, ASSETS[type].bounds if version >= 3 else V2_BOUNDS[type])
	else:
		ArtKit.apply_preview_tint(root, true)
	return root

static func _candidate_paths(type: String) -> Array[String]:
	if not ASSETS.has(type):
		return []
	var paths: Array[String] = []
	var v4_path := path_for(type)
	if ResourceLoader.exists(v4_path):
		paths.append(v4_path)
	var legacy_v3_path := "%s/%s" % [V3_DIR, ASSETS[type].file]
	if ResourceLoader.exists(legacy_v3_path):
		paths.append(legacy_v3_path)
	var v2_path := "%s/%s" % [V2_DIR, ASSETS[type].file]
	if ResourceLoader.exists(v2_path):
		paths.append(v2_path)
	return paths

static func _ensure_door(root: Node3D) -> void:
	if root.find_child("Door", true, false):
		return
	var door := Marker3D.new()
	door.name = "Door"
	# All authored models use +Z as their entrance axis.
	door.position = Vector3(0, 0, 1.08)
	root.add_child(door)

static func _ensure_collision(root: Node3D, bounds: Vector3) -> void:
	if root.find_child("AssetCollision", true, false):
		return
	var body := StaticBody3D.new()
	body.name = "AssetCollision"
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	var shape := BoxShape3D.new()
	shape.size = bounds
	collision.shape = shape
	collision.position.y = bounds.y * 0.5
	body.add_child(collision)
	root.add_child(body)
