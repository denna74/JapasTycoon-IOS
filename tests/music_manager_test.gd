extends Node

# Headless test runner for MusicManager BGM volume levels.
# Run: godot --headless res://tests/music_manager_test.tscn

var _failures: int = 0


func _ready() -> void:
	var original := _read_level()
	await _test_set_persists()
	await _test_clamps()
	await _test_legacy_migration()
	await _test_apply_to_player()
	await _test_apply_to_player_sets_bus()
	await _test_language_save_preserves_bgm()
	_set_level(original)
	MusicManager.set_bgm_level(original)
	print("TEST SUMMARY: failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		push_error("FAIL: " + name)


func _read_level() -> int:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		return config.get_value("settings", "bgm_level", 4)
	return 4


func _set_level(value: int) -> void:
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("settings", "bgm_level", value)
	config.save("user://settings.cfg")


func _write_legacy(value: bool) -> void:
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	if config.has_section_key("settings", "bgm_level"):
		config.erase_section_key("settings", "bgm_level")
	config.set_value("settings", "bgm_enabled", value)
	config.save("user://settings.cfg")


func _test_set_persists() -> void:
	MusicManager.set_bgm_level(2)
	_check(MusicManager.bgm_level == 2, "level set to 2")
	_check(_read_level() == 2, "level persists to settings.cfg")
	MusicManager.set_bgm_level(4)


func _test_clamps() -> void:
	MusicManager.set_bgm_level(1)
	MusicManager.set_bgm_level(9)
	_check(MusicManager.bgm_level == 4, "clamped to max")
	MusicManager.set_bgm_level(-3)
	_check(MusicManager.bgm_level == 0, "clamped to zero")
	MusicManager.set_bgm_level(4)


func _test_legacy_migration() -> void:
	_write_legacy(false)
	MusicManager.load_bgm_setting()
	_check(MusicManager.bgm_level == 0, "legacy bgm_enabled=false migrates to 0")
	_write_legacy(true)
	MusicManager.load_bgm_setting()
	_check(MusicManager.bgm_level == 4, "legacy bgm_enabled=true migrates to 4")


func _test_apply_to_player() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = preload("res://assets/audio/click_001.ogg")
	add_child(player)
	MusicManager.set_bgm_level(0)
	MusicManager.apply_to_player(player)
	_check(not player.playing, "player stopped at level 0")
	MusicManager.set_bgm_level(4)
	MusicManager.apply_to_player(player)
	_check(player.playing, "player plays above level 0")
	player.stop()
	player.queue_free()


func _test_apply_to_player_sets_bus() -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	MusicManager.apply_to_player(player)
	_check(player.bus == &"Music", "apply_to_player routes player to Music bus")
	player.queue_free()


func _test_language_save_preserves_bgm() -> void:
	var original_lang: String = TranslationManager.current_language
	MusicManager.set_bgm_level(2)
	TranslationManager.set_language("id")
	_check(_read_level() == 2, "set_language preserves bgm_level")
	MusicManager.set_bgm_level(4)
	TranslationManager.set_language(original_lang)
