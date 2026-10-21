extends Node

const RealisticKit = preload("res://godot/RealisticAssets.gd")

var turntable_root: Node3D
var camera: Camera3D

func _ready() -> void:
	create_environment()
	create_floor()
	create_collection()
	create_overlay()

func create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("879b96")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c4d0c7")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.72
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.07
	environment.adjustment_saturation = 1.04
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "GalleryKeyLight"
	sun.rotation_degrees = Vector3(-48, -38, 0)
	sun.light_color = Color("ffe2ba")
	sun.light_energy = 0.86
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "GalleryFillLight"
	fill.rotation_degrees = Vector3(-28, 145, 0)
	fill.light_color = Color("b9d7d5")
	fill.light_energy = 0.16
	add_child(fill)

	camera = Camera3D.new()
	camera.name = "GalleryCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.0
	camera.position = Vector3(0, 22.0, 15.5)
	add_child(camera)
	camera.look_at(Vector3(0, 0.8, 0))

func create_floor() -> void:
	var floor := MeshInstance3D.new()
	floor.name = "GalleryFloor"
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(19.0, 0.24, 13.5)
	floor.mesh = floor_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("65745f")
	material.roughness = 0.94
	floor.material_override = material
	floor.position.y = -0.14
	add_child(floor)

func create_collection() -> void:
	turntable_root = Node3D.new()
	turntable_root.name = "AssetCollection"
	add_child(turntable_root)
	var exhibits: Array[Dictionary] = [
		{"key": "building.house", "pos": Vector3(-6.6, 0, -4.0), "label": "民居", "scale": 0.86},
		{"key": "building.lumber", "pos": Vector3(-3.3, 0, -4.0), "label": "伐木场", "scale": 0.86},
		{"key": "building.farm", "pos": Vector3(0.0, 0, -4.0), "label": "农田", "scale": 0.86},
		{"key": "building.warehouse", "pos": Vector3(3.3, 0, -4.0), "label": "仓库", "scale": 0.86},
		{"key": "building.workshop", "pos": Vector3(6.6, 0, -4.0), "label": "工坊", "scale": 0.86},
		{"key": "prop.tree.01", "pos": Vector3(-6.75, 0, 0.0), "label": "树木一", "scale": 0.64},
		{"key": "prop.tree.02", "pos": Vector3(-4.05, 0, 0.0), "label": "树木二", "scale": 0.64},
		{"key": "prop.tree.03", "pos": Vector3(-1.35, 0, 0.0), "label": "树木三", "scale": 0.64},
		{"key": "prop.rock.01", "pos": Vector3(1.35, 0, 0.0), "label": "山石一", "scale": 0.82},
		{"key": "prop.rock.02", "pos": Vector3(4.05, 0, 0.0), "label": "山石二", "scale": 0.82},
		{"key": "prop.rock.03", "pos": Vector3(6.75, 0, 0.0), "label": "山石三", "scale": 0.82},
		{"key": "prop.bridge", "pos": Vector3(-5.4, 0, 4.0), "label": "木桥", "scale": 0.58},
		{"key": "prop.crops", "pos": Vector3(-1.8, 0, 4.0), "label": "庄稼", "scale": 0.82},
		{"key": "prop.lantern", "pos": Vector3(1.8, 0, 4.0), "label": "灯笼", "scale": 0.86},
		{"key": "character.citizen", "pos": Vector3(5.4, 0, 4.0), "label": "居民", "scale": 0.86},
	]
	for item in exhibits:
		if not RealisticKit.has_realistic_asset(item.key):
			continue
		var asset := RealisticKit.create_asset(item.key, false, false)
		if asset == null:
			continue
		asset.position = item.pos
		var scale_value := float(item.scale)
		asset.scale = Vector3.ONE * scale_value
		turntable_root.add_child(asset)
		add_label(item.label, item.pos + Vector3(0, 0.08, 1.15))

func add_label(text: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.name = "Label_%s" % text
	label.text = text
	label.font_size = 30
	label.modulate = Color("f2e6ca")
	label.outline_size = 7
	label.outline_modulate = Color("2f3433")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = position
	turntable_root.add_child(label)

func create_overlay() -> void:
	var status := RealisticKit.get_status()
	var missing: Array = status.missing
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 18
	panel.offset_top = 16
	panel.offset_right = -18
	panel.offset_bottom = 94 if missing.is_empty() else 126
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.14, 0.94)
	style.border_color = Color("d6a74a") if missing.is_empty() else Color("d36f3e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var text := Label.new()
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 17)
	text.add_theme_color_override("font_color", Color("fff7e7"))
	if missing.is_empty():
		text.text = "高细节写实资产验收 · %d/%d 已加载 · 全部来自 realistic/models" % [status.available.size(), status.expected]
	else:
		text.text = "高细节资产 R0 已陈列 %d 件；扩展包尚缺 %d/%d 项（未放入展厅）\n%s" % [status.available.size(), missing.size(), status.expected, ", ".join(missing)]
	panel.add_child(text)

