class_name MapViewFaunaContext
extends RefCounted

## Maps retained outdoor map IDs to fauna eligibility. Urban mammals are P2-024;
## penned livestock and wild-margin actors are P0-106.

const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")

const URBAN_FAUNA_MAPS: Dictionary = {
	&"lower_town_slice": MammalSpecies.CONTEXT_LOWER_TOWN,
	&"south_quarter": MammalSpecies.CONTEXT_LOWER_TOWN,
}

const PENNED_FAUNA_MAPS: Dictionary = {
	&"lower_town_slice": MammalSpecies.CONTEXT_LOWER_TOWN,
	&"viru_gate_foreland": MammalSpecies.CONTEXT_FORELAND,
	&"north_quarter": MammalSpecies.CONTEXT_MARKET,
}


static func context_for_map(map_id: StringName) -> StringName:
	if URBAN_FAUNA_MAPS.has(map_id):
		return StringName(URBAN_FAUNA_MAPS[map_id])
	return StringName(PENNED_FAUNA_MAPS.get(map_id, &""))


static func supports_urban_fauna(map_id: StringName) -> bool:
	return URBAN_FAUNA_MAPS.has(map_id)


static func supports_penned_fauna(map_id: StringName) -> bool:
	return PENNED_FAUNA_MAPS.has(map_id)
