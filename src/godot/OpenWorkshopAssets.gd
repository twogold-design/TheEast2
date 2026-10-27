extends RefCounted

## Reassemble the original beveled, textured GLB into a complete small rear
## hall and an uncovered working court. Source meshes/materials stay shared;
## only node transforms change, leaving the original pack and academy intact.
static func rebuild(source: Node3D) -> Node3D:
	var result := Node3D.new()
	result.name = "OpenWorkshop"
	result.set_meta("asset_key", "building.workshop")
	result.set_meta("building_type", "workshop")
	result.set_meta("asset_source", "composed_workshop")
	result.set_meta("open_work_court", true)
	result.set_meta("roof_identity", "tile_gable_chimney")
	result.set_meta("roof_marker", "RoofIdentity_WorkshopChimney")
	result.set_meta("art_bounds", Vector3(2.12, 2.08, 2.12))
	result.set_meta("footprint_cells", Vector2i.ONE)
	result.set_meta("expected_path", "res://godot/assets/realistic/models/building_workshop.glb")
	var hall := Node3D.new()
	hall.name = "OpenRearHall"
	result.add_child(hall)
	var court := Node3D.new()
	court.name = "OpenWorkCourt"
	result.add_child(court)
	var parts := {}
	for mesh in source.find_children("*", "MeshInstance3D", true, false):
		parts[str(mesh.name)] = mesh
	# Keep the full original two-slope roof, tile overlaps, rounded ridge and
	# end caps. Uniformly compress its building envelope into the rear half.
	var roof_mapping := Transform3D(Basis.from_scale(Vector3(0.78, 0.62, 0.40)), Vector3(0, 0.12, -0.57))
	for key in parts:
		if key.begins_with("RoofTile") or key.begins_with("RoofRidge") or key.begins_with("Ridge"):
			copy_transform(parts[key], hall, roof_mapping)
	var foundation := fit(parts.WorkshopFoundation, result, "WorkshopFoundation", Vector3(0, 0.12, 0), Vector3(2.12, 0.24, 2.12))
	foundation.set_meta("footprint_meters", 2.12)
	fit(parts.FireproofFloor, court, "FireproofFloor", Vector3(0, 0.245, 0), Vector3(2.00, 0.05, 1.98))
	# Three separate walls and four posts support a complete open-front hall.
	fit(parts.WorkshopWalls, hall, "RearBrickWall", Vector3(0, 0.72, -0.91), Vector3(1.60, 0.90, 0.10))
	fit(parts.WorkshopWalls, hall, "WestBrickWall", Vector3(-0.75, 0.72, -0.59), Vector3(0.10, 0.90, 0.64))
	fit(parts.WorkshopWalls, hall, "EastBrickWall", Vector3(0.75, 0.72, -0.59), Vector3(0.10, 0.90, 0.64))
	for x in [-0.73, 0.73]:
		for z in [-0.86, -0.28]:
			fit(parts.WorkshopPost, hall, "HallPost", Vector3(x, 0.75, z), Vector3(0.085, 0.98, 0.085))
	fit(parts.WorkshopSign, hall, "WorkshopSign", Vector3(-0.22, 1.15, -0.24), Vector3(0.46, 0.17, 0.045))
	# The forge aligns with the surviving brick flue. Its front firebox is open
	# to the work court instead of hidden inside an opaque building cuboid.
	fit(parts.ForgeBody, hall, "ForgeBody", Vector3(0.48, 0.51, -0.45), Vector3(0.46, 0.48, 0.48))
	fit(parts.Firebox, hall, "Firebox", Vector3(0.48, 0.49, -0.20), Vector3(0.31, 0.22, 0.04))
	fit(parts.ForgeGlow, hall, "ForgeGlow", Vector3(0.48, 0.48, -0.175), Vector3(0.24, 0.15, 0.045))
	fit(parts.RoofIdentity_WorkshopChimney, hall, "RoofIdentity_WorkshopChimney", Vector3(0.48, 1.33, -0.51), Vector3(0.24, 1.38, 0.24))
	fit(parts.ChimneyCap, hall, "ChimneyCap", Vector3(0.48, 2.045, -0.51), Vector3(0.32, 0.06, 0.32))
	var bench_map := Transform3D(Basis.from_scale(Vector3(0.72, 0.52, 0.72)), Vector3(-0.23, 0.177, 0.40))
	for key in parts:
		if key == "WorkBench" or key.begins_with("BenchLeg"):
			copy_transform(parts[key], court, bench_map)
	var anvil_map := Transform3D(Basis.from_scale(Vector3(0.68, 0.50, 0.68)), Vector3(-0.06, 0.14, 0.34))
	for key in ["AnvilBase", "AnvilBody", "AnvilHorn"]:
		copy_transform(parts[key], court, anvil_map)
	# Move the imported rack out of the old solid back wall to the uncovered
	# west side; its hammer/saw silhouettes are visible from the normal camera.
	var rack_map := Transform3D(Basis.from_scale(Vector3(0.8, 0.66, 0.8)), Vector3(-0.29, 0.11, 0.64))
	for key in parts:
		if key == "ToolRack" or key.begins_with("HangingTool") or key.begins_with("ToolHead"):
			copy_transform(parts[key], court, rack_map)
	for x in [-0.87, -0.46]:
		fit(parts.WorkshopPost, court, "ToolRackSupport", Vector3(x, 0.43, -0.02), Vector3(0.055, 0.32, 0.055))
	# Reuse beveled wood and metal source meshes for laid-out materials/tools.
	for i in range(3):
		fit(parts.WorkBench, court, "RawTimber_%d" % i, Vector3(-0.58, 0.575 + i * 0.045, 0.72), Vector3(0.54, 0.035, 0.10))
		fit(parts.AnvilBody, court, "IronStock_%d" % i, Vector3(0.75, 0.295 + i * 0.043, 0.74), Vector3(0.27, 0.035, 0.10))
	fit(parts.AnvilBody, court, "Workpiece", Vector3(0.29, 0.596, 0.64), Vector3(0.16, 0.028, 0.075))
	var door := Marker3D.new()
	door.name = "Door"
	door.position = Vector3(0, 0.0, 1.10)
	result.add_child(door)
	var artisan_anchor := Marker3D.new()
	artisan_anchor.name = "ArtisanAnchor"
	artisan_anchor.position = Vector3(0.43, 0.27, 0.39)
	result.add_child(artisan_anchor)
	source.free()
	return result

static func copy_transform(source: MeshInstance3D, parent: Node3D, mapping: Transform3D) -> MeshInstance3D:
	var copy := source.duplicate() as MeshInstance3D
	copy.transform = mapping * source.transform
	parent.add_child(copy)
	return copy

static func fit(source: MeshInstance3D, parent: Node3D, label: String, center: Vector3, size: Vector3) -> MeshInstance3D:
	var copy := source.duplicate() as MeshInstance3D
	copy.name = label
	var bounds := source.get_aabb()
	var basis := Basis.from_scale(size / bounds.size)
	copy.transform = Transform3D(basis, center - basis * bounds.get_center())
	parent.add_child(copy)
	return copy
