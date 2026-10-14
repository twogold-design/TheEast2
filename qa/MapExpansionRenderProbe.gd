extends SceneTree

const START_PATH := "res://qa/map-expansion-start.png"
const OPEN_PATH := "res://qa/map-expansion-open.png"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		push_error("MAP_EXPANSION_RENDER_FAILED: 主场景无法加载")
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
	if not save_viewport(START_PATH):
		quit(1)
		return
	game.map_region_level = 6
	game.update_region_visuals()
	game.update_ui()
	await process_frame
	await process_frame
	if not save_viewport(OPEN_PATH):
		quit(1)
		return
	print("MAP_EXPANSION_RENDER_OK: locked_and_opened")
	quit(0)

func save_viewport(path: String) -> bool:
	var image := get_root().get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("MAP_EXPANSION_RENDER_FAILED: 空视口图像")
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var error := image.save_png(absolute)
	if error != OK:
		push_error("MAP_EXPANSION_RENDER_FAILED: 无法写入 " + absolute)
		return false
	return true
