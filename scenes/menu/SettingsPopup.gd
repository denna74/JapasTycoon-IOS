extends Control

signal saved
signal cancelled

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var language_label: Label = $Panel/Margin/VBox/LanguageRow/LanguageLabel
@onready var language_btn: Button = $Panel/Margin/VBox/LanguageRow/LanguageButton
@onready var bgm_label: Label = $Panel/Margin/VBox/BgmLabel
@onready var bgm_slider: HSlider = $Panel/Margin/VBox/BgmRow/BgmSlider
@onready var bgm_pct: Label = $Panel/Margin/VBox/BgmRow/BgmPct
@onready var sfx_label: Label = $Panel/Margin/VBox/SfxLabel
@onready var sfx_slider: HSlider = $Panel/Margin/VBox/SfxRow/SfxSlider
@onready var sfx_pct: Label = $Panel/Margin/VBox/SfxRow/SfxPct
@onready var cancel_btn: Button = $Panel/CancelButton
@onready var save_btn: Button = $Panel/SaveButton

var _snapshot_lang := "en"
var _snapshot_bgm := 4
var _snapshot_sfx := 4

var _save_en: Texture2D = preload("res://assets/icons_buttons/save_en.png")
var _save_id: Texture2D = preload("res://assets/icons_buttons/save_id.png")
var _cancel_en: Texture2D = preload("res://assets/icons_buttons/cancel_en.png")
var _cancel_id: Texture2D = preload("res://assets/icons_buttons/cancel_id.png")

func _ready():
	_snapshot_lang = TranslationManager.current_language
	_snapshot_bgm = MusicManager.bgm_level
	_snapshot_sfx = ClickPlayer.sfx_level
	bgm_slider.value = _snapshot_bgm
	sfx_slider.value = _snapshot_sfx
	_refresh_pct()
	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	language_btn.pressed.connect(_on_language_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	save_btn.pressed.connect(_on_save_pressed)
	TranslationManager.language_changed.connect(_update_texts)
	_update_texts()

func _update_texts(_lang: String = ""):
	var t := TranslationManager
	title_label.text = t.t("settings")
	language_label.text = t.t("language_label")
	bgm_label.text = t.t("background_music")
	sfx_label.text = t.t("sound_effect")
	language_btn.text = t.get_language_flag() + " " + ("ID" if t.current_language == "id" else "EN")
	var is_en := t.current_language == "en"
	cancel_btn.icon = _cancel_en if is_en else _cancel_id
	save_btn.icon = _save_en if is_en else _save_id

func _refresh_pct():
	bgm_pct.text = "%d%%" % int(bgm_slider.value * 25)
	sfx_pct.text = "%d%%" % int(sfx_slider.value * 25)

func _on_bgm_changed(value: float):
	MusicManager.set_bgm_level(int(value))
	_refresh_pct()

func _on_sfx_changed(value: float):
	ClickPlayer.set_sfx_level(int(value))
	ClickPlayer.play()
	_refresh_pct()

func _on_language_pressed():
	TranslationManager.set_language("id" if TranslationManager.current_language == "en" else "en")

func _on_cancel_pressed():
	TranslationManager.set_language(_snapshot_lang)
	MusicManager.set_bgm_level(_snapshot_bgm)
	ClickPlayer.set_sfx_level(_snapshot_sfx)
	cancelled.emit()
	queue_free()

func _on_save_pressed():
	saved.emit()
	queue_free()
