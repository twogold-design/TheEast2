extends SceneTree

const MODEL_PATH := "res://godot/assets/realistic/models/character_citizen.glb"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run_acceptance")


func run_acceptance() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		fail("真实居民 GLB 无法加载")
		finish()
		return
	var instance := packed.instantiate()
	get_root().add_child(instance)
	var players := instance.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		fail("真实居民 GLB 导入后没有 AnimationPlayer")
		instance.queue_free()
		await process_frame
		finish()
		return

	var walk_animation: Animation
	var walk_name := ""
	var player_path := ""
	for candidate in players:
		var player := candidate as AnimationPlayer
		for animation_name in player.get_animation_list():
			if "walk" in str(animation_name).to_lower() or "行走" in str(animation_name):
				walk_animation = player.get_animation(animation_name)
				walk_name = str(animation_name)
				player_path = str(instance.get_path_to(player))
				break
		if walk_animation != null:
			break

	if walk_animation == null:
		fail("AnimationPlayer 中没有 Walk/行走动画")
	else:
		if walk_animation.loop_mode == Animation.LOOP_NONE:
			fail("%s 没有设置为循环播放" % walk_name)
		if walk_animation.length < 0.75 or walk_animation.length > 0.90:
			fail("步行动画时长 %.3f 秒，不符合约 0.8 秒的要求" % walk_animation.length)
		var track_paths: Array[String] = []
		for track_index in range(walk_animation.get_track_count()):
			track_paths.append(str(walk_animation.track_get_path(track_index)))
		var joined := "\n".join(track_paths)
		for required in ["Leg.L", "Leg.R", "UpperArm.L", "UpperArm.R", "Root"]:
			if required not in joined:
				fail("步行动画缺少 %s 关键帧轨道" % required)
		print("NPC_WALK_ART_METRICS: player=%s clip=%s length=%.3f tracks=%d loop=%d" % [
			player_path,
			walk_name,
			walk_animation.length,
			walk_animation.get_track_count(),
			walk_animation.loop_mode,
		])

	instance.queue_free()
	await process_frame
	await process_frame
	finish()


func fail(message: String) -> void:
	failures.append(message)
	push_error("NPC_WALK_ART_ACCEPTANCE_FAILED: " + message)


func finish() -> void:
	if failures.is_empty():
		print("NPC_WALK_ART_ACCEPTANCE_OK: rigged in-place Walk animation is imported and loopable")
		quit(0)
	else:
		print("NPC_WALK_ART_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
