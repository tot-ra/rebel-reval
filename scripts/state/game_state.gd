class_name GameState
extends RefCounted

const CURRENT_VERSION := 1

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

var _facts: Dictionary[StringName, bool] = {}
var _relationships: Dictionary[StringName, int] = {}
var _pressures: Dictionary[StringName, int] = {}
var _forged_records: Dictionary[StringName, ForgedRecord] = {}
var _flags: Dictionary[StringName, bool] = {}
var _quest_states: Dictionary[StringName, StringName] = {}
var _location_states: Dictionary[StringName, StringName] = {}
var _items: Dictionary[StringName, bool] = {}


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


func has_item(key: StringName) -> bool:
	return _items.has(key)


func add_item(key: StringName) -> bool:
	if key.is_empty() or _items.has(key):
		return false
	_items[key] = true
	return true


func remove_item(key: StringName) -> bool:
	return _items.erase(key)


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
