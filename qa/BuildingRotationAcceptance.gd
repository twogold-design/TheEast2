extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	var fixture_io := false
	func save_path() -> String:
		return "res://.godot-user/qa/building-rotation-fixture.json"
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/building-rotation-audio.cfg"
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
		push_error("BUILDING_ROTATION_FAILED: " + message)

func run() -> void:
	root.size = Vector2i(1366, 768)
	var game := IsolatedGame.new()
	root.add_child(game)
	# Music playback has its own acceptance; release its stream before this
	# synchronous placement loop so the audio thread can finish independently.
	game.background_music.player.stop()
	game.background_music.player.stream = null
	game.set_process(false)
	game.set_physics_process(false)
	game.time_paused = true
	for record in game.buildings.duplicate():
		game.remove_building_by_id(int(record.id), false)
	game.map_region_level = 6
	game.wood = 100
	game.coins = 300
	check(game.help_dialog.dialog_text.contains("R："), "help explains R rotation")
	check(not game.help_dialog.dialog_text.contains("旋转按钮"), "help has no removed button")
	for button in game.find_children("*", "Button", true, false):
		check(not button.text.contains("旋转"), "no rotation button in UI")
	game.select_building("fishpond")
	game.update_ghost(Vector2i(7, 12))
	check(game.can_place("fishpond", Vector2i(7, 12), 0) == "", "unrotated pond before trunk fits")
	var rotation_key := InputEventKey.new()
	rotation_key.physical_keycode = KEY_R
	rotation_key.pressed = true
	game._unhandled_input(rotation_key)
	check(game.selected_rotation_quarters == 1, "R rotates by quarter turn")
	var middle_click := InputEventMouseButton.new()
	middle_click.button_index = MOUSE_BUTTON_MIDDLE
	middle_click.position = Vector2(600, 300)
	middle_click.pressed = true
	game._unhandled_input(middle_click)
	middle_click.pressed = false
	game._unhandled_input(middle_click)
	check(game.selected_rotation_quarters == 1, "middle click does not rotate")
	check(is_equal_approx(game.ghost.rotation.y, PI * 0.5), "preview mesh rotates")
	check(game.ghost.position.is_equal_approx(game.building_model_position("fishpond", Vector2i(7, 12), Vector2i(2, 3))), "preview center follows rotated footprint")
	check(game.can_place("fishpond", Vector2i(8, 12), 0) != "" and game.can_place("fishpond", Vector2i(8, 12), 1) == "", "rotation changes main-road clearance")
	check(game.can_place("fishpond", Vector2i(46, 28), 0) != "" and game.can_place("fishpond", Vector2i(46, 28), 1) == "", "rotation changes world-edge clearance")
	game.add_road(Vector2i(8, 14), true)
	check(game.can_place("fishpond", Vector2i(7, 12), 0) == "" and game.can_place("fishpond", Vector2i(7, 12), 1) != "", "rotated third row collides with road")
	game.remove_road(Vector2i(8, 14), false)
	var prior_camera_target: Vector3 = game.camera_target
	middle_click.pressed = true
	game._unhandled_input(middle_click)
	var drag := InputEventMouseMotion.new()
	drag.position = middle_click.position + Vector2(24, 0)
	game._unhandled_input(drag)
	middle_click.pressed = false
	middle_click.position = drag.position
	game._unhandled_input(middle_click)
	check(not game.camera_target.is_equal_approx(prior_camera_target), "middle drag still pans map")
	check(game.selected_rotation_quarters == 1, "middle drag does not rotate building")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.position = Vector2(600, 300)
	right_click.pressed = true
	game._unhandled_input(right_click)
	right_click.pressed = false
	game._unhandled_input(right_click)
	check(game.selected_rotation_quarters == 0 and game.ghost == null and game.selected_type == "", "cancelling resets rotation and preview")
	for type in ["farm", "fishpond"]:
		for quarter in range(4):
			var cell := Vector2i(4, 12) if type == "farm" else Vector2i(7, 12)
			check(game.can_place(type, cell, quarter) == "", "%s orientation %d is placeable" % [type, quarter])
			game.add_building(type, cell, true, -1, true, Vector2i.ZERO, quarter)
			var record: Dictionary = game.buildings[-1]
			var expected: Vector2i = game.rotated_footprint(game.BUILDING_FOOTPRINTS[type], quarter)
			check(game.record_footprint(record) == expected, "runtime footprint matches rotation")
			check(record.node.position.is_equal_approx(game.building_model_position(type, cell, expected)), "runtime center matches rotation")
			check(is_equal_approx(record.node.rotation.y, quarter * PI * 0.5), "placed mesh keeps quarter turn")
			var door := record.node.find_child("Door", true, false) as Node3D
			if door:
				var expected_entrance := game.citizen_root.to_local(door.global_position + record.node.global_basis.z.normalized() * 0.26 + Vector3.UP * 0.02)
				check(game.citizen_work_position(type, 0).is_equal_approx(expected_entrance), "NPC approaches rotated real doorway")
			for covered in game.building_footprint_cells(type, cell, expected):
				check(game.occupied.get(covered, -1) == record.id and game.can_place_road(covered) != "", "all rotated cells selectable and block roads")
				game.handle_world_click(game.camera.unproject_position(game.grid_to_world(covered)))
				check(game.selected_building_id == record.id, "click every rotated occupied cell selects the same building")
			game.fixture_io = true
			game.save_game(false)
			var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path()))
			check(game.validate_save_data(saved) == "", "rotated save validates")
			check(int(saved.buildings[0].rotation_quarters) == quarter, "angle saved explicitly")
			if type == "farm":
				check(int(saved.buildings[0].farm_footprint) == 4, "new farm saves four-cell base at every angle")
			for bad_angle in [-1, 4, 0.5, "1", true, null]:
				var bad: Dictionary = saved.duplicate(true)
				bad.buildings[0].rotation_quarters = bad_angle
				check(game.validate_save_data(bad) != "", "invalid saved angle rejected")
			game.load_game(false)
			game.fixture_io = false
			var loaded: Dictionary = game.buildings[0]
			check(int(loaded.rotation_quarters) == quarter and game.record_footprint(loaded) == expected, "orientation and footprint roundtrip")
			game.remove_building_by_id(int(loaded.id), false)
			check(game.occupied.is_empty(), "rotated demolition frees every cell")
	# New fields remain optional for old saves, including legacy single-cell farms.
	var legacy := {"version": 4, "day": 1, "wood": 100, "food": 40, "coins": 300, "population": 4, "happiness": 60, "low_happiness_days": 0, "stable_days": 0, "maintenance_debt": 0, "next_id": 2, "map_region_level": 1, "buildings": [{"id": 1, "type": "farm", "x": 4, "z": 12, "enabled": true}], "roads": []}
	check(game.validate_save_data(legacy) == "" and game.saved_building_footprint(legacy.buildings[0]) == Vector2i.ONE, "legacy missing angle defaults to zero with compact farm")
	for quarter in range(4):
		legacy.buildings[0].farm_footprint = 2
		legacy.buildings[0].rotation_quarters = quarter
		var expected := Vector2i(2, 1) if quarter % 2 == 0 else Vector2i(1, 2)
		check(game.validate_save_data(legacy) == "", "legacy two-cell farm angle %d validates" % quarter)
		var fixture := FileAccess.open(game.save_path(), FileAccess.WRITE)
		fixture.store_string(JSON.stringify(legacy))
		fixture.close()
		game.fixture_io = true
		game.load_game(false)
		check(game.record_footprint(game.buildings[0]) == expected, "legacy two-cell farm keeps rotated footprint")
		check(game.buildings[0].node.scale == Vector3.ONE, "legacy two-cell farm not stretched")
		game.save_game(false)
		var saved_legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path()))
		check(int(saved_legacy.buildings[0].farm_footprint) == 2 and int(saved_legacy.buildings[0].rotation_quarters) == quarter, "legacy two-cell farm roundtrip keeps size and angle")
		game.fixture_io = false
		game.remove_building_by_id(int(game.buildings[0].id), false)
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.4, true, false, true).timeout
	if failures.is_empty():
		print("BUILDING_ROTATION_OK: R-only rotation, no button/middle rotation, preview, farm/pond four directions, boundaries, roads, rotated entrances, save validation and legacy compatibility")
		quit(0)
	else:
		quit(1)
