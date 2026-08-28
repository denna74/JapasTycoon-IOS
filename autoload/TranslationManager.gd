extends Node

const SETTINGS_FILE := "user://settings.cfg"

var current_language: String = "en"
var strings: Dictionary = {}

signal language_changed(lang: String)

func _ready():
	_load_language_setting()
	_load_strings()

func _load_language_setting():
	var config = ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		current_language = config.get_value("settings", "language", "en")

func _load_strings():
	var path = "res://resources/strings/strings_%s.json" % current_language
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary:
			strings = parsed

func set_language(lang: String):
	current_language = lang
	_load_strings()
	var config = ConfigFile.new()
	config.load(SETTINGS_FILE)
	config.set_value("settings", "language", current_language)
	config.save(SETTINGS_FILE)
	language_changed.emit(lang)

func t(key: String) -> String:
	return strings.get(key, key)

func tf(key: String, args: Array) -> String:
	var text = strings.get(key, key)
	return text % args

func get_language_flag() -> String:
	match current_language:
		"en":
			return "🇬🇧"
		"id":
			return "🇮🇩"
		_:
			return ""

func get_language_name() -> String:
	match current_language:
		"en":
			return "English"
		"id":
			return "Bahasa Indonesia"
		_:
			return current_language
