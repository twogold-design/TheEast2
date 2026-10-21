extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	func save_game(_show_feedback := true) -> void:
		pass
	func load_game(_show_feedback := true) -> void:
		pass
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/animal-building-audio.cfg"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ANIMAL_BUILDING_AVOIDANCE_FAILED: " + message)

func run() -> void:
	var game := IsolatedGame.new()
	root.add_child(game)
	game.background_music.player.stop()
	game.background_music.player.stream = null
	game.set_process(false)
	game.set_physics_process(false)
	game.time_paused = true
	game.map_region_level = 1
	var animal := game.animal_root.get_child(0) as Node3D
	var identity: String = animal.get_meta("animal_species")
	for rotation in [0, 1]:
		animal.position = game.grid_to_world(Vector2i(7, 13)) + Vector3(0.4, 0.18, 0.2)
		game.refresh_animal_routes()
		var distance_before: float = animal.get_meta("animal_distance", 0.0)
		game.add_building("fishpond", Vector2i(6, 12), true, -1, true, Vector2i.ZERO, rotation)
		check(game.animal_cell_available(game.world_to_grid(animal.position)), "animal covered by pond relocated onto nearest clear ground")
		check(float(animal.get_meta("animal_distance")) == distance_before, "construction correction not counted as accelerated walking")
		check(str(animal.get_meta("animal_species")) == identity, "same animal preserved through construction")
		for creature in game.animal_root.get_children():
			for point in creature.get_meta("animal_route", []):
				check(not game.occupied.has(game.world_to_grid(point)), "new route targets avoid entire pond footprint")
			for point in creature.get_meta("animal_navigation_path", []):
				check(not game.occupied.has(game.world_to_grid(point)), "new navigation excludes all occupied cells")
		var bad_position := false
		var accelerated := false
		var total_traveled := 0.0
		for frame in range(600):
			game.move_animals(game.ANIMAL_PHYSICS_STEP)
			for creature in game.animal_root.get_children():
				if game.occupied.has(game.world_to_grid(creature.position)):
					bad_position = true
				var travel := float(creature.get_meta("animal_last_travel_distance", 0.0))
				if travel > game.ANIMAL_MOVE_SPEED * game.ANIMAL_PHYSICS_STEP + 0.00001:
					accelerated = true
				total_traveled += travel
		check(not bad_position, "600 ticks avoid new pond and other buildings")
		check(not accelerated and total_traveled > 1.0, "animals keep walking within constant speed budget")
		game.remove_building_by_id(int(game.buildings[-1].id), false)
		check(game.animal_cell_available(Vector2i(7, 13)), "demolition returns pond cells to walkable ground")
	# A refresh halfway along an edge must return to the current clear centre
	# before changing direction, avoiding a diagonal cut through a nearby corner.
	animal.position = game.grid_to_world(Vector2i(7, 12)) + Vector3(0.7, 0.18, 0)
	game.refresh_animal_routes()
	var path: Array = animal.get_meta("animal_navigation_path")
	check(not path.is_empty() and path[0].is_equal_approx(game.grid_to_world(Vector2i(7, 12)) + Vector3(0, 0.18, 0)), "mid-edge refresh starts through clear current tile center")
	# The southern scattered tree is outside the reserved-forest rectangle.
	# Before this fix, a new clinic covering (16,25) moved the nearby animal
	# into (16,26), because it was the closest supposedly clear cell.
	game.map_region_level = 3
	game.wood = 100
	game.coins = 100
	var scattered_tree := Vector2i(16, 26)
	check(game.has_scenery_tree(scattered_tree) and not game.is_reserved_forest(scattered_tree), "fixture uses a real scattered tree outside forest zoning")
	check(not game.animal_cell_available(scattered_tree), "scattered tree cannot be used for animal spawn or relocation")
	game.add_road(scattered_tree, true, true)
	check(game.animal_cell_available(scattered_tree), "historically cleared scattered tree road remains available")
	game.remove_road(scattered_tree, false)
	check(not game.animal_cell_available(scattered_tree), "removing historical road restores tree obstacle")
	var sparse_lot_reason: String = game.can_place("clinic", Vector2i(15, 26))
	check("树木" in sparse_lot_reason, "new building placement cannot overlap scattered trees")
	animal.position = game.grid_to_world(Vector2i(16, 25)) + Vector3(0, 0.18, 0.9)
	var previous_distance: float = animal.get_meta("animal_distance", 0.0)
	check(game.can_place("clinic", Vector2i(15, 24)) == "", "2x2 clinic construction fixture is valid")
	game.add_building("clinic", Vector2i(15, 24), true)
	check(game.world_to_grid(animal.position) != scattered_tree and game.animal_cell_available(game.world_to_grid(animal.position)), "clinic construction relocates animal onto ground clear of scattered tree")
	check(float(animal.get_meta("animal_distance", 0.0)) == previous_distance, "tree-safe construction correction adds no gait distance")
	var entered_tree := false
	var entered_building := false
	for frame in range(600):
		game.move_animals(game.ANIMAL_PHYSICS_STEP)
		for creature in game.animal_root.get_children():
			var cell: Vector2i = game.world_to_grid(creature.position)
			entered_tree = entered_tree or game.has_scenery_tree(cell)
			entered_building = entered_building or game.occupied.has(cell)
	check(not entered_tree and not entered_building, "600 post-clinic movement ticks avoid trees and occupied building cells")
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.4, true, false, true).timeout
	if failures.is_empty():
		print("ANIMAL_BUILDING_AVOIDANCE_OK: construction overlap cleared, 1800 movement ticks avoid pond/clinic/trees, legacy cleared-tree exception, unchanged speed and gait distance, mid-edge reroute safe")
		quit(0)
	else:
		quit(1)
