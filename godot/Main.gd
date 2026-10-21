extends Node

const RealisticKit = preload("res://godot/RealisticAssets.gd")
const AnimalKit = preload("res://godot/AnimalAssets.gd")
const RiverWaterKit = preload("res://godot/RiverWater.gd")
const RiverBoatKit = preload("res://godot/RiverBoat.gd")
const OuterGrassShader = preload("res://godot/shaders/outer_grass.gdshader")
const DetailedMountainKit = preload("res://godot/DetailedMountainAssets.gd")
const BackgroundMusicKit = preload("res://godot/BackgroundMusic.gd")

# The goal panel keeps its plain-text value for tooltips and automated checks,
# while rendering each individual requirement inside its compact group row.
# A completed item turns green independently, without progress counters.
class GoalChecklist extends VBoxContainer:
	var text: String = ""

	func set_content(plain_text: String, lines: Array) -> void:
		text = plain_text
		for child in get_children():
			remove_child(child)
			child.free()
		for item in lines:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var segments: Array = item.get("segments", [])
			if not segments.is_empty():
				var grouped_line := RichTextLabel.new()
				grouped_line.bbcode_enabled = true
				grouped_line.fit_content = true
				grouped_line.scroll_active = false
				grouped_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				grouped_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grouped_line.add_theme_font_size_override("normal_font_size", 15)
				grouped_line.add_theme_color_override("default_color", Color("2f3433"))
				var parts: Array[String] = []
				for segment in segments:
					var segment_text := str(segment.get("text", "")).replace("[", "[lb]")
					parts.append("[color=#2f8f5b]✓ %s[/color]" % segment_text if bool(segment.get("completed", false)) else segment_text)
				var prefix := str(item.get("prefix", "")).replace("[", "[lb]")
				grouped_line.text = "• " + prefix + " · ".join(parts)
				grouped_line.set_meta("goal_segments", segments.duplicate(true))
				grouped_line.set_meta("goal_prefix", str(item.get("prefix", "")))
				add_child(grouped_line)
				continue
			var line := Label.new()
			var value := str(item.get("text", ""))
			var is_requirement := bool(item.get("requirement", false))
			var completed := bool(item.get("completed", false))
			line.text = ("✓ " if completed and is_requirement else "• " if is_requirement else "") + value
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_theme_font_size_override("font_size", 15)
			line.add_theme_color_override("font_color", Color("2f8f5b") if completed and is_requirement else Color("2f3433"))
			add_child(line)
		add_theme_constant_override("separation", 2)

const GRID_SIZE := 48
# Keep building meshes at their authored size while giving each logical cell a
# little breathing room.  The 2.2 m pitch leaves a narrow courtyard gap between
# adjacent houses and keeps the grid readable at the planning camera distance.
const TILE_SIZE := 2.2
const ROAD_WIDTH := 1.0
# A natural, non-editable apron surrounds the logical 48x48 map.  Gameplay,
# region and save coordinates continue to use GRID_SIZE; only the rendered land
# extends into this margin so the planning camera does not expose a hard edge.
const NATURAL_BUFFER_CELLS := 36
const RENDER_GRID_SIZE := GRID_SIZE + NATURAL_BUFFER_CELLS * 2
# Orthographic size controls planning-camera zoom.  The previous 118-unit
# ceiling exposed the square terrain boundary and made the buildings too small
# to read.  A 48-unit ceiling keeps the expanded landscape around the view,
# while dynamic pan limits still let a closer camera reach every playable cell.
const CAMERA_INITIAL_SIZE := 30.0
const CAMERA_MIN_SIZE := 18.0
const CAMERA_MAX_SIZE := 48.0
const CAMERA_EDGE_SAFETY_MARGIN := 5.0
const CAMERA_EDGE_BROWSE_CELLS := 4
const CAMERA_MIN_PITCH_DEGREES := 30.0
const CAMERA_MAX_PITCH_DEGREES := 70.0
const EDITOR_SAVE_PATH := "res://saves/savegame.json"
const SAVE_VERSION := 4
const VICTORY_POPULATION := 45
const VICTORY_WOOD := 200
const VICTORY_FOOD := 200
const VICTORY_HAPPINESS := 80
const VICTORY_COINS := 150
const VICTORY_STABLE_DAYS := 7
const AUTO_DAY_SECONDS := 8.0
const TIME_SPEEDS := [1.0, 2.0, 4.0]
const BASIC_TRADE_COINS_PER_SITE := 2
const BASIC_TRADE_COIN_CAP := 4
const ROAD_WOOD_COST := 1
const ROAD_TRANSPORT_BONUS := 1
const ROAD_TRANSPORT_COIN_CAP := 6
const ROAD_ELIGIBLE_BUILDING_TYPES := ["farm", "fishpond", "lumber", "workshop", "market", "academy"]
# Regional markets occupy a small open courtyard instead of a single house
# tile.  The anchor is the north-west cell; the visual is centered across all
# four cells and every occupied cell remains selectable for inspection.
const BUILDING_FOOTPRINTS := {"market": Vector2i(2, 2), "warehouse": Vector2i(2, 2), "fishpond": Vector2i(3, 2), "farm": Vector2i(2, 2), "workshop": Vector2i(2, 2), "clinic": Vector2i(2, 2)}
const VILLAGE_ROAD_X := 10
const VILLAGE_ROAD_MIN_Z := 4
const VILLAGE_ROAD_MAX_Z := 15
const NPC_SCHEDULE_SECONDS := 72.0
const NPC_MOVE_SPEED := 1.10
const ANIMAL_MOVE_SPEED := 0.62
const ANIMAL_PHYSICS_STEP := 1.0 / 60.0
const ANIMAL_MAX_COUNT := 12
const ANIMAL_SPECIES := ["chicken", "duck", "goose", "dog"]
const CITIZEN_KINDS := ["农户", "匠人", "书生", "商贩", "舟夫", "孩童", "白衣女居民", "紫衣女居民"]
const NPC_PHYSICS_STEP := 1.0 / 60.0
const NPC_TURN_SPEED := PI
const NPC_WALK_STRIDE_METERS := 0.72
const NPC_WALK_BOB_HEIGHT := 0.035
# The realistic citizen is authored at roughly the same height as a complete
# one-tile house. Scale only its visible model so route movement stays in world
# metres while residents sit below doors and eaves in the planning view.
const NPC_VISUAL_SCALE := 0.52
const NPC_BRIDGES := [
	{"id": "main_river", "water_min_x": 2, "water_max_x": 3, "row": 9, "river_end_row": GRID_SIZE},
	{"id": "east_branch", "water_min_x": 32, "water_max_x": 33, "row": 12, "river_end_row": 24},
]
const CITIZEN_SCHEDULE := [
	{"from": 0.00, "to": 0.12, "state": "居家", "activity": "起床"},
	{"from": 0.12, "to": 0.28, "state": "通勤", "activity": "前往工地"},
	{"from": 0.28, "to": 0.68, "state": "工作", "activity": "生产"},
	{"from": 0.68, "to": 0.78, "state": "用餐", "activity": "取食"},
	{"from": 0.78, "to": 0.92, "state": "散步", "activity": "往来"},
	{"from": 0.92, "to": 1.00, "state": "回家", "activity": "休息"},
]

const REGION_DEFINITIONS := [
	{"id": "river_core", "name": "河湾故地", "short_name": "故地", "area": 400, "summary": "开局营地与基础生产"},
	{"id": "north_terrace", "name": "北坡梯田", "short_name": "北坡", "area": 200, "summary": "河岸耕地、鱼塘养殖与集市商贸"},
	{"id": "east_woodland", "name": "东麓林场", "short_name": "东麓", "area": 200, "summary": "林业用地与仓储扩张"},
	{"id": "highland", "name": "云岫高台", "short_name": "高台", "area": 100, "summary": "工坊高地、医馆与聚落中心"},
	{"id": "east_plain", "name": "沧波东原", "short_name": "东原", "area": 432, "summary": "大型居住、书院、粮食与仓储区"},
	{"id": "north_pass", "name": "朔岭关田", "short_name": "北关", "area": 540, "summary": "林业、山脚工坊与后期资源区"},
	{"id": "sky_capital", "name": "天际新都", "short_name": "新都", "area": 432, "summary": "最终新城与发展成果展示区"}
]

const REGION_UNLOCK_COSTS := [
	{"wood": 0, "food": 0, "coins": 0},
	{"wood": 65, "food": 30, "coins": 15},
	{"wood": 130, "food": 65, "coins": 35},
	{"wood": 190, "food": 95, "coins": 60},
	{"wood": 250, "food": 135, "coins": 90},
	{"wood": 320, "food": 180, "coins": 125},
	{"wood": 390, "food": 230, "coins": 165}
]

const REGION_REQUIREMENTS := [
	{},
	# Stock targets leave a reserve after expansion costs. Players choose their
	# own building mix and location; only these five visible values gate a region.
	{"wood": 90, "food": 60, "coins": 45, "population": 8, "happiness": 55},
	{"wood": 160, "food": 110, "coins": 85, "population": 14, "happiness": 60},
	{"wood": 225, "food": 150, "coins": 130, "population": 20, "happiness": 68},
	{"wood": 300, "food": 200, "coins": 190, "population": 28, "happiness": 72},
	{"wood": 390, "food": 260, "coins": 260, "population": 36, "happiness": 76},
	{"wood": 480, "food": 330, "coins": 350, "population": 45, "happiness": 80},
]

const REGION_UNLOCK_REWARDS := [
	{"wood": 0, "food": 0, "coins": 0, "happiness": 0},
	{"wood": 0, "food": 20, "coins": 10, "happiness": 0},
	{"wood": 40, "food": 0, "coins": 15, "happiness": 0},
	{"wood": 0, "food": 0, "coins": 20, "happiness": 5},
	{"wood": 0, "food": 50, "coins": 25, "happiness": 0},
	{"wood": 80, "food": 0, "coins": 30, "happiness": 0},
	{"wood": 0, "food": 80, "coins": 40, "happiness": 5}
]

const REGION_UNLOCK_FEEDBACK := [
	"",
	"北坡梯田已开放：新的河岸耕地可供规划，集市与鱼塘已解锁。",
	"东麓林场已开放：林间空地与新伐木带可用。",
	"云岫高台已开放：高台新城与工坊区可用，医馆建筑已解锁。",
	"沧波东原已开放：大片平原可建设住宅、粮田和仓储，书院建筑已解锁。",
	"朔岭关田已开放：山林资源与后期工坊区可用。",
	"天际新都已开放：七境相连，最终复兴目标已开启。"
]

const CAMPAIGN_STAGE_NAMES := [
	"安家河湾", "木通东麓", "百工登台", "东原成镇", "北关兴业", "新都落成", "东境复兴"
]

const CAMPAIGN_CHAPTERS := ["第一章", "第二章", "第三章", "第四章", "第五章", "第六章", "第七章"]

# These five tools make up the complete starting settlement kit.  Regional
# expansion adds new types to the other pages; it must never replace or hide an
# opening building.
const INITIAL_BUILDING_TYPES := ["house", "farm", "lumber", "workshop", "warehouse"]

const BUILDINGS := {
	"house": {
		"name": "民居", "cost": 12, "coin_cost": 4,
		"workers": 0, "maintenance": 0, "staffing": "passive",
		"inputs": {"food": 1}, "outputs": {}, "effects": {"housing": 4},
		"unlock_level": 0, "category": "basic", "color": Color("c98963")
	},
	"lumber": {
		"name": "伐木场", "cost": 22, "coin_cost": 6,
		"workers": 2, "maintenance": 1, "staffing": "proportional",
		"inputs": {}, "outputs": {"wood": 7}, "effects": {}, "trade_coins": BASIC_TRADE_COINS_PER_SITE,
		"unlock_level": 0, "category": "industry", "color": Color("8a5c3b")
	},
	"farm": {
		"name": "农田", "cost": 18, "coin_cost": 6,
		"workers": 2, "maintenance": 1, "staffing": "proportional",
		"inputs": {}, "outputs": {"food": 10}, "effects": {}, "trade_coins": BASIC_TRADE_COINS_PER_SITE,
		"unlock_level": 0, "category": "basic", "color": Color("b9956e")
	},
	"warehouse": {
		"name": "仓库", "cost": 30, "coin_cost": 10,
		"workers": 0, "maintenance": 1, "staffing": "passive", "requires_road": true,
		"inputs": {}, "outputs": {}, "effects": {"wood_capacity": 75, "food_capacity": 75},
		"unlock_level": 0, "category": "basic", "color": Color("7f6b52")
	},
	"workshop": {
		"name": "小工坊", "cost": 38, "coin_cost": 16,
		"workers": 3, "maintenance": 2, "staffing": "full",
		"inputs": {"wood": 4, "food": 2}, "outputs": {"coins": 10},
		"effects": {"happiness_target": 4}, "effect_cap": 12,
		"unlock_level": 0, "category": "industry", "color": Color("5e7173")
	},
	"market": {
		"name": "集市", "cost": 45, "coin_cost": 18,
		"workers": 2, "maintenance": 2, "staffing": "full",
		"inputs": {"food": 3}, "outputs": {"coins": 9}, "effects": {},
		"unlock_level": 1, "category": "industry", "color": Color("b35c48")
	},
	"fishpond": {
		"name": "鱼塘", "cost": 40, "coin_cost": 16,
		"workers": 2, "maintenance": 2, "staffing": "proportional",
		"inputs": {}, "outputs": {"food": 14}, "effects": {},
		"unlock_level": 1, "category": "industry", "color": Color("548d8a")
	},
	"clinic": {
		"name": "医馆", "cost": 52, "coin_cost": 24,
		"workers": 2, "maintenance": 3, "staffing": "full",
		"inputs": {}, "outputs": {}, "effects": {"happiness_target": 7}, "effect_cap": 14,
		"unlock_level": 3, "category": "civic", "color": Color("6f9982")
	},
	"academy": {
		"name": "书院", "cost": 68, "coin_cost": 38,
		"workers": 3, "maintenance": 4, "staffing": "full",
		"inputs": {}, "outputs": {"coins": 5},
		"effects": {"happiness_target": 4}, "effect_cap": 8,
		"unlock_level": 4, "category": "civic", "color": Color("496b7a")
	}
}

var day := 1
var wood := 100
var food := 40
var coins := 60
var population := 4
var happiness := 60
var low_happiness_days := 0
var stable_days := 0
var maintenance_debt := 0
var map_region_level := 0
var selected_type := ""
var selected_rotation_quarters := 0
var ended := ""
var failure_reason := ""
var next_id := 1
var buildings: Array[Dictionary] = []
var occupied := {}
var roads := {}
var scenery_trees_by_cell := {}
var scenery_rocks_by_cell := {}
var legacy_cleared_tree_roads := {}

var world: Node3D
var building_root: Node3D
var road_root: Node3D
var citizen_root: Node3D
var animal_root: Node3D
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
var inspector_status: Label
var inspector_body: Label
var inspector_toggle_button: Button
var inspector_demolish_button: Button
var build_buttons := {}
var road_button: Button
var region_panel: PanelContainer
var region_title: Label
var region_body
var region_unlock_button: Button
var region_panel_toggle: Button
var region_panel_collapsed := false
var bottom_panel: PanelContainer
var bottom_actions: HBoxContainer
var build_category := "basic"
var build_category_buttons := {}
var pause_button: Button
var speed_buttons := {}
var settings_button: Button
var settings_overlay: Control
var settings_panel: PanelContainer
var settings_action_buttons := {}
var background_music: Node
var music_volume_slider: HSlider
var music_volume_label: Label
var music_mute_button: Button
var help_dialog: AcceptDialog
var confirmation_dialog: ConfirmationDialog
var pending_confirm_action := ""
var selected_building_id := -1
var selected_road_cell := Vector2i(-1, -1)
var road_tool_selected := false
var end_layer: CanvasLayer
var drag_button := -1
var drag_origin := Vector2.ZERO
var drag_last := Vector2.ZERO
var drag_moved := false
var camera_target := Vector3.ZERO
var citizen_time := 0.0
var citizen_schedule_time := 0.0
var citizen_variant_bag: Array = []
var animal_species_bag: Array = []
var auto_day_elapsed := 0.0
var time_paused := false
var time_speed := 1.0
var day_settling := false

func _ready() -> void:
	create_background_music()
	create_world()
	create_ui()
	reset_game(false)
	if FileAccess.file_exists(save_path()):
		load_game(false)
	get_viewport().size_changed.connect(update_camera_projection)
	update_camera_projection()

func audio_settings_path() -> String:
	return ProjectSettings.globalize_path("res://saves/audio_settings.cfg") if OS.has_feature("editor") else "user://audio_settings.cfg"

func create_background_music() -> void:
	if is_instance_valid(background_music):
		return
	background_music = BackgroundMusicKit.new()
	background_music.name = "BackgroundMusic"
	background_music.config_path = audio_settings_path()
	add_child(background_music)

func create_world() -> void:
	world = Node3D.new()
	world.name = "RiverValley"
	add_child(world)
	building_root = Node3D.new()
	building_root.name = "Buildings"
	world.add_child(building_root)
	road_root = Node3D.new()
	road_root.name = "PlayerRoads"
	world.add_child(road_root)
	citizen_root = Node3D.new()
	citizen_root.name = "Citizens"
	world.add_child(citizen_root)
	# Decorative livestock and village dogs live in their own layer so the
	# population count and resident schedule remain strictly about people.
	animal_root = Node3D.new()
	animal_root.name = "VillageAnimals"
	world.add_child(animal_root)
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
	camera.size = CAMERA_INITIAL_SIZE
	camera_target = grid_to_world(Vector2i(10, 13))
	camera.position = camera_target + Vector3(30, 34, 31)
	world.add_child(camera)
	camera.look_at(camera_target)

	create_terrain()
	create_river_life()
	create_grid_lines()
	create_scenery()
	create_region_visuals()

func create_terrain() -> void:
	var rendered_extent := RENDER_GRID_SIZE * TILE_SIZE
	var base := mesh_box(Vector3(rendered_extent + 2.0, 0.6, rendered_extent + 2.0), Color("405345"))
	base.name = "NaturalBufferFoundation"
	base.position.y = -0.38
	world.add_child(base)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var extent := GRID_SIZE * TILE_SIZE * 0.5
	for z in range(-NATURAL_BUFFER_CELLS, GRID_SIZE + NATURAL_BUFFER_CELLS):
		for x in range(-NATURAL_BUFFER_CELLS, GRID_SIZE + NATURAL_BUFFER_CELLS):
			var cell := Vector2i(x, z)
			var region := region_level_for_cell(cell)
			var inside_playable_map := is_playable_cell(cell)
			var color := Color("3f7d8b") if is_water_cell(cell) else (
				terrain_color_for_cell(cell, region) if inside_playable_map else outer_terrain_color_for_cell(cell)
			)
			var x0 := -extent + x * TILE_SIZE
			var x1 := x0 + TILE_SIZE
			var z0 := -extent + z * TILE_SIZE
			var z1 := z0 + TILE_SIZE
			var y00 := outer_terrain_height_for_vertex(x, z)
			var y10 := outer_terrain_height_for_vertex(x + 1, z)
			var y11 := outer_terrain_height_for_vertex(x + 1, z + 1)
			var y01 := outer_terrain_height_for_vertex(x, z + 1)
			if is_water_cell(cell):
				# The channel remains level through the natural map buffer.
				y00 = 0.15
				y10 = 0.15
				y11 = 0.15
				y01 = 0.15
			var first_vertex := vertices.size()
			vertices.append_array(PackedVector3Array([
				Vector3(x0, y00, z0), Vector3(x1, y10, z0),
				Vector3(x1, y11, z1), Vector3(x0, y01, z1)
			]))
			normals.append_array(PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]))
			# UV coordinates span the entire map. Adjacent logical cells therefore
			# sample adjacent parts of the atlas instead of restarting it per tile.
			var u0 := float(x + NATURAL_BUFFER_CELLS) / RENDER_GRID_SIZE
			var u1 := float(x + NATURAL_BUFFER_CELLS + 1) / RENDER_GRID_SIZE
			var v0 := float(z + NATURAL_BUFFER_CELLS) / RENDER_GRID_SIZE
			var v1 := float(z + NATURAL_BUFFER_CELLS + 1) / RENDER_GRID_SIZE
			uvs.append_array(PackedVector2Array([
				Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)
			]))
			colors.append_array(PackedColorArray([color, color, color, color]))
			indices.append_array(PackedInt32Array([
				first_vertex, first_vertex + 1, first_vertex + 2,
				first_vertex, first_vertex + 2, first_vertex + 3
			]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var terrain_material := ShaderMaterial.new()
	terrain_material.shader = OuterGrassShader
	terrain_material.set_shader_parameter("playable_half_extent", extent)
	terrain_mesh.surface_set_material(0, terrain_material)
	var terrain := MeshInstance3D.new()
	terrain.name = "ContinuousTerrain"
	terrain.mesh = terrain_mesh
	terrain.set_meta("playable_grid_size", GRID_SIZE)
	terrain.set_meta("natural_buffer_cells", NATURAL_BUFFER_CELLS)
	terrain.set_meta("outer_surface", "continuous_world_grass")
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(terrain)

func create_grid_lines() -> void:
	var immediate := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.34, 0.47, 0.36, 0.20)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var extent := GRID_SIZE * TILE_SIZE * 0.5
	for i in range(GRID_SIZE + 1):
		var p := -extent + i * TILE_SIZE
		for j in range(GRID_SIZE):
			var q := -extent + j * TILE_SIZE
			# Omit edges touching water, including the mid-channel divider.
			# Land keeps its build grid; no line is painted onto the river.
			if not is_water_cell(Vector2i(i - 1, j)) and not is_water_cell(Vector2i(i, j)):
				immediate.surface_add_vertex(Vector3(p, 0.18, q))
				immediate.surface_add_vertex(Vector3(p, 0.18, q + TILE_SIZE))
			if not is_water_cell(Vector2i(j, i - 1)) and not is_water_cell(Vector2i(j, i)):
				immediate.surface_add_vertex(Vector3(q, 0.18, p))
				immediate.surface_add_vertex(Vector3(q + TILE_SIZE, 0.18, p))
	immediate.surface_end()
	var lines := MeshInstance3D.new()
	lines.name = "LandGridLines"
	lines.mesh = immediate
	world.add_child(lines)

func create_river_life() -> void:
	var rivers := Node3D.new()
	rivers.name = "RiverLife"
	world.add_child(rivers)
	var main_water := RiverWaterKit.create_surface(Vector2(2.0 * TILE_SIZE, RENDER_GRID_SIZE * TILE_SIZE))
	main_water.name = "MainRiverSurface"
	main_water.position = Vector3(grid_to_world(Vector2i(2, 0)).x + TILE_SIZE * 0.5, 0.175, 0.0)
	rivers.add_child(main_water)
	var branch_length := (24 + NATURAL_BUFFER_CELLS) * TILE_SIZE
	var branch_water := RiverWaterKit.create_surface(Vector2(2.0 * TILE_SIZE, branch_length))
	branch_water.name = "EastRiverSurface"
	branch_water.position = Vector3(grid_to_world(Vector2i(32, 0)).x + TILE_SIZE * 0.5, 0.175, -branch_length * 0.5)
	rivers.add_child(branch_water)
	# Three small boats keep to separate stretches. Each turn fits inside the
	# channel, and the route ends leave clearance from the low stone bridges.
	var routes := [
		{"cell": Vector2i(2, 4), "length": 7.0, "phase": 0.12},
		{"cell": Vector2i(2, 16), "length": 13.0, "phase": 0.34},
		{"cell": Vector2i(32, 18), "length": 12.0, "phase": 0.58},
	]
	for i in range(routes.size()):
		var boat := RiverBoatKit.new()
		boat.name = "RiverBoat_%d" % i
		var center := grid_to_world(routes[i].cell) + Vector3(TILE_SIZE * 0.5, 0.175, 0)
		boat.configure(center, routes[i].length, 0.65, 0.38, routes[i].phase)
		boat.set_meta("decorative", true)
		rivers.add_child(boat)

func terrain_color_for_cell(_cell: Vector2i, region: int) -> Color:
	if region == 1:
		return Color("718560")
	if region == 2:
		return Color("587357")
	if region == 3:
		return Color("707a61")
	if region == 4:
		return Color("788963")
	if region == 5:
		return Color("62725b")
	if region == 6:
		return Color("788269")
	return Color("5e7857")

func is_playable_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_SIZE and cell.y >= 0 and cell.y < GRID_SIZE

func outer_terrain_height_for_vertex(grid_x: float, grid_z: float) -> float:
	var outside_x := maxf(-grid_x, grid_x - GRID_SIZE)
	var outside_z := maxf(-grid_z, grid_z - GRID_SIZE)
	var distance_outside := maxf(0.0, maxf(outside_x, outside_z))
	if distance_outside <= 0.0:
		return 0.15
	var fade := clampf(distance_outside / NATURAL_BUFFER_CELLS, 0.0, 1.0)
	var rolling := (sin(grid_x * 0.57 + grid_z * 0.21) + cos(grid_z * 0.43 - grid_x * 0.18)) * 0.16 * fade
	return 0.15 + pow(fade, 1.55) * 1.85 + rolling

func outer_terrain_color_for_cell(_cell: Vector2i) -> Color:
	# Keep a uniform undercoat at every tile; the material supplies continuous
	# grass variation in world coordinates instead of one flat color per cell.
	return Color("5a724d")

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
				if region_level_for_cell(cell) != level or is_water_cell(cell):
					continue
				locked_cells.append(cell)
		var veil_mesh := BoxMesh.new()
		veil_mesh.size = Vector3(TILE_SIZE, 0.025, TILE_SIZE)
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
	create_outer_natural_buffer()
	var road_color := Color("8d6a4f")
	var road_start := grid_to_world(Vector2i(10, 4))
	var road_end := grid_to_world(Vector2i(10, 15))
	var road := mesh_box(Vector3(1.1, 0.06, road_start.distance_to(road_end) + TILE_SIZE), road_color)
	road.name = "VillageRoad"
	# Keep the authored street at the same deck height as player roads.  The
	# street is a single continuous mesh, so matching its top plane avoids a
	# raised lip/z-fighting line when a player road meets its edge.
	road.position = (road_start + road_end) * 0.5 + Vector3(0, 0.225, 0)
	world.add_child(road)
	var bridge := RealisticKit.create_bridge()
	bridge.name = "RiverBridge"
	bridge.scale.x = TILE_SIZE / 2.0
	bridge.position = Vector3(grid_to_world(Vector2i(2, 9)).x + TILE_SIZE * 0.5, 0.34, grid_to_world(Vector2i(2, 9)).z)
	bridge.set_meta("npc_bridge_id", "main_river")
	world.add_child(bridge)
	var east_bridge := RealisticKit.create_bridge()
	east_bridge.name = "EastBranchBridge"
	east_bridge.scale.x = TILE_SIZE / 2.0
	east_bridge.position = Vector3(grid_to_world(Vector2i(32, 12)).x + TILE_SIZE * 0.5, 0.34, grid_to_world(Vector2i(32, 12)).z)
	east_bridge.set_meta("npc_bridge_id", "east_branch")
	world.add_child(east_bridge)
	var tree_cells := authored_tree_cells()
	for index in range(tree_cells.size()):
		var cell: Vector2i = tree_cells[index]
		var offset := Vector3(((index * 37) % 9 - 4) * 0.09, 0, ((index * 23) % 7 - 3) * 0.10)
		create_tree(grid_to_world(cell) + offset, index)
	for index in range(7):
		var rock := RealisticKit.create_rock(index)
		var rock_cell := Vector2i(0 if index % 2 == 0 else 19, 2 + index * 2)
		rock.position = grid_to_world(rock_cell) + Vector3(0, 0.16, 0)
		rock.rotation.y = index * 0.73
		rock.set_meta("rock_cell", rock_cell)
		rock.set_meta("road_clearable", true)
		if not scenery_rocks_by_cell.has(rock_cell):
			scenery_rocks_by_cell[rock_cell] = []
		scenery_rocks_by_cell[rock_cell].append(rock)
		rock.visible = not roads.has(rock_cell)
		world.add_child(rock)
	for z in [5, 8, 11, 14]:
		var lantern := RealisticKit.create_lantern()
		lantern.position = grid_to_world(Vector2i(10, z)) + Vector3(0.72, 0.2, 0)
		lantern.rotation.y = PI if z % 2 == 0 else 0.0
		world.add_child(lantern)
	for i in range(18):
		var hill_height := 4.0 + (i % 2) * 1.0
		var hill_position := Vector3(-62.0 + i * 7.25, 0.0, -63.0 + (i % 4) * 1.35)
		var hill_grid := Vector2(hill_position.x / TILE_SIZE + GRID_SIZE * 0.5 - 0.5, hill_position.z / TILE_SIZE + GRID_SIZE * 0.5 - 0.5)
		# Leave both river outlets clear of the broad bases of the old hills.
		if is_outer_river_corridor(hill_grid, 2.3):
			continue
		hill_position.y = mountain_ground_height(hill_position.x, hill_position.z)
		var hill := DetailedMountainKit.create_mountain(hill_position, Vector2(3.1 + (i % 3) * 0.26, 2.65 + (i % 2) * 0.20), hill_height, i, mountain_ground_height)
		hill.name = "BoundaryHill_%02d" % i
		world.add_child(hill)

func authored_tree_cells() -> Array[Vector2i]:
	# Placement and save validation use the same authored tree cells even when
	# validation is called before scenery nodes have been instantiated.
	return [
		Vector2i(16, 2), Vector2i(18, 1), Vector2i(17, 4), Vector2i(19, 5),
		Vector2i(16, 7), Vector2i(18, 8), Vector2i(17, 10), Vector2i(19, 11),
		Vector2i(16, 13), Vector2i(18, 14), Vector2i(17, 17), Vector2i(19, 18),
		Vector2i(27, 2), Vector2i(29, 4), Vector2i(28, 7), Vector2i(27, 11), Vector2i(29, 15), Vector2i(28, 18),
		Vector2i(4, 23), Vector2i(16, 26), Vector2i(3, 28), Vector2i(21, 24), Vector2i(26, 28),
		Vector2i(6, 33), Vector2i(13, 37), Vector2i(24, 34), Vector2i(28, 42), Vector2i(3, 46),
		Vector2i(45, 3), Vector2i(46, 8), Vector2i(44, 15), Vector2i(47, 22),
		Vector2i(33, 29), Vector2i(45, 32), Vector2i(34, 41), Vector2i(43, 46)
	]

func create_outer_natural_buffer() -> void:
	var outer_root := Node3D.new()
	outer_root.name = "OuterNaturalBuffer"
	outer_root.set_meta("non_editable", true)
	outer_root.set_meta("buffer_cells", NATURAL_BUFFER_CELLS)
	outer_root.set_meta("playable_grid_size", GRID_SIZE)
	world.add_child(outer_root)
	# Three staggered belts populate the whole expanded apron, including its
	# corners. Density stays sparse enough for the richer shared tree meshes;
	# hills and broken stone groups fill the spaces between woodland clusters.
	for band in range(3):
		var band_depth := 4.0 + band * 11.0
		var band_span := GRID_SIZE + (band_depth + 3.0) * 2.0
		var tree_count := ceili(band_span / 5.4)
		for side in range(4):
			for index in range(tree_count):
				var variation := posmod(index * 13 + side * 17 + band * 7, 19)
				var along := -band_depth - 2.0 + (index + 0.35) * band_span / tree_count + sin(index * 1.73 + side) * 1.25
				var depth := band_depth + variation * 0.34
				var grid_position := outer_side_grid_position(side, along, depth)
				if is_outer_river_corridor(grid_position, 2.3):
					continue
				var tree := RealisticKit.create_tree(index + side + band)
				if tree == null:
					continue
				tree.name = "BufferTree_%d_%d_%02d" % [band, side, index]
				tree.position = outer_scenery_position(grid_position.x, grid_position.y)
				tree.rotation.y = fposmod(index * 1.19 + side * 0.71 + band, TAU)
				var scale_value := 0.72 + (variation % 7) * 0.075
				tree.scale *= Vector3(scale_value, scale_value * (0.94 + (index % 3) * 0.04), scale_value)
				tree.set_meta("non_editable_scenery", true)
				tree.set_meta("buffer_band", band)
				outer_root.add_child(tree)
			var rock_count := ceili(band_span / 13.0)
			for index in range(rock_count):
				var along := -band_depth - 1.0 + (index + 0.62) * band_span / rock_count
				var depth := band_depth + 1.8 + posmod(index * 5 + side * 3, 9) * 0.52
				var grid_position := outer_side_grid_position(side, along, depth)
				if is_outer_river_corridor(grid_position, 2.5):
					continue
				var rock := RealisticKit.create_rock(index + side)
				if rock == null:
					continue
				rock.name = "BufferRock_%d_%d_%02d" % [band, side, index]
				rock.position = outer_scenery_position(grid_position.x, grid_position.y)
				rock.rotation.y = fposmod(index * 0.83 + side * 1.37, TAU)
				var scale_value := 0.76 + posmod(index * 3 + side, 5) * 0.15
				rock.scale *= Vector3(scale_value * 1.22, scale_value, scale_value * 0.87)
				rock.set_meta("non_editable_scenery", true)
				rock.set_meta("buffer_band", band)
				outer_root.add_child(rock)
	# Low irregular ridges span both the middle and distant belts, rather than
	# leaving the newly exposed ground empty behind the previous perimeter.
	for band in range(2):
		var depth_base := 17.0 if band == 0 else float(NATURAL_BUFFER_CELLS) - 5.0
		var span := GRID_SIZE + depth_base * 2.0
		var count := ceili(span / (16.0 if band == 0 else 12.0))
		for side in range(4):
			for index in range(count):
				var along := -depth_base + (index + 0.5) * span / count
				var depth := depth_base + sin(index * 1.91 + side * 0.8) * 1.4
				var grid_position := outer_side_grid_position(side, along, depth)
				if is_outer_river_corridor(grid_position, 3.2):
					continue
				var height := 3.2 + posmod(index * 5 + side + band, 5) * 0.62
				var bottom_radius := 3.2 + posmod(index + side * 2, 4) * 0.42
				var ridge := DetailedMountainKit.create_mountain(outer_scenery_position(grid_position.x, grid_position.y), Vector2(bottom_radius, bottom_radius * 0.83), height, index + side * 17 + band * 31, mountain_ground_height)
				ridge.name = "NaturalRidge_%d_%d_%02d" % [band, side, index]
				ridge.set_meta("non_editable_scenery", true)
				outer_root.add_child(ridge)

func mountain_ground_height(world_x: float, world_z: float) -> float:
	# Match the actual two triangles of ContinuousTerrain, not an analytic
	# center-height approximation that can leave wide mountain feet hovering.
	var grid_x := world_x / TILE_SIZE + GRID_SIZE * 0.5
	var grid_z := world_z / TILE_SIZE + GRID_SIZE * 0.5
	var cell_x := floori(grid_x)
	var cell_z := floori(grid_z)
	var u := grid_x - cell_x
	var v := grid_z - cell_z
	var y00 := outer_terrain_height_for_vertex(cell_x, cell_z)
	var y10 := outer_terrain_height_for_vertex(cell_x + 1, cell_z)
	var y11 := outer_terrain_height_for_vertex(cell_x + 1, cell_z + 1)
	var y01 := outer_terrain_height_for_vertex(cell_x, cell_z + 1)
	if u >= v:
		return y00 * (1.0 - u) + y10 * (u - v) + y11 * v
	return y00 * (1.0 - v) + y11 * u + y01 * (v - u)

func outer_side_grid_position(side: int, along: float, depth: float) -> Vector2:
	match side:
		0: return Vector2(along, -depth)
		1: return Vector2(along, GRID_SIZE - 1 + depth)
		2: return Vector2(-depth, along)
		_: return Vector2(GRID_SIZE - 1 + depth, along)

func is_outer_river_corridor(grid_position: Vector2, padding: float) -> bool:
	# Main river crosses both map edges; the eastern branch exits only north.
	if absf(grid_position.x - 2.5) < 1.0 + padding:
		return true
	return grid_position.y < 24.0 and absf(grid_position.x - 32.5) < 1.0 + padding

func outer_scenery_position(grid_x: float, grid_z: float) -> Vector3:
	var half := GRID_SIZE * 0.5
	return Vector3(
		(grid_x - half + 0.5) * TILE_SIZE,
		outer_terrain_height_for_vertex(grid_x + 0.5, grid_z + 0.5),
		(grid_z - half + 0.5) * TILE_SIZE
	)

func create_tree(pos: Vector3, variant := 0) -> void:
	var tree := RealisticKit.create_tree(variant)
	if tree == null:
		return
	var forest_cell := world_to_grid(pos)
	tree.name = "SceneryTree_%d_%d_%02d" % [forest_cell.x, forest_cell.y, variant]
	tree.position = pos
	tree.rotation.y = variant * 0.61
	tree.set_meta("forest_cell", forest_cell)
	tree.set_meta("road_clearable", false)
	tree.visible = not (roads.has(forest_cell) and legacy_cleared_tree_roads.has(forest_cell))
	if not scenery_trees_by_cell.has(forest_cell):
		scenery_trees_by_cell[forest_cell] = []
	var trees_in_cell: Array = scenery_trees_by_cell[forest_cell]
	trees_in_cell.append(tree)
	world.add_child(tree)

func create_citizen(index: int, forced_variant := -1) -> Node3D:
	# Keep the carrier node on the ground and apply the small walk bob only to
	# the visible model. This keeps the actor's full movement speed measurable
	# and constant in world space.
	var citizen := Node3D.new()
	var variant := citizen_variant_for_index(index) if forced_variant < 0 else posmod(forced_variant, CITIZEN_KINDS.size())
	var visual := RealisticKit.create_citizen_variant(index, variant)
	citizen.name = "Citizen_%03d" % index
	if visual:
		visual.name = "Visual"
		visual.scale = visual.scale * NPC_VISUAL_SCALE
		visual.set_meta("gameplay_visual_scale", NPC_VISUAL_SCALE)
		visual.set_meta("rest_position", visual.position)
		visual.set_meta("rest_rotation", visual.rotation)
		visual.set_meta("walk_animation_offset", fposmod(float(index) * 0.31, 1.0))
		configure_citizen_authored_walk(visual)
		citizen.add_child(visual)
	var base_cell := Vector2i(7 + index % 7, 6 + floori(index / 7.0) % 8)
	var base := grid_to_world(base_cell) + Vector3(0, 0.18, 0)
	citizen.position = base
	citizen.set_meta("base_position", base)
	citizen.set_meta("phase", float(index) * 1.71)
	citizen.set_meta("citizen_index", index)
	citizen.set_meta("citizen_kind", CITIZEN_KINDS[variant])
	citizen.set_meta("home_position", base)
	citizen.set_meta("schedule_state", "居家")
	citizen.set_meta("schedule_activity", "起床")
	citizen.set_meta("schedule_target", base)
	citizen.set_meta("schedule_slot", 0)
	citizen.set_meta("schedule_role", citizen_role_for_index(index))
	# Residents are presentation-only. Every resident uses the same real-time
	# walking speed; roles and citizen indices only choose destinations.
	citizen.set_meta("schedule_speed", NPC_MOVE_SPEED)
	citizen.set_meta("schedule_velocity", Vector3.ZERO)
	citizen.set_meta("bob_strength", 1.0)
	citizen.set_meta("walk_distance", 0.0)
	citizen.set_meta("walk_animation_active", false)
	citizen.set_meta("ground_height", base.y)
	return citizen

func citizen_kind_for_index(index: int) -> String:
	return CITIZEN_KINDS[citizen_variant_for_index(index)]

func citizen_variant_for_index(index: int) -> int:
	if citizen_variant_bag.is_empty():
		prepare_village_life_variants()
	return int(citizen_variant_bag[posmod(index, citizen_variant_bag.size())])

func prepare_village_life_variants() -> void:
	# Draw once per new village, then preserve identities across daily updates.
	# Six of every ten residents retain the original straw-hat appearance. The
	# Other styles rotate through the remaining slots across a full village.
	var other_variants := [1, 2, 3, 4, 5, 6, 7]
	other_variants.shuffle()
	citizen_variant_bag.clear()
	for group in range(5):
		var accents: Array = []
		for offset in range(4):
			accents.append(other_variants[posmod(group + offset, other_variants.size())])
		accents.shuffle()
		if group == 0:
			# The four-person opening always shows two original villagers alongside
			# two different variants, while their order still changes with each game.
			var opening: Array = [0, 0, accents[0], accents[1]]
			opening.shuffle()
			citizen_variant_bag.append_array(opening)
			var remainder: Array = [0, 0, 0, 0, accents[2], accents[3]]
			remainder.shuffle()
			citizen_variant_bag.append_array(remainder)
		else:
			var residents: Array = [0, 0, 0, 0, 0, 0]
			residents.append_array(accents)
			residents.shuffle()
			citizen_variant_bag.append_array(residents)
	animal_species_bag = ANIMAL_SPECIES.duplicate()
	animal_species_bag.shuffle()

func animal_species_for_index(index: int) -> String:
	if animal_species_bag.is_empty():
		prepare_village_life_variants()
	return str(animal_species_bag[posmod(index, animal_species_bag.size())])

func animal_spawn_cell(index: int) -> Vector2i:
	var candidates := [
		Vector2i(7, 11), Vector2i(11, 11), Vector2i(13, 12), Vector2i(7, 14),
		Vector2i(11, 14), Vector2i(14, 15), Vector2i(6, 12), Vector2i(15, 11),
		Vector2i(9, 14), Vector2i(13, 9), Vector2i(6, 15), Vector2i(16, 13)
	]
	candidates.shuffle()
	var start := posmod(index, candidates.size())
	for offset in range(candidates.size()):
		var cell: Vector2i = candidates[posmod(start + offset, candidates.size())]
		if animal_cell_available(cell):
			return cell
	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell := Vector2i(x, z)
			if animal_cell_available(cell):
				return cell
	return Vector2i(-1, -1)

func animal_cell_available(cell: Vector2i) -> bool:
	if not is_playable_cell(cell) or region_level_for_cell(cell) > map_region_level or is_water_cell(cell) or is_reserved_forest(cell) or occupied.has(cell):
		return false
	# Scattered trees also occur outside reserved forest belts. Construction
	# must not relocate an animal into one of those apparently empty cells.
	return not has_scenery_tree(cell) or (roads.has(cell) and legacy_cleared_tree_roads.has(cell))

func animal_route_for_index(index: int, start_cell: Vector2i) -> Array[Vector3]:
	# Short village-yard loops keep the animals close to the settlement. Every
	# target is a grid centre so water and locked regions still use the same safe
	# navigation code as residents.
	var offsets := [
		Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)
	]
	var result: Array[Vector3] = []
	var phase := posmod(index * 3, offsets.size())
	for step in range(4):
		var offset: Vector2i = offsets[posmod(phase + step * 2, offsets.size())]
		var cell := start_cell + offset
		if not animal_cell_available(cell):
			cell = start_cell
		result.append(grid_to_world(cell) + Vector3(0, 0.18, 0))
	return result

func create_animal(index: int) -> Node3D:
	var species := animal_species_for_index(index)
	var animal := RealisticKit.create_animal(species, index)
	if animal == null:
		animal = Node3D.new()
	animal.name = "Animal_%s_%03d" % [species, index]
	animal.scale *= 0.48
	var spawn_cell := animal_spawn_cell(index)
	if spawn_cell.x < 0:
		animal.free()
		return null
	var spawn := grid_to_world(spawn_cell) + Vector3(0, 0.18, 0)
	animal.position = spawn
	animal.set_meta("animal_index", index)
	animal.set_meta("animal_species", species)
	animal.set_meta("animal_anchor_cell", spawn_cell)
	animal.set_meta("animal_route", animal_route_for_index(index, spawn_cell))
	animal.set_meta("animal_route_index", 0)
	animal.set_meta("animal_navigation_path", [])
	animal.set_meta("animal_navigation_index", 0)
	animal.set_meta("animal_target", spawn)
	animal.set_meta("animal_distance", 0.0)
	animal.set_meta("animal_ground_height", spawn.y)
	animal_set_target(animal)
	return animal

func update_animals(preserve_existing := true) -> void:
	if animal_root == null:
		return
	var desired_count := mini(ANIMAL_MAX_COUNT, 4 + map_region_level)
	var existing := {}
	if not preserve_existing:
		for child in animal_root.get_children():
			child.queue_free()
	for child in animal_root.get_children():
		if not child is Node3D or child.is_queued_for_deletion():
			continue
		var index := int(child.get_meta("animal_index", -1))
		if index < 0 or index >= desired_count or existing.has(index):
			child.queue_free()
			continue
		existing[index] = child
	for index in range(desired_count):
		if not existing.has(index):
			var animal := create_animal(index)
			if animal == null:
				continue
			animal_root.add_child(animal)
			animal.reset_physics_interpolation()

func animal_set_target(animal: Node3D) -> void:
	var route: Array = animal.get_meta("animal_route", [])
	if route.is_empty():
		return
	var route_index := posmod(int(animal.get_meta("animal_route_index", 0)), route.size())
	for attempt in range(route.size()):
		var next_index := posmod(route_index + attempt, route.size())
		var target: Vector3 = route[next_index]
		if not animal_cell_available(world_to_grid(target)):
			continue
		var navigation := citizen_navigation_path(animal.position, target)
		if navigation.is_empty():
			continue
		var safe_path := true
		for waypoint in navigation:
			var waypoint_cell := world_to_grid(waypoint)
			if not animal_cell_available(waypoint_cell) and not is_npc_bridge_cell(waypoint_cell):
				safe_path = false
				break
		if not safe_path:
			continue
		# Layout changes can happen halfway along an edge. Return through the
		# current clear cell's centre before turning, never diagonally across a
		# neighboring pond, courtyard wall or another occupied corner.
		var centre := grid_to_world(world_to_grid(animal.position)) + Vector3(0, 0.18, 0)
		if Vector2(animal.position.x - centre.x, animal.position.z - centre.z).length() > 0.001:
			navigation.push_front(centre)
		animal.set_meta("animal_route_index", next_index)
		animal.set_meta("animal_navigation_path", navigation)
		animal.set_meta("animal_navigation_index", 0)
		animal.set_meta("animal_target", navigation[0])
		return
	# A completely enclosed yard has no safe destination. Keep this bounded;
	# the next layout refresh can restore a route without recursion or a warp.
	animal.set_meta("animal_navigation_path", [])
	animal.set_meta("animal_navigation_index", 0)
	animal.set_meta("animal_target", animal.position)

func animal_advance_target(animal: Node3D) -> void:
	var navigation: Array = animal.get_meta("animal_navigation_path", [])
	var next_navigation := int(animal.get_meta("animal_navigation_index", 0)) + 1
	if next_navigation < navigation.size():
		animal.set_meta("animal_navigation_index", next_navigation)
		animal.set_meta("animal_target", navigation[next_navigation])
		return
	var route: Array = animal.get_meta("animal_route", [])
	if route.is_empty():
		return
	animal.set_meta("animal_route_index", posmod(int(animal.get_meta("animal_route_index", 0)) + 1, route.size()))
	animal_set_target(animal)

func move_animals(delta: float) -> void:
	if animal_root == null:
		return
	var movement_delta := maxf(delta, 0.0)
	for child in animal_root.get_children():
		if not child is Node3D or child.is_queued_for_deletion() or not child.visible:
			continue
		var animal := child as Node3D
		var travel_budget := ANIMAL_MOVE_SPEED * movement_delta
		var current_planar := Vector3(animal.position.x, 0, animal.position.z)
		var traveled := 0.0
		var transitions := 0
		var last_direction := Vector3.ZERO
		while travel_budget > 0.00001 and transitions < 16:
			var target: Vector3 = animal.get_meta("animal_target", animal.position)
			var target_planar := Vector3(target.x, 0, target.z)
			var remaining := target_planar - current_planar
			if remaining.length() <= 0.001:
				animal.position = Vector3(current_planar.x, animal.position.y, current_planar.z)
				animal_advance_target(animal)
				transitions += 1
				continue
			var direction := remaining.normalized()
			var travel := minf(travel_budget, remaining.length())
			current_planar += direction * travel
			travel_budget -= travel
			traveled += travel
			last_direction = direction
			if travel >= remaining.length() - 0.00001:
				animal.position = Vector3(current_planar.x, animal.position.y, current_planar.z)
				animal_advance_target(animal)
				transitions += 1
				continue
			break
		if traveled > 0.0:
			# Match the current path segment immediately. Turning slowly while
			# already traveling along the next grid edge makes the animal slide
			# sideways; physics interpolation handles the rendered frame blend.
			animal.rotation.y = atan2(last_direction.x, last_direction.z)
		var ground_height := citizen_surface_height(current_planar)
		animal.position = Vector3(current_planar.x, ground_height, current_planar.z)
		var distance := float(animal.get_meta("animal_distance", 0.0)) + traveled
		animal.set_meta("animal_distance", distance)
		animal.set_meta("animal_last_travel_distance", traveled)
		AnimalKit.animate_walk(animal, distance)

func refresh_animal_routes() -> void:
	if animal_root == null:
		return
	for child in animal_root.get_children():
		if not child is Node3D or child.is_queued_for_deletion():
			continue
		var index := int(child.get_meta("animal_index", 0))
		var current_cell := world_to_grid(child.position)
		if not animal_cell_available(current_cell) and not is_npc_bridge_cell(current_cell):
			# Construction can cover the animal's present tile. Resolve that one
			# placement-time overlap before rendering the building; walking out
			# would visibly cross the new pond or its enclosing wall.
			var nearest := Vector2i(-1, -1)
			var nearest_distance := INF
			for z in range(GRID_SIZE):
				for x in range(GRID_SIZE):
					var candidate := Vector2i(x, z)
					if not animal_cell_available(candidate):
						continue
					var distance := grid_to_world(candidate).distance_squared_to(child.position)
					if distance < nearest_distance:
						nearest_distance = distance
						nearest = candidate
			if nearest.x < 0:
				child.visible = false
				child.set_meta("animal_navigation_path", [])
				child.set_meta("animal_route", [])
				child.set_meta("animal_target", child.position)
				continue
			current_cell = nearest
			child.position = grid_to_world(current_cell) + Vector3(0, 0.18, 0)
			child.set_meta("animal_ground_height", 0.18)
			child.reset_physics_interpolation()
		child.visible = true
		child.set_meta("animal_anchor_cell", current_cell)
		child.set_meta("animal_route", animal_route_for_index(index, current_cell))
		child.set_meta("animal_route_index", 0)
		animal_set_target(child)

func update_citizens(preserve_existing := true) -> void:
	var desired_count := mini(population, 50)
	var existing := {}
	if not preserve_existing:
		for child in citizen_root.get_children():
			child.queue_free()
	for child in citizen_root.get_children():
		if not child is Node3D or child.is_queued_for_deletion():
			continue
		var index := int(child.get_meta("citizen_index", -1))
		if index < 0 or index >= desired_count or existing.has(index):
			child.queue_free()
			continue
		# A daily settlement tick updates a resident's assignment, but keeps the
		# same node and transform so there is no visible jump back to a spawn cell.
		child.set_meta("schedule_role", citizen_role_for_index(index))
		existing[index] = child
	for index in range(desired_count):
		if not existing.has(index):
			var citizen := create_citizen(index)
			citizen_root.add_child(citizen)
			# The node starts at its authored position; do not interpolate from the
			# origin when it first enters the running scene.
			citizen.reset_physics_interpolation()
			existing[index] = citizen
	update_citizen_schedules()
	update_animals(preserve_existing)

func _process(delta: float) -> void:
	# Large render-frame gaps must not jump the walk cycle forward in one burst.
	var presentation_delta := minf(maxf(delta, 0.0), 0.10)
	citizen_time += presentation_delta
	# Resident routines are a presentation layer. They keep using real time while
	# the economy is paused, settling a day, running faster, or showing an ending.
	citizen_schedule_time = fposmod(citizen_schedule_time + presentation_delta / NPC_SCHEDULE_SECONDS, 1.0)
	update_auto_time(delta)

func _physics_process(delta: float) -> void:
	# Use one fixed presentation step even if the renderer stalls and Godot
	# reports a larger catch-up delta. This prevents a single visible sprint.
	move_citizens(NPC_PHYSICS_STEP)
	move_animals(ANIMAL_PHYSICS_STEP)

func citizen_role_for_index(index: int) -> String:
	# Jobs only choose a resident's presentation destination and activity label.
	# Movement remains on the shared real-time route at NPC_MOVE_SPEED.
	var roles := ["farm", "fishpond", "lumber", "workshop", "market", "clinic", "academy"]
	for offset in range(roles.size()):
		var role: String = roles[posmod(index + offset, roles.size())]
		if building_count(role) > 0:
			return role
	return roles[posmod(index, roles.size())]

func citizen_home_position(index: int) -> Vector3:
	var houses: Array[Dictionary] = []
	for record in buildings:
		if str(record.type) == "house":
			houses.append(record)
	if houses.is_empty():
		return grid_to_world(Vector2i(8 + index % 4, 8 + floori(index / 4.0))) + Vector3(0, 0.18, 0)
	var record: Dictionary = houses[index % houses.size()]
	return citizen_building_entrance(record)

func citizen_building_entrance(record: Dictionary) -> Vector3:
	var model: Node3D = record.node
	var front := model.global_basis.z.normalized()
	var door := model.find_child("Door", true, false) as Node3D
	if door:
		# Both the real doorway and its approach follow the placed orientation.
		return citizen_root.to_local(door.global_position + front * 0.26 + Vector3.UP * 0.02)
	return citizen_root.to_local(model.global_position + front * (record_base_footprint(record).y * TILE_SIZE * 0.5 + 0.1) + Vector3.UP * 0.18)

func citizen_work_position(role: String, index: int) -> Vector3:
	var matches: Array[Dictionary] = []
	for record in buildings:
		if str(record.type) == role:
			matches.append(record)
	if not matches.is_empty():
		var record: Dictionary = matches[index % matches.size()]
		return citizen_building_entrance(record)
	# Without a real workplace, stay near home instead of walking toward a
	# distant locked-area fallback point.
	return citizen_home_position(index) + Vector3(float(index % 3 - 1) * 0.65, 0.0, 1.0)

func citizen_schedule_target(state: String, role: String, index: int, home: Vector3) -> Vector3:
	match state:
		"居家", "回家":
			return home
		"通勤", "工作":
			return citizen_work_position(role, index)
		"用餐":
			for record in buildings:
				if str(record.type) == "warehouse":
					return citizen_building_entrance(record)
			return grid_to_world(Vector2i(10, 10)) + Vector3(0, 0.18, 0)
		"散步":
			return grid_to_world(Vector2i(10, 7 + index % 8)) + Vector3(0, 0.18, 0)
	return home

func is_npc_bridge_cell(cell: Vector2i) -> bool:
	for bridge in NPC_BRIDGES:
		if cell.y == int(bridge.row) and cell.x >= int(bridge.water_min_x) and cell.x <= int(bridge.water_max_x):
			return true
	return false

func is_npc_bridge_access_cell(cell: Vector2i) -> bool:
	for bridge in NPC_BRIDGES:
		if cell.y != int(bridge.row):
			continue
		if cell.x == int(bridge.water_min_x) - 1 or cell.x == int(bridge.water_max_x) + 1:
			return true
	return false

func citizen_route_crosses_bridge(start: Vector2i, goal: Vector2i, bridge: Dictionary) -> bool:
	var left_bank := int(bridge.water_min_x) - 1
	var right_bank := int(bridge.water_max_x) + 1
	var opposite_banks := (start.x <= left_bank and goal.x >= right_bank) or (goal.x <= left_bank and start.x >= right_bank)
	if not opposite_banks:
		return false
	# The east branch ends at row 24. Two destinations south of that point can
	# walk around the headwater without crossing any river surface.
	return start.y < int(bridge.river_end_row) or goal.y < int(bridge.river_end_row)

func citizen_navigation_cell_walkable(cell: Vector2i, start: Vector2i, goal: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= GRID_SIZE or cell.y < 0 or cell.y >= GRID_SIZE:
		return false
	if cell != start and cell != goal and region_level_for_cell(cell) > map_region_level:
		return false
	if is_water_cell(cell):
		return is_npc_bridge_cell(cell)
	if has_scenery_tree(cell) and not (roads.has(cell) and legacy_cleared_tree_roads.has(cell)):
		return false
	if cell != start and cell != goal and occupied.has(cell):
		return false
	return true

func citizen_grid_path_unforced(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if start == goal:
		result.append(start)
		return result
	var frontier: Array[Vector2i] = [start]
	var cursor := 0
	var came_from := {start: start}
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if current == goal:
			break
		for direction in directions:
			var next := current + direction
			if came_from.has(next) or not citizen_navigation_cell_walkable(next, start, goal):
				continue
			came_from[next] = current
			frontier.append(next)
	if not came_from.has(goal):
		return result
	var reverse_path: Array[Vector2i] = [goal]
	var current: Vector2i = goal
	while current != start:
		current = came_from[current]
		reverse_path.append(current)
	reverse_path.reverse()
	return reverse_path

func append_citizen_grid_segment(path: Array[Vector2i], segment: Array[Vector2i]) -> void:
	for cell in segment:
		if path.is_empty() or path.back() != cell:
			path.append(cell)

func citizen_grid_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [start]
	var current := start
	var crossed_bridges: Array[Dictionary] = []
	for raw_bridge in NPC_BRIDGES:
		var bridge: Dictionary = raw_bridge
		if citizen_route_crosses_bridge(start, goal, bridge):
			crossed_bridges.append(bridge)
	if goal.x < start.x:
		crossed_bridges.reverse()
	for bridge in crossed_bridges:
		var moving_right := goal.x > start.x
		var entry_x := int(bridge.water_min_x) - 1 if moving_right else int(bridge.water_max_x) + 1
		var exit_x := int(bridge.water_max_x) + 1 if moving_right else int(bridge.water_min_x) - 1
		var entry := Vector2i(entry_x, int(bridge.row))
		var approach := citizen_grid_path_unforced(current, entry)
		if approach.is_empty():
			return []
		append_citizen_grid_segment(path, approach)
		var water_x := int(bridge.water_min_x) if moving_right else int(bridge.water_max_x)
		var water_end := int(bridge.water_max_x) if moving_right else int(bridge.water_min_x)
		var water_step := 1 if moving_right else -1
		while water_x != water_end + water_step:
			path.append(Vector2i(water_x, int(bridge.row)))
			water_x += water_step
		path.append(Vector2i(exit_x, int(bridge.row)))
		current = Vector2i(exit_x, int(bridge.row))
	var final_segment := citizen_grid_path_unforced(current, goal)
	if final_segment.is_empty():
		return []
	append_citizen_grid_segment(path, final_segment)
	return path

func citizen_navigation_path(start_position: Vector3, target_position: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var grid_path := citizen_grid_path(world_to_grid(start_position), world_to_grid(target_position))
	if grid_path.is_empty():
		return result
	# Skip the current cell, then travel through cell centres. This keeps turns
	# clear of building footprints and places river crossings on the bridge axis.
	for index in range(1, grid_path.size()):
		result.append(grid_to_world(grid_path[index]) + Vector3(0, 0.18, 0))
	var planar_target := Vector2(target_position.x, target_position.z)
	if result.is_empty() or Vector2(result.back().x, result.back().z).distance_to(planar_target) > 0.01:
		result.append(Vector3(target_position.x, 0.18, target_position.z))
	return result

func citizen_performance_route(role: String, index: int, home: Vector3) -> Array[Dictionary]:
	var side := 1.0 if index % 2 == 0 else -1.0
	var home_outside := home + Vector3(side * 0.64, 0.0, 0.16)
	var work := citizen_work_position(role, index)
	var work_action := work + Vector3(-side * 0.58, 0.0, 0.18)
	var meal_angle := float((index * 3) % 10) * TAU / 10.0
	var meal := citizen_schedule_target("用餐", role, index, home) + Vector3(cos(meal_angle) * 0.42, 0.0, sin(meal_angle) * 0.42)
	var walk_a := citizen_schedule_target("散步", role, index, home) + Vector3(0.55 if index % 2 == 0 else -0.55, 0.0, 0.0)
	var walk_b := walk_a + Vector3(1.2 if index % 2 == 0 else -1.2, 0.0, 1.0)
	return [
		{"position": home_outside, "state": "居家", "activity": "出门"},
		{"position": work, "state": "通勤", "activity": schedule_activity_text("通勤", role)},
		{"position": work_action, "state": "工作", "activity": schedule_activity_text("工作", role)},
		{"position": meal, "state": "用餐", "activity": "取食"},
		{"position": walk_a, "state": "散步", "activity": "往来"},
		{"position": walk_b, "state": "散步", "activity": "巡游"},
		{"position": home, "state": "回家", "activity": "回家"},
	]

func schedule_slot_for_phase(phase: float) -> int:
	for slot in range(CITIZEN_SCHEDULE.size()):
		var definition: Dictionary = CITIZEN_SCHEDULE[slot]
		if phase >= float(definition.from) and phase < float(definition.to):
			return slot
	return CITIZEN_SCHEDULE.size() - 1

func update_citizen_schedules() -> void:
	for child in citizen_root.get_children():
		if not child is Node3D or child.is_queued_for_deletion():
			continue
		var index := int(child.get_meta("citizen_index", 0))
		var role := str(child.get_meta("schedule_role", citizen_role_for_index(index)))
		var home := citizen_home_position(index)
		var route := citizen_performance_route(role, index, home)
		var route_index := int(child.get_meta("performance_route_index", posmod(index, route.size())))
		route_index = posmod(route_index, route.size())
		child.set_meta("home_position", home)
		child.set_meta("performance_route", route)
		child.set_meta("performance_route_index", route_index)
		apply_citizen_route_step(child)

func apply_citizen_route_step(citizen: Node3D) -> void:
	var route: Array = citizen.get_meta("performance_route", [])
	if route.is_empty():
		citizen.set_meta("schedule_target", citizen.position)
		return
	var route_index := posmod(int(citizen.get_meta("performance_route_index", 0)), route.size())
	var step: Dictionary = route[route_index]
	citizen.set_meta("performance_route_index", route_index)
	citizen.set_meta("schedule_state", step.state)
	citizen.set_meta("schedule_activity", step.activity)
	citizen.set_meta("schedule_slot", route_index)
	var navigation_path := citizen_navigation_path(citizen.position, step.position)
	if navigation_path.is_empty():
		# Same-cell actions still need an exact destination. An empty route between
		# different cells indicates invalid scenery and must never become a river
		# shortcut, so keep the resident on its current safe point for this cycle.
		if world_to_grid(citizen.position) == world_to_grid(step.position):
			navigation_path.append(Vector3(step.position.x, 0.18, step.position.z))
		else:
			navigation_path.append(citizen.position)
	citizen.set_meta("navigation_path", navigation_path)
	citizen.set_meta("navigation_path_index", 0)
	citizen.set_meta("schedule_target", navigation_path[0])

func advance_citizen_route(citizen: Node3D) -> void:
	var route: Array = citizen.get_meta("performance_route", [])
	if route.is_empty():
		return
	citizen.set_meta("performance_route_index", posmod(int(citizen.get_meta("performance_route_index", 0)) + 1, route.size()))
	apply_citizen_route_step(citizen)

func advance_citizen_navigation(citizen: Node3D) -> void:
	var navigation_path: Array = citizen.get_meta("navigation_path", [])
	var next_index := int(citizen.get_meta("navigation_path_index", 0)) + 1
	if next_index < navigation_path.size():
		citizen.set_meta("navigation_path_index", next_index)
		citizen.set_meta("schedule_target", navigation_path[next_index])
		return
	advance_citizen_route(citizen)

func schedule_activity_text(state: String, role: String) -> String:
	if state == "工作":
		return {
			"farm": "耕作",
			"fishpond": "养鱼",
			"lumber": "伐木",
			"workshop": "制作",
			"market": "经商",
			"clinic": "应诊",
			"academy": "授课",
		}.get(role, "劳作")
	if state == "通勤":
		return {
			"farm": "前往农田",
			"fishpond": "前往鱼塘",
			"lumber": "前往林场",
			"workshop": "前往工坊",
			"market": "前往集市",
			"clinic": "前往医馆",
			"academy": "前往书院",
		}.get(role, "前往工地")
	if state == "用餐":
		return "取食"
	if state == "散步":
		return "往来"
	if state == "回家":
		return "回家"
	return "居家"

func citizen_surface_height(planar_position: Vector3) -> float:
	var surface_height := 0.18
	var bridge_half_length := TILE_SIZE
	var bridge_ramp_width := 0.75 * TILE_SIZE / 2.0
	for bridge in NPC_BRIDGES:
		var centre := grid_to_world(Vector2i(int(bridge.water_min_x), int(bridge.row)))
		centre.x += TILE_SIZE * 0.5
		if absf(planar_position.z - centre.z) > 0.66:
			continue
		var distance_from_centre := absf(planar_position.x - centre.x)
		if distance_from_centre <= bridge_half_length:
			# Follow the shallow crown of the bridge deck and keep feet above planks.
			var crown := 1.0 - distance_from_centre / bridge_half_length
			surface_height = maxf(surface_height, 0.60 + crown * 0.10)
		elif distance_from_centre < bridge_half_length + bridge_ramp_width:
			var ramp_weight := 1.0 - (distance_from_centre - bridge_half_length) / bridge_ramp_width
			surface_height = maxf(surface_height, lerpf(0.18, 0.60, ramp_weight))
	return surface_height

func configure_citizen_authored_walk(visual: Node3D) -> bool:
	for raw_player in visual.find_children("*", "AnimationPlayer", true, false):
		var player := raw_player as AnimationPlayer
		if player == null:
			continue
		for animation_name in player.get_animation_list():
			var normalized := str(animation_name).to_lower()
			if "walk" not in normalized and "行走" not in normalized:
				continue
			var animation := player.get_animation(animation_name)
			if animation:
				animation.loop_mode = Animation.LOOP_LINEAR
			visual.set_meta("authored_walk_player_path", visual.get_path_to(player))
			visual.set_meta("authored_walk_animation", str(animation_name))
			visual.set_meta("uses_authored_walk_animation", true)
			return true
	visual.set_meta("uses_authored_walk_animation", false)
	return false

func update_citizen_authored_walk(visual: Node3D, moving: bool) -> bool:
	if not bool(visual.get_meta("uses_authored_walk_animation", false)):
		return false
	var player_path: NodePath = visual.get_meta("authored_walk_player_path", NodePath())
	var player := visual.get_node_or_null(player_path) as AnimationPlayer
	var animation_name := StringName(str(visual.get_meta("authored_walk_animation", "")))
	if player == null or animation_name == &"" or not player.has_animation(animation_name):
		visual.set_meta("uses_authored_walk_animation", false)
		return false
	if moving:
		if not player.is_playing() or player.current_animation != animation_name:
			player.play(animation_name)
			if not bool(visual.get_meta("authored_walk_started", false)):
				var animation := player.get_animation(animation_name)
				if animation and animation.length > 0.0:
					player.seek(float(visual.get_meta("walk_animation_offset", 0.0)) * animation.length, true)
				visual.set_meta("authored_walk_started", true)
	else:
		player.pause()
	return true

func update_citizen_walk_animation(citizen: Node3D, traveled: float) -> void:
	var visual := citizen.get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var rest_position: Vector3 = visual.get_meta("rest_position", Vector3.ZERO)
	var rest_rotation: Vector3 = visual.get_meta("rest_rotation", Vector3.ZERO)
	if update_citizen_authored_walk(visual, traveled > 0.000001):
		# Authored clips animate the rig internally. Keep the imported model root at
		# its authored transform so a fallback sway is never layered on top.
		visual.position = rest_position
		visual.rotation = rest_rotation
		citizen.set_meta("walk_animation_active", traveled > 0.000001)
		return
	if traveled <= 0.000001:
		visual.position = rest_position
		visual.rotation = rest_rotation
		citizen.set_meta("walk_animation_active", false)
		return
	var walk_distance := float(citizen.get_meta("walk_distance", 0.0)) + traveled
	citizen.set_meta("walk_distance", walk_distance)
	var phase_offset := float(citizen.get_meta("phase", 0.0))
	var phase := walk_distance / NPC_WALK_STRIDE_METERS * TAU + phase_offset
	var step_wave := sin(phase)
	visual.position = rest_position + Vector3(sin(phase * 0.5) * 0.012, absf(step_wave) * NPC_WALK_BOB_HEIGHT, 0)
	visual.rotation = rest_rotation + Vector3(step_wave * 0.035, 0, sin(phase * 0.5) * 0.028)
	citizen.set_meta("walk_animation_active", true)

func move_citizens(delta: float) -> void:
	# Residents are decorative actors, so walking starts immediately at one fixed
	# real-time speed. Economy speed, role, resident index and previous velocity
	# never change their movement rate.
	var movement_delta := maxf(delta, 0.0)
	for child in citizen_root.get_children():
		if not child is Node3D or child.is_queued_for_deletion():
			continue
		var velocity := Vector3.ZERO
		var current_planar := Vector3(child.position.x, 0, child.position.z)
		var travel_budget := NPC_MOVE_SPEED * movement_delta
		var traveled := 0.0
		var route_transitions := 0
		var last_direction := Vector3.ZERO
		while travel_budget > 0.00001 and route_transitions < 24:
			var target: Vector3 = child.get_meta("schedule_target", child.position)
			var target_planar := Vector3(target.x, 0, target.z)
			var remaining := target_planar - current_planar
			if remaining.length() <= 0.001:
				advance_citizen_navigation(child)
				route_transitions += 1
				continue
			var direction := remaining.normalized()
			var travel := minf(travel_budget, remaining.length())
			current_planar += direction * travel
			travel_budget -= travel
			traveled += travel
			last_direction = direction
			if travel >= remaining.length() - 0.00001:
				advance_citizen_navigation(child)
				route_transitions += 1
				continue
			break
		if traveled > 0.0:
			velocity = last_direction * NPC_MOVE_SPEED
			child.rotation.y = rotate_toward(child.rotation.y, atan2(last_direction.x, last_direction.z), NPC_TURN_SPEED * movement_delta)
		child.set_meta("schedule_velocity", velocity)
		child.set_meta("last_travel_distance", traveled)
		child.set_meta("last_route_transitions", route_transitions)
		var ground_height := citizen_surface_height(current_planar)
		child.set_meta("ground_height", ground_height)
		child.position = Vector3(current_planar.x, ground_height, current_planar.z)
		update_citizen_walk_animation(child, traveled)

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
	top_row.name = "TopRow"
	top_row.add_theme_constant_override("separation", 12)
	top_panel.add_child(top_row)
	var title := Label.new()
	title.name = "TopTitle"
	title.text = "  东境 · 孤城新生"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("6b4731"))
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_row.add_child(title)
	status_label = Label.new()
	status_label.name = "TopStatus"
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("2f3433"))
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(status_label)
	goal_label = Label.new()
	goal_label.add_theme_color_override("font_color", Color("2f3433"))
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goal_label.custom_minimum_size.x = 340
	top_row.add_child(goal_label)
	settings_button = make_compact_button("设置", toggle_settings_menu, Vector2(72, 40))
	settings_button.toggle_mode = true
	settings_button.tooltip_text = "音乐、存档、游戏操作与帮助"
	top_row.add_child(settings_button)

	bottom_panel = PanelContainer.new()
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_panel.offset_left = -430
	bottom_panel.offset_right = 430
	bottom_panel.offset_top = -148
	bottom_panel.offset_bottom = -14
	bottom_panel.add_theme_stylebox_override("panel", panel_style(Color(0.95, 0.90, 0.79, 0.96)))
	layer.add_child(bottom_panel)
	var build_panel_box := VBoxContainer.new()
	build_panel_box.add_theme_constant_override("separation", 5)
	bottom_panel.add_child(build_panel_box)
	var category_row := HBoxContainer.new()
	category_row.alignment = BoxContainer.ALIGNMENT_CENTER
	category_row.add_theme_constant_override("separation", 6)
	build_panel_box.add_child(category_row)
	for category in ["basic", "industry", "civic"]:
		var category_name: String = str({"basic": "基础", "industry": "产业", "civic": "民生"}[category])
		var category_button := make_compact_button(category_name, select_build_category.bind(category), Vector2(92, 31), Color("e9dcc0"))
		category_button.toggle_mode = true
		category_button.tooltip_text = "查看%s建筑" % category_name
		category_row.add_child(category_button)
		build_category_buttons[category] = category_button
	road_button = make_compact_button("铺路 · 木%d/格" % ROAD_WOOD_COST, select_road_tool, Vector2(132, 31), Color("d8c39d"))
	road_button.toggle_mode = true
	road_button.tooltip_text = "逐格铺设道路。相邻道路连回村庄主路后，正常运行的生产建筑铜钱 +%d/日，全城上限 +%d。" % [ROAD_TRANSPORT_BONUS, ROAD_TRANSPORT_COIN_CAP]
	category_row.add_child(road_button)
	bottom_actions = HBoxContainer.new()
	bottom_actions.add_theme_constant_override("separation", 8)
	bottom_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	build_panel_box.add_child(bottom_actions)
	for type in BUILDINGS.keys():
		var definition: Dictionary = BUILDINGS[type]
		var button := Button.new()
		button.text = "%s\n木 %d · 钱 %d" % [definition.name, definition.cost, definition.coin_cost]
		button.custom_minimum_size = Vector2(112, 62)
		button.tooltip_text = building_tooltip_text(str(type))
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
	inspector.offset_left = -770
	inspector.offset_right = -412
	inspector.offset_top = 88
	inspector.offset_bottom = 505
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
	inspector_status = Label.new()
	inspector_status.name = "OperationStatus"
	inspector_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_box.add_child(inspector_status)
	inspector_body = Label.new()
	inspector_body.add_theme_color_override("font_color", Color("2f3433"))
	inspector_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspect_box.add_child(inspector_body)
	inspector_toggle_button = make_action_button("暂停生产", toggle_selected_building, Color("e7dfc5"))
	inspector_toggle_button.custom_minimum_size.y = 38
	inspect_box.add_child(inspector_toggle_button)
	inspector_demolish_button = make_action_button("删除建筑（返还一半木材与铜钱）", demolish_selected, Color("f0d1b8"))
	inspect_box.add_child(inspector_demolish_button)

	region_panel = PanelContainer.new()
	region_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	region_panel.offset_left = -398
	region_panel.offset_right = -14
	region_panel.offset_top = 88
	region_panel.offset_bottom = 468
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
	region_body = GoalChecklist.new()
	region_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	region_body.tooltip_text = "本章目标在开拓下一地区前保持不变；达成的目标会以绿色勾选显示。"
	region_box.add_child(region_body)
	region_unlock_button = make_action_button("条件尚未满足", unlock_next_region, Color("d6a74a"))
	region_unlock_button.custom_minimum_size = Vector2(0, 42)
	region_box.add_child(region_unlock_button)

	var message_panel := PanelContainer.new()
	message_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	message_panel.offset_left = -390
	message_panel.offset_right = -14
	message_panel.offset_top = -230
	message_panel.offset_bottom = -162
	message_panel.add_theme_stylebox_override("panel", panel_style(Color(0.14, 0.18, 0.17, 0.90)))
	layer.add_child(message_panel)
	message_label = Label.new()
	message_label.text = "欢迎来到河谷"
	message_label.add_theme_color_override("font_color", Color("fff7e7"))
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_panel.add_child(message_label)

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
	settings_panel.offset_bottom = 425
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
	create_music_settings(settings_box)
	settings_action_buttons["view"] = make_settings_action_button("查看地图 / 取消摆放", view_from_settings)
	settings_action_buttons["help"] = make_settings_action_button("帮助", show_help_from_settings)
	settings_action_buttons["save"] = make_settings_action_button("保存当前进度", save_from_settings)
	settings_action_buttons["load"] = make_settings_action_button("读取最近存档", request_load_from_settings)
	settings_action_buttons["reset"] = make_settings_action_button("重新开始本局", request_reset_from_settings, Color("f0d1b8"))
	for action in ["help", "view", "save", "load", "reset"]:
		settings_box.add_child(settings_action_buttons[action])

	help_dialog = AcceptDialog.new()
	help_dialog.name = "HelpDialog"
	help_dialog.title = "操作帮助"
	help_dialog.min_size = Vector2i(450, 270)
	help_dialog.dialog_text = "左键点击：放置建筑/道路，或选中已有建筑/道路\nR：将待建建筑旋转90°\n右键短按：取消当前摆放\n中键拖动：平移地图\n右键拖动：旋转视角\n滚轮：缩放视角\nEsc：取消摆放，或关闭当前面板\n移除：选中后，在详情中点击“删除建筑”/“拆除道路”"
	help_dialog.get_ok_button().text = "关闭"
	layer.add_child(help_dialog)

	confirmation_dialog = ConfirmationDialog.new()
	confirmation_dialog.min_size = Vector2i(420, 170)
	confirmation_dialog.get_ok_button().text = "确认"
	confirmation_dialog.get_cancel_button().text = "取消"
	confirmation_dialog.confirmed.connect(confirm_pending_action)
	layer.add_child(confirmation_dialog)

func create_music_settings(settings_box: VBoxContainer) -> void:
	create_background_music()
	var row := HBoxContainer.new()
	row.name = "MusicSettings"
	row.add_theme_constant_override("separation", 6)
	settings_box.add_child(row)
	var label := Label.new()
	label.text = "音乐"
	label.add_theme_color_override("font_color", Color("6b4731"))
	row.add_child(label)
	music_volume_slider = HSlider.new()
	music_volume_slider.name = "MusicVolume"
	music_volume_slider.min_value = 0
	music_volume_slider.max_value = 100
	music_volume_slider.step = 1
	music_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_volume_slider.custom_minimum_size.x = 70
	music_volume_slider.value = roundf(background_music.volume * 100.0)
	music_volume_slider.tooltip_text = "背景音乐音量"
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	row.add_child(music_volume_slider)
	music_volume_label = Label.new()
	music_volume_label.custom_minimum_size.x = 37
	music_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	music_volume_label.add_theme_font_size_override("font_size", 14)
	music_volume_label.add_theme_color_override("font_color", Color("6b4731"))
	row.add_child(music_volume_label)
	music_mute_button = make_compact_button("静音", _on_music_mute_pressed, Vector2(54, 32))
	music_mute_button.toggle_mode = true
	row.add_child(music_mute_button)
	update_music_settings()

func _on_music_volume_changed(value: float) -> void:
	background_music.set_music_volume(value / 100.0)
	update_music_settings()

func _on_music_mute_pressed() -> void:
	background_music.set_muted(not background_music.muted)
	update_music_settings()

func update_music_settings() -> void:
	if not music_volume_label or not music_mute_button:
		return
	music_volume_label.text = "%d%%" % roundi(background_music.volume * 100.0)
	music_mute_button.set_pressed_no_signal(background_music.muted)
	music_mute_button.text = "恢复" if background_music.muted else "静音"
	music_mute_button.tooltip_text = "恢复音乐" if background_music.muted else "音乐静音"

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

func show_help_from_settings() -> void:
	close_settings_menu()
	help_dialog.popup_centered(Vector2i(450, 270))

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
		return "东境复兴"
	return REGION_DEFINITIONS[map_region_level + 1].short_name

func apply_region_panel_layout() -> void:
	if not region_panel or not region_panel_toggle:
		return
	region_panel.offset_top = 88
	region_panel.offset_right = -14
	if region_panel_collapsed:
		region_panel.offset_left = -210
		region_panel.offset_bottom = 146
		region_title.text = "目标 · %s" % region_progress_text()
		region_title.add_theme_font_size_override("font_size", 16)
		region_body.visible = false
		region_unlock_button.visible = false
		region_panel_toggle.text = "<"
		region_panel_toggle.tooltip_text = "展开目标栏"
	else:
		region_panel.offset_left = -398
		region_panel.offset_bottom = 430
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

func select_build_category(category: String) -> void:
	if category not in ["basic", "industry", "civic"]:
		return
	build_category = category
	road_tool_selected = false
	clear_ghost()
	if selected_type != "" and not building_in_build_category(selected_type, category):
		selected_type = ""
		clear_ghost()
	update_build_menu()

func building_in_build_category(type: String, category: String) -> bool:
	if category == "basic":
		return type in INITIAL_BUILDING_TYPES
	return type not in INITIAL_BUILDING_TYPES and str(BUILDINGS[type].get("category", "basic")) == category

func building_is_unlocked(type: String) -> bool:
	if not BUILDINGS.has(type):
		return false
	return map_region_level >= int(BUILDINGS[type].get("unlock_level", 0))

func building_unlock_text(type: String) -> String:
	var unlock_level := int(BUILDINGS[type].get("unlock_level", 0))
	if unlock_level <= 0:
		return "已解锁"
	return "开拓%s后解锁" % REGION_DEFINITIONS[unlock_level].short_name

func building_input(type: String, resource: String) -> int:
	var inputs: Dictionary = BUILDINGS[type].get("inputs", {})
	return int(inputs.get(resource, 0))

func building_output(type: String, resource: String) -> int:
	var outputs: Dictionary = BUILDINGS[type].get("outputs", {})
	return int(outputs.get(resource, 0))

func building_effect(type: String, effect: String) -> int:
	var effects: Dictionary = BUILDINGS[type].get("effects", {})
	return int(effects.get(effect, 0))

func resource_label(resource: String) -> String:
	return str({"wood": "木材", "food": "粮食", "coins": "铜钱"}.get(resource, resource))

func resource_change_text(values: Dictionary, sign_value: int) -> String:
	var parts: Array[String] = []
	for resource in ["wood", "food", "coins"]:
		var amount := int(values.get(resource, 0))
		if amount > 0:
			parts.append("%s %s%d" % [resource_label(resource), "+" if sign_value > 0 else "-", amount])
	return "、".join(parts)

func proportional_output_text(type: String) -> String:
	var definition: Dictionary = BUILDINGS[type]
	var workers := int(definition.workers)
	var outputs: Dictionary = definition.get("outputs", {})
	var output_parts: Array[String] = []
	for resource in ["wood", "food", "coins"]:
		var full_output := int(outputs.get(resource, 0))
		if full_output <= 0:
			continue
		var amounts: Array[String] = []
		var staffing: Array[String] = []
		for assigned in range(workers + 1):
			amounts.append("%s%d" % ["+" if assigned > 0 else "", int(floor(full_output * assigned / float(workers)))])
			staffing.append(str(assigned))
		output_parts.append("%s %s（在岗 %s 人）" % [resource_label(resource), "/".join(amounts), "/".join(staffing)])
	return "、".join(output_parts)

func building_effect_lines(type: String, include_road := true) -> Array[String]:
	var definition: Dictionary = BUILDINGS[type]
	var workers := int(definition.workers)
	var staffing := str(definition.get("staffing", "passive"))
	var lines: Array[String] = []
	if staffing == "proportional":
		lines.append("岗位：%d（按在岗人数产出）" % workers)
	elif staffing == "full":
		lines.append("岗位：%d（满员运行）" % workers)

	var inputs: Dictionary = definition.get("inputs", {})
	var outputs: Dictionary = definition.get("outputs", {})
	if staffing == "proportional":
		lines.append("每日产出：%s" % proportional_output_text(type))
		var trade_coins := int(definition.get("trade_coins", 0))
		if trade_coins > 0:
			lines.append("每日收入（民生交易）：有人在岗时铜钱 +%d（农田与伐木场合计上限 +%d）" % [trade_coins, BASIC_TRADE_COIN_CAP])
	elif staffing == "full":
		var input_text := resource_change_text(inputs, -1)
		var output_text := resource_change_text(outputs, 1)
		if input_text != "" and output_text != "":
			lines.append("每日（满员且原料充足）：%s → %s" % [input_text, output_text])
		elif output_text != "":
			lines.append("每日（满员）：%s" % output_text)
	else:
		var passive_input_text := resource_change_text(inputs, -1)
		var passive_output_text := resource_change_text(outputs, 1)
		if passive_input_text != "" or passive_output_text != "":
			var passive_changes: Array[String] = []
			if passive_input_text != "":
				passive_changes.append(passive_input_text)
			if passive_output_text != "":
				passive_changes.append(passive_output_text)
			lines.append("每日：%s" % "、".join(passive_changes))

	var maintenance := int(definition.maintenance)
	var maintenance_text := "无"
	if maintenance > 0:
		maintenance_text = "铜钱 -%d/日（%s）" % [maintenance, "启用即收" if workers > 0 else "固定收取"]
		if bool(definition.get("requires_road", false)):
			maintenance_text = "铜钱 -%d/日（未接通也收取）" % maintenance
	lines.append("维护：%s" % maintenance_text)
	var fixed_parts: Array[String] = []
	var housing := building_effect(type, "housing")
	var wood_storage := building_effect(type, "wood_capacity")
	var food_storage := building_effect(type, "food_capacity")
	if housing > 0:
		fixed_parts.append("住房容量 +%d" % housing)
	if type == "warehouse":
		lines.append("接通主路：木材/粮食容量各 +%d" % wood_storage)
	elif wood_storage > 0:
		fixed_parts.append("木材容量 +%d" % wood_storage)
	if food_storage > 0 and type != "warehouse":
		fixed_parts.append("粮食容量 +%d" % food_storage)
	if not fixed_parts.is_empty():
		lines.append("固定效果：%s" % "、".join(fixed_parts))
	var happiness_gain := building_effect(type, "happiness_target")
	if happiness_gain > 0:
		lines.append("运行效果：日结幸福度目标 +%d（%s合计上限 +%d）" % [
			happiness_gain, definition.name, int(definition.get("effect_cap", happiness_gain))
		])
	if include_road and type in ROAD_ELIGIBLE_BUILDING_TYPES:
		lines.append("道路运输：相邻道路接通村庄主路且本日正常运行时，铜钱 +%d（全城上限 +%d）" % [
			ROAD_TRANSPORT_BONUS, ROAD_TRANSPORT_COIN_CAP
		])
	return lines

func building_effect_text(type: String, include_road := true) -> String:
	return "\n".join(building_effect_lines(type, include_road))

func building_tooltip_text(type: String) -> String:
	var footprint_hint := ""
	if type == "market":
		footprint_hint = "占地：2×2 格（开放集市）\n"
	elif type == "warehouse":
		footprint_hint = "占地：2×2 格（开放仓院）\n"
	elif type == "fishpond":
		footprint_hint = "占地：3×2 格（人工鱼塘，可建于陆地）\n"
	elif type == "farm":
		footprint_hint = "占地：2×2 格（河岸农田）\n"
	elif type == "workshop":
		footprint_hint = "占地：2×2 格（开放工坊）\n"
	elif type == "clinic":
		footprint_hint = "占地：2×2 格（诊堂药院）\n"
	return footprint_hint + building_effect_text(type)

func update_build_menu() -> void:
	for category in build_category_buttons:
		var category_button: Button = build_category_buttons[category]
		category_button.button_pressed = str(category) == build_category
	for type in build_buttons:
		var button: Button = build_buttons[type]
		var definition: Dictionary = BUILDINGS[type]
		var in_category := building_in_build_category(str(type), build_category)
		var unlocked := building_is_unlocked(str(type))
		button.visible = in_category
		button.disabled = ended != "" or not unlocked
		button.button_pressed = not road_tool_selected and selected_type == type
		button.text = "%s\n木 %d · 钱 %d" % [definition.name, definition.cost, definition.coin_cost] if unlocked else "%s\n%s" % [definition.name, building_unlock_text(str(type))]
		button.tooltip_text = building_tooltip_text(str(type)) if unlocked else "%s\n%s" % [building_unlock_text(str(type)), building_tooltip_text(str(type))]
	if road_button:
		road_button.disabled = ended != ""
		road_button.button_pressed = road_tool_selected

func select_road_tool() -> void:
	if ended != "":
		return
	if road_tool_selected:
		cancel_building()
		show_message("已取消铺路，进入查看模式")
		return
	road_tool_selected = true
	selected_type = ""
	selected_building_id = -1
	selected_road_cell = Vector2i(-1, -1)
	inspector.visible = false
	clear_ghost()
	show_message("铺路：木材 %d/格；道路接通村庄主路后，相邻生产建筑正常运行时铜钱 +%d/日（全城上限 +%d）" % [ROAD_WOOD_COST, ROAD_TRANSPORT_BONUS, ROAD_TRANSPORT_COIN_CAP])
	update_ui()

func select_building(type: String) -> void:
	if ended != "":
		return
	if not building_is_unlocked(type):
		show_message("%s尚未解锁：%s" % [BUILDINGS[type].name, building_unlock_text(type)])
		return
	if selected_type == type:
		cancel_building()
		show_message("已取消摆放，进入查看模式")
		return
	selected_type = type
	selected_rotation_quarters = 0
	clear_ghost()
	road_tool_selected = false
	selected_building_id = -1
	selected_road_cell = Vector2i(-1, -1)
	inspector.visible = false
	show_message("请选择格子放置%s" % BUILDINGS[type].name)
	update_ui()

func cancel_building() -> void:
	selected_type = ""
	selected_rotation_quarters = 0
	road_tool_selected = false
	clear_ghost()
	update_ui()

func rotate_selected_building() -> void:
	if selected_type == "" or road_tool_selected or ended != "":
		return
	selected_rotation_quarters = posmod(selected_rotation_quarters + 1, 4)
	var previous_cell := hover_cell
	clear_ghost()
	if previous_cell != Vector2i(-1, -1):
		update_ghost(previous_cell)

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

func is_farm_lot(anchor: Vector2i, footprint := Vector2i.ZERO) -> bool:
	# The plot may extend inland from either bank. Only one of its
	# cells needs to touch the river; normal placement still rejects water.
	for cell in building_footprint_cells("farm", anchor, footprint):
		if is_farm_cell(cell):
			return true
	return false

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

func cardinal_cells(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i.LEFT, cell + Vector2i.RIGHT,
		cell + Vector2i.UP, cell + Vector2i.DOWN,
	]

func is_village_main_road_cell(cell: Vector2i) -> bool:
	return cell.x == VILLAGE_ROAD_X and cell.y >= VILLAGE_ROAD_MIN_Z and cell.y <= VILLAGE_ROAD_MAX_Z

func is_fixed_road_infrastructure(cell: Vector2i) -> bool:
	return is_village_main_road_cell(cell) or is_npc_bridge_cell(cell)

func can_place_road(cell: Vector2i) -> String:
	if cell.x < 0 or cell.x >= GRID_SIZE or cell.y < 0 or cell.y >= GRID_SIZE:
		return "超出地图边界"
	var region_level := region_level_for_cell(cell)
	if region_level > map_region_level:
		return region_lock_message(region_level)
	if is_water_cell(cell):
		return "水面不能铺设道路，请从现有桥梁通行"
	if occupied.has(cell):
		return "建筑占用的格子不能铺路"
	if roads.has(cell):
		return "这里已有道路"
	if is_fixed_road_infrastructure(cell):
		return "这里已有村庄主路或桥梁"
	if has_scenery_tree(cell):
		return "树木占用此格，请从林间空地绕行"
	if wood < ROAD_WOOD_COST:
		return "木材不足（铺路需要 %d）" % ROAD_WOOD_COST
	return ""

func road_segment_connects(cell: Vector2i) -> bool:
	return roads.has(cell) or is_village_main_road_cell(cell)

func road_visual_connects(cell: Vector2i) -> bool:
	return road_segment_connects(cell) or is_npc_bridge_cell(cell)

func road_network_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for neighbor in cardinal_cells(cell):
		if road_segment_connects(neighbor):
			result.append(neighbor)
	# A bridge is existing fixed infrastructure.  It creates one explicit edge
	# between its two bank-access cells without turning water tiles into roads.
	for bridge in NPC_BRIDGES:
		var left_access := Vector2i(int(bridge.water_min_x) - 1, int(bridge.row))
		var right_access := Vector2i(int(bridge.water_max_x) + 1, int(bridge.row))
		if cell == left_access and road_segment_connects(right_access):
			result.append(right_access)
		elif cell == right_access and road_segment_connects(left_access):
			result.append(left_access)
	return result

func create_road_model(cell: Vector2i, preview := false, preview_valid := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Road_%d_%d" % [cell.x, cell.y]
	root.set_meta("road_cell", cell)
	var color := Color(0.55, 0.43, 0.31, 0.96)
	if preview:
		color = Color(0.34, 0.72, 0.45, 0.68) if preview_valid else Color(0.78, 0.28, 0.24, 0.68)
		var preview_tile := mesh_box(Vector3(TILE_SIZE - 0.18, 0.045, TILE_SIZE - 0.18), color, color.a)
		root.add_child(preview_tile)
		return root
	var centre := mesh_box(Vector3(ROAD_WIDTH, 0.055, ROAD_WIDTH), color)
	centre.name = "RoadCentre"
	root.add_child(centre)
	var directions := [
		{"offset": Vector3(-0.72, 0, 0), "size": Vector3(0.56, 0.05, 0.72), "cell": cell + Vector2i.LEFT},
		{"offset": Vector3(0.72, 0, 0), "size": Vector3(0.56, 0.05, 0.72), "cell": cell + Vector2i.RIGHT},
		{"offset": Vector3(0, 0, -0.72), "size": Vector3(0.72, 0.05, 0.56), "cell": cell + Vector2i.UP},
		{"offset": Vector3(0, 0, 0.72), "size": Vector3(0.72, 0.05, 0.56), "cell": cell + Vector2i.DOWN},
	]
	for entry in directions:
		if road_visual_connects(entry.cell):
			var arm_size: Vector3 = entry.size
			var arm_offset: Vector3 = entry.offset
			# The road centre is 1.0 m wide.  Recompute connector arms from the
			# actual cell pitch so roads remain continuous after the grid spacing is
			# widened, while the building meshes themselves stay unchanged.
			var is_horizontal := absf(entry.offset.x) > 0.1
			var direction_sign := signf(entry.offset.x if is_horizontal else entry.offset.z)
			var centre_half := ROAD_WIDTH * 0.5
			if is_village_main_road_cell(entry.cell):
				# A side connection meets the 1.1 m-wide continuous main street.
				# Endpoint connections meet the street's boundary halfway between
				# cell centres, so they use the same short edge-to-edge arm as a
				# bridge approach.
				if is_horizontal:
					var arm_length := TILE_SIZE - centre_half - 0.55
					arm_size.x = arm_length
					arm_offset.x = direction_sign * (centre_half + arm_length * 0.5)
				else:
					var arm_length := TILE_SIZE * 0.5 - centre_half
					arm_size.z = arm_length
					arm_offset.z = direction_sign * (centre_half + arm_length * 0.5)
			elif is_npc_bridge_cell(entry.cell):
				# The bridge deck starts at the bank boundary.  Stop the road arm
				# exactly at that edge instead of extending into the bridge mesh.
				if is_horizontal:
					var arm_length := TILE_SIZE * 0.5 - centre_half
					arm_size.x = arm_length
					arm_offset.x = direction_sign * (centre_half + arm_length * 0.5)
				else:
					var arm_length := TILE_SIZE * 0.5 - centre_half
					arm_size.z = arm_length
					arm_offset.z = direction_sign * (centre_half + arm_length * 0.5)
			else:
				# Each adjacent road cell owns half of the gap between centres.  With
				# the widened 2.2 m pitch and 1.0 m road width this is a 0.60 m arm
				# centred at 0.80 m,
				# so neighbouring arms meet at the midpoint without overlapping.
				var arm_length := (TILE_SIZE - centre_half * 2.0) * 0.5
				var arm_centre := centre_half + arm_length * 0.5
				if is_horizontal:
					arm_size.x = arm_length
					arm_offset.x = direction_sign * arm_centre
				else:
					arm_size.z = arm_length
					arm_offset.z = direction_sign * arm_centre
			var arm := mesh_box(arm_size, color)
			arm.position = arm_offset
			root.add_child(arm)
	# A few pale pavers break up the flat surface and keep roads readable from
	# the high planning camera without adding an expensive unique model per tile.
	for offset in [Vector3(-0.20, 0.035, -0.12), Vector3(0.22, 0.035, 0.16)]:
		var paver := mesh_box(Vector3(0.25, 0.022, 0.18), Color("aa9271"))
		paver.position = offset
		root.add_child(paver)
	return root

func refresh_road_model(cell: Vector2i) -> void:
	if not roads.has(cell):
		return
	var old_node = roads[cell]
	if old_node != null and is_instance_valid(old_node):
		old_node.queue_free()
	var model := create_road_model(cell)
	model.position = grid_to_world(cell) + Vector3(0, 0.225, 0)
	road_root.add_child(model)
	roads[cell] = model

func refresh_road_and_neighbors(cell: Vector2i) -> void:
	refresh_road_model(cell)
	for neighbor in cardinal_cells(cell):
		refresh_road_model(neighbor)

func has_scenery_tree(cell: Vector2i) -> bool:
	if not scenery_trees_by_cell.is_empty():
		return scenery_trees_by_cell.has(cell) and not scenery_trees_by_cell[cell].is_empty()
	return authored_tree_cells().has(cell)

func update_forest_cell_for_roads(cell: Vector2i) -> void:
	var trees_in_cell: Array = scenery_trees_by_cell.get(cell, [])
	for tree in trees_in_cell:
		if is_instance_valid(tree):
			tree.visible = not (roads.has(cell) and legacy_cleared_tree_roads.has(cell))
	for rock in scenery_rocks_by_cell.get(cell, []):
		if is_instance_valid(rock):
			rock.visible = not roads.has(cell)

func update_road_scenery() -> void:
	# Only trees authored by create_scenery carry forest_cell metadata and are
	# indexed here. OuterNaturalBuffer vegetation stays permanently decorative.
	for cell in scenery_trees_by_cell:
		update_forest_cell_for_roads(cell)
	for cell in scenery_rocks_by_cell:
		update_forest_cell_for_roads(cell)

func add_road(cell: Vector2i, free := false, legacy_tree_clearance := false) -> void:
	if ended != "":
		return
	if roads.has(cell):
		return
	# Only validated migration can preserve a historically cleared tree. Even
	# free placement cannot turn a new road into a tree-removal operation.
	if has_scenery_tree(cell):
		if not legacy_tree_clearance:
			return
		legacy_cleared_tree_roads[cell] = true
	roads[cell] = null
	if not free:
		wood -= ROAD_WOOD_COST
	refresh_road_and_neighbors(cell)
	update_forest_cell_for_roads(cell)
	if citizen_root and citizen_root.get_child_count() > 0:
		update_citizen_schedules()
	refresh_road_dependent_buildings()

func remove_road(cell: Vector2i, refund := true) -> void:
	if ended != "":
		return
	if not roads.has(cell):
		return
	var node = roads[cell]
	if node != null and is_instance_valid(node):
		node.queue_free()
	roads.erase(cell)
	legacy_cleared_tree_roads.erase(cell)
	if refund:
		# Demolition returns owned material even if lost warehouse access has
		# temporarily left the existing stock above its current capacity.
		wood += ROAD_WOOD_COST
	for neighbor in cardinal_cells(cell):
		refresh_road_model(neighbor)
	update_forest_cell_for_roads(cell)
	if citizen_root and citizen_root.get_child_count() > 0:
		update_citizen_schedules()
	refresh_road_dependent_buildings()

func refresh_road_dependent_buildings() -> void:
	# Capacity itself is derived from the live network. Refresh its UI and
	# warning markers immediately when a single road segment changes.
	if is_instance_valid(status_label):
		update_ui()
	else:
		update_building_status_markers()
	if is_instance_valid(inspector) and inspector.visible and selected_building_id >= 0:
		show_inspector(selected_building_id)

func is_road_connected(cell: Vector2i) -> bool:
	if not road_segment_connects(cell):
		return false
	var frontier: Array[Vector2i] = [cell]
	var visited := {}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		if is_village_main_road_cell(current):
			return true
		for neighbor in road_network_neighbors(current):
			if not visited.has(neighbor):
				frontier.append(neighbor)
	return false

func building_has_connected_road(record: Dictionary) -> bool:
	if str(record.type) not in ROAD_ELIGIBLE_BUILDING_TYPES and not bool(BUILDINGS[record.type].get("requires_road", false)):
		return false
	for boundary in building_boundary_cells(record):
		if road_segment_connects(boundary) and is_road_connected(boundary):
			return true
	return false

func building_footprint_cells(type: String, anchor: Vector2i, footprint := Vector2i.ZERO) -> Array[Vector2i]:
	if footprint == Vector2i.ZERO:
		footprint = BUILDING_FOOTPRINTS.get(type, Vector2i.ONE)
	var cells: Array[Vector2i] = []
	for dz in range(footprint.y):
		for dx in range(footprint.x):
			cells.append(anchor + Vector2i(dx, dz))
	return cells

func record_footprint(record: Dictionary) -> Vector2i:
	return record.get("footprint", BUILDING_FOOTPRINTS.get(str(record.type), Vector2i.ONE))

func rotated_footprint(base: Vector2i, rotation_quarters: int) -> Vector2i:
	return Vector2i(base.y, base.x) if posmod(rotation_quarters, 2) == 1 else base

func record_base_footprint(record: Dictionary) -> Vector2i:
	return record.get("base_footprint", rotated_footprint(record_footprint(record), int(record.get("rotation_quarters", 0))))

func saved_base_footprint(record: Dictionary) -> Vector2i:
	# Older saves stored single-cell warehouses without an explicit footprint.
	# Keep those lots compact instead of expanding into neighboring property.
	if str(record.type) == "warehouse":
		return Vector2i.ONE * int(record.get("warehouse_footprint", 1))
	if str(record.type) == "farm":
		var farm_cells := int(record.get("farm_footprint", 1))
		return Vector2i(2, 2) if farm_cells == 4 else Vector2i(farm_cells, 1)
	if str(record.type) in ["workshop", "clinic"]:
		return Vector2i.ONE * int(record.get(str(record.type) + "_footprint", 1))
	return BUILDING_FOOTPRINTS.get(str(record.type), Vector2i.ONE)

func saved_building_footprint(record: Dictionary) -> Vector2i:
	return rotated_footprint(saved_base_footprint(record), int(record.get("rotation_quarters", 0)))

func building_boundary_cells(record: Dictionary) -> Array[Vector2i]:
	var inside := {}
	var result: Array[Vector2i] = []
	for footprint_cell in building_footprint_cells(str(record.type), record.cell, record_footprint(record)):
		inside[footprint_cell] = true
	for footprint_cell in inside:
		for neighbor in cardinal_cells(footprint_cell):
			if not inside.has(neighbor) and neighbor not in result:
				result.append(neighbor)
	return result

func building_model_position(type: String, anchor: Vector2i, footprint := Vector2i.ZERO) -> Vector3:
	if footprint == Vector2i.ZERO:
		footprint = BUILDING_FOOTPRINTS.get(type, Vector2i.ONE)
	return grid_to_world(anchor) + Vector3((footprint.x - 1) * TILE_SIZE * 0.5, 0, (footprint.y - 1) * TILE_SIZE * 0.5)

func road_bonus_for_building(record: Dictionary) -> int:
	# Warehouses require road access for storage, but never earn production
	# transport income merely because their road requirement is satisfied.
	if str(record.type) not in ROAD_ELIGIBLE_BUILDING_TYPES:
		return 0
	if not bool(record.get("enabled", true)) or not bool(record.get("last_running", false)):
		return 0
	var required_workers := int(BUILDINGS[record.type].workers)
	if required_workers > 0 and int(record.get("assigned_workers", 0)) < required_workers:
		return 0
	if not building_has_connected_road(record):
		return 0
	return ROAD_TRANSPORT_BONUS

func daily_road_transport_income() -> int:
	var income := 0
	for record in buildings:
		income += road_bonus_for_building(record)
	return mini(ROAD_TRANSPORT_COIN_CAP, income)

func can_place(type: String, cell: Vector2i, rotation_quarters := 0) -> String:
	if not BUILDINGS.has(type):
		return "未知建筑类型"
	if not building_is_unlocked(type):
		return "%s尚未解锁" % BUILDINGS[type].name
	var footprint := rotated_footprint(BUILDING_FOOTPRINTS.get(type, Vector2i.ONE), rotation_quarters)
	var footprint_cells := building_footprint_cells(type, cell, footprint)
	for footprint_cell in footprint_cells:
		if footprint_cell.x < 0 or footprint_cell.x >= GRID_SIZE or footprint_cell.y < 0 or footprint_cell.y >= GRID_SIZE:
			return "超出地图边界"
	var region_level := region_level_for_cell(cell)
	if region_level > map_region_level:
		return region_lock_message(region_level)
	for footprint_cell in footprint_cells:
		if region_level_for_cell(footprint_cell) > map_region_level:
			return region_lock_message(region_level_for_cell(footprint_cell))
		if is_water_cell(footprint_cell):
			return "河道上不能建造"
		if is_village_main_road_cell(footprint_cell):
			return "村庄主路上不能建造"
		if is_npc_bridge_access_cell(footprint_cell):
			return "桥头需留出通行空间"
		if is_reserved_forest(footprint_cell):
			return "保留林地不能建造，请在林缘布置伐木场"
		if has_scenery_tree(footprint_cell):
			return "建筑占地有树木，请避开树木所在格"
		if occupied.has(footprint_cell):
			return "建筑占地被占用"
		if roads.has(footprint_cell):
			return "建筑占地已有道路，请先拆除道路"
	var definition: Dictionary = BUILDINGS[type]
	if wood < int(definition.cost):
		return "木材不足（需要 %d）" % definition.cost
	if coins < int(definition.coin_cost):
		return "铜钱不足（需要 %d）" % definition.coin_cost
	if type == "farm" and not is_farm_lot(cell, footprint):
		return "农田只能建在河岸；东原支流与旧河道两侧均可耕种"
	if type == "lumber" and not is_lumber_cell(cell):
		return "伐木场需要建在东麓、东原或北关的林缘"
	return ""

func can_unlock_next_region() -> String:
	if ended != "":
		return "游戏已结束，无法继续开拓"
	if map_region_level >= REGION_DEFINITIONS.size() - 1:
		return "河谷全境已开放"
	var next_level := map_region_level + 1
	for item in chapter_numeric_goals(next_level):
		if not bool(item.completed):
			return "%s还需达到 %d" % [item.name, item.target]
	return ""

func unlock_next_region() -> void:
	var reason := can_unlock_next_region()
	if reason != "":
		show_message(reason)
		return
	var next_level := map_region_level + 1
	var cost: Dictionary = REGION_UNLOCK_COSTS[next_level]
	# 条件和扣费在同一函数内再次校验，防止重复点击造成负库存。
	if wood < int(cost.wood) or food < int(cost.food) or coins < int(cost.coins):
		show_message("开拓费用不足")
		return
	wood -= int(cost.wood)
	food -= int(cost.food)
	coins -= int(cost.coins)
	map_region_level = next_level
	var reward_message := apply_region_reward(next_level)
	check_failure_conditions()
	clear_ghost()
	update_region_visuals()
	show_message("%s\n%s" % [REGION_UNLOCK_FEEDBACK[next_level], reward_message])
	update_ui()
	save_game(false)

func apply_region_reward(level: int) -> String:
	var reward: Dictionary = REGION_UNLOCK_REWARDS[level]
	var wood_reward := int(reward.wood)
	var food_reward := int(reward.food)
	var coin_reward := int(reward.coins)
	var happiness_reward := int(reward.happiness)
	var gained_wood := mini(wood_reward, maxi(0, wood_capacity() - wood))
	var gained_food := mini(food_reward, maxi(0, food_capacity() - food))
	wood += gained_wood
	food += gained_food
	coins += coin_reward
	happiness = mini(100, happiness + happiness_reward)
	var parts: Array[String] = []
	if wood_reward > 0:
		parts.append("获得木材 %d%s" % [gained_wood, "，溢出 %d" % (wood_reward - gained_wood) if gained_wood < wood_reward else ""])
	if food_reward > 0:
		parts.append("获得粮食 %d%s" % [gained_food, "，溢出 %d" % (food_reward - gained_food) if gained_food < food_reward else ""])
	if coin_reward > 0:
		parts.append("获得铜钱 %d" % coin_reward)
	if happiness_reward > 0:
		parts.append("幸福度 +%d" % happiness_reward)
	return "开拓奖励：%s" % "；".join(parts)

func add_building(type: String, cell: Vector2i, free := false, forced_id := -1, forced_enabled := true, footprint := Vector2i.ZERO, rotation_quarters := 0) -> void:
	if ended != "":
		return
	if footprint == Vector2i.ZERO:
		footprint = BUILDING_FOOTPRINTS.get(type, Vector2i.ONE)
	var base_footprint := footprint
	rotation_quarters = posmod(rotation_quarters, 4)
	footprint = rotated_footprint(base_footprint, rotation_quarters)
	var model: Node3D
	if type in ["workshop", "clinic"] and base_footprint == Vector2i.ONE:
		model = RealisticKit.create_building(type, false, true, true)
	elif type == "farm" and base_footprint == Vector2i.ONE:
		model = RealisticKit.create_asset("building.farm", false)
	elif type == "farm" and base_footprint == Vector2i(2, 1):
		model = RealisticKit.create_building(type, false, true, false, base_footprint)
	else:
		model = create_building_model(type)
	if type == "warehouse" and footprint == Vector2i.ONE:
		model.scale *= Vector3(0.5, 0.75, 0.5)
		model.set_meta("legacy_compact", true)
	model.position = building_model_position(type, cell, footprint)
	model.rotation.y = rotation_quarters * PI * 0.5
	var building_id := forced_id if forced_id >= 0 else next_id
	if forced_id < 0:
		next_id += 1
	else:
		next_id = max(next_id, forced_id + 1)
	model.set_meta("building_id", building_id)
	building_root.add_child(model)
	var record := {
		"id": building_id, "type": type, "cell": cell, "node": model, "footprint": footprint,
		"base_footprint": base_footprint, "rotation_quarters": rotation_quarters,
		"enabled": forced_enabled, "assigned_workers": 0, "last_running": false
	}
	buildings.append(record)
	for footprint_cell in building_footprint_cells(type, cell, footprint):
		occupied[footprint_cell] = building_id
	if not free:
		wood -= int(BUILDINGS[type].cost)
		coins -= int(BUILDINGS[type].coin_cost)
	assign_workers()
	if citizen_root and citizen_root.get_child_count() > 0:
		update_citizen_schedules()
	refresh_animal_routes()
	update_building_status_markers()
	if not free:
		check_failure_conditions()

func remove_building_by_id(building_id: int, refund := true) -> void:
	if ended != "":
		return
	for index in range(buildings.size()):
		var record: Dictionary = buildings[index]
		if int(record.id) == building_id:
			if refund:
				wood += int(BUILDINGS[record.type].cost) / 2
				coins += int(BUILDINGS[record.type].coin_cost) / 2
			for footprint_cell in building_footprint_cells(str(record.type), record.cell, record_footprint(record)):
				occupied.erase(footprint_cell)
			record.node.queue_free()
			buildings.remove_at(index)
			# Capacity can fall when demolishing a warehouse. Existing stock and
			# recovered building material remain owned; only new intake is limited.
			break
	selected_building_id = -1
	inspector.visible = false
	assign_workers()
	if citizen_root and citizen_root.get_child_count() > 0:
		update_citizen_schedules()
	refresh_animal_routes()
	update_building_status_markers()
	check_failure_conditions()

func demolish_selected() -> void:
	if ended != "":
		return
	if roads.has(selected_road_cell):
		var removed_cell := selected_road_cell
		remove_road(removed_cell, true)
		selected_road_cell = Vector2i(-1, -1)
		inspector.visible = false
		show_message("已拆除道路，返还木材 %d" % ROAD_WOOD_COST)
		update_ui()
		save_game(false)
		return
	if selected_building_id < 0:
		return
	var name := "建筑"
	for record in buildings:
		if int(record.id) == selected_building_id:
			name = BUILDINGS[record.type].name
			break
	remove_building_by_id(selected_building_id)
	show_message("已拆除%s并返还一半木材与铜钱" % name)
	update_ui()
	save_game(false)

func available_workers() -> int:
	return ceili(population * 0.70)

func workforce_plan() -> Dictionary:
	var available := available_workers()
	var remaining := available
	var demand := 0
	var assigned := 0
	var by_id := {}
	for record in buildings:
		var required := int(BUILDINGS[record.type].workers)
		if required > 0:
			by_id[int(record.id)] = 0
			if bool(record.get("enabled", true)):
				demand += required
	# Essential food and raw materials receive workers first, followed by
	# manufacturing, commerce and the later civic services.
	for priority_type in ["farm", "fishpond", "lumber", "workshop", "market", "clinic", "academy"]:
		for record in buildings:
			if str(record.type) != priority_type or not bool(record.get("enabled", true)):
				continue
			var required := int(BUILDINGS[record.type].workers)
			var allocated := mini(required, remaining)
			by_id[int(record.id)] = allocated
			assigned += allocated
			remaining -= allocated
	return {"available": available, "demand": demand, "assigned": assigned, "by_id": by_id}

func assign_workers() -> Dictionary:
	var plan := workforce_plan()
	var by_id: Dictionary = plan.by_id
	for record in buildings:
		record.assigned_workers = int(by_id.get(int(record.id), 0))
	return plan

func set_building_enabled(building_id: int, enabled: bool) -> void:
	if ended != "":
		return
	for record in buildings:
		if int(record.id) != building_id:
			continue
		if int(BUILDINGS[record.type].workers) <= 0:
			return
		record.enabled = enabled
		record.last_running = false
		assign_workers()
		if selected_building_id == building_id:
			show_inspector(building_id)
		show_message("%s已%s" % [BUILDINGS[record.type].name, "启用" if enabled else "暂停"])
		update_ui()
		save_game(false)
		return

func toggle_selected_building() -> void:
	if selected_building_id < 0:
		return
	for record in buildings:
		if int(record.id) == selected_building_id:
			set_building_enabled(selected_building_id, not bool(record.get("enabled", true)))
			return

func next_day() -> void:
	if ended != "" or day_settling:
		return
	# Check a complete incoming state, never intermediate daily transactions.
	if check_failure_conditions():
		update_ui()
		return
	day_settling = true
	auto_day_elapsed = 0.0
	var plan := assign_workers()
	var wood_gain := 0
	var food_gain := 0
	for record in buildings:
		record.last_running = false
		if not bool(record.get("enabled", true)):
			continue
		var definition: Dictionary = BUILDINGS[record.type]
		var required_workers := int(definition.workers)
		if str(definition.get("staffing", "")) == "proportional":
			var assigned := int(record.get("assigned_workers", 0))
			var produced_wood := int(floor(building_output(str(record.type), "wood") * assigned / float(required_workers)))
			var produced_food := int(floor(building_output(str(record.type), "food") * assigned / float(required_workers)))
			record.last_running = assigned > 0
			wood_gain += produced_wood
			food_gain += produced_food
	wood = storage_after_intake(wood, wood_gain, wood_capacity())
	food = storage_after_intake(food, food_gain, food_capacity())

	var house_food_upkeep := building_count("house") * building_input("house", "food")
	var ration := ceili(population / 2.0)
	var daily_food_need := house_food_upkeep + ration
	var shortage := food < daily_food_need
	food = maxi(0, food - daily_food_need)

	var running_workshops := 0
	for record in buildings:
		if record.type != "workshop" or not bool(record.get("enabled", true)):
			continue
		var required_workers := int(BUILDINGS.workshop.workers)
		var wood_input := building_input("workshop", "wood")
		var food_input := building_input("workshop", "food")
		var coin_output := building_output("workshop", "coins")
		if int(record.get("assigned_workers", 0)) == required_workers and wood >= wood_input and food >= food_input:
			wood -= wood_input
			food -= food_input
			coins += coin_output
			running_workshops += 1
			record.last_running = true

	var running_clinics := 0
	var running_academies := 0
	for record in buildings:
		if not bool(record.get("enabled", true)):
			continue
		var service_type := str(record.type)
		if service_type not in ["market", "clinic", "academy"]:
			continue
		var service_workers := int(BUILDINGS[service_type].workers)
		if int(record.get("assigned_workers", 0)) < service_workers:
			continue
		if service_type == "market":
			var market_food_input := building_input("market", "food")
			var market_coin_output := building_output("market", "coins")
			if food < market_food_input:
				continue
			food -= market_food_input
			coins += market_coin_output
		elif service_type == "clinic":
			running_clinics += 1
		elif service_type == "academy":
			var academy_coin_output := building_output("academy", "coins")
			coins += academy_coin_output
			running_academies += 1
		record.last_running = true
	var road_transport_income := daily_road_transport_income()
	coins += road_transport_income

	var population_tax := int(floor(population / 2.0))
	# Household levy and basic trade provide income before markets unlock.
	# Failure is evaluated after the complete day's income and maintenance.
	population_tax = maxi(1, population_tax)
	var basic_trade_income := daily_basic_trade_income()
	coins += population_tax
	coins += basic_trade_income
	var maintenance_bill := 0
	for record in buildings:
		if bool(record.get("enabled", true)):
			maintenance_bill += int(BUILDINGS[record.type].maintenance)
	var total_maintenance_due := maintenance_bill + maintenance_debt
	if coins >= total_maintenance_due:
		coins -= total_maintenance_due
		maintenance_debt = 0
	else:
		maintenance_debt = total_maintenance_due - coins
		coins = 0
	var maintenance_paid := maintenance_debt == 0

	var starvation_departures := mini(1, population) if shortage else 0
	if shortage:
		population -= starvation_departures
	else:
		var empty_beds := housing_capacity() - population
		var migration_ration := ceili(population / 2.0)
		var jobs_needed := ceili((population + 1) * 0.5)
		var can_migrate := (
			happiness >= 55 and empty_beds >= 1 and food >= 2 * migration_ration
			and maintenance_paid and enabled_job_capacity() >= jobs_needed
		)
		if can_migrate:
			var arrivals := 2 if happiness >= 75 and food >= 4 * migration_ration else 1
			arrivals = mini(mini(arrivals, empty_beds), 50 - population)
			population += arrivals

	day += 1
	var happiness_before_event := happiness
	var event_message := trigger_event(day % 4)
	var event_happiness_modifier := happiness - happiness_before_event
	happiness = happiness_before_event
	var job_demand := int(plan.demand)
	var staffing_ratio := float(plan.assigned) / float(job_demand) if job_demand > 0 else 0.0
	var happiness_target := 50
	var happiness_food_need := maxi(1, ceili(population / 2.0) + building_count("house"))
	if shortage:
		happiness_target -= 15
	elif food >= happiness_food_need * 4:
		happiness_target += 8
	elif food >= happiness_food_need * 2:
		happiness_target += 5
	elif food >= happiness_food_need:
		happiness_target += 2
	var empty_beds_after := housing_capacity() - population
	if empty_beds_after >= 4:
		happiness_target += 5
	elif empty_beds_after >= 1:
		happiness_target += 2
	elif empty_beds_after < 0:
		happiness_target -= 10
	if staffing_ratio >= 0.75:
		happiness_target += 8
	elif staffing_ratio >= 0.50:
		happiness_target += 3
	else:
		happiness_target -= 5
	happiness_target += mini(int(BUILDINGS.workshop.effect_cap), running_workshops * building_effect("workshop", "happiness_target"))
	happiness_target += mini(int(BUILDINGS.clinic.effect_cap), running_clinics * building_effect("clinic", "happiness_target"))
	happiness_target += mini(int(BUILDINGS.academy.effect_cap), running_academies * building_effect("academy", "happiness_target"))
	happiness_target += 5 if maintenance_paid else -10
	happiness_target += event_happiness_modifier
	happiness_target = clampi(happiness_target, 0, 100)
	var happiness_change := clampi(happiness_target - happiness, -6, 3)
	happiness = clampi(happiness + happiness_change, 0, 100)
	# Resolve departures using today's final happiness. Food shortage and low
	# morale overlap, so apply only the larger loss instead of adding both.
	var morale_departures := 2 if happiness < 20 else (1 if happiness < 40 else 0)
	population = maxi(0, population - maxi(0, morale_departures - starvation_departures))

	if not shortage and maintenance_paid and staffing_ratio >= 0.70:
		stable_days += 1
	else:
		stable_days = 0
	low_happiness_days = low_happiness_days + 1 if happiness < 20 else 0
	if check_failure_conditions():
		pass
	elif (
		map_region_level >= REGION_DEFINITIONS.size() - 1
		and population >= VICTORY_POPULATION
		and wood >= VICTORY_WOOD
		and food >= VICTORY_FOOD
		and coins >= VICTORY_COINS
		and happiness >= VICTORY_HAPPINESS
	):
		end_game("win")
	show_message(event_message)
	update_citizens()
	update_ui()
	save_game(false)
	day_settling = false

func daily_basic_trade_income() -> int:
	var income := 0
	for record in buildings:
		if (
			str(record.type) in ["farm", "lumber"]
			and bool(record.get("enabled", true))
			and int(record.get("assigned_workers", 0)) > 0
		):
			income += int(BUILDINGS[record.type].get("trade_coins", BASIC_TRADE_COINS_PER_SITE))
	return mini(BASIC_TRADE_COIN_CAP, income)

func trigger_event(event_index: int) -> String:
	match event_index:
		0:
			var extra_food := projected_gathering_output("farm")
			food = storage_after_intake(food, extra_food, food_capacity())
			return "丰收：农田产出翻倍，本日额外获得粮食"
		1:
			wood = maxi(0, wood - staffed_building_count("lumber") * 2)
			return "雨季：伐木场产出受影响"
		2:
			if wood >= wood_capacity():
				return "商旅经过：木材仓储已满，未进行交易"
			if food >= 10:
				food -= 10
				var traded_wood := mini(25, wood_capacity() - wood)
				wood = storage_after_intake(wood, traded_wood, wood_capacity())
				return "商旅抵达：支付 10 粮食，木材入库 %d" % traded_wood
			else:
				return "商旅经过，但库存不足以交易"
		3:
			happiness = maxi(0, happiness - 8)
			return "居民争执：幸福度 -8"
	return ""

func enabled_job_capacity() -> int:
	var capacity := 0
	for record in buildings:
		if bool(record.get("enabled", true)):
			capacity += int(BUILDINGS[record.type].workers)
	return capacity

func projected_gathering_output(type: String) -> int:
	var total := 0
	for record in buildings:
		if str(record.type) != type or not bool(record.get("enabled", true)):
			continue
		var definition: Dictionary = BUILDINGS[type]
		var required := int(definition.workers)
		if required <= 0:
			continue
		var base_output := building_output(type, "food") if type in ["farm", "fishpond"] else building_output(type, "wood")
		total += int(floor(base_output * int(record.get("assigned_workers", 0)) / float(required)))
	return total

func staffed_building_count(type: String) -> int:
	var count := 0
	for record in buildings:
		if (
			str(record.type) == type and bool(record.get("enabled", true))
			and int(record.get("assigned_workers", 0)) > 0
		):
			count += 1
	return count

func migration_block_reason() -> String:
	if housing_capacity() <= population:
		return "今日无人迁入：缺少空床位"
	if happiness < 55:
		return "今日无人迁入：幸福度不足"
	var migration_ration := ceili(population / 2.0)
	if food < 2 * migration_ration:
		return "今日无人迁入：粮食储备不足两日口粮"
	if maintenance_debt > 0:
		return "今日无人迁入：仍有维护欠款"
	var jobs_needed := ceili((population + 1) * 0.5)
	if enabled_job_capacity() < jobs_needed:
		return "今日无人迁入：生产岗位不足"
	return "今日无人迁入：尚未达到迁入条件"

func building_count(type: String) -> int:
	var count := 0
	for record in buildings:
		if record.type == type:
			count += 1
	return count

func building_count_in_region(type: String, level: int) -> int:
	var count := 0
	for record in buildings:
		if str(record.type) == type and region_level_for_cell(record.cell) == level:
			count += 1
	return count

func housing_capacity() -> int:
	return building_count("house") * building_effect("house", "housing")

func wood_capacity() -> int:
	return 100 + connected_warehouse_count() * building_effect("warehouse", "wood_capacity")

func food_capacity() -> int:
	return 100 + connected_warehouse_count() * building_effect("warehouse", "food_capacity")

func connected_warehouse_count() -> int:
	var count := 0
	for record in buildings:
		if str(record.type) == "warehouse" and building_has_connected_road(record):
			count += 1
	return count

func storage_after_intake(current: int, gained: int, capacity: int) -> int:
	# Never clamp owned stock down to a newly reduced capacity. While overfull,
	# production/rewards wait for free space; consumption continues normally.
	return current + mini(maxi(0, gained), maxi(0, capacity - current))

func update_ui() -> void:
	var plan := assign_workers()
	update_building_status_markers(plan)
	status_label.text = "第 %d 日 · %s\n木材 %d/%d · 粮食 %d/%d · 铜钱 %d · 人口 %d/%d · 幸福度 %d" % [
		day, time_status_text(), wood, wood_capacity(), food, food_capacity(), coins, population, housing_capacity(), happiness
	]
	status_label.tooltip_text = "木材容量 %d · 粮食容量 %d · 住房 %d · 有效劳力 %d · 启用岗位 %d · 稳定 %d 日 · 维护欠款 %d" % [
		wood_capacity(), food_capacity(), housing_capacity(), plan.available, plan.demand, stable_days, maintenance_debt
	]
	status_label.tooltip_text += "\n日结幸福度低于 40：离开 1 人；低于 20：离开 2 人。缺粮与低幸福取较大流失人数。\n人口或铜钱归零即失败；幸福度连续 3 日低于 20 也会失败。"
	status_label.tooltip_text += "\n仓库接通主路才增加容量；超出容量的存量保留，腾出空间后恢复入库。"
	goal_label.tooltip_text = "章节目标在开拓下一地区后切换；达成的目标会以绿色勾选显示。"
	if map_region_level >= REGION_DEFINITIONS.size() - 1:
		goal_label.text = "%s · %s\n目标：%s" % [CAMPAIGN_CHAPTERS[6], CAMPAIGN_STAGE_NAMES[6], final_current_task_text()]
	else:
		var next_level := map_region_level + 1
		goal_label.text = "%s · %s\n目标：%s" % [CAMPAIGN_CHAPTERS[map_region_level], CAMPAIGN_STAGE_NAMES[map_region_level], current_task_text(next_level)]
	if region_panel and region_title and region_body and region_unlock_button:
		if map_region_level >= REGION_DEFINITIONS.size() - 1:
			region_title.text = "%s · %s" % [CAMPAIGN_CHAPTERS[6], CAMPAIGN_STAGE_NAMES[6]]
			var final_body_text := "建设：东境全域\n用途：建成完整而稳定的新城\n\n目标：\n%s" % final_goal_requirements_text()
			region_body.set_content(final_body_text, final_goal_display_lines())
			region_unlock_button.text = "全域已开放"
			region_unlock_button.disabled = true
			region_unlock_button.tooltip_text = "完成终章目标即可复兴东境"
		else:
			var next_level := map_region_level + 1
			var next_region: Dictionary = REGION_DEFINITIONS[next_level]
			var reason := can_unlock_next_region()
			region_title.text = "%s · %s" % [CAMPAIGN_CHAPTERS[map_region_level], CAMPAIGN_STAGE_NAMES[map_region_level]]
			var chapter_body_text := "开拓：%s · %d格\n用途：%s\n\n目标：\n%s" % [
				next_region.name, next_region.area, next_region.summary, chapter_goal_requirements_text(next_level)
			]
			region_body.set_content(chapter_body_text, chapter_goal_display_lines(next_level))
			region_unlock_button.text = "开拓%s" % next_region.short_name
			region_unlock_button.disabled = ended != "" or reason != ""
			region_unlock_button.tooltip_text = reason if reason != "" else "条件齐备，可以开拓%s" % next_region.name
		apply_region_panel_layout()
	update_build_menu()
	if selected_building_id >= 0:
		show_inspector(selected_building_id)
	elif roads.has(selected_road_cell):
		show_road_inspector(selected_road_cell)
	update_time_controls()

func show_message(text: String) -> void:
	message_label.text = text

func next_stage_preview(level: int) -> String:
	if level < REGION_DEFINITIONS.size() - 1:
		return "%s · 开拓%s" % [CAMPAIGN_STAGE_NAMES[level], REGION_DEFINITIONS[level + 1].name]
	return "东境复兴 · 达成最终人口与物资目标"

func required_population_for_level(level: int) -> int:
	return int(REGION_REQUIREMENTS[level].population) if level >= 1 and level < REGION_REQUIREMENTS.size() else 0

func chapter_numeric_goals(level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if level < 1 or level >= REGION_REQUIREMENTS.size():
		return result
	var requirement: Dictionary = REGION_REQUIREMENTS[level]
	var names := {"population": "人口", "happiness": "幸福度", "wood": "木材", "food": "粮食", "coins": "铜钱"}
	for key in ["population", "happiness", "wood", "food", "coins"]:
		var target := int(requirement[key])
		result.append({"key": key, "name": names[key], "target": target, "text": "%s %d" % [names[key], target], "completed": int(get(key)) >= target})
	return result

func current_task_text(level: int) -> String:
	# `level` is the region this chapter will open.  The sentence deliberately
	# depends only on the chapter index, so construction, resources and time can
	# never replace the player's declared objective midway through a chapter.
	match level:
		1: return "建好河湾聚落，开拓北坡"
		2: return "壮大聚落储备，开拓东麓"
		3: return "积累物资民心，开拓高台"
		4: return "繁荣河谷聚落，开拓东原"
		5: return "扩充人口储备，开拓北关"
		6: return "汇聚人口物资，开拓新都"
	return "推进东境复兴"

func chapter_goal_requirements_text(level: int) -> String:
	var goals := chapter_numeric_goals(level)
	if goals.is_empty():
		return "• 推进东境复兴"
	var settlement_terms: Array[String] = []
	var stock_terms: Array[String] = []
	for item in goals:
		if str(item.key) in ["population", "happiness"]:
			settlement_terms.append(str(item.text))
		else:
			stock_terms.append(str(item.text))
	return "• 聚落：%s\n• 储备：%s" % [" · ".join(settlement_terms), " · ".join(stock_terms)]

func chapter_goal_display_lines(level: int) -> Array:
	if level < 1 or level >= REGION_REQUIREMENTS.size():
		return [{"text": "推进东境复兴", "requirement": true, "completed": false}]
	var next_region: Dictionary = REGION_DEFINITIONS[level]
	var lines: Array = [
		{"text": "开拓：%s · %d格" % [next_region.name, next_region.area]},
		{"text": "用途：%s" % next_region.summary},
		{"text": "目标："},
	]
	var goals := chapter_numeric_goals(level)
	for group in [["population", "happiness"], ["wood", "food", "coins"]]:
		var terms: Array[String] = []
		var segments: Array = []
		var complete := true
		for item in goals:
			if str(item.key) not in group:
				continue
			terms.append(str(item.text))
			segments.append({"text": item.text, "completed": item.completed})
			complete = complete and bool(item.completed)
		var prefix := "聚落：" if "population" in group else "储备："
		lines.append({"text": prefix + " · ".join(terms), "requirement": true, "completed": complete, "prefix": prefix, "segments": segments})
	return lines

func final_current_task_text() -> String:
	return "建设天际新都，复兴东境"

func final_goal_requirements_text() -> String:
	return "• 聚落：人口 %d · 幸福度 %d\n• 储备：木材 %d · 粮食 %d · 铜钱 %d" % [
		VICTORY_POPULATION, VICTORY_HAPPINESS,
		VICTORY_WOOD, VICTORY_FOOD, VICTORY_COINS,
	]

func final_goal_display_lines() -> Array:
	return [
		{"text": "建设：东境全域"},
		{"text": "用途：建成完整而稳定的新城"},
		{"text": "目标："},
		{"text": "聚落：人口 %d · 幸福度 %d" % [VICTORY_POPULATION, VICTORY_HAPPINESS], "requirement": true, "completed": population >= VICTORY_POPULATION and happiness >= VICTORY_HAPPINESS, "prefix": "聚落：", "segments": [
			{"text": "人口 %d" % VICTORY_POPULATION, "completed": population >= VICTORY_POPULATION},
			{"text": "幸福度 %d" % VICTORY_HAPPINESS, "completed": happiness >= VICTORY_HAPPINESS},
		]},
		{"text": "储备：木材 %d · 粮食 %d · 铜钱 %d" % [VICTORY_WOOD, VICTORY_FOOD, VICTORY_COINS], "requirement": true, "completed": wood >= VICTORY_WOOD and food >= VICTORY_FOOD and coins >= VICTORY_COINS, "prefix": "储备：", "segments": [
			{"text": "木材 %d" % VICTORY_WOOD, "completed": wood >= VICTORY_WOOD},
			{"text": "粮食 %d" % VICTORY_FOOD, "completed": food >= VICTORY_FOOD},
			{"text": "铜钱 %d" % VICTORY_COINS, "completed": coins >= VICTORY_COINS},
		]},
	]

func show_inspector(building_id: int) -> void:
	assign_workers()
	for record in buildings:
		if int(record.id) == building_id:
			selected_building_id = building_id
			selected_road_cell = Vector2i(-1, -1)
			var definition: Dictionary = BUILDINGS[record.type]
			inspector_title.text = definition.name
			var status := building_operation_text(record)
			var operation := building_operation_state(record)
			set_inspector_status(status, str(operation.code) in ["running", "passive"])
			var road_status := building_road_status_text(record)
			inspector_body.text = "%s%s\n\n拆除返还：%d 木材 · %d 铜钱" % [
				building_effect_text(str(record.type), false), "\n" + road_status if road_status != "" else "",
				int(definition.cost) / 2, int(definition.coin_cost) / 2
			]
			inspector_toggle_button.visible = int(definition.workers) > 0
			inspector_toggle_button.text = "暂停生产" if bool(record.get("enabled", true)) else "启用生产"
			inspector_demolish_button.text = "删除建筑（返还一半木材与铜钱）"
			inspector.visible = true
			return

func set_inspector_status(text: String, normal: bool) -> void:
	inspector_status.text = text
	inspector_status.add_theme_color_override("font_color", Color("39764b") if normal else Color("a63d32"))

func building_road_status_text(record: Dictionary) -> String:
	if str(record.type) not in ROAD_ELIGIBLE_BUILDING_TYPES:
		return ""
	if building_has_connected_road(record):
		return "道路：已接通村庄主路｜正常运行时铜钱 +%d/日（全城上限 +%d）" % [ROAD_TRANSPORT_BONUS, ROAD_TRANSPORT_COIN_CAP]
	return "道路：未接通村庄主路｜接通并正常运行后铜钱 +%d/日（全城上限 +%d）" % [ROAD_TRANSPORT_BONUS, ROAD_TRANSPORT_COIN_CAP]

func show_road_inspector(cell: Vector2i) -> void:
	if not roads.has(cell):
		return
	selected_building_id = -1
	selected_road_cell = cell
	inspector_title.text = "道路"
	var connected := is_road_connected(cell)
	set_inspector_status("状态：已接通村庄主路" if connected else "状态：尚未接通村庄主路", connected)
	inspector_body.text = "铺设：木材 -%d/格\n作用：连接村庄主路与生产建筑\n收益：相邻且正常运行的农田、鱼塘、伐木场、工坊、集市或书院，铜钱 +%d/日（全城上限 +%d）\n\n拆除返还：木材 %d" % [
		ROAD_WOOD_COST, ROAD_TRANSPORT_BONUS, ROAD_TRANSPORT_COIN_CAP,
		ROAD_WOOD_COST,
	]
	inspector_toggle_button.visible = false
	inspector_demolish_button.text = "拆除道路（返还木材 %d）" % ROAD_WOOD_COST
	inspector.visible = true

func building_operation_state(record: Dictionary, plan: Dictionary = {}) -> Dictionary:
	var definition: Dictionary = BUILDINGS[record.type]
	var required := int(definition.workers)
	var result := {"code": "running", "required": required, "assigned": 0, "missing": []}
	if bool(definition.get("requires_road", false)) and not building_has_connected_road(record):
		result.code = "road"
		return result
	if required <= 0:
		result.code = "passive"
		return result
	if not bool(record.get("enabled", true)):
		result.code = "paused"
		return result
	if plan.is_empty():
		plan = workforce_plan()
	result.assigned = int(plan.by_id.get(int(record.id), 0))
	var proportional := str(definition.get("staffing", "passive")) == "proportional"
	if int(result.assigned) == 0 or (not proportional and int(result.assigned) < required):
		result.code = "workers"
		return result
	if proportional:
		return result
	# This is current readiness, not a promise of next-day output: gathering,
	# household food and earlier recipes can change stock before settlement.
	var inputs: Dictionary = definition.get("inputs", {})
	for resource in ["wood", "food"]:
		var needed := int(inputs.get(resource, 0))
		var available := wood if resource == "wood" else food
		if needed > available:
			result.missing.append("%s需 %d（现有 %d）" % [resource_label(resource), needed, available])
	if not result.missing.is_empty():
		result.code = "materials"
	return result

func get_building_status_marker(building_id: int) -> Label3D:
	for record in buildings:
		if int(record.id) == building_id:
			return record.node.get_node_or_null("OperationStatus") as Label3D
	return null

func update_building_status_markers(plan: Dictionary = {}) -> void:
	if plan.is_empty():
		plan = workforce_plan()
	for record in buildings:
		if int(BUILDINGS[record.type].workers) <= 0 and not bool(BUILDINGS[record.type].get("requires_road", false)):
			continue
		var model: Node3D = record.node
		if not is_instance_valid(model) or model.is_queued_for_deletion():
			continue
		var marker := model.get_node_or_null("OperationStatus") as Label3D
		if marker == null:
			marker = Label3D.new()
			marker.name = "OperationStatus"
			marker.font_size = 64
			marker.pixel_size = 0.012
			marker.outline_size = 6
			marker.outline_modulate = Color("f3e8cb")
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.shaded = false
			marker.no_depth_test = true
			var highest := 0.0
			for node in model.find_children("*", "MeshInstance3D", true, false):
				var mesh_node := node as MeshInstance3D
				if mesh_node.mesh == null or not mesh_node.is_visible_in_tree():
					continue
				var relative := model.global_transform.affine_inverse() * mesh_node.global_transform
				var bounds: AABB = relative * mesh_node.mesh.get_aabb()
				highest = maxf(highest, bounds.end.y)
			marker.position = Vector3(0, highest + 0.40, 0)
			model.add_child(marker)
		var state := building_operation_state(record, plan)
		var code := str(state.code)
		marker.visible = code in ["paused", "workers", "materials", "road"]
		marker.text = {"paused": "Ⅱ", "workers": "!", "materials": "!", "road": "!"}.get(code, "")
		marker.modulate = {"paused": Color("725a43"), "workers": Color("a76a24"), "materials": Color("a54f35"), "road": Color("a63d32")}.get(code, Color("725a43"))
		marker.set_meta("operation_state", code)
		marker.set_meta("building_id", int(record.id))

func building_operation_text(record: Dictionary) -> String:
	var definition: Dictionary = BUILDINGS[record.type]
	var state := building_operation_state(record)
	var required := int(state.required)
	if str(state.code) == "road":
		return "状态：未接通主路｜仓储停用"
	if bool(definition.get("requires_road", false)):
		return "状态：已接通主路｜仓储生效"
	if required <= 0:
		return "状态：持续生效"
	if not bool(record.get("enabled", true)):
		return "状态：已暂停｜不占岗位｜不收维护费"
	var assigned := int(state.assigned)
	var type := str(record.type)
	if str(definition.get("staffing", "passive")) == "proportional":
		if assigned <= 0:
			return "状态：无人生产｜在岗 0/%d｜本日产出 0" % required
		var actual_outputs: Dictionary = {}
		var outputs: Dictionary = definition.get("outputs", {})
		for resource in outputs:
			actual_outputs[resource] = int(floor(int(outputs[resource]) * assigned / float(required)))
		return "状态：生产中｜在岗 %d/%d｜本日预计：%s%s" % [
			assigned, required, resource_change_text(actual_outputs, 1), "；参与民生交易" if int(definition.get("trade_coins", 0)) > 0 else ""
		]
	if assigned < required:
		return "状态：缺工｜在岗 %d/%d｜本日不运行" % [assigned, required]
	var missing: Array = state.missing
	if not missing.is_empty():
		return "状态：当前库存不足单次配方｜在岗 %d/%d｜%s" % [assigned, required, "、".join(missing)]
	if type == "workshop":
		return "状态：当前库存够单次配方｜在岗 %d/%d｜结算时按库存依序处理（先口粮、后加工）" % [assigned, required]
	if type == "market":
		return "状态：当前库存够单次交易｜在岗 %d/%d｜结算时按库存依序处理（口粮、工坊优先）" % [assigned, required]
	if type == "clinic":
		return "状态：应诊中｜在岗 %d/%d｜幸福度目标 +%d" % [assigned, required, building_effect(type, "happiness_target")]
	if type == "academy":
		return "状态：开课中｜在岗 %d/%d｜本日铜钱 +%d、幸福度目标 +%d" % [
			assigned, required, building_output(type, "coins"), building_effect(type, "happiness_target")
		]
	return "状态：运行中｜在岗 %d/%d" % [assigned, required]

func current_failure_reason() -> String:
	if population <= 0 and coins <= 0:
		return "人口已归零，铜钱已耗尽，聚落无法继续经营。"
	if population <= 0:
		return "人口已归零，聚落无人留守，经营失败。"
	if coins <= 0:
		return "铜钱已耗尽，聚落无法继续经营。"
	if low_happiness_days >= 3:
		return "幸福度连续 3 日低于 20，居民失去信心，经营失败。"
	return ""

func check_failure_conditions() -> bool:
	if ended != "":
		return ended == "lose"
	var reason := current_failure_reason()
	if reason.is_empty():
		return false
	end_game("lose", reason)
	return true

func end_game(result: String, reason := "") -> void:
	if ended != "":
		return
	ended = result
	failure_reason = reason if result == "lose" else ""
	if result == "lose" and failure_reason.is_empty():
		failure_reason = current_failure_reason()
		if failure_reason.is_empty():
			failure_reason = "本次经营已经结束，请重新规划聚落。"
	time_paused = true
	clear_ghost()
	if settings_overlay:
		settings_overlay.visible = false
	end_layer = CanvasLayer.new()
	end_layer.name = "GameResult"
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
	title.name = "ResultTitle"
	title.text = "东境全域复兴！" if result == "win" else "经营失败"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("6b4731"))
	box.add_child(title)
	var detail := Label.new()
	detail.name = "ResultDetail"
	detail.add_theme_color_override("font_color", Color("6b4731"))
	detail.custom_minimum_size.x = 400
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.text = "七境相连，粮木充足，百姓安居。昔日河湾已经成为一座繁盛新城。" if result == "win" else failure_reason
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(detail)
	box.add_child(make_action_button("重新开始", reset_game.bind(true), Color("d6a74a")))

func reset_game(confirm_reset := true) -> void:
	prepare_village_life_variants()
	if end_layer and is_instance_valid(end_layer):
		end_layer.queue_free()
		end_layer = null
	for child in building_root.get_children():
		child.queue_free()
	for child in road_root.get_children():
		child.queue_free()
	day = 1
	wood = 100
	food = 40
	coins = 60
	population = 4
	happiness = 60
	low_happiness_days = 0
	stable_days = 0
	maintenance_debt = 0
	map_region_level = 0
	selected_type = ""
	ended = ""
	failure_reason = ""
	auto_day_elapsed = 0.0
	citizen_schedule_time = 0.0
	time_paused = false
	time_speed = 1.0
	day_settling = false
	next_id = 1
	buildings.clear()
	occupied.clear()
	roads.clear()
	legacy_cleared_tree_roads.clear()
	update_road_scenery()
	for child in citizen_root.get_children():
		child.queue_free()
	for child in animal_root.get_children():
		child.queue_free()
	selected_building_id = -1
	selected_road_cell = Vector2i(-1, -1)
	road_tool_selected = false
	inspector.visible = false
	clear_ghost()
	update_region_visuals()
	add_building("house", Vector2i(9, 9), true)
	update_citizens(false)
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
		building_data.append({
			"id": record.id, "type": record.type, "x": cell.x, "z": cell.y,
			"enabled": bool(record.get("enabled", true)), "rotation_quarters": int(record.get("rotation_quarters", 0))
		})
		if str(record.type) == "warehouse":
			building_data[-1]["warehouse_footprint"] = record_base_footprint(record).x
		elif str(record.type) == "farm":
			var farm_base := record_base_footprint(record)
			building_data[-1]["farm_footprint"] = farm_base.x * farm_base.y
		elif str(record.type) in ["workshop", "clinic"]:
			building_data[-1][str(record.type) + "_footprint"] = record_base_footprint(record).x
	var road_data: Array[Dictionary] = []
	for cell in roads:
		road_data.append({"x": cell.x, "z": cell.y})
		if legacy_cleared_tree_roads.has(cell):
			road_data[-1]["legacy_cleared_tree"] = true
	var data := {
		"version": SAVE_VERSION, "road_rules_version": 2, "map_region_level": map_region_level, "day": day, "wood": wood, "food": food, "coins": coins,
		"population": population, "happiness": happiness, "low_happiness_days": low_happiness_days,
		"stable_days": stable_days, "maintenance_debt": maintenance_debt,
		"next_id": next_id, "ended": ended, "failure_reason": failure_reason, "buildings": building_data, "roads": road_data
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
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) not in [1, 2, 3, 4]:
		if show_feedback:
			show_message("存档格式无效，当前进度未改变")
		return
	var validation_error := validate_save_data(parsed)
	if validation_error != "":
		if show_feedback:
			show_message("存档无效：%s；当前进度未改变" % validation_error)
		return
	if is_instance_valid(end_layer):
		end_layer.queue_free()
		end_layer = null
	for child in building_root.get_children():
		child.queue_free()
	for child in road_root.get_children():
		child.queue_free()
	buildings.clear()
	occupied.clear()
	roads.clear()
	legacy_cleared_tree_roads.clear()
	update_road_scenery()
	day = int(parsed.get("day", 1))
	wood = int(parsed.get("wood", 100))
	food = int(parsed.get("food", 40))
	var loaded_version := int(parsed.get("version", 1))
	var loaded_region_level := int(parsed.get("map_region_level", 0)) if loaded_version >= 2 else 0
	coins = int(parsed.get("coins", 60 + loaded_region_level * 30))
	population = int(parsed.get("population", 4))
	happiness = int(parsed.get("happiness", 60))
	low_happiness_days = int(parsed.get("low_happiness_days", 0))
	stable_days = int(parsed.get("stable_days", 0))
	maintenance_debt = int(parsed.get("maintenance_debt", 0))
	map_region_level = loaded_region_level
	next_id = int(parsed.get("next_id", 1))
	ended = ""
	failure_reason = ""
	auto_day_elapsed = 0.0
	citizen_schedule_time = 0.0
	time_paused = false
	day_settling = false
	for record in parsed.get("buildings", []):
		var type := str(record.get("type", ""))
		if BUILDINGS.has(type):
			add_building(
				type, Vector2i(int(record.get("x", 0)), int(record.get("z", 0))), true,
				int(record.get("id", -1)), bool(record.get("enabled", true)), saved_base_footprint(record), int(record.get("rotation_quarters", 0))
			)
	if loaded_version >= 4:
		for road_record in parsed.get("roads", []):
			var road_cell := Vector2i(int(road_record.get("x", 0)), int(road_record.get("z", 0)))
			var legacy_tree: bool = has_scenery_tree(road_cell) and (not parsed.has("road_rules_version") or bool(road_record.get("legacy_cleared_tree", false)))
			add_road(road_cell, true, legacy_tree)
	selected_type = ""
	road_tool_selected = false
	selected_building_id = -1
	selected_road_cell = Vector2i(-1, -1)
	inspector.visible = false
	clear_ghost()
	update_region_visuals()
	update_citizens(false)
	# Rebuild first so temporary construction state cannot trigger defeat.
	if not check_failure_conditions():
		var saved_result := str(parsed.get("ended", ""))
		if saved_result in ["win", "lose"]:
			end_game(saved_result, str(parsed.get("failure_reason", "")))
	if show_feedback and ended == "":
		show_message("存档读取完成，时间继续自动流逝")
	update_ui()

func validate_save_data(data: Dictionary) -> String:
	if not data.has("version") or not is_json_number(data.version) or float(data.version) != floor(float(data.version)):
		return "存档版本无效"
	var save_version := int(data.version)
	var numeric_fields := ["day", "wood", "food", "population", "happiness", "low_happiness_days", "next_id"]
	if save_version >= 3:
		numeric_fields.append_array(["coins", "stable_days", "maintenance_debt"])
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
	var saved_region_level := int(data.get("map_region_level", 0)) if save_version >= 2 else 0
	var saved_coins := int(data.get("coins", 60 + saved_region_level * 30))
	var saved_stable_days := int(data.get("stable_days", 0))
	var saved_maintenance_debt := int(data.get("maintenance_debt", 0))
	if saved_day < 1 or saved_day > 1000000:
		return "日期超出范围"
	if saved_population < 0 or saved_population > 50:
		return "人口超出范围"
	if saved_happiness < 0 or saved_happiness > 100:
		return "幸福度超出范围"
	if saved_low_days < 0 or saved_low_days > 1000000:
		return "低幸福计数超出范围"
	if saved_coins < 0 or saved_coins > 1000000000:
		return "铜钱超出范围"
	if saved_stable_days < 0 or saved_stable_days > 1000000:
		return "稳定天数超出范围"
	if saved_maintenance_debt < 0 or saved_maintenance_debt > 1000000000:
		return "维护欠款超出范围"
	if saved_next_id < 1:
		return "下一个建筑编号无效"
	if save_version >= 2 and data.has("map_region_level") and (not is_json_number(data.map_region_level) or float(data.map_region_level) != floor(float(data.map_region_level))):
		return "区域等级必须是整数"
	if saved_region_level < 0 or saved_region_level > REGION_DEFINITIONS.size() - 1:
		return "区域等级超出范围"
	if typeof(data.get("buildings")) != TYPE_ARRAY:
		return "建筑列表缺失"
	if save_version >= 4 and (not data.has("roads") or typeof(data.get("roads")) != TYPE_ARRAY):
		return "道路列表缺失"
	var raw_buildings: Array = data.buildings
	if raw_buildings.size() > GRID_SIZE * GRID_SIZE:
		return "建筑数量超出地图容量"
	var used_cells := {}
	var used_ids := {}
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
		if save_version >= 3 and (not record.has("enabled") or typeof(record.enabled) != TYPE_BOOL):
			return "建筑启停状态无效"
		if building_id < 1 or used_ids.has(building_id):
			return "建筑编号重复或超出范围"
		if not BUILDINGS.has(type):
			return "包含未知建筑类型"
		if record.has("rotation_quarters"):
			if not is_json_number(record.rotation_quarters) or float(record.rotation_quarters) not in [0.0, 1.0, 2.0, 3.0]:
				return "建筑旋转角度必须为0、90、180或270度"
		if record.has("warehouse_footprint"):
			if type != "warehouse" or not is_json_number(record.warehouse_footprint):
				return "仓库占地无效"
			if float(record.warehouse_footprint) not in [1.0, 2.0]:
				return "仓库占地必须为1×1或2×2"
		if record.has("farm_footprint"):
			if type != "farm" or not is_json_number(record.farm_footprint):
				return "农田占地无效"
			if float(record.farm_footprint) not in [1.0, 2.0, 4.0]:
				return "农田占地必须为1×1、2×1或2×2"
		for compact_type in ["workshop", "clinic"]:
			var footprint_field: String = compact_type + "_footprint"
			if record.has(footprint_field):
				if type != compact_type or not is_json_number(record[footprint_field]):
					return "%s占地无效" % BUILDINGS[compact_type].name
				if float(record[footprint_field]) not in [1.0, 2.0]:
					return "%s占地必须为1×1或2×2" % BUILDINGS[compact_type].name
		if saved_region_level < int(BUILDINGS[type].get("unlock_level", 0)):
			return "%s早于区域解锁出现" % BUILDINGS[type].name
		if cell.x < 0 or cell.x >= GRID_SIZE or cell.y < 0 or cell.y >= GRID_SIZE:
			return "建筑坐标超出地图"
		if region_level_for_cell(cell) > saved_region_level:
			return "建筑位于尚未开放的区域"
		if is_water_cell(cell) or is_reserved_forest(cell):
			return "建筑位于河道或保留林地"
		if type == "farm" and not is_farm_lot(cell, saved_building_footprint(record)):
			return "农田未位于河岸"
		if type == "lumber" and not is_lumber_cell(cell):
			return "伐木场未位于林缘"
		var footprint := saved_building_footprint(record)
		for footprint_cell in building_footprint_cells(type, cell, footprint):
			if footprint_cell.x < 0 or footprint_cell.x >= GRID_SIZE or footprint_cell.y < 0 or footprint_cell.y >= GRID_SIZE:
				return "建筑占地超出地图"
			if region_level_for_cell(footprint_cell) > saved_region_level:
				return "建筑占地位于尚未开放的区域"
			if is_water_cell(footprint_cell) or is_reserved_forest(footprint_cell):
				return "建筑占地位于河道或保留林地"
			if footprint != Vector2i.ONE and (is_village_main_road_cell(footprint_cell) or is_npc_bridge_access_cell(footprint_cell)):
				return "%s占地阻挡主路或桥头" % BUILDINGS[type].name
			if used_cells.has(footprint_cell):
				return "多个建筑占用同一格"
			used_cells[footprint_cell] = true
		used_ids[building_id] = true
		max_id = maxi(max_id, building_id)
	var used_road_cells := {}
	if data.has("road_rules_version") and (not is_json_number(data.road_rules_version) or float(data.road_rules_version) != 2.0):
		return "道路规则版本无效"
	# Roads did not exist before v4. Ignore any injected field on older saves so
	# migration is deterministic and cannot import unsupported infrastructure.
	var raw_roads: Array = data.get("roads", []) if save_version >= 4 else []
	if raw_roads.size() > GRID_SIZE * GRID_SIZE:
		return "道路数量超出地图容量"
	for raw_road in raw_roads:
		if typeof(raw_road) != TYPE_DICTIONARY:
			return "道路记录类型错误"
		var road_record: Dictionary = raw_road
		if road_record.has("legacy_cleared_tree") and typeof(road_record.legacy_cleared_tree) != TYPE_BOOL:
			return "历史道路清树标记无效"
		if not road_record.has("x") or not is_json_number(road_record.x) or float(road_record.x) != floor(float(road_record.x)):
			return "道路横坐标无效"
		if not road_record.has("z") or not is_json_number(road_record.z) or float(road_record.z) != floor(float(road_record.z)):
			return "道路纵坐标无效"
		var road_cell := Vector2i(int(road_record.x), int(road_record.z))
		if road_cell.x < 0 or road_cell.x >= GRID_SIZE or road_cell.y < 0 or road_cell.y >= GRID_SIZE:
			return "道路坐标超出地图"
		if region_level_for_cell(road_cell) > saved_region_level:
			return "道路位于尚未开放的区域"
		if is_water_cell(road_cell):
			return "道路位于水面"
		if is_fixed_road_infrastructure(road_cell):
			return "道路与村庄主路或桥梁重叠"
		if has_scenery_tree(road_cell) and data.has("road_rules_version") and not bool(road_record.get("legacy_cleared_tree", false)):
			return "道路占用树木所在格"
		if bool(road_record.get("legacy_cleared_tree", false)) and not has_scenery_tree(road_cell):
			return "历史道路清树标记与场景不符"
		if used_cells.has(road_cell):
			return "道路与建筑占用同一格"
		if used_road_cells.has(road_cell):
			return "道路坐标重复"
		used_road_cells[road_cell] = true
	# A disconnected/demolished warehouse may leave legitimate existing stock
	# above today's capacity. Bound saves by the map's theoretical historical
	# capacity (including legacy 1-cell warehouses), not today's road network.
	var maximum_saved_stock := 100 + GRID_SIZE * GRID_SIZE * building_effect("warehouse", "wood_capacity")
	if saved_wood < 0 or saved_wood > maximum_saved_stock or saved_food < 0 or saved_food > maximum_saved_stock:
		return "资源数量超出地图理论仓储上限"
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
	if selected_type == "" and not road_tool_selected and not locked_region:
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
	if road_tool_selected:
		var road_valid := can_place_road(cell) == ""
		# Trees remain visible and block placement. Only clearable map rocks are
		# hidden by a valid preview; cancellation restores them.
		if road_valid:
			for rock in scenery_rocks_by_cell.get(cell, []):
				if is_instance_valid(rock):
					rock.visible = false
		ghost = create_road_model(cell, true, road_valid)
		ghost.position = grid_to_world(cell) + Vector3(0, 0.225, 0)
		world.add_child(ghost)
		return
	ghost = create_building_model(selected_type, true)
	var footprint := rotated_footprint(BUILDING_FOOTPRINTS.get(selected_type, Vector2i.ONE), selected_rotation_quarters)
	ghost.position = building_model_position(selected_type, cell, footprint)
	ghost.rotation.y = selected_rotation_quarters * PI * 0.5
	var valid := can_place(selected_type, cell, selected_rotation_quarters) == ""
	RealisticKit.apply_preview_tint(ghost, valid)
	world.add_child(ghost)

func clear_ghost() -> void:
	var previous_hover_cell := hover_cell
	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null
	if locked_hover and is_instance_valid(locked_hover):
		locked_hover.queue_free()
		locked_hover = null
	hover_cell = Vector2i(-1, -1)
	if previous_hover_cell != Vector2i(-1, -1):
		update_forest_cell_for_roads(previous_hover_cell)

func update_camera_projection() -> void:
	if camera:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		clamp_camera_target_to_bounds()

func camera_ground_axis_extents() -> Vector2:
	if camera == null:
		return Vector2.ZERO
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var view_direction := -camera.global_transform.basis.z
	var ground_forward := Vector2(view_direction.x, view_direction.z)
	if ground_forward.length_squared() < 0.0001:
		ground_forward = Vector2(0, 1)
	else:
		ground_forward = ground_forward.normalized()
	var camera_right := camera.global_transform.basis.x
	var ground_right := Vector2(camera_right.x, camera_right.z)
	if ground_right.length_squared() < 0.0001:
		ground_right = Vector2(1, 0)
	else:
		ground_right = ground_right.normalized()
	var half_width := camera.size * aspect * 0.5
	var half_depth := camera.size * 0.5 / maxf(absf(view_direction.y), 0.10)
	return Vector2(
		absf(ground_right.x) * half_width + absf(ground_forward.x) * half_depth,
		absf(ground_right.y) * half_width + absf(ground_forward.y) * half_depth
	)

func camera_pan_bounds() -> Vector2:
	# Four unbuildable cells of overscan let edge lots sit inside the screen,
	# rather than pinning them against it. The 36-cell scenic apron covers the
	# worst 48-unit, 30-degree, 16:9 ground footprint even at these new limits.
	var browse_extent := (GRID_SIZE * 0.5 + CAMERA_EDGE_BROWSE_CELLS) * TILE_SIZE
	var rendered_extent := RENDER_GRID_SIZE * TILE_SIZE * 0.5
	var footprint := camera_ground_axis_extents()
	return Vector2(
		minf(browse_extent, maxf(0.0, rendered_extent - CAMERA_EDGE_SAFETY_MARGIN - footprint.x)),
		minf(browse_extent, maxf(0.0, rendered_extent - CAMERA_EDGE_SAFETY_MARGIN - footprint.y))
	)

func clamp_camera_target_to_bounds() -> void:
	if camera == null:
		return
	var camera_offset := camera.position - camera_target
	var bounds := camera_pan_bounds()
	camera_target.x = clampf(camera_target.x, -bounds.x, bounds.x)
	camera_target.z = clampf(camera_target.z, -bounds.y, bounds.y)
	camera.position = camera_target + camera_offset
	camera.look_at(camera_target)
	# Camera input runs outside the physics tick.  Clear interpolation history so
	# fast middle-mouse pans do not render one stale transform behind the target.
	camera.reset_physics_interpolation()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		if not (settings_overlay and settings_overlay.visible) and not (help_dialog and help_dialog.visible):
			rotate_selected_building()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if help_dialog and help_dialog.visible:
			help_dialog.hide()
		elif confirmation_dialog and confirmation_dialog.visible:
			confirmation_dialog.hide()
			pending_confirm_action = ""
		elif settings_overlay and settings_overlay.visible:
			close_settings_menu()
		elif selected_type != "" or road_tool_selected:
			cancel_building()
			show_message("已取消建造，进入查看模式")
		elif inspector and inspector.visible:
			selected_building_id = -1
			selected_road_cell = Vector2i(-1, -1)
			inspector.visible = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.size = maxf(CAMERA_MIN_SIZE, camera.size * 0.9)
			clamp_camera_target_to_bounds()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.size = minf(CAMERA_MAX_SIZE, camera.size * 1.1)
			clamp_camera_target_to_bounds()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				drag_button = event.button_index
				drag_origin = event.position
				drag_last = event.position
				drag_moved = false
			elif event.button_index == drag_button:
				if drag_button == MOUSE_BUTTON_RIGHT and not drag_moved and (selected_type != "" or road_tool_selected):
					cancel_building()
					show_message("已取消建造，进入查看模式")
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
		if selected_type != "" or road_tool_selected:
			cancel_building()
			show_message("已取消摆放，已选中建筑")
		show_inspector(int(occupied[cell]))
		return
	if roads.has(cell):
		if selected_type != "" or road_tool_selected:
			cancel_building()
			show_message("已取消建造，已选中道路")
		show_road_inspector(cell)
		return
	if road_tool_selected:
		var road_reason := can_place_road(cell)
		if road_reason != "":
			show_message(road_reason)
			return
		add_road(cell)
		show_message("已铺设道路：木材 -%d；接通村庄主路后可提供运输收益" % ROAD_WOOD_COST)
		clear_ghost()
		update_ui()
		save_game(false)
		return
	if selected_type != "":
		var reason := can_place(selected_type, cell, selected_rotation_quarters)
		if reason != "":
			show_message(reason)
			return
		add_building(selected_type, cell, false, -1, true, Vector2i.ZERO, selected_rotation_quarters)
		show_message("已建造%s" % BUILDINGS[selected_type].name)
		clear_ghost()
		update_ui()
		save_game(false)
	else:
		selected_building_id = -1
		selected_road_cell = Vector2i(-1, -1)
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
	camera.position = camera_target + camera_offset
	clamp_camera_target_to_bounds()

func rotate_camera(delta: Vector2) -> void:
	var offset := camera.position - camera_target
	offset = offset.rotated(Vector3.UP, -delta.x * 0.008)
	var distance := offset.length()
	var current_pitch := asin(clampf(offset.y / distance, -1.0, 1.0))
	var new_pitch := clampf(
		current_pitch + delta.y * 0.004,
		deg_to_rad(CAMERA_MIN_PITCH_DEGREES),
		deg_to_rad(CAMERA_MAX_PITCH_DEGREES)
	)
	var horizontal := Vector2(offset.x, offset.z).normalized()
	offset = Vector3(horizontal.x * cos(new_pitch) * distance, sin(new_pitch) * distance, horizontal.y * cos(new_pitch) * distance)
	camera.position = camera_target + offset
	camera.look_at(camera_target)
	clamp_camera_target_to_bounds()

