extends SceneTree

const SAMPLE_FRAMES := 600

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := load("res://godot/Main.tscn") as PackedScene
	if scene == null:
		push_error("REALISTIC_PERFORMANCE_FAILED: 主场景无法加载")
		quit(1)
		return
	var game := scene.instantiate()
	root.add_child(game)
	for _frame in range(8):
		await process_frame
	var started_usec := Time.get_ticks_usec()
	for _frame in range(SAMPLE_FRAMES):
		await process_frame
	var elapsed_seconds := float(Time.get_ticks_usec() - started_usec) / 1000000.0
	var measured_fps := float(SAMPLE_FRAMES) / maxf(elapsed_seconds, 0.001)
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("REALISTIC_PERFORMANCE_OK: frames=%d seconds=%.3f fps=%.1f draw_calls=%d primitives=%d nodes=%d" % [SAMPLE_FRAMES, elapsed_seconds, measured_fps, draw_calls, primitives, nodes])
	game.queue_free()
	await process_frame
	quit(0)
