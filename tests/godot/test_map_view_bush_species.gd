extends "res://tests/godot/test_case.gd"

const BushSpecies := preload("res://scripts/map/view3d/map_view_bush_species.gd")
const BushMeshes := preload("res://scripts/map/view3d/map_view_bush_meshes.gd")


func test_bush_catalog_has_twenty_cached_distinct_meshes() -> void:
	assert_eq(BushSpecies.ALL_SPECIES.size(), 20)
	var archetypes: Dictionary = {}
	var groups: Dictionary = {}
	for species in BushSpecies.ALL_SPECIES:
		assert_true(BushSpecies.is_known_species(species), String(species))
		var profile := BushSpecies.profile_for(species)
		archetypes[profile["archetype"]] = true
		groups[profile["group"]] = true
		var mesh := BushMeshes.mesh_for(species)
		assert_true(mesh is ArrayMesh, "%s needs a procedural model" % species)
		assert_true(mesh.get_surface_count() > 0, "%s model must contain geometry" % species)
		assert_true(mesh == BushMeshes.mesh_for(species), "%s model must be cached" % species)
		var stats := BushMeshes.geometry_stats(species)
		assert_true(int(stats.get("triangles", 0)) >= 24, "%s silhouette is under-modeled" % species)
	assert_true(archetypes.size() >= 5, "catalog needs visibly different shrub forms")
	assert_true(groups.size() >= 6, "catalog needs ecological group diversity")


func test_bush_variants_are_valid_scatter_profiles() -> void:
	for variant in BushSpecies.ALL_VARIANTS:
		assert_true(TerrainVegetation.is_known_variant(variant), String(variant))
		var parsed := BushSpecies.parse_variant(variant)
		assert_true(parsed.has("species"), String(variant))
		var profile := TerrainVegetation.scatter_profile(variant)
		assert_eq(profile.get("bush_species"), parsed["species"])
		assert_true(float(profile.get("bush_chance", 0.0)) > 0.0)
	assert_true(TerrainVegetation.is_known_variant(&"bush.dense"))
	assert_true(TerrainVegetation.is_known_variant(&"bush.scrub"))
	assert_true(TerrainVegetation.is_known_variant(&"bush.hedge"))
	var dense_profile := TerrainVegetation.scatter_profile(&"bush.dense")
	assert_true(float(dense_profile.get("bush_chance", 0.0)) > 0.0)


func test_legacy_dense_and_scrub_pools_resolve_species() -> void:
	var dense_species := BushSpecies.pick_species(BushSpecies.DENSE_WEIGHTS, 0.12)
	var scrub_species := BushSpecies.pick_species(BushSpecies.SCRUB_WEIGHTS, 0.88)
	assert_true(BushSpecies.is_known_species(dense_species))
	assert_true(BushSpecies.is_known_species(scrub_species))
	assert_ne(dense_species, scrub_species)


func test_authored_locations_use_every_bush_model() -> void:
	var paths := [
		"res://content/maps/archbishops_garden.rrmap",
		"res://content/maps/monastery_quarter.rrmap",
		"res://content/maps/reval_harbor_east.rrmap",
		"res://content/maps/reval_harbor_north.rrmap",
		"res://content/maps/viru_gate_foreland.rrmap",
		"res://content/maps/lower_town_slice.rrmap",
	]
	var bushes: Dictionary = {}
	for path in paths:
		var parsed = MapRrmapParser.parse_file(path)
		assert_true(parsed.is_ok(), "%s: %s" % [path, str(parsed.formatted_diagnostics())])
		if not parsed.is_ok():
			continue
		for zone in parsed.definition.zones:
			_collect_bush_variant(zone.get("style_variant", &""), bushes)
		for prop in parsed.definition.props:
			if prop.get("kind", &"") == MapTypes.PROP_KIND_BUSH:
				_collect_bush_variant(prop.get("style_variant", &""), bushes)
	for species in BushSpecies.ALL_SPECIES:
		assert_true(bushes.has(species), "bush.%s needs an authored location" % species)


func test_authored_bush_prop_builds_species_mesh() -> void:
	var prop := {
		"id": &"yard.heather",
		"kind": MapTypes.PROP_KIND_BUSH,
		"position": Vector2(64, 64),
		"style_variant": &"bush.heather",
	}
	var node := MapViewMeshBuilderPropModels.build_prop(prop, MapTypes.DEFAULT_CELL_SIZE)
	assert_eq(node.get_meta(&"bush_species"), BushSpecies.SPECIES_HEATHER)
	assert_true(node.has_node("Bush"))
	assert_true((node.get_node("Bush") as MeshInstance3D).mesh is ArrayMesh)
	node.free()


func _collect_bush_variant(variant: StringName, bushes: Dictionary) -> void:
	var parsed := BushSpecies.parse_variant(variant)
	if parsed.has("species"):
		bushes[parsed["species"]] = true
