extends SceneTree

const OUTPUT_DIR := "res://qa/map-edge"

class IsolatedGame:
	extends "res://godot/Main.gd"
	func _ready() -> void:
		pass
	func save_game(_show_feedback := true) -> void:
		push_error("BUFFER_RENDER_MUST_NOT_SAVE")
	func load_game(_show_feedback := true) -> void:
		push_error("BUFFER_RENDER_MUST_NOT_LOAD")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366, 768)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game := IsolatedGame.new()
	game.time_paused = true
	root.add_child(game)
	game.create_world()
	game.set_process(false)
	game.set_physics_process(false)
	game.region_visual_root.visible = false
	await process_frame
	await process_frame
	for shot in [
		{"file": "expanded-buffer-corner-1366x768.png", "target": Vector3(61.6, 0, 61.6), "size": 48.0, "pitch": 30.0, "yaw": 45.0},
		{"file": "expanded-buffer-river-1366x768.png", "target": Vector3(-35.0, 0, -61.6), "size": 48.0, "pitch": 30.0, "yaw": 0.0},
		{"file": "expanded-buffer-side-1366x768.png", "target": Vector3(56.0, 0, 8.0), "size": 36.0, "pitch": 48.0, "yaw": 60.0}
	]:
		var pitch := deg_to_rad(float(shot.pitch))
		var yaw := deg_to_rad(float(shot.yaw))
		var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 58.0
		game.camera_target = shot.target
		game.camera.size = shot.size
		game.camera.position = game.camera_target + offset
		game.camera.look_at(game.camera_target)
		game.clamp_camera_target_to_bounds()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(OUTPUT_DIR + "/" + shot.file)
		if error != OK:
			push_error("NATURAL_BUFFER_RENDER_FAILED: " + shot.file)
			quit(1)
			return
	game.queue_free()
	await process_frame
	await process_frame
	print("NATURAL_BUFFER_RENDER_OK: three isolated edge views; no save access")
	quit(0)
