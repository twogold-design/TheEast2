extends SceneTree

## Acceptance for the resident schedule loop.  This keeps the test focused on
## the meaningful behaviour exposed by Main.gd: residents visit home, work,
## food storage and a walking route as the automatic day advances.  Scheduling
## is presentation/state only; it must not mutate the settlement numbers.

const SAVE_PATH := "res://saves/savegame.json"
const EPSILON := 0.001
const MAX_FRAME_DISPLACEMENT := 0.12

var failures: Array[String] = []
var original_save_exists := false
var original_save_text := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	preserve_save_file()
	var packed := load("res://godot/Main.tscn") as PackedScene
	if packed == null:
		fail("主场景无法加载")
		restore_save_file()
		finish()
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.reset_game(false)
	game.time_paused = true
	# Give the schedule real destinations.  Free placement avoids making this
	# behavioural check depend on the current wood balance or placement rules.
	game.add_building("farm", Vector2i(1, 10), true)
	game.add_building("lumber", Vector2i(14, 10), true)
	game.add_building("workshop", Vector2i(25, 25), true)
	game.add_building("warehouse", Vector2i(10, 10), true)
	game.add_building("market", Vector2i(11, 12), true)
	game.add_building("clinic", Vector2i(13, 12), true)
	game.add_building("academy", Vector2i(15, 12), true)
	# Six residents make every presentation role observable in this fixture.
	game.population = 6
	game.update_citizens()
	await process_frame
	if game.citizen_root.get_child_count() != int(game.population):
		fail("居民节点数量没有随人口建立：%d/%d" % [game.citizen_root.get_child_count(), game.population])
	else:
		check_visual_scale(game)
		check_walk_animation(game)
		check_regional_job_performances(game)
		check_bridge_navigation(game)
		check_schedule_phases(game)
		check_pause_and_state_only(game)
		check_constant_display_speed(game)
		check_continuous_route(game)
		check_smooth_movement(game)
		check_real_time_schedule_and_turning(game)
		check_cross_day_continuity(game)
	game.reset_game(false)
	restore_save_file()
	finish()

func check_visual_scale(game) -> void:
	var citizen := game.citizen_root.get_child(0) as Node3D
	var visual := citizen.get_node_or_null("Visual") as Node3D
	if visual == null:
		fail("居民缺少独立 Visual 节点，无法保证模型比例")
		return
	var expected := float(game.NPC_VISUAL_SCALE)
	if expected < 0.45 or expected > 0.60:
		fail("NPC视觉缩放超出与单格房屋协调的范围：%.2f" % expected)
	var age_scale := 0.78 if int(visual.get_meta("npc_variant", -1)) == 5 else 1.0
	if not visual.scale.is_equal_approx(Vector3.ONE * expected * age_scale):
		fail("NPC视觉节点没有应用统一缩放：%s" % visual.scale)
	if absf(float(visual.get_meta("gameplay_visual_scale", -1.0)) - expected) > EPSILON:
		fail("NPC视觉节点缺少可验收的缩放元数据")

func check_walk_animation(game) -> void:
	var citizen := game.citizen_root.get_child(0) as Node3D
	var visual := citizen.get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var authored_walk_found := false
	for raw_player in visual.find_children("*", "AnimationPlayer", true, false):
		var player := raw_player as AnimationPlayer
		if player == null:
			continue
		for animation_name in player.get_animation_list():
			var normalized := str(animation_name).to_lower()
			if "walk" in normalized or "行走" in normalized:
				authored_walk_found = true
	if not authored_walk_found:
		fail("真实居民模型没有导入 Walk/行走 循环动画")
	if authored_walk_found and not bool(visual.get_meta("uses_authored_walk_animation", false)):
		fail("真实走路动画已导入，但NPC程序没有识别")
	game.update_citizen_schedules()
	var carrier_before := citizen.position
	var visual_before := visual.position
	var rotation_before := visual.rotation
	game.move_citizens(0.12)
	var planar_distance := Vector2(citizen.position.x - carrier_before.x, citizen.position.z - carrier_before.z).length()
	if absf(planar_distance - float(game.NPC_MOVE_SPEED) * 0.12) > 0.0002:
		fail("走路动作改变了NPC载体的恒定移速")
	if not bool(citizen.get_meta("walk_animation_active", false)):
		fail("NPC移动时没有启用简单走路动作")
	if bool(visual.get_meta("uses_authored_walk_animation", false)):
		var player_path: NodePath = visual.get_meta("authored_walk_player_path", NodePath())
		var player := visual.get_node_or_null(player_path) as AnimationPlayer
		if player == null or not player.is_playing():
			fail("NPC真实模型包含走路动画，但移动时没有播放")
		var rest_position: Vector3 = visual.get_meta("rest_position", Vector3.ZERO)
		var rest_rotation: Vector3 = visual.get_meta("rest_rotation", Vector3.ZERO)
		if visual.position.distance_to(rest_position) > 0.0001 or visual.rotation.distance_to(rest_rotation) > 0.0001:
			fail("真实走路动画上又叠加了整体模型摆动")
	else:
		if visual.position.distance_to(visual_before) < 0.0001 and visual.rotation.distance_to(rotation_before) < 0.0001:
			fail("NPC移动时视觉模型没有后备步态起伏或摆动")
		if absf(visual.position.y - float(visual.get_meta("rest_position", Vector3.ZERO).y)) > float(game.NPC_WALK_BOB_HEIGHT) + 0.001:
			fail("NPC后备走路起伏过大")

func check_regional_job_performances(game) -> void:
	var expected_activities := {
		"farm": "耕作",
		"lumber": "伐木",
		"workshop": "制作",
		"market": "经商",
		"clinic": "应诊",
		"academy": "授课",
	}
	var expected_commutes := {
		"farm": "前往农田",
		"lumber": "前往林场",
		"workshop": "前往工坊",
		"market": "前往集市",
		"clinic": "前往医馆",
		"academy": "前往书院",
	}
	var roles_seen := {}
	for child in game.citizen_root.get_children():
		var role := str(child.get_meta("schedule_role", ""))
		roles_seen[role] = true
		if expected_activities.has(role) and game.schedule_activity_text("工作", role) != expected_activities[role]:
			fail("居民岗位 %s 缺少对应工作表演文案" % role)
		if expected_commutes.has(role) and game.schedule_activity_text("通勤", role) != expected_commutes[role]:
			fail("居民岗位 %s 缺少对应通勤文案" % role)
	for role in expected_activities:
		if not roles_seen.has(role):
			fail("有对应建筑时未分配居民表演岗位：%s" % role)
	var expected_speed := float(game.NPC_MOVE_SPEED)
	for child in game.citizen_root.get_children():
		if not child is Node3D:
			continue
		var before: Vector3 = child.position
		child.set_meta("schedule_target", before + Vector3(20.0, 0.0, 0.0))
		game.move_citizens(0.05)
		var distance := Vector2(child.position.x - before.x, child.position.z - before.z).length()
		if absf(distance - expected_speed * 0.05) > 0.0002:
			fail("居民表演岗位影响了固定移速：%s" % str(child.get_meta("schedule_role", "")))
	game.update_citizen_schedules()

func check_bridge_navigation(game) -> void:
	var previous_level := int(game.map_region_level)
	game.map_region_level = game.REGION_DEFINITIONS.size() - 1
	var main_bridge := game.world.find_child("RiverBridge", true, false) as Node3D
	var east_bridge := game.world.find_child("EastBranchBridge", true, false) as Node3D
	if main_bridge == null or str(main_bridge.get_meta("npc_bridge_id", "")) != "main_river":
		fail("主河缺少NPC可识别的实际桥梁")
	if east_bridge == null or str(east_bridge.get_meta("npc_bridge_id", "")) != "east_branch":
		fail("东侧支流缺少NPC可识别的实际桥梁")
	check_one_bridge_path(game, Vector2i(0, 7), Vector2i(7, 7), 2, 3, 9, "主河")
	check_one_bridge_path(game, Vector2i(29, 16), Vector2i(36, 16), 32, 33, 12, "东侧支流")
	game.map_region_level = previous_level

func check_one_bridge_path(game, start_cell: Vector2i, goal_cell: Vector2i, water_min_x: int, water_max_x: int, bridge_row: int, label: String) -> void:
	var start: Vector3 = game.grid_to_world(start_cell) + Vector3(0, 0.18, 0)
	var target: Vector3 = game.grid_to_world(goal_cell) + Vector3(0, 0.18, 0)
	var navigation_path: Array = game.citizen_navigation_path(start, target)
	if navigation_path.is_empty():
		fail("%s跨河路线无法生成" % label)
		return
	var points: Array[Vector3] = [start]
	for raw_point in navigation_path:
		points.append(raw_point)
	var visited_bridge_cells := {}
	for index in range(points.size() - 1):
		var from := points[index]
		var to := points[index + 1]
		var samples := maxi(1, ceili(Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z)) / 0.20))
		for sample_index in range(samples + 1):
			var point := from.lerp(to, float(sample_index) / float(samples))
			var cell: Vector2i = game.world_to_grid(point)
			if not game.is_water_cell(cell):
				continue
			if cell.y != bridge_row or cell.x < water_min_x or cell.x > water_max_x:
				fail("%s路线离开桥面并穿过河水：%s" % [label, cell])
				return
			visited_bridge_cells[cell] = true
	for water_x in range(water_min_x, water_max_x + 1):
		if not visited_bridge_cells.has(Vector2i(water_x, bridge_row)):
			fail("%s路线没有完整经过桥面" % label)
			break
	for raw_point in navigation_path:
		var cell: Vector2i = game.world_to_grid(raw_point)
		if cell != goal_cell and game.occupied.has(cell):
			fail("%s路线穿过建筑占用格：%s" % [label, cell])
			break

func check_schedule_phases(game) -> void:
	var citizen: Node = game.citizen_root.get_child(0)
	var day := int(game.day)
	var wood := int(game.wood)
	var food := int(game.food)
	var population := int(game.population)
	var happiness := int(game.happiness)
	var coins := int(game.coins)
	var stable_days := int(game.stable_days)
	var maintenance_debt := int(game.maintenance_debt)
	game.update_citizen_schedules()
	var route: Array = citizen.get_meta("performance_route", [])
	var expected_states := ["居家", "通勤", "工作", "用餐", "散步", "散步", "回家"]
	var targets: Array[Vector3] = []
	if route.size() != expected_states.size():
		fail("NPC连续表演路线节点数量错误：%d" % route.size())
	else:
		for route_index in range(route.size()):
			var step: Dictionary = route[route_index]
			if str(step.state) != expected_states[route_index]:
				fail("NPC连续表演路线第%d段语义错误" % route_index)
			if str(step.activity).is_empty():
				fail("NPC连续表演路线第%d段缺少活动说明" % route_index)
			targets.append(step.position)
		if targets[0].distance_to(targets[1]) < EPSILON:
			fail("居家与通勤表演点重合")
		if targets[1].distance_to(targets[2]) < EPSILON:
			fail("通勤与工作表演点重合")
		if targets[2].distance_to(targets[3]) < EPSILON:
			fail("工作与用餐表演点重合")
		if targets[4].distance_to(targets[5]) < EPSILON:
			fail("连续散步表演点重合")
		var home: Vector3 = citizen.get_meta("home_position", Vector3.ZERO)
		if targets[6].distance_to(home) >= EPSILON:
			fail("连续表演路线没有返回住宅")
	# Changing the schedule phase is not a production tick.  It must leave the
	# economy unchanged while paused.
	if day != int(game.day) or wood != int(game.wood) or food != int(game.food) or coins != int(game.coins) or population != int(game.population) or happiness != int(game.happiness) or stable_days != int(game.stable_days) or maintenance_debt != int(game.maintenance_debt):
		fail("NPC日程切换意外改变了日期、资源、人口、幸福度或经营状态")

func check_pause_and_state_only(game) -> void:
	game.citizen_schedule_time = 0.40
	game.update_citizen_schedules()
	game.time_paused = true
	var citizen: Node3D = game.citizen_root.get_child(0) as Node3D
	var before_state := str(citizen.get_meta("schedule_state", ""))
	var before_target: Vector3 = citizen.get_meta("schedule_target", Vector3.ZERO)
	var before_day := int(game.day)
	var before_elapsed := float(game.auto_day_elapsed)
	var before_position: Vector3 = citizen.position
	var before_phase := float(game.citizen_schedule_time)
	game._process(0.10)
	game._physics_process(0.10)
	var after_position: Vector3 = citizen.position
	if str(citizen.get_meta("schedule_state", "")) != before_state:
		fail("短帧内NPC表演日程发生非预期跨段")
	var after_target: Vector3 = citizen.get_meta("schedule_target", Vector3.ZERO)
	if after_target.distance_to(before_target) >= EPSILON:
		fail("短帧内NPC表演目标发生非预期变化")
	var presentation_distance := Vector2(after_position.x - before_position.x, after_position.z - before_position.z).length()
	if absf(presentation_distance - float(game.NPC_MOVE_SPEED) * float(game.NPC_PHYSICS_STEP)) > 0.0002:
		fail("游戏暂停影响了NPC固定展示移速")
	var expected_phase := before_phase + 0.10 / float(game.NPC_SCHEDULE_SECONDS)
	if absf(float(game.citizen_schedule_time) - expected_phase) > EPSILON:
		fail("游戏暂停影响了NPC真实时间表演日程")
	if int(game.day) != before_day or absf(float(game.auto_day_elapsed) - before_elapsed) >= EPSILON:
		fail("暂停时自动日期仍在推进")

func check_constant_display_speed(game) -> void:
	game.time_paused = false
	game.day_settling = false
	game.ended = ""
	var expected_speed := float(game.NPC_MOVE_SPEED)
	var frame_deltas := [0.016, 0.033, 0.10]
	for child in game.citizen_root.get_children():
		if not child is Node3D or child.is_queued_for_deletion():
			continue
		# Deliberately inject different legacy values: movement must ignore them.
		var index := int(child.get_meta("citizen_index", 0))
		child.set_meta("schedule_speed", 0.2 + float(index) * 2.0)
		child.set_meta("schedule_velocity", Vector3.ZERO)
		child.set_meta("schedule_target", child.position + Vector3(20.0, 0.0, 0.0))
	for frame_delta in frame_deltas:
		var before_positions := {}
		for child in game.citizen_root.get_children():
			if child is Node3D and not child.is_queued_for_deletion():
				before_positions[child.get_instance_id()] = child.position
		game.move_citizens(float(frame_delta))
		var frame_speeds: Array[float] = []
		for child in game.citizen_root.get_children():
			if not child is Node3D or child.is_queued_for_deletion():
				continue
			var before: Vector3 = before_positions[child.get_instance_id()]
			var distance := Vector2(child.position.x - before.x, child.position.z - before.z).length()
			var observed_speed := distance / float(frame_delta)
			frame_speeds.append(observed_speed)
			if absf(observed_speed - expected_speed) > 0.002:
				fail("居民 %d 移速不恒定：期望 %.2f，实际 %.3f" % [int(child.get_meta("citizen_index", -1)), expected_speed, observed_speed])
		if not frame_speeds.is_empty():
			var first_speed := frame_speeds[0]
			for observed_speed in frame_speeds:
				if absf(observed_speed - first_speed) > 0.002:
					fail("同一帧不同居民的展示移速不一致")

	var citizen := game.citizen_root.get_child(0) as Node3D
	var origin := citizen.position
	citizen.set_meta("schedule_target", origin + Vector3(20.0, 0.0, 0.0))
	game.time_speed = 1.0
	game.move_citizens(0.05)
	var normal_distance := Vector2(citizen.position.x - origin.x, citizen.position.z - origin.z).length()
	citizen.position = origin
	citizen.set_meta("schedule_target", origin + Vector3(20.0, 0.0, 0.0))
	game.time_speed = 4.0
	game.move_citizens(0.05)
	var fast_distance := Vector2(citizen.position.x - origin.x, citizen.position.z - origin.z).length()
	if absf(normal_distance - fast_distance) > EPSILON:
		fail("经济时间倍率改变了NPC展示移速")

	# Gameplay states must not affect presentation movement either.
	var states := [
		{"paused": true, "settling": false, "ended": ""},
		{"paused": false, "settling": true, "ended": ""},
		{"paused": false, "settling": false, "ended": "win"},
	]
	for state in states:
		citizen.position = origin
		citizen.set_meta("schedule_target", origin + Vector3(20.0, 0.0, 0.0))
		game.time_paused = bool(state.paused)
		game.day_settling = bool(state.settling)
		game.ended = str(state.ended)
		game.move_citizens(0.05)
		var state_distance := Vector2(citizen.position.x - origin.x, citizen.position.z - origin.z).length()
		if absf(state_distance - expected_speed * 0.05) > 0.0002:
			fail("游戏状态影响了NPC固定展示移速")

	# A sudden target reversal changes direction only; it never restarts an
	# acceleration curve.
	game.time_paused = false
	game.day_settling = false
	game.ended = ""
	citizen.position = origin
	citizen.set_meta("schedule_target", origin + Vector3(20.0, 0.0, 0.0))
	game.move_citizens(0.05)
	var turn_start := citizen.position
	citizen.set_meta("schedule_target", turn_start - Vector3(20.0, 0.0, 0.0))
	game.move_citizens(0.05)
	var reversed_distance := Vector2(citizen.position.x - turn_start.x, citizen.position.z - turn_start.z).length()
	if absf(reversed_distance - expected_speed * 0.05) > 0.0002:
		fail("NPC换向时移速发生变化")
	game.time_paused = true

func check_continuous_route(game) -> void:
	var citizen := game.citizen_root.get_child(0) as Node3D
	var origin := citizen.position
	var route: Array[Dictionary] = [
		{"position": origin + Vector3(0.04, 0.0, 0.0), "state": "通勤", "activity": "前往工地"},
		{"position": origin + Vector3(0.04, 0.0, 0.04), "state": "工作", "activity": "耕作"},
		{"position": origin + Vector3(0.0, 0.0, 0.04), "state": "用餐", "activity": "取食"},
		{"position": origin, "state": "散步", "activity": "巡游"},
	]
	citizen.set_meta("performance_route", route)
	citizen.set_meta("performance_route_index", 0)
	game.apply_citizen_route_step(citizen)
	var expected_step := float(game.NPC_MOVE_SPEED) / 60.0
	var transition_count := 0
	for _frame in range(180):
		game.move_citizens(1.0 / 60.0)
		var traveled := float(citizen.get_meta("last_travel_distance", 0.0))
		if absf(traveled - expected_step) > 0.0002:
			fail("NPC连续巡游出现停顿或变速：%.5f/%.5f" % [traveled, expected_step])
			break
		transition_count += int(citizen.get_meta("last_route_transitions", 0))
	if transition_count < 10:
		fail("NPC连续巡游没有反复跨越表演点")
	game.update_citizen_schedules()

func check_smooth_movement(game) -> void:
	var citizen: Node3D = game.citizen_root.get_child(0) as Node3D
	game.time_paused = false
	game.day_settling = false
	game.ended = ""
	citizen.set_meta("schedule_velocity", Vector3.ZERO)
	citizen.set_meta("schedule_target", citizen.position + Vector3(20.0, 0.0, 0.0))
	var before := citizen.position
	game.move_citizens(0.25)
	var displacement := Vector2(citizen.position.x - before.x, citizen.position.z - before.z).length()
	var expected_displacement := float(game.NPC_MOVE_SPEED) * 0.25
	if absf(displacement - expected_displacement) > 0.0002:
		fail("较长物理步长改变了NPC固定移速：%.3f 米" % displacement)
	if absf(citizen.position.y - float(citizen.get_meta("ground_height", 0.18))) > 0.06:
		fail("日程目标切换导致NPC高度突变")
	game.time_paused = true

func check_real_time_schedule_and_turning(game) -> void:
	var citizen := game.citizen_root.get_child(0) as Node3D
	game.time_paused = false
	game.day_settling = false
	game.ended = ""
	game.auto_day_elapsed = 0.0
	game.citizen_schedule_time = 0.25
	game.time_speed = 1.0
	game._process(0.10)
	var normal_speed_phase := float(game.citizen_schedule_time)
	game.auto_day_elapsed = 0.0
	game.citizen_schedule_time = 0.25
	game.time_speed = 4.0
	game._process(0.10)
	var fast_speed_phase := float(game.citizen_schedule_time)
	if absf(normal_speed_phase - fast_speed_phase) > EPSILON:
		fail("4倍资源时间错误加速了NPC生活日程")
	var expected_phase := 0.25 + 0.10 / float(game.NPC_SCHEDULE_SECONDS)
	if absf(fast_speed_phase - expected_phase) > EPSILON:
		fail("NPC生活日程没有按独立的真实时间推进")

	citizen.rotation.y = 0.0
	citizen.set_meta("schedule_velocity", Vector3.ZERO)
	citizen.set_meta("schedule_target", citizen.position + Vector3(0.0, 0.0, -20.0))
	game.move_citizens(0.10)
	if absf(citizen.rotation.y) > float(game.NPC_TURN_SPEED) * 0.10 + EPSILON:
		fail("NPC单帧转向速度超过上限")
	game.time_paused = true

func check_cross_day_continuity(game) -> void:
	# Put every resident partway along a route so recreating them at their spawn
	# point cannot masquerade as a harmless schedule refresh.  A citizen's
	# citizen_index is its gameplay identity; that identity must keep the same
	# node instance and world position when the automatic clock settles a day.
	var before_by_index := {}
	var setup_indices := {}
	for child in game.citizen_root.get_children():
		if not child is Node3D or child.is_queued_for_deletion():
			continue
		var index := int(child.get_meta("citizen_index", -1))
		var role := str(child.get_meta("schedule_role", ""))
		if index < 0:
			fail("居民节点缺少可追踪的 citizen_index 身份")
			continue
		if setup_indices.has(index):
			fail("跨日前存在重复居民身份：%d" % index)
			continue
		if role.is_empty():
			fail("居民 %d 缺少有意义的日程角色" % index)
		setup_indices[index] = true
		var ground_height := float(child.get_meta("ground_height", child.position.y))
		child.position = Vector3(
			child.position.x + 2.0 + float(index % 3) * 0.35,
			ground_height,
			child.position.z + 0.45 + float(index % 2) * 0.25
		)
		child.set_meta("schedule_velocity", Vector3.ZERO)
		before_by_index[index] = {
			"instance_id": child.get_instance_id(),
			"position": child.position,
			"role": role,
		}
	if before_by_index.is_empty():
		fail("跨日连续性测试没有可用居民")
		return

	# Keep population stable so this specifically tests a day boundary rather
	# than legitimate migration.  _process exercises the same order as a real
	# rendered frame: schedule, movement, then automatic day settlement.
	game.happiness = 40
	game.food = maxi(100, int(game.population) * 4)
	game.wood = maxi(100, int(game.wood))
	game.ended = ""
	game.day_settling = false
	game.time_paused = false
	game.time_speed = 1.0
	game.auto_day_elapsed = float(game.AUTO_DAY_SECONDS) - 0.01
	var day_before := int(game.day)
	game._physics_process(0.02)
	game._process(0.02)
	if int(game.day) != day_before + 1:
		fail("自动时间跨日测试没有结算到下一日")

	var after_by_index := {}
	for child in game.citizen_root.get_children():
		if not child is Node3D or child.is_queued_for_deletion():
			continue
		var index := int(child.get_meta("citizen_index", -1))
		if index < 0:
			fail("跨日后居民节点丢失 citizen_index 身份")
			continue
		if after_by_index.has(index):
			fail("跨日后出现重复居民身份：%d" % index)
			continue
		after_by_index[index] = child

	if after_by_index.size() != before_by_index.size():
		fail("无迁入迁出时跨日改变了居民节点数量：%d -> %d" % [before_by_index.size(), after_by_index.size()])
	for index in before_by_index:
		if not after_by_index.has(index):
			fail("跨日后居民身份 %d 消失" % int(index))
			continue
		var before: Dictionary = before_by_index[index]
		var citizen: Node3D = after_by_index[index] as Node3D
		if citizen.get_instance_id() != int(before.instance_id):
			fail("跨日重建了居民 %d 的节点实例" % int(index))
		if str(citizen.get_meta("schedule_role", "")) != str(before.role):
			fail("跨日改变了居民 %d 的日程角色" % int(index))
		var before_position: Vector3 = before.position
		var displacement := Vector2(
			citizen.position.x - before_position.x,
			citizen.position.z - before_position.z
		).length()
		if displacement > MAX_FRAME_DISPLACEMENT:
			fail("跨日单帧居民 %d 突进 %.3f 米" % [int(index), displacement])
		if absf(citizen.position.y - float(citizen.get_meta("ground_height", citizen.position.y))) > 0.06:
			fail("跨日单帧居民 %d 高度突变" % int(index))
	game.time_paused = true

func preserve_save_file() -> void:
	original_save_exists = FileAccess.file_exists(SAVE_PATH)
	if not original_save_exists:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		fail("无法暂存验收前的存档")
		return
	original_save_text = file.get_as_text()

func restore_save_file() -> void:
	if original_save_exists:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file == null:
			fail("无法恢复验收前的存档")
			return
		file.store_string(original_save_text)
		file.close()
		return
	if FileAccess.file_exists(SAVE_PATH):
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if error != OK:
			fail("无法清理验收生成的临时存档")

func fail(message: String) -> void:
	failures.append(message)
	push_error("NPC_SCHEDULE_ACCEPTANCE_FAILED: " + message)

func finish() -> void:
	if failures.is_empty():
		print("NPC_SCHEDULE_ACCEPTANCE_OK: walk animation, bridge-only river crossings, constant display speed, no waiting, persistent cross-day identity")
		quit(0)
	else:
		print("NPC_SCHEDULE_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
