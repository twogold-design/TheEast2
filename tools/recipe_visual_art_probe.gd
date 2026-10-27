extends SceneTree

const Assets = preload("res://godot/RealisticAssets.gd")
const Expanded = preload("res://godot/ExpandedBuildingAssets.gd")
var frames := 0

func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("bfc8b0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("faf1d5")
	env.ambient_light_energy = 0.72
	environment.environment = env
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-53, -28, 0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16
	world.add_child(camera)
	camera.look_at_from_position(Vector3(9, 15, 20), Vector3.ZERO)
	var types := ["farm", "hemp_farm", "house", "house"]
	for i in range(types.size()):
		var type: String = types[i]
		var model := Assets.create_building(type)
		world.add_child(model)
		model.position = Vector3(-3.1 if i % 2 == 0 else 3.1, 0, -2.6 if i < 2 else 2.6)
		if type == "hemp_farm":
			assert(model.get_meta("building_type") == "hemp_farm")
			assert(model.get_meta("footprint_cells") == Vector2i(2, 2))
			assert(model.get_node("Door").position == Vector3(0, 0, 2.11))
			assert(model.has_node("AssetCollision"))
			assert(model.get_node("RecipeHemp").visible)
			assert(model.get_node("RecipeHemp").get_meta("plant_count") == 48)
			for child in model.get_children():
				if child is MeshInstance3D and str(child.name).begins_with("FieldGrain"):
					assert(not child.visible)
			for batch in model.get_node("RecipeHemp").get_children():
				var bounds: AABB = batch.multimesh.get_aabb()
				assert(bounds.position.x > -2.2 and bounds.end.x < 2.2 and bounds.position.z > -2.2 and bounds.end.z < 2.2)
			var preview := Assets.create_building(type, true)
			assert(not preview.has_node("AssetCollision"))
			Assets.apply_preview_tint(preview, false)
			for batch in preview.get_node("RecipeHemp").get_children():
				assert(batch.material_override != null)
				assert(batch.material_override.albedo_color.r > batch.material_override.albedo_color.g)
			for batch in model.get_node("RecipeHemp").get_children():
				assert(batch.material_override == null, "Preview polluted placed crop")
			preview.free()
		if type == "house":
			Expanded.apply_house_visual(model, "artisan" if i == 3 else "farmer")
			if i == 3:
				var count := model.find_children("*", "", true, false).size()
				Expanded.apply_house_visual(model, "artisan")
				assert(count == model.find_children("*", "", true, false).size())
				assert(model.find_child("CraftHouseSign", true, false) != null)
				assert(model.find_child("JoineryBench", true, false) == null)
				assert(model.find_child("CarvedWoodenUtensil", true, false) == null)
		var label := Label3D.new()
		label.text = type if i < 2 else ("farmer home" if i == 2 else "artisan home: profession sign")
		label.position = model.position + Vector3(0, 0.2, 2.3)
		label.font_size = 44
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
	print("CROP_AND_HOME_ART_OK: independent grain/hemp, 48 hemp plants, metadata/collision, preview colors isolated, artisan sign without home production")

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 12:
		if DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png("res://.godot-user/Logs/recipe_visuals.png")
		quit()
	return false

