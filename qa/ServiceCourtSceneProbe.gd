extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	func save_path() -> String:
		return "res://.godot-user/qa/service-court-render-unused.json"
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/service-court-render-audio.cfg"
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
	game.map_region_level = 3
	game.wood = 80
	game.coins = 140
	game.population = 4
	game.add_building("workshop", Vector2i(5, 12), true)
	game.add_building("clinic", Vector2i(7, 12), true)
	game.get_node("Interface").hide()
	game.camera.size = 12.5
	game.camera_target = game.grid_to_world(Vector2i(7, 13)) + Vector3(0, 0.5, 0)
	game.camera.position = game.camera_target + Vector3(8, 14, 13)
	game.camera.look_at(game.camera_target)
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://qa/service-courts")
	var error := root.get_texture().get_image().save_png("res://qa/service-courts/service-courts-in-game.png")
	game.get_node("Interface").show()
	for record in game.buildings:
		if str(record.type) == "clinic":
			game.show_inspector(int(record.id))
			break
	game.update_ui()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var ui_error := root.get_texture().get_image().save_png("res://qa/service-courts/clinic-inspector-in-game.png")
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.4, true, false, true).timeout
	print("SERVICE_COURT_SCENE_OK" if error == OK and ui_error == OK else "SERVICE_COURT_SCENE_FAILED")
	quit(0 if error == OK and ui_error == OK else 1)
