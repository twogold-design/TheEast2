extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	func save_path() -> String:
		return "res://.godot-user/qa/clinic-warehouse-scene-never-written.json"
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/clinic-warehouse-scene-audio.cfg"
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
	game.population = 20
	game.add_building("warehouse", Vector2i(6, 13), true)
	game.add_building("clinic", Vector2i(8, 11), true)
	game.update_ui()
	game.get_node("Interface").hide()
	game.camera.size = 8.5
	game.camera_target = (game.grid_to_world(Vector2i(7, 14)) + game.grid_to_world(Vector2i(8, 11))) * 0.5 + Vector3(0, 0.60, 0)
	game.camera.position = game.camera_target + Vector3(5, 9, 14)
	game.camera.look_at(game.camera_target)
	DirAccess.make_dir_recursive_absolute("res://qa/clinic-warehouse")
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://qa/clinic-warehouse/clinic-warehouse-in-game.png")
	game.queue_free()
	await create_timer(0.4).timeout
	await process_frame
	print("CLINIC_WAREHOUSE_SCENE_OK: real Main scene, isolated saves/audio settings" if error == OK else "CLINIC_WAREHOUSE_SCENE_FAILED")
	quit(0 if error == OK else 1)
