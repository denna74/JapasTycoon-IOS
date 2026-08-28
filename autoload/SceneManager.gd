extends Node

var target_level: int = 1
var show_level_track: bool = false
var cold_start: bool = true

func go_to_gameplay(level: int):
	target_level = level
	show_level_track = false
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func go_to_level_track():
	show_level_track = true
	get_tree().change_scene_to_file("res://scenes/menu/MenuLevelSelect.tscn")
