extends TextureRect
class_name PuzzleTile

signal tile_pressed(tile)
signal tile_dragged_to(tile, direction: Vector2)

var japas_type: int = -1
var grid_pos: Vector2
var is_pressed: bool = false
var drag_start: Vector2


func setup(type: int, pos: Vector2, tile_size: float, gap: float = 4.0):
	japas_type = type
	grid_pos = pos
	custom_minimum_size = Vector2(tile_size, tile_size)
	size = Vector2(tile_size, tile_size)
	var tex_path = JapasDatabase.get_texture_path(type)
	if ResourceLoader.exists(tex_path):
		var src = load(tex_path)
		var img = src.get_image()
		img = _trim_transparent(img)
		var src_size = img.get_size()
		var scale = min(float(tile_size) / src_size.x, float(tile_size) / src_size.y)
		var new_w = int(src_size.x * scale)
		var new_h = int(src_size.y * scale)
		img.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
		var canvas = Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0, 0, 0, 0))
		canvas.blit_rect(img, Rect2i(0, 0, new_w, new_h), Vector2i((tile_size - new_w) / 2, (tile_size - new_h) / 2))
		texture = ImageTexture.create_from_image(canvas)
		stretch_mode = TextureRect.STRETCH_KEEP


func _trim_transparent(img: Image) -> Image:
	var size = img.get_size()
	var min_x = int(size.x)
	var min_y = int(size.y)
	var max_x = 0
	var max_y = 0
	var found = false
	var data = img.get_data()
	var w = int(size.x)
	var stride = 4

	for y in range(size.y):
		var row = int(y) * w * stride
		for x in range(size.x):
			if data[row + int(x) * stride + 3] > 8:
				if x < min_x: min_x = x
				if y < min_y: min_y = y
				if x > max_x: max_x = x
				if y > max_y: max_y = y
				found = true

	if not found:
		return img

	var rect = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	var cropped = Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(img, rect, Vector2i.ZERO)
	return cropped


func _input(event: InputEvent):
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var grid = get_parent()
	if "block_input" in grid and grid.block_input:
		return
	if "paused" in grid and grid.paused:
		return

	if mb.pressed:
		var rect = get_global_rect()
		if rect.has_point(mb.position):
			drag_start = mb.position
			is_pressed = true
			emit_signal("tile_pressed", self)
			accept_event()
	elif is_pressed:
		is_pressed = false
		var delta = mb.position - drag_start
		if delta.length() > 20.0:
			var dir = Vector2()
			if abs(delta.x) > abs(delta.y):
				dir.x = 1 if delta.x > 0 else -1
			else:
				dir.y = 1 if delta.y > 0 else -1
			emit_signal("tile_dragged_to", self, dir)
		else:
			emit_signal("tile_pressed", self)
		accept_event()



