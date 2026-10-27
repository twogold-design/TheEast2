extends RefCounted

## Expand the field by adding rows, keeping the original plant geometry intact.
static func create_farm(source: Node3D, cells := Vector2i(2, 2)) -> Node3D:
	var farm := Node3D.new()
	farm.name = "ExpandedFarm"
	farm.set_meta("building_type", "farm")
	farm.set_meta("asset_key", "building.farm")
	farm.set_meta("asset_source", "composed_farm")
	var field_depth := 4.18 if cells.y == 2 else 2.12
	farm.set_meta("art_bounds", Vector3(4.28, 1.70, field_depth))
	farm.set_meta("footprint_cells", cells)
	farm.set_meta("roof_identity", "roofless_field_scarecrow")
	farm.set_meta("roof_marker", "RoofIdentity_FieldScarecrow")
	copy_parts(source, farm, Transform3D.IDENTITY, cells)
	var door := Marker3D.new()
	door.name = "Door"
	door.position = Vector3(0, 0, 2.11 if cells.y == 2 else 1.08)
	farm.add_child(door)
	source.free()
	return farm

static func copy_parts(node: Node3D, farm: Node3D, parent_transform: Transform3D, cells: Vector2i) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		var relative: Transform3D = parent_transform * child.transform
		if child is MeshInstance3D and child.mesh != null:
			var label := str(child.name)
			if label == "FarmPlot":
				var plot := child.duplicate() as MeshInstance3D
				var bounds: AABB = child.mesh.get_aabb()
				var basis := Basis.from_scale(Vector3(4.26, 0.10, 4.00 if cells.y == 2 else 1.94) / bounds.size)
				plot.transform = Transform3D(basis, Vector3(0, 0.05, 0) - basis * bounds.get_center())
				farm.add_child(plot)
			else:
				var scarecrow := "Scarecrow" in label
				for section in range(1 if scarecrow else cells.x * cells.y):
					var part := child.duplicate() as MeshInstance3D
					part.name = label if scarecrow or section == 0 else label + "_Plot%d" % section
					part.transform = relative
					part.position.x += 1.03 if scarecrow or section % 2 == 1 else -1.03
					if cells.y == 2:
						part.position.z += 1.03 if scarecrow or section >= 2 else -1.03
					farm.add_child(part)
		else:
			copy_parts(child, farm, relative, cells)
