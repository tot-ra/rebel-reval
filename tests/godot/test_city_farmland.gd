extends "res://tests/godot/test_case.gd"

## The farmed country round Reval (docs/SYSTEMS/FARMLAND.md): plan data,
## seasonal crop growth, pasture stock and the gate-house joints of the curtain.


func _plan() -> CityPlan:
	return CityPlan.load_default()


func test_the_plan_carries_fields_pastures_woods_and_farmsteads() -> void:
	var data := _plan().data
	assert_true((data["fields"] as Array).size() >= 100, "strip fields round the town")
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
