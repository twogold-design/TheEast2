extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	func save_path() -> String:
		return "res://.godot-user/qa/music-preview-never-written.json"
	func save_game(_show_feedback := true) -> void:
		pass
	func load_game(_show_feedback := true) -> void:
		pass
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/music-preview-settings.cfg"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366, 768)
	var game := IsolatedGame.new()
	root.add_child(game)
	game.time_paused = true
	game.set_process(false)
	game.set_physics_process(false)
	game.toggle_settings_menu()
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/audio"))
	var output := ProjectSettings.globalize_path("res://qa/audio/music-settings.png")
	root.get_texture().get_image().save_png(output)
	print("Music settings captured: ", output)
	game.queue_free()
	await process_frame
	await process_frame
	var until := Time.get_ticks_usec() + 180000
	while Time.get_ticks_usec() < until:
		await process_frame
	quit()
