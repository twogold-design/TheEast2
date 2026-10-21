extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366, 768)
	var game = load("res://godot/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.time_paused = true
	game.map_region_level = 1
	game.update_region_visuals()
	game.add_building("market", Vector2i(6, 11), true)
	game.add_building("house", Vector2i(8, 14), true)
	game.add_building("workshop", Vector2i(9, 13), true)
	game.camera.size = 13.0
	game.camera_target = game.building_model_position("market", Vector2i(6, 11))
	game.camera.position = game.camera_target + Vector3(10, 12, 10)
	game.camera.look_at(game.camera_target)
	game.get_node("Interface").hide()
	for frame in range(10):
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/market"))
	var screenshot := root.get_texture().get_image()
	var result := screenshot.save_png(ProjectSettings.globalize_path("res://qa/market/open-market-in-game.png"))
	print("MARKET_RENDER_OK" if result == OK else "MARKET_RENDER_FAILED")
	quit(0 if result == OK else 1)
