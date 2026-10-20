extends SceneTree

## Acceptance for the eight building descriptions.  The checks deliberately
## read the live building catalog and run the real daily settlement so the
## build menu, tooltip, inspector and economy cannot silently disagree.

const VIEWPORT_SIZE := Vector2i(1366, 768)
const SAVE_PATH := "res://saves/savegame.json"
const TYPES := ["house", "farm", "lumber", "warehouse", "workshop", "market", "clinic", "academy"]

const EXPECTED_DEFINITIONS := {
	"house": {"workers": 0, "maintenance": 0, "inputs": {"food": 1}, "effects": {"housing": 4}},
	"farm": {"workers": 2, "maintenance": 1, "outputs": {"food": 10}, "trade_coins": 2},
	"lumber": {"workers": 2, "maintenance": 1, "outputs": {"wood": 7}, "trade_coins": 2},
	"warehouse": {"workers": 0, "maintenance": 1, "effects": {"wood_capacity": 75, "food_capacity": 75}},
	"workshop": {"workers": 3, "maintenance": 2, "inputs": {"wood": 4, "food": 2}, "outputs": {"coins": 10}, "effects": {"happiness_target": 4}, "effect_cap": 12},
	"market": {"workers": 2, "maintenance": 2, "inputs": {"food": 3}, "outputs": {"coins": 9}},
	"clinic": {"workers": 2, "maintenance": 3, "effects": {"happiness_target": 7}, "effect_cap": 14},
	"academy": {"workers": 3, "maintenance": 4, "outputs": {"coins": 5}, "effects": {"happiness_target": 4}, "effect_cap": 8},
}

const EXPECTED_COPY := {
	"house": ["每日：粮食 -1", "维护：无", "住房容量 +4"],
	"farm": ["岗位：2", "粮食 0/+5/+10", "在岗 0/1/2 人", "铜钱 +2", "农田与伐木场合计上限 +4", "维护：铜钱 -1/日（启用即收）"],
	"lumber": ["岗位：2", "木材 0/+3/+7", "在岗 0/1/2 人", "铜钱 +2", "农田与伐木场合计上限 +4", "维护：铜钱 -1/日（启用即收）"],
	"warehouse": ["维护：铜钱 -1/日（固定收取）", "木材容量 +75", "粮食容量 +75"],
	"workshop": ["岗位：3（满员运行）", "木材 -4、粮食 -2", "铜钱 +10", "维护：铜钱 -2/日（启用即收）", "幸福度目标 +4", "合计上限 +12"],
	"market": ["岗位：2（满员运行）", "粮食 -3", "铜钱 +9", "维护：铜钱 -2/日（启用即收）"],
	"clinic": ["岗位：2（满员运行）", "维护：铜钱 -3/日（启用即收）", "幸福度目标 +7", "合计上限 +14"],
	"academy": ["岗位：3（满员运行）", "铜钱 +5", "维护：铜钱 -4/日（启用即收）", "幸福度目标 +4", "合计上限 +8"],
}

const EXPECTED_DAILY_DIFFERENCE := {
	"house": {"wood": 0, "food": -1, "coins": 0},
	"farm": {"wood": 0, "food": 10, "coins": 1},
	"lumber": {"wood": 7, "food": 0, "coins": 1},
	"warehouse": {"wood": 0, "food": 0, "coins": -1},
	"workshop": {"wood": -4, "food": -2, "coins": 8},
	"market": {"wood": 0, "food": -3, "coins": 7},
	"clinic": {"wood": 0, "food": 0, "coins": -3},
	"academy": {"wood": 0, "food": 0, "coins": 1},
}

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
	game.time_paused = true
	game.map_region_level = game.REGION_DEFINITIONS.size() - 1

	check_public_copy_api(game)
	check_definition_contract(game)
	check_generated_copy(game)
	await check_menu_and_inspector_layout(game)
	check_runtime_status_copy(game)
	check_daily_settlement_matches_copy(game)

	restore_save_file()
	finish()


func check_public_copy_api(game) -> void:
	for method in ["building_input", "building_output", "building_effect", "building_effect_lines", "building_effect_text", "building_tooltip_text", "building_operation_text", "daily_settlement_text"]:
		if not game.has_method(method):
			fail("建筑文案缺少统一公开方法：%s" % method)


func check_definition_contract(game) -> void:
	if game.BUILDINGS.size() != TYPES.size():
		fail("建筑目录应为8类，实际%d类" % game.BUILDINGS.size())
	for type in TYPES:
		var definition: Dictionary = game.BUILDINGS.get(type, {})
		if definition.is_empty():
			fail("缺少建筑定义：%s" % type)
			continue
		for removed_field in ["description", "wood", "food", "housing"]:
			if definition.has(removed_field):
				fail("%s仍保留易与日结漂移的旧字段：%s" % [definition.name, removed_field])
		for scalar in ["workers", "maintenance", "trade_coins", "effect_cap"]:
			if not EXPECTED_DEFINITIONS[type].has(scalar):
				continue
			if int(definition.get(scalar, -1)) != int(EXPECTED_DEFINITIONS[type][scalar]):
				fail("%s的%s定义错误：%s" % [definition.name, scalar, definition.get(scalar)])
		for group in ["inputs", "outputs", "effects"]:
			var expected_group: Dictionary = EXPECTED_DEFINITIONS[type].get(group, {})
			var actual_group: Dictionary = definition.get(group, {})
			for key in expected_group:
				if int(actual_group.get(key, -1)) != int(expected_group[key]):
					fail("%s的%s.%s定义错误：%s" % [definition.name, group, key, actual_group.get(key)])


func check_generated_copy(game) -> void:
	var fallback_font := ThemeDB.fallback_font
	for type in TYPES:
		var definition: Dictionary = game.BUILDINGS[type]
		var effect_text := str(game.building_effect_text(type))
		var tooltip_text := str(game.building_tooltip_text(type))
		if tooltip_text != effect_text:
			fail("%s按钮提示与统一效果文案不一致" % definition.name)
		if effect_text.strip_edges() == "":
			fail("%s效果文案为空" % definition.name)
			continue
		for term in EXPECTED_COPY[type]:
			if effect_text.find(str(term)) < 0:
				fail("%s文案缺少“%s”：%s" % [definition.name, term, effect_text.replace("\n", "｜")])
		for vague_term in ["增收", "稳定民心", "若干", "适量", "丰富"]:
			if effect_text.find(vague_term) >= 0:
				fail("%s仍使用不精确词语“%s”：%s" % [definition.name, vague_term, effect_text])
		var lines := effect_text.split("\n", false)
		if lines.size() > 5:
			fail("%s提示超过5行，不够简洁：%d行" % [definition.name, lines.size()])
		for line in lines:
			var line_size := fallback_font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
			if line_size.x > 700.0:
				fail("%s提示单行过长，1366宽视口可能溢出：%s" % [definition.name, line])


func check_menu_and_inspector_layout(game) -> void:
	game.map_region_level = game.REGION_DEFINITIONS.size() - 1
	for category in ["basic", "industry", "civic"]:
		game.select_build_category(category)
		await process_frame
		for type in TYPES:
			var button: Button = game.build_buttons[type]
			if not button.visible:
				continue
			var definition: Dictionary = game.BUILDINGS[type]
			for term in [str(definition.name), str(definition.cost), str(definition.coin_cost)]:
				if str(button.text).find(term) < 0:
					fail("%s建造按钮没有显示完整造价：%s" % [definition.name, button.text])
			if str(button.tooltip_text) != str(game.building_tooltip_text(type)):
				fail("%s建造按钮未使用统一提示文案" % definition.name)
			check_control_fits(button, "%s建造按钮" % definition.name)

	for type in TYPES:
		prepare_single_building(game, type, 20, 60, 60, 500)
		var record: Dictionary = game.buildings[0]
		game.show_inspector(int(record.id))
		await process_frame
		var definition: Dictionary = game.BUILDINGS[type]
		if str(game.inspector_title.text) != str(definition.name):
			fail("%s选中详情标题错误" % definition.name)
		var body := str(game.inspector_body.text)
		if body.find(str(game.building_effect_text(type))) < 0:
			fail("%s选中详情未使用统一效果文案" % definition.name)
		if body.find(str(game.building_operation_text(record))) < 0:
			fail("%s选中详情未显示实时运行状态" % definition.name)
		check_control_fits(game.inspector, "%s选中详情面板" % definition.name)
		if game.inspector_body.get_combined_minimum_size().y > game.inspector_body.size.y + 1.0:
			fail("%s选中详情正文被垂直裁切：需要%.0f，实际%.0f" % [definition.name, game.inspector_body.get_combined_minimum_size().y, game.inspector_body.size.y])


func check_runtime_status_copy(game) -> void:
	prepare_single_building(game, "farm", 1, 60, 60, 500)
	var farm_text := str(game.building_operation_text(game.buildings[0]))
	require_terms(farm_text, ["生产中", "在岗 1/2", "粮食 +5", "民生交易"], "农田1人状态")

	prepare_single_building(game, "lumber", 1, 60, 60, 500)
	var lumber_text := str(game.building_operation_text(game.buildings[0]))
	require_terms(lumber_text, ["生产中", "在岗 1/2", "木材 +3", "民生交易"], "伐木场1人状态")

	prepare_single_building(game, "workshop", 20, 3, 1, 500)
	var workshop_missing := str(game.building_operation_text(game.buildings[0]))
	require_terms(workshop_missing, ["当前库存不足单次配方", "在岗 3/3", "木材需 4（现有 3）", "粮食需 2（现有 1）"], "小工坊缺料状态")
	prepare_single_building(game, "workshop", 20, 60, 60, 500)
	var workshop_ready := str(game.building_operation_text(game.buildings[0]))
	require_terms(workshop_ready, ["当前库存够单次配方", "在岗 3/3", "结算时按库存依序处理"], "小工坊满员状态")
	if workshop_ready.find("本日可完成") >= 0:
		fail("小工坊在生活消耗和前序建筑结算前错误承诺本日可完成")

	prepare_single_building(game, "market", 20, 60, 2, 500)
	var market_missing := str(game.building_operation_text(game.buildings[0]))
	require_terms(market_missing, ["当前库存不足单次配方", "在岗 2/2", "粮食需 3（现有 2）"], "集市缺货状态")
	prepare_single_building(game, "market", 20, 60, 60, 500)
	var market_ready := str(game.building_operation_text(game.buildings[0]))
	require_terms(market_ready, ["当前库存够单次交易", "在岗 2/2", "结算时按库存依序处理"], "集市满员状态")
	if market_ready.find("本日可完成") >= 0:
		fail("集市在生活消耗和前序建筑结算前错误承诺本日可完成")

	prepare_single_building(game, "academy", 20, 60, 60, 500)
	var record: Dictionary = game.buildings[0]
	record.enabled = false
	var paused_text := str(game.building_operation_text(record))
	require_terms(paused_text, ["已暂停", "不占岗位", "不收维护费"], "暂停状态")


func check_daily_settlement_matches_copy(game) -> void:
	var control := run_one_day(game, "")
	for type in TYPES:
		var result := run_one_day(game, type)
		var expected: Dictionary = EXPECTED_DAILY_DIFFERENCE[type]
		for resource in ["wood", "food", "coins"]:
			var actual_difference := int(result[resource]) - int(control[resource])
			if actual_difference != int(expected[resource]):
				fail("%s日结%s与说明不一致：相对基线%+d，说明应为%+d" % [game.BUILDINGS[type].name, resource, actual_difference, int(expected[resource])])
		var summary := str(result.summary)
		match type:
			"farm":
				require_terms(summary, ["农田入库 +10", "民生交易 +2", "本日维护应付 -1"], "农田日结")
			"lumber":
				require_terms(summary, ["伐木入库 +7", "民生交易 +2", "本日维护应付 -1"], "伐木场日结")
			"workshop":
				require_terms(summary, ["工坊 -4", "工坊 -2", "工坊 +10", "本日维护应付 -2"], "小工坊日结")
			"market":
				require_terms(summary, ["集市 -3", "集市 +9", "本日维护应付 -2"], "集市日结")
			"academy":
				require_terms(summary, ["书院 +5", "本日维护应付 -4"], "书院日结")


func run_one_day(game, type: String) -> Dictionary:
	prepare_empty_layout(game, 20, 60, 60, 500)
	if type != "":
		game.add_building(type, Vector2i(8, 8), true)
	var before := {"wood": int(game.wood), "food": int(game.food), "coins": int(game.coins)}
	game.next_day()
	return {
		"wood": int(game.wood) - int(before.wood),
		"food": int(game.food) - int(before.food),
		"coins": int(game.coins) - int(before.coins),
		"summary": str(game.message_label.text),
	}


func prepare_single_building(game, type: String, residents: int, start_wood: int, start_food: int, start_coins: int) -> void:
	prepare_empty_layout(game, residents, start_wood, start_food, start_coins)
	game.add_building(type, Vector2i(8, 8), true)
	game.assign_workers()


func prepare_empty_layout(game, residents: int, start_wood: int, start_food: int, start_coins: int) -> void:
	for child in game.building_root.get_children():
		child.free()
	game.buildings.clear()
	game.occupied.clear()
	game.next_id = 1
	game.map_region_level = game.REGION_DEFINITIONS.size() - 1
	game.day = 2
	game.day_settling = false
	game.ended = ""
	game.wood = start_wood
	game.food = start_food
	game.coins = start_coins
	game.population = residents
	game.happiness = 70
	game.low_happiness_days = 0
	game.stable_days = 0
	game.maintenance_debt = 0


func require_terms(text_value: String, terms: Array, context: String) -> void:
	for term in terms:
		if text_value.find(str(term)) < 0:
			fail("%s缺少“%s”：%s" % [context, term, text_value])


func check_control_fits(control: Control, label: String) -> void:
	var rect := control.get_global_rect()
	if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > VIEWPORT_SIZE.x + 1.0 or rect.end.y > VIEWPORT_SIZE.y + 1.0:
		fail("%s超出1366x768视口：%s" % [label, rect])
	var minimum := control.get_combined_minimum_size()
	if minimum.x > control.size.x + 1.0 or minimum.y > control.size.y + 1.0:
		fail("%s内容被裁切：需要%s，实际%s" % [label, minimum, control.size])


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
	push_error("BUILDING_COPY_ACCEPTANCE_FAILED: " + message)


func finish() -> void:
	if failures.is_empty():
		print("BUILDING_COPY_ACCEPTANCE_OK: 8 definitions, exact tooltips, live status, daily settlement parity, 1366x768 layout")
		quit(0)
	else:
		print("BUILDING_COPY_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
