class_name NunnatornInteriorRrmapFactory
extends RefCounted

## Blueprint factory for the developer-only Nunnatorn interior RRMap source.

const RRMAP_PATH := "res://content/maps/nunnatorn_interior.rrmap"


static func create() -> MapBlueprint:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return null
	return parsed.blueprint
