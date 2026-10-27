extends SceneTree

## Isolated rendered transition evidence; never opens a player settlement.
const Art = preload("res://godot/RealisticAssets.gd")
const Details = preload("res://godot/ExpandedBuildingAssets.gd")
var errors: Array[String] = []
var frames := 0

func _initialize() -> void:
	root.size = Vector2i(1500, 1000)
	root.content_scale_size = root.size
	var grid := GridContainer.new()
	grid.columns = 3
	root.add_child(grid)
	var times := [0.10, 0.60, 0.0, 0.25, 0.65, 1.30]
	for state in range(times.size()):
		panel(grid, state, times[state])

func panel(grid: GridContainer, state: int, elapsed: float) -> void:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(496, 496)
	grid.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(496, 496)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("788469")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e0dfc7")
	env.ambient_light_energy = 0.7
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	world.add_child(sun)
	var home := Art.create_building("house", false, false)
	world.add_child(home)
	Details.apply_house_visual(home, "farmer", 0.5)
	var effect := home.get_node("HouseUpgradeEffects")
	if state > 1:
		Details.apply_house_visual(home, "artisan")
	var remaining := elapsed
	while remaining > 0.00001:
		var step := minf(remaining, 0.05)
		effect.advance_visual(step)
		remaining -= step
	if state <= 1:
		check(effect.hammer.visible, "hammer visible during construction")
	elif elapsed < 1.25:
		check(effect.dust != null and effect.completion_count == 1, "real completion creates exactly one dust effect")
	else:
		check(effect.dust == null, "completion dust clears after 1.25 seconds")
	for part in home.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			check(part.get_active_material(surface) != null, "every effect and house surface has a valid material")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	camera.position = Vector3(5.5, 7.5, 8)
	world.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0, 1.4, 0))
	var label := Label.new()
	label.text = ["施工 · 落锤", "施工 · 抬锤", "完工瞬间", "完工 · 0.25秒", "完工 · 0.65秒", "完工 · 灰尘散尽"][state]
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 24)
	viewport.add_child(label)

func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		if DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute("res://qa/household-artisan")
			root.get_texture().get_image().save_png("res://qa/household-artisan/construction-effects.png")
		for error in errors:
			push_error(error)
		print("HOUSE_UPGRADE_DUST_RENDER_OK" if errors.is_empty() else "HOUSE_UPGRADE_DUST_RENDER_FAILED")
		quit(0 if errors.is_empty() else 1)
	return false
