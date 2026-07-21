extends "res://tests/godot/test_case.gd"


func test_local_species_catalog_covers_woodland_and_orchard_trees() -> void:
	assert_eq(MapViewTreeSpecies.ALL_SPECIES.size(), 10)
	for species in MapViewTreeSpecies.ALL_SPECIES:
		assert_true(MapViewTreeSpecies.is_known_species(species))
		var silhouette := MapViewTreeSpecies.silhouette_for(species)
		assert_true(silhouette != &"")
		assert_true(MapViewMeshBuilderPrimitives.tree_wood_mesh(species) is ArrayMesh)
		assert_true(MapViewMeshBuilderPrimitives.tree_canopy_mesh(species) is ArrayMesh)
		var stats := MapViewMeshBuilderPrimitives.tree_geometry_stats(species)
		assert_true(int(stats.get("wood_segments", 0)) > 6, "%s needs visible branching" % species)
		assert_true(int(stats.get("leaf_count", 0)) >= 25, "%s needs terminal leaf sprays" % species)
		assert_true(int(stats.get("wood_segments", 999)) <= 52, "%s exceeds branch budget" % species)


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
	assert_true(MapViewTreeSpecies.bark_kind_for(MapViewTreeSpecies.SPECIES_BIRCH) == MapViewTreeSpecies.BARK_BIRCH)


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
