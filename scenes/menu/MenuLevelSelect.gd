extends Control

@onready var main_menu_view := $MainMenuView
@onready var level_track_view := $LevelTrackView
@onready var logo := $MainMenuView/Logo
@onready var settings_btn := $MainMenuView/SettingsButton
@onready var play_btn := $MainMenuView/PlayButton
@onready var explanation_label := $MainMenuView/ExplanationLabel
@onready var user_info_bar := $LevelTrackView/UserInfoBar
@onready var level_scroll := $LevelTrackView/LevelScroll
@onready var level_grid := $LevelTrackView/LevelScroll/LevelGrid
@onready var main_menu_btn := $LevelTrackView/MainMenuBack
@onready var _skill_container := $LevelTrackView/SkillsBar/SkillContainer
@onready var _skills_bg := $LevelTrackView/SkillsBar/SkillsBg

var catalog_panel: Control
var catalog_current_page: int = 0
var _swipe_start_x: float = 0.0
var _page_player: AudioStreamPlayer
var _instant_coins_btn: TextureButton
var _instant_moods_btn: TextureButton

var _play_en: Texture2D = preload("res://assets/icons_buttons/play_en.png")
var _play_id: Texture2D = preload("res://assets/icons_buttons/play_id.png")
var _settings_en: Texture2D = preload("res://assets/icons_buttons/settings_en.png")
var _settings_id: Texture2D = preload("res://assets/icons_buttons/settings_id.png")
var _main_menu_en: Texture2D = preload("res://assets/icons_buttons/main_menu_en.png")
var _main_menu_id: Texture2D = preload("res://assets/icons_buttons/main_manu_id.png")
var _skills_bg_en: Texture2D = preload("res://assets/skills/skills_shop_en.png")
var _skills_bg_id: Texture2D = preload("res://assets/skills/skills_shop_id.png")
var _instant_coins_en: Texture2D = preload("res://assets/instant/instant_coins_en.png")
var _instant_coins_id: Texture2D = preload("res://assets/instant/instant_coins_id.png")
var _instant_moods_en: Texture2D = preload("res://assets/instant/instant_moods_en.png")
var _instant_moods_id: Texture2D = preload("res://assets/instant/instant_moods_id.png")
var _ok_icon: Texture2D = preload("res://assets/icons_buttons/ok.png")
var _cancel_en: Texture2D = preload("res://assets/icons_buttons/cancel_en.png")
var _cancel_id: Texture2D = preload("res://assets/icons_buttons/cancel_id.png")
var _instant_mood_btn_en: Texture2D = preload("res://assets/icons_buttons/instant_mood_en.png")
var _instant_mood_btn_id: Texture2D = preload("res://assets/icons_buttons/instant_mood_id.png")

const SettingsPopupScene := preload("res://scenes/menu/SettingsPopup.tscn")
var _settings_popup: Control

func _ready():
	TranslationManager.language_changed.connect(_update_ui_texts)
	SaveManager.coins_changed.connect(_on_coins_changed)
	SaveManager.mood_changed.connect(_on_mood_changed)
	IAPManager.billing_ready.connect(_on_billing_ready)
	IAPManager.purchases_restored.connect(_on_purchases_restored)
	_on_purchases_restored()

	play_btn.pivot_offset = play_btn.size / 2
	_breathe_play_btn()

	play_btn.pressed.connect(_on_play_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_back)
	settings_btn.pressed.connect(_on_settings_pressed)
	MusicManager.bgm_changed.connect(func(): MusicManager.apply_to_player($BGMPlayer))
	MusicManager.apply_to_player($BGMPlayer)

	_page_player = AudioStreamPlayer.new()
	_page_player.stream = load("res://assets/audio/page_flip.wav")
	_page_player.bus = &"SFX"
	add_child(_page_player)

	_mm_top = main_menu_view.offset_top
	_mm_bottom = main_menu_view.offset_bottom
	_lt_top = level_track_view.offset_top
	_lt_bottom = level_track_view.offset_bottom

	if SceneManager.show_level_track:
		SceneManager.show_level_track = false
		show_level_track()
	elif SceneManager.cold_start:
		_play_splash_animation()
	else:
		show_main_menu()

func _breathe_play_btn():
	var t = create_tween()
	t.tween_property(play_btn, "scale", Vector2(1.06, 1.06), 0.9).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(play_btn, "scale", Vector2(1.0, 1.0), 0.9).set_ease(Tween.EASE_IN_OUT)
	t.finished.connect(_breathe_play_btn)

func _breathe_loop(node: Control, max_scale: float, duration: float):
	if not is_instance_valid(node):
		return
	var t = node.create_tween()
	t.tween_property(node, "scale", Vector2(max_scale, max_scale), duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "scale", Vector2(1.0, 1.0), duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.finished.connect(func(): _breathe_loop(node, max_scale, duration))

func _play_splash_animation():
	SceneManager.cold_start = false
	main_menu_view.visible = true
	level_track_view.visible = false
	_update_ui_texts()

	logo.offset_top = 287
	logo.offset_bottom = 567

	var ui_elements = [play_btn, explanation_label, settings_btn]
	for el in ui_elements:
		el.modulate = Color(1, 1, 1, 0)

	await get_tree().create_timer(0.5).timeout

	var tween = create_tween().set_parallel()
	tween.tween_property(logo, "offset_top", 80, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(logo, "offset_bottom", 360, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	for el in ui_elements:
		tween.tween_property(el, "modulate", Color.WHITE, 0.4)

	await tween.finished

var _mm_top: float
var _mm_bottom: float
var _lt_top: float
var _lt_bottom: float

func show_main_menu():
	main_menu_view.offset_top = _mm_top
	main_menu_view.offset_bottom = _mm_bottom
	main_menu_view.modulate = Color.WHITE
	main_menu_view.visible = true
	level_track_view.visible = false
	_update_ui_texts()

func show_level_track():
	level_track_view.offset_top = _lt_top
	level_track_view.offset_bottom = _lt_bottom
	level_track_view.modulate = Color.WHITE
	main_menu_view.visible = false
	level_track_view.visible = true
	_update_ui_texts()
	_build_level_grid()
	_on_coins_changed(SaveManager.coins)
	_on_mood_changed(SaveManager.mood_level)
	_build_skill_buttons()
	_setup_catalog_button()

func _transition_to_level_track():
	var tween = create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(main_menu_view, "offset_top", _mm_top - 30, 0.3)
	tween.tween_property(main_menu_view, "offset_bottom", _mm_bottom - 30, 0.3)
	tween.tween_property(main_menu_view, "modulate", Color(1, 1, 1, 0), 0.3)
	await tween.finished

	show_level_track()
	level_track_view.offset_top = _lt_top + 30
	level_track_view.offset_bottom = _lt_bottom + 30
	level_track_view.modulate = Color(1, 1, 1, 0)

	var tween2 = create_tween().set_parallel()
	tween2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween2.tween_property(level_track_view, "offset_top", _lt_top, 0.3)
	tween2.tween_property(level_track_view, "offset_bottom", _lt_bottom, 0.3)
	tween2.tween_property(level_track_view, "modulate", Color(1, 1, 1, 1), 0.3)
	await tween2.finished

func _transition_to_main_menu():
	var tween = create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(level_track_view, "offset_top", _lt_top - 30, 0.3)
	tween.tween_property(level_track_view, "offset_bottom", _lt_bottom - 30, 0.3)
	tween.tween_property(level_track_view, "modulate", Color(1, 1, 1, 0), 0.3)
	await tween.finished

	show_main_menu()
	main_menu_view.offset_top = _mm_top + 30
	main_menu_view.offset_bottom = _mm_bottom + 30
	main_menu_view.modulate = Color(1, 1, 1, 0)

	var tween2 = create_tween().set_parallel()
	tween2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween2.tween_property(main_menu_view, "offset_top", _mm_top, 0.3)
	tween2.tween_property(main_menu_view, "offset_bottom", _mm_bottom, 0.3)
	tween2.tween_property(main_menu_view, "modulate", Color(1, 1, 1, 1), 0.3)
	await tween2.finished

func _on_play_pressed():
	_transition_to_level_track()

func _on_main_menu_back():
	_transition_to_main_menu()

func _on_settings_pressed():
	_close_settings_popup()
	_settings_popup = SettingsPopupScene.instantiate()
	add_child(_settings_popup)

func _close_settings_popup():
	if is_instance_valid(_settings_popup):
		_settings_popup.queue_free()
	_settings_popup = null

func _update_ui_texts(_lang: String = ""):
	var t := TranslationManager
	if t.current_language == "en":
		logo.texture = preload("res://assets/logo_en.png")
		play_btn.texture_normal = _play_en
		settings_btn.texture_normal = _settings_en
		main_menu_btn.texture_normal = _main_menu_en
		_skills_bg.texture = _skills_bg_en
	else:
		logo.texture = preload("res://assets/logo_id.png")
		play_btn.texture_normal = _play_id
		settings_btn.texture_normal = _settings_id
		main_menu_btn.texture_normal = _main_menu_id
		_skills_bg.texture = _skills_bg_id
	explanation_label.text = t.t("explanation")
	_update_instant_button_textures()

func _update_instant_button_textures():
	if not _instant_coins_btn or not _instant_moods_btn:
		return
	var t = TranslationManager
	if t.current_language == "en":
		_instant_coins_btn.texture_normal = _resize_texture(_instant_coins_en, 80, 80)
		_instant_moods_btn.texture_normal = _resize_texture(_instant_moods_en, 80, 80)
	else:
		_instant_coins_btn.texture_normal = _resize_texture(_instant_coins_id, 80, 80)
		_instant_moods_btn.texture_normal = _resize_texture(_instant_moods_id, 80, 80)

func _update_moods_button_state():
	if not _instant_moods_btn:
		return
	var is_full = SaveManager.mood_level >= 3
	_instant_moods_btn.disabled = is_full
	_instant_moods_btn.modulate = Color(0.5, 0.5, 0.5, 0.7) if is_full else Color.WHITE

func _build_coin_display(coins: int):
	var existing = user_info_bar.get_node_or_null("CoinDisplay")
	if existing:
		existing.free()

	var coin_display = Control.new()
	coin_display.name = "CoinDisplay"
	user_info_bar.add_child(coin_display)

	var coin_tex = preload("res://assets/icons_buttons/coin.png")
	for i in range(3):
		var coin = TextureRect.new()
		coin.texture = coin_tex
		coin.custom_minimum_size = Vector2(24, 24)
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.position = Vector2(10 + i * 17, 20)
		coin_display.add_child(coin)

	var colon = Label.new()
	colon.text = ":"
	colon.add_theme_font_size_override("font_size", 18)
	colon.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	colon.position = Vector2(69, 17)
	colon.size = Vector2(20, 28)
	coin_display.add_child(colon)

	var digits = str(coins)
	for i in digits.length():
		var d = digits[i]
		var tex = load("res://assets/text_icon/number_green/%s.png" % d)
		var nr = TextureRect.new()
		nr.texture = tex
		nr.custom_minimum_size = Vector2(18, 22)
		nr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		nr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		nr.position = Vector2(83 + i * 12, 21)
		coin_display.add_child(nr)

func _build_mood_display(mood: int):
	var existing = user_info_bar.get_node_or_null("MoodDisplay")
	if existing:
		existing.free()

	var mood_display = Control.new()
	mood_display.name = "MoodDisplay"
	user_info_bar.add_child(mood_display)

	var mood_label = Label.new()
	mood_label.text = "Mood"
	mood_label.add_theme_font_size_override("font_size", 16)
	mood_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	mood_label.position = Vector2(15, 48)
	mood_label.size = Vector2(50, 28)
	mood_display.add_child(mood_label)

	var colon = Label.new()
	colon.text = ":"
	colon.add_theme_font_size_override("font_size", 18)
	colon.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	colon.position = Vector2(69, 45)
	colon.size = Vector2(15, 28)
	mood_display.add_child(colon)

	var heart_tex = preload("res://assets/icons_buttons/heart.png")
	var heart_lost_tex = preload("res://assets/icons_buttons/heart_lost.png")
	for i in range(3):
		var heart = TextureRect.new()
		heart.texture = heart_tex if i < mood else heart_lost_tex
		heart.custom_minimum_size = Vector2(24, 22)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.position = Vector2(83 + i * 22, 50)
		mood_display.add_child(heart)

func _on_coins_changed(new_coins: int):
	_build_coin_display(new_coins)

func _on_mood_changed(new_mood: int):
	_build_mood_display(new_mood)
	_update_moods_button_state()

func _on_billing_ready():
	var overlay = get_node_or_null("InstantOverlay")
	if not overlay:
		return
	var popup = get_node_or_null("InstantPopup")
	if not popup:
		return
	var iap_status = popup.get_node_or_null("IapStatus")
	if iap_status:
		iap_status.text = ""
	for i in range(3):
		var btn = popup.get_node_or_null("CoinOption%d" % i)
		if btn:
			btn.disabled = false

func _on_purchases_restored():
	var pending = IAPManager.get_pending_restorations()
	for p in pending:
		var sku = p["sku"]
		var token = p["token"]
		if SaveManager.is_purchase_processed(token):
			continue
		var reward = IAPConfig.get_coin_reward(sku)
		if reward > 0:
			SaveManager.add_coins(reward)
			SaveManager.mark_purchase_processed(token, sku)
			IAPManager.finalize_purchase(token, sku)

func _build_level_grid():
	for child in level_grid.get_children():
		child.queue_free()

	var max_reached = SaveManager.max_level
	var total_to_show = max_reached + 5

	for lvl in range(total_to_show, 0, -1):
		if lvl == max_reached:
			_latest_level_btn(lvl)
		elif lvl < max_reached:
			_playable_level_node(lvl)
		else:
			_locked_level_node(lvl)

func _level_node_size() -> Vector2:
	return Vector2(80, 56)

func _latest_level_btn(lvl: int):
	var container = Control.new()
	container.custom_minimum_size = Vector2(140, 100)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_level_node_input.bind(lvl))

	var tex = load("res://assets/level_nodes/gerobak.png")
	var bg = TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)

	_add_level_number(container, lvl, Vector2(140, 100), 28)
	level_grid.add_child(container)

	container.pivot_offset = Vector2(70, 50)
	_breathe_loop(container, 1.08, 1.2)

func _add_level_number(container: Control, lvl: int, node_size: Vector2 = _level_node_size(), num_size: int = 20):
	var s = node_size
	var digits = str(lvl)
	var total_w = digits.length() * num_size
	var start_x = (s.x - total_w) / 2
	for i in range(digits.length()):
		var d = digits[i]	
		var num_tex = load("res://assets/text_icon/number_purple/%s_purple.png" % d)
		var nr = TextureRect.new()
		nr.texture = num_tex
		nr.position = Vector2(start_x + i * num_size, (s.y - num_size) / 2 + 5)
		nr.custom_minimum_size = Vector2(num_size, num_size)
		nr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		nr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		nr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(nr)

func _playable_level_node(lvl: int):
	var rating = SaveManager.get_rating(lvl)
	var tex = load("res://assets/level_nodes/star_%d.png" % rating)

	var container = Control.new()
	container.custom_minimum_size = _level_node_size()
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_level_node_input.bind(lvl))

	var bg = TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)

	_add_level_number(container, lvl)

	level_grid.add_child(container)

func _locked_level_node(lvl: int):
	var tex = load("res://assets/lock.png")

	var container = Control.new()
	container.custom_minimum_size = Vector2(60, 60)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var bg = TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.modulate = Color(0.5, 0.5, 0.5, 0.5)
	container.add_child(bg)

	level_grid.add_child(container)

func _on_level_node_input(event: InputEvent, lvl: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_level_selected(lvl)

func _setup_catalog_button():
	if not level_track_view.get_node_or_null("CatalogBtn"):
		var btn_tex = TextureRect.new()
		btn_tex.name = "CatalogBtn"
		btn_tex.texture = _resize_texture(preload("res://assets/notebook_button.png"), 60, 60)
		btn_tex.position = Vector2(410, 20)
		btn_tex.gui_input.connect(_on_catalog_btn_input)
		level_track_view.add_child(btn_tex)

		btn_tex.pivot_offset = btn_tex.size / 2
		_breathe_loop(btn_tex, 1.15, 1.2)

	if not level_track_view.get_node_or_null("InstantCoinsBtn"):
		var coins_btn = TextureButton.new()
		coins_btn.name = "InstantCoinsBtn"
		coins_btn.ignore_texture_size = true
		coins_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		coins_btn.position = Vector2(220, 10)
		coins_btn.size = Vector2(80, 80)
		coins_btn.pressed.connect(_on_instant_coins_pressed)
		level_track_view.add_child(coins_btn)
		_instant_coins_btn = coins_btn

	if not level_track_view.get_node_or_null("InstantMoodsBtn"):
		var mood_btn = TextureButton.new()
		mood_btn.name = "InstantMoodsBtn"
		mood_btn.ignore_texture_size = true
		mood_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		mood_btn.position = Vector2(315, 10)
		mood_btn.size = Vector2(80, 80)
		mood_btn.pressed.connect(_on_instant_moods_pressed)
		level_track_view.add_child(mood_btn)
		_instant_moods_btn = mood_btn

	_update_instant_button_textures()
	_update_moods_button_state()

static func _resize_texture(src: Texture2D, w: int, h: int) -> Texture2D:
	var img = src.get_image()
	if img:
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
		return ImageTexture.create_from_image(img)
	return src

func _on_catalog_btn_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_catalog_open()

func _on_instant_coins_pressed():
	_show_instant_popup("instant_coins_title")

func _on_instant_moods_pressed():
	_show_instant_popup("instant_moods_title")

func _show_instant_popup(key: String):
	var overlay = ColorRect.new()
	overlay.name = "InstantOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var popup = Control.new()
	popup.name = "InstantPopup"
	popup.anchor_left = 0.5
	popup.anchor_top = 0.5
	popup.anchor_right = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -130.0
	popup.offset_top = -150.0
	popup.offset_right = 130.0
	popup.offset_bottom = 150.0
	add_child(popup)

	var bg = Panel.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	bg.add_theme_stylebox_override("panel", style)
	popup.add_child(bg)

	var label = Label.new()
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.offset_top = 30.0
	label.offset_bottom = 60.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_font_size_override("font_size", 16)
	label.text = TranslationManager.t(key)
	popup.add_child(label)

	if key == "instant_coins_title":
		popup.offset_top = -175.0
		popup.offset_bottom = 175.0
		var iap_status = Label.new()
		iap_status.name = "IapStatus"
		iap_status.anchor_left = 0.0
		iap_status.anchor_right = 1.0
		iap_status.offset_top = 244.0
		iap_status.offset_bottom = 264.0
		iap_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		iap_status.add_theme_color_override("font_color", Color(1, 0.85, 0, 1))
		iap_status.add_theme_font_size_override("font_size", 11)
		iap_status.text = ""
		popup.add_child(iap_status)
		_build_instant_coins_options(popup, overlay, popup, iap_status)
		var t = TranslationManager
		var cancel_btn = TextureButton.new()
		cancel_btn.ignore_texture_size = true
		cancel_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		cancel_btn.position = Vector2(65, 268)
		cancel_btn.size = Vector2(130, 40)
		cancel_btn.texture_normal = _cancel_en if t.current_language == "en" else _cancel_id
		cancel_btn.pressed.connect(_close_instant_popup.bind(overlay, popup))
		popup.add_child(cancel_btn)
	else:
		var desc_label = Label.new()
		desc_label.anchor_left = 0.0
		desc_label.anchor_right = 1.0
		desc_label.offset_top = 65.0
		desc_label.offset_bottom = 90.0
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.text = TranslationManager.t("instant_moods_desc")
		popup.add_child(desc_label)

		var t = TranslationManager
		var status_label = Label.new()
		status_label.anchor_left = 0.0
		status_label.anchor_right = 1.0
		status_label.offset_top = 93.0
		status_label.offset_bottom = 113.0
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_color_override("font_color", Color(1, 0.85, 0, 1))
		status_label.add_theme_font_size_override("font_size", 11)
		status_label.text = ""
		popup.add_child(status_label)

		var watch_btn = TextureButton.new()
		watch_btn.ignore_texture_size = true
		watch_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		watch_btn.position = Vector2(65, 115)
		watch_btn.size = Vector2(130, 40)
		watch_btn.texture_normal = _instant_mood_btn_en if t.current_language == "en" else _instant_mood_btn_id
		watch_btn.pressed.connect(_on_watch_ad_pressed.bind(watch_btn, status_label, overlay, popup))
		popup.add_child(watch_btn)

		var cancel_btn = TextureButton.new()
		cancel_btn.ignore_texture_size = true
		cancel_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		cancel_btn.position = Vector2(65, 185)
		cancel_btn.size = Vector2(130, 40)
		cancel_btn.texture_normal = _cancel_en if t.current_language == "en" else _cancel_id
		cancel_btn.pressed.connect(_close_instant_popup.bind(overlay, popup))
		popup.add_child(cancel_btn)

func _build_instant_coins_options(popup: Control, overlay: ColorRect, popup_ref: Control, iap_status: Label):
	var icon_paths := [
		"res://assets/icons_buttons/instant_coins_1.png",
		"res://assets/icons_buttons/instant_coins_2.png",
		"res://assets/icons_buttons/instant_coins_3.png",
	]
	var sku_keys := ["instant_coins_1", "instant_coins_2", "instant_coins_3"]
	for i in range(3):
		var btn = Button.new()
		btn.name = "CoinOption%d" % i
		btn.flat = true
		btn.expand_icon = true
		btn.icon = load(icon_paths[i])
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		btn.anchor_left = 0.0
		btn.anchor_right = 1.0
		btn.offset_left = 5
		btn.offset_right = -5
		var y = 68.0 + i * 58.0
		btn.offset_top = y
		btn.offset_bottom = y + 52.0
		btn.pressed.connect(_on_coin_purchase_pressed.bind(sku_keys[i], btn, iap_status, overlay, popup_ref))
		btn.text = "$%d" % [i + 1]
		if not IAPManager.is_products_ready():
			btn.disabled = true
		popup.add_child(btn)

func _close_instant_popup(overlay: ColorRect, popup: Control):
	if is_instance_valid(popup):
		popup.queue_free()
	if is_instance_valid(overlay):
		overlay.queue_free()

func _on_watch_ad_pressed(watch_btn: TextureButton, status_label: Label, overlay: ColorRect, popup: Control):
	AdsManager.mood_reward_earned.connect(_on_mood_reward_earned.bind(overlay, popup), CONNECT_ONE_SHOT)
	AdsManager.mood_reward_failed.connect(_on_mood_reward_failed.bind(watch_btn, status_label), CONNECT_ONE_SHOT)
	var result = AdsManager.start_mood_reward_flow(status_label)
	match result:
		AdsManager.StartResult.SDK_READY:
			if AdsManager.is_flow_active():
				watch_btn.disabled = true
				watch_btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
		AdsManager.StartResult.SDK_NOT_READY:
			# Keep the button usable. AdsManager auto-starts the flow when the
			# SDK initializes, and fails the pending flow if init fails — the
			# failed handler re-enables the button either way.
			status_label.text = TranslationManager.t("mood_ad_loading")
		AdsManager.StartResult.FLOW_ALREADY_ACTIVE:
			pass

func _on_mood_reward_earned(overlay: ColorRect, popup: Control):
	if not is_instance_valid(overlay) or not is_instance_valid(popup):
		return
	SaveManager.mood_level = clampi(SaveManager.mood_level + 1, 0, 3)
	SaveManager.mood_changed.emit(SaveManager.mood_level)
	SaveManager.save_game()
	_close_instant_popup(overlay, popup)

func _on_mood_reward_failed(watch_btn: TextureButton, status_label: Label):
	if is_instance_valid(status_label):
		status_label.text = TranslationManager.t("mood_ad_failed")
	if is_instance_valid(watch_btn):
		watch_btn.disabled = false
		watch_btn.modulate = Color.WHITE

func _on_coin_purchase_pressed(sku_key: String, btn: Button, iap_status: Label, overlay: ColorRect, popup: Control):
	btn.disabled = true
	var sku = IAPConfig.get_sku(sku_key)
	var result = IAPManager.purchase(sku)
	match result:
		IAPManager.PurchaseResult.OK:
			iap_status.text = TranslationManager.t("iap_purchasing")
		IAPManager.PurchaseResult.NOT_INITIALIZED:
			iap_status.text = TranslationManager.t("iap_not_ready")
			btn.disabled = false
		IAPManager.PurchaseResult.UNAVAILABLE:
			iap_status.text = TranslationManager.t("iap_unavailable")
			btn.disabled = false
		IAPManager.PurchaseResult.NO_SKU:
			iap_status.text = TranslationManager.t("iap_unavailable")
			btn.disabled = false
	IAPManager.purchase_successful.connect(_on_coin_purchase_success.bind(sku_key, overlay, popup), CONNECT_ONE_SHOT)
	IAPManager.purchase_failed.connect(_on_coin_purchase_failed.bind(btn, iap_status), CONNECT_ONE_SHOT)

func _on_coin_purchase_success(sku: String, token: String, expected_sku_key: String, overlay: ColorRect, popup: Control):
	if sku != IAPConfig.get_sku(expected_sku_key):
		return
	var reward = IAPConfig.get_coin_reward(sku)
	SaveManager.add_coins(reward)
	SaveManager.mark_purchase_processed(token, sku)
	IAPManager.finalize_purchase(token, sku)
	if is_instance_valid(overlay) and is_instance_valid(popup):
		_close_instant_popup(overlay, popup)

func _on_coin_purchase_failed(sku: String, btn: Button, iap_status: Label):
	if is_instance_valid(iap_status):
		iap_status.text = TranslationManager.t("iap_purchase_failed")
	if is_instance_valid(btn):
		btn.disabled = false

func _on_catalog_open():
	if catalog_panel:
		return
	catalog_current_page = 0
	_build_catalog_panel()
	_show_catalog_page(0)
	add_child(catalog_panel)

	var screen_size = get_viewport_rect().size
	catalog_panel.position = Vector2.ZERO
	catalog_panel.size = screen_size

	var overlay = catalog_panel.get_node("OverlayBg") as ColorRect
	if overlay:
		overlay.position = Vector2.ZERO
		overlay.size = screen_size

func _close_catalog():
	if catalog_panel:
		catalog_panel.queue_free()
		catalog_panel = null

func _build_catalog_panel():
	catalog_panel = Control.new()
	catalog_panel.name = "CatalogPanel"

	var overlay = ColorRect.new()
	overlay.name = "OverlayBg"
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	catalog_panel.add_child(overlay)

	var nb = Control.new()
	nb.name = "NotebookContainer"
	nb.clip_contents = true
	nb.gui_input.connect(_on_catalog_panel_input)
	var screen_size = get_viewport_rect().size
	var margin = 15
	var nb_size = Vector2(screen_size.x - 2 * margin, screen_size.y - 2 * margin)
	nb.position = Vector2(margin, margin)
	nb.size = nb_size

	var nb_bg = TextureRect.new()
	nb_bg.name = "NotebookBg"
	nb_bg.texture = _resize_texture(preload("res://assets/notebook.png"), int(nb_size.x), int(nb_size.y))
	nb_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	nb_bg.position = Vector2.ZERO
	nb_bg.custom_minimum_size = nb_size
	nb_bg.size = nb_size
	nb_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	nb.add_child(nb_bg)

	var page_label = Label.new()
	page_label.name = "PageLabel"
	page_label.add_theme_font_size_override("font_size", 20)
	page_label.add_theme_color_override("font_color", Color.BLACK)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.position = Vector2(10, 25)
	page_label.size = Vector2(450, 36)
	page_label.mouse_filter = Control.MOUSE_FILTER_PASS
	nb.add_child(page_label)

	var close_btn = Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "X"
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.add_theme_stylebox_override("normal", _make_red_style())
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.position = Vector2(396, 19)
	close_btn.pressed.connect(_close_catalog)
	nb.add_child(close_btn)

	var real_pic = TextureRect.new()
	real_pic.name = "RealPic"
	real_pic.custom_minimum_size = Vector2(300, 225)
	real_pic.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	real_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	real_pic.position = Vector2(85, 65)
	real_pic.mouse_filter = Control.MOUSE_FILTER_PASS
	nb.add_child(real_pic)

	var desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.custom_minimum_size = Vector2(350, 0)
	desc_label.size = Vector2(350, 240)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color.BLACK)
	desc_label.position = Vector2(70, 310)
	desc_label.mouse_filter = Control.MOUSE_FILTER_PASS
	nb.add_child(desc_label)

	var unlock_label = Label.new()
	unlock_label.name = "UnlockLabel"
	unlock_label.add_theme_font_size_override("font_size", 14)
	unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_label.custom_minimum_size = Vector2(410, 0)
	unlock_label.position = Vector2(20, 560)
	unlock_label.visible = false
	unlock_label.mouse_filter = Control.MOUSE_FILTER_PASS
	nb.add_child(unlock_label)

	var nav = HBoxContainer.new()
	nav.name = "Nav"
	nav.position = Vector2(70, 590)
	nav.size = Vector2(20, 160)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.mouse_filter = Control.MOUSE_FILTER_PASS

	var transparent_flat = StyleBoxFlat.new()
	transparent_flat.bg_color = Color(0, 0, 0, 0)

	var prev_btn = Button.new()
	prev_btn.name = "PrevBtn"
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(30, 30)
	prev_btn.pressed.connect(_on_catalog_prev)
	prev_btn.add_theme_font_size_override("font_size", 20)
	prev_btn.add_theme_color_override("font_color", Color.BLACK)
	prev_btn.add_theme_stylebox_override("normal", transparent_flat)
	prev_btn.add_theme_stylebox_override("hover", transparent_flat)
	nav.add_child(prev_btn)

	var sprite_icon = TextureRect.new()
	sprite_icon.name = "SpriteIcon"
	sprite_icon.custom_minimum_size = Vector2(270, 200)
	sprite_icon.size = Vector2(270, 200)
	sprite_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	nav.add_child(sprite_icon)

	var next_btn = Button.new()
	next_btn.name = "NextBtn"
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(30, 30)
	next_btn.pressed.connect(_on_catalog_next)
	next_btn.add_theme_font_size_override("font_size", 20)
	next_btn.add_theme_color_override("font_color", Color.BLACK)
	next_btn.add_theme_stylebox_override("normal", transparent_flat)
	next_btn.add_theme_stylebox_override("hover", transparent_flat)
	nav.add_child(next_btn)

	nb.add_child(nav)
	catalog_panel.add_child(nb)

func _make_red_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.1, 0.1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _show_catalog_page(page: int):
	var total = JapasDatabase.get_count()
	var max_level_data = LevelData.get_level_data(SaveManager.max_level)
	var available = max_level_data.available_japas

	var page_label = catalog_panel.get_node("NotebookContainer/PageLabel")
	var real_pic = catalog_panel.get_node("NotebookContainer/RealPic")
	var desc_label = catalog_panel.get_node("NotebookContainer/DescLabel")
	var sprite_icon = catalog_panel.get_node("NotebookContainer/Nav/SpriteIcon")
	var unlock_label = catalog_panel.get_node("NotebookContainer/UnlockLabel")
	var prev_btn = catalog_panel.get_node("NotebookContainer/Nav/PrevBtn")
	var next_btn = catalog_panel.get_node("NotebookContainer/Nav/NextBtn")

	page_label.text = "%d/%d" % [page + 1, total]

	if page < available:
		real_pic.texture = _load_real_pic(page)
		desc_label.text = JapasDatabase.get_description(page)
		desc_label.visible = true
		sprite_icon.texture = _load_tile_sprite(page)
		sprite_icon.visible = true
		unlock_label.visible = false
	else:
		real_pic.texture = preload("res://assets/lock.png")
		var unlock_level = (page - 5) * 10 if page >= 6 else 1
		desc_label.text = "?????\n(Unlocks at level %d)" % unlock_level
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.visible = true
		sprite_icon.texture = preload("res://assets/question.png")
		sprite_icon.visible = true
		unlock_label.visible = false

	catalog_current_page = page

func _load_real_pic(index: int) -> Texture2D:
	var path = JapasDatabase.get_real_pic_path(index)
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _load_tile_sprite(index: int) -> Texture2D:
	var path = JapasDatabase.get_texture_path(index)
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _on_catalog_panel_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_swipe_start_x = event.position.x
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			var dx = event.position.x - _swipe_start_x
			if dx > 50:
				_on_catalog_prev()
			elif dx < -50:
				_on_catalog_next()

func _on_catalog_next():
	if catalog_panel and catalog_current_page < JapasDatabase.get_count() - 1:
		_page_player.play(0.0)
		_show_catalog_page(catalog_current_page + 1)

func _on_catalog_prev():
	if catalog_panel and catalog_current_page > 0:
		_page_player.play(0.0)
		_show_catalog_page(catalog_current_page - 1)

func _on_level_selected(level: int):
	if SaveManager.mood_level <= 0:
		var overlay = SaveManager.show_empty_mood_popup(self)
		await overlay.tree_exited
		return

	var overlay = ColorRect.new()
	overlay.name = "ConfirmationOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var popup = Control.new()
	popup.name = "ConfirmationPopup"
	popup.anchor_left = 0.5
	popup.anchor_top = 0.5
	popup.anchor_right = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -160.0
	popup.offset_top = -100.0
	popup.offset_right = 160.0
	popup.offset_bottom = 100.0
	add_child(popup)

	var bg = Panel.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	bg.add_theme_stylebox_override("panel", style)
	popup.add_child(bg)

	var label = Label.new()
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.offset_top = 35.0
	label.offset_bottom = 75.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_font_size_override("font_size", 18)
	label.text = TranslationManager.t("play_level") % level
	popup.add_child(label)

	var lang = TranslationManager.current_language
	var cancel_path = "res://assets/icons_buttons/cancel_%s.png" % lang

	var ok_btn = Button.new()
	ok_btn.flat = true
	ok_btn.expand_icon = true
	ok_btn.position = Vector2(70, 110)
	ok_btn.size = Vector2(120, 50)
	ok_btn.icon = _ok_icon
	ok_btn.pressed.connect(_on_confirm_level.bind(level))
	ok_btn.pressed.connect(_close_confirmation_popup.bind(overlay, popup))
	popup.add_child(ok_btn)

	var cancel_btn = Button.new()
	cancel_btn.flat = true
	cancel_btn.expand_icon = true
	cancel_btn.position = Vector2(170, 110)
	cancel_btn.size = Vector2(120, 50)
	if ResourceLoader.exists(cancel_path):
		cancel_btn.icon = load(cancel_path)
	cancel_btn.pressed.connect(_close_confirmation_popup.bind(overlay, popup))
	popup.add_child(cancel_btn)

func _close_confirmation_popup(overlay: ColorRect, popup: Control):
	if is_instance_valid(popup):
		popup.queue_free()
	if is_instance_valid(overlay):
		overlay.queue_free()

func _on_confirm_level(level: int):
	SceneManager.go_to_gameplay(level)

func _build_skill_buttons():
	for child in _skill_container.get_children():
		child.queue_free()
	var btn_scene = preload("res://scenes/skills/SkillButton.tscn")
	var btn_size := 48
	var gap := 8
	var count = len(SaveManager.SKILL_CONFIG)
	var total_w = count * btn_size + (count - 1) * gap
	var start_x = (_skill_container.size.x - total_w) / 2
	if start_x < 0:
		start_x = 0
	var start_y = (_skill_container.size.y - btn_size) / 2 + 28
	var i := 0
	for key in SaveManager.SKILL_CONFIG:
		var btn: SkillButton = btn_scene.instantiate()
		btn.setup(key, -2, true)
		btn.pressed.connect(_on_skill_shop_pressed)
		_skill_container.add_child(btn)
		var x = start_x + i * (btn_size + gap)
		btn.offset_left = x
		btn.offset_top = start_y
		btn.offset_right = x + btn_size
		btn.offset_bottom = start_y + btn_size
		var icon = btn.get_node("IconBtn")
		icon.ignore_texture_size = true
		icon.offset_left = 2
		icon.offset_top = 2
		icon.offset_right = -2
		icon.offset_bottom = -2
		i += 1

func _on_skill_shop_pressed(skill_key: String):
	_show_buy_popup(skill_key)

func _show_buy_popup(skill_key: String):
	var cfg = SaveManager.SKILL_CONFIG[skill_key]
	var t = TranslationManager
	var has_coins = SaveManager.coins >= cfg["price"]
	var lang = t.current_language

	var overlay = ColorRect.new()
	overlay.name = "BuyOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var popup = Control.new()
	popup.name = "BuyPopup"
	popup.anchor_left = 0.5
	popup.anchor_top = 0.5
	popup.anchor_right = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -130.0
	popup.offset_top = -135.0
	popup.offset_right = 130.0
	popup.offset_bottom = 135.0
	add_child(popup)

	var bg = Panel.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	bg.add_theme_stylebox_override("panel", style)
	popup.add_child(bg)

	var icon = TextureRect.new()
	icon.texture = load(cfg["icon"])
	icon.anchor_left = 0.5
	icon.anchor_top = 0.0
	icon.offset_left = -30.0
	icon.offset_top = 8.0
	icon.custom_minimum_size = Vector2(60, 60)
	icon.expand_mode = 1
	icon.stretch_mode = 5
	popup.add_child(icon)

	var name_label = Label.new()
	name_label.anchor_left = 0.0
	name_label.anchor_right = 1.0
	name_label.offset_top = 74.0
	name_label.offset_bottom = 94.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.text = t.t("skill_%s" % skill_key)
	popup.add_child(name_label)

	var desc_label = Label.new()
	desc_label.anchor_left = 10.0
	desc_label.anchor_right = -10.0
	desc_label.offset_top = 98.0
	desc_label.offset_bottom = 130.0
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.text = t.t("%s_desc" % skill_key)
	popup.add_child(desc_label)

	var price_label = Label.new()
	price_label.anchor_left = 0.0
	price_label.anchor_right = 1.0
	price_label.offset_top = 135.0
	price_label.offset_bottom = 153.0
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", Color(1, 0.85, 0, 1))
	price_label.add_theme_font_size_override("font_size", 14)
	price_label.text = "%s: %d" % [t.t("coins"), cfg["price"]]
	popup.add_child(price_label)

	var insufficient_label = Label.new()
	insufficient_label.name = "InsufficientLabel"
	insufficient_label.anchor_left = 0.0
	insufficient_label.anchor_right = 1.0
	insufficient_label.offset_top = 156.0
	insufficient_label.offset_bottom = 172.0
	insufficient_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	insufficient_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	insufficient_label.add_theme_font_size_override("font_size", 12)
	insufficient_label.text = t.t("insufficient_coins")
	insufficient_label.visible = not has_coins
	popup.add_child(insufficient_label)

	var trade_btn = Button.new()
	popup.add_child(trade_btn)
	trade_btn.flat = true
	trade_btn.expand_icon = true
	trade_btn.position = Vector2(35, 198)
	trade_btn.size = Vector2(110, 44)
	var trade_path = "res://assets/icons_buttons/trade_%s.png" % lang
	if ResourceLoader.exists(trade_path):
		trade_btn.icon = load(trade_path)
	trade_btn.disabled = not has_coins
	trade_btn.pressed.connect(_on_trade_confirm.bind(skill_key, overlay, popup))

	var cancel_btn = Button.new()
	popup.add_child(cancel_btn)
	cancel_btn.flat = true
	cancel_btn.expand_icon = true
	cancel_btn.position = Vector2(150, 198)
	cancel_btn.size = Vector2(110, 44)
	var cancel_path = "res://assets/icons_buttons/cancel_%s.png" % lang
	if ResourceLoader.exists(cancel_path):
		cancel_btn.icon = load(cancel_path)
	cancel_btn.pressed.connect(_close_buy_popup.bind(overlay, popup))

func _on_trade_confirm(skill_key: String, overlay: ColorRect, popup: Control):
	var cfg = SaveManager.SKILL_CONFIG[skill_key]
	if SaveManager.spend_coins(cfg["price"]):
		SaveManager.add_skill_stock(skill_key, cfg["stock_granted"])
		SaveManager.save_game()
	_close_buy_popup(overlay, popup)

func _close_buy_popup(overlay: ColorRect, popup: Control):
	if is_instance_valid(popup):
		popup.queue_free()
	if is_instance_valid(overlay):
		overlay.queue_free()

func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and level_track_view.visible:
		if not _is_any_popup_open():
			_transition_to_main_menu()

func _is_any_popup_open() -> bool:
	return catalog_panel != null \
		or _settings_popup != null \
		or get_node_or_null("InstantOverlay") != null \
		or get_node_or_null("ConfirmationOverlay") != null \
		or get_node_or_null("BuyOverlay") != null
