extends SceneTree

const ArtKit = preload("res://godot/RealisticAssets.gd")
const AnimalKit = preload("res://godot/AnimalAssets.gd")
var failures := 0
var maximum_contact_drift := 0.0
var contact_samples := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var roots: Array[Node3D] = []
	var holder := Node3D.new()
	root.add_child(holder)
	for species in ArtKit.get_animal_species():
		for index in range(3):
			var animal := ArtKit.create_animal(species, index)
			if animal == null or animal.get_meta("animal_species", "") != species:
				fail("动物模型或 species 元数据缺失: " + species)
			if count_meshes(animal) < 5:
				fail("动物轮廓部件不足: " + species)
			if animal.get_node_or_null("EyeL") == null or animal.get_node_or_null("Tail") == null:
				fail("动物缺少眼睛或尾部: " + species)
			holder.add_child(animal)
			check_gait(animal, species, 0.48 if index < 2 else 1.0, 0.73 if index == 1 else 0.0)
			roots.append(animal)
	for variant in range(6):
		var citizen := ArtKit.create_citizen_variant(variant, variant)
		if citizen == null or citizen.get_meta("npc_variant", -1) != variant:
			fail("居民变体元数据缺失: %d" % variant)
		if citizen.find_child("CitizenVariant_%02d" % variant, true, false) == null:
			fail("居民变体装饰缺失: %d" % variant)
		roots.append(citizen)
	for root in roots:
		if root.get_parent() == null:
			holder.add_child(root)
	await process_frame
	for root in roots:
		root.queue_free()
	holder.queue_free()
	await process_frame
	print("ANIMAL_ASSET_ACCEPTANCE_%s: species=%d variants=6 models=%d contact_samples=%d max_world_foot_drift=%.8f" % ["OK" if failures == 0 else "FAILED", ArtKit.get_animal_species().size(), roots.size(), contact_samples, maximum_contact_drift])
	quit(0 if failures == 0 else 1)

func check_gait(animal: Node3D, species: String, size: float, heading: float) -> void:
	animal.scale = Vector3.ONE * size
	animal.rotation.y = heading
	var forward := Vector3(sin(heading), 0, cos(heading))
	var stride_world := float(animal.get_meta("gait_stride")) * size
	var limbs: Array = animal.get_meta("gait_limbs")
	var previous := {}
	var max_lift := {}
	var starting_body_y := (animal.get_node("Body") as Node3D).position.y
	var max_body_bob := 0.0
	for frame in range(241):
		var distance := stride_world * float(frame) / 80.0
		animal.position = forward * distance
		AnimalKit.animate_walk(animal, distance)
		max_body_bob = maxf(max_body_bob, absf((animal.get_node("Body") as Node3D).position.y - starting_body_y))
		for limb in limbs:
			var foot := animal.get_node(limb.foot) as Node3D
			var phase := float(foot.get_meta("gait_phase"))
			var contact := bool(foot.get_meta("gait_contact"))
			var lift := foot.position.y - (limb.rest_foot as Vector3).y
			max_lift[limb.foot] = maxf(float(max_lift.get(limb.foot, 0.0)), lift)
			if contact and absf(lift) > 0.00001:
				fail("接地脚悬空: %s %s" % [species, limb.foot])
			if previous.has(limb.foot):
				var prior: Dictionary = previous[limb.foot]
				if contact and prior.contact and phase >= prior.phase:
					var drift := foot.global_position.distance_to(prior.position)
					maximum_contact_drift = maxf(maximum_contact_drift, drift)
					contact_samples += 1
					if drift > 0.00001:
						fail("接地期世界足点滑动: %s %s %.6f" % [species, limb.foot, drift])
			previous[limb.foot] = {"position": foot.global_position, "phase": phase, "contact": contact}
			var upper := animal.get_node(limb.upper) as MeshInstance3D
			var lower := animal.get_node(limb.lower) as MeshInstance3D
			var upper_bottom := upper.position - upper.basis.y * (upper.mesh as CylinderMesh).height * 0.5
			var lower_top := lower.position + lower.basis.y * (lower.mesh as CylinderMesh).height * 0.5
			var lower_bottom := lower.position - lower.basis.y * (lower.mesh as CylinderMesh).height * 0.5
			var expected_ankle := foot.position + Vector3(0, 0.012, -float(limb.heel))
			if upper_bottom.distance_to(lower_top) > 0.00001 or lower_bottom.distance_to(expected_ankle) > 0.00001:
				fail("髋膝足部件脱节: %s %s knee=%.8f ankle=%.8f phase=%.4f" % [species, limb.foot, upper_bottom.distance_to(lower_top), lower_bottom.distance_to(expected_ankle), phase])
	for limb in limbs:
		if float(max_lift.get(limb.foot, 0.0)) < 0.085:
			fail("摆动期抬脚高度不足: %s %s" % [species, limb.foot])
	if max_body_bob < 0.01:
		fail("身体没有随步起伏: " + species)

func count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += count_meshes(child)
	return count

func fail(message: String) -> void:
	failures += 1
	push_error("ANIMAL_ASSET_ACCEPTANCE_FAILED: " + message)
