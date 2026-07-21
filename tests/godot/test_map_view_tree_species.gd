extends "res://tests/godot/test_case.gd"


func test_estonian_species_catalog_covers_eight_popular_trees() -> void:
	assert_eq(MapViewTreeSpecies.ALL_SPECIES.size(), 8)
	for species in MapViewTreeSpecies.ALL_SPECIES:
		assert_true(MapViewTreeSpecies.is_known_species(species))
		var silhouette := MapViewTreeSpecies.silhouette_for(species)
		assert_true(silhouette != &"")
		assert_true(MapViewMeshBuilderPrimitives.canopy_mesh_for(silhouette) is ArrayMesh)


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
