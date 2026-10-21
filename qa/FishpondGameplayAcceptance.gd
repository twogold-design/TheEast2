extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	var fixture_io := false
	func save_path() -> String:
		return "res://.godot-user/qa/fishpond-gameplay-fixture.json"
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/fishpond-gameplay-audio.cfg"
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
		push_error("FISHPOND_GAMEPLAY_FAILED: " + message)

func clear_layout(game) -> void:
	game.ended = ""
	game.failure_reason = ""
	for child in game.building_root.get_children():
		child.free()
	for child in game.road_root.get_children():
		child.free()
	game.buildings.clear()
	game.occupied.clear()
	game.roads.clear()
	game.next_id = 1
	game.map_region_level = 1
	game.wood = 100
	game.food = 40
	game.coins = 300
	game.population = 4
	game.happiness = 65
	game.day = 2 # next daily event changes happiness only
	game.low_happiness_days = 0
	game.maintenance_debt = 0
	game.day_settling = false

func run() -> void:
	root.size = Vector2i(1366, 768)
	var game := IsolatedGame.new()
	root.add_child(game)
	game.background_music.player.stop()
	game.background_music.player.stream = null
	game.set_process(false)
	game.set_physics_process(false)
	game.time_paused = true
	clear_layout(game)
	game.map_region_level = 0
	check(not game.building_is_unlocked("fishpond"), "fishpond locked in first region")
	check(game.BUILDINGS.fishpond.unlock_level == game.BUILDINGS.market.unlock_level, "fishpond and market unlock together")
	check(game.INITIAL_BUILDING_TYPES.size() == 5 and "farm" in game.INITIAL_BUILDING_TYPES, "five starting types preserved")
	check(game.building_in_build_category("fishpond", "industry") and not game.building_in_build_category("fishpond", "basic"), "fishpond appears in industry only")
	game.map_region_level = 1
	check(game.building_is_unlocked("fishpond"), "fishpond unlocks after north terrace")
	check(game.can_place("fishpond", Vector2i(6, 12)) == "", "artificial fishpond placeable on inland clear land")
	check(game.can_place("fishpond", Vector2i(1, 12)) != "", "river overlap rejected")
	check(game.can_place("fishpond", Vector2i(8, 12)) != "", "main road in far footprint column rejected")
	game.add_road(Vector2i(8, 13), true)
	check(game.can_place("fishpond", Vector2i(6, 12)) != "", "sixth-cell road overlap rejected")
	game.remove_road(Vector2i(8, 13), false)
	game.add_building("fishpond", Vector2i(6, 12), false)
	var pond: Dictionary = game.buildings[-1]
	check(game.wood == 60 and game.coins == 284, "fishpond construction charges 40 wood and 16 coins")
	check(game.record_footprint(pond) == Vector2i(3, 2), "fishpond uses 3x2 footprint")
	check(pond.node.position.is_equal_approx(game.grid_to_world(Vector2i(6, 12)) + Vector3(2.2, 0, 1.1)), "model centered over six cells")
	for cell in game.building_footprint_cells("fishpond", pond.cell):
		check(game.occupied.get(cell, -1) == pond.id, "all six cells select pond")
	game.add_road(Vector2i(9, 13), true)
	check(game.building_has_connected_road(pond), "road reaches extended east edge")
	check(game.building_tooltip_text("fishpond").contains("3×2"), "tooltip states large footprint")
	check(game.building_effect_text("fishpond").contains("粮食 0/+7/+14"), "precise proportional output tooltip")
	check(not game.building_operation_text(pond).contains("民生交易"), "fishpond does not claim unearned basic-trade income")
	game.selected_type = "fishpond"
	game.update_ghost(Vector2i(6, 16))
	check(game.ghost.position.is_equal_approx(game.building_model_position("fishpond", Vector2i(6, 16))), "preview uses six-cell center")
	game.cancel_building()
	game.fixture_io = true
	game.save_game(false)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path()))
	check(game.validate_save_data(data) == "", "fishpond save validates")
	var invalid: Dictionary = data.duplicate(true)
	invalid.map_region_level = 0
	check(game.validate_save_data(invalid) != "", "fishpond in locked chapter rejected")
	invalid = data.duplicate(true)
	invalid.roads.append({"x": 8, "z": 13})
	check(game.validate_save_data(invalid) != "", "saved road overlap in sixth cell rejected")
	game.load_game(false)
	game.fixture_io = false
	check(game.buildings.size() == 1 and game.record_footprint(game.buildings[0]) == Vector2i(3, 2), "fishpond survives save roundtrip")
	game.remove_building_by_id(int(game.buildings[0].id), false)
	check(game.occupied.is_empty(), "demolition releases all six cells")
	for workers_case in [1, 2, 0]:
		clear_layout(game)
		game.population = 1 if workers_case == 1 else 4
		game.add_building("fishpond", Vector2i(6, 12), true)
		pond = game.buildings[0]
		if workers_case == 0:
			pond.enabled = false
		game.assign_workers()
		check(int(pond.assigned_workers) == workers_case, "staffing matches case %d" % workers_case)
		var before_food := int(game.food)
		var before_coins := int(game.coins)
		var residents := int(game.population)
		game.next_day()
		check(game.food == before_food + workers_case * 7 - ceili(residents / 2.0), "actual daily food matches staffed output %d" % workers_case)
		check(game.coins == before_coins + maxi(1, residents / 2) - (2 if workers_case > 0 else 0), "maintenance charged only enabled; no hidden trade income")
		check(bool(pond.last_running) == (workers_case > 0), "paused pond produces nothing")
	clear_layout(game)
	game.add_building("fishpond", Vector2i(6, 12), true)
	pond = game.buildings[0]
	game.add_road(Vector2i(9, 13), true)
	game.next_day()
	check(game.road_bonus_for_building(pond) == game.ROAD_TRANSPORT_BONUS, "fully staffed pond earns transport bonus")
	game.population = 1
	game.assign_workers()
	check(game.road_bonus_for_building(pond) == 0, "partial staffing uses same transport rule as farm")
	check_farm_compatibility(game)
	game.fixture_io = false
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.4, true, false, true).timeout
	if failures.is_empty():
		print("FISHPOND_GAMEPLAY_OK: industry unlock, 3x2 footprint, production, staffing, road income, save roundtrip, 2x2 farm corners and legacy compatibility")
		quit(0)
	else:
		quit(1)

func check_farm_compatibility(game) -> void:
	clear_layout(game)
	check(game.can_place("farm", Vector2i(4, 12)) == "", "new four-cell farm fits east riverbank")
	check(game.can_place("farm", Vector2i(0, 12)) == "", "new four-cell farm fits west riverbank with east side touching water")
	check(game.can_place("farm", Vector2i(1, 12)) != "", "farm cannot extend over river")
	check(game.can_place("farm", Vector2i(6, 12)) != "", "inland farm rejected")
	check(game.building_tooltip_text("farm").contains("2×2"), "farm tooltip states four-cell footprint")
	for corner in [Vector2i(4, 12), Vector2i(5, 12), Vector2i(4, 13), Vector2i(5, 13)]:
		game.add_road(corner, true)
		check(game.can_place("farm", Vector2i(4, 12)) != "", "farm cannot overlap a road in any of its four corners")
		game.remove_road(corner, false)
		game.add_building("house", corner, true)
		check(game.can_place("farm", Vector2i(4, 12)) != "", "farm cannot overlap a house in any of its four corners")
		game.remove_building_by_id(int(game.buildings[-1].id), false)
	var data := {"version": 4, "day": 1, "wood": 100, "food": 40, "coins": 300, "population": 4, "happiness": 60, "low_happiness_days": 0, "stable_days": 0, "maintenance_debt": 0, "next_id": 3, "map_region_level": 1, "buildings": [{"id": 1, "type": "farm", "x": 4, "z": 12, "enabled": true}, {"id": 2, "type": "house", "x": 5, "z": 12, "enabled": true}], "roads": []}
	for version in [1, 2, 3, 4]:
		data.version = version
		check(game.validate_save_data(data) == "", "legacy v%d farm beside house validates" % version)
	data.version = 4
	for bad_size in [0, 3, 1.5, "2", true, null]:
		var invalid: Dictionary = data.duplicate(true)
		invalid.buildings[0].farm_footprint = bad_size
		check(game.validate_save_data(invalid) != "", "invalid farm footprint rejected")
	var blocked: Dictionary = data.duplicate(true)
	blocked.buildings[0].farm_footprint = 2
	check(game.validate_save_data(blocked) != "", "expanding old farm into neighbor rejected")
	var fixture := FileAccess.open(game.save_path(), FileAccess.WRITE)
	fixture.store_string(JSON.stringify(data))
	fixture.close()
	game.fixture_io = true
	game.load_game(false)
	check(game.record_footprint(game.buildings[0]) == Vector2i.ONE, "legacy farm remains one cell")
	check(game.buildings[0].node.scale == Vector3.ONE, "legacy farm art not distorted")
	check(game.occupied.get(Vector2i(5, 12), -1) == 2, "legacy neighboring house preserved")
	game.add_building("farm", Vector2i(4, 14), true)
	var farm: Dictionary = game.buildings[-1]
	check(game.record_footprint(farm) == Vector2i(2, 2), "new farm occupies four cells")
	for corner in [Vector2i(4, 14), Vector2i(5, 14), Vector2i(4, 15), Vector2i(5, 15)]:
		check(game.occupied.get(corner, -1) == farm.id and game.can_place_road(corner) != "", "every new farm corner is occupied and blocks roads")
	game.save_game(false)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path()))
	check(saved.buildings[0].farm_footprint == 1 and saved.buildings[-1].farm_footprint == 4, "mixed farm sizes save explicitly")
	check(game.validate_save_data(saved) == "", "mixed farm save valid")
	for corner in [Vector2i(4, 14), Vector2i(5, 14), Vector2i(4, 15), Vector2i(5, 15)]:
		var overlap: Dictionary = saved.duplicate(true)
		overlap.roads.append({"x": corner.x, "z": corner.y})
		check(game.validate_save_data(overlap) != "", "saved road collision rejected at every farm corner")
	game.load_game(false)
	game.fixture_io = false
	check(game.record_footprint(game.buildings[0]) == Vector2i.ONE and game.record_footprint(game.buildings[-1]) == Vector2i(2, 2), "mixed farms reload without expansion")
	game.remove_building_by_id(int(farm.id), false)
	for corner in [Vector2i(4, 14), Vector2i(5, 14), Vector2i(4, 15), Vector2i(5, 15)]:
		check(not game.occupied.has(corner), "farm demolition releases every corner")
