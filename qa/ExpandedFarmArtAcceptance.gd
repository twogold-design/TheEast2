extends SceneTree

const Assets = preload("res://godot/RealisticAssets.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var source_path := Assets.expected_path("building.farm")
	var original_hash := FileAccess.get_sha256(source_path)
	var farm := Assets.create_building("farm", false, false)
	var preview := Assets.create_building("farm", true, false)
	var original := Assets.create_asset("building.farm", false, false)
	var legacy := Assets.create_building("farm", false, false, false, Vector2i(2, 1))
	for model in [farm, preview, original, legacy]:
		root.add_child(model)
	await process_frame
	check(farm.get_meta("footprint_cells") == Vector2i(2, 2), "new farm covers four cells")
	check(legacy.get_meta("footprint_cells") == Vector2i(2, 1), "old two-cell farm retains its shape")
	check(farm.get_meta("asset_source") == "composed_farm", "new farm factory active")
	var original_rows := original.find_children("SoilRidge*", "MeshInstance3D", true, false).size()
	check(farm.find_children("SoilRidge*", "MeshInstance3D", true, false).size() == original_rows * 4, "four plots of real soil/crop rows rather than stretched plants")
	check(legacy.find_children("SoilRidge*", "MeshInstance3D", true, false).size() == original_rows * 2, "legacy field retains two plots of rows")
	check(farm.find_children("ScarecrowHatBrim*", "MeshInstance3D", true, false).size() == 1, "one original scarecrow retained")
	check(farm.find_children("FarmPlot*", "MeshInstance3D", true, false).size() == 1, "continuous single soil base avoids overlap")
	for part in farm.find_children("*", "MeshInstance3D", true, false):
		var relative: Transform3D = farm.global_transform.affine_inverse() * part.global_transform
		var bounds: AABB = relative * part.mesh.get_aabb()
		check(bounds.position.x >= -2.2 and bounds.end.x <= 2.2 and bounds.position.z >= -2.2 and bounds.end.z <= 2.2, "mesh within 2x2 footprint: " + str(part.name))
		for surface in range(part.mesh.get_surface_count()):
			check(part.get_active_material(surface) != null, "valid material: " + str(part.name))
	check(preview.find_children("*", "CollisionObject3D", true, false).is_empty(), "preview without collision")
	check(farm.find_child("AssetCollision", true, false) != null, "built farm has collision")
	check((farm.get_node("Door") as Node3D).position.z > 2.0, "door moved to expanded field edge")
	check((legacy.get_node("Door") as Node3D).position.z < 1.1, "legacy doorway stays at original edge")
	check(FileAccess.get_sha256(source_path) == original_hash, "original GLB unchanged")
	for model in [farm, preview, original, legacy]:
		model.free()
	await process_frame
	await process_frame
	print("EXPANDED_FARM_ART_OK: four-cell field, four crop plots, legacy two-cell shape, one scarecrow, footprint/materials/preview, unchanged original" if failures.is_empty() else "EXPANDED_FARM_ART_FAILED")
	quit(0 if failures.is_empty() else 1)
