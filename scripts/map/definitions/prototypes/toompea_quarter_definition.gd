class_name ToompeaQuarterDefinition
extends RefCounted

## Runtime adapter for the Toompea-quarter .rrmap source.
## WHY: the hilltop district keeps a MapDefinition entry point while layout and
## reciprocal Lühike Jalg edges remain reviewable as compact map data.


const RRMAP_PATH := "res://content/maps/toompea_quarter.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
