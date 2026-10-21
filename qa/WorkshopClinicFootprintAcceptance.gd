extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	var fixture_io := false
	func save_path() -> String:
		return "res://.godot-user/qa/workshop-clinic-footprint-fixture.json"
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/workshop-clinic-footprint-audio.cfg"
	func save_game(show_feedback := true) -> void:
		if fixture_io:
			super.save_game(show_feedback)
	func load_game(show_feedback := true) -> void:
		if fixture_io:
			super.load_game(show_feedback)

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("WORKSHOP_CLINIC_FOOTPRINT_FAILED: " + message)

func run() -> void:
	root.size = Vector2i(1366, 768)
	var game := IsolatedGame.new()
	root.add_child(game)
	game.background_music.player.stop()
	game.background_music.player.stream = null
	game.set_process(false)
	game.set_physics_process(false)
	game.time_paused = true
	var data := {"version": 4, "day": 1, "wood": 100, "food": 40, "coins": 300, "population": 4, "happiness": 60, "low_happiness_days": 0, "stable_days": 0, "maintenance_debt": 0, "next_id": 5, "map_region_level": 3, "buildings": [
		{"id": 1, "type": "workshop", "x": 6, "z": 6, "enabled": true},
		{"id": 2, "type": "house", "x": 7, "z": 6, "enabled": true},
		{"id": 3, "type": "clinic", "x": 12, "z": 6, "enabled": true},
		{"id": 4, "type": "house", "x": 13, "z": 6, "enabled": true}
	], "roads": [{"x": 6, "z": 7}, {"x": 12, "z": 7}]}
	for version in [2, 3, 4]:
		data.version = version
		check(game.validate_save_data(data) == "", "v%d old one-cell workshop/clinic remain valid beside neighbors" % version)
	data.version = 4
	for type in ["workshop", "clinic"]:
		var index := 0 if type == "workshop" else 2
		for invalid_size in [0, 3, 1.5, "2", true, null]:
			var invalid: Dictionary = data.duplicate(true)
			invalid.buildings[index][type + "_footprint"] = invalid_size
			check(game.validate_save_data(invalid) != "", "invalid %s size rejected" % type)
		var enlargement: Dictionary = data.duplicate(true)
		enlargement.buildings[index][type + "_footprint"] = 2
		check(game.validate_save_data(enlargement) != "", "implicit enlargement into old neighbors forbidden")
	DirAccess.make_dir_recursive_absolute(game.save_path().get_base_dir())
	var fixture := FileAccess.open(game.save_path(), FileAccess.WRITE)
	fixture.store_string(JSON.stringify(data))
	fixture.close()
	game.fixture_io = true
	game.load_game(false)
	game.fixture_io = false
	for index in [0, 2]:
		var old_record: Dictionary = game.buildings[index]
		check(game.record_footprint(old_record) == Vector2i.ONE, "old footprint stays one cell")
		check(old_record.node.scale == Vector3.ONE, "old compact model and actor not scaled")
		check(game.building_boundary_cells(old_record).size() == 4, "old four-edge road boundary remains compact")
	check(game.occupied.get(Vector2i(7, 6), -1) == 2 and game.occupied.get(Vector2i(13, 6), -1) == 4, "old neighboring houses untouched")
	check(game.roads.has(Vector2i(6, 7)) and game.roads.has(Vector2i(12, 7)), "old neighboring roads untouched")
	for type in ["workshop", "clinic"]:
		var anchor := Vector2i(6, 12) if type == "workshop" else Vector2i(12, 12)
		check(game.can_place(type, anchor) == "", "%s fits clear four-cell lot" % type)
		game.add_road(anchor + Vector2i.ONE, true)
		check(game.can_place(type, anchor) != "", "far-corner road blocks new footprint")
		game.remove_road(anchor + Vector2i.ONE, false)
		game.add_building(type, anchor, true, -1, true, Vector2i.ZERO, 1)
		var record: Dictionary = game.buildings[-1]
		check(game.record_base_footprint(record) == Vector2i(2, 2) and game.record_footprint(record) == Vector2i(2, 2), "new building reserves four cells even when rotated")
		check(record.node.scale == Vector3.ONE, "new model and actors use authored scale")
		check(is_equal_approx(record.node.rotation.y, PI * 0.5), "new model rotates 90 degrees")
		check(record.node.position.is_equal_approx(game.building_model_position(type, anchor)), "new model centered across four cells")
		for cell in game.building_footprint_cells(type, anchor):
			check(game.occupied.get(cell, -1) == record.id, "all four cells address same building")
			game.handle_world_click(game.camera.unproject_position(game.grid_to_world(cell)))
			check(game.selected_building_id == record.id, "click all four cells selects building")
		check(game.building_boundary_cells(record).size() == 8, "four-cell building exposes eight road neighbors")
		game.select_building(type)
		game.update_ghost(anchor + Vector2i(0, 3))
		check(game.ghost.position.is_equal_approx(game.building_model_position(type, anchor + Vector2i(0, 3))), "preview spans same four cells")
		game.cancel_building()
		check(game.building_tooltip_text(type).contains("2×2"), "tooltip reports expanded footprint")
	game.add_road(Vector2i(8, 13), true)
	game.add_road(Vector2i(9, 13), true)
	check(game.building_has_connected_road(game.buildings[4]), "workshop connects at far east side")
	game.fixture_io = true
	game.save_game(false)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path()))
	check(saved.buildings[0].workshop_footprint == 1 and saved.buildings[2].clinic_footprint == 1, "compact sizes saved explicitly")
	check(saved.buildings[4].workshop_footprint == 2 and saved.buildings[5].clinic_footprint == 2, "new sizes saved explicitly")
	check(game.validate_save_data(saved) == "", "mixed expanded and old compact save validates")
	game.load_game(false)
	game.fixture_io = false
	check(game.record_footprint(game.buildings[0]) == Vector2i.ONE and game.record_footprint(game.buildings[2]) == Vector2i.ONE, "old lots survive save roundtrip")
	for index in [4, 5]:
		var record: Dictionary = game.buildings[index]
		check(game.record_footprint(record) == Vector2i(2, 2) and int(record.rotation_quarters) == 1, "new rotated size survives roundtrip")
	for index in [5, 4]:
		var record: Dictionary = game.buildings[index]
		var cells: Array[Vector2i] = game.building_footprint_cells(str(record.type), record.cell)
		game.remove_building_by_id(int(record.id), false)
		for cell in cells:
			check(not game.occupied.has(cell), "demolition frees all four cells")
	check(game.occupied.get(Vector2i(7, 6), -1) == 2 and game.roads.has(Vector2i(6, 7)), "expanded building demolition preserves legacy neighbors")
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.4, true, false, true).timeout
	if failures.is_empty():
		print("WORKSHOP_CLINIC_FOOTPRINT_OK: new four-cell placement/selection/preview/road/rotation/demolition, legacy compact models unchanged, isolated mixed save roundtrip")
		quit(0)
	else:
		quit(1)
