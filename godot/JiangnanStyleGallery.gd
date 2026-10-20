extends Node

const JiangnanKit = preload("res://godot/JiangnanStyleAssets.gd")
const InkWashKit = preload("res://godot/InkWashAssets.gd")

func _ready() -> void:
	create_environment()
	create_floor()
	create_water_town()
	create_overlay()

func create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b7d0ca")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e1dfcf")
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.82
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.07
	environment.adjustment_saturation = 0.88
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -38, 0)
	sun.light_color = Color("ffe2b4")
	sun.light_energy = 1.12
	sun.shadow_enabled = true
	add_child(sun)

	var camera := Camera3D.new()
	camera.name = "JiangnanDioramaCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.8
	camera.position = Vector3(11.5, 12.8, 16.4)
	add_child(camera)
	camera.look_at(Vector3(0, 0.55, 0))

func create_floor() -> void:
	add_box("GalleryGround", Vector3(22.0, 0.25, 14.0), Vector3(0, -0.14, 0), Color("849a72"))
	add_box("ContinuousCanal", Vector3(22.0, 0.05, 2.5), Vector3(0, 0.02, 0), Color("4e8d94"), 0.88)
	for side in [-1.0, 1.0]:
		add_box("StoneBank_%s" % str(side), Vector3(22.0, 0.16, 0.22), Vector3(0, 0.12, side * 1.37), Color("b8ad90"))
	for index in range(20):
		add_box("WaterRipple_%02d" % index, Vector3(0.80 + index % 3 * 0.22, 0.015, 0.045), Vector3(-9.7 + index, 0.08, -0.72 + index % 4 * 0.46), Color("b1d0c6"), 0.55)
	for bank in [-1.0, 1.0]:
		for index in range(15):
			add_box(
				"LaneStone_%s_%02d" % [str(bank), index],
				Vector3(1.22, 0.055, 0.62),
				Vector3(-9.2 + index * 1.32, 0.15, bank * (1.78 + (index % 2) * 0.04)),
				Color("a99575" if index % 3 else "97866b")
			)

func create_water_town() -> void:
	# This diorama intentionally combines the v4 buildings with bridges,
	# canal banks, boats, trees and market stalls so the new assets are judged in
	# a water-town composition rather than as isolated storefronts.
	var north_row := [
		{"type": "house", "position": Vector3(-7.6, 0, -3.15)},
		{"type": "warehouse", "position": Vector3(-3.5, 0, -3.20)},
		{"type": "workshop", "position": Vector3(0.9, 0, -3.18)},
		{"type": "tea_pavilion", "position": Vector3(5.6, 0, -3.10)},
	]
	var south_row := [
		{"type": "farm", "position": Vector3(-5.6, 0, 3.25)},
		{"type": "lumber", "position": Vector3(-0.9, 0, 3.22)},
		{"type": "market", "position": Vector3(4.2, 0, 3.15)},
	]
	for exhibit in north_row:
		add_building(str(exhibit.type), exhibit.position, 0.0)
	for exhibit in south_row:
		add_building(str(exhibit.type), exhibit.position, PI)

	var tree_positions := [
		Vector3(-9.2, 0.05, -5.35), Vector3(-4.7, 0.05, -5.45),
		Vector3(0.0, 0.05, -5.45), Vector3(4.8, 0.05, -5.45),
		Vector3(9.25, 0.05, 5.45),
	]
	for index in range(tree_positions.size()):
		var tree := InkWashKit.create_tree(index % 3)
		if tree:
			tree.name = "WatersideTree_%02d" % index
			tree.position = tree_positions[index]
			tree.scale = Vector3(0.82, 0.88, 0.82)
			add_child(tree)

	for x in [-6.1, 0.0, 6.2]:
		var bridge := InkWashKit.create_bridge()
		if bridge:
			bridge.name = "CanalBridge_%s" % str(x)
			bridge.position = Vector3(x, 0.12, 0)
			bridge.rotation.y = PI * 0.5
			bridge.scale = Vector3(0.82, 0.82, 0.82)
			add_child(bridge)

	for z in [-5.1, 5.1]:
		for x in [-6.1, -1.9, 2.2, 6.3]:
			add_box("CourtyardWall_%s_%s" % [str(z), str(x)], Vector3(2.65, 0.50, 0.15), Vector3(x, 0.32, z), Color("d0c6a8"))
	for x in [-4.0, 2.2, 7.8]:
		var lantern := InkWashKit.create_lantern()
		if lantern:
			lantern.position = Vector3(x, 0.10, -1.78)
			lantern.scale = Vector3(0.82, 0.82, 0.82)
			add_child(lantern)

	create_market_stall(Vector3(7.7, 0, 2.05), Color("b66a50"))
	create_market_stall(Vector3(8.9, 0, 3.35), Color("668678"))
	create_boat(Vector3(-3.0, 0.28, 0.15))
	for index in range(5):
		var citizen := InkWashKit.create_citizen(index)
		if citizen:
			citizen.position = Vector3(-4.8 + index * 2.0, 0.12, -1.72 if index % 2 == 0 else 1.76)
			citizen.rotation.y = PI if index % 2 == 0 else 0.0
			add_child(citizen)

func add_building(type: String, position: Vector3, rotation_y: float) -> void:
	var building := JiangnanKit.create_building(type)
	if building == null:
		return
	InkWashKit.apply_ink_style(building, type if type in ["house", "farm", "lumber", "warehouse", "workshop"] else "warehouse")
	building.name = "Diorama_%s" % type.capitalize()
	building.position = position
	building.rotation.y = rotation_y
	add_child(building)

func create_market_stall(position: Vector3, cloth: Color) -> void:
	add_box("MarketCounter", Vector3(1.05, 0.28, 0.50), position + Vector3(0, 0.42, 0), Color("855d42"))
	for side in [-1.0, 1.0]:
		add_cylinder("MarketPost", 0.035, 0.05, 1.35, position + Vector3(side * 0.43, 0.72, 0), Color("4f392c"), 6)
	add_box("MarketAwning", Vector3(1.25, 0.07, 0.74), position + Vector3(0, 1.36, 0), cloth)
	for index in range(3):
		add_box("MarketBasket_%02d" % index, Vector3(0.22, 0.18, 0.22), position + Vector3(-0.34 + index * 0.34, 0.18, 0.12), Color("b58a4f"))

func create_boat(position: Vector3) -> void:
	add_box("SampanHull", Vector3(2.0, 0.20, 0.58), position, Color("614535"))
	for side in [-1.0, 1.0]:
		add_box("SampanRim", Vector3(2.08, 0.07, 0.06), position + Vector3(0, 0.16, side * 0.28), Color("98704e"))
	add_cylinder("SampanMast", 0.025, 0.04, 1.45, position + Vector3(0.15, 0.78, 0), Color("49352b"), 6)
	add_box("SampanSail", Vector3(0.66, 0.68, 0.025), position + Vector3(-0.18, 0.92, 0), Color("d9c49d"), 0.94)

func add_box(name_value: String, size: Vector3, position: Vector3, color: Color, alpha := 1.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name_value
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = make_material(color, alpha)
	instance.position = position
	add_child(instance)
	return instance

func add_cylinder(name_value: String, top_radius: float, bottom_radius: float, height: float, position: Vector3, color: Color, sides: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.material_override = make_material(color)
	instance.position = position
	add_child(instance)
	return instance

func make_material(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = 0.90
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

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
	style.bg_color = Color(0.95, 0.90, 0.79, 0.94)
	style.border_color = Color("a8855b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var label := Label.new()
	label.text = "东境 · 江南水乡组合场景　|　河埠街巷 / 院落建筑 / 石桥乌篷 / 市井生活"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("6b4731"))
	panel.add_child(label)
