extends SceneTree

## Deliberately bypass Main._ready: this fixture never opens any player save or
## audio preference file. All save/load calls made by UI callbacks are no-ops.
class IsolatedGame extends "res://godot/Main.gd":
	var fixture_io := false
	func _ready() -> void:
		pass
	func create_background_music() -> void:
		pass
	func create_music_settings(_settings_box: VBoxContainer) -> void:
		pass
	func save_game(show_feedback := true) -> void:
		if fixture_io:
			super.save_game(show_feedback)
	func load_game(show_feedback := true) -> void:
		if fixture_io:
			super.load_game(show_feedback)
	func save_path() -> String:
		return "res://.godot-user/qa/needs-economy-roundtrip-fixture.json"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("NEEDS_INTEGRATION_FAILED: " + message)

func same_saved_value(a: Variant, b: Variant) -> bool:
	# JSON represents numbers as floating point. Compare sub-second cargo timers
	# within serialization precision, while integral fixed-point amounts stay exact.
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) < 0.0000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same_saved_value(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not same_saved_value(a[index], b[index]): return false
		return true
	return a == b

func find_site(game: Node, type: String, quarter := 0, region := -1) -> Vector2i:
	var best := Vector2i(-1, -1)
	var distance := 100000
	for z in range(game.GRID_SIZE):
		for x in range(game.GRID_SIZE):
			var cell := Vector2i(x, z)
			if region >= 0 and game.region_level_for_cell(cell) != region:
				continue
			if game.can_place(type, cell, quarter) == "":
				var score := absi(x - 10) + absi(z - 10)
				if score < distance:
					distance = score
					best = cell
	return best

func connect_record(game: Node, record: Dictionary) -> bool:
	var frontier: Array = []
	var came_from: Dictionary = {}
	for cell in game.building_boundary_cells(record):
		if game.is_village_main_road_cell(cell):
			return true
		if game.can_place_road(cell) == "" or game.roads.has(cell):
			frontier.append(cell)
			came_from[cell] = cell
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if game.is_village_main_road_cell(cell):
			var current: Vector2i = came_from[cell]
			while true:
				if not game.roads.has(current) and not game.is_village_main_road_cell(current):
					game.add_road(current)
				if came_from[current] == current:
					break
				current = came_from[current]
			return true
		for next in game.cardinal_cells(cell):
			if came_from.has(next):
				continue
			if game.is_village_main_road_cell(next) or game.roads.has(next) or game.can_place_road(next) == "":
				came_from[next] = cell
				frontier.append(next)
	return false

func build_paid_opening(game: Node) -> void:
	# The lower initial stock cannot buy the entire opening at once. Establish
	# actual timber production first, add housing for its workers, then spend
	# only earned timber on food/water buildings and their connecting roads.
	for type in ["lumber", "house", "farm", "well"]:
		var required_wood := int(game.BUILDINGS[type].cost) + 6
		for attempt in range(24):
			if game.wood >= required_wood:
				break
			game.economy.advance(10.0)
			game.refresh_economy_snapshot()
		check(game.wood >= required_wood, "paid opening earns enough timber for %s and roads within four days" % type)
		var site := find_site(game, type)
		check(site.x >= 0, "%s has an affordable legal paid-opening site" % type)
		if site.x < 0:
			continue
		var previous_count: int = game.buildings.size()
		var previous_wood: float = game.economy.snapshot().goods.wood
		var previous_coins: float = game.economy.snapshot().coins
		game.add_building(type, site)
		check(game.buildings.size() == previous_count + 1, "paid opening constructs %s using actual resources" % type)
		if game.buildings.size() != previous_count + 1:
			continue
		check(is_equal_approx(previous_wood - float(game.economy.snapshot().goods.wood), float(game.BUILDINGS[type].cost)), "%s pays its exact timber price" % type)
		check(is_equal_approx(previous_coins - float(game.economy.snapshot().coins), float(game.BUILDINGS[type].coin_cost)), "%s pays its exact copper price" % type)
		check(connect_record(game, game.buildings[-1]), "%s connects to actual trunk road with paid roads" % type)
		game.sync_economy_buildings()
		check(not game.economy.snapshot().failed, "paid opening remains alive after building %s" % type)
	print("PAID_OPENING elapsed=", game.economy.snapshot().elapsed, " wood=", game.wood, " coins=", game.coins, " population=", game.population)

func run() -> void:
	root.size = Vector2i(1366, 768)
	var game := IsolatedGame.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.create_world()
	game.create_ui()
	game.reset_game(false)
	game.time_paused = true
	check(game.economy.snapshot().goods.cloth == 12, "Main new game starts with twelve clothes")
	var initial_capacity: Dictionary = game.economy.snapshot().capacities
	check(initial_capacity.wood == 100 and initial_capacity.water == 50 and initial_capacity.food == 100 and initial_capacity.cloth == 60, "Main new settlement uses distinct wood/water/food/clothing capacities")
	check(game.economy.SPECS.well.rate == 10 and game.economy.SPECS.farm.rate == 8, "Main production catalog uses ten water and eight food daily")
	check(game.wood == 100 and game.economy.snapshot().goods.wood == 100, "initial standing house leaves the full100 timber starting stock")
	game.update_ui()
	for item in [{"name":"木材", "value": game.wood, "capacity":100}, {"name":"水", "value":40, "capacity":50}, {"name":"粮食", "value":40, "capacity":100}, {"name":"衣物", "value":12, "capacity":60}]:
		check(game.status_label.text.contains("%s %d/%d" % [item.name, item.value, item.capacity]), "top UI displays the correct individual capacity for " + str(item.name))
	check(str(game.status_label.get("cloth_tooltip")).begins_with("相关物料：麻 0"), "clothing tooltip explicitly identifies its related material and current stock")
	check(game.INITIAL_BUILDING_TYPES.size() == 6 and "well" in game.INITIAL_BUILDING_TYPES, "well joins all five original initial building types")
	check(game.household_rate(4, 8) == "1/2日", "household rate uses an integer day denominator")
	check(game.household_rate(1, 2) == "1/2日", "single-resident rate does not show a decimal")
	check(game.BUILDINGS.has("weaver"), "weaver is a functional new building type")
	check(game.BUILDINGS.size() == 26, "full campaign exposes twenty-six functional building types")
	check(game.BUILDINGS.has("hemp_farm"), "hemp farming is an independent fixed-function building")
	for type in game.BUILDINGS:
		check(game.economy.SPECS.has(type), "%s has an economic specification rather than an empty shell" % type)
	for type in game.BUILDINGS:
		var footprint: Vector2i = game.BUILDING_FOOTPRINTS.get(type, Vector2i.ONE)
		check(footprint == Vector2i.ONE if type == "house" else footprint.x >= 2 and footprint.y >= 2, "%s footprint obeys only-house-1x1 requirement" % type)
	check(game.BUILDING_FOOTPRINTS.get("market") == Vector2i(3, 3), "market has a full open 3x3 layout")
	check(game.BUILDING_FOOTPRINTS.get("fishpond") == Vector2i(3, 3), "pond uses expanded 3x3 footprint")
	check(game.BUILDING_FOOTPRINTS.get("warehouse") == Vector2i(2, 2), "warehouse now occupies exactly four tiles")
	# Geometric capacity test, separate from economic affordability. The whole
	# initial six-type kit must coexist on actual generated terrain and trees.
	game.economy.apply_resources({"wood": 10000, "coins": 10000})
	game.refresh_economy_snapshot()
	for type in game.INITIAL_BUILDING_TYPES:
		if type == "house":
			continue
		var cell := find_site(game, type)
		var quarter := 0
		check(cell.x >= 0, "%s has an initial site in default orientation without requiring rotation knowledge" % type)
		if cell.x < 0:
			quarter = 1
			cell = find_site(game, type, quarter)
		check(cell.x >= 0, "%s has a legal site in the initial region alongside the other initial buildings" % type)
		if cell.x >= 0:
			game.add_building(type, cell, true, -1, true, Vector2i.ZERO, quarter)
			print("INITIAL_SITE ", type, " ", cell, " rotation=", quarter)
	# Rotation and occupancy are exercised on every rectangular type, using
	# generated terrain. No legacy fixed-cell assumptions survive the expansion.
	game.map_region_level = 6
	# Geometry-only coverage grants all construction materials; the paid opening
	# below still uses the real starting economy without any grants.
	var placement_materials: Dictionary = {}
	for good in game.economy.GOODS:
		placement_materials[good] = 100
	game.economy.apply_resources(placement_materials)
	game.refresh_economy_snapshot()
	for type in game.BUILDINGS:
		if type == "house":
			continue
		var valid_rotations := 0
		for quarter in range(4):
			var cell := find_site(game, type, quarter)
			if type != "dock":
				check(cell.x >= 0, "%s rotation %d has legal map placement" % [type, quarter])
			if cell.x < 0:
				continue
			valid_rotations += 1
			game.add_building(type, cell, true, -1, true, Vector2i.ZERO, quarter)
			var record: Dictionary = game.buildings[-1]
			game.show_inspector(int(record.id))
			for button in game.inspector.find_children("*", "Button", true, false):
				for removed_action in ["用工：", "暂停生产", "启用生产", "改种", "工艺"]:
					check(not button.text.contains(removed_action), "%s inspector has no obsolete %s control" % [type, removed_action])
			game.inspector.hide()
			var expected: Vector2i = game.rotated_footprint(game.BUILDING_FOOTPRINTS[type], quarter)
			check(game.record_footprint(record) == expected, "%s rotated footprint" % type)
			check(record.node.position.is_equal_approx(game.building_model_position(type, cell, expected)), "%s model centered over rotated footprint" % type)
			check(record.node.scale.is_equal_approx(Vector3.ONE), "%s authored model is not stretched" % type)
			for covered in game.building_footprint_cells(type, cell, expected):
				check(game.occupied.get(covered, -1) == record.id, "%s occupied cell selects its owner" % type)
				check(game.can_place_road(covered) != "", "%s occupied cell rejects road" % type)
			game.remove_building_by_id(int(record.id), false)
			for covered in game.building_footprint_cells(type, cell, expected):
				check(not game.occupied.has(covered), "%s demolition releases every cell" % type)
			await process_frame
		check(valid_rotations >= 1, "%s has at least one legal orientation on actual terrain" % type)
	# Chapter conditions remain five stable numerical thresholds with individual
	# completion bits. Economic settings cannot rewrite these targets.
	game.population = 8
	game.happiness = 60
	game.wood = 1
	game.food = 1
	game.coins = 1
	var goals: Array = game.chapter_numeric_goals(1)
	check(goals.size() == 5, "exactly five numeric chapter conditions")
	for item in goals:
		check(str(item.key) in ["population", "happiness", "wood", "food", "coins"], "no building-count/date chapter goal")
		check(bool(item.completed) == (str(item.key) in ["population", "happiness"]), "each achieved numeric condition independently completes")
	var fixed_goal := game.current_task_text(1)
	game.day += 30
	game.population = 4
	check(game.current_task_text(1) == fixed_goal, "goal text does not mutate as time and population change")
	check(game.help_dialog.dialog_text.contains("R："), "help keeps R rotation")
	for button in game.find_children("*", "Button", true, false):
		check(not button.text.contains("旋转"), "no persistent rotation button")
	# The starting residence can be upgraded before any expansion. It supplies
	# skilled residents, but does not fabricate goods inside the home.
	game.reset_game(false)
	game.time_paused = true
	check(int(game.economy.snapshot().workforce) == game.population, "each resident supplies one worker")
	game.show_inspector(int(game.buildings[0].id))
	check(not game.inspector_promote_button.disabled, "starting-region occupied house permits artisan upgrade")
	game.promote_selected_house()
	game.economy.advance(60.0)
	game.refresh_economy_snapshot()
	var artisan_opening: Dictionary = game.economy.snapshot()
	check(int(artisan_opening.artisan_workers) == 4, "four upgraded residents supply four artisans immediately on completion")
	game.economy.advance(60.0)
	artisan_opening = game.economy.snapshot()
	check(float(artisan_opening.goods.tools) == 0, "upgraded residence does not manufacture wooden goods")
	# Real opening construction must earn workshop income before promotion,
	# trade orders or later-region unlocks. No resources are injected here.
	game.reset_game(false)
	game.time_paused = true
	build_paid_opening(game)
	game.sync_economy_buildings()
	game.economy.advance(60.0)
	game.refresh_economy_snapshot()
	check(game.population == 8, "ordinary opening reaches eight residents in one day without hidden job prerequisites")
	# Wait only for wood earned by the actual sawmill, with a finite bound.
	for attempt in 12:
		if game.wood >= int(game.BUILDINGS.workshop.cost) + 5:
			break
		game.economy.advance(15.0)
		game.refresh_economy_snapshot()
	var opening_workshop_site := find_site(game, "workshop")
	check(opening_workshop_site.x >= 0, "early direct-income workshop has a legal site")
	var opening_workshop_id := -1
	if opening_workshop_site.x >= 0:
		var opening_count: int = game.buildings.size()
		game.add_building("workshop", opening_workshop_site)
		check(game.buildings.size() == opening_count + 1, "workshop construction paid using actual opening resources")
		if game.buildings.size() == opening_count + 1:
			opening_workshop_id = int(game.buildings[-1].id)
			check(connect_record(game, game.buildings[-1]), "opening workshop reaches trunk road")
			game.sync_economy_buildings()
			var before_workshop: Dictionary = game.economy.snapshot()
			game.economy.advance(60.0)
			var earning_workshop: Dictionary = game.economy.snapshot()
			var workshop_status: Dictionary = earning_workshop.building_status[str(opening_workshop_id)]
			check(workshop_status.worker_kind == "normal" and int(workshop_status.workers) == 2 and workshop_status.ok, "initial workshop works with two ordinary residents")
			check(int(earning_workshop.artisan_workers) == 0 and earning_workshop.trade_orders.is_empty(), "direct workshop income needs neither artisans nor trade orders")
			check(float(earning_workshop.coins) > float(before_workshop.coins) and float(earning_workshop.rates.coins) > 0, "early staffed workshop produces positive daily net copper")
			check(float(earning_workshop.goods.tools) == 0, "workshop no longer accumulates unsold wooden goods")
			# Deliberate shortage fixture after the paid opening: remove only its
			# wood producer and stock, so taxes cannot be mistaken for production.
			var lumber_id := -1
			for record in game.buildings:
				if record.type == "lumber": lumber_id = int(record.id)
			game.remove_building_by_id(lumber_id, false)
			var available_wood: float = game.economy.snapshot().goods.wood
			game.economy.apply_resources({"wood": -available_wood})
			var before_shortage: Dictionary = game.economy.snapshot()
			game.economy.advance(60.0)
			var no_wood: Dictionary = game.economy.snapshot()
			check(not no_wood.building_status[str(opening_workshop_id)].ok, "workshop reports a wood shortage")
			check(float(no_wood.coins) - float(before_shortage.coins) <= 1.01, "wood-starved workshop earns no processing income; only taxes minus maintenance remain")
	# A real generated-map opening spends the actual build and road costs, then
	# uses the pure settlement clock. It never fabricates connected:true records.
	game.reset_game(false)
	game.time_paused = true
	build_paid_opening(game)
	game.sync_economy_buildings()
	game.economy.advance(30.0)
	game.refresh_economy_snapshot()
	check(game.population > 4, "first migrants arrive within thirty simulated seconds with homes and surplus food")
	game.economy.immigration_enabled = false
	var opening: Dictionary = game.economy.snapshot()
	for record in game.buildings:
		check(opening.building_status[str(record.id)].reason != "未连通主干路", "opening %s uses a verified actual road connection" % record.type)
	game.economy.advance(600.0)
	game.refresh_economy_snapshot()
	var survived: Dictionary = game.economy.snapshot()
	check(not survived.failed, "real-map farm/lumber opening survives ten minutes without workshop")
	check(float(survived.coins) >= float(opening.coins) - 0.01, "initial taxes cover farm/lumber maintenance without requiring a workshop")
	check(survived.goods.food > opening.goods.food and survived.goods.wood > opening.goods.wood, "real-map opening grows food and wood")
	# The game now exposes placement and household ecology, without a trade panel.
	for button in game.find_children("*", "Button", true, false):
		check(str(button.text) not in ["经营", "买入", "卖出", "查看运输"], "no management or manual trade button remains")
	# These inspect player-facing text only. Economic storage intentionally retains
	# fixed-point precision so integer UI cannot destroy fractional production.
	var decimal := RegEx.new()
	decimal.compile("[0-9]+\\.[0-9]+")
	for type in game.BUILDINGS:
		check(decimal.search(game.building_tooltip_text(type)) == null, "%s tooltip has integer quantities" % type)
	for record in game.buildings:
		if record.type == "house":
			game.show_inspector(int(record.id))
			check(not game.inspector_body.text.contains("缓冲"), "house details do not expose a buffer prerequisite")
			check(not game.inspector_body.text.contains("不占用劳力"), "house details omit redundant explanatory prose")
			check(decimal.search(game.inspector_body.text) == null, "household quantities are integer-readable")
			for child in game.inspector.find_children("*", "CheckButton", true, false):
				check(not child.visible or not child.text.contains("供应"), "house has no manual goods supply switches")
			break
	game.inspector.hide()
	# Automatic regional resupply still uses actual paid roads. A northern
	# household creates food and renovation-wood demand without manual routes.
	game.map_region_level = 1
	game.refresh_economy_snapshot()
	var regional_home := find_site(game, "house", 0, 1)
	check(regional_home.x >= 0, "unlocked northern region has a legal transport destination")
	if regional_home.x >= 0:
		game.add_building("house", regional_home)
		check(connect_record(game, game.buildings[-1]), "northern destination has actual paid roads")
	game.sync_economy_buildings()
	game.economy.immigration_enabled = true
	game.economy.advance(120.0)
	var cargo_snapshot: Dictionary = game.economy.snapshot()
	check(float(cargo_snapshot.regions.get("1", {}).get("goods", {}).get("wood", 0)) > 0, "automatic resupply delivers wood to occupied northern housing")
	check(float(cargo_snapshot.regions.get("1", {}).get("goods", {}).get("food", 0)) > 0, "automatic resupply delivers food through actual roads")
	check(float(cargo_snapshot.regions.get("1", {}).get("goods", {}).get("water", 0)) > 0, "automatic resupply delivers drinking water through actual roads")
	check(cargo_snapshot.clothing_unlocked, "Main expansion unlocks farmer clothing demand")
	check(cargo_snapshot.trade_orders.is_empty() and cargo_snapshot.routes.is_empty(), "automatic regional deliveries require no trade orders or manual routes")
	game.refresh_economy_snapshot()
	# Real Main save/load only becomes callable for this short isolated fixture.
	# _ready never runs and the hardcoded QA path cannot resolve to player saves.
	# The persistence fixture includes a rotated warehouse; placement geometry
	# is separately exercised for all four orientations above.
	game.economy.apply_resources({"wood": 100, "coins": 100})
	game.refresh_economy_snapshot()
	var warehouse_site := find_site(game, "warehouse", 1)
	check(warehouse_site.x >= 0, "2x2 rotated warehouse has a legal persistence-fixture site")
	var saved_warehouse_id := -1
	if warehouse_site.x >= 0:
		game.add_building("warehouse", warehouse_site, false, -1, true, Vector2i.ZERO, 1)
		var warehouse_record: Dictionary = game.buildings[-1]
		saved_warehouse_id = int(warehouse_record.id)
		check(warehouse_record.type == "warehouse" and game.record_footprint(warehouse_record) == Vector2i(2, 2), "saved warehouse has the current four-tile footprint")
		check(connect_record(game, warehouse_record), "persistence-fixture warehouse connects to trunk road")
	game.sync_economy_buildings()
	# Deliberately seed retired settings only in this isolated QA save, then
	# verify loading removes them instead of invisibly continuing transactions.
	game.economy.place_trade_order("cloth", "buy", 8, "0")
	game.economy.set_trade_policy("wood", "sell", 10, "0")
	game.economy.set_route("0", "1", "wood", 30, 4, true)
	game.economy.immigration_enabled = false
	var before_save: Dictionary = game.economy.serialize()
	var before_buildings := game.buildings.size()
	game.fixture_io = true
	game.save_game(false)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path()))
	check(game.validate_save_data(saved) == "", "new-format Main save validates")
	var inconsistent_ids: Dictionary = saved.duplicate(true)
	inconsistent_ids.economy.buildings[-1].id = "9999"
	check(game.validate_save_data(inconsistent_ids) != "", "mismatched scene and ledger IDs are rejected before load")
	game.economy.apply_resources({"coins": 100})
	game.load_game(false)
	game.fixture_io = false
	check(game.buildings.size() == before_buildings, "Main restores scene building count")
	var restored_warehouse := false
	for record in game.buildings:
		if int(record.id) != saved_warehouse_id:
			continue
		restored_warehouse = true
		check(record.type == "warehouse" and int(record.rotation_quarters) == 1, "warehouse identity and rotation survive Main save/load")
		check(game.record_footprint(record) == Vector2i(2, 2), "restored warehouse retains four-tile footprint")
		var warehouse_cells: Array = game.building_footprint_cells("warehouse", record.cell, game.record_footprint(record))
		check(warehouse_cells.size() == 4, "restored warehouse owns exactly four cells")
		for cell in warehouse_cells:
			check(int(game.occupied.get(cell, -1)) == saved_warehouse_id, "restored warehouse occupies every expected cell")
	check(restored_warehouse, "rotated warehouse exists after isolated load")
	var after_load: Dictionary = game.economy.serialize()
	for key in ["stock", "cash", "population", "households", "shipments", "remainders", "elapsed", "accumulator"]:
		check(same_saved_value(after_load[key], before_save[key]), "Main roundtrip preserves %s" % key)
	check(after_load.trade_orders.is_empty() and after_load.routes.is_empty(), "load discards retired trade orders and manual routes")
	check(bool(after_load.immigration_enabled), "load restores immigration after removing its obsolete control")
	for region in game.economy.snapshot().regions.values():
		for policy in region.policies.values():
			check(policy.mode == "off", "load disables every obsolete automatic trade policy")
	var scene_ids: Array = []
	var ledger_ids: Array = []
	for record in game.buildings:
		scene_ids.append(str(record.id))
	for record in after_load.buildings:
		ledger_ids.append(str(record.id))
	scene_ids.sort()
	ledger_ids.sort()
	check(scene_ids == ledger_ids, "scene and economic ledger restore exactly the same building IDs")
	if OS.get_cmdline_user_args().has("--capture"):
		game.economy.apply_resources({"wood": 1000, "coins": 1000})
		game.refresh_economy_snapshot()
		for type in ["workshop", "warehouse", "market", "weaver"]:
			var site := find_site(game, type)
			if site.x >= 0:
				game.add_building(type, site, true)
				connect_record(game, game.buildings[-1])
		for i in range(3):
			var site := find_site(game, "house")
			game.add_building("house", site, true)
			connect_record(game, game.buildings[-1])
		var hemp_site := find_site(game, "hemp_farm")
		game.add_building("hemp_farm", hemp_site, true)
		connect_record(game, game.buildings[-1])
		game.economy.reset({"wood": 150, "food": 100, "hemp": 10, "tools": 8, "cloth": 4, "coins": 120, "population": 16, "happiness": 60})
		game.sync_economy_buildings()
		game.economy.advance(60.0)
		game.refresh_economy_snapshot()
		var view_target := game.grid_to_world(Vector2i(10, 9))
		game.camera.position += view_target - game.camera_target
		game.camera_target = view_target
		game.camera.look_at(view_target)
		game.update_region_visuals()
		game.update_camera_projection()
		game.select_build_category("industry")
		game.update_ui()
		game.show_message("独立农田与麻田；农户提供普通劳力，匠户提供工匠。")
		await capture("settlement-overview")
		for record in game.buildings:
			if record.type == "house":
				game.show_inspector(int(record.id))
				await capture("house-farmer")
				game.promote_selected_house()
				check(record.node.get_node_or_null("HouseUpgradeScaffold") != null, "starting renovation immediately updates the real house model")
				await capture("house-construction")
				game.time_paused = false
				game.update_auto_time(60.0)
				game.time_paused = true
				check(record.node.get_meta("house_visual_tier", "") == "artisan", "automatic time updates finished artisan model")
				game.show_inspector(int(record.id))
				await capture("house-artisan")
				break
		for record in game.buildings:
			if record.type == "weaver":
				game.show_inspector(int(record.id))
				break
		await capture("weaver-inspector")
		for record in game.buildings:
			if record.type == "workshop":
				game.show_inspector(int(record.id))
				break
		await capture("workshop-inspector")
		for record in game.buildings:
			if record.type == "well":
				game.show_inspector(int(record.id))
				break
		await capture("well-inspector")
	game.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("NEEDS_INTEGRATION_OK: isolated new game, twenty-six fixed-function types, terrain layout, four-way footprints, occupancy, fixed goals, integer UI, simplified controls, real-map opening survival, no trade UI, automatic regional resupply, retired-order cleanup, 2x2 warehouse roundtrip")
		quit(0)
	else:
		quit(1)

func capture(label: String) -> void:
	var folder := "res://qa/needs-economy"
	DirAccess.make_dir_recursive_absolute(folder)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output := root.get_texture().get_image()
	check(output.save_png(folder.path_join(label + ".png")) == OK, "capture %s" % label)
