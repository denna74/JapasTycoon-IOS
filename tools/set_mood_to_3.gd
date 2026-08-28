#!/usr/bin/env godot
extends SceneTree

const SAVE_FILE := "user://japas_tycoon.save"
const SAVE_PASSPHRASE := "J4p@sTyco0n_S3cur3S4v3_2026"
const BLOCK_SIZE := 16

func _init():
	if not FileAccess.file_exists(SAVE_FILE):
		print("No save file found. Run the game once to create one.")
		quit(1)
		return

	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if not file:
		print("Could not open save file.")
		quit(1)
		return

	var all_data = file.get_buffer(file.get_length())
	if all_data.size() < BLOCK_SIZE + 32:
		print("Save file corrupted (too small).")
		quit(1)
		return

	var iv = all_data.slice(0, BLOCK_SIZE)
	var hash = all_data.slice(all_data.size() - 32, all_data.size())
	var ciphertext = all_data.slice(BLOCK_SIZE, all_data.size() - 32)

	var hash_ctx = HashingContext.new()
	hash_ctx.start(HashingContext.HASH_SHA256)
	hash_ctx.update(iv)
	hash_ctx.update(ciphertext)
	var computed_hash = hash_ctx.finish()
	if computed_hash != hash:
		print("Save file integrity check failed.")
		quit(1)
		return

	var key = _derive_key()
	var aes = AESContext.new()
	aes.start(AESContext.MODE_CBC_DECRYPT, key, iv)
	var padded = aes.update(ciphertext)
	aes.finish()

	var plaintext = _pkcs7_unpad(padded)
	var json_str = plaintext.get_string_from_utf8()
	var data = JSON.parse_string(json_str)
	if not (data is Dictionary):
		print("Failed to parse save data.")
		quit(1)
		return

	print("Loaded save data:")
	print("  mood_level was:", data.get("mood_level"))

	# Set mood to max
	data["mood_level"] = 3
	data["last_failure_time"] = 0
	data["accumulated_gameplay_sec"] = 0.0

	var json_str_new = JSON.stringify(data)
	var plaintext_new = json_str_new.to_utf8_buffer()
	var padded_new = _pkcs7_pad(plaintext_new)

	var iv_new = PackedByteArray()
	for i in range(BLOCK_SIZE):
		iv_new.append(randi() % 256)

	var key_new = _derive_key()
	var aes_new = AESContext.new()
	aes_new.start(AESContext.MODE_CBC_ENCRYPT, key_new, iv_new)
	var ciphertext_new = aes_new.update(padded_new)
	aes_new.finish()

	var hash_ctx_new = HashingContext.new()
	hash_ctx_new.start(HashingContext.HASH_SHA256)
	hash_ctx_new.update(iv_new)
	hash_ctx_new.update(ciphertext_new)
	var hash_new = hash_ctx_new.finish()

	var file_new = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file_new:
		file_new.store_buffer(iv_new)
		file_new.store_buffer(ciphertext_new)
		file_new.store_buffer(hash_new)
		print("Success! mood_level set to 3 in save data.")
	else:
		print("Could not write to save file.")
		quit(1)

	quit(0)

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
