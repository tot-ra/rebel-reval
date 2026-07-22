extends "res://tests/godot/test_case.gd"


func test_concrete_plant_catalog_has_cached_distinct_meshes() -> void:
	assert_eq(MapViewPlantSpecies.ALL_SPECIES.size(), 30)
	assert_eq(MapViewPlantSpecies.ALL_VARIANTS.size(), 30)
	var archetypes: Dictionary = {}
	for species in MapViewPlantSpecies.ALL_SPECIES:
		assert_true(MapViewPlantSpecies.is_known_species(species), String(species))
		var profile := MapViewPlantSpecies.profile_for(species)
		archetypes[profile["archetype"]] = true
		var mesh := MapViewPlantMeshes.mesh_for(species)
		assert_true(mesh is ArrayMesh, "%s needs a procedural model" % species)
		assert_true(mesh.get_surface_count() > 0, "%s model must contain geometry" % species)
		assert_true(mesh == MapViewPlantMeshes.mesh_for(species), "%s model must be cached" % species)
	assert_true(archetypes.size() >= 10, "catalog needs visibly different botanical forms")


func test_concrete_plant_variants_are_valid_scatter_profiles() -> void:
	for variant in MapViewPlantSpecies.ALL_VARIANTS:
		assert_true(TerrainVegetation.is_known_variant(variant), String(variant))
		var parsed := MapViewPlantSpecies.parse_variant(variant)
		assert_true(parsed.has("species"), String(variant))
		var profile := TerrainVegetation.scatter_profile(variant)
		assert_eq(profile.get("plant_species"), parsed["species"])
		assert_true(float(profile.get("plant_chance", 0.0)) > 0.0)


func test_authored_locations_use_every_tree_and_plant_model() -> void:
	var paths := [
		"res://content/maps/archbishops_garden.rrmap",
		"res://content/maps/monastery_quarter.rrmap",
		"res://content/maps/reval_harbor_east.rrmap",
		"res://content/maps/reval_harbor_north.rrmap",
		"res://content/maps/viru_gate_foreland.rrmap",
	]
	var trees: Dictionary = {}
	var plants: Dictionary = {}
	for path in paths:
		var parsed = MapRrmapParser.parse_file(path)
		assert_true(parsed.is_ok(), "%s: %s" % [path, str(parsed.formatted_diagnostics())])
		if not parsed.is_ok():
			continue
		for zone in parsed.definition.zones:
			_collect_variant(zone.get("style_variant", &""), trees, plants)
		for prop in parsed.definition.props:
			_collect_variant(prop.get("style_variant", &""), trees, plants)
	for species in MapViewTreeSpecies.ALL_SPECIES:
		assert_true(trees.has(species), "tree.%s needs an authored location" % species)
	for species in MapViewPlantSpecies.ALL_SPECIES:
		assert_true(plants.has(species), "plant/crop %s needs an authored location" % species)


func _collect_variant(variant: StringName, trees: Dictionary, plants: Dictionary) -> void:
	var tree := MapViewTreeSpecies.parse_variant(variant)
	if tree.has("species"):
		trees[tree["species"]] = true
	var plant := MapViewPlantSpecies.parse_variant(variant)
	if plant.has("species"):
		plants[plant["species"]] = true
