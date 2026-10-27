extends RefCounted

## Functional courtyard architecture. Each compound has its own silhouette,
## material and visible work yard; dimensions are world units (cell = 2.2).
const K = preload("res://godot/OpenClinicAssets.gd")
const M = preload("res://godot/OpenMarketAssets.gd")
const Nature = preload("res://godot/DetailedTreeAssets.gd")
const TYPES := ["orchard", "freight", "pavilion", "garden", "theater", "granary", "dock", "trading_post", "tea_farm", "teahouse", "claypit", "kiln", "bamboo", "papermill"]
const SQUARE := ["orchard", "garden", "tea_farm", "claypit", "kiln", "bamboo"]
static var _materials: Dictionary = {}
static var _organic_lobe: ArrayMesh
static var _solid_leaf: ArrayMesh

static func mat(color: String, kind := "wood") -> Material:
	var key := kind + color
	if not _materials.has(key):
		if kind == "thatch":
			var shader := Shader.new()
			shader.code = "shader_type spatial; uniform vec4 straw_color : source_color; void fragment(){ float fiber = sin(UV.x * 730.0 + sin(UV.y * 53.0) * 2.0) * 0.09; float layers = sin(UV.y * 190.0) * 0.045; ALBEDO = straw_color.rgb * (0.76 + fiber + layers); ROUGHNESS = 0.96; }"
			var straw := ShaderMaterial.new()
			straw.shader = shader
			straw.set_shader_parameter("straw_color", Color(color))
			_materials[key] = straw
		else:
			_materials[key] = M.material(kind, Color(color))
	return _materials[key]

static func create_building(type: String, preview := false) -> Node3D:
	if type not in TYPES:
		return null
	var r := Node3D.new()
	r.name = type.to_pascal_case() + "Compound"
	var cells := Vector2i(2, 2) if type == "pavilion" else Vector2i(3, 3 if type in SQUARE else 2)
	var width := cells.x * 2.2 - 0.22
	var depth := cells.y * 2.2 - 0.22
	if type != "dock":
		K.box(r, "CompactedEarth", Vector3(width, 0.10, depth), Vector3(0, 0.20, 0), mat("a49a7b", "stone"))
	match type:
		"orchard": orchard(r)
		"freight": freight(r)
		"pavilion": pavilion(r)
		"garden": garden(r)
		"theater": theater(r)
		"granary": granary(r)
		"dock": dock(r)
		"trading_post": trading_post(r)
		"tea_farm": tea_farm(r)
		"teahouse": teahouse(r)
		"claypit": claypit(r)
		"kiln": kiln(r)
		"bamboo": bamboo(r)
		"papermill": papermill(r)
	r.set_meta("building_type", type)
	r.set_meta("asset_key", "building." + type)
	r.set_meta("asset_source", "functional_industry_compound")
	r.set_meta("expected_path", "res://godot/ExpandedIndustryAssets.gd")
	r.set_meta("footprint_cells", cells)
	r.set_meta("art_bounds", Vector3(width, 3.1, depth))
	r.set_meta("main_entrance", Vector3(0, 0, depth * 0.5))
	K.anchor(r, "Door", Vector3(0, 0, depth * 0.5))
	var worker_spots := {
		"orchard": Vector3(0.7, 0.26, 2.25), "freight": Vector3(-1.8, 0.26, 1.65),
		"theater": Vector3(0, 0.62, 0.2), "granary": Vector3(1.5, 0.26, 1.75),
		"dock": Vector3(-1.75, 0.28, 1.7), "trading_post": Vector3(1.8, 0.26, 1.5),
		"tea_farm": Vector3(0.2, 0.26, 1.8), "teahouse": Vector3(0.5, 0.26, -0.65),
		"claypit": Vector3(-1.3, 0.26, -0.5), "kiln": Vector3(1.8, 0.26, 0.9),
		"bamboo": Vector3(-1.7, 0.26, 1.55), "papermill": Vector3(-1.7, 0.26, 1.35),
	}
	K.anchor(r, "ArtisanAnchor", worker_spots.get(type, Vector3(0.55, 0.26, depth * 0.5 - 0.75)))
	if not preview:
		var body := StaticBody3D.new()
		body.name = "AssetCollision"
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(width - 0.04, 0.3, depth - 0.04)
		collision.shape = shape
		collision.position.y = 0.3
		body.add_child(collision)
		r.add_child(body)
	return r

static func beam(r: Node3D, a: Vector3, b: Vector3, radius := 0.035, color := "82714f") -> void:
	var part := K.cylinder(r, "RoundTimber", radius, a.distance_to(b), (a + b) * 0.5, mat(color))
	part.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

static func leaf_ball(r: Node3D, name: String, p: Vector3, size: Vector3, color: String) -> void:
	if name in ["RoundedTreeCrown", "LowTeaHedge", "FloweringShrub"]:
		foliage_cluster(r, name, p, size, color)
		return
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 14
	var part := K.piece(r, name, mesh, p, mat(color, ""))
	part.scale = size

static func foliage_cluster(r: Node3D, label: String, p: Vector3, size: Vector3, color: String) -> void:
	if _organic_lobe == null:
		_organic_lobe = Nature._create_lobe()
		_solid_leaf = Nature._create_leaf()
	var material_key := "foliage" + color
	if not _materials.has(material_key):
		var foliage_mat := StandardMaterial3D.new()
		foliage_mat.albedo_color = Color(color).lightened(0.65)
		foliage_mat.albedo_texture = load("res://godot/assets/realistic/models/prop_tree_01_leaf_basecolor.png")
		foliage_mat.roughness = 0.95
		_materials[material_key] = foliage_mat
	var branch := K.branch(r, label)
	branch.position = p
	var core := MeshInstance3D.new()
	core.name = "IrregularFoliageCore"
	core.mesh = _organic_lobe
	core.material_override = _materials[material_key]
	core.scale = size * 0.43
	branch.add_child(core)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = _solid_leaf
	batch.instance_count = 70
	for i in range(70):
		var y := 1.0 - 2.0 * (i + 0.5) / 70.0
		var angle := i * 2.399963
		var radius := sqrt(1.0 - y * y)
		var normal := Vector3(cos(angle) * radius, y, sin(angle) * radius)
		var basis := Basis.from_euler(Vector3(sin(i) * 0.45, angle, cos(i) * 0.4)).scaled(Vector3(0.045, 0.025, 0.085))
		batch.set_instance_transform(i, Transform3D(basis, normal * size * 0.43))
	var leaves := MultiMeshInstance3D.new()
	leaves.name = "IndividualSolidLeaves"
	leaves.multimesh = batch
	leaves.material_override = _materials[material_key]
	branch.add_child(leaves)

static func ring(r: Node3D, p: Vector3, radius: float, color := "8f7954") -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.91
	mesh.outer_radius = radius
	mesh.rings = 32
	mesh.ring_segments = 8
	return K.piece(r, "RimHoop", mesh, p, mat(color))

static func basket(r: Node3D, p: Vector3, radius := 0.23) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.73
	mesh.height = radius * 1.25
	mesh.radial_segments = 24
	K.piece(r, "WovenBasket", mesh, p + Vector3(0, radius * 0.625, 0), mat("a9996c"))
	for i in range(4):
		ring(r, p + Vector3(0, radius * (0.2 + i * 0.33), 0), radius * (0.78 + i * 0.073))

static func crate(r: Node3D, p: Vector3, size := Vector3(0.5, 0.45, 0.5)) -> void:
	K.box(r, "ShippingCrate", size, p + Vector3(0, size.y * 0.5, 0), mat("ac9672"))
	for x in [-0.32, 0.32]:
		K.box(r, "CrateBand", Vector3(0.035, size.y + 0.02, size.z + 0.02), p + Vector3(size.x * x, size.y * 0.5, 0), mat("72674e"))

static func bench(r: Node3D, p: Vector3, width := 1.0, depth := 0.35, height := 0.5) -> void:
	K.box(r, "TableTop", Vector3(width, 0.06, depth), p + Vector3(0, height, 0), mat("a98e66"))
	for x in [-width * 0.39, width * 0.39]:
		for z in [-depth * 0.32, depth * 0.32]:
			K.box(r, "TableLeg", Vector3(0.055, height, 0.055), p + Vector3(x, height * 0.5, z), mat("827253"))

static func path(r: Node3D, points: Array) -> void:
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var count := int(ceil(a.distance_to(b) / 0.3))
		for n in range(count):
			var p: Vector3 = a.lerp(b, float(n) / count)
			var stone := K.box(r, "WalkingStone", Vector3(0.57, 0.025, 0.27), p, mat("a5a48e", "stone"))
			stone.rotation.y = atan2((b - a).x, (b - a).z)

static func shelter(r: Node3D, p: Vector3, width: float, depth: float, height := 1.5, color := "a58f61") -> void:
	for x in [-width * 0.43, width * 0.43]:
		for z in [-depth * 0.40, depth * 0.40]:
			beam(r, p + Vector3(x, 0.25, z), p + Vector3(x, height, z), 0.05)
	for z in [-depth * 0.40, depth * 0.40]:
		K.box(r, "ShelterTieBeam", Vector3(width, 0.09, 0.08), p + Vector3(0, height, z), mat("7f704e"))
	for i in range(int(width / 0.12)):
		for side in [-1.0, 1.0]:
			var board := K.box(r, "SplitBambooRoof", Vector3(0.116, 0.04, depth * 0.54), p + Vector3(-width * 0.5 + 0.06 + i * 0.12, height + 0.14, side * depth * 0.25), mat(color))
			board.rotation.x = side * 0.25
	K.box(r, "ShelterRidge", Vector3(width, 0.07, 0.1), p + Vector3(0, height + 0.26, 0), mat("776d50"))

static func hall(r: Node3D, p: Vector3, width: float, depth: float, height := 1.5, color := "777d74") -> void:
	K.box(r, "HallFloor", Vector3(width, 0.15, depth), p + Vector3(0, 0.32, 0), mat("9a937b", "stone"))
	K.box(r, "RearPlasterWall", Vector3(width, height - 0.35, 0.1), p + Vector3(0, (height + 0.35) * 0.5, -depth * 0.45), mat("c0bba0", "stone"))
	for x in [-width * 0.45, width * 0.45]:
		K.box(r, "SideWall", Vector3(0.1, height - 0.35, depth * 0.9), p + Vector3(x, (height + 0.35) * 0.5, 0), mat("c0bba0", "stone"))
		for z in [-depth * 0.42, depth * 0.42]:
			K.box(r, "LoadBearingPost", Vector3(0.1, height - 0.25, 0.1), p + Vector3(x, (height + 0.25) * 0.5, z), mat("756349"))
	K.box(r, "OpenFrontLintel", Vector3(width, 0.11, 0.1), p + Vector3(0, height - 0.03, depth * 0.42), mat("756349"))
	# Complete two-slope roof: small curved cylinders and staggered ridges.
	var rise := 0.42
	for side in [-1.0, 1.0]:
		var angle: float = side * atan2(rise, depth * 0.57)
		var slope := sqrt(pow(depth * 0.57, 2) + rise * rise)
		var board := K.box(r, "ContinuousRoofUnderlay", Vector3(width + 0.25, 0.055, slope), p + Vector3(0, height + rise * 0.5, side * depth * 0.285), mat(color, "stone"))
		board.rotation.x = angle
		for col in range(int((width + 0.18) / 0.13)):
			for row in range(4):
				var t := (row + 0.5) / 4.0
				var tile := K.cylinder(r, "CurvedRoofTile", 0.047, slope / 3.6, p + Vector3(-width * 0.5 - 0.04 + col * 0.13, height + rise * (1.0 - t) + 0.045, side * depth * 0.57 * t), mat(color, "stone"))
				tile.rotation.x = PI * 0.5 + angle
	K.box(r, "RoofRidge", Vector3(width + 0.25, 0.08, 0.11), p + Vector3(0, height + rise + 0.045, 0), mat("737970", "stone"))
	for x in [-width * 0.45, width * 0.45]:
		K.gable(r, "PlasterGable", p.x + x, p.z - depth * 0.49, p.z + depth * 0.49, p.y + height, p.y + height + rise, mat("c0bba0", "stone"))

static func cart(r: Node3D, p: Vector3, angle := 0.0, loaded := true) -> void:
	var c := K.branch(r, "TimberHandcart")
	c.position = p
	c.rotation.y = angle
	K.box(c, "PlankBed", Vector3(0.85, 0.07, 1.05), Vector3(0, 0.58, 0), mat("9f8a65"))
	for x in [-0.39, 0.39]:
		K.box(c, "CartSide", Vector3(0.045, 0.26, 1.02), Vector3(x, 0.74, 0), mat("9f8a65"))
		beam(c, Vector3(x, 0.57, 0.4), Vector3(x, 0.7, 1.1))
	for x in [-0.48, 0.48]:
		var wheel := ring(c, Vector3(x, 0.52, 0), 0.28, "75674d")
		wheel.rotation.z = PI * 0.5
		for i in range(8):
			var angle_i := i * TAU / 8
			beam(c, Vector3(x, 0.52, 0), Vector3(x, 0.52 + cos(angle_i) * 0.25, sin(angle_i) * 0.25), 0.015)
	if loaded:
		crate(c, Vector3(0, 0.63, -0.15))

static func tree(r: Node3D, p: Vector3, seed: int, fruit := false) -> void:
	beam(r, p, p + Vector3(0.06, 1.15, 0), 0.09, "796b50")
	for i in range(5):
		var angle := i * 2.399 + seed
		var tip := p + Vector3(cos(angle) * 0.48, 1.30 + float(i % 2) * 0.25, sin(angle) * 0.48)
		beam(r, p + Vector3(0.03, 0.8, 0), tip, 0.035)
		leaf_ball(r, "RoundedTreeCrown", tip + Vector3(0, 0.18, 0), Vector3(1.05, 0.88, 1.04), ["718756", "7f8f60", "677d4c"][i % 3])
		if fruit:
			for n in range(4):
				var a := n * 2.39 + i
				leaf_ball(r, "RipeFruit", tip + Vector3(cos(a) * 0.39, 0.1 + sin(a) * 0.22, sin(a) * 0.38), Vector3.ONE * 0.12, "b99a54")

static func orchard(r: Node3D) -> void:
	for row in range(2):
		for col in range(3):
			tree(r, Vector3(-2.05 + col * 2.0, 0.25, -1.95 + row * 2.1), row * 3 + col, true)
	shelter(r, Vector3(-1.95, 0, 2.25), 1.75, 1.05, 1.35)
	for i in range(4):
		basket(r, Vector3(0.85 + (i % 2) * 0.65, 0.26, 1.85 + (i / 2) * 0.6))
	path(r, [Vector3(0, 0.27, 3.12), Vector3(0, 0.27, 1.15), Vector3(-0.95, 0.27, 1.15), Vector3(-0.95, 0.27, -2.8)])
	cart(r, Vector3(1.85, 0, 2.3), PI * 0.5, false)

static func freight(r: Node3D) -> void:
	shelter(r, Vector3(-1.8, 0, -0.65), 2.1, 2.5, 1.6, "8e8568")
	for i in range(4):
		crate(r, Vector3(-2.35 + (i % 2) * 0.6, 0.26, -1.35 + (i / 2) * 0.8))
	for i in range(2):
		cart(r, Vector3(1.1 + i * 1.2, 0, -0.65), 0, i == 0)
	for x in [-0.15, 0.5]:
		K.box(r, "WagonWheelTrack", Vector3(0.1, 0.025, 3.8), Vector3(x, 0.27, 0), mat("8a8066", "stone"))
	bench(r, Vector3(-1.8, 0.25, 1.15), 1.3, 0.6)
	K.box(r, "DispatchLedger", Vector3(0.4, 0.04, 0.3), Vector3(-1.8, 0.82, 1.15), mat("d0c4a2", "cloth"))

static func pavilion(r: Node3D) -> void:
	var center := Vector3(0, 0, -0.5)
	K.cylinder(r, "OctagonalPavilionBase", 1.25, 0.16, center + Vector3(0, 0.3, 0), mat("aaa78e", "stone"))
	for i in range(6):
		var a := i * TAU / 6
		var p := center + Vector3(cos(a) * 0.94, 0, sin(a) * 0.94)
		beam(r, p + Vector3(0, 0.37, 0), p + Vector3(0, 1.65, 0), 0.065)
		if i != 1 and i != 2:
			var b := K.branch(r, "PavilionSeat")
			b.position = p
			b.rotation.y = -a + PI * 0.5
			bench(b, Vector3(0, 0.26, 0), 0.7, 0.22, 0.38)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.06
	roof.bottom_radius = 1.42
	roof.height = 0.7
	roof.radial_segments = 6
	K.piece(r, "CompleteHexagonalCanopy", roof, center + Vector3(0, 2.0, 0), mat("777e6b", "stone"))
	for i in range(6):
		var a := i * TAU / 6
		beam(r, center + Vector3(0, 2.35, 0), center + Vector3(cos(a) * 1.42, 1.65, sin(a) * 1.42), 0.04, "8b947a")
	path(r, [Vector3(0, 0.27, 2.04), Vector3(0, 0.27, 0.62)])
	for side in [-1.0, 1.0]:
		leaf_ball(r, "FloweringShrub", Vector3(side * 1.55, 0.5, 1.05), Vector3(0.65, 0.55, 0.8), "829467")

static func garden(r: Node3D) -> void:
	var pavilion_node := K.branch(r, "GardenPavilion")
	pavilion_node.position = Vector3(-1.75, 0, -1.5)
	pavilion_node.scale = Vector3.ONE * 0.8
	pavilion(pavilion_node)
	leaf_ball(r, "GardenPool", Vector3(1.2, 0.29, -0.65), Vector3(2.3, 0.08, 2.6), "829d91")
	for i in range(14):
		var a := i * TAU / 14
		leaf_ball(r, "PondBorderStone", Vector3(1.2 + cos(a) * 1.14, 0.34, -0.65 + sin(a) * 1.3), Vector3(0.36, 0.25, 0.3), "999b83")
	for i in range(3):
		leaf_ball(r, "WeatheredGardenRock", Vector3(2.15 + i * 0.18, 0.55 + i * 0.14, 1.65), Vector3(0.65, 0.6 + i * 0.27, 0.75), "919781")
	path(r, [Vector3(0, 0.27, 2.9), Vector3(-0.65, 0.27, 2), Vector3(-1.4, 0.27, 1.1), Vector3(-1.7, 0.27, -0.5)])
	path(r, [Vector3(-0.65, 0.27, 2), Vector3(0.8, 0.27, 2.2), Vector3(1.65, 0.27, 1.1)])
	tree(r, Vector3(-2.1, 0.25, 1.7), 4)
	tree(r, Vector3(2.2, 0.25, -2.25), 5)
	bench(r, Vector3(0.55, 0.25, 2.6), 1.25)

static func theater(r: Node3D) -> void:
	hall(r, Vector3(0, 0.3, -0.85), 4.8, 1.6, 1.7, "777b6e")
	K.box(r, "RaisedPerformanceStage", Vector3(4.75, 0.35, 1.5), Vector3(0, 0.43, 0.2), mat("997c56"))
	for side in [-1.0, 1.0]:
		for fold in range(7):
			K.cylinder(r, "GatheredStageCurtain", 0.075, 1.15, Vector3(side * (1.65 + fold * 0.07), 1.24, -0.1), mat("845f50", "cloth"))
		K.box(r, "StageStep", Vector3(0.65, 0.14, 0.45), Vector3(side * 2.6, 0.32, 0.65), mat("a29b80", "stone"))
	for row in range(2):
		for col in range(3):
			bench(r, Vector3(-1.75 + col * 1.7, 0.25, 1.15 + row * 0.57), 1.1, 0.22, 0.32)
	K.cylinder(r, "StageDrum", 0.25, 0.33, Vector3(1.45, 0.85, 0), mat("a48860"))
	K.cylinder(r, "DrumSkin", 0.255, 0.03, Vector3(1.45, 1.03, 0), mat("c4b698", "cloth"))

static func granary(r: Node3D) -> void:
	for x in [-1.95, 0.0, 1.95]:
		for dx in [-0.47, 0.47]:
			for z in [-1.35, -0.45]:
				K.cylinder(r, "GranaryStoneStilt", 0.14, 0.32, Vector3(x + dx, 0.4, z), mat("939882", "stone"))
		K.cylinder(r, "RoundRaisedGranary", 0.77, 1.12, Vector3(x, 1.13, -0.9), mat("938360", "thatch"))
		for band in range(6):
			ring(r, Vector3(x, 0.62 + band * 0.2, -0.9), 0.785)
		for slat in range(24):
			var a := slat * TAU / 24
			beam(r, Vector3(x + cos(a) * 0.775, 0.6, -0.9 + sin(a) * 0.775), Vector3(x + cos(a) * 0.775, 1.65, -0.9 + sin(a) * 0.775), 0.013, "c2ad80")
		var roof := CylinderMesh.new()
		roof.top_radius = 0.025
		roof.bottom_radius = 0.94
		roof.height = 0.74
		roof.radial_segments = 40
		K.piece(r, "ConicalThatchedRoof", roof, Vector3(x, 2.05, -0.9), mat("a99d70", "thatch"))
		for rib in range(32):
			var a := rib * TAU / 32
			beam(r, Vector3(x, 2.41, -0.9), Vector3(x + cos(a) * 0.93, 1.68, -0.9 + sin(a) * 0.93), 0.012, "a59061")
		K.box(r, "GrainHatch", Vector3(0.33, 0.44, 0.06), Vector3(x, 1.05, -0.11), mat("806d4a"))
	for i in range(5):
		leaf_ball(r, "GrainSack", Vector3(-2.4 + i * 0.45, 0.48, 1.05), Vector3(0.38, 0.48, 0.52), "b3aa81")
	K.box(r, "DryingGrainMat", Vector3(1.65, 0.035, 1.1), Vector3(1.5, 0.27, 1.0), mat("c3ac6b"))
	for i in range(36):
		leaf_ball(r, "DryingGrain", Vector3(0.78 + (i % 9) * 0.18, 0.30, 0.58 + (i / 9) * 0.25), Vector3(0.075, 0.035, 0.06), "d0b771")

static func dock(r: Node3D) -> void:
	K.box(r, "ShoreLoadingCourt", Vector3(6.3, 0.15, 1.45), Vector3(0, 0.2, 1.3), mat("a49a7b", "stone"))
	for z in range(15):
		K.box(r, "PierDeckPlank", Vector3(1.3, 0.07, 0.18), Vector3(0, 0.35, -1.75 + z * 0.2), mat("9b8964"))
	for x in range(25):
		K.box(r, "THeadDeckPlank", Vector3(0.18, 0.07, 0.8), Vector3(-2.4 + x * 0.2, 0.35, -1.6), mat("9b8964"))
	for x in [-2.2, -0.48, 0.48, 2.2]:
		beam(r, Vector3(x, -0.45, -1.65), Vector3(x, 0.62, -1.65), 0.09)
	shelter(r, Vector3(-2, 0, 1.2), 1.85, 1.2, 1.4)
	for i in range(3):
		crate(r, Vector3(-2.5 + i * 0.5, 0.29, 1.1), Vector3(0.44, 0.35, 0.45))
	var boat := K.branch(r, "MooredCargoSkiff")
	boat.position = Vector3(1.85, 0.02, -0.4)
	# Planked tapered hull, open inside and sitting below deck height.
	for i in range(15):
		var z := -0.9 + i * 0.12
		var half_width: float = 0.44 * pow(maxf(0.0, 1.0 - pow(z / 1.03, 2)), 0.5)
		K.box(boat, "BoatFloorPlank", Vector3(half_width * 2, 0.055, 0.115), Vector3(0, 0.03, z), mat("756747"))
		for side in [-1.0, 1.0]:
			K.box(boat, "BoatSideStrake", Vector3(0.055, 0.23, 0.14), Vector3(side * half_width, 0.13, z), mat("94805a"))
	for z in [-0.5, 0.35]:
		K.box(boat, "BoatBench", Vector3(0.65, 0.045, 0.18), Vector3(0, 0.22, z), mat("a18d63"))
	crate(boat, Vector3(0, 0.07, -0.2), Vector3(0.38, 0.25, 0.4))
	ring(r, Vector3(0.7, 0.39, -1.45), 0.17)
	beam(r, Vector3(0.7, 0.4, -1.5), Vector3(1.65, 0.25, -1.1), 0.012, "bbab7b")
	K.anchor(r, "WaterBerth", Vector3(1.85, 0, -0.5))

static func trading_post(r: Node3D) -> void:
	hall(r, Vector3(0.6, 0, -0.95), 3.9, 1.65, 2.05, "858276")
	K.box(r, "LoftFloor", Vector3(3.7, 0.08, 1.4), Vector3(0.6, 1.38, -0.95), mat("9f8961"))
	for i in range(12):
		K.box(r, "LoftBalustrade", Vector3(0.035, 0.3, 0.035), Vector3(-1.05 + i * 0.3, 1.58, -0.2), mat("82704e"))
	bench(r, Vector3(1.8, 0.25, 0.95), 1.4, 0.65, 0.55)
	K.box(r, "OpenAccountBook", Vector3(0.35, 0.025, 0.25), Vector3(1.8, 0.85, 0.95), mat("d3c8a8", "cloth"))
	beam(r, Vector3(-1.65, 0.25, 0.8), Vector3(-1.65, 1.65, 0.8), 0.075)
	beam(r, Vector3(-2.4, 1.55, 0.8), Vector3(-0.85, 1.55, 0.8), 0.04)
	for x in [-2.28, -1.0]:
		for dx in [-0.2, 0.2]:
			beam(r, Vector3(x, 1.55, 0.8), Vector3(x + dx, 0.85, 0.8), 0.012, "b4a274")
		K.cylinder(r, "TradeBalancePan", 0.28, 0.035, Vector3(x, 0.85, 0.8), mat("9b8d66"))
	for i in range(4):
		crate(r, Vector3(-2.6 + (i % 2) * 0.55, 0.25, -1.5 + (i / 2) * 0.6))

static func tea_farm(r: Node3D) -> void:
	for row in range(4):
		for col in range(10):
			var x := -2.6 + col * 0.57
			var z := -2.25 + row * 1.05 + 0.12 * sin(col * 0.5)
			leaf_ball(r, "LowTeaHedge", Vector3(x, 0.57, z), Vector3(0.64, 0.63, 0.62), ["728753", "7d8e59", "6b814f"][col % 3])
	shelter(r, Vector3(-1.85, 0, 2.35), 2.0, 1.0, 1.3)
	for i in range(4):
		var p := Vector3(0.1 + i * 0.65, 0.72, 2.35)
		bench(r, p - Vector3(0, 0.47, 0), 0.55, 0.55, 0.45)
		K.cylinder(r, "TeaDryingTray", 0.26, 0.035, p, mat("a18f60"))
		for j in range(8):
			leaf_ball(r, "DryingTeaLeaf", p + Vector3(cos(j * 2.399) * 0.16, 0.025, sin(j * 2.399) * 0.16), Vector3(0.1, 0.02, 0.035), "68794d")

static func teahouse(r: Node3D) -> void:
	hall(r, Vector3(-1.65, 0, -0.95), 2.5, 1.65, 1.5, "7d8378")
	shelter(r, Vector3(1.5, 0, -0.95), 2.6, 1.5, 1.5, "aa9a78")
	for p in [Vector3(-1.9, 0.25, 1.1), Vector3(0, 0.25, 0.35), Vector3(2.0, 0.25, 0.65)]:
		bench(r, p, 0.85, 0.7, 0.52)
		for side in [-1.0, 1.0]:
			bench(r, p + Vector3(side * 0.63, 0, 0), 0.27, 0.3, 0.3)
		K.jar(r, "TeaPot", p + Vector3(0.08, 0.57, 0), 0.09, mat("827859", "stone"))
		for side in [-1.0, 1.0]:
			K.cylinder(r, "TeaCup", 0.045, 0.065, p + Vector3(side * 0.25, 0.60, 0), mat("c3c2a7", "stone"))
	K.cylinder(r, "CharcoalTeaStove", 0.25, 0.42, Vector3(-0.7, 0.48, -0.85), mat("817761", "stone"))
	K.jar(r, "WaterKettle", Vector3(-0.7, 0.7, -0.85), 0.18, mat("827d6a", "stone"))

static func claypit(r: Node3D) -> void:
	# The low wet floor is surrounded by descending earthen terraces, not water.
	K.box(r, "ExcavatedClayFloor", Vector3(3.3, 0.04, 3.5), Vector3(-0.5, 0.26, -0.65), mat("99836a", "stone"))
	for level in range(3):
		var y := 0.35 + level * 0.13
		var length := 3.65 + level * 0.42
		K.box(r, "ExposedClayTerrace", Vector3(length, 0.16, 0.28), Vector3(-0.5, y, -2.25 - level * 0.23), mat("ae9779", "stone"))
		K.box(r, "CutClaySide", Vector3(0.28, 0.16, length), Vector3(-2.2 - level * 0.22, y, -0.65), mat("ae9779", "stone"))
	for i in range(14):
		K.box(r, "ClayRampPlank", Vector3(0.85, 0.035, 0.17), Vector3(0.1, 0.28 + i * 0.006, 0.2 + i * 0.2), mat("8f7d5e"))
	shelter(r, Vector3(2.15, 0, -1.75), 1.55, 1.8, 1.35)
	for i in range(5):
		leaf_ball(r, "DugClayHeap", Vector3(1.55 + (i % 2) * 0.65, 0.45, 0.6 + (i / 2) * 0.55), Vector3(0.85, 0.46, 0.75), "ae9371")
	cart(r, Vector3(-1.4, 0, 2.15), PI * 0.5, false)
	for i in range(3):
		beam(r, Vector3(-1.3 + i * 0.25, 0.3, -1.1), Vector3(-1.15 + i * 0.25, 1.1, -1.1), 0.022)
		K.box(r, "ClaySpadeBlade", Vector3(0.15, 0.23, 0.035), Vector3(-1.3 + i * 0.25, 0.37, -1.1), mat("77776b", "stone"))

static func kiln(r: Node3D) -> void:
	# Barrel vault made from individual radial courses. The front remains a
	# genuine firing mouth, with a recessed black firebox behind it.
	for course in range(10):
		for arc in range(15):
			var a := (arc + 0.5) * PI / 15
			var brick := K.box(r, "VaultKilnBrick", Vector3(0.24, 0.2, 0.27), Vector3(-1.1 + cos(a) * 1.12, 0.3 + sin(a) * 1.12, -2.45 + course * 0.28), mat(["a28b6b", "ae9374", "97836a"][(course + arc) % 3], "stone"))
			brick.rotation.z = a - PI * 0.5
	K.box(r, "RecessedKilnDarkness", Vector3(1.7, 0.8, 0.12), Vector3(-1.1, 0.68, -1.8), mat("4c493c", "stone"))
	for row in range(7):
		K.box(r, "ShortBrickChimney", Vector3(0.53, 0.18, 0.53), Vector3(-1.1, 1.37 + row * 0.18, -2.1), mat("9c8667", "stone"))
	K.box(r, "ChimneyOpening", Vector3(0.33, 0.02, 0.33), Vector3(-1.1, 2.55, -2.1), mat("555145", "stone"))
	shelter(r, Vector3(1.95, 0, -1.35), 1.8, 2.6, 1.5)
	for shelf in range(2):
		bench(r, Vector3(1.95, 0.25, -1.9 + shelf * 0.95), 1.55, 0.55, 0.6)
		for i in range(4):
			K.jar(r, "DryingPottery", Vector3(1.37 + i * 0.39, 0.9, -1.9 + shelf * 0.95), 0.15, mat("bd9c7a", "stone"))
	for i in range(6):
		K.jar(r, "FinishedEarthenware", Vector3(-2.3 + i * 0.63, 0.26, 1.85), 0.24, mat(["a88c69", "828f78", "b29a77"][i % 3], "stone"))
	bench(r, Vector3(1.8, 0.25, 1.55), 1.1, 0.75, 0.5)
	K.cylinder(r, "PottersWheel", 0.34, 0.05, Vector3(1.8, 0.82, 1.55), mat("917a55"))
	K.jar(r, "WetTurningPot", Vector3(1.8, 0.86, 1.55), 0.19, mat("a28d72", "stone"))

static func bamboo(r: Node3D) -> void:
	for row in range(3):
		for col in range(6):
			var p := Vector3(-2.35 + col * 0.9, 0.25, -2.35 + row * 1.0)
			var height := 1.65 + float((row + col) % 4) * 0.22
			beam(r, p, p + Vector3(0.05, height, 0.05), 0.037, "80905b")
			for joint in range(5):
				ring(r, p + Vector3(0.02, 0.25 + joint * 0.3, 0.02), 0.044, "a4ae75")
			for leaf in range(5):
				var angle := leaf * 2.399 + col
				var tip := p + Vector3(cos(angle) * 0.4, height - 0.2 - leaf * 0.13, sin(angle) * 0.4)
				beam(r, p + Vector3(0.03, height - 0.35 - leaf * 0.13, 0), tip, 0.012, "82905e")
				var foliage := K.branch(r, "BambooSpray")
				foliage.position = tip
				foliage.rotation.y = -angle
				for n in range(3):
					leaf_ball(foliage, "PointedBambooLeaf", Vector3(n * 0.09, n * 0.03, 0), Vector3(0.42, 0.06, 0.13), "738652")
	shelter(r, Vector3(-1.7, 0, 2.15), 2.5, 1.35, 1.3, "9eaa74")
	for i in range(12):
		beam(r, Vector3(0.6, 0.3 + (i / 4) * 0.09, 1.65 + (i % 4) * 0.13), Vector3(2.8, 0.3 + (i / 4) * 0.09, 1.65 + (i % 4) * 0.13), 0.045, "b1b57a")
	bench(r, Vector3(-1.7, 0.25, 2.05), 1.8, 0.45, 0.45)

static func papermill(r: Node3D) -> void:
	hall(r, Vector3(-1.9, 0, -1.05), 2.2, 1.55, 1.45, "818575")
	for i in range(2):
		var p := Vector3(-1.75 + i * 1.6, 0, 0.55)
		K.box(r, "PulpVatBody", Vector3(1.3, 0.34, 0.9), p + Vector3(0, 0.43, 0), mat("93856a"))
		K.box(r, "VisiblePaperPulp", Vector3(1.15, 0.015, 0.75), p + Vector3(0, 0.61, 0), mat("c6c2a2", ""))
		for side in [-1.0, 1.0]:
			K.box(r, "PapermakingFrame", Vector3(1.15, 0.035, 0.035), p + Vector3(0, 0.66, side * 0.34), mat("b4a077"))
			K.box(r, "PapermakingFrame", Vector3(0.035, 0.035, 0.7), p + Vector3(side * 0.56, 0.66, 0), mat("b4a077"))
	for i in range(5):
		var frame := K.branch(r, "LeaningDryingPaperPanel")
		frame.position = Vector3(1.0 + (i % 3) * 0.68, 0.85, -1.2 + (i / 3) * 1.7)
		frame.rotation.x = -0.22
		K.box(frame, "DryingBoard", Vector3(0.59, 1.1, 0.04), Vector3.ZERO, mat("94865f"))
		K.box(frame, "HandmadePaperSheet", Vector3(0.52, 0.97, 0.012), Vector3(0, 0, 0.03), mat("d4cfb0", "cloth"))
		beam(frame, Vector3(0, -0.55, -0.3), Vector3(0, 0.2, -0.025), 0.025)
	for x in [-2.6, -2.1]:
		beam(r, Vector3(x, 0.25, -0.9), Vector3(x, 1.25, -0.9), 0.045)
	K.box(r, "PaperPressBeam", Vector3(0.7, 0.09, 0.4), Vector3(-2.35, 1.23, -0.9), mat("8c7653"))
	K.box(r, "PressedPaperStack", Vector3(0.45, 0.2, 0.4), Vector3(-2.35, 0.65, -0.9), mat("c8c3a4", "cloth"))
	beam(r, Vector3(-2.35, 0.85, -0.9), Vector3(-2.35, 1.45, -0.9), 0.055)
