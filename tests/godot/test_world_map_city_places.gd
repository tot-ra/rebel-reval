extends "res://tests/godot/test_case.gd"

## District map fast travel lists the key places of the seamless city (ADR 0031)
## and no longer the retired 2D smithy scene.

func before_each() -> void:
	DoorNavigator.load_manifest(true)


func test_graph_lists_every_city_place_and_not_the_retired_forge() -> void:
	var ids := WorldMapGraph.active_scene_ids()
	assert_false(ids.has(&"forge"), "the 2D smithy must not be a travel node")
	assert_false(ids.has(&"reval_city"), "the city is shown as its places")
	for place in WorldMapGraph.CITY_PLACES:
		assert_array_contains(ids, place["id"])
		assert_true(
			DoorNavigator.has_spawn(CityTravel.CITY_SCENE_ID, place["spawn"]),
			"place spawn must be registered for the city: %s" % String(place["spawn"])
		)
		assert_false(
			String(place["id"]).contains("."), "place id becomes a node name and cannot hold dots"
		)


func test_every_place_is_travelable_from_the_city_and_plans_a_city_spawn() -> void:
	var neighbors := WorldMapGraph.travelable_neighbors(CityTravel.CITY_SCENE_ID)
	for place in WorldMapGraph.CITY_PLACES:
		assert_array_contains(neighbors, place["id"])
		var plan := WorldMapGraph.plan_travel(CityTravel.CITY_SCENE_ID, place["id"])
		assert_eq(plan.get("scene_id"), CityTravel.CITY_SCENE_ID)
		assert_eq(plan.get("spawn_id"), place["spawn"])


func test_overlay_plans_city_place_travel_and_names_buttons() -> void:
	var overlay := WorldMapOverlay.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(overlay)
	overlay.configure(CityTravel.CITY_SCENE_ID)
	overlay.open()
	overlay.show_fast_travel()
	var plan := overlay.plan_travel_to(&"city_kalev_smithy")
	assert_eq(plan.get("scene_id"), CityTravel.CITY_SCENE_ID)
	assert_eq(plan.get("spawn_id"), &"kalev_smithy")
	var button := overlay.get_node_button(&"city_forum")
	assert_true(button != null, "city place must render as a node")
	assert_eq(button.text, "Town Hall Square")
	overlay.queue_free()


func test_retired_forge_scene_redirects_into_the_city_smithy() -> void:
	assert_eq(
		CityTravel.redirect(&"forge", &"door_courtyard"), [CityTravel.CITY_SCENE_ID, &"kalev_smithy"]
	)
