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


func test_ancient_oak_landmark_is_huge_detailed_oak() -> void:
	MapViewAncientOakMeshes.reset_cache()
	var stats := MapViewMeshBuilderPrimitives.ancient_oak_geometry_stats()
	assert_true(float(stats["trunk_height"]) >= 10.0, "hingepuu trunk should tower over woodland oaks")
	assert_true(float(stats["trunk_base_radius"]) >= 0.9, "hingepuu needs a massive root flare")
	assert_true(int(stats["root_buttresses"]) >= 6, "buttress roots sell the ancient base")
	assert_true(int(stats["wood_segments"]) >= 120, "giant limbs need a deep branch skeleton")
	assert_true(int(stats["leaf_count"]) >= 800, "sacred canopy needs dense leaf sprays")
	assert_true(int(stats["moss_strands"]) >= 20, "hanging moss distinguishes the landmark oak")
	assert_true(MapViewMeshBuilderPrimitives.ancient_oak_wood_mesh() is ArrayMesh)
	assert_true(MapViewMeshBuilderPrimitives.ancient_oak_canopy_mesh() is ArrayMesh)
	assert_true(MapViewMeshBuilderPrimitives.ancient_oak_moss_mesh() is ArrayMesh)
	assert_true(
		MapViewMeshBuilderPrimitives.ancient_oak_wood_mesh()
		== MapViewMeshBuilderPrimitives.ancient_oak_wood_mesh(),
		"ancient oak wood mesh must be cached"
	)

	var prop := {
		"id": &"ancient_oak",
		"kind": MapTypes.PROP_KIND_TREE,
		"position": Vector2(64, 64),
		"primitive": &"ancient_tree",
		"style_variant": &"tree.oak",
	}
	var node := MapViewMeshBuilderProps.build_prop(prop, MapTypes.DEFAULT_CELL_SIZE)
	assert_eq(node.get_meta(&"tree_model"), &"ancient_oak")
	assert_eq(node.get_meta(&"tree_species"), MapViewTreeSpecies.SPECIES_OAK)
	assert_true(node.has_node("Trunk"))
	assert_true(node.has_node("Canopy"))
	assert_true(node.has_node("Moss"))
	assert_true((node.get_node("Trunk") as MeshInstance3D).mesh == MapViewMeshBuilderPrimitives.ancient_oak_wood_mesh())
	node.free()


func test_tree_line_building_places_oak_row_instead_of_house() -> void:
	var building := {
		"id": &"oak_ring_north",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"primitive": &"tree_line",
		"footprint": Rect2(0, 0, 704, 32),
		"wall_height": 62.0,
	}
	var node := MapViewMeshBuilderBuildings.build_building(building, MapTypes.DEFAULT_CELL_SIZE)
	assert_true(node.get_meta(&"tree_line"), "tree_line must skip house walls/roof")
	assert_false(node.has_node("Walls"), "tree_line must not emit masonry walls")
	assert_false(node.has_node("Roof"), "tree_line must not emit a roof")
	var oak_count := 0
	for child in node.get_children():
		if String(child.name).begins_with("Oak"):
			oak_count += 1
			assert_eq(child.get_meta(&"tree_species"), MapViewTreeSpecies.SPECIES_OAK)
			assert_true(child.has_node("Trunk"))
			assert_true(child.has_node("Canopy"))
	assert_true(oak_count >= 4, "oak ring needs multiple trunks along the footprint")
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
