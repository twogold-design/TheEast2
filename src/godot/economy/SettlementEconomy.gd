extends RefCounted
## Deterministic regional economy: local inventories, delayed road/water cargo,
## distinct ordinary/artisan jobs, services and complete household supply chains.
## Values are fixed-point; fractional transfer remainders and clocks are saved.

const SCALE := 240000
const STEP := 0.25
const INITIAL_WOOD := 100
const BASE_CAPACITIES := {"wood":100, "water":50, "food":100, "cloth":60}
const INITIAL_WATER := 40
const INITIAL_CLOTH := 12
const BASIC_DEPARTURE_SECONDS := 60.0
const CLOTHING_WARNING_SECONDS := 60.0
const CLOTHING_DEPARTURE_SECONDS := 120.0
const CLOTHING_DEPARTURE_INTERVAL := 120.0
const GOODS := ["water", "food", "wood", "hemp", "tools", "cloth", "tea", "clay", "pottery", "bamboo", "paper"]
const BUY := {"water":1, "food":2, "wood":2, "hemp":2, "tools":4, "cloth":4, "tea":4, "clay":2, "pottery":6, "bamboo":2, "paper":4}
const SELL := {"water":1, "food":1, "wood":1, "hemp":1, "tools":2, "cloth":2, "tea":2, "clay":1, "pottery":3, "bamboo":1, "paper":2}
const Balance = preload("res://godot/economy/BalanceV4.gd")
const SPECS = Balance.SPECS
const CATALOG = Balance.CATALOG
const PRIORITIES := ["well","farm","fishpond","lumber","hemp_farm","warehouse","market","granary","freight","dock","workshop","weaver","orchard","clinic","pavilion","garden","academy","theater","trading_post","tea_farm","teahouse","claypit","kiln","bamboo","papermill"]

var stock: Dictionary = {}
var cash: int = 0
var population: int = 4
var homeless_artisans: int = 0
var happiness: float = 60.0
var buildings: Array = []
var households: Dictionary = {}
var policies: Dictionary = {}
var trade_orders: Dictionary = {}
var remainders: Dictionary = {}
var building_status: Dictionary = {}
var rates: Dictionary = {}
var rate_samples: Array = []
var rate_totals: Dictionary = {}
var elapsed: float = 0.0
var accumulator: float = 0.0
var migration_clock: float = 0.0
var migration_food_balance: int = 0
var hunger_clock: float = 0.0
var thirst_clock: float = 0.0
var unlocked_level: int = 0
var unhappiness_clock: float = 0.0
var departure_clock: float = 0.0
var clothing_departure_clock: float = 0.0
var last_population_change_reason: String = ""
var population_events: Array[Dictionary] = []
var immigration_enabled: bool = true
var failed: bool = false
var failure_reason: String = ""
var capacity: int = 100
var housing_capacity: int = 0
var workforce: int = 0
var available_workers: int = 0
var artisan_workers: int = 0
var normal_workers: int = 0
var available_normal: int = 0
var available_artisan: int = 0
var trade_capacity: float = 4.0
var trade_status: String = "未设置贸易"
var _staff: Dictionary = {}
var _maintenance: float = 0.0
var regions: Dictionary = {}
var shipments: Array = []
var routes: Array = []
var regional_budgets: Dictionary = {}
var production_clocks: Dictionary = {}
var harvest_pending: Dictionary = {}
var dispatch_clock: float = 0.0
var immigration_status: String = "等待迁入"
var _route_cache: Dictionary = {}
var regional_policies: Dictionary = {}
var _service_factors: Dictionary = {}
var _food_sources: Dictionary = {}
var _consumed_sources: Dictionary = {}
var _source_clock: float = 0.0
var consumption_events: Array = []


func _init() -> void:
	reset()

func reset(initial: Dictionary = {}) -> void:
	regional_policies.clear()
	trade_orders.clear()
	regions.clear()
	shipments.clear()
	routes.clear()
	production_clocks.clear()
	harvest_pending.clear()
	dispatch_clock = 0.0
	_food_sources.clear()
	_consumed_sources.clear()
	consumption_events.clear()
	_source_clock = 0.0
	rate_samples.clear()
	rate_totals.clear()
	stock.clear()
	for good in GOODS:
		stock[good] = _units(float(initial.get(good, INITIAL_WOOD if good == "wood" else (INITIAL_WATER if good == "water" else (INITIAL_CLOTH if good == "cloth" else (40 if good == "food" else 0))))))
	cash = _units(float(initial.get("coins", 60)))
	population = maxi(0, int(initial.get("population", 4)))
	homeless_artisans = 0
	happiness = float(initial.get("happiness", 60))
	buildings.clear()
	households.clear()
	policies.clear()
	remainders.clear()
	for good in GOODS:
		policies[good] = {"mode": "off", "threshold": 30.0 if good == "wood" else 0.0}
	elapsed = 0.0
	accumulator = 0.0
	migration_clock = 0.0
	migration_food_balance = 0
	hunger_clock = 0.0
	thirst_clock = 0.0
	unlocked_level = 0
	unhappiness_clock = 0.0
	departure_clock = 0.0
	clothing_departure_clock = 0.0
	last_population_change_reason = ""
	population_events.clear()
	immigration_enabled = true
	failed = false
	failure_reason = ""
	rates = {"coins": 0.0}
	for good in GOODS:
		rates[good] = 0.0
	for good in GOODS + ["coins"]: rate_totals[good] = 0
	regions["0"] = stock.duplicate(true)
	_food_sources["0"] = {"import": int(stock.food)}
	regional_policies["0"] = policies
	_rebuild()

func sync_buildings(records: Array) -> void:
	var incoming: Array = []
	var ids: Dictionary = {}
	for record in records:
		if not record is Dictionary or not SPECS.has(str(record.get("type", ""))):
			continue
		var entry: Dictionary = record.duplicate(true)
		entry["id"] = str(entry.get("id", incoming.size() + 1))
		if ids.has(entry.id):
			continue
		ids[entry.id] = true
		entry["region"] = str(entry.get("region", "0"))
		_ensure_region(entry.region)
		entry["connected"] = bool(entry.get("connected", false))
		entry["enabled"] = true
		entry.erase("recipe")
		entry.erase("priority")
		incoming.append(entry)
		if entry.type == "house" and not households.has(entry.id):
			households[entry.id] = {"people": 0, "tier": "farmer", "upgrade_remaining": 0.0, "craft_workers": 0, "cloth_shortage_seconds": 0.0, "buffer": {"water": 0, "food": 0, "tools": 0, "cloth": 0, "pottery": 0}, "food_sources": {}, "supply": {}}
	for id in households.keys():
		if not ids.has(id):
			if households[id].tier == "artisan":
				homeless_artisans += int(households[id].people)
			# Return goods without generating a second consumption payment.
			for good in households[id].buffer:
				_add("0", good, int(households[id].buffer[good]))
			households.erase(id)
	buildings = incoming
	buildings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id).naturalnocasecmp_to(str(b.id)) < 0)
	_settle_housing()
	_rebuild()

func _settle_housing() -> void:
	var assigned := 0
	for id in households:
		assigned += int(households[id].people)
	var unhoused := maxi(0, population - assigned)
	var unhoused_farmers := maxi(0, unhoused - homeless_artisans)
	for b in buildings:
		if b.type == "house" and b.connected and b.enabled:
			var h: Dictionary = households[b.id]
			if int(h.people) == 0:
				h.tier = "artisan" if homeless_artisans > 0 else "farmer"
			var incoming := mini(4 - int(h.people), homeless_artisans if h.tier == "artisan" else unhoused_farmers)
			h.people += incoming
			if h.tier == "artisan":
				homeless_artisans -= incoming
			else:
				unhoused_farmers -= incoming

func _building(id: String) -> Dictionary:
	for b in buildings:
		if str(b.id) == id:
			return b
	return {}

func _spec(b: Dictionary) -> Dictionary:
	var spec: Dictionary = SPECS[b.type].duplicate()
	spec["worker_kind"] = str(spec.get("worker_kind","normal"))
	return spec

func _rebuild() -> void:
	_route_cache.clear()
	building_status.clear()
	_staff.clear()
	housing_capacity = 0
	_maintenance = 0.0
	workforce = 0
	normal_workers = 0
	artisan_workers = 0
	var housed := 0
	var labor_sources: Array = []
	for home in buildings:
		if home.type != "house": continue
		var h: Dictionary = households[home.id]
		housed += int(h.people)
		h.craft_workers = 0
		h["assigned_workers"] = 0
		h["normal_workers"] = int(h.people) if h.tier == "farmer" else 0
		h["artisan_workers"] = int(h.people) if h.tier == "artisan" else 0
		if not home.connected: continue
		housing_capacity += 4
		var count := int(h.people)
		var kind := "artisan" if h.tier == "artisan" else "normal"
		labor_sources.append({"id":home.id,"region":home.region,"kind":kind,"remaining":count})
		if kind == "artisan": artisan_workers += count
		else: normal_workers += count
	var camp_population := maxi(0,population - housed)
	var camp_artisans := mini(camp_population,homeless_artisans)
	if camp_population > camp_artisans:
		labor_sources.append({"id":"camp","region":"0","kind":"normal","remaining":camp_population - camp_artisans})
		normal_workers += camp_population - camp_artisans
	if camp_artisans > 0:
		labor_sources.append({"id":"camp","region":"0","kind":"artisan","remaining":camp_artisans})
		artisan_workers += camp_artisans
	workforce = normal_workers + artisan_workers
	available_normal = normal_workers
	available_artisan = artisan_workers
	for b in _ordered_workplaces():
		var spec := _spec(b)
		_maintenance += float(spec.maintenance)
		var count := 0
		if b.connected:
			for source in labor_sources:
				if source.kind != spec.worker_kind: continue
				var links: Dictionary = b.get("road_links",{})
				var reachable: bool = (source.id == "camp" and b.region == "0") or links.has(source.id) or (not b.has("road_links") and source.region == b.region)
				if not reachable: continue
				var assigned := mini(int(source.remaining),int(spec.workers) - count)
				source.remaining -= assigned
				if source.kind == "normal": available_normal -= assigned
				else: available_artisan -= assigned
				if households.has(source.id): households[source.id].assigned_workers += assigned
				count += assigned
				if count >= int(spec.workers): break
		_staff[b.id] = count
	available_workers = available_normal + available_artisan
	capacity = 0
	trade_capacity = 0.0
	regional_budgets.clear()
	for region in regions:
		var limits: Dictionary = {}
		for good in GOODS: limits[good] = int(BASE_CAPACITIES.get(good,200))
		regional_budgets[region] = {"capacity":limits.wood, "food_capacity":limits.food, "capacities":limits, "trade":4.0 if region == "0" else 0.0}
	for b in buildings:
		if not b.enabled or not b.connected or int(_staff.get(b.id, 0)) < int(SPECS[b.type].workers):
			continue
		var budget: Dictionary = regional_budgets[b.region]
		match b.type:
			"warehouse":
				# Each warehouse adds half the base limit, never half the expanded limit.
				for good in GOODS:
					budget.capacities[good] += int(BASE_CAPACITIES.get(good, 200) / 2)
				budget.capacity = budget.capacities.wood
				budget.food_capacity = budget.capacities.food
			"granary":
				budget.food_capacity += Balance.GRANARY_CAPACITY
				budget.capacities.food += Balance.GRANARY_CAPACITY
			"market": budget.trade = maxf(budget.trade, 12.0)
			"trading_post": budget.trade = maxf(budget.trade, 32.0)
	var accessible_regions := _accessible_regions()
	for region in regional_budgets:
		var budget: Dictionary = regional_budgets[region]
		if accessible_regions.has(region): capacity += int(budget.capacity)
		trade_capacity += float(budget.trade)

	for b in buildings:
		var spec := _spec(b)
		var assigned := int(_staff.get(b.id,0))
		var reason := "正常"
		if not b.connected: reason = "未连通主干路"
		elif int(spec.workers) > assigned: reason = _worker_reason(spec,assigned)
		building_status[b.id] = {"reason":reason,"ok":reason == "正常","workers":assigned,"required_workers":int(spec.workers),"worker_kind":spec.worker_kind,"maintenance":float(spec.maintenance),"ratio":float(assigned) / maxf(1,spec.workers)}
	_refresh_production_availability()

func _refresh_production_availability() -> void:
	# Read current stock, including after demolition/load while time is paused.
	# A periodic structural rebuild must not erase a missing-input warning.
	for b in buildings:
		var spec := _spec(b)
		if not spec.has("output"):
			continue
		var state: Dictionary = building_status.get(b.id, {})
		var assigned := int(_staff.get(b.id, 0))
		state["producing"] = false
		if not b.connected or assigned <= 0:
			continue
		var reason := ""
		if spec.has("input") and _local(b.region, spec.input) <= 0:
			reason = "缺少" + _good_name(spec.input)
		elif spec.has("fuel") and _local(b.region, spec.fuel) <= 0:
			reason = "缺少燃料" + _good_name(spec.fuel)
		elif spec.output != "coins" and _local(b.region, spec.output) >= _region_capacity(b.region, spec.output):
			reason = "仓储已满"
		if not reason.is_empty():
			state.reason = reason
			state.ok = false
		else:
			state.producing = true

func _worker_reason(spec: Dictionary, assigned: int) -> String:
	var label := "工匠" if spec.worker_kind == "artisan" else "普通劳力"
	return "%s %d/%d · %s" % [label,assigned,int(spec.workers),"停产" if assigned == 0 else "减产"]

func set_unlock_level(level: int) -> void:
	unlocked_level = maxi(unlocked_level, maxi(0, level))

func _household_needs(h: Dictionary) -> Dictionary:
	var people := int(h.people)
	var per_person: Dictionary = Balance.NEEDS[h.tier]
	return {"water": people * per_person.water, "food": people * per_person.food,
		"cloth": people * per_person.cloth if h.tier == "artisan" or unlocked_level >= 1 else 0.0,
		"pottery": people * per_person.pottery if unlocked_level >= Balance.POTTERY_UNLOCK else 0.0}

func advance(sim_seconds: float) -> int:
	if failed or sim_seconds <= 0.0:
		return 0
	if cash <= 0 or population <= 0:
		failed = true
		failure_reason = "铜钱耗尽" if cash <= 0 else "居民全部离开"
		return 0
	accumulator += sim_seconds
	var ticks := 0
	while accumulator + 0.0000001 >= STEP and not failed:
		accumulator = maxf(0.0, accumulator - STEP)
		_tick()
		ticks += 1
	return ticks

func _tick() -> void:
	# Complete construction before assigning this tick's jobs and household needs.
	for b in buildings:
		if b.type != "house": continue
		var h: Dictionary = households[b.id]
		if float(h.get("upgrade_remaining",0)) > 0 and b.connected and b.enabled:
			h.upgrade_remaining = maxf(0,float(h.upgrade_remaining) - STEP)
			if h.upgrade_remaining == 0: h.tier = "artisan"
	_rebuild()
	var previous := _physical_goods()
	var previous_cash := cash
	_service_factors.clear()
	for region in regional_budgets:
		var budget: Dictionary = regional_budgets[region]
		budget["trade_left"] = _quantity("trade:" + region, float(budget.trade) * STEP / 60.0)
	_advance_shipments()
	trade_status = "未设置贸易"
	_trade(true)
	var food_needed := 0
	var food_eaten := 0
	var water_needed := 0
	var water_drank := 0
	var cloth_needed := 0
	var cloth_worn := 0
	var comfort := 0.0
	var assigned_people := 0
	for b in buildings:
		if b.type != "house":
			continue
		var h: Dictionary = households[b.id]
		var people := int(h.people)
		assigned_people += people
		var supplied := {"water":0.0,"food":0.0,"cloth":0.0,"pottery":0.0}
		var needs := _household_needs(h)
		for good in needs:
			var demand_rate := float(needs[good])
			if demand_rate <= 0: continue
			var wanted := _quantity("consume:" + b.id + ":" + good, demand_rate * STEP / 60.0)
			if b.connected and b.enabled:
				var delivery := mini(wanted, _local(b.region,good))
				if good == "food":
					_consume_food_sources(b.region,delivery,b.id)
				_take(b.region, good, delivery)
				h.buffer[good] = int(h.buffer.get(good,0)) + delivery
			var consumed := mini(wanted, int(h.buffer.get(good,0)))
			h.buffer[good] = int(h.buffer.get(good,0)) - consumed
			supplied[good] = float(consumed) / maxi(1,wanted)
			if good == "water":
				water_needed += wanted
				water_drank += consumed
			elif good == "food":
				food_needed += wanted
				food_eaten += consumed
			elif good == "cloth":
				cloth_needed += wanted
				cloth_worn += consumed
				cash += _quantity("income:" + b.id + good, _value(consumed) * Balance.CLOTH_INCOME)
			elif good == "pottery":
				cash += _quantity("income:" + b.id + good, _value(consumed) * 3)
		h["supply"] = supplied
		var cloth_gap := 1.0 - float(supplied.cloth)
		h["cloth_shortage_seconds"] = float(h.get("cloth_shortage_seconds",0)) + STEP * cloth_gap if float(needs.cloth) > 0 and cloth_gap > 0.000001 else 0.0
		cash += _quantity("tax:" + b.id, people * (0.5 + (0.5 * supplied.cloth if h.tier == "artisan" else 0.0)) * STEP / 60.0)
		comfort += people * (40.0 * supplied.food + 20.0 * supplied.water + 8.0 * supplied.cloth + 4.0 * supplied.pottery)
		if b.connected and people > 0:
			var shortage: Array[String] = []
			for good in ["water", "food", "cloth"]:
				if float(needs[good]) > 0 and float(supplied[good]) < 0.999:
					shortage.append("缺少" + _good_name(good))
			if not shortage.is_empty():
				building_status[b.id].reason = "、".join(shortage)
				if float(h.cloth_shortage_seconds) >= CLOTHING_WARNING_SECONDS:
					building_status[b.id].reason += " · 居民不满"
				building_status[b.id].ok = false

		if float(h.get("upgrade_remaining",0)) > 0:
			building_status[b.id].reason = "匠户改建中" + (" · " + str(building_status[b.id].reason) if not building_status[b.id].ok else "")
	var homeless := maxi(0,population - assigned_people)
	if homeless > 0:
		var need := _quantity("homeless_food",homeless * 0.5 * STEP / 60.0)
		var eaten := mini(need,_local("0","food"))
		_take("0","food",eaten)
		_consume_food_sources("0",eaten,"camp")
		food_needed += need
		food_eaten += eaten
		var water_need := _quantity("homeless_water",homeless * 0.5 * STEP / 60.0)
		var drank := mini(water_need,_local("0","water"))
		_take("0","water",drank)
		water_needed += water_need
		water_drank += drank
		cash += _quantity("homeless_tax",homeless * 0.5 * STEP / 60.0)
		comfort += homeless * (30.0 * float(eaten) / maxi(1,need) + 15.0 * float(drank) / maxi(1,water_need))
	_advance_shipments(false)
	for b in _ordered_workplaces():
		_produce(b)
	_run_consuming_services()
	_trade(false)
	cash -= _quantity("maintenance",_maintenance * STEP / 60.0)
	var target := comfort / maxi(1,population) + _services() + _food_diversity()
	# Actual consumption, not warehouse stock: zero stock with sufficient
	# just-in-time deliveries is healthy. Optional pottery never caps happiness.
	var weakest_supply := 1.0
	for amounts in [[food_eaten, food_needed], [water_drank, water_needed], [cloth_worn, cloth_needed]]:
		if int(amounts[1]) > 0:
			weakest_supply = minf(weakest_supply, float(amounts[0]) / float(amounts[1]))
	var supply_cap := lerpf(float(Balance.EMPTY_NECESSITY_HAPPINESS_CAP), 100.0, weakest_supply)
	target = minf(target, supply_cap)
	var hungry := food_eaten < food_needed
	var thirsty := water_drank < water_needed
	happiness = move_toward(happiness,clampf(target,0,100),(16.0 if hungry or thirsty else 8.0) * STEP / 60.0)
	hunger_clock = hunger_clock + STEP if hungry else 0.0
	thirst_clock = thirst_clock + STEP if thirsty else 0.0
	unhappiness_clock = unhappiness_clock + STEP if happiness < 40 else 0.0
	var basic_departure_pressure := hunger_clock > 0 or thirst_clock > 0 or unhappiness_clock > 0
	if basic_departure_pressure:
		departure_clock += STEP
		if departure_clock >= BASIC_DEPARTURE_SECONDS:
			departure_clock -= BASIC_DEPARTURE_SECONDS
			var reasons: Array[String] = []
			if hungry: reasons.append("粮食不足")
			if thirsty: reasons.append("饮水不足")
			if happiness < 40: reasons.append("幸福度低于40")
			_depart(2 if hungry else 1, "、".join(reasons))
	else:
		departure_clock = 0
	_advance_clothing_departures(basic_departure_pressure)
	migration_clock = minf(30,migration_clock + STEP)
	immigration_status = _migration_block()
	# A final departure is terminal; do not refill an empty settlement in the
	# same tick after its last household's shortage counter has been cleared.
	if population > 0 and cash > 0 and migration_clock >= 30 and immigration_status == "可迁入":
		population += mini(2,housing_capacity - population)
		migration_clock = 0
		_settle_housing()
	dispatch_clock += STEP
	if dispatch_clock >= 2:
		dispatch_clock -= 2
		_dispatch_shipments()
	_refresh_production_availability()
	while not consumption_events.is_empty() and float(consumption_events[0].time) < elapsed - 60:
		var event: Dictionary = consumption_events.pop_front()
		_consumed_sources[event.home][event.source] = maxi(0,int(_consumed_sources[event.home].get(event.source,0)) - int(event.amount))
	elapsed += STEP
	_record_rates(previous,previous_cash)
	if cash <= 0 or population <= 0:
		failed = true
		failure_reason = "铜钱耗尽" if cash <= 0 else "居民全部离开"

func _produce(b: Dictionary) -> void:
	var spec := _spec(b)
	if not spec.has("output") or int(_staff.get(b.id,0)) == 0:
		return
	var ratio := float(_staff[b.id]) / maxf(1,spec.workers)
	var output := 0
	if spec.has("batch_seconds"):
		if int(harvest_pending.get(b.id,0)) == 0:
			production_clocks[b.id] = float(production_clocks.get(b.id,0)) + STEP * ratio
			if float(production_clocks[b.id]) < float(spec.batch_seconds):
				if int(_staff.get(b.id,0)) == int(spec.workers): building_status[b.id].reason = "果实生长中"
				return
			production_clocks[b.id] -= float(spec.batch_seconds)
			harvest_pending[b.id] = _units(float(spec.rate) * float(spec.batch_seconds) / 60)
		output = int(harvest_pending[b.id])
	else:
		output = _quantity("produce:" + b.id + str(spec.output),float(spec.rate) * ratio * STEP / 60.0)
	var input_ratio := float(spec.get("input_rate",0)) / float(spec.rate)
	var fuel_ratio := float(spec.get("fuel_rate",0)) / float(spec.rate)
	var space := output if spec.output == "coins" else maxi(0,_region_capacity(b.region,spec.output) - _local(b.region,spec.output))
	var possible := mini(output,space)
	if spec.has("input"):
		possible = mini(possible,floori(_local(b.region,spec.input) / input_ratio))
	if spec.has("fuel"):
		possible = mini(possible,floori(_local(b.region,spec.fuel) / fuel_ratio))
	if output - possible > 2:
		var reason := "仓储已满"
		if space + 2 < output: reason = "仓储已满"
		elif spec.has("input") and _local(b.region,spec.input) < ceili(output * input_ratio): reason = "缺少" + _good_name(spec.input)
		elif spec.has("fuel") and _local(b.region,spec.fuel) < ceili(output * fuel_ratio): reason = "缺少燃料木材"
		if int(_staff.get(b.id,0)) < int(spec.workers):
			reason = _worker_reason(spec,int(_staff.get(b.id,0)))
		building_status[b.id].reason = reason
		building_status[b.id].ok = false
	var used_input := ceili(possible * input_ratio)
	var used_fuel := ceili(possible * fuel_ratio)
	if spec.has("input"): _take(b.region,spec.input,used_input)
	if spec.has("fuel"): _take(b.region,spec.fuel,used_fuel)
	if spec.output == "coins": cash += possible
	else: _add(b.region,spec.output,possible)
	if spec.output == "food": _source_add(b.region,b.type,possible)
	if spec.has("batch_seconds"):
		harvest_pending[b.id] = maxi(0,int(harvest_pending[b.id]) - possible)
		if int(harvest_pending[b.id]) > 0 and int(_staff.get(b.id,0)) == int(spec.workers):
			building_status[b.id].reason = "果实待装运"
			building_status[b.id].ok = true

func _trade(importing: bool) -> void:
	_execute_trade_orders(importing)
	for region in regional_budgets:
		var budget: Dictionary = regional_budgets[region]
		for good in GOODS:
			var policy: Dictionary = regional_policies.get(region,policies)[good]
			if policy.mode != ("buy" if importing else "sell"): continue
			var reserve := maxf(float(policy.threshold), _region_people(region) + 2.0 if good == "food" else 0.0)
			var quantity := 0
			if importing:
				quantity = maxi(0,mini(_units(reserve) - _local(region,good),_region_capacity(region,good) - _local(region,good)))
				var purse := _units(maxf(10,_maintenance * 2))
				quantity = mini(quantity,floori(maxi(0,cash - purse) / float(BUY[good])))
				if cash <= purse: trade_status = "钱袋保护"
			else:
				quantity = mini(_local(region,good),maxi(0,_local(region,good) - _units(reserve)))
			quantity = mini(quantity,int(budget.trade_left))
			if quantity > 0:
				if importing:
					_add(region,good,quantity)
					cash -= _quantity("buy:" + good,_value(quantity) * float(BUY[good]))
					if good == "food": _source_add(region,"import",quantity)
				else:
					_take(region,good,quantity)
					if good == "food": _source_remove(region,quantity)
					cash += _quantity("sell:" + good,_value(quantity) * float(SELL[good]))
				budget.trade_left -= quantity
				trade_status = "自动贸易中"
			elif int(budget.trade_left) <= 0: trade_status = "外商限额"

func _migration_block() -> String:
	if not immigration_enabled: return "已暂停迁入"
	if housing_capacity <= population: return "需要接路的空床位"
	if thirst_clock >= 30: return "水供应不足"
	if _clothing_shortage_seconds() >= CLOTHING_WARNING_SECONDS: return "久缺衣物，居民不满"
	if happiness < 55: return "幸福度需55"
	var available_food := 0
	for region in _accessible_regions(): available_food += _local(region,"food")
	if available_food < _units(population + 2): return "粮食需" + str(population + 2)
	return "可迁入"

func _clothing_shortage_seconds() -> float:
	var longest := 0.0
	for h in households.values():
		if int(h.people) > 0:
			longest = maxf(longest,float(h.get("cloth_shortage_seconds",0)))
	return longest

func _clothing_shortage_status(h: Dictionary) -> String:
	var shortage := float(h.get("cloth_shortage_seconds",0))
	if int(h.people) <= 0 or shortage <= 0: return ""
	if shortage >= CLOTHING_DEPARTURE_SECONDS: return "久缺衣物，居民将离开"
	if shortage >= CLOTHING_WARNING_SECONDS: return "久缺衣物，居民不满"
	return "衣物不足"

func _advance_clothing_departures(basic_pressure: bool) -> void:
	# Clothes are a slower household-specific pressure, never an extra penalty
	# alongside hunger, thirst, or unhappiness departures.
	if basic_pressure or _clothing_shortage_seconds() <= 0:
		clothing_departure_clock = 0.0
		return
	clothing_departure_clock = minf(CLOTHING_DEPARTURE_INTERVAL,clothing_departure_clock + STEP)
	if clothing_departure_clock < CLOTHING_DEPARTURE_INTERVAL: return
	var selected := ""
	var longest := CLOTHING_DEPARTURE_SECONDS - 0.000001
	for id in _sorted_keys(households):
		var h: Dictionary = households[id]
		if int(h.people) <= 0: continue
		var shortage := float(h.get("cloth_shortage_seconds",0))
		if shortage > longest:
			longest = shortage
			selected = str(id)
	if selected.is_empty(): return
	var leaving_home: Dictionary = households[selected]
	leaving_home.people -= 1
	population -= 1
	last_population_change_reason = "衣物长期不足"
	population_events.append({"count": 1, "reason": last_population_change_reason})
	leaving_home.cloth_shortage_seconds = maxf(0,float(leaving_home.cloth_shortage_seconds) - CLOTHING_DEPARTURE_INTERVAL) if int(leaving_home.people) > 0 else 0.0
	clothing_departure_clock = 0.0

func _depart(count: int, reason := "生活物资不足") -> void:
	var previous_population := population
	var remaining := mini(count, population)
	var housed := 0
	for h in households.values():
		housed += int(h.people)
	var homeless_depart := mini(remaining, maxi(0, population - housed))
	var homeless_farmer_count := maxi(0, population - housed - homeless_artisans)
	homeless_artisans -= maxi(0, homeless_depart - homeless_farmer_count)
	population -= homeless_depart
	if homeless_depart > 0:
		last_population_change_reason = reason
	remaining -= homeless_depart
	for id in _sorted_keys(households):
		var amount := mini(remaining, int(households[id].people))
		households[id].people -= amount
		population -= amount
		if amount > 0:
			last_population_change_reason = reason
		remaining -= amount
		if remaining <= 0:
			break
	if population < previous_population:
		population_events.append({"count": previous_population - population, "reason": reason})

func take_population_events() -> Array[Dictionary]:
	# Session-only notifications: inspecting or serializing never consumes them,
	# and restore/reset cannot replay historical departures.
	var result: Array[Dictionary] = population_events.duplicate(true)
	population_events.clear()
	return result

func population_pressure_text() -> String:
	var shortages: Array[String] = []
	if hunger_clock >= 1.0: shortages.append("缺粮")
	if thirst_clock >= 1.0: shortages.append("缺水")
	if _clothing_shortage_seconds() >= 1.0: shortages.append("缺衣")
	if happiness < 40: shortages.append("幸福度低于40")
	if not shortages.is_empty():
		return "、".join(shortages) + " · 居民将逐步离开"
	return ""

func set_trade_policy(good: String, mode: String, threshold: float = 0.0, region: String = "0") -> bool:
	if not GOODS.has(good) or not ["off", "buy", "sell"].has(mode):
		return false
	_ensure_region(region)
	regional_policies[region][good] = {"mode":mode,"threshold":maxf(0,threshold)}
	if region == "0": policies = regional_policies[region]
	return true

func promote_house(id: String) -> String:
	var b := _building(id)
	if not households.has(id) or b.is_empty():
		return "未找到民居"
	var h: Dictionary = households[id]
	if h.tier == "artisan":
		return "已是匠户"
	if int(h.people) != 4:
		return "需要住满4人"
	if not b.connected or not b.enabled:
		return "需要连通主干路"
	if float(h.get("upgrade_remaining",0)) > 0:
		return "正在改建"
	if happiness < 55:
		return "幸福度需要55"
	if not apply_resources({"wood":-12,"coins":-8},false,str(b.region)):
		return "需木材12、铜钱8"
	h.upgrade_remaining = 60.0
	return ""

func apply_resources(delta: Dictionary, allow_zero_coins: bool = false, region: String = "") -> bool:
	var accessible := _accessible_regions()
	var payment_regions: Array = [region] if not region.is_empty() else accessible
	if not region.is_empty() and not accessible.has(region): return false
	for good in delta:
		if good != "coins" and not GOODS.has(good):
			return false
		var available := cash if good == "coins" else 0
		if good != "coins":
			for source in payment_regions: available += _local(source,good)
		var result := available + _units(float(delta[good]))
		if result < 0 or (good == "coins" and result == 0 and not allow_zero_coins):
			return false
	for good in delta:
		if good == "coins":
			cash += _units(float(delta[good]))
		else:
			var amount := _units(float(delta[good]))
			if amount >= 0:
				_add("0" if region.is_empty() else region,good,amount)
				if good == "food": _source_add("0" if region.is_empty() else region,"import",amount)
			else:
				var remaining := -amount
				for source in payment_regions:
					var taking := mini(remaining,_local(source,good))
					_take(source,good,taking)
					if good == "food": _source_remove(source,taking)
					remaining -= taking
	if cash <= 0:
		failed = true
		failure_reason = "铜钱耗尽"
	return true

func snapshot() -> Dictionary:
	var goods: Dictionary = {}
	for good in GOODS:
		var total := 0
		for region in _accessible_regions(): total += _local(region,good)
		goods[good] = _value(total)
	var homes: Dictionary = households.duplicate(true)
	for h in homes.values():
		h["needs"] = _household_needs(h)
		h["cloth_shortage_seconds"] = float(h.get("cloth_shortage_seconds",0))
		h["cloth_shortage_status"] = _clothing_shortage_status(h)
		h["supply"] = h.get("supply", {}).duplicate()
		for good in h.buffer:
			h.buffer[good] = _value(h.buffer[good])
	return {"goods": goods, "coins": _value(cash), "population": population, "happiness": happiness, "capacity": capacity, "capacities": _total_capacities(), "housing_capacity": housing_capacity, "workforce": workforce, "available_workers": available_workers, "artisan_workers": artisan_workers, "normal_workers":normal_workers, "available_normal":available_normal, "available_artisan":available_artisan, "building_status": building_status.duplicate(true), "households": homes, "rates": rates.duplicate(), "failed": failed, "failure_reason": failure_reason, "elapsed": elapsed, "policies": policies.duplicate(true), "trade_orders":_trade_orders_snapshot(), "trade_capacity": trade_capacity, "trade_status": trade_status, "maintenance": _maintenance, "immigration_enabled": immigration_enabled, "logistics_mode":"分区库存与道路／水路货运", "regions":_region_snapshot(), "shipments":_shipment_snapshot(), "routes":routes.duplicate(true), "immigration_status":immigration_status, "water_shortage_seconds":thirst_clock, "clothing_unlocked":unlocked_level >= 1, "clothing_shortage_seconds":_clothing_shortage_seconds(), "clothing_departure_remaining":maxf(0,CLOTHING_DEPARTURE_INTERVAL - clothing_departure_clock), "migration_remaining":maxf(0,30-migration_clock), "food_capacity":_total_food_capacity(), "population_change_reason":last_population_change_reason, "population_pressure":population_pressure_text()}

func serialize() -> Dictionary:
	return {"version": 2, "trade_orders":trade_orders.duplicate(true), "rate_samples":rate_samples.duplicate(true), "regions":regions.duplicate(true), "regional_policies":regional_policies.duplicate(true), "shipments":shipments.duplicate(true), "routes":routes.duplicate(true), "production_clocks":production_clocks.duplicate(), "harvest_pending":harvest_pending.duplicate(), "dispatch_clock":dispatch_clock, "food_sources":_food_sources.duplicate(true), "consumed_sources":_consumed_sources.duplicate(true), "source_clock":_source_clock, "consumption_events":consumption_events.duplicate(true), "stock": stock.duplicate(), "cash": cash, "population": population, "homeless_artisans": homeless_artisans, "happiness": happiness, "buildings": buildings.duplicate(true), "households": households.duplicate(true), "policies": policies.duplicate(true), "remainders": remainders.duplicate(), "elapsed": elapsed, "accumulator": accumulator, "migration_clock": migration_clock, "migration_food_balance": migration_food_balance, "hunger_clock": hunger_clock, "thirst_clock": thirst_clock, "unlocked_level": unlocked_level, "unhappiness_clock": unhappiness_clock, "departure_clock": departure_clock, "clothing_departure_clock": clothing_departure_clock, "immigration_enabled": immigration_enabled, "failed": failed, "failure_reason": failure_reason}

func normalize_state(data: Dictionary) -> Dictionary:
	# Only the complete pre-water schema is upgraded; partially damaged new saves
	# still fail validation. Never mutate the caller's dictionary or the save file.
	var result := data.duplicate(true)
	if not result.get("stock") is Dictionary or result.stock.has("water"): return result
	if not result.get("regions") is Dictionary or not result.regions.has("0") or not result.get("policies") is Dictionary or not result.get("regional_policies") is Dictionary or not result.get("households") is Dictionary or not result.get("rate_samples") is Array: return result
	if result.policies.has("water") or result.has("thirst_clock"): return result
	for region in result.regions:
		if not result.regions[region] is Dictionary or result.regions[region].has("water") or not result.regional_policies.get(region) is Dictionary or result.regional_policies[region].has("water"): return result
	for h in result.households.values():
		if not h is Dictionary or not h.get("buffer") is Dictionary or h.buffer.has("water"): return result
	for sample in result.rate_samples:
		if not sample is Dictionary or not sample.get("delta") is Dictionary or sample.delta.has("water"): return result
	result.stock.water = _units(INITIAL_WATER)
	result.policies.water = {"mode":"off","threshold":0.0}
	for region in result.regions:
		result.regions[region].water = _units(INITIAL_WATER) if region == "0" else 0
		result.regional_policies[region].water = {"mode":"off","threshold":0.0}
	for h in result.households.values(): h.buffer.water = 0
	for sample in result.rate_samples: sample.delta.water = 0
	result.thirst_clock = 0.0
	result.unlocked_level = 0
	return result

func restore(data: Dictionary) -> bool:
	# Validate the complete graph before mutating any live economic state.
	data = normalize_state(data)
	if not _valid_state(data):
		return false
	reset()
	for good in GOODS:
		stock[good] = int(data.stock[good])
	cash = int(data.get("cash", 0))
	population = maxi(0, int(data.get("population", 0)))
	homeless_artisans = int(data.get("homeless_artisans", 0))
	happiness = clampf(float(data.get("happiness", 60)), 0.0, 100.0)
	households = data.get("households", {}).duplicate(true)
	for h in households.values():
		h.people = int(h.people)
		h["cloth_shortage_seconds"] = float(h.get("cloth_shortage_seconds",0))
		for good in h.buffer:
			h.buffer[good] = int(h.buffer[good])
	policies = data.get("policies", policies).duplicate(true)
	trade_orders = data.get("trade_orders",{}).duplicate(true)
	for order in trade_orders.values():
		order.remaining = int(order.remaining)
		order.total = int(order.total)
	remainders = data.get("remainders", {}).duplicate()
	elapsed = float(data.get("elapsed", 0))
	rate_samples = data.get("rate_samples",[]).duplicate(true)
	for sample in rate_samples:
		for good in GOODS + ["coins"]:
			sample.delta[good] = int(sample.delta[good])
			rate_totals[good] = int(rate_totals.get(good,0)) + int(sample.delta[good])
	for good in GOODS + ["coins"]:
		rates[good] = _value(int(rate_totals.get(good,0))) * 60 / maxf(STEP,minf(60,elapsed))
	accumulator = float(data.get("accumulator", 0))
	migration_clock = float(data.get("migration_clock", 0))
	migration_food_balance = int(data.get("migration_food_balance", 0))
	hunger_clock = float(data.get("hunger_clock", 0))
	thirst_clock = float(data.get("thirst_clock", 0))
	unlocked_level = int(data.get("unlocked_level", 0))
	unhappiness_clock = float(data.get("unhappiness_clock", 0))
	departure_clock = float(data.get("departure_clock", 0))
	clothing_departure_clock = float(data.get("clothing_departure_clock", 0))
	immigration_enabled = bool(data.get("immigration_enabled", true))
	failed = bool(data.get("failed", false))
	failure_reason = str(data.get("failure_reason", ""))
	regions = data.get("regions",{}).duplicate(true)
	for region in regions:
		for good in GOODS: regions[region][good] = int(regions[region][good])
	regional_policies = data.get("regional_policies",{}).duplicate(true)
	policies = regional_policies.get("0",policies)
	shipments = data.get("shipments",[]).duplicate(true)
	routes = data.get("routes",[]).duplicate(true)
	for route in routes:
		route.reserve = int(route.reserve)
		route.batch = int(route.batch)
	production_clocks = data.get("production_clocks",{}).duplicate()
	harvest_pending = data.get("harvest_pending",{}).duplicate()
	for id in harvest_pending: harvest_pending[id] = int(harvest_pending[id])
	dispatch_clock = float(data.get("dispatch_clock",0))
	_food_sources = data.get("food_sources",{}).duplicate(true)
	_consumed_sources = data.get("consumed_sources",{}).duplicate()
	_source_clock = float(data.get("source_clock",0))
	consumption_events = data.get("consumption_events",[]).duplicate(true)
	for event in consumption_events: event.amount = int(event.amount)
	for cargo in shipments:
		cargo.quantity = int(cargo.quantity)
		for source in cargo.food_sources: cargo.food_sources[source] = int(cargo.food_sources[source])
	for region in _food_sources:
		for source in _food_sources[region]: _food_sources[region][source] = int(_food_sources[region][source])
	for home in _consumed_sources:
		for source in _consumed_sources[home]: _consumed_sources[home][source] = int(_consumed_sources[home][source])
	sync_buildings(data.get("buildings", []))
	return true

func _valid_state(data: Dictionary) -> bool:
	data = normalize_state(data)
	if not _integer(data.get("version")) or int(data.version) != 2:
		return false
	if not data.get("stock") is Dictionary or not data.get("buildings") is Array or not data.get("households") is Dictionary or not data.get("policies") is Dictionary or not data.get("remainders") is Dictionary:
		return false
	for good in GOODS:
		if not _integer(data.stock.get(good)) or float(data.stock[good]) < 0.0:
			return false
		var policy = data.policies.get(good)
		if not policy is Dictionary or not policy.get("mode") in ["off", "buy", "sell"] or not _number(policy.get("threshold")) or float(policy.threshold) < 0.0:
			return false
	if not _integer(data.get("cash")) or not _integer(data.get("population")) or float(data.population) < 0 or not _number(data.get("happiness")):
		return false
	if not data.get("failed") is bool or not data.get("immigration_enabled") is bool or not data.get("failure_reason") is String:
		return false
	if float(data.cash) < 0.0 and not data.failed:
		return false
	for timer in ["elapsed", "accumulator", "migration_clock", "hunger_clock", "thirst_clock", "unhappiness_clock", "departure_clock"]:
		if not _number(data.get(timer)) or float(data[timer]) < 0.0:
			return false
	if float(data.accumulator) >= STEP + 0.000001 and not data.failed:
		return false
	if not _integer(data.get("unlocked_level", 0)) or float(data.get("unlocked_level", 0)) < 0: return false
	if not _number(data.get("clothing_departure_clock",0)) or float(data.get("clothing_departure_clock",0)) < 0 or float(data.get("clothing_departure_clock",0)) > CLOTHING_DEPARTURE_INTERVAL: return false
	if not _integer(data.get("migration_food_balance", 0)):
		return false
	for remainder in data.remainders.values():
		if not _number(remainder) or float(remainder) < -0.000001 or float(remainder) >= 1.000001:
			return false
	if not data.get("regions") is Dictionary or not data.get("shipments") is Array or not data.get("regional_policies") is Dictionary:
		return false
	if not data.get("rate_samples") is Array or data.rate_samples.size() > 240: return false
	var previous_sample_time := -1.0
	for sample in data.rate_samples:
		if not sample is Dictionary or not _number(sample.get("time")) or not sample.get("delta") is Dictionary: return false
		if float(sample.time) <= previous_sample_time or float(sample.time) > float(data.elapsed): return false
		previous_sample_time = float(sample.time)
		for good in GOODS + ["coins"]:
			if not _integer(sample.delta.get(good)): return false
	if not data.get("trade_orders",{}) is Dictionary: return false
	for key in data.get("trade_orders",{}):
		var order: Variant = data.trade_orders[key]
		if not order is Dictionary or not GOODS.has(order.get("good")) or not data.regions.has(order.get("region")) or not order.get("side") in ["buy","sell"]: return false
		if key != str(order.region) + ":" + str(order.good) or not _integer(order.get("remaining")) or not _integer(order.get("total")) or float(order.remaining) < 0 or float(order.total) <= 0 or float(order.remaining) > float(order.total): return false
		if int(order.total) % SCALE != 0 or not order.get("status") is String: return false
	var regional_total: Dictionary = {}
	for good in GOODS: regional_total[good] = 0
	for region in data.regions:
		if not region is String or not data.regions[region] is Dictionary: return false
		for good in GOODS:
			var amount: Variant = data.regions[region].get(good)
			if not _integer(amount) or float(amount) < 0: return false
			regional_total[good] += int(amount)
		if not data.regional_policies.get(region) is Dictionary: return false
		for good in GOODS:
			var policy: Variant = data.regional_policies[region].get(good)
			if not policy is Dictionary or not policy.get("mode") in ["off","buy","sell"] or not _number(policy.get("threshold")) or float(policy.threshold) < 0: return false
	for good in GOODS:
		if int(data.stock[good]) != int(regional_total[good]): return false
	for cargo in data.shipments:
		if not cargo is Dictionary or not data.regions.has(cargo.get("source")) or not data.regions.has(cargo.get("destination")) or not GOODS.has(cargo.get("good")): return false
		if not _integer(cargo.get("quantity")) or float(cargo.quantity) <= 0 or not _number(cargo.get("remaining")) or float(cargo.remaining) < 0 or not cargo.get("mode") in ["road","water"]: return false
		if not cargo.get("food_sources") is Dictionary: return false
	if not data.get("routes") is Array: return false
	var route_ids: Dictionary = {}
	for route in data.routes:
		if not route is Dictionary or not data.regions.has(route.get("source")) or not data.regions.has(route.get("destination")) or route.source == route.destination or not GOODS.has(route.get("good")): return false
		if not _integer(route.get("reserve")) or float(route.reserve) < 0 or not _integer(route.get("batch")) or float(route.batch) < 1 or float(route.batch) > 16 or not route.get("enabled") is bool: return false
		var route_id := str(route.source) + ":" + str(route.destination) + ":" + str(route.good)
		if route_ids.has(route_id): return false
		route_ids[route_id] = true
	if not data.get("consumed_sources") is Dictionary or not data.get("consumption_events") is Array or not data.get("food_sources") is Dictionary: return false
	for sources in data.consumed_sources.values():
		if not sources is Dictionary: return false
		for amount in sources.values():
			if not _integer(amount) or float(amount) < 0: return false
	for event in data.consumption_events:
		if not event is Dictionary or not event.get("home") is String or not event.get("source") is String or not _integer(event.get("amount")) or float(event.amount) < 0 or not _number(event.get("time")): return false
	var ids: Dictionary = {}
	var house_ids: Dictionary = {}
	for b in data.buildings:
		if not b is Dictionary or not b.get("id") is String or str(b.id).is_empty() or ids.has(b.id) or not SPECS.has(str(b.get("type", ""))):
			return false
		if not b.get("enabled") is bool or not b.get("connected") is bool:
			return false

		ids[b.id] = true
		if b.type == "house":
			house_ids[b.id] = true
	var housed := 0
	if data.households.size() != house_ids.size():
		return false
	for id in data.households:
		var h = data.households[id]
		if not house_ids.has(id) or not h is Dictionary or not _integer(h.get("people")) or float(h.people) < 0 or float(h.people) > 4:
			return false
		if not _number(h.get("upgrade_remaining",0)) or float(h.get("upgrade_remaining",0)) < 0: return false
		if h.get("tier") not in ["farmer", "artisan"] or not h.get("buffer") is Dictionary:
			return false
		if not _number(h.get("cloth_shortage_seconds",0)) or float(h.get("cloth_shortage_seconds",0)) < 0: return false
		if not h.get("supply",{}) is Dictionary: return false
		for good in h.get("supply",{}):
			if good not in ["water","food","cloth","pottery"] or not _number(h.supply[good]) or float(h.supply[good]) < 0 or float(h.supply[good]) > 1: return false
		for good in ["water", "food", "tools", "cloth", "pottery"]:
			if not _integer(h.buffer.get(good)) or float(h.buffer[good]) < 0.0:
				return false
		housed += int(h.people)
	if not _integer(data.get("homeless_artisans", 0)) or int(data.get("homeless_artisans", 0)) < 0:
		return false
	return housed + int(data.get("homeless_artisans", 0)) <= int(data.population)

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) < 9000000000000000.0

func _integer(value: Variant) -> bool:
	return _number(value) and floorf(float(value)) == float(value)

func _units(value: float) -> int:
	return roundi(value * SCALE)

func _value(value: int) -> float:
	return float(value) / SCALE

func _quantity(key: String, value: float) -> int:
	var exact := value * SCALE + float(remainders.get(key, 0.0))
	var whole := floori(exact + 0.00000001)
	remainders[key] = exact - whole
	return whole

func _ensure_region(region: String) -> void:
	if not regions.has(region):
		regions[region] = {}
		for good in GOODS: regions[region][good] = 0
	if not regional_policies.has(region):
		regional_policies[region] = {}
		for good in GOODS: regional_policies[region][good] = {"mode":"off","threshold":0.0}
	if not _food_sources.has(region): _food_sources[region] = {}

func _local(region: String, good: String) -> int:
	return int(regions.get(region,{}).get(good,0))

func _add(region: String, good: String, amount: int) -> void:
	_ensure_region(region)
	regions[region][good] = _local(region,good) + amount
	stock[good] = int(stock.get(good,0)) + amount

func _take(region: String, good: String, amount: int) -> void:
	regions[region][good] = _local(region,good) - amount
	stock[good] = int(stock[good]) - amount

func _region_capacity(region: String, good: String) -> int:
	return int(regional_budgets.get(region,{}).get("capacities",{}).get(good,BASE_CAPACITIES.get(good,200))) * SCALE

func _total_capacities() -> Dictionary:
	var result: Dictionary = {}
	for good in GOODS:
		result[good] = 0
		for region in _accessible_regions():
			result[good] += int(_region_capacity(region,good) / SCALE)
	return result

func _region_people(region: String) -> int:
	var result := 0
	for b in buildings:
		if b.region == region and b.type == "house": result += int(households[b.id].people)
	return result

func _region_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for region in regions:
		var goods: Dictionary = {}
		for good in GOODS: goods[good] = _value(_local(region,good))
		var budget: Dictionary = regional_budgets.get(region,{})
		var limits: Dictionary = {}
		for good in GOODS: limits[good] = int(_region_capacity(region,good) / SCALE)
		result[region] = {"goods":goods,"capacity":limits.wood,"food_capacity":limits.food,"capacities":limits,"trade_capacity":float(budget.get("trade",0)),"policies":regional_policies[region].duplicate(true),"people":_region_people(region)}
	return result

func _shipment_snapshot() -> Array:
	var result: Array = []
	for shipment in shipments:
		var entry: Dictionary = shipment.duplicate()
		entry.quantity = _value(int(entry.quantity))
		result.append(entry)
	return result

func _total_food_capacity() -> int:
	var total := 0
	for region in _accessible_regions():
		total += int(_region_capacity(region,"food") / SCALE)
	return total

func _good_name(good: String) -> String:
	return {"water":"水","food":"粮食","wood":"木材","hemp":"麻料","tools":"木器","cloth":"衣物","tea":"茶叶","clay":"黏土","pottery":"陶器","bamboo":"竹材","paper":"纸张"}.get(good,good)

func _run_consuming_services() -> void:
	var visitors: Dictionary = {}
	for b in buildings:
		if not b.enabled or not b.connected or b.type not in ["teahouse","academy"]: continue
		var spec: Dictionary = SPECS[b.type]
		var staff_ratio := float(_staff.get(b.id,0)) / maxf(1,spec.workers)
		var category := str(spec.service)
		if not visitors.has(category): visitors[category] = {}
		var allocations: Dictionary = {}
		var available_seats := float(spec.service_capacity) * staff_ratio
		var links: Dictionary = b.get("service_targets",b.get("road_links",{}))
		for home in buildings:
			if home.type != "house" or not home.connected or not home.enabled: continue
			var distance := float(links.get(home.id,0 if not b.has("road_links") and not b.has("service_targets") and home.region == b.region else INF))
			if distance > float(spec.get("range",20)): continue
			var missing := maxi(0,int(households[home.id].people) - int(visitors[category].get(home.id,0)))
			var served := minf(missing,available_seats)
			allocations[home.id] = served
			available_seats -= served
			if available_seats <= 0: break
		var customers := float(spec.service_capacity) * staff_ratio - available_seats
		var good := "tea" if b.type == "teahouse" else "paper"
		var demand := _quantity(good + "_service:" + b.id,2 * customers / float(spec.service_capacity) * STEP / 60.0)
		var actual := mini(demand,_local(b.region,good))
		_take(b.region,good,actual)
		var factor := float(actual) / maxi(1,demand)
		_service_factors[b.id] = factor
		for home in allocations:
			visitors[category][home] = float(visitors[category].get(home,0)) + float(allocations[home]) * factor
		if b.type == "teahouse":
			cash += _quantity("tea_income:" + b.id,_value(actual) * 3)
			if customers == 0:
				building_status[b.id].reason = "暂无可服务居民"
			elif actual < demand:
				building_status[b.id].reason = "缺少茶叶"
				building_status[b.id].ok = false

func _services() -> float:
	var service_left: Dictionary = {}
	for b in buildings:
		var spec: Dictionary = SPECS[b.type]
		if not spec.has("service") or not b.connected or not b.enabled: continue
		var staff_ratio := 1.0 if int(spec.workers) == 0 else float(_staff.get(b.id,0)) / float(spec.workers)
		service_left[b.id] = float(spec.service_capacity) * staff_ratio
		if b.type == "academy": service_left[b.id] += 16 * float(_service_factors.get(b.id,0))
	var bonus := 0.0
	for home in buildings:
		if home.type != "house" or not home.connected or not home.enabled: continue
		var people := int(households[home.id].people)
		if people == 0: continue
		var categories: Dictionary = {}
		for b in buildings:
			if not service_left.has(b.id) or float(service_left[b.id]) <= 0: continue
			var spec: Dictionary = SPECS[b.type]
			var links: Dictionary = b.get("service_targets",b.get("road_links",{}))
			# Synthetic single-region unit fixtures omit geometry; real maps always provide links.
			var distance := float(links.get(home.id, 0 if not b.has("road_links") and not b.has("service_targets") and home.region == b.region else INF))
			if distance > float(spec.get("range",20)): continue
			var value := float(spec.service_bonus)
			if b.type == "pavilion": value *= clampf(float(b.get("scenery_score",0)) / 3.0,0,1)
			if b.type == "garden": value = minf(8,4 + float(b.get("scenery_score",0)) * 2)
			if b.type == "teahouse": value *= float(_service_factors.get(b.id,0))
			var served := minf(people,float(service_left[b.id]))
			var contribution := value * served / people
			var category: String = str(spec.service)
			if contribution > float(categories.get(category,0)):
				categories[category] = contribution
				service_left[b.id] -= served
		for value in categories.values(): bonus += people * float(value)
	return bonus / maxi(1,population)

func _source_add(region: String, source: String, amount: int) -> void:
	_ensure_region(region)
	_food_sources[region][source] = int(_food_sources[region].get(source,0)) + amount

func _source_remove(region: String, amount: int) -> Dictionary:
	var removed: Dictionary = {}
	var sources: Dictionary = _food_sources.get(region,{})
	var total := 0
	for value in sources.values(): total += int(value)
	var remaining := mini(amount,total)
	for source in _sorted_keys(sources):
		var taking := mini(int(sources[source]),floori(float(amount) * int(sources[source]) / maxi(1,total)))
		removed[source] = taking
		sources[source] -= taking
		remaining -= taking
	for source in _sorted_keys(sources):
		if remaining <= 0: break
		var taking := mini(remaining,int(sources[source]))
		sources[source] -= taking
		removed[source] = int(removed.get(source,0)) + taking
		remaining -= taking
	return removed

func _consume_food_sources(region: String, amount: int, home: String) -> void:
	var taken: Dictionary = {}
	var sources: Dictionary = _food_sources.get(region,{})
	var available: Array = []
	for source in _sorted_keys(sources):
		if int(sources[source]) > 0: available.append(source)
	var remaining := amount
	var share := floori(float(amount) / maxi(1,available.size()))
	for source in available:
		var taking := mini(share,int(sources[source]))
		sources[source] -= taking
		taken[source] = taking
		remaining -= taking
	for source in available:
		var taking := mini(remaining,int(sources[source]))
		sources[source] -= taking
		taken[source] = int(taken[source]) + taking
		remaining -= taking
	if not _consumed_sources.has(home): _consumed_sources[home] = {}
	for source in _sorted_keys(taken):
		_consumed_sources[home][source] = int(_consumed_sources[home].get(source,0)) + int(taken[source])
		if int(taken[source]) > 0: consumption_events.append({"time":elapsed,"home":home,"source":source,"amount":int(taken[source])})

func _food_diversity() -> float:
	var bonus := 0.0
	for home in households:
		var sources: Dictionary = _consumed_sources.get(home,{})
		var total := 0
		for amount in sources.values(): total += int(amount)
		if total <= 0: continue
		var diverse := 0
		for amount in sources.values():
			if float(amount) / total >= 0.25: diverse += 1
		if diverse >= 2: bonus += 4 * int(households[home].people)
	return bonus / maxi(1,population)

func _regional_needs(region: String) -> Dictionary:
	var needs: Dictionary = {}
	for good in GOODS: needs[good] = 0.0
	for b in buildings:
		if b.region != region or not b.connected or not b.enabled: continue
		if b.type == "house":
			var h: Dictionary = households[b.id]
			var home_needs := _household_needs(h)
			for good in home_needs: needs[good] += float(home_needs[good])
			if h.tier == "farmer" and int(h.people) == 4:
				needs.wood = maxf(float(needs.wood),6) # Reserve one renovation shipment locally.
		else:
			var spec := _spec(b)
			var ratio := float(_staff.get(b.id,0)) / maxf(1,spec.workers)
			if spec.has("input"): needs[spec.input] += float(spec.input_rate) * ratio
			if spec.has("fuel"): needs[spec.fuel] += float(spec.fuel_rate) * ratio
			if b.type == "teahouse": needs.tea += 2 * ratio
			if b.type == "academy": needs.paper += 2 * ratio
	# Explicit local export orders can pull surplus from other regions too.
	for good in GOODS:
		if regional_policies[region][good].mode == "sell": needs[good] = maxf(needs[good],float(regional_budgets[region].trade))
	return needs

func _freight_speed(region: String) -> float:
	for b in buildings:
		if b.region == region and b.type == "freight" and b.connected and b.enabled and int(_staff.get(b.id,0)) >= int(SPECS.freight.workers):
			return 2.0
	return 1.0

func _route(source: String, destination: String) -> Dictionary:
	var route_key := source + ":" + destination
	if _route_cache.has(route_key): return _route_cache[route_key]
	var best: Dictionary = {}
	var best_time := INF
	for a in buildings:
		if a.region != source or not a.connected or not a.enabled: continue
		for b in buildings:
			if b.region != destination or not b.connected or not b.enabled: continue
			var links: Dictionary = a.get("road_links",{})
			if links.has(b.id):
				var duration := maxf(2,float(links[b.id]) * 0.6 / _freight_speed(source))
				if duration < best_time:
					best_time = duration
					best = {"from_id":a.id,"to_id":b.id,"mode":"road","distance":float(links[b.id]),"duration":duration,"batch":4}
			if a.type == "dock" and b.type == "dock" and int(_staff.get(a.id,0)) >= 2 and int(_staff.get(b.id,0)) >= 2:
				var water: Dictionary = a.get("water_links",{})
				if water.has(b.id):
					var duration := maxf(2,float(water[b.id]) * 0.3)
					if duration < best_time:
						best_time = duration
						best = {"from_id":a.id,"to_id":b.id,"mode":"water","distance":float(water[b.id]),"duration":duration,"batch":16}
	_route_cache[route_key] = best
	return best

func _dispatch_shipments() -> void:
	var needs: Dictionary = {}
	for region in regions: needs[region] = _regional_needs(region)
	for destination in regions:
		for good in GOODS:
			var wanted := _units(float(needs[destination][good]) * 2)
			if wanted <= 0: continue
			var reachable_incoming := 0
			var reserved_incoming := 0
			for cargo in shipments:
				if cargo.destination != destination or cargo.good != good: continue
				reserved_incoming += int(cargo.quantity)
				# Stranded cargo still owns its unloading space, but cannot feed
				# residents until a real route exists again. Other suppliers may help.
				if not _route(str(cargo.source),destination).is_empty():
					reachable_incoming += int(cargo.quantity)
			var missing := mini(wanted - _local(destination,good) - reachable_incoming,_region_capacity(destination,good) - _local(destination,good) - reserved_incoming)
			if missing <= 0: continue
			var sources: Array = regions.keys()
			sources.sort_custom(func(a: String,b: String) -> bool: return float(_route(a,destination).get("duration",INF)) < float(_route(b,destination).get("duration",INF)))
			for source in sources:
				if source == destination: continue
				var reserve := _units(float(needs[source][good]))
				if good == "food": reserve = maxi(reserve,_units(_region_people(source)))
				var available := maxi(0,_local(source,good) - reserve)
				if available <= 0: continue
				var route := _route(source,destination)
				if route.is_empty(): continue
				var quantity := mini(missing,available)
				if quantity <= 0: continue
				_take(source,good,quantity)
				var cargo := {"source":source,"destination":destination,"good":good,"quantity":quantity,"remaining":route.duration,"total_time":route.duration,"mode":route.mode,"from_id":route.from_id,"to_id":route.to_id,"distance":route.distance,"status":"运输中","food_sources":{}}
				if good == "food": cargo.food_sources = _source_remove(source,quantity)
				shipments.append(cargo)
				missing -= quantity
				if missing <= 0: break

	_dispatch_player_routes(needs)

func _advance_shipments(advance_time: bool = true) -> void:
	for index in range(shipments.size()-1,-1,-1):
		var cargo: Dictionary = shipments[index]
		var route := _route(cargo.source,cargo.destination)
		if route.is_empty():
			cargo.status = "道路中断，货物保留"
			continue
		cargo.status = "运输中"
		if cargo.mode != route.mode or absf(float(cargo.total_time) - float(route.duration)) > 0.001:
			var fraction := float(cargo.remaining) / maxf(0.001,float(cargo.total_time))
			cargo.remaining = float(route.duration) * fraction
			cargo.total_time = route.duration
			cargo.mode = route.mode
			cargo.distance = route.distance
			cargo.from_id = route.from_id
			cargo.to_id = route.to_id
		cargo.remaining = maxf(0,float(cargo.remaining) - (STEP if advance_time else 0.0))
		if float(cargo.remaining) > 0: continue
		var space := maxi(0,_region_capacity(cargo.destination,cargo.good) - _local(cargo.destination,cargo.good))
		if space <= 0:
			cargo.status = "等待卸货库位"
			continue
		var delivered := mini(space,int(cargo.quantity))
		_add(cargo.destination,cargo.good,delivered)
		if cargo.good == "food":
			var remaining := delivered
			for source in _sorted_keys(cargo.food_sources):
				var amount := mini(remaining,int(cargo.food_sources[source]))
				_source_add(cargo.destination,source,amount)
				cargo.food_sources[source] -= amount
				remaining -= amount
		cargo.quantity -= delivered
		if int(cargo.quantity) == 0: shipments.remove_at(index)
		else: cargo.status = "等待卸货库位"

func _sorted_keys(dictionary: Dictionary) -> Array:
	var keys: Array = dictionary.keys()
	keys.sort()
	return keys

func _ordered_workplaces() -> Array:
	var ordered: Array = []
	for b in buildings:
		if b.type != "house": ordered.append(b)
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:

		var ra := PRIORITIES.find(str(a.type))
		var rb := PRIORITIES.find(str(b.type))
		if ra != rb: return ra < rb
		return str(a.id).naturalnocasecmp_to(str(b.id)) < 0)
	return ordered

func _accessible_regions() -> Array:
	var result: Array = ["0"]
	for b in buildings:
		if b.connected and b.enabled and not result.has(str(b.region)): result.append(str(b.region))
	return result

func set_route(source: String, destination: String, good: String, reserve: float, batch: float, enabled: bool = true) -> bool:
	if source == destination or not regions.has(source) or not regions.has(destination) or not GOODS.has(good): return false
	if not is_finite(reserve) or not is_finite(batch) or reserve < 0 or floorf(reserve) != reserve or batch < 1 or batch > 16 or floorf(batch) != batch: return false
	var entry := {"source":source,"destination":destination,"good":good,"reserve":int(reserve),"batch":int(batch),"enabled":enabled,"status":"等待调拨" if enabled else "已停用"}
	for index in routes.size():
		var old: Dictionary = routes[index]
		if old.source == source and old.destination == destination and old.good == good:
			routes[index] = entry
			return true
	routes.append(entry)
	return true

func remove_route(source: String, destination: String, good: String) -> bool:
	for index in routes.size():
		var route: Dictionary = routes[index]
		if route.source == source and route.destination == destination and route.good == good:
			routes.remove_at(index)
			return true
	return false

func _dispatch_player_routes(needs: Dictionary) -> void:
	for order in routes:
		if not order.enabled:
			order.status = "已停用"
			continue
		var source: String = order.source
		var destination: String = order.destination
		var good: String = order.good
		var route := _route(source,destination)
		if route.is_empty():
			order.status = "道路不通"
			continue
		var reserve := maxi(_units(float(order.reserve)),_units(float(needs[source][good])))
		if good == "food": reserve = maxi(reserve,_units(_region_people(source)))
		var available := maxi(0,_local(source,good) - reserve)
		if available == 0:
			order.status = "源库保留"
			continue
		var incoming := 0
		for cargo in shipments:
			if cargo.destination == destination and cargo.good == good: incoming += int(cargo.quantity)
		var space := maxi(0,_region_capacity(destination,good) - _local(destination,good) - incoming)
		if space == 0:
			order.status = "目的仓满"
			continue
		var quantity := mini(available,space)
		if quantity <= 0:
			order.status = "等待库存"
			continue
		_take(source,good,quantity)
		var cargo := {"source":source,"destination":destination,"good":good,"quantity":quantity,"remaining":route.duration,"total_time":route.duration,"mode":route.mode,"from_id":route.from_id,"to_id":route.to_id,"distance":route.distance,"status":"运输中","food_sources":{},"player_route":true}
		if good == "food": cargo.food_sources = _source_remove(source,quantity)
		shipments.append(cargo)
		order.status = "运输中"

func _physical_goods() -> Dictionary:
	# A dispatched cargo still belongs to this town until actual consumption/sale.
	var total: Dictionary = stock.duplicate()
	for cargo in shipments:
		total[cargo.good] = int(total[cargo.good]) + int(cargo.quantity)
	return total

func _record_rates(previous: Dictionary, previous_cash: int) -> void:
	var physical := _physical_goods()
	var delta: Dictionary = {"coins":cash - previous_cash}
	for good in GOODS: delta[good] = int(physical[good]) - int(previous[good])
	rate_samples.append({"time":elapsed,"delta":delta})
	for good in GOODS + ["coins"]: rate_totals[good] = int(rate_totals.get(good,0)) + int(delta[good])
	while not rate_samples.is_empty() and float(rate_samples[0].time) <= elapsed - 60:
		var sample: Dictionary = rate_samples.pop_front()
		for good in GOODS + ["coins"]: rate_totals[good] -= int(sample.delta[good])
	var window := maxf(STEP,minf(60,elapsed))
	for good in GOODS + ["coins"]: rates[good] = _value(int(rate_totals[good])) * 60 / window

func place_trade_order(good: String, side: String, quantity: int, region: String = "0") -> String:
	if failed: return "经营已结束"
	if not GOODS.has(good) or side not in ["buy","sell"]: return "买卖类型无效"
	if not regions.has(region): return "地区尚未开放"
	if quantity < 1 or quantity > 1000000: return "数量需为1至1000000的整数"
	var key := region + ":" + good
	trade_orders[key] = {"region":region,"good":good,"side":side,"total":quantity * SCALE,"remaining":quantity * SCALE,"status":"等待成交"}
	regional_policies[region][good] = {"mode":"off","threshold":0.0}
	if region == "0": policies = regional_policies[region]
	return ""

func cancel_trade_order(good: String, region: String = "0") -> bool:
	if not GOODS.has(good) or not regions.has(region): return false
	var key := region + ":" + good
	var existed: bool = trade_orders.has(key) or regional_policies[region][good].mode != "off"
	trade_orders.erase(key)
	regional_policies[region][good] = {"mode":"off","threshold":0.0}
	if region == "0": policies = regional_policies[region]
	return existed

func _trade_orders_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for original in trade_orders.values():
		var order: Dictionary = original.duplicate()
		order.total = _value(int(order.total))
		order.remaining = _value(int(order.remaining))
		if not result.has(order.region): result[order.region] = {}
		result[order.region][order.good] = order
	return result

func _execute_trade_orders(importing: bool) -> void:
	for key in _sorted_keys(trade_orders):
		var order: Dictionary = trade_orders[key]
		if order.side != ("buy" if importing else "sell") or int(order.remaining) <= 0: continue
		var region: String = order.region
		var good: String = order.good
		var budget: Dictionary = regional_budgets[region]
		var reason := ""
		var quantity := int(order.remaining)
		if not _accessible_regions().has(region): reason = "地区道路未连通"
		elif float(budget.trade) <= 0: reason = "需要接路且有人手的集市或商栈"
		if reason.is_empty() and importing:
			var space := maxi(0,_region_capacity(region,good) - _local(region,good))
			var affordable := floori(maxi(0,cash - SCALE) / float(BUY[good]))
			if space <= 0: reason = "仓储已满，等待库位"
			elif affordable <= 0: reason = "铜钱不足（至少保留1铜钱）"
			quantity = mini(quantity,mini(space,affordable))
		elif reason.is_empty():
			quantity = mini(quantity,_local(region,good))
			if quantity <= 0: reason = "库存不足，等待补货"
		if reason.is_empty():
			if int(budget.trade_left) <= 0: reason = "商路额度已用完，等待成交"
		if not reason.is_empty():
			order.status = reason
			trade_status = reason
			continue
		quantity = mini(quantity,int(budget.trade_left))
		if importing:
			_add(region,good,quantity)
			cash -= quantity * int(BUY[good])
			if good == "food": _source_add(region,"import",quantity)
		else:
			_take(region,good,quantity)
			cash += quantity * int(SELL[good])
			if good == "food": _source_remove(region,quantity)
		budget.trade_left -= quantity
		order.remaining -= quantity
		order.status = "已完成" if int(order.remaining) == 0 else "分批成交中"
		trade_status = order.status
