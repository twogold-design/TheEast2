extends SceneTree

const VIEWPORT_SIZE := Vector2i(1366, 768)
const SAVE_PATH := "res://saves/savegame.json"

var failures: Array[String] = []
var original_save_exists := false
var original_save_text := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	preserve_save_file()
	root.size = VIEWPORT_SIZE
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
	game.time_paused = true
	game.update_ui()
	await process_frame

	check_time_ui(game)
	check_boundary_hills(game)
	check_middle_mouse_pan(game)
	await check_right_click_cancel_and_building_delete(game)
	check_auto_time(game)
	await check_region_panel_collapse(game)
	await check_settings_menu(game)

	game.time_paused = true
	restore_save_file()
	finish()

func check_time_ui(game) -> void:
	var all_button_text := collect_button_text(game)
	if all_button_text.find("下一日") >= 0:
		fail("界面仍保留手动下一日按钮")
	for label in ["1×", "2×", "4×"]:
		if all_button_text.find(label) < 0:
			fail("缺少自动时间速度按钮：%s" % label)
	check_inside_viewport(game.pause_button, "暂停按钮")
	for speed in game.speed_buttons:
		check_inside_viewport(game.speed_buttons[speed], "%d倍速按钮" % int(speed))
	for type in game.build_buttons:
		check_inside_viewport(game.build_buttons[type], "%s建造按钮" % type)

func check_boundary_hills(game) -> void:
	var hill_count := 0
	for child in game.world.get_children():
		if not str(child.name).begins_with("BoundaryHill_"):
			continue
		hill_count += 1
		if not child is MeshInstance3D or not child.mesh is CylinderMesh:
			fail("边缘山体不是预期的山形网格")
			continue
		var shape: CylinderMesh = child.mesh
		if shape.top_radius >= shape.bottom_radius:
			fail("边缘山体仍是顶部宽、底部窄的倒置形态")
		if child.position.y - shape.height * 0.5 < -0.01:
			fail("边缘山体底部沉入地面")
	if hill_count != 18:
		fail("边缘山体数量异常：%d" % hill_count)

func check_middle_mouse_pan(game) -> void:
	game.reset_game(false)
	game.time_paused = true
	game.selected_type = "farm"
	var target_before: Vector3 = game.camera_target
	var offset_before: Vector3 = game.camera.position - game.camera_target
	var buildings_before: int = int(game.buildings.size())
	var wood_before := int(game.wood)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = Vector2(600, 400)
	game._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(760, 470)
	game._unhandled_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_MIDDLE
	release.pressed = false
	release.position = motion.position
	game._unhandled_input(release)

	if game.camera_target.distance_to(target_before) < 0.05:
		fail("中键拖动没有平移地图")
	if (game.camera.position - game.camera_target).distance_to(offset_before) > 0.05:
		fail("中键平移改变了镜头角度或距离")
	if game.drag_button != -1:
		fail("中键释放后仍残留拖动状态")
	if game.buildings.size() != buildings_before or int(game.wood) != wood_before:
		fail("中键拖动意外触发了建造或扣费")

func check_right_click_cancel_and_building_delete(game) -> void:
	game.reset_game(false)
	game.time_paused = true
	game.select_building("farm")
	var buildings_before: int = game.buildings.size()
	var wood_before: int = int(game.wood)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(600, 400)
	game._unhandled_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	release.position = press.position
	game._unhandled_input(release)
	if game.selected_type != "" or game.drag_button != -1:
		fail("右键短按没有取消当前摆放")
	if game.buildings.size() != buildings_before or int(game.wood) != wood_before:
		fail("右键取消摆放意外改变了建筑或木材")

	game.select_building("farm")
	var camera_before: Vector3 = game.camera.position
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(600, 400)
	game._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(680, 435)
	game._unhandled_input(motion)
	release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	release.position = motion.position
	game._unhandled_input(release)
	if game.selected_type != "farm" or game.drag_button != -1:
		fail("右键拖动旋转时错误取消了摆放")
	if game.camera.position.distance_to(camera_before) < 0.05:
		fail("右键拖动没有旋转镜头")

	game.reset_game(false)
	game.time_paused = true
	game.wood = 50
	var starter_cell := Vector2i(9, 9)
	var starter_id: int = int(game.occupied[starter_cell])
	var starter_count: int = game.buildings.size()
	var starter_wood: int = int(game.wood)
	var starter_coins: int = int(game.coins)
	var click_position: Vector2 = game.camera.unproject_position(game.grid_to_world(starter_cell))
	game.handle_world_click(click_position)
	await process_frame
	await process_frame
	if not game.inspector.visible or int(game.selected_building_id) != starter_id:
		fail("点击已有建筑没有选中并打开详情")
	check_inside_viewport(game.inspector, "建筑选中详情")
	if game.inspector.get_global_rect().intersects(game.region_panel.get_global_rect()):
		fail("建筑选中详情被目标栏遮挡")
	game.demolish_selected()
	if game.buildings.size() != starter_count - 1 or game.occupied.has(starter_cell) or game.inspector.visible:
		fail("选中建筑后无法拆除")
	var house_definition: Dictionary = game.BUILDINGS.house
	if int(game.wood) != starter_wood + int(house_definition.cost) / 2 or int(game.coins) != starter_coins + int(house_definition.coin_cost) / 2:
		fail("拆除建筑没有返还一半木材与铜钱")

func check_auto_time(game) -> void:
	game.reset_game(false)
	game.time_paused = false
	game.auto_day_elapsed = 0.0
	game.update_auto_time(game.AUTO_DAY_SECONDS - 0.1)
	if int(game.day) != 1:
		fail("1倍速在周期结束前提前结算")
	game.update_auto_time(0.2)
	if int(game.day) != 2:
		fail("1倍速经过完整周期后没有自动推进一天")

	game.toggle_time_paused()
	var paused_day := int(game.day)
	var paused_food := int(game.food)
	game.update_auto_time(game.AUTO_DAY_SECONDS * 3.0)
	if int(game.day) != paused_day or int(game.food) != paused_food:
		fail("暂停状态仍在推进经营结算")

	game.reset_game(false)
	game.set_time_speed(4.0)
	game.auto_day_elapsed = 0.0
	game.update_auto_time(game.AUTO_DAY_SECONDS / 4.0 - 0.1)
	if int(game.day) != 1:
		fail("4倍速在周期结束前提前结算")
	game.update_auto_time(0.2)
	if int(game.day) != 2:
		fail("4倍速没有按缩短后的周期推进")

	game.auto_day_elapsed = 4.0
	game.time_paused = true
	game.reset_game(false)
	if not is_zero_approx(float(game.auto_day_elapsed)) or game.time_paused or not is_equal_approx(float(game.time_speed), 1.0):
		fail("重置没有恢复默认自动时间状态")
	game.ended = "win"
	var ended_day := int(game.day)
	game.update_auto_time(game.AUTO_DAY_SECONDS * 2.0)
	if int(game.day) != ended_day:
		fail("终局后自动时间仍在推进")
	game.reset_game(false)

func check_region_panel_collapse(game) -> void:
	game.time_paused = true
	game.region_panel_collapsed = false
	game.update_ui()
	await process_frame
	var fixed_top_goal := str(game.goal_label.text)
	var fixed_goal_list := str(game.region_body.text)
	var expanded_area: float = game.region_panel.size.x * game.region_panel.size.y
	game.toggle_region_panel()
	await process_frame
	var collapsed_area: float = game.region_panel.size.x * game.region_panel.size.y
	if not game.region_panel_collapsed:
		fail("目标栏没有进入收起状态")
	if game.region_body.visible or game.region_unlock_button.visible:
		fail("目标栏收起后正文或开拓按钮仍可见")
	if collapsed_area > expanded_area * 0.25:
		fail("目标栏收起后占用面积仍过大")
	var compact_title := str(game.region_title.text).replace(" ", "")
	if compact_title != "目标·北坡" or str(game.goal_label.text).find("目标：") < 0:
		fail("目标栏收起后没有保留目标区域或顶栏动作目标")
	assert_no_goal_progress("%s\n%s" % [game.region_title.text, game.goal_label.text], "收起目标栏")
	check_inside_viewport(game.region_panel_toggle, "目标栏展开按钮")
	game.day = 5
	game.population = 8
	game.happiness = 80
	game.wood = 100
	game.food = 100
	game.coins = 100
	game.stable_days = 8
	game.update_ui()
	if not game.region_panel_collapsed or str(game.region_title.text).find("目标") < 0 or str(game.goal_label.text).find("目标：") < 0:
		fail("目标更新意外展开了目标栏")
	if str(game.goal_label.text) != fixed_top_goal or str(game.region_body.text) != fixed_goal_list:
		fail("同一章节内顶栏目标或目标清单随状态发生变化")
	game.toggle_region_panel()
	await process_frame
	if game.region_panel_collapsed or not game.region_body.visible or not game.region_unlock_button.visible:
		fail("目标栏无法恢复完整展开状态")

func check_settings_menu(game) -> void:
	game.reset_game(false)
	game.time_paused = true
	game.update_ui()
	await process_frame
	if game.settings_overlay.visible:
		fail("设置菜单初始状态不是收起")
	if str(game.settings_button.tooltip_text).is_empty():
		fail("设置按钮缺少用途提示")
	check_inside_viewport(game.settings_button, "设置按钮")
	check_inside_viewport(game.bottom_panel, "底部常用操作栏")
	var bottom_text := collect_button_text(game.bottom_panel)
	for hidden_action in ["查看/取消", "保存", "读取", "重置", "重新开始"]:
		if bottom_text.find(hidden_action) >= 0:
			fail("低频操作仍常驻底栏：%s" % hidden_action)
	for frequent_action in ["茅舍", "伐木场", "农田", "仓库", "小工坊", "1×", "2×", "4×"]:
		if bottom_text.find(frequent_action) < 0:
			fail("底栏缺少常用操作：%s" % frequent_action)
	if bottom_text.find("暂停") < 0 and bottom_text.find("继续") < 0:
		fail("底栏缺少暂停/继续控制")

	var state_before := [game.day, game.wood, game.food, game.population, game.happiness, game.map_region_level, game.buildings.size(), game.time_paused, game.time_speed, game.auto_day_elapsed]
	var target_before: Vector3 = game.camera_target
	var camera_before: Vector3 = game.camera.position
	game.toggle_settings_menu()
	await process_frame
	if not game.settings_overlay.visible or not game.settings_button.button_pressed:
		fail("设置按钮无法展开菜单")
	check_inside_viewport(game.settings_panel, "设置菜单")
	var menu_text := collect_button_text(game.settings_panel)
	for menu_action in ["查看地图 / 取消摆放", "保存当前进度", "读取最近存档", "重新开始本局"]:
		if menu_text.find(menu_action) < 0:
			fail("设置菜单缺少操作：%s" % menu_action)
	for action in game.settings_action_buttons:
		var button: Button = game.settings_action_buttons[action]
		if not button.is_visible_in_tree() or button.disabled:
			fail("设置菜单操作不可用：%s" % action)
		check_inside_viewport(button, "设置菜单%s按钮" % action)
	if game.settings_overlay.mouse_filter != Control.MOUSE_FILTER_STOP or game.settings_panel.mouse_filter != Control.MOUSE_FILTER_STOP:
		fail("设置菜单没有拦截地图点击")
	game.toggle_settings_menu()
	await process_frame
	if game.settings_overlay.visible or game.settings_button.button_pressed:
		fail("设置菜单无法再次点击收起")
	var state_after := [game.day, game.wood, game.food, game.population, game.happiness, game.map_region_level, game.buildings.size(), game.time_paused, game.time_speed, game.auto_day_elapsed]
	if state_before != state_after or game.camera_target != target_before or game.camera.position != camera_before:
		fail("开关设置菜单改变了经营或镜头状态")

	game.toggle_settings_menu()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	game._unhandled_input(escape)
	if game.settings_overlay.visible:
		fail("Esc 没有优先关闭设置菜单")
	game.toggle_settings_menu()
	var buildings_before_click: int = game.buildings.size()
	var wood_before_click := int(game.wood)
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(100, 400)
	game.settings_overlay.gui_input.emit(outside_click)
	if game.settings_overlay.visible:
		fail("点击设置菜单外部没有收起菜单")
	if game.buildings.size() != buildings_before_click or int(game.wood) != wood_before_click:
		fail("关闭设置菜单的点击穿透到了地图")

	game.selected_type = "farm"
	game.toggle_settings_menu()
	game.view_from_settings()
	if game.settings_overlay.visible or game.selected_type != "":
		fail("查看地图操作没有关闭菜单并退出摆放")
	game.toggle_settings_menu()
	game.save_from_settings()
	if game.settings_overlay.visible or not FileAccess.file_exists(SAVE_PATH):
		fail("保存操作没有关闭菜单并写入存档")
	game.toggle_settings_menu()
	game.request_load_from_settings()
	if game.settings_overlay.visible or not game.confirmation_dialog.visible or game.pending_confirm_action != "load":
		fail("读取操作没有关闭菜单并显示确认")
	game.confirmation_dialog.hide()
	game.toggle_settings_menu()
	var reset_day_before := int(game.day)
	game.request_reset_from_settings()
	if game.settings_overlay.visible or not game.confirmation_dialog.visible or game.pending_confirm_action != "reset" or int(game.day) != reset_day_before:
		fail("重新开始操作没有先显示确认")
	game.confirmation_dialog.hide()
	game.pending_confirm_action = ""

	game.time_paused = false
	game.auto_day_elapsed = 0.0
	var day_before := int(game.day)
	game.toggle_settings_menu()
	game.update_auto_time(game.AUTO_DAY_SECONDS + 0.1)
	if int(game.day) != day_before + 1 or not game.settings_overlay.visible:
		fail("设置菜单展开时自动时间没有继续流逝")
	game.close_settings_menu()
	game.time_paused = true
	game.update_ui()

func collect_button_text(node: Node) -> String:
	var parts: Array[String] = []
	if node is Button:
		parts.append(node.text)
	for child in node.get_children():
		parts.append(collect_button_text(child))
	return "\n".join(parts)

func check_inside_viewport(control: Control, label: String) -> void:
	var rect := control.get_global_rect()
	if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > VIEWPORT_SIZE.x + 1.0 or rect.end.y > VIEWPORT_SIZE.y + 1.0:
		fail("%s 超出 1366x768 视口：%s" % [label, rect])

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
		return
	if FileAccess.file_exists(SAVE_PATH):
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if error != OK:
			fail("无法清理验收生成的临时存档")

func fail(message: String) -> void:
	failures.append(message)
	push_error("CONTROLS_TIME_UI_ACCEPTANCE_FAILED: " + message)

func assert_no_goal_progress(text_value: String, context: String) -> void:
	if text_value.find("进度") >= 0:
		fail("%s仍显示“进度”：%s" % [context, text_value])
	var ratio_regex := RegEx.new()
	ratio_regex.compile("\\d+\\s*/\\s*\\d+")
	if ratio_regex.search(text_value) != null:
		fail("%s仍显示数字/数字目标进度：%s" % [context, text_value])
	var percentage_regex := RegEx.new()
	percentage_regex.compile("\\d+\\s*%")
	if percentage_regex.search(text_value) != null:
		fail("%s仍显示百分比目标进度：%s" % [context, text_value])
	var current_required_regex := RegEx.new()
	current_required_regex.compile("当前[^\\n]*要求")
	if current_required_regex.search(text_value) != null:
		fail("%s仍显示当前/要求式说明：%s" % [context, text_value])

func finish() -> void:
	if failures.is_empty():
		print("CONTROLS_TIME_UI_ACCEPTANCE_OK: middle-mouse pan, automatic time, compact collapsible goals, layered settings menu")
		quit(0)
	else:
		print("CONTROLS_TIME_UI_ACCEPTANCE_FAILED: %d issue(s)" % failures.size())
		quit(1)
