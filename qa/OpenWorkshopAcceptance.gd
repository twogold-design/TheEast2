extends SceneTree

const ArtKit = preload("res://godot/RealisticAssets.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("OPEN_WORKSHOP_FAILED: " + message)

func visible_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in node.find_children("*", "MeshInstance3D", true, false):
		if child.is_visible_in_tree() and child.mesh != null:
			result.append(child)
	return result

func run() -> void:
	# Asset-only fixture: never loads, saves, or simulates the player's game.
	var workshop := ArtKit.create_building("workshop", false, false)
	var preview := ArtKit.create_building("workshop", true, false)
	var compact := ArtKit.create_building("workshop", false, false, true)
	var academy := ArtKit.create_building("academy", false, false)
	var original := ArtKit.create_asset("building.workshop", false, false)
	for model in [workshop, preview, compact, academy, original]:
		root.add_child(model)
	await process_frame
	check(workshop.get_meta("building_type", "") == "workshop", "workshop keeps its gameplay type")
	check(workshop.get_meta("asset_source", "") == "composed_workshop", "source identifies the redesigned model")
	check(workshop.get_meta("roof_identity", "") == "tile_gable_chimney", "retains workshop roof identity")
	check(workshop.get_meta("roof_marker", "") == "RoofIdentity_WorkshopChimney", "roof marker metadata points to the chimney")
	for part in ["OpenRearHall", "OpenWorkCourt", "WorkBench", "AnvilBody", "ToolRack", "RoofIdentity_WorkshopChimney", "WorkshopArtisan"]:
		var node := workshop.find_child(part, true, false) as Node3D
		check(node != null and node.is_visible_in_tree(), "visible workshop identity: " + part)
	for closed_part in ["WorkshopWalls", "WorkshopDoor"]:
		var node := workshop.find_child(closed_part, true, false) as Node3D
		check(node == null or not node.is_visible_in_tree(), "closed original facade removed: " + closed_part)
		var retained := original.find_child(closed_part, true, false) as Node3D
		check(retained != null and retained.is_visible_in_tree(), "original asset is untouched: " + closed_part)
	check(academy.find_child("OpenRearHall", true, false) == null, "academy keeps its original building base")
	check(workshop.find_child("AssetCollision", true, false) != null, "built workshop retains collision")
	check(preview.find_children("*", "CollisionObject3D", true, false).is_empty(), "placement preview has no collision")
	var mesh_count := 0
	var textured_count := 0
	for mesh in visible_meshes(workshop):
		# Skinned citizen bounds are in bind space; test the static architecture.
		if mesh.skin == null:
			var relative := workshop.global_transform.affine_inverse() * mesh.global_transform
			var bounds: AABB = relative * mesh.mesh.get_aabb()
			check(bounds.position.x >= -2.141 and bounds.end.x <= 2.141 and bounds.position.z >= -2.141 and bounds.end.z <= 2.141, "geometry stays in two-by-two courtyard: " + str(mesh.name))
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface)
			check(material != null, "every visible mesh has a valid material")
			if material is StandardMaterial3D and material.albedo_texture != null:
				textured_count += 1
		mesh_count += 1
	check(mesh_count > 40 and textured_count > 20, "preserves detailed textured architecture")
	check(workshop.get_meta("footprint_cells") == Vector2i(2, 2), "new workshop takes four cells")
	check(compact.get_meta("footprint_cells") == Vector2i.ONE, "legacy workshop remains one cell")
	for mesh in visible_meshes(compact):
		if mesh.skin == null:
			var bounds: AABB = (compact.global_transform.affine_inverse() * mesh.global_transform) * mesh.mesh.get_aabb()
			check(bounds.position.x >= -1.101 and bounds.end.x <= 1.101 and bounds.position.z >= -1.101 and bounds.end.z <= 1.101, "legacy workshop retains original footprint")
	var door := workshop.find_child("Door", true, false) as Node3D
	check(door != null, "navigation entrance remains available")
	if door:
		var entry := workshop.to_local(door.global_position)
		check(entry.z + 0.26 > 2.2, "walking destination remains outside occupied courtyard")
	var artisan := workshop.find_child("WorkshopArtisan", true, false) as Node3D
	var activity := artisan.get_node_or_null("WorkshopActivity") if artisan else null
	check(activity != null, "craftsperson has a production gesture controller")
	if activity:
		activity.set_process(false)
		var skeleton: Skeleton3D = activity.skeleton
		var upper := skeleton.find_bone("UpperArm.L")
		var leg := skeleton.find_bone("Leg.L")
		activity.sample(0.0)
		var arm_start := skeleton.get_bone_pose_rotation(upper)
		var planted := skeleton.get_bone_global_pose(leg)
		var max_motion := 0.0
		for frame in range(80):
			activity.sample(frame * 0.20)
			max_motion = maxf(max_motion, arm_start.angle_to(skeleton.get_bone_pose_rotation(upper)))
			check(skeleton.get_bone_global_pose(leg).origin.distance_to(planted.origin) < 0.0001, "craftsperson feet stay planted")
		check(max_motion > 0.20, "craftsperson visibly works with arms")
	var preview_actor := preview.find_child("WorkshopArtisan", true, false)
	if preview_actor:
		var preview_activity := preview_actor.get_node_or_null("WorkshopActivity")
		check(preview_activity != null and not preview_activity.is_processing(), "placement preview stays still")
	for mesh in visible_meshes(preview):
		check(mesh.material_override is StandardMaterial3D and mesh.material_override.albedo_color.a < 1.0, "placement tint covers all visible details")
	for model in [workshop, preview, compact, academy, original]:
		model.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("OPEN_WORKSHOP_ACCEPTANCE_OK: expanded four-cell workcourt, legacy one-cell compatibility, preserved originals, animated artisan, static tinted preview")
	quit(0 if failures.is_empty() else 1)
