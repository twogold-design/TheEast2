extends SceneTree

const VIEWPORT_SIZE := Vector2i(1366, 768)
const OUTPUT_DIR := "res://qa/road-gameplay"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		push_error("ROAD_GAMEPLAY_RENDER_FAILED: 主场景无法加载")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.time_paused = true
	game.set_process(false)
	game.set_physics_process(false)
	prepare_network(game)

	game.select_road_tool()
	game.update_ui()
	game.camera_target = game.grid_to_world(Vector2i(10, 12))
	game.camera.position = game.camera_target + Vector3(30, 34, 31)
	game.camera.size = 28.0
	game.camera.look_at(game.camera_target)
	if not await save_frame("connected-network-1366x768.png"):
		quit(1)
		return

	game.cancel_building()
	game.show_road_inspector(Vector2i(12, 14))
	game.update_ui()
	if not await save_frame("road-details-1366x768.png"):
		quit(1)
		return

	print("ROAD_GAMEPLAY_RENDER_OK: connected road network, independent tool and road details at 1366x768")
	quit(0)


func prepare_network(game) -> void:
	for child in game.building_root.get_children():
		child.queue_free()
	for child in game.road_root.get_children():
		child.queue_free()
	game.buildings.clear()
	game.occupied.clear()
	game.roads.clear()
	game.next_id = 1
	game.map_region_level = 6
	game.day = 6
	game.wood = 82
	game.food = 76
	game.coins = 91
	game.population = 8
	game.happiness = 72
	game.ended = ""

	# Three readable branches radiate from the authored village street.  They
	# stop beside, rather than under, production buildings so the relationship
	# is visible from the normal planning camera.
	for cell in [
		Vector2i(11, 14), Vector2i(12, 14), Vector2i(13, 14),
		Vector2i(12, 13), Vector2i(12, 12),
		Vector2i(9, 10), Vector2i(8, 10), Vector2i(7, 10),
		Vector2i(6, 10), Vector2i(5, 10),
	]:
		game.add_road(cell, true)
	game.add_building("lumber", Vector2i(14, 14), true)
	game.add_building("workshop", Vector2i(13, 12), true)
	game.add_building("farm", Vector2i(4, 10), true)
	game.add_building("house", Vector2i(8, 8), true)
	game.add_building("house", Vector2i(7, 8), true)
	game.add_building("warehouse", Vector2i(11, 16), true)
	game.assign_workers()
	for record in game.buildings:
		if str(record.type) in game.ROAD_ELIGIBLE_BUILDING_TYPES:
			record.last_running = true
	game.update_citizens(false)


func save_frame(file_name: String) -> bool:
	for _frame in range(8):
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("ROAD_GAMEPLAY_RENDER_FAILED: 空视口图像")
		return false
	var output_path := OUTPUT_DIR.path_join(file_name)
	if image.save_png(ProjectSettings.globalize_path(output_path)) != OK:
		push_error("ROAD_GAMEPLAY_RENDER_FAILED: 无法保存 " + output_path)
		return false
	return true
