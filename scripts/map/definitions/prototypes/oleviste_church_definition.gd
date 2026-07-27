class_name OlevisteChurchDefinition
extends RefCounted

## Runtime adapter for the developer-only St. Olaf's Church interior RRMap source.

const RRMAP_PATH := "res://content/maps/oleviste_church.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
