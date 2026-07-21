extends "res://tests/godot/test_case.gd"


func test_grass_and_bush_variants_resolve_from_style_id() -> void:
	assert_eq(
		TerrainVegetation.resolved_variant(&"grass.flowers", {}),
		&"grass.flowers"
	)
	assert_eq(
		TerrainVegetation.resolved_variant(&"grass.tall", {"style_variant": &"grass.short"}),
		&"grass.short"
	)
	for variant in [
		TerrainVegetation.VARIANT_GRASS_CLOVER,
		TerrainVegetation.VARIANT_GRASS_FERN,
		TerrainVegetation.VARIANT_REED_SHORE,
	]:
		assert_true(TerrainVegetation.is_known_variant(variant))
		assert_true(TerrainVegetation.scatter_profile(variant).size() > 0)


func test_bush_dense_slows_more_than_tall_grass() -> void:
	var dense := TerrainVegetation.resolved_zone_speed(&"bush.dense", null)
	var tall := TerrainVegetation.resolved_zone_speed(&"grass.tall", null)
	assert_true(dense < tall)
	assert_true(dense < 1.0)


func test_bush_prop_defaults_to_penalty() -> void:
	assert_true(TerrainVegetation.default_speed_for_prop_kind(MapTypes.PROP_KIND_BUSH) < 1.0)


func test_tree_prop_defaults_to_mild_penalty() -> void:
	assert_true(TerrainVegetation.default_speed_for_prop_kind(MapTypes.PROP_KIND_TREE) < 1.0)
	assert_true(
		TerrainVegetation.default_speed_for_prop_kind(MapTypes.PROP_KIND_TREE)
		> TerrainVegetation.default_speed_for_prop_kind(MapTypes.PROP_KIND_BUSH)
	)


func test_species_tree_variants_are_known() -> void:
	for variant in [
		&"tree.pine",
		&"tree.birch",
		&"tree.oak",
		&"tree.alder",
		&"tree.aspen",
		&"tree.maple",
		&"tree.linden",
		&"tree.oak.large",
	]:
		assert_true(TerrainVegetation.is_known_variant(variant), String(variant))
		assert_true(TerrainVegetation.is_tree_variant(variant), String(variant))
		assert_true(TerrainVegetation.scatter_profile(variant).has("tree_chance"))

