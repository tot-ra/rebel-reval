extends "res://tests/godot/test_case.gd"

## R-1322 (VEGR-3): ecology-driven vegetation placement.

const ROAD := Rect2i(0, 18, 64, 2)
const SPRUCE_WOOD := Rect2i(2, 2, 20, 12)
const WATER := Rect2i(40, 26, 14, 8)
const LIMESTONE := Rect2i(6, 28, 6, 6)
const HOUSE := Rect2i(30, 4, 6, 5)
const FIELD := Rect2i(44, 4, 10, 8)
const WELL := Vector2i(20, 30)
const CLEARED := Rect2i(24, 30, 8, 6)


func _blueprint() -> MapBlueprint:
	var blueprint := MapBlueprint.new(
		&"ecology_test", &"loc.ecology_test", Vector2i(64, 40), MapTypes.TERRAIN_MEADOW
	)
	blueprint.player_spawn(&"spawn.main", Vector2i(2, 20))
	blueprint.define_style(&"tree.spruce", {})
	blueprint.terrain_rect(&"road.main", MapTypes.TERRAIN_DIRT, ROAD, 0, 20)
	blueprint.terrain_rect(
		&"wood.spruce", MapTypes.TERRAIN_FOREST_FLOOR, SPRUCE_WOOD, 0, 10, &"tree.spruce"
	)
	blueprint.terrain_rect(&"pond", MapTypes.TERRAIN_WATER, WATER, 0, 10)
	blueprint.terrain_rect(&"alvar", MapTypes.TERRAIN_STONE, LIMESTONE, 0, 10)
	blueprint.terrain_rect(&"field.rye", MapTypes.TERRAIN_FARM_SOIL, FIELD, 0, 10)
	blueprint.structure_rect(&"house.farm", MapTypes.BUILDING_KIND_HOUSE, HOUSE)
	blueprint.prop(&"prop.well", MapTypes.PROP_KIND_WELL, WELL)
	blueprint.vegetation_mask(&"mask.cleared", CLEARED, VegetationEcology.LAYER_ALL, 0.0)
	return blueprint


func _definition() -> MapDefinition:
	var result := MapBlueprintCompiler.compile_with_diagnostics(_blueprint())
	assert_true(result.is_ok(), "ecology test map must compile: %s" % str(result.errors))
	return result.definition


func _whole(definition: MapDefinition, grid: MapTerrainGrid) -> VegetationEcology:
	return VegetationEcology.for_region(definition, grid, Rect2i(Vector2i.ZERO, grid.size_cells))


func _each_cell(grid: MapTerrainGrid) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			cells.append(Vector2i(x, y))
	return cells


func test_same_seed_gives_identical_density_and_species_at_any_chunk_split() -> void:
	var definition := _definition()
	var grid := MapBuilder.build(definition)
	var whole := _whole(definition, grid)
	var again := _whole(_definition(), MapBuilder.build(_definition()))
	var chunks: Array[VegetationEcology] = []
	for origin: Vector2i in [Vector2i(0, 0), Vector2i(32, 0), Vector2i(0, 20), Vector2i(32, 20)]:
		chunks.append(VegetationEcology.for_region(definition, grid, Rect2i(origin, Vector2i(32, 20))))
	for cell in _each_cell(grid):
		var chunk := chunks[int(cell.x >= 32) + 2 * int(cell.y >= 20)]
		for layer in VegetationEcology.LAYERS:
			var value := whole.density(layer, cell)
			assert_eq(again.density(layer, cell), value, "same seed must repeat %s at %s" % [layer, cell])
			assert_eq(chunk.density(layer, cell), value, "chunk split changed %s at %s" % [layer, cell])
		assert_eq(chunk.understory(cell), whole.understory(cell), "understory at %s" % cell)
	# A different seed moves the fertility patches.
	var other := MapBlueprintCompiler.compile(_blueprint_with_seed(77))
	var moved := 0
	var shifted := _whole(other, MapBuilder.build(other))
	for cell in _each_cell(grid):
		if not is_equal_approx(shifted.fertility(cell), whole.fertility(cell)):
			moved += 1
	assert_true(moved > 500, "fertility must follow the map seed")


func _blueprint_with_seed(seed_value: int) -> MapBlueprint:
	var blueprint := _blueprint()
	blueprint.map_seed = seed_value
	return blueprint


func test_nothing_grows_on_the_trodden_road() -> void:
	var definition := _definition()
	var grid := MapBuilder.build(definition)
	var ecology := _whole(definition, grid)
	for x in ROAD.size.x:
		for y in range(ROAD.position.y, ROAD.end.y):
			var cell := Vector2i(x, y)
			for layer in VegetationEcology.LAYERS:
				assert_eq(ecology.density(layer, cell), 0.0, "%s on road %s" % [layer, cell])
			assert_eq(ecology.understory(cell)["kind"], VegetationEcology.UNDERSTORY_NONE)
	# The verge is trampled thinner than the open meadow.
	var verge := ecology.density(VegetationEcology.LAYER_GRASS, Vector2i(30, 17))
	var open := ecology.density(VegetationEcology.LAYER_GRASS, Vector2i(30, 14))
	assert_true(verge < open, "verge %s must be thinner than meadow %s" % [verge, open])
	# And the real scatter pass places no tuft, plant or tree on a road cell.
	for point in _scatter_points(definition, grid):
		assert_false(ROAD.has_point(point), "scatter on the road at %s" % point)


func test_fern_and_moss_only_under_conifer_shade() -> void:
	var definition := _definition()
	var grid := MapBuilder.build(definition)
	var ecology := _whole(definition, grid)
	var ferns := 0
	for cell in _each_cell(grid):
		var kind: StringName = ecology.understory(cell)["kind"]
		if kind in [VegetationEcology.UNDERSTORY_FERN, VegetationEcology.UNDERSTORY_MOSS]:
			assert_true(
				ecology.conifer_shade(cell) >= VegetationEcology.FERN_CONIFER_SHADE,
				"%s outside conifer shade at %s" % [kind, cell]
			)
			ferns += int(kind == VegetationEcology.UNDERSTORY_FERN)
	assert_true(ferns > 20, "the spruce wood must carry a fern floor (%d)" % ferns)
	assert_true(ecology.conifer_shade(Vector2i(10, 8)) > 0.9, "deep spruce wood is fully shaded")
	assert_eq(ecology.conifer_shade(Vector2i(30, 30)), 0.0, "open meadow has no conifer shade")


func test_juniper_takes_dry_limestone_only() -> void:
	var definition := _definition()
	var grid := MapBuilder.build(definition)
	var ecology := _whole(definition, grid)
	var junipers := 0
	for cell in _each_cell(grid):
		if ecology.understory(cell)["kind"] != VegetationEcology.UNDERSTORY_JUNIPER:
			continue
		junipers += 1
		assert_true(ecology.is_dry_limestone(cell), "juniper off dry limestone at %s" % cell)
		assert_true(ecology.stone_distance(cell) <= VegetationEcology.JUNIPER_STONE_REACH)
		assert_true(ecology.water_distance(cell) >= VegetationEcology.JUNIPER_DRY_WATER)
	assert_true(junipers > 8, "the alvar rim must carry juniper (%d)" % junipers)


func test_nettle_and_sedge_stay_at_walls_and_water() -> void:
	var definition := _definition()
	var grid := MapBuilder.build(definition)
	var ecology := _whole(definition, grid)
	var nettles := 0
	var sedges := 0
	for cell in _each_cell(grid):
		var kind: StringName = ecology.understory(cell)["kind"]
		if kind == VegetationEcology.UNDERSTORY_NETTLE:
			nettles += 1
			assert_true(
				ecology.wall_distance(cell) <= VegetationEcology.NETTLE_REACH
				or ecology.water_distance(cell) <= VegetationEcology.NETTLE_REACH + 1,
				"nettle away from wall and water at %s" % cell
			)
		elif kind == VegetationEcology.UNDERSTORY_SEDGE:
			sedges += 1
			assert_true(ecology.water_distance(cell) <= VegetationEcology.SEDGE_REACH)
	assert_true(nettles > 10, "the house foot must carry nettles (%d)" % nettles)
	assert_true(sedges > 10, "the pond bank must carry sedge (%d)" % sedges)


func test_field_weeds_only_on_field_margins() -> void:
	var definition := _definition()
	var grid := MapBuilder.build(definition)
	var ecology := _whole(definition, grid)
	var weeds := 0
	for cell in _each_cell(grid):
		if ecology.understory(cell)["kind"] == VegetationEcology.UNDERSTORY_FIELD_WEED:
			weeds += 1
			assert_true(ecology.is_field_margin(cell), "field weed off the margin at %s" % cell)
			assert_false(FIELD.has_point(cell), "weeds belong to the margin, not the crop")
	assert_true(weeds > 10, "the rye field needs a weed margin (%d)" % weeds)


func test_authored_props_and_masks_override_ecology() -> void:
	var definition := _definition()
	var grid := MapBuilder.build(definition)
	var ecology := _whole(definition, grid)
	for y in range(CLEARED.position.y, CLEARED.end.y):
		for x in range(CLEARED.position.x, CLEARED.end.x):
			var cell := Vector2i(x, y)
			for layer in VegetationEcology.LAYERS:
				assert_eq(ecology.density(layer, cell), 0.0, "mask must clear %s at %s" % [layer, cell])
			assert_eq(float(ecology.understory(cell)["chance"]), 0.0)
	var points := _scatter_points(definition, grid)
	for point in points:
		assert_false(CLEARED.has_point(point), "scatter inside the cleared mask at %s" % point)
		assert_false(point == WELL, "scatter through the authored well at %s" % point)
		assert_false(HOUSE.has_point(point), "scatter inside the house at %s" % point)
	assert_true(points.size() > 200, "the test map must still be planted (%d)" % points.size())


func test_mask_compiles_into_definition_and_round_trips_rrmap() -> void:
	var definition := _definition()
	assert_eq(definition.vegetation_masks.size(), 1)
	var mask := definition.vegetation_masks[0]
	assert_eq(mask["id"], &"mask.cleared")
	assert_eq(mask["rect"], CLEARED)
	assert_eq(mask["layer"], VegetationEcology.LAYER_ALL)
	assert_eq(mask["density"], 0.0)
	assert_true(definition.validate().is_empty(), str(definition.validate()))
	# The mask is map data: it changes the fingerprint; its absence does not.
	var unmasked := _blueprint()
	unmasked.primitives = unmasked.primitives.filter(
		func(primitive: Dictionary) -> bool: return primitive["primitive"] != &"vegetation_mask"
	)
	assert_ne(MapBlueprintCompiler.compile(unmasked).fingerprint, definition.fingerprint)
	var source := MapRrmapSerializer.canonical_print(_blueprint())
	assert_true(source.contains("vegetation_mask mask.cleared 24 30 8 6 layer=all density=0"), source)
	var parsed := MapRrmapParser.parse(source)
	assert_true(parsed.is_ok(), str(parsed.diagnostics))
	assert_eq(MapBlueprintCompiler.compile(parsed.blueprint).fingerprint, definition.fingerprint)


func test_invalid_masks_are_rejected() -> void:
	var blueprint := _blueprint()
	blueprint.vegetation_mask(&"mask.bad_layer", Rect2i(1, 1, 2, 2), &"lichen", 1.0)
	blueprint.vegetation_mask(
		&"mask.too_dense", Rect2i(1, 1, 2, 2), VegetationEcology.LAYER_GRASS, 9.0
	)
	var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	assert_false(result.is_ok(), "unknown layer and excessive density must fail")
	var text := str(result.errors)
	assert_true(text.contains("layer is unknown"), text)
	assert_true(text.contains("density must be within"), text)


## World-cell positions of every scatter instance collected for the whole map,
## read from the CPU-side arrays (the headless renderer drops MultiMesh data).
func _scatter_points(definition: MapDefinition, grid: MapTerrainGrid) -> Array[Vector2i]:
	var state := MapViewMeshBuilderScatter.begin_scatter(definition, grid)
	MapViewMeshBuilderScatter.collect_rows(state, grid.size_cells.y)
	var transforms: Array = []
	for key: String in ["small_grass", "large_grass", "clovers", "reeds"]:
		transforms.append_array(state[key])
	for batches_key: String in ["plant_batches", "bush_batches"]:
		for batch: Dictionary in (state[batches_key] as Dictionary).values():
			transforms.append_array(batch["transforms"])
	for batch: Variant in (state["tree_batches"] as Dictionary).values():
		if batch is Dictionary and (batch as Dictionary).has("transforms"):
			transforms.append_array(batch["transforms"])
	var points: Array[Vector2i] = []
	for transform: Transform3D in transforms:
		points.append(Vector2i(floori(transform.origin.x), floori(transform.origin.z)))
	(state["root"] as Node).free()
	return points
