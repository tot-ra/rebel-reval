class_name MapWearDecals
extends RefCounted

## P0-161: authored soot/mud/grime/wet_threshold placements for prototype maps.
## WHY: view-only wear stains live on MapDefinition.decals. Production `.rrmap`
## sources (`kalev_smithy`, `lower_town_slice`) now declare `decal` lines; this
## helper remains for the hand-authored `smithy_courtyard` prototype factory.


static func apply_smithy_courtyard(definition: MapDefinition) -> void:
	# Prototype yard: forge-pad soot plus lane/threshold mud matching P0-161 intent.
	definition.decals = [
		_cell(
			definition, &"decal.soot_forge_pad", MapTypes.DECAL_KIND_SOOT, Rect2i(14, 13, 8, 5), 2.0
		),
		_cell(
			definition,
			&"decal.mud_lane_threshold",
			MapTypes.DECAL_KIND_MUD,
			Rect2i(18, 5, 6, 1),
			1.4
		),
		_cell(
			definition,
			&"decal.wet_well",
			MapTypes.DECAL_KIND_WET_THRESHOLD,
			Rect2i(31, 18, 4, 3),
			1.5
		),
		_cell(
			definition, &"decal.grime_hay_edge", MapTypes.DECAL_KIND_GRIME, Rect2i(5, 11, 7, 2), 1.2
		),
	]


static func _cell(
	definition: MapDefinition, id: StringName, kind: StringName, cell_rect: Rect2i, radius: float
) -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"position": definition.cell_rect_center(cell_rect),
		"radius": radius,
	}
