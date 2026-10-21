extends RefCounted

## A complete tiled dispensary hall opens onto a small treatment/herb court.
## Source GLB geometry is reused without editing the preserved asset pack.
static func create_clinic(source: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "OpenClinic"
	root.set_meta("asset_key", "building.clinic")
	root.set_meta("building_type", "clinic")
	root.set_meta("asset_source", "composed_clinic")
	root.set_meta("art_bounds", Vector3(2.12, 2.12, 2.12))
	root.set_meta("footprint_cells", Vector2i.ONE)
	root.set_meta("roof_identity", "tile_gable_medicine_gourd")
	root.set_meta("roof_marker", "RoofIdentity_ClinicGourd")
	root.set_meta("open_treatment_court", true)
	var parts := collect_parts(source)
	var stone: MeshInstance3D = parts.StoneFoundation
	var wood: MeshInstance3D = parts.RaisedFloor
	var dark: MeshInstance3D = parts.TopBeam
	var plaster: MeshInstance3D = parts.PlasterWall
	var hall := branch(root, "DispensaryHall")
	var court := branch(root, "TreatmentCourt")
	fit(stone, root, "ClinicFoundation", Vector3(0, 0.10, 0), Vector3(2.10, 0.20, 2.10))
	fit(stone, court, "ClinicCourtPaving", Vector3(0, 0.21, 0.30), Vector3(1.99, 0.035, 1.32))
	fit(plaster, hall, "RearWall", Vector3(0, 0.68, -0.89), Vector3(1.70, 0.90, 0.11))
	for side in [-1.0, 1.0]:
		fit(plaster, hall, "SideWall", Vector3(side * 0.80, 0.67, -0.59), Vector3(0.10, 0.89, 0.69))
		fit(dark, hall, "FrontPost", Vector3(side * 0.77, 0.72, -0.20), Vector3(0.075, 0.99, 0.075))
		fit(dark, hall, "RearPost", Vector3(side * 0.77, 0.72, -0.87), Vector3(0.075, 0.99, 0.075))
	fit(dark, hall, "Lintel", Vector3(0, 1.15, -0.20), Vector3(1.68, 0.12, 0.10))
	copy_roof(parts, hall, Transform3D(Basis.from_scale(Vector3(0.80, 0.66, 0.43)), Vector3(0, 0.32, -0.59)))
	for side in [-1.0, 1.0]:
		gable(hall, "ClinicGable", side * 0.80, -0.96, -0.22, 1.10, 1.58, plaster.mesh.surface_get_material(0))
	# The cabinet is on the exposed side of the court, facing the main camera.
	var cabinet := branch(court, "MedicineCabinet")
	fit(dark, cabinet, "CabinetBody", Vector3(-0.68, 0.62, 0.00), Vector3(0.45, 0.79, 0.22))
	for row in range(5):
		for column in range(3):
			var pos := Vector3(-0.81 + column * 0.132, 0.31 + row * 0.14, 0.13)
			fit(wood, cabinet, "MedicineDrawer_%d_%d" % [row, column], pos, Vector3(0.115, 0.12, 0.036))
			box(cabinet, "DrawerLabel", Vector3(0.068, 0.025, 0.008), pos + Vector3(0, 0.024, 0.022), material(Color("c8bb91")))
			sphere(cabinet, "DrawerPull", Vector3(0.024, 0.023, 0.020), pos + Vector3(0, -0.024, 0.032), material(Color("564334")))
	for i in range(4):
		jar(hall, "MedicineJar_%d" % i, Vector3(-0.54 + i * 0.31, 0.30, -0.52), 0.10, material(Color("727e6c") if i % 2 else Color("96765b")))
	# Diagnosis table, wrist cushion, paper prescriptions and a medicine mortar.
	fit(wood, court, "DiagnosisTable", Vector3(0.28, 0.57, 0.49), Vector3(0.75, 0.085, 0.38))
	for x in [-0.02, 0.58]:
		for z in [0.35, 0.63]:
			fit(dark, court, "DiagnosisTableLeg", Vector3(x, 0.39, z), Vector3(0.05, 0.35, 0.05))
	box(court, "WristCushion", Vector3(0.18, 0.05, 0.11), Vector3(0.22, 0.64, 0.50), material(Color("777c67")))
	box(court, "PrescriptionPaper", Vector3(0.13, 0.008, 0.17), Vector3(0.48, 0.621, 0.48), material(Color("d2c6a5")))
	cylinder(court, "MedicineMortar", 0.063, 0.075, Vector3(0.04, 0.65, 0.49), material(Color("77786b")))
	var pestle := cylinder(court, "MortarPestle", 0.013, 0.13, Vector3(0.06, 0.72, 0.49), material(Color("5c5445")))
	pestle.rotation.z = -0.45
	fit(wood, court, "PatientStool", Vector3(0.26, 0.38, 0.85), Vector3(0.27, 0.055, 0.23))
	for x in [0.16, 0.36]:
		fit(dark, court, "PatientStoolLeg", Vector3(x, 0.30, 0.85), Vector3(0.045, 0.16, 0.18))
	# Two shallow woven drying trays and visible loose herbs occupy the left.
	for tray_index in range(2):
		var center := Vector3(-0.65, 0.32 + tray_index * 0.21, 0.58)
		cylinder(court, "HerbDryingTray", 0.21, 0.038, center, material(Color("a18a60")))
		for herb in range(9):
			var angle := herb * 2.399
			var leaf := box(court, "DryingHerb", Vector3(0.082, 0.018, 0.028), center + Vector3(cos(angle) * 0.115, 0.028, sin(angle) * 0.115), material(Color("62745b") if herb % 2 else Color("99825b")))
			leaf.rotation.y = angle
	for x in [-0.81, -0.49]:
		fit(dark, court, "TrayRackLeg", Vector3(x, 0.40, 0.58), Vector3(0.035, 0.37, 0.035))
	var marker := branch(root, "RoofIdentity_ClinicGourd")
	marker.position = Vector3(0.27, 1.63, -0.57)
	gourd(marker, Vector3.ZERO, 0.30)
	var banner := branch(root, "ClinicMedicineBanner")
	fit(dark, banner, "BannerPole", Vector3(0.88, 0.83, 0.24), Vector3(0.043, 1.20, 0.043))
	fit(dark, banner, "BannerArm", Vector3(0.68, 1.37, 0.24), Vector3(0.46, 0.04, 0.045))
	box(banner, "HerbBannerCloth", Vector3(0.31, 0.48, 0.025), Vector3(0.68, 1.10, 0.24), material(Color("506f5b")))
	text_sign(banner, "药", Vector3(0.68, 1.11, 0.26), 0.0033, Color("e2d1a4"))
	fit(dark, hall, "ClinicSignBoard", Vector3(0, 1.16, -0.13), Vector3(0.65, 0.19, 0.035))
	text_sign(hall, "医 馆", Vector3(0, 1.16, -0.105), 0.0019, Color("d8c49a"))
	anchor(root, "DoctorAnchor", Vector3(0.22, 0.23, 0.05))
	anchor(root, "Door", Vector3(0, 0, 1.08))
	source.free()
	return root

static func collect_parts(source: Node3D) -> Dictionary:
	var parts := {}
	for child in source.find_children("*", "MeshInstance3D", true, false):
		parts[str(child.name)] = child
	return parts

static func copy_roof(parts: Dictionary, parent: Node3D, mapping: Transform3D, vents := false) -> void:
	for key in parts:
		if key.begins_with("RoofTile") or key.begins_with("RoofRidge") or key.begins_with("RidgeEnd") or (vents and key.begins_with("RoofIdentity_Warehouse")):
			var copy := (parts[key] as MeshInstance3D).duplicate() as MeshInstance3D
			copy.transform = mapping * parts[key].transform
			parent.add_child(copy)

static func fit(source: MeshInstance3D, parent: Node3D, label: String, center: Vector3, size: Vector3) -> MeshInstance3D:
	var copy := source.duplicate() as MeshInstance3D
	copy.name = label
	var bounds := source.get_aabb()
	var basis := Basis.from_scale(size / bounds.size)
	copy.transform = Transform3D(basis, center - basis * bounds.get_center())
	parent.add_child(copy)
	return copy

static func branch(parent: Node3D, label: String) -> Node3D:
	var result := Node3D.new()
	result.name = label
	parent.add_child(result)
	return result

static func anchor(parent: Node3D, label: String, pos: Vector3) -> Marker3D:
	var result := Marker3D.new()
	result.name = label
	result.position = pos
	parent.add_child(result)
	return result

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.88
	return result

static func piece(parent: Node3D, label: String, mesh: PrimitiveMesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	mesh.material = mat
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = mesh
	result.position = pos
	parent.add_child(result)
	return result

static func box(parent: Node3D, label: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return piece(parent, label, mesh, pos, mat)

static func cylinder(parent: Node3D, label: String, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return piece(parent, label, mesh, pos, mat)

static func sphere(parent: Node3D, label: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var result := piece(parent, label, mesh, pos, mat)
	result.scale = size
	return result

static func jar(parent: Node3D, label: String, base: Vector3, radius: float, mat: Material) -> void:
	sphere(parent, label, Vector3(radius * 2, radius * 2.3, radius * 2), base + Vector3(0, radius, 0), mat)
	cylinder(parent, label + "Lid", radius * 0.65, radius * 0.24, base + Vector3(0, radius * 2.1, 0), material(Color("574b3f")))

static func gourd(parent: Node3D, pos: Vector3, size: float) -> void:
	var mat := material(Color("a38a53"))
	sphere(parent, "MedicineGourdLower", Vector3(size, size * 0.94, size), pos + Vector3(0, size * 0.45, 0), mat)
	sphere(parent, "MedicineGourdUpper", Vector3(size * 0.65, size * 0.65, size * 0.65), pos + Vector3(0, size * 1.10, 0), mat)
	cylinder(parent, "MedicineGourdStopper", size * 0.12, size * 0.22, pos + Vector3(0, size * 1.46, 0), material(Color("66523a")))

static func text_sign(parent: Node3D, text: String, pos: Vector3, pixel_size: float, color: Color) -> void:
	var label := Label3D.new()
	label.name = "SignLettering"
	label.text = text
	label.font_size = 64
	label.pixel_size = pixel_size
	label.position = pos
	label.modulate = color
	label.outline_size = 0
	parent.add_child(label)

static func gable(parent: Node3D, label: String, x: float, back: float, front: float, eave: float, ridge: float, mat: Material) -> void:
	var vertices := PackedVector3Array([
		Vector3(x, eave, back), Vector3(x, ridge, (back + front) * 0.5), Vector3(x, eave, front),
		Vector3(x, eave, front), Vector3(x, ridge, (back + front) * 0.5), Vector3(x, eave, back)
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2(0.5, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0.5, 1), Vector2.ZERO])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = mesh
	parent.add_child(result)
