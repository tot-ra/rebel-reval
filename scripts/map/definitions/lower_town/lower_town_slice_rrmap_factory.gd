class_name LowerTownSliceRrmapFactory
extends RefCounted

## Loads the expanded Eastern Quarters blueprint from its reviewed .rrmap source.

const RRMAP_PATH := "res://content/maps/lower_town_slice.rrmap"


static func create() -> MapBlueprint:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return null
	return parsed.blueprint
