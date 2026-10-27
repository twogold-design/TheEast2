extends SceneTree
## No game startup or save I/O: only Main's road geometry functions are used.
const Main = preload("res://godot/Main.gd")
var errors: Array[String] = []
var frames := 0
var game: Node
func _initialize() -> void:
	root.size = Vector2i(1500, 1000)
	game = Main.new()
	var center := Vector2i(20, 20)
	var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for mask in range(16):
		game.roads.clear()
		game.roads[center] = null
		for i in range(4):
			if mask & (1 << i): game.roads[center + directions[i]] = null
		var model: Node3D = game.create_road_model(center)
		check(model.get_child_count() == 2, "merged mesh count for mask " + str(mask))
		var openings: Array = model.get_meta("openings")
		var expected := 0
		for i in range(4):
			if mask & (1 << i): expected += 1
		check(openings.size() == expected, "each connected arm has an open endpoint")
		for child in model.get_children():
			check(child.mesh.get_surface_count() == 1 and child.get_active_material(0) != null, "valid shared material")
			var bounds: AABB = child.get_aabb()
			check(bounds.size.y < 0.001, "path has no raised slab walls")
			check(bounds.end.y <= 0.041, "no raised transverse connection lips")
		model.free()
	game.roads.clear()
	game.roads[Vector2i(11,10)] = null
	var side: Node3D = game.create_road_model(Vector2i(11,10))
	var left_end := 0.0
	for rect in side.get_meta("surface_rectangles"):
		left_end = minf(left_end, rect.position.x)
	check(is_equal_approx(left_end, -1.65), "side branch meets narrow main street exactly")
	side.free()
	game.roads.clear()
	game.roads[Vector2i(1,9)] = null
	var bridge: Node3D = game.create_road_model(Vector2i(1,9))
	var right_end := 0.0
	for rect in bridge.get_meta("surface_rectangles"):
		right_end = maxf(right_end, rect.end.x)
	check(is_equal_approx(right_end, 1.10), "bridge approach stops at bank boundary")
	bridge.free()
	var grid := GridContainer.new()
	grid.columns = 3
	root.add_child(grid)
	panel(grid, "直路", [Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0)], center)
	panel(grid, "转角", [Vector2i(0,-1),Vector2i(0,0),Vector2i(1,0)], center)
	panel(grid, "丁字路", [Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)], center)
	panel(grid, "十字路口", [Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)], center)
	panel(grid, "主路衔接", [Vector2i(0,-1),Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(2,0)], Vector2i(10,10))
	panel(grid, "桥头衔接", [Vector2i(-1,0),Vector2i(0,0)], Vector2i(1,9), true)
	game.free()

func panel(grid: GridContainer, title: String, offsets: Array, center: Vector2i, bridge := false) -> void:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(496,496)
	grid.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(496,496)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("788467")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("f1e3ca")
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-30,0)
	light.light_energy = 0.9
	light.shadow_enabled = true
	world.add_child(light)
	var ground: MeshInstance3D = game.mesh_box(Vector3(9,0.2,9),Color("7e8966"))
	ground.position.y = 0.10
	world.add_child(ground)
	game.roads.clear()
	for offset in offsets: game.roads[center + offset] = null
	for offset in offsets:
		var model: Node3D = game.create_road_model(center + offset)
		model.position = Vector3(offset.x * 2.2,0.225,offset.y * 2.2)
		world.add_child(model)
	if bridge:
		var model: Node3D = game.RealisticKit.create_bridge()
		model.scale.x = 1.1
		model.position = Vector3(3.3,0.34,0)
		world.add_child(model)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.8
	camera.position = Vector3(7,10,9)
	world.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0.6,0,0))
	var label := Label.new()
	label.text = title
	label.position = Vector2(16,12)
	label.add_theme_font_size_override("font_size",24)
	viewport.add_child(label)

func check(ok: bool, text: String) -> void:
	if not ok: errors.append(text)
func _process(_delta: float) -> bool:
	frames += 1
	if frames == 15:
		if DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute("res://qa/road-surface")
			check(root.get_texture().get_image().save_png("res://qa/road-surface/junctions.png") == OK, "save six-junction render")
		for error in errors: push_error(error)
		print("ROAD_SURFACE_VISUAL_OK" if errors.is_empty() else "ROAD_SURFACE_VISUAL_FAILED")
		quit(0 if errors.is_empty() else 1)
	return false
