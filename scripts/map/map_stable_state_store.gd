class_name MapStableStateStore
extends RefCounted

## Versioned persistence boundary for chunked maps. Stable location/object IDs and
## global coordinates are authoritative; chunk ownership and scene nodes are
## deliberately excluded so repartitioning and unload/reload stay save-compatible.

const CURRENT_SAVE_VERSION := 2

var _save: Dictionary = {
	"save_version": CURRENT_SAVE_VERSION,
	"world_state": {},
}


func load_payload(
	payload: Dictionary,
	known_archetypes: Array[StringName] = [],
	expected_fingerprints: Dictionary = {}
) -> Array[String]:
	var errors: Array[String] = []
	var candidate: Dictionary = payload.duplicate(true)
	var version := int(candidate.get("save_version", candidate.get("version", 1)))
	if version < 1 or version > CURRENT_SAVE_VERSION:
		errors.append("unsupported map world-state save version %d (supported: 1-%d)" % [version, CURRENT_SAVE_VERSION])
		return errors

	if version == 1:
		# Version 1 had no chunk-aware world state. Preserve every existing field
		# and initialize only the new envelope rather than guessing scene-node state.
		candidate["world_state"] = {}
	elif not candidate.get("world_state", {}) is Dictionary:
		errors.append("world_state must be a dictionary")
		return errors

	candidate["save_version"] = CURRENT_SAVE_VERSION
	_validate_world_state(candidate["world_state"], known_archetypes, expected_fingerprints, errors)
	if errors.is_empty():
		_save = candidate
	return errors


func save_payload() -> Dictionary:
	var payload := _save.duplicate(true)
	payload["save_version"] = CURRENT_SAVE_VERSION
	return payload


func stable_handle(location_id: StringName, object_id: StringName) -> Dictionary:
	assert(not location_id.is_empty())
	assert(not object_id.is_empty())
	return {"location_id": String(location_id), "object_id": String(object_id)}


func record_entity(location_id: StringName, object_id: StringName, snapshot: Dictionary) -> bool:
	if location_id.is_empty() or object_id.is_empty() or not _valid_position(snapshot):
		return false
	var location := _ensure_location(location_id)
	var entities: Dictionary = location["entities"]
	var previous := entities.get(String(object_id), {}) as Dictionary
	var merged := _merge_preserving_unknown(previous, snapshot)
	# Runtime cache hints must never become save authority.
	merged.erase("chunk")
	merged.erase("owner_chunk")
	entities[String(object_id)] = merged
	return true


func entity_state(location_id: StringName, object_id: StringName) -> Dictionary:
	var location := _location(location_id)
	var entities := location.get("entities", {}) as Dictionary
	return (entities.get(String(object_id), {}) as Dictionary).duplicate(true)


func record_object_delta(location_id: StringName, object_id: StringName, delta: Dictionary) -> bool:
	if location_id.is_empty() or object_id.is_empty():
		return false
	var location := _ensure_location(location_id)
	var objects: Dictionary = location["objects"]
	var previous := objects.get(String(object_id), {}) as Dictionary
	var merged := _merge_preserving_unknown(previous, delta)
	merged.erase("chunk")
	merged.erase("owner_chunk")
	objects[String(object_id)] = merged
	return true


func object_delta(location_id: StringName, object_id: StringName) -> Dictionary:
	var location := _location(location_id)
	var objects := location.get("objects", {}) as Dictionary
	return (objects.get(String(object_id), {}) as Dictionary).duplicate(true)


func set_location_metadata(location_id: StringName, map_fingerprint: String, chunk_config_version: int = 0) -> void:
	var location := _ensure_location(location_id)
	location["map_fingerprint"] = map_fingerprint
	if chunk_config_version > 0:
		location["chunk_config_version"] = chunk_config_version


func canonical_text() -> String:
	return MapParitySnapshot.serialize_value(save_payload()) + "\n"


func _ensure_location(location_id: StringName) -> Dictionary:
	var world: Dictionary = _save["world_state"]
	var key := String(location_id)
	if not world.has(key) or not world[key] is Dictionary:
		world[key] = {}
	var location: Dictionary = world[key]
	if not location.get("entities", {}) is Dictionary:
		location["entities"] = {}
	elif not location.has("entities"):
		location["entities"] = {}
	if not location.get("objects", {}) is Dictionary:
		location["objects"] = {}
	elif not location.has("objects"):
		location["objects"] = {}
	return location


func _location(location_id: StringName) -> Dictionary:
	var world := _save.get("world_state", {}) as Dictionary
	return world.get(String(location_id), {}) as Dictionary


static func _validate_world_state(
	world_value: Variant,
	known_archetypes: Array[StringName],
	expected_fingerprints: Dictionary,
	errors: Array[String]
) -> void:
	if not world_value is Dictionary:
		errors.append("world_state must be a dictionary")
		return
	var known: Dictionary = {}
	for archetype in known_archetypes:
		known[String(archetype)] = true
	var world := world_value as Dictionary
	for location_key in world:
		var location_id := String(location_key)
		var location_value: Variant = world[location_key]
		if location_id.is_empty() or not location_value is Dictionary:
			errors.append("world_state locations must use non-empty IDs and dictionary values")
			continue
		var location := location_value as Dictionary
		if expected_fingerprints.has(location_id):
			var saved_fingerprint := String(location.get("map_fingerprint", ""))
			var expected := String(expected_fingerprints[location_id])
			if not saved_fingerprint.is_empty() and saved_fingerprint != expected:
				errors.append("map fingerprint mismatch for %s: save=%s current=%s" % [location_id, saved_fingerprint, expected])
		for collection_name in ["entities", "objects"]:
			var collection_value: Variant = location.get(collection_name, {})
			if not collection_value is Dictionary:
				errors.append("world_state.%s.%s must be a dictionary" % [location_id, collection_name])
				continue
			for object_key in collection_value:
				var object_id := String(object_key)
				var record_value: Variant = collection_value[object_key]
				if object_id.is_empty() or not record_value is Dictionary:
					errors.append("world_state.%s.%s records require stable IDs and dictionary values" % [location_id, collection_name])
					continue
				var record := record_value as Dictionary
				if record.has("chunk") or record.has("owner_chunk"):
					errors.append("world_state.%s.%s.%s must not persist chunk ownership" % [location_id, collection_name, object_id])
				if collection_name == "entities":
					if not _valid_position(record):
						errors.append("world_state.%s.entities.%s requires global_cell and sub_cell pairs" % [location_id, object_id])
					var archetype := String(record.get("archetype", ""))
					if not known.is_empty() and (archetype.is_empty() or not known.has(archetype)):
						errors.append("unknown archetype '%s' for %s/%s" % [archetype, location_id, object_id])


static func _valid_position(record: Dictionary) -> bool:
	var global_cell: Variant = record.get("global_cell")
	var sub_cell: Variant = record.get("sub_cell")
	if not global_cell is Array or not sub_cell is Array:
		return false
	if global_cell.size() != 2 or sub_cell.size() != 2:
		return false
	for value in global_cell:
		if not value is int and not value is float:
			return false
	for value in sub_cell:
		if not value is int and not value is float:
			return false
	return true


static func _merge_preserving_unknown(previous: Dictionary, incoming: Dictionary) -> Dictionary:
	var merged := previous.duplicate(true)
	for key in incoming:
		if merged.get(key) is Dictionary and incoming[key] is Dictionary:
			merged[key] = _merge_preserving_unknown(merged[key], incoming[key])
		else:
			merged[key] = incoming[key]
	return merged
