extends "res://tests/godot/test_case.gd"


func test_source_identity_diagnostics_have_stable_codes() -> void:
	var duplicate := _base_blueprint()
	duplicate.prop(&"same", MapTypes.PROP_KIND_ANVIL, Vector2i(2, 2))
	duplicate.prop(&"same", MapTypes.PROP_KIND_CART, Vector2i(3, 2))
	_assert_code(duplicate, &"MAP_ID_DUPLICATE")

	var unstable := _base_blueprint()
	unstable.prop(&"Not Stable", MapTypes.PROP_KIND_ANVIL, Vector2i(2, 2))
	_assert_code(unstable, &"MAP_ID_UNSTABLE")


func test_unknown_style_kind_and_terrain_diagnostics_have_stable_codes() -> void:
	var unknown_style := _base_blueprint()
	unknown_style.prop(&"styled", MapTypes.PROP_KIND_ANVIL, Vector2i(2, 2), &"missing")
	_assert_code(unknown_style, &"MAP_STYLE_UNKNOWN")

	var unknown_kind := _base_blueprint()
	unknown_kind.structure_rect(&"unknown", &"castle", Rect2i(2, 2, 2, 2))
	_assert_code(unknown_kind, &"MAP_KIND_UNKNOWN")

	var unknown_terrain := _base_blueprint()
	unknown_terrain.base_terrain = &"lava"
	_assert_code(unknown_terrain, &"MAP_TERRAIN_UNKNOWN")


func test_geometry_bounds_and_size_diagnostics_have_stable_codes() -> void:
	var outside := _base_blueprint()
	outside.structure_rect(&"outside", MapTypes.BUILDING_KIND_HOUSE, Rect2i(7, 7, 2, 2))
	_assert_code(outside, &"MAP_GEOMETRY_OUT_OF_BOUNDS")

	var invalid_size := _base_blueprint()
	invalid_size.structure_rect(&"empty", MapTypes.BUILDING_KIND_HOUSE, Rect2i(2, 2, 0, 2))
	_assert_code(invalid_size, &"MAP_SIZE_INVALID")


func test_prefab_recursion_and_missing_override_targets_have_stable_codes() -> void:
	var prefab := MapPrefab.new(&"recursive")
	prefab.instance(&"self", &"test.recursive", Vector2i.ZERO)
	var package := MapPrefabPackage.new(&"test")
	package.add_prefab(prefab)
	var recursive := _base_blueprint()
	recursive.use_prefab_package(package)
	recursive.prefab_instance(&"cycle", &"test.recursive", Vector2i(2, 2))
	_assert_code(recursive, &"MAP_PREFAB_RECURSION")

	var missing_override := _base_blueprint()
	missing_override.override_object(&"missing", {"wall_height": 64.0})
	_assert_code(missing_override, &"MAP_OVERRIDE_TARGET_MISSING")


func test_transition_spawn_relationships_are_validated_against_registry() -> void:
	var partial := _base_blueprint()
	partial.transition(&"partial", Rect2i(6, 2, 1, 1), &"destination", &"", &"local")
	_assert_code(partial, &"MAP_TRANSITION_SPAWN_RELATION_INVALID", {&"destination": {&"entry": true}})

	var unknown_scene := _base_blueprint()
	unknown_scene.transition(&"unknown.scene", Rect2i(6, 2, 1, 1), &"missing", &"entry", &"local")
	_assert_code(unknown_scene, &"MAP_TRANSITION_DESTINATION_UNKNOWN", {&"destination": {&"entry": true}})

	var unknown_spawn := _base_blueprint()
	unknown_spawn.transition(&"unknown.spawn", Rect2i(6, 2, 1, 1), &"destination", &"missing", &"local")
	_assert_code(unknown_spawn, &"MAP_TRANSITION_DESTINATION_SPAWN_UNKNOWN", {&"destination": {&"entry": true}})


func test_anchor_inside_blocking_geometry_is_an_error() -> void:
	var blueprint := _base_blueprint()
	blueprint.structure_rect(&"house", MapTypes.BUILDING_KIND_HOUSE, Rect2i(3, 3, 2, 2))
	blueprint.interaction_anchor(&"work", Vector2i(3, 3))
	_assert_code(blueprint, &"MAP_ANCHOR_BLOCKED")


func test_required_anchor_must_exist_and_be_reachable_from_spawn() -> void:
	var missing := _base_blueprint()
	_assert_code(missing, &"MAP_REQUIRED_ANCHOR_MISSING", {}, [&"required"])

	var unreachable := _base_blueprint()
	unreachable.structure_rect(&"barrier", MapTypes.BUILDING_KIND_WALL, Rect2i(4, 0, 1, 8))
	unreachable.interaction_anchor(&"required", Vector2i(6, 6))
	_assert_code(unreachable, &"MAP_REQUIRED_ANCHOR_UNREACHABLE", {}, [&"required"])


func test_unintended_complete_overlap_is_a_warning() -> void:
	var blueprint := _base_blueprint()
	blueprint.structure_rect(&"first", MapTypes.BUILDING_KIND_HOUSE, Rect2i(3, 3, 2, 2))
	blueprint.structure_rect(&"second", MapTypes.BUILDING_KIND_HOUSE, Rect2i(3, 3, 2, 2))
	var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	assert_true(result.is_ok(), "Warnings must not reject compiled maps")
	_assert_result_code(result, &"MAP_GEOMETRY_OVERLAP", MapBlueprintDiagnostic.SEVERITY_WARNING)


func test_ambiguous_future_chunk_boundary_crossing_is_a_warning() -> void:
	var blueprint := _base_blueprint(Vector2i(40, 20))
	blueprint.structure_rect(&"crossing", MapTypes.BUILDING_KIND_HOUSE, Rect2i(15, 3, 2, 2))
	var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	assert_true(result.is_ok(), "Warnings must not reject compiled maps")
	_assert_result_code(result, &"MAP_CHUNK_BOUNDARY_AMBIGUOUS", MapBlueprintDiagnostic.SEVERITY_WARNING)


func test_diagnostics_are_machine_readable_and_deterministically_sorted() -> void:
	var blueprint := _base_blueprint(Vector2i(40, 20))
	blueprint.structure_rect(&"z.crossing", MapTypes.BUILDING_KIND_HOUSE, Rect2i(15, 3, 2, 2))
	blueprint.structure_rect(&"a.crossing", MapTypes.BUILDING_KIND_HOUSE, Rect2i(31, 3, 2, 2))
	var first := MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	var second := MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	assert_eq(first.formatted_diagnostics(), second.formatted_diagnostics())
	var payload := first.diagnostics[0].to_dict()
	for key in ["code", "severity", "message", "map_id", "path", "subject", "details"]:
		assert_true(payload.has(key), "Diagnostic payload must expose %s" % key)


func _base_blueprint(size: Vector2i = Vector2i(8, 8)) -> MapBlueprint:
	var blueprint := MapBlueprint.new(&"semantic_test", &"loc.semantic_test", size, MapTypes.TERRAIN_GRASS)
	blueprint.player_spawn(&"spawn.main", Vector2i(1, 1))
	return blueprint


func _assert_code(
	blueprint: MapBlueprint,
	expected_code: StringName,
	transition_registry: Dictionary = {},
	required_anchors: Array[StringName] = []
) -> void:
	var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint, required_anchors, transition_registry)
	_assert_result_code(result, expected_code, MapBlueprintDiagnostic.SEVERITY_ERROR)
	assert_false(result.is_ok(), "%s must reject the blueprint" % expected_code)


func _assert_result_code(result: MapBlueprintCompileResult, expected_code: StringName, severity: StringName) -> void:
	for diagnostic in result.diagnostics:
		if diagnostic.code == expected_code and diagnostic.severity == severity:
			return
	fail("Expected %s[%s], got %s" % [severity, expected_code, result.formatted_diagnostics()])
