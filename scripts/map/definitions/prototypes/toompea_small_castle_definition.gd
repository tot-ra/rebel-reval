class_name ToompeaSmallCastleDefinition
extends RefCounted

## Runtime adapter for the developer-only Danish Small Castle interior RRMap.
## WHY: the interior is authored as a stable, inactive map package before a
## dedicated packed scene is activated; the source remains the single geometry
## contract for editor previews and runtime validation.

const RRMAP_PATH := "res://content/maps/toompea_small_castle.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
