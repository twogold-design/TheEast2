extends SceneTree

## Asset-only acceptance. Does not instantiate Main or read/write any save.
const Art = preload("res://godot/RealisticAssets.gd")
const Expanded = preload("res://godot/ExpandedBuildingAssets.gd")
const DT := 1.0 / 60.0
var failures: Array[String] = []
var stages_seen: Dictionary = {}
var moving_frames := 0
var planted_frames := 0
var lifted_frames := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
		push_error("LUMBER_ACTIVITY_FAILED: " + message)

func bone_poses(skeleton: Skeleton3D) -> Array:
	var result: Array = []
	for id in range(skeleton.get_bone_count()):
		result.append(skeleton.get_bone_pose(id))
	return result

func poses_equal(skeleton: Skeleton3D, poses: Array) -> bool:
	for id in range(skeleton.get_bone_count()):
		if not skeleton.get_bone_pose(id).is_equal_approx(poses[id]):
			return false
	return true

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var yards: Array[Node3D] = []
	for quarter in range(4):
		var yard := Art.create_building("lumber", false, false)
		yard.rotation.y = quarter * PI * 0.5
		yard.position = Vector3(quarter * 8.0, 0, -quarter * 2.0)
		stage.add_child(yard)
		yards.append(yard)
	var preview := Art.create_building("lumber", true, false)
	stage.add_child(preview)
	await process_frame
	for yard in yards:
		var actor := yard.get_node_or_null("WorkingResident") as Node3D
		check(actor != null, "imported resident exists")
		if actor == null: continue
		var activity := actor.get_node_or_null("LumberActivity")
		check(activity != null, "dedicated lumber controller exists")
		check(actor.get_node_or_null("MarketActivity") == null, "lumber resident does not run stall gestures")
		if activity == null: continue
		var before_elapsed: float = activity.elapsed
		await process_frame
		check(float(activity.elapsed) > before_elapsed, "work cycle advances automatically")
		activity.set_process(false)
		check(activity.skeleton != null, "real imported skeleton is animated")
		if activity.skeleton == null: continue
		check_cycle(yard, actor, activity)
		check_stop_resume(yard, actor, activity)
		for player in actor.find_children("*", "AnimationPlayer", true, false):
			check(not player.is_playing(), "no competing authored in-place animation")
	check_preview(preview)
	for phase in ["saw", "pickup", "carry", "putdown", "return"]:
		check(stages_seen.has(phase), "complete work cycle includes " + phase)
	check(moving_frames > 400, "cycle includes sustained carrying and return walking")
	check(planted_frames > 200, "walking has actual stance contacts")
	check(lifted_frames > 100, "walking has visible lifted-foot swings")
	stage.queue_free()
	await process_frame
	await process_frame
	await process_frame
	print("LUMBER_ACTIVITY_ACCEPTANCE_OK: saw, pickup, carry, putdown, return; uniform walking, planted feet, four rotations, static preview, stop/resume" if failures.is_empty() else "LUMBER_ACTIVITY_ACCEPTANCE_FAILED: " + str(failures))
	quit(0 if failures.is_empty() else 1)

func check_cycle(yard: Node3D, actor: Node3D, activity: Node) -> void:
	var skeleton: Skeleton3D = activity.skeleton
	var obstacles: Array = yard.get_meta("lumber_obstacles", [])
	check(not obstacles.is_empty(), "yard declares its solid worksite obstacles")
	var radius: float = yard.get_meta("lumber_body_radius", 0.14)
	var previous_position := Vector3.ZERO
	var previous_walking := false
	var previous_phase := ""
	var previous_contacts: Dictionary = {}
	var arm_id := skeleton.find_bone("UpperArm.L")
	check(arm_id >= 0, "sawing uses a real arm bone")
	var first_arm := Quaternion.IDENTITY
	var arm_amplitude := 0.0
	var duration: float = activity.CYCLE_SECONDS
	for frame in range(ceili(duration * 2.0 / DT) + 1):
		activity.sample(frame * DT)
		var phase: String = activity.activity
		stages_seen[phase] = true
		var local_position := yard.to_local(actor.global_position)
		check(absf(local_position.x) + radius < 2.2 and absf(local_position.z) + radius < 2.2, "resident stays inside rotated 2x2 lot")
		for obstacle in obstacles:
			var rect: Rect2 = obstacle
			var point := Vector2(local_position.x, local_position.z)
			var nearest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
			check(point.distance_to(nearest) >= radius - 0.001, "body avoids logs, benches and shelter posts in every rotation")
		if frame > 0:
			var distance := actor.global_position.distance_to(previous_position)
			var speed: float = activity.SPEED
			check(distance <= speed * DT + 0.00015, "work cycle has no position snap or burst of speed")
			if bool(activity.walking) and previous_walking and phase in ["carry", "return"] and previous_phase == phase:
				check(absf(distance - speed * DT) < 0.00015, "continuous carrying and return steps keep uniform speed")
				moving_frames += 1
		if arm_id >= 0:
			if frame == 0: first_arm = skeleton.get_bone_pose_rotation(arm_id)
			arm_amplitude = maxf(arm_amplitude, first_arm.angle_to(skeleton.get_bone_pose_rotation(arm_id)))
		var contacts: Dictionary = activity.foot_contacts
		for side in contacts:
			var contact: Dictionary = contacts[side]
			var foot: Vector3 = contact.position
			var world_foot := yard.to_global(foot)
			var side_sign := -1.0 if str(side) == "Leg.L" else 1.0
			var id := skeleton.find_bone(str(side))
			var rest := skeleton.get_bone_global_rest(id)
			var shoe_actor := Vector3(side_sign * 0.10, 0.025, 0.045)
			var shoe_in_bone: Vector3 = rest.affine_inverse() * activity.skeleton_to_actor.affine_inverse() * shoe_actor
			var rendered_shoe := skeleton.global_transform * skeleton.get_bone_global_pose(id) * shoe_in_bone
			check(rendered_shoe.distance_to(world_foot) < 0.001, "declared foot contacts match the actual imported rig shoe position")
			if bool(activity.walking) and previous_walking and bool(contact.planted) and previous_contacts.has(side) and bool(previous_contacts[side].planted):
				check(world_foot.distance_to(previous_contacts[side].position) < 0.002, "support foot stays planted in world space without sliding")
				planted_frames += 1
			if bool(activity.walking) and not bool(contact.planted) and foot.y > local_position.y + 0.01:
				lifted_frames += 1
			previous_contacts[side] = {"position": world_foot, "planted": bool(contact.planted)}
		previous_position = actor.global_position
		previous_walking = bool(activity.walking)
		previous_phase = phase
	check(arm_amplitude > 0.2, "sawing and handling visibly articulate arms")

func check_stop_resume(yard: Node3D, actor: Node3D, activity: Node) -> void:
	# Find the middle of a real carrying segment, not a rest/turn boundary.
	for frame in range(ceili(float(activity.CYCLE_SECONDS) / DT)):
		activity.sample(frame * DT)
		if str(activity.activity) == "carry" and bool(activity.walking):
			activity.sample(frame * DT + 0.5)
			break
	var position := actor.transform
	var poses := bone_poses(activity.skeleton)
	var stopped_at: float = activity.elapsed
	Expanded.apply_working_visual(yard, false)
	activity.tick(3.0)
	check(actor.transform.is_equal_approx(position), "stopping production does not teleport resident to origin")
	check(poses_equal(activity.skeleton, poses), "stopped resident holds current pose")
	check(is_equal_approx(float(activity.elapsed), stopped_at), "production stop freezes work-cycle time")
	Expanded.apply_working_visual(yard, true)
	activity.tick(DT)
	activity.set_process(false)
	check(float(activity.elapsed) > stopped_at and float(activity.elapsed) <= stopped_at + DT + 0.00001, "resume continues old phase instead of restarting cycle")
	check(actor.position.distance_to(position.origin) <= float(activity.SPEED) * DT + 0.00015, "resumed worker moves continuously from current location")

func check_preview(yard: Node3D) -> void:
	var actor := yard.get_node_or_null("WorkingResident") as Node3D
	var activity := actor.get_node_or_null("LumberActivity") if actor else null
	check(activity != null, "preview retains a dedicated but static controller")
	if activity == null: return
	check(not activity.is_processing(), "placement preview does not auto-animate")
	var position := actor.transform
	var poses := bone_poses(activity.skeleton)
	activity.sample(9.0)
	activity.tick(3.0)
	Expanded.apply_working_visual(yard, true)
	check(actor.transform.is_equal_approx(position) and poses_equal(activity.skeleton, poses), "preview ignores animation and resume requests")
	check(not activity.is_processing(), "working-state refresh cannot animate preview")
