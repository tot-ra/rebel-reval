class_name RevalHarborNorthDefinition
extends RefCounted

## Dev-traversal Coastal Gate merchant landing authored in .rrmap. Pikk Street
## descends to the shore here; the west-edge seam continues into Kalamaja's fishing
## shore while the east side remains open Tallinn Bay.


const RRMAP_PATH := "res://content/maps/reval_harbor_north.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
