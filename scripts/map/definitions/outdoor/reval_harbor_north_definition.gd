class_name RevalHarborNorthDefinition
extends RefCounted

## Dev-traversal northern harbour authored in .rrmap. Pikk Street exits through
## the Great Coast Gate to this map, with an eastward connection to the Viru road
## harbour foreland.


const RRMAP_PATH := "res://content/maps/reval_harbor_north.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
