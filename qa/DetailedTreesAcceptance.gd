extends SceneTree

const Kit = preload("res://godot/RealisticAssets.gd")
var failures: Array[String] = []

func _initialize() -> void:
	for variant in range(3):
		var original := Kit.create_asset("prop.tree.%02d" % (variant + 1), false, false)
		var first := Kit.create_tree(variant, false)
		var second := Kit.create_tree(variant, false)
		check(first != null and second != null, "species creates without fallback")
		check(first.get_meta("foliage_detail", "") == "rounded_lobes_solid_leaves", "new trees use detailed foliage")
		check(not original.has_meta("foliage_detail"), "original GLB remains unchanged")
		check(first.get_child_count() <= 6, "tree geometry is batched")
		var crown := first.get_node("CanopyLobes") as MultiMeshInstance3D
		var leaves := first.get_node("OuterLeaves") as MultiMeshInstance3D
		check(crown.multimesh == second.get_node("CanopyLobes").multimesh, "canopy data is shared across instances")
		check(leaves.multimesh == second.get_node("OuterLeaves").multimesh, "leaf data is shared across instances")
		check(crown.material_override != null and leaves.material_override != null, "foliage has material")
		check(leaves.multimesh.instance_count >= 500, "individual leaf volume detail is present")
		var leaf_bounds := leaves.multimesh.mesh.get_aabb()
		check(leaf_bounds.size.x > 0 and leaf_bounds.size.y > 0.5 and leaf_bounds.size.z > 0, "leaves are solid mesh volumes")
		var original_bounds := bounds_of(original)
		var detailed_bounds := bounds_of(first)
		print("TREE_BOUNDS ", variant, " original=", original_bounds.size, " detailed=", detailed_bounds.size)
		check(detailed_bounds.size.y > original_bounds.size.y * 0.84 and detailed_bounds.size.y < original_bounds.size.y * 1.15, "height stays consistent with original tree")
		check(detailed_bounds.size.x < original_bounds.size.x * 1.2 and detailed_bounds.size.z < original_bounds.size.z * 1.2, "canopy does not grow beyond original footprint")
		original.free()
		first.free()
		second.free()
	if failures.is_empty():
		print("DETAILED_TREES_ACCEPTANCE_OK: three species, original preservation, solid leaves, shared resources, dimensions")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func bounds_of(root_node: Node3D) -> AABB:
	var result := AABB()
	for node in root_node.find_children("*", "GeometryInstance3D", true, false):
		var local := Transform3D.IDENTITY
		var cursor: Node3D = node
		while cursor != root_node:
			local = cursor.transform * local
			cursor = cursor.get_parent()
		if node is MultiMeshInstance3D:
			var multi: MultiMesh = node.multimesh
			for index in range(multi.instance_count):
				result = result.merge(local * multi.get_instance_transform(index) * multi.mesh.get_aabb())
		else:
			result = result.merge(local * node.get_aabb())
	return result
