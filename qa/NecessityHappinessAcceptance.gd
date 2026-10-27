extends SceneTree
## In-memory economies only. No player save access.
const Economy = preload("res://godot/economy/SettlementEconomy.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func fixture(missing := "", start := 60.0):
	var e := Economy.new()
	var resources := {"population":4,"food":1000,"water":1000,"cloth":100,"coins":1000,"happiness":start}
	if not missing.is_empty(): resources[missing] = 0
	e.reset(resources)
	e.set_unlock_level(1)
	e.immigration_enabled = false
	e.sync_buildings([{"id":"home","type":"house","region":"0","connected":true}])
	return e

func _initialize() -> void:
	for missing in ["food","water","cloth"]:
		var e = fixture(missing)
		e.advance(30)
		check(e.happiness < 59, missing + " shortage visibly lowers happiness before residents depart")
		check(e.population == 4, "early happiness feedback does not remove people immediately")
	var naked = fixture("cloth")
	naked.advance(60)
	check(is_equal_approx(naked.happiness,55.0), "one day without clothes lowers sixty happiness to fifty-five")
	naked.advance(120)
	check(is_equal_approx(naked.happiness,55.0), "persistent lack of clothes remains at the artisan recovery threshold")
	check(naked.population == 3, "clothing alone retains its slower population loss")
	naked.apply_resources({"cloth":20})
	naked.advance(60)
	check(is_equal_approx(naked.happiness,63.0), "restored supply recovers gradually rather than instantly")
	check(naked.snapshot().clothing_shortage_seconds == 0, "recovery clears clothing pressure")
	# Many services must not hide a fully missing necessity.
	var serviced = fixture("cloth",60)
	var buildings: Array = serviced.buildings.duplicate(true)
	for kind in ["market","clinic","garden","academy"]:
		buildings.append({"id":kind,"type":kind,"region":"0","connected":true,"scenery_score":3})
	serviced.sync_buildings(buildings)
	serviced.advance(60)
	check(is_equal_approx(serviced.happiness,55.0), "services cannot hide missing clothes or keep happiness at sixty")
	check(serviced.promote_house("home").is_empty(), "shortage still allows the first artisan home to restore the clothing chain")
	# Half supply is a smaller deficit; count actual consumption, not stock.
	var partial = fixture("cloth",68)
	var empty_but_supplied = fixture("cloth")
	for tick in 240:
		partial._add("0","cloth",500)
		empty_but_supplied._add("0","cloth",1000)
		partial.advance(0.25)
		empty_but_supplied.advance(0.25)
	check(is_equal_approx(partial.happiness,64.0), "half supply reduces comfort proportionally")
	check(empty_but_supplied.snapshot().goods.cloth == 0 and is_equal_approx(empty_but_supplied.happiness,68.0), "zero stored clothes with complete deliveries is not falsely penalized")
	var locked = fixture("cloth")
	locked.unlocked_level = 0
	locked.advance(60)
	check(is_equal_approx(locked.happiness,60.0), "farmer clothes not yet unlocked do not reduce happiness")
	var optional = fixture("pottery")
	optional.set_unlock_level(5)
	optional.households.home.tier = "artisan"
	optional.advance(60)
	check(is_equal_approx(optional.happiness,68.0), "optional pottery has no necessity cap")
	var saved = fixture("cloth")
	saved.advance(45)
	var restored := Economy.new()
	check(restored.restore(saved.serialize()), "mid-shortage state restores")
	saved.advance(30)
	restored.advance(30)
	check(is_equal_approx(restored.happiness,saved.happiness), "load does not reset happiness decline")
	print("NECESSITY_HAPPINESS_OK" if failures.is_empty() else "NECESSITY_HAPPINESS_FAILED")
	quit(0 if failures.is_empty() else 1)
