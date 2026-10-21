extends SceneTree

## The user may have a live game open. This fixture cannot read or write their
## save: even production callbacks dispatch to these no-op overrides.
class IsolatedGame extends "res://godot/Main.gd":
	var intercepted_saves := 0
	func save_path() -> String:
		return "res://.godot-user/qa/building-status-never-written.json"
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/building-status-audio.cfg"
	func save_game(_show_feedback := true) -> void:
		intercepted_saves += 1
	func load_game(_show_feedback := true) -> void:
		pass

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := IsolatedGame.new()
	root.add_child(game)
	game.background_music.player.stop()
	game.background_music.player.stream = null
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.time_paused = true
	game.add_building("warehouse", Vector2i(6, 12), true)
	var warehouse_id := int(game.buildings.back().id)
	for record in game.buildings:
		if str(record.type) == "warehouse":
			continue
		if game.get_building_status_marker(int(record.id)) != null:
			fail("普通住宅不应出现停产标记")
		game.show_inspector(int(record.id))
		check_inspector_status(game, false)
	game.show_inspector(warehouse_id)
	check_marker(game, warehouse_id, "road", true)
	check_inspector_status(game, true)
	if "未接通主路" not in game.inspector_status.text or "仓储停用" not in game.inspector_status.text:
		fail("仓库详情应解释断路停用")
	game.add_road(Vector2i(8, 13), true)
	game.add_road(Vector2i(9, 13), true)
	game.update_ui()
	check_marker(game, warehouse_id, "passive", false)
	check_inspector_status(game, false)
	game.remove_road(Vector2i(9, 13), false)
	game.update_ui()
	check_marker(game, warehouse_id, "road", true)
	game.add_building("workshop", Vector2i(12, 9), true)
	var workshop: Dictionary = game.buildings.back()
	var workshop_id := int(workshop.id)
	game.wood = 3
	game.food = 1
	game.update_ui()
	check_marker(game, workshop_id, "materials", true)
	game.show_inspector(workshop_id)
	check_inspector_status(game, true)
	if "木材需 4（现有 3）" not in game.inspector_status.text or "粮食需 2（现有 1）" not in game.inspector_status.text:
		fail("详情没有准确说明当前缺料数量")
	var marker := game.get_building_status_marker(workshop_id)
	if marker == null or marker.position.y <= 1.5 or marker.billboard != BaseMaterial3D.BILLBOARD_ENABLED:
		fail("停产标记没有放在建筑上方面向镜头")
	game.population = 1
	game.update_ui()
	check_marker(game, workshop_id, "workers", true)
	if "在岗 1/3" not in game.inspector_status.text or "缺工" not in game.inspector_status.text:
		fail("不足满员时应优先显示缺工而非原料")
	game.set_building_enabled(workshop_id, false)
	check_marker(game, workshop_id, "paused", true)
	if "已暂停" not in game.inspector_status.text:
		fail("手动暂停原因未同步至详情")
	game.population = 4
	game.wood = 50
	game.food = 50
	game.set_building_enabled(workshop_id, true)
	check_marker(game, workshop_id, "running", false)
	# Readiness reflects resources and workers now, never yesterday's result.
	workshop.last_running = true
	game.food = 0
	game.update_ui()
	check_marker(game, workshop_id, "materials", true)
	workshop.last_running = false
	game.food = 50
	game.update_ui()
	check_marker(game, workshop_id, "running", false)
	game.next_day()
	check_marker(game, workshop_id, "running", false)
	if game.intercepted_saves <= 0:
		fail("暂停与日结测试没有经过隔离存档回调")
	game.remove_building_by_id(workshop_id, false)
	if game.get_building_status_marker(workshop_id) != null:
		fail("拆除后仍能取到旧建筑标记")
	game.population = 1
	game.add_building("farm", Vector2i(4, 9), true)
	var farm_id := int(game.buildings.back().id)
	game.add_building("lumber", Vector2i(14, 9), true)
	var lumber_id := int(game.buildings.back().id)
	check_marker(game, farm_id, "running", false)
	check_marker(game, lumber_id, "workers", true)
	game.show_inspector(farm_id)
	check_inspector_status(game, false)
	if "在岗 1/2" not in game.inspector_status.text or "生产中" not in game.inspector_status.text:
		fail("部分在岗农田被误报停产")
	game.remove_building_by_id(farm_id, false)
	check_marker(game, lumber_id, "running", false)
	game.population = 20
	game.add_building("market", Vector2i(12, 12), true)
	var market_id := int(game.buildings.back().id)
	game.food = 2
	game.update_ui()
	check_marker(game, market_id, "materials", true)
	game.food = 3
	game.update_ui()
	check_marker(game, market_id, "running", false)
	game.show_inspector(market_id)
	check_inspector_status(game, false)
	if "当前库存够单次交易" not in game.inspector_status.text or "口粮、工坊优先" not in game.inspector_status.text:
		fail("集市未区分当前库存与日结优先级")
	game.add_road(Vector2i(11, 6), true)
	game.show_road_inspector(Vector2i(11, 6))
	check_inspector_status(game, false)
	if game.inspector_status.text != "状态：已接通村庄主路":
		fail("联网道路状态未放在独立顶部栏")
	game.add_road(Vector2i(13, 6), true)
	game.show_road_inspector(Vector2i(13, 6))
	check_inspector_status(game, true)
	game.add_road(Vector2i(12, 6), true)
	game.update_ui()
	check_inspector_status(game, false)
	if game.inspector_status.text != "状态：已接通村庄主路":
		fail("道路恢复联网后独立状态未实时转绿")
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.4, true, false, true).timeout
	if failures.is_empty():
		print("BUILDING_STATUS_ACCEPTANCE_OK: live overhead paused/workforce/material markers, inspector agreement, partial production, isolated no-save fixture")
	else:
		push_error("BUILDING_STATUS_ACCEPTANCE_FAILED: " + "; ".join(failures))
	quit(0 if failures.is_empty() else 1)

func check_marker(game, building_id: int, state: String, shown: bool) -> void:
	var marker: Label3D = game.get_building_status_marker(building_id)
	if marker == null:
		fail("建筑 %d 缺少状态标记" % building_id)
		return
	if str(marker.get_meta("operation_state", "")) != state or marker.visible != shown:
		fail("建筑 %d 状态应为 %s / visible=%s，实际 %s / visible=%s" % [building_id, state, shown, marker.get_meta("operation_state", ""), marker.visible])
	var expected_text: String = {"paused": "Ⅱ", "workers": "!", "materials": "!", "road": "!"}.get(state, "")
	if marker.text != expected_text:
		fail("建筑 %d 应仅显示醒目符号 %s" % [building_id, expected_text])
	if int(game.selected_building_id) == building_id:
		check_inspector_status(game, state in ["paused", "workers", "materials", "road"])
	if shown:
		var expected_color: Color = {"paused": Color("725a43"), "workers": Color("a76a24"), "materials": Color("a54f35"), "road": Color("a63d32")}[state]
		if not marker.modulate.is_equal_approx(expected_color):
			fail("建筑 %d 状态色错误" % building_id)
		if marker.font_size != 64 or not is_equal_approx(marker.pixel_size, 0.012) or marker.outline_size != 6:
			fail("建筑 %d 符号大小与描边不够清晰" % building_id)

func check_inspector_status(game, abnormal: bool) -> void:
	var status: Label = game.inspector_status
	if status == null:
		fail("详情缺少独立置顶状态栏")
		return
	if status.get_parent() != game.inspector_title.get_parent() or status.get_parent() != game.inspector_body.get_parent():
		fail("状态栏与标题、正文没有放在同一顺序容器")
	if status.get_index() != game.inspector_title.get_index() + 1 or status.get_index() >= game.inspector_body.get_index():
		fail("状态栏未紧随标题且位于描述正文上方")
	var expected := Color("a63d32") if abnormal else Color("39764b")
	if not status.get_theme_color("font_color").is_equal_approx(expected):
		fail("详情状态应为%s色：%s" % ["异常红" if abnormal else "正常绿", status.text])
	if status.text.is_empty() or not status.visible:
		fail("独立状态栏未展示当前状态")
	if "状态：" in game.inspector_body.text:
		fail("详情正文重复显示状态，未移到顶部独立栏")

func fail(message: String) -> void:
	failures.append(message)
