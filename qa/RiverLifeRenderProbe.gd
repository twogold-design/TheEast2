extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	func save_path() -> String:
		return "res://.godot-user/qa/river-render-never-written.json"
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
	game.get_node("Interface").hide()
	DirAccess.make_dir_recursive_absolute("res://qa/river-life")
	var result := OK
	for view in [
		{"name": "river-and-bridge", "cell": Vector2i(3, 10), "size": 23.0},
		{"name": "boat-detail", "cell": Vector2i(3, 17), "size": 7.0},
		{"name": "east-river", "cell": Vector2i(33, 17), "size": 20.0},
	]:
		game.camera_target = game.grid_to_world(view.cell)
		game.camera.size = view.size
		game.camera.position = game.camera_target + Vector3(10, 13, 14)
		game.camera.look_at(game.camera_target)
		for frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		result = maxi(result, root.get_texture().get_image().save_png("res://qa/river-life/%s.png" % view.name))
	game.queue_free()
	await process_frame
	await process_frame
	print("RIVER_LIFE_RENDER_OK" if result == OK else "RIVER_LIFE_RENDER_FAILED")
	quit(0 if result == OK else 1)
