extends "res://tests/godot/test_case.gd"

const SOURCE := "res://tests/fixtures/maps/rrmap_courtyard_example.rrmap"


func test_editor_moves_and_removes_direct_primitives_without_changing_ids() -> void:
	var model := MapAlignmentEditorModel.new()
	assert_true(model.load_source(SOURCE), model.last_error)
	if model.blueprint == null:
		return
	var target: Dictionary = model.blueprint.primitives.filter(
		func(primitive: Dictionary) -> bool: return primitive.get("primitive") == &"structure_rect"
	)[0]
	var target_id: StringName = target["id"]
	var original_rect: Rect2i = target["data"]["rect"]

	assert_true(model.move_primitive(target_id, Vector2i.RIGHT), model.last_error)
	assert_eq(model.selected_primitive_id, target_id)
	var moved: Dictionary = model.blueprint.primitives.filter(
		func(primitive: Dictionary) -> bool: return primitive.get("id") == target_id
	)[0]
	assert_eq(Rect2i(moved["data"]["rect"]).position, original_rect.position + Vector2i.RIGHT)
	assert_true(target_id in MapRrmapSerializer.canonical_print(model.blueprint))
	assert_true(model.remove_primitive(target_id), model.last_error)
	assert_false(target_id in MapRrmapSerializer.canonical_print(model.blueprint))
	assert_true(model.dirty)


func test_editor_adds_prop_through_normal_compiler_contract() -> void:
	var model := MapAlignmentEditorModel.new()
	assert_true(model.load_source(SOURCE), model.last_error)
	var prop_id := model.add_prop(&"barrels", Vector2i(8, 8), "editor.test_barrels")
	assert_eq(prop_id, &"editor.test_barrels", model.last_error)
	assert_eq(model.primitive_at(Vector2i(8, 8)).get("id"), prop_id)
	assert_true("prop editor.test_barrels barrels 8 8" in MapRrmapSerializer.canonical_print(model.blueprint))


func test_editor_rejects_unknown_prop_kind_without_dirtying_source() -> void:
	var model := MapAlignmentEditorModel.new()
	assert_true(model.load_source(SOURCE), model.last_error)
	var before := MapRrmapSerializer.canonical_print(model.blueprint)
	assert_eq(model.add_prop(&"barrel", Vector2i(8, 8)), &"")
	assert_false(model.dirty)
	assert_eq(MapRrmapSerializer.canonical_print(model.blueprint), before)

func test_editor_save_reload_round_trip_uses_canonical_serializer() -> void:
	var temp_path := "user://rrmap_editor_roundtrip.rrmap"
	var source_file := FileAccess.open(temp_path, FileAccess.WRITE)
	assert_true(source_file != null)
	if source_file == null:
		return
	source_file.store_string(FileAccess.get_file_as_string(SOURCE))
	source_file.close()

	var model := MapAlignmentEditorModel.new()
	assert_true(model.load_source(temp_path), model.last_error)
	assert_eq(model.add_prop(&"barrels", Vector2i(8, 8), "editor.round_trip"), &"editor.round_trip")
	assert_true(model.save(), model.last_error)
	assert_false(model.dirty)

	var reparsed := MapRrmapParser.parse_file(temp_path)
	assert_true(reparsed.is_ok(), str(reparsed.formatted_diagnostics()))
	if reparsed.is_ok():
		assert_eq(MapRrmapSerializer.canonical_print(reparsed.blueprint), MapRrmapSerializer.canonical_print(model.blueprint))
		var found_round_trip_prop := false
		for prop in reparsed.definition.props:
			if prop.get("id") == &"editor.round_trip":
				found_round_trip_prop = true
		assert_true(found_round_trip_prop, "saved prop must survive parser/compiler round trip")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
