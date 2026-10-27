extends Node
## Browser lifecycle only. No remote service, desktop-save migration or test API.
var game: Node
var _visibility_callback: JavaScriptObject
var _pause_callback: JavaScriptObject
var _autosave_elapsed := 0.0

func _ready() -> void:
	_visibility_callback = JavaScriptBridge.create_callback(_on_visibility)
	_pause_callback = JavaScriptBridge.create_callback(_on_pause)
	var document = JavaScriptBridge.get_interface("document")
	document.addEventListener("visibilitychange", _visibility_callback)
	document.addEventListener("east-pause", _pause_callback)
	await get_tree().process_frame
	JavaScriptBridge.eval("window.eastGameReady=true; document.dispatchEvent(new Event('east-ready'));",true)
	if not OS.is_userfs_persistent():
		game.show_message("浏览器未允许保存进度，请使用普通窗口并允许网站存储。")

func _process(delta: float) -> void:
	_autosave_elapsed += delta
	if _autosave_elapsed >= 15.0:
		_autosave_elapsed = 0.0
		game.save_game(false)

func _on_visibility(_args: Array) -> void:
	if JavaScriptBridge.get_interface("document").hidden:
		_on_pause([])

func _on_pause(_args: Array) -> void:
	game.time_paused = true
	game.save_game(false)
	game.update_ui()

func _exit_tree() -> void:
	var document = JavaScriptBridge.get_interface("document")
	document.removeEventListener("visibilitychange",_visibility_callback)
	document.removeEventListener("east-pause",_pause_callback)
