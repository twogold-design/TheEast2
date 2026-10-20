extends SceneTree

const OUTPUT_DIR := "res://qa/npc-schedule"
const VIEWPORT_SIZE := Vector2i(1366, 768)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		push_error("NPC_SCHEDULE_RENDER_FAILED: 主场景无法加载")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.reset_game(false)
	game.set_process(false)
	game.time_paused = true
	game.add_building("house", Vector2i(8, 9), true)
	game.add_building("farm", Vector2i(2, 10), true)
	game.add_building("lumber", Vector2i(14, 10), true)
	game.add_building("workshop", Vector2i(13, 13), true)
	game.add_building("warehouse", Vector2i(10, 11), true)
	game.population = 12
	game.update_citizens()
	game.region_panel_collapsed = true
	game.update_ui()
	await process_frame

	var phases := [
		{"time": 0.40, "name": "work"},
		{"time": 0.70, "name": "meal"},
		{"time": 0.82, "name": "walk"},
		{"time": 0.95, "name": "return-home"},
	]
	for phase in phases:
		game.citizen_schedule_time = float(phase.time)
		game.update_citizen_schedules()
		move_residents_to_schedule_targets(game)
		await process_frame
		await process_frame
		if not save_viewport("%s/%s-1366x768.png" % [OUTPUT_DIR, phase.name]):
			quit(1)
			return
	print("NPC_SCHEDULE_RENDER_OK: work, meal, walk, return-home")
	quit(0)

func move_residents_to_schedule_targets(game) -> void:
	for child in game.citizen_root.get_children():
		if not child is Node3D:
			continue
		var target: Vector3 = child.get_meta("schedule_target", child.position)
		child.position = target

func save_viewport(path: String) -> bool:
	var image := get_root().get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("NPC_SCHEDULE_RENDER_FAILED: 空视口图像")
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var error := image.save_png(absolute)
	if error != OK:
		push_error("NPC_SCHEDULE_RENDER_FAILED: 无法写入 " + absolute)
		return false
	return true
