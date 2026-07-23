class_name TownHallDefinition
extends RefCounted

## Runtime adapter for the developer-only early Town Hall interior RRMap source.
## The scene and Map Alignment preview intentionally compile identical geometry.

const RRMAP_PATH := "res://content/maps/town_hall.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
