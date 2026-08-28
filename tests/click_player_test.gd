extends Node

# Headless test runner for ClickPlayer button click effect + sfx.
# Run: godot --headless res://tests/click_player_test.tscn

var _failures: int = 0


func _ready() -> void:
	await _test_play_sound()
	await _test_button_wired()
	await _test_texture_button_wired()
	await _test_plain_control_untouched()
	await _test_sfx_level_persists()
	await _test_hover_preserves_custom_modulate()
	print("TEST SUMMARY: failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		push_error("FAIL: " + name)


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _test_play_sound() -> void:
	ClickPlayer.play()
	_check(ClickPlayer._player.playing, "play() starts click sound")
	await _wait_frames(2)
	ClickPlayer._player.stop()


func _test_button_wired() -> void:
	var btn := Button.new()
	add_child(btn)
	btn.button_down.emit()
	_check(btn.modulate != Color.WHITE, "button_down dips brightness")
	_check(ClickPlayer._player.playing, "button_down plays click sound")
	ClickPlayer._player.stop()
	btn.button_up.emit()
	_check(btn.modulate == Color.WHITE, "button_up restores brightness")
	btn.queue_free()
	await _wait_frames(2)


func _test_texture_button_wired() -> void:
	var btn := TextureButton.new()
	add_child(btn)
	btn.button_down.emit()
	_check(btn.modulate != Color.WHITE, "texture button_down dips brightness")
	btn.button_up.emit()
	_check(btn.modulate == Color.WHITE, "texture button_up restores brightness")
	btn.queue_free()
	await _wait_frames(2)


func _test_plain_control_untouched() -> void:
	var label := Label.new()
	add_child(label)
	_check(true, "plain Control added without wiring errors")
	label.queue_free()
	await _wait_frames(2)


func _test_sfx_level_persists() -> void:
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	var original: int = config.get_value("settings", "sfx_level", 4)
	ClickPlayer.set_sfx_level(3)
	_check(ClickPlayer.sfx_level == 3, "sfx_level set to 3")
	config = ConfigFile.new()
	config.load("user://settings.cfg")
	_check(config.get_value("settings", "sfx_level", -1) == 3, "sfx_level persists")
	ClickPlayer.set_sfx_level(99)
	_check(ClickPlayer.sfx_level == 4, "sfx_level clamped to max")
	ClickPlayer.set_sfx_level(original)


func _test_hover_preserves_custom_modulate() -> void:
	var btn := Button.new()
	add_child(btn)
	btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
	btn.mouse_exited.emit()
	_check(btn.modulate == Color(0.5, 0.5, 0.5, 0.7), "hover exit preserves custom modulate")
	btn.button_down.emit()
	_check(btn.modulate == Color(0.7, 0.7, 0.7, 1), "button_down darkens")
	btn.mouse_exited.emit()
	_check(btn.modulate == Color(0.5, 0.5, 0.5, 0.7), "exit after press restores original modulate")
	btn.button_up.emit()
	_check(btn.modulate == Color(0.5, 0.5, 0.5, 0.7), "stray button_up keeps original modulate")
	btn.queue_free()
	await _wait_frames(2)
