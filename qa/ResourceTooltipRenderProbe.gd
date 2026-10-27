extends SceneTree
## Actual Main layout with isolated simulation; no save/settings access.
class Game extends "res://godot/Main.gd":
	func _ready() -> void: pass
	func save_game(_feedback := true) -> void: pass
	func load_game(_feedback := true) -> void: pass
	func create_background_music() -> void: pass
	func create_music_settings(_box: VBoxContainer) -> void: pass

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366,768)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.create_world()
	game.create_ui()
	game.reset_game(false)
	game.map_region_level = 1
	game.economy.set_unlock_level(1)
	game.economy.apply_resources({"cloth":-12})
	game.economy.advance(60)
	game.refresh_economy_snapshot()
	game.update_ui()
	DirAccess.make_dir_recursive_absolute("res://qa/resource-tooltips")
	await process_frame
	for resource in ["幸福度","衣物","人口"]:
		var motion := InputEventMouseMotion.new()
		motion.position = game.status_label.global_position + game.status_label.resource_text_bounds(resource).get_center()
		root.push_input(motion)
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png("res://qa/resource-tooltips/" + resource + ".png")
		if result != OK:
			push_error("Resource tooltip capture failed")
			quit(1)
			return
	game.queue_free()
	await process_frame
	print("RESOURCE_TOOLTIP_RENDER_OK")
	quit()
