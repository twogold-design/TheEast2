extends SceneTree

const OUTPUT_DIR := "res://qa/goal-clarity"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		push_error("GOAL_CLARITY_RENDER_FAILED: 主场景无法加载")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.reset_game(false)
	game.set_process(false)
	game.update_ui()
	await process_frame
	if not save_viewport(OUTPUT_DIR + "/chapter-one-1366x768.png"):
		quit(1)
		return
	game.show_inspector(int(game.occupied[Vector2i(9, 9)]))
	await process_frame
	await process_frame
	if not save_viewport(OUTPUT_DIR + "/building-selection-1366x768.png"):
		quit(1)
		return
	game.inspector.visible = false
	var camera_transform: Transform3D = game.camera.transform
	var camera_target: Vector3 = game.camera_target
	var camera_size: float = game.camera.size
	game.region_panel.visible = false
	game.camera_target = Vector3(0, 1.5, -44)
	game.camera.position = Vector3(0, 14, -18)
	game.camera.size = 34.0
	game.camera.look_at(game.camera_target)
	await process_frame
	await process_frame
	if not save_viewport(OUTPUT_DIR + "/boundary-hills-1366x768.png"):
		quit(1)
		return
	game.camera.transform = camera_transform
	game.camera_target = camera_target
	game.camera.size = camera_size
	game.region_panel.visible = true
	game.toggle_region_panel()
	await process_frame
	await process_frame
	if not save_viewport(OUTPUT_DIR + "/chapter-one-collapsed-1366x768.png"):
		quit(1)
		return
	game.toggle_settings_menu()
	await process_frame
	await process_frame
	if not save_viewport(OUTPUT_DIR + "/settings-menu-1366x768.png"):
		quit(1)
		return
	game.close_settings_menu()

	game.reset_game(false)
	game.region_panel_collapsed = false
	game.map_region_level = 3
	game.day = 22
	game.population = 24
	game.wood = 132
	game.food = 74
	game.add_building("farm", Vector2i(1, 10), true)
	game.add_building("farm", Vector2i(1, 11), true)
	game.add_building("farm", Vector2i(1, 12), true)
	game.add_building("warehouse", Vector2i(10, 10), true)
	game.update_region_visuals()
	game.update_ui()
	await process_frame
	await process_frame
	if not save_viewport(OUTPUT_DIR + "/chapter-four-1366x768.png"):
		quit(1)
		return
	print("GOAL_CLARITY_RENDER_OK: chapter_one, building_selection, boundary_hills, collapsed, settings_menu, chapter_four_1366x768")
	quit(0)

func save_viewport(path: String) -> bool:
	var image := get_root().get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("GOAL_CLARITY_RENDER_FAILED: 空视口图像")
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var error := image.save_png(absolute)
	if error != OK:
		push_error("GOAL_CLARITY_RENDER_FAILED: 无法写入 " + absolute)
		return false
	return true
