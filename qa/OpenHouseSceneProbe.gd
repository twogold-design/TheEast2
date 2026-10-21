extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	func save_path() -> String:
		return "res://.godot-user/qa/open-house-render-unused.json"
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/open-house-render-audio.cfg"
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
	game.wood = 500
	game.coins = 500
	game.add_building("house", Vector2i(11, 11), true)
	game.add_building("house", Vector2i(12, 11), true)
	game.add_building("house", Vector2i(11, 12), true)
	game.get_node("Interface").hide()
	game.camera.size = 8.0
	game.camera_target = game.grid_to_world(Vector2i(11, 11)) + Vector3(0.6, 0.5, 0.4)
	game.camera.position = game.camera_target + Vector3(10, 14, 13)
	game.camera.look_at(game.camera_target)
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://qa/open-house")
	var error := root.get_texture().get_image().save_png("res://qa/open-house/residence-in-game.png")
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.4, true, false, true).timeout
	print("OPEN_HOUSE_SCENE_OK" if error == OK else "OPEN_HOUSE_SCENE_FAILED")
	quit(0 if error == OK else 1)
