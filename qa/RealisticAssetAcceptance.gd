extends SceneTree

## Strict acceptance for the restored v1 realistic pack. Every registered model
## must exist, instantiate without fallback, expose a material on every mesh
## surface, and release its scene instance cleanly before the test exits. The five
## buildings must also carry distinct top-view roof identities backed by a visible
## GLB marker, so visually similar structures cannot regress to the same roof.

const RealisticKit = preload("res://godot/RealisticAssets.gd")
const EXPECTED_ASSET_COUNT := 15
const BUILDING_ROOF_IDENTITIES := {
	"building.house": "tile_gable_red_brackets",
	"building.lumber": "tile_gable_timber_battens",
	"building.farm": "roofless_field_scarecrow",
	"building.warehouse": "tile_gable_twin_vents",
	"building.workshop": "tile_gable_chimney",
}
const BUILDING_ROOF_MARKERS := {
	"building.house": "RoofIdentity_HouseBrackets",
	"building.lumber": "RoofIdentity_TimberBatten",
	"building.farm": "RoofIdentity_FieldScarecrow",
	"building.warehouse": "RoofIdentity_WarehouseVent",
	"building.workshop": "RoofIdentity_WorkshopChimney",
}

var assets: Array[Node3D] = []
var tracked_instances: Array[WeakRef] = []
var checked_meshes := 0
var checked_surfaces := 0
var failure_message := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var initial_root_children := root.get_child_count()
	var status := RealisticKit.get_status()
	var manifest := RealisticKit.read_manifest()
	var manifest_entries: Array = manifest.get("assets", [])
	var manifest_assets := index_manifest_buildings(manifest_entries)
	if RealisticKit.ASSETS.size() != EXPECTED_ASSET_COUNT:
		fail("写实资源注册表应包含 %d 项，实际为 %d 项" % [EXPECTED_ASSET_COUNT, RealisticKit.ASSETS.size()])
	elif int(status.get("expected", 0)) != EXPECTED_ASSET_COUNT:
		fail("写实资源状态中的预期数量不是 %d 项" % EXPECTED_ASSET_COUNT)
	elif status.get("available", []).size() != EXPECTED_ASSET_COUNT:
		fail("写实资源可用数量不足 %d 项" % EXPECTED_ASSET_COUNT)
	elif not status.get("missing", []).is_empty():
		fail("写实资源仍有缺失项：%s" % ", ".join(status.get("missing", [])))
	elif manifest_entries.size() != EXPECTED_ASSET_COUNT:
		fail("写实资源 manifest 项数异常：%d/%d" % [manifest_entries.size(), EXPECTED_ASSET_COUNT])
	elif manifest_assets.size() != BUILDING_ROOF_IDENTITIES.size():
		fail("写实资源 manifest 建筑项数异常：%d/%d" % [manifest_assets.size(), BUILDING_ROOF_IDENTITIES.size()])

	if failure_message.is_empty():
		var keys: Array = RealisticKit.ASSETS.keys()
		keys.sort()
		for key_value in keys:
			var key := str(key_value)
			var path := RealisticKit.expected_path(key)
			if path.is_empty() or not ResourceLoader.exists(path):
				fail("写实资源文件不存在：%s (%s)" % [key, path])
				break
			var asset := RealisticKit.create_asset(key, false, false)
			if asset == null:
				fail("写实资源无法严格实例化：" + key)
				break
			root.add_child(asset)
			assets.append(asset)
			tracked_instances.append(weakref(asset))
			if str(asset.get_meta("asset_source", "")) != "realistic":
				fail("资源实例没有来自 realistic：" + key)
				break
			if str(asset.get_meta("asset_key", "")) != key:
				fail("资源实例键不匹配：" + key)
				break
			if key.begins_with("building.") and not inspect_roof_identity(asset, key, manifest_assets):
				break
			var meshes_before := checked_meshes
			if not inspect_materials(asset, key):
				break
			if checked_meshes == meshes_before:
				fail("写实资源没有可渲染网格：" + key)
				break

	if failure_message.is_empty() and assets.size() != EXPECTED_ASSET_COUNT:
		fail("写实资源没有全部实例化，实际为 %d/%d 项" % [assets.size(), EXPECTED_ASSET_COUNT])
	if failure_message.is_empty() and (checked_meshes == 0 or checked_surfaces == 0):
		fail("写实资源没有可验收的网格表面")
	if failure_message.is_empty():
		inspect_roof_identity_set()

	await finish(initial_root_children)

func index_manifest_buildings(entries: Array) -> Dictionary:
	var indexed := {}
	for value in entries:
		if value is not Dictionary:
			continue
		var entry := value as Dictionary
		if str(entry.get("asset_type", "")) != "building":
			continue
		var fallback_key := str(entry.get("fallback_key", ""))
		if fallback_key.is_empty():
			continue
		indexed["building.%s" % fallback_key] = entry
	return indexed

func inspect_roof_identity(asset: Node3D, key: String, manifest_assets: Dictionary) -> bool:
	if not BUILDING_ROOF_IDENTITIES.has(key):
		fail("建筑没有登记屋顶识别契约：" + key)
		return false
	if not manifest_assets.has(key):
		fail("manifest 缺少建筑记录：" + key)
		return false
	var expected_identity := str(BUILDING_ROOF_IDENTITIES[key])
	var manifest_entry := manifest_assets[key] as Dictionary
	var manifest_identity := str(manifest_entry.get("roof_identity", ""))
	var glb_path := "%s/%s" % [RealisticKit.BASE_DIR, str(manifest_entry.get("file", ""))]
	var glb_extras := read_glb_root_extras(glb_path, str(manifest_entry.get("root", "")))
	var runtime_identity := str(glb_extras.get("roof_identity", ""))
	if manifest_identity != expected_identity:
		fail("%s 的 manifest roof_identity 不符合约定：%s" % [key, manifest_identity])
		return false
	if runtime_identity != expected_identity:
		fail("%s 的原始 GLB 根节点 roof_identity 不符合约定：%s" % [key, runtime_identity])
		return false
	var marker_name := str(manifest_entry.get("roof_marker", ""))
	var runtime_marker := str(glb_extras.get("roof_marker", ""))
	var expected_marker := str(BUILDING_ROOF_MARKERS.get(key, ""))
	if marker_name != expected_marker or not marker_name.begins_with("RoofIdentity_"):
		fail("%s 的 manifest roof_marker 不符合约定：%s" % [key, marker_name])
		return false
	if runtime_marker != marker_name:
		fail("%s 的原始 GLB roof_marker 与 manifest 不一致" % key)
		return false
	var marker := asset.find_child(marker_name, true, false)
	if marker == null:
		fail("%s 的 GLB 缺少屋顶差异件：%s" % [key, marker_name])
		return false
	if count_meshes(marker) == 0:
		fail("%s 的屋顶差异件没有可见网格：%s" % [key, marker_name])
		return false
	return true

func read_glb_root_extras(path: String, root_name: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	# GLB 2.0 header: magic, version and total length, followed by chunks.
	if file.get_length() < 20 or file.get_32() != 0x46546C67 or file.get_32() != 2:
		file.close()
		return {}
	var declared_length := file.get_32()
	var safe_length := mini(declared_length, file.get_length())
	while file.get_position() + 8 <= safe_length:
		var chunk_length := file.get_32()
		var chunk_type := file.get_32()
		if chunk_length > safe_length - file.get_position():
			file.close()
			return {}
		var chunk := file.get_buffer(chunk_length)
		if chunk_type != 0x4E4F534A:
			continue
		file.close()
		var document = JSON.parse_string(chunk.get_string_from_utf8())
		if document is not Dictionary:
			return {}
		var nodes: Array = (document as Dictionary).get("nodes", [])
		for value in nodes:
			if value is not Dictionary:
				continue
			var node := value as Dictionary
			if str(node.get("name", "")) != root_name:
				continue
			var extras = node.get("extras", {})
			return extras as Dictionary if extras is Dictionary else {}
		return {}
	file.close()
	return {}

func inspect_roof_identity_set() -> bool:
	var identities := {}
	var markers := {}
	for key_value in BUILDING_ROOF_IDENTITIES.keys():
		var key := str(key_value)
		var identity := str(BUILDING_ROOF_IDENTITIES[key])
		if identity.is_empty() or identities.has(identity):
			fail("五类建筑的 roof_identity 必须全部可区分：%s" % identity)
			return false
		identities[identity] = key
		var marker_name := str(BUILDING_ROOF_MARKERS.get(key, ""))
		if marker_name.is_empty() or markers.has(marker_name):
			fail("五类建筑的 roof_marker 必须全部可区分：%s" % marker_name)
			return false
		markers[marker_name] = key
	if BUILDING_ROOF_IDENTITIES["building.lumber"] == BUILDING_ROOF_IDENTITIES["building.warehouse"]:
		fail("伐木场与仓库的 roof_identity 不得相同")
		return false
	return true

func count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += count_meshes(child)
	return count

func inspect_materials(node: Node, key: String) -> bool:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			fail("%s 的网格节点 %s 没有 Mesh" % [key, mesh_instance.name])
			return false
		checked_meshes += 1
		var surface_count := mesh_instance.mesh.get_surface_count()
		if surface_count == 0:
			fail("%s 的网格节点 %s 没有表面" % [key, mesh_instance.name])
			return false
		for surface in range(surface_count):
			checked_surfaces += 1
			if mesh_instance.mesh.surface_get_material(surface) == null:
				fail("%s 的网格节点 %s 表面 %d 缺少材质" % [key, mesh_instance.name, surface])
				return false
	for child in node.get_children():
		if not inspect_materials(child, key):
			return false
	return true

func fail(message: String) -> void:
	if failure_message.is_empty():
		failure_message = message

func finish(initial_root_children: int) -> void:
	for asset in assets:
		if is_instance_valid(asset):
			asset.queue_free()
	assets.clear()
	await process_frame
	await process_frame
	await process_frame
	for reference in tracked_instances:
		if reference.get_ref() != null:
			fail("写实资源实例未释放干净")
			break
	tracked_instances.clear()
	if root.get_child_count() != initial_root_children:
		fail("验收结束后场景树仍残留写实资源节点")
	if not failure_message.is_empty():
		push_error("REALISTIC_ASSET_ACCEPTANCE_FAILED: " + failure_message)
		quit(1)
		return
	print("REALISTIC_ASSET_ACCEPTANCE_OK: assets=%d roofs=%d meshes=%d surfaces=%d released=true" % [EXPECTED_ASSET_COUNT, BUILDING_ROOF_IDENTITIES.size(), checked_meshes, checked_surfaces])
	quit(0)
