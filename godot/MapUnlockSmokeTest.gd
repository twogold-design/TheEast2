extends SceneTree

const SAVE_PATH := "res://saves/savegame.json"
const UNLOCK_MESSAGE_EXPECTATIONS := {
	1: ["北坡梯田已开放", "开拓奖励", "获得粮食 20", "获得铜钱 10"],
	2: ["东麓林场已开放", "开拓奖励", "获得木材 40", "获得铜钱 15"],
	3: ["云岫高台已开放", "开拓奖励", "获得铜钱 20", "幸福度 +5"],
	4: ["沧波东原已开放", "开拓奖励", "获得粮食 50", "获得铜钱 25"],
	5: ["朔岭关田已开放", "开拓奖励", "获得木材 80", "获得铜钱 30"],
	6: ["天际新都已开放", "开拓奖励", "获得粮食 80", "获得铜钱 40", "幸福度 +5"],
}

var original_save_exists := false
var original_save_text := ""
var save_snapshot_ready := false
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	preserve_save_file()
	var scene := load("res://godot/Main.tscn") as PackedScene
	if scene == null:
		fail("无法加载主场景")
		restore_save_file()
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.reset_game(false)
	game.time_paused = true
	await process_frame
	await process_frame
	check_map_layout(game)
	check_goal_guidance(game)
	check_unlock_ladder(game)
	check_save_compatibility(game)
	game.reset_game(false)
	restore_save_file()
	if failures.is_empty():
		print("MAP_UNLOCK_SMOKE_OK: 48x48, 7 regions, goal-only UI, unlock reward feedback, numeric stock/population/happiness gates, v1/v2-to-v4 saves")
		quit(0)
	else:
		print("MAP_UNLOCK_SMOKE_FAILED: %d issue(s)" % failures.size())
		quit(1)

func preserve_save_file() -> void:
	original_save_exists = FileAccess.file_exists(SAVE_PATH)
	if not original_save_exists:
		save_snapshot_ready = true
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	original_save_text = file.get_as_text()
	save_snapshot_ready = true

func restore_save_file() -> void:
	if not save_snapshot_ready:
		return
	if original_save_exists:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_string(original_save_text)
		return
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func check_map_layout(game) -> void:
	if game.GRID_SIZE != 48 or game.map_region_level != 0:
		fail("地图尺寸或初始区域等级不正确")
		return
	var counts := [0, 0, 0, 0, 0, 0, 0]
	for z in range(48):
		for x in range(48):
			var level: int = game.region_level_for_cell(Vector2i(x, z))
			if level < 0 or level > 6:
				fail("地图存在未归属格：%d,%d" % [x, z])
				return
			counts[level] += 1
	if counts != [400, 200, 200, 100, 432, 540, 432]:
		fail("七区面积错误：%s" % [counts])
		return
	var samples := {
		Vector2i(19, 19): 0, Vector2i(0, 20): 1, Vector2i(20, 0): 2,
		Vector2i(29, 29): 3, Vector2i(30, 23): 4, Vector2i(29, 47): 5,
		Vector2i(30, 24): 6, Vector2i(47, 47): 6
	}
	for cell in samples:
		if game.region_level_for_cell(cell) != samples[cell]:
			fail("区域边界错误：%s" % cell)
			return
	if game.region_visual_root.get_child_count() != 6:
		fail("初始锁区视觉应为每区一个合并节点")

func check_goal_guidance(game) -> void:
	var header := str(game.goal_label.text)
	var panel := str(game.region_title.text) + "\n" + str(game.region_body.text)
	if header.find("第一章") < 0 or header.find("安家河湾") < 0 or header.find("目标：") < 0 or header.find("开拓北坡") < 0:
		fail("顶栏没有明确显示第一章的固定目标：%s" % header)
		return
	for keyword in ["北坡梯田", "用途", "目标：", "人口 8", "幸福度 55", "木材 90", "粮食 60", "铜钱 45"]:
		if panel.find(keyword) < 0:
			fail("复兴目标面板缺少关键词 %s" % keyword)
			return
	var first_cost: Dictionary = game.REGION_UNLOCK_COSTS[1]
	for forbidden in [
		"费用", "奖励",
		"木材 %d" % int(first_cost.wood),
		"粮食 %d" % int(first_cost.food),
		"铜钱 %d" % int(first_cost.coins),
	]:
		if header.find(forbidden) >= 0 or panel.find(forbidden) >= 0:
			fail("常驻目标仍显示开拓费用或奖励“%s”：%s\n%s" % [forbidden, header, panel])
			return
	if has_visible_goal_progress(header + "\n" + panel):
		fail("可见目标仍显示进度、数字/数字或当前/要求：%s\n%s" % [header, panel])
		return
	var unlock_reason := str(game.can_unlock_next_region())
	if unlock_reason != "" and str(game.region_unlock_button.tooltip_text).find(unlock_reason) < 0:
		fail("不可开拓时按钮悬停没有说明首个阻碍")
		return
	if has_visible_goal_progress(str(game.goal_label.tooltip_text) + "\n" + str(game.region_body.tooltip_text) + "\n" + str(game.region_unlock_button.tooltip_text)):
		fail("目标悬停提示仍显示完成进度")
		return
	var fixed_header := header
	var fixed_panel := panel
	game.add_building("farm", Vector2i(4, 10), true)
	game.add_building("house", Vector2i(8, 8), true)
	game.population = 8
	game.happiness = 80
	game.wood = 100
	game.food = 100
	game.coins = 100
	game.stable_days = 8
	game.day = 20
	game.update_ui()
	var updated_panel := str(game.region_title.text) + "\n" + str(game.region_body.text)
	if str(game.goal_label.text) != fixed_header or updated_panel != fixed_panel:
		fail("同一章节内目标随条件完成发生变化")
		return
	game.remove_building_by_id(2, false)
	game.remove_building_by_id(3, false)

func check_unlock_ladder(game) -> void:
	for level in range(1, game.REGION_DEFINITIONS.size()):
		prepare_unlock_level(game, level)
		var standing_goal := "%s\n%s\n%s" % [game.goal_label.text, game.region_title.text, game.region_body.text]
		var standing_cost: Dictionary = game.REGION_UNLOCK_COSTS[level]
		for forbidden in [
			"费用", "奖励",
			"木材 %d" % int(standing_cost.wood),
			"粮食 %d" % int(standing_cost.food),
			"铜钱 %d" % int(standing_cost.coins),
		]:
			if standing_goal.find(forbidden) >= 0:
				fail("第%d级常驻目标仍显示开拓信息“%s”：%s" % [level, forbidden, standing_goal])
				return
		if str(game.message_label.text).find("开拓奖励") >= 0:
			fail("第%d级尚未开拓就显示奖励提示：%s" % [level, game.message_label.text])
			return
		var reason := str(game.can_unlock_next_region())
		if reason != "":
			fail("第%d级条件齐备后仍不可开拓：%s" % [level, reason])
			return
		var cost: Dictionary = game.REGION_UNLOCK_COSTS[level]
		var reward: Dictionary = game.REGION_UNLOCK_REWARDS[level]
		var happiness_before := int(game.happiness)
		game.unlock_next_region()
		var requirement: Dictionary = game.REGION_REQUIREMENTS[level]
		var remaining_wood := int(requirement.wood) - int(cost.wood)
		var expected_wood := remaining_wood + mini(maxi(0, int(game.wood_capacity()) - remaining_wood), int(reward.wood))
		var remaining_food := int(requirement.food) - int(cost.food)
		var expected_food := remaining_food + mini(maxi(0, int(game.food_capacity()) - remaining_food), int(reward.food))
		var expected_happiness := mini(100, happiness_before + int(reward.happiness))
		if int(game.map_region_level) != level:
			fail("第%d级开拓后区域等级没有推进" % level)
			return
		if int(game.wood) != expected_wood or int(game.food) != expected_food or int(game.coins) != int(requirement.coins) - int(cost.coins) + int(reward.coins) or int(game.happiness) != expected_happiness:
			fail("第%d级没有按木材%d、粮食%d、铜钱%d费用及奖励结算" % [level, cost.wood, cost.food, cost.coins])
			return
		var unlock_message := str(game.message_label.text)
		for expected in UNLOCK_MESSAGE_EXPECTATIONS[level]:
			if unlock_message.find(str(expected)) < 0:
				fail("第%d级开拓成功提示缺少“%s”：%s" % [level, expected, unlock_message])
				return
		var persistent_goal := "%s\n%s\n%s" % [game.goal_label.text, game.region_title.text, game.region_body.text]
		for forbidden in ["费用", "奖励"]:
			if persistent_goal.find(forbidden) >= 0:
				fail("第%d级开拓后“%s”仍进入常驻目标：%s" % [level, forbidden, persistent_goal])
				return
		if level < game.REGION_DEFINITIONS.size() - 1 and str(game.goal_label.text).find(game.CAMPAIGN_CHAPTERS[level]) < 0:
			fail("第%d级开拓后没有立即切换下一章" % level)
			return
	game.wood = int(game.BUILDINGS.house.cost)
	game.coins = int(game.BUILDINGS.house.coin_cost)
	if game.can_place("house", Vector2i(47, 47)) != "":
		fail("天际新都开放后仍不可建造")

func prepare_unlock_level(game, level: int) -> void:
	game.reset_game(false)
	game.time_paused = true
	game.map_region_level = level - 1
	var requirement: Dictionary = game.REGION_REQUIREMENTS[level]
	# Regional gates use current metrics, never a prescribed building mix.
	for key in requirement:
		game.set(key, requirement[key])
	game.stable_days = 0
	game.maintenance_debt = 0
	game.update_ui()

func check_save_compatibility(game) -> void:
	game.save_game(false)
	var saved := read_save(game.save_path())
	if int(saved.get("version", 0)) != 4 or int(saved.get("map_region_level", -1)) != 6:
		fail("新存档没有保持v4格式或区域等级")
		return
	for field in ["coins", "stable_days", "maintenance_debt"]:
		if not saved.has(field):
			fail("v4存档缺少经济字段：%s" % field)
			return
	if typeof(saved.get("roads")) != TYPE_ARRAY:
		fail("v4存档缺少道路列表")
	write_save(game.save_path(), {
		"version": 1, "day": 2, "wood": 100, "food": 40, "population": 4,
		"happiness": 60, "low_happiness_days": 0, "next_id": 2,
		"buildings": [{"id": 1, "type": "house", "x": 9, "z": 9}]
	})
	game.load_game()
	if game.map_region_level != 0 or game.day != 2 or game.coins <= 0 or game.stable_days != 0 or not game.roads.is_empty():
		fail("v1存档兼容失败")
		return
	write_save(game.save_path(), {
		"version": 2, "map_region_level": 3, "day": 20, "wood": 100, "food": 40, "population": 4,
		"happiness": 60, "low_happiness_days": 0, "next_id": 2, "ended": "",
		"buildings": [{"id": 1, "type": "house", "x": 9, "z": 9}]
	})
	game.load_game()
	if game.map_region_level != 3 or game.coins <= 0 or game.stable_days != 0 or not game.roads.is_empty() or str(game.goal_label.text).find("第四章") < 0:
		fail("旧v2等级3存档未进入第四章")

func write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	file.close()

func read_save(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func has_visible_goal_progress(text_value: String) -> bool:
	if text_value.find("进度") >= 0:
		return true
	var ratio_regex := RegEx.new()
	ratio_regex.compile("\\d+\\s*/\\s*\\d+")
	if ratio_regex.search(text_value) != null:
		return true
	var percentage_regex := RegEx.new()
	percentage_regex.compile("\\d+\\s*%")
	if percentage_regex.search(text_value) != null:
		return true
	var current_required_regex := RegEx.new()
	current_required_regex.compile("当前[^\\n]*要求")
	return current_required_regex.search(text_value) != null

func fail(message: String) -> void:
	failures.append(message)
	push_error("MAP_UNLOCK_SMOKE_FAILED: " + message)
