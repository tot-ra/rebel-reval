class_name RevalHarborDefinition
extends RefCounted

## Dev-traversal harbor suburbs authored in .rrmap. Viru road continues east from
## the Lower Town slice; Pikk street leads north to the quay and Great Coast Gate.


const RRMAP_PATH := "res://content/maps/reval_harbor_surroundings.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
