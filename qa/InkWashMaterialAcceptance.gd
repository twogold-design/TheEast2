extends SceneTree

const InkWashKit = preload("res://godot/InkWashAssets.gd")

var checked_meshes := 0
var checked_surfaces := 0
var assets: Array[Node3D] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assets = [
		InkWashKit.create_building("house"),
		InkWashKit.create_building("lumber"),
		InkWashKit.create_building("farm"),
		InkWashKit.create_building("warehouse"),
		InkWashKit.create_building("workshop"),
		InkWashKit.create_tree(0),
		InkWashKit.create_tree(1),
		InkWashKit.create_tree(2),
		InkWashKit.create_rock(0),
		InkWashKit.create_rock(1),
		InkWashKit.create_rock(2),
		InkWashKit.create_lantern(),
		InkWashKit.create_bridge(),
		InkWashKit.create_citizen(0),
	]
	for asset in assets:
		if asset == null:
			fail("水墨资源实例化失败")
			await finish(1)
			return
	for asset in assets:
		if not inspect_materials(asset):
			await finish(1)
			return
	if checked_meshes == 0 or checked_surfaces == 0:
		fail("水墨资源没有可验证的网格表面")
		await finish(1)
		return
	print("INK_WASH_MATERIAL_ACCEPTANCE_OK: meshes=%d surfaces=%d" % [checked_meshes, checked_surfaces])
	await finish(0)

func inspect_materials(node: Node) -> bool:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			checked_meshes += 1
			for surface in range(mesh_instance.mesh.get_surface_count()):
				checked_surfaces += 1
				if mesh_instance.mesh.surface_get_material(surface) == null:
					fail("%s 的表面 %d 缺少水墨材质" % [mesh_instance.name, surface])
					return false
	for child in node.get_children():
		if not inspect_materials(child):
			return false
	return true

func fail(message: String) -> void:
	push_error("INK_WASH_MATERIAL_ACCEPTANCE_FAILED: " + message)

func finish(exit_code: int) -> void:
	for asset in assets:
		if is_instance_valid(asset):
			asset.free()
	assets.clear()
	await process_frame
	await process_frame
	await process_frame
	quit(exit_code)
