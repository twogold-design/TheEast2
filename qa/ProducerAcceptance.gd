extends SceneTree

const SAVE_PATH := "res://saves/savegame.json"

var original_save_exists := false
var original_save_text := ""
var save_snapshot_ready := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	preserve_save_file()
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		fail("主场景无法加载")
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.reset_game(false)
	game.time_paused = true

	# Victory path: the expanded map must be fully open before the settlement can win.
	game.map_region_level = 6
	game.day = 3
	game.population = 45
	game.happiness = 100
	for x in range(5, 10):
		game.add_building("warehouse", Vector2i(x, 8), true)
	game.wood = 200
	game.food = 250
	game.next_day()
	if game.ended != "win" or game.end_layer == null:
		fail("胜利路径没有正确结束本局")
		return

	# Food-loss path: an empty granary must immediately lose on the next settlement.
	game.reset_game(false)
	game.food = 0
	game.next_day()
	if game.ended != "lose" or game.end_layer == null:
		fail("断粮失败路径没有正确结束本局")
		return

	# Stability path: a minimal sustainable settlement should run for 30 settlements.
	game.reset_game(false)
	game.add_building("farm", Vector2i(1, 1), true)
	game.add_building("lumber", Vector2i(14, 1), true)
	for index in range(30):
		game.next_day()
		if game.ended != "":
			fail("可持续聚落在第 %d 次结算意外结束" % (index + 1))
			return
	if game.day != 31 or game.food <= 0 or game.wood <= 0:
		fail("30 日稳定性状态异常")
		return

	game.reset_game(false)
	restore_save_file()
	print("PRODUCER_ACCEPTANCE_OK: win, food loss, 30-day stability")
	quit(0)

func preserve_save_file() -> void:
	original_save_exists = FileAccess.file_exists(SAVE_PATH)
	if not original_save_exists:
		save_snapshot_ready = true
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		fail("无法暂存验收前的存档")
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
	push_error("PRODUCER_ACCEPTANCE_FAILED: " + message)
	quit(1)
