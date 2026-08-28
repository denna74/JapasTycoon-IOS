extends Resource
class_name JapasData

static func get_japas_name(index: int) -> String:
	return JapasDatabase.get_japas_name(index)

static func get_price(index: int) -> int:
	return JapasDatabase.get_price(index)

static func get_description(index: int) -> String:
	return JapasDatabase.get_description(index)

static func get_origin(index: int) -> String:
	return JapasDatabase.get_origin(index)

static func get_texture_path(index: int) -> String:
	return JapasDatabase.get_texture_path(index)

static func get_count() -> int:
	return JapasDatabase.get_count()
