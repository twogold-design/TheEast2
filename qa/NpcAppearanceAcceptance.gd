extends SceneTree

const ArtKit = preload("res://godot/RealisticAssets.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("NPC_APPEARANCE_FAILED: " + message)

func run() -> void:
	var source := ArtKit.create_citizen(0, false)
	root.add_child(source)
	# Load alternate outfits first to catch accidental changes to shared GLB
	# meshes/materials before measuring the restored original farmer.
	var variants: Array[Node3D] = []
	for kind in [1, 2, 3, 4, 5, 0]:
		var citizen := ArtKit.create_citizen_variant(kind, kind, false)
		root.add_child(citizen)
		variants.append(citizen)
		check(citizen.find_child("MerchantCap", true, false) == null, "red merchant cap must be removed")
		check(citizen.find_child("ChildCap", true, false) == null, "yellow child cap must be removed")
		check(citizen.find_child("FarmerHatBrim", true, false) == null, "do not replace the original straw hat with a cylinder")
	var farmer: Node3D = variants[-1]
	for part_name in ["HatBrim", "HatCrown", "Basket", "BasketHandle"]:
		var part := farmer.find_child(part_name, true, false) as MeshInstance3D
		check(part != null and part.is_visible_in_tree(), "original farmer accessory visible: " + part_name)
	for original in source.find_children("*", "MeshInstance3D", true, false):
		var restored := farmer.get_node_or_null(source.get_path_to(original)) as MeshInstance3D
		check(restored != null, "original mesh retained: " + str(original.name))
		if restored == null:
			continue
		check(restored.mesh == original.mesh, "farmer uses the original textured geometry: " + str(original.name))
		check(restored.material_override == original.material_override, "farmer keeps original outfit material: " + str(original.name))
		check(restored.visible == original.visible and restored.transform.is_equal_approx(original.transform), "farmer keeps original silhouette: " + str(original.name))
	for citizen in variants:
		citizen.queue_free()
	source.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("NPC_APPEARANCE_ACCEPTANCE_OK: original straw hat, basket and outfit preserved; red/yellow caps removed")
	quit(0 if failures.is_empty() else 1)
