extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	func save_path() -> String:
		return "res://.godot-user/qa/farming-render-unused.json"
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/farming-render-audio.cfg"
	func save_game(_show_feedback := true) -> void:
		pass
	func load_game(_show_feedback := true) -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366, 768)
	var game := IsolatedGame.new()
	root.add_child(game)
	game.time_paused = true
	game.set_process(false)
	game.set_physics_process(false)
	game.map_region_level = 1
	game.wood = 500
	game.coins = 500
	game.population = 12
	game.add_building("farm", Vector2i(4, 11), true)
	game.add_building("farm", Vector2i(4, 13), true)
	game.add_building("fishpond", Vector2i(6, 12), true)
	game.update_ui()
	game.get_node("Interface").hide()
	game.camera.size = 14.0
	game.camera_target = game.grid_to_world(Vector2i(6, 12)) + Vector3(0, 0.30, 0)
	game.camera.position = game.camera_target + Vector3(10, 14, 13)
	game.camera.look_at(game.camera_target)
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://qa/farming")
	var error := root.get_texture().get_image().save_png("res://qa/farming/farm-and-fishpond-in-game.png")
	game.get_node("Interface").show()
	game.region_panel_collapsed = true
	game.select_build_category("industry")
	game.select_building("fishpond")
	game.update_ghost(Vector2i(12, 12))
	game.rotate_selected_building()
	game.camera.size = 22.0
	game.camera_target = game.grid_to_world(Vector2i(11, 12))
	game.camera.position = game.camera_target + Vector3(10, 14, 13)
	game.camera.look_at(game.camera_target)
	game.update_ui()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	error = maxi(error, root.get_texture().get_image().save_png("res://qa/farming/rotated-fishpond-ui.png"))
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.4, true, false, true).timeout
	print("FARMING_SCENE_OK" if error == OK else "FARMING_SCENE_FAILED")
	quit(0 if error == OK else 1)
