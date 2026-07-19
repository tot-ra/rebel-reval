class_name NorthQuarterDefinition
extends RefCounted

## Runtime adapter for the north-quarter .rrmap source.
## WHY: gameplay scenes keep a MapDefinition entry point while map authoring lives in .rrmap.


const RRMAP_PATH := "res://content/maps/north_quarter.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
