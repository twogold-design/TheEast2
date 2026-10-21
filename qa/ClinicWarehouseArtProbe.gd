extends SceneTree

const Assets = preload("res://godot/RealisticAssets.gd")
const Clinic = preload("res://godot/OpenClinicAssets.gd")
const Output := "res://qa/clinic-warehouse"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var source_hashes := {}
	for key in ["building.house", "building.warehouse"]:
		var path := Assets.expected_path(key)
		source_hashes[path] = FileAccess.get_sha256(path)
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
	Clinic.box(world, "Ground", Vector3(50, 0.10, 50), Vector3(0, -0.055, 0), Clinic.material(Color("788766")))
	var clinic := Assets.create_building("clinic", false, false)
	var warehouse := Assets.create_building("warehouse", false, false)
	world.add_child(clinic)
	world.add_child(warehouse)
	clinic.position = Vector3(-2.45, 0, 0.30)
	warehouse.position = Vector3(2.20, 0, -0.15)
	verify_art(clinic, 4.4)
	verify_art(warehouse, 4.4)
	var doctor := clinic.get_node_or_null("ClinicDoctor") as Node3D
	if doctor == null or int(doctor.get_meta("npc_variant", -1)) != 2:
		failures.append("运行时郎中应使用书生模型而非舟夫")
	if clinic.get_meta("asset_source", "") != "composed_clinic" or warehouse.get_meta("asset_source", "") != "composed_warehouse":
		failures.append("真实建筑入口未接入新美术资源")
	for building in [clinic, warehouse]:
		if building.get_node_or_null("AssetCollision") == null:
			failures.append("普通建筑缺少后堂碰撞")
	if warehouse.find_children("RoofIdentity_WarehouseVent*", "MeshInstance3D", true, false).size() < 4:
		failures.append("仓库缺少双通风帽")
	if clinic.find_children("MedicineDrawer_*", "MeshInstance3D", true, false).size() != 30:
		failures.append("医馆药柜抽屉缺失")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	DirAccess.make_dir_recursive_absolute(Output)
	for shot in [
		{"name": "clinic-warehouse-overview.png", "target": Vector3(-0.10, 0.5, 0), "size": 8.4, "offset": Vector3(8, 10, 13)},
		{"name": "clinic-detail.png", "target": Vector3(-2.45, 0.83, 0.30), "size": 4.9, "offset": Vector3(4, 4.8, 9)},
		{"name": "warehouse-detail.png", "target": Vector3(2.20, 0.70, -0.15), "size": 4.6, "offset": Vector3(7, 8, 12)},
		{"name": "clinic-warehouse-overhead.png", "target": Vector3(-0.10, 0.5, 0), "size": 8.4, "offset": Vector3(8, 17, 8)}
	]:
		camera.size = shot.size
		camera.position = shot.target + shot.offset
		camera.look_at(shot.target)
		await process_frame
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var error := root.get_texture().get_image().save_png(Output + "/" + shot.name)
			if error != OK:
				failures.append("截图保存失败")
	# Exercise the actual placement-preview factory, including external doctor.
	for type in ["clinic", "warehouse"]:
		var preview := Assets.create_building(type, true, false)
		world.add_child(preview)
		await process_frame
		if not preview.find_children("*", "CollisionObject3D", true, false).is_empty() or not preview.find_children("*", "CollisionShape3D", true, false).is_empty():
			failures.append("预览不应包含碰撞：" + type)
		var activity := preview.find_child("ClinicActivity", true, false)
		var skeleton: Skeleton3D
		var skeletons := preview.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			skeleton = skeletons[0]
		var poses: Array[Transform3D] = []
		if skeleton:
			for bone in range(skeleton.get_bone_count()):
				poses.append(skeleton.get_bone_pose(bone))
		if type == "clinic":
			if activity == null or activity.is_processing() or not activity.preview:
				failures.append("医馆预览人物未停用动画")
			elif skeleton:
				activity.tick(10.0)
		for valid in [true, false, true]:
			Assets.apply_preview_tint(preview, valid)
			var expected := Color(0.40, 0.90, 0.65, 0.55) if valid else Color(0.95, 0.35, 0.30, 0.55)
			for label in preview.find_children("*", "Label3D", true, false):
				if not label.modulate.is_equal_approx(expected):
					failures.append("招牌文字未跟随预览染色：" + type)
			await process_frame
		if skeleton:
			for bone in range(skeleton.get_bone_count()):
				if not skeleton.get_bone_pose(bone).is_equal_approx(poses[bone]):
					failures.append("医馆预览郎中骨骼仍在运动")
		preview.queue_free()
		await process_frame
	world.queue_free()
	await process_frame
	await process_frame
	for path in source_hashes:
		if FileAccess.get_sha256(path) != source_hashes[path]:
			failures.append("原版GLB内容被改变：" + path)
	for failure in failures:
		push_error("CLINIC_WAREHOUSE_ART_FAILED: " + failure)
	print("CLINIC_WAREHOUSE_ART_OK: runtime factory, scholar doctor, footprint/materials, collision-free previews, frozen preview bones, label tint, unchanged GLB; no save access" if failures.is_empty() else "CLINIC_WAREHOUSE_ART_FAILED")
	quit(0 if failures.is_empty() else 1)

func verify_art(asset: Node3D, width: float) -> void:
	var doctor := asset.get_node_or_null("ClinicDoctor")
	for mesh in asset.find_children("*", "MeshInstance3D", true, false):
		var local_transform: Transform3D = asset.global_transform.affine_inverse() * mesh.global_transform
		var bounds: AABB = local_transform * mesh.get_aabb()
		if maxf(absf(bounds.position.x), absf(bounds.end.x)) > width * 0.5 + 0.01 or maxf(absf(bounds.position.z), absf(bounds.end.z)) > width * 0.5 + 0.01:
			failures.append("占地越界 %s/%s %s" % [asset.name, mesh.name, bounds])
		var is_doctor: bool = doctor != null and doctor.is_ancestor_of(mesh)
		if mesh.material_override != null and not is_doctor:
			failures.append("不应使用实例材质覆盖 %s" % mesh.name)
		for surface in range(mesh.mesh.get_surface_count()):
			if mesh.get_active_material(surface) == null:
				failures.append("网格材质缺失 %s" % mesh.name)
