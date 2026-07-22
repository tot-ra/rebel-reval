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



func test_cobblestone_surface_map_matches_high_resolution_source() -> void:
	var surface := MapViewMaterialPatterns.cobble_surface_texture(8219)
	assert_eq(surface.get_width(), MapViewMaterials.COBBLE_TEXTURE_SIZE)
	assert_eq(surface.get_height(), MapViewMaterials.COBBLE_TEXTURE_SIZE)
	var material := MapViewMaterials.blended_ground(731)
	assert_eq(material.get_shader_parameter("cobble_surface"), surface)

func test_natural_rock_pattern_avoids_masonry_horizontal_banding() -> void:
	var rock := MapViewMaterialPatterns.pattern_texture(MapViewMaterials.PATTERN_ROCK, 9041).get_image()
	var limestone := MapViewMaterialPatterns.pattern_texture(MapViewMaterials.PATTERN_LIMESTONE, 9041).get_image()
	var rock_anisotropy := _banding_anisotropy(rock)
	var limestone_anisotropy := _banding_anisotropy(limestone)
	assert_true(
		limestone_anisotropy > rock_anisotropy * 2.0,
		"limestone ashlar must band horizontally more than natural shoreline rock"
	)
	assert_true(
		rock_anisotropy < 1.35,
		"natural rock grain must stay roughly isotropic on sphere UVs"
	)


func test_cobblestone_high_resolution_texture_remains_seamless() -> void:
	var image := MapViewMaterialPatterns.pattern_texture_at_size(
		MapViewMaterials.PATTERN_COBBLE,
		731,
		MapViewMaterials.COBBLE_TEXTURE_SIZE
	).get_image()
	var boundaries_x := MapViewMaterialPatterns.COBBLE_STONES_X
	var boundaries_y := MapViewMaterialPatterns.COBBLE_STONES_Y
	var cell_width := float(image.get_width()) / float(boundaries_x)
	var cell_height := float(image.get_height()) / float(boundaries_y)
	var internal_vertical_peak := 0.0
	var internal_horizontal_peak := 0.0
	for boundary in range(1, boundaries_x):
		var pixel_x := roundi(float(boundary) * cell_width)
		internal_vertical_peak = maxf(internal_vertical_peak, _vertical_delta(image, pixel_x - 1, pixel_x))
	for boundary in range(1, boundaries_y):
		var pixel_y := roundi(float(boundary) * cell_height)
		internal_horizontal_peak = maxf(internal_horizontal_peak, _horizontal_delta(image, pixel_y - 1, pixel_y))

	assert_true(
		_vertical_delta(image, image.get_width() - 1, 0) <= internal_vertical_peak * 1.05,
		"horizontal wrapping must stay within the strongest internal stone boundary"
	)
	assert_true(
		_horizontal_delta(image, image.get_height() - 1, 0) <= internal_horizontal_peak * 1.05,
		"vertical wrapping must stay within the strongest internal stone boundary"
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


func _banding_anisotropy(image: Image) -> float:
	var row_means: Array[float] = []
	for y in image.get_height():
		var mean := 0.0
		for x in image.get_width():
			mean += image.get_pixel(x, y).r
		row_means.append(mean / float(image.get_width()))
	var column_means: Array[float] = []
	for x in image.get_width():
		var mean := 0.0
		for y in image.get_height():
			mean += image.get_pixel(x, y).r
		column_means.append(mean / float(image.get_height()))
	return _array_variance(row_means) / maxf(_array_variance(column_means), 0.0001)


func _array_variance(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var mean := 0.0
	for value in values:
		mean += value
	mean /= float(values.size())
	var variance := 0.0
	for value in values:
		var delta := value - mean
		variance += delta * delta
	return variance / float(values.size())


func _row_variance(image: Image) -> float:
	var total := 0.0
	for y in image.get_height():
		var row_mean := 0.0
		for x in image.get_width():
			row_mean += image.get_pixel(x, y).r
		row_mean /= float(image.get_width())
		var row_var := 0.0
		for x in image.get_width():
			var delta := image.get_pixel(x, y).r - row_mean
			row_var += delta * delta
		total += row_var / float(image.get_width())
	return total / float(image.get_height())


func _column_variance(image: Image) -> float:
	var total := 0.0
	for x in image.get_width():
		var column_mean := 0.0
		for y in image.get_height():
			column_mean += image.get_pixel(x, y).r
		column_mean /= float(image.get_height())
		var column_var := 0.0
		for y in image.get_height():
			var delta := image.get_pixel(x, y).r - column_mean
			column_var += delta * delta
		total += column_var / float(image.get_height())
	return total / float(image.get_width())
