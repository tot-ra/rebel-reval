extends "res://tests/godot/test_case.gd"

const SOURCE_PATH := "res://content/transitions/active_destinations.json"


func test_rentenitorn_transition_is_fail_closed_and_non_release() -> void:
	var file := FileAccess.open(SOURCE_PATH, FileAccess.READ)
	assert_true(file != null, "Transition manifest must be readable")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert_true(parsed is Dictionary, "Transition manifest must decode as an object")
	if not parsed is Dictionary:
		return
	var rentenitorn: Dictionary = {}
	for scene_record: Dictionary in (parsed as Dictionary).get("scenes", []):
		if scene_record.get("id", "") == "rentenitorn_interior":
			rentenitorn = scene_record
			break
	assert_false(rentenitorn.is_empty(), "Rentenitorn transition record must remain present")
	if rentenitorn.is_empty():
		return
	assert_false(
		bool(rentenitorn.get("active", true)),
		"Rentenitorn transition must remain inactive",
	)
	assert_false(
		bool(rentenitorn.get("release", true)),
		"Rentenitorn transition must remain non-release",
	)
	assert_eq(
		rentenitorn.get("spawns", []),
		[{"id": "rentenitorn_interior_entry"}],
		"Rentenitorn return spawn must remain stable",
	)


func test_inactive_reciprocal_wiring_stays_structural_but_not_active() -> void:
	var inactive_source := _base_blueprint()
	inactive_source.transition(
		&"inactive.destination",
		Rect2i(6, 2, 1, 1),
		&"inactive",
		&"entry",
		&"local",
	)
	var inactive_result := MapBlueprintCompiler.compile_with_diagnostics(
		inactive_source,
		[],
		{"inactive": {"spawns": {&"entry": true}, "active": false}},
	)
	assert_true(
		inactive_result.is_ok(),
		str(inactive_result.formatted_diagnostics()),
	)

	var active_source := _base_blueprint()
	active_source.scope = &"production"
	active_source.active = true
	active_source.transition(
		&"active.destination",
		Rect2i(6, 2, 1, 1),
		&"inactive",
		&"entry",
		&"local",
	)
	var active_result := MapBlueprintCompiler.compile_with_diagnostics(
		active_source,
		[],
		{"inactive": {"spawns": {&"entry": true}, "active": false}},
	)
	_assert_result_code(
		active_result,
		&"MAP_TRANSITION_DESTINATION_UNKNOWN",
		MapBlueprintDiagnostic.SEVERITY_ERROR,
	)
	assert_false(active_result.is_ok(), "active maps must not reference inactive destinations")


func _base_blueprint() -> MapBlueprint:
	var blueprint := MapBlueprint.new(
		&"r806_semantic_test",
		&"loc.r806_semantic_test",
		Vector2i(8, 8),
		MapTypes.TERRAIN_GRASS,
	)
	blueprint.player_spawn(&"spawn.main", Vector2i(1, 1))
	return blueprint


func _assert_result_code(
	result: MapBlueprintCompileResult,
	expected_code: StringName,
	severity: StringName,
) -> void:
	for diagnostic in result.diagnostics:
		if diagnostic.code == expected_code and diagnostic.severity == severity:
			return
	fail("Expected %s[%s], got %s" % [severity, expected_code, result.formatted_diagnostics()])
