extends SceneTree

## Release acceptance for the 48x48 map, seven regions and v3 economy migration.

const SAVE_PATH := "res://saves/savegame.json"

var failures: Array[String] = []
var original_save_exists := false
var original_save_text := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	preserve_save_file()
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		fail("主场景无法加载")
		restore_save_file()
		finish()
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.reset_game(false)
	game.time_paused = true
	await process_frame
	await process_frame
	check_region_layout(game)
	check_locked_area(game)
	check_late_region_rules(game)
	check_save_migration(game)
	check_victory_gate(game)
	game.reset_game(false)
	restore_save_file()
	finish()

func preserve_save_file() -> void:
	original_save_exists = FileAccess.file_exists(SAVE_PATH)
	if not original_save_exists:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		fail("无法暂存验收前的存档")
		return
	original_save_text = file.get_as_text()

func restore_save_file() -> void:
	if original_save_exists:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file == null:
			fail("无法恢复验收前的存档")
			return
		file.store_string(original_save_text)
		return
	if FileAccess.file_exists(SAVE_PATH):
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if error != OK:
			fail("无法清理验收生成的临时存档")

func check_region_layout(game) -> void:
	if int(game.GRID_SIZE) != 48 or game.REGION_DEFINITIONS.size() != 7:
		fail("地图应为48x48且包含七区")
		return
	var counts := [0, 0, 0, 0, 0, 0, 0]
	for z in range(48):
		for x in range(48):
			var level := int(game.region_level_for_cell(Vector2i(x, z)))
			if level < 0 or level > 6:
				fail("存在未归属地图格：%d,%d" % [x, z])
				return
			counts[level] += 1
	if counts != [400, 200, 200, 100, 432, 540, 432]:
		fail("七区面积错误：%s" % [counts])
	for z in range(30):
		for x in range(30):
			var expected := 3 if x >= 20 and z >= 20 else (2 if x >= 20 else (1 if z >= 20 else 0))
			if int(game.region_level_for_cell(Vector2i(x, z))) != expected:
				fail("旧30x30坐标含义变化：%d,%d" % [x, z])
				return

func check_locked_area(game) -> void:
	for sample in [Vector2i(30, 0), Vector2i(0, 30), Vector2i(30, 24)]:
		if str(game.can_place("house", sample)) == "":
			fail("锁定新区允许建造：%s" % sample)
	if game.region_visual_root.get_child_count() != 6:
		fail("锁区视觉没有按区域合并")
	for region_node in game.region_visual_root.get_children():
		var fog_count := 0
		for child in region_node.get_children():
			if child is MultiMeshInstance3D:
				fog_count += 1
		if fog_count != 1:
			fail("锁区 %s 没有使用单个MultiMesh雾层" % region_node.name)

func check_late_region_rules(game) -> void:
	game.reset_game(false)
	game.map_region_level = 4
	game.day = 1
	# Chapter five is intentionally a multi-system gate: population and beds,
	# all four production chains, happiness, and the larger reserve cost.
	# reset_game already contributes one free house, so add nine more for 40
	# beds in total.
	var house_cells := [
		Vector2i(6, 12), Vector2i(7, 12), Vector2i(8, 12), Vector2i(9, 12),
		Vector2i(10, 12), Vector2i(11, 12), Vector2i(12, 12), Vector2i(13, 12),
		Vector2i(14, 12)
	]
	for cell in house_cells:
		game.add_building("house", cell, true)
	for cell in [Vector2i(1, 10), Vector2i(1, 11), Vector2i(1, 12), Vector2i(4, 10), Vector2i(4, 11)]:
		game.add_building("farm", cell, true)
	game.add_building("lumber", Vector2i(14, 8), true)
	game.add_building("lumber", Vector2i(14, 9), true)
	game.add_building("lumber", Vector2i(14, 10), true)
	game.add_building("lumber", Vector2i(15, 10), true)
	game.add_building("workshop", Vector2i(8, 8), true)
	game.add_building("workshop", Vector2i(9, 8), true)
	game.add_building("warehouse", Vector2i(10, 8), true)
	game.add_building("warehouse", Vector2i(11, 8), true)
	game.add_building("warehouse", Vector2i(12, 8), true)
	var requirement: Dictionary = game.REGION_REQUIREMENTS[5]
	var cost: Dictionary = game.REGION_UNLOCK_COSTS[5]
	game.population = int(requirement.population)
	game.happiness = int(requirement.happiness)
	game.stable_days = int(requirement.stable_days)
	game.wood = int(cost.wood)
	game.food = int(cost.food)
	game.coins = int(cost.coins)
	var new_type_reason := str(game.can_unlock_next_region())
	if new_type_reason.find("书院") < 0:
		fail("第五章没有要求使用随开拓解锁的书院：%s" % new_type_reason)
	# An academy in the old settlement satisfies the global building count, but
	# must not satisfy the East Plain investment gate.
	game.add_building("academy", Vector2i(8, 9), true)
	var local_gate_reason := str(game.can_unlock_next_region())
	if local_gate_reason.find("东原") < 0 or local_gate_reason.find("仓库") < 0:
		fail("第五章没有明确阻止只在旧区堆建筑：%s" % local_gate_reason)
	# At least one required warehouse must be built in the currently opened
	# fourth region, proving that a first-plot build stack cannot unlock chapter
	# five by global counts alone.
	game.add_building("warehouse", Vector2i(35, 8), true)
	var academy_local_reason := str(game.can_unlock_next_region())
	if academy_local_reason.find("东原") < 0 or academy_local_reason.find("书院") < 0:
		fail("第五章没有要求在东原落地书院：%s" % academy_local_reason)
	game.add_building("academy", Vector2i(35, 9), true)
	if str(game.can_unlock_next_region()) != "":
		fail("第五章条件齐备后仍不可开拓：%s" % game.can_unlock_next_region())
		return
	game.unlock_next_region()
	var reward: Dictionary = game.REGION_UNLOCK_REWARDS[5]
	if int(game.map_region_level) != 5 or int(game.wood) != int(reward.wood) or int(game.food) != int(reward.food) or int(game.coins) != int(reward.coins):
		fail("朔岭关田没有按木粮钱费用与奖励结算")
	if str(game.can_place("house", Vector2i(15, 40))) != "":
		fail("朔岭关田开放后普通地块不可建造")
	if str(game.can_place("house", Vector2i(30, 24))) == "":
		fail("天际新都在第六章前提前开放")

func check_save_migration(game) -> void:
	var target := str(game.save_path())
	write_save(target, {
		"version": 1, "day": 7, "wood": 80, "food": 30, "population": 4,
		"happiness": 60, "low_happiness_days": 0, "next_id": 2,
		"buildings": [{"id": 1, "type": "house", "x": 9, "z": 9}]
	})
	game.load_game()
	if int(game.map_region_level) != 0 or int(game.day) != 7:
		fail("v1存档读取未保持旧状态")
		return
	game.save_game(false)
	var migrated := read_save(target)
	if int(migrated.get("version", 0)) != 3 or int(migrated.get("map_region_level", -1)) != 0:
		fail("v1存档未迁移为v3")
	for field in ["coins", "stable_days", "maintenance_debt"]:
		if not migrated.has(field):
			fail("v3存档缺少经济字段：%s" % field)
	var migrated_buildings: Array = migrated.get("buildings", [])
	if migrated_buildings.is_empty() or not bool(migrated_buildings[0].get("enabled", false)):
		fail("旧建筑迁移后没有默认启用")

	write_save(target, {
		"version": 2, "map_region_level": 3, "day": 20, "wood": 80, "food": 30, "population": 4,
		"happiness": 60, "low_happiness_days": 0, "next_id": 2, "ended": "",
		"buildings": [{"id": 1, "type": "house", "x": 9, "z": 9}]
	})
	game.load_game()
	if int(game.map_region_level) != 3 or int(game.food) != 30 or int(game.coins) <= 0 or int(game.stable_days) != 0:
		fail("旧v2等级3存档没有兼容新的铜钱与稳定经营状态")
		return
	var before_day := int(game.day)
	write_save(target, {
		"version": 2, "map_region_level": 7, "day": 99, "wood": 80, "food": 30, "population": 4,
		"happiness": 60, "low_happiness_days": 0, "next_id": 2, "ended": "", "buildings": []
	})
	game.load_game()
	if int(game.day) != before_day or int(game.map_region_level) != 3:
		fail("非法等级存档没有被事务式拒绝")

func check_victory_gate(game) -> void:
	game.reset_game(false)
	for x in range(5, 10):
		game.add_building("warehouse", Vector2i(x, 8), true)
	for index in range(11):
		game.add_building("house", Vector2i(5 + index, 12), true)
	game.add_building("farm", Vector2i(1, 10), true)
	game.population = 45
	game.wood = 200
	game.food = 250
	game.coins = int(game.VICTORY_COINS)
	game.happiness = 100
	game.stable_days = int(game.VICTORY_STABLE_DAYS) - 1
	game.day = 3
	game.next_day()
	if str(game.ended) == "win":
		fail("全境未开放时提前胜利")
		return
	game.ended = ""
	game.map_region_level = 6
	game.day = 3
	game.population = 45
	game.wood = 200
	game.food = 250
	game.coins = int(game.VICTORY_COINS)
	game.happiness = 100
	game.stable_days = int(game.VICTORY_STABLE_DAYS) - 1
	game.next_day()
	if str(game.ended) != "win":
		fail("七境与最终数值满足后没有胜利")

func write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		fail("无法写入测试存档")
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()

func read_save(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		fail("无法读取测试存档")
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func fail(message: String) -> void:
	failures.append(message)
	push_error("MAP_EXPANSION_ACCEPTANCE_FAILED: " + message)

func finish() -> void:
	if failures.is_empty():
		print("MAP_EXPANSION_ACCEPTANCE_OK: 48x48, 7 regions, MultiMesh locks, v1/v2-to-v3 migration, coin/stability victory")
		quit(0)
	else:
		print("MAP_EXPANSION_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
