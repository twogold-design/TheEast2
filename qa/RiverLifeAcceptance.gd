extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	func save_path() -> String:
		return "res://.godot-user/qa/river-life-never-written.json"
	func save_game(_show_feedback := true) -> void:
		pass
	func load_game(_show_feedback := true) -> void:
		pass

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition and not failures.has(description):
		failures.append(description)
		push_error("RIVER_LIFE_FAILED: " + description)

func run() -> void:
	var game := IsolatedGame.new()
	root.add_child(game)
	game.time_paused = true
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var lines := game.world.get_node("LandGridLines") as MeshInstance3D
	var vertices: PackedVector3Array = lines.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(vertices.size() > 100, "land retains its construction grid")
	for i in range(0, vertices.size(), 2):
		var midpoint := (vertices[i] + vertices[i + 1]) * 0.5
		var across := Vector3(0.02, 0, 0) if is_equal_approx(vertices[i].x, vertices[i + 1].x) else Vector3(0, 0, 0.02)
		check(not game.is_water_cell(game.world_to_grid(midpoint + across)) and not game.is_water_cell(game.world_to_grid(midpoint - across)), "all grid segments exclude water")
	var river := game.world.get_node("RiverLife")
	for label in ["MainRiverSurface", "EastRiverSurface"]:
		var surface := river.get_node(label) as MeshInstance3D
		check(surface.mesh is PlaneMesh and surface.mesh.get_surface_count() == 1, "continuous river planes without tile seams")
		var material := surface.get_active_material(0) as ShaderMaterial
		check(material != null and material.shader != null, "animated water material is assigned")
		check(is_equal_approx(surface.mesh.size.x, game.TILE_SIZE * 2.0), "water matches the full channel width")
	var boats := river.find_children("RiverBoat_*", "Node3D", false, false)
	check(boats.size() == 3, "river traffic stays sparse")
	for boat in boats:
		boat.set_process(false)
		var period: float = boat.route_length / boat.speed
		boat.sample(0.0)
		var start: Vector3 = boat.position
		var last: Vector3 = boat.position
		var last_direction: Vector3 = boat.basis.z
		var step := 0.1
		for frame in range(1, ceili(period / step) + 1):
			boat.sample(frame * step)
			var travel: float = boat.position.distance_to(last) / step
			check(absf(travel - boat.speed) < 0.002, "boats keep steady speed through turns")
			check(boat.basis.z.angle_to(last_direction) < 0.07, "boats turn smoothly without snapping")
			check(game.is_water_cell(game.world_to_grid(boat.position)), "boat centres stay in the river")
			# Conservative envelope including oars, rotated with the vessel.
			for x in [-0.75, 0.75]:
				for z in [-0.94, 0.94]:
					var corner: Vector3 = boat.position + boat.basis * Vector3(x, 0, z)
					check(absf(corner.x - boat.route_center.x) < game.TILE_SIZE, "hull and oars stay clear of both banks")
			for bridge in [game.world.get_node("RiverBridge"), game.world.get_node("EastBranchBridge")]:
				if absf(boat.position.x - bridge.position.x) < 3.0:
					check(absf(boat.position.z - bridge.position.z) > 2.4, "routes leave clearance from bridge decks")
			last = boat.position
			last_direction = boat.basis.z
		boat.sample(period)
		check(boat.position.distance_to(start) < 0.0001, "closed boat routes join continuously")
		boat.sample(0.0)
		var oar_angle: Vector3 = boat.oars[0].rotation
		boat.sample(0.7)
		check(boat.oars[0].rotation.distance_to(oar_angle) > 0.05, "oars visibly row")
	# Region fog must not reintroduce square overlays on water.
	for fog in game.region_visual_root.find_children("FogTiles", "MultiMeshInstance3D", true, false):
		for i in range(fog.multimesh.instance_count):
			var location: Vector3 = fog.multimesh.get_instance_transform(i).origin
			check(not game.is_water_cell(game.world_to_grid(location)), "locked regions leave water continuous")
	game.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("RIVER_LIFE_ACCEPTANCE_OK: land-only grid, continuous water, three steady boats, bridge/bank clearance, rowing, no save access")
	quit(0 if failures.is_empty() else 1)
