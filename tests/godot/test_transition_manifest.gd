extends "res://tests/godot/test_case.gd"


func before_each() -> void:
	DoorNavigator.load_manifest(true)


func test_transition_manifest_exposes_release_scene_ids() -> void:
	var active_scene_ids := DoorNavigator.get_active_scene_ids()
	assert_false(active_scene_ids.has(&"forge"), "the standalone forge is retired")
	assert_array_contains(
		active_scene_ids, &"reval_city", "The seamless city is the playable Reval"
	)
	assert_eq(
		DoorNavigator.has_active_scene(&"archive_only"), false, "Unknown scenes must not be active"
	)


func test_transition_manifest_has_no_old_district_scenes() -> void:
	for retired in [
		&"forge",
		&"reval_east",
		&"reval_center",
		&"reval_north",
		&"reval_monastery",
		&"reval_toompea",
		&"reval_south",
		&"reval_archbishops_garden",
		&"st_olafs_guild_hall",
		&"oleviste_church",
		&"holy_spirit_church",
		&"town_hall",
		&"viru_gate_foreland",
		&"reval_harbor_north",
		&"reval_harbor_east",
		&"toompea_small_castle",
		&"nunnatorn_interior",
		&"kuldjala_interior",
		&"rentenitorn_interior",
		&"harbor_warehouse"
	]:
		assert_false(DoorNavigator.has_active_scene(retired), "%s was retired" % retired)


func test_transition_manifest_resolves_city_aliases_for_old_smithy_saves() -> void:
	assert_true(
		DoorNavigator.has_spawn(&"reval_city", &"kalev_smithy"), "The city exposes Kalev's smithy"
	)
	assert_eq(CityTravel.redirect(&"forge", &"door_courtyard"), [&"reval_city", &"kalev_smithy"])
	assert_eq(CityTravel.redirect(&"forge", &"smithy_start"), [&"reval_city", &"kalev_smithy"])


func test_transition_manifest_resolves_paths_and_spawns() -> void:
	assert_eq(DoorNavigator.get_scene_path(&"forge"), "")
	assert_false(DoorNavigator.has_spawn(&"forge", &"door_courtyard"))
	assert_false(DoorNavigator.has_spawn(&"forge", &"smithy_start"))
	assert_true(
		DoorNavigator.has_spawn(&"reval_city", &"kalev_smithy"), "The city exposes New Game start"
	)
	assert_true(
		DoorNavigator.has_spawn(&"reval_city", &"gate.viru.outside"),
		"The city exposes the Viru road arrival"
	)


func test_transition_manifest_returns_deterministic_city_spawn_ids() -> void:
	var spawn_ids := DoorNavigator.get_scene_spawn_ids(&"reval_city")
	assert_true(spawn_ids.has(&"kalev_smithy"))
	assert_eq(DoorNavigator.get_scene_spawn_ids(&"archive_only"), [])

	DoorNavigator._scenes[&"stale_scene"] = {
		"path": "res://scenes/missing/stale_scene.tscn",
		"active": true,
		"spawns": {&"stale_spawn": true},
	}
	assert_true(DoorNavigator.has_active_scene(&"stale_scene"))
	assert_true(DoorNavigator.has_spawn(&"stale_scene", &"stale_spawn"))

	assert_true(
		DoorNavigator.load_manifest(true),
		"Forced reload should rebuild the manifest registry",
	)
	assert_false(
		DoorNavigator.has_active_scene(&"stale_scene"),
		"Forced reload must discard scene records from the previous registry",
	)
	assert_false(
		DoorNavigator.has_spawn(&"stale_scene", &"stale_spawn"),
		"Forced reload must discard stale spawn records with their scene",
	)


func test_transition_manifest_forced_reload_is_idempotent() -> void:
	assert_true(
		DoorNavigator.load_manifest(true),
		"First forced reload should rebuild the manifest registry",
	)
	var first_scene_ids := DoorNavigator.get_active_scene_ids()
	var first_forge_spawn_ids := DoorNavigator.get_scene_spawn_ids(&"forge")

	assert_true(
		DoorNavigator.load_manifest(true),
		"Second forced reload should rebuild the manifest registry",
	)
	assert_eq(
		DoorNavigator.get_active_scene_ids(),
		first_scene_ids,
		"Repeated manifest reloads must preserve active scene IDs",
	)
	assert_eq(
		DoorNavigator.get_scene_spawn_ids(&"forge"),
		first_forge_spawn_ids,
		"Repeated manifest reloads must preserve forge spawn IDs",
	)
