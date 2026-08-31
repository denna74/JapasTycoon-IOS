extends Node

# Headless test runner for the iOS force-quit mood penalty flow.
# Verifies the pending_quit_penalty flag mechanics in SaveManager:
#   - setting the flag marks a pending penalty
#   - clearing it (on app resume) removes any penalty
#   - applying it on a fresh launch deducts exactly one mood and clears the flag
#   - applying with no flag does nothing
# Run: godot --headless res://tests/quit_penalty_test.tscn

const SaveManagerScript = preload("res://autoload/SaveManager.gd")

var _failures: int = 0


class TestSaveManager:
	extends SaveManagerScript

	func _ready():
		pass

	func save_game():
		pass

	func load_game() -> bool:
		return false

	func reset_to_defaults():
		pass


func _ready() -> void:
	await _test_flag_set_get_clear()
	await _test_apply_with_flag_deducts_once()
	await _test_apply_without_flag_noop()
	print("TEST SUMMARY: failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		push_error("FAIL: " + name)


func _make_manager() -> TestSaveManager:
	var m: TestSaveManager = TestSaveManager.new()
	add_child(m)
	return m


func _test_flag_set_get_clear() -> void:
	var m: TestSaveManager = _make_manager()
	_check(not m.is_pending_quit_penalty(), "initial flag is false")
	m.set_pending_quit_penalty(true)
	_check(m.is_pending_quit_penalty(), "flag is true after mark")
	m.set_pending_quit_penalty(false)
	_check(not m.is_pending_quit_penalty(), "flag is false after clear")
	m.queue_free()
	await get_tree().process_frame


func _test_apply_with_flag_deducts_once() -> void:
	var m: TestSaveManager = _make_manager()
	m.mood_level = 3
	m.last_failure_time = 0
	m.set_pending_quit_penalty(true)
	var before := m.mood_level
	m.apply_pending_quit_penalty_if_any()
	_check(m.mood_level == before - 1, "mood deducted by one on fresh launch with flag")
	_check(not m.is_pending_quit_penalty(), "flag cleared after applying penalty")
	m.queue_free()
	await get_tree().process_frame


func _test_apply_without_flag_noop() -> void:
	var m: TestSaveManager = _make_manager()
	m.mood_level = 3
	m.set_pending_quit_penalty(false)
	m.apply_pending_quit_penalty_if_any()
	_check(m.mood_level == 3, "mood unchanged when no flag set")
	m.queue_free()
	await get_tree().process_frame
