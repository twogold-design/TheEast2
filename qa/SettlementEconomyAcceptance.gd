extends SceneTree
const Economy = preload("res://godot/economy/SettlementEconomy.gd")
var errors: Array[String] = []
func _initialize() -> void:
	var e = Economy.new()
	e.sync_buildings([_record(1,"house"),_record(2,"house"),_record(3,"farm"),_record(4,"lumber")])
	e.advance(29.75)
	_check(e.population == 4,"migration waits 30 simulation seconds")
	e.advance(0.25)
	_check(e.population == 6,"first migration arrives at 30 seconds")
	e.advance(30)
	_check(e.population == 8,"opening reaches 8 without a workshop")
	var blocked = Economy.new()
	blocked.reset({"population":4,"food":0,"coins":100,"happiness":70})
	blocked.sync_buildings([_record(1,"house"),_record(2,"house")])
	blocked.advance(31)
	_check(blocked.population == 4 and blocked.migration_clock == 30,"blocked migration retains mature timer")
	blocked.apply_resources({"food":30})
	blocked.advance(0.25)
	_check(blocked.population == 6,"restored conditions immediately permit immigration")
	var export = Economy.new()
	export.sync_buildings([_record(1,"house"),_record(2,"house"),_record(3,"farm")])
	export.set_trade_policy("food","sell",4)
	export.advance(60)
	_check(export.population == 8,"food exports do not block new arrivals")
	var home = Economy.new()
	home.reset({"population":4,"food":100,"wood":100,"coins":100,"happiness":60,"cloth":10})
	home.immigration_enabled = false
	home.sync_buildings([_record(1,"house")])
	home.advance(60)
	_check(home.snapshot().goods.tools == 0 and home.snapshot().goods.cloth == 10,"farmer homes do not craft or consume optional goods")
	_check(home.promote_house("1") == "","promotion only requires occupied home, happiness55, wood12 and coins8")
	_check(home.households["1"].tier == "farmer","construction does not immediately change resident class")
	home.advance(59.75)
	_check(home.households["1"].tier == "farmer","one day construction completes only after 60 simulated seconds")
	home.advance(0.25)
	_check(home.households["1"].tier == "artisan","construction completes and exposes artisan workers immediately")
	var before: Dictionary = home.snapshot()
	home.advance(60)
	var after: Dictionary = home.snapshot()
	_check(after.goods.tools == before.goods.tools,"artisan homes do not produce goods implicitly")
	_check(after.goods.wood == before.goods.wood,"homes have no implicit wood consumption")
	_check(after.available_artisan == 4 and after.workforce == 4,"each resident supplies exactly one worker with no home reservation")
	var state: Dictionary = home.serialize()
	var clone = Economy.new()
	_check(clone.restore(JSON.parse_string(JSON.stringify(state))),"version2 state roundtrip succeeds")
	home.advance(11.75)
	clone.advance(11.75)
	_check(_same(home.serialize(),clone.serialize()),"complete save roundtrip preserves deterministic accounting")
	var chunks = Economy.new()
	chunks.restore(home.serialize())
	home.advance(20)
	for i in 80: chunks.advance(0.25)
	_check(home.serialize() == chunks.serialize(),"large frames and fixed ticks are equivalent")
	var paused: Dictionary = home.serialize()
	home.advance(0)
	_check(paused == home.serialize(),"pause does not advance construction or economy")
	var chain = Economy.new()
	chain.reset({"population":80,"coins":1000,"food":1000,"wood":100,"hemp":100,"clay":100,"bamboo":100})
	var chain_records: Array = []
	for i in 20: chain_records.append(_record(i+1,"house"))
	for i in ["warehouse","workshop","weaver","tea_farm","claypit","kiln","bamboo","papermill","freight"]:
		chain_records.append(_record(chain_records.size()+1,i))
	chain.sync_buildings(chain_records)
	chain.immigration_enabled = false
	for id in ["1","2","3"]: chain.households[id].tier = "artisan"
	chain._rebuild()
	chain.advance(60)
	for good in ["cloth","tea","pottery","paper"]:
		_check(chain.snapshot().goods[good] > 0,"complete production chain produces " + good)
	_check(Economy.CATALOG.size() == 26 and Economy.SPECS.size() == 26,"all26 building types have real economic definitions")
	for kind in Economy.CATALOG:
		_check(kind == "house" or Economy.CATALOG[kind].footprint.x * Economy.CATALOG[kind].footprint.y >= 4,"nonresidential footprint is at least four: " + kind)
	var disconnected = Economy.new()
	disconnected.sync_buildings([_record(1,"house"),_record(2,"warehouse",false),_record(3,"farm",false)])
	disconnected.advance(1)
	_check(disconnected.snapshot().capacity == 100,"disconnected warehouse adds no capacity")
	_check(disconnected.snapshot().building_status["3"].reason == "未连通主干路","disconnected production has readable status")
	_test_regional_cargo()
	_test_water_and_services()
	_test_local_payment()
	_test_player_routes()
	_test_migration_food_and_worker_assignment()
	_test_rates_exclude_transport()
	_test_opening_transport_and_fairness()
	_test_strict_worker_classes()
	_test_construction_requires_connection()
	_test_quantity_orders()
	_test_workshop_direct_income()
	var failure = Economy.new()
	failure.reset({"food":0,"coins":100,"population":4,"happiness":20})
	failure.sync_buildings([_record(1,"house")])
	failure.advance(300)
	_check(failure.failed and failure.population == 0,"hunger departures can cause population failure")
	var cash_failure = Economy.new()
	cash_failure.reset({"coins":0.001,"population":1,"food":100})
	cash_failure.sync_buildings([_record(1,"clinic")])
	cash_failure.advance(2)
	_check(cash_failure.failed,"maintenance can cause zero-coin failure")
	var ledger = Economy.new()
	_check(not ledger.apply_resources({"wood":-1000,"coins":10}) and ledger.snapshot().coins == 60,"construction payment is atomic")
	var corrupt: Dictionary = home.serialize()
	corrupt.households["1"].buffer = {"food":-1}
	var before_reject: Dictionary = home.serialize()
	_check(not home.restore(corrupt) and home.serialize() == before_reject,"corrupt save rejected without mutating live economy")
	if errors.is_empty():
		print("PASS SettlementEconomyAcceptance: 30s migration, mature clock retention, construction, strict worker pools, eleven goods,26 buildings, exact save, cargo reservation, road interruption, real failures")
		quit(0)
	else:
		for error in errors: push_error(error)
		quit(1)

func _test_regional_cargo() -> void:
	var e = Economy.new()
	e.reset({"population":8,"food":100,"wood":100,"coins":100})
	e.immigration_enabled = false
	var records: Array = [_record(1,"house"),_record(2,"house"),_record(3,"farm"),_record(4,"warehouse")]
	records[1].region = "1"
	records[3].region = "1"
	for a in records:
		a.road_links = {}
		for b in records:
			if a.id != b.id: a.road_links[str(b.id)] = 20
	e.sync_buildings(records)
	e.advance(2)
	_check(not e.shipments.is_empty(),"regional demand dispatches real reserved cargo")
	_check(e.snapshot().regions["1"].goods.food == 0,"distant food does not teleport before travel finishes")
	var total := 0
	for cargo in e.shipments: total += int(cargo.quantity)
	_check(total > 0,"in-transit cargo has reserved stock")
	for record in records: record.road_links = {}
	e.sync_buildings(records)
	var remaining: float = e.shipments[0].remaining
	e.advance(1)
	_check(e.shipments[0].remaining == remaining and e.snapshot().regions["1"].goods.food == 0,"broken routes pause without deleting or delivering cargo")
	for a in records:
		for b in records:
			if a.id != b.id: a.road_links[str(b.id)] = 20
	e.sync_buildings(records)
	e.advance(15)
	_check(e.snapshot().regions["1"].goods.food > 0,"restored real road eventually delivers goods")
	var clone = Economy.new()
	_check(clone.restore(JSON.parse_string(JSON.stringify(e.serialize()))),"in-flight cargo survives save restore")
	e.advance(7)
	clone.advance(7)
	_check(_same(e.serialize(),clone.serialize()),"regional route save roundtrip preserves reserved cargo deterministically")

func _record(id: int, kind: String, connected: bool = true) -> Dictionary:
	return {"id":str(id),"type":kind,"connected":connected,"region":"0"}

func _check(condition: bool,message: String) -> void:
	if not condition: errors.append(message)

func _same(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < 0.00000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _same(a[i],b[i]): return false
		return true
	return a == b

func _test_water_and_services() -> void:
	var e = Economy.new()
	e.reset({"population":24,"food":100,"coins":500,"wood":100})
	e.immigration_enabled = false
	var records: Array = []
	for i in 6:
		var r := _record(i+1,"house")
		r.region = "0" if i < 3 else "1"
		records.append(r)
	var first := _record(7,"dock")
	first.water_links = {"8":10}
	var second := _record(8,"dock")
	second.region = "1"
	second.water_links = {"7":10}
	records.append(first)
	records.append(second)
	for a in records:
		a.road_links = {}
		for b in records:
			if a.id != b.id: a.road_links[str(b.id)] = 5 if a.region == b.region else 100
	e.sync_buildings(records)
	e.advance(2)
	var water := false
	for cargo in e.shipments:
		if cargo.mode == "water": water = true
	_check(water,"two staffed docks choose actual shorter water path")
	e.advance(5)
	_check(e.snapshot().regions["1"].goods.food > 0,"water cargo arrives and feeds real region inventory")
	var orchard = Economy.new()
	orchard.reset({"food":20,"population":4,"coins":100})
	orchard.sync_buildings([_record(1,"house"),_record(2,"orchard")])
	orchard.immigration_enabled = false
	orchard.advance(89.75)
	var before := float(orchard.snapshot().goods.food)
	orchard.advance(0.25)
	_check(orchard.snapshot().goods.food > before + 20,"orchard has actual batched harvest")
	var services = Economy.new()
	services.reset({"population":16,"food":200,"coins":500,"tea":10,"paper":10})
	var service_records: Array = []
	for i in 4: service_records.append(_record(i+1,"house"))
	for kind in ["market","clinic","academy","theater","teahouse"]:
		service_records.append(_record(service_records.size()+1,kind))
	services.sync_buildings(service_records)
	services.immigration_enabled = false
	services.advance(60)
	_check(services.snapshot().goods.tea < 10 and services.snapshot().goods.paper < 10,"tea and academy paper are real optional consumption")
	_check(services._services() <= 26.001,"academy and theater do not stack same culture category")
	var empty_services = Economy.new()
	empty_services.reset({"population":4,"food":100,"coins":100,"tea":10,"paper":10})
	var empty_tea := _record(2,"teahouse")
	var empty_school := _record(3,"academy")
	empty_tea.service_targets = {}
	empty_school.service_targets = {}
	empty_services.sync_buildings([_record(1,"house"),empty_tea,empty_school])
	empty_services.immigration_enabled = false
	empty_services.advance(60)
	_check(empty_services.snapshot().goods.tea == 10 and empty_services.snapshot().goods.paper == 10,"services without reachable residents neither consume supplies nor invent customers")
	var invalid: Dictionary = services.serialize()
	invalid.regions["0"].wood += 1
	_check(not services.restore(invalid),"regional totals must reconcile with authoritative stock")

func _test_local_payment() -> void:
	var e = Economy.new()
	e.reset({"wood":100})
	e.immigration_enabled = false
	var records: Array = [_record(1,"house"),_record(2,"farm"),_record(3,"lumber")]
	e.sync_buildings(records)
	_check(e.snapshot().building_status["2"].workers == 2 and e.snapshot().building_status["3"].workers == 2,"four residents fill four ordinary jobs exactly")
	var far := _record(4,"house",false)
	far.region = "1"
	records.append(far)
	e.sync_buildings(records)
	e._add("1","wood",e._units(50))
	_check(e.snapshot().goods.wood == 100,"disconnected stocks do not count toward settlement goals")
	_check(not e.apply_resources({"wood":-110}),"construction cannot withdraw disconnected inventory")
	_check(not e.apply_resources({"wood":-1},false,"1"),"local payment requires road access")
	records[3].connected = true
	e.sync_buildings(records)
	_check(e.snapshot().goods.wood == 150,"reconnection restores visible resources without duplication")
	_check(e.apply_resources({"wood":-12},false,"1") and e.snapshot().regions["0"].goods.wood == 100 and e.snapshot().regions["1"].goods.wood == 38,"local renovation payment never takes distant wood")

func _test_player_routes() -> void:
	var e = Economy.new()
	e.reset({"population":4,"food":100,"coins":100,"bamboo":100})
	e.immigration_enabled = false
	var records: Array = [_record(1,"house"),_record(2,"warehouse"),_record(3,"warehouse")]
	records[2].region = "1"
	for a in records:
		a.road_links = {}
		for b in records:
			if a.id != b.id: a.road_links[str(b.id)] = 20
	e.sync_buildings(records)
	_check(not e.set_route("0","0","bamboo",10,4) and not e.set_route("0","1","bamboo",10,1.5),"player routes validate regions and whole-unit batch limits")
	_check(e.set_route("0","1","bamboo",10,4),"player can create an actual transfer route")
	e.advance(2)
	var cargo_count: int = e.shipments.size()
	_check(cargo_count > 0 and e.snapshot().regions["1"].goods.bamboo == 0,"configured route reserves stock and waits for physical travel")
	var reserved := 0
	for cargo in e.shipments:
		if cargo.good == "bamboo": reserved += int(cargo.quantity)
	_check(e._local("0","bamboo") + reserved == e._units(100),"route reservation conserves source inventory exactly")
	_check(e.set_route("0","1","bamboo",20,8,false) and e.routes.size() == 1,"updating route replaces entire rule without duplicate dispatchers")
	for record in records: record.road_links = {}
	records[2].connected = false
	e.sync_buildings(records)
	var remaining := float(e.shipments[0].remaining)
	e.advance(2)
	_check(e.shipments.size() == cargo_count and e.shipments[0].remaining == remaining,"disabled rule and broken road preserve existing cargo")
	var copy = Economy.new()
	_check(copy.restore(JSON.parse_string(JSON.stringify(e.serialize()))),"configured routes and blocked cargo survive save restore")
	_check(copy.routes.size() == 1 and not copy.routes[0].enabled and copy.routes[0].reserve == 20,"restored route retains whole rule settings")
	var bad: Dictionary = copy.serialize()
	bad.routes[0].batch = 17
	_check(not copy.restore(bad),"corrupt route batch rejected before live-state mutation")
	_check(e.remove_route("0","1","bamboo") and e.shipments.size() == cargo_count,"removing rule leaves already reserved cargo intact")
	records[2].connected = true
	for a in records:
		for b in records:
			if a.id != b.id: a.road_links[str(b.id)] = 20
	e.sync_buildings(records)
	e.advance(20)
	_check(e.shipments.is_empty() and e.snapshot().regions["1"].goods.bamboo > 0,"cargo completes after road restored even after route removed")
	_check(e._local("0","bamboo") + e._local("1","bamboo") == e._units(100),"completed manual transfer never creates or destroys goods")

func _test_migration_food_and_worker_assignment() -> void:
	var e = Economy.new()
	e.reset({"population":4,"food":0,"coins":100,"happiness":70})
	var far := _record(3,"warehouse",false)
	far.region = "1"
	e.sync_buildings([_record(1,"house"),_record(2,"house"),far])
	e._add("1","food",e._units(100))
	e.advance(30)
	_check(e.population == 4 and e.migration_clock == 30,"isolated food stocks cannot authorize new residents")
	e.apply_resources({"food":12})
	e.advance(0.25)
	_check(e.population == 6,"accessible food immediately enables the mature immigration timer")
	var staff = Economy.new()
	staff.reset({"population":16,"food":100,"coins":100})
	staff.immigration_enabled = false
	var records: Array = []
	for i in 4: records.append(_record(i+1,"house"))
	for kind in ["farm","lumber","warehouse","market","weaver"]: records.append(_record(records.size()+1,kind))
	staff.sync_buildings(records)
	staff.households["1"].tier = "artisan"
	staff.households["2"].tier = "artisan"
	staff._rebuild()
	_check(staff.snapshot().building_status["9"].workers == 2,"basic jobs use available farmers before reservable skilled workers regardless of household order")
	_check(staff.snapshot().households["1"].craft_workers == 0 and staff.snapshot().available_artisan == 6,"all artisan labor is external and no worker is implicitly reserved")

func _test_rates_exclude_transport() -> void:
	var e = Economy.new()
	e.reset({"population":4,"food":100,"coins":100,"bamboo":100})
	e.immigration_enabled = false
	var records: Array = [_record(1,"house"),_record(2,"warehouse"),_record(3,"warehouse")]
	records[2].region = "1"
	for a in records:
		a.road_links = {}
		for b in records:
			if a.id != b.id: a.road_links[str(b.id)] = 10
	e.sync_buildings(records)
	e.set_route("0","1","bamboo",10,4)
	for i in 40:
		e.advance(0.5)
		_check(absf(e.snapshot().rates.bamboo) < 0.000001,"internal dispatch and arrival never appear as production or consumption")
	var clone = Economy.new()
	_check(clone.restore(JSON.parse_string(JSON.stringify(e.serialize()))),"rolling-rate history survives save restore")
	_check(_same(e.snapshot().rates,clone.snapshot().rates),"restored rate panel preserves the rolling window")
	e.advance(5)
	clone.advance(5)
	_check(_same(e.snapshot().rates,clone.snapshot().rates),"rolling-rate continuation remains deterministic")
	var orchard = Economy.new()
	orchard.reset({"population":4,"food":100,"coins":100})
	orchard.immigration_enabled = false
	orchard.sync_buildings([_record(1,"house"),_record(2,"orchard")])
	orchard.advance(90)
	_check(absf(orchard.snapshot().rates.food) < 40,"batch harvest reports a whole-day rolling rate instead of annualizing one frame")

func _test_opening_transport_and_fairness() -> void:
	var opening = Economy.new()
	opening.reset({"population":12,"food":40,"wood":40,"coins":100})
	opening.immigration_enabled = false
	var records: Array = []
	for i in 3: records.append(_record(i+1,"house"))
	records.append(_record(4,"farm"))
	records.append(_record(5,"farm"))
	records.append(_record(6,"lumber"))
	opening.sync_buildings(records)
	opening.advance(60)
	var snapshot: Dictionary = opening.snapshot()
	_check(absf(snapshot.goods.food - 50) < 0.001 and absf(snapshot.goods.wood - 52) < 0.001,"12 residents, two farms and lumber operate at full output without warehouse")
	_check(not snapshot.regions["0"].has("transport_capacity"),"removed transport quota is not exposed in regional state")
	for id in ["4","5","6"]: _check(snapshot.building_status[id].reason == "正常","opening facility is not falsely marked transport deficient: " + id)
	var busy = Economy.new()
	busy.reset({"population":24,"food":40,"wood":40,"coins":100})
	busy.immigration_enabled = false
	var busy_records: Array = []
	for i in 6: busy_records.append(_record(i+1,"house"))
	for i in 4: busy_records.append(_record(i+7,"farm"))
	for i in 2: busy_records.append(_record(i+11,"lumber"))
	busy.sync_buildings(busy_records)
	busy.advance(60)
	var busy_snapshot: Dictionary = busy.snapshot()
	_check(busy_snapshot.goods.wood > 40 and busy_snapshot.goods.food > 40,"real overload fairly shares handling across both grain and lumber")
	_check(absf(busy_snapshot.goods.food - 60) < 0.001 and absf(busy_snapshot.goods.wood - 64) < 0.001,"four farms and two lumberyards produce full daily output without transport quotas")
	for id in ["7","8","9","10","11","12"]: _check(busy_snapshot.building_status[id].reason == "正常","busy producer has no transport bottleneck: " + id)

	var full = Economy.new()
	full.reset({"population":12,"food":200,"wood":200,"coins":100})
	full.immigration_enabled = false
	full.sync_buildings(records)
	full.advance(1)
	_check(full.snapshot().building_status["4"].reason == "仓储已满" and full.snapshot().building_status["6"].reason == "仓储已满","limited storage is never mislabeled transport shortage")
	var short_staff = Economy.new()
	short_staff.reset({"population":3,"food":40,"wood":40,"coins":100})
	short_staff.sync_buildings([_record(1,"house"),_record(2,"farm"),_record(3,"lumber")])
	short_staff.advance(1)
	_check(short_staff.snapshot().building_status["3"].reason == "普通劳力 1/2 · 减产","partial staffing keeps labor diagnosis over transport wording")
	_check(short_staff.snapshot().building_status["3"].producing, "partial staffing still allows production when storage has room")
	short_staff.apply_resources({"wood":100})
	short_staff.sync_buildings([_record(1,"house"),_record(2,"farm"),_record(3,"lumber")])
	_check(short_staff.snapshot().building_status["3"].reason == "仓储已满" and not short_staff.snapshot().building_status["3"].producing, "full storage stops even a partially staffed producer")

func _test_strict_worker_classes() -> void:
	var e = Economy.new()
	e.reset({"population":8,"food":100,"wood":100,"coins":100,"hemp":100})
	e.immigration_enabled = false
	var records: Array = [_record(1,"house"),_record(2,"house"),_record(3,"farm"),_record(4,"lumber"),_record(5,"weaver"),_record(6,"weaver")]
	e.sync_buildings(records)
	_check(e.snapshot().normal_workers == 8 and e.snapshot().artisan_workers == 0,"all eight ordinary residents count as eight normal workers")
	_check(e.snapshot().building_status["5"].workers == 0,"ordinary workers never fill artisan jobs")
	_check(e.promote_house("1") == "","one ordinary household can start artisan construction")
	e.advance(59.75)
	_check(e.snapshot().artisan_workers == 0 and e.snapshot().normal_workers == 8,"resident class and labor stay ordinary until construction ends")
	e.advance(0.25)
	var state: Dictionary = e.snapshot()
	_check(state.normal_workers == 4 and state.artisan_workers == 4 and state.workforce == 8,"exactly at60 seconds one upgraded four-person household supplies four artisans")
	_check(state.building_status["5"].workers == 2 and state.building_status["6"].workers == 2,"exactly at60 seconds the newly finished artisan household fully staffs both weaving workshops")
	_check(state.households["1"].assigned_workers == 4 and state.households["1"].craft_workers == 0,"all artisan residents are explicitly assigned outside their home")
	var previous: Dictionary = e.snapshot()
	e.advance(60)
	_check(absf(e.snapshot().goods.cloth - previous.goods.cloth - 6) < 0.001,"two weaving workshops produce8 clothes minus2 consumed by four artisan residents")
	var all_artisan = Economy.new()
	all_artisan.reset({"population":4,"food":100,"wood":100,"coins":100,"hemp":100})
	all_artisan.sync_buildings([_record(1,"house"),_record(2,"farm"),_record(3,"weaver")])
	all_artisan.households["1"].tier = "artisan"
	all_artisan._rebuild()
	_check(all_artisan.snapshot().building_status["2"].workers == 0 and all_artisan.snapshot().building_status["3"].workers == 2,"artisans never substitute for missing ordinary farmers")
	var independent = Economy.new()
	independent.reset({"population":4,"food":20,"coins":100})
	var farm := _record(2,"farm")
	farm.recipe = "hemp"
	farm.enabled = false
	farm.priority = 2
	independent.sync_buildings([_record(1,"house"),farm,_record(3,"hemp_farm")])
	independent.immigration_enabled = false
	independent.advance(60)
	_check(absf(independent.snapshot().goods.hemp - 8) < 0.001 and absf(independent.snapshot().goods.food - 26) < 0.001,"separate grain and hemp fields produce independently with fixed recipes")
	var legacy: Dictionary = independent.serialize()
	legacy.buildings[1].enabled = false
	legacy.buildings[1].priority = 2
	legacy.buildings[1].recipe = "hemp"
	legacy.households["1"].craft_workers = 2
	var restored = Economy.new()
	_check(restored.restore(legacy),"old control fields are accepted for normalization")
	var restored_building: Dictionary = restored._building("2")
	_check(restored_building.enabled and not restored_building.has("recipe") and not restored_building.has("priority") and restored.households["1"].craft_workers == 0,"restore strips obsolete operations and home reservation without applying them")
	_check(not restored.has_method("set_recipe") and not restored.has_method("set_enabled") and not restored.has_method("set_priority"),"obsolete building-operation APIs are removed")

func _test_construction_requires_connection() -> void:
	var e = Economy.new()
	e.reset({"population":4,"food":100,"wood":100,"coins":100})
	e.immigration_enabled = false
	var home := _record(1,"house")
	e.sync_buildings([home])
	_check(e.promote_house("1") == "","connected full residence starts construction")
	e.advance(30)
	home.connected = false
	e.sync_buildings([home])
	e.advance(30)
	_check(e.households["1"].upgrade_remaining == 30 and e.households["1"].tier == "farmer","disconnected construction timer does not advance")
	home.connected = true
	e.sync_buildings([home])
	e.advance(30)
	_check(e.households["1"].tier == "artisan" and e.snapshot().artisan_workers == 4 and e.snapshot().households["1"].artisan_workers == 4,"reconnected construction and labor update together on the exact finishing tick")

func _test_quantity_orders() -> void:
	var e = Economy.new()
	e.reset({"population":4,"food":100,"wood":70,"coins":100})
	e.immigration_enabled = false
	e.sync_buildings([_record(1,"house")])
	_check(e.place_trade_order("wood","sell",5) == "","player can directly sell specified quantity")
	e.advance(60)
	_check(absf(e.snapshot().goods.wood - 66) < 0.000001 and absf(e.snapshot().trade_orders["0"].wood.remaining - 1) < 0.000001,"quantity order obeys four-unit daily outpost quota")
	e.advance(60)
	_check(e.snapshot().goods.wood == 65 and e.snapshot().trade_orders["0"].wood.remaining == 0 and e.snapshot().trade_orders["0"].wood.status == "已完成","sell order stops exactly after five units")
	e.advance(60)
	_check(e.snapshot().goods.wood == 65,"completed sell order never repeats")
	_check(e.place_trade_order("wood","buy",3) == "","player can place fixed purchase")
	e.advance(60)
	_check(e.snapshot().goods.wood == 68 and e.snapshot().trade_orders["0"].wood.remaining == 0,"buy order delivers exactly three units then stops")
	_check(e.place_trade_order("bamboo","sell",4) == "","missing stock creates waiting order")
	e.advance(0.25)
	_check(e.snapshot().trade_orders["0"].bamboo.status.contains("库存不足") and e.snapshot().trade_orders["0"].bamboo.remaining == 4,"insufficient stock does not fabricate sales")
	e.apply_resources({"bamboo":4})
	e.advance(30)
	var halfway: Dictionary = e.snapshot()
	_check(halfway.trade_orders["0"].bamboo.remaining > 0 and halfway.trade_orders["0"].bamboo.remaining < 4,"order makes partial actual progress")
	var copy = Economy.new()
	_check(copy.restore(JSON.parse_string(JSON.stringify(e.serialize()))),"partially filled order survives save restore")
	e.advance(60)
	copy.advance(60)
	_check(_same(e.serialize(),copy.serialize()),"restored order fills the exact remaining quantity deterministically")
	_check(e.place_trade_order("wood","sell",10) == "","new order replaces completed record")
	e.advance(5)
	var before_cancel := float(e.snapshot().goods.wood)
	_check(e.cancel_trade_order("wood"),"cancel removes future unfilled quantity")
	e.advance(60)
	_check(e.snapshot().goods.wood == before_cancel and not e.snapshot().trade_orders.get("0",{}).has("wood"),"cancelling neither refunds executed trades nor keeps selling")
	e.set_trade_policy("wood","sell",0)
	e.place_trade_order("wood","buy",1)
	_check(e.policies.wood.mode == "off","new order disables hidden legacy policy for that commodity")
	e.set_trade_policy("wood","sell",0)
	e.cancel_trade_order("wood")
	_check(e.policies.wood.mode == "off","cancel also stops a legacy policy")
	var empty_purse = Economy.new()
	empty_purse.reset({"population":4,"food":100,"wood":20,"coins":1})
	empty_purse.immigration_enabled = false
	empty_purse.sync_buildings([_record(1,"house")])
	empty_purse.place_trade_order("wood","buy",5)
	empty_purse.advance(0.25)
	_check(empty_purse.snapshot().trade_orders["0"].wood.status.contains("铜钱不足") and empty_purse.snapshot().trade_orders["0"].wood.remaining == 5,"cash shortage waits explicitly without spending below one coin")
	var full = Economy.new()
	full.reset({"population":4,"food":100,"wood":200,"coins":100})
	full.sync_buildings([_record(1,"house")])
	full.place_trade_order("wood","buy",2)
	full.advance(0.25)
	_check(full.snapshot().trade_orders["0"].wood.status.contains("仓储已满") and full.snapshot().trade_orders["0"].wood.remaining == 2,"full warehouse waits without charging money")
	_check(full.place_trade_order("wood","buy",0) != "" and full.place_trade_order("missing","sell",2) != "","invalid order input is rejected")
	var offsite := _record(2,"warehouse",false)
	offsite.region = "1"
	full.sync_buildings([_record(1,"house"),offsite])
	full.place_trade_order("bamboo","buy",3,"1")
	full.advance(0.25)
	_check(full.snapshot().trade_orders["1"].bamboo.status == "地区道路未连通","remote disconnected orders wait without teleporting goods")
	offsite.connected = true
	full.sync_buildings([_record(1,"house"),offsite])
	full.advance(0.25)
	_check(full.snapshot().trade_orders["1"].bamboo.status.contains("集市"),"region without an operating merchant cannot execute orders")
	full.place_trade_order("wood","sell",7)
	full.place_trade_order("wood","buy",2)
	_check(full.snapshot().trade_orders["0"].wood.side == "buy" and full.snapshot().trade_orders["0"].wood.total == 2,"replacement order does not retain or duplicate old remaining quantity")
	var corrupt: Dictionary = full.serialize()
	corrupt.trade_orders["0:wood"].remaining = corrupt.trade_orders["0:wood"].total + 1
	_check(not full.restore(corrupt),"invalid remaining quantity is rejected atomically")

func _test_workshop_direct_income() -> void:
	var e = Economy.new()
	e.reset({"population":4,"food":100,"wood":100,"coins":100})
	e.immigration_enabled = false
	e.sync_buildings([_record(1,"house"),_record(2,"workshop")])
	e.advance(60)
	var state: Dictionary = e.snapshot()
	_check(absf(state.coins - 112) < 0.000001,"ordinary staffed workshop generates12 cash less2 upkeep plus2 resident income per day without selling")
	_check(absf(state.goods.wood - 96) < 0.000001 and state.goods.tools == 0,"direct cash workshop consumes4 wood and never duplicates wooden goods")
	_check(state.building_status["2"].worker_kind == "normal" and state.building_status["2"].workers == 2,"opening workshop requires only two ordinary workers")
	_check(not state.has("transport_capacity") and not state.regions["0"].has("transport_used"),"workshop and household consumption expose no removed handling quota")
	_check(absf(state.rates.coins - 12) < 0.000001,"net cash rate includes actual workshop production and upkeep")
	for situation in ["wood","road","labor"]:
		var blocked = Economy.new()
		blocked.reset({"population":4,"food":100,"cloth":0,"wood":0 if situation == "wood" else 100,"coins":100})
		blocked.immigration_enabled = false
		blocked.sync_buildings([_record(1,"house"),_record(2,"workshop",situation != "road")])
		if situation == "labor":
			blocked.households["1"].tier = "artisan"
			blocked._rebuild()
		blocked.advance(60)
		_check(absf(blocked.snapshot().coins - 100) < 0.000001,"workshop without required " + situation + " produces no money")
		_check(blocked.snapshot().goods.wood == (0 if situation == "wood" else 100),"blocked workshop does not consume wood: " + situation)
	var full = Economy.new()
	full.reset({"population":4,"food":200,"wood":200,"tools":200,"coins":1000})
	full.immigration_enabled = false
	full.sync_buildings([_record(1,"house"),_record(2,"workshop")])
	full.advance(60)
	_check(absf(full.snapshot().coins - 1012) < 0.000001,"full goods warehouses never cap workshop cash receipts")
	var copy = Economy.new()
	_check(copy.restore(JSON.parse_string(JSON.stringify(e.serialize()))),"direct cash production saves and restores")
	e.advance(11.25)
	copy.advance(11.25)
	_check(_same(e.serialize(),copy.serialize()),"direct cash production remains fixed-step deterministic after restore")
