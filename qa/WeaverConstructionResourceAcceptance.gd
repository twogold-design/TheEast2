extends SceneTree
const Main = preload("res://godot/Main.gd")
const Economy = preload("res://godot/economy/SettlementEconomy.gd")
var failures: Array[String] = []
func _initialize() -> void:
	var main_fixture = Main.new()
	var def: Dictionary = main_fixture.BUILDINGS.weaver
	check(def.get("resource_costs", {}).get("hemp", 0) == 8, "weaver has an eight-hemp construction cost")
	main_fixture.free()
	var e := Economy.new()
	e.reset({"wood":100,"hemp":10,"coins":100,"population":4})
	var before: Dictionary = e.snapshot().goods.duplicate(true)
	check(e.apply_resources({"wood":-int(def.cost),"hemp":-8,"coins":-int(def.coin_cost)}), "weaver payment succeeds with hemp")
	check(e.snapshot().goods.wood == before.wood - int(def.cost) and e.snapshot().goods.hemp == before.hemp - 8, "weaver payment deducts wood and hemp atomically")
	var short := Economy.new()
	short.reset({"wood":100,"hemp":7,"coins":100,"population":4})
	var short_before: Dictionary = short.snapshot().goods.duplicate(true)
	check(not short.apply_resources({"wood":-int(def.cost),"hemp":-8,"coins":-int(def.coin_cost)}), "weaver payment fails when hemp is short")
	check(short.snapshot().goods.wood == short_before.wood and short.snapshot().goods.hemp == short_before.hemp, "failed weaver payment does not partially deduct")
	for failure in failures: push_error(failure)
	print("WEAVER_CONSTRUCTION_RESOURCE_OK" if failures.is_empty() else "WEAVER_CONSTRUCTION_RESOURCE_FAILED")
	quit(0 if failures.is_empty() else 1)
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

