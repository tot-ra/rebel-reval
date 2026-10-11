extends "res://tests/godot/test_case.gd"

const BushSpecies := preload("res://scripts/map/view3d/map_view_bush_species.gd")
const AssetShowcaseDefinitionScript := preload("res://scenes/debug/asset_showcase_definition.gd")


func test_bush_catalog_has_twenty_species() -> void:
	assert_eq(BushSpecies.ALL_SPECIES.size(), 20)
	var archetypes: Dictionary = {}
	var groups: Dictionary = {}
	for species in BushSpecies.ALL_SPECIES:
		assert_true(BushSpecies.is_known_species(species), String(species))
		var profile := BushSpecies.profile_for(species)
		archetypes[profile["archetype"]] = true
		groups[profile["group"]] = true
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


func test_authored_bush_prop_has_no_3d_model() -> void:
	# The legacy procedural shrub mesh was removed; bush props build no model.
	var prop := {
		"id": &"yard.heather",
		"kind": MapTypes.PROP_KIND_BUSH,
		"position": Vector2(64, 64),
		"style_variant": &"bush.heather",
	}
	var node := MapViewMeshBuilderPropModels.build_prop(prop, MapTypes.DEFAULT_CELL_SIZE)
	assert_false(node.has_node("Bush"))
	assert_false(node.has_meta(&"bush_species"))
	node.free()


func test_district_scatter_emits_no_bushes() -> void:
	# Bush zones and dry limestone (juniper understory) used to scatter the
	# removed shrub mesh; now they emit no Bushes_* layer.
	var blueprint := MapBlueprint.new(
		&"bush_scatter_test", &"loc.bush_scatter_test", Vector2i(32, 24), MapTypes.TERRAIN_MEADOW
	)
	blueprint.player_spawn(&"spawn.main", Vector2i(1, 1))
	blueprint.define_style(&"bush.dense", {})
	blueprint.terrain_rect(
		&"scrub", MapTypes.TERRAIN_MEADOW, Rect2i(2, 2, 14, 14), 0, 10, &"bush.dense"
	)
	blueprint.terrain_rect(&"alvar", MapTypes.TERRAIN_STONE, Rect2i(18, 4, 10, 10), 0, 10)
	var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	assert_true(result.is_ok(), "bush scatter map must compile: %s" % str(result.errors))
	if not result.is_ok():
		return
	var grid := MapBuilder.build(result.definition)
	var state := MapViewMeshBuilderScatter.begin_scatter(result.definition, grid)
	MapViewMeshBuilderScatter.collect_rows(state, grid.size_cells.y)
	assert_false(state.has("bush_batches"))
	MapViewMeshBuilderScatter.emit_layers(state)
	var root: Node3D = state["root"]
	assert_true(root.get_child_count() > 0, "the scrub zone still grows grass")
	for child in root.get_children():
		assert_false(String(child.name).begins_with("Bushes_"), String(child.name))
	root.free()


func test_asset_showcase_has_no_bush_prop() -> void:
	assert_false(
		MapTypes.PROP_KIND_BUSH in AssetShowcaseDefinitionScript.small_prop_kinds()
	)
