extends "res://tests/godot/test_case.gd"

const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")
const HouseStyles := preload("res://scripts/map/view3d/map_view_mesh_builder_building_houses.gd")
const Config := preload("res://scripts/map/view3d/map_view_mesh_builder_config.gd")


const EXPECTED_TIERS := {
	&"pikk_corner_house": &"merchant_stone",
	&"vene_row_house": &"merchant_stone",
	&"vene_corner_house": &"merchant_stone",
	&"market_row_house": &"merchant_stone",
	&"saiakang_house": &"merchant_stone",
	&"vene_gate_house": &"merchant_stone",
	&"apothecary_house": &"merchant_stone",
	&"moneychangers_house": &"merchant_stone",
	&"kaik_house_west": &"merchant_stone",
	&"kaik_house_mid": &"merchant_stone",
	&"kaik_house_east": &"merchant_stone",
	&"glovers_house": &"merchant_stone",
	&"viru_house_stone": &"merchant_stone",
	&"merchants_house": &"merchant_stone",
	&"turg_house_north": &"merchant_timber",
	&"vanaturu_kael_house": &"merchant_timber",
	&"corner_house_muurivahe": &"merchant_timber",
	&"viru_house_west": &"merchant_timber",
	&"viru_house_mid": &"merchant_timber",
	&"viru_house_east": &"merchant_timber",
	&"weary_traveler_inn": &"merchant_timber",
	&"saddlers_house": &"merchant_timber",
	&"coopers_house": &"merchant_timber",
	&"rope_makers_house": &"merchant_timber",
	&"karja_corner_house": &"merchant_timber",
	&"turg_south_house": &"merchant_timber",
	&"west_lane_house": &"merchant_timber",
	&"glassblowers_house": &"merchant_timber",
	&"sauna_corner_house": &"craft_boda",
	&"kuninga_house_west": &"craft_boda",
	&"kuninga_house_mid": &"craft_boda",
	&"kuninga_house_east": &"craft_boda",
	&"vaike_karja_house": &"craft_boda",
	&"tenement_row": &"craft_boda",
	&"laundress_house": &"craft_boda",
	&"widows_house": &"craft_boda",
	&"dyers_house": &"craft_boda",
	&"hedge_house": &"craft_boda",
	&"wall_side_house": &"craft_boda",
	&"artisan_shed": &"craft_boda",
	&"potters_house": &"craft_boda",
	&"south_apron_timber_house": &"craft_boda",
	&"south_apron_far_roofs": &"craft_boda",
}

const EXCEPTIONAL_OR_SPECIAL_IDS: Array[StringName] = [
	&"st_catherines_church",
	&"monastery_cloister",
	&"monastery_barn",
	&"guild_storehouse",
	&"public_bathhouse",
	&"karja_gate_house",
	&"kalev_smithy",
]


func test_lower_town_assigns_mixed_r003_tiers_to_stable_ordinary_ids() -> void:
	var definition := LowerTownSliceDefinition.create()
	var by_id := {}
	for building in definition.buildings:
		by_id[building["id"]] = building

	var counts := {&"merchant_stone": 0, &"merchant_timber": 0, &"craft_boda": 0}
	for building_id in EXPECTED_TIERS:
		assert_true(by_id.has(building_id), "missing authored Lower Town building %s" % building_id)
		if not by_id.has(building_id):
			continue
		var building: Dictionary = by_id[building_id]
		var tier: StringName = building.get("house_tier", &"")
		assert_eq(tier, EXPECTED_TIERS[building_id], "%s tier drift" % building_id)
		assert_true(PropStyleVariants.is_known_house_tier(tier))
		counts[tier] = int(counts[tier]) + 1

	assert_true(int(counts[&"merchant_stone"]) >= 10, "primary-street stone frontage must be represented")
	assert_true(int(counts[&"merchant_timber"]) >= 10, "ordinary timber frontage must be represented")
	assert_true(int(counts[&"craft_boda"]) >= 6, "southern craft edge must include boda houses")


func test_lower_town_exceptional_and_special_buildings_remain_untiered() -> void:
	var definition := LowerTownSliceDefinition.create()
	for building in definition.buildings:
		if building["id"] in EXCEPTIONAL_OR_SPECIAL_IDS:
			assert_eq(building.get("house_tier", &""), &"", "%s must stay outside ordinary tiers" % building["id"])


func test_tier_fallback_and_authored_material_precedence_are_deterministic() -> void:
	for tier in [PropStyleVariants.HOUSE_TIER_MERCHANT_STONE, PropStyleVariants.HOUSE_TIER_MERCHANT_TIMBER, PropStyleVariants.HOUSE_TIER_CRAFT_BODA]:
		var fallback := {"id": StringName("fallback_%s" % String(tier)), "house_tier": tier}
		match tier:
			PropStyleVariants.HOUSE_TIER_MERCHANT_STONE:
				assert_eq(HouseStyles.house_style(fallback), Config.HOUSE_STYLE_STONE)
				assert_eq(HouseStyles.roof_style(fallback), Config.ROOF_STYLE_TILE)
			PropStyleVariants.HOUSE_TIER_MERCHANT_TIMBER:
				assert_eq(HouseStyles.house_style(fallback), Config.HOUSE_STYLE_TIMBER)
				assert_eq(HouseStyles.roof_style(fallback), Config.ROOF_STYLE_SHINGLE)
			PropStyleVariants.HOUSE_TIER_CRAFT_BODA:
				assert_eq(HouseStyles.house_style(fallback), Config.HOUSE_STYLE_LOG)

	var authored := {
		"id": &"authored_material_priority",
		"house_tier": PropStyleVariants.HOUSE_TIER_MERCHANT_STONE,
		"wall_material": &"plaster",
		"roof_material": &"thatch",
	}
	assert_eq(HouseStyles.house_style(authored), Config.HOUSE_STYLE_TIMBER)
	assert_eq(HouseStyles.roof_style(authored), Config.ROOF_STYLE_THATCH)
