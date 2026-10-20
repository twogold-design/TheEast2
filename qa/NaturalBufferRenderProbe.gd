extends SceneTree

const VIEWPORT_SIZE := Vector2i(1366, 768)
const OUTPUT_DIR := "res://qa/natural-buffer"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		push_error("NATURAL_BUFFER_RENDER_FAILED: 主场景无法加载")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.time_paused = true
	game.map_region_level = 6
	game.update_region_visuals()
	game.update_ui()
	# Exercise the worst legal view: maximum zoom-out plus a pan request far past
	# each corner.  The production clamp resolves every request to a reachable
	# target whose ground footprint remains inside the natural apron.
	game.camera.size = float(game.CAMERA_MAX_SIZE)
	var camera_offset := Vector3(30.0, 34.0, 31.0)
	var views := {
		"north-west": Vector3(-200.0, 0.0, -200.0),
		"north-east": Vector3(200.0, 0.0, -200.0),
		"south-west": Vector3(-200.0, 0.0, 200.0),
		"south-east": Vector3(200.0, 0.0, 200.0),
	}
	for view_name in views:
		game.camera_target = views[view_name]
		game.camera.position = game.camera_target + camera_offset
		game.camera.look_at(game.camera_target)
		game.clamp_camera_target_to_bounds()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		if not save_viewport("%s/%s-1366x768.png" % [OUTPUT_DIR, view_name]):
			quit(1)
			return
	print("NATURAL_BUFFER_RENDER_OK: four corners at 1366x768")
	quit(0)

func save_viewport(path: String) -> bool:
	var image := get_root().get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("NATURAL_BUFFER_RENDER_FAILED: 空视口图像")
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var error := image.save_png(absolute)
	if error != OK:
		push_error("NATURAL_BUFFER_RENDER_FAILED: 无法写入 " + absolute)
		return false
	return true
