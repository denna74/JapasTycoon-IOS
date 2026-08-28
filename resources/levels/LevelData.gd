extends Resource
class_name LevelData

var level_number: int
var grid_cols: int
var grid_rows: int
var customer_count: int
var available_japas: int
var money_reward: int = 50
var move_limit: int

func get_grid_size() -> Vector2:
	return Vector2(grid_cols, grid_rows)

static func get_level_data(level: int) -> LevelData:
	var data := LevelData.new()
	data.level_number = level
	var japas_count = JapasDatabase.get_count()
	data.available_japas = clampi(6 + (level - 1) / 10, 6, japas_count)

	if level <= 10:
		data.grid_cols = 6
		data.grid_rows = 6
	elif level <= 50:
		data.grid_cols = 6
		data.grid_rows = 7
	elif level <= 100:
		data.grid_cols = 7
		data.grid_rows = 7
	else:
		data.grid_cols = 8
		data.grid_rows = 8

	if level <= 5:
		data.customer_count = 1
	elif level <= 35:
		data.customer_count = 2
	elif level <= 95:
		data.customer_count = 3
	elif level <= 195:
		data.customer_count = 4
	else:
		data.customer_count = 5

	data.move_limit = mini(20 + level / 2 + data.customer_count * 2, 60)
	data.money_reward = 50 + level * 10
	return data

static func is_unlock_level(level: int) -> bool:
	return level > 0 and level % 10 == 0

static func get_newly_unlocked_index(level: int) -> int:
	return 6 + level / 10 - 1
