extends SceneTree

const RealisticKit = preload("res://godot/RealisticAssets.gd")
const OUTPUT_DIR := "res://qa/regional-buildings"
const OUTPUT_PATH := OUTPUT_DIR + "/regional-buildings.png"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(1366, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var stage := Node3D.new()
	root.add_child(stage)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b9d1cf")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d6ddd2")
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	sun.light_color = Color("ffe1b8")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(13.0, 7.5)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("71806b")
	ground_material.roughness = 0.96
	ground_mesh.material = ground_material
	ground.mesh = ground_mesh
	stage.add_child(ground)
	var types := ["market", "clinic", "academy"]
	for index in range(types.size()):
		var type: String = types[index]
		var building := RealisticKit.create_building(type, false, false)
		if building == null:
			push_error("REGIONAL_BUILDINGS_RENDER_FAILED: " + type)
			quit(1)
			return
		building.position = Vector3((index - 1) * 3.5, 0.0, 0.0)
		stage.add_child(building)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 7.2
	camera.position = Vector3(13.0, 14.0, 15.0)
	camera.current = true
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 0.9, 0.0))
	for _frame in range(6):
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH)) != OK:
		push_error("REGIONAL_BUILDINGS_RENDER_FAILED: screenshot")
		quit(1)
		return
	print("REGIONAL_BUILDINGS_RENDER_OK: market, clinic, academy")
	quit(0)
