extends "res://tests/godot/test_case.gd"

## WB-02 (R-974, ADR 0023): signed relief primitives compile into a deterministic
## per-cell height field with a sampling API and four stable diagnostics, while
## every map that authors no relief_* statement keeps its pre-relief heights.

const FIXTURE_PATH := "res://tests/fixtures/maps/rrmap_relief_example.rrmap"
const FIXTURE_STATEMENTS := [
	"relief_hill relief.hill 10 10 8 3",
	"relief_ridge relief.ridge 20 4 36 4 6 1.5 falloff=linear",
	"relief_ditch relief.ditch 4 34 44 34 8 0.9",
	"relief_terrace relief.terrace 30 12 6 6 2 edge=3",
	"relief_cliff relief.cliff 40 20 40 12 2",
	"relief_noise relief.noise 2 22 16 6 0.4 seed=7",
]


func _fixture() -> MapRrmapParseResult:
	var parsed := MapRrmapParser.parse_file(FIXTURE_PATH)
	assert_true(parsed.is_ok(), "relief fixture compiles: %s" % [parsed.formatted_diagnostics()])
	return parsed


func _codes(parsed: MapRrmapParseResult) -> Dictionary:
	var codes := {}
	for diagnostic in parsed.diagnostics:
		codes[diagnostic.code] = diagnostic.severity
	return codes


## Pre-ADR-0023 rendered datum: MapViewMeshBuilderTerrain.field_height minus noise.
func _legacy_datum(definition: MapDefinition, cell: Vector2i) -> float:
	var position := Vector2(cell) + Vector2(0.5, 0.5)
	var size := definition.size_cells
	var border := minf(
		minf(position.x, float(size.x) - position.x), minf(position.y, float(size.y) - position.y)
	)
	return definition.ground_elevation * smoothstep(0.0, 10.0, border)


func test_fixture_parses_every_statement_and_round_trips_exactly() -> void:
	var parsed := _fixture()
	if not parsed.is_ok():
		return
	assert_true(
		parsed.diagnostics.is_empty(),
		"fixture is warning-free: %s" % [parsed.formatted_diagnostics()]
	)
	assert_eq(parsed.definition.relief_features.size(), FIXTURE_STATEMENTS.size())
	var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
	for statement in FIXTURE_STATEMENTS:
		assert_true(statement in canonical, "canonical print keeps '%s'" % statement)
	var reparsed := MapRrmapParser.parse(canonical, "res://relief.canonical.rrmap")
	assert_true(reparsed.is_ok(), str(reparsed.formatted_diagnostics()))
	if not reparsed.is_ok():
		return
	assert_eq(reparsed.blueprint.relief_features, parsed.blueprint.relief_features)
	assert_eq(reparsed.definition.relief_heights, parsed.definition.relief_heights)
	assert_eq(reparsed.definition.fingerprint, parsed.definition.fingerprint)
	assert_eq(MapRrmapParser.canonical_print(reparsed.blueprint), canonical, "print is a fixed point")


func test_defaults_are_omitted_and_optional_arguments_round_trip() -> void:
	var source := """rrmap 1
map relief_defaults loc.relief_defaults 24 24 grass
relief_hill hill.smooth 6 6 4 1
relief_hill hill.plateau 16 6 4 1 falloff=plateau
relief_ridge ridge.smooth 2 16 20 16 4 0.5
relief_terrace terrace.default 4 18 4 3 -1
relief_noise noise.derived 12 12 8 8 0.3
spawn spawn.main 12 20
"""
	var parsed := MapRrmapParser.parse(source, "res://relief_defaults.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
	for statement in [
		"relief_hill hill.smooth 6 6 4 1\n",
		"relief_hill hill.plateau 16 6 4 1 falloff=plateau\n",
		"relief_ridge ridge.smooth 2 16 20 16 4 0.5\n",
		"relief_terrace terrace.default 4 18 4 3 -1\n",
		"relief_noise noise.derived 12 12 8 8 0.3\n",
	]:
		assert_true(statement in canonical, "canonical print keeps '%s'" % statement.strip_edges())
	assert_false(parsed.blueprint.relief_features[4].has("seed"), "derived seed is not stored")
	assert_eq(parsed.blueprint.relief_features[3]["edge"], 2)


func test_compile_is_deterministic_across_two_compiles() -> void:
	var first := _fixture()
	var second := _fixture()
	if not first.is_ok() or not second.is_ok():
		return
	assert_eq(first.definition.relief_heights, second.definition.relief_heights)
	assert_eq(first.definition.fingerprint, second.definition.fingerprint)
	var direct := MapBlueprintCompiler.compile(first.blueprint)
	assert_eq(direct.relief_heights, first.definition.relief_heights)
	for index in first.definition.relief_heights.size():
		var value := first.definition.relief_heights[index]
		assert_eq(value, snappedf(value, MapDefinition.RELIEF_QUANTUM), "heights are quantised")


func test_primitives_produce_known_heights_including_signed_depth() -> void:
	var parsed := _fixture()
	if not parsed.is_ok():
		return
	var definition := parsed.definition
	assert_eq(definition.height_at(Vector2i(10, 10)), 3.0, "hill crest")
	assert_eq(definition.height_at(Vector2i(28, 4)), 1.5, "ridge crest")
	var ditch_bed := definition.height_at(Vector2i(20, 34))
	assert_eq(ditch_bed, snappedf(-0.9, MapDefinition.RELIEF_QUANTUM), "ditch bed")
	assert_true(ditch_bed < 0.0, "ditch depth is signed below the datum")
	assert_eq(definition.height_at(Vector2i(32, 14)), 2.0, "terrace top")
	assert_eq(definition.height_at(Vector2i(29, 14)), 1.5, "terrace edge ring 1")
	assert_eq(definition.height_at(Vector2i(27, 14)), 0.5, "terrace edge ring 3")
	assert_eq(definition.height_at(Vector2i(26, 14)), 0.0, "terrace edge ends")
	assert_eq(definition.height_at(Vector2i(41, 16)), -2.0, "cliff lowers the right-hand side")
	assert_eq(definition.height_at(Vector2i(39, 16)), 0.0, "cliff leaves the left-hand side")
	assert_eq(definition.height_at(Vector2i(0, 0)), 0.0, "untouched ground")
	var noise_min := INF
	var noise_max := -INF
	for y in range(22, 28):
		for x in range(2, 18):
			noise_min = minf(noise_min, definition.height_at(Vector2i(x, y)))
			noise_max = maxf(noise_max, definition.height_at(Vector2i(x, y)))
	assert_true(noise_max - noise_min > 0.05, "noise undulates")
	assert_true(noise_max <= 0.4 and noise_min >= -0.4, "noise stays within its amplitude")


func test_legacy_elevation_profiles_lower_to_zero_relief() -> void:
	var with_profiles := """rrmap 1
map legacy_profiles loc.legacy_profiles 32 32 grass elevation=2.8
grade slope south -0.1
elevation_area plateau 16 16 10 2.8 falloff=1.5
elevation_ramp descent 16 16 30 16 2.8 0.0 width=3
spawn spawn.main 4 4
"""
	var parsed := MapRrmapParser.parse(with_profiles, "res://legacy_profiles.rrmap")
	var plain := MapRrmapParser.parse(
		with_profiles.replace("grade slope south -0.1\n", "").replace(
			"elevation_area plateau 16 16 10 2.8 falloff=1.5\n", ""
		).replace("elevation_ramp descent 16 16 30 16 2.8 0.0 width=3\n", ""),
		"res://legacy_plain.rrmap"
	)
	assert_true(parsed.is_ok() and plain.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok() or not plain.is_ok():
		return
	assert_eq(parsed.definition.elevation_profiles.size(), 3, "profile IDs are preserved")
	assert_true(parsed.definition.relief_heights.is_empty(), "profiles add no relief")
	for y in 32:
		for x in 32:
			var cell := Vector2i(x, y)
			assert_eq(parsed.definition.height_at(cell), plain.definition.height_at(cell))
			assert_eq(parsed.definition.height_at(cell), _legacy_datum(parsed.definition, cell))


func test_registered_maps_keep_pre_relief_heights() -> void:
	assert_eq(
		MapDefinition.DATUM_TAPER_CELLS,
		MapViewMeshBuilderConfig.ELEVATION_SLOPE_CELLS,
		"compiled datum taper matches the view taper"
	)
	var compiled := 0
	var entries := MapBlueprintRegistry.entries()
	for entry in entries:
		var blueprint := MapBlueprintRegistry.create_blueprint(entry)
		var definition := MapBlueprintCompiler.compile(blueprint)
		assert_true(definition != null, "%s compiles" % entry.get("id", ""))
		if definition == null:
			continue
		compiled += 1
		assert_true(definition.relief_features.is_empty(), "%s authors no relief yet" % definition.map_id)
		assert_true(definition.relief_heights.is_empty(), "%s has zero relief" % definition.map_id)
		var size := definition.size_cells
		for cell in [
			Vector2i.ZERO,
			Vector2i(3, 3),
			size / 2,
			size - Vector2i.ONE,
			Vector2i(size.x - 4, 1),
		]:
			assert_eq(
				definition.height_at(cell),
				_legacy_datum(definition, cell),
				"%s height at %s is the pre-relief datum" % [definition.map_id, cell]
			)
	assert_eq(compiled, entries.size(), "every registered map compiled and was checked")
	assert_true(compiled > 0, "the registry is not empty")


func test_bilinear_sampling_at_cell_centres_and_edges() -> void:
	var parsed := _fixture()
	if not parsed.is_ok():
		return
	var definition := parsed.definition
	var cell_size := float(definition.cell_size)
	for cell in [Vector2i(10, 10), Vector2i(29, 14), Vector2i(41, 16)]:
		var centre := (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size
		assert_eq(definition.height_at_world(centre), definition.height_at(cell), "centre %s" % cell)
	# Halfway between two cell centres is their mean.
	var between := (Vector2(29, 14) + Vector2(1.0, 0.5)) * cell_size
	assert_almost_eq(
		definition.height_at_world(between),
		(definition.height_at(Vector2i(29, 14)) + definition.height_at(Vector2i(30, 14))) * 0.5,
		0.0001,
		"midpoint is bilinear"
	)
	# The field clamps to the edge cell value at the map border.
	var heights := PackedFloat32Array()
	heights.resize(4)
	heights[0] = 1.0
	heights[1] = 3.0
	heights[2] = 5.0
	heights[3] = 7.0
	var size := Vector2i(2, 2)
	assert_eq(MapDefinition.sample_relief(heights, size, Vector2(0.0, 0.0)), 1.0, "corner clamps")
	assert_eq(MapDefinition.sample_relief(heights, size, Vector2(2.0, 0.5)), 3.0, "edge clamps")
	assert_eq(MapDefinition.sample_relief(heights, size, Vector2(1.0, 1.0)), 4.0, "centre blends")
	assert_eq(MapDefinition.sample_relief(PackedFloat32Array(), size, Vector2.ONE), 0.0)


func test_slope_on_a_known_terrace_ramp() -> void:
	var source := """rrmap 1
map relief_slope loc.relief_slope 32 16 grass
relief_terrace ramp 20 0 12 16 4 edge=7
spawn spawn.main 2 8
"""
	var parsed := MapRrmapParser.parse(source, "res://relief_slope.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definition := parsed.definition
	var cell_size := float(definition.cell_size)
	# Edge ring d drops by 4/8 = 0.5 per cell: slope atan(0.5) inside the ramp.
	var on_ramp := Vector2(16.0, 8.5) * cell_size
	assert_almost_eq(definition.slope_at_world(on_ramp), atan(0.5), 0.0001, "ramp slope")
	assert_almost_eq(definition.slope_at_world(Vector2(3.0, 8.0) * cell_size), 0.0, 0.0001, "flat")
	assert_almost_eq(
		definition.slope_at_world(Vector2(26.0, 8.0) * cell_size), 0.0, 0.0001, "terrace top"
	)


func test_range_diagnostic_rejects_heights_outside_the_adr_span() -> void:
	var source := """rrmap 1
map relief_range loc.relief_range 32 32 grass
relief_terrace base 0 0 32 32 20 edge=0
relief_terrace stack 8 8 8 8 16 edge=0
spawn spawn.main 2 2
"""
	var parsed := MapRrmapParser.parse(source, "res://relief_range.rrmap")
	assert_false(parsed.is_ok(), "a 36-unit field is rejected")
	assert_eq(_codes(parsed).get(&"MAP_RELIEF_RANGE"), &"error")


func test_slope_diagnostic_warns_unless_a_cliff_was_authored() -> void:
	var steep := """rrmap 1
map relief_steep loc.relief_steep 32 16 grass
relief_terrace step 16 0 16 16 3 edge=0
spawn spawn.main 2 8
"""
	var parsed := MapRrmapParser.parse(steep, "res://relief_steep.rrmap")
	assert_true(parsed.is_ok(), "slope is a warning, not an error")
	assert_eq(_codes(parsed).get(&"MAP_RELIEF_SLOPE"), &"warning")
	var cliff := """rrmap 1
map relief_cliff loc.relief_cliff 32 16 grass
relief_cliff face 15 0 15 15 3
spawn spawn.main 20 8
"""
	var authored := MapRrmapParser.parse(cliff, "res://relief_cliff.rrmap")
	assert_true(authored.is_ok(), str(authored.formatted_diagnostics()))
	assert_false(_codes(authored).has(&"MAP_RELIEF_SLOPE"), "an authored cliff is intentional")
	if authored.is_ok():
		assert_eq(
			authored.definition.height_at(Vector2i(10, 8)),
			-3.0,
			"west of a south-running cliff drops"
		)
		assert_eq(authored.definition.height_at(Vector2i(20, 8)), 0.0)


func test_under_building_diagnostic_warns_on_uneven_footprints() -> void:
	var source := """rrmap 1
map relief_building loc.relief_building 32 24 grass
relief_ridge bank 4 12 28 12 12 2
building house.a house 12 8 4 4
spawn spawn.main 2 2
"""
	var parsed := MapRrmapParser.parse(source, "res://relief_building.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	assert_eq(_codes(parsed).get(&"MAP_RELIEF_UNDER_BUILDING"), &"warning")


func test_seam_diagnostic_requires_matching_edge_heights() -> void:
	var base_text := """rrmap 1
map relief_seam_a loc.relief_seam_a 20 10 grass
%s
spawn spawn.a 2 5
transition exit.east 19 4 1 2 to=relief_seam_b destination_spawn=spawn.b spawn=spawn.a
"""
	var neighbor_text := """rrmap 1
map relief_seam_b loc.relief_seam_b 20 10 grass
spawn spawn.b 17 5
transition exit.west 0 4 1 2 to=relief_seam_a destination_spawn=spawn.a spawn=spawn.b
"""
	var neighbor := MapRrmapParser.parse(neighbor_text, "res://relief_seam_b.rrmap")
	var flat := MapRrmapParser.parse(base_text % "", "res://relief_seam_a.rrmap")
	var raised := MapRrmapParser.parse(
		base_text % "relief_terrace lift 15 0 5 10 1 edge=3", "res://relief_seam_a.rrmap"
	)
	var definitions: Array[MapDefinition] = []
	for parsed in [neighbor, flat, raised]:
		assert_true(parsed.blueprint != null, str(parsed.formatted_diagnostics()))
		if parsed.blueprint == null:
			return
		definitions.append(MapBlueprintCompiler.compile_with_diagnostics(parsed.blueprint).definition)
	var flat_pair: Array[MapDefinition] = [definitions[1], definitions[0]]
	var matching := MapBlueprintSemanticValidator.validate_relief_seams(flat_pair)
	assert_true(matching.is_empty(), "flat seams meet: %s" % [matching])
	var raised_pair: Array[MapDefinition] = [definitions[2], definitions[0]]
	var broken := MapBlueprintSemanticValidator.validate_relief_seams(raised_pair)
	assert_eq(broken.size(), 1, "one mismatched seam")
	if broken.size() == 1:
		assert_eq(broken[0].code, &"MAP_RELIEF_SEAM")
		assert_true(broken[0].is_error())
		assert_eq(broken[0].subject, &"exit.east")


func test_view_height_field_adds_the_compiled_relief() -> void:
	var parsed := _fixture()
	var source := FileAccess.get_file_as_string(FIXTURE_PATH)
	for statement in FIXTURE_STATEMENTS:
		source = source.replace(statement + "\n", "")
	var flat := MapRrmapParser.parse(source, "res://relief_flat.rrmap")
	assert_true(flat.is_ok(), str(flat.formatted_diagnostics()))
	if not parsed.is_ok() or not flat.is_ok():
		return
	var relief_field := MapViewMeshBuilderTerrain.ensure_height_field(
		parsed.definition, MapBuilder.build(parsed.definition)
	)
	var flat_field := MapViewMeshBuilderTerrain.ensure_height_field(
		flat.definition, MapBuilder.build(flat.definition)
	)
	# Same seed, pads and water: the procedural detail cancels and the difference
	# is exactly the compiled relief, so the view no longer owns base height.
	for position in [Vector2(10.5, 10.5), Vector2(29.25, 14.75), Vector2(41.5, 16.5)]:
		assert_almost_eq(
			MapViewMeshBuilderTerrain.field_height(relief_field, position)
			- MapViewMeshBuilderTerrain.field_height(flat_field, position),
			parsed.definition.height_at_cell_space(position),
			0.0001,
			"view relief at %s" % position
		)
