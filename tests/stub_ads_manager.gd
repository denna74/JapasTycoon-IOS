extends "res://autoload/AdsManager.gd"

# Test double for AdsManager: forces internet on, shortens timeouts, drives
# the rewarded-ad lifecycle without touching AdMob, and counts SDK
# initialize() calls so the init guard is observable.

var init_calls: int = 0
var load_calls: int = 0


func _has_internet() -> bool:
	return true


func _ad_load_timeout() -> float:
	return 0.4


func _ad_complete_timeout() -> float:
	return 0.4


func _ensure_sdk_initialized() -> void:
	if _sdk_initialized:
		return
	init_calls += 1


func _load_rewarded_ad() -> void:
	load_calls += 1


func _show_rewarded_ad() -> void:
	_handle_reward()