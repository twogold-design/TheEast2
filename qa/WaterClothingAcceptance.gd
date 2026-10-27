extends SceneTree
## Pure in-memory economy fixtures: no player save files or Main startup.
const Economy = preload("res://godot/economy/SettlementEconomy.gd")
var failures: Array[String] = []

func _initialize() -> void:
	consumption_and_unlocks()
	water_production_and_recovery()
	regional_delivery_and_persistence()
	unlimited_production_and_warehouses()
	legacy_normalization()
	alternate_water_supplier()
	warehouse_capacity_regression()
	if failures.is_empty():
		print("PASS WaterClothingAcceptance: real water/clothing consumption, unlock, shortage recovery, regional routes, save, no transport quota")
	else:
		for item in failures: push_error(item)
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)

func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.0001, "%s (actual=%s expected=%s)" % [label, actual, expected])

func record(id: int, kind: String, region := "0", connected := true) -> Dictionary:
	return {"id":str(id), "type":kind, "region":region, "connected":connected}

func household_fixture(level := 0):
	var e = Economy.new()
	e.reset({"population":4,"food":100,"water":40,"wood":100,"coins":100,"cloth":10,"happiness":60})
	e.immigration_enabled = false
	e.sync_buildings([record(1,"house")])
	e.set_unlock_level(level)
	return e

func consumption_and_unlocks() -> void:
	var farmers = household_fixture()
	farmers.advance(60)
	near(farmers.snapshot().goods.water,38,"four farmers actually drink two water per day")
	near(farmers.snapshot().goods.food,98,"food still independently consumed")
	near(farmers.snapshot().goods.cloth,10,"farmer clothes not consumed before chain unlock")
	near(farmers.snapshot().households["1"].needs.cloth,0,"locked clothes have zero stated demand")
	farmers.set_unlock_level(1)
	var before: Dictionary = farmers.snapshot()
	farmers.advance(60)
	var after: Dictionary = farmers.snapshot()
	near(after.goods.cloth,9,"four farmers consume one cloth per day after unlock")
	near(after.households["1"].needs.cloth,1,"farmer demand matches actual daily consumption")
	near(after.households["1"].supply.cloth,1,"real clothes delivery reports full supply")
	near(after.coins-before.coins,3,"tax plus actual clothing consumption income")
	check(after.happiness > before.happiness,"actual clothing supply improves happiness")
	var artisan = household_fixture(1)
	artisan.households["1"].tier = "artisan"
	artisan.advance(60)
	near(artisan.snapshot().goods.cloth,8,"four artisans consume two clothes per day demand")
	near(artisan.snapshot().goods.water,36,"four artisans drink four water per day")
	near(artisan.snapshot().goods.food,96,"four artisans eat four food per day")
	near(artisan.snapshot().households["1"].needs.water,4,"artisan water demand doubles ordinary residents")
	near(artisan.snapshot().households["1"].needs.food,4,"artisan food demand doubles ordinary residents")
	near(artisan.snapshot().households["1"].needs.cloth,2,"artisan daily demand is explicit")
	var missing = household_fixture(1)
	missing.apply_resources({"food":-80})
	missing.apply_resources({"cloth":-10})
	missing.sync_buildings([record(1,"house"),record(2,"house"),record(3,"farm"),record(4,"well")])
	missing.immigration_enabled = true
	missing.advance(59.75)
	check(missing.population == 6 and not missing.failed,"brief clothing shortage allows initial migration before dissatisfaction")
	check(missing.snapshot().building_status["1"].reason.contains("衣"),"house identifies absent clothing")
	check(missing.snapshot().building_status["3"].ok,"missing clothing does not stop food production")
	missing.apply_resources({"cloth":10})
	missing.advance(0.25)
	near(missing.snapshot().households["1"].supply.cloth,1,"clothing recovers automatically without a switch")

func water_production_and_recovery() -> void:
	check(Economy.CATALOG.well.footprint == Vector2i(2,2),"well occupies four cells")
	var e = household_fixture()
	e.sync_buildings([record(1,"house"),record(2,"well")])
	e.advance(60)
	near(e.snapshot().goods.water,48,"well10 minus residents2 gives8 real water per day")
	near(e.snapshot().coins,102,"well has no maintenance charge")
	var disconnected := record(2,"well","0",false)
	e.sync_buildings([record(1,"house"),disconnected])
	e.advance(60)
	near(e.snapshot().goods.water,46,"disconnected well produces no water")
	check(e.snapshot().building_status["2"].reason == "未连通主干路","well has precise disconnected status")
	var dry = household_fixture()
	dry.apply_resources({"water":-40})
	dry.sync_buildings([record(1,"house"),record(2,"house")])
	dry.immigration_enabled = true
	dry.advance(29.75)
	check(dry.population == 4 and not dry.failed,"brief lack of water is not an instant failure")
	dry.advance(0.25)
	check(dry.population == 4 and dry.snapshot().immigration_status.contains("水"),"sustained water shortage explains blocked migration")
	dry.advance(29.75)
	check(dry.population == 4 and dry.happiness < 60,"water shortage gradually lowers happiness before departure")
	var clone = Economy.new()
	check(clone.restore(JSON.parse_string(JSON.stringify(dry.serialize()))),"thirst countdown saves and restores")
	near(clone.snapshot().water_shortage_seconds,dry.snapshot().water_shortage_seconds,"persisted water shortage timing")
	dry.advance(0.25)
	clone.advance(0.25)
	check(dry.population == 3 and clone.population == 3,"long shortage causes a recoverable single departure")
	dry.sync_buildings([record(1,"house"),record(2,"house"),record(3,"well")])
	dry.advance(1)
	near(dry.snapshot().households["1"].supply.water,1,"staffed well restores drinking automatically")
	near(dry.snapshot().water_shortage_seconds,0,"recovery clears drought timer")
	dry.advance(120)
	check(dry.population > 3 and not dry.failed,"water recovery permits growth again")

func connect_all(records: Array, distance := 20) -> void:
	for a in records:
		a.road_links = {}
		for b in records:
			if a.id != b.id: a.road_links[str(b.id)] = distance

func regional_delivery_and_persistence() -> void:
	var e = Economy.new()
	e.reset({"population":8,"food":100,"water":100,"cloth":10,"coins":100})
	e.set_unlock_level(1)
	e.immigration_enabled = false
	var records := [record(1,"house"),record(2,"house","1"),record(3,"well")]
	connect_all(records)
	e.sync_buildings(records)
	e.advance(2)
	near(e.snapshot().regions["1"].goods.water,0,"regional drinking water never teleports before journey finishes")
	var water_cargo := false
	var cloth_cargo := false
	for cargo in e.shipments:
		water_cargo = water_cargo or cargo.good == "water"
		cloth_cargo = cloth_cargo or cargo.good == "cloth"
	check(water_cargo and cloth_cargo,"automatic real cargo includes water and farmer clothes")
	for item in records: item.road_links = {}
	e.sync_buildings(records)
	var remaining := float(e.shipments[0].remaining)
	e.advance(2)
	near(e.shipments[0].remaining,remaining,"broken road preserves in-transit cargo without delivering")
	var clone = Economy.new()
	check(clone.restore(JSON.parse_string(JSON.stringify(e.serialize()))),"water/clothes cargo state roundtrips")
	check(clone.snapshot().clothing_unlocked,"farmer clothes unlock survives persistence")
	connect_all(records)
	e.sync_buildings(records)
	clone.sync_buildings(records)
	e.advance(30)
	clone.advance(30)
	var snapshot: Dictionary = e.snapshot()
	near(snapshot.households["2"].supply.water,1,"repaired route supplies distant drinking water")
	near(snapshot.households["2"].supply.cloth,1,"repaired route supplies distant farmer clothes")
	check(same(e.serialize(),clone.serialize()),"restored cargo and consumption continue deterministically")
	var base_route: Dictionary = e._route("0","1")
	records.append(record(4,"freight"))
	connect_all(records)
	e.sync_buildings(records)
	var fast_route: Dictionary = e._route("0","1")
	check(fast_route.duration < base_route.duration,"staffed freight station makes actual road delivery faster")

func unlimited_production_and_warehouses() -> void:
	var e = Economy.new()
	e.reset({"population":32,"food":40,"water":40,"wood":40,"coins":500})
	e.immigration_enabled = false
	var records: Array = []
	for i in 8: records.append(record(i+1,"house"))
	for kind in ["farm","farm","farm","farm","lumber","lumber","well","well","warehouse","warehouse"]:
		records.append(record(records.size()+1,kind))
	e.sync_buildings(records)
	e.advance(60)
	var snapshot: Dictionary = e.snapshot()
	near(snapshot.goods.food,56,"four farms run full output with 32 residents")
	near(snapshot.goods.wood,64,"two lumberyards run full output with other industries")
	near(snapshot.goods.water,44,"two wells run full output with other industries")
	check(snapshot.capacity == 200,"two connected warehouses stack physical storage")
	for status in snapshot.building_status.values():
		check(not str(status.reason).contains("运力"),"no removed transport quota warnings")

func legacy_normalization() -> void:
	var source = household_fixture(1)
	source.advance(1)
	var original: Dictionary = source.serialize()
	var damaged: Dictionary = original.duplicate(true)
	damaged.stock.erase("water")
	var receiver = Economy.new()
	check(not receiver.restore(damaged),"new-format save missing water is rejected as damaged")
	var legacy: Dictionary = original.duplicate(true)
	legacy.stock.erase("water")
	legacy.policies.erase("water")
	legacy.erase("thirst_clock")
	legacy.erase("unlocked_level")
	for goods in legacy.regions.values(): goods.erase("water")
	for policies in legacy.regional_policies.values(): policies.erase("water")
	for h in legacy.households.values(): h.buffer.erase("water")
	for sample in legacy.rate_samples: sample.delta.erase("water")
	var before: Dictionary = legacy.duplicate(true)
	check(receiver.restore(legacy),"complete previous schema normalizes in memory")
	check(legacy == before,"normalization never mutates the supplied old save")
	near(receiver.snapshot().goods.water,Economy.INITIAL_WATER,"normalized old world receives initial water")

func same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < 0.00000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not same(a[i],b[i]): return false
		return true
	return a == b

func alternate_water_supplier() -> void:
	var e = Economy.new()
	e.reset({"population":4,"food":100,"water":100,"coins":100})
	e.immigration_enabled = false
	var records := [record(1,"house","1"),record(2,"warehouse","0"),record(3,"warehouse","2")]
	records[0].road_links = {"2":40}
	records[1].road_links = {"1":40}
	records[2].road_links = {}
	e.sync_buildings(records)
	e._add("2","water",e._units(100))
	var physical_before: int = e._physical_goods().water
	e._dispatch_shipments()
	var first_quantity := 0
	for cargo in e.shipments:
		if cargo.good == "water" and cargo.source == "0" and cargo.destination == "1": first_quantity += int(cargo.quantity)
	check(first_quantity > 0,"first source dispatches drinking water before road breaks")
	records[0].road_links = {"3":20}
	records[1].road_links = {}
	records[2].road_links = {"1":20}
	e.sync_buildings(records)
	e._dispatch_shipments()
	var alternate_quantity := 0
	var reserved_quantity := 0
	for cargo in e.shipments:
		if cargo.good != "water" or cargo.destination != "1": continue
		reserved_quantity += int(cargo.quantity)
		if cargo.source == "2": alternate_quantity += int(cargo.quantity)
	check(alternate_quantity > 0,"stranded first shipment does not block available third-region water")
	check(e._local("1","water") + reserved_quantity <= e._region_capacity("1","water"),"all stranded and moving cargo reserve unloading capacity")
	near(e._value(e._local("1","water")),0,"replacement delivery also waits for actual travel")
	for tick in 60: e._advance_shipments()
	near(e._value(e._local("1","water")),e._value(alternate_quantity),"alternate water arrives while original route remains broken")
	check(e._physical_goods().water == physical_before,"replacement dispatch preserves total physical water")
	connect_all(records,20)
	e.sync_buildings(records)
	for tick in 60: e._advance_shipments()
	near(e._value(e._local("1","water")),e._value(first_quantity + alternate_quantity),"reconnection unloads original cargo exactly once")
	check(e._physical_goods().water == physical_before,"restored original route never duplicates or destroys drinking water")
	check(e._local("1","water") <= e._region_capacity("1","water"),"reconnected cargo respects destination storage")

func warehouse_capacity_regression() -> void:
	var e = Economy.new()
	e.reset({"population":8,"food":100,"water":50,"wood":100,"coins":100,"happiness":60})
	e.immigration_enabled = false
	var records := [record(1,"house"),record(2,"house"),record(3,"warehouse"),record(4,"well"),record(5,"farm"),record(6,"lumber")]
	e.sync_buildings(records)
	e._add("0","food",e._units(50))
	near(e.snapshot().goods.food,150,"existing food inventory reaches150 inside expanded warehouse")
	check(e.snapshot().capacity == 150 and e.snapshot().food_capacity == 150,"connected warehouse raises actual capacity")
	check(e.promote_house("1") == "","capacity fixture uses real artisan renovation")
	e.advance(60)
	records.append(record(7,"hemp_farm"))
	e.sync_buildings(records)
	check(e.snapshot().normal_workers == 4 and e.snapshot().available_normal == 0,"conversion and hemp farming genuinely exhaust normal labor")
	check(e.snapshot().capacity == 150 and e.snapshot().food_capacity == 150,"lack of normal labor never removes connected warehouse capacity")
	check(e.snapshot().building_status["3"].ok and e.snapshot().building_status["3"].required_workers == 0,"warehouse only needs its road connection")
	var before: float = e.snapshot().goods.food
	e.set_unlock_level(2)
	check(e.snapshot().capacity == 150 and e.snapshot().goods.food == before,"unlocking territory does not reset existing capacity or stocks")
	records[2].connected = false
	e.sync_buildings(records)
	check(e.snapshot().capacity == 100 and e.snapshot().goods.food == before and before > 100,"real disconnection lowers capacity while preserving existing overflow")
	records.remove_at(2)
	e.sync_buildings(records)
	check(e.snapshot().capacity == 100 and e.snapshot().goods.food == before,"demolition retains physical overflow instead of truncating stock")
	var regional = Economy.new()
	regional.reset({"population":4,"food":100,"coins":100})
	var near_home := record(1,"house")
	var far_home := record(2,"house","1",false)
	var remote_warehouse := record(4,"warehouse","1",false)
	var regional_records := [near_home,far_home,record(3,"warehouse"),remote_warehouse]
	regional.sync_buildings(regional_records)
	regional._add("1","food",regional._units(20))
	regional._add("1","cloth",regional._units(10))
	check(regional.snapshot().capacity == 150 and regional.snapshot().food_capacity == 150,"inaccessible region does not inflate resource denominators")
	near(regional.snapshot().goods.food,100,"inaccessible goods excluded from matching numerator")
	far_home.connected = true
	regional.sync_buildings(regional_records)
	check(regional.snapshot().capacity == 250 and regional.snapshot().food_capacity == 250,"reconnected region adds its real base capacity")
	near(regional.snapshot().goods.food,120,"reconnected region adds the same region inventory")
	remote_warehouse.connected = true
	regional.sync_buildings(regional_records)
	check(regional.snapshot().capacity == 300 and regional.snapshot().food_capacity == 300,"remote connected warehouse contributes even without local workers")
