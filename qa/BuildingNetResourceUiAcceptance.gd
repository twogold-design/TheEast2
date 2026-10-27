extends SceneTree
## UI-only, in-memory fixtures: Main never enters the tree, so no player save is read or written.
const MainScript = preload("res://godot/Main.gd")
const Economy = preload("res://godot/economy/SettlementEconomy.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = MainScript.new()
	game.inspector_body = Label.new()
	var original_specs: Dictionary = Economy.SPECS.duplicate(true)
	check(not game.is_inside_tree(), "fixture cannot invoke Main ready or player save access")
	check(Economy.SPECS.size() == 26, "all 26 live building types are covered")
	for type in Economy.SPECS:
		var card: String = game.building_tooltip_text(type)
		var details: String = game.building_detail_text(type)
		for entry in [["card", card], ["details", details]]:
			var output := section(entry[1], "产出：")
			var cost := section(entry[1], "消耗：")
			for good in Economy.GOODS + ["coins"]:
				var label: String = game.resource_label(good)
				check(not (output.contains(label) and cost.contains(label)),
					"%s %s does not list %s as both output and consumption" % [type, entry[0], label])
		if type != "house":
			var parts: Dictionary = game.building_daily_resource_parts(type)
			for side in ["outputs", "costs"]:
				for part in parts[side]:
					check(card.contains(str(part)), "%s card includes shared %s: %s" % [type, side, part])
					check(details.contains(str(part)), "%s details includes shared %s: %s" % [type, side, part])

	var workshop: Dictionary = game.building_daily_resource_net("workshop")
	check(workshop == {"wood": -4, "coins": 10}, "workshop nets 12 revenue minus 2 upkeep while retaining wood input")
	for text in [game.building_tooltip_text("workshop"), game.building_detail_text("workshop")]:
		var compact := compact_text(text)
		check(compact.contains("铜钱10/日") and compact.contains("木材4/日"), "workshop says coins 10/day and wood 4/day")
		check(not compact.contains("铜钱12") and not section(text, "消耗：").contains("铜钱"), "workshop omits duplicate coin expense")

	var tea: Dictionary = game.building_daily_resource_net("teahouse")
	check(tea == {"tea": -2, "coins": 4}, "teahouse nets full-customer income and upkeep")
	for text in [game.building_tooltip_text("teahouse"), game.building_detail_text("teahouse")]:
		var compact := compact_text(text)
		check(compact.contains("铜钱4/日") and compact.contains("茶叶2/日"), "teahouse states net 4 and tea input 2")
		check(str(text).contains("满客"), "teahouse makes customer-dependent rate explicit")

	check(game.building_daily_resource_net("kiln") == {"clay": -6, "wood": -2, "coins": -3, "pottery": 6},
		"kiln preserves different input, fuel, maintenance and output resources")
	var synthetic := {"output": "wood", "rate": 12, "input": "wood", "input_rate": 4,
		"fuel": "wood", "fuel_rate": 3, "maintenance": 2}
	check(MainScript.net_daily_resources(synthetic) == {"wood": 5, "coins": -2},
		"same resource input and fuel both subtract from output")
	synthetic.rate = 7
	check(MainScript.net_daily_resources(synthetic) == {"coins": -2}, "net zero resource is omitted")
	synthetic.rate = 2
	check(MainScript.net_daily_resources(synthetic) == {"wood": -5, "coins": -2}, "net deficit has negative sign")
	check(MainScript.net_daily_resources({"maintenance": 2}, {"coins": 6}, {"tea": 2}) == {"coins": 4, "tea": -2},
		"special outputs and inputs participate in the same net calculation")

	var kiln_parts: Dictionary = game.building_daily_resource_parts("kiln")
	check(not " ".join(kiln_parts.outputs).contains("木材"), "negative wood is not presented as output")
	check(" ".join(kiln_parts.costs).contains("木材2/日"), "negative wood is presented as consumption")
	check(" ".join(game.building_daily_resource_parts("well").costs).is_empty(), "zero maintenance is omitted from costs")
	check(Economy.SPECS == original_specs, "live production and expense definitions remain unchanged")
	game.inspector_body.free()
	game.free()
	if failures.is_empty():
		print("PASS BuildingNetResourceUiAcceptance: 26 building cards/details, workshop, full-customer tea, multi-input nets, zero omission, negative costs; no player save access")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func section(text: String, prefix: String) -> String:
	for line in text.split("\n"):
		if line.begins_with(prefix):
			return line
	return ""

func compact_text(value: String) -> String:
	return value.replace(" ", "").replace("+", "").replace("−", "").replace("-", "")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
