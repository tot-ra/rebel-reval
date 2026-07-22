class_name StOlafsGuildHallDefinition
extends RefCounted

## Runtime adapter for the developer-only guild hall RRMap source.
## Map Alignment and scene assembly intentionally compile the same geometry.

const RRMAP_PATH := "res://content/maps/st_olafs_guild_hall.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition
