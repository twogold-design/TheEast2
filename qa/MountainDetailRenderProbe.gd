extends SceneTree

class IsolatedGame:
	extends "res://godot/Main.gd"
	func _ready() -> void:
		pass
	func save_game(_feedback := true) -> void:
		push_error("MOUNTAIN_RENDER_MUST_NOT_SAVE")
	func load_game(_feedback := true) -> void:
		push_error("MOUNTAIN_RENDER_MUST_NOT_LOAD")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366, 768)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/mountains"))
	var game := IsolatedGame.new()
	root.add_child(game)
	game.create_world()
	game.set_process(false)
	game.set_physics_process(false)
	game.region_visual_root.visible = false
	for shot in [
		{"file": "grounded-mountains-close.png", "target": Vector3(-5.5, 1.0, -61.5), "size": 19.0, "pitch": 19.0, "yaw": 10.0},
		{"file": "grounded-mountains-context.png", "target": Vector3(-1.0, 0.0, -57.0), "size": 47.0, "pitch": 42.0, "yaw": 0.0},
		{"file": "outer-mountains-close.png", "target": Vector3(62.0, 0.8, -108.0), "size": 22.0, "pitch": 24.0, "yaw": -30.0}
	]:
		var pitch := deg_to_rad(float(shot.pitch))
		var yaw := deg_to_rad(float(shot.yaw))
		game.camera.size = shot.size
		game.camera.position = shot.target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 58.0
		game.camera.look_at(shot.target)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png("res://qa/mountains/" + shot.file) != OK:
			quit(1)
			return
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	print("MOUNTAIN_DETAIL_RENDER_OK: three actual GL views; no save access")
	quit(0)
