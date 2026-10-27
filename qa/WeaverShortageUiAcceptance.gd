extends SceneTree
## Isolated real Main fixture. Never runs startup, audio, or player save I/O.
class Game extends "res://godot/Main.gd":
	func _ready() -> void: pass
	func save_game(_feedback := true) -> void: pass
	func load_game(_feedback := true) -> void: pass
	func create_background_music() -> void: pass
	func create_music_settings(_box: VBoxContainer) -> void: pass

var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

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

func run() -> void:
	root.size = Vector2i(1366, 768)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.create_world()
	game.create_ui()
	# Let the actual UI settle before measuring or capturing its containers.
	await process_frame
	await process_frame
	game.reset_game(false)
	game.map_region_level = 1
	game.economy.reset({"population":8,"wood":100,"hemp":8,"cloth":12,"food":100,"water":50,"coins":200})
	game.sync_economy_buildings()
	game.refresh_economy_snapshot()
	var second_home := find_site(game, "house")
	game.add_building("house", second_home, true)
	check(connect_record(game, game.buildings[-1]), "second household connects")
	game.economy.households[str(game.buildings[0].id)].tier = "artisan"
	game.sync_economy_buildings()
	game.economy.immigration_enabled = false
	var site := find_site(game, "weaver")
	check(site.x >= 0, "weaver has a legal actual-map site")
	if site.x < 0:
		game.free()
		quit(1)
		return
	game.economy.apply_resources({"hemp":-1})
	game.refresh_economy_snapshot()
	var before: Dictionary = game.economy.snapshot()
	var count := game.buildings.size()
	check(game.can_place("weaver", site).contains("麻料不足"), "preview names hemp shortage")
	game.add_building("weaver", site)
	check(game.buildings.size() == count and game.economy.snapshot().goods == before.goods and game.economy.snapshot().coins == before.coins, "failed actual placement changes no occupancy or resources")
	game.economy.apply_resources({"hemp":1})
	game.refresh_economy_snapshot()
	# Even when the preview is old, authoritative payment is all-or-nothing.
	game.economy.apply_resources({"hemp":-1})
	game.add_building("weaver", site)
	check(game.buildings.size() == count and game.economy.snapshot().goods.wood == before.goods.wood, "stale valid preview cannot bypass required hemp")
	game.economy.apply_resources({"hemp":1})
	game.refresh_economy_snapshot()
	before = game.economy.snapshot()
	game.add_building("weaver", site)
	check(game.buildings.size() == count + 1, "paid weaver placed")
	check(game.economy.snapshot().goods.hemp == 0 and game.economy.snapshot().goods.wood == float(before.goods.wood) - int(game.BUILDINGS.weaver.cost) and game.economy.snapshot().coins == float(before.coins) - int(game.BUILDINGS.weaver.coin_cost), "real construction deducts hemp8 and current generated wood/coin costs once")
	var weaver: Dictionary = game.buildings[-1]
	check(connect_record(game, weaver), "weaver connects to residential craftsmen")
	game.sync_economy_buildings()
	game.update_ui()
	game.show_inspector(int(weaver.id))
	check(game.inspector_status.text.contains("停产") and game.inspector_status.text.contains("缺少麻料"), "zero input immediately shows stopped cause even before advancing time")
	check(game.inspector_status.get_theme_color("font_color") == Color("a63d32"), "shortage reason is red")
	check(game.get_building_status_marker(int(weaver.id)).visible, "empty-input weaver shows overhead warning")
	check(game.inspector_body.text.contains("衣物0/日（停产）"), "details no longer imply nominal output while halted")
	check(game.inspector_body.text.contains("维护：铜钱2/日") and not game.inspector_body.text.contains("麻料4/日"), "stopped details show only ongoing maintenance, not imaginary raw-material consumption")
	check(game.build_buttons.weaver.text.contains("麻料 8"), "build card displays material cost")
	if OS.get_cmdline_user_args().has("--capture"):
		await capture(game, weaver, "weaver-starved")
	var hemp_site := find_site(game, "hemp_farm")
	check(hemp_site.x >= 0, "hemp field has a legal site")
	game.add_building("hemp_farm", hemp_site, true)
	var field: Dictionary = game.buildings[-1]
	check(connect_record(game, field), "hemp farm connects")
	game.economy.advance(60.0)
	game.refresh_economy_snapshot()
	var hemp_after_farm: float = game.economy_snapshot.goods.hemp
	check(hemp_after_farm > 0 and game.economy_snapshot.building_status[str(weaver.id)].ok, "working farm supplies the weaver")
	game.remove_building_by_id(int(field.id), false)
	game.economy.advance(1.0)
	game.refresh_economy_snapshot()
	check(float(game.economy_snapshot.goods.hemp) < hemp_after_farm and bool(game.economy_snapshot.building_status[str(weaver.id)].producing), "after demolition weaver consumes remaining stored hemp")
	game.economy.advance(90.0)
	game.refresh_economy_snapshot()
	game.update_ui()
	game.show_inspector(int(weaver.id))
	check(float(game.economy_snapshot.goods.hemp) == 0 and not bool(game.economy_snapshot.building_status[str(weaver.id)].producing), "stored hemp exhaustion stops production")
	var cloth_before: float = game.economy_snapshot.goods.cloth
	game.economy.advance(20.0)
	game.refresh_economy_snapshot()
	check(float(game.economy_snapshot.goods.cloth) <= cloth_before, "no cloth is created without hemp")
	game.sync_economy_buildings()
	game.update_ui()
	game.show_inspector(int(weaver.id))
	check(game.get_building_status_marker(int(weaver.id)).visible and game.inspector_status.text.contains("缺少麻料"), "structural refresh cannot erase material warning")
	var saved: Dictionary = game.economy.serialize()
	check(game.economy.restore(saved), "isolated saved economy restores")
	game.sync_economy_buildings()
	game.update_ui()
	check(game.get_building_status_marker(int(weaver.id)).visible, "paused restored weaver remains visibly starved")
	game.economy.apply_resources({"hemp":4})
	game.economy.advance(1.0)
	game.refresh_economy_snapshot()
	game.update_ui()
	game.show_inspector(int(weaver.id))
	check(not game.get_building_status_marker(int(weaver.id)).visible and game.inspector_status.get_theme_color("font_color") == Color("39764b"), "new input automatically resumes production and clears warning")
	if OS.get_cmdline_user_args().has("--capture"):
		await capture(game, weaver, "weaver-running")
	var hemp_before_refund: float = game.economy_snapshot.goods.hemp
	game.remove_building_by_id(int(weaver.id))
	check(is_equal_approx(float(game.economy.snapshot().goods.hemp), hemp_before_refund + 4), "demolition returns half of construction hemp")
	# UI departure events remain deliverable even if another refresh changed the
	# mirrored population field first (selection, simulation speed, or new roads).
	game.reset_game(false)
	game.economy.reset({"population":4,"food":100,"water":0,"cloth":12,"coins":100,"happiness":60})
	game.sync_economy_buildings()
	game.economy.immigration_enabled = false
	game.economy.advance(60)
	game.refresh_economy_snapshot()
	game.update_population_feedback()
	game.update_ui()
	check(game.message_label.text.contains("人口 -1") and game.message_label.text.contains("饮水不足"), "actual water departure is surfaced with a count and cause")
	check(game.status_label.text.contains("缺水"), "persistent top-line shortage warning is visible")
	check(game.get_building_status_marker(int(game.buildings[0].id)).visible, "undersupplied residence also has an overhead warning")
	if OS.get_cmdline_user_args().has("--capture"):
		await capture(game, game.buildings[0], "population-shortage")
	var prior_message := game.message_label.text
	game.update_population_feedback()
	check(game.message_label.text == prior_message and game.economy.take_population_events().is_empty(), "events are delivered exactly once")
	game.economy.apply_resources({"water":20})
	game.economy.advance(0.25)
	game.refresh_economy_snapshot()
	game.update_population_feedback()
	game.update_ui()
	check(not game.status_label.text.contains("缺水") and game.message_label.text.contains("风险解除"), "resupply clears warning and acknowledges recovery")
	game.queue_free()
	await process_frame
	await process_frame
	print("WEAVER_SHORTAGE_UI_OK" if failures.is_empty() else "WEAVER_SHORTAGE_UI_FAILED")
	quit(0 if failures.is_empty() else 1)

func capture(game: Node, record: Dictionary, label: String) -> void:
	var target: Vector3 = record.node.position + Vector3(2.5, 0, -2.0)
	game.camera.position = target + Vector3(16, 18, 20)
	game.camera.look_at(target)
	game.camera.size = 18
	game.select_build_category("industry")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://qa/shortage-feedback")
	check(root.get_texture().get_image().save_png("res://qa/shortage-feedback/" + label + ".png") == OK, "capture " + label)
