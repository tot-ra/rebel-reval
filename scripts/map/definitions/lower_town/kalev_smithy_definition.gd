class_name KalevSmithyDefinition
extends RefCounted

## Production interior for Kalev's forge (P2-018).
## WHY: gameplay scenes keep a MapDefinition entry point while authoring lives in .rrmap.


const RRMAP_PATH := "res://content/maps/kalev_smithy.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
