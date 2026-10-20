extends SceneTree

const VIEWPORT_SIZE := Vector2i(1366, 768)
const OUTPUT_DIR := "res://qa/building-copy"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		push_error("BUILDING_COPY_RENDER_FAILED: 主场景无法加载")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.time_paused = true
	game.map_region_level = game.REGION_DEFINITIONS.size() - 1

	prepare_single_building(game, "farm", 1)
	game.select_build_category("basic")
	game.show_inspector(int(game.buildings[0].id))
	game.update_ui()
	if not await save_frame("opening-farm-details-1366x768.png"):
		quit(1)
		return

	prepare_single_building(game, "academy", 20)
	game.select_build_category("civic")
	game.show_inspector(int(game.buildings[0].id))
	game.update_ui()
	if not await save_frame("academy-details-1366x768.png"):
		quit(1)
		return

	print("BUILDING_COPY_RENDER_OK: opening and regional details at 1366x768")
	quit(0)


func prepare_single_building(game, type: String, residents: int) -> void:
	for child in game.building_root.get_children():
		child.free()
	game.buildings.clear()
	game.occupied.clear()
	game.next_id = 1
	game.wood = 80
	game.food = 80
	game.coins = 120
	game.population = residents
	game.happiness = 70
	game.ended = ""
	game.add_building(type, Vector2i(8, 8), true)
	game.assign_workers()


func save_frame(file_name: String) -> bool:
	for _frame in range(4):
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("BUILDING_COPY_RENDER_FAILED: 空视口图像")
		return false
	var output_path := OUTPUT_DIR.path_join(file_name)
	if image.save_png(ProjectSettings.globalize_path(output_path)) != OK:
		push_error("BUILDING_COPY_RENDER_FAILED: 无法保存 " + output_path)
		return false
	return true
