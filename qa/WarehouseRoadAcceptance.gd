extends SceneTree

class IsolatedGame:
	extends "res://godot/Main.gd"
	var fixture_io := false
	func save_path() -> String:
		return "res://.godot-user/qa/warehouse-road-fixture.json"
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/warehouse-road-audio.cfg"
	func save_game(feedback := true) -> void:
		if fixture_io:
			super.save_game(feedback)
	func load_game(feedback := true) -> void:
		if fixture_io:
			super.load_game(feedback)
	func trigger_event(_event_index: int) -> String:
		return "验收：无额外事件"
	func real_event(event_index: int) -> String:
		return super.trigger_event(event_index)

var failures: Array[String] = []
var boundary_cases := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := IsolatedGame.new()
	root.add_child(game)
	await process_frame
	game.time_paused = true
	game.set_process(false)
	game.set_physics_process(false)
	clear_village(game)
	check(game.building_count("warehouse") == 0, "initial fixture contains no warehouse")
	for quarter in range(4):
		check_footprint_boundaries(game, Vector2i(2, 2), quarter)
	check_footprint_boundaries(game, Vector2i.ONE, 2)
	check_inventory_and_settlement(game)
	check_saved_overflow(game)
	check_tooltip(game)
	if DisplayServer.get_name() != "headless":
		await capture_status(game)
	if FileAccess.file_exists(game.save_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path()))
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	if failures.is_empty():
		print("WAREHOUSE_ROAD_ACCEPTANCE_OK: %d boundary/rotation cases, legacy footprint, disconnected warning/green reconnection, no transport bonus, preserved overflow/refunds/events/settlement/save roundtrip" % boundary_cases)
		quit(0)
	else:
		quit(1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("WAREHOUSE_ROAD_ACCEPTANCE_FAILED: " + message)

func clear_roads(game) -> void:
	for cell in game.roads.keys().duplicate():
		game.remove_road(cell, false)

func clear_village(game) -> void:
	game.selected_building_id = -1
	game.inspector.visible = false
	for root_node in [game.building_root, game.road_root, game.citizen_root, game.animal_root]:
		for child in root_node.get_children():
			child.free()
	game.buildings.clear()
	game.occupied.clear()
	game.roads.clear()
	game.legacy_cleared_tree_roads.clear()
	game.update_road_scenery()
	game.map_region_level = 6
	game.day = 1
	game.population = 10
	game.happiness = 70
	game.wood = 100
	game.food = 100
	game.coins = 500
	game.maintenance_debt = 0
	game.low_happiness_days = 0
	game.ended = ""
	game.failure_reason = ""
	game.next_id = 1
	game.update_region_visuals()

func check_footprint_boundaries(game, footprint: Vector2i, rotation: int) -> void:
	clear_village(game)
	game.add_building("warehouse", Vector2i(6, 12), true, -1, true, footprint, rotation)
	var warehouse: Dictionary = game.buildings.back()
	var boundary: Array = game.building_boundary_cells(warehouse)
	check(boundary.size() == (8 if footprint == Vector2i(2, 2) else 4), "warehouse boundary size")
	for neighbor in boundary:
		clear_roads(game)
		boundary_cases += 1
		check(game.wood_capacity() == 100 and game.food_capacity() == 100, "disconnected warehouse adds no capacity")
		check(game.building_operation_state(warehouse).code == "road", "disconnected state is road")
		var marker: Label3D = game.get_building_status_marker(int(warehouse.id))
		check(marker != null and marker.visible and marker.text == "!", "disconnected warehouse has visible warning")
		game.show_inspector(int(warehouse.id))
		check(game.inspector_status.get_theme_color("font_color").is_equal_approx(Color("a63d32")), "disconnected inspector is red")
		game.add_road(neighbor, true)
		check(game.wood_capacity() == 100, "isolated adjacent road is insufficient")
		var route := exclusive_boundary_route(game, warehouse, neighbor)
		check(not route.is_empty(), "route exists to each specific perimeter cell")
		for cell in route:
			if not game.is_fixed_road_infrastructure(cell):
				game.add_road(cell, true)
		check(game.wood_capacity() == 175 and game.food_capacity() == 175, "connected perimeter activates both capacities")
		check(game.building_operation_state(warehouse).code == "passive", "connected warehouse status is active")
		check(not marker.visible, "reconnection hides warning immediately")
		check(game.inspector_status.get_theme_color("font_color").is_equal_approx(Color("39764b")), "reconnection makes open inspector green")
		warehouse.last_running = true
		check(game.road_bonus_for_building(warehouse) == 0, "warehouse never gets production transport bonus")
		game.wood = 150
		game.food = 160
		game.remove_road(neighbor, false)
		check(game.wood_capacity() == 100 and game.food_capacity() == 100, "cutting only connected perimeter disables storage")
		check(game.wood == 150 and game.food == 160, "road removal preserves existing over-capacity stock")
		check(marker.visible and game.inspector_status.text.contains("仓储停用"), "cut road immediately restores warning and inspector state")

func exclusive_boundary_route(game, warehouse: Dictionary, start: Vector2i) -> Array[Vector2i]:
	# No other perimeter cell is allowed, proving all four edges and far-corner
	# cells work rather than accidentally connecting through the anchor edge.
	var blocked: Array = game.building_boundary_cells(warehouse)
	blocked.erase(start)
	var goal := Vector2i(10, 8)
	var frontier: Array[Vector2i] = [start]
	var visited := {start: start}
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if cell == goal:
			var result: Array[Vector2i] = [goal]
			while result.back() != start:
				result.append(visited[result.back()])
			result.reverse()
			return result
		for neighbor in game.cardinal_cells(cell):
			if visited.has(neighbor) or neighbor in blocked or game.occupied.has(neighbor):
				continue
			if neighbor != goal and (not game.is_playable_cell(neighbor) or game.is_water_cell(neighbor) or game.has_scenery_tree(neighbor) or game.is_fixed_road_infrastructure(neighbor)):
				continue
			visited[neighbor] = cell
			frontier.append(neighbor)
	return []

func check_inventory_and_settlement(game) -> void:
	clear_village(game)
	game.add_building("warehouse", Vector2i(6, 12), true)
	game.add_building("lumber", Vector2i(15, 10), true)
	game.add_building("farm", Vector2i(4, 6), true)
	game.wood = 150
	game.food = 160
	game.population = 10
	game.coins = 100
	game.next_day()
	check(game.wood == 150, "daily production cannot truncate old overfull wood")
	check(game.food == 155, "daily food changes only by legitimate 5-person ration units")
	check(game.coins == 106, "disconnected warehouse still pays its fixed 1-coin maintenance")
	game.real_event(0)
	check(game.food == 155, "harvest event cannot truncate old overfull food")
	game.real_event(2)
	check(game.wood == 150 and game.food == 155, "full wood store skips unusable caravan trade without destroying stock")
	game.apply_region_reward(1)
	check(game.wood == 150 and game.food == 155, "region reward cannot truncate existing overfull inventory")
	game.add_road(Vector2i(8, 12), true)
	game.add_road(Vector2i(9, 12), true)
	check(game.wood_capacity() == 175, "road can reactivate warehouse after overfull period")
	game.next_day()
	check(game.wood > 150 and game.wood <= 175, "reconnected storage resumes new wood intake")
	game.wood = 170
	game.food = 170
	game.remove_road(Vector2i(9, 12), true)
	check(game.wood == 171 and game.food == 170 and game.wood_capacity() == 100, "road refund preserves existing stock plus recovered wood")
	var warehouse: Dictionary = game.buildings[0]
	game.remove_building_by_id(int(warehouse.id), true)
	check(game.wood == 186 and game.food == 170, "warehouse demolition preserves old inventory and refund")
	check(game.storage_after_intake(186, 20, 100) == 186, "overfull intake is zero")
	check(game.storage_after_intake(98, 20, 100) == 100, "partial free space limits only new intake")

func check_saved_overflow(game) -> void:
	game.fixture_io = true
	game.save_game(false)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path()))
	check(game.validate_save_data(data) == "", "overfull stock without surviving warehouse is save-valid: " + game.validate_save_data(data))
	game.wood = 0
	game.food = 0
	game.load_game(false)
	game.fixture_io = false
	check(game.wood == 186 and game.food == 170 and game.wood_capacity() == 100, "overfull stock survives isolated save roundtrip")
	var invalid: Dictionary = data.duplicate(true)
	invalid.wood = -1
	check(game.validate_save_data(invalid) != "", "negative stock rejected")
	invalid.wood = 100 + game.GRID_SIZE * game.GRID_SIZE * 75 + 1
	check(game.validate_save_data(invalid) != "", "absurd stock beyond map theoretical storage rejected")

func check_tooltip(game) -> void:
	var tooltip: String = game.building_tooltip_text("warehouse")
	check(tooltip.contains("接通主路：木材/粮食容量各 +75"), "tooltip explicitly conditions storage on main-road connection")
	check(tooltip.contains("未接通也收取"), "tooltip states disconnected maintenance")
	check(not tooltip.contains("道路运输"), "warehouse tooltip promises no transport coins")

func capture_status(game) -> void:
	clear_village(game)
	game.time_paused = true
	game.add_building("warehouse", Vector2i(6, 12), true)
	var warehouse: Dictionary = game.buildings.back()
	game.show_inspector(int(warehouse.id))
	game.camera_target = game.building_model_position("warehouse", Vector2i(6, 12))
	game.camera.position = game.camera_target + Vector3(25, 28, 27)
	game.camera.size = 16.0
	game.camera.look_at(game.camera_target)
	var framing_shift: Vector3 = game.camera.basis.x * 5.4
	game.camera_target += framing_shift
	game.camera.position += framing_shift
	game.update_ui()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/warehouse-road"))
	for connected in [false, true]:
		if connected:
			game.add_road(Vector2i(8, 12), true)
			game.add_road(Vector2i(9, 12), true)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var suffix := "connected" if connected else "disconnected"
		check(root.get_texture().get_image().save_png("res://qa/warehouse-road/" + suffix + ".png") == OK, "save warehouse connection screenshot")
