extends Node

## Music owns its real-time clock and its preferences, independently of a town save.
const TRACK_PATH := "res://godot/assets/audio/country_meadow.ogg"
const DEFAULT_VOLUME := 0.45
const FADE_SECONDS := 2.8

var config_path := ""
var volume := DEFAULT_VOLUME
var muted := false
var player: AudioStreamPlayer
var started_at_usec := 0
var preference_save_at_usec := 0
var preferences_dirty := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if config_path.is_empty():
		config_path = ProjectSettings.globalize_path("res://saves/audio_settings.cfg") if OS.has_feature("editor") else "user://audio_settings.cfg"
	load_preferences()
	player = AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.volume_db = -80.0
	add_child(player)
	# Imported resources work in a PCK; direct WAV loading also works before the
	# editor's first import, including the one-click source-project launcher.
	var music: AudioStream
	if ResourceLoader.exists(TRACK_PATH):
		music = load(TRACK_PATH) as AudioStream
	if music == null and FileAccess.file_exists(TRACK_PATH):
		music = AudioStreamWAV.load_from_file(TRACK_PATH)
	if music == null:
		push_warning("背景音乐文件暂不可用：" + TRACK_PATH)
		return
	if music is AudioStreamWAV:
		music.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.loop_begin = 0
		music.loop_end = roundi(music.get_length() * music.mix_rate)
	if music is AudioStreamOggVorbis:
		music.loop = true
	player.stream = music
	started_at_usec = Time.get_ticks_usec()
	player.play()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if player and player.playing:
		var fade := clampf(float(now - started_at_usec) / (FADE_SECONDS * 1000000.0), 0.0, 1.0)
		var gain := 0.0 if muted else volume * fade
		player.volume_db = linear_to_db(gain) if gain > 0.0001 else -80.0
	if preferences_dirty and now >= preference_save_at_usec:
		save_preferences()

func set_music_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	queue_preferences_save()
	_process(0.0)

func set_muted(value: bool) -> void:
	muted = value
	queue_preferences_save()
	_process(0.0)

func queue_preferences_save() -> void:
	preferences_dirty = true
	preference_save_at_usec = Time.get_ticks_usec() + 350000

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return
	volume = clampf(float(config.get_value("music", "volume", DEFAULT_VOLUME)), 0.0, 1.0)
	muted = bool(config.get_value("music", "muted", false))

func save_preferences() -> void:
	if not preferences_dirty:
		return
	var config := ConfigFile.new()
	config.set_value("music", "volume", volume)
	config.set_value("music", "muted", muted)
	var directory := ProjectSettings.globalize_path(config_path).get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) == OK and config.save(config_path) == OK:
		preferences_dirty = false
	else:
		preference_save_at_usec = Time.get_ticks_usec() + 5000000
		push_warning("音乐设置未能保存：" + config_path)

func _exit_tree() -> void:
	if is_instance_valid(player):
		player.stop()
		player.stream = null
	if preferences_dirty:
		save_preferences()
