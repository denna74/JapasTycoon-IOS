extends Control
class_name CustomerSlot

var required: Dictionary = {}
var collected: Dictionary = {}
var is_satisfied: bool = false

signal satisfied()

@onready var container := $VBoxContainer

func _ready():
	pass

func _draw():
	pass
var counter_rows: Array = []

static var _resized_textures: Dictionary = {}

func setup(request_data: Dictionary):
	for c in container.get_children():
		c.queue_free()
	counter_rows.clear()

	required = request_data.duplicate()
	collected = {}
	for t in required.keys():
		collected[t] = 0

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.set_corner_radius_all(6)
	var panel = Panel.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(90, 76 + required.size() * 30)
	container.add_child(panel)

	var inner = VBoxContainer.new()
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	panel.add_child(inner)

	var npc = TextureRect.new()
	npc.name = "NPCSprite"
	npc.custom_minimum_size = Vector2(52, 70)
	npc.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	npc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	npc.texture = _get_random_npc_texture()
	npc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(npc)

	for japas_type in required.keys():
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 28)
		var tex_path = JapasDatabase.get_texture_path(japas_type)
		if _resized_textures.has(japas_type):
			icon.texture = _resized_textures[japas_type]
		elif ResourceLoader.exists(tex_path):
			var src = load(tex_path)
			var img = src.get_image()
			if img:
				img.resize(40, 28, Image.INTERPOLATE_LANCZOS)
				var tex = ImageTexture.create_from_image(img)
				_resized_textures[japas_type] = tex
				icon.texture = tex

		var label = Label.new()
		label.text = "0/%d" % required[japas_type]
		label.add_theme_font_size_override("font_size", 14)
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		hbox.add_child(icon)
		hbox.add_child(label)
		inner.add_child(hbox)
		counter_rows.append({"type": japas_type, "icon": icon, "label": label})

func fulfill_request(japas_type: int) -> bool:
	if is_satisfied:
		return false
	if required.has(japas_type) and collected[japas_type] < required[japas_type]:
		collected[japas_type] += 1
		for row in counter_rows:
			if row["type"] == japas_type:
				row["label"].text = "%d/%d" % [collected[japas_type], required[japas_type]]
				break
		if collected[japas_type] == required[japas_type]:
			required.erase(japas_type)
			for row in counter_rows:
				if row["type"] == japas_type:
					row["label"].add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
					break
		if required.size() == 0:
			is_satisfied = true
			satisfied.emit()
		return true
	return false

func get_target_global_position() -> Vector2:
	return global_position + size * 0.5

static func _get_random_npc_texture() -> Texture2D:
	var idx = randi() % 28 + 1
	return load("res://assets/npcs/%d.png" % idx)
