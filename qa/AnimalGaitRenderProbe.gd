extends SceneTree

const AnimalKit = preload("res://godot/AnimalAssets.gd")
const PHASES := [0.0, 0.2, 0.45, 0.6, 0.8, 0.95]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1536, 960)
	root.content_scale_size = Vector2i(1536, 960)
	var layout := GridContainer.new()
	layout.columns = 6
	layout.add_theme_constant_override("h_separation", 0)
	layout.add_theme_constant_override("v_separation", 0)
	root.add_child(layout)
	for species in AnimalKit.SPECIES:
		for phase in PHASES:
			var container := SubViewportContainer.new()
			container.custom_minimum_size = Vector2(256, 240)
			var viewport := SubViewport.new()
			viewport.size = Vector2i(256, 240)
			viewport.own_world_3d = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			container.add_child(viewport)
			layout.add_child(container)
			create_stage(viewport, species, phase)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://qa/village-life")
	root.get_texture().get_image().save_png("res://qa/village-life/animal-gait-phases.png")
	layout.queue_free()
	await process_frame
	await process_frame
	print("ANIMAL_GAIT_RENDER_OK: 4 species x 6 phases, gameplay scale 0.48")
	quit(0)

func create_stage(viewport: SubViewport, species: String, phase: float) -> void:
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("546357")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c8d1bd")
	environment.ambient_light_energy = 0.40
	environment_node.environment = environment
	stage.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(1.5, 0.04, 1.5)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("788971")
	floor_mesh.material = floor_material
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.position.y = -0.02
	stage.add_child(floor)
	var animal := AnimalKit.create_animal(species, 0)
	animal.scale = Vector3.ONE * 0.48
	stage.add_child(animal)
	AnimalKit.animate_walk(animal, phase * float(animal.get_meta("gait_stride")) * 0.48)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.72
	camera.position = Vector3(-1.5, 0.65, 1.0)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.24, 0))
	var label := Label.new()
	label.text = "%s  %.2f" % [species, phase]
	label.position = Vector2(12, 8)
	label.add_theme_font_size_override("font_size", 18)
	viewport.add_child(label)
