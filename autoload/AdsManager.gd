extends Node

# Project-wide Unity Ads manager for iOS. Owns the two-ad rewarded flow used to
# recover mood. Registered as the `AdsManager` autoload in project.godot.
#
# Unity Ads signal order when an ad finishes:
#   1. ad_completed fires first
#   2. rewarded fires second (only if state == "COMPLETED")
#
# We track ads completed with a simple counter. After 2 rewarded ads, the
# flow completes.

signal mood_reward_earned
signal mood_reward_failed
signal initialized

enum StartResult { SDK_READY, SDK_NOT_READY, FLOW_ALREADY_ACTIVE }

var _sdk_initialized: bool = false
var _ad_flow_active: bool = false
var _ads_completed: int = 0
var _flow_pending: bool = false
var _body_label: Label
var _pending_body_label: Label
var _timeout_timer: Timer

# How long to wait for an ad to load before aborting the flow, and how long
# to wait for a shown ad to finish. Overridden in tests.
func _ad_load_timeout() -> float:
	return 10.0

func _ad_complete_timeout() -> float:
	return 60.0

func _ready():
	_timeout_timer = Timer.new()
	_timeout_timer.one_shot = true
	_timeout_timer.timeout.connect(_on_flow_timeout)
	add_child(_timeout_timer)
	_setup_unity_ads()

func _setup_unity_ads():
	UnityAds.initialized.connect(_on_initialized)
	UnityAds.init_failed.connect(_on_init_failed)
	UnityAds.ad_loaded.connect(_on_ad_loaded)
	UnityAds.ad_load_failed.connect(_on_ad_load_failed)
	UnityAds.rewarded.connect(_on_rewarded)
	UnityAds.ad_completed.connect(_on_ad_completed)
	UnityAds.ad_show_failed.connect(_on_ad_show_failed)

func is_initialized() -> bool:
	return _sdk_initialized

func is_flow_active() -> bool:
	return _ad_flow_active

func start_mood_reward_flow(body_label: Label = null) -> int:
	if _ad_flow_active:
		return StartResult.FLOW_ALREADY_ACTIVE
	if not _sdk_initialized:
		_flow_pending = true
		_pending_body_label = body_label
		return StartResult.SDK_NOT_READY
	_kick_off_flow(body_label)
	return StartResult.SDK_READY

func _kick_off_flow(body_label: Label):
	_ad_flow_active = true
	_ads_completed = 0
	_flow_pending = false
	_body_label = body_label
	_pending_body_label = null
	if not _has_internet():
		_set_body_text(TranslationManager.t("mood_ad_no_internet"))
		_abort_ad_flow()
		return
	_set_body_text(TranslationManager.t("mood_ad_loading"))
	_ensure_sdk_initialized()
	UnityAds.load_rewarded()
	_start_timeout(_ad_load_timeout())

# F3: never re-initialize the SDK once it is already initialized.
func _ensure_sdk_initialized() -> void:
	if _sdk_initialized:
		return
	_call_unity_initialize()

func _call_unity_initialize() -> void:
	UnityAds.initialize()

func _start_timeout(seconds: float) -> void:
	if _timeout_timer:
		_timeout_timer.start(seconds)

func _stop_timeout() -> void:
	if _timeout_timer:
		_timeout_timer.stop()

# F1: if an ad neither loads nor finishes in time, abort instead of leaving
# the player trapped in the flow.
func _on_flow_timeout() -> void:
	if _ad_flow_active:
		_abort_ad_flow()

func _has_internet() -> bool:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		if addr.begins_with("127."):
			continue
		if "." in addr and not addr.begins_with("0."):
			return true
	return false

func _on_initialized():
	_sdk_initialized = true
	initialized.emit()
	if _flow_pending and not _ad_flow_active:
		_kick_off_flow(_pending_body_label)

func _on_init_failed(error: String, message: String):
	print("AdsManager: Unity Ads SDK initialization failed - error=", error, " msg=", message)
	_sdk_initialized = false
	# F4: if a flow is waiting on init, fail it so the UI re-enables instead
	# of hanging on "Loading ad..." forever.
	if _flow_pending:
		_fail_pending_flow()

func _fail_pending_flow() -> void:
	_flow_pending = false
	_pending_body_label = null
	mood_reward_failed.emit()

func _on_ad_loaded(placement_id: String):
	if not _ad_flow_active:
		return
	if _ads_completed == 0:
		_set_body_text(TranslationManager.t("mood_ad_watch_1"))
		UnityAds.show_rewarded()
		_start_timeout(_ad_complete_timeout())
	elif _ads_completed == 1:
		_set_body_text(TranslationManager.t("mood_ad_watch_2"))
		UnityAds.show_rewarded()
		_start_timeout(_ad_complete_timeout())

func _on_ad_load_failed(placement_id: String, error: String, message: String):
	print("AdsManager: ad FAILED to load - error=", error, " msg=", message)
	_abort_ad_flow()

func _on_rewarded(placement_id: String):
	_ads_completed += 1
	if _ads_completed == 1:
		UnityAds.load_rewarded()
		_start_timeout(_ad_load_timeout())
	elif _ads_completed >= 2:
		_stop_timeout()
		_complete_ad_flow()

func _on_ad_completed(placement_id: String, state: String):
	# F2: `rewarded` only fires on COMPLETED. An ad that closes without it
	# (skipped/failed) would otherwise hang the flow, so abort so the player
	# can retry.
	if not _ad_flow_active:
		return
	if state != "COMPLETED":
		_abort_ad_flow()
		return
	_stop_timeout()
	if _ads_completed == 0:
		_set_body_text(TranslationManager.t("mood_ad_loading_next"))

func _on_ad_show_failed(placement_id: String, error: String, message: String):
	print("AdsManager: ad FAILED to show - error=", error, " msg=", message)
	_abort_ad_flow()

func _complete_ad_flow():
	_ad_flow_active = false
	_ads_completed = 0
	_body_label = null
	mood_reward_earned.emit()

func _abort_ad_flow():
	_stop_timeout()
	_ad_flow_active = false
	_ads_completed = 0
	_set_body_text(TranslationManager.t("mood_ad_failed"))
	_body_label = null
	mood_reward_failed.emit()

func _set_body_text(text: String):
	if _body_label and is_instance_valid(_body_label):
		_body_label.text = text
