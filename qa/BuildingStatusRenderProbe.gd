extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	func save_path() -> String:
		return "res://.godot-user/qa/status-render-never-written.json"
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
	game.population = 8
	game.add_building("farm", Vector2i(4, 10), true)
	game.set_building_enabled(int(game.buildings.back().id), false)
	game.add_building("lumber", Vector2i(15, 7), true)
	game.add_building("workshop", Vector2i(11, 10), true)
	game.add_building("workshop", Vector2i(11, 13), true)
	game.food = 100
	game.wood = 0
	game.update_ui()
	game.camera.size = 24.0
	game.camera_target = game.grid_to_world(Vector2i(9, 10))
	game.camera.position = game.camera_target + Vector3(30, 34, 31)
	game.camera.look_at(game.camera_target)
	game.get_node("Interface").hide()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://qa/building-status")
	var error := root.get_texture().get_image().save_png("res://qa/building-status/operation-markers.png")
	game.get_node("Interface").show()
	var workshop_id := int(game.buildings.back().id)
	game.show_inspector(workshop_id)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	error = maxi(error, root.get_texture().get_image().save_png("res://qa/building-status/inspector-abnormal.png"))
	game.population = 20
	game.wood = 50
	game.update_ui()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	error = maxi(error, root.get_texture().get_image().save_png("res://qa/building-status/inspector-normal.png"))
	game.queue_free()
	await process_frame
	await process_frame
	print("BUILDING_STATUS_RENDER_OK" if error == OK else "BUILDING_STATUS_RENDER_FAILED")
	quit(0 if error == OK else 1)
