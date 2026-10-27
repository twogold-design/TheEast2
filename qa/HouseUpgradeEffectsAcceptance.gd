extends SceneTree

## Visual lifecycle fixture only. No player save, load, audio, or Main._ready.
const Effects = preload("res://godot/HouseUpgradeEffects.gd")
const Art = preload("res://godot/RealisticAssets.gd")
const Details = preload("res://godot/ExpandedBuildingAssets.gd")

class IsolatedGame extends "res://godot/Main.gd":
	func _ready() -> void:
		pass
	func save_game(_show_feedback := true) -> void:
		push_error("House upgrade visual fixture must never save")
	func load_game(_show_feedback := true) -> void:
		push_error("House upgrade visual fixture must never load")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error("HOUSE_UPGRADE_EFFECTS_FAILED: " + description)

func hammer_pose(effect: Node3D) -> Transform3D:
	return effect.hammer.transform

func mesh_count(node: Node) -> int:
	return node.find_children("*", "MeshInstance3D", true, false).size()

func run() -> void:
	var loaded_artisan := Effects.new()
	root.add_child(loaded_artisan)
	loaded_artisan.apply_state(true, false)
	check(loaded_artisan.completion_count == 0 and not is_instance_valid(loaded_artisan.dust), "loading completed artisan does not replay completion")
	check(loaded_artisan.hammer == null or not loaded_artisan.hammer.visible, "loaded artisan has no construction hammer")
	loaded_artisan.free()

	var effect := Effects.new()
	root.add_child(effect)
	effect.apply_state(false, true)
	check(effect.hammer.visible, "loading ongoing renovation immediately shows hammer")
	check(effect.completion_count == 0, "loading renovation does not emit completion dust")
	var before := hammer_pose(effect)
	effect.advance_visual(0.17, true)
	check(not before.is_equal_approx(hammer_pose(effect)), "construction hammer moves during active construction")
	before = hammer_pose(effect)
	effect.advance_visual(0.31, false)
	check(before.is_equal_approx(hammer_pose(effect)), "paused construction hammer holds its pose")
	effect.apply_state(false, false)
	check(not effect.hammer.visible and effect.completion_count == 0, "cancelled renovation hides hammer without completion dust")
	effect.apply_state(false, true)
	effect.apply_state(true, false)
	check(not effect.hammer.visible, "completion removes construction hammer")
	check(effect.completion_count == 1 and is_instance_valid(effect.dust), "real renovation completion creates one dust effect")
	var original_dust := effect.dust
	for repeat in range(20):
		effect.apply_state(true, false)
	check(effect.completion_count == 1 and effect.dust == original_dust, "repeated completed refresh does not restart dust")
	var dust_age_before: float = effect.dust_age
	effect.advance_visual(0.1, false)
	check(effect.dust_age > dust_age_before, "short completion puff settles even if construction is paused")
	effect.advance_visual(0.3, true)
	check(effect.dust_age > dust_age_before and is_instance_valid(effect.dust), "dust develops during completion")
	for frame in range(14):
		effect.advance_visual(0.1, true)
	await process_frame
	check(not is_instance_valid(effect.dust), "dust nodes are removed after their short lifetime")
	check(not is_instance_valid(original_dust), "completed dust owns no leaked node")
	effect.free()

	var home := Art.create_building("house", false, false)
	root.add_child(home)
	Details.apply_house_visual(home, "farmer", 0.25)
	var home_effect = home.get_node_or_null("HouseUpgradeEffects")
	check(home_effect != null, "real house visual refresh attaches the effects controller")
	if home_effect != null:
		var initial_meshes := mesh_count(home)
		for repeat in range(20):
			Details.apply_house_visual(home, "farmer", 0.25)
		check(mesh_count(home) == initial_meshes, "repeated construction refresh does not accumulate meshes")
		Details.apply_house_visual(home, "artisan")
		check(home_effect.completion_count == 1, "real house visual transition emits completion")
		check(home.get_meta("house_visual_tier", "") == "artisan", "completion also selects the artisan building")
		var live_dust: Node3D = home_effect.dust
		home.free()
		check(not is_instance_valid(home_effect) and not is_instance_valid(live_dust), "demolition frees controller and live dust with its house")
	else:
		home.free()
	var preview := Art.create_building("house", true, false)
	check(preview.get_node_or_null("HouseUpgradeEffects") == null, "placement preview has no construction or completion animation")
	preview.free()

	var game := IsolatedGame.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var construction_home := Art.create_building("house", false, false)
	game.add_child(construction_home)
	Details.apply_house_visual(construction_home, "farmer", 0.5)
	game.buildings.append({"id": 91, "type": "house", "node": construction_home, "enabled": true})
	game.economy.buildings = [{"id": 91, "type": "house", "connected": true, "enabled": true}]
	var controller = construction_home.get_node_or_null("HouseUpgradeEffects")
	if controller != null:
		before = hammer_pose(controller)
		game.update_house_upgrade_effects(0.17)
		check(not before.is_equal_approx(hammer_pose(controller)), "Main animation hook advances connected enabled renovation")
		for state in ["time_paused", "ended", "day_settling", "disconnected", "disabled"]:
			game.time_paused = state == "time_paused"
			game.ended = "failed" if state == "ended" else ""
			game.day_settling = state == "day_settling"
			game.economy.buildings[0].connected = state != "disconnected"
			game.economy.buildings[0].enabled = state != "disabled"
			before = hammer_pose(controller)
			game.update_house_upgrade_effects(0.17)
			check(before.is_equal_approx(hammer_pose(controller)), "Main holds construction animation while " + state)
		game.economy.buildings[0].enabled = true
		before = hammer_pose(controller)
		game.update_house_upgrade_effects(0.17)
		check(not before.is_equal_approx(hammer_pose(controller)), "Main resumes hammer when construction can progress again")
		game.economy_snapshot = {"households": {"91": {"tier": "farmer", "upgrade_remaining": 20}}}
		game.refresh_recipe_visuals()
		check(controller.completion_count == 0 and controller.hammer.visible, "Main snapshot retains unfinished renovation")
		game.economy_snapshot.households["91"] = {"tier": "artisan", "upgrade_remaining": 0}
		game.refresh_recipe_visuals()
		check(controller.completion_count == 1 and not controller.hammer.visible, "Main completion snapshot switches hammer to dust once")
		for repeat in range(20):
			game.refresh_recipe_visuals()
		check(controller.completion_count == 1, "Main repeated economy refresh never replays completion")
	game.free()
	await process_frame
	print("HOUSE_UPGRADE_EFFECTS_OK" if failures.is_empty() else "HOUSE_UPGRADE_EFFECTS_FAILED")
	quit(0 if failures.is_empty() else 1)
