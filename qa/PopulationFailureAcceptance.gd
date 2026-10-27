extends SceneTree
## Pure model fixtures plus an isolated real UI. Never reads/writes player saves.
const Economy = preload("res://godot/economy/SettlementEconomy.gd")
class Game extends "res://godot/Main.gd":
	func _ready() -> void: pass
	func save_game(_feedback := true) -> void: pass
	func load_game(_feedback := true) -> void: pass
	func create_background_music() -> void: pass
	func create_music_settings(_box: VBoxContainer) -> void: pass

var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func fixture(initial: Dictionary = {}):
	var e := Economy.new()
	var supplied := {"population":4,"food":1000,"water":1000,"cloth":100,"coins":100,"happiness":60}
	supplied.merge(initial,true)
	e.reset(supplied)
	e.immigration_enabled = false
	e.sync_buildings([{"id":"1","type":"house","region":"0","connected":true}])
	return e

func model_checks() -> void:
	for shortage in ["food","water","happiness"]:
		var e = fixture({shortage:0})
		e.advance(59.75)
		check(e.population == 4, "%s grants one day to recover" % shortage)
		e.advance(0.25)
		var lost := 2 if shortage == "food" else 1
		check(e.population == 4-lost, "%s reduces population after one day" % shortage)
		var events: Array = e.take_population_events()
		check(events.size() == 1 and events[0].count == lost, "%s reports actual departure count" % shortage)
		if shortage == "happiness":
			check(str(events[0].reason).contains("低于40"), "low happiness has an explicit reason")
		e.advance(240)
		check(e.population == 0 and e.failed, "%s can cause total population loss" % shortage)
		var stopped: float = e.elapsed
		e.advance(60)
		check(e.elapsed == stopped and e.population == 0, "failed economy no longer advances")
	var edge = fixture({"happiness":40})
	edge.advance(60)
	check(edge.population == 4 and edge.take_population_events().is_empty(), "happiness exactly forty does not cause departures")
	var brief = fixture({"water":0})
	brief.advance(30)
	brief.apply_resources({"water":100})
	brief.advance(60)
	check(brief.population == 4 and brief.departure_clock == 0, "recovery cancels the pending loss")
	var saved = fixture({"water":0})
	saved.advance(59.75)
	var clone := Economy.new()
	check(clone.restore(saved.serialize()), "pending departure restores")
	clone.advance(0.25)
	check(clone.population == 3, "restoring does not postpone departure")
	# Starting clothing stock is not a permanent last-worker safety net.
	for tier in ["farmer","artisan"]:
		var last = fixture({"population":1,"cloth":0})
		last.set_unlock_level(1)
		last.households["1"].tier = tier
		last.advance(119.75)
		check(last.population == 1 and not last.failed, "%s has the slower clothing deadline" % tier)
		last.immigration_enabled = true
		last.migration_clock = 30
		last.advance(0.25)
		check(last.population == 0 and last.failed, "%s final clothing departure causes defeat despite a mature migration timer" % tier)
		check(last.take_population_events().size() == 1, "final clothing departure is notified once")
	var empty = fixture({"coins":0})
	empty.advance(0.01)
	check(empty.failed and empty.elapsed == 0 and empty.snapshot().coins == 0, "zero coins fails before tax can refill them")
	var nobody = fixture({"population":0})
	nobody.immigration_enabled = true
	nobody.advance(0.01)
	check(nobody.failed and nobody.elapsed == 0, "empty settlement fails without migration revival")
	var fraction = fixture({"coins":0.5})
	fraction.advance(0.25)
	check(not fraction.failed, "positive fractional coins are not rounded into a false defeat")
	var material_only = fixture({"wood":0,"hemp":0,"bamboo":0,"paper":0,"clay":0,"pottery":0,"tea":0})
	material_only.set_unlock_level(1)
	material_only.advance(240)
	check(material_only.population == 4, "unused construction and production inputs are not resident necessities")

func reset_fixture(game: Node, people := 4) -> void:
	game.reset_game(false)
	game.economy.reset({"population":people,"food":100,"water":0,"cloth":12,"coins":100,"happiness":60})
	game.sync_economy_buildings()
	game.economy.immigration_enabled = false
	game.time_paused = false
	game.refresh_economy_snapshot()

func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://qa/population-failure")
	check(root.get_texture().get_image().save_png("res://qa/population-failure/" + label + ".png") == OK, "capture " + label)

func run() -> void:
	model_checks()
	root.size = Vector2i(1366,768)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.create_world()
	game.create_ui()
	await process_frame
	await process_frame
	for speed in [1.0,2.0,4.0]:
		reset_fixture(game)
		game.time_speed = speed
		game.update_auto_time(60.0/speed)
		check(game.population == 3 and game.ended == "", "%dx speed uses game-day departure timing" % int(speed))
		check(game.message_label.text.contains("人口 -1"), "actual UI reports loss")
	reset_fixture(game)
	game.time_paused = true
	game.update_auto_time(120)
	check(game.economy.population == 4 and game.economy.elapsed == 0, "pause stops departure clocks")
	reset_fixture(game,1)
	game.update_auto_time(60)
	check(game.population == 0 and game.ended == "lose" and game.time_paused, "last water-starved resident causes real defeat overlay and pause")
	check(game.end_layer.find_child("ResultTitle",true,false).text == "经营失败", "actual failure screen has correct title")
	check(game.message_label.text.contains("饮水不足"), "underlying departure reason stays visible")
	await capture("population-zero")
	var stopped: float = game.economy.elapsed
	game.update_auto_time(60)
	check(game.economy.elapsed == stopped, "defeat stops auto simulation")
	reset_fixture(game)
	check(game.ended == "" and not game.economy.failed, "new game clears terminal state")
	game.economy.apply_resources({"coins":-100},true)
	game.economy_refresh_elapsed = 0.0
	game.update_auto_time(0.01)
	check(game.ended == "lose" and game.time_paused and game.failure_reason.contains("铜钱"), "zero coins opens defeat without waiting for UI refresh throttle")
	await capture("coins-zero")
	check(game.end_layer.find_children("*","Button",true,false).size() == 1, "defeat offers restart, not continue")
	game.queue_free()
	await process_frame
	await process_frame
	print("POPULATION_FAILURE_OK" if failures.is_empty() else "POPULATION_FAILURE_FAILED")
	quit(0 if failures.is_empty() else 1)
