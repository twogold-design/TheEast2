extends RefCounted

## The existing authored walk rig also carries the new skirt, collar and hair.
## Original GLB meshes/materials remain shared and untouched.
static func dress(citizen: Node3D, variant: int) -> void:
	var white := variant == 6
	var fabric := cloth(Color("e6e1d5") if white else Color("a998b8"))
	var trim := cloth(Color("9e91ae") if white else Color("e5ddcf"))
	var skirt_material := cloth(Color("d1cbc0") if white else Color("857394"))
	for part in citizen.find_children("*", "MeshInstance3D", true, false):
		var label := str(part.name)
		if label in ["Torso", "UpperArm_L", "UpperArm_R", "Forearm_L", "Forearm_R"]:
			part.material_override = fabric
		elif label == "Sash":
			part.material_override = trim
		elif label == "RobeLower":
			part.visible = false
	var layer := attach_body(citizen)
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.225
	skirt.bottom_radius = 0.33
	skirt.height = 0.66
	skirt.radial_segments = 40
	skirt.rings = 4
	mesh_part(layer, "FemaleSkirt", skirt, Vector3(0, 0.57, 0), skirt_material)
	# A crossed collar distinguishes the jacket without intersecting the skirt.
	for side in [-1.0, 1.0]:
		var collar := BoxMesh.new()
		collar.size = Vector3(0.055, 0.30, 0.025)
		var lapel := mesh_part(layer, "FemaleCollar", collar, Vector3(side * 0.065, 1.12, 0.19), trim)
		lapel.rotation.z = -side * 0.40
	var hair := cloth(Color("302d2a"))
	var bun := SphereMesh.new()
	bun.radius = 0.12
	bun.height = 0.22
	bun.radial_segments = 24
	bun.rings = 12
	mesh_part(layer, "HairBun", bun, Vector3(0, 1.715, -0.015), hair)
	var swept := SphereMesh.new()
	swept.radius = 0.16
	swept.height = 0.28
	swept.radial_segments = 24
	swept.rings = 12
	var back := mesh_part(layer, "SweptBackHair", swept, Vector3(0, 1.52, -0.115), hair)
	back.scale = Vector3(0.9, 1.0, 0.63)
	var pin := CylinderMesh.new()
	pin.top_radius = 0.012
	pin.bottom_radius = 0.012
	pin.height = 0.29
	pin.radial_segments = 10
	var hairpin := mesh_part(layer, "SimpleHairpin", pin, Vector3(0, 1.71, 0.015), trim)
	hairpin.rotation.z = PI * 0.5
	citizen.set_meta("outfit_style", "female_white" if white else "female_lavender")
	citizen.set_meta("outfit_rigged", layer.get_parent() is BoneAttachment3D)

static func attach_body(citizen: Node3D) -> Node3D:
	var layer := Node3D.new()
	layer.name = "FemaleOutfit"
	var skeletons := citizen.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		var skeleton := skeletons[0] as Skeleton3D
		var bone := skeleton.find_bone("Root")
		if bone >= 0:
			var attachment := BoneAttachment3D.new()
			attachment.name = "FemaleOutfitRig"
			attachment.bone_name = "Root"
			skeleton.add_child(attachment)
			attachment.add_child(layer)
			layer.transform = skeleton.get_bone_global_rest(bone).affine_inverse()
			return layer
	citizen.add_child(layer)
	return layer

static func cloth(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	return material

static func mesh_part(parent: Node3D, label: String, mesh: PrimitiveMesh, position: Vector3, material: Material) -> MeshInstance3D:
	mesh.material = material
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.position = position
	parent.add_child(part, true)
	return part
