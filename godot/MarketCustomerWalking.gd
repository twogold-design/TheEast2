extends RefCounted

## Deterministic small shopping circuits in the open market's central aisle.
## Each visitor owns a separate north/south loop, so neither can cross stalls
## or another visitor. Feet use world-space stance contacts instead of sliding
## under a moving, otherwise stationary character mesh.
const SPEED := 0.35
const RADIUS := 0.18
const STRAIGHT := 0.60
const WAIT_SECONDS := 1.8
const PERIMETER := STRAIGHT * 2.0 + TAU * RADIUS
const LEG_DISTANCE := PERIMETER * 0.5
const WALK_SECONDS := LEG_DISTANCE / SPEED
const STRIDE := LEG_DISTANCE / 4.0
const START_DISTANCE := STRAIGHT + PI * RADIUS * 0.5

var lane := 0
var ground_y := 0.28
var origin := Transform3D.IDENTITY
var walking := false
var walk_distance := 0.0
var look_time := 0.0

func configure(actor: Node3D, slot: int) -> void:
	lane = posmod(slot, 2)
	ground_y = actor.position.y
	origin = actor.transform

func sample(controller, seconds: float) -> void:
	var time := maxf(seconds, 0.0) + lane * 2.45
	var period := WALK_SECONDS + WAIT_SECONDS
	var segment := floori(time / period)
	var local_time := fposmod(time, period)
	walking = local_time < WALK_SECONDS
	walk_distance = segment * LEG_DISTANCE + minf(local_time, WALK_SECONDS) * SPEED
	look_time = maxf(local_time - WALK_SECONDS, 0.0)
	var pose := route(walk_distance)
	var actor: Node3D = controller.actor
	actor.position = pose.position
	actor.rotation.y = float(pose.yaw)
	controller.customer_walking = walking
	controller.customer_walk_distance = walk_distance
	if walking:
		controller.activity = "walk"
		var swing := sin(walk_distance / STRIDE * TAU)
		controller.rotate_bone("UpperArm.L", Vector3.RIGHT, swing * 0.25)
		controller.rotate_bone("UpperArm.R", Vector3.RIGHT, -swing * 0.25)
		controller.rotate_bone("LowerArm.L", Vector3.RIGHT, -0.10)
		controller.rotate_bone("LowerArm.R", Vector3.RIGHT, -0.10)
	else:
		controller.activity = "browse"
		var greeting := sin(clampf(look_time / WAIT_SECONDS, 0, 1) * PI)
		controller.rotate_bone("UpperArm.L", Vector3.RIGHT, -0.48 * greeting)
		controller.rotate_bone("LowerArm.L", Vector3.RIGHT, -0.58 * greeting)
	pose_leg(controller, "Leg.L", -1.0, 0.0)
	pose_leg(controller, "Leg.R", 1.0, 0.5)
	actor.set_meta("market_activity", controller.activity)

func route(distance: float) -> Dictionary:
	var d := fposmod(distance + START_DISTANCE, PERIMETER)
	var arc := PI * RADIUS
	var center_z := -0.83 if lane == 0 else 0.83
	var point := Vector3(0, ground_y, center_z)
	var tangent := Vector3(0, 0, 1)
	if d < STRAIGHT:
		point += Vector3(RADIUS, 0, -STRAIGHT * 0.5 + d)
	elif d < STRAIGHT + arc:
		var angle := (d - STRAIGHT) / RADIUS
		point += Vector3(cos(angle) * RADIUS, 0, STRAIGHT * 0.5 + sin(angle) * RADIUS)
		tangent = Vector3(-sin(angle), 0, cos(angle))
	elif d < STRAIGHT * 2.0 + arc:
		point += Vector3(-RADIUS, 0, STRAIGHT * 0.5 - (d - STRAIGHT - arc))
		tangent = Vector3(0, 0, -1)
	else:
		var angle := PI + (d - STRAIGHT * 2.0 - arc) / RADIUS
		point += Vector3(cos(angle) * RADIUS, 0, -STRAIGHT * 0.5 + sin(angle) * RADIUS)
		tangent = Vector3(-sin(angle), 0, cos(angle))
	return {"position": point, "yaw": atan2(tangent.x, tangent.z)}

func pose_leg(controller, bone_name: String, side: float, offset: float) -> void:
	if not controller.bones.has(bone_name):
		return
	var cycles := walk_distance / STRIDE + offset
	var phase := fposmod(cycles, 1.0)
	var contact_start := (floorf(cycles) - offset) * STRIDE
	var first := foot_contact(contact_start + STRIDE * 0.25, side)
	var second := foot_contact(contact_start + STRIDE * 1.25, side)
	var target: Vector3 = first.position
	var foot_yaw: float = first.yaw
	if phase > 0.5:
		var swing := (phase - 0.5) * 2.0
		var blend := smoothstep(0.0, 1.0, swing)
		target = (first.position as Vector3).lerp(second.position, blend)
		target.y += sin(swing * PI) * 0.045
		foot_yaw = lerp_angle(first.yaw, second.yaw, blend)
	# The imported rig has one rigid bone per lower leg. Solve its entire pose
	# around the planted shoe contact, keeping sole orientation level. The
	# upper join stays hidden beneath the robe during the short stride.
	var actor: Node3D = controller.actor
	var rig: Skeleton3D = controller.skeleton
	var id: int = controller.bones[bone_name]
	var rest: Transform3D = controller.rest_globals[bone_name]
	var rest_contact := Vector3(side * 0.10, 0.025, 0.045)
	var actor_rotation := Basis(Vector3.UP, actor.rotation.y)
	var facing := Basis(Vector3.UP, foot_yaw)
	var basis := actor_rotation.inverse() * facing * rest.basis
	var target_local := actor.transform.affine_inverse() * target
	var contact_in_bone := rest.affine_inverse() * rest_contact
	var desired := Transform3D(basis, target_local - basis * contact_in_bone)
	var parent_pose := rig.get_bone_global_pose(rig.get_bone_parent(id))
	var local := parent_pose.affine_inverse() * desired
	rig.set_bone_pose_position(id, local.origin)
	rig.set_bone_pose_rotation(id, local.basis.get_rotation_quaternion())

func foot_contact(distance: float, side: float) -> Dictionary:
	var pose := route(distance)
	var yaw: float = pose.yaw
	var position: Vector3 = pose.position
	position += Basis(Vector3.UP, yaw) * Vector3(side * 0.048, 0.012, 0.0216)
	return {"position": position, "yaw": yaw}
