extends "res://tests/godot/test_case.gd"

## Padise regional site (ADR 0042, docs/SYSTEMS/REGIONAL_SITES.md): the plan
## loads from its own directory, the 1343 monastery keeps the greybox anchor
## contract the monastery controller reads, the scene has sky and weather but
## no sea, the monks stand at their anchors before the attack, every manifest
## spawn is a plan arrival and the edge opens the travel map.

const PADISE_SCENE := "res://scenes/world/sites/padise.tscn"
const SiteLevel := preload("res://scenes/world/sites/site_level.gd")
const Controller := preload("res://scripts/world/padise_monastery_controller.gd")
## Later than 1343 (period rule): none of these may appear in the plan.
const LATE_WORDS: Array[String] = ["quadrangle", "gun tower", "abbey church", "moat"]
const PREFIXED_KEYS: Array[String] = [
	"buildings", "streets", "fields", "pastures", "districts", "points_of_interest", "woods"
]
const REQUIRED_BUILDINGS: Array[String] = [
	"padise.bldg.stone_house", "padise.bldg.niche_house", "padise.bldg.oratory", "padise.bldg.mill"
]
const SEA_NODES: Array[String] = [
	"Sea", "OpenSea", "SeaLod", "SeaSurfBand0", "ShoreSpray", "Harbour", "Shore", "Ships"
]


func _padise() -> CityPlan:
	return CityPlan.load_site("padise")


func test_padise_plan_loads_from_its_own_directory() -> void:
	var plan := _padise()
	assert_eq(plan.site_id, "padise")
	assert_eq(plan.site_dir, "res://content/world/padise")
	assert_almost_eq(plan.bounds.size.x, 600.0, 0.01, "600 m frame")
	assert_almost_eq(plan.bounds.size.y, 600.0, 0.01, "600 m frame")
	assert_almost_eq(plan.origin_latitude(), 59.2276, 0.01, "origin is Padise, not Reval")
	assert_false(plan.has_coast(), "Padise is inland: no shoreline, no sea")
	for feature: String in ["citizens", "fauna", "interiors"]:
		assert_false(plan.feature_enabled(feature), "%s off until a task enables them" % feature)


func test_padise_keeps_its_travel_ids() -> void:
	var definition := CityMapDefinition.from_plan(_padise())
	assert_eq(definition.map_id, &"world.padise")
	assert_eq(definition.location, &"loc.world_padise")
	assert_eq(DoorNavigator.get_scene_path(&"world_padise"), PADISE_SCENE)


func test_padise_ids_are_site_prefixed() -> void:
	var data := _padise().data
	for key: String in PREFIXED_KEYS:
		for record: Dictionary in data[key]:
			var id := String(record["id"])
			assert_true(id.begins_with("padise."), "%s id %s lacks the site prefix" % [key, id])


func test_monastery_is_the_1343_house_before_the_quadrangle() -> void:
	var data := _padise().data
	assert_true((data["towers"] as Array).is_empty(), "no towers in 1343")
	assert_true((data["curtains"] as Array).is_empty(), "no fortified circuit")
	assert_true((data["moat"] as Dictionary).is_empty(), "no moat")
	var ids: Dictionary = {}
	for b: Dictionary in data["buildings"]:
		ids[b["id"]] = b
		for word in LATE_WORDS:
			assert_false(String(b["name_1343"]).contains(word), "%s is later than 1343" % b["id"])
	for required: String in REQUIRED_BUILDINGS:
		assert_true(ids.has(required), "missing %s" % required)
	assert_eq(ids["padise.bldg.stone_house"]["material"], "limestone", "the attested early masonry")
	assert_eq(ids["padise.bldg.oratory"]["material"], "log", "the oratory is timber in 1343")
	# An open estate: no wall round the close (the pipeline's free-standing walls
	# are crenellated curtains) and no paved market yard.
	assert_true((data["toompea_walls"] as Array).is_empty(), "no fortified close in 1343")
	assert_true((data["forum"] as Dictionary).is_empty(), "the close is not a paved square")
	assert_false((data["harjapea"] as Dictionary).is_empty(), "the Kloostri river is in the plan")


func test_controller_anchor_contract_comes_from_the_plan() -> void:
	var definition := Controller.definition_from_plan(_padise())
	var errors := Controller.validate_definition(definition)
	assert_true(errors.is_empty(), str(errors))
	for monk: Dictionary in Controller.phase_manifest(Controller.PHASE_BEFORE_ATTACK)["monks"]:
		var monk_anchor := StringName(monk["anchor_id"])
		assert_true(MapVerification.has_anchor(definition, monk_anchor), "monk anchor %s" % monk_anchor)
	var inner := _padise().bounds.grow(-SiteLevel.EDGE_MARGIN)
	for anchor: Dictionary in definition.interaction_anchors:
		var at := CityPlan.to_world_xz(anchor["position"])
		assert_true(inner.has_point(at), "%s inside the frame" % anchor["id"])


func test_every_manifest_spawn_is_a_plan_arrival_inside_the_edge() -> void:
	var plan := _padise()
	var inner := plan.bounds.grow(-SiteLevel.EDGE_MARGIN)
	var spawns := DoorNavigator.get_scene_spawn_ids(&"world_padise")
	assert_eq(spawns.size(), 2, "from_reval_west, from_world_parnu")
	for spawn: StringName in spawns:
		var arrival := plan.arrival_spawn(String(spawn))
		assert_false(arrival.is_empty(), "%s has no plan arrival" % spawn)
		var at := CityTravel.spawn_position(plan, String(spawn))
		assert_true(inner.has_point(at), "%s arrives inside the edge band (%s)" % [spawn, at])
		assert_true(String(arrival["record"]).begins_with("padise.spawn."))


func test_padise_scene_has_sky_weather_and_monks_but_no_sea() -> void:
	SessionState.state.set_phase(&"phase.prologue_day")
	var scene: Node = load(PADISE_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	await until_ready(scene)
	await Engine.get_main_loop().process_frame
	var world: CityWorld3D = scene.get("world")
	assert_true(world != null, "the city world is built")
	for sea_node: String in SEA_NODES:
		assert_true(world.find_child(sea_node, true, false) == null, "inland site has no %s" % sea_node)
	assert_true(world.ships == null and world.spray == null and world.sea_lod == null)
	assert_true(world.find_child("Harjapea", true, false) != null, "the river is water")
	assert_true(world.sky_weather != null and world.sun != null, "shared sky, sun and weather")
	assert_almost_eq(SkyAstronomy.observer_latitude_degrees, 59.2276, 0.01, "sky over Padise")
	var monastery: PadiseMonasteryController = scene.get("monastery")
	assert_true(monastery != null, "the monastery controller is mounted")
	assert_eq(monastery.current_phase(), Controller.PHASE_BEFORE_ATTACK)
	var monks := monastery.spawned_monks()
	assert_eq(monks.size(), 2, "choir and lay brother before the attack")
	var definition := Controller.definition_from_plan(scene.get("plan"))
	for monk: Node2D in monks:
		assert_true(monk is PadiseMonkActor, "%s is a monk actor" % monk.name)
		assert_eq(monk.get_parent(), scene.get("actors"), "monks live on the actors plane")
	assert_eq(
		monks[0].global_position,
		MapVerification.anchor_position(definition, &"landmark_timber_oratory"),
		"the choir monk stands before the oratory"
	)
	var player: Node2D = scene.get("player")
	var xz := CityPlan.to_world_xz(player.global_position)
	assert_true(xz.distance_to(Vector2(-6, -38)) < 1.0, "default arrival by the cart gate (%s)" % xz)
	# After the attack the house is empty.
	SessionState.state.set_phase(&"phase.act1_climax")
	assert_eq(monastery.current_phase(), Controller.PHASE_AFTER_ATTACK)
	assert_true(monastery.spawned_monks().is_empty(), "no monks after St George's Night")
	SessionState.state.set_phase(&"phase.prologue_day")
	scene.queue_free()
	await Engine.get_main_loop().process_frame
	assert_almost_eq(
		SkyAstronomy.observer_latitude_degrees, SkyAstronomy.OBSERVER_LATITUDE_DEGREES, 0.0001,
		"leaving the site restores the Reval sky"
	)


func test_walking_off_the_edge_opens_the_travel_map() -> void:
	var scene: Node = load(PADISE_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	await until_ready(scene)
	var plan: CityPlan = scene.get("plan")
	var player: Node2D = scene.get("player")
	var controller := player.get_node("WorldMapController") as WorldMapController
	assert_false(controller.is_open())
	var outside := Vector2(plan.bounds.end.x - 4.0, -30.0)
	player.global_position = CityPlan.to_logic(outside)
	scene.call("_check_city_edge", outside)
	assert_true(controller.is_open(), "the edge opens the global travel map")
	var back := CityPlan.to_world_xz(player.global_position)
	var inner := plan.bounds.grow(-SiteLevel.EDGE_MARGIN)
	assert_true(inner.has_point(back), "player set back inside (%s)" % back)
	controller.close()
	scene.queue_free()
	await Engine.get_main_loop().process_frame


func test_travel_graph_reaches_reval_and_parnu_from_padise() -> void:
	# The global map keeps Padise's neighbours and the spawn ids they land on.
	var entry := GlobalMapCatalog.get_location(&"world_padise")
	assert_array_contains(entry["neighbors"], &"world_parnu")
	assert_true(DoorNavigator.has_spawn(&"world_padise", entry["arrival_spawn_id"]))
	assert_true(DoorNavigator.has_spawn(&"world_padise", &"from_world_parnu"))
