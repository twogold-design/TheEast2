extends SceneTree

## Producer acceptance for the 48x48 world and the seven-chapter goal chain.
## The checks read the live Main scene so UI copy and gameplay data cannot drift
## without failing the same release gate.

const VIEWPORT_SIZE := Vector2i(1366, 768)
const SAVE_PATH := "res://saves/savegame.json"
const EXPECTED_AREAS := [400, 200, 200, 100, 432, 540, 432]
const EXPECTED_CHAPTER_TOTALS := [3, 4, 4, 4, 5, 6]
const CHAPTER_EXPECTATIONS := [
	["第一章", "安家河湾", "北坡梯田", "200", "20"],
	["第二章", "木通东麓", "东麓林场", "200", "40"],
	["第三章", "百工登台", "云岫高台", "100", "幸福"],
	["第四章", "东原成镇", "沧波东原", "432", "50"],
	["第五章", "北关兴业", "朔岭关田", "540", "80"],
	["第六章", "新都落成", "天际新都", "432", "80"],
]

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
		finish()
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	if game.get_script() == null or not game.has_method("reset_game"):
		fail("主场景脚本未成功加载")
		finish()
		return

	check_map_layout(game)
	await check_goal_panel_at_1366(game)
	check_current_task_priority(game)
	check_chapter_previews(game)
	check_first_unlock_reward_and_transition(game)

	game.reset_game(false)
	await process_frame
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

func check_map_layout(game) -> void:
	if int(game.GRID_SIZE) != 48:
		fail("地图尺寸应为 48x48，实际为 %dx%d" % [game.GRID_SIZE, game.GRID_SIZE])
		return
	if game.REGION_DEFINITIONS.size() != 7:
		fail("目标链应有七个区域，实际为 %d 个" % game.REGION_DEFINITIONS.size())
		return
	var counts := [0, 0, 0, 0, 0, 0, 0]
	for z in range(48):
		for x in range(48):
			var level := int(game.region_level_for_cell(Vector2i(x, z)))
			if level < 0 or level >= counts.size():
				fail("存在未归属地图格：%d,%d" % [x, z])
				return
			counts[level] += 1
	if counts != EXPECTED_AREAS:
		fail("七区面积错误：%s，应为 %s" % [counts, EXPECTED_AREAS])

	# The complete old 30x30 map must retain its original region meaning.
	for z in range(30):
		for x in range(30):
			var expected := 0
			if x >= 20 and z >= 20:
				expected = 3
			elif x >= 20:
				expected = 2
			elif z >= 20:
				expected = 1
			if int(game.region_level_for_cell(Vector2i(x, z))) != expected:
				fail("旧 30x30 坐标含义发生变化：%d,%d" % [x, z])
				return
	var boundary_samples := {
		Vector2i(30, 0): 4, Vector2i(47, 23): 4,
		Vector2i(0, 30): 5, Vector2i(29, 47): 5,
		Vector2i(30, 24): 6, Vector2i(47, 47): 6,
	}
	for cell in boundary_samples:
		if int(game.region_level_for_cell(cell)) != int(boundary_samples[cell]):
			fail("新区边界判定错误：%s" % cell)
	if int(game.region_level_for_cell(Vector2i(48, 47))) != -1:
		fail("地图外坐标未返回 -1")

func check_goal_panel_at_1366(game) -> void:
	game.reset_game(false)
	game.time_paused = true
	game.region_panel_collapsed = false
	game.update_ui()
	var top_text := str(game.goal_label.text)
	var panel_text := goal_panel_text(game)
	require_terms(top_text, ["第一章", "进度", "当前", "农田"], "顶栏目标")
	require_terms(panel_text, ["北坡梯田", "当前任务", "费用", "木材", "粮食", "奖励", "200", "20"], "复兴目标面板")
	if panel_text.find("日期") >= 0 or panel_text.find("第 5 日") >= 0:
		fail("章节目标仍把日期列为条件：%s" % panel_text)
	if top_text.find("0/1") < 0 and panel_text.find("0/1") < 0:
		fail("开局农田目标没有显示 0/1 实时进度")
	if not game.region_panel.visible or not game.region_unlock_button.visible:
		fail("复兴目标面板或开拓按钮在 1366x768 下不可见")
	await process_frame
	check_inside_viewport(game.region_panel, "复兴目标面板")
	check_inside_viewport(game.region_unlock_button, "开拓按钮")
	check_inside_viewport(game.goal_label, "顶栏目标")
	var panel_minimum: Vector2 = game.region_panel.get_combined_minimum_size()
	if panel_minimum.y > game.region_panel.size.y + 2.0:
		fail("复兴目标面板内容被纵向裁切：需要 %.0f，实际 %.0f" % [panel_minimum.y, game.region_panel.size.y])
	var goal_minimum: Vector2 = game.goal_label.get_combined_minimum_size()
	if goal_minimum.y > game.goal_label.size.y + 2.0:
		fail("顶栏目标文字被纵向裁切：需要 %.0f，实际 %.0f" % [goal_minimum.y, game.goal_label.size.y])

func check_current_task_priority(game) -> void:
	game.reset_game(false)
	game.update_ui()
	assert_current_task(game, ["农田", "0/1"], "开局应先指引专属建筑")

	game.add_building("farm", Vector2i(1, 10), true)
	game.update_ui()
	assert_current_task(game, ["茅舍"], "农田完成后应先补足住房")

	game.add_building("house", Vector2i(10, 9), true)
	game.update_ui()
	var housing_done_text := current_goal_text(game)
	if (housing_done_text.find("迁入") < 0 and housing_done_text.find("人口") < 0) or housing_done_text.find("4/8") < 0:
		fail("住房完成后没有给出 4/8 人口的可执行任务：%s" % housing_done_text)

	game.population = 8
	game.wood = 100
	game.food = 40
	game.update_ui()
	var ready_text := current_goal_text(game)
	if ready_text.find("条件齐备") < 0 or ready_text.find("开拓") < 0:
		fail("第 1 日满足非日期条件后没有明确要求点击开拓：%s" % ready_text)
	if ready_text.find("日期") >= 0 or ready_text.find("第 5 日") >= 0:
		fail("当前任务仍生成日期目标：%s" % ready_text)

	game.reset_game(false)
	game.map_region_level = 3
	game.add_building("farm", Vector2i(1, 10), true)
	game.add_building("farm", Vector2i(1, 11), true)
	game.add_building("farm", Vector2i(1, 12), true)
	game.add_building("warehouse", Vector2i(10, 10), true)
	game.update_ui()
	assert_current_task(game, ["再建 1 座仓库", "当前 1/2"], "部分完成的建筑任务应区分剩余数量和总进度")

func check_chapter_previews(game) -> void:
	for index in range(CHAPTER_EXPECTATIONS.size()):
		game.reset_game(false)
		game.map_region_level = index
		game.update_ui()
		var expected: Array = CHAPTER_EXPECTATIONS[index]
		var combined := current_goal_text(game)
		require_terms(combined, expected, "第 %d 章目标预告" % (index + 1))
		if str(game.region_title.text).find("/%d" % EXPECTED_CHAPTER_TOTALS[index]) < 0:
			fail("第 %d 章进度分母没有移除日期项：%s" % [index + 1, game.region_title.text])
		if combined.find("日期") >= 0:
			fail("第 %d 章仍显示日期目标" % (index + 1))
		if combined.find("奖励") < 0:
			fail("第 %d 章没有常驻奖励预告" % (index + 1))

	game.map_region_level = 6
	game.update_ui()
	var final_text := current_goal_text(game)
	require_terms(final_text, ["第七章", "东境复兴", "45", "200", "80"], "终局目标")
	if final_text.find("当前") < 0 and final_text.find("任务") < 0:
		fail("第七章没有给出当前任务")

func check_first_unlock_reward_and_transition(game) -> void:
	game.reset_game(false)
	game.add_building("farm", Vector2i(1, 10), true)
	game.add_building("house", Vector2i(10, 9), true)
	game.population = 8
	game.day = 1
	game.wood = 100
	game.food = 40
	game.update_ui()
	var wood_before := int(game.wood)
	var food_before := int(game.food)
	game.unlock_next_region()
	if int(game.map_region_level) != 1:
		fail("第一章完成后没有进入第二章")
	if int(game.wood) != wood_before - 50:
		fail("北坡开拓木材扣费错误")
	if int(game.food) != mini(int(game.food_capacity()), food_before - 15 + 20):
		fail("北坡开拓没有结算 20 粮食奖励")
	var transitioned_text := current_goal_text(game)
	require_terms(transitioned_text, ["第二章", "木通东麓", "东麓林场", "奖励", "40"], "章节切换")
	var level_after := int(game.map_region_level)
	wood_before = int(game.wood)
	food_before = int(game.food)
	game.unlock_next_region()
	if int(game.map_region_level) != level_after or int(game.wood) != wood_before or int(game.food) != food_before:
		fail("重复点击在条件不足时造成越级、重复扣费或重复奖励")

func assert_current_task(game, terms: Array, context: String) -> void:
	var text_value := current_goal_text(game)
	for term in terms:
		if text_value.find(str(term)) < 0:
			fail("%s：缺少“%s”，实际为：%s" % [context, term, text_value])

func current_goal_text(game) -> String:
	return "%s\n%s" % [str(game.goal_label.text), goal_panel_text(game)]

func goal_panel_text(game) -> String:
	var parts: Array[String] = []
	collect_visible_text(game.region_panel, parts)
	return "\n".join(parts)

func collect_visible_text(node: Node, parts: Array[String]) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label:
		parts.append(str((node as Label).text))
	elif node is Button:
		parts.append(str((node as Button).text))
	for child in node.get_children():
		collect_visible_text(child, parts)

func require_terms(text_value: String, terms: Array, context: String) -> void:
	for term in terms:
		if text_value.find(str(term)) < 0:
			fail("%s缺少“%s”：%s" % [context, term, text_value])

func check_inside_viewport(control: Control, label: String) -> void:
	var rect := control.get_global_rect()
	if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > VIEWPORT_SIZE.x + 1.0 or rect.end.y > VIEWPORT_SIZE.y + 1.0:
		fail("%s超出 1366x768：%s" % [label, rect])

func fail(message: String) -> void:
	failures.append(message)
	push_error("GOAL_CLARITY_ACCEPTANCE_FAILED: " + message)

func finish() -> void:
	if failures.is_empty():
		print("GOAL_CLARITY_ACCEPTANCE_OK: 48x48, 7 regions, no date gates, visible chapter/task/progress/reward")
		quit(0)
	else:
		print("GOAL_CLARITY_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
