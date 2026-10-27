extends SceneTree
## In-memory fixtures only; no player save locations are accessed.
const Economy = preload("res://godot/economy/SettlementEconomy.gd")
var failures: Array[String] = []

func _initialize() -> void:
	initial_stock()
	shortage_lifecycle()
	weighted_shortage()
	targeted_departure()
	persistence_and_legacy()
	basic_shortages_do_not_stack()
	if failures.is_empty():
		print("PASS ClothingLifecycleAcceptance: initial clothes, weighted household shortages, slow departure, recovery, zero-population failure, persistence")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func near(value: float, expected: float, label: String) -> void:
	check(absf(value-expected) < 0.0001, "%s actual=%s expected=%s" % [label,value,expected])

func home(id := 1, region := "0") -> Dictionary:
	return {"id":str(id),"type":"house","connected":true,"region":region}

func fixture(level := 1):
	var e = Economy.new()
	e.reset({"population":4,"food":200,"water":200,"coins":100,"cloth":0,"happiness":60})
	e.immigration_enabled = false
	e.set_unlock_level(level)
	e.sync_buildings([home()])
	return e

func initial_stock() -> void:
	var e = Economy.new()
	near(e.snapshot().goods.cloth,12,"new model starts with twelve clothes")
	e.apply_resources({"cloth":-12})
	e.reset()
	near(e.snapshot().goods.cloth,12,"reset restores twelve starting clothes")
	e.reset({"cloth":0})
	near(e.snapshot().goods.cloth,0,"explicit empty cloth fixture is not replaced with default")
	var locked = fixture(0)
	locked.advance(600)
	check(locked.population == 4,"locked farmer clothing demand never triggers departure")
	near(locked.snapshot().clothing_shortage_seconds,0,"no shortage accumulates before farmer clothes unlock")
	var supplied = fixture()
	supplied.apply_resources({"cloth":12})
	supplied.advance(600)
	check(supplied.population == 4,"fully supplied residents do not leave")
	near(supplied.snapshot().clothing_shortage_seconds,0,"full supply keeps shortage timer zero")

func shortage_lifecycle() -> void:
	var e = fixture()
	e.advance(59.75)
	check(e.population == 4,"first day without clothing does not cause departure")
	e.advance(0.25)
	e.immigration_enabled = true
	e.sync_buildings([home(),home(2)])
	e.advance(0.25)
	check(e.snapshot().immigration_status.contains("衣"),"prolonged shortage explicitly blocks immigration")
	e.immigration_enabled = false
	e.advance(59.5)
	check(e.population == 4,"no clothes departure before two complete days")
	e.advance(0.25)
	check(e.population == 3,"first clothing departure at two equivalent shortage days")
	var events := e.take_population_events()
	check(events.size() == 1 and events[0].count == 1 and events[0].reason == "衣物长期不足", "clothing departure exposes the exact resident loss and reason to the UI")
	check(e.take_population_events().is_empty(), "clothing notification is delivered once")
	e.advance(119.75)
	check(e.population == 3,"clothes departures are at least two days apart")
	e.advance(0.25)
	check(e.population == 2,"continued shortage slowly loses a second resident")
	e.apply_resources({"cloth":12})
	e.immigration_enabled = true
	e.advance(0.25)
	near(e.snapshot().clothing_shortage_seconds,0,"renewed supply clears old clothing dissatisfaction")
	check(e.population > 2,"mature migration resumes when clothing recovers")
	var last_worker = fixture()
	last_worker.advance(1500)
	check(last_worker.population == 0 and last_worker.failed,"continued clothing shortage can lose the last ordinary resident and end the game")
	var last_artisan = fixture()
	last_artisan.households["1"].tier = "artisan"
	last_artisan.advance(1500)
	check(last_artisan.population == 0 and last_artisan.failed,"continued clothing shortage can lose the last artisan and end the game")

func weighted_shortage() -> void:
	var e = fixture()
	# Four farmers require1000 fixed-point cloth units per tick. Supply half.
	for tick in 480:
		e._add("0","cloth",500)
		e.advance(0.25)
	near(e.snapshot().households["1"].supply.cloth,0.5,"half delivery is recorded as half supply")
	near(e.snapshot().clothing_shortage_seconds,60,"half supply accumulates only half the shortage time")
	check(e.population == 4,"partial supply postpones departure instead of treating every tick as empty")
	for tick in 479:
		e._add("0","cloth",500)
		e.advance(0.25)
	check(e.population == 4,"half supply delays first departure until four actual days")
	e._add("0","cloth",500)
	e.advance(0.25)
	check(e.population == 3,"four days half supply equals two days complete shortage")

func targeted_departure() -> void:
	var e = fixture()
	e.reset({"population":8,"food":200,"water":200,"coins":100,"cloth":12,"happiness":60})
	e.immigration_enabled = false
	e.set_unlock_level(1)
	e.sync_buildings([home(1),home(2,"1")])
	e._add("1","food",e._units(200))
	e._add("1","water",e._units(200))
	e.advance(120)
	check(e.households["1"].people == 4 and e.households["2"].people == 3,"departure comes from the underserved home, not the first well-supplied home")
	check(e.population == 7,"one household clothing departure changes total population exactly once")

func persistence_and_legacy() -> void:
	var e = fixture()
	e.advance(90)
	var saved: Dictionary = e.serialize()
	var restored = Economy.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))),"clothing shortage saves and restores")
	near(restored.snapshot().clothing_shortage_seconds,90,"load does not reset household dissatisfaction")
	near(restored.clothing_departure_clock,e.clothing_departure_clock,"load preserves settlement departure cooldown")
	e.advance(30)
	restored.advance(30)
	check(e.population == 3 and restored.population == 3,"saving cannot postpone the pending clothing departure")
	near(e.snapshot().clothing_shortage_seconds,restored.snapshot().clothing_shortage_seconds,"restored shortage bookkeeping continues equally")
	var previous_water_schema: Dictionary = saved.duplicate(true)
	previous_water_schema.erase("clothing_departure_clock")
	for h in previous_water_schema.households.values(): h.erase("cloth_shortage_seconds")
	var old = Economy.new()
	check(old.restore(previous_water_schema),"previous water-era save accepts absent new shortage counters")
	near(old.snapshot().goods.cloth,0,"loading an existing water-era save grants no starting clothes")
	near(old.snapshot().clothing_shortage_seconds,0,"old schema initializes only missing shortage counters")
	var damaged: Dictionary = saved.duplicate(true)
	damaged.households["1"].cloth_shortage_seconds = -1
	check(not old.restore(damaged),"negative household shortage timer is rejected")

func basic_shortages_do_not_stack() -> void:
	var clothed = fixture()
	clothed.apply_resources({"water":-200,"cloth":12})
	var naked = fixture()
	naked.apply_resources({"water":-200})
	clothed.advance(120)
	naked.advance(120)
	check(naked.population == clothed.population and naked.population > 0,"simultaneous thirst and clothes shortage never double-count departures")
