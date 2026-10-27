extends SceneTree
## Visual-only scene; no player save, audio setup or automatic simulation.
class Game extends "res://godot/Main.gd":
	func _ready() -> void: pass
	func save_game(_feedback := true) -> void: pass
	func load_game(_feedback := true) -> void: pass
	func create_background_music() -> void: pass
	func create_music_settings(_box: VBoxContainer) -> void: pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366,768)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.create_world()
	game.create_ui()
	game.reset_game(false)
	DirAccess.make_dir_recursive_absolute("res://qa/road-surface")
	var target: Vector3 = game.grid_to_world(Vector2i(10,10))
	for size in [22.0,6.0]:
		game.camera.size = size
		game.camera.look_at_from_position(target + Vector3(12,16,14),target)
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		var name := "mud-road-scene" if size > 10 else "mud-road-closeup"
		var result := root.get_texture().get_image().save_png("res://qa/road-surface/" + name + ".png")
		if result != OK:
			push_error("Road render capture failed")
			quit(1)
			return
	game.queue_free()
	await process_frame
	print("MUD_ROAD_RENDER_OK")
	quit()
