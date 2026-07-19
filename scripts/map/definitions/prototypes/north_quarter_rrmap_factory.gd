class_name NorthQuarterRrmapFactory
extends RefCounted

## Blueprint factory for the north-quarter .rrmap source.


const RRMAP_PATH := "res://content/maps/north_quarter.rrmap"


static func create() -> MapBlueprint:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return null
	return parsed.blueprint
