class_name EnterableTowerContract
extends RefCounted

## Shared R-270 contract for a completed, enterable tower package.
## WHY: tower-specific scenes can vary, but transition identity, vertical traversal,
## authored outcomes, and durable state must remain consistent across every package.

const MIN_FLOOR_COUNT := 3

const REQUIRED_FIELDS: Array[String] = [
	"tower_id",
	"exterior_map_id",
	"exterior_scene_id",
	"exterior_building_id",
	"interior_map_id",
	"exterior_return_spawn",
	"interior_entry_spawn",
	"enter_transition",
	"exit_transition",
	"floors",
	"wall_walk_route",
	"boss_id",
	"boss_name",
	"defeated_outcome_id",
	"alternate_outcome_id",
	"loot_id",
	"evidence_id",
	"persistence_key",
	"retry_key",
	"readability_id",
	"acceptance_id",
]


## Return every contract violation instead of accepting the first one. This makes
## the result useful to editor tooling and keeps fail-closed package checks readable.
static func validate(package: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field in REQUIRED_FIELDS:
		if not package.has(field):
			errors.append("missing required field: %s" % field)

	if not errors.is_empty():
		return errors

	var identity_fields: Array[String] = [
		"tower_id",
		"exterior_map_id",
		"exterior_scene_id",
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
	var seen_ids: Dictionary = {}
	for field in identity_fields:
		var value := String(package.get(field, ""))
		if value.is_empty():
			errors.append("%s must be a non-empty stable ID" % field)
		elif seen_ids.has(value):
			errors.append(
				"stable ID %s is reused by %s and %s" % [value, seen_ids[value], field]
			)
		else:
			seen_ids[value] = field

	var enter_transition: Variant = package.get("enter_transition", {})
	var exit_transition: Variant = package.get("exit_transition", {})
	if not (enter_transition is Dictionary):
		errors.append("enter_transition must be a Dictionary")
	else:
		errors.append_array(_transition_errors(
			"enter_transition",
			enter_transition,
			String(package["interior_map_id"]),
			String(package["interior_entry_spawn"]),
			String(package["exterior_return_spawn"]),
			true,
		))
	if not (exit_transition is Dictionary):
		errors.append("exit_transition must be a Dictionary")
	else:
		errors.append_array(_transition_errors(
			"exit_transition",
			exit_transition,
			String(package["exterior_scene_id"]),
			String(package["exterior_return_spawn"]),
			String(package["interior_entry_spawn"]),
			false,
		))

	var floors: Variant = package.get("floors", [])
	if not (floors is Array):
		errors.append("floors must be an Array")
	else:
		var floor_ids: Dictionary = {}
		if floors.size() < MIN_FLOOR_COUNT:
			errors.append("floors must contain at least %d reachable levels" % MIN_FLOOR_COUNT)
		for floor in floors:
			var floor_id: String = String(floor)
			if floor_id.is_empty():
				errors.append("floors must contain non-empty stable IDs")
			elif floor_ids.has(floor_id):
				errors.append("floor stable ID %s is duplicated" % floor_id)
			else:
				floor_ids[floor_id] = true

	var wall_walk_route: Variant = package.get("wall_walk_route", {})
	if not (wall_walk_route is Dictionary):
		errors.append("wall_walk_route must be a Dictionary")
	else:
		for field in ["id", "entry_anchor"]:
			if String(wall_walk_route.get(field, "")).is_empty():
				errors.append("wall_walk_route.%s must be a non-empty stable ID" % field)

	if String(package["boss_name"]).is_empty():
		errors.append("boss_name must be authored")
	if String(package["loot_id"]) == String(package["evidence_id"]):
		errors.append("loot_id and evidence_id must remain separate records")
	if String(package["defeated_outcome_id"]) == String(package["alternate_outcome_id"]):
		errors.append("defeated and alternate outcomes must remain distinct")
	return errors


static func _transition_errors(
	label: String,
	transition: Dictionary,
	expected_destination: String,
	expected_destination_spawn: String,
	expected_spawn: String,
	is_entry: bool,
) -> Array[String]:
	var errors: Array[String] = []
	var checks := {
		"destination_scene_id": expected_destination,
		"destination_spawn_id": expected_destination_spawn,
		"spawn_id": expected_spawn,
	}
	for field in checks:
		var actual := String(transition.get(field, ""))
		if actual != String(checks[field]):
			errors.append(
				"%s.%s must be %s (got %s)" % [label, field, checks[field], actual]
			)
	if is_entry and String(transition.get("building_id", "")).is_empty():
		errors.append("enter_transition.building_id must identify the exterior tower")
	return errors
