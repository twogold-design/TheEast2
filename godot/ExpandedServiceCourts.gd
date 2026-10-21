extends RefCounted

const Kit = preload("res://godot/OpenClinicAssets.gd")

## Extend an authored single-cell service building into an actual two-hall
## courtyard. Architecture, tools and people retain their original world scale.
static func expand(compact: Node3D, type: String) -> Node3D:
	var root := Node3D.new()
	root.name = "ExpandedWorkshop" if type == "workshop" else "ExpandedClinic"
	for key in compact.get_meta_list():
		root.set_meta(key, compact.get_meta(key))
	root.set_meta("footprint_cells", Vector2i(2, 2))
	root.set_meta("art_bounds", Vector3(4.28, 2.12, 4.28))
	root.set_meta("expanded_service_court", true)
	var is_workshop := type == "workshop"
	var parts := Kit.collect_parts(compact)
	var stone: MeshInstance3D = parts.WorkshopFoundation if is_workshop else parts.ClinicFoundation
	var wood: MeshInstance3D = parts.WorkBench if is_workshop else parts.DiagnosisTable
	var dark: MeshInstance3D = parts.HallPost if is_workshop else parts.FrontPost
	var ground_height := 0.27 if is_workshop else 0.23
	Kit.fit(stone, root, "ServiceCourtFoundation", Vector3(0, ground_height * 0.5, 0), Vector3(4.26, ground_height, 4.26))
	var court := Kit.branch(root, "ExpandedWorkingCourt" if is_workshop else "ExpandedHealingCourt")
	# Keep old material/geometry data alive for reuse, but remove coplanar floors.
	var old_floor := compact.find_child("FireproofFloor" if is_workshop else "ClinicCourtPaving", true, false)
	if old_floor:
		old_floor.hide()
	var old_door := compact.get_node_or_null("Door")
	if old_door:
		old_door.free()
	compact.name = "OriginalScaleWorkshop" if is_workshop else "OriginalScaleDispensary"
	compact.position = Vector3(-0.95, 0, -0.85)
	root.add_child(compact)
	var second_hall := Kit.branch(root, "TimberWorkShelter" if is_workshop else "OpenTreatmentPavilion")
	var source_hall := compact.get_node("OpenRearHall" if is_workshop else "DispensaryHall")
	for child in source_hall.get_children():
		if child is MeshInstance3D and (str(child.name).begins_with("RoofTile") or str(child.name).begins_with("RoofRidge") or str(child.name).begins_with("RidgeEnd")):
			var copy := child.duplicate() as MeshInstance3D
			copy.position += Vector3(0.96, 0, -0.85)
			second_hall.add_child(copy)
	for x in [0.22, 1.70]:
		for z in [-1.71, -1.08]:
			Kit.fit(dark, second_hall, "PavilionPost", Vector3(x, (ground_height + 1.14) * 0.5, z), Vector3(0.075, 1.14 - ground_height, 0.075))
	for z in [-1.73, -1.08]:
		Kit.fit(dark, second_hall, "PavilionBeam", Vector3(0.96, 1.10, z), Vector3(1.60, 0.09, 0.08))
	# A low boundary encloses the compound without blocking the front aisle.
	for side in [-1.0, 1.0]:
		Kit.fit(stone, court, "LowSideWall", Vector3(side * 2.035, ground_height + 0.12, 0.50), Vector3(0.105, 0.24, 2.85))
		Kit.fit(stone, court, "EntranceWingWall", Vector3(side * 1.28, ground_height + 0.12, 2.03), Vector3(1.42, 0.24, 0.105))
		Kit.fit(stone, court, "EntrancePost", Vector3(side * 0.59, ground_height + 0.22, 2.03), Vector3(0.16, 0.44, 0.16))
	Kit.fit(stone, court, "CourtEntranceStep", Vector3(0, 0.12, 2.02), Vector3(0.95, 0.18, 0.20))
	for paver in range(5):
		Kit.box(court, "CentralCourtyardPath", Vector3(0.43, 0.016, 0.32), Vector3(0, ground_height + 0.01, 1.68 - paver * 0.38), Kit.material(Color("8a8b79")))
	if is_workshop:
		_workshop_yard(court, second_hall, parts, wood, dark, stone)
		Kit.anchor(root, "ArtisanAnchor", Vector3(-0.52, 0.27, -0.46))
	else:
		_clinic_yard(court, second_hall, parts, wood, dark, stone)
		Kit.anchor(root, "DoctorAnchor", Vector3(-0.73, 0.23, -0.80))
	Kit.anchor(root, "Door", Vector3(0, 0, 2.14))
	stone.hide()
	return root

static func _table(parent: Node3D, name: String, pos: Vector3, size: Vector2, wood: MeshInstance3D, dark: MeshInstance3D) -> void:
	Kit.fit(wood, parent, name, pos, Vector3(size.x, 0.07, size.y))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			Kit.fit(dark, parent, name + "Leg", Vector3(pos.x + x * (size.x * 0.5 - 0.08), (pos.y + 0.25) * 0.5, pos.z + z * (size.y * 0.5 - 0.06)), Vector3(0.05, pos.y - 0.25, 0.05))

static func _workshop_yard(court: Node3D, shelter: Node3D, parts: Dictionary, wood: MeshInstance3D, dark: MeshInstance3D, stone: MeshInstance3D) -> void:
	_table(shelter, "CarpentryBench", Vector3(0.96, 0.71, -1.13), Vector2(1.25, 0.52), wood, dark)
	for i in range(4):
		Kit.fit(wood, shelter, "JoineryBoard", Vector3(0.73 + i * 0.12, 0.765, -1.14), Vector3(0.09, 0.04, 0.43))
	Kit.fit(parts.AnvilBody, shelter, "CarpentryPlane", Vector3(1.27, 0.795, -1.11), Vector3(0.18, 0.065, 0.075))
	# An exposed saw trestle, hardware stock and assembly stand occupy the yard.
	_table(court, "AssemblyBench", Vector3(1.15, 0.64, 0.53), Vector2(1.18, 0.54), wood, dark)
	for side in [-1.0, 1.0]:
		Kit.fit(wood, court, "TrestleFrameRail", Vector3(1.15, 0.705, 0.53 + side * 0.15), Vector3(0.93, 0.045, 0.065))
	for x in [0.78, 1.03, 1.28, 1.53]:
		Kit.fit(wood, court, "AssembledDoorSlat", Vector3(x, 0.74, 0.53), Vector3(0.07, 0.04, 0.40))
	Kit.fit(parts.AnvilBody, court, "HandSawBlade", Vector3(1.47, 0.76, 0.55), Vector3(0.045, 0.025, 0.29))
	Kit.fit(dark, court, "HandSawGrip", Vector3(1.47, 0.77, 0.77), Vector3(0.07, 0.04, 0.14))
	var rack := Kit.branch(court, "TimberStorageRack")
	for layer in range(4):
		for plank in range(3):
			Kit.fit(wood, rack, "SeasoningTimber", Vector3(-1.20, 0.34 + layer * 0.09, 0.53 + plank * 0.12), Vector3(1.23, 0.06, 0.10))
	for x in [-1.70, -0.70]:
		Kit.fit(dark, rack, "TimberRackFoot", Vector3(x, 0.31, 0.65), Vector3(0.12, 0.10, 0.55))
	for i in range(3):
		Kit.fit(parts.AnvilBody, court, "IronBilletStack", Vector3(-1.57 + i * 0.24, 0.35, 1.35), Vector3(0.19, 0.14, 0.38))
	# A spoked cart makes finished-goods handling explicit.
	var cart := Kit.branch(court, "WorkshopHandcart")
	cart.position = Vector3(1.06, 0, 1.16)
	Kit.fit(wood, cart, "CartBed", Vector3(0, 0.53, 0), Vector3(0.80, 0.065, 0.46))
	for side in [-1.0, 1.0]:
		Kit.fit(dark, cart, "CartHandle", Vector3(side * 0.27, 0.56, 0.32), Vector3(0.055, 0.055, 0.95))
		var wheel := TorusMesh.new()
		wheel.inner_radius = 0.19
		wheel.outer_radius = 0.22
		wheel.rings = 24
		wheel.ring_segments = 8
		var rim := Kit.piece(cart, "CartWheel", wheel, Vector3(side * 0.46, 0.50, -0.04), dark.mesh.surface_get_material(0))
		rim.rotation.z = PI / 2
		for spoke_index in range(6):
			var spoke := Kit.box(rim, "WheelSpoke", Vector3(0.41, 0.025, 0.025), Vector3.ZERO, wood.mesh.surface_get_material(0))
			spoke.rotation.y = spoke_index * PI / 3
	for i in range(3):
		Kit.fit(wood, cart, "FinishedCrate", Vector3(-0.25 + i * 0.25, 0.69, 0), Vector3(0.21, 0.24, 0.34))
	Kit.fit(stone, court, "QuenchingTrough", Vector3(-1.58, 0.43, -0.04), Vector3(0.54, 0.27, 0.26))
	Kit.box(court, "QuenchingWater", Vector3(0.44, 0.016, 0.17), Vector3(-1.58, 0.573, -0.04), Kit.material(Color("435e59")))

static func _clinic_yard(court: Node3D, shelter: Node3D, parts: Dictionary, wood: MeshInstance3D, dark: MeshInstance3D, stone: MeshInstance3D) -> void:
	_table(shelter, "SecondDiagnosisTable", Vector3(1.02, 0.58, -0.97), Vector2(0.86, 0.43), wood, dark)
	Kit.box(shelter, "SecondWristCushion", Vector3(0.20, 0.055, 0.12), Vector3(1.05, 0.65, -0.97), Kit.material(Color("76816d")))
	Kit.box(shelter, "PrescriptionBundle", Vector3(0.16, 0.018, 0.21), Vector3(0.73, 0.63, -0.97), Kit.material(Color("d5c6a2")))
	_table(court, "PatientWaitingBench", Vector3(1.14, 0.44, -0.24), Vector2(1.10, 0.25), wood, dark)
	# Duplicate the complete textured drawer cabinet at original human scale.
	var cabinet := parts.MedicineDrawer_0_0.get_parent().duplicate() as Node3D
	cabinet.name = "SecondMedicineCabinet"
	cabinet.position = Vector3(1.46, 0, -1.61)
	shelter.add_child(cabinet)
	for i in range(4):
		Kit.jar(shelter, "BulkHerbJar", Vector3(1.43 + (i % 2) * 0.21, 0.27, -1.62 + floori(i / 2.0) * 0.25), 0.09, Kit.material(Color("7b846c") if i % 2 else Color("987a59")))
	# The sunny front half holds drying racks and planted medicinal herbs.
	for rack_index in range(2):
		var center := Vector3(-1.25 + rack_index * 0.65, 0, 0.94)
		for level in range(2):
			var tray_center := center + Vector3(0, 0.49 + level * 0.31, 0)
			Kit.cylinder(court, "ExpandedDryingTray", 0.32, 0.037, tray_center, Kit.material(Color("a18a60")))
			for leaf_index in range(15):
				var a := leaf_index * 2.399
				var leaf := Kit.box(court, "DryingMedicine", Vector3(0.087, 0.018, 0.031), tray_center + Vector3(cos(a) * 0.23, 0.03, sin(a) * 0.23), Kit.material(Color("6f815b") if leaf_index % 2 else Color("9a8158")))
				leaf.rotation.y = a
		for side in [-1.0, 1.0]:
			Kit.fit(dark, court, "HerbRackLeg", center + Vector3(side * 0.24, 0.50, 0), Vector3(0.04, 0.55, 0.04))
	var herb_bed := Kit.branch(court, "MedicinalHerbGarden")
	Kit.fit(stone, herb_bed, "HerbBedBorder", Vector3(1.23, 0.32, 1.20), Vector3(1.26, 0.19, 0.88))
	Kit.box(herb_bed, "HerbBedSoil", Vector3(1.12, 0.018, 0.74), Vector3(1.23, 0.423, 1.20), Kit.material(Color("675e43")))
	for row in range(3):
		for column in range(5):
			var plant := Vector3(0.79 + column * 0.21, 0.48, 0.95 + row * 0.24)
			for leaf_index in range(4):
				var a := leaf_index * PI / 2 + column * 0.35
				var leaf := Kit.sphere(herb_bed, "GrowingMedicinalLeaf", Vector3(0.12, 0.035, 0.055), plant + Vector3(cos(a) * 0.035, leaf_index * 0.018, sin(a) * 0.035), Kit.material(Color("62794f")))
				leaf.rotation.y = a
	Kit.fit(wood, court, "MedicinePreparationTable", Vector3(1.15, 0.59, 0.38), Vector3(1.05, 0.07, 0.40))
	for x in [0.72, 1.58]:
		Kit.fit(dark, court, "MedicineTableLeg", Vector3(x, 0.41, 0.38), Vector3(0.055, 0.36, 0.28))
	for i in range(3):
		Kit.jar(court, "PreparedMedicinePot", Vector3(0.83 + i * 0.28, 0.635, 0.39), 0.067, Kit.material(Color("7a7763")))
