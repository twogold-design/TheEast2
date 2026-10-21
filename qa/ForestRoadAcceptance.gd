extends SceneTree

## Dedicated fixture only: never reads or writes the player's real save.
const FIXTURE_PATH := "res://qa/fixtures/forest-road-save.json"
const TREE_CELL := Vector2i(18, 14)
const GAP_CELL := Vector2i(18, 12)
const ROCK_CELL := Vector2i(19, 12)
const FAR_CELL := Vector2i(20, 12)
var failures: Array[String] = []

class IsolatedGame:
	extends "res://godot/Main.gd"
	var fixture_loading := false
	var schedule_refresh_count := 0
	func save_game(_feedback := true) -> void:
		pass
	func load_game(feedback := true) -> void:
		if fixture_loading:
			super(feedback)
	func save_path() -> String:
		return ProjectSettings.globalize_path(FIXTURE_PATH)
	func write_fixture_save() -> void:
		super.save_game(false)
	func update_citizen_schedules() -> void:
		schedule_refresh_count += 1
		super()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366, 768)
	root.content_scale_size = root.size
	var game := IsolatedGame.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.time_paused = true
	game.set_process(false)
	game.set_physics_process(false)
	prepare_empty(game)
	check_trees_and_gaps(game)
	check_rocks_and_connection(game)
	if DisplayServer.get_name() != "headless":
		await capture(game, "forest-corridor-laid-1366x768.png")
	check_rock_restore(game)
	if DisplayServer.get_name() != "headless":
		await capture(game, "forest-cell-restored-1366x768.png")
	check_new_save_rules(game)
	check_legacy_migration(game)
	game.reset_game(false)
	check_visibility(game.scenery_trees_by_cell.get(TREE_CELL, []), true, "重置后树木未恢复")
	check_visibility(game.scenery_rocks_by_cell.get(ROCK_CELL, []), true, "重置后石头未恢复")
	if not game.legacy_cleared_tree_roads.is_empty():
		fail("重置后历史清树标记未清空")
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_PATH))
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	if failures.is_empty():
		print("FOREST_ROAD_ACCEPTANCE_OK: trees preserved/blocked, forest-gap route connected, rocks cleared/restored, NPC tree avoidance, legacy-only migration and marked roundtrip; isolated saves")
		quit(0)
	else:
		quit(1)

func prepare_empty(game) -> void:
	for child in game.building_root.get_children():
		child.queue_free()
	for child in game.road_root.get_children():
		child.queue_free()
	game.buildings.clear()
	game.occupied.clear()
	game.roads.clear()
	game.legacy_cleared_tree_roads.clear()
	game.update_road_scenery()
	game.map_region_level = 2
	game.population = 10
	game.coins = 100
	game.wood = 100
	game.food = 100
	game.ended = ""
	game.next_id = 1
	game.update_region_visuals()

func check_trees_and_gaps(game) -> void:
	if not game.is_reserved_forest(TREE_CELL) or not game.has_scenery_tree(TREE_CELL):
		fail("树格测试点不符")
	if game.can_place_road(TREE_CELL).find("树木") < 0:
		fail("树木实际占格未阻挡铺路")
	var before: int = game.wood
	game.add_road(TREE_CELL, true)
	if game.roads.has(TREE_CELL) or game.wood != before:
		fail("免费放置绕过树格限制")
	game.select_road_tool()
	game.update_ghost(TREE_CELL)
	check_visibility(game.scenery_trees_by_cell.get(TREE_CELL, []), true, "无效道路预览隐藏了树")
	game.cancel_building()
	check_visibility(game.scenery_trees_by_cell.get(TREE_CELL, []), true, "取消预览未保留树")
	if not game.is_reserved_forest(GAP_CELL) or game.has_scenery_tree(GAP_CELL) or game.can_place_road(GAP_CELL) != "":
		fail("林区空格不能铺路")
	if game.can_place("house", GAP_CELL).find("保留林地") < 0:
		fail("普通建筑错误进入保留林地")
	if game.citizen_navigation_cell_walkable(TREE_CELL, Vector2i(15, 14), Vector2i(21, 14)):
		fail("居民仍能穿过树木所在格")
	if not game.citizen_navigation_cell_walkable(GAP_CELL, Vector2i(15, 12), Vector2i(21, 12)):
		fail("居民不能沿林间空地通行")
	game.map_region_level = 0
	if game.can_place_road(FAR_CELL).find("尚未开放") < 0:
		fail("未解锁区域允许铺路")
	game.map_region_level = 2
	if game.can_place_road(Vector2i(-1, 10)).find("边界") < 0:
		fail("外围缓冲区允许铺路")

func check_rocks_and_connection(game) -> void:
	var rocks: Array = game.scenery_rocks_by_cell.get(ROCK_CELL, [])
	if rocks.is_empty() or game.can_place_road(ROCK_CELL) != "":
		fail("实际石头格不能铺路")
	game.select_road_tool()
	game.update_ghost(ROCK_CELL)
	check_visibility(rocks, false, "有效预览未让石头让出道路")
	game.cancel_building()
	check_visibility(rocks, true, "取消预览没有恢复石头")
	var refreshes: int = game.schedule_refresh_count
	for x in range(11, 21):
		var cell := Vector2i(x, 12)
		if game.can_place_road(cell) != "":
			fail("绕树通道无法贯通：%s %s" % [cell, game.can_place_road(cell)])
		game.add_road(cell, true)
	if game.schedule_refresh_count <= refreshes:
		fail("铺路未更新居民路线")
	if not game.is_road_connected(FAR_CELL):
		fail("首区经过林间空地未接通东麓")
	check_visibility(rocks, false, "已铺路后石头仍挡路")
	check_visibility(game.scenery_trees_by_cell.get(TREE_CELL, []), true, "空隙铺路影响邻格树木")
	var path: Array = game.citizen_grid_path_unforced(Vector2i(15, 12), Vector2i(21, 12))
	if path.is_empty() or not path.has(GAP_CELL):
		fail("居民未走林间通道")
	for cell in path:
		if game.has_scenery_tree(cell):
			fail("居民路径穿过树木")
	game.add_building("lumber", Vector2i(21, 12), true)
	game.assign_workers()
	var lumber: Dictionary = game.buildings.back()
	lumber.last_running = true
	if game.road_bonus_for_building(lumber) != 1:
		fail("绕树道路连通后无运输收益")
	var outer: Node = game.world.get_node("OuterNaturalBuffer")
	for child in outer.get_children():
		if not child.visible:
			fail("铺路影响了外围装饰")

func check_rock_restore(game) -> void:
	game.remove_road(ROCK_CELL, false)
	check_visibility(game.scenery_rocks_by_cell.get(ROCK_CELL, []), true, "拆路后石头没有恢复")
	if game.is_road_connected(FAR_CELL):
		fail("拆除通道后路网未断开")

func check_new_save_rules(game) -> void:
	var data := fixture_data(14)
	data.road_rules_version = 2
	if game.validate_save_data(data).find("树木") < 0:
		fail("新版存档可无标记导入树格道路")
	data.roads[7].legacy_cleared_tree = "true"
	if game.validate_save_data(data).find("标记") < 0:
		fail("错误类型历史标记被接受")
	data = fixture_data(12)
	data.road_rules_version = 2
	if game.validate_save_data(data) != "":
		fail("新版空林格道路存档无效：" + game.validate_save_data(data))
	load_fixture(game, data)
	check_visibility(game.scenery_trees_by_cell.get(TREE_CELL, []), true, "新存档读取清除了树")
	check_visibility(game.scenery_rocks_by_cell.get(ROCK_CELL, []), false, "新存档读取未清理道路石头")
	if not game.is_road_connected(FAR_CELL):
		fail("新存档空林道路读取后断开")

func check_legacy_migration(game) -> void:
	var old := fixture_data(14)
	if game.validate_save_data(old) != "":
		fail("旧版树格道路无法兼容迁移")
	load_fixture(game, old)
	if not game.roads.has(TREE_CELL) or not game.legacy_cleared_tree_roads.has(TREE_CELL):
		fail("旧版已有树格道路未保留")
	check_visibility(game.scenery_trees_by_cell.get(TREE_CELL, []), false, "旧路兼容时重新长出了挡路树")
	if not game.citizen_navigation_cell_walkable(TREE_CELL, Vector2i(15, 14), Vector2i(21, 14)):
		fail("历史已有道路无法通行")
	game.write_fixture_save()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	if int(saved.get("road_rules_version", 0)) != 2:
		fail("迁移后缺少新道路规则版本")
	var marked := false
	for road in saved.roads:
		if Vector2i(int(road.x), int(road.z)) == TREE_CELL:
			marked = bool(road.get("legacy_cleared_tree", false))
	if not marked:
		fail("迁移后未明确保存历史清树标记")
	game.remove_road(TREE_CELL, false)
	check_visibility(game.scenery_trees_by_cell.get(TREE_CELL, []), true, "拆除历史道路没有恢复树")
	game.add_road(TREE_CELL, true)
	if game.roads.has(TREE_CELL) or game.legacy_cleared_tree_roads.has(TREE_CELL):
		fail("拆除历史道路后仍可重铺清树")
	load_fixture(game, saved)
	if not game.roads.has(TREE_CELL) or not game.legacy_cleared_tree_roads.has(TREE_CELL):
		fail("明确标记的历史道路不能往返读取")

func fixture_data(row: int) -> Dictionary:
	var saved_roads: Array = []
	for x in range(11, 21):
		saved_roads.append({"x": x, "z": row})
	return {"version": 4, "map_region_level": 2, "day": 6, "wood": 100, "food": 100, "coins": 100, "population": 10, "happiness": 70, "low_happiness_days": 0, "stable_days": 0, "maintenance_debt": 0, "next_id": 2, "buildings": [{"id": 1, "type": "lumber", "x": 21, "z": row, "enabled": true}], "roads": saved_roads}

func load_fixture(game, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_PATH).get_base_dir())
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	game.fixture_loading = true
	game.load_game(false)
	game.fixture_loading = false
	game.time_paused = true

func check_visibility(nodes: Array, expected: bool, message: String) -> void:
	if nodes.is_empty():
		fail("场景验证缺少对象：" + message)
	for node in nodes:
		if is_instance_valid(node) and node.visible != expected:
			fail(message)

func capture(game, filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/forest-road"))
	game.inspector.visible = false
	game.camera_target = game.grid_to_world(Vector2i(17, 12))
	game.camera.position = game.camera_target + Vector3(25, 28, 27)
	game.camera.size = 18.0
	game.camera.look_at(game.camera_target)
	game.show_message("道路沿林间空格连通；树木保留，道路占格石头移除")
	game.update_ui()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://qa/forest-road/" + filename) != OK:
		fail("截图失败")

func fail(message: String) -> void:
	failures.append(message)
	push_error("FOREST_ROAD_ACCEPTANCE_FAILED: " + message)
