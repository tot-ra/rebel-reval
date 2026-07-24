extends "res://tests/godot/test_case.gd"

const MapCompositionAudit := preload("res://scripts/map/map_composition_audit.gd")


func test_enforced_registry_maps_pass_documented_thresholds() -> void:
	var thresholds_doc: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://docs/data/map_composition_thresholds.json")
	)
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
		var violations := MapCompositionAudit.audit(definition, grid, card)
		assert_true(
			violations.is_empty(),
			"%s composition violations: %s" % [map_id, violations]
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
