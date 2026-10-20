extends SceneTree

const OUTPUT_DIR := "res://qa/camera-edge"
const VIEWPORT_SIZE := Vector2i(1366, 768)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		push_error("CAMERA_EDGE_RENDER_FAILED: 主场景无法加载")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.reset_game(false)
	game.set_process(false)
	game.time_paused = true
	game.map_region_level = game.REGION_DEFINITIONS.size() - 1
	game.update_region_visuals()
	game.update_ui()
	game.camera.size = float(game.CAMERA_MAX_SIZE)
	move_camera_target(game, Vector3.ZERO)
	if not await settle_and_save(OUTPUT_DIR + "/max-zoom-1366x768.png"):
		quit(1)
		return

	game.camera.size = float(game.CAMERA_INITIAL_SIZE)
	var corners := {
		"north-west": Vector3(-47, 0, -47),
		"north-east": Vector3(47, 0, -47),
		"south-west": Vector3(-47, 0, 47),
		"south-east": Vector3(47, 0, 47),
	}
	for label in corners:
		move_camera_target(game, corners[label])
		if not await settle_and_save(OUTPUT_DIR + "/corner-%s-1366x768.png" % label):
			quit(1)
			return
	print("CAMERA_EDGE_RENDER_OK: max_zoom_and_four_corners_1366x768")
	quit(0)

func move_camera_target(game, target: Vector3) -> void:
	var offset: Vector3 = game.camera.position - game.camera_target
	game.camera_target = target
	game.camera.position = target + offset
	game.camera.look_at(target)
	game.clamp_camera_target_to_bounds()

func settle_and_save(path: String) -> bool:
	await process_frame
	await process_frame
	var image := get_root().get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("CAMERA_EDGE_RENDER_FAILED: 空视口图像")
		return false
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("CAMERA_EDGE_RENDER_FAILED: 无法保存 " + path)
		return false
	return true
