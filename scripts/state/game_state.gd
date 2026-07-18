class_name GameState
extends RefCounted

## Fired after a slot's contents change so the 3D view can mirror the state.
signal equipment_changed(slot: StringName)

const CURRENT_VERSION := 2

const PHASE_PROLOGUE_DAY := &"phase.prologue_day"

const PRESSURE_SUSPICION := &"pressure.suspicion"
const PRESSURE_SOLIDARITY := &"pressure.solidarity"
const PRESSURE_SCARCITY := &"pressure.scarcity"

const RELATIONSHIP_MIN := -3
const RELATIONSHIP_MAX := 3
const PRESSURE_MIN := 0
const PRESSURE_MAX := 3

var version: int = CURRENT_VERSION
var phase: StringName = PHASE_PROLOGUE_DAY
var player: PlayerState = PlayerState.new()
var bag: InventoryBag = InventoryBag.new()
var map_world_state: MapStableStateStore = MapStableStateStore.new()

var _equipped: Dictionary[StringName, StringName] = {}
var _facts: Dictionary[StringName, bool] = {}
var _relationships: Dictionary[StringName, int] = {}
var _pressures: Dictionary[StringName, int] = {}
var _forged_records: Dictionary[StringName, ForgedRecord] = {}
var _flags: Dictionary[StringName, bool] = {}
var _quest_states: Dictionary[StringName, StringName] = {}
var _location_states: Dictionary[StringName, StringName] = {}
var _items: Dictionary[StringName, bool] = {}
var _world_items: Dictionary = {}


func _init() -> void:
	_pressures[PRESSURE_SUSPICION] = 0
	_pressures[PRESSURE_SOLIDARITY] = 0
	_pressures[PRESSURE_SCARCITY] = 0


func get_version() -> int:
	return version


func get_phase() -> StringName:
	return phase


func set_phase(value: StringName) -> void:
	phase = value


func get_fact(key: StringName) -> bool:
	return _facts.get(key, false)


func set_fact(key: StringName, value: bool) -> void:
	_facts[key] = value


func get_flag(key: StringName) -> bool:
	return _flags.get(key, false)


func set_flag(key: StringName, value: bool) -> void:
	_flags[key] = value


func get_quest_state(key: StringName) -> StringName:
	return _quest_states.get(key, &"")


func set_quest_state(key: StringName, value: StringName) -> void:
	_quest_states[key] = value


func get_location_state(key: StringName) -> StringName:
	return _location_states.get(key, &"")


func set_location_state(key: StringName, value: StringName) -> void:
	_location_states[key] = value


func load_map_world_state(
	payload: Dictionary,
	known_archetypes: Array[StringName] = [],
	expected_fingerprints: Dictionary = {}
) -> Array[String]:
	return map_world_state.load_payload(payload, known_archetypes, expected_fingerprints)


func save_map_world_state() -> Dictionary:
	return map_world_state.save_payload()


## --- Equipment placement (see docs/INVENTORY_MECHANICS.md) ---------------
## Equipped items leave the bag grid but keep counting toward the weight cap:
## you carry what you wear. Failed swaps mutate nothing.

func equipped_item(slot: StringName) -> StringName:
	return _equipped.get(slot, &"")


func equipped_slots() -> Array[StringName]:
	var slots: Array[StringName] = []
	for slot: StringName in _equipped:
		slots.append(slot)
	slots.sort()
	return slots


func equip_from_bag(slot: StringName, item_id: StringName) -> bool:
	if slot.is_empty() or item_id.is_empty():
		return false
	var placement := bag.find_placement(item_id)
	if placement == null:
		return false

	# Take one unit out of the grid before attempting the swap-back so the
	# previous occupant can use the freed cells.
	var restore_origin := Vector2i(placement.grid_x, placement.grid_y)
	if placement.quantity > 1:
		placement.quantity -= 1
	else:
		bag.remove(placement)

	var previous := equipped_item(slot)
	if not previous.is_empty() and bag.try_add(previous) != InventoryBag.AddResult.OK:
		# Rollback: the previous occupant does not fit back into the grid.
		if placement.quantity >= 1 and bag.find_placement(item_id) == placement:
			placement.quantity += 1
		else:
			bag.try_add(item_id)
		return false

	_equipped[slot] = item_id
	_refresh_reserved_weight()
	equipment_changed.emit(slot)
	return true


func unequip_to_bag(slot: StringName) -> bool:
	var item_id := equipped_item(slot)
	if item_id.is_empty():
		return false
	# The item's own weight is already counted as reserved, so release it
	# for the duration of the add-back check.
	bag.reserved_weight_kg -= bag.profile_for(item_id).weight_kg
	if bag.try_add(item_id) != InventoryBag.AddResult.OK:
		_refresh_reserved_weight()
		return false
	_equipped.erase(slot)
	_refresh_reserved_weight()
	equipment_changed.emit(slot)
	return true


## Bag weight plus worn weight; the cap covers everything Kalev carries.
func get_carried_weight() -> float:
	return bag.get_total_weight() + bag.reserved_weight_kg


func _refresh_reserved_weight() -> void:
	var total := 0.0
	for slot: StringName in _equipped:
		total += bag.profile_for(_equipped[slot]).weight_kg
	bag.reserved_weight_kg = total


func has_item(key: StringName) -> bool:
	return _items.has(key)


func add_item(key: StringName) -> bool:
	if key.is_empty() or _items.has(key):
		return false
	_items[key] = true
	return true


func remove_item(key: StringName) -> bool:
	return _items.erase(key)


## --- World item placement (session-scoped, survives map re-entry) ---------
## Items on the ground live outside the bag grid until picked up.

func get_world_items(location_id: StringName) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if location_id.is_empty():
		return records
	var bucket: Variant = _world_items.get(String(location_id), {})
	if not bucket is Dictionary:
		return records
	for object_key in bucket:
		var record: Variant = bucket[object_key]
		if record is Dictionary:
			records.append((record as Dictionary).duplicate(true))
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("object_id", "")) < String(b.get("object_id", ""))
	)
	return records


func is_world_item_placed(location_id: StringName, object_id: StringName) -> bool:
	if location_id.is_empty() or object_id.is_empty():
		return false
	var bucket: Variant = _world_items.get(String(location_id), {})
	return bucket is Dictionary and (bucket as Dictionary).has(String(object_id))


func place_world_item(
	location_id: StringName,
	object_id: StringName,
	item_id: StringName,
	position: Vector2
) -> bool:
	if location_id.is_empty() or object_id.is_empty() or item_id.is_empty():
		return false
	var bucket: Dictionary = _world_items.get(String(location_id), {}) as Dictionary
	if not _world_items.has(String(location_id)):
		_world_items[String(location_id)] = bucket
	bucket[String(object_id)] = {
		"object_id": object_id,
		"item_id": item_id,
		"position": position,
	}
	return true


func take_world_item(location_id: StringName, object_id: StringName) -> Dictionary:
	if location_id.is_empty() or object_id.is_empty():
		return {}
	var bucket: Variant = _world_items.get(String(location_id), {})
	if not bucket is Dictionary:
		return {}
	var key := String(object_id)
	var record: Variant = (bucket as Dictionary).get(key, {})
	if not record is Dictionary:
		return {}
	(bucket as Dictionary).erase(key)
	return (record as Dictionary).duplicate(true)


func get_relationship(key: StringName) -> int:
	return _relationships.get(key, 0)


func set_relationship(key: StringName, value: int) -> void:
	_relationships[key] = clampi(value, RELATIONSHIP_MIN, RELATIONSHIP_MAX)


func adjust_relationship(key: StringName, amount: int) -> void:
	set_relationship(key, get_relationship(key) + amount)


func get_pressure(key: StringName) -> int:
	return _pressures.get(key, 0)


func set_pressure(key: StringName, value: int) -> void:
	_pressures[key] = clampi(value, PRESSURE_MIN, PRESSURE_MAX)


func adjust_pressure(key: StringName, amount: int) -> void:
	set_pressure(key, get_pressure(key) + amount)


func add_forged_record(record: ForgedRecord) -> bool:
	if record == null or record.record_id.is_empty():
		return false
	if _forged_records.has(record.record_id):
		return false
	_forged_records[record.record_id] = record
	return true


func has_forged_record(record_id: StringName) -> bool:
	return _forged_records.has(record_id)


func get_forged_record(record_id: StringName) -> ForgedRecord:
	return _forged_records.get(record_id)


func get_forged_records() -> Array[ForgedRecord]:
	var records: Array[ForgedRecord] = []
	for record in _forged_records.values():
		records.append(record)
	records.sort_custom(func(a: ForgedRecord, b: ForgedRecord) -> bool:
		return String(a.record_id) < String(b.record_id)
	)
	return records
