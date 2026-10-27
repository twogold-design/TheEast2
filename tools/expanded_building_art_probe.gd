extends SceneTree

const Assets = preload("res://godot/RealisticAssets.gd")
var models: Array[Node3D] = []
var frames := 0
var view_angle := 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("angle="):
			view_angle = int(argument.trim_prefix("angle="))
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("bfc8b0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("faf1d5")
	env.ambient_light_energy = 0.72
	environment.environment = env
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-53, -28, 0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 28
	world.add_child(camera)
	camera.position = Vector3(13, 22, 28)
	camera.look_at_from_position(camera.position, Vector3(0, 0, 0))
	var types := ["lumber", "workshop", "warehouse", "weaver", "market", "fishpond", "academy"]
	for i in range(types.size()):
		var model := Assets.create_building(types[i])
		world.add_child(model)
		model.position = Vector3((i % 4) * 7.7 - 11.55, 0, (i / 4) * 8.2 - 4.1)
		models.append(model)
		var label := Label3D.new()
		label.text = types[i]
		label.position = model.position + Vector3(0, 0.2, 3.6)
		label.font_size = 42
		label.pixel_size = 0.014
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
		var bounds := _bounds(model, Transform3D.IDENTITY)
		assert(model.find_child("Door", true, false) == model.get_node("Door"), types[i] + " ambiguous entrance")
		assert(model.get_node("Door").position == model.get_meta("main_entrance"), types[i] + " inconsistent entrance")
		print("ART ", types[i], " bounds=", bounds, " cells=", model.get_meta("footprint_cells"))
		var half_x: float = 2.21 if types[i] in ["lumber", "warehouse"] else 3.31
		assert(bounds.position.x >= -half_x and bounds.end.x <= half_x, types[i] + " exceeds X footprint")
		var half_z: float = 3.31 if types[i] in ["market", "fishpond", "academy"] else 2.21
		assert(bounds.position.z >= -half_z and bounds.end.z <= half_z, types[i] + " exceeds Z footprint")
		for quarter in range(4):
			var rotated := _bounds(model, Transform3D(Basis(Vector3.UP, quarter * PI / 2.0), Vector3.ZERO))
			var limit_x := half_x if quarter % 2 == 0 else half_z
			var limit_z := half_z if quarter % 2 == 0 else half_x
			assert(rotated.position.x >= -limit_x and rotated.end.x <= limit_x, types[i] + " rotated X bounds")
			assert(rotated.position.z >= -limit_z and rotated.end.z <= limit_z, types[i] + " rotated Z bounds")
		model.rotation.y = deg_to_rad(view_angle)
	print("ART_PROBE_CREATED_OK")

func _bounds(node: Node3D, transform: Transform3D) -> AABB:
	var bounds := AABB()
	if not node.visible:
		return bounds
	if node is MeshInstance3D:
		bounds = transform * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var extra := _bounds(child, transform * child.transform)
			if extra.size.length_squared() > 0:
				bounds = extra if bounds.size.length_squared() == 0 else bounds.merge(extra)
	return bounds

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 12:
		if DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png("res://.godot-user/Logs/expanded_buildings_%d.png" % view_angle)
		print("ART_PROBE_DONE")
		quit()
	return false
