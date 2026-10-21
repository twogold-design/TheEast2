extends RefCounted

## The original three species retain their authored branches and texture palette.
## Canopies are rebuilt with rounded lobes and small solid leaves, then cached:
## every tree uses the same three draw resources for its species.
static var _species: Dictionary = {}
static var _lobe_mesh: ArrayMesh
static var _leaf_mesh: ArrayMesh

static func enhance(source: Node3D, variant: int) -> Node3D:
	if source == null or str(source.get_meta("asset_source", "")) != "realistic":
		return source
	if not _species.has(variant):
		_species[variant] = _build_species(source, variant)
	var kit: Dictionary = _species[variant]
	for child in source.get_children():
		source.remove_child(child)
		child.free()
	for index in range(kit.wood.size()):
		var branch_mesh := MeshInstance3D.new()
		branch_mesh.name = "TexturedTrunkBranches_%d" % index
		branch_mesh.mesh = kit.wood[index]
		source.add_child(branch_mesh)
	for key in ["CanopyLobes", "OuterLeaves"]:
		var foliage := MultiMeshInstance3D.new()
		foliage.name = key
		foliage.multimesh = kit[key]
		foliage.material_override = kit.material
		source.add_child(foliage)
	source.set_meta("foliage_detail", "rounded_lobes_solid_leaves")
	source.set_meta("tree_species", ["broadleaf", "weeping_willow", "mountain_pine"][variant])
	source.set_meta("foliage_lobes", kit.CanopyLobes.instance_count)
	source.set_meta("solid_leaf_count", kit.OuterLeaves.instance_count)
	source.set_meta("shared_tree_resources", true)
	return source

static func _build_species(source: Node3D, variant: int) -> Dictionary:
	var meshes: Array[Dictionary] = []
	_collect(source, Transform3D.IDENTITY, meshes)
	var wood_groups: Dictionary = {}
	var clusters: Array[Dictionary] = []
	var original_leaf: StandardMaterial3D
	for entry in meshes:
		var instance: MeshInstance3D = entry.node
		var leafy := _is_foliage(str(instance.name))
		if leafy:
			var bounds: AABB = entry.transform * instance.mesh.get_aabb()
			clusters.append({"center": bounds.get_center(), "size": bounds.size * 0.5})
			if original_leaf == null:
				original_leaf = instance.get_active_material(0) as StandardMaterial3D
			continue
		for surface in range(instance.mesh.get_surface_count()):
			var material := instance.get_active_material(surface)
			var material_key := material.get_instance_id() if material else 0
			if not wood_groups.has(material_key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tool.set_material(material)
				wood_groups[material_key] = tool
			wood_groups[material_key].append_from(instance.mesh, surface, entry.transform)
	var wood: Array[ArrayMesh] = []
	for tool in wood_groups.values():
		wood.append(tool.commit())
	var leaf_material := original_leaf.duplicate() as StandardMaterial3D if original_leaf else StandardMaterial3D.new()
	leaf_material.vertex_color_use_as_albedo = true
	leaf_material.roughness = 0.9
	leaf_material.cull_mode = BaseMaterial3D.CULL_BACK
	if original_leaf == null:
		leaf_material.albedo_color = Color("49713d")
	if _lobe_mesh == null:
		_lobe_mesh = _create_lobe()
		_leaf_mesh = _create_leaf()
	var rng := RandomNumberGenerator.new()
	rng.seed = 37129 + variant * 197
	var lobe_transforms: Array[Transform3D] = []
	var lobe_colors: Array[Color] = []
	var leaf_transforms: Array[Transform3D] = []
	var leaf_colors: Array[Color] = []
	for cluster in clusters:
		var center: Vector3 = cluster.center
		var radius: Vector3 = cluster.size
		# Several irregular, overlapping lobes break the old polyhedron outline.
		# Willow curtains stay long; pine foliage remains horizontal and layered.
		var lobes: int = [6, 4, 3][variant]
		for index in range(lobes):
			var direction := _direction(rng)
			var offset := direction * radius * (0.34 if index > 0 else 0.0)
			var size := radius * (rng.randf_range(0.48, 0.70) if index > 0 else 0.74)
			lobe_transforms.append(Transform3D(Basis.IDENTITY.scaled(size), center + offset))
			var brightness := rng.randf_range(0.80, 1.13)
			lobe_colors.append(Color(brightness, brightness, brightness * 0.97, 1))
		var leaves: int = [74, 32, 18][variant]
		for index in range(leaves):
			var direction := _direction(rng)
			var point := center + direction * radius * rng.randf_range(0.66, 0.96)
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-PI, PI), rng.randf_range(-0.8, 0.8)))
			var length := rng.randf_range(0.085, 0.15)
			var shape := Vector3(length * 0.47, length * 0.22, length)
			if variant == 1:
				shape = Vector3(length * 0.29, length * 1.20, length * 0.16)
			elif variant == 2:
				shape = Vector3(length * 0.27, length * 0.20, length * 0.90)
			leaf_transforms.append(Transform3D(basis.scaled_local(shape), point))
			var brightness := rng.randf_range(0.83, 1.26)
			leaf_colors.append(Color(brightness, brightness, brightness * 0.94, 1))
	return {"wood": wood, "material": leaf_material,
		"CanopyLobes": _multimesh(_lobe_mesh, lobe_transforms, lobe_colors),
		"OuterLeaves": _multimesh(_leaf_mesh, leaf_transforms, leaf_colors)}

static func _collect(node: Node, inherited: Transform3D, output: Array[Dictionary]) -> void:
	for child in node.get_children():
		var transform := inherited
		if child is Node3D:
			transform = inherited * child.transform
		if child is MeshInstance3D and child.mesh:
			output.append({"node": child, "transform": transform})
		_collect(child, transform, output)

static func _is_foliage(node_name: String) -> bool:
	return node_name.begins_with("LeafCluster") or node_name.begins_with("WillowLeaf") or node_name.begins_with("WillowCanopy") or node_name.begins_with("PineNeedles") or node_name.begins_with("PineCrown")

static func _direction(rng: RandomNumberGenerator) -> Vector3:
	var y := rng.randf_range(-1.0, 1.0)
	var angle := rng.randf_range(-PI, PI)
	var radius := sqrt(1.0 - y * y)
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)

static func _multimesh(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color]) -> MultiMesh:
	var result := MultiMesh.new()
	result.transform_format = MultiMesh.TRANSFORM_3D
	result.use_colors = true
	result.mesh = mesh
	result.instance_count = transforms.size()
	for index in range(transforms.size()):
		result.set_instance_transform(index, transforms[index])
		result.set_instance_color(index, colors[index])
	return result

static func _create_lobe() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	var sides := 14
	for ring in range(rings):
		for side in range(sides):
			for corner in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var u := float(side + corner.x) / sides
				var v := float(ring + corner.y) / rings
				var azimuth := u * TAU
				var polar := v * PI
				var normal := Vector3(sin(polar) * cos(azimuth), cos(polar), sin(polar) * sin(azimuth))
				var uneven := 1.0 + 0.075 * sin(azimuth * 5.0 + polar * 3.0) * sin(polar * 4.0)
				tool.set_normal(normal)
				tool.set_uv(Vector2(u, v))
				tool.add_vertex(normal * uneven)
	tool.index()
	return tool.commit()

static func _create_leaf() -> ArrayMesh:
	# A closed, curved almond-shaped volume: never a camera-facing plane.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := [Vector3(0, 0, -1), Vector3(0.86, 0, -0.28), Vector3(0.66, 0, 0.45), Vector3(0, 0, 1), Vector3(-0.66, 0, 0.45), Vector3(-0.86, 0, -0.28)]
	for side in [-1.0, 1.0]:
		var middle := Vector3(0, 0.55 * side, 0)
		for index in range(rim.size()):
			var first: Vector3 = rim[index]
			var second: Vector3 = rim[(index + 1) % rim.size()]
			var points := [middle, first, second] if side > 0 else [middle, second, first]
			for point in points:
				tool.set_normal(Vector3(point.x * 0.35, side, point.z * 0.25).normalized())
				tool.set_uv(Vector2(point.x, point.z) * 0.5 + Vector2.ONE * 0.5)
				tool.add_vertex(point)
	tool.index()
	return tool.commit()
