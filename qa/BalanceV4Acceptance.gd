extends SceneTree
const Economy = preload("res://godot/economy/SettlementEconomy.gd")
const Main = preload("res://godot/Main.gd")
var errors: Array[String] = []
var reports: Array = []
const PLANS = [
	{"name":"8人起步","population":8,"artisans":0,"level":0,"counts":{"well":1,"farm":1,"lumber":1,"workshop":1,"warehouse":1}},
	{"name":"16人衣链","population":16,"artisans":4,"level":1,"counts":{"well":1,"farm":2,"lumber":1,"workshop":1,"hemp_farm":1,"weaver":2,"market":1,"warehouse":1}},
	{"name":"32人服务城镇","population":32,"artisans":8,"level":3,"counts":{"well":2,"farm":1,"fishpond":1,"lumber":2,"workshop":1,"hemp_farm":2,"weaver":3,"market":1,"clinic":1,"garden":1,"warehouse":1}},
	{"name":"48人陶纸链","population":48,"artisans":16,"level":5,"counts":{"well":4,"orchard":3,"lumber":2,"workshop":1,"hemp_farm":2,"weaver":4,"market":2,"clinic":1,"garden":1,"academy":1,"bamboo":1,"papermill":1,"claypit":1,"kiln":1,"warehouse":1}}
]
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message); push_error(message)
func _initialize() -> void: call_deferred("run")
func same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b))<0.000001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not same(a[i],b[i]): return false
		return true
	return a==b
func fixture(plan: Dictionary):
	var e := Economy.new()
	e.reset({"population":plan.population,"wood":80,"food":80,"water":50,"cloth":24,"hemp":16,"bamboo":12,"clay":12,"paper":4,"pottery":4,"coins":200,"happiness":60})
	e.immigration_enabled = false
	e.set_unlock_level(plan.level)
	var records: Array = []
	for i in int(plan.population)/4:
		records.append({"id":str(records.size()+1),"type":"house","connected":true,"region":"0"})
	for type in plan.counts:
		for i in int(plan.counts[type]):
			records.append({"id":str(records.size()+1),"type":type,"connected":true,"region":"0","scenery_score":2})
	e.sync_buildings(records)
	for i in int(plan.artisans)/4: e.households[str(i+1)].tier = "artisan"
	e.sync_buildings(records)
	return e

func theoretical(plan: Dictionary) -> Dictionary:
	var f := int(plan.population)-int(plan.artisans)
	var a := int(plan.artisans)
	var needs := {"water":f*.5+a,"food":f*.5+a,"cloth":f*.25+a*.5 if int(plan.level)>=1 else a*.5,"pottery":a*.125 if int(plan.level)>=5 else 0.0}
	var net: Dictionary = {}
	for good in Economy.GOODS: net[good] = -float(needs.get(good,0))
	var normal := 0
	var artisan := 0
	var maintenance := 0
	var cash := f*.5+a+float(needs.cloth)*Economy.Balance.CLOTH_INCOME+float(needs.pottery)*3
	for type in plan.counts:
		var count := int(plan.counts[type])
		var s: Dictionary = Economy.SPECS[type]
		if s.worker_kind == "artisan": artisan += count*int(s.workers)
		else: normal += count*int(s.workers)
		maintenance += count*int(s.maintenance)
		if s.has("output"):
			if s.output == "coins": cash += count*float(s.rate)
			else: net[s.output] += count*float(s.rate)
		if s.has("input"): net[s.input] -= count*float(s.input_rate)
		if s.has("fuel"): net[s.fuel] -= count*float(s.fuel_rate)
		if type == "academy": net.paper -= 2*count
	return {"needs":needs,"net_goods":net,"normal_jobs":normal,"normal_workers":f,"artisan_jobs":artisan,"artisan_workers":a,"net_cash":cash-maintenance,"maintenance":maintenance}

func run() -> void:
	var values: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/balance-v4-values.json"))
	check(same(Economy.SPECS,values.specs), "live recipes exactly match generated document values")
	check(same(Main.REGION_REQUIREMENTS,values.requirements), "live goals exactly match document values")
	check(same(Main.REGION_UNLOCK_COSTS,values.expansion_costs), "live expansion payment matches document values")
	check(same(Economy.Balance.NEEDS,values.needs), "live household consumption matches document values")
	for plan in PLANS:
		var account := theoretical(plan)
		check(account.normal_jobs<=account.normal_workers and account.artisan_jobs<=account.artisan_workers, plan.name+" has enough workers by class")
		for good in account.net_goods: check(float(account.net_goods[good])>=-0.0001, plan.name+" sustainable " +good)
		check(float(account.net_cash)>0,plan.name+" nominal net income is positive")
		var e = fixture(plan)
		var min_population := int(plan.population)
		var min_cash := float(e.snapshot().coins)
		var min_supply := 1.0
		for day in 30:
			e.advance(60)
			var snapshot: Dictionary = e.snapshot()
			min_population = mini(min_population,e.population)
			min_cash = minf(min_cash,float(snapshot.coins))
			for h in snapshot.households.values():
				for good in ["water","food","cloth"]:
					if float(h.needs[good])>0: min_supply = minf(min_supply,float(h.supply[good]))
		check(not e.failed and min_population==int(plan.population), plan.name+" survives thirty days without grants or immigration during simulation")
		check(min_supply>.999,plan.name+" supplies all active necessities")
		check(float(e.snapshot().coins)>200,plan.name+" earns actual income after upkeep")
		var sensitivity: Dictionary = {}
		for factor in [.9,1.1]:
			var deficits: Dictionary = {}
			for good in ["water","food","cloth"]:
				deficits[good] = float(account.net_goods[good])-(factor-1)*float(account.needs[good])
			sensitivity[str(factor)] = deficits
		reports.append({"plan":plan,"account":account,"days":30,"minimum_population":min_population,"minimum_cash":min_cash,"minimum_supply":min_supply,"final":e.snapshot(),"demand_sensitivity_net":sensitivity})
		print("V4_REFERENCE ",plan.name," population=",e.population," coins=",e.snapshot().coins," min_supply=",min_supply)
		await process_frame
	# With a full clothing chain, removing hemp supply must propagate to failure.
	var stress_plan: Dictionary = PLANS[1]
	var broken = fixture(stress_plan)
	var records: Array = broken.buildings.filter(func(b: Dictionary) -> bool: return b.type != "hemp_farm")
	broken.sync_buildings(records)
	var first_loss := -1
	for day in 60:
		broken.advance(60)
		if broken.population<int(stress_plan.population) and first_loss<0: first_loss=day+1
		if broken.failed: break
	check(first_loss>0, "removing hemp causes actual departures after stored hemp and clothes run out")
	var output := {"version":4,"references":reports,"stress":{"hemp_removed_first_loss_day":first_loss,"final_population":broken.population,"failed":broken.failed},"passed":errors.is_empty(),"errors":errors}
	DirAccess.make_dir_recursive_absolute("res://qa/economy-balance-v4")
	var file := FileAccess.open("res://qa/economy-balance-v4/engine-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t")); file.close()
	print("BALANCE_V4_OK" if errors.is_empty() else "BALANCE_V4_FAILED")
	quit(0 if errors.is_empty() else 1)
