extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("MARKET_FOOTPRINT_FAILED: " + message)

func run() -> void:
	root.size = Vector2i(1366, 768)
	var game = load("res://godot/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.time_paused = true
	for child in game.building_root.get_children():
		child.queue_free()
	for child in game.road_root.get_children():
		child.queue_free()
	game.buildings.clear()
	game.occupied.clear()
	game.roads.clear()
	game.map_region_level = 1
	game.wood = 1000
	game.coins = 1000
	var anchor := Vector2i(6, 6)
	check(game.can_place("market", anchor) == "", "clear 2x2 market is placeable")
	check(game.can_place("market", Vector2i(19, 6)) != "", "footprint cannot partially cross locked region")
	check(game.can_place("market", Vector2i(1, 6)) != "", "second footprint column cannot enter river")
	check(game.can_place("market", Vector2i(9, 6)) != "", "second footprint column cannot cover trunk road")
	game.add_road(Vector2i(7, 7), true)
	check(game.can_place("market", anchor) != "", "non-anchor road blocks placement")
	game.remove_road(Vector2i(7, 7), false)
	game.add_building("house", Vector2i(7, 7), true)
	var house_id: int = game.buildings[-1].id
	check(game.can_place("market", anchor) != "", "non-anchor house blocks placement")
	game.remove_building_by_id(house_id, false)
	game.add_building("market", anchor, true)
	var record: Dictionary = game.buildings[-1]
	var cells: Array = game.building_footprint_cells("market", anchor)
	check(cells.size() == 4, "market reserves four cells")
	check(record.node.position.is_equal_approx(game.grid_to_world(anchor) + Vector3(game.TILE_SIZE * 0.5, 0, game.TILE_SIZE * 0.5)), "model centered across four cells")
	for cell in cells:
		check(game.occupied.get(cell, -1) == record.id, "every footprint cell owns same building id")
		game.cancel_building()
		game.handle_world_click(game.camera.unproject_position(game.grid_to_world(cell)))
		check(game.selected_building_id == record.id, "click any of four cells selects market")
		check(game.can_place_road(cell) != "", "road cannot enter any market cell")
	check(not game.building_has_connected_road(record), "isolated market has no transportation income")
	game.add_road(Vector2i(8, 7), true)
	game.add_road(Vector2i(9, 7), true)
	check(game.building_has_connected_road(record), "road touches far east footprint edge")
	game.selected_type = "market"
	game.update_ghost(Vector2i(6, 12))
	check(game.ghost.position.is_equal_approx(game.building_model_position("market", Vector2i(6, 12))), "preview uses four-cell center")
	check(game.building_tooltip_text("market").contains("2×2"), "tooltip states footprint")
	game.remove_building_by_id(record.id, false)
	for cell in cells:
		check(not game.occupied.has(cell), "demolition releases all footprint cells")
	var data := {"version": 4, "day": 1, "wood": 100, "food": 40, "coins": 60, "population": 4, "happiness": 60, "low_happiness_days": 0, "stable_days": 0, "maintenance_debt": 0, "next_id": 3, "map_region_level": 1, "buildings": [{"id": 1, "type": "market", "x": 6, "z": 6, "enabled": true}], "roads": []}
	check(game.validate_save_data(data) == "", "four-cell market save validates")
	data.buildings.append({"id": 2, "type": "house", "x": 7, "z": 7, "enabled": true})
	check(game.validate_save_data(data) != "", "overlapping save footprint rejected")
	data.buildings.pop_back()
	data.roads.append({"x": 7, "z": 7})
	check(game.validate_save_data(data) != "", "road inside saved footprint rejected")
	data.roads.clear()
	data.buildings[0].x = 19
	check(game.validate_save_data(data) != "", "partially locked saved footprint rejected")
	data.buildings[0].x = 47
	data.map_region_level = 6
	check(game.validate_save_data(data) != "", "out of bounds saved footprint rejected")
	data.buildings[0].x = 1
	check(game.validate_save_data(data) != "", "water in saved footprint rejected")
	if failures.is_empty():
		print("MARKET_FOOTPRINT_ACCEPTANCE_OK: 2x2 placement, selection, preview, demolition, roads, save validation")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
