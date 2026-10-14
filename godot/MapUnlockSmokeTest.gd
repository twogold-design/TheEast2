extends SceneTree

const SAVE_PATH := "res://saves/savegame.json"

var original_save_exists := false
var original_save_text := ""
var save_snapshot_ready := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	preserve_save_file()
	var scene := load("res://godot/Main.tscn") as PackedScene
	if scene == null:
		fail("无法加载主场景")
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
	print("MAP_UNLOCK_SMOKE_OK: 48x48, 7 regions, day-one unlocks, rewards, goal chain, v1/v2 saves")
	quit(0)

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
	if header.find("第一章") < 0 or header.find("进度") < 0 or header.find("当前") < 0 or header.find("农田") < 0:
		fail("顶栏没有明确显示第一章进度和当前农田任务：%s" % header)
		return
	for keyword in ["北坡梯田", "当前任务", "费用", "奖励", "200", "20"]:
		if panel.find(keyword) < 0:
			fail("复兴目标面板缺少关键词 %s" % keyword)
			return
	game.add_building("farm", Vector2i(4, 10), true)
	game.update_ui()
	if str(game.goal_label.text).find("茅舍") < 0:
		fail("完成农田后当前任务没有切换到住房")
		return
	game.add_building("house", Vector2i(8, 8), true)
	game.update_ui()
	if str(game.goal_label.text).find("居民迁入") < 0 or str(game.goal_label.text).find("4/8") < 0:
		fail("补足住房后当前任务没有切换到人口迁入")
		return
	game.remove_building_by_id(2, false)
	game.remove_building_by_id(3, false)

func check_unlock_ladder(game) -> void:
	game.reset_game(false)
	game.day = 1
	game.population = 8
	game.add_building("farm", Vector2i(4, 10), true)
	game.wood = 100
	game.food = 40
	game.unlock_next_region()
	if game.map_region_level != 1 or game.wood != 50 or game.food != 45:
		fail("第一章扣费或20粮奖励错误")
		return
	if str(game.goal_label.text).find("第二章") < 0 or str(game.region_body.text).find("40木奖励") < 0:
		fail("开拓后没有立即切换第二章及奖励预告")
		return

	game.day = 1
	game.population = 12
	game.add_building("lumber", Vector2i(14, 10), true)
	game.add_building("lumber", Vector2i(15, 10), true)
	game.add_building("warehouse", Vector2i(6, 10), true)
	game.wood = 100
	game.food = 50
	game.unlock_next_region()
	if game.map_region_level != 2 or game.wood != 50 or game.food != 20:
		fail("第二章扣费或40木奖励错误")
		return

	game.day = 1
	game.population = 18
	game.happiness = 65
	game.add_building("workshop", Vector2i(7, 10), true)
	game.wood = 150
	game.food = 100
	game.unlock_next_region()
	if game.map_region_level != 3 or game.wood != 10 or game.food != 50 or game.happiness != 70:
		fail("第三章扣费或幸福奖励错误")
		return

	game.day = 1
	game.population = 24
	game.add_building("farm", Vector2i(4, 11), true)
	game.add_building("farm", Vector2i(4, 12), true)
	game.add_building("warehouse", Vector2i(8, 10), true)
	game.wood = 200
	game.food = 100
	game.unlock_next_region()
	if game.map_region_level != 4 or game.wood != 20 or game.food != 80:
		fail("第四章扣费或50粮奖励错误")
		return

	game.day = 1
	game.population = 32
	game.happiness = 70
	game.add_building("lumber", Vector2i(20, 10), true)
	game.add_building("workshop", Vector2i(9, 10), true)
	game.add_building("warehouse", Vector2i(10, 10), true)
	game.wood = 250
	game.food = 150
	game.unlock_next_region()
	if game.map_region_level != 5 or game.wood != 90 or game.food != 50:
		fail("第五章扣费或80木奖励错误")
		return

	game.day = 1
	game.population = 40
	game.happiness = 75
	game.add_building("workshop", Vector2i(11, 10), true)
	game.add_building("warehouse", Vector2i(12, 10), true)
	game.add_building("warehouse", Vector2i(13, 10), true)
	for x in range(5, 15):
		game.add_building("house", Vector2i(x, 12), true)
	game.wood = 350
	game.food = 200
	game.unlock_next_region()
	if game.map_region_level != 6 or game.wood != 30 or game.food != 140 or game.happiness != 80:
		fail("第六章扣费或新都奖励错误")
		return
	if game.can_place("house", Vector2i(47, 47)) != "":
		fail("天际新都开放后仍不可建造")

func check_save_compatibility(game) -> void:
	game.save_game(false)
	var saved := read_save(game.save_path())
	if int(saved.get("version", 0)) != 2 or int(saved.get("map_region_level", -1)) != 6:
		fail("新存档没有保持v2格式或区域等级")
		return
	write_save(game.save_path(), {
		"version": 1, "day": 2, "wood": 100, "food": 40, "population": 4,
		"happiness": 60, "low_happiness_days": 0, "next_id": 2,
		"buildings": [{"id": 1, "type": "house", "x": 9, "z": 9}]
	})
	game.load_game()
	if game.map_region_level != 0 or game.day != 2:
		fail("v1存档兼容失败")
		return
	write_save(game.save_path(), {
		"version": 2, "map_region_level": 3, "day": 20, "wood": 100, "food": 40, "population": 4,
		"happiness": 60, "low_happiness_days": 0, "next_id": 2, "ended": "",
		"buildings": [{"id": 1, "type": "house", "x": 9, "z": 9}]
	})
	game.load_game()
	if game.map_region_level != 3 or str(game.goal_label.text).find("第四章") < 0:
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

func fail(message: String) -> void:
	restore_save_file()
	push_error("MAP_UNLOCK_SMOKE_FAILED: " + message)
	quit(1)
