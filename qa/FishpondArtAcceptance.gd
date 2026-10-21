extends SceneTree

const Assets = preload("res://godot/RealisticAssets.gd")
const Kit = preload("res://godot/OpenClinicAssets.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366, 768)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b6c9c2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cad4c1")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.52
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -35, 0)
	sun.light_color = Color("ffe5bd")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	world.add_child(sun)
	# Match the game's terrain top at y=.15 so the mud bank blends into the ground.
	Kit.box(world, "Ground", Vector3(30, 0.10, 30), Vector3(0, 0.10, 0), Kit.material(Color("798768")))
	var pond := Assets.create_building("fishpond", false, false)
	world.add_child(pond)
	check(pond.get_meta("footprint_cells") == Vector2i(3, 2), "pond occupies 3x2")
	check(pond.get_meta("asset_source") == "composed_fishpond", "runtime registry uses new art")
	check(pond.get_meta("bank_style", "") == "rural_earth", "rural earthen pond bank")
	check(pond.get_node_or_null("MasonryBanks") == null, "no dressed-stone wall or rim caps")
	var bank := pond.get_node_or_null("EarthenBanks") as MeshInstance3D
	check(bank != null and bank.mesh is ArrayMesh, "continuous sculpted soil bank")
	if bank:
		var arrays := bank.mesh.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_VERTEX].size() >= 700, "rounded detailed bank geometry")
		check(arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size(), "wet-to-dry soil color transitions")
		check(bank.get_active_material(0).albedo_texture != null, "textured earth surface")
	check(pond.find_children("BankGrass*", "Node3D", true, false).size() >= 10, "sparse rural grass at pond edge")
	check(pond.get_node_or_null("AssetCollision") != null, "pond collision present")
	var bed := pond.get_node("PondBed") as MeshInstance3D
	var bed_top: float = bed.position.y + bed.get_aabb().end.y
	check(bed_top > 0.18 and bed_top < 0.235, "opaque bed covers world terrain/build grid and remains below fish")
	check(pond.get_node("Door").position.is_equal_approx(Vector3(2.10, 0, 2.14)), "door at pier entrance")
	for mesh in pond.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = (pond.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		check(maxf(absf(bounds.position.x), absf(bounds.end.x)) <= 3.24, "mesh x bound " + str(mesh.name))
		check(maxf(absf(bounds.position.z), absf(bounds.end.z)) <= 2.14, "mesh z bound " + str(mesh.name))
		for surface in range(mesh.mesh.get_surface_count()):
			check(mesh.get_active_material(surface) != null, "all surfaces own live material")
	var fish: Array[Node] = pond.get_node("SwimmingFish").get_children()
	check(fish.size() == 7, "seven real geometric fish")
	var activity := pond.get_node("FishpondActivity")
	activity.set_process(false)
	var original_position: Vector3 = fish[0].position
	var original_tail: float = fish[0].get_node("TailJoint").rotation.y
	var prior: Vector3 = original_position
	var minimum_speed := INF
	var maximum_speed := 0.0
	var travelled := 0.0
	for frame in range(3600):
		activity.tick(1.0 / 60.0)
		var speed: float = fish[0].position.distance_to(prior) * 60.0
		minimum_speed = minf(minimum_speed, speed)
		maximum_speed = maxf(maximum_speed, speed)
		travelled += speed / 60.0
		prior = fish[0].position
		for swimmer in fish:
			check(absf(swimmer.position.x) < 2.35 and absf(swimmer.position.z) < 1.45, "fish remain inside basin")
	check(travelled > 8.0, "fish swim continuously around closed paths")
	check(absf(fish[0].get_node("TailJoint").rotation.y - original_tail) > 0.01, "fish tails articulate")
	check(maximum_speed / minimum_speed < 1.015, "constant real-clock swim speed")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	DirAccess.make_dir_recursive_absolute("res://qa/fishpond")
	for shot in [
		{"name": "fishpond-detail.png", "size": 5.4, "offset": Vector3(7, 10, 12)},
		{"name": "fishpond-overhead.png", "size": 5.4, "offset": Vector3(7, 17, 8)},
		{"name": "fishpond-fish-detail.png", "size": 2.5, "offset": Vector3(1, 17, 4)}
	]:
		camera.size = shot.size
		camera.position = Vector3(0, 0.3, 0) + shot.offset
		camera.look_at(Vector3(0, 0.3, 0))
		await process_frame
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://qa/fishpond/" + shot.name) == OK, "save art screenshot")
	var preview := Assets.create_building("fishpond", true, false)
	world.add_child(preview)
	var preview_activity := preview.get_node("FishpondActivity")
	check(not preview_activity.is_processing(), "preview animation disabled")
	check(preview.find_children("*", "CollisionObject3D", true, false).is_empty(), "preview collision absent")
	var frozen: Transform3D = preview.get_node("SwimmingFish").get_child(0).transform
	preview_activity.tick(60.0)
	check(frozen.is_equal_approx(preview.get_node("SwimmingFish").get_child(0).transform), "preview remains frozen")
	for valid in [true, false]:
		Assets.apply_preview_tint(preview, valid)
		var expected: Color = Assets.ArtKit.PALETTE.preview_valid if valid else Assets.ArtKit.PALETTE.preview_invalid
		expected.a = 0.46
		for mesh in preview.find_children("*", "MeshInstance3D", true, false):
			check(mesh.material_override != null and mesh.material_override.albedo_color.is_equal_approx(expected), "all preview geometry uniformly tinted")
	world.queue_free()
	await process_frame
	await process_frame
	for failure in failures:
		push_error("FISHPOND_ART_FAILED: " + failure)
	print("FISHPOND_ART_OK: rural sculpted earth bank, wet/dry mud and grass, 3x2 bounds, materials, visible submerged geometry, real-clock smooth swimming/tail motion, frozen tinted collision-free previews; no save access" if failures.is_empty() else "FISHPOND_ART_FAILED")
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
