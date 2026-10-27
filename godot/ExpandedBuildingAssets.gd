extends RefCounted

## Function-led compounds. Human-scale doors, furniture and GLB tile detail
## are preserved; added land is occupied by working yards, not scaled houses.
const Kit = preload("res://godot/OpenClinicAssets.gd")
const Market = preload("res://godot/OpenMarketAssets.gd")
const Pond = preload("res://godot/FishpondAssets.gd")
const Workshop = preload("res://godot/OpenWorkshopAssets.gd")
const Warehouse = preload("res://godot/OpenWarehouseAssets.gd")
const HouseEffects = preload("res://godot/HouseUpgradeEffects.gd")

## tier can be farmer/artisan (or 0/1). Negative construction_ratio means
## finished; [0,1) shows a temporary bamboo scaffold without hiding the home.
static func apply_house_visual(model: Node3D, tier: Variant, construction_ratio := -1.0) -> void:
	if model == null:
		return
	var artisan: bool = str(tier) in ["artisan", "1", "craftsman"]
	var work := model.get_node_or_null("HouseholdJoinery") as Node3D
	if artisan and work == null:
		work = _artisan_home_details(model)
	if work:
		work.visible = artisan
	var hall := model.get_node_or_null("TiledLivingHall") as Node3D
	if hall:
		for part in hall.get_children():
			if part is Node3D and _house_roof_part(part):
				part.visible = not artisan
	var firewood := model.get_node_or_null("LivingCourt/HouseholdFirewood") as Node3D
	if firewood:
		firewood.visible = not artisan
	var construction := model.get_node_or_null("HouseUpgradeScaffold") as Node3D
	var building := construction_ratio >= 0.0 and construction_ratio < 1.0
	if building and construction == null:
		construction = Kit.branch(model, "HouseUpgradeScaffold")
		var bamboo := _mat("wood", "a3a370")
		for z in [-0.72, -0.12]:
			Kit.cylinder(construction, "ScaffoldUpright", 0.024, 1.62, Vector3(0.91, 1.04, z), bamboo)
		for y in [0.58, 1.12, 1.65]:
			Kit.box(construction, "ScaffoldCrossbar", Vector3(0.035, 0.035, 0.72), Vector3(0.91, y, -0.42), bamboo)
		Kit.box(construction, "ScaffoldFootboard", Vector3(0.17, 0.035, 0.72), Vector3(0.86, 1.10, -0.42), bamboo)
		for i in range(3):
			Kit.box(construction, "RenovationTimber", Vector3(0.07, 0.06, 0.55), Vector3(0.45 + i * 0.1, 0.32, 0.58), bamboo)
	if construction:
		construction.visible = building
	model.set_meta("house_visual_tier", "artisan" if artisan else "farmer")
	model.set_meta("art_bounds", Vector3(2.12, 3.12 if artisan else 2.04, 2.12))
	var effects := model.get_node_or_null("HouseUpgradeEffects")
	if effects == null:
		effects = HouseEffects.new()
		effects.name = "HouseUpgradeEffects"
		model.add_child(effects)
	effects.apply_state(artisan, building)

static func _house_roof_part(part: Node3D) -> bool:
	var label := str(part.name)
	if label.begins_with("RoofTile") or label.begins_with("RoofRidge") or label.begins_with("RidgeEnd") or label.begins_with("HouseGable") or label.begins_with("RoofIdentity_HouseBrackets") or label.begins_with("EaveBracketSupport"):
		return true
	# Repeated helper-created parts can receive Godot's anonymous node names.
	# Identify the authored gables/eave brackets geometrically as well, so
	# the old roof never remains buried inside the second-storey rooms.
	if part is MeshInstance3D:
		var bounds: AABB = part.transform * part.get_aabb()
		if bounds.size.x < 0.001 and bounds.position.y > 1.13:
			return true
		if bounds.size.x < 0.20 and bounds.position.y > 1.04 and bounds.end.y < 1.15:
			return true
	return false

static func _artisan_home_details(model: Node3D) -> Node3D:
	var details := Kit.branch(model, "HouseholdJoinery")
	var wood := _mat("wood", "a38a62")
	var dark := _mat("wood", "756348")
	var blue := Kit.material(Color("657f83"))
	var iron := Kit.material(Color("70766e"))
	# A genuine upper storey, using the original wall, open-window and tiled
	# roof meshes at their authored scale. Only the lower roof is hidden;
	# the downstairs doorway, domestic interior and full courtyard survive.
	var hall := model.get_node_or_null("TiledLivingHall") as Node3D
	if hall:
		var upper := hall.duplicate() as Node3D
		upper.name = "ArtisanUpperStorey"
		upper.position.y += 1.08
		details.add_child(upper)
		for part in upper.get_children():
			if part is Node3D:
				part.visible = true
		# The open upstairs doors lead onto an enclosed timber balcony.
		# Its floor joins the upper room floor, with posts bearing on the
		# original front wall and corner posts rather than floating in air.
		var balcony := Kit.branch(details, "ArtisanUpperBalcony")
		Kit.box(balcony, "BalconyFloor", Vector3(1.78, 0.085, 0.43), Vector3(0, 1.36, 0.19), wood)
		for x in [-0.80, 0.80]:
			Kit.box(balcony, "BalconyBearingPost", Vector3(0.065, 1.08, 0.065), Vector3(x, 0.82, 0.23), dark)
			Kit.box(balcony, "BalconyCornerPost", Vector3(0.055, 0.48, 0.055), Vector3(x, 1.61, 0.38), dark)
			Kit.box(balcony, "BalconySideToprail", Vector3(0.045, 0.045, 0.38), Vector3(x, 1.84, 0.20), wood)
			for z in [0.10, 0.24]:
				Kit.box(balcony, "BalconySideBaluster", Vector3(0.028, 0.36, 0.028), Vector3(x, 1.62, z), dark)
		for y in [1.45, 1.84]:
			Kit.box(balcony, "BalconyFrontRail", Vector3(1.67, 0.045, 0.05), Vector3(0, y, 0.38), wood)
		for i in range(11):
			Kit.box(balcony, "BalconyTurnedBaluster", Vector3(0.026, 0.37, 0.026), Vector3(-0.72 + i * 0.144, 1.64, 0.38), dark)
		# A restrained blue cloth and carved window lattices distinguish the
		# craftsman's home from the ordinary household at the game camera.
		Kit.box(balcony, "IndigoDryingCloth", Vector3(0.31, 0.25, 0.022), Vector3(0.43, 1.73, 0.418), blue)
		Kit.box(balcony, "ClothHem", Vector3(0.31, 0.018, 0.026), Vector3(0.43, 1.61, 0.42), wood)
		for side in [-1.0, 1.0]:
			for i in range(3):
				Kit.box(details, "UpperWindowLattice", Vector3(0.018, 0.42, 0.025), Vector3(side * 0.54 - 0.12 + i * 0.12, 1.998, 0.0), dark)
			Kit.box(details, "UpperWindowCrossrail", Vector3(0.43, 0.018, 0.025), Vector3(side * 0.54, 1.998, 0.0), wood)
		# Reinforce the visible floor seam around three faces so the two
		# inhabited floors read clearly even from the rear camera angle.
		Kit.box(details, "UpperRearFloorBeam", Vector3(1.76, 0.09, 0.08), Vector3(0, 1.36, -0.89), dark)
		for x in [-0.83, 0.83]:
			Kit.box(details, "UpperSideFloorBeam", Vector3(0.075, 0.09, 0.98), Vector3(x, 1.36, -0.43), dark)
		details.set_meta("storeys", 2)
	# A better-finished domestic gate frames the existing opening; side fences
	# and the direct 0.55m route to the house are left completely intact.
	var gate := Kit.branch(details, "ArtisanCourtyardGate")
	for x in [-0.33, 0.33]:
		Kit.box(gate, "DressedGatePost", Vector3(0.065, 0.88, 0.065), Vector3(x, 0.69, 0.95), dark)
		Kit.box(gate, "GatePostFoot", Vector3(0.10, 0.13, 0.10), Vector3(x, 0.315, 0.95), Kit.material(Color("8b8d79")))
	Kit.box(gate, "GateLintel", Vector3(0.79, 0.085, 0.095), Vector3(0, 1.15, 0.95), wood)
	Kit.box(gate, "BlueGateHeader", Vector3(0.50, 0.12, 0.04), Vector3(0, 1.055, 0.985), blue)
	Kit.text_sign(gate, "匠 家", Vector3(0, 1.055, 1.009), 0.00135, Color("e2d5b3"))
	for x in [-0.39, 0.39]:
		Kit.box(gate, "GateEndCap", Vector3(0.07, 0.11, 0.13), Vector3(x, 1.17, 0.95), dark)
	# Personal tool storage replaces the household firewood pile, staying
	# inside the left porch. It is a home, with no workbench or stock output.
	var rack := Kit.branch(details, "ArtisanPersonalToolRack")
	rack.position = Vector3(-0.62, 0, 0.31)
	for x in [-0.17, 0.17]:
		Kit.box(rack, "ToolRackLeg", Vector3(0.035, 0.65, 0.035), Vector3(x, 0.575, 0), dark)
		Kit.box(rack, "ToolRackFoot", Vector3(0.055, 0.035, 0.22), Vector3(x, 0.268, 0.035), wood)
	Kit.box(rack, "ToolRackBackboard", Vector3(0.39, 0.30, 0.028), Vector3(0, 0.74, -0.013), wood)
	Kit.box(rack, "ToolRackShelf", Vector3(0.42, 0.035, 0.24), Vector3(0, 0.45, 0.06), wood)
	Kit.box(rack, "HangingSquareLong", Vector3(0.025, 0.21, 0.016), Vector3(-0.12, 0.75, 0.012), iron)
	Kit.box(rack, "HangingSquareShort", Vector3(0.13, 0.025, 0.016), Vector3(-0.067, 0.65, 0.012), iron)
	Kit.box(rack, "PersonalMalletHandle", Vector3(0.024, 0.22, 0.025), Vector3(0.105, 0.73, 0.025), dark)
	Kit.box(rack, "PersonalMalletHead", Vector3(0.13, 0.055, 0.045), Vector3(0.105, 0.82, 0.025), wood)
	var case := Kit.box(rack, "PersonalClothToolRoll", Vector3(0.20, 0.075, 0.12), Vector3(0, 0.505, 0.07), blue)
	case.rotation.y = -0.12
	details.set_meta("residential_only", true)
	return details

## Economy may stop work gestures independently of cosmetic walking NPCs.
static func apply_working_visual(model: Node3D, working: bool) -> void:
	if model == null:
		return
	for actor in model.get_children():
		if str(actor.name) not in ["WorkingResident", "WorkshopArtisan"]:
			continue
		var lumber_activity := actor.get_node_or_null("LumberActivity")
		if lumber_activity:
			lumber_activity.set_working(working)
			continue
		var activity := actor.get_node_or_null("MarketActivity")
		if activity:
			activity.set_process(working)
			if not working and activity.has_method("sample"):
				activity.sample(0.0)

## Safe for placement, recipe switching and load. Original crop meshes and
## their materials remain intact; only recipe-specific branches toggle.
static func apply_recipe_visual(model: Node3D, type: String, recipe: String) -> void:
	if model == null:
		return
	if type == "farm":
		var hemp := recipe == "hemp"
		var crop := model.get_node_or_null("RecipeHemp") as Node3D
		if hemp and crop == null:
			crop = _hemp_crop(model)
		if crop:
			crop.visible = hemp
		for part in model.get_children():
			if part is MeshInstance3D and (str(part.name).begins_with("FieldGrain") or str(part.name).begins_with("FieldLeaf") or str(part.name).begins_with("FieldStem")):
				part.visible = not hemp
		model.set_meta("recipe_visual", "hemp" if hemp else "grain")
	elif type == "workshop":
		var precision := recipe == "precision"
		var rack := model.get_node_or_null("RecipePrecision") as Node3D
		if precision and rack == null:
			rack = _precision_rack(model)
		if rack:
			rack.visible = precision
		model.set_meta("recipe_visual", "precision" if precision else "basic")

static func _hemp_crop(model: Node3D) -> Node3D:
	var crop := Kit.branch(model, "RecipeHemp")
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.008
	stem_mesh.bottom_radius = 0.014
	stem_mesh.height = 1.0
	stem_mesh.radial_segments = 10
	stem_mesh.material = _mat("", "5c713f")
	var leaf_mesh := _hemp_leaf_mesh()
	var seed_mesh := SphereMesh.new()
	seed_mesh.radius = 0.5
	seed_mesh.height = 1.0
	seed_mesh.radial_segments = 12
	seed_mesh.rings = 6
	seed_mesh.material = _mat("", "68834d")
	var stems: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	var tips: Array[Transform3D] = []
	var index := 0
	# Plant positions follow the authored rows, preserving paths and channels.
	for part in model.get_children():
		if not (part is MeshInstance3D and str(part.name).begins_with("FieldStem")):
			continue
		var location: Vector3 = (part.transform * part.get_aabb()).get_center()
		var height := 0.70 + float(index % 5) * 0.052
		var base := Vector3(location.x, 0.15, location.z)
		stems.append(Transform3D(Basis.from_scale(Vector3(1, height, 1)), base + Vector3(0, height * 0.5, 0)))
		for level in range(3):
			for side in [-1.0, 1.0]:
				var angle: float = index * 2.399 + level * 1.15 + (PI if side < 0 else 0.0)
				var direction := Vector3(cos(angle), 0, sin(angle))
				var scale := Vector3(0.21 + level * 0.018, 0.065, 0.092)
				var basis := Basis(Vector3.UP, -angle) * Basis(Vector3.FORWARD, -0.20) * Basis.from_scale(scale)
				leaves.append(Transform3D(basis, base + direction * 0.09 + Vector3(0, height * (0.40 + level * 0.20), 0)))
		for cluster in range(3):
			var angle := index * 2.399 + cluster * 2.094
			tips.append(Transform3D(Basis.from_scale(Vector3(0.065, 0.12, 0.065)), base + Vector3(cos(angle) * 0.035, height - cluster * 0.035, sin(angle) * 0.035)))
		index += 1
	_multimesh(crop, "SlenderHempStems", stem_mesh, stems)
	_multimesh(crop, "OpposedHempLeaves", leaf_mesh, leaves)
	_multimesh(crop, "HempFlowerClusters", seed_mesh, tips)
	crop.set_meta("plant_count", index)
	return crop

static func _hemp_leaf_mesh() -> ArrayMesh:
	# Curved pointed blades with a raised midrib, rather than flat triangles
	# or spherical foliage. Both faces remain readable from rotated cameras.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := Kit.material(Color("425e34"))
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(material)
	for section in range(8):
		for side in [-1.0, 1.0]:
			var t0 := float(section) / 8.0
			var t1 := float(section + 1) / 8.0
			var a := Vector3(t0 - 0.5, sin(t0 * PI) * 0.24, 0)
			var b := Vector3(t0 - 0.5, sin(t0 * PI) * 0.06, side * sin(t0 * PI) * 0.48)
			var c := Vector3(t1 - 0.5, sin(t1 * PI) * 0.24, 0)
			var d := Vector3(t1 - 0.5, sin(t1 * PI) * 0.06, side * sin(t1 * PI) * 0.48)
			for vertex in ([a, b, c, b, d, c] if side > 0 else [a, c, b, b, c, d]):
				surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()

static func _multimesh(root: Node3D, label: String, mesh: Mesh, transforms: Array[Transform3D]) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in range(transforms.size()):
		batch.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = batch
	root.add_child(instance)

static func _precision_rack(model: Node3D) -> Node3D:
	var rack := Kit.branch(model, "RecipePrecision")
	# Shelved wooden utensils occupy a clear strip beside the front aisle.
	rack.position = Vector3(-1.58, 0, 0.31)
	var wood := _mat("wood", "bca57b")
	var dark := _mat("wood", "88704d")
	for x in [-0.54, 0.54]:
		for z in [-0.20, 0.20]:
			Kit.box(rack, "JoineryRackUpright", Vector3(0.045, 0.86, 0.045), Vector3(x, 0.69, z), dark)
	for tier in range(2):
		var y := 0.42 + tier * 0.36
		Kit.box(rack, "FinishedGoodsShelf", Vector3(1.20, 0.045, 0.48), Vector3(0, y, 0), wood)
		for item in range(3):
			var pos := Vector3(-0.37 + item * 0.37, y + 0.078, 0)
			var bowl := TorusMesh.new()
			bowl.inner_radius = 0.07
			bowl.outer_radius = 0.13
			bowl.rings = 24
			bowl.ring_segments = 10
			Kit.piece(rack, "TurnedWoodenBowl", bowl, pos, wood)
			Kit.cylinder(rack, "BowlBase", 0.088, 0.022, pos - Vector3(0, 0.032, 0), dark)
	Kit.box(rack, "PrecisionCaliper", Vector3(0.26, 0.03, 0.025), Vector3(0.20, 1.0, 0), dark)
	return rack

static func create_building(type: String, preview: bool, source: Node3D = null) -> Node3D:
	var root: Node3D
	match type:
		"market": root = _market()
		"fishpond": root = _pond(preview)
		"warehouse": root = _warehouse(source)
		"workshop": root = _workshop(source)
		"lumber": root = _lumber()
		"well": root = _well()
		"weaver": root = _weaver(source)
		"academy": root = _academy(source)
		_: return null
	var square: bool = type in ["market", "fishpond", "academy"]
	var compact_lumber: bool = type in ["lumber", "warehouse", "well"]
	root.set_meta("building_type", type)
	root.set_meta("asset_key", "building." + type)
	root.set_meta("asset_source", "expanded_functional_compound")
	root.set_meta("expected_path", "res://godot/ExpandedBuildingAssets.gd")
	root.set_meta("footprint_cells", Vector2i(2 if compact_lumber else 3, 3 if square else 2))
	root.set_meta("art_bounds", Vector3(4.18 if type in ["warehouse", "well"] else (4.28 if compact_lumber else 6.48), 2.65, 4.18 if type in ["warehouse", "well"] else (6.48 if square else 4.28)))
	root.set_meta("main_entrance", Vector3(0, 0, 2.09 if type in ["warehouse", "well"] else (3.24 if square else 2.14)))
	var door := root.get_node_or_null("Door") as Node3D
	if door == null:
		Kit.anchor(root, "Door", root.get_meta("main_entrance"))
	else:
		door.position = root.get_meta("main_entrance")
	# Interior source modules may retain their old door markers. Only the
	# compound entrance is called Door so recursive NPC lookup stays correct.
	for marker in root.find_children("Door", "Node3D", true, false):
		if marker.get_parent() != root:
			marker.name = "InteriorDoor"
	# Existing colliders were authored for smaller compounds. Main owns placement
	# occupancy; this shallow pick volume stays inside the new footprint.
	for body in root.find_children("*", "StaticBody3D", true, false):
		body.free()
	if not preview:
		var body := StaticBody3D.new()
		body.name = "AssetCollision"
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(4.18 if compact_lumber else 6.38, 0.35, 6.38 if square else 4.18)
		collision.shape = shape
		collision.position.y = 0.25
		body.add_child(collision)
		root.add_child(body)
	return root

static func _mat(kind: String, color: String) -> Material:
	return Market.material(kind, Color(color))

static func _floor(root: Node3D, depth: float) -> void:
	Kit.box(root, "CompactedEarthCourt", Vector3(6.40, 0.09, depth), Vector3(0, 0.205, 0), _mat("stone", "a5987b"))
	for i in range(int(depth / 0.43)):
		Kit.box(root, "EntryPath", Vector3(0.78, 0.025, 0.38), Vector3(0, 0.263, depth * 0.5 - 0.24 - i * 0.43), _mat("stone", "a3a08d"))

## Open draw-well: a hollow masonry ring and visible water remain readable
## from the normal village camera. All props fit the 2x2 earthen court.
static func _well() -> Node3D:
	var root := Node3D.new()
	root.name = "VillageDrawWell"
	Kit.box(root, "EarthenWellCourt", Vector3(4.18, 0.09, 4.18), Vector3(0, 0.205, 0), _lumber_soil())
	var stone := Kit.material(Color("838574"))
	var dark_stone := Kit.material(Color("6b7464"))
	var timber := _mat("wood", "8e7652")
	var pale_wood := _mat("wood", "b6a079")
	var rope := _mat("", "b3a27b")
	var iron := _mat("", "535953")
	var center := Vector3(-0.48, 0, -0.30)
	# Individual annular voussoirs have inner walls, tops and end faces;
	# there is deliberately no solid cylinder filling the mouth of the well.
	for layer in range(3):
		for block in range(12):
			var angle := (block + (0.5 if layer % 2 else 0.0)) * TAU / 12.0
			_well_masonry(root, center, 0.48, 0.70 if layer == 2 else 0.67,
				0.255 + layer * 0.19, 0.18, angle + 0.008, TAU / 12.0 - 0.016,
				stone if (block + layer) % 3 else dark_stone)
	var pool := CylinderMesh.new()
	pool.top_radius = 0.477
	pool.bottom_radius = 0.477
	pool.height = 0.018
	pool.radial_segments = 64
	Kit.piece(root, "VisibleWellWater", pool, center + Vector3(0, 0.49, 0), _well_water())
	# A winding drum on two mortised posts, with a genuine coiled rope.
	for side in [-1.0, 1.0]:
		var pos := center + Vector3(side * 0.88, 0, 0)
		Kit.box(root, "WindlassStoneFoot", Vector3(0.31, 0.14, 0.35), pos + Vector3(0, 0.32, 0), dark_stone)
		Kit.box(root, "WindlassPost", Vector3(0.15, 1.39, 0.17), pos + Vector3(0, 1.00, 0), timber)
		Kit.box(root, "WindlassPostCap", Vector3(0.22, 0.07, 0.23), pos + Vector3(0, 1.72, 0), pale_wood)
		Kit.box(root, "WindlassBearing", Vector3(0.055, 0.23, 0.25), pos + Vector3(side * 0.09, 1.37, 0), iron)
		var brace := Kit.box(root, "WindlassFootBrace", Vector3(0.075, 0.62, 0.075), pos + Vector3(0, 0.56, 0.25), timber)
		brace.rotation.x = -0.65
	var axle := Kit.cylinder(root, "WindlassAxle", 0.095, 2.06, center + Vector3(0, 1.37, 0), pale_wood)
	axle.rotation.z = PI * 0.5
	for i in range(14):
		var coil := TorusMesh.new()
		coil.inner_radius = 0.094
		coil.outer_radius = 0.113
		coil.rings = 32
		coil.ring_segments = 6
		var turn := Kit.piece(root, "WoundHempRope", coil, center + Vector3(-0.13 + i * 0.020, 1.37, 0), rope)
		turn.rotation.z = PI * 0.5
	Kit.cylinder(root, "HangingWellRope", 0.011, 0.49, center + Vector3(0.13, 1.125, 0.101), rope)
	_well_bucket(root, "SuspendedDrawBucket", center + Vector3(0.13, 0.57, 0.10), pale_wood, iron)
	Kit.box(root, "WindlassCrankArm", Vector3(0.055, 0.31, 0.07), center + Vector3(1.08, 1.23, 0), timber)
	var grip := Kit.cylinder(root, "WindlassCrankGrip", 0.037, 0.22, center + Vector3(1.17, 1.09, 0), pale_wood)
	grip.rotation.z = PI * 0.5
	# Hollow stone trough and filled carrying buckets show the building's use.
	var trough := Kit.branch(root, "WaterDistributionTrough")
	trough.position = Vector3(1.25, 0, 0.32)
	Kit.box(trough, "TroughBottom", Vector3(0.70, 0.12, 1.48), Vector3(0, 0.32, 0), dark_stone)
	for x in [-0.30, 0.30]:
		Kit.box(trough, "TroughLongWall", Vector3(0.10, 0.27, 1.48), Vector3(x, 0.49, 0), stone)
	for z in [-0.69, 0.69]:
		Kit.box(trough, "TroughEndWall", Vector3(0.50, 0.27, 0.10), Vector3(0, 0.49, z), stone)
	Kit.box(trough, "TroughWater", Vector3(0.49, 0.018, 1.27), Vector3(0, 0.50, 0), _well_water())
	_well_bucket(root, "ReadyWaterPail", Vector3(0.35, 0.25, 1.17), pale_wood, iron)
	_well_bucket(root, "SpareWaterPail", Vector3(-0.17, 0.25, 1.32), timber, iron)
	Kit.box(root, "CarryingYoke", Vector3(1.02, 0.045, 0.08), Vector3(0.03, 0.61, 1.27), pale_wood)
	for i in range(4):
		var step := Kit.box(root, "WornWellSteppingStone", Vector3(0.55, 0.025, 0.29), Vector3(-0.78 + i * 0.11, 0.263, 0.88 + i * 0.29), stone)
		step.rotation.y = -0.12 + i * 0.06
	# Low boundary and vegetation leave the front approach completely open.
	for i in range(6):
		Kit.box(root, "BackCourtStone", Vector3(0.50, 0.12, 0.20), Vector3(-1.39 + i * 0.55, 0.30, -1.79), dark_stone)
	for i in range(11):
		var angle := i * 2.399
		var pos := Vector3(-1.62 + cos(angle) * 0.16, 0.29, -1.44 + sin(angle) * 0.18)
		var leaf := Kit.sphere(root, "WellsideGroundCover", Vector3(0.17, 0.07, 0.32), pos, _mat("", "687a4e" if i % 2 else "7b865c"))
		leaf.rotation.y = angle
	root.set_meta("well_open_mouth_radius", 0.48)
	root.set_meta("well_water_height", 0.49)
	return root

static func _well_masonry(root: Node3D, center: Vector3, inner: float, outer: float, bottom: float, height: float, start: float, span: float, mat: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mat)
	for slice in range(4):
		var a := start + span * slice / 4.0
		var b := start + span * (slice + 1) / 4.0
		var p: Array[Vector3] = []
		for y in [bottom, bottom + height]:
			for radius in [inner, outer]:
				for angle in [a, b]:
					p.append(center + Vector3(cos(angle) * radius, y, sin(angle) * radius))
		# Clockwise face winding as viewed from the exterior, including cavity.
		var faces: Array = [[4,5,7,6], [0,2,3,1], [2,6,7,3], [0,1,5,4]]
		if slice == 0:
			faces.append([0,4,6,2])
		if slice == 3:
			faces.append([1,3,7,5])
		for face in faces:
			var normal := (p[face[1]] - p[face[0]]).cross(p[face[2]] - p[face[0]]).normalized()
			for index in [0,2,1,0,3,2]:
				var v: Vector3 = p[face[index]]
				surface.set_normal(normal)
				surface.set_uv([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN][index])
				surface.add_vertex(v)
	var mesh := MeshInstance3D.new()
	mesh.name = "CutWellMasonry"
	mesh.mesh = surface.commit()
	root.add_child(mesh, true)

static func _well_bucket(root: Node3D, label: String, pos: Vector3, wood: Material, metal: Material) -> void:
	var bucket := Kit.branch(root, label)
	bucket.position = pos
	Kit.cylinder(bucket, "PailBottom", 0.13, 0.035, Vector3(0, 0.02, 0), wood)
	for i in range(14):
		var angle := i * TAU / 14.0
		var stave := Kit.box(bucket, "PailWoodStave", Vector3(0.059, 0.23, 0.028), Vector3(sin(angle) * 0.138, 0.13, cos(angle) * 0.138), wood)
		stave.rotation.y = angle
	for y in [0.065, 0.207]:
		var hoop := TorusMesh.new()
		hoop.inner_radius = 0.145
		hoop.outer_radius = 0.158
		hoop.rings = 32
		hoop.ring_segments = 6
		Kit.piece(bucket, "PailIronHoop", hoop, Vector3(0, y, 0), metal)
	for x in [-0.13, 0.13]:
		Kit.cylinder(bucket, "PailHandleUpright", 0.009, 0.18, Vector3(x, 0.28, 0), metal)
	Kit.box(bucket, "PailHandle", Vector3(0.28, 0.025, 0.027), Vector3(0, 0.37, 0), wood)
	Kit.cylinder(bucket, "PailWater", 0.122, 0.01, Vector3(0, 0.17, 0), _well_water())

static var _draw_well_water: ShaderMaterial

static func _well_water() -> ShaderMaterial:
	if _draw_well_water != null:
		return _draw_well_water
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode specular_schlick_ggx;
varying vec3 pool_pos;
void vertex() { pool_pos = VERTEX; }
void fragment() {
    float wave = sin(pool_pos.x * 29.0 + pool_pos.z * 13.0 + TIME * 1.4);
    float rings = sin(length(pool_pos.xz) * 42.0 - TIME * 1.2);
    ALBEDO = mix(vec3(0.20, 0.35, 0.30), vec3(0.43, 0.56, 0.46), 0.44 + wave * 0.10 + rings * 0.07);
    ROUGHNESS = 0.28;
    METALLIC = 0.12;
    NORMAL_MAP = vec3(0.5 + wave * 0.025, 0.5 + rings * 0.025, 1.0);
}
"""
	_draw_well_water = ShaderMaterial.new()
	_draw_well_water.shader = shader
	return _draw_well_water

static func _plank_shelter(root: Node3D, pos: Vector3, width: float, depth: float, height: float) -> Node3D:
	var shelter := Kit.branch(root, "TimberPlankShelter")
	shelter.position = pos
	var wood := _mat("wood", "a18d69")
	var dark := _mat("wood", "736249")
	for x in [-width * 0.43, width * 0.43]:
		for z in [-depth * 0.39, depth * 0.39]:
			Kit.box(shelter, "ShelterPost", Vector3(0.075, height - 0.25, 0.075), Vector3(x, (height + 0.25) * 0.5, z), dark)
	for z in [-depth * 0.39, depth * 0.39]:
		Kit.box(shelter, "TieBeam", Vector3(width * 0.96, 0.09, 0.09), Vector3(0, height - 0.04, z), dark)
	for i in range(int(width / 0.14)):
		var x: float = -width * 0.5 + 0.07 + i * 0.14
		for side in [-1.0, 1.0]:
			var plank := Kit.box(shelter, "WeatheredRoofBoard", Vector3(0.135, 0.045, depth * 0.55), Vector3(x, height + 0.12, side * depth * 0.245), wood)
			plank.rotation.x = side * 0.22
	Kit.box(shelter, "RoofRidgeTimber", Vector3(width, 0.07, 0.10), Vector3(0, height + 0.22, 0), dark)
	return shelter

static func _bench(root: Node3D, pos: Vector3, size := Vector2(1.2, 0.6)) -> void:
	var wood := _mat("wood", "af9572")
	Kit.box(root, "WorkingTable", Vector3(size.x, 0.085, size.y), pos + Vector3(0, 0.71, 0), wood)
	for x in [-size.x * 0.40, size.x * 0.40]:
		for z in [-size.y * 0.36, size.y * 0.36]:
			Kit.box(root, "TableLeg", Vector3(0.065, 0.43, 0.065), pos + Vector3(x, 0.48, z), wood)

static func _log(root: Node3D, pos: Vector3, length: float, radius: float) -> void:
	var timber := Kit.cylinder(root, "BarkLog", radius, length, pos, _mat("wood", "726349"))
	timber.rotation.z = PI * 0.5
	for side in [-1.0, 1.0]:
		var end := Kit.cylinder(root, "CutEndGrain", radius * 0.94, 0.012, pos + Vector3(side * (length * 0.5 + 0.004), 0, 0), _mat("wood", "c1a778"))
		end.rotation.z = PI * 0.5
		for ring_index in range(3):
			var ring := TorusMesh.new()
			ring.inner_radius = radius * (0.25 + ring_index * 0.22)
			ring.outer_radius = ring.inner_radius + 0.009
			ring.rings = 24
			ring.ring_segments = 4
			var rings := Kit.piece(root, "GrowthRing", ring, pos + Vector3(side * (length * 0.5 + 0.013), 0, 0), _mat("wood", "8c7957"))
			rings.rotation.z = PI * 0.5

static func _lumber() -> Node3D:
	var root := Node3D.new()
	root.name = "TimberYard"
	# Dedicated compact earth yard: no stone/warehouse texture or paved path.
	Kit.box(root, "WarmEarthenTimberYard", Vector3(4.18, 0.09, 4.18), Vector3(0, 0.205, 0), _lumber_soil())
	_plank_shelter(root, Vector3(-0.55, 0, -0.94), 2.64, 1.83, 1.50)
	# Turn the log pile lengthwise along the right boundary, preserving each
	# trunk's original world scale while leaving a central loading approach.
	var stack := Kit.branch(root, "LengthwiseLogStack")
	stack.position = Vector3(1.48, 0, -0.78)
	stack.rotation.y = PI * 0.5
	for tier in range(3):
		for row in range(3 - tier):
			_log(stack, Vector3(0, 0.40 + tier * 0.25, -0.29 + row * 0.29 + tier * 0.14), 1.83, 0.15)
	# Low saw horses fit the unchanged 0.44-scale worker. The old full-height
	# table put its timber above his hands and hid the operation under the roof.
	for side in [-1.0, 1.0]:
		var horse := Kit.branch(root, "SawHorse")
		horse.position = Vector3(-0.68 + side * 0.48, 0, -0.12)
		Kit.box(horse, "Saddle", Vector3(0.11, 0.065, 0.42), Vector3(0, 0.51, 0), _mat("wood", "af9572"))
		for z in [-0.15, 0.15]:
			Kit.box(horse, "TrestleLeg", Vector3(0.055, 0.25, 0.055), Vector3(0, 0.375, z), _mat("wood", "736249"))
	_log(root, Vector3(-0.68, 0.62, -0.12), 1.72, 0.09)
	var saw := Kit.branch(root, "FrameSaw")
	saw.position = Vector3(-0.68, 0.69, -0.12)
	for z in [-0.30, 0.30]:
		Kit.box(saw, "SawHandle", Vector3(0.055, 0.27, 0.055), Vector3(0, 0.035, z), _mat("wood", "756043"))
	Kit.box(saw, "SawBlade", Vector3(0.018, 0.055, 0.60), Vector3(0, -0.065, 0), _mat("", "70766c"))
	Kit.box(saw, "SawFrame", Vector3(0.045, 0.045, 0.65), Vector3(0, 0.17, 0), _mat("wood", "756043"))
	for tooth in range(15):
		var tip := Kit.box(saw, "SawTooth", Vector3(0.018, 0.018, 0.018), Vector3(0, -0.099, -0.28 + tooth * 0.04), _mat("", "70766c"))
		tip.rotation.x = PI * 0.25
	var loose := Kit.branch(root, "LooseTimber")
	loose.position = Vector3(-0.68, 0.455, 0.045)
	_log(loose, Vector3.ZERO, 0.58, 0.055)
	Kit.box(root, "OffcutTray", Vector3(0.68, 0.045, 0.13), Vector3(-0.68, 0.38, 0.045), _mat("wood", "887651"))
	Kit.box(root, "DeliveryTray", Vector3(0.76, 0.11, 0.13), Vector3(0.60, 0.345, 0.49), _mat("wood", "887651"))
	for i in range(8):
		Kit.box(root, "SeasoningBoard", Vector3(1.6, 0.06, 0.13), Vector3(1.13, 0.30 + (i / 4) * 0.075, 0.72 + (i % 4) * 0.15), _mat("wood", "ad956c"))
	# Thin chips around the saw, kept off the front gate and clear walking strip.
	var chips := _mat("", "b49a68")
	for i in range(22):
		var angle := i * 2.399
		var radius := 0.18 + float(i % 7) * 0.07
		var chip := Kit.box(root, "ScatteredWoodChip", Vector3(0.065 + float(i % 3) * 0.018, 0.012, 0.022), Vector3(-1.15 + cos(angle) * radius, 0.257, 0.45 + sin(angle) * radius), chips)
		chip.rotation.y = angle
	Kit.anchor(root, "ArtisanAnchor", Vector3(-0.68, 0.25, 0.25))
	Kit.anchor(root, "LumberDeliveryAnchor", Vector3(0.60, 0.25, 0.25))
	root.set_meta("lumber_body_radius", 0.14)
	var obstacles: Array[Rect2] = [Rect2(1.04, -1.85, 0.88, 2.10), Rect2(0.33, 0.655, 1.60, 0.58), Rect2(-1.54, -0.21, 1.72, 0.18), Rect2(-1.02, -0.02, 0.68, 0.13), Rect2(0.22, 0.425, 0.76, 0.13)]
	for x in [-1.6852, 0.5852]:
		for z in [-1.6537, -0.2263]:
			obstacles.append(Rect2(x - 0.0375, z - 0.0375, 0.075, 0.075))
	for x in [-1.16, -0.20]:
		obstacles.append(Rect2(x - 0.055, -0.33, 0.11, 0.42))
	root.set_meta("lumber_obstacles", obstacles)
	return root

static var _lumber_earth: ShaderMaterial

static func _lumber_soil() -> ShaderMaterial:
	if _lumber_earth != null:
		return _lumber_earth
	var shader := Shader.new()
	shader.code = """shader_type spatial;
uniform vec4 soil_dark : source_color = vec4(0.13, 0.115, 0.085, 1.0);
uniform vec4 soil_light : source_color = vec4(0.25, 0.215, 0.155, 1.0);
varying vec3 local_position;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0,0.0)), u.x),
               mix(hash21(i + vec2(0.0,1.0)), hash21(i + vec2(1.0,1.0)), u.x), u.y);
}
void vertex() { local_position = VERTEX; }
void fragment() {
    vec2 p = local_position.xz;
    float broad = noise2(p * 2.1 + 14.3);
    float grain = noise2(p * 49.0 + 8.9);
    float clods = noise2(p * 12.0 + 3.1);
    float worn = exp(-pow(p.x * 2.3, 2.0)) * smoothstep(-0.4, 1.9, p.y);
    ALBEDO = mix(soil_dark.rgb, soil_light.rgb, clamp(0.3 + broad * 0.48 + clods * 0.14 + grain * 0.08 + worn * 0.12, 0.0, 1.0));
    ROUGHNESS = 0.96; SPECULAR = 0.12;
}
"""
	_lumber_earth = ShaderMaterial.new()
	_lumber_earth.shader = shader
	return _lumber_earth

static func _warehouse(source: Node3D) -> Node3D:
	# Recompose around the original full-size hall and its central loading aisle.
	# Removing the annex frees two cells without shrinking doors, sacks or carts.
	var root := Warehouse.create_warehouse(source)
	root.name = "CompactWarehouseLoadingCourt"
	root.find_child("WarehouseFoundation", true, false).hide()
	Kit.box(root, "CompactWarehouseFoundation", Vector3(4.18, 0.20, 4.18), Vector3(0, 0.10, 0), _mat("stone", "a5987b"))
	root.set_meta("open_loading_court", true)
	root.set_meta("compact_warehouse", true)
	return root

static func _crate(root: Node3D, pos: Vector3, size: Vector3) -> void:
	Kit.box(root, "PlankedCrate", size, pos, _mat("wood", "a58d66"))
	for side in [-1.0, 1.0]:
		Kit.box(root, "CrateStrap", Vector3(0.035, size.y + 0.02, size.z + 0.02), pos + Vector3(side * size.x * 0.35, 0, 0), _mat("wood", "766648"))

static func _workshop(source: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "CarpentersWorkingCourt"
	_floor(root, 4.18)
	var old := Workshop.rebuild(source)
	old.position = Vector3(-1.90, 0, -0.78)
	root.add_child(old)
	old.get_node("WorkshopFoundation").hide()
	old.find_child("FireproofFloor", true, false).hide()
	_plank_shelter(root, Vector3(1.57, 0, -0.95), 2.55, 1.68, 1.42)
	_bench(root, Vector3(1.48, 0, -0.77), Vector2(1.9, 0.65))
	for i in range(7):
		Kit.box(root, "JoineryStock", Vector3(0.17, 0.06, 0.56), Vector3(0.83 + i * 0.19, 0.79, -0.77), _mat("wood", "c3ab80"))
	_bench(root, Vector3(1.30, 0, 0.95), Vector2(1.65, 0.65))
	for i in range(3):
		_crate(root, Vector3(-2.4 + i * 0.55, 0.48, 1.27), Vector3(0.46, 0.42, 0.52))
	for side in [-1.0, 1.0]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.23
		ring.outer_radius = 0.29
		ring.rings = 24
		ring.ring_segments = 8
		var wheel := Kit.piece(root, "UnfinishedCartWheel", ring, Vector3(2.65, 0.58, side * 0.39 + 0.45), _mat("wood", "9d825b"))
		wheel.rotation.z = PI * 0.5
		for i in range(6):
			var spoke := Kit.box(wheel, "WheelSpoke", Vector3(0.48, 0.04, 0.04), Vector3.ZERO, _mat("wood", "9d825b"))
			spoke.rotation.y = i * PI / 3
	Kit.anchor(root, "ArtisanAnchor", Vector3(1.35, 0.25, 0.39))
	return root

static func _hall(root: Node3D, source: Node3D, pos: Vector3, width: float, depth: float) -> void:
	var hall := Kit.branch(root, "CompleteRoofHall")
	hall.position = pos
	var parts := Kit.collect_parts(source)
	var plaster := _mat("stone", "c6c1a7")
	var wood := _mat("wood", "786b53")
	Kit.box(hall, "RaisedTimberFloor", Vector3(width, 0.12, depth), Vector3(0, 0.3, 0), wood)
	Kit.box(hall, "RearPlasterWall", Vector3(width, 1.1, 0.1), Vector3(0, 0.91, -depth * 0.5), plaster)
	for side in [-1.0, 1.0]:
		Kit.box(hall, "SidePlasterWall", Vector3(0.1, 1.1, depth), Vector3(side * width * 0.5, 0.91, 0), plaster)
		for z in [-depth * 0.44, depth * 0.44]:
			Kit.box(hall, "StructuralPost", Vector3(0.10, 1.23, 0.10), Vector3(side * width * 0.45, 0.93, z), wood)
	Kit.box(hall, "FrontLintel", Vector3(width, 0.13, 0.12), Vector3(0, 1.48, depth * 0.48), wood)
	# Copy the complete original roof, including individually curved tiles.
	Kit.copy_roof(parts, hall, Transform3D(Basis.from_scale(Vector3(width / 2.20, 0.71, depth / 2.0)), Vector3(0, 0.23, 0)))
	for side in [-1.0, 1.0]:
		Kit.gable(hall, "PlasterGable", side * width * 0.5, -depth * 0.5, depth * 0.5, 1.45, 1.95, plaster)

static func _weaver(source: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "WeavingAndDryingCourt"
	_floor(root, 4.18)
	_hall(root, source, Vector3(-1.45, 0, -1.08), 2.85, 1.40)
	source.free()
	_plank_shelter(root, Vector3(1.71, 0, -0.92), 2.14, 1.78, 1.53)
	for x in [-2.10, -0.76]:
		_loom(root, Vector3(x, 0, -0.59))
	# Broad hanging cloth is the primary top-view identity, ahead of the hall.
	for x in [0.80, 2.73]:
		Kit.cylinder(root, "DryingRackPost", 0.035, 1.63, Vector3(x, 1.05, 1.04), _mat("wood", "938157"))
	Kit.box(root, "DryingRackBeam", Vector3(2.10, 0.045, 0.045), Vector3(1.77, 1.84, 1.04), _mat("wood", "938157"))
	for i in range(4):
		var fabric := _mat("cloth", ["c8c2a5", "81958c", "b5a6b9", "a9b9b0"][i])
		for fold in range(6):
			Kit.box(root, "HangingWovenCloth", Vector3(0.076, 1.12, 0.017), Vector3(0.87 + i * 0.47 + fold * 0.072, 1.26, 1.04 + sin(fold * 1.6) * 0.027), fabric)
	for i in range(5):
		var spool := Kit.cylinder(root, "YarnSpool", 0.10, 0.31, Vector3(1.0 + i * 0.33, 0.68, -0.65), _mat("cloth", "c6b78f"))
		spool.rotation.z = PI * 0.5
	_bench(root, Vector3(1.75, 0, -0.7), Vector2(1.8, 0.52))
	Kit.anchor(root, "ArtisanAnchor", Vector3(-0.80, 0.25, 0.24))
	return root

static func _loom(root: Node3D, pos: Vector3) -> void:
	var loom := Kit.branch(root, "OpenTimberLoom")
	loom.position = pos
	var wood := _mat("wood", "a89068")
	for x in [-0.34, 0.34]:
		for z in [-0.26, 0.26]:
			Kit.box(loom, "LoomUpright", Vector3(0.055, 0.87, 0.055), Vector3(x, 0.69, z), wood)
	for z in [-0.26, 0.26]:
		Kit.box(loom, "LoomCrossbar", Vector3(0.77, 0.07, 0.07), Vector3(0, 1.1, z), wood)
	for i in range(18):
		var thread := Kit.box(loom, "WarpThread", Vector3(0.008, 0.012, 0.69), Vector3(-0.28 + i * 0.033, 0.81, 0), _mat("cloth", "d5c9a8"))
		thread.rotation.x = -0.45
	Kit.box(loom, "WovenWeb", Vector3(0.56, 0.018, 0.27), Vector3(0, 0.73, 0.29), _mat("cloth", "bdb899"))
	Kit.box(loom, "WeaverSeat", Vector3(0.55, 0.07, 0.23), Vector3(0, 0.49, 0.55), wood)
	for x in [-0.2, 0.2]:
		Kit.box(loom, "SeatLeg", Vector3(0.05, 0.22, 0.16), Vector3(x, 0.36, 0.55), wood)

static func _market() -> Node3D:
	var root := Market.create_market()
	root.name = "OpenMarketStreets"
	root.get_node("StoneCourt").hide()
	for paver in root.find_children("Paving_*", "MeshInstance3D", true, false):
		paver.hide()
	_floor(root, 6.38)
	for i in range(4):
		var stall := root.get_node("Stall_%d" % i) as Node3D
		stall.position.x = -2.05 if i < 2 else 2.05
		stall.position.z = -1.12 if i % 2 == 0 else 1.14
	for i in range(2):
		var stall := Kit.branch(root, "RearStall_%d" % i)
		stall.position = Vector3(-0.98 if i == 0 else 0.98, 0.26, -2.30)
		Market.create_stall(stall, i + 2, Color("a99a76") if i == 0 else Color("8a9990"))
	for i in range(6):
		Kit.anchor(root, "VendorAnchor_%d" % i, Vector3(-2.1 if i < 2 else (2.1 if i < 4 else (-0.98 if i == 4 else 0.98)), 0.28, (-1.12 if i % 2 == 0 else 1.14) if i < 4 else -2.32))
	return root

static func _pond(preview: bool) -> Node3D:
	var root := Pond.create_pond(preview)
	root.name = "BroadEarthenFishpond"
	# Change only terrain/water geometry. Dock planks, baskets, plants and fish
	# retain world dimensions; no whole-building stretch.
	(root.get_node("PondBed") as MeshInstance3D).scale.z = 5.94 / 3.74
	(root.get_node("PondWater") as MeshInstance3D).scale.z = 5.96 / 3.76
	(root.get_node("EarthenBanks") as MeshInstance3D).scale.z = 3.215 / 2.115
	(root.get_node("FeedingDock") as Node3D).position.z += 1.08
	for child in root.get_children():
		if child is Node3D and (str(child.name).begins_with("BankGrass") or str(child.name).begins_with("PondReed") or str(child.name).begins_with("ReedLeaf") or str(child.name).begins_with("BedPebble")):
			child.position.z *= 1.50
	_plank_shelter(root, Vector3(-2.30, 0, 2.51), 1.18, 0.8, 1.18)
	return root

static func _academy(source: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "AcademyCourtyard"
	_floor(root, 6.38)
	_hall(root, source, Vector3(0, 0, -2.07), 4.6, 1.46)
	source.free()
	for side in [-1.0, 1.0]:
		_plank_shelter(root, Vector3(side * 2.43, 0, 0.05), 1.16, 3.44, 1.45)
		for i in range(3):
			_bench(root, Vector3(side * 2.42, 0, -1.0 + i * 0.98), Vector2(0.65, 0.48))
		Kit.box(root, "CourtyardSideWall", Vector3(0.10, 0.65, 5.9), Vector3(side * 3.07, 0.55, 0), _mat("stone", "c6c1ac"))
		Kit.box(root, "GateWing", Vector3(2.02, 0.66, 0.12), Vector3(side * 2.00, 0.55, 3.00), _mat("stone", "c6c1ac"))
		for i in range(5):
			var pos := Vector3(side * (1.17 + (i % 2) * 0.18), 0.76, 1.2 + (i / 2) * 0.19)
			Kit.cylinder(root, "CourtyardBamboo", 0.02, 1.05, pos, _mat("wood", "7c8960"))
			for leaf in range(3):
				var foliage := Kit.sphere(root, "BambooLeaves", Vector3(0.42, 0.12, 0.13), pos + Vector3(side * 0.1, 0.16 + leaf * 0.16, 0), _mat("", "788760"))
				foliage.rotation.z = side * 0.35
	for i in range(3):
		_bench(root, Vector3(-1.4 + i * 1.4, 0, -1.76), Vector2(0.9, 0.45))
		Kit.box(root, "ReadingScroll", Vector3(0.38, 0.012, 0.25), Vector3(-1.4 + i * 1.4, 0.763, -1.76), _mat("cloth", "dbd0b2"))
	Kit.text_sign(root, "书 院", Vector3(0, 1.48, -1.26), 0.003, Color("d6cba5"))
	return root
