extends SceneTree

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	var scene := load("res://godot/Main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.add_building("farm", Vector2i(4, 7), true)
	game.add_building("lumber", Vector2i(14, 7), true)
	game.add_building("warehouse", Vector2i(8, 11), true)
	game.add_building("workshop", Vector2i(11, 11), true)
	game.add_building("house", Vector2i(9, 7), true)
	game.population = 8
	game.update_citizens()
	game.update_ui()
	game.show_message("资产验收：五类建筑、桥梁、灯笼、林区与居民均已接入主场景")
