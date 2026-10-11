class_name CompletedTowerPackages
extends RefCounted

## R-661 catalog for the four completed 1343 tower positions.
## WHY: package-specific interiors arrive from separate owner tasks, so the shared
## contract must cover their stable IDs before a missing scene can be mistaken for
## an activated dungeon.

const EnterableTowerContract := preload("res://scripts/tower/enterable_tower_contract.gd")

const PACKAGE_IDS: Array[StringName] = [
	&"nunnatorn",
	&"kuldjala",
	&"rentenitorn",
	&"great_coastal_gate",
]

const CONTRACT_ID_FIELDS: Array[String] = [
	"tower_id",
	"exterior_building_id",
	"interior_map_id",
	"exterior_return_spawn",
	"interior_entry_spawn",
	"boss_id",
	"defeated_outcome_id",
	"alternate_outcome_id",
	"loot_id",
	"evidence_id",
	"persistence_key",
	"retry_key",
	"readability_id",
	"acceptance_id",
]

const DESCRIPTOR_FIELDS: Array[String] = [
	"implementation_status",
	"interior_scene_path",
	"interior_source_path",
	"contract_source_path",
	"developer_only",
	"release_active",
]


static func all() -> Array[Dictionary]:
	return [
		_package(
			"nunnatorn",
			"Nunnatorn / Nun's Tower",
			"monastery_quarter",
			"reval_monastery",
			"monastery_wall_tower_northwest",
			"nunnatorn_interior",
			"monastery_wall_tower_northwest_return",
			"nunnatorn_interior_entry",
			"nunnatorn_interior",
			"nunnatorn_boss",
			"Marten of Nunnatorn",
			"nunnatorn_boss_defeated",
			"nunnatorn_boss_alternate_resolution",
			"nunnatorn_loot",
			"nunnatorn_evidence",
			"nunnatorn_state",
			"nunnatorn_retry",
			"nunnatorn_readability",
			"nunnatorn_acceptance",
			"implemented",
			"res://scenes/reval_monastery/nunnatorn_interior.tscn",
			"res://content/maps/nunnatorn_interior.rrmap",
			"res://scripts/map/definitions/prototypes/nunnatorn_interior_definition.gd",
		),
		_package(
			"kuldjala",
			"Kuldjala / Golden Leg Tower",
			"monastery_quarter",
			"reval_monastery",
			"monastery_wall_tower_west_mid",
			"kuldjala_interior",
			"monastery_wall_tower_west_mid_return",
			"kuldjala_interior_entry",
			"kuldjala_interior",
			"kuldjala_boss",
			"The Golden Leg Warden",
			"kuldjala_boss_defeated",
			"kuldjala_boss_alternate_resolution",
			"kuldjala_loot",
			"kuldjala_evidence",
			"kuldjala_state",
			"kuldjala_retry",
			"kuldjala_readability",
			"kuldjala_acceptance",
			"implemented",
			"res://scenes/reval_monastery/kuldjala_interior.tscn",
			"res://content/maps/kuldjala_interior.rrmap",
			"res://scripts/map/definitions/prototypes/kuldjala_interior_definition.gd",
		),
		_package(
			"rentenitorn",
			"Rentenitorn / Rent Tower",
			"north_quarter",
			"reval_north",
			"merchant_wall_tower_northwest",
			"rentenitorn_interior",
			"merchant_wall_tower_northwest_return",
			"rentenitorn_interior_entry",
			"rentenitorn_interior",
			"rentenitorn_boss",
			"The Rent Tower Watcher",
			"rentenitorn_boss_defeated",
			"rentenitorn_boss_alternate_resolution",
			"rentenitorn_loot",
			"rentenitorn_evidence",
			"rentenitorn_state",
			"rentenitorn_retry",
			"rentenitorn_readability",
			"rentenitorn_acceptance",
			"implemented",
			"res://scenes/reval_north/rentenitorn_interior.tscn",
			"res://content/maps/rentenitorn_interior.rrmap",
			"res://scripts/map/definitions/prototypes/rentenitorn_interior_definition.gd",
		),
		_package(
			"great_coastal_gate",
			"Great Coastal Gate tower",
			"north_quarter",
			"reval_north",
			"coast_gate_west_tower",
			"great_coastal_gate_interior",
			"coast_gate_west_tower_return",
			"great_coastal_gate_interior_entry",
			"great_coastal_gate_interior",
			"great_coastal_gate_boss",
			"The Harbour Gate Warden",
			"great_coastal_gate_boss_defeated",
			"great_coastal_gate_boss_alternate_resolution",
			"great_coastal_gate_loot",
			"great_coastal_gate_evidence",
			"great_coastal_gate_state",
			"great_coastal_gate_retry",
			"great_coastal_gate_readability",
			"great_coastal_gate_acceptance",
			"in_progress",
			"res://scenes/reval_north/great_coastal_gate_interior.tscn",
			"res://content/maps/great_coastal_gate_interior.rrmap",
			"res://scripts/map/definitions/prototypes/great_coastal_gate_interior_definition.gd",
		),
	]


static func by_id(tower_id: StringName) -> Dictionary:
	for package in all():
		if StringName(package["tower_id"]) == tower_id:
			return package
	return {}


static func validate_catalog(
	packages: Array[Dictionary],
	require_complete_catalog: bool = true,
) -> Array[String]:
	var errors: Array[String] = []
	var seen_towers: Dictionary = {}
	var seen_ids: Dictionary = {}
	for package in packages:
		for field in DESCRIPTOR_FIELDS:
			if not package.has(field):
				errors.append("missing descriptor field: %s" % field)
		var tower_id := String(package.get("tower_id", ""))
		if tower_id.is_empty():
			continue
		if seen_towers.has(tower_id):
			errors.append("tower package %s is declared more than once" % tower_id)
		else:
			seen_towers[tower_id] = true

		var contract_errors := EnterableTowerContract.validate(package)
		errors.append_array(contract_errors.map(func(error: String) -> String:
			return "%s: %s" % [tower_id, error]
		))
		for field in CONTRACT_ID_FIELDS:
			var stable_id := String(package.get(field, ""))
			if stable_id.is_empty():
				continue
			if seen_ids.has(stable_id):
				errors.append(
					"stable ID %s is reused across packages (%s and %s)"
					% [stable_id, seen_ids[stable_id], tower_id]
				)
			else:
				seen_ids[stable_id] = tower_id

		if not bool(package.get("developer_only", false)):
			errors.append("%s must remain developer-only" % tower_id)
		if bool(package.get("release_active", true)):
			errors.append("%s must not be release-active" % tower_id)
		if String(package.get("implementation_status", "")) == "implemented":
			for path_field in ["interior_scene_path", "interior_source_path", "contract_source_path"]:
				var path := String(package.get(path_field, ""))
				if path.is_empty() or not FileAccess.file_exists(path):
					errors.append("implemented %s is missing %s: %s" % [tower_id, path_field, path])

	for expected_id in PACKAGE_IDS:
		if require_complete_catalog and not seen_towers.has(String(expected_id)):
			errors.append("completed tower package is missing: %s" % expected_id)
	return errors


static func validate_all() -> Array[String]:
	return validate_catalog(all())


static func release_ready(package: Dictionary) -> bool:
	return (
		validate_catalog([package], false).is_empty()
		and package.get("implementation_status") == "implemented"
	)


static func _package(
	tower_id: String,
	historical_name: String,
	exterior_map_id: String,
	exterior_scene_id: String,
	exterior_building_id: String,
	interior_map_id: String,
	exterior_return_spawn: String,
	interior_entry_spawn: String,
	interior_scene_id: String,
	boss_id: String,
	boss_name: String,
	defeated_outcome_id: String,
	alternate_outcome_id: String,
	loot_id: String,
	evidence_id: String,
	persistence_key: String,
	retry_key: String,
	readability_id: String,
	acceptance_id: String,
	implementation_status: String,
	interior_scene_path: String,
	interior_source_path: String,
	contract_source_path: String,
) -> Dictionary:
	return {
		"tower_id": tower_id,
		"historical_name": historical_name,
		"exterior_map_id": exterior_map_id,
		"exterior_scene_id": exterior_scene_id,
		"exterior_building_id": exterior_building_id,
		"interior_map_id": interior_map_id,
		"exterior_return_spawn": exterior_return_spawn,
		"interior_entry_spawn": interior_entry_spawn,
		"enter_transition": {
			"destination_scene_id": interior_scene_id,
			"destination_spawn_id": interior_entry_spawn,
			"spawn_id": exterior_return_spawn,
			"building_id": exterior_building_id,
		},
		"exit_transition": {
			"destination_scene_id": exterior_scene_id,
			"destination_spawn_id": exterior_return_spawn,
			"spawn_id": interior_entry_spawn,
		},
		"floors": [
			"%s_floor_ground" % tower_id,
			"%s_floor_watch" % tower_id,
			"%s_floor_roof" % tower_id,
		],
		"wall_walk_route": {
			"id": "%s_wall_walk" % tower_id,
			"entry_anchor": "%s_wall_walk_entry" % tower_id,
		},
		"boss_id": boss_id,
		"boss_name": boss_name,
		"defeated_outcome_id": defeated_outcome_id,
		"alternate_outcome_id": alternate_outcome_id,
		"loot_id": loot_id,
		"evidence_id": evidence_id,
		"persistence_key": persistence_key,
		"retry_key": retry_key,
		"readability_id": readability_id,
		"acceptance_id": acceptance_id,
		"implementation_status": implementation_status,
		"interior_scene_path": interior_scene_path,
		"interior_source_path": interior_source_path,
		"contract_source_path": contract_source_path,
		"developer_only": true,
		"release_active": false,
	}
