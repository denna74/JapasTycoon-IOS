extends Node

const SAVE_FILE := "user://japas_tycoon.save"
const SAVE_PASSPHRASE := "J4p@sTyco0n_S3cur3S4v3_2026"
const BLOCK_SIZE := 16
const DEFAULT_SKILLS := { "skill_1": 0, "skill_2": 0, "skill_3": 0, "skill_4": 0, "skill_5": 0 }

const SKILL_CONFIG := {
	"skill_1": {"icon": "res://assets/skills/skill_1.png", "price": 30000, "stock_granted": 3},
	"skill_2": {"icon": "res://assets/skills/skill_2.png", "price": 45000, "stock_granted": 3},
	"skill_3": {"icon": "res://assets/skills/skill_3.png", "price": 60000, "stock_granted": 3},
	"skill_4": {"icon": "res://assets/skills/skill_4.png", "price": 80000, "stock_granted": 3},
	"skill_5": {"icon": "res://assets/skills/skill_5.png", "price": 99000, "stock_granted": 3},
}

var coins: int = 50000
var max_level: int = 1
var mood_level: int = 3
var last_failure_time: int = 0
var accumulated_gameplay_sec: float = 0.0
var pending_quit_penalty: bool = false
var skills: Dictionary = {}
var ratings: Dictionary = {}
var processed_purchases: Dictionary = {}

signal coins_changed(new_coins: int)
signal mood_changed(new_mood: int)
signal skill_stock_changed(skill: String, new_stock: int)

func _ready():
	load_game()
	apply_pending_quit_penalty_if_any()

func reset_to_defaults():
	coins = 50000
	max_level = 1
	mood_level = 3
	last_failure_time = 0
	accumulated_gameplay_sec = 0.0
	skills = DEFAULT_SKILLS.duplicate()
	ratings = {}

func add_coins(amount: int):
	coins += amount
	coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		coins_changed.emit(coins)
		return true
	return false

func calculate_recovered_mood() -> int:
	if last_failure_time == 0:
		return 0
	var now = Time.get_unix_time_from_system()
	var elapsed = now - last_failure_time - accumulated_gameplay_sec
	return max(0, int(elapsed / 3600))

func apply_mood_recovery():
	var recovered = calculate_recovered_mood()
	if recovered > 0:
		mood_level = clampi(mood_level + recovered, 0, 3)
		mood_changed.emit(mood_level)
		if mood_level >= 3:
			last_failure_time = 0
			accumulated_gameplay_sec = 0.0

func get_seconds_until_next_mood() -> int:
	if last_failure_time == 0 or mood_level >= 3:
		return 0
	var now = Time.get_unix_time_from_system()
	var elapsed = now - last_failure_time - accumulated_gameplay_sec
	return max(0, 3600 - int(elapsed) % 3600)

func lose_mood():
	mood_level = max(0, mood_level - 1)
	last_failure_time = int(Time.get_unix_time_from_system())
	accumulated_gameplay_sec = 0.0
	mood_changed.emit(mood_level)
	save_game()

func set_pending_quit_penalty(value: bool):
	pending_quit_penalty = value

func is_pending_quit_penalty() -> bool:
	return pending_quit_penalty

func apply_pending_quit_penalty_if_any():
	if not pending_quit_penalty:
		return
	pending_quit_penalty = false
	lose_mood()

func show_empty_mood_popup(parent: Control) -> ColorRect:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.anchor_left = 0
	overlay.anchor_top = 0
	overlay.anchor_right = 1
	overlay.anchor_bottom = 1
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)

	var popup = Panel.new()
	var popup_bg := StyleBoxFlat.new()
	popup_bg.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	popup_bg.set_corner_radius_all(12)
	popup.add_theme_stylebox_override("panel", popup_bg)
	popup.anchor_left = 0.5
	popup.anchor_top = 0.5
	popup.anchor_right = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -130
	popup.offset_top = -85
	popup.offset_right = 130
	popup.offset_bottom = 85
	overlay.add_child(popup)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.anchor_left = 0
	vbox.anchor_top = 0
	vbox.anchor_right = 1
	vbox.anchor_bottom = 1
	vbox.offset_left = 15
	vbox.offset_top = 12
	vbox.offset_right = -15
	vbox.offset_bottom = -12
	popup.add_child(vbox)

	var label1 = Label.new()
	label1.text = "Your mood level is empty!"
	label1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label1.add_theme_font_size_override("font_size", 14)
	vbox.add_child(label1)

	var label2 = Label.new()
	label2.text = "Come back after your mood level increased."
	label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label2.add_theme_font_size_override("font_size", 11)
	vbox.add_child(label2)

	var label3 = Label.new()
	label3.text = "Your mood level will increase after :"
	label3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label3.add_theme_font_size_override("font_size", 11)
	vbox.add_child(label3)

	var time_label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(time_label)

	var btn_w = 76
	var btn_h = 26
	var ok_btn = TextureButton.new()
	ok_btn.ignore_texture_size = true
	ok_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	ok_btn.texture_normal = load("res://assets/icons_buttons/ok.png")
	ok_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	ok_btn.pressed.connect(overlay.queue_free)

	var btn_center = CenterContainer.new()
	btn_center.add_child(ok_btn)
	vbox.add_child(btn_center)

	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = false
	popup.add_child(timer)

	var update_time = func():
		var secs = get_seconds_until_next_mood()
		var m = secs / 60
		var s = secs % 60
		time_label.text = "%02d:%02d" % [m, s]
		if secs <= 0:
			timer.stop()

	timer.timeout.connect(update_time)
	update_time.call()
	timer.start()

	overlay.tree_exiting.connect(timer.stop)
	return overlay

func add_skill_stock(skill: String, amount: int):
	if skills.has(skill):
		skills[skill] += amount
		skill_stock_changed.emit(skill, skills[skill])
		save_game()

func use_skill(skill: String) -> bool:
	if skills.has(skill) and skills[skill] > 0:
		skills[skill] -= 1
		skill_stock_changed.emit(skill, skills[skill])
		save_game()
		return true
	return false

func get_rating(level: int) -> int:
	return ratings.get(level, 1)

func get_skill_stock(skill: String) -> int:
	return skills.get(skill, 0)

func is_purchase_processed(token: String) -> bool:
	return processed_purchases.has(token)

func mark_purchase_processed(token: String, sku: String):
	processed_purchases[token] = {
		"sku": sku,
		"timestamp": Time.get_unix_time_from_system()
	}
	save_game()

func _derive_key() -> PackedByteArray:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(SAVE_PASSPHRASE.to_utf8_buffer())
	return ctx.finish()

func _pkcs7_pad(data: PackedByteArray) -> PackedByteArray:
	var pad_len = BLOCK_SIZE - (data.size() % BLOCK_SIZE)
	var padded = data.duplicate()
	for i in range(pad_len):
		padded.append(pad_len)
	return padded

func _pkcs7_unpad(data: PackedByteArray) -> PackedByteArray:
	var pad_len = data[data.size() - 1]
	if pad_len < 1 or pad_len > BLOCK_SIZE:
		return data
	return data.slice(0, data.size() - pad_len)

func save_game():
	var data = {
		"coins": coins,
		"max_level": max_level,
		"mood_level": mood_level,
		"last_failure_time": last_failure_time,
		"accumulated_gameplay_sec": accumulated_gameplay_sec,
		"pending_quit_penalty": pending_quit_penalty,
		"skills": skills,
		"ratings": ratings,
		"processed_purchases": processed_purchases
	}
	var json_str = JSON.stringify(data)
	var plaintext = json_str.to_utf8_buffer()

	# Pad
	var padded = _pkcs7_pad(plaintext)

	# Generate IV
	var iv = PackedByteArray()
	for i in range(BLOCK_SIZE):
		iv.append(randi() % 256)

	# Encrypt
	var key = _derive_key()
	var aes = AESContext.new()
	aes.start(AESContext.MODE_CBC_ENCRYPT, key, iv)
	var ciphertext = aes.update(padded)
	aes.finish()

	# Integrity hash
	var hash_ctx = HashingContext.new()
	hash_ctx.start(HashingContext.HASH_SHA256)
	hash_ctx.update(iv)
	hash_ctx.update(ciphertext)
	var hash = hash_ctx.finish()

	# Write: IV (16) + ciphertext (N) + hash (32)
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_buffer(iv)
		file.store_buffer(ciphertext)
		file.store_buffer(hash)
	else:
		push_error("SaveManager: Could not open save file for writing")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE):
		reset_to_defaults()
		return false

	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if not file:
		reset_to_defaults()
		return false

	var all_data = file.get_buffer(file.get_length())
	if all_data.size() < BLOCK_SIZE + 32:
		reset_to_defaults()
		return false

	var iv = all_data.slice(0, BLOCK_SIZE)
	var hash = all_data.slice(all_data.size() - 32, all_data.size())
	var ciphertext = all_data.slice(BLOCK_SIZE, all_data.size() - 32)

	# Verify integrity
	var hash_ctx = HashingContext.new()
	hash_ctx.start(HashingContext.HASH_SHA256)
	hash_ctx.update(iv)
	hash_ctx.update(ciphertext)
	var computed_hash = hash_ctx.finish()
	if computed_hash != hash:
		reset_to_defaults()
		return false

	# Decrypt
	var key = _derive_key()
	var aes = AESContext.new()
	aes.start(AESContext.MODE_CBC_DECRYPT, key, iv)
	var padded = aes.update(ciphertext)
	aes.finish()

	var plaintext = _pkcs7_unpad(padded)
	var json_str = plaintext.get_string_from_utf8()
	var parsed = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		reset_to_defaults()
		return false

	coins = parsed.get("coins", 0)
	max_level = parsed.get("max_level", 1)
	mood_level = parsed.get("mood_level", 3)
	last_failure_time = parsed.get("last_failure_time", 0)
	accumulated_gameplay_sec = parsed.get("accumulated_gameplay_sec", 0.0)
	pending_quit_penalty = parsed.get("pending_quit_penalty", false)
	apply_mood_recovery()
	var loaded_skills = parsed.get("skills", {})
	skills = DEFAULT_SKILLS.duplicate()
	for sk in loaded_skills:
		if skills.has(sk):
			skills[sk] = loaded_skills[sk]
	ratings = parsed.get("ratings", {})
	for lvl_key in ratings.keys():
		if lvl_key is String and lvl_key.is_valid_int():
			ratings[lvl_key.to_int()] = ratings[lvl_key]
			ratings.erase(lvl_key)
	processed_purchases = parsed.get("processed_purchases", {})

	return true

var _session_start_time: int = 0

func on_gameplay_start():
	_session_start_time = int(Time.get_unix_time_from_system())

func on_gameplay_end():
	if _session_start_time > 0:
		var now = int(Time.get_unix_time_from_system())
		accumulated_gameplay_sec += now - _session_start_time
		_session_start_time = 0
		save_game()

func complete_level(level: int, reward: int, rating: int = 1):
	add_coins(reward)
	var next_level = level + 1
	if next_level > max_level:
		max_level = next_level
	if ratings.get(level, 0) < rating:
		ratings[level] = rating
	save_game()
