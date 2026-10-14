extends SceneTree

const ArtKit = preload("res://godot/ArtAssets.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var assets: Array[Node3D] = []
	for type in ["house", "lumber", "farm", "warehouse", "workshop"]:
		var building := ArtKit.create_building(type)
		if building == null or building.get_meta("building_type", "") != type:
			fail("建筑工厂元数据错误：" + type)
			return
		if count_meshes(building) < 3:
			fail("建筑模型缺少足够部件：" + type)
			return
		if building.scene_file_path.is_empty():
			fail("建筑没有加载独立 GLB：" + type)
			return
		assets.append(building)
	assets.append(ArtKit.create_tree(0))
	assets.append(ArtKit.create_tree(1))
	assets.append(ArtKit.create_tree(2))
	assets.append(ArtKit.create_rock(0))
	assets.append(ArtKit.create_lantern())
	assets.append(ArtKit.create_bridge())
	assets.append(ArtKit.create_crops())
	assets.append(ArtKit.create_citizen(0))
	for asset in assets:
		if asset == null or count_meshes(asset) == 0:
			fail("环境或角色模型加载失败")
			return
		root.add_child(asset)
	var preview := ArtKit.create_building("workshop", true)
	ArtKit.apply_preview_tint(preview, false)
	if count_overrides(preview) != count_meshes(preview):
		fail("嵌套模型预览染色不完整")
		return
	preview.free()
	for asset in assets:
		asset.queue_free()
	assets.clear()
	await process_frame
	print("ASSET_SMOKE_OK: GLB buildings, props, citizen and recursive preview tint")
	quit(0)

func count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += count_meshes(child)
	return count

func count_overrides(node: Node) -> int:
	var count := 1 if node is MeshInstance3D and (node as MeshInstance3D).material_override != null else 0
	for child in node.get_children():
		count += count_overrides(child)
	return count

func fail(message: String) -> void:
	push_error("ASSET_SMOKE_FAILED: " + message)
	quit(1)

