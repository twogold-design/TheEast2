class_name RealisticAssets
extends RefCounted

## Independent high-detail asset registry. The low-poly ArtAssets kit is used only
## as an explicit fallback and the returned root always records its source.

const ArtKit = preload("res://godot/ArtAssets.gd")
const AnimalKit = preload("res://godot/AnimalAssets.gd")
const OpenMarketKit = preload("res://godot/OpenMarketAssets.gd")
const MarketActivityKit = preload("res://godot/MarketCharacterAnimation.gd")
const LumberActivityKit = preload("res://godot/LumberCharacterAnimation.gd")
const OpenWorkshopKit = preload("res://godot/OpenWorkshopAssets.gd")
const OpenClinicKit = preload("res://godot/OpenClinicAssets.gd")
const OpenWarehouseKit = preload("res://godot/OpenWarehouseAssets.gd")
const FishpondKit = preload("res://godot/FishpondAssets.gd")
const ExpandedBuildingKit = preload("res://godot/ExpandedBuildingAssets.gd")
const ExpandedIndustryKit = preload("res://godot/ExpandedIndustryAssets.gd")
const BASE_DIR := "res://godot/assets/realistic/models"
const MANIFEST_PATH := BASE_DIR + "/realistic_manifest.json"

const ASSETS := {
	"building.house": {"file": "building_house.glb", "fallback": "house", "bounds": Vector3(1.70, 1.85, 1.65)},
	"building.lumber": {"file": "building_lumber.glb", "fallback": "lumber", "bounds": Vector3(1.82, 1.72, 1.72)},
	"building.farm": {"file": "building_farm.glb", "fallback": "farm", "bounds": Vector3(1.72, 1.28, 1.72)},
	"building.warehouse": {"file": "building_warehouse.glb", "fallback": "warehouse", "bounds": Vector3(1.82, 2.12, 1.82)},
	"building.workshop": {"file": "building_workshop.glb", "fallback": "workshop", "bounds": Vector3(1.78, 2.22, 1.72)},
	"prop.bridge": {"file": "prop_bridge.glb", "fallback": "bridge", "bounds": Vector3(4.0, 1.05, 1.42)},
	"prop.tree.01": {"file": "prop_tree_01.glb", "fallback": "tree", "variant": 0},
	"prop.tree.02": {"file": "prop_tree_02.glb", "fallback": "tree", "variant": 1},
	"prop.tree.03": {"file": "prop_tree_03.glb", "fallback": "tree", "variant": 2},
	"prop.rock.01": {"file": "prop_rock_01.glb", "fallback": "rock", "variant": 0},
	"prop.rock.02": {"file": "prop_rock_02.glb", "fallback": "rock", "variant": 1},
	"prop.rock.03": {"file": "prop_rock_03.glb", "fallback": "rock", "variant": 2},
	"prop.lantern": {"file": "prop_lantern.glb", "fallback": "lantern"},
	"prop.crops": {"file": "prop_crops.glb", "fallback": "crops"},
	"character.citizen": {"file": "character_citizen.glb", "fallback": "citizen", "variant": 0},
}

static var _packed_scenes: Dictionary = {}
static var _warned_missing: Dictionary = {}

static func expected_path(key: String) -> String:
	if not ASSETS.has(key):
		return ""
	return "%s/%s" % [BASE_DIR, ASSETS[key].file]

static func has_realistic_asset(key: String) -> bool:
	var path := expected_path(key)
	return not path.is_empty() and ResourceLoader.exists(path)

static func get_missing_keys() -> Array[String]:
	var missing: Array[String] = []
	for key in ASSETS.keys():
		if not has_realistic_asset(key):
			missing.append(key)
	missing.sort()
	return missing

static func get_status() -> Dictionary:
	var available: Array[String] = []
	var missing := get_missing_keys()
	for key in ASSETS.keys():
		if key not in missing:
			available.append(key)
	available.sort()
	return {
		"base_dir": BASE_DIR,
		"manifest_exists": FileAccess.file_exists(MANIFEST_PATH),
		"expected": ASSETS.size(),
		"available": available,
		"missing": missing,
	}

static func create_asset(key: String, preview := false, allow_fallback := true, variant := 0) -> Node3D:
	if not ASSETS.has(key):
		push_error("RealisticAssets: unknown asset key '%s'" % key)
		return null
	var path := expected_path(key)
	var imported := _instantiate(path)
	if imported:
		_configure_root(imported, key, "realistic", path, preview)
		return imported
	if not allow_fallback:
		push_error("RealisticAssets: required model is missing: %s (%s)" % [key, path])
		return null
	if not _warned_missing.has(key):
		push_warning("RealisticAssets: %s is missing at %s; using low-poly fallback." % [key, path])
		_warned_missing[key] = true
	var fallback := _create_fallback(key, preview, variant)
	if fallback:
		_configure_root(fallback, key, "fallback", path, preview)
	return fallback

static func create_building(type: String, preview := false, allow_fallback := true, compact := false, farm_cells := Vector2i(2, 2)) -> Node3D:
	if type in ExpandedIndustryKit.TYPES:
		var industry := ExpandedIndustryKit.create_building(type, preview)
		if type not in ["garden", "pavilion"]:
			var worker := create_citizen_variant(210 + ExpandedIndustryKit.TYPES.find(type), 6 if type in ["tea_farm", "teahouse", "papermill"] else 0, allow_fallback)
			if worker:
				worker.name = "WorkingResident"
				worker.scale = Vector3.ONE * 0.44
				worker.position = industry.get_node("ArtisanAnchor").position
				industry.add_child(worker)
				MarketActivityKit.attach(worker, "vendor", 2, preview)
		if preview:
			apply_preview_tint(industry, true)
		return industry
	if (not compact or type == "well") and type in ["lumber", "workshop", "warehouse", "market", "fishpond", "weaver", "academy", "well"]:
		var source: Node3D = null
		if type in ["workshop", "warehouse", "weaver", "academy"]:
			source = create_asset("building.warehouse" if type == "warehouse" else "building.workshop", false, allow_fallback)
			if source == null:
				return null
		var expanded := ExpandedBuildingKit.create_building(type, preview, source)
		if type in ["workshop", "weaver", "lumber"]:
			var worker := create_citizen_variant(200, 0 if type == "lumber" else (6 if type == "weaver" else 1), allow_fallback)
			if worker:
				worker.name = "WorkshopArtisan" if type == "workshop" else "WorkingResident"
				worker.scale = Vector3.ONE * 0.44
				worker.position = expanded.get_node("ArtisanAnchor").position
				expanded.add_child(worker)
				if type == "lumber":
					LumberActivityKit.attach(worker, expanded, preview)
				else:
					var activity := MarketActivityKit.attach(worker, "workshop" if type == "workshop" else "vendor", 0, preview)
					if type == "workshop":
						activity.attach_workshop_hammer()
		if type == "market":
			for i in range(6):
				var vendor := create_citizen_variant(100 + i, [0, 3, 6, 1, 0, 7][i], allow_fallback)
				if vendor:
					vendor.name = "MarketVendor_%d" % i
					vendor.scale = Vector3.ONE * 0.48
					vendor.position = expanded.get_node("VendorAnchor_%d" % i).position
					vendor.rotation.y = (PI / 2 if i < 2 else -PI / 2) if i < 4 else 0.0
					expanded.add_child(vendor)
					MarketActivityKit.attach(vendor, "vendor", i, preview)
			for i in range(2):
				var visitor := create_citizen_variant(110 + i, [4, 6][i], allow_fallback)
				if visitor:
					visitor.name = "MarketCustomer_%d" % i
					visitor.scale = Vector3.ONE * 0.48
					visitor.position = Vector3(-0.18 if i == 0 else 0.18, 0.28, -0.8 if i == 0 else 1.0)
					expanded.add_child(visitor)
					MarketActivityKit.attach(visitor, "customer", i + 4, preview)
		if preview:
			apply_preview_tint(expanded, true)
		return expanded
	if type == "house":
		var source := create_asset("building.house", false, allow_fallback)
		if source and source.get_meta("asset_source", "") == "realistic":
			var home := preload("res://godot/OpenHouseAssets.gd").create_house(source)
			home.set_meta("expected_path", "res://godot/OpenHouseAssets.gd")
			if preview:
				apply_preview_tint(home, true)
			else:
				_ensure_collision(home, Vector3(1.70, 1.45, 0.94), "AssetCollision")
				(home.get_node("AssetCollision") as Node3D).position.z = -0.43
			return home
		if source and preview:
			var collision := source.find_child("AssetCollision", true, false)
			if collision:
				collision.free()
			apply_preview_tint(source, true)
		return source
	if type in ["farm", "hemp_farm"]:
		if type == "hemp_farm":
			farm_cells = Vector2i(2, 2)
		var source := create_asset("building.farm", false, allow_fallback)
		if source:
			var farm := preload("res://godot/ExpandedFarmAssets.gd").create_farm(source, farm_cells)
			if type == "hemp_farm":
				ExpandedBuildingKit.apply_recipe_visual(farm, "farm", "hemp")
				farm.name = "HempFarm"
				farm.set_meta("building_type", "hemp_farm")
				farm.set_meta("asset_key", "building.hemp_farm")
				farm.set_meta("footprint_cells", Vector2i(2, 2))
			if preview:
				apply_preview_tint(farm, true)
			else:
				_ensure_collision(farm, Vector3(4.26, 0.28, 4.00 if farm_cells.y == 2 else 1.94), "AssetCollision")
			return farm
		return source
	if type == "fishpond":
		var pond := FishpondKit.create_pond(preview)
		if preview:
			apply_preview_tint(pond, true)
		return pond
	if type in ["clinic", "warehouse"]:
		var base_type := "house" if type == "clinic" else "warehouse"
		var source := create_asset("building." + base_type, preview, allow_fallback)
		if source and source.get_meta("asset_source", "") == "realistic":
			var model := OpenClinicKit.create_clinic(source) if type == "clinic" else OpenWarehouseKit.create_warehouse(source)
			if type == "clinic" and not compact:
				model = preload("res://godot/ExpandedServiceCourts.gd").expand(model, "clinic")
			model.set_meta("composite_base", base_type)
			model.set_meta("expected_path", "res://godot/OpenClinicAssets.gd" if type == "clinic" else "res://godot/OpenWarehouseAssets.gd")
			if type == "clinic":
				var doctor := create_citizen_variant(204, 2, allow_fallback)
				if doctor:
					doctor.name = "ClinicDoctor"
					doctor.scale = Vector3.ONE * 0.40
					doctor.position = model.get_node("DoctorAnchor").position
					model.add_child(doctor)
					var activity := MarketActivityKit.attach(doctor, "vendor", 2, preview)
					activity.name = "ClinicActivity"
			if preview:
				apply_preview_tint(model, true)
			else:
				var hall_size := (Vector3(1.70, 1.20, 0.80) if compact else Vector3(3.76, 1.20, 0.90)) if type == "clinic" else Vector3(3.50, 1.60, 1.60)
				_ensure_collision(model, hall_size, "AssetCollision")
				(model.get_node("AssetCollision") as Node3D).position.z = (-0.56 if compact else -1.41) if type == "clinic" else -1.03
			return model
		return source
	if type == "workshop":
		var source := create_asset("building.workshop", false, allow_fallback)
		if source and source.get_meta("asset_source", "") == "realistic":
			var workshop := OpenWorkshopKit.rebuild(source)
			if not compact:
				workshop = preload("res://godot/ExpandedServiceCourts.gd").expand(workshop, "workshop")
			var artisan := create_citizen_variant(200, 1, allow_fallback)
			if artisan:
				artisan.name = "WorkshopArtisan"
				artisan.scale = Vector3.ONE * 0.44
				artisan.position = workshop.get_node("ArtisanAnchor").position
				workshop.add_child(artisan)
				var activity := MarketActivityKit.attach(artisan, "workshop", 0, preview)
				activity.name = "WorkshopActivity"
				activity.attach_workshop_hammer()
			if not preview:
				_ensure_collision(workshop, Vector3(1.66, 1.3, 0.84) if compact else Vector3(3.76, 1.3, 0.94), "AssetCollision")
				(workshop.get_node("AssetCollision") as Node3D).position.z = -0.55 if compact else -1.40
			else:
				apply_preview_tint(workshop, true)
			return workshop
		if source and preview:
			var collision := source.find_child("AssetCollision", true, false)
			if collision:
				collision.free()
			apply_preview_tint(source, true)
		return source
	if type == "market":
		var market := OpenMarketKit.create_market()
		market.set_meta("asset_key", "building.market")
		market.set_meta("expected_path", "res://godot/OpenMarketAssets.gd")
		for i in range(4):
			var vendor := create_citizen_variant(100 + i, [0, 3, 2, 1][i], allow_fallback)
			if vendor:
				vendor.name = "MarketVendor_%d" % i
				vendor.scale = Vector3.ONE * 0.48
				vendor.position = Vector3(-1.30 if i < 2 else 1.30, 0.28, -0.98 if i % 2 == 0 else 0.98)
				vendor.rotation.y = PI / 2 if i < 2 else -PI / 2
				market.add_child(vendor)
				MarketActivityKit.attach(vendor, "vendor", i, preview)
		for i in range(2):
			var visitor := create_citizen_variant(110 + i, [4, 3][i], allow_fallback)
			if visitor:
				visitor.name = "MarketCustomer_%d" % i
				visitor.scale = Vector3.ONE * 0.48
				visitor.position = Vector3(-0.16 if i == 0 else 0.16, 0.28, -0.98 if i == 0 else 0.98)
				visitor.rotation.y = PI / 2 if i == 0 else -PI / 2
				market.add_child(visitor)
				MarketActivityKit.attach(visitor, "customer", i + 4, preview)
		if preview:
			apply_preview_tint(market, true)
		return market
	if type == "academy":
		var base_type := "workshop"
		var composite := create_asset("building.%s" % base_type, preview, allow_fallback)
		if composite:
			composite.name = "Realistic_Building_%s" % type.capitalize()
			composite.set_meta("building_type", type)
			composite.set_meta("composite_base", base_type)
			_add_regional_identity(composite, type)
			if preview:
				apply_preview_tint(composite, true)
		return composite
	return create_asset("building.%s" % type, preview, allow_fallback)

static func create_tree(variant := 0, allow_fallback := true) -> Node3D:
	var normalized := posmod(variant, 3)
	var tree := create_asset("prop.tree.%02d" % (normalized + 1), false, allow_fallback, normalized)
	return preload("res://godot/DetailedTreeAssets.gd").enhance(tree, normalized)

static func create_rock(variant := 0, allow_fallback := true) -> Node3D:
	var normalized := posmod(variant, 3)
	return create_asset("prop.rock.%02d" % (normalized + 1), false, allow_fallback, normalized)

static func create_bridge(allow_fallback := true) -> Node3D:
	return create_asset("prop.bridge", false, allow_fallback)

static func create_lantern(allow_fallback := true) -> Node3D:
	return create_asset("prop.lantern", false, allow_fallback)

static func create_crops(preview := false, allow_fallback := true) -> Node3D:
	return create_asset("prop.crops", preview, allow_fallback)

static func create_citizen(index := 0, allow_fallback := true) -> Node3D:
	var citizen := create_asset("character.citizen", false, allow_fallback, index)
	if citizen:
		citizen.name = "RealisticCitizen_%03d" % index
		citizen.set_meta("palette_variant", posmod(index, 4))
	return citizen

## Returns the same authored resident body with a readable occupation/age
## silhouette.  The base GLB stays shared; only the small accessory layer is
## unique, so dozens of residents remain cheap to instantiate.
static func create_citizen_variant(index := 0, variant := -1, allow_fallback := true) -> Node3D:
	var citizen := create_citizen(index, allow_fallback)
	if citizen == null:
		return null
	var resolved := posmod(index if variant < 0 else variant, 8)
	citizen.set_meta("npc_variant", resolved)
	citizen.set_meta("npc_variant_name", ["农户", "匠人", "书生", "商贩", "舟夫", "孩童", "白衣女居民", "紫衣女居民"][resolved])
	var cloth_colors := [Color("8b9c76"), Color("6f8b9a"), Color("bfc5b6"), Color("af795b"), Color("658386"), Color("d0a25f"), Color("e6e1d5"), Color("a998b8")]
	# Keep the original imported farmer, including its textured straw hat,
	# basket and clothes. Only the other occupations receive outfit changes.
	if resolved != 0:
		_apply_citizen_outfit(citizen, cloth_colors[resolved], resolved)
	_add_citizen_variant_details(citizen, resolved)
	if resolved >= 6:
		preload("res://godot/FemaleCitizenAssets.gd").dress(citizen, resolved)
	if resolved == 5:
		citizen.scale *= 0.78
	return citizen

static func create_animal(species: String, index := 0) -> Node3D:
	return AnimalKit.create_animal(species, index)

static func get_animal_species() -> Array[String]:
	return AnimalKit.SPECIES.duplicate()

static func apply_preview_tint(root: Node3D, valid: bool) -> void:
	ArtKit.apply_preview_tint(root, valid)
	# Crop foliage is batched. Tint its instance, never mutate shared meshes.
	var crop_preview := ArtKit._material(ArtKit.PALETTE.preview_valid if valid else ArtKit.PALETTE.preview_invalid, 0.46, true)
	for batch in root.find_children("*", "MultiMeshInstance3D", true, false):
		batch.material_override = crop_preview
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for label in root.find_children("*", "Label3D", true, false):
		label.modulate = Color(0.40, 0.90, 0.65, 0.55) if valid else Color(0.95, 0.35, 0.30, 0.55)

static func read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

static func _instantiate(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var packed := _packed_scenes.get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene
		if packed == null:
			push_error("RealisticAssets: Godot could not import %s" % path)
			return null
		_packed_scenes[path] = packed
	return packed.instantiate() as Node3D

static func _create_fallback(key: String, preview: bool, variant: int) -> Node3D:
	var definition: Dictionary = ASSETS[key]
	match str(definition.fallback):
		"house", "lumber", "farm", "warehouse", "workshop":
			return ArtKit.create_building(str(definition.fallback), preview)
		"bridge":
			return ArtKit.create_bridge()
		"tree":
			return ArtKit.create_tree(int(definition.get("variant", variant)))
		"rock":
			return ArtKit.create_rock(int(definition.get("variant", variant)))
		"lantern":
			return ArtKit.create_lantern()
		"crops":
			return ArtKit.create_crops(preview)
		"citizen":
			return ArtKit.create_citizen(variant)
	return null

static func _add_regional_identity(root: Node3D, type: String) -> void:
	var identity := Node3D.new()
	identity.name = "RegionalIdentity_%s" % type.capitalize()
	root.add_child(identity)
	match type:
		"clinic":
			# The turquoise herb awning and oversized wooden medicine gourd create a
			# different roof silhouette without covering the readable front facade.
			_add_box(identity, "ClinicHerbAwning", Vector3(1.38, 0.10, 0.44), Vector3(0.0, 0.76, 0.95), Color("6f9982"))
			_add_box(identity, "ClinicMedicineCabinet", Vector3(0.48, 0.70, 0.24), Vector3(-0.58, 0.36, 0.94), Color("806044"))
			_add_cylinder(identity, "ClinicGourdLower", 0.18, 0.34, Vector3(0.42, 1.76, 0.16), Color("b6a064"), 14)
			_add_cylinder(identity, "ClinicGourdUpper", 0.12, 0.24, Vector3(0.42, 2.00, 0.16), Color("c5b274"), 14)
			_add_box(identity, "ClinicHerbSign", Vector3(0.50, 0.54, 0.08), Vector3(0.54, 0.90, 0.98), Color("496c5e"))
		"academy":
			# A blue scroll board across the ridge plus paired courtyard writing
			# desks makes the academy distinct from the workshop shell.
			_add_box(identity, "AcademyRoofScroll", Vector3(1.20, 0.12, 0.32), Vector3(0.0, 2.08, 0.04), Color("496b7a"))
			_add_box(identity, "AcademyGoldRidge", Vector3(1.48, 0.08, 0.10), Vector3(0.0, 2.20, 0.04), Color("c49a51"))
			_add_box(identity, "AcademyDeskLeft", Vector3(0.54, 0.12, 0.34), Vector3(-0.42, 0.34, 1.02), Color("725039"))
			_add_box(identity, "AcademyDeskRight", Vector3(0.54, 0.12, 0.34), Vector3(0.42, 0.34, 1.02), Color("725039"))
			_add_box(identity, "AcademyGateBoard", Vector3(0.92, 0.34, 0.09), Vector3(0.0, 1.08, 1.00), Color("3f6473"))

static func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _identity_material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)

static func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, color: Color, sides: int) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _identity_material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)

static func _add_citizen_variant_details(root: Node3D, variant: int) -> void:
	var layer := Node3D.new()
	layer.name = "CitizenVariant_%02d" % variant
	layer.set_meta("variant_name", ["农户", "匠人", "书生", "商贩", "舟夫", "孩童", "白衣女居民", "紫衣女居民"][variant])
	root.add_child(layer)
	# The imported resident is authored close to 1.8 m tall.  Details sit above
	# the head and at the shoulder line, then inherit the game's NPC visual scale.
	match variant:
		0: # Original GLB straw hat and basket are already present.
			pass
		1: # blue headband and tool satchel
			_variant_box(layer, "CraftsmanHeadband", Vector3(0.37, 0.07, 0.08), Vector3(0, 1.55, 0.05), Color("5d8792"))
			_variant_box(layer, "CraftsmanSatchel", Vector3(0.22, 0.28, 0.16), Vector3(0.25, 0.86, 0.12), Color("8a5c3b"))
			_variant_cylinder(layer, "CraftsmanHammer", 0.035, 0.32, Vector3(-0.27, 0.83, 0.12), Color("51392d"), 8).rotation_degrees.z = -16.0
		2: # scholar cap and scroll
			_variant_box(layer, "ScholarCap", Vector3(0.42, 0.08, 0.32), Vector3(0, 1.66, -0.01), Color("3f5961"))
			_variant_cylinder(layer, "ScholarScroll", 0.055, 0.26, Vector3(-0.27, 0.84, 0.08), Color("d6c395"), 10).rotation_degrees.z = 90.0
			_variant_box(layer, "ScholarSash", Vector3(0.08, 0.46, 0.05), Vector3(0.18, 1.08, 0.08), Color("b58d53"))
		3: # Uncovered hair, subdued sash and purse.
			_variant_box(layer, "MerchantSash", Vector3(0.48, 0.10, 0.07), Vector3(0, 0.92, 0.02), Color("795c48"))
			_variant_box(layer, "MerchantPouch", Vector3(0.20, 0.18, 0.16), Vector3(-0.27, 0.85, 0.14), Color("9b8055"))
		4: # boatman blue scarf and pole
			_variant_box(layer, "BoatmanScarf", Vector3(0.44, 0.08, 0.10), Vector3(0, 1.50, 0.03), Color("718d96"))
			_variant_cylinder(layer, "BoatmanPole", 0.025, 0.95, Vector3(0.31, 0.93, 0.08), Color("8a5c3b"), 8).rotation_degrees.z = -8.0
			_variant_box(layer, "BoatmanShoulderCloth", Vector3(0.52, 0.06, 0.06), Vector3(0, 1.21, -0.02), Color("657f82"))
		5: # Child with uncovered hair and a small satchel.
			_variant_box(layer, "ChildSatchel", Vector3(0.19, 0.20, 0.14), Vector3(-0.22, 0.84, 0.12), Color("78916e"))

static func _apply_citizen_outfit(node: Node, cloth_color: Color, variant: int) -> void:
	if node is MeshInstance3D:
		var part := node as MeshInstance3D
		# The source farmer already has a straw hat and basket. Remove those
		# accessories before adding each occupation's distinct head silhouette.
		if str(part.name) in ["HatBrim", "HatCrown", "Basket", "BasketHandle"]:
			part.visible = false
		if str(part.name) in ["Torso", "RobeLower", "UpperArm_L", "UpperArm_R", "Forearm_L", "Forearm_R"]:
			var material := _variant_material(cloth_color)
			if part.mesh and part.mesh.get_surface_count() > 0:
				var original := part.mesh.surface_get_material(0) as StandardMaterial3D
				if original:
					material = original.duplicate() as StandardMaterial3D
					material.albedo_color = cloth_color
			part.material_override = material
	for child in node.get_children():
		_apply_citizen_outfit(child, cloth_color, variant)

static func _variant_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _variant_material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance

static func _variant_cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, color: Color, sides: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _variant_material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance

static func _variant_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return material

static func _identity_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material

static func _configure_root(root: Node3D, key: String, source: String, expected: String, preview: bool) -> void:
	root.name = "Realistic_%s" % key.replace(".", "_").capitalize()
	root.set_meta("asset_key", key)
	root.set_meta("asset_source", source)
	root.set_meta("expected_path", expected)
	root.set_meta("tile_meters", 2.0)
	if key.begins_with("building."):
		var type := key.trim_prefix("building.")
		root.set_meta("building_type", type)
		root.set_meta("art_bounds", ASSETS[key].bounds)
		_ensure_door(root)
		if not preview:
			_ensure_collision(root, ASSETS[key].bounds, "AssetCollision")
	elif key == "prop.bridge":
		_ensure_collision(root, Vector3(4.0, 0.24, 1.42), "BridgeDeckCollision", 0.38)
	if preview:
		apply_preview_tint(root, true)

static func _ensure_door(root: Node3D) -> void:
	if root.find_child("Door", true, false):
		return
	var door := Marker3D.new()
	door.name = "Door"
	door.position = Vector3(0, 0, 0.92)
	root.add_child(door)

static func _ensure_collision(root: Node3D, bounds: Vector3, collision_name: String, center_y := -1.0) -> void:
	if root.find_child(collision_name, true, false):
		return
	var body := StaticBody3D.new()
	body.name = collision_name
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	var shape := BoxShape3D.new()
	shape.size = bounds
	collision.shape = shape
	collision.position.y = bounds.y * 0.5 if center_y < 0.0 else center_y
	body.add_child(collision)
	root.add_child(body)

