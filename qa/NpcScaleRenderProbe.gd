extends SceneTree

const RealisticKit = preload("res://godot/RealisticAssets.gd")
const OUTPUT_PATH := "res://qa/npc-scale/current-ratio-1366x768.png"
const VIEWPORT_SIZE := Vector2i(1366, 768)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/npc-scale"))
	var stage := Node3D.new()
	stage.name = "NpcScaleComparison"
	root.add_child(stage)
	build_environment(stage)
	var house := RealisticKit.create_building("house", false, false)
	var packed := load("res://godot/Main.tscn") as PackedScene
	var game = packed.instantiate() if packed else null
	var citizen: Node3D = game.create_citizen(0) if game else null
	if game:
		game.free()
	if house == null or citizen == null:
		push_error("NPC_SCALE_RENDER_FAILED: 无法通过主场景加载真实茅舍或居民模型")
		quit(1)
		return
	house.position = Vector3(-0.55, 0.0, 0.0)
	citizen.position = Vector3(1.30, 0.0, 0.55)
	citizen.rotation.y = PI
	stage.add_child(house)
	stage.add_child(citizen)
	await process_frame
	var house_height := visible_height(house)
	var citizen_height := visible_height(citizen)
	var door_height := measure_door_height(house, house_height)
	add_height_guide(stage, citizen_height, 0.00, Color("d45d48"))
	add_height_guide(stage, door_height, 0.42, Color("547e9b"))
	add_height_guide(stage, house_height, 0.84, Color("ba8b3a"))
	add_caption(citizen_height, door_height, house_height)
	await process_frame
	await process_frame
	var texture := root.get_texture()
	if texture == null:
		push_error("NPC_SCALE_RENDER_FAILED: 当前显示驱动没有可读取的渲染纹理")
		quit(1)
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("NPC_SCALE_RENDER_FAILED: 渲染结果为空")
		quit(1)
		return
	var absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	var error := image.save_png(absolute)
	if error != OK:
		push_error("NPC_SCALE_RENDER_FAILED: 无法保存 " + absolute)
		quit(1)
		return
	print("NPC_SCALE_RENDER_OK: " + absolute)
	quit(0)

func build_environment(stage: Node3D) -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("dce1d7")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff6df")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	stage.add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_energy = 1.45
	light.shadow_enabled = true
	stage.add_child(light)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(9.0, 6.5)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("aeb899")
	material.roughness = 1.0
	plane.material = material
	ground.mesh = plane
	stage.add_child(ground)

	var camera := Camera3D.new()
	camera.position = Vector3(5.4, 3.6, 7.4)
	camera.look_at_from_position(camera.position, Vector3(0.25, 1.0, 0.0))
	camera.fov = 36.0
	stage.add_child(camera)
	camera.current = true

func add_height_guide(stage: Node3D, height: float, x_offset: float, color: Color) -> void:
	var root_guide := Node3D.new()
	root_guide.position = Vector3(2.05 + x_offset, 0.0, 0.52)
	stage.add_child(root_guide)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for y in [0.02, height]:
		var tick := MeshInstance3D.new()
		var tick_mesh := BoxMesh.new()
		tick_mesh.size = Vector3(0.36, 0.025, 0.025)
		tick_mesh.material = material
		tick.mesh = tick_mesh
		tick.position.y = y
		root_guide.add_child(tick)
	var line := MeshInstance3D.new()
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.025, height, 0.025)
	line_mesh.material = material
	line.mesh = line_mesh
	line.position = Vector3(0.17, height * 0.5, 0.0)
	root_guide.add_child(line)
func visible_height(subject: Node3D) -> float:
	var bounds := AABB()
	var has_bounds := false
	for child in subject.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var relative_transform := subject.global_transform.affine_inverse() * mesh_instance.global_transform
		var transformed := relative_transform * mesh_instance.mesh.get_aabb()
		bounds = transformed if not has_bounds else bounds.merge(transformed)
		has_bounds = true
	return bounds.size.y

func measure_door_height(house: Node3D, house_height: float) -> float:
	var bounds := AABB()
	var has_bounds := false
	for child in house.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var normalized := mesh_instance.name.to_lower()
		if "door" not in normalized and "entrance" not in normalized:
			continue
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var relative_transform := house.global_transform.affine_inverse() * mesh_instance.global_transform
		var transformed := relative_transform * mesh_instance.mesh.get_aabb()
		bounds = transformed if not has_bounds else bounds.merge(transformed)
		has_bounds = true
	return bounds.size.y if has_bounds and bounds.size.y > 0.30 else house_height * 0.58

func add_caption(citizen_height: float, door_height: float, house_height: float) -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(30, 28)
	panel.size = Vector2(720, 175)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.08, 0.88)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var label := Label.new()
	label.text = "居民与茅舍比例验收\n红 居民 %.2f m　蓝 房门 %.2f m　黄 茅舍 %.2f m\n当前：居民/茅舍 %.1f%%　房门/居民 %.1f%%\n通过范围：42–62%%　　　　 92–116%%" % [
		citizen_height,
		door_height,
		house_height,
		citizen_height / house_height * 100.0,
		door_height / citizen_height * 100.0,
	]
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("f4ead1"))
	panel.add_child(label)
