extends RefCounted
class_name PuzzleGenerator

static func generate_board(cols: int, rows: int, japas_count: int, required_types: Array = []) -> Array:
	var grid: Array = []
	for x in range(cols):
		var column: Array = []
		for y in range(rows):
			var valid_types: Array = []
			for t in range(japas_count):
				valid_types.append(t)
			if x >= 2:
				if grid[x-1][y] == grid[x-2][y]:
					valid_types.erase(grid[x-1][y])
			if y >= 2:
				if column[y-1] == column[y-2]:
					valid_types.erase(column[y-1])
			if valid_types.is_empty():
				for t in range(japas_count):
					valid_types.append(t)

			var chosen: int
			if not required_types.is_empty() and randf() < 0.65:
				var req_available: Array = []
				for t in valid_types:
					if t in required_types:
						req_available.append(t)
				if req_available.is_empty():
					chosen = valid_types[randi() % valid_types.size()]
				else:
					chosen = req_available[randi() % req_available.size()]
			else:
				chosen = valid_types[randi() % valid_types.size()]

			column.append(chosen)
		grid.append(column)

	if not required_types.is_empty():
		_ensure_required_type_minimum(grid, cols, rows, required_types, japas_count)

	var attempts := 0
	while (not has_valid_move(grid, cols, rows, japas_count) or not find_all_matches(grid, cols, rows).is_empty()) and attempts < 100:
		grid = regenerate(grid, cols, rows, japas_count)
		attempts += 1

	return grid

static func generate_board_with_pool(cols: int, rows: int, pool: Array, required_types: Array = []) -> Array:
	var grid: Array = []
	for x in range(cols):
		var column: Array = []
		for y in range(rows):
			var valid_types: Array = pool.duplicate()
			if x >= 2:
				if grid[x-1][y] == grid[x-2][y]:
					valid_types.erase(grid[x-1][y])
			if y >= 2:
				if column[y-1] == column[y-2]:
					valid_types.erase(column[y-1])
			if valid_types.is_empty():
				valid_types = pool.duplicate()

			var chosen: int
			if not required_types.is_empty() and randf() < 0.65:
				var req_available: Array = []
				for t in valid_types:
					if t in required_types:
						req_available.append(t)
				if req_available.is_empty():
					chosen = valid_types[randi() % valid_types.size()]
				else:
					chosen = req_available[randi() % req_available.size()]
			else:
				chosen = valid_types[randi() % valid_types.size()]

			column.append(chosen)
		grid.append(column)

	if not required_types.is_empty():
		_ensure_required_type_minimum(grid, cols, rows, required_types, pool.size())

	var attempts := 0
	while (not has_valid_move(grid, cols, rows, pool.size()) or not find_all_matches(grid, cols, rows).is_empty()) and attempts < 100:
		grid = regenerate_with_pool(grid, cols, rows, pool)
		attempts += 1

	return grid

static func regenerate_with_pool(grid: Array, cols: int, rows: int, pool: Array) -> Array:
	for x in range(cols):
		for y in range(rows):
			var valid_types: Array = pool.duplicate()
			if x >= 2:
				if grid[x-1][y] == grid[x-2][y]:
					valid_types.erase(grid[x-1][y])
			if y >= 2:
				if grid[x][y-1] == grid[x][y-2]:
					valid_types.erase(grid[x][y-1])
			if valid_types.is_empty():
				valid_types = pool.duplicate()
			grid[x][y] = valid_types[randi() % valid_types.size()]
	return grid

static func regenerate(grid: Array, cols: int, rows: int, japas_count: int) -> Array:
	for x in range(cols):
		for y in range(rows):
			var valid_types: Array = []
			for t in range(japas_count):
				valid_types.append(t)
			if x >= 2:
				if grid[x-1][y] == grid[x-2][y]:
					valid_types.erase(grid[x-1][y])
			if y >= 2:
				if grid[x][y-1] == grid[x][y-2]:
					valid_types.erase(grid[x][y-1])
			if valid_types.is_empty():
				for t in range(japas_count):
					valid_types.append(t)
			grid[x][y] = valid_types[randi() % valid_types.size()]
	return grid

static func _ensure_required_type_minimum(grid: Array, cols: int, rows: int, required_types: Array, japas_count: int):
	var counts := {}
	for t in required_types:
		counts[t] = 0
	for x in range(cols):
		for y in range(rows):
			if grid[x][y] in counts:
				counts[grid[x][y]] += 1

	for t in required_types:
		var need = 3 - counts[t]
		if need <= 0:
			continue
		for x in range(cols):
			for y in range(rows):
				if need <= 0:
					break
				if grid[x][y] in required_types:
					continue
				var old = grid[x][y]
				grid[x][y] = t
				var match_check = find_matches_at(grid, cols, rows, x, y)
				if not match_check.is_empty():
					grid[x][y] = old
					continue
				counts[t] += 1
				need -= 1
			if need <= 0:
				break
		if need > 0:
			for x in range(cols):
				for y in range(rows):
					if need <= 0:
						break
					if grid[x][y] in required_types:
						continue
					grid[x][y] = t
					counts[t] += 1
					need -= 1
				if need <= 0:
					break

static func has_valid_move(grid: Array, cols: int, rows: int, japas_count: int) -> bool:
	for x in range(cols):
		for y in range(rows):
			var neighbors = [
				Vector2(x+1, y),
				Vector2(x-1, y),
				Vector2(x, y+1),
				Vector2(x, y-1),
			]
			for n in neighbors:
				if n.x < 0 or n.x >= cols or n.y < 0 or n.y >= rows:
					continue
				var temp = grid[x][y]
				grid[x][y] = grid[n.x][n.y]
				grid[n.x][n.y] = temp
				var matches = find_matches_at(grid, cols, rows, x, y)
				if matches.size() > 0:
					temp = grid[x][y]
					grid[x][y] = grid[n.x][n.y]
					grid[n.x][n.y] = temp
					return true
				temp = grid[x][y]
				grid[x][y] = grid[n.x][n.y]
				grid[n.x][n.y] = temp
	return false

static func find_matches_at(grid: Array, cols: int, rows: int, x: int, y: int) -> Array:
	var matched: Array = []
	var t = grid[x][y]

	var count_h = 1
	var cx = x - 1
	while cx >= 0 and grid[cx][y] == t:
		count_h += 1
		cx -= 1
	cx = x + 1
	while cx < cols and grid[cx][y] == t:
		count_h += 1
		cx += 1
	if count_h >= 3:
		cx = x - 1
		while cx >= 0 and grid[cx][y] == t:
			matched.append(Vector2(cx, y))
			cx -= 1
		matched.append(Vector2(x, y))
		cx = x + 1
		while cx < cols and grid[cx][y] == t:
			matched.append(Vector2(cx, y))
			cx += 1

	var count_v = 1
	var cy = y - 1
	while cy >= 0 and grid[x][cy] == t:
		count_v += 1
		cy -= 1
	cy = y + 1
	while cy < rows and grid[x][cy] == t:
		count_v += 1
		cy += 1
	if count_v >= 3 and count_h < 3:
		cy = y - 1
		while cy >= 0 and grid[x][cy] == t:
			matched.append(Vector2(x, cy))
			cy -= 1
		matched.append(Vector2(x, y))
		cy = y + 1
		while cy < rows and grid[x][cy] == t:
			matched.append(Vector2(x, cy))
			cy += 1

	return matched

static func find_all_matches(grid: Array, cols: int, rows: int) -> Array:
	var all_matched: Array = []
	var checked: Array = []
	for x in range(cols):
		for y in range(rows):
			if Vector2(x, y) in checked:
				continue
			var t = grid[x][y]
			if t == -1:
				continue

			var matched: Array = [Vector2(x, y)]

			var cx = x - 1
			while cx >= 0 and grid[cx][y] == t:
				matched.append(Vector2(cx, y))
				cx -= 1
			cx = x + 1
			while cx < cols and grid[cx][y] == t:
				matched.append(Vector2(cx, y))
				cx += 1

			if matched.size() >= 3:
				for m in matched:
					if not m in checked:
						checked.append(m)
						all_matched.append(m)

			matched = [Vector2(x, y)]
			var cy = y - 1
			while cy >= 0 and grid[x][cy] == t:
				matched.append(Vector2(x, cy))
				cy -= 1
			cy = y + 1
			while cy < rows and grid[x][cy] == t:
				matched.append(Vector2(x, cy))
				cy += 1

			if matched.size() >= 3:
				for m in matched:
					if not m in checked:
						checked.append(m)
						all_matched.append(m)

	return all_matched
