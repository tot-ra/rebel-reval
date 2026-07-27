class_name GameState
extends RefCounted

const _PersistenceScript := preload("res://scripts/state/game_state_persistence.gd")
const _RelationshipMemoryScript := preload("res://scripts/relationship/relationship_memory.gd")

## Fired after a slot's contents change so the 3D view can mirror the state.
signal equipment_changed(slot: StringName)
## Fired when quest ownership flags change.
signal items_changed()
## Fired when a forged commission record is committed.
signal forged_record_added(record_id: StringName)
## Fired when an explicit faction ledger event is recorded.
signal faction_event_recorded(event_id: StringName, faction_id: StringName)
## Fired when the campaign phase changes; SessionState autosaves on this boundary.
signal phase_changed(previous: StringName, next: StringName)

const CURRENT_VERSION := 2

const PHASE_PROLOGUE_DAY := &"phase.prologue_day"
const PHASE_INVESTIGATION_MORNING := &"phase.investigation_morning"
const PHASE_INVESTIGATION_NIGHT := &"phase.investigation_night"
const PHASE_CONSEQUENCE_NIGHT := &"phase.consequence_night"
const PHASE_REFLECTION_MORNING := &"phase.reflection_morning"

const SLICE_PHASES: Array[StringName] = [
	PHASE_PROLOGUE_DAY,
	PHASE_INVESTIGATION_MORNING,
	PHASE_INVESTIGATION_NIGHT,
	PHASE_CONSEQUENCE_NIGHT,
	PHASE_REFLECTION_MORNING,
]

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
var _faction_events: Dictionary[StringName, Dictionary] = {}
var _pressures: Dictionary[StringName, int] = {}
var _forged_records: Dictionary[StringName, ForgedRecord] = {}
var _flags: Dictionary[StringName, bool] = {}
var _quest_states: Dictionary[StringName, StringName] = {}
var _location_states: Dictionary[StringName, StringName] = {}
var _items: Dictionary[StringName, bool] = {}
var _dialogue_nodes_seen: Dictionary[StringName, bool] = {}
var _relationship_memories: Dictionary[StringName, bool] = {}
var _world_items: Dictionary = {}
var _world_defaults_seeded: Dictionary = {}
## One equipped forge technique (Iron / Ember / Root) or empty when none.
var _equipped_forge_technique: StringName = &""


func _init() -> void:
	_pressures[PRESSURE_SUSPICION] = 0
	_pressures[PRESSURE_SOLIDARITY] = 0
	_pressures[PRESSURE_SCARCITY] = 0


func get_version() -> int:
	return version


func get_phase() -> StringName:
	return phase


func set_phase(value: StringName) -> void:
	if phase == value:
		return
	var previous := phase
	phase = value
	phase_changed.emit(previous, value)


func get_fact(key: StringName) -> bool:
	return _facts.get(key, false)


func set_fact(key: StringName, value: bool) -> void:
	_facts[key] = value


func get_flag(key: StringName) -> bool:
	return _flags.get(key, false)


func set_flag(key: StringName, value: bool) -> void:
	_flags[key] = value


func equipped_forge_technique() -> StringName:
	return _equipped_forge_technique


## Equips an allowlisted forge technique, or clears it when empty. Returns false
## when the id is not one of the three authored techniques.
func set_equipped_forge_technique(technique_id: StringName) -> bool:
	if technique_id.is_empty():
		_equipped_forge_technique = &""
		return true
	if not ForgeTechnique.is_allowed(technique_id):
		return false
	_equipped_forge_technique = technique_id
	return true


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


func get_owned_item_ids_in_order() -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in _items:
		keys.append(key)
	return keys


func possesses_item(item_id: StringName) -> bool:
	if item_id.is_empty():
		return false
	if has_item(item_id):
		return true
	if bag.find_placement(item_id) != null:
		return true
	for slot: StringName in equipped_slots():
		if equipped_item(slot) == item_id:
			return true
	return false


func add_item(key: StringName) -> bool:
	if key.is_empty() or _items.has(key):
		return false
	_items[key] = true
	items_changed.emit()
	return true


func remove_item(key: StringName) -> bool:
	if not _items.erase(key):
		return false
	items_changed.emit()
	return true


func has_dialogue_node_seen(dialogue_id: StringName, node_id: String) -> bool:
	if dialogue_id.is_empty() or node_id.is_empty():
		return false
	return _dialogue_nodes_seen.has(_dialogue_node_key(dialogue_id, node_id))


func mark_dialogue_node_seen(dialogue_id: StringName, node_id: String) -> void:
	if dialogue_id.is_empty() or node_id.is_empty():
		return
	_dialogue_nodes_seen[_dialogue_node_key(dialogue_id, node_id)] = true


func get_dialogue_nodes_seen() -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in _dialogue_nodes_seen:
		keys.append(key)
	keys.sort()
	return keys


func has_relationship_memory(key: StringName) -> bool:
	return _relationship_memories.get(key, false)


func record_relationship_memory(key: StringName) -> bool:
	if not _RelationshipMemoryScript.is_valid_key(key):
		return false
	_relationship_memories[key] = true
	return true


func get_relationship_memories() -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in _relationship_memories:
		if _relationship_memories[key]:
			keys.append(key)
	keys.sort()
	return keys


func get_relationship_memories_for_character(character_id: StringName) -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in get_relationship_memories():
		if _RelationshipMemoryScript.character_id_for_key(key) == character_id:
			keys.append(key)
	return keys


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


func are_world_defaults_seeded(location_id: StringName) -> bool:
	if location_id.is_empty():
		return false
	return bool(_world_defaults_seeded.get(String(location_id), false))


func mark_world_defaults_seeded(location_id: StringName) -> void:
	if location_id.is_empty():
		return
	_world_defaults_seeded[String(location_id)] = true


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


func has_faction_event(event_id: StringName) -> bool:
	return _faction_events.has(event_id)


func record_faction_event(
	event_id: StringName,
	faction_id: StringName,
	delta: int,
	summary: String
) -> bool:
	if event_id.is_empty() or not FactionLedger.is_active_faction(faction_id):
		return false
	if _faction_events.has(event_id):
		return false
	_faction_events[event_id] = {
		"event_id": event_id,
		"faction_id": faction_id,
		"delta": clampi(delta, FactionLedger.STANDING_MIN, FactionLedger.STANDING_MAX),
		"summary": summary,
	}
	faction_event_recorded.emit(event_id, faction_id)
	return true


func get_faction_standing(faction_id: StringName) -> int:
	if not FactionLedger.is_active_faction(faction_id):
		return 0
	var total := 0
	for event in _faction_events.values():
		if event.get("faction_id", &"") == faction_id:
			total += int(event.get("delta", 0))
	return clampi(total, FactionLedger.STANDING_MIN, FactionLedger.STANDING_MAX)


func get_faction_events_for(faction_id: StringName) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for event_id in _faction_events.keys():
		var event: Dictionary = _faction_events[event_id]
		if event.get("faction_id", &"") != faction_id:
			continue
		events.append(event.duplicate(true))
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("event_id", "")) < String(b.get("event_id", ""))
	)
	return events


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
	forged_record_added.emit(record.record_id)
	return true


func has_forged_record(record_id: StringName) -> bool:
	return _forged_records.has(record_id)


func has_forged_modification(commission_id: StringName, modification_id: StringName) -> bool:
	for record in get_forged_records():
		if record.commission_id == commission_id and record.modification_id == modification_id:
			return true
	return false


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


func save_payload() -> Dictionary:
	return _PersistenceScript.save_payload(self)


func load_payload(payload: Dictionary) -> Array[String]:
	return _PersistenceScript.load_payload(self, payload)


func _dialogue_node_key(dialogue_id: StringName, node_id: String) -> StringName:
	return StringName("%s:%s" % [String(dialogue_id), node_id])
