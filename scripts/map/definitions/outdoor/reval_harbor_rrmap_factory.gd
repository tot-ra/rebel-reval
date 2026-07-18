class_name RevalHarborRrmapFactory
extends RefCounted

## Blueprint factory for editor preview of the harbor .rrmap source.


const RRMAP_PATH := "res://content/maps/reval_harbor_surroundings.rrmap"


static func create() -> MapBlueprint:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return null
	return parsed.blueprint
