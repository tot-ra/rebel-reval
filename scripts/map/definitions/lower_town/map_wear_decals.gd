class_name MapWearDecals
extends RefCounted

## P0-161: authored soot/mud/grime/wet_threshold placements for slice maps.
## WHY: view-only wear stains live on MapDefinition.decals; .rrmap has no decal
## statement yet, so production adapters append these after compile without
## touching collision, navigation, or parity fingerprints.


static func apply_kalev_smithy(definition: MapDefinition) -> void:
	# Forge pad soot, living/work thresholds, and door mud only - no blood/scorch.
	definition.decals = [
		_cell(definition, &"decal.soot_furnace_pad", MapTypes.DECAL_KIND_SOOT, Rect2i(19, 1, 3, 3), 1.8),
		_cell(definition, &"decal.soot_anvil_apron", MapTypes.DECAL_KIND_SOOT, Rect2i(18, 5, 3, 2), 1.4),
		_cell(definition, &"decal.grime_quench", MapTypes.DECAL_KIND_GRIME, Rect2i(16, 5, 2, 2), 1.1),
		_cell(definition, &"decal.wet_wash_corner", MapTypes.DECAL_KIND_WET_THRESHOLD, Rect2i(11, 1, 1, 1), 1.0),
		_cell(definition, &"decal.mud_courtyard_door", MapTypes.DECAL_KIND_MUD, Rect2i(12, 13, 2, 1), 1.3),
		_cell(definition, &"decal.wet_courtyard_door", MapTypes.DECAL_KIND_WET_THRESHOLD, Rect2i(12, 12, 2, 1), 1.0),
		_cell(definition, &"decal.grime_bay_divider", MapTypes.DECAL_KIND_GRIME, Rect2i(14, 7, 1, 2), 1.0),
	]


static func apply_lower_town_slice(definition: MapDefinition) -> void:
	# Door thresholds, smithy yard corners, cistern splash, and restrained street mud.
	definition.decals = [
		_cell(definition, &"decal.mud_smithy_door", MapTypes.DECAL_KIND_MUD, Rect2i(88, 73, 2, 1), 1.4),
		_cell(definition, &"decal.wet_smithy_door", MapTypes.DECAL_KIND_WET_THRESHOLD, Rect2i(88, 74, 2, 1), 1.1),
		_cell(definition, &"decal.grime_hay_corner", MapTypes.DECAL_KIND_GRIME, Rect2i(86, 76, 2, 2), 1.2),
		_cell(definition, &"decal.mud_quench_apron", MapTypes.DECAL_KIND_MUD, Rect2i(98, 76, 1, 1), 1.0),
		_cell(definition, &"decal.soot_courtyard_anvil", MapTypes.DECAL_KIND_SOOT, Rect2i(97, 65, 2, 2), 1.3),
		_cell(definition, &"decal.mud_brewery_door", MapTypes.DECAL_KIND_MUD, Rect2i(78, 60, 2, 1), 1.3),
		_cell(definition, &"decal.wet_cistern", MapTypes.DECAL_KIND_WET_THRESHOLD, Rect2i(104, 60, 2, 2), 1.4),
		_cell(definition, &"decal.grime_yard_cart", MapTypes.DECAL_KIND_GRIME, Rect2i(79, 84, 2, 2), 1.1),
		_cell(definition, &"decal.mud_checkpoint_east", MapTypes.DECAL_KIND_MUD, Rect2i(109, 51, 2, 2), 1.2),
		_cell(definition, &"decal.mud_street_start", MapTypes.DECAL_KIND_MUD, Rect2i(83, 54, 2, 2), 1.0),
	]


static func apply_smithy_courtyard(definition: MapDefinition) -> void:
	# Prototype yard: forge-pad soot plus lane/threshold mud matching P0-161 intent.
	definition.decals = [
		_cell(definition, &"decal.soot_forge_pad", MapTypes.DECAL_KIND_SOOT, Rect2i(14, 13, 8, 5), 2.0),
		_cell(definition, &"decal.mud_lane_threshold", MapTypes.DECAL_KIND_MUD, Rect2i(18, 5, 6, 1), 1.4),
		_cell(definition, &"decal.wet_well", MapTypes.DECAL_KIND_WET_THRESHOLD, Rect2i(31, 18, 4, 3), 1.5),
		_cell(definition, &"decal.grime_hay_edge", MapTypes.DECAL_KIND_GRIME, Rect2i(5, 11, 7, 2), 1.2),
	]


static func _cell(
	definition: MapDefinition,
	id: StringName,
	kind: StringName,
	cell_rect: Rect2i,
	radius: float
) -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"position": definition.cell_rect_center(cell_rect),
		"radius": radius,
	}
