extends "res://tests/godot/test_case.gd"

## WB-10 (R-982): dressing-and-ground density metrics on fixtures with known answers.

const MapCompositionAudit := preload("res://scripts/map/map_composition_audit.gd")


func test_prop_and_decal_density_use_walkable_cells_and_exclude_vegetation() -> void:
	var definition := _fixture(&"fixture.density")
	# 16x16 = 256 cells, one 4x4 house = 16 built, 240 walkable.
	_add_house(definition, &"house_a", Rect2i(0, 0, 4, 4))
	for index in 12:
		var cell := Vector2i(6 + index % 6, 6 + int(index / 6.0))
		_add_prop(definition, StringName("barrel_%d" % index), MapTypes.PROP_KIND_BARRELS, cell)
	for index in 3:
		var cell := Vector2i(1, 8 + index)
		_add_prop(definition, StringName("tree_%d" % index), MapTypes.PROP_KIND_TREE, cell)
	for index in 6:
		definition.decals.append({"id": StringName("decal_%d" % index), "position": Vector2(200, 200)})
	var dressing := _dressing(definition)
	assert_eq(dressing["walkable_cells"], 240)
	assert_eq(dressing["dressing_props"], 12, "trees must not count as dressing")
	assert_eq(dressing["vegetation_props"], 3)
	assert_almost_eq(float(dressing["props_per_1000"]), 50.0, 0.001)
	assert_almost_eq(float(dressing["decals_per_1000"]), 25.0, 0.001)


func test_single_kind_share_cap_and_variety_floor() -> void:
	var definition := _fixture(&"fixture.one_barrel")
	for index in 8:
		var cell := Vector2i(index, 10)
		_add_prop(definition, StringName("barrel_%d" % index), MapTypes.PROP_KIND_BARRELS, cell)
	_add_prop(definition, &"well_a", MapTypes.PROP_KIND_WELL, Vector2i(12, 12))
	_add_prop(definition, &"cart_a", MapTypes.PROP_KIND_CART, Vector2i(13, 12))
	var dressing := _dressing(definition)
	assert_eq(dressing["distinct_prop_kinds"], 3)
	assert_eq(dressing["max_prop_kind"], "barrels")
	assert_almost_eq(float(dressing["max_prop_kind_share_pct"]), 80.0, 0.001)
	var violations := MapCompositionAudit.audit_density(
		"fixture.one_barrel",
		dressing,
		{"max_prop_kind_share_pct": 30, "distinct_prop_kinds_min": 12},
	)
	var codes := violations.map(func(v): return v["code"])
	assert_true(
		codes.has(MapCompositionAudit.VIOLATION_PROP_KIND_SHARE),
		"cloned barrels must trip the share cap"
	)
	assert_true(
		codes.has(MapCompositionAudit.VIOLATION_PROP_VARIETY),
		"three kinds must trip the variety floor"
	)
	var share: Dictionary = violations.filter(
		func(v): return v["code"] == MapCompositionAudit.VIOLATION_PROP_KIND_SHARE
	)[0]
	assert_eq(share["metric"], "max_prop_kind_share_pct")
	assert_eq(share["expected"], "<= 30.0")


func test_identical_footprint_run_detects_a_row_of_boxes() -> void:
	var definition := _fixture(&"fixture.row_of_boxes")
	# Five identical 3x2 houses touching along a street, then one rotated 2x3
	# with a one-cell gap: still the same box, so the run is six.
	for index in 5:
		_add_house(definition, StringName("row_%d" % index), Rect2i(index * 3, 0, 3, 2))
	_add_house(definition, &"rotated", Rect2i(16, 0, 2, 3))
	# A different footprint breaks nothing and joins nothing.
	_add_house(definition, &"odd", Rect2i(0, 6, 4, 4))
	# Same footprint but diagonal only (no shared row or column): not a neighbour.
	_add_house(definition, &"diagonal", Rect2i(5, 10, 3, 2))
	var dressing := _dressing(definition, Vector2i(24, 16))
	assert_eq(dressing["max_identical_footprint_run"], 6)
	var violations := MapCompositionAudit.audit_density(
		"fixture.row_of_boxes", dressing, {"max_identical_footprint_run": 3}
	)
	assert_eq(violations.size(), 1)
	assert_eq(violations[0]["code"], MapCompositionAudit.VIOLATION_FOOTPRINT_RUN)


func test_varied_row_and_wide_gap_do_not_count_as_a_run() -> void:
	var definition := _fixture(&"fixture.varied_row")
	_add_house(definition, &"a", Rect2i(0, 0, 3, 2))
	_add_house(definition, &"b", Rect2i(3, 0, 4, 2))
	_add_house(definition, &"c", Rect2i(7, 0, 3, 2))
	# Same footprint as `c` but two cells away: a lane, not a party wall.
	_add_house(definition, &"d", Rect2i(12, 0, 3, 2))
	assert_eq(_dressing(definition)["max_identical_footprint_run"], 1)


func test_ground_cover_counts_grass_variants_and_vegetation_props() -> void:
	var definition := _fixture(&"fixture.ground_cover")
	# Paved 16x16, then a 4x4 grass patch (16), a 2x4 bush-variant zone on
	# paving (8) and one tree on paving (1): 25 of 256 walkable cells.
	definition.zones.append({"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(0, 0, 4, 4)})
	definition.zones.append({
		"terrain": MapTypes.TERRAIN_COBBLESTONE,
		"rect": Rect2i(8, 0, 2, 4),
		"style_variant": &"bush.scrub",
	})
	_add_prop(definition, &"tree_a", MapTypes.PROP_KIND_TREE, Vector2i(12, 12))
	var dressing := _dressing(definition)
	assert_almost_eq(float(dressing["ground_cover_pct"]), 100.0 * 25.0 / 256.0, 0.001)
	var violations := MapCompositionAudit.audit_density(
		"fixture.ground_cover", dressing, {"ground_cover_pct_min": 10}
	)
	assert_eq(violations.size(), 1)
	assert_eq(violations[0]["code"], MapCompositionAudit.VIOLATION_GROUND_COVER)


func test_relief_floor_reuses_elevation_flat_code_and_null_keys_are_skipped() -> void:
	var dressing := {"relief_span_m": 0.1, "props_per_1000": 0.0}
	var violations := MapCompositionAudit.audit_density(
		"fixture.flat",
		dressing,
		{"elevation_range_min": 0.3, "props_per_1000_min": null, "ground_cover_pct_min": null},
	)
	assert_eq(violations.size(), 1)
	assert_eq(violations[0]["code"], MapCompositionAudit.VIOLATION_ELEVATION_FLAT)
	assert_eq(violations[0]["metric"], "relief_span_m")


func test_tier_spread_is_reported_but_not_judged_until_r981() -> void:
	var definition := _fixture(&"fixture.tiers")
	_add_house(definition, &"a", Rect2i(0, 0, 3, 3))
	_add_house(definition, &"b", Rect2i(6, 0, 4, 3))
	definition.buildings[0]["wealth_tier"] = &"merchant_stone"
	definition.buildings[1]["wealth_tier"] = &"craft_boda"
	var dressing := _dressing(definition)
	assert_eq(dressing["wealth_tiers"], 2)
	assert_eq(dressing["age_tiers"], 0)
	var dormant := MapCompositionAudit.audit_density(
		"fixture.tiers", dressing, {"min_wealth_tiers": 3, "tier_spread_active": false}
	)
	assert_true(dormant.is_empty(), "tier spread must stay dormant before R-981")
	var active := MapCompositionAudit.audit_density(
		"fixture.tiers", dressing, {"min_wealth_tiers": 3, "tier_spread_active": true}
	)
	assert_eq(active.size(), 1)
	assert_eq(active[0]["code"], MapCompositionAudit.VIOLATION_TIER_SPREAD)


func test_every_density_class_states_every_key_and_benchmark_passes_its_own_class() -> void:
	var doc: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://docs/data/map_composition_thresholds.json")
	)
	var contract: Dictionary = doc["density_contract"]
	for class_id in ["dense_urban", "sparse_urban", "foreland", "rural", "interior"]:
		assert_true(contract["classes"].has(class_id), "missing class %s" % class_id)
	for map_id in doc["maps"]:
		assert_true(
			contract["classes"].has(String(doc["maps"][map_id].get("map_class", ""))),
			"%s needs a known map_class" % map_id
		)
	# The interior floors are fractions of kalev_smithy; the benchmark itself
	# must therefore pass, or the derivation is broken.
	var benchmark: Dictionary = contract["benchmark"]
	var violations := MapCompositionAudit.audit_density(
		"kalev_smithy",
		{
			"props_per_1000": benchmark["props_per_1000"],
			"decals_per_1000": benchmark["decals_per_1000"],
			"distinct_prop_kinds": benchmark["distinct_prop_kinds"],
			"max_prop_kind_share_pct": benchmark["max_prop_kind_share_pct"],
		},
		contract["classes"]["interior"],
	)
	assert_true(violations.is_empty(), "benchmark fails its own class: %s" % [violations])


func _dressing(definition: MapDefinition, size := Vector2i(16, 16)) -> Dictionary:
	definition.size_cells = size
	var grid := MapBuilder.build(definition)
	return MapCompositionAudit.measure(definition, grid)["dressing"]


func _fixture(map_id: StringName) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = map_id
	definition.seed = 4242
	definition.cell_size = 32
	definition.size_cells = Vector2i(16, 16)
	definition.base_terrain = MapTypes.TERRAIN_COBBLESTONE
	definition.ground_elevation = 0.0
	definition.player_spawn = Vector2(8, 8)
	definition.location = &"loc.test"
	definition.scope = &"prototype"
	definition.active = false
	definition.palette = &"clean_painted"
	definition.fingerprint = "fixture-%s" % map_id
	return definition


func _add_house(definition: MapDefinition, building_id: StringName, cells: Rect2i) -> void:
	var cell_size := float(definition.cell_size)
	definition.buildings.append({
		"id": building_id,
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"footprint": Rect2(Vector2(cells.position) * cell_size, Vector2(cells.size) * cell_size),
		"wall_material": &"plaster",
		"style": &"plaster",
	})


func _add_prop(
	definition: MapDefinition, prop_id: StringName, kind: StringName, cell: Vector2i
) -> void:
	var cell_size := float(definition.cell_size)
	definition.props.append({
		"id": prop_id,
		"kind": kind,
		"position": (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size,
	})
