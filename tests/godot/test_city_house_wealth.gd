extends "res://tests/godot/test_case.gd"

## R-1659: census wealth drives the timber wall plate and window repertoire.

const HouseWealth := preload("res://scripts/city/city_house_wealth.gd")


func _square(side: float) -> PackedVector2Array:
	return PackedVector2Array(
		[Vector2.ZERO, Vector2(side, 0), Vector2(side, side), Vector2(0, side)]
	)


func test_census_class_maps_to_tier() -> void:
	HouseWealth.bind_tiers({"b.poor": 0, "b.rich": 2})
	var small := _square(5.0)
	assert_eq(HouseWealth.tier_of({"id": "b.rich", "material": "log"}, small), 2, "census rich")
	var stone_poor := {"id": "b.poor", "material": "limestone"}
	assert_eq(HouseWealth.tier_of(stone_poor, _square(20)), 0, "census wins")
	assert_eq(HouseWealth.CLASS_TIER["master"], 1, "master is middling")
	assert_eq(HouseWealth.CLASS_TIER["great"], 2, "great is rich")
	HouseWealth.clear()


func test_fallback_is_deterministic() -> void:
	HouseWealth.clear()
	assert_eq(HouseWealth.tier_of({"id": "x", "material": "limestone"}, _square(5)), 2, "stone")
	assert_eq(HouseWealth.tier_of({"id": "x", "material": "log"}, _square(12)), 2, "big house")
	assert_eq(HouseWealth.tier_of({"id": "x", "material": "log"}, _square(9)), 1, "mid house")
	assert_eq(
		HouseWealth.tier_of({"id": "x", "material": "log", "kind": "outbuilding"}, _square(12)),
		0,
		"outbuilding"
	)
	var b := {"id": "house.small", "material": "log"}
	assert_eq(HouseWealth.tier_of(b, _square(5)), HouseWealth.tier_of(b, _square(5)), "stable")


func test_timber_walls_vary_and_follow_wealth() -> void:
	var stems := {}
	var weathered := [0, 0, 0]
	var tar := [0, 0, 0]
	for i in 40:
		var b := {"id": "house.%d" % i, "material": "log"}
		for tier in 3:
			var stem := HouseWealth.wall_stem(b, &"log", tier)
			assert_true(stem.begins_with("logwall_"), "log stem %s" % stem)
			stems[stem] = true
			weathered[tier] += int(stem == "logwall_weathered")
			tar[tier] += int(stem == "logwall_tar")
		assert_true(HouseWealth.wall_stem(b, &"plank", 1).begins_with("plank_"), "plank stem")
		assert_eq(HouseWealth.wall_stem(b, &"limestone", 2), "", "stone keeps one plate")
	assert_eq(stems.size(), 3, "all three log plates are used")
	assert_true(weathered[0] > weathered[2], "poor walls are greyer than rich")
	assert_true(tar[2] > tar[0], "rich walls are tarred more often")
	assert_eq(tar[0], 0, "no tarred poor cottage")


func test_wall_material_key_resolves_to_its_plate() -> void:
	var plain := CityBuildingBuilder.material_for_key("wall:log")
	var tar := CityBuildingBuilder.material_for_key("wall:log:logwall_tar")
	var grey := CityBuildingBuilder.material_for_key("wall:log:logwall_weathered")
	assert_true(tar is ShaderMaterial and grey is ShaderMaterial, "weathered wall shader")
	assert_true(tar != grey and tar != plain, "one material per plate")
	assert_true(
		(tar as ShaderMaterial).get_shader_parameter("albedo_tex")
		!= (grey as ShaderMaterial).get_shader_parameter("albedo_tex"),
		"different textures"
	)
	assert_true(
		float((grey as ShaderMaterial).get_shader_parameter("age"))
		> float((tar as ShaderMaterial).get_shader_parameter("age")),
		"bare grey logs weather more than tarred ones"
	)
