class_name GameStatePersistence
extends RefCounted

## Save/load serialization for GameState. Kept separate so runtime state accessors
## stay readable and persistence tests can evolve independently.


static func save_payload(state: GameState) -> Dictionary:
	var forged: Array[Dictionary] = []
	for record in state.get_forged_records():
		forged.append({
			"record_id": String(record.record_id),
			"commission_id": String(record.commission_id),
			"item_id": String(record.item_id),
			"modification_id": String(record.modification_id),
		})

	var placements: Array[Dictionary] = []
	for placement in state.bag.placements:
		placements.append({
			"item_id": String(placement.item_id),
			"grid_x": placement.grid_x,
			"grid_y": placement.grid_y,
			"quantity": placement.quantity,
		})

	return {
		"version": state.version,
		"phase": String(state.phase),
		"player": {
			"health": state.player.health,
			"max_health": state.player.max_health,
			"stamina": state.player.stamina,
			"max_stamina": state.player.max_stamina,
			"location_id": String(state.player.location_id),
			"spawn_id": String(state.player.spawn_id),
		},
		"bag": {
			"placements": placements,
		},
		"equipped": _string_dictionary(state._equipped),
		"facts": _bool_dictionary(state._facts),
		"flags": _bool_dictionary(state._flags),
		"relationships": _int_dictionary(state._relationships),
		"pressures": _int_dictionary(state._pressures),
		"quest_states": _string_dictionary(state._quest_states),
		"location_states": _string_dictionary(state._location_states),
		"items": _bool_dictionary(state._items),
		"dialogue_nodes_seen": _bool_dictionary(state._dialogue_nodes_seen),
		"forged_records": forged,
		"world_items": state._world_items.duplicate(true),
		"world_defaults_seeded": state._world_defaults_seeded.duplicate(true),
		"map_world_state": state.save_map_world_state(),
	}


static func load_payload(state: GameState, payload: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not payload is Dictionary:
		return ["game state payload must be a dictionary"]

	var schema_version := int(payload.get("version", 0))
	if schema_version < 1 or schema_version > GameState.CURRENT_VERSION:
		errors.append(
			"unsupported game-state version %d (supported: 1-%d)" % [schema_version, GameState.CURRENT_VERSION]
		)
		return errors

	state.version = schema_version
	state.phase = StringName(String(payload.get("phase", GameState.PHASE_PROLOGUE_DAY)))

	var player_payload: Variant = payload.get("player", {})
	if not player_payload is Dictionary:
		errors.append("player must be a dictionary")
	else:
		var player_dict := player_payload as Dictionary
		state.player.health = float(player_dict.get("health", state.player.health))
		state.player.max_health = float(player_dict.get("max_health", state.player.max_health))
		state.player.stamina = float(player_dict.get("stamina", state.player.stamina))
		state.player.max_stamina = float(player_dict.get("max_stamina", state.player.max_stamina))
		state.player.location_id = StringName(String(player_dict.get("location_id", state.player.location_id)))
		state.player.spawn_id = StringName(String(player_dict.get("spawn_id", state.player.spawn_id)))

	var bag_payload: Variant = payload.get("bag", {})
	if not bag_payload is Dictionary:
		errors.append("bag must be a dictionary")
	else:
		state.bag.placements.clear()
		state.bag.reserved_weight_kg = 0.0
		var placement_rows: Variant = (bag_payload as Dictionary).get("placements", [])
		if not placement_rows is Array:
			errors.append("bag.placements must be an array")
		else:
			for row in placement_rows as Array:
				if not row is Dictionary:
					errors.append("bag placement row must be a dictionary")
					continue
				var placement_dict := row as Dictionary
				state.bag.placements.append(
					InventoryPlacement.new(
						StringName(String(placement_dict.get("item_id", ""))),
						int(placement_dict.get("grid_x", 0)),
						int(placement_dict.get("grid_y", 0)),
						int(placement_dict.get("quantity", 1))
					)
				)
			state.bag._rebuild_occupancy()

	state._equipped = _load_string_dictionary(payload.get("equipped", {}), errors, "equipped")
	state._facts = _load_bool_dictionary(payload.get("facts", {}), errors, "facts")
	state._flags = _load_bool_dictionary(payload.get("flags", {}), errors, "flags")
	state._relationships = _load_int_dictionary(payload.get("relationships", {}), errors, "relationships")
	state._pressures = _load_pressure_dictionary(state, payload.get("pressures", {}), errors)
	state._quest_states = _load_string_dictionary(payload.get("quest_states", {}), errors, "quest_states")
	state._location_states = _load_string_dictionary(payload.get("location_states", {}), errors, "location_states")
	state._items = _load_bool_dictionary(payload.get("items", {}), errors, "items")
	state._dialogue_nodes_seen = _load_bool_dictionary(
		payload.get("dialogue_nodes_seen", {}),
		errors,
		"dialogue_nodes_seen"
	)

	state._forged_records.clear()
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
			if state._forged_records.has(record.record_id):
				errors.append("duplicate forged record id %s" % String(record.record_id))
				continue
			state._forged_records[record.record_id] = record

	var world_items_payload: Variant = payload.get("world_items", {})
	if not world_items_payload is Dictionary:
		errors.append("world_items must be a dictionary")
	else:
		state._world_items = (world_items_payload as Dictionary).duplicate(true)

	var seeded_payload: Variant = payload.get("world_defaults_seeded", {})
	if not seeded_payload is Dictionary:
		errors.append("world_defaults_seeded must be a dictionary")
	else:
		state._world_defaults_seeded = (seeded_payload as Dictionary).duplicate(true)

	var map_payload: Variant = payload.get("map_world_state", {})
	if not map_payload is Dictionary:
		errors.append("map_world_state must be a dictionary")
	else:
		errors.append_array(state.map_world_state.load_payload(map_payload as Dictionary))

	state._refresh_reserved_weight()
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


static func _load_pressure_dictionary(
	state: GameState,
	source: Variant,
	errors: Array[String]
) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	out[GameState.PRESSURE_SUSPICION] = 0
	out[GameState.PRESSURE_SOLIDARITY] = 0
	out[GameState.PRESSURE_SCARCITY] = 0
	if not source is Dictionary:
		errors.append("pressures must be a dictionary")
		return out
	for key in source as Dictionary:
		var pressure_key := StringName(String(key))
		out[pressure_key] = clampi(int(source[key]), GameState.PRESSURE_MIN, GameState.PRESSURE_MAX)
	return out
