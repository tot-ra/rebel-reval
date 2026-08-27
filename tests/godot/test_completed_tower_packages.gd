extends "res://tests/godot/test_case.gd"

## R-661: every completed 1343 tower has a shared package descriptor, but only
## authored interiors can become release-ready.

const CompletedTowerPackages := preload("res://scripts/tower/completed_tower_packages.gd")
const EnterableTowerContract := preload("res://scripts/tower/enterable_tower_contract.gd")


func test_catalog_covers_all_completed_1343_towers() -> void:
	var packages := CompletedTowerPackages.all()
	assert_eq(packages.size(), 4)
	assert_eq(CompletedTowerPackages.validate_all(), [])
	for tower_id in CompletedTowerPackages.PACKAGE_IDS:
		var package := CompletedTowerPackages.by_id(tower_id)
		assert_false(package.is_empty(), "missing package %s" % tower_id)
		assert_eq(String(package["tower_id"]), String(tower_id))


## Release readiness is derived from each package's declared implementation status
## instead of a hard-coded tower list, so landing one more authored interior can
## neither be forgotten here nor silently promote an unfinished follow-up.
func test_authored_packages_are_release_ready_while_follow_ups_stay_blocked() -> void:
	var authored: Array[String] = []
	for package in CompletedTowerPackages.all():
		var tower_id := String(package["tower_id"])
		var implemented := String(package["implementation_status"]) == "implemented"
		assert_eq(
			CompletedTowerPackages.release_ready(package),
			implemented,
			"%s release readiness must follow its implementation status" % tower_id,
		)
		assert_false(bool(package["release_active"]), "%s must not be release-active" % tower_id)
		assert_true(bool(package["developer_only"]), "%s must stay developer-only" % tower_id)
		if implemented:
			authored.append(tower_id)
	assert_true(authored.has("nunnatorn"), str(authored))
	assert_true(authored.has("rentenitorn"), str(authored))


func test_catalog_rejects_reused_ids_and_one_way_transitions() -> void:
	var duplicate := CompletedTowerPackages.by_id(&"kuldjala")
	duplicate["tower_id"] = "nunnatorn"
	var duplicate_errors := CompletedTowerPackages.validate_catalog([
		CompletedTowerPackages.by_id(&"nunnatorn"),
		duplicate,
	])
	assert_true(_contains(duplicate_errors, "stable ID nunnatorn"), str(duplicate_errors))

	var broken := CompletedTowerPackages.by_id(&"nunnatorn")
	broken["exit_transition"]["destination_spawn_id"] = "wrong_return_spawn"
	var transition_errors := EnterableTowerContract.validate(broken)
	assert_true(
		_contains(transition_errors, "exit_transition.destination_spawn_id"),
		str(transition_errors),
	)


func _contains(errors: Array[String], fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false
