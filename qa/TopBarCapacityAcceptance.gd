extends SceneTree

const VIEWPORT_SIZE := Vector2i(1366, 768)

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = VIEWPORT_SIZE
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		fail("主场景无法加载")
		finish()
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.reset_game(false)
	game.time_paused = true
	game.update_ui()
	await process_frame

	assert_status_text(game, [
		"第 1 日", "木材 100/100", "粮食 40/100", "铜钱 60", "人口 4/4", "幸福度 60"
	], "开局状态")

	# Four houses provide 16 beds.  The population readout must expose both
	# values without requiring the tooltip.
	for cell in [Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9)]:
		game.add_building("house", cell, true)
	game.population = 8
	game.update_ui()
	await process_frame
	assert_status_text(game, [
		"木材 100/100", "粮食 40/100", "铜钱 60", "人口 8/16", "幸福度 60"
	], "8/16 常用状态")
	if str(game.status_label.text).count("\n") != 1:
		fail("顶栏日期/时间与完整资源信息没有分成两行：%s" % game.status_label.text)
	check_top_bar_layout(game, "8/16 常用状态")

	# Use longer late-game values and the final chapter copy to catch horizontal
	# clipping that is not visible in the opening state.
	var extra_houses := [
		Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5),
		Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6),
	]
	for cell in extra_houses:
		game.add_building("house", cell, true)
	for cell in [Vector2i(13, 9), Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9)]:
		game.add_building("warehouse", cell, true)
	game.day = 999
	game.wood = 399
	game.food = 388
	game.coins = 999999
	game.population = 45
	game.happiness = 100
	game.map_region_level = game.REGION_DEFINITIONS.size() - 1
	game.update_ui()
	await process_frame
	assert_status_text(game, [
		"木材 399/400", "粮食 388/400", "铜钱 999999", "人口 45/48", "幸福度 100"
	], "后期长数值状态")
	check_top_bar_layout(game, "后期长数值状态")
	finish()

func assert_status_text(game, expected_terms: Array[String], context: String) -> void:
	var visible_text := str(game.status_label.text)
	for term in expected_terms:
		if visible_text.find(term) < 0:
			fail("%s缺少完整状态“%s”：%s" % [context, term, visible_text])
	var normalized := visible_text.replace("·", " ").replace("\n", " ").replace("\t", " ")
	for token in normalized.split(" ", false):
		if token in ["木", "粮", "钱", "人", "幸", "幸福"]:
			fail("%s仍使用孤立缩写“%s”：%s" % [context, token, visible_text])

func check_top_bar_layout(game, context: String) -> void:
	var top_row := game.find_child("TopRow", true, false) as HBoxContainer
	var top_title := game.find_child("TopTitle", true, false) as Label
	if top_row == null or top_title == null:
		fail("%s：找不到顶栏布局节点" % context)
		return
	var controls: Array[Control] = [top_title, game.status_label, game.goal_label, game.settings_button]
	for control in controls:
		var rect := control.get_global_rect()
		if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > VIEWPORT_SIZE.x + 1.0 or rect.end.y > VIEWPORT_SIZE.y + 1.0:
			fail("%s：%s 超出 1366x768 视口：%s" % [context, control.name, rect])
		var minimum := control.get_combined_minimum_size()
		if minimum.x > control.size.x + 1.0 or minimum.y > control.size.y + 1.0:
			fail("%s：%s 内容被裁切，需要 %s，实际 %s" % [context, control.name, minimum, control.size])
	var row_rect := top_row.get_global_rect()
	if row_rect.end.x > VIEWPORT_SIZE.x + 1.0 or row_rect.end.y > VIEWPORT_SIZE.y + 1.0:
		fail("%s：顶栏容器超出视口：%s" % [context, row_rect])
	if top_row.get_combined_minimum_size().x > top_row.size.x + 1.0:
		fail("%s：顶栏总宽度不足，需要 %.0f，实际 %.0f" % [context, top_row.get_combined_minimum_size().x, top_row.size.x])

func fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func finish() -> void:
	if failures.is_empty():
		print("TOP_BAR_CAPACITY_ACCEPTANCE_OK: full resource labels, capacities, and unclipped 1366x768 layout")
		quit(0)
	else:
		print("TOP_BAR_CAPACITY_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
