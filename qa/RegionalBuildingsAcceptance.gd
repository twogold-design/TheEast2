extends SceneTree

## Acceptance for buildings unlocked by regional expansion.  The checks use the
## live settlement scene so menu paging, labour, upkeep, daily effects and v3
## persistence cannot drift apart.

const RealisticKit = preload("res://godot/RealisticAssets.gd")
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
		finish()
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.time_paused = true

	check_definitions_and_unlocks(game)
	check_opening_buildings(game)
	check_catalog_progression(game)
	check_paged_build_menu(game)
	check_composite_models(game)
	check_market_operation(game)
	check_clinic_operation(game)
	check_academy_operation(game)
	check_pause_and_v3_roundtrip(game)

	restore_save_file()
	finish()


func check_definitions_and_unlocks(game) -> void:
	var expected := {
		"market": {"name": "集市", "unlock": 1, "workers": 2, "maintenance": 2},
		"clinic": {"name": "医馆", "unlock": 3, "workers": 2, "maintenance": 3},
		"academy": {"name": "书院", "unlock": 4, "workers": 3, "maintenance": 4},
	}
	for type in expected:
		var definition: Dictionary = game.BUILDINGS.get(type, {})
		if definition.is_empty():
			fail("缺少新增建筑：%s" % type)
			continue
		var contract: Dictionary = expected[type]
		for field in ["cost", "coin_cost"]:
			if int(definition.get(field, 0)) <= 0:
				fail("%s没有有效%s" % [contract.name, field])
		if int(definition.get("unlock_level", -1)) != int(contract.unlock):
			fail("%s解锁区域等级错误" % contract.name)
		if int(definition.get("workers", 0)) != int(contract.workers):
			fail("%s岗位数错误" % contract.name)
		if int(definition.get("maintenance", 0)) != int(contract.maintenance):
			fail("%s维护费错误" % contract.name)

	game.map_region_level = 0
	if str(game.can_place("market", Vector2i(8, 8))).find("尚未解锁") < 0:
		fail("集市可在北坡开拓前摆放")
	game.map_region_level = 1
	game.wood = 1000
	game.coins = 1000
	if str(game.can_place("market", Vector2i(8, 8))) != "":
		fail("北坡开拓后集市仍不可摆放：%s" % game.can_place("market", Vector2i(8, 8)))
	game.map_region_level = 2
	if str(game.can_place("clinic", Vector2i(8, 8))).find("尚未解锁") < 0:
		fail("医馆可在高台开拓前摆放")
	game.map_region_level = 3
	if str(game.can_place("clinic", Vector2i(8, 8))) != "":
		fail("高台开拓后医馆仍不可摆放")
	game.map_region_level = 3
	if str(game.can_place("academy", Vector2i(8, 8))).find("尚未解锁") < 0:
		fail("书院可在东原开拓前摆放")
	game.map_region_level = 4
	if str(game.can_place("academy", Vector2i(8, 8))) != "":
		fail("东原开拓后书院仍不可摆放")


func check_opening_buildings(game) -> void:
	var expected := ["house", "farm", "lumber", "workshop", "warehouse"]
	if game.INITIAL_BUILDING_TYPES != expected:
		fail("开局建筑清单应完整保留五类：%s" % game.INITIAL_BUILDING_TYPES)
	game.map_region_level = 0
	game.wood = 1000
	game.coins = 1000
	game.select_build_category("basic")
	var opening_cells := {
		"house": Vector2i(8, 8),
		"farm": Vector2i(1, 8),
		"lumber": Vector2i(14, 8),
		"workshop": Vector2i(8, 8),
		"warehouse": Vector2i(8, 8),
	}
	var visible_opening: Array[String] = []
	for type in game.build_buttons:
		var button: Button = game.build_buttons[type]
		if not button.visible:
			continue
		visible_opening.append(str(type))
		if type not in expected:
			fail("开局页混入后期建筑：%s" % type)
		if button.disabled:
			fail("开局建筑按钮被锁定：%s" % type)
		if not game.building_is_unlocked(str(type)):
			fail("开局建筑解锁逻辑错误：%s" % type)
		var placement_reason := str(game.can_place(str(type), opening_cells[type]))
		if placement_reason != "":
			fail("开局建筑不能立即建造：%s（%s）" % [type, placement_reason])
		check_inside_viewport(button, "开局%s按钮" % game.BUILDINGS[type].name)
	if visible_opening.size() != expected.size():
		fail("开局页应直接显示五类建筑，实际%s" % visible_opening)


func check_catalog_progression(game) -> void:
	var starter_types := ["house", "farm", "lumber", "workshop", "warehouse"]
	var regional_unlocks := {"market": 1, "clinic": 3, "academy": 4}
	if game.BUILDINGS.size() != starter_types.size() + regional_unlocks.size():
		fail("建筑图鉴应由5类开局建筑继续扩充为8类，实际%d类" % game.BUILDINGS.size())
	for level in range(game.REGION_DEFINITIONS.size()):
		game.map_region_level = level
		var unlocked_count := 0
		for type in game.BUILDINGS:
			if game.building_is_unlocked(str(type)):
				unlocked_count += 1
		var expected_count := starter_types.size()
		for type in regional_unlocks:
			if level >= int(regional_unlocks[type]):
				expected_count += 1
		if unlocked_count != expected_count:
			fail("区域等级%d应解锁%d类建筑，实际%d类" % [level, expected_count, unlocked_count])
	for type in starter_types:
		if int(game.BUILDINGS[type].get("unlock_level", -1)) != 0:
			fail("开局建筑%s没有从第0级解锁" % game.BUILDINGS[type].name)
	for type in regional_unlocks:
		var level := int(regional_unlocks[type])
		var name := str(game.BUILDINGS[type].name)
		if str(game.REGION_UNLOCK_FEEDBACK[level]).find(name) < 0 or str(game.REGION_UNLOCK_FEEDBACK[level]).find("解锁") < 0:
			fail("%s开放反馈没有明确告知%s解锁" % [game.REGION_DEFINITIONS[level].short_name, name])
		if str(game.REGION_DEFINITIONS[level].summary).find(name) < 0:
			fail("%s区域摘要没有说明新增建筑%s" % [game.REGION_DEFINITIONS[level].short_name, name])


func check_paged_build_menu(game) -> void:
	game.map_region_level = 0
	for category in ["basic", "industry", "civic"]:
		game.select_build_category(category)
		var visible_count := 0
		for type in game.build_buttons:
			var button: Button = game.build_buttons[type]
			if button.visible:
				visible_count += 1
				var definition: Dictionary = game.BUILDINGS[type]
				if not game.building_in_build_category(str(type), category):
					fail("%s分类页混入%s" % [category, type])
				check_inside_viewport(button, "%s按钮" % definition.name)
		var page_limit := 5 if category == "basic" else 3
		if visible_count > page_limit:
			fail("%s分类同时显示%d个建筑，底栏可能溢出" % [category, visible_count])
	if not game.build_buttons.market.disabled or str(game.build_buttons.market.text).find("开拓北坡") < 0:
		fail("锁定集市没有在菜单说明北坡解锁条件")
	check_inside_viewport(game.bottom_panel, "分页建造栏")
	for category in game.build_category_buttons:
		check_inside_viewport(game.build_category_buttons[category], "%s分类按钮" % category)


func check_composite_models(_game) -> void:
	var markers := {
		"market": "MarketRoofBanner",
		"clinic": "ClinicGourdLower",
		"academy": "AcademyRoofScroll",
	}
	for type in markers:
		var model := RealisticKit.create_building(type, false, false)
		if model == null:
			fail("%s组合模型无法创建" % type)
			continue
		if str(model.get_meta("building_type", "")) != type:
			fail("%s模型未保留独立建筑类型" % type)
		if str(model.get_meta("asset_source", "")) != "realistic":
			fail("%s没有复用写实模型" % type)
		if model.find_child(str(markers[type]), true, false) == null:
			fail("%s缺少俯视识别构件%s" % [type, markers[type]])
		model.free()


func check_market_operation(game) -> void:
	prepare_layout(game, [{"type": "market", "cell": Vector2i(8, 8)}], 10, 50, 100)
	game.next_day()
	if int(game.food) != 42:
		fail("集市每日应在居民口粮后整份消耗3粮，实际剩余%d" % game.food)
	if int(game.coins) != 112:
		fail("集市应收入9钱、人口税5钱并支付2钱维护，实际%d" % game.coins)
	if not bool(game.buildings[0].last_running):
		fail("满员集市没有标记为营业")


func check_clinic_operation(game) -> void:
	prepare_layout(game, [{"type": "market", "cell": Vector2i(8, 8)}], 10, 80, 100)
	game.happiness = 56
	game.next_day()
	var market_happiness := int(game.happiness)
	prepare_layout(game, [{"type": "clinic", "cell": Vector2i(8, 8)}], 10, 80, 100)
	game.happiness = 56
	game.next_day()
	if int(game.happiness) < market_happiness + 5:
		fail("运转医馆没有产生明确幸福收益：%d/%d" % [game.happiness, market_happiness])
	if not bool(game.buildings[0].last_running):
		fail("满员医馆没有标记为应诊")


func check_academy_operation(game) -> void:
	prepare_layout(game, [{"type": "academy", "cell": Vector2i(8, 8)}], 10, 80, 100)
	game.next_day()
	# 5人口税 + 5书院收入 - 4维护。
	if int(game.coins) != 106:
		fail("书院税收与维护结算错误，实际铜钱%d" % game.coins)
	if not bool(game.buildings[0].last_running):
		fail("满员书院没有标记为开课")


func check_pause_and_v3_roundtrip(game) -> void:
	prepare_layout(game, [
		{"type": "market", "cell": Vector2i(8, 8)},
		{"type": "clinic", "cell": Vector2i(9, 8)},
		{"type": "academy", "cell": Vector2i(10, 8)},
	], 20, 100, 100)
	game.set_building_enabled(int(game.buildings[0].id), false)
	game.save_game(false)
	game.load_game(false)
	if game.buildings.size() != 3:
		fail("v3存档未完整读取三种区域建筑")
		return
	var loaded_types := {}
	for record in game.buildings:
		loaded_types[str(record.type)] = bool(record.get("enabled", true))
	for type in ["market", "clinic", "academy"]:
		if not loaded_types.has(type):
			fail("v3存档丢失%s" % type)
	if bool(loaded_types.get("market", true)):
		fail("集市暂停状态没有通过v3存档保留")


func prepare_layout(game, layout: Array, residents: int, provisions: int, money: int) -> void:
	for child in game.building_root.get_children():
		child.queue_free()
	game.buildings.clear()
	game.occupied.clear()
	game.next_id = 1
	game.map_region_level = 6
	game.day = 2
	game.wood = 100
	game.food = provisions
	game.coins = money
	game.population = residents
	game.happiness = 60
	game.low_happiness_days = 0
	game.stable_days = 0
	game.maintenance_debt = 0
	game.ended = ""
	for item in layout:
		game.add_building(str(item.type), item.cell, true)
	game.assign_workers()


func check_inside_viewport(control: Control, label: String) -> void:
	var rect := control.get_global_rect()
	if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > VIEWPORT_SIZE.x + 1.0 or rect.end.y > VIEWPORT_SIZE.y + 1.0:
		fail("%s超出1366x768视口：%s" % [label, rect])


func preserve_save_file() -> void:
	original_save_exists = FileAccess.file_exists(SAVE_PATH)
	if original_save_exists:
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
	push_error("REGIONAL_BUILDINGS_ACCEPTANCE_FAILED: " + message)


func finish() -> void:
	if failures.is_empty():
		print("REGIONAL_BUILDINGS_ACCEPTANCE_OK: 5 opening buildings, 3 unlock tiers, paged menu, distinct models, daily effects, pause, v3 persistence")
		quit(0)
	else:
		print("REGIONAL_BUILDINGS_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
