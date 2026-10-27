extends SceneTree
## Isolated game: no startup, user settings, or player save reads/writes.
class Game extends "res://godot/Main.gd":
	func _ready() -> void: pass
	func save_game(_feedback := true) -> void: pass
	func load_game(_feedback := true) -> void: pass
	func create_background_music() -> void: pass
	func create_music_settings(_box: VBoxContainer) -> void: pass

const Economy = preload("res://godot/economy/SettlementEconomy.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func check_dependencies() -> void:
	# Require a repeatable source, not just a finite starting stock. Per-stage
	# closure catches both circular dependencies and materials unlocked later.
	for level in range(7):
		var available := {"wood":true, "coins":true}
		var reachable: Dictionary = {}
		for iteration in range(Economy.CATALOG.size()):
			var progress := false
			for type in Economy.CATALOG:
				var definition: Dictionary = Economy.CATALOG[type]
				if int(definition.unlock_level) > level or reachable.has(type): continue
				var ready := true
				for good in definition.get("resource_costs", {}):
					if not available.has(good): ready = false
				var spec: Dictionary = Economy.SPECS[type]
				for input in ["input", "fuel"]:
					if spec.has(input) and not available.has(spec[input]): ready = false
				if not ready: continue
				reachable[type] = true
				progress = true
				if spec.has("output"): available[spec.output] = true
			if not progress: break
		for type in Economy.CATALOG:
			if int(Economy.CATALOG[type].unlock_level) <= level:
				check(reachable.has(type), "stage %d can build and supply %s without a circular or future-material dependency" % [level,type])
	var diversified := 0
	for type in Economy.CATALOG:
		var extras: Dictionary = Economy.CATALOG[type].get("resource_costs", {})
		if not extras.is_empty(): diversified += 1
		check(not extras.has("tools"), "no building depends on wooden tools with no live production source")
		for good in extras:
			check(Economy.GOODS.has(good) and int(extras[good]) > 0, "%s has valid material %s" % [type,good])
	check(diversified == 20, "twenty buildings use functional materials beyond timber and coins")
	for type in ["house","well","farm","lumber","workshop","warehouse"]:
		check(Economy.CATALOG[type].get("resource_costs", {}).is_empty(), "%s remains available to bootstrap and recover the economy" % type)

func find_site(game: Node, type: String) -> Dictionary:
	for quarter in range(4):
		for z in range(game.GRID_SIZE):
			for x in range(game.GRID_SIZE):
				var cell := Vector2i(x,z)
				if game.can_place(type, cell, quarter) == "":
					return {"cell":cell, "quarter":quarter}
	return {}

func costs_for(type: String) -> Dictionary:
	var definition: Dictionary = Economy.CATALOG[type]
	var costs := {"wood":int(definition.cost), "coins":int(definition.coin_cost)}
	costs.merge(definition.get("resource_costs", {}))
	return costs

func amount(snapshot: Dictionary, good: String) -> float:
	return float(snapshot.coins) if good == "coins" else float(snapshot.goods[good])

func same_stock(a: Dictionary, b: Dictionary) -> bool:
	return a.goods == b.goods and is_equal_approx(float(a.coins),float(b.coins))

func run() -> void:
	check_dependencies()
	root.size = Vector2i(1366,768)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.create_world()
	game.create_ui()
	await process_frame
	await process_frame
	game.reset_game(false)
	game.map_region_level = 6
	var grant := {"coins":10000}
	for good in Economy.GOODS: grant[good] = 10000
	game.economy.apply_resources(grant)
	game.refresh_economy_snapshot()
	for type in Economy.CATALOG:
		var site := find_site(game, type)
		check(not site.is_empty(), "%s has a legal paid site" % type)
		if site.is_empty(): continue
		var count := game.buildings.size()
		var extras: Dictionary = Economy.CATALOG[type].get("resource_costs", {})
		for good in extras:
			# Every extra material is independently enforced, with other materials
			# plentiful. Failure must leave all stock and map occupancy unchanged.
			var full := amount(game.economy.snapshot(), good)
			game.economy.apply_resources({good:float(extras[good]) - 1 - full})
			game.refresh_economy_snapshot()
			var before: Dictionary = game.economy.snapshot()
			check(game.can_place(type,site.cell,site.quarter).contains(game.resource_label(good) + "不足"), "%s preview names missing %s" % [type,good])
			game.add_building(type,site.cell,false,-1,true,Vector2i.ZERO,site.quarter)
			check(game.buildings.size() == count and same_stock(before,game.economy.snapshot()), "%s cannot partially pay when %s is missing" % [type,good])
			game.economy.apply_resources({good:1})
			game.refresh_economy_snapshot()
			game.economy.apply_resources({good:-1})
			game.add_building(type,site.cell,false,-1,true,Vector2i.ZERO,site.quarter)
			check(game.buildings.size() == count and same_stock(before,game.economy.snapshot()), "%s authoritative payment rejects stale %s availability" % [type,good])
			game.economy.apply_resources({good:full - amount(game.economy.snapshot(),good)})
			game.refresh_economy_snapshot()
		var before: Dictionary = game.economy.snapshot()
		game.add_building(type,site.cell,false,-1,true,Vector2i.ZERO,site.quarter)
		check(game.buildings.size() == count + 1, "%s builds when all materials exist" % type)
		if game.buildings.size() != count + 1: continue
		var record: Dictionary = game.buildings[-1]
		var paid: Dictionary = game.economy.snapshot()
		var costs := costs_for(type)
		for good in costs:
			check(is_equal_approx(amount(before,good)-amount(paid,good),float(costs[good])), "%s deducts exactly %s %d" % [type,good,costs[good]])
		game.show_inspector(int(record.id))
		for good in extras:
			check(game.inspector_body.text.contains("%s %d" % [game.resource_label(good),extras[good]]), "%s details state construction %s" % [type,good])
			check(game.inspector_demolish_button.tooltip_text.contains("%s%d" % [game.resource_label(good),int(extras[good])/2]), "%s refund tooltip includes %s" % [type,good])
		game.remove_building_by_id(int(record.id))
		var returned: Dictionary = game.economy.snapshot()
		for good in costs:
			check(is_equal_approx(amount(returned,good)-amount(paid,good),float(int(costs[good])/2)), "%s returns half of %s" % [type,good])
		await process_frame
	game.inspector.hide()
	game.show_message("建造所需材料已显示在建筑卡牌上")
	var panel_y := 0.0
	for category in ["basic","industry","civic","logistics","landscape"]:
		game.select_build_category(category)
		for page in range(2):
			game.build_page = page
			game.update_build_menu()
			await process_frame
			await process_frame
			for type in game.build_buttons:
				var button: Button = game.build_buttons[type]
				if not button.visible: continue
				check(button.get_global_rect().end.x <= 1366 and button.get_global_rect().end.y <= 768, "%s card stays on screen" % type)
				var font := button.get_theme_font("font")
				for line in button.text.split("\n"):
					check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x <= button.size.x-16, "%s card cost line is not clipped" % type)
				for good in Economy.CATALOG[type].get("resource_costs", {}):
					check(button.text.contains(game.resource_label(good)), "%s card includes %s" % [type,good])
				if panel_y == 0: panel_y = button.global_position.y
				check(absf(button.global_position.y-panel_y) < 1, "category/page changes preserve card row position")
			if OS.get_cmdline_user_args().has("--capture") and category in ["industry","civic"] and page == 0:
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://qa/construction-materials")
				check(root.get_texture().get_image().save_png("res://qa/construction-materials/" + category + ".png") == OK, "save construction card capture")
	game.queue_free()
	await process_frame
	await process_frame
	print("CONSTRUCTION_MATERIALS_OK" if failures.is_empty() else "CONSTRUCTION_MATERIALS_FAILED")
	quit(0 if failures.is_empty() else 1)
