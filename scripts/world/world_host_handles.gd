class_name WorldHostHandles
extends RefCounted
## Stable-handle discovery for mounted location packages, split out of WorldHost
## (R-1406). Pure functions over a node subtree.

## Entries {handle, key, node}. A `stable_handle` dictionary is location-scoped
## ({location_id, object_id}, the MapStableStateStore identity). A bare
## `stable_id` is a world-unique content id (for example `char.aita`), so it
## must exist at most once across every mounted location (ADR 0019 gate).
static func collect(package: Node, location_id: StringName) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	_collect_stable_handles(package, location_id, entries)
	return entries


static func _collect_stable_handles(
	node: Node, location_id: StringName, entries: Array[Dictionary]
) -> void:
	if node.has_meta(&"stable_handle"):
		var raw_handle: Variant = node.get_meta(&"stable_handle")
		if raw_handle is Dictionary:
			var handle := _normalize_handle(raw_handle as Dictionary, location_id)
			entries.append({"handle": handle, "key": handle_key(handle), "node": node})
	elif node.has_meta(&"stable_id"):
		var handle := _normalize_handle({"object_id": node.get_meta(&"stable_id")}, location_id)
		entries.append({"handle": handle, "key": world_key(handle), "node": node})
	for child in node.get_children():
		_collect_stable_handles(child, location_id, entries)


static func _normalize_handle(raw_handle: Dictionary, location_id: StringName) -> Dictionary:
	return {
		"location_id": String(raw_handle.get("location_id", location_id)),
		"object_id": String(raw_handle.get("object_id", "")),
	}


static func handle_key(handle: Dictionary) -> String:
	return "%s/%s" % [String(handle.get("location_id", "")), String(handle.get("object_id", ""))]


static func world_key(handle: Dictionary) -> String:
	return "*/%s" % String(handle.get("object_id", ""))
