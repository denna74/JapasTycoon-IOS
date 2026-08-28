extends Control

var customer_slots: Array = []
var satisfied_count: int = 0

signal all_customers_satisfied()

@onready var slot_scene := preload("res://scenes/customer/CustomerSlot.tscn")
@onready var container := $HBoxContainer

func setup(customer_count: int, japas_count: int, level: int = 1):
	for child in container.get_children():
		child.free()
	customer_slots.clear()
	satisfied_count = 0

	for i in range(customer_count):
		var slot: CustomerSlot = slot_scene.instantiate()
		var requests = generate_requests(japas_count, level)
		slot.satisfied.connect(_on_slot_satisfied)
		container.add_child(slot)
		slot.setup(requests)
		customer_slots.append(slot)

	_fit_slots_to_width()

func _fit_slots_to_width():
	var count = customer_slots.size()
	if count == 0:
		return
	var spacing = 4
	var avail = container.size.x - spacing * (count - 1)
	var slot_w = maxf(80.0, avail / count)
	slot_w = minf(slot_w, 200.0)
	for s in customer_slots:
		s.custom_minimum_size.x = slot_w
		s.size.x = slot_w

func generate_requests(available_japas: int, level: int = 1) -> Dictionary:
	var request_count = clampi(1 + level / 10, 2, 3)

	var qty_min = 2
	var qty_max = 2
	if level <= 5:
		qty_min = 2; qty_max = 3
	elif level <= 20:
		qty_min = 2; qty_max = 4
	elif level <= 50:
		qty_min = 3; qty_max = 5
	elif level <= 80:
		qty_min = 3; qty_max = 6
	elif level <= 120:
		qty_min = 4; qty_max = 7
	elif level <= 250:
		qty_min = 4; qty_max = 8
	else:
		qty_min = 5; qty_max = 9

	var types: Array = []
	while types.size() < request_count:
		var t = randi() % available_japas
		if not t in types:
			types.append(t)
	var requests: Dictionary = {}
	for t in types:
		requests[t] = randi() % (qty_max - qty_min + 1) + qty_min
	return requests

func get_requested_types() -> Array:
	var types: Array = []
	for slot in customer_slots:
		for t in slot.required.keys():
			if not t in types:
				types.append(t)
	return types

func on_tile_matched(japas_type: int, count: int):
	for i in range(count):
		for slot in customer_slots:
			if not slot.is_satisfied and slot.fulfill_request(japas_type):
				break

func _on_slot_satisfied():
	satisfied_count += 1
	if satisfied_count >= customer_slots.size():
		all_customers_satisfied.emit()

func get_target_for_type(japas_type: int) -> Vector2:
	for slot in customer_slots:
		if not slot.is_satisfied:
			var req = slot.required.get(japas_type)
			var col = slot.collected.get(japas_type, 0)
			if req != null and col < req:
				return slot.get_target_global_position()
	return Vector2.ZERO

func get_target_position() -> Vector2:
	return global_position + Vector2(size.x / 2, size.y / 2)
