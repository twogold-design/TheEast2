extends SceneTree

const Economy = preload("res://godot/economy/SettlementEconomy.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var e := Economy.new()
	e.reset({"population": 4, "food": 0, "water": 0, "coins": 100, "happiness": 60})
	e.immigration_enabled = true
	e.sync_buildings([{"id":"1","type":"house","region":"0","connected":true,"enabled":true}])
	e.advance(59.75)
	check(e.snapshot().population == 4, "shortage warning period does not remove residents immediately")
	e.advance(0.25)
	var result: Dictionary = e.snapshot()
	check(int(result.population) < 4, "sustained food/water shortage reduces population")
	check(str(result.population_change_reason).contains("粮食不足"), "departure reason identifies mandatory food shortage")
	check(str(result.immigration_status) == "水供应不足", "migration status exposes water shortage")
	check(str(result.population_pressure).contains("缺粮") and str(result.population_pressure).contains("缺水"), "ongoing risk identifies both missing necessities")
	e.serialize()
	e.snapshot()
	var events := e.take_population_events()
	check(events.size() == 1 and int(events[0].count) == 2 and str(events[0].reason).contains("粮食不足"), "snapshot and serialization preserve the actual two-person departure notification")
	check(e.take_population_events().is_empty(), "a delivered departure is not repeated")
	if failures.is_empty():
		print("POPULATION_SHORTAGE_FEEDBACK_OK: delayed loss, reason and migration warning")
	else:
		for failure in failures: push_error(failure)
		print("POPULATION_SHORTAGE_FEEDBACK_FAILED")
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

