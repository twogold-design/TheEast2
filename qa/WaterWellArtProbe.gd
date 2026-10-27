extends SceneTree

## Asset-only checks; no Main instance, save reads or save writes.
const Art = preload("res://godot/ExpandedBuildingAssets.gd")
var errors: Array[String] = []
var frames := 0

func _initialize() -> void:
	root.size = Vector2i(1440, 1000)
	root.content_scale_size = root.size
	var grid := GridContainer.new()
	grid.columns = 2
	root.add_child(grid)
	for quarter in range(4):
		var container := SubViewportContainer.new()
		container.custom_minimum_size = Vector2(716, 496)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(716, 496)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		grid.add_child(container)
		var world := Node3D.new()
		viewport.add_child(world)
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("788469")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("e0dfc7")
		env.ambient_light_energy = 0.70
		var environment := WorldEnvironment.new()
		environment.environment = env
		world.add_child(environment)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-48, -35, 0)
		sun.light_energy = 0.85
		sun.shadow_enabled = true
		world.add_child(sun)
		var ground := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(6, 6)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("788469")
		mesh.material = mat
		ground.mesh = mesh
		world.add_child(ground)
		var well := Art.create_building("well", false)
		well.rotation.y = quarter * PI * 0.5
		world.add_child(well)
		check(well.get_meta("footprint_cells") == Vector2i(2, 2), "well footprint")
		var shape: BoxShape3D = well.get_node("AssetCollision").get_child(0).shape
		check(shape.size == Vector3(4.18, 0.35, 4.18), "well collision")
		var bounds := bounds_of(well, well.transform)
		check(bounds.position.x >= -2.091 and bounds.end.x <= 2.091 and bounds.position.z >= -2.091 and bounds.end.z <= 2.091, "well geometry fits rotation " + str(quarter))
		check(well.find_child("VisibleWellWater", true, false) != null, "open well contains water")
		check(well.find_children("CutWellMasonry*", "MeshInstance3D", true, false).size() == 36, "36 individually modelled masonry blocks")
		check(well.find_child("WaterDistributionTrough", true, false) != null, "distribution trough exists")
		for instance in well.find_children("*", "MeshInstance3D", true, false):
			for index in instance.mesh.get_surface_count():
				check(instance.get_active_material(index) != null, "material exists for " + str(instance.name))
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 4.7
		camera.position = Vector3(5.5, 7.5, 8)
		world.add_child(camera)
		camera.look_at_from_position(camera.position, Vector3(0, 0.6, 0))
		var label := Label.new()
		label.text = "水井 2×2 · %d°" % (quarter * 90)
		label.position = Vector2(18, 12)
		label.add_theme_font_size_override("font_size", 23)
		viewport.add_child(label)
	var preview := Art.create_building("well", true)
	check(preview.get_node_or_null("AssetCollision") == null, "preview has no collision")
	preview.free()

func bounds_of(node: Node3D, transform: Transform3D) -> AABB:
	var result := AABB()
	if node is MeshInstance3D:
		result = transform * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var extra := bounds_of(child, transform * child.transform)
			if extra.size.length_squared() > 0.0:
				result = extra if result.size.length_squared() == 0.0 else result.merge(extra)
	return result

func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 16:
		if DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute("res://qa/needs-economy")
			root.get_texture().get_image().save_png("res://qa/needs-economy/water-well-four-angles.png")
		for message in errors:
			push_error(message)
		print("WATER_WELL_ART_OK" if errors.is_empty() else "WATER_WELL_ART_FAILED")
		quit(0 if errors.is_empty() else 1)
	return false
