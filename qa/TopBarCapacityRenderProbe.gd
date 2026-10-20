extends SceneTree

const OUTPUT_DIR := "res://qa/topbar-capacity"
const OUTPUT_PATH := OUTPUT_DIR + "/full-resource-labels-1366x768.png"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		push_error("TOP_BAR_CAPACITY_RENDER_FAILED: 主场景无法加载")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.reset_game(false)
	game.set_process(false)
	game.time_paused = true
	for cell in [Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9)]:
		game.add_building("house", cell, true)
	game.add_building("warehouse", Vector2i(13, 9), true)
	game.population = 8
	game.update_ui()
	await process_frame
	await process_frame
	var image := get_root().get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("TOP_BAR_CAPACITY_RENDER_FAILED: 空视口图像")
		quit(1)
		return
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("TOP_BAR_CAPACITY_RENDER_FAILED: 无法保存截图")
		quit(1)
		return
	print("TOP_BAR_CAPACITY_RENDER_OK: " + OUTPUT_PATH)
	quit(0)
