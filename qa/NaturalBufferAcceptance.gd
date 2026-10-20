extends SceneTree

## Verifies that the visible world extends beyond the unchanged 48x48 gameplay
## grid and that every added perimeter prop remains outside editable cells.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		fail("主场景无法加载")
		finish()
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.time_paused = true
	check_coordinate_compatibility(game)
	check_extended_terrain(game)
	check_natural_buffer(game)
	check_non_editable_boundary(game)
	finish()

func check_coordinate_compatibility(game) -> void:
	if int(game.GRID_SIZE) != 48:
		fail("可建网格不再是48x48")
	if int(game.NATURAL_BUFFER_CELLS) < 10:
		fail("自然缓冲区不足10格，镜头仍容易看到硬边")
	if int(game.RENDER_GRID_SIZE) != int(game.GRID_SIZE) + int(game.NATURAL_BUFFER_CELLS) * 2:
		fail("渲染地表尺寸没有按两侧缓冲区扩展")
	var old_origin: Vector3 = game.grid_to_world(Vector2i(0, 0))
	var old_corner: Vector3 = game.grid_to_world(Vector2i(47, 47))
	if old_origin.distance_to(Vector3(-47.0, 0.0, -47.0)) > 0.001:
		fail("旧存档原点坐标发生变化：%s" % old_origin)
	if old_corner.distance_to(Vector3(47.0, 0.0, 47.0)) > 0.001:
		fail("旧存档末端坐标发生变化：%s" % old_corner)
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
	var edge_height := float(game.outer_terrain_height_for_vertex(-12.0, -12.0))
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
	if tree_count < 56 or rock_count < 24 or ridge_count < 28:
		fail("外围自然景物数量不足：树%d、石%d、山脊%d" % [tree_count, rock_count, ridge_count])
	for side in occupied_sides:
		if not bool(occupied_sides[side]):
			fail("外围景物没有覆盖%s侧" % side)
	if depth_samples.size() < 20:
		fail("外围景物纵深变化不足，仍像重复直排：%d" % depth_samples.size())

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

func fail(message: String) -> void:
	failures.append(message)
	push_error("NATURAL_BUFFER_ACCEPTANCE_FAILED: " + message)

func finish() -> void:
	if failures.is_empty():
		print("NATURAL_BUFFER_ACCEPTANCE_OK: 12-cell apron, four-side woodland, rocks/ridges, non-editable, 48x48 coordinates preserved")
		quit(0)
	else:
		print("NATURAL_BUFFER_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
