class_name MapViewFaunaContext
extends RefCounted

## Maps retained outdoor map IDs to urban-fauna eligibility (P2-024). Penned
## livestock and wild-margin actors remain P0-106.

const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")

const URBAN_FAUNA_MAPS: Dictionary = {
	&"lower_town_slice": MammalSpecies.CONTEXT_LOWER_TOWN,
}


static func context_for_map(map_id: StringName) -> StringName:
	return StringName(URBAN_FAUNA_MAPS.get(map_id, &""))


static func supports_urban_fauna(map_id: StringName) -> bool:
	return URBAN_FAUNA_MAPS.has(map_id)
