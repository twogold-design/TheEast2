extends SceneTree

## Verifies the visible resident scale against the actual imported house mesh.
## The ratios intentionally use mesh bounds instead of registry metadata so a
## re-exported GLB cannot silently invalidate the scale contract.

const RealisticKit = preload("res://godot/RealisticAssets.gd")
const MIN_CITIZEN_TO_HOUSE := 0.42
const MAX_CITIZEN_TO_HOUSE := 0.62
const MIN_DOOR_TO_CITIZEN := 0.92
const MAX_DOOR_TO_CITIZEN := 1.16

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var house := RealisticKit.create_building("house", false, false)
	var packed := load("res://godot/Main.tscn") as PackedScene
	var game = packed.instantiate() if packed else null
	var citizen: Node3D = game.create_citizen(0) if game else null
	if game:
		game.free()
	if house == null or citizen == null:
		fail("无法通过主场景加载真实茅舍或居民模型")
		finish()
		return
	# Measure the same carrier/Visual hierarchy used by the running game.  The
	# raw realistic GLB is deliberately not measured here because Main owns the
	# presentation scale contract.
	citizen.position = Vector3.ZERO
	root.add_child(house)
	root.add_child(citizen)
	await process_frame
	var house_bounds := visible_bounds(house)
	var citizen_bounds := visible_bounds(citizen)
	if house_bounds.size.y <= 0.0 or citizen_bounds.size.y <= 0.0:
		fail("茅舍或居民模型没有可测量的可见网格")
		finish()
		return
	var door_height := infer_house_door_height(house, house_bounds)
	var citizen_to_house := citizen_bounds.size.y / house_bounds.size.y
	var door_to_citizen := door_height / citizen_bounds.size.y
	print("NPC_SCALE_METRICS: citizen=%.3fm house=%.3fm door=%.3fm citizen/house=%.3f door/citizen=%.3f" % [
		citizen_bounds.size.y,
		house_bounds.size.y,
		door_height,
		citizen_to_house,
		door_to_citizen,
	])
	if citizen_to_house < MIN_CITIZEN_TO_HOUSE or citizen_to_house > MAX_CITIZEN_TO_HOUSE:
		fail("居民/茅舍高度比例 %.3f 超出 %.2f–%.2f" % [citizen_to_house, MIN_CITIZEN_TO_HOUSE, MAX_CITIZEN_TO_HOUSE])
	if door_to_citizen < MIN_DOOR_TO_CITIZEN or door_to_citizen > MAX_DOOR_TO_CITIZEN:
		fail("门/居民高度比例 %.3f 超出 %.2f–%.2f" % [door_to_citizen, MIN_DOOR_TO_CITIZEN, MAX_DOOR_TO_CITIZEN])
	finish()

func visible_bounds(subject: Node3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	for child in subject.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var local_bounds := mesh_instance.mesh.get_aabb()
		var relative_transform := subject.global_transform.affine_inverse() * mesh_instance.global_transform
		var transformed := relative_transform * local_bounds
		result = transformed if not has_bounds else result.merge(transformed)
		has_bounds = true
	return result

func infer_house_door_height(house: Node3D, house_bounds: AABB) -> float:
	# Imported models currently expose the entrance as a position marker only.
	# Door lintel meshes have stable names in the realistic asset; if a future
	# export renames them, use the documented 58% wall/roof split as a fallback.
	var door_bounds := AABB()
	var has_door_mesh := false
	for child in house.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var normalized := mesh_instance.name.to_lower()
		if "door" not in normalized and "entrance" not in normalized:
			continue
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var relative_transform := house.global_transform.affine_inverse() * mesh_instance.global_transform
		var transformed := relative_transform * mesh_instance.mesh.get_aabb()
		door_bounds = transformed if not has_door_mesh else door_bounds.merge(transformed)
		has_door_mesh = true
	if has_door_mesh and door_bounds.size.y > 0.30:
		return door_bounds.size.y
	return house_bounds.size.y * 0.58

func fail(message: String) -> void:
	failures.append(message)
	push_error("NPC_SCALE_ACCEPTANCE_FAILED: " + message)

func finish() -> void:
	if failures.is_empty():
		print("NPC_SCALE_ACCEPTANCE_OK: resident height reads naturally beside the house and entrance")
		quit(0)
	else:
		print("NPC_SCALE_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
