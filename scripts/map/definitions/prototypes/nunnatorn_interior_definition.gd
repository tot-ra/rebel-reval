class_name NunnatornInteriorDefinition
extends RefCounted

## Runtime adapter for the developer-only Nunnatorn interior RRMap source.

const RRMAP_PATH := "res://content/maps/nunnatorn_interior.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition


## Shared R-270 package descriptor consumed by the generic tower contract test.
## The map source remains authoritative for geometry; this table binds its stable
## route, encounter, reward, and persistence IDs into one reviewable package.
static func enterable_tower_contract() -> Dictionary:
	return {
		"tower_id": "nunnatorn",
		"exterior_map_id": "monastery_quarter",
		"exterior_scene_id": "reval_monastery",
		"exterior_building_id": "monastery_wall_tower_northwest",
		"interior_map_id": "nunnatorn_interior",
		"exterior_return_spawn": "monastery_wall_tower_northwest_return",
		"interior_entry_spawn": "nunnatorn_interior_entry",
		"enter_transition": {
			"destination_scene_id": "nunnatorn_interior",
			"destination_spawn_id": "nunnatorn_interior_entry",
			"spawn_id": "monastery_wall_tower_northwest_return",
			"building_id": "monastery_wall_tower_northwest",
		},
		"exit_transition": {
			"destination_scene_id": "reval_monastery",
			"destination_spawn_id": "monastery_wall_tower_northwest_return",
			"spawn_id": "nunnatorn_interior_entry",
		},
		"floors": [
			"nunnatorn_floor_ground",
			"nunnatorn_floor_watch",
			"nunnatorn_floor_roof",
		],
		"wall_walk_route": {
			"id": "nunnatorn_wall_walk",
			"entry_anchor": "nunnatorn_wall_walk_entry",
		},
		"boss_id": "nunnatorn_boss",
		"boss_name": "Marten of Nunnatorn",
		"defeated_outcome_id": "nunnatorn_boss_defeated",
		"alternate_outcome_id": "nunnatorn_boss_alternate_resolution",
		"loot_id": "nunnatorn_loot",
		"evidence_id": "nunnatorn_evidence",
		"persistence_key": "nunnatorn_state",
		"retry_key": "nunnatorn_retry",
		"readability_id": "nunnatorn_readability",
		"acceptance_id": "nunnatorn_acceptance",
	}
