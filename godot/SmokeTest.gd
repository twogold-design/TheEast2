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
	var asset_sources := count_asset_sources(game)
	if asset_sources.realistic == 0 or asset_sources.fallback != 0:
		fail("主场景必须默认使用写实资源且不能出现低模回退")
		return

	if game.day != 1 or game.wood != 100 or game.food != 40 or game.coins != 60 or game.population != 4 or game.happiness != 60 or game.stable_days != 0:
		fail("初始经营数值不正确")
		return
	if game.buildings.size() != 1:
		fail("初始建筑数量不正确")
		return
	if game.can_place("farm", Vector2i(10, 10)) == "":
		fail("远离河流的农田应被拒绝")
		return
	if game.can_place("house", Vector2i(2, 10)) == "":
		fail("河道上的建筑应被拒绝")
		return
	if game.can_place("farm", Vector2i(4, 10)) != "":
		fail("河岸农田应允许建造")
		return
	if game.can_place("lumber", Vector2i(14, 10)) != "":
		fail("林缘伐木场应允许建造")
		return
	if game.wood_capacity() != 100 or game.food_capacity() != 100:
		fail("基础库存容量应为 100")
		return

	var wood_before: int = game.wood
	var coins_before: int = game.coins
	game.add_building("house", Vector2i(8, 8))
	if game.wood != wood_before - int(game.BUILDINGS.house.cost) or game.coins != coins_before - int(game.BUILDINGS.house.coin_cost):
		fail("建造没有同时扣除木材与铜钱")
		return
	game.next_day()
	if game.day != 2:
		fail("下一日没有推进日期")
		return

	game.save_game(false)
	if not FileAccess.file_exists("res://saves/savegame.json"):
		fail("项目内存档未生成")
		return
	var saved_day: int = game.day
	var saved_coins: int = game.coins
	game.day = 99
	game.coins = 0
	game.load_game()
	if game.day != saved_day or game.coins != saved_coins:
		fail("读取存档没有恢复日期与铜钱")
		return
	var valid_count: int = game.buildings.size()
	var bad_file := FileAccess.open("res://saves/savegame.json", FileAccess.WRITE)
	bad_file.store_string(JSON.stringify({
		"version": 1, "day": 99, "wood": 10, "food": 10, "population": 4,
		"happiness": 60, "low_happiness_days": 0, "next_id": 2,
		"buildings": [
			{"id": 1, "type": "house", "x": 2, "z": 10},
			{"id": 1, "type": "house", "x": 2, "z": 10}
		]
	}))
	bad_file.close()
	game.load_game()
	if game.day != saved_day or game.buildings.size() != valid_count:
		fail("损坏存档改变了当前城镇")
		return

	game.reset_game(false)
	restore_save_file()
	print("SMOKE_TEST_OK: scene, build rules, economy, save and load")
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

func fail(message: String) -> void:
	restore_save_file()
	push_error("SMOKE_TEST_FAILED: " + message)
	quit(1)

func count_asset_sources(node: Node) -> Dictionary:
	var result := {"realistic": 0, "fallback": 0}
	var source := str(node.get_meta("asset_source", ""))
	if source == "realistic":
		result.realistic += 1
	elif source == "fallback":
		result.fallback += 1
	for child in node.get_children():
		var nested := count_asset_sources(child)
		result.realistic += nested.realistic
		result.fallback += nested.fallback
	return result
