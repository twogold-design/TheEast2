class_name RiverBoat
extends Node3D

## Decorative river traffic. Capsule routes use world metres and wall-clock
## seconds; no economy, population, save or terrain dependencies.
## +Z is the bow. phase is a normalized fraction of one complete circuit.
const Kit = preload("res://godot/RealisticAssets.gd")
const LENGTH := 1.84
const WIDTH := 0.72

var route_center := Vector3.ZERO
var straight_length := 8.0
var turn_radius := 0.65
var speed := 0.32
var phase := 0.0
var elapsed := 0.0
var route_length := 0.0
var visual: Node3D
var rower: Node3D
var rig: Skeleton3D
var arm_bones := {}
var oars: Array[Node3D] = []
var _built := false
var _wood: StandardMaterial3D
var _dark_wood: StandardMaterial3D
var _cloth: StandardMaterial3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	build_visual()
	sample(elapsed)

func configure(center: Vector3, length: float, radius: float, travel_speed: float, start_phase: float) -> void:
	route_center = center
	straight_length = maxf(length, 0.0)
	turn_radius = maxf(radius, 0.05)
	speed = maxf(travel_speed, 0.0)
	phase = fposmod(start_phase, 1.0)
	route_length = 2.0 * straight_length + TAU * turn_radius
	elapsed = 0.0
	build_visual()
	sample(0.0)

func _process(delta: float) -> void:
	sample(elapsed + maxf(delta, 0.0))

func sample(seconds: float) -> void:
	elapsed = maxf(seconds, 0.0)
	if not _built:
		build_visual()
	route_length = 2.0 * straight_length + TAU * turn_radius
	var distance := fposmod(elapsed * speed + phase * route_length, route_length)
	var location := Vector3.ZERO
	var tangent := Vector3.FORWARD
	var arc := PI * turn_radius
	var half := straight_length * 0.5
	if distance < straight_length:
		location = Vector3(turn_radius, 0, -half + distance)
		tangent = Vector3(0, 0, 1)
	elif distance < straight_length + arc:
		var angle := (distance - straight_length) / turn_radius
		location = Vector3(cos(angle) * turn_radius, 0, half + sin(angle) * turn_radius)
		tangent = Vector3(-sin(angle), 0, cos(angle))
	elif distance < 2.0 * straight_length + arc:
		location = Vector3(-turn_radius, 0, half - (distance - straight_length - arc))
		tangent = Vector3(0, 0, -1)
	else:
		var angle := PI + (distance - 2.0 * straight_length - arc) / turn_radius
		location = Vector3(cos(angle) * turn_radius, 0, -half + sin(angle) * turn_radius)
		tangent = Vector3(-sin(angle), 0, cos(angle))
	position = route_center + location
	rotation.y = atan2(tangent.x, tangent.z)
	# Bob only the visual child so QA and route placement retain exact centre
	# speed. Small roll suggests buoyancy without making the hull leave water.
	visual.position.y = sin(elapsed * 1.45 + phase * TAU) * 0.011
	visual.rotation.z = sin(elapsed * 1.1 + phase * TAU) * 0.012
	var rowing := elapsed * 2.1 + phase * TAU
	for index in range(oars.size()):
		var side := -1.0 if index == 0 else 1.0
		oars[index].rotation.y = side * (0.10 + sin(rowing) * 0.32)
		oars[index].rotation.x = cos(rowing) * 0.10
	if rig:
		for bone_name in arm_bones:
			var id: int = arm_bones[bone_name]
			var rest := rig.get_bone_rest(id)
			var parent := rig.get_bone_parent(id)
			var parent_basis := rig.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
			var axis := (parent_basis.inverse() * Vector3.RIGHT).normalized()
			var amount := -0.38 + sin(rowing) * 0.20
			if str(bone_name).begins_with("Lower"):
				amount = -0.48 - sin(rowing) * 0.14
			rig.set_bone_pose_rotation(id, (Quaternion(axis, amount) * rest.basis.get_rotation_quaternion()).normalized())

func build_visual() -> void:
	if _built:
		return
	_built = true
	set_meta("decoration_only", true)
	set_meta("boat_length", LENGTH)
	set_meta("boat_width", WIDTH)
	visual = Node3D.new()
	visual.name = "BoatVisual"
	add_child(visual)
	_wood = material(Color("ccb58f"), "building_warehouse_wood_warm_basecolor.png")
	_dark_wood = material(Color("8a7961"), "building_warehouse_wood_dark_basecolor.png")
	_cloth = material(Color("586763"), "")
	var stations := [-0.92, -0.76, -0.46, 0.0, 0.46, 0.76, 0.92]
	var widths := [0.025, 0.23, 0.33, 0.36, 0.33, 0.23, 0.025]
	var hull := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for index in range(stations.size() - 1):
			var z0: float = stations[index]
			var z1: float = stations[index + 1]
			var w0: float = widths[index]
			var w1: float = widths[index + 1]
			var top0 := Vector3(side * w0, 0.20 + absf(z0) * 0.09, z0)
			var top1 := Vector3(side * w1, 0.20 + absf(z1) * 0.09, z1)
			var low0 := Vector3(side * w0 * 0.47, -0.12 + absf(z0) * 0.14, z0 * 0.96)
			var low1 := Vector3(side * w1 * 0.47, -0.12 + absf(z1) * 0.14, z1 * 0.96)
			quad(hull, top0, top1, low1, low0)
			beam(visual, "CurvedGunwale", top0, top1, 0.019, _dark_wood)
			beam(visual, "HullStrake", top0.lerp(low0, 0.48), top1.lerp(low1, 0.48), 0.007, _dark_wood)
	hull.generate_normals()
	var hull_mesh := MeshInstance3D.new()
	hull_mesh.name = "PointedPlankHull"
	hull_mesh.mesh = hull.commit()
	hull_mesh.material_override = _wood
	visual.add_child(hull_mesh)
	for i in range(11):
		var z := -0.71 + i * 0.142
		var width := 0.54 - pow(absf(z) / 0.88, 2.0) * 0.32
		box(visual, "DeckPlank_%02d" % i, Vector3(width, 0.026, 0.135), Vector3(0, 0.10, z), _wood)
	for z in [-0.65, 0.24, 0.65]:
		box(visual, "CrossSeat", Vector3(0.52 if absf(z) > 0.4 else 0.66, 0.034, 0.10), Vector3(0, 0.19, z), _dark_wood)
	# Two-ended arched canopy: a genuine curved shell with bent ribs. The bow
	# remains open, so the helmsman and cargo read from the planning camera.
	var canopy := SurfaceTool.new()
	canopy.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(12):
		var a0 := i * PI / 12.0
		var a1 := (i + 1) * PI / 12.0
		var p0 := Vector3(cos(a0) * 0.31, 0.24 + sin(a0) * 0.36, -0.69)
		var p1 := Vector3(cos(a1) * 0.31, 0.24 + sin(a1) * 0.36, -0.69)
		quad(canopy, p0, p1, p1 + Vector3(0, 0, 0.54), p0 + Vector3(0, 0, 0.54))
		for z_offset in [0.0, 0.27, 0.54]:
			beam(visual, "CanopyRib", p0 + Vector3(0, 0, z_offset), p1 + Vector3(0, 0, z_offset), 0.009, _dark_wood)
	canopy.generate_normals()
	var hood := MeshInstance3D.new()
	hood.name = "ArchedWupengCanopy"
	hood.mesh = canopy.commit()
	hood.material_override = _cloth
	visual.add_child(hood)
	var cargo := box(visual, "CargoCrate", Vector3(0.22, 0.17, 0.20), Vector3(-0.12, 0.195, -0.02), _wood)
	for x in [-0.075, 0.075]:
		box(cargo, "CrateBinding", Vector3(0.025, 0.18, 0.21), Vector3(x, 0, 0), _dark_wood)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "PortOar" if side < 0 else "StarboardOar"
		pivot.position = Vector3(side * 0.22, 0.26, 0.37)
		visual.add_child(pivot)
		oars.append(pivot)
		beam(pivot, "OarShaft", Vector3(-side * 0.10, 0.015, -0.08), Vector3(side * 0.43, -0.20, 0.12), 0.012, _wood)
		var blade := box(pivot, "OarBlade", Vector3(0.075, 0.024, 0.20), Vector3(side * 0.41, -0.18, 0.115), _dark_wood)
		blade.rotation.y = side * 0.8
	rower = Kit.create_citizen_variant(410, 4, true)
	if rower:
		rower.name = "Boatman"
		rower.position = Vector3(0, 0.12, 0.33)
		rower.scale = Vector3.ONE * 0.30
		visual.add_child(rower)
		var pole := rower.find_child("BoatmanPole", true, false)
		if pole is Node3D:
			pole.hide()
		for player in rower.find_children("*", "AnimationPlayer", true, false):
			player.stop()
			player.autoplay = ""
			player.active = false
		var rigs := rower.find_children("*", "Skeleton3D", true, false)
		if not rigs.is_empty():
			rig = rigs[0]
			rig.reset_bone_poses()
			for bone_name in ["UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R"]:
				var bone := rig.find_bone(bone_name)
				if bone >= 0:
					arm_bones[bone_name] = bone

static func material(color: Color, texture_name: String) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.91
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not texture_name.is_empty():
		result.albedo_texture = load("res://godot/assets/realistic/models/" + texture_name)
	return result

static func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var vertices := [a, b, c, a, c, d]
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in range(6):
		surface.set_uv(uv[i])
		surface.add_vertex(vertices[i])

static func box(parent: Node3D, label: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = mesh
	result.position = pos
	result.material_override = mat
	parent.add_child(result)
	return result

static func beam(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var direction := b - a
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = direction.length()
	mesh.radial_segments = 8
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = mesh
	result.position = (a + b) * 0.5
	result.quaternion = Quaternion(Vector3.UP, direction.normalized())
	result.material_override = mat
	parent.add_child(result)
