extends Node

# Project-wide AdMob manager for iOS. Owns the two-ad rewarded flow used to
# recover mood. Registered as the `AdsManager` autoload in project.godot.
#
# AdMob rewarded ad flow:
#   1. Load first rewarded ad
#   2. Show first ad -> on user earned reward -> load second ad
#   3. Show second ad -> on user earned reward -> flow complete
#
# All AdMob types are accessed via ClassDB so the script parses correctly on
# desktop editors where the iOS plugin is absent.

signal mood_reward_earned
signal mood_reward_failed
signal initialized

enum StartResult { SDK_READY, SDK_NOT_READY, FLOW_ALREADY_ACTIVE }

# iOS test rewarded ad unit ID. Replace with your own ad unit ID before
# production release.
const REWARDED_AD_UNIT_ID := "ca-app-pub-3940256099942544/1712485313"

var _sdk_initialized: bool = false
var _ad_flow_active: bool = false
var _ads_completed: int = 0
var _flow_pending: bool = false
var _body_label: Label
var _pending_body_label: Label
var _timeout_timer: Timer

var _rewarded_ad = null
var _full_screen_callback = null
var _admob_available: bool = false
var _mobile_ads = null

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
	_admob_available = ClassDB.class_exists("MobileAds")
	if _admob_available:
		_setup_admob()
	else:
		print("AdsManager: AdMob plugin not available (editor mode)")

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
		_ensure_sdk_initialized()
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
	_load_rewarded_ad()
	_start_timeout(_ad_load_timeout())

func _setup_admob():
	_mobile_ads = ClassDB.instantiate("MobileAds")
	_mobile_ads.connect("initialization_completed", _on_initialized)
	_full_screen_callback = ClassDB.instantiate("FullScreenContentCallback")
	_full_screen_callback.on_ad_dismissed_full_screen_content = _on_ad_dismissed
	_full_screen_callback.on_ad_failed_to_show_full_screen_content = _on_ad_show_failed
	_ensure_sdk_initialized()

# Never re-initialize the SDK once it is already initialized.
func _ensure_sdk_initialized() -> void:
	if _sdk_initialized:
		return
	if not _admob_available:
		return
	_mobile_ads.initialize()

func _start_timeout(seconds: float) -> void:
	if _timeout_timer:
		_timeout_timer.start(seconds)

func _stop_timeout() -> void:
	if _timeout_timer:
		_timeout_timer.stop()

# If an ad neither loads nor finishes in time, abort instead of leaving the
# player trapped in the flow.
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

func _on_initialized(_status = null):
	_sdk_initialized = true
	initialized.emit()
	if _flow_pending and not _ad_flow_active:
		_kick_off_flow(_pending_body_label)

func _load_rewarded_ad():
	if not _admob_available:
		_abort_ad_flow()
		return
	var load_callback = ClassDB.instantiate("RewardedAdLoadCallback")
	load_callback.on_ad_loaded = _on_ad_loaded
	load_callback.on_ad_failed_to_load = _on_ad_load_failed
	var loader = ClassDB.instantiate("RewardedAdLoader")
	var ad_request = ClassDB.instantiate("AdRequest")
	loader.load(REWARDED_AD_UNIT_ID, ad_request, load_callback)

func _on_ad_loaded(ad):
	print("AdsManager: rewarded ad loaded, ads_completed=", _ads_completed)
	if not _ad_flow_active:
		return
	_rewarded_ad = ad
	if _rewarded_ad and _admob_available:
		_rewarded_ad.full_screen_content_callback = _full_screen_callback
	if _ads_completed == 0:
		_set_body_text(TranslationManager.t("mood_ad_watch_1"))
	else:
		_set_body_text(TranslationManager.t("mood_ad_watch_2"))
	_start_timeout(_ad_complete_timeout())
	_show_rewarded_ad()

func _on_ad_load_failed(error):
	print("AdsManager: ad FAILED to load - ", error.message if error else "unknown")
	_abort_ad_flow()

func _show_rewarded_ad():
	if not (_rewarded_ad and _admob_available):
		return
	var reward_listener = ClassDB.instantiate("OnUserEarnedRewardListener")
	reward_listener.on_user_earned_reward = _handle_reward
	_rewarded_ad.show(reward_listener)

func _handle_reward(reward = null):
	print("AdsManager: rewarded, ads_completed was=", _ads_completed)
	if not _ad_flow_active:
		return
	_stop_timeout()
	_ads_completed += 1
	if _ads_completed == 1:
		_set_body_text(TranslationManager.t("mood_ad_loading_next"))
		_load_rewarded_ad()
		_start_timeout(_ad_load_timeout())
	elif _ads_completed >= 2:
		_complete_ad_flow()

func _on_ad_dismissed():
	print("AdsManager: ad dismissed")

func _on_ad_show_failed(ad_error = null):
	print("AdsManager: ad FAILED to show - ", ad_error.message if ad_error else "unknown")
	_abort_ad_flow()

func _complete_ad_flow():
	_stop_timeout()
	_ad_flow_active = false
	_ads_completed = 0
	_rewarded_ad = null
	_body_label = null
	mood_reward_earned.emit()

func _abort_ad_flow():
	_stop_timeout()
	_ad_flow_active = false
	_ads_completed = 0
	_rewarded_ad = null
	_set_body_text(TranslationManager.t("mood_ad_failed"))
	_body_label = null
	mood_reward_failed.emit()

func _set_body_text(text: String):
	if _body_label and is_instance_valid(_body_label):
		_body_label.text = text