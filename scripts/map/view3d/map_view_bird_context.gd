class_name MapViewBirdContext
extends RefCounted

## Maps retained outdoor map IDs to the P0-117 bird habitat contexts used for
## spawn-weight selection. Penned livestock and urban mammals remain P0-106/P2-024.

const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")

const MAP_CONTEXTS: Dictionary = {
	&"lower_town_slice": BirdSpecies.CONTEXT_LOWER_TOWN,
	&"reval_harbor_north": BirdSpecies.CONTEXT_HARBOR,
	&"reval_harbor_east": BirdSpecies.CONTEXT_HARBOR,
	&"viru_gate_foreland": BirdSpecies.CONTEXT_FORELAND,
	&"market_civic_quarter": BirdSpecies.CONTEXT_MARKET,
	&"monastery_quarter": BirdSpecies.CONTEXT_MONASTERY,
	&"north_quarter": BirdSpecies.CONTEXT_MARKET,
	&"south_quarter": BirdSpecies.CONTEXT_LOWER_TOWN,
	&"toompea_quarter": BirdSpecies.CONTEXT_TOOMPEA,
	&"archbishops_garden": BirdSpecies.CONTEXT_GARDEN,
}


static func context_for_map(map_id: StringName) -> StringName:
	return StringName(MAP_CONTEXTS.get(map_id, &""))


static func has_ambient_bird_audio(map_id: StringName) -> bool:
	return not context_for_map(map_id).is_empty()
