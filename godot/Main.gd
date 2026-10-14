extends Node

const RealisticKit = preload("res://godot/RealisticAssets.gd")

const GRID_SIZE := 48
const TILE_SIZE := 2.0
const EDITOR_SAVE_PATH := "res://saves/savegame.json"
const SAVE_VERSION := 2
const VICTORY_POPULATION := 45
const VICTORY_WOOD := 200
const VICTORY_FOOD := 200
const VICTORY_HAPPINESS := 80
const AUTO_DAY_SECONDS := 8.0
const TIME_SPEEDS := [1.0, 2.0, 4.0]

const REGION_DEFINITIONS := [
	{"id": "river_core", "name": "河湾故地", "short_name": "故地", "area": 400, "summary": "开局营地与基础生产"},
	{"id": "north_terrace", "name": "北坡梯田", "short_name": "北坡", "area": 200, "summary": "河岸耕地与粮食扩张"},
	{"id": "east_woodland", "name": "东麓林场", "short_name": "东麓", "area": 200, "summary": "林业用地与仓储扩张"},
	{"id": "highland", "name": "云岫高台", "short_name": "高台", "area": 100, "summary": "工坊高地与聚落中心"},
	{"id": "east_plain", "name": "沧波东原", "short_name": "东原", "area": 432, "summary": "大型居住、粮食与仓储区"},
	{"id": "north_pass", "name": "朔岭关田", "short_name": "北关", "area": 540, "summary": "林业、山脚工坊与后期资源区"},
	{"id": "sky_capital", "name": "天际新都", "short_name": "新都", "area": 432, "summary": "最终新城与发展成果展示区"}
]

const REGION_UNLOCK_COSTS := [
	{"wood": 0, "food": 0},
	{"wood": 50, "food": 15},
	{"wood": 90, "food": 30},
	{"wood": 140, "food": 50},
	{"wood": 180, "food": 70},
	{"wood": 240, "food": 100},
	{"wood": 320, "food": 140}
]

const REGION_UNLOCK_REWARDS := [
	{"wood": 0, "food": 0, "happiness": 0},
	{"wood": 0, "food": 20, "happiness": 0},
	{"wood": 40, "food": 0, "happiness": 0},
	{"wood": 0, "food": 0, "happiness": 5},
	{"wood": 0, "food": 50, "happiness": 0},
	{"wood": 80, "food": 0, "happiness": 0},
	{"wood": 0, "food": 80, "happiness": 5}
]

const REGION_UNLOCK_FEEDBACK := [
	"",
	"北坡梯田已开放：新的河岸耕地可供规划。",
	"东麓林场已开放：林间空地与新伐木带可用。",
	"云岫高台已开放：高台新城与工坊区可用。",
	"沧波东原已开放：大片平原可建设住宅、粮田和仓储。",
	"朔岭关田已开放：山林资源与后期工坊区可用。",
	"天际新都已开放：七境相连，最终复兴目标已开启。"
]

const CAMPAIGN_STAGE_NAMES := [
	"安家河湾", "木通东麓", "百工登台", "东原成镇", "北关兴业", "新都落成", "东境复兴"
]

const CAMPAIGN_CHAPTERS := ["第一章", "第二章", "第三章", "第四章", "第五章", "第六章", "第七章"]

const BUILDINGS := {
	"house": {
		"name": "茅舍", "cost": 10, "wood": 0, "food": 0, "housing": 4,
		"happiness": 0, "description": "人口容量 +4，维护粮食 1/日", "color": Color("c98963")
	},
	"lumber": {
		"name": "伐木场", "cost": 20, "wood": 5, "food": 0, "housing": 0,
		"happiness": 0, "description": "每日木材 +5，需靠近东侧林地", "color": Color("8a5c3b")
	},
	"farm": {
		"name": "农田", "cost": 15, "wood": 0, "food": 8, "housing": 0,
		"happiness": 1, "description": "每日粮食 +8，需靠近河岸", "color": Color("b9956e")
	},
	"warehouse": {
		"name": "仓库", "cost": 30, "wood": 0, "food": 0, "housing": 0,
		"happiness": 0, "description": "粮食与木材容量各 +50", "color": Color("7f6b52")
	},
	"workshop": {
		"name": "小工坊", "cost": 35, "wood": 2, "food": 0, "housing": 0,
		"happiness": 2, "description": "每日木材 +2，幸福度 +2，需 8 人", "color": Color("5e7173")
	}
}

var day := 1
var wood := 100
var food := 40
var population := 4
var happiness := 60
var low_happiness_days := 0
var map_region_level := 0
var selected_type := ""
var ended := ""
var next_id := 1
var buildings: Array[Dictionary] = []
var occupied := {}

var world: Node3D
var building_root: Node3D
var citizen_root: Node3D
var region_visual_root: Node3D
var camera: Camera3D
var ghost: Node3D
var locked_hover: Node3D
var hover_cell := Vector2i(-1, -1)
var status_label: Label
var goal_label: Label
var message_label: Label
var inspector: PanelContainer
var inspector_title: Label
var inspector_body: Label
var build_buttons := {}
var region_panel: PanelContainer
var region_title: Label
var region_body: Label
var region_unlock_button: Button
var region_panel_toggle: Button
var region_panel_collapsed := false
var bottom_panel: PanelContainer
var bottom_actions: HBoxContainer
var pause_button: Button
var speed_buttons := {}
var settings_button: Button
var settings_overlay: Control
var settings_panel: PanelContainer
var settings_action_buttons := {}
var confirmation_dialog: ConfirmationDialog
var pending_confirm_action := ""
var selected_building_id := -1
var end_layer: CanvasLayer
var drag_button := -1
var drag_origin := Vector2.ZERO
var drag_last := Vector2.ZERO
var drag_moved := false
var camera_target := Vector3.ZERO
var citizen_time := 0.0
var auto_day_elapsed := 0.0
var time_paused := false
var time_speed := 1.0
var day_settling := false

func _ready() -> void:
	create_world()
	create_ui()
	reset_game(false)
	if FileAccess.file_exists(save_path()):
		load_game(false)
	get_viewport().size_changed.connect(update_camera_projection)
	update_camera_projection()

func create_world() -> void:
	world = Node3D.new()
	world.name = "RiverValley"
	add_child(world)
	building_root = Node3D.new()
	building_root.name = "Buildings"
	world.add_child(building_root)
	citizen_root = Node3D.new()
	citizen_root.name = "Citizens"
	world.add_child(citizen_root)
	region_visual_root = Node3D.new()
	region_visual_root.name = "RegionVisuals"
	world.add_child(region_visual_root)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a7c8c5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9d7ca")
	env.ambient_light_energy = 0.28
	env.fog_enabled = true
	env.fog_light_color = Color("a7c8c5")
	env.fog_density = 0.004
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.52
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.84
	env.adjustment_contrast = 1.10
	env.adjustment_saturation = 1.08
	environment.environment = env
	world.add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("ffe0ad")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	world.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 140, 0)
	fill.light_color = Color("bfe0df")
	fill.light_energy = 0.08
	world.add_child(fill)

	camera = Camera3D.new()
	camera.name = "PlanningCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 36.0
	camera_target = grid_to_world(Vector2i(10, 13))
	camera.position = camera_target + Vector3(30, 34, 31)
	world.add_child(camera)
	camera.look_at(camera_target)

	create_terrain()
	create_grid_lines()
	create_scenery()
	create_region_visuals()

func create_terrain() -> void:
	var base := mesh_box(Vector3(GRID_SIZE * TILE_SIZE + 2.0, 0.6, GRID_SIZE * TILE_SIZE + 2.0), Color("405345"))
	base.position.y = -0.38
	world.add_child(base)
	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var is_river := is_water_cell(Vector2i(x, z))
			var region := region_level_for_cell(Vector2i(x, z))
			var color := Color("3f7d8b") if is_river else terrain_color_for_cell(Vector2i(x, z), region)
			var tile := mesh_box(Vector3(TILE_SIZE - 0.06, 0.12, TILE_SIZE - 0.06), color, 0.88 if is_river else 1.0)
			tile.position = grid_to_world(Vector2i(x, z)) + Vector3(0, 0.03 if is_river else 0.09, 0)
			tile.set_meta("grid", Vector2i(x, z))
			world.add_child(tile)

func create_grid_lines() -> void:
	var immediate := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.34, 0.47, 0.36, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var extent := GRID_SIZE * TILE_SIZE * 0.5
	for i in range(GRID_SIZE + 1):
		var p := -extent + i * TILE_SIZE
		immediate.surface_add_vertex(Vector3(p, 0.18, -extent))
		immediate.surface_add_vertex(Vector3(p, 0.18, extent))
		immediate.surface_add_vertex(Vector3(-extent, 0.18, p))
		immediate.surface_add_vertex(Vector3(extent, 0.18, p))
	immediate.surface_end()
	var lines := MeshInstance3D.new()
	lines.mesh = immediate
	world.add_child(lines)

func terrain_color_for_cell(cell: Vector2i, region: int) -> Color:
	if region == 1:
		return Color("6d815e") if (cell.x + cell.y) % 3 else Color("758b64")
	if region == 2:
		return Color("506d52") if (cell.x + cell.y) % 3 else Color("5d7958")
	if region == 3:
		return Color("6b755d") if (cell.x + cell.y) % 3 else Color("778163")
	if region == 4:
		return Color("72835d") if (cell.x + cell.y) % 4 else Color("809269")
	if region == 5:
		return Color("596b55") if (cell.x + cell.y) % 3 else Color("687860")
	if region == 6:
		return Color("707b64") if (cell.x + cell.y) % 4 else Color("7f8970")
	return Color("607b59") if (cell.x + cell.y) % 3 == 0 else Color("587151")

func region_level_for_cell(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= GRID_SIZE or cell.y < 0 or cell.y >= GRID_SIZE:
		return -1
	if cell.x >= 30:
		return 4 if cell.y < 24 else 6
	if cell.y >= 30:
		return 5
	if cell.x < 20 and cell.y < 20:
		return 0
	if cell.x < 20 and cell.y >= 20:
		return 1
	if cell.x >= 20 and cell.y < 20:
		return 2
	return 3

func region_name_for_cell(cell: Vector2i) -> String:
	var level := region_level_for_cell(cell)
	return "地图外" if level < 0 else str(REGION_DEFINITIONS[level].name)

func region_center(level: int) -> Vector2i:
	match level:
		0: return Vector2i(10, 10)
		1: return Vector2i(10, 25)
		2: return Vector2i(25, 10)
		3: return Vector2i(25, 25)
		4: return Vector2i(39, 12)
		5: return Vector2i(15, 39)
		6: return Vector2i(39, 36)
	return Vector2i.ZERO

func create_region_visuals() -> void:
	if region_visual_root == null:
		return
	update_region_visuals()

func update_region_visuals() -> void:
	if region_visual_root == null:
		return
	for child in region_visual_root.get_children():
		child.queue_free()
	for level in range(1, REGION_DEFINITIONS.size()):
		if level <= map_region_level:
			continue
		var region_fog := Node3D.new()
		region_fog.name = "LockedRegion_%d" % level
		region_visual_root.add_child(region_fog)
		var locked_cells: Array[Vector2i] = []
		for z in range(GRID_SIZE):
			for x in range(GRID_SIZE):
				var cell := Vector2i(x, z)
				if region_level_for_cell(cell) != level:
					continue
				locked_cells.append(cell)
		var veil_mesh := BoxMesh.new()
		veil_mesh.size = Vector3(TILE_SIZE - 0.10, 0.025, TILE_SIZE - 0.10)
		veil_mesh.material = make_material(Color(0.18, 0.23, 0.22, 0.28), 0.28)
		var veil_multimesh := MultiMesh.new()
		veil_multimesh.transform_format = MultiMesh.TRANSFORM_3D
		veil_multimesh.mesh = veil_mesh
		veil_multimesh.instance_count = locked_cells.size()
		for index in range(locked_cells.size()):
			veil_multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, grid_to_world(locked_cells[index]) + Vector3(0, 0.20, 0)))
		var veil_instances := MultiMeshInstance3D.new()
		veil_instances.name = "FogTiles"
		veil_instances.multimesh = veil_multimesh
		region_fog.add_child(veil_instances)
		var sign := Label3D.new()
		sign.text = "锁定 · %s\n%s" % [REGION_DEFINITIONS[level].name, REGION_DEFINITIONS[level].summary]
		sign.position = grid_to_world(region_center(level)) + Vector3(0, 2.5, 0)
		sign.font_size = 48
		sign.pixel_size = 0.012
		sign.outline_size = 10
		sign.modulate = Color("f1c86a") if level == map_region_level + 1 else Color("a9aaa2")
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		region_fog.add_child(sign)

func create_scenery() -> void:
	var road_color := Color("8d6a4f")
	for z in range(4, 16):
		var road := mesh_box(Vector3(1.1, 0.06, 1.84), road_color)
		road.position = grid_to_world(Vector2i(10, z)) + Vector3(0, 0.19, 0)
		world.add_child(road)
	var bridge := RealisticKit.create_bridge()
	bridge.name = "RiverBridge"
	bridge.position = Vector3(grid_to_world(Vector2i(2, 9)).x + TILE_SIZE * 0.5, 0.34, grid_to_world(Vector2i(2, 9)).z)
	world.add_child(bridge)
	var tree_cells := [
		Vector2i(16, 2), Vector2i(18, 1), Vector2i(17, 4), Vector2i(19, 5),
		Vector2i(16, 7), Vector2i(18, 8), Vector2i(17, 10), Vector2i(19, 11),
		Vector2i(16, 13), Vector2i(18, 14), Vector2i(17, 17), Vector2i(19, 18),
		Vector2i(27, 2), Vector2i(29, 4), Vector2i(28, 7), Vector2i(27, 11), Vector2i(29, 15), Vector2i(28, 18),
		Vector2i(4, 23), Vector2i(16, 26), Vector2i(3, 28), Vector2i(21, 24), Vector2i(26, 28),
		Vector2i(6, 33), Vector2i(13, 37), Vector2i(24, 34), Vector2i(28, 42), Vector2i(3, 46),
		Vector2i(45, 3), Vector2i(46, 8), Vector2i(44, 15), Vector2i(47, 22),
		Vector2i(33, 29), Vector2i(45, 32), Vector2i(34, 41), Vector2i(43, 46)
	]
	for index in range(tree_cells.size()):
		var cell: Vector2i = tree_cells[index]
		var offset := Vector3(((index * 37) % 9 - 4) * 0.09, 0, ((index * 23) % 7 - 3) * 0.10)
		create_tree(grid_to_world(cell) + offset, index)
	for index in range(7):
		var rock := RealisticKit.create_rock(index)
		rock.position = grid_to_world(Vector2i(0 if index % 2 == 0 else 19, 2 + index * 2)) + Vector3(0, 0.16, 0)
		rock.rotation.y = index * 0.73
		world.add_child(rock)
	for z in [5, 8, 11, 14]:
		var lantern := RealisticKit.create_lantern()
		lantern.position = grid_to_world(Vector2i(10, z)) + Vector3(0.72, 0.2, 0)
		lantern.rotation.y = PI if z % 2 == 0 else 0.0
		world.add_child(lantern)
	for i in range(18):
		var hill_height := 4.0 + (i % 2) * 1.0
		var hill := mesh_cylinder(0.15, 1.65 + (i % 3) * 0.35, hill_height, Color("536b5c"), 6)
		hill.name = "BoundaryHill_%02d" % i
		hill.position = Vector3(-44.0 + i * 5.2, hill_height * 0.5 + 0.10, -45.0 + (i % 2) * 2.0)
		hill.scale.z = 0.75
		world.add_child(hill)

func create_tree(pos: Vector3, variant := 0) -> void:
	var tree := RealisticKit.create_tree(variant)
	tree.position = pos
	tree.rotation.y = variant * 0.61
	world.add_child(tree)

func create_citizen(index: int) -> Node3D:
	var citizen := RealisticKit.create_citizen(index)
	var base_cell := Vector2i(7 + index % 7, 6 + floori(index / 7.0) % 8)
	var base := grid_to_world(base_cell) + Vector3(0, 0.18, 0)
	citizen.position = base
	citizen.set_meta("base_position", base)
	citizen.set_meta("phase", float(index) * 1.71)
	return citizen

func update_citizens() -> void:
	for child in citizen_root.get_children():
		child.queue_free()
	for index in range(mini(population, 50)):
		citizen_root.add_child(create_citizen(index))

func _process(delta: float) -> void:
	citizen_time += delta
	var index := 0
	for child in citizen_root.get_children():
		if child is Node3D and not child.is_queued_for_deletion():
			var base: Vector3 = child.get_meta("base_position")
			var phase: float = child.get_meta("phase")
			child.position = base + Vector3(sin(citizen_time * 0.45 + phase) * 0.42, absf(sin(citizen_time * 2.0 + phase)) * 0.035, cos(citizen_time * 0.38 + phase) * 0.42)
			index += 1
	update_auto_time(delta)

func update_auto_time(delta: float) -> void:
	if ended != "" or time_paused or day_settling:
		update_time_controls()
		return
	auto_day_elapsed += maxf(delta, 0.0) * time_speed
	if auto_day_elapsed >= AUTO_DAY_SECONDS:
		auto_day_elapsed = 0.0
		next_day()
	update_time_controls()

func toggle_time_paused() -> void:
	if ended != "":
		return
	time_paused = not time_paused
	show_message("时间已暂停，可安心规划" if time_paused else "时间继续以 %d× 自动流逝" % int(time_speed))
	update_ui()

func set_time_speed(speed: float) -> void:
	if speed not in TIME_SPEEDS:
		return
	time_speed = speed
	show_message("时间速度已调整为 %d×" % int(time_speed))
	update_ui()

func update_time_controls() -> void:
	if pause_button:
		var remaining := maxf(0.0, (AUTO_DAY_SECONDS - auto_day_elapsed) / time_speed)
		pause_button.text = "继续 ▶" if time_paused else "暂停 Ⅱ\n%.1f秒" % remaining
		pause_button.button_pressed = time_paused
		pause_button.disabled = ended != ""
	for speed in speed_buttons:
		var button: Button = speed_buttons[speed]
		button.button_pressed = is_equal_approx(float(speed), time_speed)
		button.disabled = ended != ""

func time_status_text() -> String:
	return "Ⅱ 暂停" if time_paused else "▶ %d×" % int(time_speed)

func create_building_model(type: String, preview := false) -> Node3D:
	return RealisticKit.create_building(type, preview)

func mesh_box(size: Vector3, color: Color, alpha := 1.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = make_material(color, alpha)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance

func mesh_cylinder(top_radius: float, bottom_radius: float, height: float, color: Color, sides: int, alpha := 1.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = top_radius
	shape.bottom_radius = bottom_radius
	shape.height = height
	shape.radial_segments = sides
	instance.mesh = shape
	instance.material_override = make_material(color, alpha)
	return instance

func make_material(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = 0.86
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func create_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	add_child(layer)

	var top_panel := PanelContainer.new()
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 14
	top_panel.offset_top = 14
	top_panel.offset_right = -14
	top_panel.offset_bottom = 74
	top_panel.add_theme_stylebox_override("panel", panel_style(Color(0.95, 0.90, 0.79, 0.96)))
	layer.add_child(top_panel)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 20)
	top_panel.add_child(top_row)
	var title := Label.new()
	title.text = "  东境 · 孤城新生"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color("6b4731"))
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_row.add_child(title)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("2f3433"))
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(status_label)
	goal_label = Label.new()
	goal_label.add_theme_color_override("font_color", Color("2f3433"))
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goal_label.custom_minimum_size.x = 350
	top_row.add_child(goal_label)
	settings_button = make_compact_button("设置", toggle_settings_menu, Vector2(72, 40))
	settings_button.toggle_mode = true
	settings_button.tooltip_text = "存档与游戏操作"
	top_row.add_child(settings_button)

	bottom_panel = PanelContainer.new()
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_panel.offset_left = -430
	bottom_panel.offset_right = 430
	bottom_panel.offset_top = -102
	bottom_panel.offset_bottom = -14
	bottom_panel.add_theme_stylebox_override("panel", panel_style(Color(0.95, 0.90, 0.79, 0.96)))
	layer.add_child(bottom_panel)
	bottom_actions = HBoxContainer.new()
	bottom_actions.add_theme_constant_override("separation", 8)
	bottom_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_panel.add_child(bottom_actions)
	for type in BUILDINGS.keys():
		var definition: Dictionary = BUILDINGS[type]
		var button := Button.new()
		button.text = "%s\n木材 %d" % [definition.name, definition.cost]
		button.custom_minimum_size = Vector2(112, 62)
		button.tooltip_text = definition.description
		button.toggle_mode = true
		apply_button_theme(button, Color("f5e8cb"))
		button.pressed.connect(select_building.bind(type))
		bottom_actions.add_child(button)
		build_buttons[type] = button
	var time_controls := HBoxContainer.new()
	time_controls.add_theme_constant_override("separation", 4)
	bottom_actions.add_child(time_controls)
	pause_button = make_compact_button("暂停 Ⅱ", toggle_time_paused, Vector2(70, 50), Color("d6a74a"))
	pause_button.toggle_mode = true
	pause_button.tooltip_text = "暂停或继续自动时间"
	time_controls.add_child(pause_button)
	for speed in TIME_SPEEDS:
		var speed_button := make_compact_button("%d×" % int(speed), set_time_speed.bind(speed), Vector2(44, 50))
		speed_button.toggle_mode = true
		speed_button.tooltip_text = "自动时间 %d 倍速" % int(speed)
		time_controls.add_child(speed_button)
		speed_buttons[speed] = speed_button
	inspector = PanelContainer.new()
	inspector.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	inspector.offset_left = -674
	inspector.offset_right = -412
	inspector.offset_top = 88
	inspector.offset_bottom = 298
	inspector.z_index = 5
	inspector.add_theme_stylebox_override("panel", panel_style(Color(0.95, 0.90, 0.79, 0.96)))
	inspector.visible = false
	layer.add_child(inspector)
	var inspect_box := VBoxContainer.new()
	inspect_box.add_theme_constant_override("separation", 9)
	inspector.add_child(inspect_box)
	inspector_title = Label.new()
	inspector_title.add_theme_font_size_override("font_size", 20)
	inspector_title.add_theme_color_override("font_color", Color("6b4731"))
	inspect_box.add_child(inspector_title)
	inspector_body = Label.new()
	inspector_body.add_theme_color_override("font_color", Color("2f3433"))
	inspector_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspect_box.add_child(inspector_body)
	inspect_box.add_child(make_action_button("删除建筑（返还一半木材）", demolish_selected, Color("f0d1b8")))

	region_panel = PanelContainer.new()
	region_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	region_panel.offset_left = -398
	region_panel.offset_right = -14
	region_panel.offset_top = 88
	region_panel.offset_bottom = 552
	region_panel.add_theme_stylebox_override("panel", panel_style(Color(0.95, 0.90, 0.79, 0.96)))
	layer.add_child(region_panel)
	var region_box := VBoxContainer.new()
	region_box.add_theme_constant_override("separation", 5)
	region_panel.add_child(region_box)
	var region_header := HBoxContainer.new()
	region_header.add_theme_constant_override("separation", 6)
	region_box.add_child(region_header)
	region_title = Label.new()
	region_title.add_theme_font_size_override("font_size", 20)
	region_title.add_theme_color_override("font_color", Color("6b4731"))
	region_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region_title.clip_text = true
	region_header.add_child(region_title)
	region_panel_toggle = make_compact_button(">", toggle_region_panel, Vector2(38, 34))
	region_panel_toggle.tooltip_text = "收起目标栏"
	region_header.add_child(region_panel_toggle)
	region_body = Label.new()
	region_body.add_theme_font_size_override("font_size", 15)
	region_body.add_theme_color_override("font_color", Color("2f3433"))
	region_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	region_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	region_box.add_child(region_body)
	region_unlock_button = make_action_button("条件尚未满足", unlock_next_region, Color("d6a74a"))
	region_unlock_button.custom_minimum_size = Vector2(0, 42)
	region_box.add_child(region_unlock_button)

	var message_panel := PanelContainer.new()
	message_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	message_panel.offset_left = -390
	message_panel.offset_right = -14
	message_panel.offset_top = -184
	message_panel.offset_bottom = -116
	message_panel.add_theme_stylebox_override("panel", panel_style(Color(0.14, 0.18, 0.17, 0.90)))
	layer.add_child(message_panel)
	message_label = Label.new()
	message_label.text = "欢迎来到河谷"
	message_label.add_theme_color_override("font_color", Color("fff7e7"))
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_panel.add_child(message_label)

	var help := Label.new()
	help.text = "左键建造/查看/选中 · 右键短按取消摆放 · 中键拖动平移 · 右键拖动旋转 · 滚轮缩放"
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 20
	help.offset_top = -129
	help.offset_right = 930
	help.offset_bottom = -106
	help.add_theme_color_override("font_color", Color("2f3433"))
	help.add_theme_color_override("font_outline_color", Color(0.95, 0.90, 0.79, 0.92))
	help.add_theme_constant_override("outline_size", 4)
	layer.add_child(help)

	settings_overlay = Control.new()
	settings_overlay.name = "SettingsOverlay"
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_overlay.z_index = 30
	settings_overlay.visible = false
	settings_overlay.gui_input.connect(_on_settings_overlay_gui_input)
	layer.add_child(settings_overlay)
	settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings_panel.offset_left = -278
	settings_panel.offset_right = -14
	settings_panel.offset_top = 82
	settings_panel.offset_bottom = 332
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_panel.add_theme_stylebox_override("panel", panel_style(Color(0.95, 0.90, 0.79, 0.99)))
	settings_overlay.add_child(settings_panel)
	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 7)
	settings_panel.add_child(settings_box)
	var settings_header := HBoxContainer.new()
	settings_box.add_child(settings_header)
	var settings_title := Label.new()
	settings_title.text = "游戏设置"
	settings_title.add_theme_font_size_override("font_size", 19)
	settings_title.add_theme_color_override("font_color", Color("6b4731"))
	settings_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	settings_header.add_child(settings_title)
	var close_button := make_compact_button("×", close_settings_menu, Vector2(36, 32))
	close_button.tooltip_text = "关闭设置"
	settings_header.add_child(close_button)
	settings_action_buttons["view"] = make_settings_action_button("查看地图 / 取消摆放", view_from_settings)
	settings_action_buttons["save"] = make_settings_action_button("保存当前进度", save_from_settings)
	settings_action_buttons["load"] = make_settings_action_button("读取最近存档", request_load_from_settings)
	settings_action_buttons["reset"] = make_settings_action_button("重新开始本局", request_reset_from_settings, Color("f0d1b8"))
	for action in ["view", "save", "load", "reset"]:
		settings_box.add_child(settings_action_buttons[action])

	confirmation_dialog = ConfirmationDialog.new()
	confirmation_dialog.min_size = Vector2i(420, 170)
	confirmation_dialog.get_ok_button().text = "确认"
	confirmation_dialog.get_cancel_button().text = "取消"
	confirmation_dialog.confirmed.connect(confirm_pending_action)
	layer.add_child(confirmation_dialog)

func make_action_button(text: String, callback: Callable, color := Color("f5e8cb")) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(92, 50)
	apply_button_theme(button, color)
	button.pressed.connect(callback)
	return button

func make_compact_button(text: String, callback: Callable, minimum_size: Vector2, color := Color("f5e8cb")) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	apply_button_theme(button, color)
	button.pressed.connect(callback)
	return button

func make_settings_action_button(text: String, callback: Callable, color := Color("f5e8cb")) -> Button:
	var button := make_action_button(text, callback, color)
	button.custom_minimum_size = Vector2(236, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button

func toggle_settings_menu() -> void:
	if settings_overlay.visible:
		close_settings_menu()
		return
	settings_overlay.visible = true
	settings_button.set_pressed_no_signal(true)
	drag_button = -1

func close_settings_menu() -> void:
	settings_overlay.visible = false
	settings_button.set_pressed_no_signal(false)
	drag_button = -1

func _on_settings_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not settings_panel.get_global_rect().has_point(event.position):
			close_settings_menu()
			settings_overlay.accept_event()

func view_from_settings() -> void:
	close_settings_menu()
	cancel_building()
	show_message("已进入查看模式：点击建筑可查看详情")

func save_from_settings() -> void:
	close_settings_menu()
	save_game()

func request_load_from_settings() -> void:
	close_settings_menu()
	if not FileAccess.file_exists(save_path()):
		show_message("还没有可读取的存档")
		return
	pending_confirm_action = "load"
	confirmation_dialog.title = "读取最近存档"
	confirmation_dialog.dialog_text = "读取存档将覆盖当前未保存的进度。"
	confirmation_dialog.get_ok_button().text = "读取"
	confirmation_dialog.popup_centered(Vector2i(420, 170))

func request_reset_from_settings() -> void:
	close_settings_menu()
	pending_confirm_action = "reset"
	confirmation_dialog.title = "重新开始本局"
	confirmation_dialog.dialog_text = "当前城镇将被清除，并从第 1 日重新开始。"
	confirmation_dialog.get_ok_button().text = "重新开始"
	confirmation_dialog.popup_centered(Vector2i(420, 170))

func confirm_pending_action() -> void:
	var action := pending_confirm_action
	pending_confirm_action = ""
	if action == "load":
		load_game()
	elif action == "reset":
		reset_game(true)

func toggle_region_panel() -> void:
	region_panel_collapsed = not region_panel_collapsed
	update_ui()

func region_progress_text() -> String:
	if map_region_level >= REGION_DEFINITIONS.size() - 1:
		return final_progress_fraction()
	return objective_progress_fraction(map_region_level + 1)

func apply_region_panel_layout() -> void:
	if not region_panel or not region_panel_toggle:
		return
	region_panel.offset_top = 88
	region_panel.offset_right = -14
	if region_panel_collapsed:
		region_panel.offset_left = -190
		region_panel.offset_bottom = 146
		region_title.text = "目标 %s" % region_progress_text()
		region_title.add_theme_font_size_override("font_size", 16)
		region_body.visible = false
		region_unlock_button.visible = false
		region_panel_toggle.text = "<"
		region_panel_toggle.tooltip_text = "展开目标栏"
	else:
		region_panel.offset_left = -398
		region_panel.offset_bottom = 552
		region_title.add_theme_font_size_override("font_size", 20)
		region_body.visible = true
		region_unlock_button.visible = true
		region_panel_toggle.text = ">"
		region_panel_toggle.tooltip_text = "收起目标栏"

func apply_button_theme(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_color", Color("2f3433"))
	button.add_theme_color_override("font_hover_color", Color("2f3433"))
	button.add_theme_color_override("font_pressed_color", Color("2f3433"))
	button.add_theme_color_override("font_focus_color", Color("2f3433"))
	button.add_theme_color_override("font_disabled_color", Color("6c6a64"))
	button.add_theme_stylebox_override("normal", button_style(color))
	button.add_theme_stylebox_override("hover", button_style(color.lightened(0.06)))
	button.add_theme_stylebox_override("pressed", button_style(Color("d6a74a"), 2))
	button.add_theme_stylebox_override("hover_pressed", button_style(Color("e0b965"), 2))
	button.add_theme_stylebox_override("focus", button_style(Color("f2e6ca"), 2))
	button.add_theme_stylebox_override("disabled", button_style(Color("d8d0c1")))

func panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("a8855b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style

func button_style(color: Color, border_width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("a8855b")
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	return style

func select_building(type: String) -> void:
	if ended != "":
		return
	if selected_type == type:
		cancel_building()
		show_message("已取消摆放，进入查看模式")
		return
	selected_type = type
	selected_building_id = -1
	inspector.visible = false
	show_message("请选择格子放置%s" % BUILDINGS[type].name)
	update_ui()

func cancel_building() -> void:
	selected_type = ""
	clear_ghost()
	update_ui()

func is_reserved_forest(cell: Vector2i) -> bool:
	return (
		(cell.x >= 16 and cell.x <= 19 and cell.y < 20)
		or (cell.x >= 27 and cell.x <= 29 and cell.y < 20)
		or (cell.x >= 44 and cell.x <= 47 and cell.y < 24)
		or (cell.y >= 30 and cell.x <= 4)
		or (cell.y >= 30 and cell.x >= 24 and cell.x <= 29)
	)

func is_water_cell(cell: Vector2i) -> bool:
	return cell.x == 2 or cell.x == 3 or (cell.y < 24 and (cell.x == 32 or cell.x == 33))

func is_farm_cell(cell: Vector2i) -> bool:
	return cell.x == 1 or cell.x == 4 or (cell.y < 24 and (cell.x == 31 or cell.x == 34))

func is_lumber_cell(cell: Vector2i) -> bool:
	return (
		cell.x == 14 or cell.x == 15
		or (cell.x >= 20 and cell.x <= 22)
		or (cell.y < 24 and cell.x >= 41 and cell.x <= 43)
		or (cell.y >= 30 and ((cell.x >= 5 and cell.x <= 7) or (cell.x >= 21 and cell.x <= 23)))
	)

func region_lock_message(level: int) -> String:
	match level:
		1: return "北坡梯田尚未开放。查看右侧“区域开拓”了解条件。"
		2: return "东麓林场尚未开放。需先经营北坡梯田。"
		3: return "云岫高台尚未开放。需先经营东麓林场。"
		4: return "沧波东原尚未开放。完成百工登台主线后可开拓。"
		5: return "朔岭关田尚未开放。完成东原成镇主线后可开拓。"
		6: return "天际新都尚未开放。完成北关兴业主线后可开拓。"
	return "这片区域尚未开放。"

func can_place(type: String, cell: Vector2i) -> String:
	if cell.x < 0 or cell.x >= GRID_SIZE or cell.y < 0 or cell.y >= GRID_SIZE:
		return "超出地图边界"
	var region_level := region_level_for_cell(cell)
	if region_level > map_region_level:
		return region_lock_message(region_level)
	if is_water_cell(cell):
		return "河道上不能建造"
	if is_reserved_forest(cell):
		return "保留林地不能建造，请在林缘布置伐木场"
	if occupied.has(cell):
		return "这里已有建筑"
	var definition: Dictionary = BUILDINGS[type]
	if wood < int(definition.cost):
		return "木材不足（需要 %d）" % definition.cost
	if type == "farm" and not is_farm_cell(cell):
		return "农田只能建在河岸；东原支流与旧河道两侧均可耕种"
	if type == "lumber" and not is_lumber_cell(cell):
		return "伐木场需要建在东麓、东原或北关的林缘"
	if type == "workshop" and population < 8:
		return "小工坊需要人口达到 8"
	return ""

func can_unlock_next_region() -> String:
	if ended != "":
		return "游戏已结束，无法继续开拓"
	if map_region_level >= REGION_DEFINITIONS.size() - 1:
		return "河谷全境已开放"
	var next_level := map_region_level + 1
	var requirement := ""
	match next_level:
		1:
			if population < 8: requirement = "需要人口达到 8"
			elif building_count("farm") < 1: requirement = "需要至少 1 座农田"
		2:
			if population < 12: requirement = "需要人口达到 12"
			elif building_count("lumber") < 2: requirement = "需要至少 2 座伐木场"
			elif building_count("warehouse") < 1: requirement = "需要至少 1 座仓库"
		3:
			if population < 18: requirement = "需要人口达到 18"
			elif happiness < 65: requirement = "需要幸福度达到 65"
			elif building_count("workshop") < 1: requirement = "需要至少 1 座小工坊"
		4:
			if population < 24: requirement = "需要人口达到 24"
			elif building_count("farm") < 3: requirement = "需要至少 3 座农田"
			elif building_count("warehouse") < 2: requirement = "需要至少 2 座仓库"
		5:
			if population < 32: requirement = "需要人口达到 32"
			elif building_count("lumber") < 3: requirement = "需要至少 3 座伐木场"
			elif building_count("workshop") < 2: requirement = "需要至少 2 座小工坊"
			elif happiness < 70: requirement = "需要幸福度达到 70"
		6:
			if population < 40: requirement = "需要人口达到 40"
			elif housing_capacity() < 44: requirement = "需要住房容量达到 44"
			elif building_count("warehouse") < 3: requirement = "需要至少 3 座仓库"
			elif building_count("workshop") < 3: requirement = "需要至少 3 座小工坊"
			elif happiness < 75: requirement = "需要幸福度达到 75"
	var cost: Dictionary = REGION_UNLOCK_COSTS[next_level]
	if requirement != "":
		return requirement
	if wood < int(cost.wood):
		return "木材不足（需要 %d）" % cost.wood
	if food < int(cost.food):
		return "粮食不足（需要 %d）" % cost.food
	return ""

func unlock_next_region() -> void:
	var reason := can_unlock_next_region()
	if reason != "":
		show_message(reason)
		return
	var next_level := map_region_level + 1
	var cost: Dictionary = REGION_UNLOCK_COSTS[next_level]
	# 条件和扣费在同一函数内再次校验，防止重复点击造成负库存。
	if wood < int(cost.wood) or food < int(cost.food):
		show_message("开拓费用不足")
		return
	wood -= int(cost.wood)
	food -= int(cost.food)
	map_region_level = next_level
	var reward_message := apply_region_reward(next_level)
	clear_ghost()
	update_region_visuals()
	show_message("%s\n%s" % [REGION_UNLOCK_FEEDBACK[next_level], reward_message])
	update_ui()
	save_game(false)

func apply_region_reward(level: int) -> String:
	var reward: Dictionary = REGION_UNLOCK_REWARDS[level]
	var wood_reward := int(reward.wood)
	var food_reward := int(reward.food)
	var happiness_reward := int(reward.happiness)
	var gained_wood := mini(wood_reward, maxi(0, wood_capacity() - wood))
	var gained_food := mini(food_reward, maxi(0, food_capacity() - food))
	wood += gained_wood
	food += gained_food
	happiness = mini(100, happiness + happiness_reward)
	var parts: Array[String] = []
	if wood_reward > 0:
		parts.append("获得木材 %d%s" % [gained_wood, "，溢出 %d" % (wood_reward - gained_wood) if gained_wood < wood_reward else ""])
	if food_reward > 0:
		parts.append("获得粮食 %d%s" % [gained_food, "，溢出 %d" % (food_reward - gained_food) if gained_food < food_reward else ""])
	if happiness_reward > 0:
		parts.append("幸福度 +%d" % happiness_reward)
	return "开拓奖励：%s" % "；".join(parts)

func add_building(type: String, cell: Vector2i, free := false, forced_id := -1) -> void:
	var model := create_building_model(type)
	model.position = grid_to_world(cell)
	var building_id := forced_id if forced_id >= 0 else next_id
	if forced_id < 0:
		next_id += 1
	else:
		next_id = max(next_id, forced_id + 1)
	model.set_meta("building_id", building_id)
	building_root.add_child(model)
	var record := {"id": building_id, "type": type, "cell": cell, "node": model}
	buildings.append(record)
	occupied[cell] = building_id
	if not free:
		wood -= int(BUILDINGS[type].cost)

func remove_building_by_id(building_id: int, refund := true) -> void:
	for index in range(buildings.size()):
		var record: Dictionary = buildings[index]
		if int(record.id) == building_id:
			if refund:
				wood = mini(wood_capacity(), wood + int(BUILDINGS[record.type].cost) / 2)
			occupied.erase(record.cell)
			record.node.queue_free()
			buildings.remove_at(index)
			break
	selected_building_id = -1
	inspector.visible = false

func demolish_selected() -> void:
	if selected_building_id < 0:
		return
	var name := "建筑"
	for record in buildings:
		if int(record.id) == selected_building_id:
			name = BUILDINGS[record.type].name
			break
	remove_building_by_id(selected_building_id)
	show_message("已拆除%s并返还一半木材" % name)
	update_ui()
	save_game(false)

func next_day() -> void:
	if ended != "" or day_settling:
		return
	day_settling = true
	auto_day_elapsed = 0.0
	var wood_gain := 0
	var food_gain := 0
	var building_upkeep := 0
	for record in buildings:
		var definition: Dictionary = BUILDINGS[record.type]
		wood_gain += int(definition.wood)
		food_gain += int(definition.food)
		if record.type == "house" or record.type == "workshop":
			building_upkeep += 1
	wood = mini(wood_capacity(), wood + wood_gain)
	food = mini(food_capacity(), food + food_gain)
	var ration := ceili(population * 0.25)
	var daily_food_need := building_upkeep + ration
	var shortage := food < daily_food_need
	food = maxi(0, food - daily_food_need)
	var population_message := ""
	if shortage:
		population = maxi(1, population - 1)
		happiness -= 12
		population_message = "粮食短缺，1 名居民离开"
	else:
		var empty_beds := housing_capacity() - population
		if happiness >= 55 and food >= 2 * population and empty_beds >= 1:
			var arrivals := mini(2, int(floor(empty_beds / 2.0)) + 1)
			arrivals = mini(arrivals, 50 - population)
			population += arrivals
			population_message = "%d 名新居民迁入河谷" % arrivals
		else:
			population_message = "今日无人迁入：请检查空床、粮食与幸福度"
	if food >= 2 * population:
		happiness += 2
	elif food > 0 and food < population:
		happiness -= 3
	happiness = clampi(happiness + building_count("workshop") * 2, 0, 100)
	day += 1
	var event_message := trigger_event(day % 4)
	low_happiness_days = low_happiness_days + 1 if happiness < 20 else 0
	if (
		map_region_level >= REGION_DEFINITIONS.size() - 1
		and population >= VICTORY_POPULATION
		and wood >= VICTORY_WOOD
		and food >= VICTORY_FOOD
		and happiness >= VICTORY_HAPPINESS
	):
		end_game("win")
	elif food <= 0 or low_happiness_days >= 3:
		end_game("lose")
	var summary := "%s；产出木材 %d、粮食 %d；消耗粮食 %d" % [population_message, wood_gain, food_gain, daily_food_need]
	show_message(summary + ("\n" + event_message if event_message != "" else ""))
	update_citizens()
	update_ui()
	save_game(false)
	day_settling = false

func trigger_event(event_index: int) -> String:
	match event_index:
		0:
			food = mini(food_capacity(), food + building_count("farm") * 8)
			return "丰收：农田产出翻倍，本日额外获得粮食"
		1:
			wood = maxi(0, wood - building_count("lumber") * 2)
			return "雨季：伐木场产出受影响"
		2:
			if food >= 10:
				food -= 10
				wood = mini(wood_capacity(), wood + 25)
				return "商旅抵达：支付 10 粮食换取 25 木材"
			else:
				return "商旅经过，但库存不足以交易"
		3:
			happiness = maxi(0, happiness - 8)
			return "居民争执：幸福度 -8"
	return ""

func building_count(type: String) -> int:
	var count := 0
	for record in buildings:
		if record.type == type:
			count += 1
	return count

func housing_capacity() -> int:
	return building_count("house") * 4

func wood_capacity() -> int:
	return 100 + building_count("warehouse") * 50

func food_capacity() -> int:
	return 100 + building_count("warehouse") * 50

func update_ui() -> void:
	status_label.text = "第 %d 日 · %s     木材 %d/%d     粮食 %d/%d     人口 %d/%d     幸福 %d" % [day, time_status_text(), wood, wood_capacity(), food, food_capacity(), population, housing_capacity(), happiness]
	if map_region_level >= REGION_DEFINITIONS.size() - 1:
		goal_label.text = "%s · %s    进度 %s\n当前：%s" % [CAMPAIGN_CHAPTERS[6], CAMPAIGN_STAGE_NAMES[6], final_progress_fraction(), final_current_task_text()]
	else:
		var next_level := map_region_level + 1
		goal_label.text = "%s · %s    进度 %s\n当前：%s" % [CAMPAIGN_CHAPTERS[map_region_level], CAMPAIGN_STAGE_NAMES[map_region_level], objective_progress_fraction(next_level), current_task_text(next_level)]
	if region_panel and region_title and region_body and region_unlock_button:
		if map_region_level >= REGION_DEFINITIONS.size() - 1:
			region_title.text = "%s · %s    进度 %s" % [CAMPAIGN_CHAPTERS[6], CAMPAIGN_STAGE_NAMES[6], final_progress_fraction()]
			region_body.text = "目标：完成东境全域复兴\n\n%s\n\n当前任务\n%s\n\n下一解锁：七境已经全部开放\n奖励：完成后赢得“东境全域复兴”" % [final_goal_progress_text(), final_current_task_text()]
			region_unlock_button.text = "终章目标进行中"
			region_unlock_button.disabled = true
		else:
			var next_level := map_region_level + 1
			var next_region: Dictionary = REGION_DEFINITIONS[next_level]
			var cost: Dictionary = REGION_UNLOCK_COSTS[next_level]
			var reason := can_unlock_next_region()
			region_title.text = "%s · %s    进度 %s" % [CAMPAIGN_CHAPTERS[map_region_level], CAMPAIGN_STAGE_NAMES[map_region_level], objective_progress_fraction(next_level)]
			region_body.text = "目标：开拓%s\n用途：%s\n\n%s\n%s\n\n当前任务\n%s\n\n下一解锁：%s · %d格\n费用：木材 %d · 粮食 %d\n奖励：%s" % [next_region.name, next_region.summary, objective_progress_text(next_level), resource_cost_progress_text(next_level), current_task_text(next_level), next_region.name, next_region.area, cost.wood, cost.food, objective_reward_text(next_level)]
			region_unlock_button.text = "开拓%s" % next_region.short_name if reason == "" else "条件尚未满足"
			region_unlock_button.disabled = ended != "" or reason != ""
		apply_region_panel_layout()
	for type in build_buttons:
		var button: Button = build_buttons[type]
		button.disabled = ended != ""
		button.button_pressed = selected_type == type
	update_time_controls()

func show_message(text: String) -> void:
	message_label.text = text

func unlock_requirement_text(level: int) -> String:
	match level:
		1: return "条件：人口 8 · 农田 1"
		2: return "条件：人口 12 · 伐木场 2 · 仓库 1"
		3: return "条件：人口 18 · 幸福 65 · 小工坊 1"
		4: return "条件：人口 24 · 农田 3 · 仓库 2"
		5: return "条件：人口 32 · 伐木场 3 · 小工坊 2 · 幸福 70"
		6: return "条件：人口 40 · 住房 44 · 仓库 3 · 小工坊 3 · 幸福 75"
	return ""

func progress_line(label: String, current: int, required: int) -> String:
	return "%s %s：当前 %d / 要求 %d" % ["✓" if current >= required else "○", label, current, required]

func objective_progress_text(level: int) -> String:
	var lines: Array[String] = []
	match level:
		1:
			lines = [progress_line("人口", population, 8), progress_line("农田", building_count("farm"), 1)]
		2:
			lines = [progress_line("人口", population, 12), progress_line("伐木场", building_count("lumber"), 2), progress_line("仓库", building_count("warehouse"), 1)]
		3:
			lines = [progress_line("人口", population, 18), progress_line("幸福", happiness, 65), progress_line("小工坊", building_count("workshop"), 1)]
		4:
			lines = [progress_line("人口", population, 24), progress_line("农田", building_count("farm"), 3), progress_line("仓库", building_count("warehouse"), 2)]
		5:
			lines = [progress_line("人口", population, 32), progress_line("伐木场", building_count("lumber"), 3), progress_line("小工坊", building_count("workshop"), 2), progress_line("幸福", happiness, 70)]
		6:
			lines = [progress_line("人口", population, 40), progress_line("住房容量", housing_capacity(), 44), progress_line("仓库", building_count("warehouse"), 3), progress_line("小工坊", building_count("workshop"), 3), progress_line("幸福", happiness, 75)]
	return "\n".join(lines)

func resource_cost_progress_text(level: int) -> String:
	var cost: Dictionary = REGION_UNLOCK_COSTS[level]
	var ready := wood >= int(cost.wood) and food >= int(cost.food)
	return "%s 开拓物资：木材 当前 %d / 要求 %d · 粮食 当前 %d / 要求 %d" % ["✓" if ready else "○", wood, cost.wood, food, cost.food]

func objective_reward_text(level: int) -> String:
	match level:
		1: return "200格新耕地 + 20粮奖励"
		2: return "200格林业用地 + 40木奖励"
		3: return "100格工坊高地 + 幸福度 5"
		4: return "432格大平原 + 50粮奖励"
		5: return "540格山林工坊区 + 80木奖励"
		6: return "432格天际新都 + 80粮奖励 + 幸福度 5"
	return ""

func next_stage_preview(level: int) -> String:
	if level < REGION_DEFINITIONS.size() - 1:
		return "%s · 开拓%s" % [CAMPAIGN_STAGE_NAMES[level], REGION_DEFINITIONS[level + 1].name]
	return "东境复兴 · 达成最终人口与物资目标"

func objective_progress_fraction(level: int) -> String:
	var totals := objective_completion_counts(level)
	return "%d/%d" % [totals.done, totals.total]

func objective_completion_counts(level: int) -> Dictionary:
	var completed := 0
	var total := 1
	match level:
		1:
			completed += int(population >= 8) + int(building_count("farm") >= 1)
			total += 2
		2:
			completed += int(population >= 12) + int(building_count("lumber") >= 2) + int(building_count("warehouse") >= 1)
			total += 3
		3:
			completed += int(population >= 18) + int(happiness >= 65) + int(building_count("workshop") >= 1)
			total += 3
		4:
			completed += int(population >= 24) + int(building_count("farm") >= 3) + int(building_count("warehouse") >= 2)
			total += 3
		5:
			completed += int(population >= 32) + int(building_count("lumber") >= 3) + int(building_count("workshop") >= 2) + int(happiness >= 70)
			total += 4
		6:
			completed += int(population >= 40) + int(housing_capacity() >= 44) + int(building_count("warehouse") >= 3) + int(building_count("workshop") >= 3) + int(happiness >= 75)
			total += 5
	var cost: Dictionary = REGION_UNLOCK_COSTS[level]
	completed += int(wood >= int(cost.wood) and food >= int(cost.food))
	return {"done": completed, "total": total}

func required_population_for_level(level: int) -> int:
	return [0, 8, 12, 18, 24, 32, 40][level]

func required_buildings_for_level(level: int) -> Array[Dictionary]:
	match level:
		1: return [{"type": "farm", "target": 1, "name": "农田", "hint": "请靠近河岸放置"}]
		2: return [{"type": "lumber", "target": 2, "name": "伐木场", "hint": "请在林缘放置"}, {"type": "warehouse", "target": 1, "name": "仓库", "hint": "提升物资容量"}]
		3: return [{"type": "workshop", "target": 1, "name": "小工坊", "hint": "增加木材与幸福度"}]
		4: return [{"type": "farm", "target": 3, "name": "农田", "hint": "请靠近河岸放置"}, {"type": "warehouse", "target": 2, "name": "仓库", "hint": "提升物资容量"}]
		5: return [{"type": "lumber", "target": 3, "name": "伐木场", "hint": "请在林缘放置"}, {"type": "workshop", "target": 2, "name": "小工坊", "hint": "发展山脚工坊"}]
		6: return [{"type": "warehouse", "target": 3, "name": "仓库", "hint": "提升物资容量"}, {"type": "workshop", "target": 3, "name": "小工坊", "hint": "建设新都产业"}]
	return []

func current_task_text(level: int) -> String:
	for requirement in required_buildings_for_level(level):
		var current := building_count(str(requirement.type))
		var target := int(requirement.target)
		if current < target:
			if current == 0:
				return "建造 %d 座%s（%d/%d），%s" % [target, requirement.name, current, target, requirement.hint]
			return "再建 %d 座%s（当前 %d/%d），%s" % [target - current, requirement.name, current, target, requirement.hint]
	var cost: Dictionary = REGION_UNLOCK_COSTS[level]
	var needed_capacity := maxi(int(cost.wood), int(cost.food))
	if wood_capacity() < needed_capacity or food_capacity() < int(cost.food):
		var target_capacity := 100 + ceili((needed_capacity - 100) / 50.0) * 50
		var warehouses_needed := maxi(0, ceili((target_capacity - wood_capacity()) / 50.0))
		return "建造 %d 座仓库，把物资容量提升到 %d" % [warehouses_needed, target_capacity]
	var target_population := required_population_for_level(level)
	if housing_capacity() < target_population:
		var houses_needed := ceili((target_population - housing_capacity()) / 4.0)
		return "建造 %d 座茅舍，为 %d 人准备床位" % [houses_needed, target_population]
	if population < target_population:
		var migration_food := population * 2
		if food < migration_food:
			return "储备粮食到 %d，居民才会迁入（当前 %d/%d）" % [migration_food, population, target_population]
		return "保持运转，等待居民迁入（当前 %d/%d）" % [population, target_population]
	var happiness_target: int = [0, 0, 0, 65, 0, 70, 75][level]
	if happiness < happiness_target:
		return "保障口粮并让小工坊运转，把幸福度提升到 %d（当前 %d/%d）" % [happiness_target, happiness, happiness_target]
	if wood < int(cost.wood):
		return "储备木材 %d/%d，还需 %d（伐木场每日产出）" % [wood, cost.wood, int(cost.wood) - wood]
	if food < int(cost.food):
		return "储备粮食 %d/%d，还需 %d（农田每日产出）" % [food, cost.food, int(cost.food) - food]
	return "条件齐备，点击“开拓%s”" % REGION_DEFINITIONS[level].short_name

func final_goal_progress_text() -> String:
	return "\n".join([
		progress_line("住房容量", housing_capacity(), VICTORY_POPULATION),
		progress_line("人口", population, VICTORY_POPULATION),
		progress_line("木材", wood, VICTORY_WOOD),
		progress_line("粮食", food, VICTORY_FOOD),
		progress_line("幸福", happiness, VICTORY_HAPPINESS)
	])

func final_progress_fraction() -> String:
	var done := int(housing_capacity() >= VICTORY_POPULATION) + int(population >= VICTORY_POPULATION) + int(wood >= VICTORY_WOOD) + int(food >= VICTORY_FOOD) + int(happiness >= VICTORY_HAPPINESS)
	return "%d/5" % done

func final_current_task_text() -> String:
	if housing_capacity() < VICTORY_POPULATION:
		return "建造 %d 座茅舍，为 45 人准备床位" % ceili((VICTORY_POPULATION - housing_capacity()) / 4.0)
	if population < VICTORY_POPULATION:
		return "让人口达到 45（当前 %d/45；住房 %d）" % [population, housing_capacity()]
	if food < VICTORY_FOOD:
		return "储备粮食 %d/%d" % [food, VICTORY_FOOD]
	if wood < VICTORY_WOOD:
		return "储备木材 %d/%d" % [wood, VICTORY_WOOD]
	if happiness < VICTORY_HAPPINESS:
		return "把幸福度提升到 %d（当前 %d/%d）" % [VICTORY_HAPPINESS, happiness, VICTORY_HAPPINESS]
	return "目标达成：东境全域复兴"

func show_inspector(building_id: int) -> void:
	for record in buildings:
		if int(record.id) == building_id:
			selected_building_id = building_id
			var definition: Dictionary = BUILDINGS[record.type]
			inspector_title.text = definition.name
			var cell: Vector2i = record.cell
			inspector_body.text = "%s\n\n位置：%d，%d\n拆除返还：%d 木材" % [definition.description, cell.x + 1, cell.y + 1, int(definition.cost) / 2]
			inspector.visible = true
			return

func end_game(result: String) -> void:
	ended = result
	end_layer = CanvasLayer.new()
	end_layer.layer = 10
	add_child(end_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.11, 0.15, 0.15, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -110
	panel.offset_bottom = 110
	panel.add_theme_stylebox_override("panel", panel_style(Color("f2e6ca")))
	end_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var title := Label.new()
	title.text = "东境全域复兴！" if result == "win" else "聚落陷入困境"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("6b4731"))
	box.add_child(title)
	var detail := Label.new()
	detail.text = "七境相连，粮木充足，百姓安居。昔日河湾已经成为一座繁盛新城。" if result == "win" else "粮食耗尽或民心持续低落，请调整规划。"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(detail)
	box.add_child(make_action_button("重新开始", reset_game.bind(true), Color("d6a74a")))

func reset_game(confirm_reset := true) -> void:
	if end_layer and is_instance_valid(end_layer):
		end_layer.queue_free()
		end_layer = null
	for child in building_root.get_children():
		child.queue_free()
	day = 1
	wood = 100
	food = 40
	population = 4
	happiness = 60
	low_happiness_days = 0
	map_region_level = 0
	selected_type = ""
	ended = ""
	auto_day_elapsed = 0.0
	time_paused = false
	time_speed = 1.0
	day_settling = false
	next_id = 1
	buildings.clear()
	occupied.clear()
	for child in citizen_root.get_children():
		child.queue_free()
	selected_building_id = -1
	inspector.visible = false
	clear_ghost()
	update_region_visuals()
	add_building("house", Vector2i(9, 9), true)
	update_citizens()
	show_message("时间正以 1× 自动流逝：先建设住房与生产设施吧")
	update_ui()
	if confirm_reset:
		save_game(false)

func save_game(show_feedback := true) -> void:
	var target_path := save_path()
	DirAccess.make_dir_recursive_absolute(target_path.get_base_dir())
	var building_data: Array[Dictionary] = []
	for record in buildings:
		var cell: Vector2i = record.cell
		building_data.append({"id": record.id, "type": record.type, "x": cell.x, "z": cell.y})
	var data := {
		"version": SAVE_VERSION, "map_region_level": map_region_level, "day": day, "wood": wood, "food": food, "population": population,
		"happiness": happiness, "low_happiness_days": low_happiness_days,
		"next_id": next_id, "ended": ended, "buildings": building_data
	}
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()
		if show_feedback:
			show_message("存档已写入项目 saves 文件夹")
	else:
		show_message("存档写入失败")

func load_game(show_feedback := true) -> void:
	var target_path := save_path()
	if not FileAccess.file_exists(target_path):
		if show_feedback:
			show_message("还没有可读取的存档")
		return
	var file := FileAccess.open(target_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) not in [1, 2]:
		if show_feedback:
			show_message("存档格式无效，当前进度未改变")
		return
	var validation_error := validate_save_data(parsed)
	if validation_error != "":
		if show_feedback:
			show_message("存档无效：%s；当前进度未改变" % validation_error)
		return
	for child in building_root.get_children():
		child.queue_free()
	buildings.clear()
	occupied.clear()
	day = int(parsed.get("day", 1))
	wood = int(parsed.get("wood", 100))
	food = int(parsed.get("food", 40))
	population = int(parsed.get("population", 4))
	happiness = int(parsed.get("happiness", 60))
	low_happiness_days = int(parsed.get("low_happiness_days", 0))
	map_region_level = int(parsed.get("map_region_level", 0)) if int(parsed.get("version", 1)) >= 2 else 0
	next_id = int(parsed.get("next_id", 1))
	ended = ""
	auto_day_elapsed = 0.0
	time_paused = false
	day_settling = false
	for record in parsed.get("buildings", []):
		var type := str(record.get("type", ""))
		if BUILDINGS.has(type):
			add_building(type, Vector2i(int(record.get("x", 0)), int(record.get("z", 0))), true, int(record.get("id", -1)))
	selected_type = ""
	selected_building_id = -1
	inspector.visible = false
	clear_ghost()
	update_region_visuals()
	update_citizens()
	if show_feedback:
		show_message("存档读取完成，时间继续自动流逝")
	update_ui()

func validate_save_data(data: Dictionary) -> String:
	var numeric_fields := ["day", "wood", "food", "population", "happiness", "low_happiness_days", "next_id"]
	for field in numeric_fields:
		if not data.has(field) or not is_json_number(data[field]):
			return "字段 %s 缺失或类型错误" % field
		if float(data[field]) != floor(float(data[field])):
			return "字段 %s 必须是整数" % field
	var saved_day := int(data.day)
	var saved_wood := int(data.wood)
	var saved_food := int(data.food)
	var saved_population := int(data.population)
	var saved_happiness := int(data.happiness)
	var saved_low_days := int(data.low_happiness_days)
	var saved_next_id := int(data.next_id)
	var save_version := int(data.get("version", 1))
	var saved_region_level := int(data.get("map_region_level", 0)) if save_version >= 2 else 0
	if saved_day < 1 or saved_day > 1000000:
		return "日期超出范围"
	if saved_population < 1 or saved_population > 50:
		return "人口超出范围"
	if saved_happiness < 0 or saved_happiness > 100:
		return "幸福度超出范围"
	if saved_low_days < 0 or saved_low_days > 1000000:
		return "低幸福计数超出范围"
	if saved_next_id < 1:
		return "下一个建筑编号无效"
	if save_version >= 2 and data.has("map_region_level") and (not is_json_number(data.map_region_level) or float(data.map_region_level) != floor(float(data.map_region_level))):
		return "区域等级必须是整数"
	if saved_region_level < 0 or saved_region_level > REGION_DEFINITIONS.size() - 1:
		return "区域等级超出范围"
	if typeof(data.get("buildings")) != TYPE_ARRAY:
		return "建筑列表缺失"
	var raw_buildings: Array = data.buildings
	if raw_buildings.size() > GRID_SIZE * GRID_SIZE:
		return "建筑数量超出地图容量"
	var used_cells := {}
	var used_ids := {}
	var warehouse_count := 0
	var max_id := 0
	for raw_record in raw_buildings:
		if typeof(raw_record) != TYPE_DICTIONARY:
			return "建筑记录类型错误"
		var record: Dictionary = raw_record
		if not record.has("id") or not is_json_number(record.id) or float(record.id) != floor(float(record.id)):
			return "建筑编号无效"
		if not record.has("x") or not is_json_number(record.x) or float(record.x) != floor(float(record.x)):
			return "建筑横坐标无效"
		if not record.has("z") or not is_json_number(record.z) or float(record.z) != floor(float(record.z)):
			return "建筑纵坐标无效"
		var building_id := int(record.id)
		var type := str(record.get("type", ""))
		var cell := Vector2i(int(record.x), int(record.z))
		if building_id < 1 or used_ids.has(building_id):
			return "建筑编号重复或超出范围"
		if not BUILDINGS.has(type):
			return "包含未知建筑类型"
		if cell.x < 0 or cell.x >= GRID_SIZE or cell.y < 0 or cell.y >= GRID_SIZE:
			return "建筑坐标超出地图"
		if region_level_for_cell(cell) > saved_region_level:
			return "建筑位于尚未开放的区域"
		if is_water_cell(cell) or is_reserved_forest(cell):
			return "建筑位于河道或保留林地"
		if type == "farm" and not is_farm_cell(cell):
			return "农田未位于河岸"
		if type == "lumber" and not is_lumber_cell(cell):
			return "伐木场未位于林缘"
		if used_cells.has(cell):
			return "多个建筑占用同一格"
		used_ids[building_id] = true
		used_cells[cell] = true
		max_id = maxi(max_id, building_id)
		if type == "warehouse":
			warehouse_count += 1
	var saved_capacity := 100 + warehouse_count * 50
	if saved_wood < 0 or saved_wood > saved_capacity or saved_food < 0 or saved_food > saved_capacity:
		return "资源数量超出当前仓储容量"
	if saved_next_id <= max_id:
		return "下一个建筑编号与现有建筑冲突"
	return ""

func is_json_number(value: Variant) -> bool:
	var value_type := typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT

func save_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path(EDITOR_SAVE_PATH)
	return OS.get_executable_path().get_base_dir().path_join("saves/savegame.json")

func grid_to_world(cell: Vector2i) -> Vector3:
	var half := GRID_SIZE * 0.5
	return Vector3((cell.x - half + 0.5) * TILE_SIZE, 0, (cell.y - half + 0.5) * TILE_SIZE)

func world_to_grid(point: Vector3) -> Vector2i:
	var half := GRID_SIZE * 0.5
	return Vector2i(floori(point.x / TILE_SIZE + half), floori(point.z / TILE_SIZE + half))

func mouse_ground_position(mouse_position: Vector2) -> Variant:
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	if absf(direction.y) < 0.0001:
		return null
	var distance := -origin.y / direction.y
	if distance < 0:
		return null
	return origin + direction * distance

func update_ghost(cell: Vector2i) -> void:
	if cell.x < 0 or cell.x >= GRID_SIZE or cell.y < 0 or cell.y >= GRID_SIZE:
		clear_ghost()
		return
	var locked_region := region_level_for_cell(cell) > map_region_level
	if selected_type == "" and not locked_region:
		clear_ghost()
		return
	if (ghost or locked_hover) and hover_cell == cell:
		return
	clear_ghost()
	hover_cell = cell
	if locked_region:
		locked_hover = mesh_box(Vector3(TILE_SIZE - 0.10, 0.035, TILE_SIZE - 0.10), Color(0.80, 0.67, 0.38, 0.72), 0.72)
		locked_hover.position = grid_to_world(cell) + Vector3(0, 0.24, 0)
		world.add_child(locked_hover)
		return
	ghost = create_building_model(selected_type, true)
	ghost.position = grid_to_world(cell)
	var valid := can_place(selected_type, cell) == ""
	RealisticKit.apply_preview_tint(ghost, valid)
	world.add_child(ghost)

func clear_ghost() -> void:
	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null
	if locked_hover and is_instance_valid(locked_hover):
		locked_hover.queue_free()
		locked_hover = null
	hover_cell = Vector2i(-1, -1)

func update_camera_projection() -> void:
	if camera:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if confirmation_dialog and confirmation_dialog.visible:
			confirmation_dialog.hide()
			pending_confirm_action = ""
		elif settings_overlay and settings_overlay.visible:
			close_settings_menu()
		elif selected_type != "":
			cancel_building()
			show_message("已取消摆放，进入查看模式")
		elif inspector and inspector.visible:
			selected_building_id = -1
			inspector.visible = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.size = maxf(18.0, camera.size * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.size = minf(118.0, camera.size * 1.1)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				drag_button = event.button_index
				drag_origin = event.position
				drag_last = event.position
				drag_moved = false
			elif event.button_index == drag_button:
				if drag_button == MOUSE_BUTTON_RIGHT and not drag_moved and selected_type != "":
					cancel_building()
					show_message("已取消摆放，进入查看模式")
					get_viewport().set_input_as_handled()
				elif drag_button == MOUSE_BUTTON_LEFT and not drag_moved:
					handle_world_click(event.position)
				drag_button = -1
	elif event is InputEventMouseMotion:
		var point = mouse_ground_position(event.position)
		if point != null:
			update_ghost(world_to_grid(point))
		if drag_button >= 0:
			var delta: Vector2 = event.position - drag_last
			if event.position.distance_to(drag_origin) > 4.0:
				drag_moved = true
			if drag_moved:
				if drag_button == MOUSE_BUTTON_RIGHT:
					rotate_camera(delta)
				elif drag_button == MOUSE_BUTTON_MIDDLE:
					pan_camera(delta)
			drag_last = event.position

func handle_world_click(mouse_position: Vector2) -> void:
	if ended != "":
		return
	var point = mouse_ground_position(mouse_position)
	if point == null:
		return
	var cell := world_to_grid(point)
	if region_level_for_cell(cell) > map_region_level:
		show_message(region_lock_message(region_level_for_cell(cell)))
		return
	if occupied.has(cell):
		if selected_type != "":
			cancel_building()
			show_message("已取消摆放，已选中建筑")
		show_inspector(int(occupied[cell]))
		return
	if selected_type != "":
		var reason := can_place(selected_type, cell)
		if reason != "":
			show_message(reason)
			return
		add_building(selected_type, cell)
		show_message("已建造%s" % BUILDINGS[selected_type].name)
		clear_ghost()
		update_ui()
		save_game(false)
	else:
		selected_building_id = -1
		inspector.visible = false

func pan_camera(delta: Vector2) -> void:
	var camera_offset := camera.position - camera_target
	var right := camera.global_transform.basis.x
	var forward := -camera.global_transform.basis.z
	right.y = 0
	forward.y = 0
	right = right.normalized()
	forward = forward.normalized()
	var movement := right * (-delta.x * camera.size * 0.0018) + forward * (delta.y * camera.size * 0.0018)
	camera_target += movement
	var extent := GRID_SIZE * TILE_SIZE * 0.5
	camera_target.x = clampf(camera_target.x, -extent, extent)
	camera_target.z = clampf(camera_target.z, -extent, extent)
	camera.position = camera_target + camera_offset
	camera.look_at(camera_target)

func rotate_camera(delta: Vector2) -> void:
	var offset := camera.position - camera_target
	offset = offset.rotated(Vector3.UP, -delta.x * 0.008)
	var distance := offset.length()
	var current_pitch := asin(clampf(offset.y / distance, -1.0, 1.0))
	var new_pitch := clampf(current_pitch + delta.y * 0.004, deg_to_rad(25.0), deg_to_rad(70.0))
	var horizontal := Vector2(offset.x, offset.z).normalized()
	offset = Vector3(horizontal.x * cos(new_pitch) * distance, sin(new_pitch) * distance, horizontal.y * cos(new_pitch) * distance)
	camera.position = camera_target + offset
	camera.look_at(camera_target)

