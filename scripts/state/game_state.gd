class_name GameState
extends RefCounted

## Fired after a slot's contents change so the 3D view can mirror the state.
signal equipment_changed(slot: StringName)
## Fired when the campaign phase changes; SessionState autosaves on this boundary.
signal phase_changed(previous: StringName, next: StringName)

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
var _dialogue_nodes_seen: Dictionary[StringName, bool] = {}
var _world_items: Dictionary = {}
var _world_defaults_seeded: Dictionary = {}


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


func save_payload() -> Dictionary:
	var forged: Array[Dictionary] = []
	for record in get_forged_records():
		forged.append({
			"record_id": String(record.record_id),
			"commission_id": String(record.commission_id),
			"item_id": String(record.item_id),
			"modification_id": String(record.modification_id),
		})

	var placements: Array[Dictionary] = []
	for placement in bag.placements:
		placements.append({
			"item_id": String(placement.item_id),
			"grid_x": placement.grid_x,
			"grid_y": placement.grid_y,
			"quantity": placement.quantity,
		})

	return {
		"version": version,
		"phase": String(phase),
		"player": {
			"health": player.health,
			"max_health": player.max_health,
			"stamina": player.stamina,
			"max_stamina": player.max_stamina,
			"location_id": String(player.location_id),
			"spawn_id": String(player.spawn_id),
		},
		"bag": {
			"placements": placements,
		},
		"equipped": _string_dictionary(_equipped),
		"facts": _bool_dictionary(_facts),
		"flags": _bool_dictionary(_flags),
		"relationships": _int_dictionary(_relationships),
		"pressures": _int_dictionary(_pressures),
		"quest_states": _string_dictionary(_quest_states),
		"location_states": _string_dictionary(_location_states),
		"items": _bool_dictionary(_items),
		"dialogue_nodes_seen": _bool_dictionary(_dialogue_nodes_seen),
		"forged_records": forged,
		"world_items": _world_items.duplicate(true),
		"world_defaults_seeded": _world_defaults_seeded.duplicate(true),
		"map_world_state": save_map_world_state(),
	}


func load_payload(payload: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not payload is Dictionary:
		return ["game state payload must be a dictionary"]

	var schema_version := int(payload.get("version", 0))
	if schema_version < 1 or schema_version > CURRENT_VERSION:
		errors.append(
			"unsupported game-state version %d (supported: 1-%d)" % [schema_version, CURRENT_VERSION]
		)
		return errors

	version = schema_version
	phase = StringName(String(payload.get("phase", PHASE_PROLOGUE_DAY)))

	var player_payload: Variant = payload.get("player", {})
	if not player_payload is Dictionary:
		errors.append("player must be a dictionary")
	else:
		var player_dict := player_payload as Dictionary
		player.health = float(player_dict.get("health", player.health))
		player.max_health = float(player_dict.get("max_health", player.max_health))
		player.stamina = float(player_dict.get("stamina", player.stamina))
		player.max_stamina = float(player_dict.get("max_stamina", player.max_stamina))
		player.location_id = StringName(String(player_dict.get("location_id", player.location_id)))
		player.spawn_id = StringName(String(player_dict.get("spawn_id", player.spawn_id)))

	var bag_payload: Variant = payload.get("bag", {})
	if not bag_payload is Dictionary:
		errors.append("bag must be a dictionary")
	else:
		bag.placements.clear()
		bag.reserved_weight_kg = 0.0
		var placement_rows: Variant = (bag_payload as Dictionary).get("placements", [])
		if not placement_rows is Array:
			errors.append("bag.placements must be an array")
		else:
			for row in placement_rows as Array:
				if not row is Dictionary:
					errors.append("bag placement row must be a dictionary")
					continue
				var placement_dict := row as Dictionary
				bag.placements.append(
					InventoryPlacement.new(
						StringName(String(placement_dict.get("item_id", ""))),
						int(placement_dict.get("grid_x", 0)),
						int(placement_dict.get("grid_y", 0)),
						int(placement_dict.get("quantity", 1))
					)
				)
			bag._rebuild_occupancy()

	_equipped = _load_string_dictionary(payload.get("equipped", {}), errors, "equipped")
	_facts = _load_bool_dictionary(payload.get("facts", {}), errors, "facts")
	_flags = _load_bool_dictionary(payload.get("flags", {}), errors, "flags")
	_relationships = _load_int_dictionary(payload.get("relationships", {}), errors, "relationships")
	_pressures = _load_pressure_dictionary(payload.get("pressures", {}), errors)
	_quest_states = _load_string_dictionary(payload.get("quest_states", {}), errors, "quest_states")
	_location_states = _load_string_dictionary(payload.get("location_states", {}), errors, "location_states")
	_items = _load_bool_dictionary(payload.get("items", {}), errors, "items")
	_dialogue_nodes_seen = _load_bool_dictionary(
		payload.get("dialogue_nodes_seen", {}),
		errors,
		"dialogue_nodes_seen"
	)

	_forged_records.clear()
	var forged_rows: Variant = payload.get("forged_records", [])
	if not forged_rows is Array:
		errors.append("forged_records must be an array")
	else:
		for row in forged_rows as Array:
			if not row is Dictionary:
				errors.append("forged record row must be a dictionary")
				continue
			var record_dict := row as Dictionary
			var record := ForgedRecord.new(
				StringName(String(record_dict.get("record_id", ""))),
				StringName(String(record_dict.get("commission_id", ""))),
				StringName(String(record_dict.get("item_id", ""))),
				StringName(String(record_dict.get("modification_id", "")))
			)
			if record.record_id.is_empty():
				errors.append("forged record row missing record_id")
				continue
			if _forged_records.has(record.record_id):
				errors.append("duplicate forged record id %s" % String(record.record_id))
				continue
			_forged_records[record.record_id] = record

	var world_items_payload: Variant = payload.get("world_items", {})
	if not world_items_payload is Dictionary:
		errors.append("world_items must be a dictionary")
	else:
		_world_items = (world_items_payload as Dictionary).duplicate(true)

	var seeded_payload: Variant = payload.get("world_defaults_seeded", {})
	if not seeded_payload is Dictionary:
		errors.append("world_defaults_seeded must be a dictionary")
	else:
		_world_defaults_seeded = (seeded_payload as Dictionary).duplicate(true)

	var map_payload: Variant = payload.get("map_world_state", {})
	if not map_payload is Dictionary:
		errors.append("map_world_state must be a dictionary")
	else:
		errors.append_array(map_world_state.load_payload(map_payload as Dictionary))

	_refresh_reserved_weight()
	return errors


static func _string_dictionary(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in source:
		out[String(key)] = String(source[key])
	return out


static func _bool_dictionary(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in source:
		out[String(key)] = bool(source[key])
	return out


static func _int_dictionary(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in source:
		out[String(key)] = int(source[key])
	return out


static func _load_string_dictionary(
	source: Variant,
	errors: Array[String],
	label: String
) -> Dictionary[StringName, StringName]:
	var out: Dictionary[StringName, StringName] = {}
	if not source is Dictionary:
		errors.append("%s must be a dictionary" % label)
		return out
	for key in source as Dictionary:
		out[StringName(String(key))] = StringName(String(source[key]))
	return out


static func _load_bool_dictionary(
	source: Variant,
	errors: Array[String],
	label: String
) -> Dictionary[StringName, bool]:
	var out: Dictionary[StringName, bool] = {}
	if not source is Dictionary:
		errors.append("%s must be a dictionary" % label)
		return out
	for key in source as Dictionary:
		out[StringName(String(key))] = bool(source[key])
	return out


static func _load_int_dictionary(
	source: Variant,
	errors: Array[String],
	label: String
) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	if not source is Dictionary:
		errors.append("%s must be a dictionary" % label)
		return out
	for key in source as Dictionary:
		out[StringName(String(key))] = int(source[key])
	return out


func _load_pressure_dictionary(source: Variant, errors: Array[String]) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	out[PRESSURE_SUSPICION] = 0
	out[PRESSURE_SOLIDARITY] = 0
	out[PRESSURE_SCARCITY] = 0
	if not source is Dictionary:
		errors.append("pressures must be a dictionary")
		return out
	for key in source as Dictionary:
		var pressure_key := StringName(String(key))
		out[pressure_key] = clampi(int(source[key]), PRESSURE_MIN, PRESSURE_MAX)
	return out


func _dialogue_node_key(dialogue_id: StringName, node_id: String) -> StringName:
	return StringName("%s:%s" % [String(dialogue_id), node_id])
