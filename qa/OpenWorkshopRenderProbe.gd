extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	func save_path() -> String:
		return "res://.godot-user/qa/workshop-render-never-written.json"
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
	game.add_building("workshop", Vector2i(8, 11), true)
	game.add_building("warehouse", Vector2i(6, 13), true)
	game.update_ui()
	game.camera.size = 10
	game.camera_target = game.grid_to_world(Vector2i(8, 11)) + Vector3(0, 0.45, 0)
	game.camera.position = game.camera_target + Vector3(10, 12, 10)
	game.camera.look_at(game.camera_target)
	game.get_node("Interface").hide()
	var artisan := game.find_child("WorkshopArtisan", true, false)
	if artisan:
		var activity := artisan.get_node("WorkshopActivity")
		activity.set_process(false)
		activity.sample(1.7)
	DirAccess.make_dir_recursive_absolute("res://qa/workshop")
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://qa/workshop/open-workshop-in-game.png")
	game.camera.size = 5.4
	game.camera.position = game.camera_target + Vector3(6, 5.5, 9)
	game.camera.look_at(game.camera_target)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	error = maxi(error, root.get_texture().get_image().save_png("res://qa/workshop/open-workshop-detail.png"))
	game.queue_free()
	await process_frame
	await process_frame
	print("OPEN_WORKSHOP_RENDER_OK" if error == OK else "OPEN_WORKSHOP_RENDER_FAILED")
	quit(0 if error == OK else 1)
