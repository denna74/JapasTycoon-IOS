extends Panel

signal retry_pressed()
signal next_level_pressed()
signal exit_pressed()

@onready var title_label := $TitleLabel
@onready var info_label := $InfoLabel
@onready var retry_btn := $RetryButton
@onready var next_btn := $NextButton
@onready var exit_btn := $ExitButton

var star_texture: Texture2D

var _retry_en: Texture2D = preload("res://assets/icons_buttons/retry_en.png")
var _retry_id: Texture2D = preload("res://assets/icons_buttons/retry_id.png")
var _next_level_en: Texture2D = preload("res://assets/icons_buttons/next_level_en.png")
var _next_level_id: Texture2D = preload("res://assets/icons_buttons/next_level_id.png")
var _exit_en: Texture2D = preload("res://assets/icons_buttons/exit_en.png")
var _exit_id: Texture2D = preload("res://assets/icons_buttons/exit_id.png")

func show_win(reward: int, rating: int = 1):
	title_label.text = TranslationManager.t("level_complete")
	info_label.text = TranslationManager.tf("reward", [reward])
	next_btn.show()
	retry_btn.show()
	exit_btn.show()
	retry_btn.offset_left = 35
	retry_btn.offset_right = 150
	_show_stars(rating)
	show()

func _show_stars(rating: int):
	var container = $StarContainer
	for c in container.get_children():
		c.queue_free()
	for i in range(rating):
		var star = TextureRect.new()
		star.texture = star_texture
		star.custom_minimum_size = Vector2(32, 32)
		star.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(star)

func show_lose():
	title_label.text = TranslationManager.t("level_failed")
	info_label.text = TranslationManager.t("mood_lost")
	next_btn.hide()
	retry_btn.show()
	exit_btn.show()
	retry_btn.offset_left = 105
	retry_btn.offset_right = 230
	show()

func _ready():
	star_texture = preload("res://assets/text_icon/star.png")
	TranslationManager.language_changed.connect(_update_texts)
	retry_btn.pressed.connect(func(): retry_pressed.emit())
	next_btn.pressed.connect(func(): next_level_pressed.emit())
	exit_btn.pressed.connect(func(): exit_pressed.emit())
	hide()
	_update_texts()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", style)

func _update_texts():
	var t = TranslationManager
	if t.current_language == "en":
		retry_btn.icon = _retry_en
		next_btn.icon = _next_level_en
		exit_btn.icon = _exit_en
	else:
		retry_btn.icon = _retry_id
		next_btn.icon = _next_level_id
		exit_btn.icon = _exit_id
