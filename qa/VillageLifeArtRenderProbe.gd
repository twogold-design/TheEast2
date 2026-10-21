extends SceneTree

const ArtKit = preload("res://godot/RealisticAssets.gd")
const AnimalKit = preload("res://godot/AnimalAssets.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366, 768)
	var stage := Node3D.new()
	root.add_child(stage)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a7b3a2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ded6bd")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.75
	env_node.environment = env
	stage.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(13, 0.1, 8)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("84916d")
	floor_mat.roughness = 0.95
	floor_mesh.material = floor_mat
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.position.y = -0.05
	stage.add_child(floor)
	var house := ArtKit.create_building("house")
	house.position = Vector3(-4.3, 0, -0.6)
	stage.add_child(house)
	for index in range(6):
		var citizen := ArtKit.create_citizen_variant(index, index)
		citizen.scale *= 0.52
		citizen.position = Vector3(-1.8 + index * 1.0, 0, -0.8)
		citizen.rotation.y = -0.25
		stage.add_child(citizen)
		add_label(stage, str(citizen.get_meta("npc_variant_name")), citizen.position + Vector3(0, 0.17, 0.6))
	for index in range(4):
		var species: String = AnimalKit.SPECIES[index]
		var animal := AnimalKit.create_animal(species, index)
		animal.scale *= 0.48
		animal.position = Vector3(-0.9 + index * 1.05, 0, 1.1)
		AnimalKit.animate_walk(animal, 0.08)
		stage.add_child(animal)
		add_label(stage, ["鸡", "鸭", "鹅", "狗"][index], animal.position + Vector3(0, 0.17, 0.60))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.2
	camera.position = Vector3(5, 9, 13)
	stage.add_child(camera)
	camera.look_at(Vector3(-0.7, 0.4, 0))
	camera.current = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://qa/village-life")
	root.get_texture().get_image().save_png("res://qa/village-life/model-scale-comparison.png")
	stage.queue_free()
	await process_frame
	print("VILLAGE_LIFE_ART_RENDER_OK: six residents, four animals, house scale reference")
	quit(0)

func add_label(stage: Node3D, text: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 38
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = position
	label.modulate = Color("f2e6ca")
	label.outline_modulate = Color("2f3433")
	label.outline_size = 7
	stage.add_child(label)
