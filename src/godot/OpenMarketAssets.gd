extends RefCounted

## Four open stalls surround a clear central aisle. Roofs belong to individual
## stalls, never cover the courtyard, and all geometry stays inside 4.4 m.
static var materials := {}

static func create_market() -> Node3D:
	var root := Node3D.new()
	root.name = "OpenMarket"
	root.set_meta("building_type", "market")
	root.set_meta("asset_source", "composed_market")
	root.set_meta("art_bounds", Vector3(4.2, 1.9, 4.2))
	root.set_meta("open_courtyard", true)
	box(root, "StoneCourt", Vector3(4.12, 0.14, 4.12), Vector3(0, 0.17, 0), material("stone", Color("a0a293")))
	for row in range(8):
		for col in range(8):
			box(root, "Paving_%d_%d" % [row, col], Vector3(0.495, 0.025, 0.495), Vector3(-1.785 + col * 0.51, 0.253, -1.785 + row * 0.51), material("stone", Color("93968a") if (row + col) % 3 == 0 else Color("a7aa9a")))
	var colors := [Color("a16a4c"), Color("698477"), Color("a89668"), Color("647c86")]
	for i in range(4):
		var stall := Node3D.new()
		stall.name = "Stall_%d" % i
		stall.position = Vector3(-1.25 if i < 2 else 1.25, 0.26, -0.98 if i % 2 == 0 else 0.98)
		stall.rotation.y = PI / 2 if i < 2 else -PI / 2
		root.add_child(stall)
		create_stall(stall, i, colors[i])
	for side in [-1.0, 1.0]:
		cylinder(root, "BannerPost", 0.035, 1.55, Vector3(side * 1.72, 1.02, 1.84), material("wood", Color("6d503b")))
		box(root, "MarketRoofBanner" if side < 0 else "MarketBanner", Vector3(0.42, 0.58, 0.035), Vector3(side * 1.5, 1.49, 1.84), material("cloth", Color("985d45")))
		for mark in range(3):
			box(root, "BannerInk", Vector3(0.14, 0.035, 0.012), Vector3(side * 1.5, 1.67 - mark * 0.15, 1.865), material("", Color("dfcf9e")))
	var door := Marker3D.new()
	door.name = "Door"
	door.position = Vector3(0, 0.18, 2.05)
	root.add_child(door)
	return root

static func create_stall(root: Node3D, index: int, cloth_color: Color) -> void:
	var wood := material("wood", Color("9b7856"))
	var dark := material("wood", Color("604b38"))
	var cloth := material("cloth", cloth_color)
	# A complete shallow pitched canvas roof, with exposed counter in front.
	for side in [-1.0, 1.0]:
		var roof := box(root, "CanvasSlope", Vector3(1.67, 0.045, 0.49), Vector3(0, 1.28, side * 0.22 - 0.15), cloth)
		roof.rotation.x = side * 0.23
		for x in [-0.73, 0.73]:
			cylinder(root, "TimberPost", 0.028, 1.3, Vector3(x, 0.65, side * 0.48 - 0.15), dark)
	box(root, "RidgePole", Vector3(1.76, 0.045, 0.045), Vector3(0, 1.35, -0.15), dark)
	for panel in range(8):
		box(root, "ScallopedValance", Vector3(0.19, 0.115 + (panel % 2) * 0.025, 0.025), Vector3(-0.70 + panel * 0.2, 1.18, 0.31), cloth)
	box(root, "CounterTop", Vector3(1.55, 0.075, 0.42), Vector3(0, 0.47, 0.43), wood)
	for x in [-0.66, 0.66]:
		box(root, "CounterLeg", Vector3(0.055, 0.44, 0.32), Vector3(x, 0.22, 0.43), dark)
	box(root, "CounterApron", Vector3(1.45, 0.22, 0.045), Vector3(0, 0.32, 0.64), wood)
	for ware in range(3):
		var x := -0.46 + ware * 0.46
		if index == 2:
			for roll in range(3):
				var cloth_roll := cylinder(root, "ClothRoll", 0.055, 0.25, Vector3(x, 0.55 + roll * 0.085, 0.44), material("cloth", [Color("8a6251"), Color("657e7d"), Color("b59f74")][roll]))
				cloth_roll.rotation.z = PI / 2
		else:
			box(root, "ProduceTray", Vector3(0.36, 0.06, 0.30), Vector3(x, 0.55, 0.43), dark)
			for item in range(5):
				var color: Color = [Color("918a4a"), Color("b59454"), Color("a67755"), Color("717e54")][index]
				if index == 3:
					cylinder(root, "Pottery", 0.055, 0.14, Vector3(x - 0.11 + (item % 3) * 0.11, 0.63, 0.36 + (item / 3) * 0.13), material("", color))
				else:
					sphere(root, "Produce", Vector3(0.105, 0.085, 0.095), Vector3(x - 0.11 + (item % 3) * 0.11, 0.62, 0.36 + (item / 3) * 0.13), material("", color))
	box(root, "Crate", Vector3(0.34, 0.30, 0.32), Vector3(-0.58, 0.15, -0.48), wood)
	for band in [-0.10, 0.10]:
		box(root, "CrateBand", Vector3(0.025, 0.32, 0.34), Vector3(-0.58 + band, 0.16, -0.48), dark)
	cylinder(root, "GrainBasket", 0.16, 0.22, Vector3(0.58, 0.11, -0.47), material("", Color("aa905e")))
	sphere(root, "GrainMound", Vector3(0.29, 0.12, 0.29), Vector3(0.58, 0.24, -0.47), material("", Color("b8a06d")))

static func material(kind: String, color: Color) -> StandardMaterial3D:
	var key := kind + color.to_html()
	if materials.has(key):
		return materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	var path := ""
	if kind == "wood":
		path = "res://godot/assets/realistic/models/building_warehouse_wood_warm_basecolor.png"
	elif kind == "stone":
		path = "res://godot/assets/realistic/models/building_warehouse_stone_basecolor.png"
	if not path.is_empty():
		result.albedo_texture = load(path)
	materials[key] = result
	return result

static func box(parent: Node3D, label: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return piece(parent, label, mesh, pos, mat)

static func cylinder(parent: Node3D, label: String, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.9
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return piece(parent, label, mesh, pos, mat)

static func sphere(parent: Node3D, label: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var result := piece(parent, label, mesh, pos, mat)
	result.scale = size
	return result

static func piece(parent: Node3D, label: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = mesh
	result.position = pos
	result.material_override = mat
	parent.add_child(result)
	return result
