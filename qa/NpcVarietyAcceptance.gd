extends SceneTree

## Acceptance for the mixed resident and village-animal presentation layer.
## Animals are decorative and must not change the population count or economy.

const EPSILON := 0.0002
class IsolatedGame extends "res://godot/Main.gd":
	func save_game(_show_feedback := true) -> void:
		pass
	func load_game(_show_feedback := true) -> void:
		pass
	func audio_settings_path() -> String:
		return "res://.godot-user/qa/npc-variety-audio.cfg"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := IsolatedGame.new()
	root.add_child(game)
	game.background_music.player.stop()
	game.background_music.player.stream = null
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	game.reset_game(false)
	game.time_paused = true
	game.population = 4
	game.update_citizens(false)
	await process_frame
	await process_frame
	var people: int = game.citizen_root.get_child_count()
	var animals: int = game.animal_root.get_child_count()
	if people != game.population:
		fail("动物层影响居民数量：%d/%d" % [people, game.population])
	if animals < 4:
		fail("初始村落动物数量不足：%d" % animals)
	var resident_variants := {}
	var original_residents := 0
	var resident_identities := {}
	for citizen in game.citizen_root.get_children():
		var visual: Node = citizen.get_node_or_null("Visual")
		var variant := int(visual.get_meta("npc_variant", -1)) if visual else -1
		if variant == 0 and visual:
			original_residents += 1
			var hat := visual.find_child("HatBrim", true, false) as Node3D
			if hat == null or not hat.is_visible_in_tree():
				fail("原版居民缺少可见草帽")
		elif visual == null or (visual.find_child("CitizenVariant_%02d" % variant, true, false) == null and visual.find_child("FemaleOutfit*", true, false) == null):
			fail("居民随机外观缺少实际配件模型")
		resident_variants[variant] = true
		resident_identities[citizen.get_instance_id()] = variant
	if original_residents != 2 or resident_variants.size() != 3:
		fail("开局应有两名原版草帽居民及两种其他外观")
	check_resident_distribution(game)
	var species := {}
	for child in game.animal_root.get_children():
		species[str(child.get_meta("animal_species", ""))] = true
		if child.get_node_or_null("Body") == null:
			fail("动物缺少可见身体模型：%s" % child.name)
		if not child.scale.is_equal_approx(Vector3.ONE * 0.48):
			fail("动物比例没有缩小到村民身高以下")
	if species.size() < 4:
		fail("随机动物种类不足，当前：%s" % str(species.keys()))
	var before_count: int = game.animal_root.get_child_count()
	var first := game.animal_root.get_child(0) as Node3D
	var before := first.position
	game.move_animals(0.20)
	var distance := Vector2(first.position.x - before.x, first.position.z - before.z).length()
	if distance > float(game.ANIMAL_MOVE_SPEED) * 0.20 + EPSILON:
		fail("动物出现瞬时加速：%.4f" % distance)
	if game.animal_root.get_child_count() != before_count:
		fail("动物移动时节点数量发生变化")
	var identities := {}
	for animal in game.animal_root.get_children():
		identities[animal.get_instance_id()] = animal.get_meta("animal_species", "")
	game.update_citizens()
	for citizen in game.citizen_root.get_children():
		var visual: Node = citizen.get_node_or_null("Visual")
		var variant := int(visual.get_meta("npc_variant", -1)) if visual else -1
		if not resident_identities.has(citizen.get_instance_id()) or resident_identities[citizen.get_instance_id()] != variant:
			fail("日常更新重新抽取居民身份")
	for animal in game.animal_root.get_children():
		if not identities.has(animal.get_instance_id()) or identities[animal.get_instance_id()] != animal.get_meta("animal_species", ""):
			fail("日常更新重新抽取动物身份")
	# Force a corner in the next few physics steps so the heading assertion
	# detects the former half-second sideways turn, even on a short run.
	var corner_origin := first.position
	var corner := corner_origin + Vector3(0.025, 0, 0)
	first.set_meta("animal_navigation_path", [corner, corner + Vector3(0, 0, 1.6)])
	first.set_meta("animal_navigation_index", 0)
	first.set_meta("animal_target", corner)
	for tick in range(180):
		var old_positions := {}
		for animal in game.animal_root.get_children():
			old_positions[animal.get_instance_id()] = animal.position
		game.move_animals(1.0 / 60.0)
		for animal in game.animal_root.get_children():
			var travel := float(animal.get_meta("animal_last_travel_distance", 0.0))
			if absf(travel - float(game.ANIMAL_MOVE_SPEED) / 60.0) > EPSILON:
				fail("动物连续漫游没有保持匀速")
				break
			var displacement: Vector3 = animal.position - old_positions[animal.get_instance_id()]
			displacement.y = 0.0
			# A physics step spanning a corner has two directions. When the
			# measured chord equals the distance budget, movement was straight.
			if absf(displacement.length() - travel) < 0.00001 and travel > 0.00001:
				var forward: Vector3 = animal.transform.basis.z.normalized()
				if forward.dot(displacement.normalized()) < 0.999:
					fail("动物模型朝向与实际位移不一致，产生横向滑步")
	var blocked_target: Vector3 = first.get_meta("animal_target", first.position)
	var blocked_cell: Vector2i = game.world_to_grid(blocked_target)
	if blocked_cell != game.world_to_grid(first.position):
		game.add_building("house", blocked_cell, true)
		for animal in game.animal_root.get_children():
			for waypoint in animal.get_meta("animal_navigation_path", []):
				if game.occupied.has(game.world_to_grid(waypoint)):
					fail("新建房屋后动物路径仍穿过占用格")
		game.remove_building_by_id(int(game.occupied[blocked_cell]), false)
	# An entirely blocked route must terminate safely, without recursion or a
	# direct line through water/buildings.
	first.set_meta("animal_route", [game.grid_to_world(Vector2i(9, 9))])
	game.animal_set_target(first)
	if not (first.get_meta("animal_navigation_path", []) as Array).is_empty():
		fail("全阻塞路线没有安全清空")
	if failures.is_empty():
		print("NPC_VARIETY_ACCEPTANCE_OK: residents, chickens, ducks, geese and dogs are present with fixed-speed wandering")
	else:
		push_error("NPC_VARIETY_ACCEPTANCE_FAILED: " + "; ".join(failures))
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.4, true, false, true).timeout
	quit(1 if not failures.is_empty() else 0)

func fail(message: String) -> void:
	failures.append(message)

func check_resident_distribution(game) -> void:
	var preserved_residents: Array = game.citizen_variant_bag.duplicate()
	var preserved_animals: Array = game.animal_species_bag.duplicate()
	var draws := {}
	# Exercise the same draw used by reset_game without rebuilding the entire
	# world or writing a save. Restore both bags before checking live identities.
	for draw in range(6):
		game.prepare_village_life_variants()
		var bag: Array = game.citizen_variant_bag
		draws[str(bag)] = true
		if bag.size() != 50 or bag.count(0) != 30:
			fail("完整村落随机袋应包含60%的原版草帽居民")
		for group in range(5):
			if bag.slice(group * 10, group * 10 + 10).count(0) != 6:
				fail("每10名居民的草帽比例不是6名")
		if bag.slice(0, 4).count(0) != 2:
			fail("新局开场没有保证两名原版草帽居民")
		for variant in range(1, game.CITIZEN_KINDS.size()):
			if bag.count(variant) < 1 or bag.count(variant) > 4:
				fail("其他七种外观没有轮换覆盖，或单种超过原四人配额")
	if draws.size() <= 1:
		fail("新局居民顺序未重新随机")
	game.citizen_variant_bag = preserved_residents
	game.animal_species_bag = preserved_animals

func finish() -> void:
	quit(1 if not failures.is_empty() else 0)
