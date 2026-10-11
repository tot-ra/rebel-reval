class_name MapViewInsectContext
extends RefCounted

## Maps outdoor map IDs to insect (Orthoptera) habitat contexts. Only green /
## rural maps appear here: the stone town core (harbour, market, paved streets,
## Toompea) is intentionally absent, so insect ambience stays silent in the city.
## Interior maps are gated separately by MapDefinition.suppresses_exterior_surroundings().

const InsectSpecies := preload("res://scripts/map/view3d/map_view_insect_species.gd")

const MAP_CONTEXTS: Dictionary = {
	&"viru_gate_foreland": InsectSpecies.CONTEXT_MEADOW,
	&"archbishops_garden": InsectSpecies.CONTEXT_GARDEN,
	&"monastery_quarter": InsectSpecies.CONTEXT_GARDEN,
}


static func context_for_map(map_id: StringName) -> StringName:
	return StringName(MAP_CONTEXTS.get(map_id, &""))


static func has_ambient_insect_audio(map_id: StringName) -> bool:
	return not context_for_map(map_id).is_empty()
