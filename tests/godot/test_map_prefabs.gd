extends "res://tests/godot/test_case.gd"


func test_rotates_and_mirrors_terrain_buildings_and_orientation() -> void:
	var prefab := MapPrefab.new(&"block")
	prefab.terrain_rect(&"yard", MapTypes.TERRAIN_DIRT, Rect2i(0, 0, 3, 2))
	prefab.structure_rect(&"house", MapTypes.BUILDING_KIND_HOUSE, Rect2i(1, 0, 2, 3), &"", {
		"door_side": &"south",
		"ridge_axis": &"z",
	})
	var blueprint := _base_blueprint()
	blueprint.use_prefab_package(_package(&"test", [prefab]))
	blueprint.prefab_instance(&"rotated", &"test.block", Vector2i(8, 5), MapTransform.new(90, true))

	var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	assert_true(result.is_ok(), "Transformed prefab should compile: %s" % str(result.errors))
	if not result.is_ok():
		return
	assert_eq(result.definition.zones[0], {"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(7, 3, 2, 3)})
	var house := _record_by_id(result.definition.buildings, &"rotated/house")
	assert_eq(house["footprint"], Rect2(192, 64, 96, 64))
	assert_eq(house["door_side"], &"west")
	assert_eq(house["ridge_axis"], &"x")


func test_parameters_defaults_types_and_named_override_order() -> void:
	var prefab := MapPrefab.new(&"house")
	prefab.declare_parameter(&"wall_color", MapPrefab.TYPE_COLOR, Color.RED)
	prefab.declare_parameter(&"door_side", MapPrefab.TYPE_STRING_NAME, &"south")
	prefab.structure_rect(&"body", MapTypes.BUILDING_KIND_HOUSE, Rect2i(0, 0, 2, 3), &"", {
		"wall_color": MapPrefab.parameter(&"wall_color"),
		"door_side": MapPrefab.parameter(&"door_side"),
	})
	var blueprint := _base_blueprint()
	blueprint.use_prefab_package(_package(&"test", [prefab]))
	blueprint.prefab_instance(&"default", &"test.house", Vector2i(2, 2))
	blueprint.prefab_instance(&"custom", &"test.house", Vector2i(8, 2), MapTransform.new(90), {
		&"wall_color": Color.BLUE,
	}, {
		&"body": {"door_side": &"north", "wall_color": Color.GREEN},
	})
	blueprint.override_object(&"custom/body", {"wall_color": Color.YELLOW})

	var definition := MapBlueprintCompiler.compile(blueprint)
	assert_true(definition != null)
	if definition == null:
		return
	var default_house := _record_by_id(definition.buildings, &"default/body")
	assert_eq(default_house["wall_color"], Color.RED)
	assert_eq(default_house["door_side"], &"south")
	var custom_house := _record_by_id(definition.buildings, &"custom/body")
	assert_eq(custom_house["door_side"], &"north", "Instance override applies after transform")
	assert_eq(custom_house["wall_color"], Color.YELLOW, "Map override applies last")

	var bad_type := _base_blueprint()
	bad_type.use_prefab_package(_package(&"test", [prefab]))
	bad_type.prefab_instance(&"bad", &"test.house", Vector2i(2, 2), null, {&"wall_color": &"red"})
	_assert_compile_error(bad_type, "must have type color")


func test_nested_instances_compose_namespaces_and_transforms() -> void:
	var tower := MapPrefab.new(&"tower")
	tower.structure_rect(&"body", MapTypes.BUILDING_KIND_WALL, Rect2i(0, 0, 2, 3))
	var gate := MapPrefab.new(&"gate")
	gate.instance(&"left", &"test.tower", Vector2i(1, 0), MapTransform.new(90))
	gate.instance(&"right", &"test.tower", Vector2i(5, 0))
	var blueprint := _base_blueprint()
	blueprint.use_prefab_package(_package(&"test", [tower, gate]))
	blueprint.prefab_instance(&"north_gate", &"test.gate", Vector2i(10, 8), MapTransform.new(90))

	var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	assert_true(result.is_ok(), "Nested prefab should compile: %s" % str(result.errors))
	if not result.is_ok():
		return
	assert_eq(_ids(result.definition.buildings), [&"north_gate/left/body", &"north_gate/right/body"])
	assert_eq(_record_by_id(result.definition.buildings, &"north_gate/left/body")["footprint"], Rect2(288, 224, 64, 96))
	assert_eq(_record_by_id(result.definition.buildings, &"north_gate/right/body")["footprint"], Rect2(256, 416, 96, 64))


func test_rejects_recursive_prefabs_duplicate_ids_and_invalid_override_targets() -> void:
	var recursive_a := MapPrefab.new(&"a")
	recursive_a.instance(&"b", &"test.b", Vector2i.ZERO)
	var recursive_b := MapPrefab.new(&"b")
	recursive_b.instance(&"a", &"test.a", Vector2i.ZERO)
	var recursive := _base_blueprint()
	recursive.use_prefab_package(_package(&"test", [recursive_a, recursive_b]))
	recursive.prefab_instance(&"cycle", &"test.a", Vector2i(2, 2))
	_assert_compile_error(recursive, "recursive prefab instance")

	var duplicate_prefab := MapPrefab.new(&"duplicate")
	duplicate_prefab.structure_rect(&"body", MapTypes.BUILDING_KIND_HOUSE, Rect2i(0, 0, 1, 1))
	duplicate_prefab.structure_rect(&"body", MapTypes.BUILDING_KIND_HOUSE, Rect2i(1, 1, 1, 1))
	var duplicate := _base_blueprint()
	duplicate.use_prefab_package(_package(&"test", [duplicate_prefab]))
	duplicate.prefab_instance(&"one", &"test.duplicate", Vector2i(2, 2))
	_assert_compile_error(duplicate, "duplicates prefab-local id")

	var simple := MapPrefab.new(&"simple")
	simple.structure_rect(&"body", MapTypes.BUILDING_KIND_HOUSE, Rect2i(0, 0, 2, 2))
	var duplicate_instance := _base_blueprint()
	duplicate_instance.use_prefab_package(_package(&"test", [simple]))
	duplicate_instance.prefab_instance(&"same", &"test.simple", Vector2i(2, 2))
	duplicate_instance.prefab_instance(&"same", &"test.simple", Vector2i(8, 2))
	_assert_compile_error(duplicate_instance, "duplicates prefab instance id")

	var invalid_target := _base_blueprint()
	invalid_target.use_prefab_package(_package(&"test", [simple]))
	invalid_target.prefab_instance(&"one", &"test.simple", Vector2i(2, 2), null, {}, {
		&"missing": {"wall_height": 10.0},
	})
	_assert_compile_error(invalid_target, "targets unknown prefab object: missing")


func test_nested_named_override_and_recompilation_are_deterministic() -> void:
	var child := MapPrefab.new(&"child")
	child.structure_rect(&"body", MapTypes.BUILDING_KIND_HOUSE, Rect2i(0, 0, 2, 2), &"", {"wall_height": 64.0})
	var parent := MapPrefab.new(&"parent")
	parent.instance(&"inner", &"test.child", Vector2i(1, 1))
	var blueprint := _base_blueprint()
	blueprint.use_prefab_package(_package(&"test", [parent, child]))
	blueprint.prefab_instance(&"outer", &"test.parent", Vector2i(4, 4), null, {}, {
		&"inner/body": {"wall_height": 120.0},
	})
	var first := MapBlueprintCompiler.compile(blueprint)
	var second := MapBlueprintCompiler.compile(blueprint)
	assert_true(first != null and second != null)
	if first == null or second == null:
		return
	assert_eq(_record_by_id(first.buildings, &"outer/inner/body")["wall_height"], 120.0)
	assert_eq(first.fingerprint, second.fingerprint)
	assert_eq(first.buildings, second.buildings)


func test_urban_package_examples_compile_without_lower_town_migration() -> void:
	var blueprint := _base_blueprint(Vector2i(80, 50))
	blueprint.use_prefab_package(UrbanPrefabPackage.create())
	blueprint.prefab_instance(&"street.houses", UrbanPrefabPackage.HOUSE_ROW, Vector2i(5, 8))
	blueprint.prefab_instance(&"wall.east", UrbanPrefabPackage.WALL_TOWER_SEGMENT, Vector2i(30, 10), MapTransform.new(90))
	blueprint.prefab_instance(&"gate.north", UrbanPrefabPackage.GATE_COMPOSITION, Vector2i(45, 20), null, {}, {
		&"arch": {"top_px": 288.0},
	})
	var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	assert_true(result.is_ok(), "Urban examples should compile: %s" % str(result.errors))
	if result.is_ok():
		assert_eq(_record_by_id(result.definition.view_landmarks, &"gate.north/arch")["top_px"], 288.0)


func _base_blueprint(size: Vector2i = Vector2i(30, 20)) -> MapBlueprint:
	var blueprint := MapBlueprint.new(&"prefab_test", &"loc.prefab_test", size, MapTypes.TERRAIN_GRASS)
	blueprint.player_spawn(&"spawn.main", Vector2i(1, 1))
	return blueprint


func _package(package_id: StringName, prefabs: Array[MapPrefab]) -> MapPrefabPackage:
	var package := MapPrefabPackage.new(package_id)
	for prefab in prefabs:
		package.add_prefab(prefab)
	return package


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
