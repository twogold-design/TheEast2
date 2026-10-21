extends SceneTree

## Camera acceptance for the playable 48x48 map and its non-editable natural
## buffer. The camera may browse every playable corner, but its ground
## footprint must stay inside the buffered landscape at every legal zoom.

const VIEWPORT_SIZE := Vector2i(1366, 768)
const EPSILON := 0.05

var failures: Array[String] = []

class IsolatedGame:
	extends "res://godot/Main.gd"
	func _ready() -> void:
		pass
	func save_game(_show_feedback := true) -> void:
		push_error("CAMERA_TEST_MUST_NOT_SAVE")
	func load_game(_show_feedback := true) -> void:
		push_error("CAMERA_TEST_MUST_NOT_LOAD")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = VIEWPORT_SIZE
	var game := IsolatedGame.new()
	game.time_paused = true
	root.add_child(game)
	game.create_world()
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	game.time_paused = true
	check_zoom_limits(game)
	check_buffer_aware_clamp(game)
	await check_corner_browsing(game)
	check_rotation_reclamp(game)
	game.queue_free()
	await process_frame
	await process_frame
	finish()

func check_zoom_limits(game) -> void:
	if absf(float(game.CAMERA_INITIAL_SIZE) - 30.0) > EPSILON:
		fail("默认镜头应保持近景规划尺度 30，实际 %.2f" % float(game.CAMERA_INITIAL_SIZE))
	if float(game.CAMERA_MAX_SIZE) > 48.0 + EPSILON:
		fail("最大拉远仍过高：%.2f" % float(game.CAMERA_MAX_SIZE))
	if absf(game.camera.size - float(game.CAMERA_INITIAL_SIZE)) > EPSILON:
		fail("启动时没有使用默认镜头尺度")
	for index in range(32):
		send_wheel(game, MOUSE_BUTTON_WHEEL_DOWN)
	if absf(game.camera.size - float(game.CAMERA_MAX_SIZE)) > EPSILON:
		fail("滚轮向下没有准确停在最大拉远上限")
	for index in range(32):
		send_wheel(game, MOUSE_BUTTON_WHEEL_UP)
	if absf(game.camera.size - float(game.CAMERA_MIN_SIZE)) > EPSILON:
		fail("滚轮向上没有准确停在最近缩放下限")

func check_buffer_aware_clamp(game) -> void:
	game.camera.size = float(game.CAMERA_MAX_SIZE)
	game.clamp_camera_target_to_bounds()
	for delta in [Vector2(20000, 0), Vector2(-20000, 0), Vector2(0, 20000), Vector2(0, -20000)]:
		game.pan_camera(delta)
		assert_camera_inside_buffer(game, "最大拉远平移")
	var far_bounds: Vector2 = game.camera_pan_bounds()
	game.camera.size = float(game.CAMERA_MIN_SIZE)
	game.clamp_camera_target_to_bounds()
	var near_bounds: Vector2 = game.camera_pan_bounds()
	var browse_extent: float = (game.GRID_SIZE * 0.5 + game.CAMERA_EDGE_BROWSE_CELLS) * game.TILE_SIZE
	if near_bounds.x < browse_extent - EPSILON or near_bounds.y < browse_extent - EPSILON or far_bounds.x < browse_extent - EPSILON or far_bounds.y < browse_extent - EPSILON:
		fail("近景和远景都应能浏览边缘外4格：远景 %s，近景 %s" % [far_bounds, near_bounds])

func check_corner_browsing(game) -> void:
	game.camera.size = float(game.CAMERA_MIN_SIZE)
	var extent: float = (game.GRID_SIZE - 1) * game.TILE_SIZE * 0.5
	for corner in [Vector3(-extent, 0, -extent), Vector3(extent, 0, -extent), Vector3(-extent, 0, extent), Vector3(extent, 0, extent)]:
		move_camera_target(game, corner)
		await process_frame
		assert_camera_inside_buffer(game, "四角浏览")
		var screen: Vector2 = game.camera.unproject_position(corner)
		if game.camera.is_position_behind(corner) or screen.x < -1.0 or screen.y < -1.0 or screen.x > VIEWPORT_SIZE.x + 1.0 or screen.y > VIEWPORT_SIZE.y + 1.0:
			fail("中键平移后地图角落不在视野内：%s -> %s" % [corner, screen])

func check_rotation_reclamp(game) -> void:
	game.camera.size = float(game.CAMERA_MAX_SIZE)
	move_camera_target(game, Vector3(47, 0, 47))
	for delta in [Vector2(180, 500), Vector2(-360, -900), Vector2(720, 1000)]:
		game.rotate_camera(delta)
		assert_camera_inside_buffer(game, "旋转后镜头")
		var direction: Vector3 = -game.camera.global_transform.basis.z
		var pitch := rad_to_deg(asin(clampf(-direction.y, -1.0, 1.0)))
		if pitch < float(game.CAMERA_MIN_PITCH_DEGREES) - 0.1 or pitch > float(game.CAMERA_MAX_PITCH_DEGREES) + 0.1:
			fail("镜头俯角越界：%.2f" % pitch)

func send_wheel(game, button_index: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	event.position = VIEWPORT_SIZE / 2
	game._unhandled_input(event)

func move_camera_target(game, target: Vector3) -> void:
	var offset: Vector3 = game.camera.position - game.camera_target
	game.camera_target = target
	game.camera.position = target + offset
	game.camera.look_at(target)
	game.clamp_camera_target_to_bounds()

func assert_camera_inside_buffer(game, context: String) -> void:
	var footprint: Vector2 = game.camera_ground_axis_extents()
	var outer_extent := (float(game.GRID_SIZE) * float(game.TILE_SIZE) * 0.5) + float(game.NATURAL_BUFFER_CELLS) * float(game.TILE_SIZE)
	var margin := float(game.CAMERA_EDGE_SAFETY_MARGIN)
	if absf(game.camera_target.x) + footprint.x > outer_extent - margin + EPSILON:
		fail("%s在东西方向看见自然缓冲硬边" % context)
	if absf(game.camera_target.z) + footprint.y > outer_extent - margin + EPSILON:
		fail("%s在南北方向看见自然缓冲硬边" % context)

func fail(message: String) -> void:
	failures.append(message)
	push_error("CAMERA_EDGE_ACCEPTANCE_FAILED: " + message)

func finish() -> void:
	if failures.is_empty():
		print("CAMERA_EDGE_ACCEPTANCE_OK: zoom=%.0f..%.0f, buffered clamp, rotation, four-corner browsing" % [18.0, 48.0])
		quit(0)
	else:
		print("CAMERA_EDGE_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
