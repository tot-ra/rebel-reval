extends "res://tests/godot/test_case.gd"

## Cobblestone dominates the street-level frame and must retain more source
## detail than secondary terrain materials without inflating their texture array.


func test_cobblestone_uses_a_dedicated_high_resolution_texture_array() -> void:
	var terrain_patterns := MapViewMaterials.terrain_pattern_array(731)
	var cobble_patterns := MapViewMaterials.cobble_pattern_array(731)

	assert_eq(terrain_patterns.get_width(), MapViewMaterials.TEXTURE_SIZE)
	assert_eq(terrain_patterns.get_height(), MapViewMaterials.TEXTURE_SIZE)
	assert_eq(cobble_patterns.get_width(), MapViewMaterials.COBBLE_TEXTURE_SIZE)
	assert_eq(cobble_patterns.get_height(), MapViewMaterials.COBBLE_TEXTURE_SIZE)
	assert_eq(cobble_patterns.get_layers(), 2, "cobblestone and castle paving need high-resolution layers")
	assert_true(
		cobble_patterns.get_width() > terrain_patterns.get_width(),
		"cobblestone source resolution must exceed the general terrain resolution"
	)


func test_cobblestone_high_resolution_texture_remains_seamless() -> void:
	var image := MapViewMaterialPatterns.pattern_texture_at_size(
		MapViewMaterials.PATTERN_COBBLE,
		731,
		MapViewMaterials.COBBLE_TEXTURE_SIZE
	).get_image()
	var cell_size := image.get_width() / 8
	var internal_vertical := 0.0
	var internal_horizontal := 0.0
	for boundary in range(1, 8):
		internal_vertical += _vertical_delta(image, boundary * cell_size - 1, boundary * cell_size)
		internal_horizontal += _horizontal_delta(image, boundary * cell_size - 1, boundary * cell_size)
	internal_vertical /= 7.0
	internal_horizontal /= 7.0

	assert_true(
		_vertical_delta(image, image.get_width() - 1, 0) <= internal_vertical * 1.35,
		"horizontal wrapping must not introduce a seam stronger than internal stone boundaries"
	)
	assert_true(
		_horizontal_delta(image, image.get_height() - 1, 0) <= internal_horizontal * 1.35,
		"vertical wrapping must not introduce a seam stronger than internal stone boundaries"
	)


func _vertical_delta(image: Image, left_x: int, right_x: int) -> float:
	var total := 0.0
	for y in image.get_height():
		total += absf(image.get_pixel(left_x, y).r - image.get_pixel(right_x, y).r)
	return total / float(image.get_height())


func _horizontal_delta(image: Image, top_y: int, bottom_y: int) -> float:
	var total := 0.0
	for x in image.get_width():
		total += absf(image.get_pixel(x, top_y).r - image.get_pixel(x, bottom_y).r)
	return total / float(image.get_width())
