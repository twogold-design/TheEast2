extends RefCounted

const Kit = preload("res://godot/OpenClinicAssets.gd")

## A single complete tiled storehouse with an open loading court, not a set
## of market stalls. The old GLB remains intact and supplies textured parts.
static func create_warehouse(source: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "OpenWarehouse"
	root.set_meta("asset_key", "building.warehouse")
	root.set_meta("building_type", "warehouse")
	root.set_meta("asset_source", "composed_warehouse")
	root.set_meta("art_bounds", Vector3(4.28, 2.30, 4.28))
	root.set_meta("roof_identity", "tile_gable_twin_vents")
	root.set_meta("roof_marker", "RoofIdentity_WarehouseVent")
	root.set_meta("open_loading_court", true)
	root.set_meta("footprint_cells", Vector2i(2, 2))
	var parts := Kit.collect_parts(source)
	var stone: MeshInstance3D = parts.HighStonePlinth
	var wood: MeshInstance3D = parts.WarehouseFloor
	var dark: MeshInstance3D = parts.WarehouseTieBeam
	var wall: MeshInstance3D = parts.ThickPlasterWalls
	var sack: MeshInstance3D = parts.GrainSack_00
	var hall := Kit.branch(root, "OpenStorageHall")
	var court := Kit.branch(root, "LoadingCourt")
	Kit.fit(stone, root, "WarehouseFoundation", Vector3(0, 0.10, 0), Vector3(4.28, 0.20, 4.28))
	Kit.fit(stone, court, "StoneLoadingCourt", Vector3(0, 0.215, 0.83), Vector3(4.08, 0.045, 2.47))
	# Raised timber hall floor, full rear roof, three walls and exposed posts.
	Kit.fit(wood, hall, "WarehouseFloor", Vector3(0, 0.30, -1.03), Vector3(3.49, 0.16, 1.55))
	Kit.fit(wall, hall, "RearWarehouseWall", Vector3(0, 0.97, -1.80), Vector3(3.48, 1.18, 0.13))
	for side in [-1.0, 1.0]:
		Kit.fit(wall, hall, "WarehouseSideWall", Vector3(side * 1.68, 0.97, -1.08), Vector3(0.13, 1.18, 1.44))
		for z in [-1.74, -0.36]:
			Kit.fit(dark, hall, "WarehouseLoadPost", Vector3(side * 1.62, 1.00, z), Vector3(0.13, 1.31, 0.13))
	Kit.fit(dark, hall, "WarehouseLintel", Vector3(0, 1.60, -0.36), Vector3(3.49, 0.13, 0.14))
	Kit.copy_roof(parts, hall, Transform3D(Basis.from_scale(Vector3(1.48, 0.76, 0.75)), Vector3(0, 0.30, -1.03)), true)
	for side in [-1.0, 1.0]:
		Kit.gable(hall, "WarehouseGable", side * 1.68, -1.80, -0.30, 1.55, 2.15, wall.mesh.surface_get_material(0))
	# Original double doors are swung clear against either side of the hall;
	# the front remains a real opening into visible stored goods.
	for side in [-1.0, 1.0]:
		var door := Kit.branch(hall, "OpenLoadingDoor")
		door.position = Vector3(side * 1.50, 0, -0.35)
		door.rotation.y = side * -1.27
		Kit.fit(parts.DoubleDoor, door, "WarehouseDoorLeaf", Vector3(-side * 0.43, 0.99, 0), Vector3(0.86, 1.21, 0.08))
		for y in [0.52, 0.99, 1.47]:
			Kit.fit(parts.DoorIronStrap, door, "DoorIronStrap", Vector3(-side * 0.43, y, 0.045), Vector3(0.76, 0.05, 0.025))
	Kit.fit(parts.WarehouseSign, hall, "WarehouseSign", Vector3(0, 1.48, -0.13), Vector3(0.81, 0.25, 0.045))
	Kit.text_sign(hall, "仓 库", Vector3(0, 1.48, -0.10), 0.0025, Color("ddc58f"))
	# Low boundary walls define an open yard without hiding cargo from above.
	for side in [-1.0, 1.0]:
		Kit.fit(wall, court, "LowCourtWall", Vector3(side * 2.01, 0.47, 0.69), Vector3(0.12, 0.48, 2.73))
		Kit.fit(stone, court, "CourtWallCoping", Vector3(side * 2.01, 0.73, 0.69), Vector3(0.16, 0.07, 2.78))
		Kit.fit(wall, court, "FrontGateWing", Vector3(side * 1.51, 0.42, 1.99), Vector3(1.08, 0.39, 0.13))
		Kit.fit(dark, court, "GatePost", Vector3(side * 0.92, 0.56, 1.97), Vector3(0.12, 0.70, 0.13))
	# A deliberate central unloaded aisle links the open hall and front gate.
	var grain := Kit.branch(court, "GrainSackStack")
	Kit.fit(wood, grain, "GrainPallet", Vector3(-1.10, 0.29, 0.35), Vector3(1.15, 0.10, 1.19))
	for tier in range(3):
		var count := 3 if tier < 2 else 2
		for row in range(2):
			for column in range(count):
				var center := Vector3(-1.46 + column * 0.34 + (0.17 if tier == 2 else 0.0), 0.45 + tier * 0.24, 0.04 + row * 0.52)
				Kit.fit(sack, grain, "StackedGrainSack", center, Vector3(0.36, 0.27, 0.47))
				Kit.cylinder(grain, "SackTie", 0.022, 0.032, center + Vector3(0, 0.143, 0), Kit.material(Color("6c6044")))
	var crates := Kit.branch(court, "CargoCrateStack")
	for i in range(5):
		var center := Vector3(0.90 + (i % 2) * 0.64, 0.51 + (i / 4) * 0.53, -0.16 + ((i / 2) % 2) * 0.60)
		create_crate(crates, wood, dark, center, Vector3(0.57, 0.51, 0.53))
	# Cargo remains visible inside the shaded hall through its broad opening.
	for i in range(4):
		create_crate(hall, wood, dark, Vector3(-1.22 + i * 0.64, 0.65, -1.24), Vector3(0.55, 0.52, 0.56))
	var timber := Kit.branch(court, "SortedTimberStack")
	for tier in range(3):
		for board in range(4 - (tier % 2)):
			Kit.fit(wood, timber, "StackedTimber", Vector3(-1.52 + board * 0.23, 0.28 + tier * 0.13, 1.30), Vector3(0.20, 0.11, 0.91))
	for x in [-1.55, -0.77]:
		Kit.fit(dark, timber, "TimberBand", Vector3(x, 0.40, 1.30), Vector3(0.035, 0.43, 0.93))
	create_cart(court, wood, dark)
	Kit.fit(wood, court, "UnloadingRamp", Vector3(0, 0.275, -0.10), Vector3(1.46, 0.105, 0.40))
	Kit.anchor(root, "Door", Vector3(0, 0, 2.14))
	Kit.anchor(root, "PorterAnchor", Vector3(0.10, 0.24, 0.70))
	source.free()
	return root

static func create_crate(parent: Node3D, wood: MeshInstance3D, dark: MeshInstance3D, center: Vector3, size: Vector3) -> void:
	Kit.fit(wood, parent, "CargoCrate", center, size)
	for side in [-1.0, 1.0]:
		Kit.fit(dark, parent, "CrateVerticalBand", center + Vector3(side * size.x * 0.35, 0, 0), Vector3(0.035, size.y + 0.02, size.z + 0.015))
	Kit.fit(dark, parent, "CrateTopBrace", center + Vector3(0, size.y * 0.5 + 0.014, 0), Vector3(size.x, 0.028, 0.055))

static func create_cart(parent: Node3D, wood: MeshInstance3D, dark: MeshInstance3D) -> void:
	var cart := Kit.branch(parent, "WarehouseHandcart")
	cart.position = Vector3(1.20, 0, 1.30)
	cart.rotation.y = -0.18
	Kit.fit(wood, cart, "CartBed", Vector3(0, 0.47, 0), Vector3(0.70, 0.08, 0.73))
	for side in [-1.0, 1.0]:
		Kit.fit(wood, cart, "CartSide", Vector3(side * 0.32, 0.64, 0), Vector3(0.055, 0.31, 0.73))
		Kit.fit(dark, cart, "CartHandle", Vector3(side * 0.25, 0.48, 0.45), Vector3(0.045, 0.045, 0.48))
		var wheel := Node3D.new()
		wheel.name = "SpokedCartWheel"
		wheel.position = Vector3(side * 0.41, 0.43, -0.03)
		cart.add_child(wheel)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.145
		ring.outer_radius = 0.197
		ring.rings = 18
		ring.ring_segments = 8
		var rim := Kit.piece(wheel, "IronWheelRim", ring, Vector3.ZERO, Kit.material(Color("494c43")))
		rim.rotation.z = PI * 0.5
		for spoke in range(8):
			var spoke_node := Kit.fit(dark, wheel, "WheelSpoke", Vector3.ZERO, Vector3(0.038, 0.32, 0.029))
			spoke_node.rotation.x = spoke * PI / 4
	Kit.fit(wood, cart, "CartRearPanel", Vector3(0, 0.64, -0.35), Vector3(0.65, 0.31, 0.055))
	create_crate(cart, wood, dark, Vector3(0, 0.65, 0), Vector3(0.40, 0.26, 0.37))
