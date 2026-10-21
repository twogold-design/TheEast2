extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	func save_path() -> String:
		return "res://.godot-user/qa/goal-segments-never-written.json"
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/goal-segments-audio.cfg"
	func save_game(_show_feedback := true) -> void:
		pass
	func load_game(_show_feedback := true) -> void:
		pass

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("GOAL_SEGMENTS_FAILED: " + message)

func row(game, prefix: String) -> RichTextLabel:
	for child in game.region_body.get_children():
		if child is RichTextLabel and str(child.get_meta("goal_prefix", "")) == prefix:
			return child
	check(false, "missing goal row " + prefix)
	return null

func check_term(line: RichTextLabel, term: String, completed: bool) -> void:
	if line == null:
		return
	var green := "[color=#2f8f5b]✓ " + term + "[/color]"
	check((green in line.text) == completed, "independent rendered color for " + term)
	check(term in line.get_parsed_text(), "term still visible " + term)

func run() -> void:
	root.size = Vector2i(1366, 768)
	var game := IsolatedGame.new()
	root.add_child(game)
	game.background_music.player.stop()
	game.background_music.player.stream = null
	game.set_process(false)
	game.set_physics_process(false)
	game.time_paused = true
	check(game.can_unlock_next_region() != "", "initial stock cannot unlock first region")
	# No construction, housing count or local development may gate these tests.
	# Numeric fixtures isolate unlock logic from the production simulation.
	for building in game.buildings.duplicate():
		game.remove_building_by_id(int(building.id), false)
	check(game.buildings.is_empty(), "fixture has no buildings")
	var prior: Dictionary = {}
	for level in range(1, 7):
		game.map_region_level = level - 1
		game.day = 1
		game.stable_days = 0
		var requirement: Dictionary = game.REGION_REQUIREMENTS[level]
		check(requirement.size() == 5, "exactly five numeric requirements")
		for key in requirement:
			check(key in ["wood", "food", "coins", "population", "happiness"], "no hidden building/housing/date requirements")
			game.set(key, requirement[key])
			if prior.has(key):
				check(int(requirement[key]) > int(prior[key]), "rising threshold: " + key)
		for key in ["wood", "food", "coins"]:
			check(int(requirement[key]) > int(game.REGION_UNLOCK_COSTS[level][key]), "expansion preserves stock: " + key)
		var warehouses := ceili((int(requirement.wood) - 100) / 75.0)
		var capacity := 100 + maxi(0, warehouses) * 75
		var food_use := ceili(int(requirement.population) / 4.0) + ceili(int(requirement.population) / 2.0)
		check(int(requirement.food) + food_use < capacity, "food target allows daily consumption below reachable capacity")
		check(int(requirement.population) <= 50, "population cap allows target")
		game.update_ui()
		var fixed_copy: String = game.region_body.text
		var fixed_task: String = game.goal_label.text
		check(game.can_unlock_next_region() == "", "all five values permit unlock without any buildings")
		check(not game.region_unlock_button.disabled, "complete goal UI enables unlock")
		for forbidden in ["费用", "奖励", "住房", "稳定", "农田 1", "集市 1", "进度", "固定"]:
			check(forbidden not in fixed_copy, "goal panel omits " + forbidden)
		for item in game.chapter_numeric_goals(level):
			var key := str(item.key)
			game.set(key, int(item.target) - 1)
			game.update_ui()
			check(game.can_unlock_next_region() != "", "below-threshold blocks " + key)
			check(str(item.name) in game.can_unlock_next_region(), "failure identifies actual missing metric " + key)
			check(game.region_unlock_button.disabled, "UI blocks missing " + key)
			for displayed in game.chapter_numeric_goals(level):
				var prefix := "聚落：" if str(displayed.key) in ["population", "happiness"] else "储备："
				check_term(row(game, prefix), str(displayed.text), str(displayed.key) != key)
			check(game.region_body.text == fixed_copy and game.goal_label.text == fixed_task, "goal wording fixed when values fall")
			game.set(key, int(item.target))
		game.update_ui()
		if level == 2 and "--render" in OS.get_cmdline_user_args():
			game.food -= 1
			game.update_ui()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://qa/goal-clarity")
			root.get_texture().get_image().save_png("res://qa/goal-clarity/numeric-goals.png")
			game.food += 1
		var cost: Dictionary = game.REGION_UNLOCK_COSTS[level]
		game.unlock_next_region()
		check(game.map_region_level == level, "actual unlock works with zero buildings")
		check(game.ended == "", "unlock does not trigger failure")
		check(game.coins == int(requirement.coins) - int(cost.coins) + int(game.REGION_UNLOCK_REWARDS[level].coins), "one unlock cost/reward transaction")
		if level < 6:
			var after_coins: int = game.coins
			game.unlock_next_region()
			check(game.map_region_level == level and game.coins == after_coins, "repeat click cannot skip next goal or repeat reward")
		prior = requirement
	game.map_region_level = 6
	game.wood = 200
	game.food = 0
	game.coins = 150
	game.update_ui()
	check_term(row(game, "储备："), "木材 200", true)
	check_term(row(game, "储备："), "粮食 200", false)
	check_term(row(game, "储备："), "铜钱 150", true)
	await process_frame
	await process_frame
	for child in game.region_body.get_children():
		if child is RichTextLabel:
			check(child.size.x <= game.region_body.size.x + 1.0, "goal row does not overflow panel")
			check(child.size.y + 1.0 >= child.get_content_height(), "wrapped goal text is not clipped")
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	if failures.is_empty():
		print("GOAL_SEGMENTS_ACCEPTANCE_OK: 30 threshold boundaries, independent colors, fixed text, six numeric-only unlocks without buildings, no date gates, reserves and capacity")
	quit(0 if failures.is_empty() else 1)
