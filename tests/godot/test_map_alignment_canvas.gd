extends "res://tests/godot/test_case.gd"

var _canvas: MapAlignmentCanvas


func before_each() -> void:
	super.before_each()
	_canvas = MapAlignmentCanvas.new()


func after_each() -> void:
	_canvas.free()
	_canvas = null


func test_background_transform_and_visibility_define_world_bounds() -> void:
	var image := Image.create(40, 20, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_canvas.set_background(ImageTexture.create_from_image(image), "/tmp/reference.png")

	assert_true(_canvas.has_background())
	assert_eq(_canvas.background_path, "/tmp/reference.png")
	assert_eq(_canvas.background_world_rect(), Rect2(0, 0, 40, 20))

	_canvas.set_background_offset(Vector2(-12, 8))
	_canvas.set_background_scale(2.5)
	assert_eq(_canvas.background_world_rect(), Rect2(-12, 8, 100, 50))
	assert_eq(_canvas.visible_world_bounds(), Rect2(-12, 8, 100, 50))

	_canvas.set_background_visible(false)
	assert_false(_canvas.visible_world_bounds().has_area())


func test_clear_resets_layers_seams_selection_and_background() -> void:
	var parsed := MapRrmapParser.parse_file("res://tests/fixtures/maps/rrmap_courtyard_example.rrmap")
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definitions: Array[MapDefinition] = []
	definitions.append(parsed.definition)
	_canvas.configure(definitions, {parsed.definition.map_id: Vector2.ZERO}, [{
		"base_map_id": parsed.definition.map_id,
		"neighbor_map_id": parsed.definition.map_id,
		"base": {"rect": Rect2(0, 0, 32, 32)},
		"neighbor": {"rect": Rect2(0, 0, 32, 32)},
	}])
	_canvas.select_layer(parsed.definition.map_id)
	_canvas.selected_primitive_id = &"prop.well"
	var image := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_canvas.set_background(ImageTexture.create_from_image(image), "reference.png")
	_canvas.set_background_offset(Vector2(-4, 6))
	_canvas.set_background_scale(2.0)
	_canvas.edit_background = true

	_canvas.clear()

	assert_true(_canvas.layer_ids().is_empty())
	assert_true(_canvas.seams.is_empty())
	assert_eq(_canvas.selected_map_id, &"")
	assert_eq(_canvas.selected_primitive_id, &"")
	assert_false(_canvas.has_background())
	assert_eq(_canvas.background_path, "")
	assert_eq(_canvas.background_offset, Vector2.ZERO)
	assert_eq(_canvas.background_scale, 1.0)
	assert_false(_canvas.edit_background)


func test_background_values_are_clamped_and_clear_resets_state() -> void:
	var image := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	_canvas.set_background(ImageTexture.create_from_image(image), "reference.png")
	_canvas.set_background_scale(0.0)
	_canvas.set_background_opacity(2.0)
	_canvas.edit_background = true

	assert_eq(_canvas.background_scale, MapAlignmentCanvas.MIN_BACKGROUND_SCALE)
	assert_eq(_canvas.background_opacity, 1.0)

	_canvas.clear_background()
	assert_false(_canvas.has_background())
	assert_eq(_canvas.background_offset, Vector2.ZERO)
	assert_eq(_canvas.background_scale, 1.0)
	assert_false(_canvas.edit_background)
