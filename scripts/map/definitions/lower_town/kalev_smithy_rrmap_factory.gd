class_name KalevSmithyRrmapFactory
extends RefCounted

## Loads Kalev's forge from the reviewed .rrmap source (P2-018).


const RRMAP_PATH := "res://content/maps/kalev_smithy.rrmap"


static func create() -> MapBlueprint:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return null
	return parsed.blueprint
