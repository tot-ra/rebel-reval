class_name ArchbishopsGardenDefinition
extends RefCounted

## Runtime adapter for the Archbishop's Garden .rrmap source.

const RRMAP_PATH := "res://content/maps/archbishops_garden.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
