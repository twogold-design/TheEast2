extends SceneTree

const RealisticKit = preload("res://godot/RealisticAssets.gd")

const OUTPUT_DIR := "res://qa/roof-identity"
const DEFAULT_OUTPUT := OUTPUT_DIR + "/roof-identity-default.png"
const REVERSE_OUTPUT := OUTPUT_DIR + "/roof-identity-reverse.png"
const VIEWPORT_SIZE := Vector2i(1366, 768)
const CAMERA_TARGET := Vector3(0.0, 0.85, 0.0)
const CAMERA_SIZE := 11.0
const BUILDING_TYPES := ["house", "lumber", "farm", "warehouse", "workshop"]
const BUILDING_POSITIONS := [
	Vector3(-6.4, 0.0, 0.0),
	Vector3(-3.2, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
	Vector3(3.2, 0.0, 0.0),
	Vector3(6.4, 0.0, 0.0),
]

var stage: Node3D
var camera: Camera3D


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	stage = Node3D.new()
	stage.name = "RoofIdentityStage"
	root.add_child(stage)
	create_environment()
	create_ground()
	if not create_buildings():
		quit(1)
		return
	create_camera()

	await settle_render()
	if not save_viewport(DEFAULT_OUTPUT):
		quit(1)
		return

	camera.position = CAMERA_TARGET + Vector3(-30.0, 34.0, -31.0)
	camera.look_at(CAMERA_TARGET)
	await settle_render()
	if not save_viewport(REVERSE_OUTPUT):
		quit(1)
		return

	print("ROOF_IDENTITY_RENDER_OK: house, lumber, farm, warehouse, workshop; default_and_reverse")
	quit(0)


func create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "RoofIdentityEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b9d1cf")
	environment.background_energy_multiplier = 0.8
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c9d7d2")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	stage.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "RoofIdentitySun"
	sun.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	sun.light_color = Color("ffe1b8")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	stage.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "RoofIdentityFill"
	fill.rotation_degrees = Vector3(-30.0, 142.0, 0.0)
	fill.light_color = Color("bed9d7")
	fill.light_energy = 0.16
	fill.shadow_enabled = false
	stage.add_child(fill)


func create_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "RoofIdentityGround"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(18.0, 8.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("71806b")
	material.roughness = 0.96
	mesh.material = material
	ground.mesh = mesh
	ground.position.y = -0.025
	stage.add_child(ground)


func create_buildings() -> bool:
	for index in range(BUILDING_TYPES.size()):
		var building_type: String = BUILDING_TYPES[index]
		var building := RealisticKit.create_building(building_type, false, false)
		if building == null:
			push_error("ROOF_IDENTITY_RENDER_FAILED: missing realistic building " + building_type)
			return false
		if str(building.get_meta("asset_source", "")) != "realistic":
			push_error("ROOF_IDENTITY_RENDER_FAILED: fallback building " + building_type)
			return false
		building.name = "RoofIdentity_%s" % building_type.capitalize()
		building.position = BUILDING_POSITIONS[index]
		stage.add_child(building)
	return true


func create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "RoofIdentityCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = CAMERA_SIZE
	camera.position = CAMERA_TARGET + Vector3(30.0, 34.0, 31.0)
	camera.current = true
	stage.add_child(camera)
	camera.look_at(CAMERA_TARGET)


func settle_render() -> void:
	for _frame in range(5):
		await process_frame


func save_viewport(path: String) -> bool:
	var image := get_root().get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("ROOF_IDENTITY_RENDER_FAILED: empty viewport")
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var error := image.save_png(absolute)
	if error != OK:
		push_error("ROOF_IDENTITY_RENDER_FAILED: cannot save " + absolute)
		return false
	return true
