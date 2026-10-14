extends SceneTree

const RealisticKit = preload("res://godot/RealisticAssets.gd")
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var status := RealisticKit.get_status()
	if int(status.expected) != RealisticKit.ASSETS.size():
		fail("资产状态统计不一致")
		return
	var manifest := RealisticKit.read_manifest()
	if str(manifest.get("tier", "")) != "realistic_full_v1" or int(manifest.get("art_version", 0)) != 2 or float(manifest.get("tile_meters", 0.0)) != 2.0:
		fail("完整写实 manifest 缺失或版本、尺度契约错误")
		return
	var manifest_assets: Array = manifest.get("assets", [])
	if manifest_assets.size() != 15:
		fail("manifest 必须登记完整 15 项写实资源")
		return
	if status.available.size() != 15 or not status.missing.is_empty():
		fail("完整写实资源包必须为 available=15、missing=0")
		return
	for required_key in RealisticKit.ASSETS.keys():
		if not RealisticKit.has_realistic_asset(required_key):
			fail("必需写实资源缺失：" + required_key)
			return
	var created: Array[Node3D] = []
	for key in RealisticKit.ASSETS.keys():
		var asset := RealisticKit.create_asset(key, false, false)
		if asset == null:
			fail("严格加载失败：" + key)
			return
		if asset.get_meta("asset_key", "") != key:
			fail("资源键元数据错误：" + key)
			return
		var source := str(asset.get_meta("asset_source", ""))
		if source != "realistic":
			fail("资源未从 realistic/models 加载：" + key)
			return
		if count_meshes(asset) == 0:
			fail("资源没有可渲染网格：" + key)
			return
		if key.begins_with("building."):
			if asset.find_child("Door", true, false) == null:
				fail("建筑缺少门点：" + key)
				return
			if asset.find_child("AssetCollision", true, false) == null:
				var child_names: Array[String] = []
				for child in asset.get_children():
					child_names.append(child.name)
				fail("建筑缺少碰撞体：%s；根节点子项=%s" % [key, ",".join(child_names)])
				return
		elif key == "prop.bridge" and asset.find_child("BridgeDeckCollision", true, false) == null:
			fail("木桥缺少桥面碰撞体")
			return
		root.add_child(asset)
		created.append(asset)
	var gallery_scene := load("res://godot/RealisticGallery.tscn") as PackedScene
	if gallery_scene == null:
		fail("写实资产展厅场景无法加载")
		return
	var gallery := gallery_scene.instantiate()
	root.add_child(gallery)
	await process_frame
	var collection := gallery.get_node_or_null("AssetCollection")
	if collection == null:
		fail("写实资产展厅没有创建资产集合")
		return
	var gallery_sources := count_gallery_sources(collection)
	if gallery_sources.fallback != 0:
		fail("写实展厅错误陈列了低多边形回退")
		return
	if gallery_sources.realistic != status.available.size():
		fail("写实展厅陈列数量与 available 状态不一致")
		return
	for asset in created:
		asset.queue_free()
	created.clear()
	gallery.queue_free()
	await process_frame
	print("REALISTIC_ASSET_SMOKE_OK: available=%d missing=%d all_sources=realistic" % [status.available.size(), status.missing.size()])
	quit(0)

func count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += count_meshes(child)
	return count

func count_gallery_sources(node: Node) -> Dictionary:
	var result := {"realistic": 0, "fallback": 0}
	var source := str(node.get_meta("asset_source", ""))
	if source == "realistic":
		result.realistic += 1
	elif source == "fallback":
		result.fallback += 1
	for child in node.get_children():
		var nested := count_gallery_sources(child)
		result.realistic += nested.realistic
		result.fallback += nested.fallback
	return result

func fail(message: String) -> void:
	push_error("REALISTIC_ASSET_SMOKE_FAILED: " + message)
	quit(1)

