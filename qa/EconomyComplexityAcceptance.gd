extends SceneTree

## Release acceptance for the v3 economy.  These checks exercise the live Main
## scene instead of duplicating the settlement formulas, so save migration,
## production, labour allocation, upkeep and the visible objective copy must
## continue to work together.

const VIEWPORT_SIZE := Vector2i(1366, 768)
const SAVE_PATH := "res://saves/savegame.json"

var failures: Array[String] = []
var original_save_exists := false
var original_save_text := ""
var save_snapshot_ready := false


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
	if game.get_script() == null or not game.has_method("next_day"):
		fail("主场景脚本未成功加载")
		finish()
		return

	game.time_paused = true
	check_economy_contract(game)
	check_v2_save_migration(game)
	check_labour_reduces_production(game)
	check_pause_releases_labour(game)
	check_zero_coin_recovery(game)
	check_workshop_atomic_recipe(game)
	check_maintenance_and_stability(game)
	check_storage_and_region_costs(game)
	check_objective_ui_has_no_progress(game)

	game.time_paused = true
	restore_save_file()
	finish()


func check_economy_contract(game) -> void:
	if int(game.SAVE_VERSION) != 3:
		fail("经济存档版本应为 v3，实际为 v%d" % int(game.SAVE_VERSION))
	for property_name in ["coins", "stable_days"]:
		if not has_property(game, property_name):
			fail("经济状态缺少字段：%s" % property_name)
	for type in ["farm", "lumber", "workshop"]:
		var definition: Dictionary = game.BUILDINGS.get(type, {})
		if int(definition.get("workers", 0)) <= 0:
			fail("%s 没有配置岗位需求" % type)
	for type in ["farm", "lumber", "warehouse", "workshop"]:
		var definition: Dictionary = game.BUILDINGS.get(type, {})
		if int(definition.get("maintenance", 0)) <= 0:
			fail("%s 没有配置铜钱维护费" % type)
	var workshop: Dictionary = game.BUILDINGS.get("workshop", {})
	if int(workshop.get("workers", 0)) != 3:
		fail("小工坊应需要 3 名工人")
	if int(game.BASIC_TRADE_COINS_PER_SITE) <= 0 or int(game.BASIC_TRADE_COIN_CAP) <= 0:
		fail("开局生产建筑没有配置民生交易收入")
	if int(game.BASIC_TRADE_COIN_CAP) >= 10:
		fail("民生交易收入不应追平小工坊的 10 铜钱加工收入")
	for type in ["farm", "lumber"]:
		if str(game.building_tooltip_text(type)).find("民生交易") < 0:
			fail("%s说明没有向玩家解释民生交易收入" % game.BUILDINGS[type].name)


func check_v2_save_migration(game) -> void:
	var legacy := {
		"version": 2,
		"map_region_level": 2,
		"day": 7,
		"wood": 50,
		"food": 30,
		"population": 4,
		"happiness": 60,
		"low_happiness_days": 0,
		"next_id": 2,
		"ended": "",
		"buildings": [
			{"id": 1, "type": "house", "x": 9, "z": 9},
		],
	}
	write_save_text(JSON.stringify(legacy, "  "))
	game.load_game(false)
	if int(game.day) != 7 or int(game.map_region_level) != 2 or int(game.wood) != 50 or int(game.food) != 30:
		fail("读取旧 v2 存档时改变了原有日期、区域或资源")
	if int(game.coins) <= 0:
		fail("旧 v2 存档没有获得可继续经营的兼容铜钱")
	if int(game.stable_days) != 0:
		fail("旧 v2 存档的稳定天数应从 0 开始")
	if game.buildings.size() != 1 or not bool(game.buildings[0].get("enabled", false)):
		fail("旧建筑迁移后没有默认启用")

	game.save_game(false)
	var migrated := read_save_json()
	if int(migrated.get("version", 0)) != 3:
		fail("旧存档保存后没有升级为 v3")
	for field in ["coins", "stable_days"]:
		if not migrated.has(field):
			fail("升级后的 v3 存档缺少字段：%s" % field)
	var saved_buildings: Array = migrated.get("buildings", [])
	if saved_buildings.is_empty() or not saved_buildings[0].has("enabled") or not bool(saved_buildings[0].enabled):
		fail("升级后的建筑记录没有保存 enabled=true")


func check_labour_reduces_production(game) -> void:
	var layout := [
		{"type": "farm", "cell": Vector2i(1, 10)},
		{"type": "farm", "cell": Vector2i(4, 11)},
		{"type": "lumber", "cell": Vector2i(14, 10)},
		{"type": "lumber", "cell": Vector2i(15, 11)},
	]
	var short_result := run_one_day(game, layout, 4, 30, 80, 500)
	var full_result := run_one_day(game, layout, 12, 30, 80, 500)
	var short_farm_output := int(short_result.food_delta) + ration_for(4)
	var full_farm_output := int(full_result.food_delta) + ration_for(12)
	if short_farm_output >= full_farm_output:
		fail("劳动力不足没有降低农田总产出：不足 %d，充足 %d" % [short_farm_output, full_farm_output])
	if int(short_result.wood_delta) >= int(full_result.wood_delta):
		fail("劳动力不足没有降低伐木场总产出：不足 %d，充足 %d" % [short_result.wood_delta, full_result.wood_delta])
	if game.has_method("available_workers"):
		game.population = 4
		if int(game.available_workers()) != 3:
			fail("人口 4 时有效劳动力应为 ceil(4*70%) = 3")
	else:
		fail("主场景缺少 available_workers()，无法解释岗位供给")


func check_pause_releases_labour(game) -> void:
	var layout := [
		{"type": "farm", "cell": Vector2i(1, 10)},
		{"type": "farm", "cell": Vector2i(4, 11)},
		{"type": "lumber", "cell": Vector2i(14, 10)},
	]
	var all_enabled := run_one_day(game, layout, 4, 30, 80, 500)
	prepare_layout(game, layout, 4, 30, 80, 500)
	var farm_id := first_building_id(game, "farm")
	if farm_id < 0:
		fail("暂停验收没有找到农田")
		return
	set_building_enabled_for_test(game, farm_id, false)
	var paused_record := building_by_id(game, farm_id)
	if paused_record.is_empty() or bool(paused_record.get("enabled", true)):
		fail("农田没有进入暂停状态")
	var wood_before := int(game.wood)
	game.next_day()
	var paused_wood_gain := int(game.wood) - wood_before
	if paused_wood_gain <= int(all_enabled.wood_delta):
		fail("暂停农田没有把劳动力释放给伐木场：暂停后 %d，全部启用 %d" % [paused_wood_gain, all_enabled.wood_delta])


func check_zero_coin_recovery(game) -> void:
	var no_workshop: Array = [
		{"type": "farm", "cell": Vector2i(1, 10)},
		{"type": "lumber", "cell": Vector2i(14, 10)},
		{"type": "warehouse", "cell": Vector2i(10, 10)},
	]
	var last_resident := run_one_day(game, [], 1, 50, 80, 0)
	if int(last_resident.coin_delta) < 1:
		fail("仅剩 1 名居民且铜钱为零时，最低人口税没有提供恢复渠道")
	var passive := run_one_day(game, [], 4, 50, 80, 0)
	var productive := run_one_day(game, no_workshop, 4, 50, 80, 0)
	if int(passive.coin_delta) <= 0:
		fail("零铜钱且没有工坊时，人口税仍无法提供最低恢复渠道")
	if int(productive.coin_delta) <= int(passive.coin_delta):
		fail("维持农田和伐木场没有比无脑等待更快地恢复铜钱")
	if str(game.message_label.text).find("民生交易") < 0:
		fail("每日结算没有显示民生交易收入")

	prepare_layout(game, no_workshop, 4, 50, 80, 0)
	var workshop_cost := int(game.BUILDINGS.workshop.coin_cost)
	var recovery_days := 0
	while int(game.coins) < workshop_cost and recovery_days < 8:
		game.next_day()
		recovery_days += 1
	if int(game.building_count("workshop")) != 0:
		fail("零铜钱恢复模拟意外预建了小工坊")
	if int(game.coins) < workshop_cost:
		fail("零铜钱、无小工坊且承担 3 铜钱维护时，基础生产在 8 日内仍无法恢复到小工坊造价")
	if int(game.wood) < int(game.BUILDINGS.workshop.cost):
		fail("恢复到小工坊铜钱造价时，基础生产没有保留足够木材")

	prepare_layout(game, [
		{"type": "house", "cell": Vector2i(10, 9)},
		{"type": "farm", "cell": Vector2i(1, 10)},
		{"type": "lumber", "cell": Vector2i(14, 10)},
	], 8, 100, 100, 0)
	game.stable_days = 1
	# Income channels are explained by their building descriptions and daily
	# settlement report. The chapter goal stays fixed instead of turning into a
	# changing economy hint as individual thresholds are met.
	var fixed_goal := str(game.current_task_text(1))
	if fixed_goal != "建好河湾聚落，开拓北坡":
		fail("经济状态改变了第一章固定目标：%s" % fixed_goal)


func check_workshop_atomic_recipe(game) -> void:
	var no_workshop: Array = []
	var workshop_layout := [{"type": "workshop", "cell": Vector2i(10, 10)}]
	var control := run_one_day(game, no_workshop, 20, 50, 80, 500)
	var operating := run_one_day(game, workshop_layout, 20, 50, 80, 500)
	if int(operating.wood_delta) - int(control.wood_delta) != -4:
		fail("满员小工坊没有原子扣除 4 木材")
	if int(operating.food_delta) - int(control.food_delta) != -2:
		fail("满员小工坊没有原子扣除 2 粮食")
	# The workshop earns 10 coins and also adds its own 2-coin maintenance.
	if int(operating.coin_delta) - int(control.coin_delta) != 8:
		fail("满员小工坊应在维护前增加 10 铜钱（净差应为 8）")

	var understaffed_control := run_one_day(game, no_workshop, 2, 50, 40, 500)
	var understaffed := run_one_day(game, workshop_layout, 2, 50, 40, 500)
	if int(understaffed.wood_delta) != int(understaffed_control.wood_delta) or int(understaffed.food_delta) != int(understaffed_control.food_delta):
		fail("小工坊缺工时仍扣除了部分配方原料")
	if int(understaffed.coin_delta) - int(understaffed_control.coin_delta) >= 8:
		fail("小工坊缺工时仍获得了完整铜钱产出")

	var starved_control := run_one_day(game, no_workshop, 20, 3, 80, 500)
	var starved := run_one_day(game, workshop_layout, 20, 3, 80, 500)
	if int(starved.wood_delta) != int(starved_control.wood_delta) or int(starved.food_delta) != int(starved_control.food_delta):
		fail("小工坊缺木材时发生了部分扣料")
	if int(starved.coin_delta) - int(starved_control.coin_delta) >= 8:
		fail("小工坊缺料时仍获得了完整铜钱产出")


func check_maintenance_and_stability(game) -> void:
	var costly_layout := [
		{"type": "warehouse", "cell": Vector2i(10, 10)},
		{"type": "warehouse", "cell": Vector2i(11, 10)},
		{"type": "warehouse", "cell": Vector2i(12, 10)},
	]
	prepare_layout(game, costly_layout, 1, 40, 50, 0)
	game.stable_days = 5
	game.happiness = 80
	game.next_day()
	if int(game.stable_days) != 0:
		fail("铜钱不足、维护未付时 stable_days 没有归零")
	if int(game.happiness) >= 80:
		fail("维护不足没有使幸福度下行")

	var stable_layout := [
		{"type": "house", "cell": Vector2i(10, 9)},
		{"type": "farm", "cell": Vector2i(1, 10)},
		{"type": "farm", "cell": Vector2i(4, 11)},
		{"type": "lumber", "cell": Vector2i(14, 10)},
	]
	prepare_layout(game, stable_layout, 8, 60, 120, 100)
	game.stable_days = 0
	game.happiness = 70
	game.day = 10
	game.next_day()
	game.next_day()
	if int(game.stable_days) < 2:
		fail("人员、粮食和维护充足的布局无法连续累计 stable_days")


func check_storage_and_region_costs(game) -> void:
	game.reset_game(false)
	game.time_paused = true
	if int(game.wood_capacity()) != 100 or int(game.food_capacity()) != 100:
		fail("无仓库时木材和粮食容量应为 100")
	game.add_building("warehouse", Vector2i(10, 10), true)
	if int(game.wood_capacity()) != 175 or int(game.food_capacity()) != 175:
		fail("每座仓库应使木材和粮食容量各增加 75")
	game.add_building("warehouse", Vector2i(11, 10), true)
	if int(game.wood_capacity()) != 250 or int(game.food_capacity()) != 250:
		fail("两座仓库的木材和粮食容量应为 250")
	for level in range(1, game.REGION_UNLOCK_COSTS.size()):
		var cost: Dictionary = game.REGION_UNLOCK_COSTS[level]
		if not cost.has("coins") or int(cost.coins) <= 0:
			fail("第 %d 级区域开拓费用缺少铜钱" % level)


func check_objective_ui_has_no_progress(game) -> void:
	game.reset_game(false)
	game.time_paused = true
	game.region_panel_collapsed = false
	game.update_ui()
	var parts: Array[String] = [str(game.goal_label.text)]
	collect_visible_text(game.region_panel, parts)
	var visible_goal_text := "\n".join(parts)
	if visible_goal_text.find("进度") >= 0:
		fail("可见目标 UI 仍显示“进度”：%s" % visible_goal_text)
	for forbidden in ["当前/要求", "当前值/要求值", "当前值 / 要求值"]:
		if visible_goal_text.find(forbidden) >= 0:
			fail("可见目标 UI 仍显示“%s”" % forbidden)
	var fraction := RegEx.new()
	fraction.compile("[0-9]+\\s*/\\s*[0-9]+")
	var fraction_match := fraction.search(visible_goal_text)
	if fraction_match != null:
		fail("可见目标 UI 仍显示数字进度：%s" % fraction_match.get_string())
	if visible_goal_text.find("目标") < 0:
		fail("移除进度后，可见目标 UI 没有保留目标文案")


func prepare_layout(game, layout: Array, target_population: int, start_wood: int, start_food: int, start_coins: int) -> void:
	game.reset_game(false)
	game.time_paused = true
	game.day = 2
	game.ended = ""
	for item in layout:
		game.add_building(str(item.type), item.cell, true)
	game.population = target_population
	game.wood = start_wood
	game.food = start_food
	game.coins = start_coins
	game.happiness = 70
	game.stable_days = 0


func run_one_day(game, layout: Array, target_population: int, start_wood: int, start_food: int, start_coins: int) -> Dictionary:
	prepare_layout(game, layout, target_population, start_wood, start_food, start_coins)
	var before := {"wood": int(game.wood), "food": int(game.food), "coins": int(game.coins)}
	game.next_day()
	return {
		"wood_delta": int(game.wood) - int(before.wood),
		"food_delta": int(game.food) - int(before.food),
		"coin_delta": int(game.coins) - int(before.coins),
	}


func ration_for(target_population: int) -> int:
	return ceili(target_population / 2.0)


func first_building_id(game, type: String) -> int:
	for record in game.buildings:
		if str(record.type) == type:
			return int(record.id)
	return -1


func building_by_id(game, building_id: int) -> Dictionary:
	for record in game.buildings:
		if int(record.id) == building_id:
			return record
	return {}


func set_building_enabled_for_test(game, building_id: int, enabled: bool) -> void:
	if game.has_method("set_building_enabled"):
		game.set_building_enabled(building_id, enabled)
		return
	# Keep the acceptance independent of the inspector's presentation method.
	# The authoritative record must still expose the persisted enabled flag.
	for index in range(game.buildings.size()):
		var record: Dictionary = game.buildings[index]
		if int(record.id) != building_id:
			continue
		record["enabled"] = enabled
		game.buildings[index] = record
		return
	fail("无法设置建筑启用状态")


func collect_visible_text(node: Node, parts: Array[String]) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label:
		parts.append(str((node as Label).text))
	elif node is Button:
		parts.append(str((node as Button).text))
	for child in node.get_children():
		collect_visible_text(child, parts)


func has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if str(property.name) == property_name:
			return true
	return false


func preserve_save_file() -> void:
	original_save_exists = FileAccess.file_exists(SAVE_PATH)
	if not original_save_exists:
		save_snapshot_ready = true
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		fail("无法暂存验收前的真实存档")
		return
	original_save_text = file.get_as_text()
	save_snapshot_ready = true


func restore_save_file() -> void:
	if not save_snapshot_ready:
		return
	if original_save_exists:
		write_save_text(original_save_text)
		return
	if FileAccess.file_exists(SAVE_PATH):
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if error != OK:
			fail("无法清理验收生成的临时存档")


func write_save_text(contents: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		fail("无法写入验收存档")
		return
	file.store_string(contents)


func read_save_json() -> Dictionary:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		fail("无法读取验收存档")
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		fail("验收存档不是有效 JSON 对象")
		return {}
	return parsed


func fail(message: String) -> void:
	failures.append(message)
	push_error("ECONOMY_COMPLEXITY_ACCEPTANCE_FAILED: " + message)


func finish() -> void:
	if failures.is_empty():
		print("ECONOMY_COMPLEXITY_ACCEPTANCE_OK: v3 migration, labour, pause, zero-coin recovery, basic trade, atomic workshop, maintenance, stability, storage, coin gates, concise goals")
		quit(0)
	else:
		print("ECONOMY_COMPLEXITY_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
