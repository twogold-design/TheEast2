extends Node

## A complete yard-local work cycle. Economy can freeze it in place; neither
## economic time scale nor repeated state refreshes restart its real-time clock.
const Rig = preload("res://godot/MarketCharacterAnimation.gd")
const SPEED := 0.32
const CYCLE_SECONDS := 21.2
const BODY_RADIUS := 0.14
const SAW_POSITION := Vector3(-0.68, 0.25, 0.25)
const DELIVERY_POSITION := Vector3(0.60, 0.25, 0.25)
const PICKUP_POSITION := Vector3(-0.68, 0.455, 0.045)
const DROP_POSITION := Vector3(0.60, 0.455, 0.49)
const STAGES := ["saw", "pickup", "turn_out", "carry", "turn_drop", "putdown", "turn_back", "return", "turn_saw"]
const STAGE_ENDS := [6.0, 8.0, 8.8, 12.8, 13.6, 15.6, 16.4, 20.4, 21.2]

var actor: Node3D
var yard: Node3D
var skeleton: Skeleton3D
var preview := false
var working := true
var elapsed := 0.0
var activity := "saw"
var walking := false
var walking_speed := 0.0
var carrying := false
var bones := {}
var rest_globals := {}
var foot_contacts := {}
var hand_contacts := {}
var saw: Node3D
var timber: Node3D
var saw_rest := Transform3D.IDENTITY
var skeleton_to_actor := Transform3D.IDENTITY

static func attach(character: Node3D, compound: Node3D, is_preview: bool) -> Node:
	var controller := new()
	controller.name = "LumberActivity"
	controller.actor = character
	controller.yard = compound
	controller.preview = is_preview
	controller.process_mode = Node.PROCESS_MODE_ALWAYS
	character.add_child(controller)
	controller.configure()
	return controller

func _ready() -> void:
	set_process(not preview and working and skeleton != null)

func configure() -> void:
	skeleton = Rig.find_skeleton(actor)
	Rig.stop_authored_animation(actor)
	# The original hat stays. A basket attached to the right forearm would pass
	# through the saw and obscure both hands, so only these two parts are hidden.
	for part_name in ["Basket", "BasketHandle"]:
		var part := actor.find_child(part_name, true, false) as Node3D
		if part:
			part.hide()
	saw = yard.get_node_or_null("FrameSaw") as Node3D
	timber = yard.get_node_or_null("LooseTimber") as Node3D
	if saw:
		saw_rest = saw.transform
	if skeleton == null:
		set_process(false)
		return
	skeleton.reset_bone_poses()
	skeleton_to_actor = Rig.relative_transform(skeleton, actor)
	for bone_name in ["Root", "UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R", "Leg.L", "Leg.R"]:
		var id := skeleton.find_bone(bone_name)
		if id >= 0:
			bones[bone_name] = id
			rest_globals[bone_name] = skeleton.get_bone_global_rest(id)
	actor.position = SAW_POSITION
	actor.rotation.y = PI
	actor.set_meta("lumber_working", working)
	if preview:
		activity = "preview"
		_standing_feet(SAW_POSITION, PI)
	else:
		sample(0.0)
	set_process(not preview)

func set_working(enabled: bool) -> void:
	working = enabled
	actor.set_meta("lumber_working", enabled)
	set_process(enabled and not preview and skeleton != null)

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if preview or not working or skeleton == null:
		return
	sample(elapsed + clampf(delta, 0.0, 0.10))

func sample(seconds: float) -> void:
	if preview or not working or skeleton == null:
		return
	elapsed = maxf(seconds, 0.0)
	var phase := fposmod(elapsed, CYCLE_SECONDS)
	var index := 0
	while phase >= float(STAGE_ENDS[index]) and index < STAGES.size() - 1:
		index += 1
	var start := 0.0 if index == 0 else float(STAGE_ENDS[index - 1])
	var duration := float(STAGE_ENDS[index]) - start
	var local_time := phase - start
	var fraction := clampf(local_time / duration, 0.0, 1.0)
	activity = STAGES[index]
	walking = activity in ["carry", "return"]
	walking_speed = SPEED if walking else 0.0
	carrying = activity in ["turn_out", "carry", "turn_drop"]
	_reset_bones()
	if saw:
		saw.transform = saw_rest
	var bend := 0.0
	var lower := 0.0
	var grip_blend := 0.0
	var using_saw := false
	var position := SAW_POSITION
	var yaw := PI
	match activity:
		"saw":
			var weight := smoothstep(0.0, 0.5, local_time) * (1.0 - smoothstep(5.4, 6.0, local_time))
			var stroke := sin(local_time * TAU / 0.85)
			bend = 0.17 * weight
			using_saw = true
			grip_blend = weight
			if saw:
				saw.position.z += stroke * 0.075 * weight
			if timber:
				timber.transform = Transform3D(Basis.IDENTITY, PICKUP_POSITION)
				timber.visible = local_time >= 5.4
		"pickup":
			var reach := smoothstep(0.0, 0.8, local_time)
			var lift := smoothstep(0.8, 2.0, local_time)
			bend = 0.90 * reach * (1.0 - lift)
			lower = 0.14 * reach * (1.0 - lift)
			grip_blend = reach
			carrying = local_time >= 0.8
			if timber:
				timber.visible = true
				timber.transform = Transform3D(Basis(Vector3.UP, yaw), PICKUP_POSITION.lerp(_carry_center(position, yaw), lift))
		"turn_out":
			yaw = lerpf(PI, PI * 0.5, fraction)
			grip_blend = 1.0
		"carry":
			position = SAW_POSITION.lerp(DELIVERY_POSITION, fraction)
			yaw = PI * 0.5
			grip_blend = 1.0
		"turn_drop":
			position = DELIVERY_POSITION
			yaw = lerpf(PI * 0.5, 0.0, fraction)
			grip_blend = 1.0
		"putdown":
			position = DELIVERY_POSITION
			yaw = 0.0
			var lower_weight := smoothstep(0.0, 1.0, local_time)
			var release := smoothstep(1.0, 2.0, local_time)
			bend = 0.90 * lower_weight * (1.0 - release)
			lower = 0.14 * lower_weight * (1.0 - release)
			grip_blend = 1.0 - release
			carrying = local_time < 1.0
			if timber:
				timber.visible = true
				timber.transform = Transform3D(Basis.IDENTITY, _carry_center(position, yaw).lerp(DROP_POSITION, lower_weight))
		"turn_back":
			position = DELIVERY_POSITION
			yaw = lerpf(0.0, -PI * 0.5, fraction)
		"return":
			position = DELIVERY_POSITION.lerp(SAW_POSITION, fraction)
			yaw = -PI * 0.5
		"turn_saw":
			yaw = lerpf(-PI * 0.5, -PI, fraction)
	actor.position = position
	actor.rotation.y = yaw
	if activity in ["turn_out", "carry", "turn_drop"] and timber:
		timber.visible = true
		timber.transform = Transform3D(Basis(Vector3.UP, yaw), _carry_center(position, yaw))
	elif activity in ["turn_back", "return", "turn_saw"] and timber:
		timber.transform = Transform3D(Basis.IDENTITY, DROP_POSITION)
		timber.visible = true
	_bend_body(bend, lower)
	match activity:
		"carry": _moving_feet(SAW_POSITION, DELIVERY_POSITION, PI * 0.5, PI * 0.5, local_time, duration, 8)
		"return": _moving_feet(DELIVERY_POSITION, SAW_POSITION, -PI * 0.5, -PI * 0.5, local_time, duration, 8)
		"turn_out": _moving_feet(position, position, PI, PI * 0.5, local_time, duration, 2)
		"turn_drop": _moving_feet(position, position, PI * 0.5, 0.0, local_time, duration, 2)
		"turn_back": _moving_feet(position, position, 0.0, -PI * 0.5, local_time, duration, 2)
		"turn_saw": _moving_feet(position, position, -PI * 0.5, -PI, local_time, duration, 2)
		_: _standing_feet(position, yaw)
	for side in [-1.0, 1.0]:
		var rest_hand := Vector3(side * 0.28, 0.70, 0.12)
		var target := actor.transform * rest_hand
		if using_saw and saw:
			var grip := saw.transform * Vector3(side * -0.045, 0.035, 0.30)
			target = target.lerp(grip, grip_blend)
		elif grip_blend > 0.0 and timber:
			var grip := timber.transform * Vector3(side * 0.12, 0.025, 0.0)
			target = target.lerp(grip, grip_blend)
		elif walking:
			var swing: float = sin(local_time * TAU) * float(side) * 0.045
			target += Basis(Vector3.UP, yaw) * Vector3(0, 0.01, swing)
		_solve_arm("L" if side < 0 else "R", target, side)
	actor.set_meta("lumber_activity", activity)
	actor.set_meta("lumber_carrying", carrying)
	actor.set_meta("lumber_cycle_time", phase)

func _carry_center(position: Vector3, yaw: float) -> Vector3:
	return position + Basis(Vector3.UP, yaw) * Vector3(0, 0.40, 0.18)

func _reset_bones() -> void:
	for id in bones.values():
		var rest := skeleton.get_bone_rest(id)
		skeleton.set_bone_pose_position(id, rest.origin)
		skeleton.set_bone_pose_rotation(id, rest.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(id, rest.basis.get_scale())

func _set_global_bone(id: int, pose: Transform3D) -> void:
	var parent := skeleton.get_bone_parent(id)
	var local := pose if parent < 0 else skeleton.get_bone_global_pose(parent).affine_inverse() * pose
	skeleton.set_bone_pose_position(id, local.origin)
	skeleton.set_bone_pose_rotation(id, local.basis.get_rotation_quaternion().normalized())
	skeleton.set_bone_pose_scale(id, local.basis.get_scale())

func _bend_body(angle: float, lower: float) -> void:
	if not bones.has("Root"):
		return
	var rest: Transform3D = rest_globals.Root
	var pivot := skeleton_to_actor.affine_inverse() * Vector3(0, 0.80, 0)
	var rotation := Basis(Vector3.RIGHT, angle)
	_set_global_bone(bones.Root, Transform3D(rotation * rest.basis, pivot + rotation * (rest.origin - pivot) - Vector3(0, lower, 0)))

func _standing_feet(position: Vector3, yaw: float) -> void:
	for side in [-1.0, 1.0]:
		_set_foot("Leg.L" if side < 0 else "Leg.R", side, _foot_point(position, yaw, side), yaw, true)

func _foot_point(position: Vector3, yaw: float, side: float) -> Vector3:
	return position + Basis(Vector3.UP, yaw) * (Vector3(side * 0.10, 0.025, 0.045) * actor.scale)

func _moving_feet(first: Vector3, last: Vector3, first_yaw: float, last_yaw: float, time: float, duration: float, steps: int) -> void:
	var step_time := duration / float(steps)
	var step_index := mini(floori(time / step_time), steps - 1)
	var step_fraction := clampf((time - step_index * step_time) / step_time, 0, 1)
	for leg in range(2):
		var side := -1.0 if leg == 0 else 1.0
		var prior_index := step_index - 1
		if posmod(prior_index, 2) != leg:
			prior_index -= 1
		var prior_fraction := _contact_fraction(prior_index, steps)
		var contact_yaw := lerpf(first_yaw, last_yaw, prior_fraction)
		var target := _foot_point(first.lerp(last, prior_fraction), contact_yaw, side)
		var planted := posmod(step_index, 2) != leg
		if not planted:
			var next_fraction := _contact_fraction(step_index, steps)
			var next_yaw := lerpf(first_yaw, last_yaw, next_fraction)
			var next := _foot_point(first.lerp(last, next_fraction), next_yaw, side)
			var blend := smoothstep(0.0, 1.0, step_fraction)
			target = target.lerp(next, blend)
			target.y += sin(step_fraction * PI) * (0.035 if walking else 0.022)
			contact_yaw = lerpf(contact_yaw, next_yaw, blend)
		_set_foot("Leg.L" if leg == 0 else "Leg.R", side, target, contact_yaw, planted)

func _contact_fraction(step: int, steps: int) -> float:
	if step < 0:
		return 0.0
	if step >= steps - 2:
		return 1.0
	return float(step + 1.5) / float(steps)

func _set_foot(bone_name: String, side: float, target: Vector3, yaw: float, planted: bool) -> void:
	if not bones.has(bone_name):
		return
	var id: int = bones[bone_name]
	var rest: Transform3D = rest_globals[bone_name]
	var contact := skeleton_to_actor.affine_inverse() * Vector3(side * 0.10, 0.025, 0.045)
	var contact_in_bone := rest.affine_inverse() * contact
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(actor.scale) * skeleton_to_actor.basis * rest.basis
	var desired := Transform3D(basis, target - basis * contact_in_bone)
	_set_global_bone(id, (actor.transform * skeleton_to_actor).affine_inverse() * desired)
	foot_contacts[bone_name] = {"position": target, "planted": planted}

func _solve_arm(suffix: String, target_in_yard: Vector3, side: float) -> void:
	var upper_name := "UpperArm." + suffix
	var lower_name := "LowerArm." + suffix
	if not bones.has(upper_name) or not bones.has(lower_name):
		return
	var upper_id: int = bones[upper_name]
	var lower_id: int = bones[lower_name]
	var upper_rest: Transform3D = rest_globals[upper_name]
	var lower_rest: Transform3D = rest_globals[lower_name]
	var rest_hand := skeleton_to_actor.affine_inverse() * Vector3(side * 0.28, 0.70, 0.12)
	var shoulder := skeleton.get_bone_global_pose(upper_id).origin
	var target := (actor.transform * skeleton_to_actor).affine_inverse() * target_in_yard
	var upper_length := upper_rest.origin.distance_to(lower_rest.origin)
	var lower_length := lower_rest.origin.distance_to(rest_hand)
	var direction := (target - shoulder).normalized()
	var distance := clampf(shoulder.distance_to(target), absf(upper_length - lower_length) + 0.001, upper_length + lower_length - 0.001)
	target = shoulder + direction * distance
	var along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var pole := Vector3(side, -0.35, -0.15)
	pole = (pole - direction * pole.dot(direction)).normalized()
	var elbow := shoulder + direction * along + pole * height
	var upper_rotation := Basis(Quaternion((lower_rest.origin - upper_rest.origin).normalized(), (elbow - shoulder).normalized()))
	_set_global_bone(upper_id, Transform3D(upper_rotation * upper_rest.basis, shoulder))
	var lower_rotation := Basis(Quaternion((rest_hand - lower_rest.origin).normalized(), (target - elbow).normalized()))
	_set_global_bone(lower_id, Transform3D(lower_rotation * lower_rest.basis, elbow))
	hand_contacts[suffix] = (actor.transform * skeleton_to_actor) * target
