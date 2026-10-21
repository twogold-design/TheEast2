extends RefCounted

const Kit = preload("res://godot/OpenClinicAssets.gd")

## A complete gray-tiled home with open doors/windows and a lived-in front yard.
## All textured architectural pieces come from the preserved original house GLB.
static func create_house(source: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "OpenCourtyardHouse"
	root.set_meta("asset_key", "building.house")
	root.set_meta("building_type", "house")
	root.set_meta("asset_source", "composed_house")
	root.set_meta("art_bounds", Vector3(2.12, 2.04, 2.12))
	root.set_meta("door_clear_height", 0.956)
	root.set_meta("roof_identity", "tile_gable_red_brackets")
	root.set_meta("roof_marker", "RoofIdentity_HouseBrackets")
	root.set_meta("open_living_court", true)
	var parts := Kit.collect_parts(source)
	var stone: MeshInstance3D = parts.StoneFoundation
	var wood: MeshInstance3D = parts.RaisedFloor
	var dark: MeshInstance3D = parts.TopBeam
	var plaster: MeshInstance3D = parts.PlasterWall
	var hall := Kit.branch(root, "TiledLivingHall")
	# Keep a person-sized clear doorway; scale about the raised floor datum.
	hall.scale.y = 1.20
	hall.position.y = -0.06
	var court := Kit.branch(root, "LivingCourt")
	Kit.fit(stone, root, "HouseFoundation", Vector3(0, 0.12, 0), Vector3(2.08, 0.24, 2.08))
	Kit.fit(stone, court, "CourtPaving", Vector3(0, 0.243, 0.50), Vector3(1.97, 0.025, 0.95))
	Kit.fit(wood, hall, "InteriorFloor", Vector3(0, 0.278, -0.43), Vector3(1.68, 0.06, 0.92))
	Kit.fit(plaster, hall, "RearWall", Vector3(0, 0.715, -0.86), Vector3(1.70, 0.87, 0.10))
	for side in [-1.0, 1.0]:
		Kit.fit(plaster, hall, "SideWall", Vector3(side * 0.81, 0.715, -0.43), Vector3(0.10, 0.87, 0.94))
		Kit.fit(dark, hall, "PorchPost", Vector3(side * 0.80, 0.765, 0.035), Vector3(0.075, 1.01, 0.075))
		Kit.fit(dark, hall, "RearPost", Vector3(side * 0.80, 0.765, -0.86), Vector3(0.075, 1.01, 0.075))
		# Each facade window is an actual opening, with clear space between sills.
		Kit.fit(plaster, hall, "WindowSillWall", Vector3(side * 0.54, 0.445, 0.012), Vector3(0.51, 0.32, 0.09))
		Kit.fit(plaster, hall, "WindowHeaderWall", Vector3(side * 0.54, 1.08, 0.012), Vector3(0.51, 0.14, 0.09))
		for x in [side * 0.79, side * 0.29]:
			Kit.fit(dark, hall, "WindowJamb", Vector3(x, 0.82, 0.024), Vector3(0.043, 0.47, 0.06))
		for y in [0.60, 1.025]:
			Kit.fit(wood, hall, "WindowSill", Vector3(side * 0.54, y, 0.044), Vector3(0.52, 0.035, 0.11))
		var shutter := Kit.branch(hall, "OpenWindowShutter")
		shutter.position = Vector3(side * 0.78, 0.815, 0.074)
		shutter.rotation.y = side * 0.70
		Kit.fit(wood, shutter, "ShutterPanel", Vector3(-side * 0.09, 0, 0), Vector3(0.18, 0.37, 0.035))
		for brace_y in [-0.125, 0.125]:
			Kit.fit(dark, shutter, "ShutterBrace", Vector3(-side * 0.09, brace_y, 0.025), Vector3(0.18, 0.022, 0.016))
	Kit.fit(dark, hall, "DoorLintel", Vector3(0, 1.155, 0.035), Vector3(1.72, 0.10, 0.10))
	for side in [-1.0, 1.0]:
		var hinge := Kit.branch(hall, "OpenDoorLeaf")
		hinge.position = Vector3(side * 0.255, 0.70, 0.065)
		hinge.rotation.y = side * 1.15
		Kit.fit(wood, hinge, "DoorPlanks", Vector3(-side * 0.116, 0, 0), Vector3(0.232, 0.77, 0.039))
		for y in [-0.26, 0.26]:
			Kit.fit(dark, hinge, "DoorBrace", Vector3(-side * 0.116, y, 0.025), Vector3(0.232, 0.032, 0.022))
		Kit.sphere(hinge, "DoorPull", Vector3(0.025, 0.035, 0.018), Vector3(-side * 0.19, 0.02, 0.029), Kit.material(Color("907948")))
	Kit.fit(stone, court, "Doorstep", Vector3(0, 0.285, 0.24), Vector3(0.66, 0.085, 0.28))
	var roof_mapping := Transform3D(Basis.from_scale(Vector3(0.82, 0.70, 0.49)), Vector3(0, 0.27, -0.43))
	Kit.copy_roof(parts, hall, roof_mapping)
	var red_source: MeshInstance3D = parts.RoofIdentity_HouseBrackets
	for side in [-1.0, 1.0]:
		for bracket_index in range(5):
			var bracket_x := -0.65 + float(bracket_index) * 0.325
			var bracket_z := 0.09 if side > 0 else -0.89
			Kit.fit(red_source, hall, "RoofIdentity_HouseBrackets", Vector3(bracket_x, 1.076, bracket_z), Vector3(0.135, 0.06, 0.15))
			Kit.fit(dark, hall, "EaveBracketSupport", Vector3(bracket_x, 1.114, bracket_z), Vector3(0.085, 0.04, 0.10))
	for side in [-1.0, 1.0]:
		Kit.gable(hall, "HouseGable", side * 0.805, -0.90, 0.04, 1.14, 1.57, plaster.mesh.surface_get_material(0))
	# Small interior furniture makes the open doorway read as a home.
	Kit.fit(wood, hall, "FamilyTable", Vector3(0, 0.55, -0.53), Vector3(0.45, 0.05, 0.31))
	for x in [-0.16, 0.16]:
		Kit.fit(dark, hall, "TableLeg", Vector3(x, 0.425, -0.53), Vector3(0.04, 0.24, 0.20))
	Kit.jar(hall, "TeaPot", Vector3(0.09, 0.58, -0.51), 0.034, Kit.material(Color("697868")))
	Kit.fit(wood, hall, "InteriorBench", Vector3(-0.51, 0.43, -0.42), Vector3(0.21, 0.045, 0.51))
	for z in [-0.59, -0.26]:
		Kit.fit(dark, hall, "BenchLeg", Vector3(-0.51, 0.37, z), Vector3(0.16, 0.13, 0.04))
	# Enclose the entire homestead with a low bamboo boundary, leaving one
	# person-sized gate aligned with the house door and front approach.
	var bamboo := Kit.material(Color("999067"))
	var bamboo_dark := Kit.material(Color("756746"))
	var perimeter := Kit.branch(court, "EnclosedBambooBoundary")
	for side in [-1.0, 1.0]:
		_bamboo_fence(perimeter, "BambooSideFence", Vector3(side * 0.99, 0, -0.99), Vector3(side * 0.99, 0, 0.95), bamboo, bamboo_dark)
		_bamboo_fence(perimeter, "BambooFrontFence", Vector3(side * 0.99, 0, 0.95), Vector3(side * 0.31, 0, 0.95), bamboo, bamboo_dark)
		Kit.cylinder(perimeter, "GatePost", 0.024, 0.48, Vector3(side * 0.31, 0.49, 0.95), bamboo_dark)
	_bamboo_fence(perimeter, "BambooRearFence", Vector3(-0.99, 0, -0.99), Vector3(0.99, 0, -0.99), bamboo, bamboo_dark)
	Kit.fit(stone, court, "GardenGateThreshold", Vector3(0, 0.258, 0.94), Vector3(0.55, 0.028, 0.18))
	# Split firewood is stacked under the left window, clear of the open door.
	var logs := Kit.branch(court, "HouseholdFirewood")
	for layer in range(3):
		for log_index in range(3 - layer):
			var log := Kit.cylinder(logs, "SplitFirewood", 0.036, 0.34, Vector3(-0.68 + log_index * 0.072 + layer * 0.036, 0.30 + layer * 0.064, 0.29), wood.mesh.surface_get_material(0))
			log.rotation.x = PI / 2
	# A genuinely open ceramic water jar, with a dark visible water surface.
	var jar := Kit.branch(court, "OpenWaterJar")
	jar.position = Vector3(0.64, 0.27, 0.57)
	var ceramic := Kit.material(Color("6e7561"))
	_open_jar_body(jar, ceramic)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.106
	lip.outer_radius = 0.139
	lip.rings = 32
	lip.ring_segments = 12
	Kit.piece(jar, "JarRim", lip, Vector3(0, 0.292, 0), ceramic)
	var water := Kit.material(Color("354c46"))
	water.roughness = 0.21
	Kit.cylinder(jar, "StoredWater", 0.107, 0.008, Vector3(0, 0.291, 0), water)
	# Sun-drying tray, vegetables and a rustic stool imply everyday activity.
	Kit.cylinder(court, "VegetableDryingTray", 0.19, 0.035, Vector3(-0.63, 0.33, 0.74), bamboo)
	for i in range(10):
		var a := float(i) * 2.399
		var vegetable := Kit.sphere(court, "DryingVegetable", Vector3(0.073, 0.027, 0.034), Vector3(-0.63 + cos(a) * 0.12, 0.36, 0.74 + sin(a) * 0.12), Kit.material(Color("a27048") if i % 2 else Color("8c8550")))
		vegetable.rotation.y = a
	Kit.fit(wood, court, "CourtyardStool", Vector3(0.54, 0.43, 0.13), Vector3(0.25, 0.05, 0.22))
	for x in [0.45, 0.63]:
		Kit.fit(dark, court, "StoolLeg", Vector3(x, 0.345, 0.13), Vector3(0.035, 0.17, 0.15))
	# Two potted leafy plants stay below the eaves and off the entrance path.
	for i in range(2):
		var center := Vector3(-0.82 + i * 0.18, 0.26, -0.02)
		Kit.cylinder(court, "GardenPot", 0.056, 0.11, center + Vector3.UP * 0.055, Kit.material(Color("93745b")))
		for leaf_index in range(5):
			var a := float(leaf_index) * TAU / 5.0
			var leaf := Kit.sphere(court, "HerbLeaf", Vector3(0.048, 0.12, 0.02), center + Vector3(cos(a) * 0.028, 0.16, sin(a) * 0.028), Kit.material(Color("627852")))
			leaf.rotation = Vector3(sin(a) * 0.50, a, cos(a) * 0.50)
	Kit.anchor(root, "Door", Vector3(0, 0, 1.08))
	source.free()
	return root

static func _bamboo_fence(parent: Node3D, label: String, start: Vector3, finish: Vector3, bamboo: Material, binding: Material) -> void:
	var fence := Kit.branch(parent, label)
	var length := start.distance_to(finish)
	var intervals := maxi(1, ceili(length / 0.11))
	for stave in range(intervals + 1):
		var pos := start.lerp(finish, float(stave) / intervals) + Vector3.UP * 0.45
		Kit.cylinder(fence, "BambooUpright", 0.014, 0.40 + float(stave % 2) * 0.04, pos, bamboo)
	for y in [0.36, 0.55]:
		var rail := Kit.cylinder(fence, "BambooRail", 0.014, length, (start + finish) * 0.5 + Vector3.UP * y, binding)
		if absf(finish.x - start.x) > absf(finish.z - start.z):
			rail.rotation.z = PI / 2
		else:
			rail.rotation.x = PI / 2

static func _open_jar_body(parent: Node3D, material: Material) -> void:
	var profiles := [Vector2(0.103, 0.005), Vector2(0.143, 0.06), Vector2(0.166, 0.14), Vector2(0.155, 0.22), Vector2(0.123, 0.29), Vector2(0.103, 0.29), Vector2(0.107, 0.25)]
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var segments := 32
	for profile in profiles:
		for segment in range(segments):
			var a := TAU * segment / segments
			vertices.append(Vector3(cos(a) * profile.x, profile.y, sin(a) * profile.x))
	for ring in range(profiles.size() - 1):
		for segment in range(segments):
			var a := ring * segments + segment
			var b := ring * segments + (segment + 1) % segments
			indices.append_array(PackedInt32Array([a, b, a + segments, b, b + segments, a + segments]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var raw := ArrayMesh.new()
	raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(raw, 0)
	surface.generate_normals()
	var body := MeshInstance3D.new()
	body.name = "JarBody"
	body.mesh = surface.commit()
	body.mesh.surface_set_material(0, material)
	parent.add_child(body)
