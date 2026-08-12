extends "res://tests/godot/test_case.gd"

const URBAN_EXTERIOR_CASES := [
	["lower_town_slice", "res://content/maps/lower_town_slice.rrmap", 0.0, [
		"r454.lt.lowtown_datum",
		"r454.lt.pikk_to_harbourward",
		"r454.lt.viru_karja_spines",
		"r454.lt.south_boundary",
	]],
	["market_civic_quarter", "res://content/maps/market_civic_quarter.rrmap", 0.0, [
		"r454.market.forum_datum",
		"r454.market.east_throat_fall",
		"r454.market.south_yards",
		"r454.market.harbour_spine",
	]],
	["monastery_quarter", "res://content/maps/monastery_quarter.rrmap", 0.0, [
		"r454.monastery.inner_datum",
		"r454.monastery.outer_road",
		"r454.monastery.east_ditch",
		"r454.monastery.causeway",
		"r454.monastery.north_inner_gate",
	]],
	["north_quarter", "res://content/maps/north_quarter.rrmap", 0.0, [
		"r454.north.pikk_harbour_fall",
		"r454.north.coastal_gate_sill",
		"r454.north.outer_wall_road",
		"r454.north.monastery_seam",
	]],
	["south_quarter", "res://content/maps/south_quarter.rrmap", 0.0, [
		"r454.south.lower_town_datum",
		"r454.south.king_to_karja",
		"r454.south.karja_glacis",
		"r454.south.garden_seam",
	]],
	["toompea_quarter", "res://content/maps/toompea_quarter.rrmap", 2.8, [
		"r454.toompea.plateau_datum",
		"r454.toompea.pikk_jalg_descent",
		"r454.toompea.luhike_jalg_descent",
		"r454.toompea.southern_slope",
	]],
	["archbishops_garden", "res://content/maps/archbishops_garden.rrmap", 2.8, [
		"r454.garden.plateau_datum",
		"r454.garden.toompea_seam",
		"r454.garden.center_gate_taper",
		"r454.garden.south_gate_taper",
	]],
	["reval_harbor_north", "res://content/maps/reval_harbor_north.rrmap", 0.0, [
		"r454.harbor_n.coastal_gate_ramp",
		"r454.harbor_n.quay_to_wet_margin",
		"r454.harbor_n.wet_margin",
		"r454.harbor_n.harbor_east_seam",
	]],
	["reval_harbor_east", "res://content/maps/reval_harbor_east.rrmap", 0.0, [
		"r454.harbor_e.kalarand_shore",
		"r454.harbor_e.shore_track",
		"r454.harbor_e.village_edge",
		"r454.harbor_e.north_seam",
	]],
]

const FLAT_INTERIOR_CASES := [
	["kalev_smithy", "res://content/maps/kalev_smithy.rrmap"],
	["town_hall", "res://content/maps/town_hall.rrmap"],
	["holy_spirit_church", "res://content/maps/holy_spirit_church.rrmap"],
	["oleviste_church", "res://content/maps/oleviste_church.rrmap"],
	["st_olafs_guild_hall", "res://content/maps/st_olafs_guild_hall.rrmap"],
]

const EXCLUDED_FORELAND_PATH := "res://content/maps/viru_gate_foreland.rrmap"


func test_r454_urban_exterior_profiles_stay_within_matrix_scope() -> void:
	var expected_map_ids: Array[StringName] = []
	for item in URBAN_EXTERIOR_CASES:
		var expected_id: StringName = StringName(item[0])
		expected_map_ids.append(expected_id)
		var parsed := MapRrmapParser.parse_file(item[1])
		assert_true(parsed.is_ok(), "%s must compile: %s" % [item[0], parsed.formatted_diagnostics()])
		if not parsed.is_ok():
			continue

		var definition: MapDefinition = parsed.definition
		assert_eq(definition.map_id, expected_id, "%s map ID" % item[0])
		assert_eq(definition.ground_elevation, float(item[2]), "%s authored datum" % item[0])

		var allowed_profile_ids: Array = item[3]
		for profile in definition.elevation_profiles:
			var profile_id := String(profile.get("id", ""))
			assert_true(
				allowed_profile_ids.has(profile_id),
				"%s profile %s is outside the R-454 matrix" % [item[0], profile_id]
			)

	assert_false(
		expected_map_ids.has(&"viru_gate_foreland"),
		"the extramural foreland must stay outside the nine-map urban matrix"
	)
	assert_eq(expected_map_ids.size(), 9, "R-454 urban exterior scope is exactly nine maps")


func test_r454_flat_interiors_have_no_authored_relief() -> void:
	for item in FLAT_INTERIOR_CASES:
		var parsed := MapRrmapParser.parse_file(item[1])
		assert_true(parsed.is_ok(), "%s must compile: %s" % [item[0], parsed.formatted_diagnostics()])
		if not parsed.is_ok():
			continue

		var definition: MapDefinition = parsed.definition
		assert_eq(definition.map_id, StringName(item[0]), "%s map ID" % item[0])
		assert_eq(definition.ground_elevation, 0.0, "%s must keep the flat datum" % item[0])
		assert_true(
			definition.elevation_profiles.is_empty(),
			"%s must not inherit an exterior elevation profile" % item[0]
		)


func test_r454_foreland_is_explicitly_excluded_from_urban_relief() -> void:
	var parsed := MapRrmapParser.parse_file(EXCLUDED_FORELAND_PATH)
	assert_true(
		parsed.is_ok(),
		"viru_gate_foreland must compile: %s" % [parsed.formatted_diagnostics()]
	)
	if not parsed.is_ok():
		return

	var definition: MapDefinition = parsed.definition
	assert_eq(definition.map_id, &"viru_gate_foreland")
	assert_eq(definition.ground_elevation, 0.0)
	assert_true(
		definition.elevation_profiles.is_empty(),
		"foreland needs a separate future profile decision"
	)
