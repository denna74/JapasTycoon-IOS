extends Control

signal pause_toggled(paused)

@onready var coin_label := $VBox/Row1/CoinLabel
@onready var exit_btn := $ExitButton
@onready var level_label := $VBox/Row1/LevelLabel
@onready var mood_label := $VBox/Row2/MoodLabel
@onready var heart_0 := $VBox/Row2/Heart0
@onready var heart_1 := $VBox/Row2/Heart1
@onready var heart_2 := $VBox/Row2/Heart2
@onready var move_label := $VBox/Row2/MoveLabel

var heart_texture: Texture2D = load("res://assets/icons_buttons/heart.png")
var heart_lost_texture: Texture2D = load("res://assets/icons_buttons/heart_lost.png")
var exit_en_texture: Texture2D = preload("res://assets/icons_buttons/exit_en.png")
var exit_id_texture: Texture2D = preload("res://assets/icons_buttons/exit_id.png")

var _current_level: int = 0
var _current_move_count: int = 0

func _ready():
	exit_btn.pressed.connect(_on_pause)
	SaveManager.coins_changed.connect(_on_coins_changed)
	SaveManager.mood_changed.connect(_on_mood_changed)
	TranslationManager.language_changed.connect(_refresh_texts)
	_on_coins_changed(SaveManager.coins)
	_on_mood_changed(SaveManager.mood_level)
	_refresh_texts()

func set_level(level: int):
	_current_level = level
	level_label.text = "%s: %d" % [TranslationManager.t("level"), level]

func set_move_count(count: int):
	_current_move_count = count
	move_label.text = "%s: %d" % [TranslationManager.t("move"), count]

func _refresh_texts():
	mood_label.text = "%s:" % TranslationManager.t("mood")
	level_label.text = "%s: %d" % [TranslationManager.t("level"), _current_level]
	move_label.text = "%s: %d" % [TranslationManager.t("move"), _current_move_count]
	exit_btn.texture_normal = exit_en_texture if TranslationManager.current_language == "en" else exit_id_texture

func _on_coins_changed(new_coins: int):
	coin_label.text = ": %s" % _format_coins(new_coins)

func _on_mood_changed(new_mood: int):
	heart_0.texture = heart_texture if 0 < new_mood else heart_lost_texture
	heart_1.texture = heart_texture if 1 < new_mood else heart_lost_texture
	heart_2.texture = heart_texture if 2 < new_mood else heart_lost_texture

static func _format_coins(amount: int) -> String:
	var s = str(amount)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result = s[i] + result
		count += 1
	return result

func set_exit_enabled(enabled: bool):
	exit_btn.disabled = not enabled

func _on_pause():
	pause_toggled.emit(true)
