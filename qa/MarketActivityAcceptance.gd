extends SceneTree

const ArtKit = preload("res://godot/RealisticAssets.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("MARKET_ACTIVITY_FAILED: " + message)

func actors(market: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in market.get_children():
		if child.name.begins_with("MarketVendor_") or child.name.begins_with("MarketCustomer_"):
			result.append(child)
	return result

func run() -> void:
	# Instantiate only art assets: this test never loads or writes player saves.
	var market := ArtKit.create_building("market", false, false)
	var preview := ArtKit.create_building("market", true, false)
	root.add_child(market)
	root.add_child(preview)
	await process_frame
	var residents := actors(market)
	check(residents.size() == 6, "four vendors and two customers remain present")
	var initial_times := {}
	for actor in residents:
		var activity := actor.get_node_or_null("MarketActivity")
		check(activity != null, "activity controller exists for " + str(actor.name))
		if activity:
			initial_times[actor.name] = activity.elapsed
	await process_frame
	await process_frame
	var signatures := {}
	for actor in residents:
		var activity := actor.get_node_or_null("MarketActivity")
		if activity == null:
			continue
		check(activity.elapsed > float(initial_times[actor.name]), "animation advances automatically: " + str(actor.name))
		activity.set_process(false)
		var skeleton: Skeleton3D = activity.skeleton
		check(skeleton != null, "real imported skeleton is animated")
		if skeleton == null:
			continue
		var origin := actor.transform
		activity.sample(0.0)
		var leg_ids := [skeleton.find_bone("Leg.L"), skeleton.find_bone("Leg.R")]
		var arm_ids := [skeleton.find_bone("UpperArm.L"), skeleton.find_bone("UpperArm.R"), skeleton.find_bone("LowerArm.L"), skeleton.find_bone("LowerArm.R")]
		var feet: Array[Transform3D] = []
		var arms: Array[Quaternion] = []
		for id in leg_ids:
			feet.append(skeleton.global_transform * skeleton.get_bone_global_pose(id))
		for id in arm_ids:
			arms.append(skeleton.get_bone_pose_rotation(id))
		var amplitude := 0.0
		var customer := str(activity.role) == "customer"
		for frame in range(73):
			activity.sample(frame * 0.25)
			if not customer:
				check(actor.transform.is_equal_approx(origin), "vendor must stay behind counter")
				for index in range(leg_ids.size()):
					var foot := skeleton.global_transform * skeleton.get_bone_global_pose(leg_ids[index])
					check(foot.origin.distance_to(feet[index].origin) < 0.0001, "vendor feet stay planted through upper-body activity")
			for index in range(arm_ids.size()):
				amplitude = maxf(amplitude, arms[index].angle_to(skeleton.get_bone_pose_rotation(arm_ids[index])))
		check(amplitude > 0.20, "visible arm gestures, not just whole-body turning: " + str(actor.name))
		activity.sample(1.7)
		var signature := ""
		for id in arm_ids:
			signature += str(skeleton.get_bone_pose_rotation(id))
		signatures[signature] = true
		for player in actor.find_children("*", "AnimationPlayer", true, false):
			check(not player.is_playing(), "do not play an in-place walking clip at the stall")
	check_customer_routes(market)
	check(signatures.size() >= 4, "characters have staggered gestures")
	for actor in actors(preview):
		var activity := actor.get_node_or_null("MarketActivity")
		if activity == null:
			continue
		check(not activity.is_processing(), "placement preview stays still")
		var skeleton: Skeleton3D = activity.skeleton
		if skeleton == null:
			continue
		var poses: Array[Transform3D] = []
		var original_transform := actor.transform
		for id in range(skeleton.get_bone_count()):
			poses.append(skeleton.get_bone_pose(id))
		activity.sample(3.2)
		check(actor.transform.is_equal_approx(original_transform), "preview visitors do not move")
		for id in range(skeleton.get_bone_count()):
			check(skeleton.get_bone_pose(id).is_equal_approx(poses[id]), "preview ignores animation sampling")
	market.queue_free()
	preview.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("MARKET_ACTIVITY_ACCEPTANCE_OK: planted vendors, walking customers with stance contacts, clear aisle, static preview")
	quit(0 if failures.is_empty() else 1)

func check_customer_routes(market: Node3D) -> void:
	var visitors := [market.get_node("MarketCustomer_0"), market.get_node("MarketCustomer_1")]
	var previous_positions := {}
	var previous_yaws := {}
	var previous_feet := {}
	var previous_distance := {}
	var walking_frames := 0
	var browsing_frames := 0
	var planted_frames := 0
	var swing_frames := 0
	for frame in range(2401):
		var time := frame / 60.0
		for actor in visitors:
			var activity = actor.get_node("MarketActivity")
			activity.sample(time)
			var skeleton: Skeleton3D = activity.skeleton
			var key: String = actor.name
			check(absf(actor.position.x) <= 0.181, "customer stays within central clear aisle")
			check(absf(actor.position.z) < 1.32 and absf(actor.position.z) > 0.34, "customer circuit avoids other customer zone")
			check(is_equal_approx(actor.position.y, 0.28), "customer root remains on paving")
			if previous_positions.has(key):
				var movement: float = actor.position.distance_to(previous_positions[key])
				check(movement <= 0.35 / 60.0 + 0.0001, "no teleport or burst of customer speed")
				check(absf(angle_difference(previous_yaws[key], actor.rotation.y)) < 0.04, "smooth customer turn")
				if activity.customer_walking:
					walking_frames += 1
					var dd := float(activity.customer_walk_distance) - float(previous_distance[key])
					check(dd >= 0 and dd <= 0.35 / 60.0 + 0.0001, "walking distance remains uniform")
				else:
					browsing_frames += 1
			previous_positions[key] = actor.position
			previous_yaws[key] = actor.rotation.y
			previous_distance[key] = activity.customer_walk_distance
			for pair in [["Leg.L", -1.0, 0.0], ["Leg.R", 1.0, 0.5]]:
				var id := skeleton.find_bone(pair[0])
				var rest := skeleton.get_bone_global_rest(id)
				var rest_point := Vector3(pair[1] * 0.10, 0.025, 0.045)
				var shoe := skeleton.global_transform * skeleton.get_bone_global_pose(id) * (rest.affine_inverse() * rest_point)
				var phase := fposmod(float(activity.customer_walk_distance) / activity.customer_route.STRIDE + pair[2], 1.0)
				var foot_key: String = key + pair[0]
				if phase > 0.05 and phase < 0.45 and previous_feet.has(foot_key):
					check(shoe.distance_to(previous_feet[foot_key]) < 0.0001, "stance shoe planted in market space without sliding")
					planted_frames += 1
				if shoe.y > 0.31:
					swing_frames += 1
				previous_feet[foot_key] = shoe
		check(visitors[0].position.distance_to(visitors[1].position) > 0.68, "visitors never collide")
	check(walking_frames > 200 and browsing_frames > 100, "customers alternate walking and browsing")
	check(planted_frames > 200 and swing_frames > 100, "real stance and lifted-foot walk phases")
