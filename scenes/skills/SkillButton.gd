extends Control
class_name SkillButton

var skill_key: String = ""
var skill_type: int = -1
var shop_mode: bool = false
var _input_blocked: bool = false

signal skill_used(skill_key: String, skill_type: int)
signal pressed(skill_key: String)


func set_input_blocked(blocked: bool):
	_input_blocked = blocked
	_update_stock()

func setup(key: String, st: int, is_shop: bool = false):
	skill_key = key
	skill_type = st
	shop_mode = is_shop
	var cfg = SaveManager.SKILL_CONFIG[key]
	$IconBtn.texture_normal = load(cfg["icon"])
	_update_stock()

func _ready():
	$IconBtn.pressed.connect(_on_pressed)
	SaveManager.skill_stock_changed.connect(_on_stock_changed)

func _on_stock_changed(_skill: String = "", _new_stock: int = 0):
	if _skill == skill_key or _skill == "":
		_update_stock()

func _update_stock():
	var stock = SaveManager.get_skill_stock(skill_key)
	$StockLabel.text = str(stock)
	$IconBtn.disabled = (stock <= 0 and not shop_mode) or _input_blocked

func _on_pressed():
	if shop_mode:
		pressed.emit(skill_key)
	else:
		skill_used.emit(skill_key, skill_type)
