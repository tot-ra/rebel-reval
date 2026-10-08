extends "res://tests/godot/test_case.gd"

## The farmed country round Reval (docs/SYSTEMS/FARMLAND.md): plan data,
## seasonal crop growth, pasture stock and the gate-house joints of the curtain.


func _plan() -> CityPlan:
	return CityPlan.load_default()


func test_the_plan_carries_fields_pastures_woods_and_farmsteads() -> void:
	var data := _plan().data
	assert_true((data["fields"] as Array).size() >= 90, "strip fields round the town")
	assert_true((data["pastures"] as Array).size() >= 15, "crofts and common pastures")
	assert_true((data["woods"] as Array).size() >= 5, "woods")
	assert_true((data["farmsteads"] as Array).size() >= 20, "farmsteads")
	var crops := {}
	for f: Dictionary in data["fields"]:
		crops[f["crop"]] = true
		assert_true(CityFarmland.CROPS.has(StringName(f["crop"])) or f["crop"] == "fallow", "known crop %s" % f["crop"])  # gdlint: ignore=max-line-length
	for crop in ["rye", "barley", "oat", "wheat", "flax", "cabbage"]:
		assert_true(crops.has(crop), "%s is grown" % crop)


func test_no_tree_or_building_stands_in_a_field() -> void:
	var plan := _plan()
	for f in CityFarmland.features_for(plan):
		if f["kind"] != &"field":
			continue
		var poly: PackedVector2Array = f["polygon"]
		for t: Array in plan.data["trees"]:
			assert_false(Geometry2D.is_point_in_polygon(Vector2(t[0], t[1]), poly), "%s holds no tree" % f["id"])  # gdlint: ignore=max-line-length
		assert_eq(plan.building_at(f["centre"]), -1, "%s holds no building" % f["id"])


func test_orchards_hold_fruit_trees_and_stay_clear_of_fields() -> void:
	var plan := _plan()
	var orchards: Array = plan.data.get("orchards", [])
	assert_true(orchards.size() >= 15, "fenced fruit gardens round the farmsteads")
	var fruit := {&"apple": true, &"cherry": true, &"plum": true, &"pear": true}
	var seen := {}
	for o: Dictionary in orchards:
		var poly := CityPlan.points(o["polygon"])
		var inside := 0
		for t: Array in plan.data["trees"]:
			if Geometry2D.is_point_in_polygon(Vector2(t[0], t[1]), poly):
				inside += 1
				assert_true(fruit.has(StringName(t[2])), "%s holds only fruit trees, not %s" % [o["id"], t[2]])
				seen[StringName(t[2])] = true
		assert_eq(inside, int(o["trees"]), "%s tree count matches the plan" % o["id"])
	assert_true(seen.has(&"apple") and seen.has(&"cherry"), "apple and cherry are planted")
	for f in CityFarmland.features_for(plan):
		if f["kind"] != &"orchard":
			continue
		for g in CityFarmland.features_for(plan):
			if g["kind"] == &"field":
				assert_false(Geometry2D.intersect_polygons(f["polygon"], g["polygon"]).size() > 0, "%s clear of %s" % [f["id"], g["id"]])  # gdlint: ignore=max-line-length


func test_crops_follow_the_calendar() -> void:
	# 21 April (day 111): winter grain is green and low, spring grain only sown.
	assert_true(CityFarmland.growth(&"winter", 111) > 0.25)
	assert_true(CityFarmland.growth(&"winter", 111) < 0.45)
	assert_true(CityFarmland.growth(&"spring", 111) < CityFarmland.MIN_GROWTH)
	assert_almost_eq(CityFarmland.growth(&"winter", 190), 1.0, 0.001)
	assert_true(CityFarmland.growth(&"spring", 250) < 0.2, "stubble after harvest")
	assert_eq(CityFarmland.growth(&"garden", 300), 0.0)
	assert_eq(CityFarmland.tint(&"winter", 111), Color.WHITE)
	assert_ne(CityFarmland.tint(&"winter", 215), Color.WHITE, "ripe grain is gold")


func test_pastures_carry_livestock() -> void:
	var plan := _plan()
	var seen := {}
	for group in CityFauna.groups_for(plan):
		if String(group["id"]).begins_with("pasture."):
			seen[group["species"]] = true
	for species in [&"cow", &"sheep"]:
		assert_true(seen.has(species), "%s graze the pastures" % species)


func test_every_curtain_end_at_a_gate_lands_inside_the_gate_house() -> void:
	var plan := _plan()
	for g: Dictionary in plan.data["gates"]:
		if String(g["state"]) == "wooden":
			continue
		var at := Vector2(g["at"][0], g["at"][1])
		var along := Vector2(cos(float(g["angle"])), sin(float(g["angle"])))
		for toward: Vector2 in [along, -along, along.orthogonal()]:
			var joint := CityFortificationBuilder.gate_joint(g, toward)
			var local := (joint - at)
			assert_true(absf(local.dot(along)) < CityFortificationBuilder._gate_half_extent(g), "%s joint is within the house" % g["id"])  # gdlint: ignore=max-line-length
			assert_true(absf(local.dot(along.orthogonal())) < 0.01, "%s joint is on the gate axis" % g["id"])


func test_roads_cross_the_hareapea_on_timber_bridges() -> void:
	var plan := _plan()
	var bridges: Array = plan.data["bridges"]
	assert_true(bridges.size() >= 2, "Viru and Tartu roads are bridged")
	for b: Dictionary in bridges:
		var at := Vector2(b["at"][0], b["at"][1])
		var deck := plan.bridge_deck_height(at)
		assert_false(is_nan(deck), "%s has a deck at its middle" % b["id"])
		assert_eq(plan.walk_height(at), deck, "%s is walked on its deck" % b["id"])
		assert_true(deck > 0.5, "%s deck clears the water" % b["id"])
		assert_true(is_nan(plan.bridge_deck_height(at + Vector2(0.0, 80.0))), "%s deck is local" % b["id"])  # gdlint: ignore=max-line-length


func test_the_east_curtain_has_a_moat() -> void:
	var plan := _plan()
	var points := CityPlan.points(plan.data["moat"]["points"])
	var east := 0
	for p in points:
		if p.x > 200.0 and p.y < -100.0:
			east += 1
	assert_true(east >= 20, "ditch runs up the east side, got %d points" % east)


func test_farm_yards_have_distinct_historical_outbuildings() -> void:
	var plan := _plan()
	var types := {}
	for b: Dictionary in plan.data["buildings"]:
		if String(b["kind"]) != "outbuilding":
			continue
		types[b["type"]] = (types.get(b["type"], 0) as int) + 1
		assert_false(bool(b["enterable"]), "%s is not a dwelling to enter" % b["id"])
	for type in ["barn_dwelling", "barn", "byre", "sheep_shed", "pigsty", "hen_house", "store"]:
		assert_true(types.has(type), "%s is built" % type)
	assert_false(types.has("rabbit_hutch"), "no rabbit hutches in 1343 Estonia")
	# Livestock stands at its own sheds.
	var yard := {}
	for group in CityFauna.groups_for(plan):
		if "bldg." in String(group["id"]):
			yard[group["species"]] = true
	for species in [&"chicken", &"pig", &"cow", &"sheep"]:
		assert_true(yard.has(species), "%s kept at an outbuilding" % species)


func test_both_shores_are_dressed_from_the_dossiers() -> void:
	var plan := _plan()
	var harbour: Dictionary = plan.data["harbour"]
	assert_false((harbour["crane"] as Dictionary).is_empty(), "one yard crane")
	assert_eq((harbour["net_yards"] as Array).size(), 3, "three net yards")
	assert_eq((harbour["landings"] as Array).size(), 3, "three beach decks")
	assert_true((harbour["boats"] as Array).size() >= 6, "six to eight boats on the sand")
	var decks := 0
	for b: Dictionary in plan.data["bridges"]:
		if String(b.get("kind", "")) in ["jetty", "beach_deck"]:
			decks += 1
			var at := Vector2(b["at"][0], b["at"][1])
			assert_false(is_nan(plan.bridge_deck_height(at)), "%s is walkable" % b["id"])
	assert_eq(decks, 5, "two jetties and three beach decks")
	var types := {}
	for b: Dictionary in plan.data["buildings"]:
		if String(b["kind"]) == "outbuilding":
			types[b["type"]] = true
	for type in ["cargo_shed", "smoke_shed", "salt_shed"]:
		assert_true(types.has(type), "%s stands on the shore" % type)
