extends SceneTree

## Asset-only inspection and rendering. Never reads a settlement save.
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
	for quarter in [0, 2]:
		for state in range(3):
			panel(grid, state, quarter)
	var home := Art.create_building("house", false, false)
	var original_roof := home.get_node("TiledLivingHall").get_child_count()
	Details.apply_house_visual(home, "artisan")
	var count := mesh_count(home)
	for i in range(20):
		Details.apply_house_visual(home, "artisan")
	check(count == mesh_count(home), "repeated refresh does not accumulate geometry")
	check(home.get_node("TiledLivingHall").get_child_count() == original_roof, "original hall geometry retained for restoring farmer home")
	var upper := home.get_node_or_null("HouseholdJoinery/ArtisanUpperStorey") as Node3D
	check(upper != null, "artisan has an actual second storey")
	if upper:
		check(is_equal_approx(upper.position.y - home.get_node("TiledLivingHall").position.y, 1.08), "second storey raised by a full floor height")
		check(upper.scale == home.get_node("TiledLivingHall").scale, "upper floor retains human-scale doors and windows")
		check(upper.get_node_or_null("RearWall") != null and upper.get_node_or_null("OpenDoorLeaf") != null, "upper floor includes complete walls and open doors")
		for part in upper.get_children():
			if part is Node3D and Details._house_roof_part(part):
				check(part.visible, "upper storey has complete tiled roof and gables")
	for part in home.get_node("TiledLivingHall").get_children():
		if part is Node3D and Details._house_roof_part(part):
			check(not part.visible, "old roof removed from inside upper rooms")
	check(home.get_node_or_null("HouseholdJoinery/ArtisanUpperBalcony") != null, "upper floor opens onto a supported balcony")
	check(home.get_node("LivingCourt/EnclosedBambooBoundary").visible, "closed perimeter fence retained")
	var entrance := AABB(Vector3(-0.27, 0.26, 0.86), Vector3(0.54, 0.69, 0.20))
	for part in home.get_node("HouseholdJoinery/ArtisanCourtyardGate").get_children():
		if part is MeshInstance3D:
			check(not (part.transform * part.get_aabb()).intersects(entrance), "upgraded gate retains clear passage")
	check(not home.get_node("LivingCourt/HouseholdFirewood").visible, "tool rack replaces firewood rather than overlapping it")
	Details.apply_house_visual(home, "farmer", 0.5)
	check(not home.get_node("HouseholdJoinery").visible, "renovation does not show completed artisan details")
	check(home.get_node("HouseUpgradeScaffold").visible, "construction scaffold remains")
	check(home.get_node("LivingCourt/HouseholdFirewood").visible, "farmer firewood restored")
	for part in home.get_node("TiledLivingHall").get_children():
		if part is Node3D and Details._house_roof_part(part):
			check(part.visible, "farmer roof and both gables restore completely")
	Details.apply_house_visual(home, "artisan")
	check(home.get_node("HouseholdJoinery").visible and not home.get_node("HouseUpgradeScaffold").visible, "completion immediately swaps scaffold for artisan home")
	for quarter in range(4):
		var bounds := bounds_of(home, Transform3D(Basis(Vector3.UP, quarter * PI / 2), Vector3.ZERO))
		check(bounds.position.x >= -1.1 and bounds.end.x <= 1.1 and bounds.position.z >= -1.1 and bounds.end.z <= 1.1, "artisan fits one 2.2m cell in rotation " + str(quarter))
		check(home.scale == Vector3.ONE, "whole house is not scaled")
	for mesh in home.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			check(mesh.get_active_material(surface) != null, "all mesh materials exist")
	home.free()
	var preview := Art.create_building("house", true, false)
	check(preview.get_node_or_null("HouseholdJoinery") == null, "placement preview is ordinary farmer home")
	preview.free()

func panel(grid: GridContainer, state: int, quarter: int) -> void:
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
	Details.apply_house_visual(home, "artisan" if state == 2 else "farmer", 0.5 if state == 1 else -1.0)
	home.rotation.y = quarter * PI / 2
	world.add_child(home)
	if state == 1:
		var effect := home.get_node_or_null("HouseUpgradeEffects")
		if effect and effect.has_method("advance_visual"):
			effect.advance_visual(0.1)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	camera.position = Vector3(5.5, 7.5, 8)
	world.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0, 1.4, 0))
	var label := Label.new()
	label.text = ["农户", "改建中", "匠户"][state] + " · %d°" % (quarter * 90)
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 24)
	viewport.add_child(label)

func mesh_count(root_node: Node) -> int:
	return root_node.find_children("*", "MeshInstance3D", true, false).size()

func bounds_of(node: Node3D, transform: Transform3D) -> AABB:
	if not node.visible or node.name == "HouseUpgradeEffects":
		return AABB()
	var bounds := AABB()
	if node is MeshInstance3D:
		bounds = transform * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var extra := bounds_of(child, transform * child.transform)
			if extra.size.length_squared() > 0:
				bounds = extra if bounds.size.length_squared() == 0 else bounds.merge(extra)
	return bounds

func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		if DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute("res://qa/household-artisan")
			root.get_texture().get_image().save_png("res://qa/household-artisan/farmer-renovating-artisan.png")
		for error in errors:
			push_error(error)
		print("ARTISAN_HOUSE_VISUAL_OK" if errors.is_empty() else "ARTISAN_HOUSE_VISUAL_FAILED")
		quit(0 if errors.is_empty() else 1)
	return false
