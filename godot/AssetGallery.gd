extends Node

const ArtKit = preload("res://godot/ArtAssets.gd")

func _ready() -> void:
	create_environment()
	create_floor()
	create_assets()
	create_overlay()

func create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a7c8c5")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c9d7ca")
	environment.ambient_light_energy = 0.26
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.60
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.94
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.08
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("ffe0ad")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	add_child(sun)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.7
	camera.position = Vector3(0, 9.5, 14.5)
	add_child(camera)
	camera.look_at(Vector3(0, 0.55, 0))

func create_floor() -> void:
	var floor := MeshInstance3D.new()
	floor.name = "GalleryFloor"
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(16.5, 0.24, 9.0)
	floor.mesh = floor_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("718866")
	material.roughness = 0.92
	floor.material_override = material
	floor.position.y = -0.14
	add_child(floor)

func create_assets() -> void:
	var building_types := ["house", "lumber", "farm", "warehouse", "workshop"]
	var labels := ["茅舍", "伐木场", "农田", "仓库", "小工坊"]
	for index in range(building_types.size()):
		var x := -6.0 + index * 3.0
		var building := ArtKit.create_building(building_types[index])
		building.position = Vector3(x, 0, 1.45)
		add_child(building)
		add_label(labels[index], Vector3(x, 0.15, 2.55))

	var tree_one := ArtKit.create_tree(0)
	tree_one.position = Vector3(-6.2, 0, -2.2)
	add_child(tree_one)
	var tree_two := ArtKit.create_tree(2)
	tree_two.position = Vector3(-4.7, 0, -2.4)
	add_child(tree_two)
	var rock := ArtKit.create_rock(2)
	rock.position = Vector3(-3.3, 0, -2.2)
	add_child(rock)
	var bridge := ArtKit.create_bridge()
	bridge.position = Vector3(-0.4, 0, -2.1)
	bridge.scale = Vector3(0.72, 0.72, 0.72)
	add_child(bridge)
	var lantern := ArtKit.create_lantern()
	lantern.position = Vector3(2.2, 0, -2.1)
	add_child(lantern)
	var crops := ArtKit.create_crops()
	crops.position = Vector3(4.1, 0, -2.0)
	add_child(crops)
	var citizen := ArtKit.create_citizen(1)
	citizen.position = Vector3(6.3, 0, -2.0)
	add_child(citizen)

func add_label(text: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.name = "Label_%s" % text
	label.text = text
	label.font_size = 30
	label.modulate = Color("2f3433")
	label.outline_size = 6
	label.outline_modulate = Color(0.95, 0.90, 0.79, 0.92)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = position
	add_child(label)

func create_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 18
	panel.offset_top = 16
	panel.offset_right = -18
	panel.offset_bottom = 70
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.90, 0.79, 0.96)
	style.border_color = Color("a8855b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var label := Label.new()
	label.text = "东境低多边形资产陈列 · 五类建筑 / 树木山石 / 桥灯作物居民"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("6b4731"))
	panel.add_child(label)
