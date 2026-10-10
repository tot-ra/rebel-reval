extends "res://tests/godot/test_case.gd"

## Saaremaa regional site (ADR 0042, task R-1524, docs/SYSTEMS/REGIONAL_SITES.md):
## choosing Saaremaa on the travel map loads Kaali. The plan keeps the travel
## ids, lands every manifest spawn inside the edge, carves the crater bowl
## round a still lake the player can swim in, builds sky and weather without a
## sea, and opens the travel map at the edge.

const SiteLevel := preload("res://scenes/world/sites/site_level.gd")
const SCENE := "res://scenes/world/sites/saaremaa.tscn"
const SEA_NODES: Array[String] = [
	"Sea", "OpenSea", "SeaLod", "SeaSurfBand0", "ShoreSpray", "Harbour", "Shore", "Ships"
]
const PREFIXED_KEYS: Array[String] = [
	"buildings", "streets", "fields", "pastures", "districts", "points_of_interest", "woods", "lakes"
]


func _lake(plan: CityPlan) -> Dictionary:
	return (plan.data.get("lakes", []) as Array)[0]


func _scene() -> Node:
	var scene: Node = load(SCENE).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	await until_ready(scene)
	await Engine.get_main_loop().process_frame
	return scene


func test_travel_map_loads_the_kaali_site() -> void:
	assert_eq(DoorNavigator.get_scene_path(&"world_saaremaa"), SCENE)
	var plan := CityPlan.load_site("saaremaa")
	assert_eq(plan.site_dir, "res://content/world/saaremaa")
	assert_almost_eq(plan.bounds.size.x, 500.0, 0.01)
	assert_almost_eq(plan.origin_latitude(), 58.3728, 0.001, "frame on the Kaali lake")
	assert_false(plan.has_coast(), "Kaali is inland")
	var definition := CityMapDefinition.from_plan(plan)
	assert_eq(definition.map_id, &"world.saaremaa")
	assert_eq(definition.location, &"loc.world_saaremaa")
	for key: String in PREFIXED_KEYS:
		for record: Dictionary in plan.data.get(key, []):
			assert_true(String(record["id"]).begins_with("saaremaa."), "%s id %s" % [key, record["id"]])


func test_every_manifest_spawn_is_a_plan_arrival_inside_the_edge() -> void:
	var plan := CityPlan.load_site("saaremaa")
	var inner := plan.bounds.grow(-SiteLevel.EDGE_MARGIN)
	var spawns := DoorNavigator.get_scene_spawn_ids(&"world_saaremaa")
	for spawn: StringName in [&"from_reval_harbor", &"from_world_parnu", &"from_world_poide"]:
		assert_array_contains(spawns, spawn)
	for spawn: StringName in spawns:
		var arrival := plan.arrival_spawn(String(spawn))
		assert_false(arrival.is_empty(), "%s has no plan arrival" % spawn)
		assert_true(inner.has_point(CityTravel.spawn_position(plan, String(spawn))), "%s inside" % spawn)


func test_crater_bowl_holds_the_lake_below_its_rim() -> void:
	var plan := CityPlan.load_site("saaremaa")
	var lake := _lake(plan)
	var centre := Vector2(lake["at"][0], lake["at"][1])
	var surface := float(lake["surface"])
	var radius := float(lake["radius"])
	assert_true(radius > 12.0 and radius < 32.0, "lake %s m" % radius)
	assert_true(surface - plan.ground_height(centre) > 2.5, "lake deep enough to swim")
	var rim := plan.ground_height(centre + Vector2(0.0, -55.0))
	var plain := plan.ground_height(centre + Vector2(0.0, -150.0))
	assert_true(rim - surface > 12.0, "rim %.1f over the water %.1f" % [rim, surface])
	assert_true(rim > plain + 2.0, "raised rim %.1f over the plain %.1f" % [rim, plain])
	for tree: Array in plan.data["trees"]:
		assert_true(
			Vector2(tree[0], tree[1]).distance_to(centre) > float(lake["radius"]), "tree in the lake"
		)


func test_scene_has_sky_lake_water_and_no_sea() -> void:
	var scene: Node = await _scene()
	var world: CityWorld3D = scene.get("world")
	var plan: CityPlan = scene.get("plan")
	for sea_node: String in SEA_NODES:
		assert_true(world.find_child(sea_node, true, false) == null, "no %s" % sea_node)
	assert_true(world.sky_weather != null and world.sun != null, "shared sky and weather")
	assert_almost_eq(SkyAstronomy.observer_latitude_degrees, 58.3728, 0.001, "sky over Kaali")
	assert_true(world.find_child("Lake_saaremaa_lake", true, false) != null, "lake is drawn")
	var lake := _lake(plan)
	var centre := Vector2(lake["at"][0], lake["at"][1])
	assert_almost_eq(world.water_surface_at(centre), float(lake["surface"]), 0.001)
	var medium := world.water_medium_at(centre)
	assert_false(medium.is_empty(), "under the lake surface is water")
	assert_true(medium["material"] == world.lake_material, "lake material")
	var view = scene.get("view")
	assert_true(view.water_depth_at(centre) > 2.5, "Kalev swims in the middle of the lake")
	var bank := centre + Vector2(float(lake["radius"]) + 1.2, 0.0)
	assert_almost_eq(view.water_depth_at(bank), 0.0, 0.001, "dry bank inside the swim circle")
	scene.queue_free()
	await Engine.get_main_loop().process_frame


func test_walking_off_the_edge_opens_the_travel_map() -> void:
	var scene: Node = await _scene()
	var plan: CityPlan = scene.get("plan")
	var player: Node2D = scene.get("player")
	var controller := player.get_node("WorldMapController") as WorldMapController
	var outside := Vector2(plan.bounds.end.x - 4.0, 0.0)
	player.global_position = CityPlan.to_logic(outside)
	scene.call("_check_city_edge", outside)
	assert_true(controller.is_open(), "edge opens the global travel map")
	controller.close()
	scene.queue_free()
	await Engine.get_main_loop().process_frame
