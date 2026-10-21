extends SceneTree

## All save callbacks are intercepted; only explicit fixture methods write to QA.
class IsolatedGame extends "res://godot/Main.gd":
	func save_path() -> String:
		return ProjectSettings.globalize_path("res://.godot-user/qa/failure-conditions-fixture.json")
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/failure-conditions-audio.cfg"
	func save_game(_show_feedback := true) -> void:
		pass
	func load_game(_show_feedback := true) -> void:
		pass
	func save_fixture() -> void:
		super.save_game(false)
	func load_fixture() -> void:
		super.load_game(false)

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAILURE_CONDITIONS: " + message)

func run() -> void:
	root.size = Vector2i(1366, 768)
	var game := IsolatedGame.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	expect(game.ended == "" and game.coins == 60 and game.population == 4, "Fresh start must remain playable")
	game.coins = int(game.BUILDINGS.workshop.coin_cost)
	game.add_building("workshop", Vector2i(8, 11))
	expect(game.coins == 0 and game.ended == "lose", "Spending the last coin must lose immediately after building")
	expect("铜钱" in game.failure_reason and game.time_paused, "Bankruptcy must explain the reason and stop time")
	var day_before := game.day
	var count_before := game.buildings.size()
	var id_to_demolish := int(game.buildings.back().id)
	game.next_day()
	game.add_building("farm", Vector2i(4, 11))
	game.remove_building_by_id(id_to_demolish)
	game.add_road(Vector2i(7, 11))
	game.unlock_next_region()
	game.set_building_enabled(id_to_demolish, false)
	expect(game.day == day_before and game.coins == 0 and game.buildings.size() == count_before and game.roads.is_empty(), "Defeat must freeze all economic operations")
	expect(game.buildings.back().enabled, "Defeat must block production toggles")
	var result_layer := game.end_layer
	game.check_failure_conditions()
	game.end_game("win")
	expect(game.end_layer == result_layer and game.ended == "lose", "Result must be idempotent and cannot change to victory")

	game.reset_game(false)
	expect(game.ended == "" and game.failure_reason == "" and game.coins == 60 and not game.time_paused, "Restart must clear defeat and restore resources")
	game.population = 1
	game.food = 0
	game.next_day()
	expect(game.population == 0 and game.ended == "lose" and "人口" in game.failure_reason, "Starvation must allow the last resident to leave")
	game.save_fixture()
	game.reset_game(false)
	game.load_fixture()
	expect(game.population == 0 and game.ended == "lose", "Population-zero loss must survive save/load")

	# Old saves may have zero money without an ended marker. Load must detect it.
	game.reset_game(false)
	game.coins = 0
	game.ended = "win"
	game.save_fixture()
	game.reset_game(false)
	game.load_fixture()
	expect(game.coins == 0 and game.ended == "lose" and "铜钱" in game.failure_reason, "Loaded exhausted treasury must override stale victory")
	game.coins = 60
	game.population = 4
	game.ended = ""
	game.save_fixture()
	game.load_fixture()
	expect(game.ended == "" and game.end_layer == null, "Loading valid active state must remove previous result overlay")

	# Every income channel settles before upkeep and the final loss check.
	game.reset_game(false)
	game.add_building("workshop", Vector2i(8, 11), true)
	game.coins = 1
	game.next_day()
	expect(game.coins > 1 and game.ended == "", "Daily production income must be included before defeat check")
	game.reset_game(false)
	game.population = 1
	game.add_building("warehouse", Vector2i(6, 12), true)
	game.add_building("warehouse", Vector2i(8, 12), true)
	game.coins = 1
	game.next_day()
	expect(game.coins == 0 and game.maintenance_debt == 0 and game.ended == "lose", "Exactly zero after fully paid maintenance is defeat")
	game.reset_game(false)
	game.population = 1
	for cell in [Vector2i(6, 12), Vector2i(8, 12), Vector2i(6, 15), Vector2i(8, 15)]:
		game.add_building("warehouse", cell, true)
	game.coins = 1
	game.next_day()
	expect(game.coins == 0 and game.maintenance_debt > 0 and game.ended == "lose", "Insufficient maintenance funds must also lose")

	# Expansion charge and its reward form one transaction.
	game.reset_game(false)
	game.add_building("house", Vector2i(8, 9), true)
	game.add_building("farm", Vector2i(0, 10), true)
	game.population = 8
	game.coins = int(game.REGION_UNLOCK_COSTS[1].coins)
	game.wood = 100
	game.food = 100
	expect(game.can_unlock_next_region() == "", "Expansion fixture must meet objectives")
	game.unlock_next_region()
	expect(game.map_region_level == 1 and game.coins == int(game.REGION_UNLOCK_REWARDS[1].coins) and game.ended == "", "Expansion must include reward before checking bankruptcy")

	# These values gain exactly 3 happiness with full food, testing the final
	# 39/40 and 19/20 thresholds rather than the pre-settlement value.
	for example in [[36, 39, 1], [37, 40, 0], [16, 19, 2], [17, 20, 1]]:
		game.reset_game(false)
		game.population = 4
		game.day = 2
		game.food = 100
		game.happiness = int(example[0])
		game.next_day()
		expect(game.happiness == int(example[1]), "Happiness boundary fixture must reach expected final value")
		expect(game.population == 4 - int(example[2]), "Departure threshold incorrect at happiness %d" % int(example[1]))
	for example in [[36, 1], [16, 2]]:
		game.reset_game(false)
		game.population = 4
		game.food = 0
		game.happiness = int(example[0])
		game.next_day()
		expect(game.population == 4 - int(example[1]), "Starvation and morale must take the larger loss without double counting")
	game.reset_game(false)
	game.population = 1
	game.food = 100
	game.happiness = 36
	game.next_day()
	expect(game.population == 0 and game.ended == "lose", "Low happiness can empty the settlement and trigger defeat")
	game.reset_game(false)
	game.population = 1
	game.food = 0
	game.happiness = 16
	game.next_day()
	expect(game.population == 0, "Combined departures must clamp to zero, never negative")

	game.reset_game(false)
	game.happiness = 1
	game.low_happiness_days = 2
	game.next_day()
	expect(game.ended == "lose" and "连续 3 日" in game.failure_reason, "Existing low-happiness failure must remain")
	game.reset_game(false)
	game.population = 0
	game.coins = 0
	game.next_day()
	expect(game.day == 1 and game.population == 0 and game.coins == 0 and game.ended == "lose", "Terminal input must not recover through migration or taxes")
	expect("人口" in game.failure_reason and "铜钱" in game.failure_reason, "Combined failure should explain both causes")

	# Optional visual capture uses the same isolated scene, never the live save.
	if "--capture" in OS.get_cmdline_user_args():
		game.reset_game(false)
		game.coins = int(game.BUILDINGS.workshop.coin_cost)
		game.add_building("workshop", Vector2i(8, 11))
		game.update_ui()
		DirAccess.make_dir_recursive_absolute("res://qa/failure-conditions")
		for frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		expect(root.get_texture().get_image().save_png("res://qa/failure-conditions/bankruptcy.png") == OK, "Screenshot must save")
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.4, true, false, true).timeout
	print("FAILURE_CONDITIONS_ACCEPTANCE_OK" if failures.is_empty() else "FAILURE_CONDITIONS_ACCEPTANCE_FAILED: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
