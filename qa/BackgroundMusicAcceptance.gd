extends SceneTree

const MusicKit = preload("res://godot/BackgroundMusic.gd")
const QA_CONFIG := "res://.godot-user/qa/audio-acceptance.cfg"

class IsolatedGame extends "res://godot/Main.gd":
	func save_path() -> String:
		return "res://.godot-user/qa/audio-never-written.json"
	func save_game(_show_feedback := true) -> void:
		pass
	func load_game(_show_feedback := true) -> void:
		pass
	func audio_settings_path() -> String:
		return QA_CONFIG

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if FileAccess.file_exists(QA_CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_CONFIG))
	var game := IsolatedGame.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var music: Node = game.background_music
	var player: AudioStreamPlayer = music.player
	check(player.stream != null, "Music asset must load")
	if player.stream == null:
		game.queue_free()
		await process_frame
		finish()
		return
	check(player.playing, "Music starts automatically")
	check(player.stream is AudioStreamWAV, "PCM WAV is used")
	check(player.stream.get_length() > 90.0, "Track is longer than 90 seconds")
	check(player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Track loops in audio engine")
	check(player.stream.loop_begin == 0 and player.stream.loop_end > 0, "Loop covers full track")
	check(player.volume_db < -20.0, "Music starts with soft fade")
	music.started_at_usec -= 4000000
	music._process(0.0)
	check(is_equal_approx(db_to_linear(player.volume_db), 0.45), "Default volume is 45 percent")
	var original_id := player.get_instance_id()
	player.seek(12.0)
	await wait_wall_seconds(0.3)
	var before := player.get_playback_position()
	game.time_speed = 4.0
	game.time_paused = true
	Engine.time_scale = 4.0
	paused = true
	await wait_wall_seconds(0.5)
	var advanced := player.get_playback_position() - before
	print("Music real-time advance: ", advanced, " seconds; playback ", before, " -> ", player.get_playback_position())
	check(advanced > 0.1 and advanced < 0.9, "Music runs at real-time speed during pause and 4x speed")
	check(player.pitch_scale == 1.0 and not player.stream_paused, "Music is never pitch-shifted or paused by simulation")
	paused = false
	Engine.time_scale = 1.0
	game.create_background_music()
	game.next_day()
	game.reset_game(false)
	check(game.background_music.player.get_instance_id() == original_id, "New day and town reset reuse one music player")
	check(player.get_playback_position() >= 12.0, "Town reset does not rewind music")
	game.music_volume_slider.value = 31
	music._process(0.0)
	check(is_equal_approx(music.volume, 0.31) and game.music_volume_label.text == "31%", "Settings slider applies exact volume")
	game._on_music_mute_pressed()
	check(music.muted and player.volume_db <= -79.0 and player.playing, "Mute silences without stopping playback")
	music.save_preferences()
	var reloaded := MusicKit.new()
	reloaded.config_path = QA_CONFIG
	reloaded.load_preferences()
	check(is_equal_approx(reloaded.volume, 0.31) and reloaded.muted, "Audio preferences reload independently from town save")
	reloaded.free()
	game._on_music_mute_pressed()
	check(not music.muted and is_equal_approx(db_to_linear(player.volume_db), 0.31), "Unmute restores chosen volume")
	player.seek(player.stream.get_length() - 0.15)
	await wait_wall_seconds(0.55)
	check(player.playing and player.get_playback_position() < 1.5, "Actual playback crosses loop boundary without stopping")
	game.toggle_settings_menu()
	await process_frame
	check(game.settings_panel.get_rect().size.y < 440, "Music settings remain compact")
	check(game.music_mute_button.get_global_rect().end.x <= game.settings_panel.get_global_rect().end.x, "Music row fits settings width")
	game.queue_free()
	await process_frame
	await process_frame
	await wait_wall_seconds(0.18)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_CONFIG))
	finish()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func wait_wall_seconds(seconds: float) -> void:
	var until := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < until:
		await process_frame

func finish() -> void:
	if failures.is_empty():
		print("BACKGROUND_MUSIC_ACCEPTANCE: PASS — playback, loop, fade, pause/speed independence, settings, isolated persistence")
	else:
		print("BACKGROUND_MUSIC_ACCEPTANCE: FAIL — ", failures)
	quit(0 if failures.is_empty() else 1)
