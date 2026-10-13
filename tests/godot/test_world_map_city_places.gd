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


func test_church_spawns_land_at_their_church_not_the_forum() -> void:
	var plan := CityPlan.load_default()
	var forum := CityTravel.spawn_position(plan, "poi.forum")
	for spawn in ["landmark.st_olaf", "landmark.st_nicholas"]:
		var at := CityTravel.spawn_position(plan, spawn)
		assert_true(at.distance_to(forum) > 50.0, "%s must not fall back to the forum" % spawn)


func test_city_place_spawns_never_land_inside_a_closed_building() -> void:
	# poi.granary.pikk sits inside a non-enterable house: arriving there trapped
	# the player in a doorless hull.
	var plan := CityPlan.load_default()
	for place in WorldMapGraph.CITY_PLACES:
		var at := CityTravel.spawn_position(plan, String(place["spawn"]))
		var index := plan.building_at(at)
		var closed := index >= 0 and not bool(plan.buildings[index].get("enterable", false))
		assert_false(closed, "%s spawns inside closed %s" % [place["spawn"], index])
	var granary := CityTravel.spawn_position(plan, "poi.granary.pikk")
	assert_true(granary.distance_to(Vector2(120.0, -400.0)) < 40.0, "granary stays near its quay")


func test_city_markers_sit_on_the_basemap_and_do_not_overlap() -> void:
	var points: Array[Vector2] = []
	for place in WorldMapGraph.CITY_PLACES:
		var at := WorldMapGraph.city_place_map_position(place["id"])
		assert_true(Rect2(0, 0, 1, 1).has_point(at), "%s must be on the map" % String(place["id"]))
		points.append(at * WorldMapGraph.CITY_MAP_PIXELS)
	for i in points.size():
		for j in range(i + 1, points.size()):
			assert_true(
				points[i].distance_to(points[j]) > WorldMapGraph.CITY_MAP_MIN_GAP_PX - 1.0,
				"markers %d and %d overlap" % [i, j]
			)


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
	assert_eq(button.get_script(), preload("res://scripts/ui/world_map_marker.gd"))
	overlay.queue_free()


func test_city_forge_retires_the_separate_2d_forge_scene() -> void:
	var manifest := (
		JSON.parse_string(
			FileAccess.get_file_as_string("res://content/transitions/active_destinations.json")
		)
		as Dictionary
	)
	for scene: Dictionary in manifest.get("scenes", []):
		if String(scene.get("id", "")) == "forge":
			assert_false(bool(scene.get("active", true)), "old separate forge scene is retired")
			assert_false(
				bool(scene.get("release", true)), "old forge cannot appear as release destination"
			)
	assert_eq(
		CityTravel.redirect(&"forge", &"door_courtyard"),
		[CityTravel.CITY_SCENE_ID, &"kalev_smithy"]
	)
