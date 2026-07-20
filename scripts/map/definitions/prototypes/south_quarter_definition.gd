class_name SouthQuarterDefinition
extends RefCounted

## Runtime adapter for the south-quarter .rrmap source.
## WHY: the southern lower-town prototype keeps a MapDefinition entry point while
## Rataskaev and Karja Gate adjacency remain reviewable as compact map data.


const RRMAP_PATH := "res://content/maps/south_quarter.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
