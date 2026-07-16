extends "res://tests/godot/test_case.gd"

func before_each() -> void:
	DoorNavigator.load_manifest(true)

func test_transition_manifest_exposes_active_scene_ids() -> void:
	var active_scene_ids := DoorNavigator.get_active_scene_ids()

	assert_array_contains(active_scene_ids, &"forge", "Forge should stay registered as an active transition scene")
	assert_array_contains(active_scene_ids, &"reval_east", "Reval East should stay registered as a playable transition scene")
	assert_eq(DoorNavigator.has_active_scene(&"archive_only"), false, "Unknown scenes must not be active")

func test_transition_manifest_resolves_paths_and_spawns() -> void:
	assert_eq(DoorNavigator.get_scene_path(&"forge"), "res://scenes/reval_east/forge/forge.tscn")
	assert_true(DoorNavigator.has_spawn(&"forge", &"main"), "Forge must expose its stable main spawn")
	assert_false(DoorNavigator.has_spawn(&"forge", &"missing_spawn"), "Missing spawn IDs must not resolve")
