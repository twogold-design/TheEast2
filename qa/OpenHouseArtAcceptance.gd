extends SceneTree

const Assets = preload("res://godot/RealisticAssets.gd")
const Kit = preload("res://godot/OpenClinicAssets.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> void:
	var original_hash := FileAccess.get_sha256(Assets.expected_path("building.house"))
	root.size = Vector2i(1366, 768)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a7c8c5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9d7ca")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.52
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("ffe0ad")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	world.add_child(sun)
	Kit.box(world, "Ground", Vector3(30, 0.10, 30), Vector3(0, 0.10, 0), Kit.material(Color("788766")))
	var home := Assets.create_building("house", false, false)
	world.add_child(home)
	check(home.get_meta("asset_source", "") == "composed_house", "runtime uses courtyard residence")
	check(home.get_meta("roof_identity", "") == "tile_gable_red_brackets", "red eave identity retained")
	check(home.find_child("RoofIdentity_HouseBrackets", true, false) != null, "visible red brackets")
	for feature in ["LivingCourt", "OpenDoorLeaf", "OpenWindowShutter", "OpenWaterJar", "HouseholdFirewood", "VegetableDryingTray", "BambooSideFence", "FamilyTable"]:
		check(home.find_child(feature, true, false) != null, "domestic feature: " + feature)
	check(home.get_node_or_null("AssetCollision") != null, "built hall collision")
	check(home.get_node("Door").position.z > 1.0, "entry outside front courtyard")
	var boundary := home.find_child("EnclosedBambooBoundary", true, false)
	check(boundary != null, "courtyard has a complete perimeter")
	if boundary:
		var fence_bounds: Array[AABB] = []
		for piece in boundary.find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = (home.global_transform.affine_inverse() * piece.global_transform) * piece.get_aabb()
			fence_bounds.append(bounds.grow(0.002))
			check(not bounds.intersects(AABB(Vector3(-0.27, 0.29, 0.90), Vector3(0.54, 0.60, 0.15))), "front gate remains clear of fence: " + str(piece.name))
		for sample in range(21):
			var coordinate := lerpf(-0.99, 0.95, float(sample) / 20.0)
			for point in [Vector3(-0.99, 0.36, coordinate), Vector3(0.99, 0.36, coordinate), Vector3(coordinate, 0.36, -0.99)]:
				check(_covered(point, fence_bounds), "continuous sides and rear at " + str(point))
		for side in [-1.0, 1.0]:
			for sample in range(9):
				var point := Vector3(side * lerpf(0.31, 0.99, float(sample) / 8.0), 0.36, 0.95)
				check(_covered(point, fence_bounds), "front fence closes up to gate at " + str(point))
	var textured_count := 0
	for mesh in home.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = (home.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		check(maxf(absf(bounds.position.x), absf(bounds.end.x)) <= 1.061 and maxf(absf(bounds.position.z), absf(bounds.end.z)) <= 1.061, "one-cell bounds: " + str(mesh.name))
		for surface in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(surface)
			check(material != null, "valid material: " + str(mesh.name))
			if material is StandardMaterial3D and material.albedo_texture != null:
				textured_count += 1
	check(textured_count > 100, "preserved original textured tiles and timber")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	DirAccess.make_dir_recursive_absolute("res://qa/open-house")
	for shot in [
		{"name": "residence-detail.png", "size": 3.0, "offset": Vector3(5, 5, 9)},
		{"name": "residence-overhead.png", "size": 3.0, "offset": Vector3(6, 14, 8)}
	]:
		camera.size = shot.size
		camera.position = Vector3(0, 0.95, 0) + shot.offset
		camera.look_at(Vector3(0, 0.95, 0))
		await process_frame
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://qa/open-house/" + shot.name) == OK, "save screenshot")
	var preview := Assets.create_building("house", true, false)
	world.add_child(preview)
	check(preview.find_children("*", "CollisionObject3D", true, false).is_empty(), "preview contains no collision")
	for valid in [true, false]:
		Assets.apply_preview_tint(preview, valid)
		var tint: Color = Assets.ArtKit.PALETTE.preview_valid if valid else Assets.ArtKit.PALETTE.preview_invalid
		tint.a = 0.46
		for mesh in preview.find_children("*", "MeshInstance3D", true, false):
			check(mesh.material_override is StandardMaterial3D and mesh.material_override.albedo_color.is_equal_approx(tint), "uniform preview tint")
	world.queue_free()
	await process_frame
	await process_frame
	check(FileAccess.get_sha256(Assets.expected_path("building.house")) == original_hash, "original GLB unchanged")
	for failure in failures:
		push_error("OPEN_HOUSE_ART_FAILED: " + failure)
	print("OPEN_HOUSE_ART_OK: runtime residence, enclosed bamboo perimeter with clear front gate, complete red-bracket roof, open facade/living yard, textured one-cell bounds, collision-free preview, original GLB unchanged; no save access" if failures.is_empty() else "OPEN_HOUSE_ART_FAILED")
	quit(0 if failures.is_empty() else 1)

func _covered(point: Vector3, bounds: Array[AABB]) -> bool:
	for box in bounds:
		if box.has_point(point):
			return true
	return false
