extends SceneTree

class IsolatedGame:
	extends "res://godot/Main.gd"
	func _ready() -> void:
		pass
	func save_game(_feedback := true) -> void:
		push_error("MOUNTAIN_TEST_MUST_NOT_SAVE")
	func load_game(_feedback := true) -> void:
		push_error("MOUNTAIN_TEST_MUST_NOT_LOAD")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := IsolatedGame.new()
	root.add_child(game)
	game.create_world()
	game.set_process(false)
	game.set_physics_process(false)
	var mountains: Array[Node] = game.world.find_children("BoundaryHill_*", "MeshInstance3D", false, false)
	mountains.append_array(game.world.get_node("OuterNaturalBuffer").find_children("NaturalRidge_*", "MeshInstance3D", false, false))
	if mountains.size() < 45:
		failures.append("Missing mountain belts")
	var foot_samples := 0
	var shape_families := {}
	for mountain in mountains:
		if mountain.mesh == null or mountain.get_active_material(0) == null:
			failures.append("Missing mesh/material: " + mountain.name)
			continue
		if int(mountain.get_meta("triangle_count", 0)) < 4000:
			failures.append("Low polygon mountain: " + mountain.name)
		var data: Array = mountain.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
		shape_families[int(mountain.get_meta("shape_family", -1))] = true
		var start: int = mountain.get_meta("foot_ring_start")
		var count: int = mountain.get_meta("foot_ring_count")
		var highest := points[0]
		for point_index in range(start):
			if points[point_index].y > highest.y:
				highest = points[point_index]
		if Vector2(highest.x, highest.z).length() < 0.45:
			failures.append("Mountain remains a centered cone: " + mountain.name)
		for i in range(start, start + count):
			var point: Vector3 = mountain.global_transform * points[i]
			var ground: float = game.mountain_ground_height(point.x, point.z)
			if absf(ground - point.y - 0.24) > 0.002:
				failures.append("Floating foot: %s vertex %d" % [mountain.name, i])
			var river_grid := Vector2(point.x / game.TILE_SIZE + game.GRID_SIZE * 0.5 - 0.5, point.z / game.TILE_SIZE + game.GRID_SIZE * 0.5 - 0.5)
			if game.is_outer_river_corridor(river_grid, 0.0):
				failures.append("Mountain footprint overlaps river: " + mountain.name)
			foot_samples += 1
		for i in range(0, start + count):
			if normals[i].y <= 0.0 or not normals[i].is_normalized():
				failures.append("Invalid smooth top normal: " + mountain.name)
		var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
		for i in range(0, indices.size() - count * 3, 3):
			var a := points[indices[i]]
			var b := points[indices[i + 1]]
			var c := points[indices[i + 2]]
			if -(b - a).cross(c - a).y <= 0.0:
				failures.append("Wrong top winding: " + mountain.name)
	if shape_families.size() < 3:
		failures.append("Missing distinct mountain shape families")
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	if failures.is_empty():
		print("MOUNTAIN_DETAIL_ACCEPTANCE_OK: %d smooth solid mountains, %d buried footprint samples, river clearance, normals/winding/materials; no save access" % [mountains.size(), foot_samples])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
