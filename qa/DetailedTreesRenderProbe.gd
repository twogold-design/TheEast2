extends SceneTree

const Kit = preload("res://godot/RealisticAssets.gd")

class IsolatedGame extends "res://godot/Main.gd":
	func _ready() -> void:
		create_world()
		create_ui()
		reset_game(false)
		update_camera_projection()
	func save_game(_show_feedback := true) -> void:
		pass
	func load_game(_show_feedback := true) -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1600, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b3bca4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e0ddc8")
	env.ambient_light_energy = 0.45
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(26, 18)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("879571")
	material.roughness = 1
	mesh.material = material
	ground.mesh = mesh
	stage.add_child(ground)
	for row in range(2):
		for species in range(3):
			var tree := Kit.create_asset("prop.tree.%02d" % (species + 1), false, false) if row == 0 else Kit.create_tree(species, false)
			tree.position = Vector3((species - 1) * 5.0, 0, (row - 0.5) * 6.5)
			stage.add_child(tree)
			var label := Label3D.new()
			label.text = ("原版 · " if row == 0 else "新版 · ") + ["阔叶", "垂柳", "山松"][species]
			label.position = tree.position + Vector3(0, 0.2, 2.0)
			label.font_size = 46
			label.pixel_size = 0.006
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			stage.add_child(label)
			if row == 1:
				print("DETAILED_TREE ", species, " lobes=", tree.get_meta("foliage_lobes"), " leaves=", tree.get_meta("solid_leaf_count"), " draw_nodes=", tree.get_child_count())
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17
	camera.position = Vector3(4, 17, 22)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.3, 0))
	camera.current = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://qa/trees")
	root.get_texture().get_image().save_png("res://qa/trees/species-comparison.png")
	stage.queue_free()
	await process_frame
	await render_in_game()
	print("DETAILED_TREES_RENDER_OK")
	quit(0)

func render_in_game() -> void:
	var game := IsolatedGame.new()
	root.add_child(game)
	game.time_paused = true
	game.set_process(false)
	game.set_physics_process(false)
	game.add_building("workshop", Vector2i(8, 11), true)
	game.add_building("house", Vector2i(10, 11), true)
	for index in range(3):
		var tree := Kit.create_tree(index, false)
		tree.position = game.grid_to_world(Vector2i(7 + index * 2, 13))
		tree.scale *= 0.78
		game.world.add_child(tree)
	game.camera.size = 13
	game.camera_target = game.grid_to_world(Vector2i(9, 12)) + Vector3(0, 0.8, 0)
	game.camera.position = game.camera_target + Vector3(11, 13, 16)
	game.camera.look_at(game.camera_target)
	game.get_node("Interface").hide()
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/trees/detailed-trees-in-game.png")
	game.queue_free()
	await process_frame
	await process_frame
