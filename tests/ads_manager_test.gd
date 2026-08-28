extends Node

# Headless test runner for AdsManager (Unity Ads iOS) fixes F1-F4.
# Run: godot --headless res://tests/ads_manager_test.tscn

const StubAdsManager = preload("res://tests/stub_ads_manager.gd")

const REWARDED := "Rewarded_iOS"

var _failures: int = 0


func _ready() -> void:
	await _test_load_timeout_aborts()
	await _test_show_failure_aborts()
	await _test_init_guard_skips_initialize()
	await _test_pending_flow_auto_starts_on_init()
	await _test_skipped_ad_aborts()
	await _test_normal_completed_flow_still_earns()
	_test_menu_level_select_compiles()
	print("TEST SUMMARY: failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		push_error("FAIL: " + name)


func _make_manager() -> StubAdsManager:
	var m: StubAdsManager = StubAdsManager.new()
	add_child(m)
	return m


func _make_label() -> Label:
	var label := Label.new()
	add_child(label)
	return label


func _free_node(n: Node) -> void:
	n.queue_free()


func _test_load_timeout_aborts() -> void:
	var m := _make_manager()
	var got := {"failed": false}
	m.mood_reward_failed.connect(func(): got["failed"] = true)
	m._kick_off_flow(_make_label())
	_check(m.is_flow_active(), "F1 flow active right after kickoff")
	await get_tree().create_timer(1.0).timeout
	_check(got["failed"], "F1 load timeout emits mood_reward_failed")
	_check(not m.is_flow_active(), "F1 flow inactive after load timeout")
	_free_node(m)


func _test_show_failure_aborts() -> void:
	var m := _make_manager()
	var got := {"failed": false}
	m.mood_reward_failed.connect(func(): got["failed"] = true)
	m._kick_off_flow(_make_label())
	m._on_ad_show_failed(REWARDED, "error", "msg")
	_check(got["failed"], "F2 ad show failure emits mood_reward_failed")
	_check(not m.is_flow_active(), "F2 flow inactive after show failure")
	_free_node(m)


func _test_init_guard_skips_initialize() -> void:
	var m := _make_manager()
	m._sdk_initialized = true
	m._call_unity_initialize()
	m._ensure_sdk_initialized()
	_check(m.init_calls == 1, "F3 no re-init when already initialized (counter unchanged)")
	m._sdk_initialized = false
	m._ensure_sdk_initialized()
	_check(m.init_calls == 2, "F3 initialize() called when not yet initialized")
	_free_node(m)


func _test_pending_flow_auto_starts_on_init() -> void:
	var m := _make_manager()
	var result: int = m.start_mood_reward_flow(null)
	_check(result == m.StartResult.SDK_NOT_READY, "F4 SDK not ready returns SDK_NOT_READY")
	_check(not m.is_flow_active(), "F4 no flow running before SDK initializes")
	m._sdk_initialized = true
	m._on_initialized()
	_check(m.is_flow_active(), "F4 pending flow auto-starts when SDK initializes")
	_free_node(m)


func _test_skipped_ad_aborts() -> void:
	var m := _make_manager()
	var got := {"failed": false}
	m.mood_reward_failed.connect(func(): got["failed"] = true)
	m._kick_off_flow(_make_label())
	m._on_ad_completed(REWARDED, "SKIPPED")
	_check(got["failed"], "F2 skipped ad emits mood_reward_failed")
	_check(not m.is_flow_active(), "F2 flow inactive after skipped ad")
	_free_node(m)


func _test_normal_completed_flow_still_earns() -> void:
	var m := _make_manager()
	var got := {"earned": false}
	m.mood_reward_earned.connect(func(): got["earned"] = true)
	m._kick_off_flow(_make_label())
	m._on_ad_loaded(REWARDED)
	_check(m.is_flow_active(), "first ad keeps flow active")
	m._on_ad_completed(REWARDED, "COMPLETED")
	m._on_rewarded(REWARDED)
	_check(m.is_flow_active(), "after first reward flow still active (loading second ad)")
	m._on_ad_loaded(REWARDED)
	m._on_ad_completed(REWARDED, "COMPLETED")
	m._on_rewarded(REWARDED)
	_check(got["earned"], "F2 normal 2-ad flow still earns reward")
	_check(not m.is_flow_active(), "F2 flow finished after reward")
	_free_node(m)


func _test_menu_level_select_compiles() -> void:
	var script := load("res://scenes/menu/MenuLevelSelect.gd")
	_check(script != null, "MenuLevelSelect.gd compiles with autoloads registered")
