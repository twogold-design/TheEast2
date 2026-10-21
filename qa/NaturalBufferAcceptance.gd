extends SceneTree

## Verifies that the visible world extends beyond the unchanged 48x48 gameplay
## grid and that every added perimeter prop remains outside editable cells.

var failures: Array[String] = []

class IsolatedGame:
	extends "res://godot/Main.gd"
	func _ready() -> void:
		pass
	func save_game(_show_feedback := true) -> void:
		push_error("NATURAL_BUFFER_TEST_MUST_NOT_SAVE")
	func load_game(_show_feedback := true) -> void:
		push_error("NATURAL_BUFFER_TEST_MUST_NOT_LOAD")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Construct only the world: no Main._ready/reset/load and no save writes.
	root.size = Vector2i(1366, 768)
	var game := IsolatedGame.new()
	game.time_paused = true
	root.add_child(game)
	game.create_world()
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	game.time_paused = true
	check_coordinate_compatibility(game)
	check_extended_terrain(game)
	check_natural_buffer(game)
	check_non_editable_boundary(game)
	await check_camera_envelope(game)
	game.queue_free()
	await process_frame
	finish()

func check_coordinate_compatibility(game) -> void:
	if int(game.GRID_SIZE) != 48:
		fail("可建网格不再是48x48")
	if int(game.NATURAL_BUFFER_CELLS) < 36:
		fail("自然缓冲区不足36格，最大镜头无法完整浏览边缘")
	if int(game.RENDER_GRID_SIZE) != int(game.GRID_SIZE) + int(game.NATURAL_BUFFER_CELLS) * 2:
		fail("渲染地表尺寸没有按两侧缓冲区扩展")
	var old_origin: Vector3 = game.grid_to_world(Vector2i(0, 0))
	var old_corner: Vector3 = game.grid_to_world(Vector2i(47, 47))
	var expected_extent := float(game.GRID_SIZE - 1) * float(game.TILE_SIZE) * 0.5
	if absf(old_origin.x + expected_extent) > 0.001 or absf(old_origin.z + expected_extent) > 0.001:
		fail("网格原点没有按新的格距居中：%s" % old_origin)
	if absf(old_corner.x - expected_extent) > 0.001 or absf(old_corner.z - expected_extent) > 0.001:
		fail("网格末端没有按新的格距居中：%s" % old_corner)
	for sample in [Vector2i(0, 0), Vector2i(19, 19), Vector2i(30, 24), Vector2i(47, 47)]:
		if game.world_to_grid(game.grid_to_world(sample)) != sample:
			fail("可建坐标无法保持往返一致：%s" % sample)

func check_extended_terrain(game) -> void:
	var terrain := game.world.get_node_or_null("ContinuousTerrain") as MeshInstance3D
	if terrain == null or terrain.mesh == null:
		fail("缺少连续扩展地表")
		return
	var bounds := terrain.mesh.get_aabb()
	var expected_width := float(game.RENDER_GRID_SIZE * game.TILE_SIZE)
	if bounds.size.x < expected_width - 0.01 or bounds.size.z < expected_width - 0.01:
		fail("地表没有覆盖完整自然缓冲区：%s" % bounds.size)
	if absf(bounds.position.x + expected_width * 0.5) > 0.01 or absf(bounds.position.z + expected_width * 0.5) > 0.01:
		fail("扩展地表没有围绕旧地图居中：%s" % bounds)
	if int(terrain.get_meta("playable_grid_size", -1)) != 48:
		fail("连续地表没有标明可玩网格范围")
	var inner_height := float(game.outer_terrain_height_for_vertex(24.0, 24.0))
	var edge_height := float(game.outer_terrain_height_for_vertex(-game.NATURAL_BUFFER_CELLS, -game.NATURAL_BUFFER_CELLS))
	if absf(inner_height - 0.15) > 0.001 or edge_height <= inner_height + 1.0:
		fail("外围地势没有从可建区平滑抬高")

func check_natural_buffer(game) -> void:
	var buffer := game.world.get_node_or_null("OuterNaturalBuffer") as Node3D
	if buffer == null:
		fail("缺少外围自然缓冲区节点")
		return
	if not bool(buffer.get_meta("non_editable", false)):
		fail("外围缓冲区未标记为不可编辑")
	if int(buffer.get_meta("buffer_cells", 0)) != int(game.NATURAL_BUFFER_CELLS):
		fail("外围节点记录的缓冲宽度错误")
	var tree_count := 0
	var rock_count := 0
	var ridge_count := 0
	var occupied_sides := {"north": false, "south": false, "west": false, "east": false}
	var depth_samples := {}
	var populated_bands := {}
	for child in buffer.get_children():
		var child_name := str(child.name)
		if child_name.begins_with("BufferTree_"):
			tree_count += 1
		elif child_name.begins_with("BufferRock_"):
			rock_count += 1
		elif child_name.begins_with("NaturalRidge_"):
			ridge_count += 1
		else:
			continue
		var cell: Vector2i = game.world_to_grid(child.position)
		var depth := maxi(maxi(-cell.x, cell.x - game.GRID_SIZE + 1), maxi(-cell.y, cell.y - game.GRID_SIZE + 1))
		populated_bands[mini(2, maxi(0, depth - 1) / 12)] = true
		if game.is_outer_river_corridor(Vector2(cell), 1.0):
			fail("外围景物阻挡河流出口：%s" % child_name)
		if game.is_playable_cell(cell):
			fail("外围景物侵入可建网格：%s @ %s" % [child_name, cell])
		if cell.y < 0:
			occupied_sides.north = true
			depth_samples["n%d" % cell.y] = true
		if cell.y >= int(game.GRID_SIZE):
			occupied_sides.south = true
			depth_samples["s%d" % cell.y] = true
		if cell.x < 0:
			occupied_sides.west = true
			depth_samples["w%d" % cell.x] = true
		if cell.x >= int(game.GRID_SIZE):
			occupied_sides.east = true
			depth_samples["e%d" % cell.x] = true
	if tree_count < 130 or rock_count < 48 or ridge_count < 40:
		fail("外围自然景物数量不足：树%d、石%d、山脊%d" % [tree_count, rock_count, ridge_count])
	for side in occupied_sides:
		if not bool(occupied_sides[side]):
			fail("外围景物没有覆盖%s侧" % side)
	if depth_samples.size() < 20:
		fail("外围景物纵深变化不足，仍像重复直排：%d" % depth_samples.size())
	if populated_bands.size() != 3:
		fail("扩展外围的三个12格纵深带未全部覆盖")
	for child in game.world.get_children():
		if str(child.name).begins_with("BoundaryHill_"):
			var hill_grid := Vector2(child.position.x / game.TILE_SIZE + game.GRID_SIZE * 0.5 - 0.5, child.position.z / game.TILE_SIZE + game.GRID_SIZE * 0.5 - 0.5)
			if game.is_outer_river_corridor(hill_grid, 2.3):
				fail("旧边界山堵住河流出口：%s" % child.name)

func check_non_editable_boundary(game) -> void:
	for sample in [
		Vector2i(-1, 12), Vector2i(48, 12), Vector2i(12, -1), Vector2i(12, 48),
		Vector2i(-10, -10), Vector2i(57, -10), Vector2i(-10, 57), Vector2i(57, 57)
	]:
		if str(game.can_place("house", sample)) != "超出地图边界":
			fail("外围自然缓冲区可建造：%s" % sample)
	game.selected_type = "house"
	game.update_ghost(Vector2i(-4, 20))
	if game.ghost != null or game.locked_hover != null:
		fail("鼠标经过外围时生成了可编辑预览")

func check_camera_envelope(game) -> void:
	var full_browse_extent: float = (game.GRID_SIZE * 0.5 + game.CAMERA_EDGE_BROWSE_CELLS) * game.TILE_SIZE
	var surface_extent: float = game.RENDER_GRID_SIZE * game.TILE_SIZE * 0.5
	for viewport_size in [Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(1024, 768), Vector2i(2560, 1080)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await process_frame
		for zoom in [game.CAMERA_MIN_SIZE, game.CAMERA_MAX_SIZE]:
			for pitch in [game.CAMERA_MIN_PITCH_DEGREES, game.CAMERA_MAX_PITCH_DEGREES]:
				for yaw in range(0, 360, 15):
					var offset := Vector3(sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)), cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch))) * 58.0
					game.camera.size = zoom
					for side in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
						game.camera_target = Vector3(side.x * 10000, 0, side.y * 10000)
						game.camera.position = game.camera_target + offset
						game.camera.look_at(game.camera_target)
						game.clamp_camera_target_to_bounds()
						var bounds: Vector2 = game.camera_pan_bounds()
						if viewport_size.x <= 1920 and (bounds.x < full_browse_extent - 0.05 or bounds.y < full_browse_extent - 0.05):
							fail("常见视口无法在最大镜头浏览边缘外4格：%s/%s/%s/%s" % [viewport_size, zoom, pitch, yaw])
						for corner in [Vector2.ZERO, Vector2(viewport_size.x, 0), Vector2(0, viewport_size.y), Vector2(viewport_size)]:
							var origin: Vector3 = game.camera.project_ray_origin(corner)
							var direction: Vector3 = game.camera.project_ray_normal(corner)
							var ground := origin - direction * (origin.y / direction.y)
							if absf(ground.x) > surface_extent - game.CAMERA_EDGE_SAFETY_MARGIN + 0.05 or absf(ground.z) > surface_extent - game.CAMERA_EDGE_SAFETY_MARGIN + 0.05:
								fail("真实镜头角射线露出地表边缘：%s/%s/%s/%s" % [viewport_size, zoom, pitch, yaw])

func fail(message: String) -> void:
	failures.append(message)
	push_error("NATURAL_BUFFER_ACCEPTANCE_FAILED: " + message)

func finish() -> void:
	if failures.is_empty():
		print("NATURAL_BUFFER_ACCEPTANCE_OK: 36-cell layered apron, 4-cell camera overscan, four viewports/all corners/extreme zoom-pitch, unchanged 48x48 build grid")
		quit(0)
	else:
		print("NATURAL_BUFFER_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
