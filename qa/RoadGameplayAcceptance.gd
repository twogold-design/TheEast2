extends SceneTree

## Release acceptance for the player-built road network.  Roads are independent
## infrastructure: they do not consume a building slot, but a connected segment
## beside a normally operating production building adds a small daily coin
## transport income.

const VIEWPORT_SIZE := Vector2i(1366, 768)
const SAVE_PATH := "res://saves/savegame.json"

var failures: Array[String] = []
var original_save_exists := false
var original_save_text := ""


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	preserve_save_file()
	root.size = VIEWPORT_SIZE
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		fail("主场景无法加载")
		restore_save_file()
		finish()
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.time_paused = true

	check_independent_tool_and_ui(game)
	check_placement_rules_and_cost(game)
	check_connectivity_and_bridge(game)
	check_transport_eligibility_and_cap(game)
	await check_daily_settlement_and_copy(game)
	await check_cancel_select_and_demolish(game)
	check_v4_roundtrip_and_v3_migration(game)

	restore_save_file()
	finish()


func check_independent_tool_and_ui(game) -> void:
	if int(game.ROAD_WOOD_COST) != 1 or int(game.ROAD_TRANSPORT_BONUS) != 1 or int(game.ROAD_TRANSPORT_COIN_CAP) != 6:
		fail("道路成本或运输收益规则与策划规格不一致")
	var opening_types := ["house", "farm", "lumber", "workshop", "warehouse"]
	if game.INITIAL_BUILDING_TYPES != opening_types:
		fail("道路功能改变了五类开局建筑清单：%s" % game.INITIAL_BUILDING_TYPES)
	if game.BUILDINGS.has("road") or game.BUILDINGS.has("道路"):
		fail("道路被错误加入建筑图鉴")
	if game.build_buttons.has("road") or game.build_buttons.has("道路"):
		fail("道路被错误加入普通建筑按钮")
	if game.road_root == null or game.road_root == game.building_root:
		fail("道路没有使用独立场景根节点")
	if game.road_button == null or not game.road_button.is_visible_in_tree():
		fail("底部没有常驻铺路入口")
		return
	check_inside_viewport(game.road_button, "铺路按钮")
	check_inside_viewport(game.bottom_panel, "底部建造栏")
	var button_text := str(game.road_button.text)
	var tooltip := str(game.road_button.tooltip_text)
	if button_text.find("铺路") < 0 or button_text.find("木1") < 0:
		fail("铺路按钮没有简洁显示每格木材成本：%s" % button_text)
	for phrase in ["村庄主路", "正常运行", "铜钱", "+1", "上限 +6"]:
		if tooltip.find(phrase) < 0:
			fail("铺路提示缺少“%s”：%s" % [phrase, tooltip])

	game.select_road_tool()
	if not game.road_tool_selected or game.selected_type != "" or not game.road_button.button_pressed:
		fail("铺路工具没有独立于建筑摆放模式启用")
	game.select_building("farm")
	if game.road_tool_selected or game.selected_type != "farm":
		fail("选择建筑后没有正确退出铺路模式")
	game.cancel_building()


func check_placement_rules_and_cost(game) -> void:
	prepare_empty(game, 0)
	game.wood = 20
	if str(game.can_place_road(Vector2i(-1, 8))).find("边界") < 0:
		fail("道路可铺到地图外")
	if str(game.can_place_road(Vector2i(2, 8))).find("水面") < 0:
		fail("道路可直接铺到河面")
	if str(game.can_place_road(Vector2i(10, 20))).find("尚未开放") < 0:
		fail("道路可铺到未解锁区域")

	game.add_building("house", Vector2i(8, 8), true)
	if str(game.can_place_road(Vector2i(8, 8))).find("建筑占用") < 0:
		fail("道路可与建筑占用同一格")
	game.wood = 0
	if str(game.can_place_road(Vector2i(8, 9))).find("木材不足") < 0:
		fail("木材不足时仍可铺路")
	game.wood = 20
	if str(game.can_place_road(Vector2i(10, 14))).find("已有村庄主路") < 0:
		fail("可在固定村庄主路上重复铺路")
	if str(game.can_place_road(Vector2i(1, 9))) != "" or str(game.can_place_road(Vector2i(4, 9))) != "":
		fail("桥梁两岸的桥头不能铺路")

	var cell := Vector2i(11, 14)
	var wood_before := int(game.wood)
	game.add_road(cell)
	if not game.roads.has(cell) or game.road_root.get_child_count() <= 0:
		fail("道路没有加入独立道路数据与场景")
	if int(game.wood) != wood_before - int(game.ROAD_WOOD_COST):
		fail("铺路没有按每格成本扣除木材")
	if game.occupied.has(cell) or game.buildings.size() != 1:
		fail("铺路污染了建筑占用或建筑列表")
	if str(game.can_place("house", cell)).find("道路") < 0:
		fail("普通建筑可覆盖既有道路")
	var duplicate_count := int(game.roads.size())
	game.add_road(cell)
	if game.roads.size() != duplicate_count:
		fail("同一道路格可以重复添加")
	game.remove_road(cell, true)
	if game.roads.has(cell) or int(game.wood) != wood_before:
		fail("拆路没有移除道路并返还每格木材")


func check_connectivity_and_bridge(game) -> void:
	prepare_empty(game, 0)
	game.wood = 100
	game.add_road(Vector2i(11, 14), true)
	game.add_road(Vector2i(12, 14), true)
	if not game.is_road_connected(Vector2i(11, 14)) or not game.is_road_connected(Vector2i(12, 14)):
		fail("正交接入村庄主路的连续道路未识别为联网")
	var main_road_join: Node3D = game.create_road_model(Vector2i(11, 14))
	var leftmost_surface := 0.0
	for child in main_road_join.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			leftmost_surface = minf(leftmost_surface, child.position.x - child.mesh.size.x * 0.5)
	# Cell centres are two world units apart and the authored street is 1.1m
	# wide, so the player road must reach x=-1.45 locally to meet its edge.
	if leftmost_surface > -1.40:
		fail("玩家道路与固定村庄主路存在明显视觉断缝：最远仅到 %.2f" % leftmost_surface)
	main_road_join.free()
	game.add_road(Vector2i(8, 8), true)
	if game.is_road_connected(Vector2i(8, 8)):
		fail("与主路分离的孤立道路被错误识别为联网")
	game.remove_road(Vector2i(11, 14), false)
	if game.is_road_connected(Vector2i(12, 14)):
		fail("道路断开后远端仍保持联网")

	# Connect the right bank to the main street.  The fixed bridge must create a
	# single graph edge between the two bank-access cells without player roads on
	# the water tiles themselves.
	prepare_empty(game, 0)
	for x in range(4, 11):
		if x == 10:
			continue
		game.add_road(Vector2i(x, 9), true)
	game.add_road(Vector2i(1, 9), true)
	if not game.is_road_connected(Vector2i(4, 9)):
		fail("村庄侧桥头没有接通主路")
	if not game.is_road_connected(Vector2i(1, 9)):
		fail("道路网络不能通过现有桥梁连通两岸")
	if game.roads.has(Vector2i(2, 9)) or game.roads.has(Vector2i(3, 9)):
		fail("桥梁连通错误要求在水面创建玩家道路")


func check_transport_eligibility_and_cap(game) -> void:
	prepare_empty(game, 6)
	game.population = 50
	game.food = 100
	game.coins = 100
	game.wood = 100
	# A road branch beside the lumber yard, connected to the fixed main road.
	for x in range(11, 14):
		game.add_road(Vector2i(x, 14), true)
	game.add_building("lumber", Vector2i(14, 14), true)
	game.assign_workers()
	var connected: Dictionary = game.buildings[0]
	connected.last_running = true
	connected.assigned_workers = 1
	if int(game.road_bonus_for_building(connected)) != 0:
		fail("半员农田或伐木场错误获得道路运输收益")
	connected.assigned_workers = int(game.BUILDINGS.lumber.workers)
	if int(game.road_bonus_for_building(connected)) != 1:
		fail("联网且运行中的伐木场没有获得道路运输收益")
	connected.last_running = false
	if int(game.road_bonus_for_building(connected)) != 0:
		fail("未运行建筑仍获得道路运输收益")
	connected.last_running = true
	connected.enabled = false
	# The settlement marks paused/failed sites as not running during settlement;
	# also assert the public status text explains the connected reward.
	if str(game.building_road_status_text(connected)).find("已接通村庄主路") < 0:
		fail("建筑详情没有明确说明道路联网状态")
	connected.enabled = true

	game.add_building("house", Vector2i(13, 13), true)
	var passive: Dictionary = game.buildings[1]
	passive.last_running = true
	if int(game.road_bonus_for_building(passive)) != 0:
		fail("非生产建筑错误获得道路运输收益")

	game.add_building("lumber", Vector2i(14, 8), true)
	var disconnected: Dictionary = game.buildings[2]
	disconnected.last_running = true
	if int(game.road_bonus_for_building(disconnected)) != 0:
		fail("只运行但未邻接联网道路的建筑获得运输收益")

	# Exercise the city-wide cap with seven eligible synthetic running records.
	# They all point to the same connected branch, which is sufficient here: the
	# cap is per operating building, not per road tile.
	for index in range(7):
		game.buildings.append({
			"id": 100 + index, "type": "academy", "cell": Vector2i(14, 14),
			"node": null, "enabled": true, "assigned_workers": 3, "last_running": true,
		})
	if int(game.daily_road_transport_income()) != int(game.ROAD_TRANSPORT_COIN_CAP):
		fail("道路运输收益没有按全城上限封顶")


func check_daily_settlement_and_copy(game) -> void:
	prepare_empty(game, 6)
	game.day = 2
	game.population = 4
	game.food = 50
	game.coins = 100
	game.wood = 0
	for x in range(11, 14):
		game.add_road(Vector2i(x, 14), true)
	game.add_building("lumber", Vector2i(14, 14), true)
	game.assign_workers()
	game.next_day()
	# 2 population tax + 2 basic trade + 1 road transport - 1 maintenance.
	if int(game.coins) != 104:
		fail("道路运输没有进入实际日结铜钱：期望104，实际%d" % game.coins)
	var settlement := str(game.message_label.text)
	for phrase in ["道路运输", "铜钱 +1", "联网且正常运行", "上限 +6"]:
		if settlement.find(phrase) < 0:
			fail("日结说明缺少“%s”：%s" % [phrase, settlement])
	game.show_inspector(int(game.buildings[0].id))
	await process_frame
	await process_frame
	var details := str(game.inspector_body.text)
	for phrase in ["道路", "村庄主路", "正常运行时铜钱 +1/日"]:
		if details.find(phrase) < 0:
			fail("生产建筑详情缺少“%s”：%s" % [phrase, details])
	check_inside_viewport(game.inspector, "道路加成建筑详情")
	if game.inspector.get_global_rect().intersects(game.region_panel.get_global_rect()):
		fail("道路加成建筑详情与右侧目标栏重叠")


func check_cancel_select_and_demolish(game) -> void:
	prepare_empty(game, 0)
	game.wood = 20
	game.select_road_tool()
	var roads_before := int(game.roads.size())
	var wood_before := int(game.wood)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(600, 400)
	game._unhandled_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	release.position = press.position
	game._unhandled_input(release)
	if game.road_tool_selected or game.drag_button != -1:
		fail("右键短按没有取消铺路模式")
	if game.roads.size() != roads_before or int(game.wood) != wood_before:
		fail("右键取消铺路意外创建道路或扣除木材")

	var cell := Vector2i(11, 14)
	game.add_road(cell, true)
	game.show_road_inspector(cell)
	await process_frame
	if not game.inspector.visible or game.selected_road_cell != cell or game.selected_building_id != -1:
		fail("选中道路没有打开独立道路详情")
	var detail_text := str(game.inspector_body.text)
	for phrase in ["连接村庄主路", "农田", "伐木场", "工坊", "集市", "书院", "拆除返还"]:
		if detail_text.find(phrase) < 0:
			fail("道路详情缺少“%s”：%s" % [phrase, detail_text])
	if str(game.inspector_demolish_button.text).find("拆除道路") < 0:
		fail("道路详情没有明确的拆除操作")
	check_inside_viewport(game.inspector, "道路详情")
	wood_before = int(game.wood)
	game.demolish_selected()
	if game.roads.has(cell) or game.inspector.visible or game.selected_road_cell != Vector2i(-1, -1):
		fail("选中道路后无法拆除或没有关闭详情")
	if int(game.wood) != wood_before + int(game.ROAD_WOOD_COST):
		fail("拆除道路没有返还木材")


func check_v4_roundtrip_and_v3_migration(game) -> void:
	prepare_empty(game, 0)
	game.wood = 80
	for cell in [Vector2i(11, 14), Vector2i(12, 14), Vector2i(8, 8)]:
		game.add_road(cell, true)
	game.save_game(false)
	var saved := read_save()
	if int(saved.get("version", 0)) != 4:
		fail("道路存档没有升级到 v4")
	if typeof(saved.get("roads")) != TYPE_ARRAY or saved.roads.size() != 3:
		fail("v4 存档没有完整写入道路坐标")
	game.load_game(false)
	if game.roads.size() != 3 or not game.roads.has(Vector2i(11, 14)) or not game.roads.has(Vector2i(8, 8)):
		fail("v4 存档读取后道路不完整")

	write_save({
		"version": 3, "map_region_level": 0, "day": 2,
		"wood": 80, "food": 40, "coins": 60, "population": 4,
		"happiness": 60, "low_happiness_days": 0, "stable_days": 0,
		"maintenance_debt": 0, "next_id": 2, "ended": "",
		"buildings": [{"id": 1, "type": "house", "x": 9, "z": 9, "enabled": true}],
		# Legacy formats never owned road state.  Even a stray field must be
		# ignored instead of importing unvalidated future-version data.
		"roads": [{"x": 11, "z": 14}],
	})
	game.load_game(false)
	if not game.roads.is_empty():
		fail("v3 旧存档迁移后没有默认使用空道路列表")
	game.save_game(false)
	var migrated := read_save()
	if int(migrated.get("version", 0)) != 4 or typeof(migrated.get("roads")) != TYPE_ARRAY or not migrated.roads.is_empty():
		fail("v3 旧存档没有迁移为带空道路列表的 v4")

	var valid_base: Dictionary = migrated.duplicate(true)
	valid_base.roads = [{"x": 11, "z": 14}]
	if str(game.validate_save_data(valid_base)) != "":
		fail("合法 v4 道路存档被拒绝：%s" % game.validate_save_data(valid_base))
	for invalid_case in [
		{"label": "越界", "roads": [{"x": -1, "z": 8}]},
		{"label": "水面", "roads": [{"x": 2, "z": 8}]},
		{"label": "锁区", "roads": [{"x": 10, "z": 20}]},
		{"label": "建筑重叠", "roads": [{"x": 9, "z": 9}]},
		{"label": "重复", "roads": [{"x": 11, "z": 14}, {"x": 11, "z": 14}]},
	]:
		var invalid: Dictionary = valid_base.duplicate(true)
		invalid.roads = invalid_case.roads
		if str(game.validate_save_data(invalid)) == "":
			fail("v4 存档校验没有拒绝道路%s" % invalid_case.label)


func prepare_empty(game, region_level: int) -> void:
	for child in game.building_root.get_children():
		child.queue_free()
	for child in game.road_root.get_children():
		child.queue_free()
	game.buildings.clear()
	game.occupied.clear()
	game.roads.clear()
	game.next_id = 1
	game.map_region_level = region_level
	game.day = 2
	game.wood = 100
	game.food = 100
	game.coins = 100
	game.population = 4
	game.happiness = 60
	game.low_happiness_days = 0
	game.stable_days = 0
	game.maintenance_debt = 0
	game.ended = ""
	game.day_settling = false
	game.time_paused = true
	game.selected_type = ""
	game.road_tool_selected = false
	game.selected_building_id = -1
	game.selected_road_cell = Vector2i(-1, -1)
	game.inspector.visible = false
	game.clear_ghost()


func check_inside_viewport(control: Control, label: String) -> void:
	var rect := control.get_global_rect()
	if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > VIEWPORT_SIZE.x + 1.0 or rect.end.y > VIEWPORT_SIZE.y + 1.0:
		fail("%s超出1366x768视口：%s" % [label, rect])


func read_save() -> Dictionary:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		fail("无法读取道路验收存档")
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		fail("道路验收存档不是字典")
		return {}
	return parsed


func write_save(data: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		fail("无法写入道路验收存档")
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func preserve_save_file() -> void:
	original_save_exists = FileAccess.file_exists(SAVE_PATH)
	if not original_save_exists:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		original_save_text = file.get_as_text()


func restore_save_file() -> void:
	if original_save_exists:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_string(original_save_text)
		return
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func fail(message: String) -> void:
	failures.append(message)
	push_error("ROAD_GAMEPLAY_ACCEPTANCE_FAILED: " + message)


func finish() -> void:
	if failures.is_empty():
		print("ROAD_GAMEPLAY_ACCEPTANCE_OK: independent road tool, placement gates, bridge BFS, running-only transport income, daily cap, UI, demolition, v4 persistence")
		quit(0)
	else:
		print("ROAD_GAMEPLAY_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
