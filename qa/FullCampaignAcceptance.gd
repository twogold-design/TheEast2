extends SceneTree
## A paid playthrough on generated terrain. No grants, resource/population edits,
## free buildings or chapter skips are permitted in this fixture.
class IsolatedGame extends "res://godot/Main.gd":
	var fixture_io := false
	func _ready() -> void: pass
	func create_background_music() -> void: pass
	func create_music_settings(_box: VBoxContainer) -> void: pass
	func save_game(feedback := true) -> void:
		if fixture_io: super.save_game(feedback)
	func load_game(feedback := true) -> void:
		if fixture_io: super.load_game(feedback)
	func save_path() -> String:
		return "res://.godot-user/qa/full-campaign-victory-" + str(get_meta("qa_strategy", "default")) + ".json"
	func create_building_model(type: String, _preview := false) -> Node3D:
		var model := Node3D.new()
		model.name = "Campaign_" + type
		return model

var game: Node
var failures: Array[String] = []
var history: Array = []
var purchases: Array = []
var road_parents: Dictionary = {}
var road_distances: Dictionary = {}
var reserved_corridors: Dictionary = {}
var simulated_seconds := 0.0
var min_cash := 100000.0
var last_report := -1
var strategy := "self_sufficient"
var trade_history: Array = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--strategy="):
			strategy = argument.trim_prefix("--strategy=")
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FULL_CAMPAIGN_FAILED: " + message)

func rebuild_paths() -> void:
	road_parents.clear()
	road_distances.clear()
	var queue: Array[Vector2i] = []
	for z in range(game.GRID_SIZE):
		for x in range(game.GRID_SIZE):
			var cell := Vector2i(x, z)
			if game.is_village_main_road_cell(cell) and game.region_level_for_cell(cell) <= game.map_region_level:
				queue.append(cell)
				road_parents[cell] = cell
				road_distances[cell] = 0
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var neighbors: Array = game.cardinal_cells(cell)
		for bridge in game.NPC_BRIDGES:
			var left := Vector2i(int(bridge.water_min_x) - 1, int(bridge.row))
			var right := Vector2i(int(bridge.water_max_x) + 1, int(bridge.row))
			if cell == left: neighbors.append(right)
			if cell == right: neighbors.append(left)
		for next in neighbors:
			if road_parents.has(next): continue
			if next.x < 0 or next.y < 0 or next.x >= game.GRID_SIZE or next.y >= game.GRID_SIZE: continue
			if game.region_level_for_cell(next) > game.map_region_level: continue
			if game.is_village_main_road_cell(next) or game.roads.has(next) or game.can_place_road(next) == "":
				road_parents[next] = cell
				road_distances[next] = int(road_distances[cell]) + (0 if game.roads.has(next) else 1)
				queue.append(next)

func access_path(record: Dictionary) -> Array:
	var footprint: Array = game.building_footprint_cells(record.type, record.cell, game.record_footprint(record))
	var best: Array = []
	var best_cost := 999999
	for boundary in game.building_boundary_cells(record):
		if not road_parents.has(boundary): continue
		var path: Array = []
		var cursor: Vector2i = boundary
		var valid := true
		var cost := 0
		while true:
			if cursor in footprint:
				valid = false
				break
			path.append(cursor)
			if not game.roads.has(cursor) and not game.is_village_main_road_cell(cursor): cost += 1
			if road_parents[cursor] == cursor: break
			cursor = road_parents[cursor]
		if valid and cost < best_cost:
			best = path
			best_cost = cost
	return best

func build_paid(type: String, prefer_region := -1) -> bool:
	if not game.BUILDINGS.has(type) or not game.building_is_unlocked(type): return false
	game.refresh_economy_snapshot()
	var definition: Dictionary = game.BUILDINGS[type]
	if game.wood < int(definition.cost) + 4 or game.coins < int(definition.coin_cost) + 14: return false
	for good in definition.get("resource_costs", {}):
		if float(game.economy_snapshot.goods[good]) < float(definition.resource_costs[good]): return false
	rebuild_paths()
	var best: Dictionary = {}
	var best_path: Array = []
	var best_score := 999999.0
	for quarter in range(2):
		var size: Vector2i = game.rotated_footprint(game.BUILDING_FOOTPRINTS[type], quarter)
		for z in range(game.GRID_SIZE):
			for x in range(game.GRID_SIZE):
				var cell := Vector2i(x, z)
				if prefer_region >= 0 and game.region_level_for_cell(cell) != prefer_region: continue
				if game.can_place(type, cell, quarter) != "": continue
				var record := {"type": type, "cell": cell, "footprint": size, "rotation_quarters": quarter}
				var blocks_corridor := false
				for covered in game.building_footprint_cells(type,cell,size):
					if reserved_corridors.has(covered): blocks_corridor = true
				if blocks_corridor: continue
				var path := access_path(record)
				if path.is_empty(): continue
				var road_cost := 0
				for item in path:
					if not game.roads.has(item) and not game.is_village_main_road_cell(item): road_cost += game.ROAD_WOOD_COST
				if game.wood < int(definition.cost) + road_cost + 2: continue
				var region_penalty := 0 if prefer_region < 0 or game.region_level_for_cell(cell) == prefer_region else 100
				var score := float(road_cost * 20 + absi(x - 10) + absi(z - 10) + region_penalty)
				if score < best_score:
					best = record
					best_score = score
					best_path = path
	if best.is_empty():
		if not game.has_meta("failed_site_"+type):
			game.set_meta("failed_site_"+type,true)
			print("CAMPAIGN_NO_SITE ",type," level=",game.map_region_level," reachable_cells=",road_parents.size())
		return false
	var before: int = game.buildings.size()
	var before_cash: int = game.coins
	game.add_building(type, best.cell, false, -1, true, Vector2i.ZERO, int(best.rotation_quarters))
	if game.buildings.size() != before + 1: return false
	best_path.reverse()
	for cell in best_path:
		if not game.roads.has(cell) and not game.is_village_main_road_cell(cell): game.add_road(cell)
	var record: Dictionary = game.buildings[-1]
	check(game.building_has_connected_road(record), "paid %s has a legal road connection" % type)
	game.sync_economy_buildings()
	purchases.append({"time": simulated_seconds, "type": type, "id": record.id, "cell": [best.cell.x, best.cell.y], "region": game.region_level_for_cell(best.cell), "cash_before": before_cash, "cash_after": game.coins})
	print("CAMPAIGN_BUILD t=", simulated_seconds, " ", type, " ", best.cell, " cash=", game.coins)
	return true

func count_type(type: String) -> int:
	var result := 0
	for record in game.buildings:
		if record.type != type: continue
		result += 1
	return result

func ensure(type: String, desired: int, region := -1) -> bool:
	if count_type(type) >= desired: return false
	build_paid(type, region)
	return true

func choose_actions() -> void:
	var level: int = game.map_region_level
	var target_population: int = int(game.REGION_REQUIREMENTS[mini(level+1,6)].population)
	var artisan_houses := 0
	for h in game.economy_snapshot.households.values():
		if h.tier == "artisan" or float(h.get("upgrade_remaining",0))>0: artisan_houses += 1
	var desired_artisan_houses := 0 if level==0 else maxi(1,ceili(target_population/16.0))
	var desired_artisans := desired_artisan_houses*4
	var daily_basics := .5*(target_population-desired_artisans)+desired_artisans
	if ensure("farm",1): return
	if ensure("lumber",1): return
	if ensure("well",ceili(daily_basics/10.0)): return
	if ensure("house",ceili(target_population/4.0)): return
	if ensure("workshop",1): return
	if level==0: return
	if ensure("farm",2): return
	if ensure("hemp_farm",1): return
	if ensure("weaver",1): return
	if artisan_houses < desired_artisan_houses:
		for id in game.economy_snapshot.households:
			var h: Dictionary = game.economy_snapshot.households[id]
			if h.tier=="farmer" and int(h.people)==4 and float(h.upgrade_remaining)<=0:
				if game.economy.promote_house(str(id)).is_empty():
					print("CAMPAIGN_PROMOTE t=",simulated_seconds," id=",id)
					return
		return
	var clothes := .25*(target_population-desired_artisans)+.5*desired_artisans
	var looms := ceili(clothes/4.0)
	if ensure("hemp_farm",ceili(looms/2.0)): return
	if ensure("weaver",looms): return
	if ensure("warehouse",1): return
	if ensure("market",ceili(target_population/24.0)): return
	if level>=2:
		if ensure("lumber",2): return
		if ensure("well",ceili(daily_basics/10.0)+1): return
		if ensure("fishpond",maxi(1,ceili((daily_basics-16)/12.0))): return
		if ensure("bamboo",1): return
	if level>=3:
		if ensure("clinic",1): return
		if ensure("garden",1): return
	if level>=4:
		# Storage is regional: expand the timber-producing district itself.
		if ensure("warehouse",2,0): return
		if ensure("papermill",1): return
		if ensure("academy",1): return

func record_status() -> void:
	var snapshot: Dictionary = game.economy.snapshot()
	var entry := {"time": simulated_seconds, "level": game.map_region_level, "population": game.population, "happiness": game.happiness, "goods": snapshot.goods, "coins": snapshot.coins, "housing": snapshot.housing_capacity, "next": game.can_unlock_next_region(), "rates": snapshot.rates, "available_workers": snapshot.available_workers}
	history.append(entry)
	print("CAMPAIGN_STATUS ", JSON.stringify(entry))

func plan_corridors() -> void:
	# Read-only layout planning over visible terrain; no region payment, rewards,
	# buildings, roads or resources are changed. Preserve routes before infill.
	var original_level: int = game.map_region_level
	game.map_region_level = 6
	rebuild_paths()
	for cell in road_parents:
		if posmod(cell.x,6)!=3 or posmod(cell.y,6)!=3: continue
		var cursor: Vector2i = cell
		while not reserved_corridors.has(cursor):
			reserved_corridors[cursor] = true
			if road_parents[cursor]==cursor: break
			cursor = road_parents[cursor]
	game.map_region_level = original_level

func run() -> void:
	if strategy != "self_sufficient":
		push_error("Only the current self_sufficient no-trade route is supported; prior trade routes remain historical reports.")
		quit(1)
		return
	game = IsolatedGame.new()
	game.set_meta("qa_strategy", strategy)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.create_world()
	game.create_ui()
	game.reset_game(false)
	plan_corridors()
	game.time_paused = false
	check(game.map_region_level == 0 and game.population == 4, "starts at actual initial population and region")
	check(game.wood == game.economy.INITIAL_WOOD and game.coins <= 60 and game.food <= 40, "uses configured starting wood after placing the initial house, without extra resource grants")
	check(game.economy.snapshot().goods.cloth == 12, "actual new game includes twelve starter clothes")
	record_status()
	while simulated_seconds < 14400 and not game.economy.snapshot().failed:
		choose_actions()
		game.update_auto_time(15.0)
		simulated_seconds += 15
		game.refresh_economy_snapshot()
		check(game.economy_snapshot.trade_orders.is_empty() and game.economy_snapshot.routes.is_empty(), "self-sufficient campaign never creates trade orders or manual routes")
		min_cash = minf(min_cash, float(game.economy_snapshot.coins))
		if game.map_region_level < 6 and game.can_unlock_next_region() == "":
			var old_level: int = game.map_region_level
			game.unlock_next_region()
			check(game.map_region_level == old_level + 1, "chapter is opened through its real payment callback")
			print("CAMPAIGN_UNLOCK t=", simulated_seconds, " level=", game.map_region_level)
			record_status()
		if int(simulated_seconds / 120) != last_report:
			last_report = int(simulated_seconds / 120)
			record_status()
		game.update_ui()
		if game.ended == "win": break
		await process_frame
	check(not game.economy.snapshot().failed, "campaign never goes bankrupt or loses all residents")
	check(game.map_region_level == 6, "all seven regions opened with paid progression")
	check(game.ended == "win", "actual Main victory condition is reached")
	var reached_end: String = game.ended
	if game.ended == "win":
		game.continue_after_victory()
		check(game.ended == "" and game.victory_achieved and not game.time_paused, "continue after victory resumes time and retains completion")
		game.update_auto_time(1.0)
		check(game.ended == "", "victory dialog does not reopen on subsequent ticks")
		game.fixture_io = true
		game.save_game(false)
		game.load_game(false)
		game.fixture_io = false
		check(game.victory_achieved and game.ended == "", "isolated save roundtrip remembers continued victory")
		game.update_auto_time(1.0)
		check(game.ended == "", "restored victory remains playable without repeated dialogs")
	var result := {"strategy": strategy, "trade_mode": "disabled", "ok": failures.is_empty(), "simulated_seconds": simulated_seconds, "minimum_coins": min_cash, "level": game.map_region_level, "ended": reached_end, "continued_after_victory": game.victory_achieved and game.ended == "", "failures": failures, "purchases": purchases, "trade_orders": trade_history, "history": history, "final_snapshot": game.economy.snapshot()}
	DirAccess.make_dir_recursive_absolute("res://qa/economy-balance-v4")
	var output := FileAccess.open("res://qa/economy-balance-v4/paid-playthrough.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	game.queue_free()
	await process_frame
	print("FULL_CAMPAIGN_OK" if failures.is_empty() else "FULL_CAMPAIGN_FAILED")
	quit(0 if failures.is_empty() else 1)
