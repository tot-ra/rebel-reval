class_name RevalHarborEastRrmapFactory
extends RefCounted

## Blueprint factory for editor preview of the Kalamaja fishing-shore .rrmap source.


const RRMAP_PATH := "res://content/maps/reval_harbor_east.rrmap"


static func create() -> MapBlueprint:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return null
	return parsed.blueprint
