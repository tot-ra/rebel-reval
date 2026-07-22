class_name ViruGateForelandDefinition
extends RefCounted

## Runtime adapter for the Pirita River crossing .rrmap source. The legacy file ID is stable for saves/transitions.


const RRMAP_PATH := "res://content/maps/viru_gate_foreland.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
