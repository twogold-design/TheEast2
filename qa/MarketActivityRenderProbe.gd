extends SceneTree

const ArtKit = preload("res://godot/RealisticAssets.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440, 920)
	root.content_scale_size = root.size
	var layout := GridContainer.new()
	layout.columns = 2
	layout.add_theme_constant_override("h_separation", 0)
	layout.add_theme_constant_override("v_separation", 0)
	root.add_child(layout)
	for seconds in [0.0, 2.2, 7.8, 9.2]:
		var container := SubViewportContainer.new()
		container.custom_minimum_size = Vector2(720, 460)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(720, 460)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		layout.add_child(container)
		build_stage(viewport, seconds)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://qa/market")
	var error := root.get_texture().get_image().save_png("res://qa/market/market-activity-phases.png")
	layout.queue_free()
	await process_frame
	await process_frame
	print("MARKET_ACTIVITY_RENDER_OK" if error == OK else "MARKET_ACTIVITY_RENDER_FAILED")
	quit(0 if error == OK else 1)

func build_stage(viewport: SubViewport, seconds: float) -> void:
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("829373")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d6d8c1")
	environment.ambient_light_energy = 0.55
	environment_node.environment = environment
	stage.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	stage.add_child(sun)
	var market := ArtKit.create_building("market", false, false)
	stage.add_child(market)
	for actor in market.get_children():
		var activity := actor.get_node_or_null("MarketActivity")
		if activity:
			activity.set_process(false)
			activity.sample(seconds)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.5
	camera.position = Vector3(-6.5, 8, 10)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.55, 0))
	var label := Label.new()
	label.text = "集市人物动作 · %.1f 秒" % seconds
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 20)
	viewport.add_child(label)
