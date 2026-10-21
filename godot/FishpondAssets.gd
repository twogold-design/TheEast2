extends RefCounted

const Kit = preload("res://godot/OpenClinicAssets.gd")
const Activity = preload("res://godot/FishpondActivity.gd")
const WaterShader = preload("res://godot/shaders/fishpond_water.gdshader")

static func create_pond(preview := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Fishpond"
	root.set_meta("building_type", "fishpond")
	root.set_meta("asset_key", "building.fishpond")
	root.set_meta("asset_source", "composed_fishpond")
	root.set_meta("art_bounds", Vector3(6.48, 1.54, 4.28))
	root.set_meta("footprint_cells", Vector2i(3, 2))
	root.set_meta("expected_path", "res://godot/FishpondAssets.gd")
	root.set_meta("water_contains_visible_fish", true)
	root.set_meta("bank_style", "rural_earth")
	var materials := _materials()
	var stone: Material = materials.stone
	var wood: Material = materials.wood
	var dark := Kit.material(Color("514a36"))
	var clay := Kit.material(Color("897b59"))
	# The world terrain is y=.15 and its translucent build grid is y=.18.
	# An opaque bed above both occludes the grid without hiding submerged fish.
	Kit.box(root, "PondBed", Vector3(5.94, 0.035, 3.74), Vector3(0, 0.205, 0), Kit.material(Color("637862")))
	_earth_banks(root)
	var water := ShaderMaterial.new()
	water.shader = WaterShader
	var plane := PlaneMesh.new()
	plane.size = Vector2(5.96, 3.76)
	var surface := Kit.piece(root, "PondWater", plane, Vector3(0, 0.355, 0), water)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A small working pier leaves most of the open water and fish unobscured.
	var dock := Kit.branch(root, "FeedingDock")
	dock.position.x = 1.10
	for plank in range(9):
		Kit.box(dock, "DockPlank", Vector3(1.02, 0.065, 0.139), Vector3(1.04, 0.566, 0.75 + plank * 0.146), wood)
	for x in [0.62, 1.46]:
		Kit.box(dock, "DockSupport", Vector3(0.095, 0.12, 1.40), Vector3(x, 0.493, 1.31), dark)
		for z in [0.85, 1.91]:
			Kit.cylinder(dock, "DockPile", 0.052, 0.59, Vector3(x, 0.335, z), wood)
	_basket(dock, Vector3(1.15, 0.61, 1.50), wood, dark)
	_basket(dock, Vector3(0.78, 0.61, 1.12), clay, dark, 0.70)
	var pole := Kit.cylinder(dock, "FishingNetHandle", 0.022, 1.10, Vector3(1.30, 0.91, 0.96), wood)
	pole.rotation.z = -0.30
	var net_ring := TorusMesh.new()
	net_ring.inner_radius = 0.185
	net_ring.outer_radius = 0.203
	net_ring.rings = 32
	net_ring.ring_segments = 8
	var rim := Kit.piece(dock, "LandingNetRim", net_ring, Vector3(1.46, 1.32, 0.96), wood)
	rim.rotation.x = PI * 0.30
	for strand in range(7):
		var offset := (strand - 3) * 0.049
		var span := sqrt(maxf(0.0, 0.185 * 0.185 - offset * offset)) * 2.0
		var line := Kit.box(rim, "WovenNet", Vector3(span, 0.008, 0.008), Vector3(0, 0, offset), dark)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kit.box(rim, "WovenNetCross", Vector3(0.008, 0.008, span), Vector3(offset, 0, 0), dark)
	# Small submerged pebbles, reeds and floating leaves describe a living pond.
	for i in range(20):
		var angle := float(i) * 2.399
		var pebble := Kit.sphere(root, "BedPebble", Vector3(0.08, 0.035, 0.055), Vector3(cos(angle) * 2.70, 0.234, sin(angle) * 1.60), stone)
		pebble.rotation.y = angle
	for corner in [Vector3(-2.70, 0, -1.59), Vector3(2.70, 0, -1.59)]:
		for reed in range(8):
			var a := float(reed) * 2.399
			var stem := Kit.cylinder(root, "PondReed", 0.010, 0.36 + reed % 3 * 0.055, corner + Vector3(cos(a) * 0.13, 0.44, sin(a) * 0.13), Kit.material(Color("657455")))
			stem.rotation.z = cos(a) * 0.20
			var leaf := Kit.sphere(root, "ReedLeaf", Vector3(0.030, 0.30, 0.014), stem.position + Vector3(cos(a) * 0.045, 0.07, 0), Kit.material(Color("647453")))
			leaf.rotation.z = cos(a) * 0.45
	for i in range(5):
		var pad := Kit.cylinder(root, "LilyLeaf", 0.09 + (i % 2) * 0.025, 0.009, Vector3(-2.50 + float(i % 3) * 0.17, 0.366, 0.85 + float(i / 3) * 0.19), Kit.material(Color("6f855a")))
		pad.scale.z = 0.80
	var fish_root := Kit.branch(root, "SwimmingFish")
	var swimmers: Array[Node3D] = []
	for i in range(7):
		var fish := _fish(i)
		fish_root.add_child(fish)
		swimmers.append(fish)
	var activity := Activity.new()
	activity.name = "FishpondActivity"
	root.add_child(activity)
	activity.configure(swimmers, water, preview)
	Kit.anchor(root, "Door", Vector3(2.10, 0, 2.14))
	if not preview:
		var collision := StaticBody3D.new()
		collision.name = "AssetCollision"
		root.add_child(collision)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(6.44, 0.54, 4.24)
		shape.shape = box
		shape.position.y = 0.27
		collision.add_child(shape)
	return root

static func _earth_banks(parent: Node3D) -> void:
	# One continuous rounded bank: dark wet mud, dry crown and a grass-facing slope.
	# The outer toe stays below the terrain while the inner toe stays below water.
	var sections := [
		Vector3(2.65, 0.25, 1.55), Vector3(2.77, 0.365, 1.66),
		Vector3(2.91, 0.445, 1.79), Vector3(3.04, 0.46, 1.91),
		Vector3(3.14, 0.36, 2.03), Vector3(3.215, 0.125, 2.115),
	]
	var tones := [Color("544b32"), Color("69583a"), Color("8b724a"), Color("998057"), Color("8b7950"), Color("737548")]
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	const RING_POINTS := 128
	for ring in range(sections.size()):
		var section: Vector3 = sections[ring]
		var contour := _bank_contour(Vector2(section.x, section.z), 0.23 if ring >= 3 else 0.41)
		for i in range(RING_POINTS):
			var point: Vector2 = contour[i]
			var angle := TAU * float(i) / RING_POINTS
			var irregularity := sin(angle * 5.0 + 0.7) * 0.018 + sin(angle * 11.0) * 0.007
			var edge_fade := 0.28 if ring == sections.size() - 1 else 1.0
			point += point.normalized() * irregularity * edge_fade
			var height := section.y + (sin(angle * 7.0) * 0.018 + sin(angle * 13.0 + 0.5) * 0.008) * edge_fade
			vertices.append(Vector3(point.x, height, point.y))
			var variation := 1.0 + sin(angle * 9.0 + ring * 0.7) * 0.035
			var tone: Color = tones[ring]
			colors.append(Color(tone.r * variation, tone.g * variation, tone.b * variation))
			uvs.append(point * 1.8)
	for ring in range(sections.size() - 1):
		for i in range(RING_POINTS):
			var a := ring * RING_POINTS + i
			var b := ring * RING_POINTS + (i + 1) % RING_POINTS
			indices.append_array(PackedInt32Array([a, a + RING_POINTS, b, b, a + RING_POINTS, b + RING_POINTS]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var builder := SurfaceTool.new()
	builder.create_from(mesh, 0)
	builder.generate_normals()
	var earth := Kit.material(Color.WHITE)
	earth.vertex_color_use_as_albedo = true
	earth.roughness = 1.0
	var noise := FastNoiseLite.new()
	noise.seed = 821
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.87, 0.86, 0.83))
	ramp.set_color(1, Color(1.0, 0.99, 0.94))
	texture.color_ramp = ramp
	earth.albedo_texture = texture
	var bank := MeshInstance3D.new()
	bank.name = "EarthenBanks"
	bank.mesh = builder.commit()
	bank.mesh.surface_set_material(0, earth)
	parent.add_child(bank)
	# Sparse irregular tufts, with the working pier entrance deliberately clear.
	var grass := Kit.material(Color("737b48"))
	var dry_grass := Kit.material(Color("92905b"))
	for tuft in range(17):
		var i := (tuft * 29 + 9) % RING_POINTS
		var point := _bank_contour(Vector2(3.075, 1.965), 0.23)[i]
		if point.x > 1.30 and point.y > 1.3:
			continue
		var clump := Kit.branch(parent, "BankGrass_%02d" % tuft)
		clump.position = Vector3(point.x, 0.41, point.y)
		for blade in range(5):
			var angle := float(blade) * 2.399 + float(tuft)
			var height := 0.10 + float((blade + tuft) % 4) * 0.025
			var leaf := Kit.sphere(clump, "GrassBlade", Vector3(0.018, height, 0.012), Vector3(cos(angle) * 0.037, height * 0.40, sin(angle) * 0.037), grass if blade % 3 else dry_grass)
			leaf.rotation = Vector3(sin(angle) * 0.4, angle, cos(angle) * 0.4)

static func _bank_contour(half_size: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var centers := [
		Vector2(half_size.x - radius, -half_size.y + radius),
		Vector2(half_size.x - radius, half_size.y - radius),
		Vector2(-half_size.x + radius, half_size.y - radius),
		Vector2(-half_size.x + radius, -half_size.y + radius),
	]
	for corner in range(4):
		var start_angle := -PI / 2.0 + float(corner) * PI / 2.0
		for step in range(16):
			var angle := start_angle + float(step) / 16.0 * PI / 2.0
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * radius)
		var end_angle := start_angle + PI / 2.0
		var offset := Vector2(cos(end_angle), sin(end_angle)) * radius
		for step in range(16):
			points.append((centers[corner] + offset).lerp(centers[(corner + 1) % 4] + offset, float(step) / 16.0))
	return points

static func _materials() -> Dictionary:
	var stone: Material = Kit.material(Color("7b7f70"))
	var wood: Material = Kit.material(Color("8b7654"))
	var scene := load("res://godot/assets/realistic/models/building_warehouse.glb") as PackedScene
	if scene:
		var original := scene.instantiate() as Node3D
		var parts := Kit.collect_parts(original)
		if parts.has("StoneFoundation"):
			stone = parts.StoneFoundation.mesh.surface_get_material(0)
		if parts.has("RaisedFloor"):
			wood = parts.RaisedFloor.mesh.surface_get_material(0)
		original.free()
	if stone is StandardMaterial3D and stone.albedo_texture == null:
		stone = stone.duplicate()
		var noise := FastNoiseLite.new()
		noise.seed = 713
		noise.frequency = 0.16
		noise.fractal_octaves = 3
		var texture := NoiseTexture2D.new()
		texture.width = 128
		texture.height = 128
		texture.seamless = true
		texture.noise = noise
		var tones := Gradient.new()
		tones.set_color(0, Color(0.77, 0.79, 0.78))
		tones.set_color(1, Color(1.0, 1.0, 0.98))
		texture.color_ramp = tones
		stone.albedo_texture = texture
	return {"stone": stone, "wood": wood}

static func _basket(parent: Node3D, pos: Vector3, wood: Material, dark: Material, scale_factor := 1.0) -> void:
	var basket := Kit.branch(parent, "FishFeedBasket")
	basket.position = pos
	basket.scale = Vector3.ONE * scale_factor
	Kit.cylinder(basket, "BasketFloor", 0.13, 0.022, Vector3.ZERO, dark)
	for slat in range(18):
		var a := TAU * slat / 18.0
		var stave := Kit.box(basket, "BasketStave", Vector3(0.039, 0.23, 0.018), Vector3(cos(a) * 0.13, 0.12, sin(a) * 0.13), wood)
		stave.rotation.y = -a - PI / 2
	for height in [0.04, 0.12, 0.225]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.13
		ring.outer_radius = 0.145
		ring.rings = 32
		ring.ring_segments = 6
		Kit.piece(basket, "BasketHoop", ring, Vector3(0, height, 0), dark)
	Kit.sphere(basket, "FishFeedGrain", Vector3(0.235, 0.025, 0.235), Vector3(0, 0.175, 0), Kit.material(Color("a69465")))

static func _fish(index: int) -> Node3D:
	var fish := Node3D.new()
	fish.name = "PondFish_%d" % index
	var body_mat := Kit.material([Color("ad895a"), Color("b5bcad"), Color("788b7a")][index % 3])
	body_mat.roughness = 0.30
	var fin_mat := Kit.material([Color("907149"), Color("909d90"), Color("5a7267")][index % 3])
	var size := 0.85 + float(index % 3) * 0.10
	fish.scale = Vector3.ONE * size
	_fish_body(fish, body_mat)
	for side in [-1.0, 1.0]:
		Kit.sphere(fish, "FishEye", Vector3(0.012, 0.009, 0.012), Vector3(side * 0.030, 0.018, -0.150), Kit.material(Color("242f29")))
	var dorsal := Kit.sphere(fish, "DorsalFin", Vector3(0.014, 0.045, 0.15), Vector3(0, 0.024, 0.016), fin_mat)
	dorsal.rotation.x = -0.13
	for side in [-1.0, 1.0]:
		var fin := Kit.sphere(fish, "LeftFin" if side < 0 else "RightFin", Vector3(0.062, 0.008, 0.10), Vector3(side * 0.060, -0.014, -0.04), fin_mat)
		fin.rotation.y = side * -0.43
	var tail := Kit.branch(fish, "TailJoint")
	tail.position.z = 0.125
	Kit.sphere(tail, "TailStem", Vector3(0.065, 0.035, 0.12), Vector3(0, 0, 0.025), body_mat)
	for side in [-1.0, 1.0]:
		var fin := Kit.sphere(tail, "TailLobe", Vector3(0.072, 0.009, 0.115), Vector3(side * 0.030, 0, 0.090), fin_mat)
		fin.rotation.y = side * 0.55
	return fish

static func _fish_body(parent: Node3D, material: Material) -> void:
	# 24-sided smooth fusiform body: rounded snout, broad shoulders, narrow tail.
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var segments := 24
	var rings := 22
	for ring in range(rings + 1):
		var t := float(ring) / rings
		var radius := maxf(0.002, pow(sin(t * PI), 0.75) * lerpf(0.075, 0.036, t))
		for segment in range(segments):
			var angle := TAU * segment / segments
			vertices.append(Vector3(cos(angle) * radius, sin(angle) * radius * 0.53, -0.195 + t * 0.36))
	for ring in range(rings):
		for segment in range(segments):
			var a := ring * segments + segment
			var b := ring * segments + (segment + 1) % segments
			indices.append_array(PackedInt32Array([a, b, a + segments, b, b + segments, a + segments]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var base_mesh := ArrayMesh.new()
	base_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(base_mesh, 0)
	surface.generate_normals()
	var result := MeshInstance3D.new()
	result.name = "FishBody"
	result.mesh = surface.commit()
	result.mesh.surface_set_material(0, material)
	parent.add_child(result)
