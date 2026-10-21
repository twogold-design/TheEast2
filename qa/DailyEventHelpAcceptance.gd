extends SceneTree

class IsolatedGame extends "res://godot/Main.gd":
	var latest_event := ""
	func save_path() -> String:
		return "res://.godot-user/qa/daily-event-help-never-written.json"
	func save_game(_show_feedback := true) -> void:
		pass
	func load_game(_show_feedback := true) -> void:
		pass
	func trigger_event(index: int) -> String:
		latest_event = super.trigger_event(index)
		return latest_event

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("DAILY_EVENT_HELP_FAILED: " + message)

func check_no_persistent_help(node: Node) -> void:
	if node is Window and not node.visible:
		return
	if node is CanvasItem and not node.is_visible_in_tree():
		return
	if node is Label:
		for term in ["左键", "中键", "右键", "滚轮"]:
			check(term not in node.text, "main view contains mouse help: " + node.text)
	for child in node.get_children():
		check_no_persistent_help(child)

func capture(path: String) -> void:
	if "--render" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://qa/ui-simplification")
	check(root.get_texture().get_image().save_png(path) == OK, "save screenshot")

func run() -> void:
	root.size = Vector2i(1366, 768)
	root.gui_embed_subwindows = true
	var game := IsolatedGame.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.time_paused = true
	await process_frame
	await process_frame
	check(not game.help_dialog.visible, "help starts hidden")
	check(not game.settings_overlay.visible, "settings start hidden")
	check_no_persistent_help(game)
	for event_index in range(4):
		game.reset_game(false)
		game.time_paused = false
		game.day = event_index + 3
		game.update_auto_time(game.AUTO_DAY_SECONDS)
		check(not game.latest_event.is_empty(), "event is retained")
		check(game.message_label.text == game.latest_event, "automatic settlement shows only event")
		check("\n" not in game.message_label.text, "daily ledger and migration lines removed")
	game.reset_game(false)
	game.time_paused = true
	game.day = 1
	game.food = 0
	game.wood = 40 # Keep space for a trade so this checks the missing-food case.
	game.maintenance_debt = 100
	game.next_day()
	check(game.latest_event == "商旅经过，但库存不足以交易", "insufficient food event retained")
	check(game.message_label.text == game.latest_event, "debt and departing population do not append a ledger")
	await process_frame
	await process_frame
	await capture("res://qa/ui-simplification/event-only.png")
	game.settings_button.pressed.emit()
	await process_frame
	check(game.settings_overlay.visible, "settings button opens settings")
	var help_button: Button = game.settings_action_buttons["help"]
	check(help_button.is_visible_in_tree(), "help accessible inside settings")
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(game.settings_panel.get_global_rect()), "settings fit viewport")
	help_button.pressed.emit()
	await process_frame
	await process_frame
	check(game.help_dialog.visible, "help opens from menu")
	check(not game.settings_overlay.visible, "settings closes when help opens")
	for term in ["左键", "右键短按", "中键拖动", "右键拖动", "滚轮", "Esc", "删除建筑", "拆除道路"]:
		check(term in game.help_dialog.dialog_text, "help contains " + term)
	await capture("res://qa/ui-simplification/settings-help.png")
	game.help_dialog.get_ok_button().pressed.emit()
	await process_frame
	check(not game.help_dialog.visible, "close button dismisses help")
	game.show_help_from_settings()
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	game._unhandled_input(cancel)
	check(not game.help_dialog.visible, "Escape dismisses help")
	check_no_persistent_help(game)
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.4, true, false, true).timeout
	if failures.is_empty():
		print("DAILY_EVENT_HELP_ACCEPTANCE_OK: 4 automatic daily events, insufficient-food event, no ledger, help hidden by default, settings entry, close/Escape")
	quit(0 if failures.is_empty() else 1)
