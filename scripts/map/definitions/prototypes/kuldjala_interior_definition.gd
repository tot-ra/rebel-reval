class_name KuldjalaInteriorDefinition
extends RefCounted

## Runtime adapter and stable enterable-tower contract for Kuldjala.

const RRMAP_PATH := "res://content/maps/kuldjala_interior.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition


static func enterable_tower_contract() -> Dictionary:
	return {
		"tower_id": "kuldjala",
		"exterior_map_id": "monastery_quarter",
		"exterior_scene_id": "reval_monastery",
		"exterior_building_id": "monastery_wall_tower_west_mid",
		"interior_map_id": "kuldjala_interior",
		"exterior_return_spawn": "monastery_wall_tower_west_mid_return",
		"interior_entry_spawn": "kuldjala_interior_entry",
		"enter_transition": {
			"destination_scene_id": "kuldjala_interior",
			"destination_spawn_id": "kuldjala_interior_entry",
			"spawn_id": "monastery_wall_tower_west_mid_return",
			"building_id": "monastery_wall_tower_west_mid",
		},
		"exit_transition": {
			"destination_scene_id": "reval_monastery",
			"destination_spawn_id": "monastery_wall_tower_west_mid_return",
			"spawn_id": "kuldjala_interior_entry",
		},
		"floors": [
			"kuldjala_floor_ground",
			"kuldjala_floor_watch",
			"kuldjala_floor_roof",
		],
		"wall_walk_route": {
			"id": "kuldjala_wall_walk",
			"entry_anchor": "kuldjala_wall_walk_entry",
		},
		"boss_id": "kuldjala_boss",
		"boss_name": "The Golden Leg Warden",
		"defeated_outcome_id": "kuldjala_boss_defeated",
		"alternate_outcome_id": "kuldjala_boss_alternate_resolution",
		"loot_id": "kuldjala_loot",
		"evidence_id": "kuldjala_evidence",
		"persistence_key": "kuldjala_state",
		"retry_key": "kuldjala_retry",
		"readability_id": "kuldjala_readability",
		"acceptance_id": "kuldjala_acceptance",
	}
