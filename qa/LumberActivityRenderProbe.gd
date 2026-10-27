extends SceneTree

## Models only: never instantiates Main or accesses player saves.
const Art = preload("res://godot/RealisticAssets.gd")
const OUTPUT := "res://qa/lumber-activity"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440, 960)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var layout := GridContainer.new()
	layout.columns = 2
	layout.add_theme_constant_override("h_separation", 0)
	layout.add_theme_constant_override("v_separation", 0)
	root.add_child(layout)
	var phases := phase_samples()
	for entry in phases:
		add_panel(layout, float(entry.time), 0, str(entry.label))
	await save_sheet("lumber-work-cycle.png")
	for child in layout.get_children():
		child.queue_free()
	await process_frame
	for quarter in range(4):
		add_panel(layout, float(phases[2].time), quarter, "搬运通道 · %d°" % (quarter * 90))
	await save_sheet("lumber-four-rotations.png")
	layout.queue_free()
	await process_frame
	await process_frame
	await process_frame
	print("LUMBER_ACTIVITY_RENDER_OK" if failures.is_empty() else "LUMBER_ACTIVITY_RENDER_FAILED: " + str(failures))
	quit(0 if failures.is_empty() else 1)

func phase_samples() -> Array:
	# Sample the middle of each authored stage, so labels remain truthful when
	# animation durations change. All times are deterministic within a cycle.
	var yard := Art.create_building("lumber", false, false)
	root.add_child(yard)
	var activity := yard.get_node("WorkingResident/LumberActivity")
	activity.set_process(false)
	var windows: Dictionary = {}
	for frame in range(ceili(float(activity.CYCLE_SECONDS) * 60.0)):
		var seconds := frame / 60.0
		activity.sample(seconds)
		var phase: String = activity.activity
		if not windows.has(phase): windows[phase] = []
		windows[phase].append(seconds)
	var result: Array = []
	for pair in [["saw", "锯木"], ["pickup", "整理取料"], ["carry", "搬运"], ["putdown", "放料"]]:
		if windows.has(pair[0]):
			var times: Array = windows[pair[0]]
			result.append({"label": pair[1], "time": times[times.size() / 2]})
		else:
			failures.append("missing stage " + str(pair[0]))
			result.append({"label": pair[1] + "（阶段缺失）", "time": 0.0})
	yard.free()
	return result

func add_panel(layout: GridContainer, seconds: float, quarter: int, title: String) -> void:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(720, 480)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 480)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	layout.add_child(container)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("788469")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce0c7")
	environment.ambient_light_energy = 0.68
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(6, 6)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("788469")
	ground_mesh.material = ground_material
	ground.mesh = ground_mesh
	stage.add_child(ground)
	var yard := Art.create_building("lumber", false, false)
	yard.rotation.y = quarter * PI * 0.5
	stage.add_child(yard)
	var actor := yard.get_node_or_null("WorkingResident")
	var activity := actor.get_node_or_null("LumberActivity") if actor else null
	if activity:
		activity.set_process(false)
		activity.sample(seconds)
	else:
		failures.append("missing lumber actor/controller")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.85
	camera.position = Vector3(5.5, 7.5, 8)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.65, 0))
	var label := Label.new()
	label.text = title + " · %.2f秒" % seconds
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("fff2d2"))
	label.add_theme_color_override("font_shadow_color", Color("313727"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	viewport.add_child(label)

func save_sheet(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT.path_join(filename))
	if result != OK:
		failures.append("cannot save " + filename)
