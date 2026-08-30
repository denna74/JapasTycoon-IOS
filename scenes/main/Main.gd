extends Control

var current_level_data: LevelData
var is_playing: bool = false
var level_complete_sound: AudioStreamPlayer
var move_count: int = 0
var _current_skill_key: String = ""

@onready var header := $Header
@onready var customer_area := $CustomerArea
@onready var puzzle_grid := $PuzzleGrid
@onready var skill_bar := $SkillBar
@onready var result_popup := $ResultPopup
@onready var pause_popup := $PausePopup
@onready var continue_btn := $PausePopup/ContinueButton
@onready var exit_btn := $PausePopup/ExitButton
@onready var pause_desc := $PausePopup/PauseDesc
@onready var cancel_skill_btn := $CancelSkillBtn

var cancel_en_texture: Texture2D = preload("res://assets/icons_buttons/cancel_en.png")
var cancel_id_texture: Texture2D = preload("res://assets/icons_buttons/cancel_id.png")
var continue_en_texture: Texture2D = preload("res://assets/icons_buttons/continue_en.png")
var continue_id_texture: Texture2D = preload("res://assets/icons_buttons/continue_id.png")
var exit_en_texture: Texture2D = preload("res://assets/icons_buttons/exit_en.png")
var exit_id_texture: Texture2D = preload("res://assets/icons_buttons/exit_id.png")

func _ready():
	level_complete_sound = AudioStreamPlayer.new()
	level_complete_sound.stream = preload("res://assets/audio/confirmation_001.ogg")
	level_complete_sound.bus = &"SFX"
	add_child(level_complete_sound)

	MusicManager.bgm_changed.connect(func(): MusicManager.apply_to_player($BGMPlayer))
	MusicManager.apply_to_player($BGMPlayer)

	header.pause_toggled.connect(_on_pause_toggled)
	puzzle_grid.match_completed.connect(_on_match_completed)
	puzzle_grid.board_stuck.connect(_on_board_stuck)
	puzzle_grid.stuck_popup_shown.connect(func():
		skill_bar.set_input_blocked(true)
		header.set_exit_enabled(false)
	)
	puzzle_grid.stuck_popup_hidden.connect(func():
		skill_bar.set_input_blocked(false)
		header.set_exit_enabled(true)
	)
	puzzle_grid.move_made.connect(_on_move_made)
	skill_bar.skill_activated.connect(_on_skill_activated)
	continue_btn.pressed.connect(_on_continue_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

	pause_desc.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	TranslationManager.language_changed.connect(_update_pause_texts)
	TranslationManager.language_changed.connect(_on_cancel_language_changed)
	cancel_skill_btn.pressed.connect(_on_cancel_skill_pressed)
	cancel_skill_btn.texture_normal = cancel_en_texture if TranslationManager.current_language == "en" else cancel_id_texture
	puzzle_grid.skill_applied.connect(_on_skill_applied)

	var pause_style := StyleBoxFlat.new()
	pause_style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	pause_style.corner_radius_top_left = 12
	pause_style.corner_radius_top_right = 12
	pause_style.corner_radius_bottom_left = 12
	pause_style.corner_radius_bottom_right = 12
	pause_popup.add_theme_stylebox_override("panel", pause_style)

	start_level(SceneManager.target_level)

func _update_pause_texts():
	var t := TranslationManager
	pause_desc.text = t.t("pause_description")
	var lang = t.current_language
	continue_btn.icon = continue_en_texture if lang == "en" else continue_id_texture
	exit_btn.icon = exit_en_texture if lang == "en" else exit_id_texture

func start_level(level: int):
	current_level_data = LevelData.get_level_data(level)
	move_count = current_level_data.move_limit
	header.set_level(level)
	header.set_move_count(move_count)

	SaveManager.on_gameplay_start()
	customer_area.setup(current_level_data.customer_count, current_level_data.available_japas, current_level_data.level_number)

	var requested_types = customer_area.get_requested_types()
	puzzle_grid.setup_board(current_level_data.grid_cols, current_level_data.grid_rows, current_level_data.available_japas, requested_types)
	puzzle_grid.customer_area = customer_area
	puzzle_grid.block_input = true
	puzzle_grid.animate_initial_pour()

	if customer_area.all_customers_satisfied.is_connected(_on_level_complete):
		customer_area.all_customers_satisfied.disconnect(_on_level_complete)
	customer_area.all_customers_satisfied.connect(_on_level_complete)

	is_playing = true
	result_popup.hide()
	pause_popup.hide()
	skill_bar.set_input_blocked(false)
	header.set_exit_enabled(true)
	_update_pause_texts()

func _connect_result_popup_signals():
	if result_popup.next_level_pressed.is_connected(_on_next_level):
		result_popup.next_level_pressed.disconnect(_on_next_level)
	if result_popup.retry_pressed.is_connected(_on_retry):
		result_popup.retry_pressed.disconnect(_on_retry)
	if result_popup.exit_pressed.is_connected(_on_result_exit):
		result_popup.exit_pressed.disconnect(_on_result_exit)
	result_popup.next_level_pressed.connect(_on_next_level)
	result_popup.retry_pressed.connect(_on_retry)
	result_popup.exit_pressed.connect(_on_result_exit)

func _on_level_complete():
	if not is_playing:
		return
	SaveManager.on_gameplay_end()
	is_playing = false
	puzzle_grid.block_input = true
	skill_bar.set_input_blocked(true)
	header.set_exit_enabled(false)
	level_complete_sound.play()

	var is_new_progress = current_level_data.level_number >= SaveManager.max_level

	var used_moves = maxi(0, current_level_data.move_limit - move_count)
	var ratio = float(used_moves) / float(current_level_data.move_limit)
	var rating = 1
	if ratio <= 0.5:
		rating = 3
	elif ratio <= 0.75:
		rating = 2

	SaveManager.complete_level(current_level_data.level_number, current_level_data.money_reward, rating)

	if is_new_progress and LevelData.is_unlock_level(current_level_data.level_number):
		await _show_unlock_popup(current_level_data.level_number)

	result_popup.show_win(current_level_data.money_reward, rating)
	_connect_result_popup_signals()

func _show_unlock_popup(level: int):
	var index = LevelData.get_newly_unlocked_index(level)
	var japas_name = JapasDatabase.get_japas_name(index)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.anchor_left = 0
	overlay.anchor_top = 0
	overlay.anchor_right = 1
	overlay.anchor_bottom = 1
	overlay.offset_left = 0
	overlay.offset_top = 0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var popup = Panel.new()
	var popup_bg := StyleBoxFlat.new()
	popup_bg.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	popup_bg.set_corner_radius_all(12)
	popup.add_theme_stylebox_override("panel", popup_bg)
	popup.anchor_left = 0.5
	popup.anchor_top = 0.5
	popup.anchor_right = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -140
	popup.offset_top = -170
	popup.offset_right = 140
	popup.offset_bottom = 170
	overlay.add_child(popup)

	var popup_w = 280

	var title = Label.new()
	title.text = TranslationManager.t("unlock_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.anchor_left = 0
	title.anchor_top = 0
	title.anchor_right = 0
	title.anchor_bottom = 0
	title.offset_left = 20
	title.offset_top = 15
	title.offset_right = popup_w - 20
	title.offset_bottom = 45
	popup.add_child(title)

	var label = Label.new()
	label.text = TranslationManager.t("congratulation") + "\n" + TranslationManager.tf("unlocked_snack", [japas_name])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0
	label.anchor_top = 0
	label.anchor_right = 0
	label.anchor_bottom = 0
	label.offset_left = 20
	label.offset_top = 55
	label.offset_right = popup_w - 20
	label.offset_bottom = 95
	popup.add_child(label)

	var img_container = CenterContainer.new()
	img_container.offset_left = 0
	img_container.offset_top = 135
	img_container.offset_right = popup_w
	img_container.offset_bottom = 255
	popup.add_child(img_container)

	var tex_path = JapasDatabase.get_texture_path(index)
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		var rect = TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(120, 120)
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img_container.add_child(rect)

	var btn_w = 130
	var btn_h = 50
	var ok_btn = Button.new()
	ok_btn.icon = load("res://assets/icons_buttons/ok.png")
	ok_btn.text = ""
	ok_btn.flat = true
	ok_btn.expand_icon = true
	ok_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	ok_btn.anchor_left = 0
	ok_btn.anchor_top = 0
	ok_btn.anchor_right = 0
	ok_btn.anchor_bottom = 0
	ok_btn.offset_left = (popup_w - btn_w) / 2 + 20
	ok_btn.offset_top = 258
	ok_btn.offset_right = ok_btn.offset_left + btn_w
	ok_btn.offset_bottom = ok_btn.offset_top + btn_h
	ok_btn.pressed.connect(overlay.queue_free)
	popup.add_child(ok_btn)

	await overlay.tree_exited

func _on_match_completed(japas_type: int, count: int):
	customer_area.on_tile_matched(japas_type, count)

func _on_board_stuck():
	if not is_playing:
		return

func _on_moves_exhausted():
	if not is_playing:
		return
	is_playing = false
	puzzle_grid.block_input = true
	skill_bar.set_input_blocked(true)
	header.set_exit_enabled(false)
	SaveManager.lose_mood()
	result_popup.show_lose()
	_connect_result_popup_signals()

func _on_move_made():
	move_count -= 1
	header.set_move_count(move_count)
	if move_count <= 0:
		_on_moves_exhausted()

func _on_skill_activated(skill_key: String, skill_type: int):
	_current_skill_key = skill_key
	if skill_type == -1:
		SaveManager.use_skill(skill_key)
		move_count += 3
		header.set_move_count(move_count)

		var container = $SkillBar/ButtonContainer
		for child in container.get_children():
			if child is SkillButton and child.skill_key == skill_key:
				var player = AudioStreamPlayer.new()
				player.stream = preload("res://assets/audio/confirmation_001.ogg")
				player.bus = &"SFX"
				player.finished.connect(player.queue_free)
				add_child(player)
				player.play()

				child.pivot_offset = Vector2(child.size.x / 2, child.size.y)
				var t = create_tween().set_loops(3)
				t.tween_property(child, "scale", Vector2(1.25, 1.25), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
				t.tween_property(child, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
				break
	else:
		header.modulate = Color(0.5, 0.5, 0.5, 0.7)
		customer_area.modulate = Color(0.5, 0.5, 0.5, 0.7)
		$Background.modulate = Color(0.5, 0.5, 0.5, 0.7)
		skill_bar.modulate = Color(0.5, 0.5, 0.5, 0.7)
		cancel_skill_btn.show()
		header.set_exit_enabled(false)
		if skill_type == 0:
			var container = $SkillBar/ButtonContainer
			for child in container.get_children():
				if child is SkillButton and child.skill_key == skill_key:
					var btn_center = child.get_global_rect().position + child.get_global_rect().size / 2
					puzzle_grid.tongs_start_pos = btn_center - puzzle_grid.get_global_rect().position
					break
		if skill_type == 3:
			var container = $SkillBar/ButtonContainer
			for child in container.get_children():
				if child is SkillButton and child.skill_key == skill_key:
					var btn_center = child.get_global_rect().position + child.get_global_rect().size / 2
					puzzle_grid.bomb_start_pos = btn_center - puzzle_grid.get_global_rect().position
					break
		if skill_type == 2:
			var container = $SkillBar/ButtonContainer
			for child in container.get_children():
				if child is SkillButton and child.skill_key == skill_key:
					var btn_center = child.get_global_rect().position + child.get_global_rect().size / 2
					puzzle_grid.vacuum_start_pos = btn_center - puzzle_grid.get_global_rect().position
					break
		puzzle_grid.activate_skill_mode(skill_type)
		puzzle_grid.block_input = false

func _on_skill_applied():
	SaveManager.use_skill(_current_skill_key)
	_restore_after_skill()

func _on_cancel_skill_pressed():
	puzzle_grid.cancel_skill_mode()
	_restore_after_skill()

func _restore_after_skill():
	cancel_skill_btn.hide()
	header.set_exit_enabled(true)
	header.modulate = Color.WHITE
	customer_area.modulate = Color.WHITE
	$Background.modulate = Color.WHITE
	skill_bar.modulate = Color.WHITE

func _on_cancel_language_changed(_lang: String):
	cancel_skill_btn.texture_normal = cancel_en_texture if TranslationManager.current_language == "en" else cancel_id_texture

func _on_pause_toggled(paused: bool):
	pause_popup.visible = paused
	puzzle_grid.set_paused(paused)
	skill_bar.set_input_blocked(paused)

func _on_continue_pressed():
	_on_pause_toggled(false)

func _on_exit_pressed():
	if is_playing:
		SaveManager.lose_mood()
	SceneManager.go_to_level_track()

func _request_app_exit() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if tree.root != null:
		tree.root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	tree.quit()

func _on_next_level():
	start_level(current_level_data.level_number + 1)

func _on_retry():
	start_level(current_level_data.level_number)

func _on_result_exit():
	SceneManager.go_to_level_track()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_playing:
			SaveManager.lose_mood()
		_request_app_exit()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_playing and not pause_popup.visible and not cancel_skill_btn.visible:
			_on_pause_toggled(true)
