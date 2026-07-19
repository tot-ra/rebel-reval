extends "res://tests/godot/test_case.gd"

const EXAMPLE_PATH := "res://tests/fixtures/maps/rrmap_courtyard_example.rrmap"


func test_complete_example_parses_and_compiles_through_blueprint_compiler() -> void:
	var parsed := MapRrmapParser.parse_file(EXAMPLE_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(parsed.blueprint.map_id, &"rrmap_courtyard_example")
	assert_eq(parsed.definition.map_id, &"rrmap_courtyard_example")
	assert_eq(parsed.definition.buildings.size(), 3) # House plus two wall fragments.
	assert_eq(parsed.definition.props.size(), 2)
	assert_eq(parsed.definition.get_meta("player_spawn_id"), &"spawn.main")
	assert_eq(parsed.definition.source_references, ["docs/MAP_AUTHORING.md"])


func test_wall_and_roof_material_style_keys_compile_into_buildings() -> void:
	var source := """rrmap 1
map materials loc.materials 12 10 grass
style house.log wall_height=96 wall_color=806f5cff wall_material=log roof_color=453027ff roof_material=shingle door_side=south
building house.main house 3 3 4 3 style=house.log
spawn spawn.main 2 2
"""
	var parsed := MapRrmapParser.parse(source, "res://materials.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(parsed.definition.buildings.size(), 1)
	var building: Dictionary = parsed.definition.buildings[0]
	assert_eq(building.get("wall_material"), &"log")
	assert_eq(building.get("roof_material"), &"shingle")


func test_comments_quoting_and_exact_primitive_mapping() -> void:
	var source := """rrmap 1 # version
map syntax_test loc.syntax_test 12 10 grass # map
terrain mud mud 1 1 2 2 layer=3 order=4
prop anvil.main anvil 4 5
spawn spawn.main 2 2
sign sign.south "quoted # text" 3 3 south
"""
	var parsed := MapRrmapParser.parse(source, "res://syntax_test.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(parsed.blueprint.primitives[0]["primitive"], &"terrain_rect")
	assert_eq(parsed.blueprint.primitives[0]["data"]["layer"], 3)
	assert_eq(parsed.blueprint.primitives[0]["data"]["order"], 4)
	assert_eq(parsed.definition.direction_signs[0]["text"], "quoted # text")


func test_malformed_input_reports_file_line_column_and_code() -> void:
	var source := """rrmap 1
map malformed loc.malformed twelve 10 grass
spawn spawn.main 2 2
"""
	var parsed := MapRrmapParser.parse(source, "res://bad/malformed.rrmap")
	assert_false(parsed.is_ok())
	assert_true(not parsed.diagnostics.is_empty())
	var diagnostic := parsed.diagnostics[0]
	assert_eq(diagnostic.source_path, "res://bad/malformed.rrmap")
	assert_eq(diagnostic.line, 2)
	assert_eq(diagnostic.column, 29)
	assert_eq(diagnostic.code, &"invalid_integer")
	assert_true(diagnostic.format().begins_with("res://bad/malformed.rrmap:2:29: error[invalid_integer]:"))


func test_unknown_commands_and_fields_cannot_execute_code() -> void:
	var source := """rrmap 1
map safe loc.safe 10 10 grass
spawn spawn.main 2 2
load res://malicious.gd
building house house 3 3 2 2 script=res://malicious.gd
"""
	var parsed := MapRrmapParser.parse(source, "res://safe.rrmap")
	assert_false(parsed.is_ok())
	assert_true(_has_code(parsed, &"unknown_command"))
	assert_true(_has_code(parsed, &"unknown_typed_field"))


func test_version_zero_requires_explicit_migration_and_future_versions_are_rejected() -> void:
	var old := MapRrmapParser.parse("rrmap 0\nmap old loc.old 8 8 grass\nspawn spawn.main 1 1\n", "old.rrmap")
	assert_false(old.is_ok())
	assert_true(_has_code(old, &"version_migration_required"))
	assert_true(old.formatted_diagnostics()[0].contains("migrate the header to 'rrmap 1'"))
	var future := MapRrmapParser.parse("rrmap 2\nmap future loc.future 8 8 grass\nspawn spawn.main 1 1\n", "future.rrmap")
	assert_false(future.is_ok())
	assert_true(_has_code(future, &"unsupported_version"))


func test_canonical_print_is_deterministic_and_round_trips() -> void:
	var first := MapRrmapParser.parse_file(EXAMPLE_PATH)
	assert_true(first.is_ok(), str(first.formatted_diagnostics()))
	if not first.is_ok():
		return
	var canonical := MapRrmapParser.canonical_print(first.blueprint)
	var second := MapRrmapParser.parse(canonical, "canonical.rrmap")
	assert_true(second.is_ok(), str(second.formatted_diagnostics()))
	if not second.is_ok():
		return
	assert_eq(MapRrmapParser.canonical_print(second.blueprint), canonical)
	assert_eq(second.definition.fingerprint, first.definition.fingerprint)


func test_loader_recognizes_rrmap_and_returns_compiled_resource() -> void:
	var loader := RrmapResourceFormatLoader.new()
	assert_eq(loader._get_recognized_extensions(), PackedStringArray(["rrmap"]))
	assert_eq(loader._get_resource_type(EXAMPLE_PATH), "RrmapResource")
	var loaded = loader._load(EXAMPLE_PATH, EXAMPLE_PATH, false, ResourceLoader.CACHE_MODE_IGNORE)
	assert_true(loaded is RrmapResource)
	if loaded is RrmapResource:
		assert_true(loaded.is_valid())
		assert_eq(loaded.definition.map_id, &"rrmap_courtyard_example")


func _has_code(parsed: MapRrmapParseResult, code: StringName) -> bool:
	for diagnostic in parsed.diagnostics:
		if diagnostic.code == code:
			return true
	return false
