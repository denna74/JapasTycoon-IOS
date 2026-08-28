extends Control

signal skill_activated(skill_key: String, skill_type: int)

const SKILL_MAP := {
	"skill_1": 0,
	"skill_2": 1,
	"skill_3": -1,
	"skill_4": 2,
	"skill_5": 3,
}
const BTN_SIZE := 62
const GAP := 8
const BTN_PAD := 3

@onready var btn_scene := preload("res://scenes/skills/SkillButton.tscn")
@onready var container := $ButtonContainer

func _ready():
	for key in SaveManager.SKILL_CONFIG:
		var btn: SkillButton = btn_scene.instantiate()
		btn.setup(key, SKILL_MAP[key])
		btn.skill_used.connect(_on_skill_used)
		container.add_child(btn)
		var icon = btn.get_node("IconBtn")
		icon.offset_left = BTN_PAD
		icon.offset_top = BTN_PAD
		icon.offset_right = -BTN_PAD
		icon.offset_bottom = -BTN_PAD
	_position_buttons()
	resized.connect(_position_buttons)

func _position_buttons():
	var count = container.get_child_count()
	if count == 0:
		return
	var total_w = count * BTN_SIZE + (count - 1) * GAP
	var start_x = max(0, (size.x - total_w) / 2)
	var start_y = max(0, (size.y - BTN_SIZE) / 2)
	for i in range(count):
		var btn = container.get_child(i)
		var x = start_x + i * (BTN_SIZE + GAP)
		btn.offset_left = x
		btn.offset_top = start_y
		btn.offset_right = x + BTN_SIZE
		btn.offset_bottom = start_y + BTN_SIZE

func set_input_blocked(blocked: bool):
	for child in container.get_children():
		if child is SkillButton:
			child.set_input_blocked(blocked)

func _on_skill_used(skill_key: String, skill_type: int):
	skill_activated.emit(skill_key, skill_type)
