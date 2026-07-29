class_name KalevSmithyDefinition
extends RefCounted

## Production interior for Kalev's forge (P2-018).
## WHY: gameplay scenes keep a MapDefinition entry point while authoring lives in .rrmap.


const RRMAP_PATH := "res://content/maps/kalev_smithy.rrmap"
const WearDecals := preload("res://scripts/map/definitions/lower_town/map_wear_decals.gd")


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	var definition: MapDefinition = parsed.definition
	# P0-161: view-only wear stains; .rrmap lacks a decal statement so far.
	WearDecals.apply_kalev_smithy(definition)
	return definition
