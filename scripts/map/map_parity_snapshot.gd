class_name MapParitySnapshot
extends RefCounted

## Canonical, reviewable serialization of the runtime MapDefinition contract.
## WHY: authoring migrations may reorder dictionaries or emit floats differently
## without changing gameplay. This serializer normalizes those representation
## details while retaining every runtime field and built-grid behavior.

const FORMAT_VERSION := 1
const FLOAT_DECIMALS := 9


static func serialize(definition: MapDefinition, grid: MapTerrainGrid) -> String:
	var snapshot := {
		"format_version": FORMAT_VERSION,
		"metadata": {
			"active": definition.active,
			"base_terrain": definition.base_terrain,
			"camera_bounds": definition.camera_bounds,
			"cell_size": definition.cell_size,
			"location": definition.location,
			"map_id": definition.map_id,
			"palette": definition.palette,
			"player_spawn": definition.player_spawn,
			"scope": definition.scope,
			"seed": definition.seed,
			"size_cells": definition.size_cells,
		},
		"terrain": {
			"terrain_id_grid_sha256": terrain_grid_fingerprint(grid),
			"used_terrain_ids": _sorted_strings(grid.used_terrain_ids()),
		},
		"buildings": _sorted_id_records(definition.buildings),
		"props": _sorted_id_records(definition.props),
		"anchors": _sorted_id_records(definition.interaction_anchors),
		"transitions": _sorted_id_records(definition.transitions),
		"patrols": _sorted_records(definition.patrols),
		"landmarks": _sorted_id_records(definition.view_landmarks),
		"signs": _sorted_records(definition.direction_signs),
		"exclusions": _sorted_records(definition.excluded_areas),
		"fade_volumes": _sorted_records(definition.fade_volumes),
		"source_references": _sorted_strings(definition.source_references),
		"surroundings_town_sides": _sorted_strings(definition.surroundings_town_sides),
		"navigation": _navigation_snapshot(definition, grid),
	}
	return serialize_value(snapshot) + "\n"


static func serialize_value(value: Variant) -> String:
	return _serialize_value(value, 0)


static func terrain_grid_fingerprint(grid: MapTerrainGrid) -> String:
	var cells := PackedStringArray()
	cells.append("%d,%d" % [grid.size_cells.x, grid.size_cells.y])
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			var terrain := String(grid.get_terrain(Vector2i(x, y)))
			# Length-prefixing makes the hash input unambiguous even if IDs later
			# contain separator characters.
			cells.append("%d:%s" % [terrain.length(), terrain])
	return _sha256("|".join(cells))


static func first_difference(expected: String, actual: String) -> String:
	var expected_lines := expected.split("\n")
	var actual_lines := actual.split("\n")
	var shared_count := mini(expected_lines.size(), actual_lines.size())
	for index in shared_count:
		if expected_lines[index] != actual_lines[index]:
			return "line %d\nexpected: %s\nactual:   %s" % [
				index + 1,
				expected_lines[index],
				actual_lines[index],
			]
	if expected_lines.size() != actual_lines.size():
		return "line count differs: expected %d, actual %d" % [expected_lines.size(), actual_lines.size()]
	return "no textual difference"


static func _navigation_snapshot(definition: MapDefinition, grid: MapTerrainGrid) -> Dictionary:
	var blocked := MapVerification.blocked_cells(definition)
	var walkability := PackedByteArray()
	walkability.resize(definition.size_cells.x * definition.size_cells.y)
	var walkable_count := 0
	for y in definition.size_cells.y:
		for x in definition.size_cells.x:
			var cell := Vector2i(x, y)
			var walkable := not MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell)) and not blocked.has(cell)
			var index := y * definition.size_cells.x + x
			walkability[index] = 1 if walkable else 0
			if walkable:
				walkable_count += 1
	return {
		"walkability_sha256": _sha256(walkability.hex_encode()),
		"walkable_cell_count": walkable_count,
	}


static func _sorted_id_records(source: Array[Dictionary]) -> Array:
	var records: Array = []
	for record in source:
		records.append(record)
	records.sort_custom(_compare_id_records)
	return records


static func _sorted_records(source: Array) -> Array:
	var records := source.duplicate()
	records.sort_custom(_compare_canonical_values)
	return records


static func _sorted_strings(source: Array) -> Array[String]:
	var values: Array[String] = []
	for value in source:
		values.append(String(value))
	values.sort()
	return values


static func _compare_id_records(left: Dictionary, right: Dictionary) -> bool:
	var left_id := String(left.get("id", ""))
	var right_id := String(right.get("id", ""))
	if left_id == right_id:
		return serialize_value(left) < serialize_value(right)
	return left_id < right_id


static func _compare_canonical_values(left: Variant, right: Variant) -> bool:
	return serialize_value(left) < serialize_value(right)


static func _serialize_value(value: Variant, depth: int) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return _format_float(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(String(value))
		TYPE_VECTOR2:
			return _serialize_value([value.x, value.y], depth)
		TYPE_VECTOR2I:
			return _serialize_value([value.x, value.y], depth)
		TYPE_RECT2:
			return _serialize_value([value.position.x, value.position.y, value.size.x, value.size.y], depth)
		TYPE_RECT2I:
			return _serialize_value([value.position.x, value.position.y, value.size.x, value.size.y], depth)
		TYPE_COLOR:
			return _serialize_value([value.r, value.g, value.b, value.a], depth)
		TYPE_ARRAY:
			return _serialize_array(value, depth)
		TYPE_DICTIONARY:
			return _serialize_dictionary(value, depth)
		_:
			push_error("MapParitySnapshot cannot serialize Variant type %d" % typeof(value))
			return JSON.stringify(str(value))


static func _serialize_array(values: Array, depth: int) -> String:
	if values.is_empty():
		return "[]"
	var lines: Array[String] = ["["]
	for index in values.size():
		var suffix := "," if index < values.size() - 1 else ""
		lines.append("%s%s%s" % [_indent(depth + 1), _serialize_value(values[index], depth + 1), suffix])
	lines.append(_indent(depth) + "]")
	return "\n".join(lines)


static func _serialize_dictionary(values: Dictionary, depth: int) -> String:
	if values.is_empty():
		return "{}"
	var keys := values.keys()
	keys.sort_custom(_compare_dictionary_keys)
	var lines: Array[String] = ["{"]
	for index in keys.size():
		var key: Variant = keys[index]
		var suffix := "," if index < keys.size() - 1 else ""
		lines.append("%s%s: %s%s" % [
			_indent(depth + 1),
			JSON.stringify(String(key)),
			_serialize_value(values[key], depth + 1),
			suffix,
		])
	lines.append(_indent(depth) + "}")
	return "\n".join(lines)


static func _compare_dictionary_keys(left: Variant, right: Variant) -> bool:
	return String(left) < String(right)


static func _format_float(value: float) -> String:
	if value == 0.0:
		return "0." + "0".repeat(FLOAT_DECIMALS)
	return ("%%.%df" % FLOAT_DECIMALS) % value


static func _indent(depth: int) -> String:
	return "  ".repeat(depth)


static func _sha256(text: String) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(text.to_utf8_buffer())
	return hashing.finish().hex_encode()
