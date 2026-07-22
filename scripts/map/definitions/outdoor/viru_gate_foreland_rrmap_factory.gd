class_name ViruGateForelandRrmapFactory
extends RefCounted

## Blueprint factory for editor preview of Pirita. The legacy file ID is stable for saves/transitions.


const RRMAP_PATH := "res://content/maps/viru_gate_foreland.rrmap"


static func create() -> MapBlueprint:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return null
	return parsed.blueprint
