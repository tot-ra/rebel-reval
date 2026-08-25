class_name GameStatePersistence
extends RefCounted

## Save/load serialization for GameState. Kept separate so runtime state accessors
## stay readable and persistence tests can evolve independently.


static func save_payload(state: GameState) -> Dictionary:
	var forged: Array[Dictionary] = []
	for record in state.get_forged_records():
		(
			forged
			. append(
				{
					"record_id": String(record.record_id),
					"commission_id": String(record.commission_id),
					"item_id": String(record.item_id),
					"modification_id": String(record.modification_id),
				}
			)
		)

	var commission_deadlines: Dictionary = {}
	for commission_id in state._commission_deadlines:
		commission_deadlines[String(commission_id)] = String(
			state._commission_deadlines[commission_id]
		)

	var placements: Array[Dictionary] = []
	for placement in state.bag.placements:
		(
			placements
			. append(
				{
					"item_id": String(placement.item_id),
					"grid_x": placement.grid_x,
					"grid_y": placement.grid_y,
					"quantity": placement.quantity,
				}
			)
		)

	return {
		"version": state.version,
		"phase": String(state.phase),
		"player":
		{
			"health": state.player.health,
			"max_health": state.player.max_health,
			"stamina": state.player.stamina,
			"max_stamina": state.player.max_stamina,
			"location_id": String(state.player.location_id),
			"spawn_id": String(state.player.spawn_id),
		},
		"bag":
		{
			"placements": placements,
		},
		"equipped": _string_dictionary(state._equipped),
		"equipped_forge_technique": String(state.equipped_forge_technique()),
		"facts": _bool_dictionary(state._facts),
		"flags": _bool_dictionary(state._flags),
		"relationships": _int_dictionary(state._relationships),
		"faction_events": _faction_events_array(state._faction_events),
		"pressures": _int_dictionary(state._pressures),
		"living_city": {
			"hope": state.get_living_city_hope(),
			"fear": state.get_living_city_fear(),
			"events": _living_city_events_dictionary(state._living_city_events),
		},
		"quest_states": _string_dictionary(state._quest_states),
		"location_states": _string_dictionary(state._location_states),
		"items": _bool_dictionary(state._items),
		"dialogue_nodes_seen": _bool_dictionary(state._dialogue_nodes_seen),
		"relationship_memories": _bool_dictionary(state._relationship_memories),
		"commission_deadlines": commission_deadlines,
		"forged_records": forged,
		"world_items": _world_items_dictionary(state._world_items),
		"world_defaults_seeded": state._world_defaults_seeded.duplicate(true),
		"map_world_state": state.save_map_world_state(),
		"act1_transition": state._act1_transition.duplicate(true),
	}


static func load_payload(state: GameState, payload: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not payload is Dictionary:
		return ["game state payload must be a dictionary"]

	var candidate := payload.duplicate(true)
	var schema_version := int(candidate.get("version", 0))
	if schema_version < 1 or schema_version > GameState.CURRENT_VERSION:
		errors.append(
			(
				"unsupported game-state version %d (supported: 1-%d)"
				% [schema_version, GameState.CURRENT_VERSION]
			)
		)
		return errors

	while schema_version < GameState.CURRENT_VERSION:
		match schema_version:
			1:
				candidate = GameState._migrate_v1_to_v2(candidate)
				schema_version = 2
			_:
				errors.append("no game-state migration available from version %d" % schema_version)
				return errors

	state.version = GameState.CURRENT_VERSION
	state.phase = StringName(String(candidate.get("phase", GameState.PHASE_PROLOGUE_DAY)))

	var player_payload: Variant = candidate.get("player", {})
	if not player_payload is Dictionary:
		errors.append("player must be a dictionary")
	else:
		var player_dict := player_payload as Dictionary
		state.player.health = float(player_dict.get("health", state.player.health))
		state.player.max_health = float(player_dict.get("max_health", state.player.max_health))
		state.player.stamina = float(player_dict.get("stamina", state.player.stamina))
		state.player.max_stamina = float(player_dict.get("max_stamina", state.player.max_stamina))
		state.player.location_id = StringName(
			String(player_dict.get("location_id", state.player.location_id))
		)
		state.player.spawn_id = StringName(
			String(player_dict.get("spawn_id", state.player.spawn_id))
		)

	var bag_payload: Variant = candidate.get("bag", {})
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

	state._equipped = _load_string_dictionary(candidate.get("equipped", {}), errors, "equipped")
	# Optional for older saves; empty means no technique equipped.
	var technique_raw := String(candidate.get("equipped_forge_technique", ""))
	if technique_raw.is_empty():
		state._equipped_forge_technique = &""
	elif not state.set_equipped_forge_technique(StringName(technique_raw)):
		errors.append("unsupported equipped_forge_technique %s" % technique_raw)
	state._facts = _load_bool_dictionary(candidate.get("facts", {}), errors, "facts")
	state._flags = _load_bool_dictionary(candidate.get("flags", {}), errors, "flags")
	state._relationships = _load_int_dictionary(
		candidate.get("relationships", {}), errors, "relationships"
	)
	state._faction_events = _load_faction_events(candidate.get("faction_events", []), errors)
	state._pressures = _load_pressure_dictionary(state, candidate.get("pressures", {}), errors)
	_load_living_city(state, candidate.get("living_city", {}), errors)
	state._quest_states = _load_string_dictionary(
		candidate.get("quest_states", {}), errors, "quest_states"
	)
	state._location_states = _load_string_dictionary(
		candidate.get("location_states", {}), errors, "location_states"
	)
	state._items = _load_bool_dictionary(candidate.get("items", {}), errors, "items")
	state._dialogue_nodes_seen = _load_bool_dictionary(
		candidate.get("dialogue_nodes_seen", {}), errors, "dialogue_nodes_seen"
	)
	state._relationship_memories = _load_bool_dictionary(
		candidate.get("relationship_memories", {}), errors, "relationship_memories"
	)
	state._commission_deadlines = _load_string_dictionary(
		candidate.get("commission_deadlines", {}), errors, "commission_deadlines"
	)

	state._forged_records.clear()
	var forged_rows: Variant = candidate.get("forged_records", [])
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

	var world_items_payload: Variant = candidate.get("world_items", {})
	if not world_items_payload is Dictionary:
		errors.append("world_items must be a dictionary")
	else:
		# WHY: JSON fixtures encode Vector2 as {"x":..,"y":..}; normalize on load
		# so WorldItemController never sees a Dictionary where Vector2 is required.
		state._world_items = _normalize_world_items(world_items_payload as Dictionary)

	var seeded_payload: Variant = candidate.get("world_defaults_seeded", {})
	if not seeded_payload is Dictionary:
		errors.append("world_defaults_seeded must be a dictionary")
	else:
		state._world_defaults_seeded = (seeded_payload as Dictionary).duplicate(true)

	var map_payload: Variant = candidate.get("map_world_state", {})
	if not map_payload is Dictionary:
		errors.append("map_world_state must be a dictionary")
	else:
		errors.append_array(state.map_world_state.load_payload(map_payload as Dictionary))

	var act1_payload: Variant = candidate.get("act1_transition", {})
	if act1_payload == null:
		state._act1_transition = {}
	elif not act1_payload is Dictionary:
		errors.append("act1_transition must be a dictionary")
	else:
		state._act1_transition = (act1_payload as Dictionary).duplicate(true)

	state._refresh_reserved_weight()
	return errors


static func _faction_events_array(source: Dictionary[StringName, Dictionary]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for event_id in source.keys():
		var event: Dictionary = source[event_id]
		(
			rows
			. append(
				{
					"event_id": String(event_id),
					"faction_id": String(event.get("faction_id", "")),
					"delta": int(event.get("delta", 0)),
					"summary": String(event.get("summary", "")),
				}
			)
		)
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("event_id", "")) < String(b.get("event_id", ""))
	)
	return rows


static func _load_faction_events(
	source: Variant, errors: Array[String]
) -> Dictionary[StringName, Dictionary]:
	var out: Dictionary[StringName, Dictionary] = {}
	if source == null:
		return out
	if not source is Array:
		errors.append("faction_events must be an array")
		return out
	for index in (source as Array).size():
		var row: Variant = (source as Array)[index]
		if not row is Dictionary:
			errors.append("faction_events[%d] must be a dictionary" % index)
			continue
		var event_dict := row as Dictionary
		var event_id := StringName(String(event_dict.get("event_id", "")))
		var faction_id := StringName(String(event_dict.get("faction_id", "")))
		if event_id.is_empty():
			errors.append("faction_events[%d] missing event_id" % index)
			continue
		if not FactionCandidateSeats.is_recordable_faction(faction_id):
			errors.append(
				"faction_events[%d] uses unknown faction %s" % [index, String(faction_id)]
			)
			continue
		if out.has(event_id):
			errors.append("duplicate faction event id %s" % String(event_id))
			continue
		out[event_id] = {
			"event_id": event_id,
			"faction_id": faction_id,
			"delta":
			clampi(
				int(event_dict.get("delta", 0)),
				FactionLedger.STANDING_MIN,
				FactionLedger.STANDING_MAX
			),
			"summary": String(event_dict.get("summary", "")),
		}
	return out


static func _living_city_events_dictionary(
	source: Dictionary[StringName, Dictionary]
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for event_id in source.keys():
		var event: Dictionary = source[event_id]
		rows.append({
			"event_id": String(event_id),
			"hope_delta": int(event.get("hope_delta", 0)),
			"fear_delta": int(event.get("fear_delta", 0)),
			"summary": String(event.get("summary", "")),
		})
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("event_id", "")) < String(b.get("event_id", ""))
	)
	return rows


static func _load_living_city(state: GameState, source: Variant, errors: Array[String]) -> void:
	state._living_city_events.clear()
	state.set_living_city_meter(GameState.LIVING_CITY_HOPE, GameState.LIVING_CITY_DEFAULT)
	state.set_living_city_meter(GameState.LIVING_CITY_FEAR, GameState.LIVING_CITY_DEFAULT)
	if source == null:
		return
	if not source is Dictionary:
		errors.append("living_city must be a dictionary")
		return
	var living_city := source as Dictionary
	state.set_living_city_meter(
		GameState.LIVING_CITY_HOPE, int(living_city.get("hope", GameState.LIVING_CITY_DEFAULT))
	)
	state.set_living_city_meter(
		GameState.LIVING_CITY_FEAR, int(living_city.get("fear", GameState.LIVING_CITY_DEFAULT))
	)
	var events: Variant = living_city.get("events", [])
	if not events is Array:
		errors.append("living_city.events must be an array")
		return
	for index in (events as Array).size():
		var row: Variant = (events as Array)[index]
		if not row is Dictionary:
			errors.append("living_city.events[%d] must be a dictionary" % index)
			continue
		var event := row as Dictionary
		var event_id := StringName(String(event.get("event_id", "")))
		var hope_delta := int(event.get("hope_delta", 0))
		var fear_delta := int(event.get("fear_delta", 0))
		if event_id.is_empty() or not String(event_id).begins_with("living."):
			errors.append("living_city.events[%d] has invalid event_id" % index)
			continue
		if state._living_city_events.has(event_id):
			errors.append("duplicate living city event id %s" % String(event_id))
			continue
		if (
			(hope_delta == 0 and fear_delta == 0)
			or hope_delta < GameState.LIVING_CITY_DELTA_MIN
			or hope_delta > GameState.LIVING_CITY_DELTA_MAX
			or fear_delta < GameState.LIVING_CITY_DELTA_MIN
			or fear_delta > GameState.LIVING_CITY_DELTA_MAX
		):
			errors.append("living_city.events[%d] delta is outside -5..5 or is zero" % index)
			continue
		state._living_city_events[event_id] = {
			"event_id": event_id,
			"hope_delta": hope_delta,
			"fear_delta": fear_delta,
			"summary": String(event.get("summary", "")),
		}


static func _string_dictionary(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in source:
		out[String(key)] = String(source[key])
	return out


## JSON.stringify does not preserve Vector2, so save positions as explicit
## coordinates and let _normalize_world_items reconstruct runtime vectors.
static func _world_items_dictionary(source: Dictionary) -> Dictionary:
	var out: Dictionary = source.duplicate(true)
	for location_key in out:
		var bucket_variant: Variant = out[location_key]
		if not bucket_variant is Dictionary:
			continue
		for object_key in bucket_variant as Dictionary:
			var record_variant: Variant = (bucket_variant as Dictionary)[object_key]
			if not record_variant is Dictionary:
				continue
			var record := record_variant as Dictionary
			var position: Variant = record.get("position", Vector2.ZERO)
			if position is Vector2:
				record["position"] = {"x": position.x, "y": position.y}
	return out


## Convert JSON-shaped world item positions into Vector2 for runtime consumers.
static func _normalize_world_items(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for location_key in source:
		var bucket_variant: Variant = source[location_key]
		if not bucket_variant is Dictionary:
			out[String(location_key)] = bucket_variant
			continue
		var normalized_bucket: Dictionary = {}
		for object_key in bucket_variant as Dictionary:
			var record_variant: Variant = (bucket_variant as Dictionary)[object_key]
			if not record_variant is Dictionary:
				normalized_bucket[String(object_key)] = record_variant
				continue
			var record := (record_variant as Dictionary).duplicate(true)
			record["position"] = _coerce_vector2(record.get("position", Vector2.ZERO))
			normalized_bucket[String(object_key)] = record
		out[String(location_key)] = normalized_bucket
	return out


static func _coerce_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		var as_dict := value as Dictionary
		return Vector2(float(as_dict.get("x", 0.0)), float(as_dict.get("y", 0.0)))
	return Vector2.ZERO


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
	source: Variant, errors: Array[String], label: String
) -> Dictionary[StringName, StringName]:
	var out: Dictionary[StringName, StringName] = {}
	if not source is Dictionary:
		errors.append("%s must be a dictionary" % label)
		return out
	for key in source as Dictionary:
		out[StringName(String(key))] = StringName(String(source[key]))
	return out


static func _load_bool_dictionary(
	source: Variant, errors: Array[String], label: String
) -> Dictionary[StringName, bool]:
	var out: Dictionary[StringName, bool] = {}
	if not source is Dictionary:
		errors.append("%s must be a dictionary" % label)
		return out
	for key in source as Dictionary:
		out[StringName(String(key))] = bool(source[key])
	return out


static func _load_int_dictionary(
	source: Variant, errors: Array[String], label: String
) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	if not source is Dictionary:
		errors.append("%s must be a dictionary" % label)
		return out
	for key in source as Dictionary:
		out[StringName(String(key))] = int(source[key])
	return out


static func _load_pressure_dictionary(
	_state: GameState, source: Variant, errors: Array[String]
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
