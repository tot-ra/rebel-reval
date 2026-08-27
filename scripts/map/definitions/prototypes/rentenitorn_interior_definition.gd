class_name RentenitornInteriorDefinition
extends RefCounted

## Runtime adapter and stable enterable-tower contract for Rentenitorn.

const RRMAP_PATH := "res://content/maps/rentenitorn_interior.rrmap"


static func create() -> MapDefinition:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	if not parsed.is_ok():
		for diagnostic in parsed.formatted_diagnostics():
			push_error(diagnostic)
		return MapDefinition.new()
	return parsed.definition


static func enterable_tower_contract() -> Dictionary:
	return {
		"tower_id": "rentenitorn",
		"exterior_map_id": "north_quarter",
		"exterior_scene_id": "reval_north",
		"exterior_building_id": "merchant_wall_tower_northwest",
		"interior_map_id": "rentenitorn_interior",
		"exterior_return_spawn": "merchant_wall_tower_northwest_return",
		"interior_entry_spawn": "rentenitorn_interior_entry",
		"enter_transition": {
			"destination_scene_id": "rentenitorn_interior",
			"destination_spawn_id": "rentenitorn_interior_entry",
			"spawn_id": "merchant_wall_tower_northwest_return",
			"building_id": "merchant_wall_tower_northwest",
		},
		"exit_transition": {
			"destination_scene_id": "reval_north",
			"destination_spawn_id": "merchant_wall_tower_northwest_return",
			"spawn_id": "rentenitorn_interior_entry",
		},
		"floors": [
			"rentenitorn_floor_ground",
			"rentenitorn_floor_watch",
			"rentenitorn_floor_roof",
		],
		"wall_walk_route": {
			"id": "rentenitorn_wall_walk",
			"entry_anchor": "rentenitorn_wall_walk_entry",
		},
		"boss_id": "rentenitorn_boss",
		"boss_name": "The Rent Tower Watcher",
		"defeated_outcome_id": "rentenitorn_boss_defeated",
		"alternate_outcome_id": "rentenitorn_boss_alternate_resolution",
		"loot_id": "rentenitorn_loot",
		"evidence_id": "rentenitorn_evidence",
		"persistence_key": "rentenitorn_state",
		"retry_key": "rentenitorn_retry",
		"readability_id": "rentenitorn_readability",
		"acceptance_id": "rentenitorn_acceptance",
	}
