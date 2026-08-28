extends Node

signal bgm_changed

const MAX_LEVEL := 4

var bgm_level: int = MAX_LEVEL

func _ready():
	load_bgm_setting()
	_apply_bgm_level()

func _apply_bgm_level():
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, bgm_level <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(float(bgm_level) / float(MAX_LEVEL)))

func load_bgm_setting():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		if config.has_section_key("settings", "bgm_level"):
			bgm_level = clampi(config.get_value("settings", "bgm_level", MAX_LEVEL), 0, MAX_LEVEL)
		else:
			var legacy_enabled: bool = config.get_value("settings", "bgm_enabled", true)
			bgm_level = MAX_LEVEL if legacy_enabled else 0

func save_bgm_setting():
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("settings", "bgm_level", bgm_level)
	config.save("user://settings.cfg")

func set_bgm_level(level: int):
	level = clampi(level, 0, MAX_LEVEL)
	if bgm_level == level:
		return
	bgm_level = level
	_apply_bgm_level()
	save_bgm_setting()
	bgm_changed.emit()

func apply_to_player(player: AudioStreamPlayer):
	if not player:
		return
	player.bus = &"Music"
	if bgm_level > 0:
		if not player.playing:
			player.play()
	else:
		player.stop()
