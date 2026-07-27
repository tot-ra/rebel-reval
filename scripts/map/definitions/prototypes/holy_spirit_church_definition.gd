class_name HolySpiritChurchDefinition
extends RefCounted

## Runtime adapter for the developer-only Holy Spirit Church interior RRMap.

const RRMAP_PATH := "res://content/maps/holy_spirit_church.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
