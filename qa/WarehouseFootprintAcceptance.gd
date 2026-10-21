extends SceneTree

# Only this disposable fixture may be read or written, including startup/shutdown.
class IsolatedGame extends "res://godot/Main.gd":
	var fixture_io := false
	func save_path() -> String:
		return "res://.godot-user/qa/warehouse-footprint-fixture.json"
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/warehouse-footprint-audio.cfg"
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
		push_error("WAREHOUSE_FOOTPRINT_FAILED: " + message)

func run() -> void:
	root.size = Vector2i(1366, 768)
	var game := IsolatedGame.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.time_paused = true
	var data := {"version": 4, "day": 1, "wood": 100, "food": 40, "coins": 300, "population": 4, "happiness": 60, "low_happiness_days": 0, "stable_days": 0, "maintenance_debt": 0, "next_id": 3, "map_region_level": 1, "buildings": [{"id": 1, "type": "warehouse", "x": 6, "z": 6, "enabled": true}, {"id": 2, "type": "house", "x": 7, "z": 6, "enabled": true}], "roads": [{"x": 6, "z": 7}]}
	check(game.validate_save_data(data) == "", "legacy warehouse beside house and road validates")
	for version in [1, 2, 3, 4]:
		var older: Dictionary = data.duplicate(true)
		older.version = version
		check(game.validate_save_data(older) == "", "legacy version %d keeps one-cell warehouse" % version)
	for invalid_size in [0, 3, 1.5, "2", true, null]:
		var invalid: Dictionary = data.duplicate(true)
		invalid.buildings[0].warehouse_footprint = invalid_size
		check(game.validate_save_data(invalid) != "", "invalid footprint rejected: %s" % str(invalid_size))
	var enlarged: Dictionary = data.duplicate(true)
	enlarged.buildings[0].warehouse_footprint = 2
	check(game.validate_save_data(enlarged) != "", "expansion into old neighbor is rejected")
	DirAccess.make_dir_recursive_absolute(game.save_path().get_base_dir())
	var fixture := FileAccess.open(game.save_path(), FileAccess.WRITE)
	fixture.store_string(JSON.stringify(data))
	fixture.close()
	game.fixture_io = true
	game.load_game(false)
	game.time_paused = true
	var legacy: Dictionary = game.buildings[0]
	check(game.record_footprint(legacy) == Vector2i.ONE, "legacy warehouse footprint remains one cell")
	check(legacy.node.position.is_equal_approx(game.grid_to_world(Vector2i(6, 6))), "legacy warehouse stays at original center")
	check(legacy.node.scale.is_equal_approx(Vector3(0.5, 0.75, 0.5)), "legacy warehouse art is compact")
	check(game.occupied.get(Vector2i(7, 6), -1) == 2 and game.roads.has(Vector2i(6, 7)), "legacy neighboring property survives load")
	check(game.building_boundary_cells(legacy).size() == 4, "legacy road boundary remains single cell")
	check(game.can_place("warehouse", Vector2i(6, 12)) == "", "clear new 2x2 warehouse is placeable")
	check(game.can_place("warehouse", Vector2i(19, 6)) != "", "locked non-anchor cell blocks placement")
	check(game.can_place("warehouse", Vector2i(1, 6)) != "", "river in non-anchor column blocks placement")
	check(game.can_place("warehouse", Vector2i(9, 6)) != "", "trunk road in non-anchor column blocks placement")
	game.add_road(Vector2i(7, 13), true)
	check(game.can_place("warehouse", Vector2i(6, 12)) != "", "road in far corner blocks placement")
	game.remove_road(Vector2i(7, 13), false)
	game.add_building("warehouse", Vector2i(6, 12), true)
	var warehouse: Dictionary = game.buildings[-1]
	check(game.record_footprint(warehouse) == Vector2i(2, 2), "new warehouse has four-cell footprint")
	check(warehouse.node.scale == Vector3.ONE, "new warehouse art uses full scale")
	check(warehouse.node.position.is_equal_approx(game.grid_to_world(Vector2i(6, 12)) + Vector3(1.1, 0, 1.1)), "new warehouse centered over four cells")
	check(game.building_boundary_cells(warehouse).size() == 8, "new warehouse uses eight boundary neighbors")
	for cell in game.building_footprint_cells("warehouse", warehouse.cell):
		check(game.occupied.get(cell, -1) == warehouse.id, "all four cells select same warehouse")
		game.cancel_building()
		game.handle_world_click(game.camera.unproject_position(game.grid_to_world(cell)))
		check(game.selected_building_id == warehouse.id, "click any footprint cell selects warehouse")
		check(game.can_place_road(cell) != "", "road cannot overlap warehouse")
	game.add_road(Vector2i(8, 13), true)
	game.add_road(Vector2i(9, 13), true)
	check(Vector2i(8, 13) in game.building_boundary_cells(warehouse) and game.is_road_connected(Vector2i(8, 13)), "connected road reaches extended east edge")
	check(game.building_has_connected_road(warehouse), "connected extended boundary enables storage")
	check(game.road_bonus_for_building(warehouse) == 0, "warehouse still has no production transport bonus")
	game.selected_type = "warehouse"
	game.update_ghost(Vector2i(6, 15))
	check(game.ghost.position.is_equal_approx(game.building_model_position("warehouse", Vector2i(6, 15))), "warehouse preview uses four-cell center")
	check(game.building_tooltip_text("warehouse").contains("2×2"), "warehouse tooltip states footprint")
	check(game.building_footprint_cells("market", Vector2i(6, 15)).size() == 4, "market remains four cells")
	game.save_game(false)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path()))
	check(saved.buildings[0].warehouse_footprint == 1 and saved.buildings[-1].warehouse_footprint == 2, "mixed warehouse sizes save explicitly")
	check(game.validate_save_data(saved) == "", "mixed warehouse save validates")
	var blocked: Dictionary = saved.duplicate(true)
	blocked.roads.append({"x": 7, "z": 13})
	check(game.validate_save_data(blocked) != "", "saved road cannot occupy extended footprint")
	blocked = saved.duplicate(true)
	blocked.buildings.append({"id": 99, "type": "house", "x": 7, "z": 13, "enabled": true})
	blocked.next_id = 100
	check(game.validate_save_data(blocked) != "", "saved house cannot occupy extended footprint")
	game.load_game(false)
	game.time_paused = true
	check(game.record_footprint(game.buildings[0]) == Vector2i.ONE and game.record_footprint(game.buildings[-1]) == Vector2i(2, 2), "mixed sizes survive save and reload")
	check(game.occupied.get(Vector2i(7, 6), -1) == 2 and game.roads.has(Vector2i(6, 7)), "legacy neighbors survive save and reload")
	game.remove_building_by_id(1, false)
	check(game.occupied.get(Vector2i(7, 6), -1) == 2 and game.roads.has(Vector2i(6, 7)), "removing legacy warehouse leaves neighbors intact")
	game.remove_building_by_id(int(warehouse.id), false)
	for cell in game.building_footprint_cells("warehouse", Vector2i(6, 12)):
		check(not game.occupied.has(cell), "new warehouse demolition releases all four cells")
	game.fixture_io = false
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	if failures.is_empty():
		print("WAREHOUSE_FOOTPRINT_ACCEPTANCE_OK: new 2x2 placement, selection, preview, roads, demolition; legacy 1x1 and mixed save roundtrip isolated")
	quit(0 if failures.is_empty() else 1)
