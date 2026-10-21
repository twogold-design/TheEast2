class_name AnimalAssets
extends RefCounted

## Small, readable Jiangnan village animals.
##
## These are intentionally authored as lightweight procedural meshes rather than
## another imported pack: the animals are background life, so their silhouettes
## need to read clearly at the planning camera while staying inexpensive when a
## settlement contains several of them.

const SPECIES := ["chicken", "duck", "goose", "dog"]

const PALETTE := {
	"ivory": Color("e8dfc9"),
	"cream": Color("d9c38b"),
	"white": Color("eee8d8"),
	"brown": Color("9d6948"),
	"dark_brown": Color("634334"),
	"slate": Color("657f82"),
	"ink": Color("3f4440"),
	"beak": Color("d39a48"),
	"comb": Color("b74e46"),
	"collar": Color("b94f43"),
	"grass": Color("718760"),
}

static func create_animal(species: String, index := 0) -> Node3D:
	var normalized := species.to_lower().strip_edges()
	if normalized not in SPECIES:
		normalized = SPECIES[posmod(index, SPECIES.size())]
	var root := Node3D.new()
	root.name = "Animal_%s_%02d" % [normalized.capitalize(), index]
	root.set_meta("animal_species", normalized)
	root.set_meta("animal_variant", posmod(index, 3))
	root.set_meta("asset_source", "procedural_ink_wash")
	root.set_meta("art_style", "ink_wash")
	match normalized:
		"chicken":
			_build_chicken(root, index)
		"duck":
			_build_duck(root, index)
		"goose":
			_build_goose(root, index)
		"dog":
			_build_dog(root, index)
	_add_face_and_tail(root, normalized)
	_prepare_gait(root, normalized)
	for part in root.get_children():
		if part is Node3D:
			part.set_meta("rest_rotation", part.rotation)
			part.set_meta("rest_position", part.position)
	animate_walk(root, 0.0)
	return root

static func _add_face_and_tail(root: Node3D, species: String) -> void:
	var eye_y := {"chicken": 0.58, "duck": 0.60, "goose": 1.00, "dog": 0.82}
	var eye_x := 0.14 if species != "dog" else 0.16
	var eye_z := 0.10 if species != "dog" else 0.42
	for side in [-1.0, 1.0]:
		_add_sphere(root, "EyeL" if side < 0 else "EyeR", 0.025, Vector3(side * eye_x, eye_y[species], eye_z), PALETTE.ink)
	if species != "dog":
		var tail := _add_sphere(root, "Tail", 0.16, Vector3(0, 0.41 if species == "goose" else 0.34, -0.25), PALETTE.dark_brown if species == "chicken" else PALETTE.ivory, Vector3(0.62, 0.8, 1.4))
		tail.rotation_degrees.x = -25.0

## World-distance-driven gait. Feet travel backwards at exactly the carrier's
## speed during contact, then lift and swing forwards. Converting through the
## actual model scale is essential: gameplay animals use a 0.48 visual scale.
static func animate_walk(root: Node3D, distance: float) -> void:
	var model_scale := root.global_basis.z.length() if root.is_inside_tree() else root.basis.z.length()
	var stride := float(root.get_meta("gait_stride", 0.40))
	var cycle := distance / maxf(model_scale * stride, 0.0001)
	var phase := cycle * TAU
	var body_bob := (1.0 - cos(phase * 2.0)) * 0.009
	for part in root.get_children():
		if not part is Node3D:
			continue
		var rest: Vector3 = part.get_meta("rest_rotation", Vector3.ZERO)
		var rest_position: Vector3 = part.get_meta("rest_position", part.position)
		var part_name := str(part.name)
		if "Leg" in part_name or "Foot" in part_name:
			continue
		part.position = rest_position + Vector3(0, body_bob, 0)
		if part_name in ["Head", "Beak", "FlatBill", "LongBill", "Comb", "EyeL", "EyeR", "Muzzle", "Nose", "EarL", "EarR"]:
			part.position += Vector3(0, sin(phase * 2.0) * 0.009, sin(phase * 2.0) * 0.015)
		if part_name.begins_with("Wing"):
			part.rotation.z = rest.z + sin(phase * 0.5) * 0.07
		elif part_name == "Tail":
			part.rotation.y = rest.y + sin(phase * 0.6) * 0.17
	for limb in root.get_meta("gait_limbs", []):
		_pose_limb(root, limb, cycle, stride, body_bob)

static func _prepare_gait(root: Node3D, species: String) -> void:
	var dog := species == "dog"
	root.set_meta("gait_stride", 0.62 if dog else 0.36)
	var limbs: Array[Dictionary] = []
	var names := ["FrontLegL", "FrontLegR", "BackLegL", "BackLegR"] if dog else ["LegL", "LegR"]
	# Four-beat dog walk, versus alternating bird feet. A 60% contact interval
	# gives a brief double-support phase without freezing either actor's carrier.
	var offsets := [0.0, 0.5, 0.75, 0.25] if dog else [0.0, 0.5]
	for index in range(names.size()):
		var leg := root.get_node(names[index]) as MeshInstance3D
		var cylinder := leg.mesh as CylinderMesh
		var hip := leg.position + Vector3(0, cylinder.height * 0.5, 0)
		var foot_name: String = "Foot" + names[index].replace("Leg", "") if dog else names[index].replace("Leg", "Foot")
		var foot := root.get_node_or_null(foot_name) as MeshInstance3D
		if foot == null:
			foot = _add_box(root, foot_name, Vector3(0.13, 0.045, 0.17), Vector3(hip.x, 0.025, hip.z + 0.035), Color("77503b"))
		var lower_name: String = "Lower" + names[index]
		_add_cylinder(root, lower_name, cylinder.top_radius * 0.80, cylinder.bottom_radius * 0.72, cylinder.height * 0.5, leg.position, (leg.material_override as StandardMaterial3D).albedo_color)
		limbs.append({"upper": names[index], "lower": lower_name, "foot": foot_name, "hip": hip, "rest_foot": foot.position, "offset": offsets[index], "lift": 0.13 if dog else 0.10, "heel": 0.025 if dog else 0.045})
	root.set_meta("gait_limbs", limbs)

static func _pose_limb(root: Node3D, limb: Dictionary, cycle: float, stride: float, bob: float) -> void:
	const CONTACT := 0.60
	var phase := fposmod(cycle + float(limb.offset), 1.0)
	var travel := stride * CONTACT
	var foot_position: Vector3 = limb.rest_foot
	var lift := 0.0
	if phase < CONTACT:
		foot_position.z += travel * 0.5 - stride * phase
	else:
		var swing := (phase - CONTACT) / (1.0 - CONTACT)
		var ease := swing * swing * (3.0 - 2.0 * swing)
		foot_position.z += lerpf(-travel * 0.5, travel * 0.5, ease)
		lift = sin(PI * swing) * sin(PI * swing) * float(limb.lift)
		foot_position.y += lift
	var foot := root.get_node(limb.foot) as Node3D
	foot.position = foot_position
	foot.rotation = Vector3.ZERO
	foot.set_meta("gait_contact", phase < CONTACT)
	foot.set_meta("gait_phase", phase)
	var hip: Vector3 = limb.hip + Vector3(0, bob, 0)
	var ankle := foot_position + Vector3(0, 0.012, -float(limb.heel))
	var knee := hip.lerp(ankle, 0.5) + Vector3(0, 0, -0.035 - lift * 0.45)
	_pose_leg_segment(root.get_node(limb.upper) as MeshInstance3D, hip, knee)
	_pose_leg_segment(root.get_node(limb.lower) as MeshInstance3D, knee, ankle)

static func _pose_leg_segment(segment: MeshInstance3D, top: Vector3, bottom: Vector3) -> void:
	var direction := top - bottom
	segment.position = (top + bottom) * 0.5
	var axis_y := direction.normalized()
	var axis_z := Vector3.RIGHT.cross(axis_y).normalized()
	var length_scale := direction.length() / (segment.mesh as CylinderMesh).height
	segment.basis = Basis(axis_y.cross(axis_z), axis_y * length_scale, axis_z)

static func _build_chicken(root: Node3D, index: int) -> void:
	var body_color: Color = [PALETTE.cream, PALETTE.ivory, Color("c9a875")][posmod(index, 3)]
	_add_sphere(root, "Body", 0.24, Vector3(0, 0.30, 0), body_color, Vector3(1.18, 0.88, 1.0))
	_add_sphere(root, "Head", 0.16, Vector3(0.04, 0.54, 0.02), body_color, Vector3.ONE)
	_add_box(root, "Beak", Vector3(0.14, 0.07, 0.12), Vector3(0.04, 0.52, 0.17), PALETTE.beak)
	_add_sphere(root, "Comb", 0.065, Vector3(0.01, 0.70, -0.01), PALETTE.comb, Vector3(0.90, 1.30, 0.70))
	_add_sphere(root, "WingL", 0.13, Vector3(-0.20, 0.30, 0.02), body_color, Vector3(0.42, 0.92, 1.16))
	_add_sphere(root, "WingR", 0.13, Vector3(0.20, 0.30, 0.02), body_color, Vector3(0.42, 0.92, 1.16))
	_add_cylinder(root, "LegL", 0.025, 0.025, 0.17, Vector3(-0.08, 0.10, 0.02), PALETTE.beak)
	_add_cylinder(root, "LegR", 0.025, 0.025, 0.17, Vector3(0.08, 0.10, 0.02), PALETTE.beak)
	_add_box(root, "FootL", Vector3(0.15, 0.025, 0.08), Vector3(-0.08, 0.015, 0.09), PALETTE.beak)
	_add_box(root, "FootR", Vector3(0.15, 0.025, 0.08), Vector3(0.08, 0.015, 0.09), PALETTE.beak)

static func _build_duck(root: Node3D, index: int) -> void:
	var body_color: Color = [Color("d8c27f"), Color("e2cb8d"), Color("b7c1a0")][posmod(index, 3)]
	_add_sphere(root, "Body", 0.27, Vector3(0, 0.31, 0), body_color, Vector3(1.20, 0.84, 1.04))
	_add_sphere(root, "Head", 0.17, Vector3(0.02, 0.56, 0.02), body_color, Vector3(1.0, 1.05, 0.95))
	_add_box(root, "FlatBill", Vector3(0.22, 0.055, 0.16), Vector3(0.02, 0.53, 0.18), PALETTE.beak)
	_add_sphere(root, "WingL", 0.14, Vector3(-0.22, 0.32, 0.02), PALETTE.slate, Vector3(0.38, 0.90, 1.16))
	_add_sphere(root, "WingR", 0.14, Vector3(0.22, 0.32, 0.02), PALETTE.slate, Vector3(0.38, 0.90, 1.16))
	_add_cylinder(root, "LegL", 0.024, 0.024, 0.14, Vector3(-0.09, 0.11, 0.02), PALETTE.beak)
	_add_cylinder(root, "LegR", 0.024, 0.024, 0.14, Vector3(0.09, 0.11, 0.02), PALETTE.beak)
	_add_box(root, "FootL", Vector3(0.18, 0.025, 0.12), Vector3(-0.09, 0.015, 0.10), PALETTE.beak)
	_add_box(root, "FootR", Vector3(0.18, 0.025, 0.12), Vector3(0.09, 0.015, 0.10), PALETTE.beak)

static func _build_goose(root: Node3D, index: int) -> void:
	var body_color: Color = [PALETTE.white, Color("e1dfce"), PALETTE.ivory][posmod(index, 3)]
	_add_sphere(root, "Body", 0.30, Vector3(0, 0.38, 0), body_color, Vector3(1.18, 1.00, 1.08))
	_add_cylinder(root, "LongNeck", 0.095, 0.11, 0.38, Vector3(0.02, 0.72, 0.01), body_color)
	_add_sphere(root, "Head", 0.15, Vector3(0.02, 0.96, 0.02), body_color, Vector3.ONE)
	_add_box(root, "LongBill", Vector3(0.22, 0.06, 0.12), Vector3(0.02, 0.92, 0.17), PALETTE.beak)
	_add_sphere(root, "WingL", 0.16, Vector3(-0.24, 0.39, 0.00), PALETTE.slate, Vector3(0.38, 0.96, 1.18))
	_add_sphere(root, "WingR", 0.16, Vector3(0.24, 0.39, 0.00), PALETTE.slate, Vector3(0.38, 0.96, 1.18))
	_add_cylinder(root, "LegL", 0.027, 0.027, 0.16, Vector3(-0.10, 0.14, 0.02), PALETTE.beak)
	_add_cylinder(root, "LegR", 0.027, 0.027, 0.16, Vector3(0.10, 0.14, 0.02), PALETTE.beak)
	_add_box(root, "FootL", Vector3(0.20, 0.025, 0.13), Vector3(-0.10, 0.015, 0.10), PALETTE.beak)
	_add_box(root, "FootR", Vector3(0.20, 0.025, 0.13), Vector3(0.10, 0.015, 0.10), PALETTE.beak)

static func _build_dog(root: Node3D, index: int) -> void:
	var body_color: Color = [PALETTE.brown, Color("b7875f"), Color("d3b18c")][posmod(index, 3)]
	_add_sphere(root, "Body", 0.34, Vector3(0, 0.47, 0), body_color, Vector3(1.30, 0.86, 1.02))
	_add_sphere(root, "Chest", 0.21, Vector3(0, 0.56, 0.22), body_color, Vector3(1.0, 1.12, 0.72))
	_add_sphere(root, "Head", 0.23, Vector3(0, 0.78, 0.28), body_color, Vector3(0.94, 0.92, 0.92))
	_add_sphere(root, "Muzzle", 0.13, Vector3(0, 0.72, 0.47), Color("d1b08b"), Vector3(1.0, 0.72, 0.80))
	_add_sphere(root, "Nose", 0.045, Vector3(0, 0.75, 0.57), PALETTE.ink, Vector3.ONE)
	_add_sphere(root, "EarL", 0.12, Vector3(-0.18, 0.91, 0.25), PALETTE.dark_brown, Vector3(0.65, 1.20, 0.80))
	_add_sphere(root, "EarR", 0.12, Vector3(0.18, 0.91, 0.25), PALETTE.dark_brown, Vector3(0.65, 1.20, 0.80))
	_add_cylinder(root, "FrontLegL", 0.055, 0.065, 0.40, Vector3(-0.19, 0.20, 0.18), body_color)
	_add_cylinder(root, "FrontLegR", 0.055, 0.065, 0.40, Vector3(0.19, 0.20, 0.18), body_color)
	_add_cylinder(root, "BackLegL", 0.060, 0.070, 0.36, Vector3(-0.20, 0.18, -0.20), body_color)
	_add_cylinder(root, "BackLegR", 0.060, 0.070, 0.36, Vector3(0.20, 0.18, -0.20), body_color)
	var tail := _add_cylinder(root, "Tail", 0.045, 0.07, 0.38, Vector3(0, 0.62, -0.37), body_color)
	tail.rotation_degrees.x = -42.0
	_add_box(root, "Collar", Vector3(0.30, 0.045, 0.045), Vector3(0, 0.70, 0.32), PALETTE.collar)

static func _add_box(root: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(instance)
	return instance

static func _add_sphere(root: Node3D, node_name: String, radius: float, position: Vector3, color: Color, shape_scale := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	instance.mesh = mesh
	instance.position = position
	instance.scale = shape_scale
	instance.material_override = _material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(instance)
	return instance

static func _add_cylinder(root: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, position: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 10
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(instance)
	return instance

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.90
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return material
