extends Node

const MAX_LEVEL := 4
const PRESSED_MODULATE := Color(0.7, 0.7, 0.7, 1)

var sfx_level: int = MAX_LEVEL

var _player: AudioStreamPlayer
var _wired: Dictionary = {}
var _pressed_modulates: Dictionary = {}

func _ready():
	_player = AudioStreamPlayer.new()
	_player.stream = preload("res://assets/audio/cute_click.mp3")
	_player.bus = &"SFX"
	add_child(_player)
	get_tree().node_added.connect(_on_node_added)
	load_sfx_setting()
	_apply_sfx_level()

func _apply_sfx_level():
	var idx := AudioServer.get_bus_index("SFX")
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, sfx_level <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(float(sfx_level) / float(MAX_LEVEL)))

func load_sfx_setting():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		sfx_level = clampi(config.get_value("settings", "sfx_level", MAX_LEVEL), 0, MAX_LEVEL)

func save_sfx_setting():
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("settings", "sfx_level", sfx_level)
	config.save("user://settings.cfg")

func set_sfx_level(level: int):
	level = clampi(level, 0, MAX_LEVEL)
	if sfx_level == level:
		return
	sfx_level = level
	_apply_sfx_level()
	save_sfx_setting()

func _on_node_added(node: Node):
	if not node is BaseButton:
		return
	var id := node.get_instance_id()
	if _wired.has(id):
		if _wired[id].get_ref() == node:
			return
		_wired.erase(id)
	_wired[id] = weakref(node)
	node.button_down.connect(_on_button_down.bind(node))
	node.button_up.connect(_on_button_up.bind(node))
	node.mouse_exited.connect(_restore.bind(node))

func _on_button_down(btn: BaseButton):
	play()
	_pressed_modulates[btn.get_instance_id()] = btn.modulate
	btn.modulate = PRESSED_MODULATE

func _on_button_up(btn: BaseButton):
	_restore(btn)

func _restore(btn: BaseButton):
	var id := btn.get_instance_id()
	if not _pressed_modulates.has(id):
		return
	btn.modulate = _pressed_modulates[id]
	_pressed_modulates.erase(id)

func play():
	_player.play()
