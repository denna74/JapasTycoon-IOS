class_name JapasDatabase

static var _entries := _load_entries()

static func _load_entries() -> Array:
	var file = FileAccess.open("res://resources/japas/japas_database.json", FileAccess.READ)
	var json_str = file.get_as_text()
	var json = JSON.new()
	json.parse(json_str)
	return json.data

static func get_count() -> int:
	return _entries.size()

static func get_japas(index: int) -> Dictionary:
	return _entries[index] if index >= 0 and index < _entries.size() else {}

static func get_japas_name(index: int) -> String:
	return _entries[index].get("name", "Unknown") if index >= 0 and index < _entries.size() else "Unknown"

static func get_price(index: int) -> int:
	return _entries[index].get("price", 0) if index >= 0 and index < _entries.size() else 0

static func get_description(index: int) -> String:
	if index < 0 or index >= _entries.size():
		return ""
	if TranslationManager.current_language == "en":
		return _entries[index].get("desc_en", "")
	return _entries[index].get("desc_id", "")

static func get_origin(index: int) -> String:
	return _entries[index].get("origin", "") if index >= 0 and index < _entries.size() else ""

static func get_texture_path(index: int) -> String:
	var name = _entries[index].get("name", "") if index >= 0 and index < _entries.size() else ""
	if name.is_empty():
		return ""
	var sanitized = name.to_lower().replace(" ", "_").replace("-", "_")
	return "res://assets/japas_sprites/tiles/" + sanitized + ".png"

static func get_real_pic_path(index: int) -> String:
	var name = _entries[index].get("name", "") if index >= 0 and index < _entries.size() else ""
	if name.is_empty():
		return ""
	var sanitized = name.replace(" ", "_")
	return "res://assets/japas_real_pics/" + sanitized + ".png"
