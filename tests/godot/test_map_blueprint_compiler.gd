extends "res://tests/godot/test_case.gd"


func test_compiles_metadata_and_every_explicit_primitive() -> void:
	var blueprint := _base_blueprint()
	blueprint.add_source_reference("README.md")
	blueprint.terrain_rect(&"yard", MapTypes.TERRAIN_DIRT, Rect2i(1, 1, 2, 2))
	blueprint.structure_rect(&"house.main", MapTypes.BUILDING_KIND_HOUSE, Rect2i(4, 4, 3, 2))
	blueprint.wall_run(&"wall.north", Vector2i(2, 8), Vector2i(9, 8), 1)
	blueprint.prop(&"prop.anvil", MapTypes.PROP_KIND_ANVIL, Vector2i(5, 6))
	blueprint.transition(&"exit.east", Rect2i(19, 5, 1, 2), &"forge", &"door_courtyard", &"exit.east")
	blueprint.interaction_anchor(&"anchor.work", Vector2i(7, 5), &"work")
	blueprint.patrol_path(&"patrol.watch", [Vector2i(2, 2), Vector2i(8, 2), Vector2i(8, 7)])
	blueprint.excluded_rect(&"blocked.store", Rect2i(10, 10, 2, 2))
	blueprint.fade_rect(&"fade.roof", Rect2i(4, 4, 3, 2))
	blueprint.direction_sign(&"sign.exit", "to harbour", Vector2i(18, 6), Vector2i.RIGHT)
	blueprint.view_landmark(&"landmark.gate", &"gate_arch", Rect2i(15, 3, 2, 1))
	blueprint.surroundings([&"west", &"north"])
	blueprint.camera_bounds(Rect2i(1, 1, 18, 10))

	var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	assert_true(result.is_ok(), "Every explicit primitive should compile: %s" % str(result.errors))
	if not result.is_ok():
		return
	var definition := result.definition
	assert_eq(definition.map_id, &"blueprint_test")
	assert_eq(definition.location, &"loc.blueprint_test")
	assert_eq(definition.size_cells, Vector2i(20, 12))
	assert_eq(definition.player_spawn, Vector2(80, 80))
	assert_eq(definition.get_meta("player_spawn_id"), &"spawn.main")
	assert_eq(definition.zones[0], {"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(1, 1, 2, 2)})
	assert_eq(_record_by_id(definition.buildings, &"house.main")["footprint"], Rect2(128, 128, 96, 64))
	assert_eq(_record_by_id(definition.props, &"prop.anvil")["position"], Vector2(176, 208))
	assert_eq(_record_by_id(definition.transitions, &"exit.east")["rect"], Rect2(608, 160, 32, 64))
	assert_eq(_record_by_id(definition.interaction_anchors, &"anchor.work")["position"], Vector2(240, 176))
	assert_eq(_record_by_id(definition.patrols, &"patrol.watch")["points"], [Vector2(80, 80), Vector2(272, 80), Vector2(272, 240)])
	assert_eq(definition.excluded_areas, [Rect2i(10, 10, 2, 2)])
	assert_eq(_record_by_id(definition.fade_volumes, &"fade.roof")["rect"], Rect2(128, 128, 96, 64))
	assert_eq(_record_by_id(definition.direction_signs, &"sign.exit")["direction"], Vector2.RIGHT)
	assert_eq(_record_by_id(definition.view_landmarks, &"landmark.gate")["rect"], Rect2(480, 96, 64, 32))
	assert_eq(definition.camera_bounds, Rect2(32, 32, 576, 320))
	assert_eq(definition.source_references, ["README.md"])
	assert_eq(definition.surroundings_town_sides, [&"north", &"west"])
	assert_eq(definition.surroundings_sides, {&"north": &"town", &"west": &"town"})
	assert_true(definition.validate().is_empty(), "Compiled runtime contract must validate")


func test_grouped_terrain_rectangles_and_orthogonal_strokes_expand_deterministically() -> void:
	var blueprint := _base_blueprint()
	blueprint.terrain_rects(&"water.group", MapTypes.TERRAIN_WATER, [Rect2i(8, 1, 2, 2), Rect2i(1, 1, 2, 1)], 0, 2)
	blueprint.terrain_stroke(&"road.main", MapTypes.TERRAIN_COBBLESTONE, [Vector2i(1, 5), Vector2i(5, 5), Vector2i(5, 8)], 2, 1, 0)
	blueprint.terrain_rect(&"top.paint", MapTypes.TERRAIN_STONE, Rect2i(3, 5, 1, 1), 2, 0)

	var definition := MapBlueprintCompiler.compile(blueprint)
	assert_true(definition != null)
	if definition == null:
		return
	assert_eq(definition.zones, [
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(1, 1, 2, 1)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(8, 1, 2, 2)},
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(1, 5, 5, 2)},
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(5, 5, 2, 4)},
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(3, 5, 1, 1)},
	])


func test_rect_placement_uses_cell_rect_center_for_even_footprints() -> void:
	var blueprint := _base_blueprint()
	blueprint.prop_rect(&"prop.anvil", MapTypes.PROP_KIND_ANVIL, Rect2i(2, 3, 2, 2))
	blueprint.interaction_anchor_rect(&"anchor.work", Rect2i(4, 4, 2, 2))
	blueprint.patrol_path_rects(&"patrol.watch", [Rect2i(1, 1, 2, 2), Rect2i(7, 1, 2, 2)])
	var definition := MapBlueprintCompiler.compile(blueprint)
	assert_true(definition != null)
	if definition == null:
		return
	assert_eq(_record_by_id(definition.props, &"prop.anvil")["position"], Vector2(96, 128))
	assert_eq(_record_by_id(definition.interaction_anchors, &"anchor.work")["position"], Vector2(160, 160))
	assert_eq(_record_by_id(definition.patrols, &"patrol.watch")["points"], [Vector2(64, 64), Vector2(256, 64)])


func test_wall_openings_use_stable_deterministic_fragment_ids() -> void:
	var blueprint := _base_blueprint()
	blueprint.wall_run(
		&"wall.gate",
		Vector2i(1, 6),
		Vector2i(10, 6),
		1,
		[Rect2i(4, 6, 2, 1), Rect2i(8, 6, 1, 1)]
	)
	var definition := MapBlueprintCompiler.compile(blueprint)
	assert_true(definition != null)
	if definition == null:
		return
	assert_eq(_ids(definition.buildings), [&"wall.gate/segment.000", &"wall.gate/segment.001", &"wall.gate/segment.002"])
	assert_eq(definition.buildings[0]["footprint"], Rect2(32, 192, 96, 32))
	assert_eq(definition.buildings[1]["footprint"], Rect2(192, 192, 64, 32))
	assert_eq(definition.buildings[2]["footprint"], Rect2(288, 192, 64, 32))


func test_named_style_inheritance_and_override_precedence() -> void:
	var blueprint := _base_blueprint()
	blueprint.define_style(&"base.wall", {"wall_height": 64.0, "wall_color": Color.RED})
	blueprint.define_style(&"tall.wall", {"wall_height": 96.0, "roof_color": Color.BLUE}, &"base.wall")
	blueprint.structure_rect(
		&"styled.house",
		MapTypes.BUILDING_KIND_HOUSE,
		Rect2i(4, 4, 3, 2),
		&"tall.wall",
		{"wall_height": 112.0}
	)
	blueprint.override_object(&"styled.house", {"wall_height": 128.0, "wall_color": Color.GREEN})

	var definition := MapBlueprintCompiler.compile(blueprint)
	assert_true(definition != null)
	if definition == null:
		return
	var building := _record_by_id(definition.buildings, &"styled.house")
	assert_eq(building["wall_height"], 128.0, "Object override wins over inline, child, and parent values")
	assert_eq(building["wall_color"], Color.GREEN, "Object override wins over inherited value")
	assert_eq(building["roof_color"], Color.BLUE, "Child style inherits and adds values")


func test_stable_id_placement_rows_support_slot_and_object_overrides() -> void:
	var blueprint := _base_blueprint()
	blueprint.define_style(&"row.props", {"style_variant": &"plain"})
	blueprint.placement_row(
		&"market.row",
		MapBlueprint.OBJECT_PROP,
		MapTypes.PROP_KIND_STALL,
		Vector2i(3, 4),
		Vector2i(2, 0),
		[&"fish", &"cloth", &"bread"],
		Vector2i.ONE,
		&"row.props",
		{&"cloth": {"style_variant": &"striped"}}
	)
	blueprint.override_object(&"market.row/bread", {"style_variant": &"bakery"})
	var definition := MapBlueprintCompiler.compile(blueprint)
	assert_true(definition != null)
	if definition == null:
		return
	assert_eq(_ids(definition.props), [&"market.row/bread", &"market.row/cloth", &"market.row/fish"])
	assert_eq(_record_by_id(definition.props, &"market.row/fish")["position"], Vector2(112, 144))
	assert_eq(_record_by_id(definition.props, &"market.row/cloth")["position"], Vector2(176, 144))
	assert_eq(_record_by_id(definition.props, &"market.row/cloth")["style_variant"], &"striped")
	assert_eq(_record_by_id(definition.props, &"market.row/bread")["style_variant"], &"bakery")


func test_unordered_declaration_order_is_canonical_but_ordered_semantics_are_preserved() -> void:
	var first := _base_blueprint()
	first.prop(&"prop.z", MapTypes.PROP_KIND_CART, Vector2i(7, 4))
	first.structure_rect(&"building.z", MapTypes.BUILDING_KIND_HOUSE, Rect2i(8, 8, 2, 2))
	first.prop(&"prop.a", MapTypes.PROP_KIND_ANVIL, Vector2i(4, 4))
	first.structure_rect(&"building.a", MapTypes.BUILDING_KIND_WALL, Rect2i(1, 8, 2, 1))
	first.patrol_path(&"patrol.route", [Vector2i(8, 2), Vector2i(3, 2), Vector2i(3, 7)])

	var second := _base_blueprint()
	second.patrol_path(&"patrol.route", [Vector2i(8, 2), Vector2i(3, 2), Vector2i(3, 7)])
	second.structure_rect(&"building.a", MapTypes.BUILDING_KIND_WALL, Rect2i(1, 8, 2, 1))
	second.prop(&"prop.a", MapTypes.PROP_KIND_ANVIL, Vector2i(4, 4))
	second.structure_rect(&"building.z", MapTypes.BUILDING_KIND_HOUSE, Rect2i(8, 8, 2, 2))
	second.prop(&"prop.z", MapTypes.PROP_KIND_CART, Vector2i(7, 4))

	var first_definition := MapBlueprintCompiler.compile(first)
	var second_definition := MapBlueprintCompiler.compile(second)
	assert_true(first_definition != null and second_definition != null)
	if first_definition == null or second_definition == null:
		return
	assert_eq(_ids(first_definition.buildings), [&"building.a", &"building.z"])
	assert_eq(_ids(first_definition.props), [&"prop.a", &"prop.z"])
	assert_eq(first_definition.patrols[0]["points"], [Vector2(272, 80), Vector2(112, 80), Vector2(112, 240)])
	assert_eq(first_definition.fingerprint, second_definition.fingerprint)
	assert_eq(first_definition.buildings, second_definition.buildings)
	assert_eq(first_definition.props, second_definition.props)


func test_repeated_compilation_has_stable_fingerprint() -> void:
	var blueprint := _base_blueprint()
	blueprint.terrain_rect(&"road", MapTypes.TERRAIN_STONE, Rect2i(1, 1, 8, 2), 1, 4)
	blueprint.prop(&"well", MapTypes.PROP_KIND_WELL, Vector2i(6, 6))
	var first := MapBlueprintCompiler.compile(blueprint)
	var second := MapBlueprintCompiler.compile(blueprint)
	assert_true(first != null and second != null)
	if first != null and second != null:
		assert_eq(first.fingerprint, second.fingerprint)
		assert_eq(first.fingerprint.length(), 64)


func test_rejects_duplicate_ids_unknown_styles_and_unknown_kinds() -> void:
	var duplicate := _base_blueprint()
	duplicate.prop(&"same.id", MapTypes.PROP_KIND_ANVIL, Vector2i(3, 3))
	duplicate.interaction_anchor(&"same.id", Vector2i(4, 4))
	_assert_compile_error(duplicate, "duplicates source id: same.id")

	var unknown_style := _base_blueprint()
	unknown_style.prop(&"styled", MapTypes.PROP_KIND_ANVIL, Vector2i(3, 3), &"missing.style")
	_assert_compile_error(unknown_style, "references unknown style: missing.style")

	var bad_building := _base_blueprint()
	bad_building.structure_rect(&"bad.building", &"castle", Rect2i(2, 2, 2, 2))
	_assert_compile_error(bad_building, "building kind is unknown")

	var bad_prop := _base_blueprint()
	bad_prop.prop(&"bad.prop", &"bonsai", Vector2i(3, 3))
	_assert_compile_error(bad_prop, "prop kind is unknown")

	var bad_landmark := _base_blueprint()
	bad_landmark.view_landmark(&"bad.landmark", &"tower", Rect2i(3, 3, 2, 2))
	_assert_compile_error(bad_landmark, "kind is unknown")


func test_rejects_invalid_geometry_with_source_paths() -> void:
	var bad_rect := _base_blueprint()
	bad_rect.structure_rect(&"outside", MapTypes.BUILDING_KIND_HOUSE, Rect2i(19, 11, 2, 2))
	_assert_compile_error(bad_rect, "primitives[1].rect is outside map bounds")

	var diagonal_stroke := _base_blueprint()
	diagonal_stroke.terrain_stroke(&"diagonal", MapTypes.TERRAIN_DIRT, [Vector2i(1, 1), Vector2i(3, 3)])
	_assert_compile_error(diagonal_stroke, "segment 0 must be non-zero and orthogonal")

	var diagonal_wall := _base_blueprint()
	diagonal_wall.wall_run(&"diagonal.wall", Vector2i(1, 1), Vector2i(4, 4))
	_assert_compile_error(diagonal_wall, "must have distinct orthogonal endpoints")

	var overlapping_openings := _base_blueprint()
	overlapping_openings.wall_run(&"wall", Vector2i(1, 6), Vector2i(10, 6), 1, [Rect2i(3, 6, 3, 1), Rect2i(5, 6, 2, 1)])
	_assert_compile_error(overlapping_openings, "openings overlap")


func test_rejects_recursive_inheritance_and_invalid_overrides() -> void:
	var recursive := _base_blueprint()
	recursive.define_style(&"style.a", {"wall_height": 64.0}, &"style.b")
	recursive.define_style(&"style.b", {"wall_height": 96.0}, &"style.a")
	recursive.structure_rect(&"house", MapTypes.BUILDING_KIND_HOUSE, Rect2i(2, 2, 2, 2), &"style.a")
	_assert_compile_error(recursive, "recursive style inheritance")

	var invalid_field := _base_blueprint()
	invalid_field.prop(&"prop", MapTypes.PROP_KIND_ANVIL, Vector2i(3, 3), &"", {"footprint": Rect2i(1, 1, 1, 1)})
	_assert_compile_error(invalid_field, "unsupported field for this primitive: footprint")

	var kind_mutation := _base_blueprint()
	kind_mutation.prop(&"prop", MapTypes.PROP_KIND_ANVIL, Vector2i(3, 3), &"", {"kind": MapTypes.PROP_KIND_CART})
	_assert_compile_error(kind_mutation, "unsupported field for this primitive: kind")

	var unknown_style_field := _base_blueprint()
	unknown_style_field.define_style(&"bad.style", {"raw_runtime_entry": true})
	_assert_compile_error(unknown_style_field, "unknown style field: raw_runtime_entry")

	var id_mutation := _base_blueprint()
	id_mutation.prop(&"prop", MapTypes.PROP_KIND_ANVIL, Vector2i(3, 3), &"", {"id": &"renamed"})
	_assert_compile_error(id_mutation, "cannot mutate stable identity")

	var unknown_target := _base_blueprint()
	unknown_target.override_object(&"missing.object", {"wall_height": 10.0})
	_assert_compile_error(unknown_target, "override targets unknown object")

	var disabled_target := _base_blueprint()
	disabled_target.placement_row(
		&"row",
		MapBlueprint.OBJECT_PROP,
		MapTypes.PROP_KIND_ANVIL,
		Vector2i(2, 2),
		Vector2i(1, 0),
		[&"disabled"],
		Vector2i.ONE,
		&"",
		{&"disabled": {"enabled": false}}
	)
	disabled_target.override_object(&"row/disabled", {"style_variant": &"worn"})
	_assert_compile_error(disabled_target, "override targets disabled object")

	var conflicting := _base_blueprint()
	conflicting.override_object(&"spawn.main", {"cell": Vector2i(3, 3)})
	conflicting.override_object(&"spawn.main", {"cell": Vector2i(4, 4)})
	_assert_compile_error(conflicting, "conflicts with another override")


func test_rejects_non_deterministic_constructs_invalid_ids_and_stale_sources() -> void:
	var non_deterministic := _base_blueprint()
	non_deterministic.primitives[0]["overrides"]["generator"] = func() -> int: return 1
	_assert_compile_error(non_deterministic, "unsupported non-deterministic value type")

	var invalid_id := _base_blueprint()
	invalid_id.prop(&"Bad ID", MapTypes.PROP_KIND_ANVIL, Vector2i(3, 3))
	_assert_compile_error(invalid_id, "has invalid stable id")

	var stale_source := _base_blueprint()
	stale_source.add_source_reference("docs/does-not-exist.md")
	_assert_compile_error(stale_source, "does not exist")

	var duplicate_source := _base_blueprint()
	duplicate_source.add_source_reference("README.md").add_source_reference("README.md")
	_assert_compile_error(duplicate_source, "duplicate source reference")


func test_requires_exactly_one_spawn_and_valid_row_slots() -> void:
	var no_spawn := MapBlueprint.new(&"no_spawn", &"loc.no_spawn", Vector2i(8, 8), MapTypes.TERRAIN_GRASS)
	_assert_compile_error(no_spawn, "exactly one enabled player_spawn")

	var two_spawns := _base_blueprint()
	two_spawns.player_spawn(&"spawn.other", Vector2i(3, 3))
	_assert_compile_error(two_spawns, "exactly one enabled player_spawn")

	var unstable_row := _base_blueprint()
	unstable_row.placement_row(
		&"row",
		MapBlueprint.OBJECT_PROP,
		MapTypes.PROP_KIND_ANVIL,
		Vector2i(2, 2),
		Vector2i(1, 0),
		[&"same", &"same"]
	)
	_assert_compile_error(unstable_row, "duplicate slot id")

	var unknown_slot := _base_blueprint()
	unknown_slot.placement_row(
		&"row",
		MapBlueprint.OBJECT_BUILDING,
		MapTypes.BUILDING_KIND_HOUSE,
		Vector2i(2, 2),
		Vector2i(3, 0),
		[&"one"],
		Vector2i(2, 2),
		&"",
		{&"missing": {"wall_height": 80.0}}
	)
	_assert_compile_error(unknown_slot, "unknown slot: missing")


func _base_blueprint() -> MapBlueprint:
	var blueprint := MapBlueprint.new(
		&"blueprint_test",
		&"loc.blueprint_test",
		Vector2i(20, 12),
		MapTypes.TERRAIN_GRASS
	)
	blueprint.player_spawn(&"spawn.main", Vector2i(2, 2))
	return blueprint


func _record_by_id(records: Array[Dictionary], record_id: StringName) -> Dictionary:
	for record in records:
		if record.get("id", &"") == record_id:
			return record
	return {}


func _ids(records: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for record in records:
		result.append(record["id"])
	return result


func _assert_compile_error(blueprint: MapBlueprint, expected: String) -> void:
	var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	assert_false(result.is_ok(), "Blueprint should be rejected")
	for error in result.errors:
		if error.contains(expected):
			return
	fail("Expected compile error containing <%s>, got: %s" % [expected, result.errors])
