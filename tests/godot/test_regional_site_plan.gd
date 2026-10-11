extends "res://tests/godot/test_case.gd"

## Regional site plans (ADR 0042, docs/SYSTEMS/REGIONAL_SITES.md): the Paide
## pilot loads through the shared city runtime, has no sea, keeps the sky and
## weather, arrives on its manifest spawns and returns to the travel map at its edge.

const PAIDE_SCENE := "res://scenes/world/sites/paide.tscn"
const SiteLevel := preload("res://scenes/world/sites/site_level.gd")


func _paide() -> CityPlan:
	return CityPlan.load_site("paide")


func test_paide_plan_loads_from_its_own_directory() -> void:
	var plan := _paide()
	assert_eq(plan.site_id, "paide")
	assert_eq(plan.site_dir, "res://content/world/paide")
	assert_eq(plan.splat_path(), "res://content/world/paide/splat.png")
	assert_almost_eq(plan.bounds.size.x, 600.0, 0.01, "600 m frame")
	assert_almost_eq(plan.bounds.size.y, 600.0, 0.01, "600 m frame")
	assert_almost_eq(plan.origin_latitude(), 58.889, 0.01, "origin is Paide, not Reval")
	assert_false(plan.has_coast(), "Paide is inland: no shoreline, no sea")
	assert_true(plan.sites.is_empty(), "no ADR 0032 landmark sites at Paide")
	for feature: String in ["citizens", "fauna", "interiors"]:
		assert_false(plan.feature_enabled(feature), "%s off until a task enables them" % feature)


func test_reval_plan_is_unchanged_by_the_site_loader() -> void:
	var city := CityPlan.load_default()
	assert_eq(city.site_id, CityPlan.DEFAULT_SITE)
	assert_true(city.has_coast(), "Reval keeps its sea")
	assert_true(city.feature_enabled("citizens"), "Reval has no site block: every feature stays on")
	assert_true(city != _paide(), "each site has its own cached plan")
	var definition := CityMapDefinition.from_plan(city)
	assert_eq(definition.map_id, &"reval_city")
	assert_eq(definition.fingerprint, "reval_city")


func test_paide_keeps_its_travel_ids() -> void:
	var definition := CityMapDefinition.from_plan(_paide())
	assert_eq(definition.map_id, &"world.paide")
	assert_eq(definition.location, &"loc.world_paide")
	assert_eq(DoorNavigator.get_scene_path(&"world_paide"), PAIDE_SCENE)


func test_every_manifest_spawn_is_a_plan_arrival_inside_the_edge() -> void:
	var plan := _paide()
	var inner := plan.bounds.grow(-SiteLevel.EDGE_MARGIN)
	var spawns := DoorNavigator.get_scene_spawn_ids(&"world_paide")
	assert_eq(spawns.size(), 3, "from_world_kanavere, from_world_sojamae, from_world_parnu")
	for spawn: StringName in spawns:
		var arrival := plan.arrival_spawn(String(spawn))
		assert_false(arrival.is_empty(), "%s has no plan arrival" % spawn)
		var at := CityTravel.spawn_position(plan, String(spawn))
		assert_true(inner.has_point(at), "%s arrives inside the edge band (%s)" % [spawn, at])
		assert_true(String(arrival["record"]).begins_with("paide.spawn."))


func test_paide_ids_are_site_prefixed() -> void:
	var data := _paide().data
	for key: String in ["buildings", "towers", "gates", "streets", "fields", "pastures", "bridges", "districts", "points_of_interest", "curtains"]:
		for record: Dictionary in data[key]:
			assert_true(String(record["id"]).begins_with("paide."), "%s id %s lacks the site prefix" % [key, record["id"]])


func test_paide_castle_has_the_octagonal_keep() -> void:
	var keep := {}
	for t: Dictionary in _paide().data["towers"]:
		if t["id"] == "paide.tower.keep":
			keep = t
	assert_false(keep.is_empty(), "keep tower in the plan")
	assert_eq(keep.get("form", ""), "octagonal")
	assert_true(float(keep["h"]) >= 25.0, "the keep dominates the plain")
	# Its collision sits on the tower, not projected toward a town wall.
	assert_eq(
		CityFortificationBuilder.tower_centre(_paide(), keep), Vector2(keep["at"][0], keep["at"][1])
	)


func test_sun_follows_the_site_latitude() -> void:
	var date := {"year": 1343, "month": 5, "day": 14}
	# Independent of test order: a site scene freed by another test may not have
	# left the tree yet, so start from the Reval observer explicitly.
	SkyAstronomy.reset_observer()
	var reval_noon := SkyAstronomy.solar_elevation_degrees(0.5, date)
	SkyAstronomy.set_observer(58.889, 25.572)
	var paide_noon := SkyAstronomy.solar_elevation_degrees(0.5, date)
	SkyAstronomy.reset_observer()
	assert_almost_eq(paide_noon - reval_noon, 59.437 - 58.889, 0.02, "noon sun higher by the latitude difference")
	assert_almost_eq(SkyAstronomy.observer_latitude_degrees, SkyAstronomy.OBSERVER_LATITUDE_DEGREES, 0.0001)


func test_paide_scene_has_sky_and_weather_but_no_sea() -> void:
	var scene: Node = load(PAIDE_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	await until_ready(scene)
	await Engine.get_main_loop().process_frame
	var world: CityWorld3D = scene.get("world")
	assert_true(world != null, "the city world is built")
	for sea_node: String in ["Sea", "OpenSea", "SeaLod", "SeaSurfBand0", "ShoreSpray", "Harbour", "Shore", "Ships"]:
		assert_true(world.find_child(sea_node, true, false) == null, "inland site has no %s" % sea_node)
	assert_true(world.ships == null and world.spray == null and world.sea_lod == null)
	assert_true(world.find_child("Harjapea", true, false) != null, "the brook is water")
	assert_true(world.sky_weather != null and world.sun != null, "shared sky, sun and weather")
	assert_true(world.environment != null and world.environment.sky != null, "the sky dome is mounted")
	assert_almost_eq(SkyAstronomy.observer_latitude_degrees, 58.889, 0.01, "sky over Paide")
	assert_true(scene.get("_npcs") == null and scene.get("_fauna") == null, "no people or animals yet")
	var player: Node2D = scene.get("player")
	var xz := CityPlan.to_world_xz(player.global_position)
	assert_true(xz.distance_to(Vector2(-150, 246)) < 1.0, "default arrival at the market (%s)" % xz)
	scene.queue_free()
	await Engine.get_main_loop().process_frame
	assert_almost_eq(
		SkyAstronomy.observer_latitude_degrees, SkyAstronomy.OBSERVER_LATITUDE_DEGREES, 0.0001,
		"leaving the site restores the Reval sky"
	)


func test_walking_off_the_edge_opens_the_travel_map() -> void:
	var scene: Node = load(PAIDE_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	await until_ready(scene)
	var plan: CityPlan = scene.get("plan")
	var player: Node2D = scene.get("player")
	var controller := player.get_node("WorldMapController") as WorldMapController
	assert_false(controller.is_open())
	var outside := Vector2(plan.bounds.end.x - 4.0, 0.0)
	player.global_position = CityPlan.to_logic(outside)
	scene.call("_check_city_edge", outside)
	assert_true(controller.is_open(), "the edge opens the global travel map")
	var back := CityPlan.to_world_xz(player.global_position)
	assert_true(plan.bounds.grow(-SiteLevel.EDGE_MARGIN).has_point(back), "player set back inside (%s)" % back)
	controller.close()
	scene.queue_free()
	await Engine.get_main_loop().process_frame
