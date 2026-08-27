extends "res://tests/godot/test_case.gd"

## R-270: every completed tower exposes the same reciprocal-route and outcome
## contract even when its authored map, boss, or presentation differs.

const EnterableTowerContract := preload("res://scripts/tower/enterable_tower_contract.gd")
const NunnatornDefinition := preload(
	"res://scripts/map/definitions/prototypes/nunnatorn_interior_definition.gd"
)


func test_nunnatorn_satisfies_shared_enterable_tower_contract() -> void:
	var package := NunnatornDefinition.enterable_tower_contract()
	assert_eq(EnterableTowerContract.validate(package), [])


func test_shared_contract_rejects_one_way_transition() -> void:
	var package := NunnatornDefinition.enterable_tower_contract()
	package["exit_transition"]["destination_spawn_id"] = "wrong_spawn"

	var errors := EnterableTowerContract.validate(package)
	assert_true(_contains(errors, "exit_transition.destination_spawn_id"), str(errors))


func test_shared_contract_keeps_rewards_and_vertical_route_distinct() -> void:
	var package := NunnatornDefinition.enterable_tower_contract()
	package["evidence_id"] = package["loot_id"]
	package["floors"] = ["nunnatorn_floor_ground", "nunnatorn_floor_watch"]

	var errors := EnterableTowerContract.validate(package)
	assert_true(_contains(errors, "loot_id and evidence_id"), str(errors))
	assert_true(_contains(errors, "at least 3 reachable levels"), str(errors))


func _contains(errors: Array[String], fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false
