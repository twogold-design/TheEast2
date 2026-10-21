extends SceneTree

const Assets = preload("res://godot/RealisticAssets.gd")
const Kit = preload("res://godot/OpenClinicAssets.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)

func run() -> void:
	var original_hashes := {}
	for key in ["building.house", "building.workshop"]:
		original_hashes[key] = FileAccess.get_sha256(Assets.expected_path(key))
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
	Kit.box(world, "Ground", Vector3(45, 0.10, 45), Vector3(0, 0.10, 0), Kit.material(Color("788766")))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	DirAccess.make_dir_recursive_absolute("res://qa/service-courts")
	for type in ["workshop", "clinic"]:
		var main := Assets.create_building(type, false, false)
		world.add_child(main)
		verify_model(main, type, false)
		check(main.get_meta("footprint_cells") == Vector2i(2, 2), type + " new courtyard occupies 2x2")
		check(main.get_node("Door").position == Vector3(0, 0, 2.14), type + " front entrance follows expanded boundary")
		var actor := main.get_node("WorkshopArtisan" if type == "workshop" else "ClinicDoctor") as Node3D
		check(actor.scale.is_equal_approx(Vector3.ONE * (0.44 if type == "workshop" else 0.40)), type + " actor retains original human scale")
		var anchor := main.get_node("ArtisanAnchor" if type == "workshop" else "DoctorAnchor") as Node3D
		check(actor.position.is_equal_approx(anchor.position), type + " actor uses authored work anchor")
		for shot in [
			{"suffix": "detail", "offset": Vector3(7, 7, 12), "size": 4.8},
			{"suffix": "overhead", "offset": Vector3(8, 17, 8), "size": 4.9}
		]:
			camera.size = shot.size
			camera.position = Vector3(0, 0.72, 0) + shot.offset
			camera.look_at(Vector3(0, 0.72, 0))
			await process_frame
			await process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png("res://qa/service-courts/" + type + "-" + shot.suffix + ".png") == OK, "save render")
		main.queue_free()
		await process_frame
		for compact in [false, true]:
			var preview := Assets.create_building(type, true, false, compact)
			world.add_child(preview)
			check(preview.find_children("*", "CollisionObject3D", true, false).is_empty(), type + " preview has no collision")
			var controller := preview.find_child("WorkshopActivity" if type == "workshop" else "ClinicActivity", true, false)
			await process_frame
			check(controller != null and not controller.is_processing(), type + " preview freezes animation")
			for valid in [true, false]:
				Assets.apply_preview_tint(preview, valid)
				var tint: Color = Assets.ArtKit.PALETTE.preview_valid if valid else Assets.ArtKit.PALETTE.preview_invalid
				tint.a = 0.46
				for mesh in preview.find_children("*", "MeshInstance3D", true, false):
					check(mesh.material_override is StandardMaterial3D and mesh.material_override.albedo_color.is_equal_approx(tint), type + " uniform preview tint")
			preview.queue_free()
			await process_frame
		var legacy := Assets.create_building(type, false, false, true)
		world.add_child(legacy)
		verify_model(legacy, type, true)
		check(legacy.get_meta("footprint_cells") == Vector2i.ONE, type + " legacy one-cell model retained")
		legacy.queue_free()
		await process_frame
	world.queue_free()
	await process_frame
	await process_frame
	for key in original_hashes:
		check(FileAccess.get_sha256(Assets.expected_path(key)) == original_hashes[key], "original GLB unchanged")
	for failure in failures:
		push_error("SERVICE_COURT_ART_FAILED: " + failure)
	print("SERVICE_COURT_ART_OK: expanded/legacy bounds, original-sized actors at anchors, clear entrance, materials, frozen collision-free tinted previews, preserved source GLBs; no save access" if failures.is_empty() else "SERVICE_COURT_ART_FAILED")
	quit(0 if failures.is_empty() else 1)

func verify_model(model: Node3D, type: String, compact: bool) -> void:
	var limit := 1.061 if compact else 2.141
	var actor := model.get_node("WorkshopArtisan" if type == "workshop" else "ClinicDoctor")
	check(model.get_node_or_null("AssetCollision") != null, type + " built collision")
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree():
			continue
		if not actor.is_ancestor_of(mesh):
			var bounds: AABB = (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
			check(maxf(absf(bounds.position.x), absf(bounds.end.x)) <= limit and maxf(absf(bounds.position.z), absf(bounds.end.z)) <= limit, type + " footprint bounds " + str(mesh.name))
		for surface in range(mesh.mesh.get_surface_count()):
			check(mesh.get_active_material(surface) != null, type + " live material")
