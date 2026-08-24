extends "res://tests/godot/test_case.gd"

func before_each() -> void:
	DoorNavigator.load_manifest(true)


func test_forced_manifest_reload_discards_scene_resource_cache() -> void:
	var cached_scene := load("res://scenes/reval_east/forge/forge.tscn") as PackedScene
	assert_true(cached_scene != null, "Forge should provide a loadable PackedScene fixture")

	DoorNavigator.scene_cache[&"forge"] = cached_scene
	DoorNavigator.cache_order.append(&"forge")
	assert_true(DoorNavigator.scene_cache.has(&"forge"))
	assert_eq(DoorNavigator.cache_order, [&"forge"])

	assert_true(
		DoorNavigator.load_manifest(true),
		"Forced reload should rebuild the transition manifest",
	)
	assert_false(
		DoorNavigator.scene_cache.has(&"forge"),
		"Forced reload must discard scene resources resolved from the old manifest",
	)
	assert_eq(
		DoorNavigator.cache_order,
		[],
		"Forced reload must reset the LRU order with the scene cache",
	)

	var reloaded_scene := DoorNavigator._get_scene_resource(&"forge")
	assert_true(
		reloaded_scene != null,
		"A cleared cache must still allow the active scene to load again",
	)
	assert_true(DoorNavigator.scene_cache.has(&"forge"))
