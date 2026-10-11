extends "res://tests/godot/test_case.gd"

## Species leaf atlas: falling leaves and forest-floor litter show the leaf of
## the tree above them, tinted by species and season.

const LeafAtlas := preload("res://scripts/map/view3d/leaf_atlas.gd")


func _date(day: int, month: int) -> Dictionary:
	return {"day": day, "month": month, "year": 1343}


func test_every_tree_species_has_a_leaf_cell() -> void:
	for species: StringName in MapViewTreeSpecies.ALL_SPECIES:
		var cell := LeafAtlas.cell_for(species)
		assert_true(cell >= 0 and cell < 16, "%s maps to a cell" % species)
	assert_eq(LeafAtlas.cell_for(&"pine"), LeafAtlas.CELLS.find(&"pine_needles"))
	assert_ne(LeafAtlas.cell_for(&"oak"), LeafAtlas.cell_for(&"maple"))


func test_every_atlas_cell_holds_a_cut_out_leaf() -> void:
	var image: Image = LeafAtlas.ATLAS.get_image()
	if image.is_compressed():
		image.decompress()
	assert_eq(image.get_width(), 1024)
	for cell in LeafAtlas.CELLS.size():
		var rect := LeafAtlas.uv_rect(cell)
		var origin := Vector2i(rect.position * 1024.0)
		var opaque := 0
		var clear := 0
		for y in range(0, 256, 8):
			for x in range(0, 256, 8):
				var a := image.get_pixel(origin.x + x, origin.y + y).a
				if a > 0.5:
					opaque += 1
				elif a < 0.1:
					clear += 1
		assert_true(opaque > 30, "cell %s has a leaf" % LeafAtlas.CELLS[cell])
		assert_true(clear > 300, "cell %s has a transparent margin" % LeafAtlas.CELLS[cell])


func test_fresh_litter_follows_the_leaf_drop_then_browns() -> void:
	assert_eq(VegetationPhenology.fresh_litter_share(&"birch", _date(15, 7)), 0.0)
	var october := VegetationPhenology.fresh_litter_share(&"birch", _date(25, 10))
	assert_true(october > 0.6, "late October: most birch litter is fresh yellow")
	var december := VegetationPhenology.fresh_litter_share(&"birch", _date(20, 12))
	assert_true(december < october and december < 0.2, "browned by midwinter")
	assert_eq(VegetationPhenology.fresh_litter_share(&"birch", _date(1, 5)), 0.0)
	assert_eq(VegetationPhenology.fresh_litter_share(&"pine", _date(25, 10)), 0.0)


func test_litter_mesh_samples_its_species_cell() -> void:
	var mesh := CityVegetationBuilder.litter_mesh(&"maple", 2.0)
	var arrays := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var rect := LeafAtlas.uv_rect(LeafAtlas.cell_for(&"maple")).grow(0.0001)
	assert_true(uvs.size() > 0)
	for uv in uvs:
		assert_true(rect.has_point(uv), "maple litter stays in the maple cell")
	for color in colors:
		assert_true(color.a >= 0.0 and color.a <= 1.0)


func test_litter_season_sets_fresh_share_and_snow() -> void:
	var material := CityVegetationBuilder.litter_material(&"maple")
	CityVegetationBuilder.apply_litter_season(_date(25, 10), 0.0)
	assert_true(float(material.get_shader_parameter("fresh")) > 0.5)
	CityVegetationBuilder.apply_litter_season(_date(15, 7), 0.4)
	assert_eq(float(material.get_shader_parameter("fresh")), 0.0)
	assert_almost_eq(float(material.get_shader_parameter("snow_cover")), 0.4, 0.0001)


func test_city_leaf_fall_draws_atlas_leaves() -> void:
	var leaves := CityLeafFall.new()
	leaves.configure(null, 16)
	var material := (leaves.draw_pass_1 as ArrayMesh).surface_get_material(0) as ShaderMaterial
	assert_true(material != null)
	assert_eq(material.get_shader_parameter("leaf_atlas"), LeafAtlas.ATLAS)
	assert_eq(int(material.get_shader_parameter("fixed_cell")), -1)
	leaves.free()


func test_cell_code_round_trips_through_colour_alpha() -> void:
	for cell in 16:
		assert_eq(int(floor(LeafAtlas.cell_code(cell) * 16.0)), cell)
