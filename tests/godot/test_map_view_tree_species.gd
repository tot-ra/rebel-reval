extends "res://tests/godot/test_case.gd"


func test_local_species_catalog_covers_woodland_and_orchard_trees() -> void:
	assert_eq(MapViewTreeSpecies.ALL_SPECIES.size(), 20)
	for species in MapViewTreeSpecies.ALL_SPECIES:
		assert_true(MapViewTreeSpecies.is_known_species(species))
		var silhouette := MapViewTreeSpecies.silhouette_for(species)
		assert_true(silhouette != &"")
		assert_true(MapViewMeshBuilderPrimitives.tree_wood_mesh(species) is ArrayMesh)
		assert_true(MapViewMeshBuilderPrimitives.tree_canopy_mesh(species) is ArrayMesh)
		var stats := MapViewMeshBuilderPrimitives.tree_geometry_stats(species)
		assert_true(int(stats.get("wood_segments", 0)) > 12, "%s needs visible branching" % species)
		assert_true(int(stats.get("leaf_count", 0)) >= 80, "%s needs terminal leaf sprays" % species)
		assert_true(int(stats.get("wood_segments", 999)) <= MapViewTreeMeshes.MAX_WOOD_SEGMENTS, "%s exceeds branch budget" % species)
		assert_true(int(stats.get("leaf_sprays", 999)) <= MapViewTreeMeshes.MAX_LEAF_SPRAYS, "%s exceeds foliage budget" % species)
		assert_true(int(stats.get("fruit_count", 999)) <= MapViewTreeMeshes.MAX_FRUIT_COUNT, "%s exceeds fruit budget" % species)
		var trunk_radii: Array = stats.get("trunk_radii", [])
		assert_eq(trunk_radii.size(), 4, "%s needs a radius at every trunk joint" % species)
		for radius_index in range(1, trunk_radii.size()):
			assert_true(
				float(trunk_radii[radius_index]) < float(trunk_radii[radius_index - 1]),
				"%s trunk must narrow continuously with height" % species
			)
		assert_true(
			float(trunk_radii[0]) * 2.0 < float(stats.get("trunk_height", 0.0)) * 0.22,
			"%s trunk is too thick for its height" % species
		)


func test_species_geometry_is_cached_for_multimesh_reuse() -> void:
	for species in MapViewTreeSpecies.ALL_SPECIES:
		assert_true(
			MapViewMeshBuilderPrimitives.tree_wood_mesh(species)
			== MapViewMeshBuilderPrimitives.tree_wood_mesh(species),
			"%s wood mesh must be shared between instances" % species
		)
		assert_true(
			MapViewMeshBuilderPrimitives.tree_canopy_mesh(species)
			== MapViewMeshBuilderPrimitives.tree_canopy_mesh(species),
			"%s canopy mesh must be shared between instances" % species
		)


func test_variant_pins_species_and_optional_size() -> void:
	var oak := MapViewTreeSpecies.parse_variant(&"tree.oak")
	assert_eq(oak.get("species"), MapViewTreeSpecies.SPECIES_OAK)
	var birch_large := MapViewTreeSpecies.parse_variant(&"tree.birch.large")
	assert_eq(birch_large.get("species"), MapViewTreeSpecies.SPECIES_BIRCH)
	assert_eq(birch_large.get("size"), MapViewTreeSpecies.SIZE_LARGE)
	var mixed := MapViewTreeSpecies.parse_variant(&"tree.mixed")
	assert_eq(mixed.get("group"), &"mixed")
	assert_true(TerrainVegetation.is_known_variant(&"tree.oak.small"))
	assert_true(TerrainVegetation.is_tree_variant(&"tree.pine"))


func test_orchard_variants_resolve_fruit_species_and_meshes() -> void:
	var orchard := MapViewTreeSpecies.parse_variant(&"tree.orchard")
	assert_eq(orchard.get("group"), &"orchard")
	assert_true(TerrainVegetation.is_known_variant(&"tree.apple"))
	assert_true(TerrainVegetation.is_known_variant(&"tree.cherry"))
	assert_true(MapViewMeshBuilderPrimitives.tree_fruit_mesh(MapViewTreeSpecies.SPECIES_APPLE) is ArrayMesh)
	assert_true(MapViewMeshBuilderPrimitives.tree_fruit_mesh(MapViewTreeSpecies.SPECIES_CHERRY) is ArrayMesh)
	assert_eq(MapViewMeshBuilderPrimitives.tree_fruit_mesh(MapViewTreeSpecies.SPECIES_BIRCH), null)


func test_birch_and_oak_use_distinct_growth_architecture() -> void:
	var birch := MapViewMeshBuilderPrimitives.tree_geometry_stats(MapViewTreeSpecies.SPECIES_BIRCH)
	var oak := MapViewMeshBuilderPrimitives.tree_geometry_stats(MapViewTreeSpecies.SPECIES_OAK)
	assert_true(int(birch["wood_segments"]) != int(oak["wood_segments"]))
	assert_true(int(birch["leaf_count"]) >= 500, "birch crown needs dense leaf coverage")
	assert_true(int(birch["leaf_count"]) > int(oak["leaf_count"]), "birch should carry more, smaller leaves than oak")
	assert_true(int(birch["wood_segments"]) >= 40, "birch needs a deeper branch skeleton")
	var birch_radii: Array = birch["trunk_radii"]
	assert_true(
		float(birch_radii[0]) * 2.0 < float(birch["trunk_height"]) * 0.08,
		"birch should retain a slender height-to-diameter ratio"
	)
	assert_true(MapViewTreeSpecies.bark_kind_for(MapViewTreeSpecies.SPECIES_BIRCH) == MapViewTreeSpecies.BARK_BIRCH)


func test_size_classes_make_large_trees_much_taller() -> void:
	var small := MapViewTreeSpecies.instance_scale(MapViewTreeSpecies.SIZE_SMALL, 0.5)
	var medium := MapViewTreeSpecies.instance_scale(MapViewTreeSpecies.SIZE_MEDIUM, 0.5)
	var large := MapViewTreeSpecies.instance_scale(MapViewTreeSpecies.SIZE_LARGE, 0.5)
	assert_true(small.y < medium.y, "saplings must sit below medium crowns")
	assert_true(large.y > medium.y * 1.7, "large veterans must tower well above medium trees")
	assert_true(large.y > large.x, "large trees stretch taller than they widen")
	assert_true(small.y < small.x * 1.05, "saplings stay compact rather than lanky")


func test_mixed_weights_sum_to_one() -> void:
	var total := 0.0
	for weight: Variant in MapViewTreeSpecies.MIXED_WEIGHTS.values():
		total += float(weight)
	assert_true(absf(total - 1.0) < 0.001)


func test_authored_tree_prop_builds_species_mesh() -> void:
	var prop := {
		"id": &"yard.oak",
		"kind": MapTypes.PROP_KIND_TREE,
		"position": Vector2(64, 64),
		"style_variant": &"tree.oak.large",
	}
	var node := MapViewMeshBuilderProps.build_prop(prop, MapTypes.DEFAULT_CELL_SIZE)
	assert_eq(node.get_meta(&"tree_species"), MapViewTreeSpecies.SPECIES_OAK)
	assert_eq(node.get_meta(&"tree_size"), MapViewTreeSpecies.SIZE_LARGE)
	assert_true(node.has_node("Trunk"))
	assert_true(node.has_node("Canopy"))
	assert_true((node.get_node("Canopy") as MeshInstance3D).mesh is ArrayMesh)
	node.free()


func test_outdoor_maps_author_multiple_tree_species() -> void:
	var definition: MapDefinition = preload(
		"res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd"
	).create()
	var species_seen: Dictionary = {}
	for prop in definition.props:
		if prop.get("kind") != MapTypes.PROP_KIND_TREE:
			continue
		var variant: StringName = prop.get("style_variant", &"")
		var parsed: Dictionary = MapViewTreeSpecies.parse_variant(variant)
		if parsed.has("species"):
			species_seen[parsed["species"]] = true
	assert_true(species_seen.size() >= 3, "harbor east should author several Estonian shoreline species")
