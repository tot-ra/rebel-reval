extends "res://tests/godot/test_case.gd"

func before_each() -> void:
	DoorNavigator.load_manifest(true)

func test_transition_manifest_exposes_release_scene_ids() -> void:
	var active_scene_ids := DoorNavigator.get_active_scene_ids()

	assert_array_contains(active_scene_ids, &"forge", "Forge should stay registered as an active transition scene")
	assert_array_contains(active_scene_ids, &"reval_east", "Lower Town slice should stay registered as a playable transition scene")
	assert_eq(DoorNavigator.has_active_scene(&"archive_only"), false, "Unknown scenes must not be active")

func test_transition_manifest_includes_dev_traversal_scenes() -> void:
	assert_true(DoorNavigator.has_active_scene(&"reval_center"), "Market civic quarter should be traversable in dev")
	assert_true(DoorNavigator.has_active_scene(&"reval_north"), "North quarter should be traversable in dev")
	assert_true(DoorNavigator.has_active_scene(&"market_civic_quarter"), "Market square should be traversable in dev")
	assert_true(DoorNavigator.has_active_scene(&"st_olafs_guild_hall"), "Guild hall should be traversable in dev")
	assert_true(DoorNavigator.has_active_scene(&"reval_harbor"), "Harbor surroundings should be traversable in dev")
	assert_true(DoorNavigator.has_active_scene(&"harbor_warehouse"), "Harbor warehouse should be traversable in dev")

func test_transition_manifest_resolves_paths_and_spawns() -> void:
	assert_eq(DoorNavigator.get_scene_path(&"forge"), "res://scenes/reval_east/forge/forge.tscn")
	assert_true(DoorNavigator.has_spawn(&"forge", &"door_courtyard"), "Forge must expose its stable courtyard spawn")
	assert_true(DoorNavigator.has_spawn(&"forge", &"smithy_start"), "Forge must expose its new-game start spawn")
	assert_true(DoorNavigator.has_spawn(&"reval_east", &"street_start"), "Lower Town must expose its Start spawn")
	assert_true(DoorNavigator.has_spawn(&"reval_east", &"forge"), "Lower Town must expose its smithy spawn")
	assert_true(DoorNavigator.has_spawn(&"reval_east", &"vana_turg_boundary"), "Lower Town must expose its west boundary spawn")
	assert_true(DoorNavigator.has_spawn(&"reval_center", &"from_reval_east"), "Center must expose its east-entry spawn")
	assert_false(DoorNavigator.has_spawn(&"forge", &"main"), "Legacy forge spawn alias must be retired")
	assert_false(DoorNavigator.has_spawn(&"reval_east", &"south_1"), "Legacy district-edge spawns must be retired")
	assert_false(DoorNavigator.has_spawn(&"forge", &"missing_spawn"), "Missing spawn IDs must not resolve")
