class_name RevalHarborEastDefinition
extends RefCounted

## Dev-traversal Kalamaja fishing shore authored in .rrmap. The stable legacy map
## ID remains `reval_harbor_east`, but its only cityward link follows the shore to
## the Coastal Gate landing; the topologically false Viru road link is removed.


const RRMAP_PATH := "res://content/maps/reval_harbor_east.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
