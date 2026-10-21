extends Node

## Small, deterministic market gestures on the imported resident skeleton.
## Vendors stay planted at their counters; customers stroll in separate clear
## aisle circuits and stop to browse. Workshop craft poses remain independent.
const CustomerWalking = preload("res://godot/MarketCustomerWalking.gd")
var elapsed := 0.0
var role := "vendor"
var slot := 0
var preview := false
var skeleton: Skeleton3D
var activity := "idle"
var actor: Node3D
var bones := {}
var rest_globals := {}
var accessories: Array[Dictionary] = []
var workshop_hammer: Node3D
var customer_route: RefCounted
var customer_walking := false
var customer_walk_distance := 0.0

func _ready() -> void:
	# Godot enables _process when a newly assembled actor first enters the tree.
	# Reassert the preview policy after that automatic registration.
	set_process(not preview and skeleton != null)

static func attach(character: Node3D, character_role: String, character_slot: int, is_preview: bool) -> Node:
	var controller := new()
	controller.name = "MarketActivity"
	controller.actor = character
	controller.role = character_role
	controller.slot = character_slot
	controller.preview = is_preview
	controller.process_mode = Node.PROCESS_MODE_ALWAYS
	character.add_child(controller)
	controller.configure()
	return controller

func configure() -> void:
	skeleton = find_skeleton(actor)
	stop_authored_animation(actor)
	if skeleton == null:
		set_process(false)
		return
	skeleton.reset_bone_poses()
	for bone_name in ["Root", "UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R", "Leg.L", "Leg.R"]:
		var id := skeleton.find_bone(bone_name)
		if id >= 0:
			bones[bone_name] = id
			rest_globals[bone_name] = skeleton.get_bone_global_rest(id)
	for child in actor.get_children():
		if child is Node3D and str(child.name).begins_with("CitizenVariant_"):
			accessories.append({"node": child, "rest": child.transform})
	if role == "customer":
		customer_route = CustomerWalking.new()
		customer_route.configure(actor, slot)
	set_process(not preview)
	sample(0.0)

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if preview or skeleton == null:
		return
	sample(elapsed + minf(maxf(delta, 0.0), 0.10))

func sample(seconds: float) -> void:
	elapsed = maxf(seconds, 0.0)
	if skeleton == null:
		return
	for id in bones.values():
		var rest := skeleton.get_bone_rest(id)
		skeleton.set_bone_pose_position(id, rest.origin)
		skeleton.set_bone_pose_rotation(id, rest.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(id, rest.basis.get_scale())
	for accessory in accessories:
		accessory.node.transform = accessory.rest
	activity = "idle"
	if preview:
		return
	if role == "customer" and customer_route:
		customer_route.sample(self, elapsed)
		return
	var phase := fposmod(elapsed + slot * 2.37, 15.0 + (slot % 3) * 0.65)
	var turn := 0.0
	if role == "workshop":
		var working := envelope(phase, 0.7, 6.8, 0.65)
		var sorting := envelope(phase, 9.0, 12.8, 0.7)
		if working > 0.0:
			activity = "hammer"
			# Raise the hammer deliberately and deliver a short downward stroke.
			# Neither the root nor legs take part in this craft animation.
			var beat := fposmod(phase - 0.7, 1.35) / 1.35
			var lift := sin(minf(beat / 0.78, 1.0) * PI * 0.5) if beat < 0.78 else 1.0 - smoothstep(0.78, 1.0, beat)
			rotate_bone("UpperArm.L", Vector3.RIGHT, (-0.715 - lift * 0.345) * working)
			rotate_bone("LowerArm.L", Vector3.RIGHT, (-0.15 - lift * 0.65) * working)
			rotate_bone("UpperArm.R", Vector3.RIGHT, -0.37 * working)
			rotate_bone("LowerArm.R", Vector3.RIGHT, -0.27 * working)
		elif sorting > 0.0:
			activity = "arrange"
			rotate_bone("UpperArm.R", Vector3.RIGHT, (-0.46 + sin(phase * 2.5) * 0.11) * sorting)
			rotate_bone("LowerArm.R", Vector3.RIGHT, -0.32 * sorting)
	elif role == "vendor":
		var greeting := envelope(phase, 0.7, 4.0, 0.65)
		var arranging := envelope(phase, 6.4, 10.4, 0.8)
		if greeting > 0.0:
			activity = "greet"
			# Lift the empty left hand, bend the elbow and offer two small waves.
			rotate_bone("UpperArm.L", Vector3.RIGHT, -0.85 * greeting)
			rotate_bone("LowerArm.L", Vector3.RIGHT, -0.85 * greeting)
			rotate_bone("LowerArm.L", Vector3.FORWARD, sin((phase - 0.7) * 5.0) * 0.19 * greeting)
			turn = -0.07 * greeting
		elif arranging > 0.0:
			activity = "arrange"
			var sorting := sin((phase - 6.4) * 3.3)
			rotate_bone("UpperArm.L", Vector3.RIGHT, (-0.57 + sorting * 0.12) * arranging)
			rotate_bone("LowerArm.L", Vector3.RIGHT, -0.40 * arranging)
			# The farmer's original basket stays on the right arm; only lift it a
			# little while the free hand sorts the counter goods.
			rotate_bone("UpperArm.R", Vector3.RIGHT, (-0.18 - sorting * 0.05) * arranging)
			rotate_bone("LowerArm.R", Vector3.RIGHT, -0.12 * arranging)
	else:
		var browsing := envelope(phase, 0.9, 5.5, 0.9)
		var responding := envelope(phase, 7.1, 10.2, 0.65)
		if browsing > 0.0:
			activity = "browse"
			turn = sin((phase - 0.9) * 1.1) * 0.16 * browsing
			rotate_bone("UpperArm.L", Vector3.RIGHT, -0.28 * browsing)
			rotate_bone("LowerArm.L", Vector3.RIGHT, -0.36 * browsing)
		elif responding > 0.0:
			activity = "respond"
			turn = 0.10 * responding
			rotate_bone("UpperArm.L", Vector3.RIGHT, -0.57 * responding)
			rotate_bone("LowerArm.L", Vector3.RIGHT, (-0.64 + sin(phase * 2.8) * 0.12) * responding)
	rotate_bone("Root", Vector3.UP, turn)
	pin_feet_and_follow_accessories()
	update_workshop_hammer()
	actor.set_meta("market_activity", activity)

func attach_workshop_hammer() -> void:
	if skeleton == null or not bones.has("LowerArm.L"):
		return
	# This prop follows the animated hand through the same rest-to-pose skin
	# transform as its mesh. The original occupation prop would float at rest.
	var old_hammer := actor.find_child("CraftsmanHammer", true, false)
	if old_hammer is Node3D:
		old_hammer.hide()
	workshop_hammer = Node3D.new()
	workshop_hammer.name = "WorkingHammer"
	actor.add_child(workshop_hammer)
	var handle := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.018
	cylinder.bottom_radius = 0.022
	cylinder.height = 0.32
	cylinder.radial_segments = 10
	handle.mesh = cylinder
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("69503b")
	wood.roughness = 0.86
	handle.material_override = wood
	workshop_hammer.add_child(handle)
	var head := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.16, 0.085, 0.085)
	head.mesh = shape
	head.position.y = -0.15
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("525b56")
	iron.metallic = 0.6
	iron.roughness = 0.65
	head.material_override = iron
	workshop_hammer.add_child(head)
	update_workshop_hammer()

func update_workshop_hammer() -> void:
	if workshop_hammer == null:
		return
	var id: int = bones["LowerArm.L"]
	var skeleton_to_actor := relative_transform(skeleton, actor)
	var rest: Transform3D = rest_globals["LowerArm.L"]
	var pose := skeleton.get_bone_global_pose(id)
	var delta := skeleton_to_actor * pose * rest.affine_inverse() * skeleton_to_actor.affine_inverse()
	workshop_hammer.transform = delta * Transform3D(Basis.IDENTITY, Vector3(-0.28, 0.70, 0.12))

func rotate_bone(bone_name: String, skeleton_axis: Vector3, radians: float) -> void:
	if not bones.has(bone_name):
		return
	var id: int = bones[bone_name]
	var parent := skeleton.get_bone_parent(id)
	var parent_basis := Basis.IDENTITY if parent < 0 else skeleton.get_bone_global_rest(parent).basis
	var local_axis := (parent_basis.inverse() * skeleton_axis).normalized()
	var rotation := Quaternion(local_axis, radians) * skeleton.get_bone_pose_rotation(id)
	skeleton.set_bone_pose_rotation(id, rotation.normalized())

func pin_feet_and_follow_accessories() -> void:
	if not bones.has("Root"):
		return
	var root_pose := skeleton.get_bone_global_pose(bones.Root)
	for leg_name in ["Leg.L", "Leg.R"]:
		if not bones.has(leg_name):
			continue
		var id: int = bones[leg_name]
		var parent_pose := skeleton.get_bone_global_pose(skeleton.get_bone_parent(id))
		var local: Transform3D = parent_pose.affine_inverse() * rest_globals[leg_name]
		skeleton.set_bone_pose_position(id, local.origin)
		skeleton.set_bone_pose_rotation(id, local.basis.get_rotation_quaternion())
	var skeleton_to_actor := relative_transform(skeleton, actor)
	var root_delta: Transform3D = skeleton_to_actor * root_pose * (rest_globals.Root as Transform3D).affine_inverse() * skeleton_to_actor.affine_inverse()
	for accessory in accessories:
		accessory.node.transform = root_delta * accessory.rest

static func relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = current.transform * result
		current = current.get_parent()
	return result

static func envelope(time: float, start: float, finish: float, fade: float) -> float:
	if time <= start or time >= finish:
		return 0.0
	return smoothstep(0.0, fade, time - start) * smoothstep(0.0, fade, finish - time)

static func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found:
			return found
	return null

static func stop_authored_animation(node: Node) -> void:
	if node is AnimationPlayer:
		node.stop()
		node.autoplay = ""
		node.active = false
	for child in node.get_children():
		stop_authored_animation(child)
