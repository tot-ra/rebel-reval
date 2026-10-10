extends "res://tests/godot/test_case.gd"

## Act 2 hinterland regional sites (ADR 0042, docs/SYSTEMS/REGIONAL_SITES.md):
## the Harju village, the rebel kings' camp and the sacred grove. Each plan
## loads from its own directory with its own frame and sky, keeps its travel
## ids, prefixes every record id, lands every manifest spawn inside the edge,
## builds sky and weather without a sea, carries its point-of-interest
## dressing (smoke, fires, stones, spring) and opens the travel map at the edge.

const SiteLevel := preload("res://scenes/world/sites/site_level.gd")
const Hinterland := preload("res://scenes/world/sites/hinterland_site.gd")
const PREFIXED_KEYS: Array[String] = [
	"buildings", "streets", "fields", "pastures", "districts", "points_of_interest", "woods", "gates"
]
const SEA_NODES: Array[String] = [
	"Sea", "OpenSea", "SeaLod", "SeaSurfBand0", "ShoreSpray", "Harbour", "Shore", "Ships"
]
## site id -> [frame size m, origin latitude, location id, map id, manifest spawn count]
const SITES := {
	"harju": [700.0, 59.46, &"world_harju", &"world.harju", 5],
	"rebel_kings": [500.0, 59.3666, &"world_rebel_kings", &"world.rebel_kings", 2],
	"sacred_grove": [500.0, 59.427, &"world_sacred_grove", &"world.sacred_grove", 2],
}


func _scene_path(site: String) -> String:
	return "res://scenes/world/sites/%s.tscn" % site


func _pois_of(plan: CityPlan, kind: String) -> Array:
	return (plan.data["points_of_interest"] as Array).filter(
		func(p: Dictionary) -> bool: return String(p["kind"]) == kind
	)


func test_plans_load_from_their_own_directories() -> void:
	for site: String in SITES:
		var row: Array = SITES[site]
		var plan := CityPlan.load_site(site)
		assert_eq(plan.site_id, site)
		assert_eq(plan.site_dir, "res://content/world/%s" % site)
		assert_almost_eq(plan.bounds.size.x, row[0], 0.01, "%s frame" % site)
		assert_almost_eq(plan.bounds.size.y, row[0], 0.01, "%s frame" % site)
		assert_almost_eq(plan.origin_latitude(), row[1], 0.01, "%s origin is its own" % site)
		assert_false(plan.has_coast(), "%s is inland" % site)
		for feature: String in ["citizens", "fauna"]:
			assert_false(plan.feature_enabled(feature), "%s %s off" % [site, feature])
		# Harju's farmsteads can be walked into (R-1627); the camp and grove cannot.
		assert_eq(plan.feature_enabled("interiors"), site == "harju", "%s interiors" % site)
		assert_false((plan.data["harjapea"] as Dictionary).is_empty(), "%s has its water" % site)


func test_sites_keep_their_travel_ids_and_prefix_records() -> void:
	for site: String in SITES:
		var row: Array = SITES[site]
		var plan := CityPlan.load_site(site)
		var definition := CityMapDefinition.from_plan(plan)
		assert_eq(definition.map_id, row[3])
		assert_eq(definition.location, StringName("loc.%s" % row[2]))
		assert_eq(DoorNavigator.get_scene_path(row[2]), _scene_path(site))
		for key: String in PREFIXED_KEYS:
			for record: Dictionary in plan.data[key]:
				var id := String(record["id"])
				assert_true(id.begins_with(site + "."), "%s id %s lacks the prefix" % [key, id])


func test_every_manifest_spawn_is_a_plan_arrival_inside_the_edge() -> void:
	for site: String in SITES:
		var row: Array = SITES[site]
		var plan := CityPlan.load_site(site)
		var inner := plan.bounds.grow(-SiteLevel.EDGE_MARGIN)
		var spawns := DoorNavigator.get_scene_spawn_ids(row[2])
		assert_eq(spawns.size(), row[4], "%s keeps every spawn id" % site)
		for spawn: StringName in spawns:
			var arrival := plan.arrival_spawn(String(spawn))
			assert_false(arrival.is_empty(), "%s %s has no plan arrival" % [site, spawn])
			var at := CityTravel.spawn_position(plan, String(spawn))
			assert_true(inner.has_point(at), "%s %s inside the edge (%s)" % [site, spawn, at])
			assert_true(String(arrival["record"]).begins_with(site + ".spawn."))


func test_village_is_smoke_room_farmsteads_without_chimneys() -> void:
	var plan := CityPlan.load_site("harju")
	var dwellings := 0
	for b: Dictionary in plan.data["buildings"]:
		# 1343: split boards under birch bark; the high thatch is 15th-16th c. (R-1627).
		assert_eq(b["roof"], "shingle", "%s has a board roof" % b["id"])
		assert_eq(b["kind"], "outbuilding", "%s has no glazed windows or chimney" % b["id"])
		if String(b["id"]).ends_with(".dwelling"):
			dwellings += 1
			assert_eq(b["type"], "smoke_room")
	assert_eq(dwellings, 7, "five village farmsteads and two outlying ones")
	assert_true(_pois_of(plan, "smoke").size() >= 7, "smoke over every smoke room")
	assert_false((plan.data["fields"] as Array).is_empty(), "strip fields")
	assert_true((plan.data["curtains"] as Array).is_empty(), "no fortification")


## Every Harju building has a door Kalev's 1 m capsule fits through and can be
## entered; every dwelling is furnished from its authored household (R-1627).
func test_every_harju_building_is_enterable_and_dwellings_furnished() -> void:
	var plan := CityPlan.load_site("harju")
	var interiors := CityInteriors.create(plan, CitizenRoster.load_for(plan), [])
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		assert_true(bool(b["enterable"]), "%s enterable" % b["id"])
		assert_true(b["door"] != null, "%s has a door" % b["id"])
		assert_true(CityBuildingBuilder.door_size(b).x >= 1.2, "%s door wide enough" % b["id"])
		if not String(b["id"]).ends_with(".dwelling"):
			assert_false(interiors.is_lived_in(i), "%s is not lived in" % b["id"])
			continue
		assert_true(interiors.is_lived_in(i), "%s lived in" % b["id"])
		var layout := interiors.layout(i)
		assert_true(layout != null and layout.hearth >= 0, "%s has a hearth" % b["id"])
		assert_false(layout.slots_of(&"sleep").is_empty(), "%s has beds" % b["id"])
	interiors.free()


## Farmsteads stand apart: yards of the loose village cluster 75 m or more from
## each other, and no crop strip reaches a road surface.
func test_farmsteads_spread_and_fields_clear_of_roads() -> void:
	var plan := CityPlan.load_site("harju")
	var centres: Array[Vector2] = []
	for i in plan.buildings.size():
		if String(plan.buildings[i]["id"]).ends_with(".dwelling"):
			centres.append(_centre(plan.footprint(i)))
	for a in centres.size():
		for c in range(a + 1, centres.size()):
			assert_true(centres[a].distance_to(centres[c]) >= 75.0, "farmsteads %d and %d apart" % [a, c])
	for f: Dictionary in plan.data["fields"]:
		var poly := CityPlan.points(f["polygon"])
		for s: Dictionary in plan.streets:
			var pts := CityPlan.points(s["points"])
			for k in pts.size() - 1:
				for q in poly:
					var d := Geometry2D.get_closest_point_to_segment(q, pts[k], pts[k + 1]).distance_to(q)
					assert_true(d >= float(s["width"]) * 0.5, "%s off %s" % [f["id"], s["id"]])


func _centre(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / poly.size()


func test_camp_has_a_stake_fence_fires_and_horse_lines() -> void:
	var plan := CityPlan.load_site("rebel_kings")
	for curtain: Dictionary in plan.data["curtains"]:
		assert_eq(curtain["state"], "palisade", "the kings' enclosure is a stake fence")
	assert_eq((plan.data["gates"] as Array).size(), 2)
	for gate: Dictionary in plan.data["gates"]:
		assert_eq(gate["state"], "wooden")
	assert_true(_pois_of(plan, "campfire").size() >= 8, "cooking fires and the council fire")
	var horse_lines := (plan.data["pastures"] as Array).filter(
		func(p: Dictionary) -> bool: return String(p["id"]).ends_with("horse_lines")
	)
	assert_eq(horse_lines.size(), 1)
	assert_true(bool(horse_lines[0]["fence"]), "the horse lines are fenced")


func test_grove_has_no_building_and_its_stones_and_spring() -> void:
	var plan := CityPlan.load_site("sacred_grove")
	assert_true((plan.data["buildings"] as Array).is_empty(), "no human building at the hiis")
	assert_eq(_pois_of(plan, "offering_stone").size(), 4)
	assert_eq(_pois_of(plan, "spring").size(), 1)
	var oaks := (plan.data["trees"] as Array).filter(func(t: Array) -> bool: return t[2] == "oak")
	assert_true(oaks.size() >= 20, "old oaks in the grove (%d)" % oaks.size())


## The bird sound sampler asks for the HUD location every frame; a site without
## buildings must not be read as standing inside building 0 (it used to index
## an empty array and fail on every frame at the grove).
func test_bird_context_works_on_a_site_without_buildings() -> void:
	var plan := CityPlan.load_site("sacred_grove")
	var definition := CityMapDefinition.from_plan(plan)
	var meadow := plan.point_of_interest("sacred_grove.spawn.meadow")
	var xz := plan.bounds.get_center()
	if not meadow.is_empty():
		xz = Vector2(meadow["at"][0], meadow["at"][1])
	assert_eq(plan.location_at(xz).get("building", "?"), "")
	assert_false(definition.bird_context_at(xz * float(definition.cell_size)) == &"")


func test_scenes_have_sky_weather_dressing_and_no_sea() -> void:
	for site: String in SITES:
		var scene: Node = load(_scene_path(site)).instantiate()
		Engine.get_main_loop().root.add_child(scene)
		await until_ready(scene)
		await Engine.get_main_loop().process_frame
		var world: CityWorld3D = scene.get("world")
		assert_true(world != null, "%s world is built" % site)
		for sea_node: String in SEA_NODES:
			assert_true(world.find_child(sea_node, true, false) == null, "%s has no %s" % [site, sea_node])
		assert_true(world.sky_weather != null and world.sun != null, "%s shared sky and weather" % site)
		assert_almost_eq(
			SkyAstronomy.observer_latitude_degrees, SITES[site][1], 0.01, "sky over %s" % site
		)
		assert_true(world.find_child("Harjapea", true, false) != null, "%s water is drawn" % site)
		var plan: CityPlan = scene.get("plan")
		var dressing: Node3D = scene.get("dressing")
		assert_true(dressing != null, "%s dressing mounted" % site)
		var fires := dressing.find_children("Campfire_*", "", false, false)
		assert_eq(fires.size(), _pois_of(plan, "campfire").size(), "%s one fire per campfire" % site)
		var plumes := _pois_of(plan, "smoke").size() + fires.size()
		var lit_ids := world.smoke.lit.map(func(c: Array) -> String: return String(c[1]))
		for poi: Dictionary in _pois_of(plan, "smoke") + _pois_of(plan, "campfire"):
			assert_true(lit_ids.has(String(poi["id"])), "%s plume for %s" % [site, poi["id"]])
		assert_true(lit_ids.size() >= plumes)
		assert_eq(
			dressing.find_children("OfferingStone_*", "", false, false).size(),
			_pois_of(plan, "offering_stone").size()
		)
		assert_eq(
			dressing.find_children("Spring_*", "", false, false).size(), _pois_of(plan, "spring").size()
		)
		var player: Node2D = scene.get("player")
		var xz := CityPlan.to_world_xz(player.global_position)
		var home: Dictionary = plan.arrival_spawn(String(plan.site_info()["default_spawn"]))
		assert_true(
			xz.distance_to(Vector2(home["at"][0], home["at"][1])) < 1.0,
			"%s default arrival (%s)" % [site, xz]
		)
		scene.queue_free()
		await Engine.get_main_loop().process_frame
		assert_almost_eq(
			SkyAstronomy.observer_latitude_degrees,
			SkyAstronomy.OBSERVER_LATITUDE_DEGREES,
			0.0001,
			"leaving %s restores the Reval sky" % site
		)


func test_fires_burn_bright_at_night_and_low_by_day() -> void:
	var scene: Node = load(_scene_path("rebel_kings")).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	await until_ready(scene)
	var dressing: Node3D = scene.get("dressing")
	var light: OmniLight3D = dressing.find_children("*", "OmniLight3D", true, false)[0]
	Hinterland.apply_dressing_cycle(dressing, 0.5)
	var day := light.light_energy
	Hinterland.apply_dressing_cycle(dressing, 0.0)
	var night := light.light_energy
	assert_true(night > day * 3.0, "fire light day %.2f night %.2f" % [day, night])
	scene.queue_free()
	await Engine.get_main_loop().process_frame


func test_walking_off_the_edge_opens_the_travel_map() -> void:
	for site: String in SITES:
		var scene: Node = load(_scene_path(site)).instantiate()
		Engine.get_main_loop().root.add_child(scene)
		await until_ready(scene)
		var plan: CityPlan = scene.get("plan")
		var player: Node2D = scene.get("player")
		var controller := player.get_node("WorldMapController") as WorldMapController
		assert_false(controller.is_open())
		var outside := Vector2(plan.bounds.end.x - 4.0, 0.0)
		player.global_position = CityPlan.to_logic(outside)
		scene.call("_check_city_edge", outside)
		assert_true(controller.is_open(), "%s edge opens the global travel map" % site)
		var back := CityPlan.to_world_xz(player.global_position)
		assert_true(plan.bounds.grow(-SiteLevel.EDGE_MARGIN).has_point(back), "%s set back inside" % site)
		controller.close()
		scene.queue_free()
		await Engine.get_main_loop().process_frame


func test_travel_graph_links_the_hinterland() -> void:
	var harju := GlobalMapCatalog.get_location(&"world_harju")
	for neighbor: StringName in [&"world_sacred_grove", &"world_rebel_kings", &"world_kanavere"]:
		assert_array_contains(harju["neighbors"], neighbor)
	for site: StringName in [&"world_rebel_kings", &"world_sacred_grove"]:
		assert_array_contains(GlobalMapCatalog.get_location(site)["neighbors"], &"world_harju")
	for pair: Array in [
		[&"world_harju", &"from_world_rebel_kings"],
		[&"world_harju", &"from_world_sacred_grove"],
		[&"world_rebel_kings", &"from_world_harju"],
		[&"world_sacred_grove", &"from_world_harju"],
	]:
		assert_true(DoorNavigator.has_spawn(pair[0], pair[1]), "%s accepts %s" % pair)
	# Returning to Reval from the grove still lands outside the Harju gate.
	assert_eq(
		GlobalMapCatalog.get_location(&"world_sacred_grove")["gate_spawn_id"], &"from_world_sacred_grove"
	)
	assert_eq(
		CityTravel.redirect(&"reval_south", &"from_world_sacred_grove"),
		[&"reval_city", &"gate.harju.outside"]
	)
