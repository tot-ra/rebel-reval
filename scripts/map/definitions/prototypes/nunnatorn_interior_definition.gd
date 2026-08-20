class_name NunnatornInteriorDefinition
extends RefCounted

## Runtime adapter for the developer-only Nunnatorn interior RRMap source.

const RRMAP_PATH := "res://content/maps/nunnatorn_interior.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
