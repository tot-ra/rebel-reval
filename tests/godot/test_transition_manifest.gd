extends "res://tests/godot/test_case.gd"

func before_each() -> void:
	DoorNavigator.load_manifest(true)

func test_transition_manifest_exposes_active_scene_ids() -> void:
	var active_scene_ids := DoorNavigator.get_active_scene_ids()

	assert_array_contains(active_scene_ids, &"forge", "Forge should stay registered as an active transition scene")
	assert_array_contains(active_scene_ids, &"reval_east", "Lower Town slice should stay registered as a playable transition scene")
	assert_eq(active_scene_ids.size(), 2, "Only forge and reval_east remain active after P2-020 cutover")
	assert_eq(DoorNavigator.has_active_scene(&"reval_center"), false, "Prototype center must not be active")
	assert_eq(DoorNavigator.has_active_scene(&"reval_north"), false, "Prototype north must not be active")
	assert_eq(DoorNavigator.has_active_scene(&"archive_only"), false, "Unknown scenes must not be active")

func test_transition_manifest_resolves_paths_and_spawns() -> void:
	assert_eq(DoorNavigator.get_scene_path(&"forge"), "res://scenes/reval_east/forge/forge.tscn")
	assert_true(DoorNavigator.has_spawn(&"forge", &"door_courtyard"), "Forge must expose its stable courtyard spawn")
	assert_true(DoorNavigator.has_spawn(&"reval_east", &"street_start"), "Lower Town must expose its Start spawn")
	assert_true(DoorNavigator.has_spawn(&"reval_east", &"forge"), "Lower Town must expose its smithy spawn")
	assert_false(DoorNavigator.has_spawn(&"forge", &"main"), "Legacy forge spawn alias must be retired")
	assert_false(DoorNavigator.has_spawn(&"reval_east", &"south_1"), "Legacy district-edge spawns must be retired")
	assert_false(DoorNavigator.has_spawn(&"forge", &"missing_spawn"), "Missing spawn IDs must not resolve")
