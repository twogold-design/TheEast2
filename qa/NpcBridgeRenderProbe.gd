extends SceneTree

const OUTPUT_DIR := "res://qa/npc-bridge"
const OUTPUT_PATH := OUTPUT_DIR + "/main-river-1366x768.png"
const VIEWPORT_SIZE := Vector2i(1366, 768)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		push_error("NPC_BRIDGE_RENDER_FAILED: 主场景无法加载")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.reset_game(false)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.time_paused = true
	for child in game.get_children():
		if child is CanvasLayer:
			child.visible = false

	var bridge := game.world.find_child("RiverBridge", true, false) as Node3D
	if bridge == null or game.citizen_root.get_child_count() < 1:
		push_error("NPC_BRIDGE_RENDER_FAILED: 缺少主河桥或居民")
		quit(1)
		return
	var bridge_centre: Vector3 = bridge.position
	var resident_offsets := [-1.25, 0.0, 1.25]
	var resident_index := 0
	for child in game.citizen_root.get_children():
		if not child is Node3D or child.is_queued_for_deletion():
			continue
		if resident_index >= resident_offsets.size():
			child.visible = false
			continue
		var resident := child as Node3D
		var planar := Vector3(bridge_centre.x + float(resident_offsets[resident_index]), 0.0, bridge_centre.z)
		var surface_height: float = game.citizen_surface_height(planar)
		resident.position = Vector3(planar.x, surface_height, planar.z)
		resident.rotation.y = PI * 0.5
		resident.set_meta("walk_distance", 0.18 + resident_index * 0.14)
		game.update_citizen_walk_animation(resident, 0.12)
		resident_index += 1

	var focus := bridge_centre + Vector3(0, 0.62, 0)
	game.camera.size = 8.5
	game.camera_target = focus
	game.camera.position = focus + Vector3(7.4, 6.8, 7.8)
	game.camera.look_at(focus)
	add_caption()
	await process_frame
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("NPC_BRIDGE_RENDER_FAILED: 空视口图像")
		quit(1)
		return
	var absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	var error := image.save_png(absolute)
	if error != OK:
		push_error("NPC_BRIDGE_RENDER_FAILED: 无法写入 " + absolute)
		quit(1)
		return
	print("NPC_BRIDGE_RENDER_OK: " + absolute)
	quit(0)

func add_caption() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 26)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.08, 0.86)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var label := Label.new()
	label.text = "居民桥面通行验收\n桥面中线行走 · 脚部抬高 · 避开水面与栏杆"
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("f3e6c9"))
	panel.add_child(label)
