extends Control

var grid: Array = []
var tile_nodes: Array = []
var cols: int
var rows: int
var japas_count: int
var is_animating: bool = false
var skill_mode: int = -1
var block_swap_on_release: bool = false
var paused: bool = false
var block_input: bool = false
var required_types: Array = []
var board_pool: Array = []
var customer_area: Control = null
var bomb_start_pos: Vector2 = Vector2.ZERO
var vacuum_start_pos: Vector2 = Vector2.ZERO
var tongs_start_pos: Vector2 = Vector2.ZERO
var _match_chain_active: bool = false

const GRID_AREA_SIZE := 480.0
const TILE_GAP := 6.0

var tile_size: float = 64.0
var grid_offset: Vector2


signal match_completed(japas_type: int, count: int)
signal board_stuck()
signal move_made()
signal skill_applied()
signal stuck_popup_shown()
signal stuck_popup_hidden()

@onready var tile_scene := preload("res://scenes/puzzle/PuzzleTile.tscn")
var reshuffle_en: Texture2D = preload("res://assets/icons_buttons/reshuffle_en.png")
var reshuffle_id: Texture2D = preload("res://assets/icons_buttons/reshuffle_id.png")
@onready var sfx_players := $SFXPlayers

func _ready():
	_setup_sfx()
	resized.connect(_on_resized)


func _on_resized():
	if tile_nodes.size() > 0:
		center_grid()


func _setup_sfx():
	var sounds = {
		"Click": preload("res://assets/audio/click_001.ogg"),
		"Switch": preload("res://assets/audio/switch_004.ogg"),
		"Error": preload("res://assets/audio/error_001.ogg"),
		"Match": preload("res://assets/audio/confirmation_003.ogg"),
		"BigMatch": preload("res://assets/audio/maximize_003.ogg"),
		"Explode": preload("res://assets/audio/maximize_003.ogg"),
		"Take": preload("res://assets/audio/select_001.ogg"),
		"Drop": preload("res://assets/audio/drop_001.ogg"),
	}
	for name in sounds:
		var player = AudioStreamPlayer.new()
		player.stream = sounds[name]
		player.name = name + "Sound"
		player.bus = &"SFX"
		sfx_players.add_child(player)


func _play_sfx(sound_name: String):
	var node = sfx_players.get_node(sound_name + "Sound") as AudioStreamPlayer
	if node:
		if node.playing:
			node.stop()
		node.play()

func setup_board(p_cols: int, p_rows: int, p_japas_count: int, p_required_types: Array = []):
	cols = p_cols
	rows = p_rows
	japas_count = p_japas_count
	required_types = p_required_types
	paused = false
	skill_mode = -1
	tile_size = floor((GRID_AREA_SIZE - (cols - 1) * TILE_GAP) / cols)

	board_pool = _build_board_pool(p_japas_count, p_required_types)
	grid = PuzzleGenerator.generate_board_with_pool(cols, rows, board_pool, required_types)
	build_tiles()
	center_grid()

func _build_board_pool(japas_total: int, req_types: Array) -> Array:
	var pool = req_types.duplicate()
	var pool_size = maxi(pool.size() + 2, 6)
	pool_size = mini(pool_size, maxi(pool.size(), 14))
	pool_size = mini(pool_size, japas_total)
	var candidates: Array = []
	for i in range(japas_total):
		if not i in pool:
			candidates.append(i)
	candidates.shuffle()
	while pool.size() < pool_size and candidates.size() > 0:
		pool.append(candidates.pop_front())
	return pool

func build_tiles():
	for child in get_children():
		if child is PuzzleTile:
			child.queue_free()
	tile_nodes.clear()

	for x in range(cols):
		var column: Array = []
		for y in range(rows):
			var tile: PuzzleTile = tile_scene.instantiate()
			tile.tile_pressed.connect(_on_tile_pressed)
			tile.tile_dragged_to.connect(_on_tile_dragged_to)
			add_child(tile)
			tile.setup(grid[x][y], Vector2(x, y), tile_size, TILE_GAP)
			column.append(tile)
		tile_nodes.append(column)

func center_grid():
	var total_w = cols * tile_size + (cols - 1) * TILE_GAP
	var total_h = rows * tile_size + (rows - 1) * TILE_GAP
	grid_offset = Vector2(
		(GRID_AREA_SIZE - total_w) / 2,
		max(0, (size.y - total_h) / 2) + 20
	)
	for x in range(cols):
		for y in range(rows):
			var tile = tile_nodes[x][y]
			if tile:
				tile.position = _get_tile_position(Vector2(x, y))

func _on_tile_pressed(tile: PuzzleTile):
	if is_animating or paused or block_input:
		return

	block_swap_on_release = false
	if skill_mode >= 0:
		block_swap_on_release = true
		match skill_mode:
			0:
				remove_tile_at(tile.grid_pos.x, tile.grid_pos.y)
				skill_mode = -1
			1:
				remove_row(tile.grid_pos.y)
				skill_mode = -1
			2:
				remove_type(grid[tile.grid_pos.x][tile.grid_pos.y])
				skill_mode = -1
			3:
				explode_tile_at(tile.grid_pos.x, tile.grid_pos.y)
				skill_mode = -1
		return

	_play_sfx("Click")

func _on_tile_dragged_to(tile: PuzzleTile, direction: Vector2):
	if is_animating or paused or block_input or block_swap_on_release:
		block_swap_on_release = false
		return

	var target_pos = tile.grid_pos + direction
	if target_pos.x < 0 or target_pos.x >= cols or target_pos.y < 0 or target_pos.y >= rows:
		return
	var target = tile_nodes[target_pos.x][target_pos.y]
	if not target:
		return

	try_swap(tile, target)

func _get_tile_position(grid_pos: Vector2) -> Vector2:
	return Vector2(
		grid_pos.x * (tile_size + TILE_GAP) + grid_offset.x,
		grid_pos.y * (tile_size + TILE_GAP) + grid_offset.y
	)

func try_swap(tile_a: PuzzleTile, tile_b: PuzzleTile):
	is_animating = true
	var pos_a = tile_a.grid_pos
	var pos_b = tile_b.grid_pos

	grid[pos_a.x][pos_a.y] = tile_b.japas_type
	grid[pos_b.x][pos_b.y] = tile_a.japas_type

	var matches = PuzzleGenerator.find_all_matches(grid, cols, rows)

	if matches.is_empty():
		grid[pos_a.x][pos_a.y] = tile_a.japas_type
		grid[pos_b.x][pos_b.y] = tile_b.japas_type
		_animate_tile_swap(tile_a, tile_b)
		_play_sfx("Error")
		await get_tree().create_timer(0.12).timeout
		_animate_tile_swap_back(tile_a, tile_b, pos_a, pos_b)
		await get_tree().create_timer(0.12).timeout
		is_animating = false
		check_stuck()
		return

	_animate_tile_swap(tile_a, tile_b)
	_play_sfx("Switch")
	await get_tree().create_timer(0.12).timeout

	tile_a.grid_pos = pos_b
	tile_b.grid_pos = pos_a
	tile_nodes[pos_a.x][pos_a.y] = tile_b
	tile_nodes[pos_b.x][pos_b.y] = tile_a

	_match_chain_active = true
	process_matches()

func _animate_tile_swap(tile_a: PuzzleTile, tile_b: PuzzleTile):
	var target_a = _get_tile_position(tile_b.grid_pos)
	var target_b = _get_tile_position(tile_a.grid_pos)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(tile_a, "position", target_a, 0.12).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(tile_b, "position", target_b, 0.12).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _animate_tile_swap_back(tile_a: PuzzleTile, tile_b: PuzzleTile, pos_a: Vector2, pos_b: Vector2):
	var target_a = _get_tile_position(pos_a)
	var target_b = _get_tile_position(pos_b)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(tile_a, "position", target_a, 0.12).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(tile_b, "position", target_b, 0.12).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func process_matches():
	var matches = PuzzleGenerator.find_all_matches(grid, cols, rows)
	if matches.size() == 0:
		is_animating = false
		check_stuck()
		if _match_chain_active:
			_match_chain_active = false
			move_made.emit()
		return

	var match_groups: Dictionary = {}
	var animated_tiles: Array[PuzzleTile] = []

	for m_pos in matches:
		var mx = int(m_pos.x)
		var my = int(m_pos.y)
		var t = grid[mx][my]
		if not match_groups.has(t):
			match_groups[t] = 0
		match_groups[t] += 1

		var tile = tile_nodes[mx][my]
		animated_tiles.append(tile)
		tile_nodes[mx][my] = null
		grid[mx][my] = -1

	var type_targets: Dictionary = {}
	if customer_area and customer_area.has_method("get_target_for_type"):
		for japas_type in match_groups.keys():
			var slot_global = customer_area.get_target_for_type(japas_type)
			if slot_global != Vector2.ZERO:
				type_targets[japas_type] = slot_global - global_position
			else:
				type_targets[japas_type] = Vector2.ZERO
	else:
		for japas_type in match_groups.keys():
			type_targets[japas_type] = Vector2.ZERO

	var has_big_match = false
	for count in match_groups.values():
		if count >= 5:
			has_big_match = true
			break
	_play_sfx("BigMatch" if has_big_match else "Match")

	var max_stagger = animated_tiles.size() * 0.03
	for i in animated_tiles.size():
		var tile = animated_tiles[i]
		var target = type_targets.get(tile.japas_type, Vector2.ZERO)
		_animate_match_tile(tile, target, i * 0.03)

	await get_tree().create_timer(max_stagger + 0.75).timeout

	for tile in animated_tiles:
		if is_instance_valid(tile):
			tile.queue_free()

	for japas_type in match_groups.keys():
		match_completed.emit(japas_type, match_groups[japas_type])

	cascade_up()
	await get_tree().create_timer(0.35).timeout
	process_matches()


func _animate_match_tile(tile: PuzzleTile, target_local: Vector2, stagger: float):
	var tween = create_tween()

	tween.tween_property(tile, "scale", Vector2(1.3, 1.3), 0.08).set_delay(stagger).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tile, "scale", Vector2(0.85, 0.85), 0.08).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tile, "scale", Vector2(1.15, 1.15), 0.07).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tile, "scale", Vector2(1.0, 1.0), 0.07).set_ease(Tween.EASE_IN_OUT)

	tween.set_parallel(true)
	if target_local != Vector2.ZERO:
		target_local += Vector2(randf_range(-20, 20), randf_range(-30, 0))
		tween.tween_property(tile, "position", target_local, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(tile, "scale", Vector2.ZERO, 0.2).set_delay(0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)

func cascade_up():
	_play_sfx("Drop")
	for x in range(cols):
		var column_tiles: Array = []
		for y in range(rows):
			if grid[x][y] != -1 and is_instance_valid(tile_nodes[x][y]):
				column_tiles.append({"type": grid[x][y], "node": tile_nodes[x][y]})
				tile_nodes[x][y] = null

		var spawn_y = 0
		for entry in column_tiles:
			grid[x][spawn_y] = entry["type"]
			var tile = entry["node"]
			tile.grid_pos = Vector2(x, spawn_y)
			tile_nodes[x][spawn_y] = tile
			var target_pos = _get_tile_position(Vector2(x, spawn_y))
			var tween = create_tween()
			tween.tween_property(tile, "position", target_pos, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
			spawn_y += 1

		for y in range(spawn_y, rows):
			if is_instance_valid(tile_nodes[x][y]):
				tile_nodes[x][y].queue_free()
				tile_nodes[x][y] = null

			var new_type = board_pool[randi() % board_pool.size()]
			grid[x][y] = new_type
			var tile: PuzzleTile = tile_scene.instantiate()
			tile.tile_pressed.connect(_on_tile_pressed)
			tile.tile_dragged_to.connect(_on_tile_dragged_to)
			add_child(tile)
			tile.setup(new_type, Vector2(x, y), tile_size, TILE_GAP)
			tile.position = _get_tile_position(Vector2(x, -1))
			tile_nodes[x][y] = tile
			var tween = create_tween()
			tween.tween_property(tile, "position", _get_tile_position(Vector2(x, y)), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)

func check_stuck():
	if block_input:
		return
	if not PuzzleGenerator.has_valid_move(grid, cols, rows, board_pool.size()):
		board_stuck.emit()
		block_input = true
		_show_stuck_popup()

func _show_stuck_popup():
	var popup = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	popup.add_theme_stylebox_override("panel", style)
	popup.name = "StuckPopup"
	var screen_center = get_viewport_rect().size / 2
	popup.position = screen_center - global_position - Vector2(130, 85)
	popup.size = Vector2(260, 170)
	add_child(popup)

	var label = Label.new()
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.offset_top = 25.0
	label.offset_bottom = 80.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = TranslationManager.t("board_stuck")
	popup.add_child(label)

	var lang = TranslationManager.current_language
	var btn = Button.new()
	btn.flat = true
	btn.expand_icon = true
	btn.position = Vector2(75, 100)
	btn.size = Vector2(160, 54)
	btn.icon = reshuffle_en if lang == "en" else reshuffle_id
	btn.pressed.connect(_close_stuck_popup.bind(popup))
	btn.pressed.connect(_on_popup_ok.bind(popup))
	popup.add_child(btn)

	stuck_popup_shown.emit()

func _close_stuck_popup(popup: Control):
	if is_instance_valid(popup):
		popup.queue_free()

func _animate_tiles_pour_out() -> Tween:
	var tween = create_tween().set_parallel()
	for x in range(cols):
		var col_delay = x * 0.02
		for y in range(rows):
			var tile = tile_nodes[x][y]
			if tile:
				tween.tween_property(tile, "position",
					Vector2(tile.position.x, size.y + 60), 0.2
				).set_delay(col_delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	return tween

func _animate_tiles_pour() -> Tween:
	var tween = create_tween().set_parallel()
	for x in range(cols):
		for y in range(rows):
			var tile = tile_nodes[x][y]
			if tile:
				tile.position = _get_tile_position(Vector2(x, -1))
				var target = _get_tile_position(Vector2(x, y))
				var delay = x * 0.02 + y * 0.02
				tween.tween_property(tile, "position", target, 0.25
				).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	return tween

func animate_initial_pour():
	block_input = true
	var pour = _animate_tiles_pour()
	await pour.finished
	block_input = false

func _on_popup_ok(popup: Control):
	if is_instance_valid(popup):
		remove_child(popup)
		popup.queue_free()
	is_animating = true

	var new_grid = PuzzleGenerator.generate_board_with_pool(cols, rows, board_pool)
	var pour_out = _animate_tiles_pour_out()
	await pour_out.finished

	for x in range(cols):
		for y in range(rows):
			if is_instance_valid(tile_nodes[x][y]):
				tile_nodes[x][y].queue_free()
	tile_nodes.clear()
	grid.clear()

	grid = new_grid
	build_tiles()
	center_grid()

	var pour = _animate_tiles_pour()
	await pour.finished

	is_animating = false
	block_input = false
	stuck_popup_hidden.emit()

func remove_type(japas_type: int):
	is_animating = true
	_play_sfx("Take")
	var animated_tiles: Array[PuzzleTile] = []
	var tile_positions: Array[Vector2] = []
	for x in range(cols):
		for y in range(rows):
			if grid[x][y] == japas_type:
				grid[x][y] = -1
				if is_instance_valid(tile_nodes[x][y]):
					var tile = tile_nodes[x][y]
					animated_tiles.append(tile)
					tile_positions.append(tile.position)
					tile_nodes[x][y] = null

	if animated_tiles.is_empty():
		is_animating = false
		skill_applied.emit()
		return

	var vacuum = TextureRect.new()
	vacuum.texture = preload("res://assets/skills/vacuum.png")
	vacuum.ignore_texture_size = true
	vacuum.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var vacuum_size = tile_size * 1.3
	vacuum.size = Vector2(vacuum_size, vacuum_size)
	var vacuum_center := Vector2(vacuum_start_pos.x, vacuum_start_pos.y - vacuum_size)
	vacuum.position = vacuum_center - Vector2(vacuum_size, vacuum_size) * 0.5
	add_child(vacuum)

	for tile in animated_tiles:
		tile.pivot_offset = Vector2(tile_size, tile_size) * 0.5
		var spin = create_tween().set_parallel()
		spin.tween_property(tile, "rotation", deg_to_rad(720), 0.5).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.5).timeout

	for tile in animated_tiles:
		var fly = create_tween()
		fly.tween_property(tile, "position", vacuum_center, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
		fly.tween_property(tile, "scale", Vector2.ZERO, 0.2)
		fly.tween_property(tile, "modulate", Color(1, 1, 1, 0), 0.15)

	await get_tree().create_timer(0.9).timeout
	vacuum.queue_free()
	for tile in animated_tiles:
		if is_instance_valid(tile):
			tile.queue_free()
	match_completed.emit(japas_type, animated_tiles.size())
	cascade_up()
	await get_tree().create_timer(0.35).timeout
	process_matches()
	skill_applied.emit()

func remove_row(row_y: int):
	is_animating = true
	_play_sfx("Take")
	var type_groups: Dictionary = {}
	var animated_tiles: Array[PuzzleTile] = []
	for x in range(cols):
		var t = grid[x][row_y]
		if t != -1:
			if not type_groups.has(t):
				type_groups[t] = 0
			type_groups[t] += 1
			grid[x][row_y] = -1
			if is_instance_valid(tile_nodes[x][row_y]):
				animated_tiles.append(tile_nodes[x][row_y])
				tile_nodes[x][row_y] = null
	var scoop = TextureRect.new()
	scoop.texture = preload("res://assets/skills/scoop.png")
	scoop.ignore_texture_size = true
	scoop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var scoop_size = tile_size * 1.8
	scoop.size = Vector2(scoop_size, scoop_size)
	add_child(scoop)

	var first_pos = _get_tile_position(Vector2(0, row_y))
	var last_pos = _get_tile_position(Vector2(cols - 1, row_y))
	var start_x = first_pos.x - (scoop_size - tile_size) * 0.5
	var end_x = last_pos.x + tile_size

	scoop.position = Vector2(start_x, first_pos.y - (scoop_size - tile_size) * 0.5)

	for i in animated_tiles.size():
		var tile = animated_tiles[i]
		var stagger = i * 0.06
		var tween = create_tween().set_parallel()
		tween.tween_property(tile, "position", tile.position + Vector2(0, -120), 0.5).set_delay(stagger).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(tile, "scale", Vector2(1.3, 1.3), 0.2).set_delay(stagger).set_ease(Tween.EASE_OUT)
		tween.tween_property(tile, "scale", Vector2.ZERO, 0.3).set_delay(stagger + 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
		tween.tween_property(tile, "modulate", Color(1, 1, 1, 0), 0.35).set_delay(stagger + 0.15)

	var max_stagger = animated_tiles.size() * 0.06
	var scoop_tween = create_tween()
	scoop_tween.tween_property(scoop, "position:x", end_x, max_stagger + 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(max_stagger + 0.55).timeout
	scoop.queue_free()
	for tile in animated_tiles:
		if is_instance_valid(tile):
			tile.queue_free()
	for japas_type in type_groups:
		match_completed.emit(japas_type, type_groups[japas_type])
	cascade_up()
	await get_tree().create_timer(0.35).timeout
	process_matches()
	skill_applied.emit()

func explode_tile_at(x: int, y: int):
	is_animating = true
	var type_groups: Dictionary = {}
	var animated_tiles: Array[PuzzleTile] = []
	var center_pos = _get_tile_position(Vector2(x, y)) + Vector2(tile_size / 2, tile_size / 2)

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < cols and ny >= 0 and ny < rows and grid[nx][ny] != -1:
				var t = grid[nx][ny]
				if not type_groups.has(t):
					type_groups[t] = 0
				type_groups[t] += 1
				grid[nx][ny] = -1
				if is_instance_valid(tile_nodes[nx][ny]):
					animated_tiles.append(tile_nodes[nx][ny])
					tile_nodes[nx][ny] = null

	var bomb = TextureRect.new()
	bomb.texture = preload("res://assets/skills/bomb.png")
	bomb.ignore_texture_size = true
	bomb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bomb.custom_minimum_size = Vector2(tile_size, tile_size)
	bomb.size = Vector2(tile_size, tile_size)
	add_child(bomb)

	var target_pos = _get_tile_position(Vector2(x, y))
	bomb.position = bomb_start_pos - Vector2(tile_size / 2, tile_size / 2)

	var bomb_tween = create_tween()
	bomb_tween.tween_property(bomb, "position", target_pos, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	await bomb_tween.finished
	bomb.queue_free()

	_play_sfx("Explode")
	for tile in animated_tiles:
		var tile_center = tile.position + Vector2(tile_size / 2, tile_size / 2)
		var dir = (tile_center - center_pos).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2(0, -1)
		var target = tile.position + dir * randf_range(80, 150)
		var tween = create_tween().set_parallel()
		tween.tween_property(tile, "position", target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
		tween.tween_property(tile, "scale", Vector2(1.8, 1.8), 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(tile, "scale", Vector2.ZERO, 0.25).set_delay(0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
		tween.tween_property(tile, "modulate", Color(1, 1, 1, 0), 0.3).set_delay(0.1)

	await get_tree().create_timer(0.45).timeout

	for tile in animated_tiles:
		if is_instance_valid(tile):
			tile.queue_free()

	for japas_type in type_groups:
		match_completed.emit(japas_type, type_groups[japas_type])
	cascade_up()
	await get_tree().create_timer(0.35).timeout
	process_matches()
	skill_applied.emit()

func remove_tile_at(x: int, y: int):
	is_animating = true
	_play_sfx("Take")
	if x >= 0 and x < cols and y >= 0 and y < rows and grid[x][y] != -1:
		var t = grid[x][y]
		grid[x][y] = -1
		if is_instance_valid(tile_nodes[x][y]):
			var tile = tile_nodes[x][y]
			tile_nodes[x][y] = null

			var tongs = TextureRect.new()
			tongs.texture = preload("res://assets/skills/tongs.png")
			tongs.ignore_texture_size = true
			tongs.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var tongs_size = tile_size * 0.9
			tongs.size = Vector2(tongs_size, tongs_size)
			tongs.position = tongs_start_pos - Vector2(tongs_size, tongs_size) * 0.5
			add_child(tongs)

			var tile_center = tile.position + Vector2(tile_size, tile_size) * 0.5
			var tongs_target = Vector2(tile_center.x - tongs_size * 0.5, tile.position.y - tongs_size)
			var fly_tween = create_tween()
			fly_tween.tween_property(tongs, "position", tongs_target, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
			await fly_tween.finished

			var jump_offset = Vector2(randf_range(-20, 20), -120)
			var tween = create_tween().set_parallel()
			tween.tween_property(tile, "position", tile.position + jump_offset, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tween.tween_property(tile, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT)
			tween.tween_property(tile, "scale", Vector2.ZERO, 0.3).set_delay(0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
			tween.tween_property(tile, "modulate", Color(1, 1, 1, 0), 0.35).set_delay(0.15)
			tween.tween_property(tongs, "position", tongs.position + jump_offset, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tween.tween_property(tongs, "modulate", Color(1, 1, 1, 0), 0.35).set_delay(0.15)
			tween.tween_property(tongs, "scale", Vector2.ZERO, 0.3).set_delay(0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
			await tween.finished
			if is_instance_valid(tile):
				tile.queue_free()
			if is_instance_valid(tongs):
				tongs.queue_free()
		match_completed.emit(t, 1)
	cascade_up()
	await get_tree().create_timer(0.35).timeout
	process_matches()
	skill_applied.emit()

func set_paused(p: bool):
	paused = p
	if p:
		for x in range(cols):
			for y in range(rows):
				if tile_nodes.size() > x and tile_nodes[x].size() > y and is_instance_valid(tile_nodes[x][y]):
					tile_nodes[x][y].is_pressed = false

func activate_skill_mode(st: int):
	skill_mode = st

func cancel_skill_mode():
	skill_mode = -1
