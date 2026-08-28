extends Control

@onready var _splash_image := $SplashImage

func _ready():
	_splash_image.modulate = Color(1, 1, 1, 0)

	var tween = create_tween()
	tween.tween_property(_splash_image, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.0)
	tween.tween_property(_splash_image, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_finish)

func _finish():
	SceneManager.cold_start = false
	get_tree().change_scene_to_file("res://scenes/menu/MenuLevelSelect.tscn")
