extends SceneTree
## In-memory fixtures only; never touches a player's save.
const Economy = preload("res://godot/economy/SettlementEconomy.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var e = Economy.new()
	var expected := {"wood":100,"water":50,"food":100,"cloth":60}
	for good in expected:
		check(e.snapshot().capacities[good] == expected[good],"initial capacity: " + good)
		check(e.snapshot().goods[good] <= expected[good],"initial stock fits: " + good)
	check(e.snapshot().goods.wood == 100,"fresh stock starts with100 wood")
	e.immigration_enabled = false
	e.reset({"population":4,"water":10,"food":10,"coins":100})
	e.immigration_enabled = false
	e.sync_buildings([record(1,"house"),record(2,"well"),record(3,"farm")])
	e.advance(60)
	near(e.snapshot().goods.water,18,"water10 minus resident2 daily")
	near(e.snapshot().goods.food,16,"food8 minus resident2 daily")
	e.advance(1200)
	check(e.snapshot().goods.water <= 50 and e.snapshot().goods.food <= 100,"production obeys individual caps")
	var records := [record(1,"house"),record(2,"warehouse")]
	e.sync_buildings(records)
	for good in expected:
		check(e.snapshot().capacities[good] == expected[good] + int(expected[good] / 2),"warehouse expands each good: " + good)
	records.append(record(4,"warehouse"))
	e.sync_buildings(records)
	for good in Economy.GOODS:
		var base: int = int(Economy.BASE_CAPACITIES.get(good,200))
		check(e.snapshot().capacities[good] == base * 2,"two warehouses stack base halves, including intermediates: " + good)
	records.pop_back()
	e.sync_buildings(records)
	e.set_unlock_level(3)
	check(e.snapshot().capacities.wood == 150 and e.snapshot().capacities.water == 75,"unlock preserves existing capacity")
	e._add("0","wood",e._units(200))
	var before: float = e.snapshot().goods.wood
	records[1].connected = false
	e.sync_buildings(records)
	check(e.snapshot().capacities.wood == 100 and e.snapshot().goods.wood == before,"disconnection preserves owned overflow")
	var clone = Economy.new()
	check(clone.restore(JSON.parse_string(JSON.stringify(e.serialize()))),"overflow save loads")
	check(clone.snapshot().goods.wood == before and clone.snapshot().capacities.wood == 100,"loading never destroys owned stock")
	records.append(record(3,"house","1"))
	e.sync_buildings(records)
	for good in expected:
		check(e.snapshot().capacities[good] == expected[good] * 2,"accessible regional limits sum: " + good)
	records[2].connected = false
	e.sync_buildings(records)
	check(e.snapshot().capacities == clone.snapshot().capacities,"disconnected regional caps excluded")
	if failures.is_empty(): print("PASS InitialCapacityAcceptance: distinct caps, actual daily production, storage, expansion, safe saved overflow")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func record(id: int, kind: String, region := "0") -> Dictionary:
	return {"id":str(id),"type":kind,"region":region,"connected":true}

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func near(actual: float, expected: float, message: String) -> void:
	check(absf(actual-expected) < 0.0001,"%s: %s expected %s" % [message,actual,expected])
