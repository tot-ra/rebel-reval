class_name SmithyRoutineDefinition
extends RefCounted

## Loads authored smithy activity points and per-actor schedules from JSON (P2-058).

const DEFAULT_PATH := "res://content/routines/kalev_smithy.json"

var map_id: StringName = &""
var activity_points: Dictionary = {}
var schedules: Dictionary = {}
var visitor_sequences: Dictionary = {}


static func load_from_file(path: String = DEFAULT_PATH) -> SmithyRoutineDefinition:
	var definition := SmithyRoutineDefinition.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SmithyRoutineDefinition: cannot open %s" % path)
		return definition
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		definition.load_from_dict(parsed)
	else:
		push_error("SmithyRoutineDefinition: invalid JSON in %s" % path)
	return definition


func load_from_dict(data: Dictionary) -> void:
	map_id = StringName(str(data.get("map_id", "")))
	activity_points.clear()
	for entry in data.get("activity_points", []):
		if entry is Dictionary:
			var point := SmithyActivityPoint.from_dict(entry)
			if not point.id.is_empty():
				activity_points[point.id] = point
	schedules = _parse_nested_sequences(data.get("schedules", {}))
	visitor_sequences = _parse_nested_sequences(data.get("visitor_sequences", {}))


func get_activity_point(activity_id: StringName) -> SmithyActivityPoint:
	return activity_points.get(activity_id) as SmithyActivityPoint


func schedule_for(actor_id: StringName, phase_id: StringName, time_band: StringName) -> Array[StringName]:
	var actor_schedules: Variant = schedules.get(actor_id, {})
	if actor_schedules is Dictionary:
		var phase_schedules: Variant = actor_schedules.get(phase_id, {})
		if phase_schedules is Dictionary:
			if phase_schedules.has(time_band):
				return _to_string_name_array(phase_schedules[time_band])
			var band_text := str(time_band)
			if phase_schedules.has(band_text):
				return _to_string_name_array(phase_schedules[band_text])
			if phase_schedules.has(&"any"):
				return _to_string_name_array(phase_schedules[&"any"])
			return _to_string_name_array(phase_schedules.get("any", []))
	return []


func visitor_sequence_for(actor_id: StringName, phase_id: StringName) -> Array[StringName]:
	var actor_sequences: Variant = visitor_sequences.get(actor_id, {})
	if actor_sequences is Dictionary:
		return _to_string_name_array(actor_sequences.get(phase_id, []))
	return []


func all_activity_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in activity_points.keys():
		ids.append(key)
	ids.sort()
	return ids


static func _parse_nested_sequences(value: Variant) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for actor_key in value.keys():
			var actor_id := StringName(str(actor_key))
			result[actor_id] = {}
			var actor_value: Variant = value[actor_key]
			if actor_value is Dictionary:
				for phase_key in actor_value.keys():
					var phase_id := StringName(str(phase_key))
					var phase_value: Variant = actor_value[phase_key]
					if phase_value is Array:
						result[actor_id][phase_id] = _to_string_name_array(phase_value)
					elif phase_value is Dictionary:
						var bands := {}
						for band_key in phase_value.keys():
							bands[StringName(str(band_key))] = _to_string_name_array(phase_value[band_key])
						result[actor_id][phase_id] = bands
	return result


static func _to_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for entry in value:
			result.append(StringName(str(entry)))
	return result
