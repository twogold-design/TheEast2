extends SceneTree

## Asset-only fixture: Main is instantiated off-tree solely to create a citizen.
## _ready never runs, so the fixture never loads or saves player progress.
## Body/building proportions use actual visible meshes. Door metadata is checked
## against the opening from interior floor to lintel, excluding steps and trim.

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
	var citizen: Node3D = game.create_citizen(0, 0) if game else null
	if game:
		game.free()
	if house == null or citizen == null:
		fail("无法通过主场景加载真实民居或居民模型")
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
		fail("民居或居民模型没有可测量的可见网格")
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
		fail("居民/民居高度比例 %.3f 超出 %.2f–%.2f" % [citizen_to_house, MIN_CITIZEN_TO_HOUSE, MAX_CITIZEN_TO_HOUSE])
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

func infer_house_door_height(house: Node3D, _house_bounds: AABB) -> float:
	var declared := float(house.get_meta("door_clear_height", 0.0))
	var lintel := house.find_child("DoorLintel", true, false) as MeshInstance3D
	var floor_mesh := house.find_child("InteriorFloor", true, false) as MeshInstance3D
	if declared <= 0.0 or lintel == null or floor_mesh == null:
		fail("民居缺少可验证的门洞净高、门梁或室内地板")
		return 0.0
	var to_house := house.global_transform.affine_inverse()
	var lintel_bounds: AABB = (to_house * lintel.global_transform) * lintel.mesh.get_aabb()
	var floor_bounds: AABB = (to_house * floor_mesh.global_transform) * floor_mesh.mesh.get_aabb()
	var measured := lintel_bounds.position.y - floor_bounds.end.y
	if absf(declared - measured) > 0.005:
		fail("民居门洞净高声明 %.3fm 与实际开口 %.3fm 不符" % [declared, measured])
	return declared

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
