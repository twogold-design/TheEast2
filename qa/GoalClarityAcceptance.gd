extends SceneTree

## Producer acceptance for the 48x48 world and the seven-chapter goal chain.
## The checks read the live Main scene so UI copy and gameplay data cannot drift
## without failing the same release gate.

const VIEWPORT_SIZE := Vector2i(1366, 768)
const SAVE_PATH := "res://saves/savegame.json"
const EXPECTED_AREAS := [400, 200, 200, 100, 432, 540, 432]
## Persistent chapter UI only needs to identify the chapter and its destination.
## Unlock costs and rewards belong to the unlock action, not the standing goal.
const CHAPTER_EXPECTATIONS := [
	["第一章", "安家河湾", "北坡梯田"],
	["第二章", "木通东麓", "东麓林场"],
	["第三章", "百工登台", "云岫高台"],
	["第四章", "东原成镇", "沧波东原"],
	["第五章", "北关兴业", "朔岭关田"],
	["第六章", "新都落成", "天际新都"],
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
	await check_chapter_previews(game)
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
	require_terms(top_text, ["第一章", "安家河湾", "目标：", "开拓北坡"], "顶栏目标")
	require_terms(panel_text, ["北坡梯田", "用途", "固定目标：", "聚落", "人口 8", "住房 8", "农田 1", "稳定运转 1 日"], "复兴目标面板")
	assert_no_persistent_unlock_details(game, top_text, panel_text, 1, "第一章常驻目标")
	if top_text.count("目标：") != 1:
		fail("顶栏必须只显示一句章节目标：%s" % top_text)
	if panel_text.count("目标：") != 1:
		fail("复兴目标面板必须只显示一条动作目标：%s" % panel_text)
	assert_no_goal_progress(top_text, "顶栏目标")
	assert_no_goal_progress(panel_text, "展开目标栏")
	if panel_text.find("日期") >= 0 or panel_text.find("第 5 日") >= 0:
		fail("章节目标仍把日期列为条件：%s" % panel_text)
	if not game.region_panel.visible or not game.region_unlock_button.visible:
		fail("复兴目标面板或开拓按钮在 1366x768 下不可见")
	if str(game.region_unlock_button.text).find("开拓") < 0:
		fail("开拓按钮没有保留明确动作：%s" % game.region_unlock_button.text)
	var unlock_reason := str(game.can_unlock_next_region())
	if unlock_reason != "" and str(game.region_unlock_button.tooltip_text).find(unlock_reason) < 0:
		fail("不可开拓时按钮悬停没有说明首个阻碍：%s" % game.region_unlock_button.tooltip_text)
	assert_no_goal_progress(str(game.goal_label.tooltip_text), "顶栏目标悬停")
	assert_no_goal_progress(str(game.region_body.tooltip_text), "展开目标栏悬停")
	assert_no_goal_progress(str(game.region_unlock_button.tooltip_text), "开拓按钮悬停")
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
	game.toggle_region_panel()
	await process_frame
	var collapsed_text := "%s\n%s" % [str(game.goal_label.text), str(game.region_title.text)]
	var compact_title := str(game.region_title.text).replace(" ", "")
	if compact_title != "目标·北坡":
		fail("收起目标栏必须显示“目标 · 区域名”：%s" % game.region_title.text)
	assert_no_goal_progress(collapsed_text, "收起目标栏与顶栏")
	game.toggle_region_panel()

func check_current_task_priority(game) -> void:
	game.reset_game(false)
	game.update_ui()
	var fixed_top := str(game.goal_label.text)
	var fixed_panel := goal_panel_text(game)
	assert_current_task(game, ["目标：", "建好河湾聚落", "人口 8", "住房 8", "农田 1", "稳定运转 1 日"], "开局章节目标")

	# Chapter UI must remain byte-for-byte stable as individual conditions are
	# completed. Only opening the next region is allowed to replace it.
	game.add_building("farm", Vector2i(1, 10), true)
	game.add_building("house", Vector2i(10, 9), true)
	game.population = 8
	game.happiness = 80
	game.wood = 100
	game.food = 40
	game.coins = 100
	game.stable_days = int(game.REGION_REQUIREMENTS[1].stable_days)
	game.day = 30
	game.update_ui()
	if str(game.goal_label.text) != fixed_top or goal_panel_text(game) != fixed_panel:
		fail("同一章节内目标随完成条件发生变化：\n原顶栏：%s\n现顶栏：%s\n原目标栏：%s\n现目标栏：%s" % [
			fixed_top, game.goal_label.text, fixed_panel, goal_panel_text(game),
		])
	assert_no_dynamic_goal_language(current_goal_text(game), "条件全部满足后的章节目标")

func check_chapter_previews(game) -> void:
	for index in range(CHAPTER_EXPECTATIONS.size()):
		game.reset_game(false)
		game.map_region_level = index
		game.update_ui()
		await process_frame
		var expected: Array = CHAPTER_EXPECTATIONS[index]
		var combined := current_goal_text(game)
		require_terms(combined, expected, "第 %d 章目标预告" % (index + 1))
		require_terms(combined, ["目标："], "第 %d 章精简目标信息" % (index + 1))
		assert_no_persistent_unlock_details(game, str(game.goal_label.text), goal_panel_text(game), index + 1, "第 %d 章常驻目标" % (index + 1))
		assert_no_goal_progress(combined, "第 %d 章可见目标" % (index + 1))
		assert_no_dynamic_goal_language(combined, "第 %d 章固定目标" % (index + 1))
		if combined.find("日期") >= 0:
			fail("第 %d 章仍显示日期目标" % (index + 1))
		var panel_minimum: Vector2 = game.region_panel.get_combined_minimum_size()
		if panel_minimum.y > game.region_panel.size.y + 2.0:
			fail("第 %d 章目标清单被纵向裁切：需要 %.0f，实际 %.0f" % [index + 1, panel_minimum.y, game.region_panel.size.y])

	game.map_region_level = 6
	game.update_ui()
	var final_text := current_goal_text(game)
	require_terms(final_text, ["第七章", "东境复兴", "目标：", "人口 45", "木材 200", "粮食 200", "铜钱 150", "幸福 80", "稳定运转 7 日"], "终局目标")
	assert_no_unlock_copy(final_text, "终局常驻目标")
	assert_no_goal_progress(final_text, "终局目标")
	assert_no_dynamic_goal_language(final_text, "终局目标")

func check_first_unlock_reward_and_transition(game) -> void:
	game.reset_game(false)
	game.add_building("farm", Vector2i(1, 10), true)
	game.add_building("house", Vector2i(10, 9), true)
	game.population = 8
	game.day = 1
	game.wood = 100
	game.food = 40
	game.coins = 100
	game.stable_days = int(game.REGION_REQUIREMENTS[1].stable_days)
	game.update_ui()
	var wood_before := int(game.wood)
	var food_before := int(game.food)
	var coins_before := int(game.coins)
	var first_cost: Dictionary = game.REGION_UNLOCK_COSTS[1]
	var first_reward: Dictionary = game.REGION_UNLOCK_REWARDS[1]
	game.unlock_next_region()
	if int(game.map_region_level) != 1:
		fail("第一章完成后没有进入第二章")
	if int(game.wood) != mini(int(game.wood_capacity()), wood_before - int(first_cost.wood) + int(first_reward.wood)):
		fail("北坡开拓木材扣费错误")
	if int(game.food) != mini(int(game.food_capacity()), food_before - int(first_cost.food) + int(first_reward.food)):
		fail("北坡开拓没有结算 20 粮食奖励")
	if int(game.coins) != coins_before - int(first_cost.coins) + int(first_reward.coins):
		fail("北坡开拓铜钱扣费或奖励错误")
	var transitioned_text := current_goal_text(game)
	require_terms(transitioned_text, ["第二章", "木通东麓", "东麓林场"], "章节切换")
	assert_no_persistent_unlock_details(game, str(game.goal_label.text), goal_panel_text(game), 2, "开拓后的第二章常驻目标")
	var unlock_message := str(game.message_label.text)
	require_terms(unlock_message, ["北坡梯田已开放", "开拓奖励", "获得粮食 20", "获得铜钱 10"], "北坡开拓一次性提示")
	if unlock_message.find("费用") >= 0:
		fail("开拓成功提示混入了已扣除费用：%s" % unlock_message)
	var level_after := int(game.map_region_level)
	wood_before = int(game.wood)
	food_before = int(game.food)
	game.unlock_next_region()
	if int(game.map_region_level) != level_after or int(game.wood) != wood_before or int(game.food) != food_before:
		fail("重复点击在条件不足时造成越级、重复扣费或重复奖励")
	if str(game.message_label.text).find("开拓奖励") >= 0:
		fail("开拓奖励提示没有在下一次操作反馈后消失：%s" % game.message_label.text)

func assert_no_persistent_unlock_details(game, top_text: String, panel_text: String, next_level: int, context: String) -> void:
	assert_no_unlock_copy(top_text, "%s顶栏" % context)
	assert_no_unlock_copy(panel_text, "%s右侧目标栏" % context)
	if next_level < 1 or next_level >= game.REGION_UNLOCK_COSTS.size():
		return
	var cost: Dictionary = game.REGION_UNLOCK_COSTS[next_level]
	var cost_phrases := [
		"木材 %d" % int(cost.wood),
		"粮食 %d" % int(cost.food),
		"铜钱 %d" % int(cost.coins),
	]
	for phrase in cost_phrases:
		if top_text.find(phrase) >= 0 or panel_text.find(phrase) >= 0:
			fail("%s仍常驻显示开拓成本“%s”：%s" % [context, phrase, "%s\n%s" % [top_text, panel_text]])

func assert_no_unlock_copy(text_value: String, context: String) -> void:
	for term in ["费用", "奖励"]:
		if text_value.find(term) >= 0:
			fail("%s仍常驻显示“%s”：%s" % [context, term, text_value])

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

func assert_no_goal_progress(text_value: String, context: String) -> void:
	if text_value.find("进度") >= 0:
		fail("%s仍显示“进度”：%s" % [context, text_value])
	var ratio_regex := RegEx.new()
	ratio_regex.compile("\\d+\\s*/\\s*\\d+")
	if ratio_regex.search(text_value) != null:
		fail("%s仍显示数字/数字目标进度：%s" % [context, text_value])
	var percentage_regex := RegEx.new()
	percentage_regex.compile("\\d+\\s*%")
	if percentage_regex.search(text_value) != null:
		fail("%s仍显示百分比目标进度：%s" % [context, text_value])
	var current_required_regex := RegEx.new()
	current_required_regex.compile("当前[^\\n]*要求")
	if current_required_regex.search(text_value) != null:
		fail("%s仍显示当前/要求式说明：%s" % [context, text_value])

func assert_no_dynamic_goal_language(text_value: String, context: String) -> void:
	for term in ["当前任务", "还需", "再建", "等待", "条件齐备", "目标达成"]:
		if text_value.find(term) >= 0:
			fail("%s仍包含动态下一步“%s”：%s" % [context, term, text_value])

func check_inside_viewport(control: Control, label: String) -> void:
	var rect := control.get_global_rect()
	if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > VIEWPORT_SIZE.x + 1.0 or rect.end.y > VIEWPORT_SIZE.y + 1.0:
		fail("%s超出 1366x768：%s" % [label, rect])

func fail(message: String) -> void:
	failures.append(message)
	push_error("GOAL_CLARITY_ACCEPTANCE_FAILED: " + message)

func finish() -> void:
	if failures.is_empty():
		print("GOAL_CLARITY_ACCEPTANCE_OK: 48x48, 7 regions, stable goal-only UI, unlock-only reward feedback, no visible progress")
		quit(0)
	else:
		print("GOAL_CLARITY_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
