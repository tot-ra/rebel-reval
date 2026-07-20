class_name RevalHarborEastDefinition
extends RefCounted

## Dev-traversal eastern harbour authored in .rrmap. Viru road arrives from the
## eastern Lower Town district, while a separate west-edge lane joins Trade Harbour.


const RRMAP_PATH := "res://content/maps/reval_harbor_east.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
