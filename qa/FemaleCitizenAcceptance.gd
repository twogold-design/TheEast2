extends SceneTree

const Assets = preload("res://godot/RealisticAssets.gd")
const OUTPUT := "res://qa/female-citizens"
class IsolatedGame extends "res://godot/Main.gd":
	func save_game(_show_feedback := true) -> void:
		pass
	func load_game(_show_feedback := true) -> void:
		pass
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/female-citizen-audio.cfg"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FEMALE_CITIZEN_FAILED: " + message)

func material_snapshot(character: Node3D) -> Dictionary:
	var values := {}
	for mesh in character.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(surface)
			if material is StandardMaterial3D:
				values[str(mesh.name) + ":" + str(surface)] = [material.albedo_color, material.albedo_texture, material.roughness, material.normal_texture]
	return values

func run() -> void:
	root.size = Vector2i(1366, 768)
	var game := IsolatedGame.new()
	root.add_child(game)
	game.background_music.player.stop()
	game.background_music.player.stream = null
	game.set_process(false)
	game.set_physics_process(false)
	game.time_paused = true
	check(game.CITIZEN_KINDS.size() == 8, "eight runtime resident variants")
	for draw in range(8):
		game.prepare_village_life_variants()
		check(game.citizen_variant_bag.size() == 50 and game.citizen_variant_bag.count(0) == 30, "60 percent original farmers preserved")
		check(game.citizen_variant_bag.has(6) and game.citizen_variant_bag.has(7), "both female variants occur in each village bag")
		check(game.citizen_variant_bag.slice(0, 4).count(0) == 2, "initial four retain two straw-hat farmers")
	game.population = 50
	game.update_citizens(false)
	await process_frame
	await process_frame
	var identities := {}
	for citizen in game.citizen_root.get_children():
		var visual := citizen.get_node("Visual") as Node3D
		identities[citizen.get_instance_id()] = int(visual.get_meta("npc_variant", -1))
	game.update_citizens(true)
	for citizen in game.citizen_root.get_children():
		check(identities.get(citizen.get_instance_id(), -2) == citizen.get_node("Visual").get_meta("npc_variant", -1), "daily refresh preserves resident identity")
	var baseline := Assets.create_citizen_variant(0, 0, false)
	var baseline_materials := material_snapshot(baseline)
	for variant in range(8):
		var resident := game.create_citizen(200 + variant, variant)
		game.citizen_root.add_child(resident)
		var visual := resident.get_node("Visual") as Node3D
		check(int(visual.get_meta("npc_variant", -1)) == variant, "variant factory resolves %d" % variant)
		check(bool(visual.get_meta("uses_authored_walk_animation", false)), "variant keeps imported walk animation")
		for mesh in visual.find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				check(mesh.get_active_material(surface) != null, "visible character mesh material exists")
		if variant >= 6:
			check_female(visual, variant)
			var skeletons := visual.find_children("*", "Skeleton3D", true, false)
			if not skeletons.is_empty():
				var skeleton := skeletons[0] as Skeleton3D
				var leg := skeleton.find_bone("Leg.L")
				check(leg >= 0, "female retains walking leg bone")
				if leg >= 0:
					game.update_citizen_walk_animation(resident, 0.025)
					var player := visual.get_node(visual.get_meta("authored_walk_player_path")) as AnimationPlayer
					player.advance(0.03)
					var first_pose := skeleton.get_bone_pose_rotation(leg)
					var max_angle := 0.0
					for frame in range(24):
						game.update_citizen_walk_animation(resident, 0.025)
						player.advance(0.03)
						max_angle = maxf(max_angle, first_pose.angle_to(skeleton.get_bone_pose_rotation(leg)))
					check(max_angle > 0.08, "female leg skeleton actually walks")
		resident.queue_free()
	var farmer_after := Assets.create_citizen_variant(0, 0, false)
	check(material_snapshot(farmer_after) == baseline_materials, "female outfits do not mutate shared original farmer materials")
	check(farmer_after.find_child("FemaleOutfit*", true, false) == null, "farmer keeps original costume")
	baseline.free()
	farmer_after.free()
	game.queue_free()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await render_gallery()
	await create_timer(0.4, true, false, true).timeout
	if failures.is_empty():
		print("FEMALE_CITIZEN_OK: eight variants, two attached skirt/bun/collar outfits, skeletal walking, unchanged farmer material, 60 percent farmers, persistent daily identities")
		quit(0)
	else:
		quit(1)

func check_female(visual: Node3D, variant: int) -> void:
	check(str(visual.get_meta("npc_variant_name", "")) == ("白衣女居民" if variant == 6 else "紫衣女居民"), "female variant readable name")
	for part in ["FemaleSkirt", "HairBun", "FemaleCollar"]:
		var node := visual.find_child(part + "*", true, false) as Node3D
		check(node != null and node.is_visible_in_tree(), "visible female clothing part: " + part)
		if node:
			var ancestor := node.get_parent()
			while ancestor and not ancestor is BoneAttachment3D:
				ancestor = ancestor.get_parent()
			check(ancestor is BoneAttachment3D, "female clothing follows skeleton: " + part)
			if ancestor is BoneAttachment3D:
				check(ancestor.bone_idx >= 0, "female attachment binds a real bone")
	check(not visual.find_children("FemaleOutfit*", "BoneAttachment3D", true, false).is_empty(), "female has authored outfit bone attachments")

func render_gallery() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b8c5b6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e9e0c9")
	env.ambient_light_energy = 0.45
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -28, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("718065")
	material.roughness = 1
	plane.material = material
	floor_mesh.mesh = plane
	world.add_child(floor_mesh)
	for index in range(3):
		var variant: int = [0, 6, 7][index]
		var actor := Assets.create_citizen_variant(variant, variant, false)
		actor.position.x = (index - 1) * 1.5
		world.add_child(actor)
		for player in actor.find_children("*", "AnimationPlayer", true, false):
			for animation in player.get_animation_list():
				if "walk" in str(animation).to_lower():
					player.play(animation)
					player.seek(0.18 + index * 0.13, true)
					player.pause()
		var label := Label3D.new()
		label.text = str(actor.get_meta("npc_variant_name"))
		label.position = Vector3((index - 1) * 1.5, 0.06, 0.55)
		label.font_size = 44
		label.pixel_size = 0.004
		label.modulate = Color("fff0cd")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.4
	world.add_child(camera)
	camera.position = Vector3(3.8, 3.3, 8)
	camera.look_at(Vector3(0, 0.7, 0))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT + "/female-residents.png") == OK, "female gallery screenshot saved")
	world.queue_free()
	await process_frame
