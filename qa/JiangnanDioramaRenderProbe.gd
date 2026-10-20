extends SceneTree

const OUTPUT_PATH := "res://qa/assets-upgrade/jiangnan-diorama.png"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1366, 768)
	var packed := load("res://godot/JiangnanStyleGallery.tscn") as PackedScene
	if packed == null:
		push_error("JIANGNAN_DIORAMA_RENDER_FAILED: gallery scene missing")
		quit(1)
		return
	var gallery := packed.instantiate()
	root.add_child(gallery)
	await process_frame
	await process_frame
	await process_frame
	var image := get_root().get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("JIANGNAN_DIORAMA_RENDER_FAILED: empty viewport")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/assets-upgrade"))
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("JIANGNAN_DIORAMA_RENDER_FAILED: cannot save preview")
		quit(1)
		return
	print("JIANGNAN_DIORAMA_RENDER_OK")
	quit(0)
