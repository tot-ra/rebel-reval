extends "res://tests/godot/test_case.gd"

const MapCompositionAudit := preload("res://scripts/map/map_composition_audit.gd")


func test_lower_town_composition_gate_declares_ownership_exclusions() -> void:
	var thresholds_doc: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://docs/data/map_composition_thresholds.json")
	)
	var card: Dictionary = thresholds_doc["maps"]["lower_town_slice"]
	assert_true(
		card.get("enforce", false),
		"Lower Town composition must be enforced, not silently skipped"
	)
	assert_eq(card.get("enforcement_state"), "enforced")
	assert_eq(
		card.get("ownership_contract"),
		"docs/data/lower_town_authoring_contract.json"
	)
	assert_true(
		["H04-H05", "H09-H10"].all(
			func(source_ref): return source_ref in card.get("source_refs", [])
		)
	)

	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://content/map_audit_manifest.json")
	)
	var lower_town_rows: Array = manifest["maps"].filter(
		func(row): return row.get("id") == "lower_town_slice"
	)
	assert_eq(lower_town_rows.size(), 1)
	var enforcement: Dictionary = lower_town_rows[0].get("composition_enforcement", {})
	assert_eq(enforcement.get("state"), "enforced")
	assert_eq(
		enforcement.get("thresholds"),
		"docs/data/map_composition_thresholds.json#maps.lower_town_slice"
	)
	assert_eq(enforcement.get("ownership"), "docs/data/lower_town_authoring_contract.json")
	assert_eq(
		enforcement.get("open_region_exclusions"),
		"ownership.open_regions[].exclude_from_unowned_empty_region"
	)

	var ownership: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://docs/data/lower_town_authoring_contract.json")
	)
	var open_regions: Array = ownership.get("open_regions", [])
	assert_true(open_regions.size() > 0)
	for region in open_regions:
		assert_true(
			region.get("bounds_cells", []).size() == 4,
			"open region needs cell bounds"
		)
		assert_true(
			not String(region.get("reason", "")).is_empty(),
			"open region needs an ownership reason"
		)
		assert_true(
			region.get("exclude_from_unowned_empty_region", false),
			"intentional open regions must opt out explicitly"
		)


func test_enforced_registry_maps_pass_documented_thresholds() -> void:
	var thresholds_doc: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://docs/data/map_composition_thresholds.json")
	)
	var band_grace: Dictionary = thresholds_doc.get("historical_band_grace", {})
	for entry in MapBlueprintRegistry.entries():
		var map_id := String(entry.get("id", ""))
		var card: Dictionary = thresholds_doc["maps"][map_id]
		if card.get("enforce", true) == false:
			continue
		var blueprint := MapBlueprintRegistry.create_blueprint(entry)
		assert_true(blueprint != null, "Missing blueprint for %s" % map_id)
		var required_anchors: Array[StringName] = []
		required_anchors.assign(entry.get("required_anchors", []))
		var result := MapBlueprintCompiler.compile_with_diagnostics(
			blueprint,
			required_anchors
		)
		assert_true(
			not result.diagnostics.any(func(d): return d.is_error()),
			"%s compile errors: %s" % [map_id, result.diagnostics]
		)
		var definition := result.definition
		var grid := MapBuilder.build(definition)
		var contract := _authoring_contract_for(map_id, card)
		var violations := MapCompositionAudit.audit(definition, grid, card, contract)
		var grace: Dictionary = band_grace.get(map_id, {})
		if not String(grace.get("until", "")).is_empty():
			assert_false(
				String(grace.get("reason", "")).is_empty(),
				"%s historical band grace needs a reason" % map_id
			)
			continue
		assert_true(
			violations.is_empty(),
			"%s composition violations: %s" % [map_id, violations]
		)


func test_lower_town_ownership_contract_is_applied_to_empty_region() -> void:
	# The audit used to look up docs/data/lower_town_slice_authoring_contract.json
	# and silently dropped the real ownership file, so largest_empty_region_cells
	# equalled every walkable cell (14977).
	var compiled := _compile_registry_map("lower_town_slice")
	var thresholds_doc: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://docs/data/map_composition_thresholds.json")
	)
	var card: Dictionary = thresholds_doc["maps"]["lower_town_slice"]
	var contract := _authoring_contract_for("lower_town_slice", card)
	assert_true(contract.get("open_regions", []).size() > 0)
	var bare := MapCompositionAudit.measure(compiled["definition"], compiled["grid"])
	var owned := MapCompositionAudit.measure(compiled["definition"], compiled["grid"], contract)
	assert_true(
		int(owned["excluded_open_region_cells"]) > 0,
		"ownership contract must exclude named open reserves"
	)
	assert_true(
		int(owned["largest_empty_region_cells"]) < int(bare["largest_empty_region_cells"]),
		"open-region exclusions must shrink the unowned empty-region metric"
	)
	assert_true(
		int(owned["largest_empty_region_cells"]) < int(owned["dressing"]["walkable_cells"]),
		"empty region must not collapse to the whole walkable field"
	)


func test_excess_cobble_violation_reports_map_metric_and_source() -> void:
	var definition := _outdoor_fixture(&"fixture.excess_cobble")
	var grid := MapBuilder.build(definition)
	var thresholds := {
		"source_refs": ["H04-H05"],
		"surface_shares": {"stone_pct": [0, 5], "earth_pct": [0, 100], "grass_pct": [0, 100]},
		"max_cobblestone_pct": 5.0,
	}
	var violations := MapCompositionAudit.audit(definition, grid, thresholds)
	var excess := violations.filter(
		func(v): return v["code"] == MapCompositionAudit.VIOLATION_EXCESS_COBBLE
	)
	assert_eq(excess.size(), 1)
	assert_eq(excess[0]["map_id"], "fixture.excess_cobble")
	assert_true(String(excess[0]["expected"]).contains("5"))


func test_sparse_building_violation_reports_density_band() -> void:
	var definition := _outdoor_fixture(&"fixture.sparse_buildings")
	definition.buildings.clear()
	_add_house(definition, &"only_house", Rect2(4, 4, 4, 4), &"plaster")
	var grid := MapBuilder.build(definition)
	var thresholds := {
		"source_refs": ["H04"],
		"built_density_pct": [45, 60],
		"surface_shares": {"stone_pct": [0, 100], "earth_pct": [0, 100], "grass_pct": [0, 100]},
	}
	var violations := MapCompositionAudit.audit(definition, grid, thresholds)
	assert_true(
		violations.any(func(v): return v["code"] == MapCompositionAudit.VIOLATION_DENSITY),
		"expected sparse-building density violation"
	)


func test_missing_landmark_violation_reports_required_id() -> void:
	var definition := _outdoor_fixture(&"fixture.missing_landmark")
	var grid := MapBuilder.build(definition)
	var thresholds := {
		"source_refs": ["H15"],
		"surface_shares": {"stone_pct": [0, 100], "earth_pct": [0, 100], "grass_pct": [0, 100]},
		"required_landmark_building_ids": ["st_catherines_church"],
	}
	var violations := MapCompositionAudit.audit(definition, grid, thresholds)
	assert_eq(violations.size(), 1)
	assert_eq(violations[0]["code"], MapCompositionAudit.VIOLATION_MISSING_LANDMARK)
	assert_eq(violations[0]["measured"], "st_catherines_church")


func test_flat_relief_violation_reports_elevation_range() -> void:
	var definition := _outdoor_fixture(&"fixture.flat_relief")
	definition.ground_elevation = 0.0
	definition.seed = 1
	var grid := MapBuilder.build(definition)
	var thresholds := {
		"source_refs": ["H08-H10"],
		"surface_shares": {"stone_pct": [0, 100], "earth_pct": [0, 100], "grass_pct": [0, 100]},
		"elevation_range_min": 5.0,
	}
	var violations := MapCompositionAudit.audit(definition, grid, thresholds)
	assert_true(
		violations.any(func(v): return v["code"] == MapCompositionAudit.VIOLATION_ELEVATION_FLAT),
		"expected flat-relief violation"
	)


func test_repeated_style_violation_reports_style_share() -> void:
	var definition := _outdoor_fixture(&"fixture.repeated_style")
	definition.buildings.clear()
	for index in 6:
		_add_house(definition, StringName("house_%d" % index), Rect2(1 + index * 2, 2, 2, 2), &"plaster")
	var grid := MapBuilder.build(definition)
	var thresholds := {
		"source_refs": ["H04"],
		"surface_shares": {"stone_pct": [0, 100], "earth_pct": [0, 100], "grass_pct": [0, 100]},
		"max_style_share_pct": 70.0,
	}
	var violations := MapCompositionAudit.audit(definition, grid, thresholds)
	assert_true(
		violations.any(func(v): return v["code"] == MapCompositionAudit.VIOLATION_REPEATED_STYLE),
		"expected repeated-style violation"
	)


func test_surface_share_violation_reports_map_metric_and_source() -> void:
	var definition := _outdoor_fixture(&"fixture.surface_share")
	definition.zones.clear()
	definition.zones.append({"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(0, 0, 16, 16)})
	var grid := MapBuilder.build(definition)
	var thresholds := {
		"source_refs": ["H04-H05"],
		"surface_shares": {"stone_pct": [25, 40], "earth_pct": [0, 100], "grass_pct": [0, 100]},
	}
	var violations := MapCompositionAudit.audit(definition, grid, thresholds)
	var surface := violations.filter(
		func(v): return v["code"] == MapCompositionAudit.VIOLATION_SURFACE_SHARE
	)
	assert_eq(surface.size(), 1)
	assert_eq(surface[0]["map_id"], "fixture.surface_share")
	assert_eq(surface[0]["metric"], "stone_pct")
	assert_eq(surface[0]["source_refs"], ["H04-H05"])


func test_intentional_open_reserve_is_excluded_only_from_empty_region_metric() -> void:
	var definition := _outdoor_fixture(&"fixture.open_reserve")
	definition.buildings.clear()
	_add_house(definition, &"barrier", Rect2(12, 0, 2, 16), &"plaster")
	var grid := MapBuilder.build(definition)
	var thresholds := {
		"source_refs": ["H04-H05"],
		"surface_shares": {"stone_pct": [0, 100], "earth_pct": [0, 100], "grass_pct": [0, 100]},
	}
	var unowned_metrics := MapCompositionAudit.measure(definition, grid)
	var contract := {
		"open_regions": [
			{
				"id": "intentional_reserve",
				"bounds_cells": [0, 0, 12, 16],
				"exclude_from_unowned_empty_region": true,
			}
		]
	}
	var reserved_metrics := MapCompositionAudit.measure(definition, grid, contract)
	assert_true(
		int(reserved_metrics["largest_empty_region_cells"])
			< int(unowned_metrics["largest_empty_region_cells"]),
		"excluded reserves must not inflate unowned empty-region size"
	)
	assert_eq(
		reserved_metrics["developable_cells"],
		unowned_metrics["developable_cells"],
		"reserve exclusions must not alter developable density denominator"
	)
	assert_eq(
		reserved_metrics["built_density_pct"],
		unowned_metrics["built_density_pct"],
		"reserve exclusions must not alter built density"
	)
	assert_eq(
		reserved_metrics["surface_shares"],
		unowned_metrics["surface_shares"],
		"reserve exclusions must not alter surface shares"
	)
	assert_true(MapCompositionAudit.audit(definition, grid, thresholds, contract).is_empty())


func test_density_zone_opt_in_keeps_default_whole_map_metric() -> void:
	var definition := _outdoor_fixture(&"fixture.density_zones")
	definition.size_cells = Vector2i(16, 8)
	definition.zones.clear()
	definition.zones.append({"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(0, 0, 16, 8)})
	definition.buildings.clear()
	_add_house(definition, &"west_a", Rect2(1, 1, 3, 3), &"plaster")
	_add_house(definition, &"west_b", Rect2(1, 4, 3, 3), &"log")
	var grid := MapBuilder.build(definition)
	var contract := {
		"density_zones": [
			{
				"id": "inside_wall",
				"bounds_cells": [0, 0, 8, 8],
				"reason": "left intramural half",
			},
			{
				"id": "outside_wall",
				"bounds_cells": [8, 0, 8, 8],
				"reason": "right extramural half",
			},
		]
	}
	var bare := MapCompositionAudit.measure(definition, grid)
	var zoned := MapCompositionAudit.measure(definition, grid, contract)
	assert_false(
		bare.has("zone_built_density_pct"),
		"unsigned contracts must not emit zone density keys"
	)
	assert_eq(
		zoned["built_density_pct"],
		bare["built_density_pct"],
		"opt-in zones must not change the whole-map density metric"
	)
	var zones: Dictionary = zoned["zone_built_density_pct"]
	assert_true(float(zones["inside_wall"]) > float(zoned["built_density_pct"]))
	assert_eq(float(zones["outside_wall"]), 0.0)
	var whole_card := {
		"source_refs": ["H08-H10"],
		"built_density_pct": [25, 35],
		"surface_shares": {"stone_pct": [0, 100], "earth_pct": [0, 100], "grass_pct": [0, 100]},
	}
	assert_true(
		MapCompositionAudit.audit(definition, grid, whole_card, contract).any(
			func(v): return v["code"] == MapCompositionAudit.VIOLATION_DENSITY
		),
		"default density band still uses the whole-map metric"
	)
	var zone_card := whole_card.duplicate(true)
	zone_card["built_density_zone"] = "inside_wall"
	zone_card["outside_wall_built_density_pct"] = [0, 5]
	zone_card["outside_wall_built_density_zone"] = "outside_wall"
	assert_true(
		MapCompositionAudit.audit(definition, grid, zone_card, contract).is_empty(),
		"named inside-wall and outside-wall bands must use zone densities"
	)


func test_south_quarter_density_zones_name_wall_and_ward_rects() -> void:
	var contract: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://docs/data/south_quarter_authoring_contract.json")
	)
	assert_eq(contract.get("map_id"), "south_quarter")
	var by_id: Dictionary = {}
	for zone in contract.get("density_zones", []):
		by_id[String(zone.get("id", ""))] = zone
	assert_true(by_id.has("inside_wall"))
	assert_true(by_id.has("outside_wall"))
	assert_true(by_id.has("eastern_ward"))
	assert_true(by_id.has("western_connector"))
	assert_eq(_int_bounds(by_id["inside_wall"].get("bounds_cells", [])[0]), [0, 0, 331, 60])
	assert_eq(_int_bounds(by_id["eastern_ward"].get("bounds_cells", [])), [257, 0, 74, 82])
	assert_eq(_int_bounds(by_id["western_connector"].get("bounds_cells", [])), [4, 0, 140, 82])
	var thresholds_doc: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://docs/data/map_composition_thresholds.json")
	)
	var card: Dictionary = thresholds_doc["maps"]["south_quarter"]
	assert_eq(card.get("built_density_zone"), "inside_wall")
	assert_eq(card.get("outside_wall_built_density_zone"), "outside_wall")
	var outside_band: Array = card.get("outside_wall_built_density_pct", [])
	assert_eq(outside_band.size(), 2)
	assert_eq(int(outside_band[0]), 10)
	assert_eq(int(outside_band[1]), 25)


func test_south_quarter_zone_density_stays_above_the_diluted_whole_map() -> void:
	var compiled := _compile_registry_map("south_quarter")
	var contract := _authoring_contract_for("south_quarter", {})
	assert_true(contract.get("density_zones", []).size() >= 4)
	var definition: MapDefinition = compiled["definition"]
	var grid: MapTerrainGrid = compiled["grid"]
	var bare := MapCompositionAudit.measure(definition, grid)
	var zoned := MapCompositionAudit.measure(definition, grid, contract)
	assert_eq(float(zoned["built_density_pct"]), float(bare["built_density_pct"]))
	var zones: Dictionary = zoned["zone_built_density_pct"]
	assert_true(
		float(zones["inside_wall"]) > float(zoned["built_density_pct"]),
		"glacis cells must not dilute the intramural density band"
	)
	assert_true(
		float(zones["eastern_ward"]) > float(zones["western_connector"]),
		"eastern ward must stay denser than the western connector"
	)
	# R-1082 ledger: intramural frontage is still short of the signed H-band.
	assert_true(float(zones["inside_wall"]) > 35.0)
	assert_true(float(zones["inside_wall"]) < 40.0)
	assert_true(float(zones["eastern_ward"]) >= 40.0)
	assert_true(float(zones["eastern_ward"]) <= 55.0)
	assert_true(float(zones["outside_wall"]) < 10.0)
	assert_true(int(zoned["largest_empty_region_cells"]) <= 20000)


func test_open_reserve_without_explicit_exclusion_still_counts_as_empty_region() -> void:
	var definition := _outdoor_fixture(&"fixture.unexcluded_reserve")
	definition.buildings.clear()
	_add_house(definition, &"barrier", Rect2(12, 0, 2, 16), &"plaster")
	var grid := MapBuilder.build(definition)
	var metrics := MapCompositionAudit.measure(
		definition,
		grid,
		{"open_regions": [{"bounds_cells": [0, 0, 12, 16]}]},
	)
	assert_eq(metrics["excluded_open_region_cells"], 0)
	assert_eq(metrics["largest_empty_region_cells"], 192)


func _int_bounds(values: Array) -> Array[int]:
	var ints: Array[int] = []
	for value in values:
		ints.append(int(value))
	return ints


func _compile_registry_map(map_id: String) -> Dictionary:
	for entry in MapBlueprintRegistry.entries():
		if String(entry.get("id", "")) != map_id:
			continue
		var blueprint := MapBlueprintRegistry.create_blueprint(entry)
		var required_anchors: Array[StringName] = []
		required_anchors.assign(entry.get("required_anchors", []))
		var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint, required_anchors)
		assert_true(
			not result.diagnostics.any(func(d): return d.is_error()),
			"%s compile errors: %s" % [map_id, result.diagnostics]
		)
		return {
			"definition": result.definition,
			"grid": MapBuilder.build(result.definition),
		}
	assert_true(false, "missing registry map %s" % map_id)
	return {}


func _authoring_contract_for(map_id: String, card: Dictionary) -> Dictionary:
	var candidates: Array[String] = []
	var named := String(card.get("ownership_contract", ""))
	if named.begins_with("docs/data/") and named.ends_with(".json"):
		candidates.append("res://" + named)
	candidates.append("res://docs/data/%s_authoring_contract.json" % map_id)
	for path in candidates:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return parsed
	return {}


func _outdoor_fixture(map_id: StringName) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = map_id
	definition.seed = 4242
	definition.cell_size = 32
	definition.size_cells = Vector2i(16, 16)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.ground_elevation = 0.0
	definition.player_spawn = Vector2(8, 8)
	definition.location = &"loc.test"
	definition.scope = &"prototype"
	definition.active = false
	definition.palette = &"clean_painted"
	definition.fingerprint = "fixture-%s" % map_id
	definition.zones.append({"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(0, 0, 16, 16)})
	for index in 4:
		_add_house(
			definition,
			StringName("house_%d" % index),
			Rect2(2 + index * 3, 2, 3, 3),
			&"plaster" if index % 2 == 0 else &"log",
		)
	return definition


func _add_house(
	definition: MapDefinition,
	building_id: StringName,
	footprint: Rect2,
	wall_material: StringName,
) -> void:
	var cell_size := float(definition.cell_size)
	definition.buildings.append({
		"id": building_id,
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"footprint": Rect2(Vector2(footprint.position) * cell_size, Vector2(footprint.size) * cell_size),
		"wall_material": wall_material,
		"style": wall_material,
	})
