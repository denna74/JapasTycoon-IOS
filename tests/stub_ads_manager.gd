extends "res://autoload/AdsManager.gd"

# Test double for AdsManager: forces internet on, shortens timeouts, and counts
# SDK initialize() calls so the init guard is observable. Unity Ads events are
# simulated by the test calling the manager's handler methods directly.

var init_calls: int = 0


func _has_internet() -> bool:
	return true


func _ad_load_timeout() -> float:
	return 0.4


func _ad_complete_timeout() -> float:
	return 0.4


func _call_unity_initialize() -> void:
	init_calls += 1
