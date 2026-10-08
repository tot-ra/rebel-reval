extends "res://tests/godot/test_case.gd"

## SurfaceResolver mapping and the catalog fallback chain (ADR 0035 phase 2).


func _grid(terrains: Array) -> MapTerrainGrid:
	var grid := MapTerrainGrid.new()
	grid.initialize_chunks(Vector2i(terrains.size(), 1), 32, 7)
	for index in terrains.size():
		grid.set_terrain(Vector2i(index, 0), terrains[index])
	return grid


func test_every_terrain_maps_to_a_known_surface() -> void:
	for terrain: StringName in MapTypes.ALL_TERRAINS:
		var surface := SurfaceResolver.surface_for_terrain(terrain)
		if terrain == MapTypes.TERRAIN_DEEP_WATER:
			assert_eq(surface, &"", "deep water must stay silent; the swimmer owns it")
			continue
		assert_array_contains(
			SurfaceResolver.SURFACES, surface, "terrain %s has no surface" % terrain
		)


func test_unknown_terrain_is_silent_rather_than_guessed() -> void:
	assert_eq(SurfaceResolver.surface_for_terrain(&"obsidian"), &"")
	assert_eq(SurfaceResolver.surface_for_terrain(&""), &"")


func test_surface_families_fold_as_documented() -> void:
	assert_eq(
		SurfaceResolver.surface_for_terrain(MapTypes.TERRAIN_TIMBER_FLOOR),
		SurfaceResolver.SURFACE_WOOD
	)
	assert_eq(
		SurfaceResolver.surface_for_terrain(MapTypes.TERRAIN_COBBLESTONE),
		SurfaceResolver.SURFACE_STONE
	)
	assert_eq(
		SurfaceResolver.surface_for_terrain(MapTypes.TERRAIN_MUD), SurfaceResolver.SURFACE_DIRT
	)
	assert_eq(
		SurfaceResolver.surface_for_terrain(MapTypes.TERRAIN_HAY), SurfaceResolver.SURFACE_GRASS
	)
	assert_eq(
		SurfaceResolver.surface_for_terrain(MapTypes.TERRAIN_COAST_SAND),
		SurfaceResolver.SURFACE_GRAVEL
	)
	assert_eq(
		SurfaceResolver.surface_for_terrain(MapTypes.TERRAIN_SHALLOW_WATER),
		SurfaceResolver.SURFACE_WATER_SHALLOW
	)


func test_logic_position_samples_the_cell_under_the_foot() -> void:
	var grid := _grid([MapTypes.TERRAIN_TIMBER_FLOOR, MapTypes.TERRAIN_MUD])
	assert_eq(
		SurfaceResolver.surface_at_logic_position(grid, 32, Vector2(4.0, 10.0)),
		SurfaceResolver.SURFACE_WOOD
	)
	assert_eq(
		SurfaceResolver.surface_at_logic_position(grid, 32, Vector2(40.0, 10.0)),
		SurfaceResolver.SURFACE_DIRT
	)
	# Outside the grid and a missing grid must not invent a surface.
	assert_eq(SurfaceResolver.surface_at_logic_position(grid, 32, Vector2(-8.0, 0.0)), &"")
	assert_eq(SurfaceResolver.surface_at_logic_position(null, 32, Vector2.ZERO), &"")
	assert_eq(SurfaceResolver.surface_at_logic_position(grid, 0, Vector2.ZERO), &"")


func test_gait_follows_logic_speed() -> void:
	assert_eq(SurfaceResolver.gait_for_speed(40.0), SurfaceResolver.GAIT_WALK)
	assert_eq(
		SurfaceResolver.gait_for_speed(SurfaceResolver.RUN_SPEED_THRESHOLD + 1.0),
		SurfaceResolver.GAIT_RUN
	)


func test_fallback_chain_prefers_the_exact_entry() -> void:
	var catalog := SfxCatalog.new()
	catalog.load_dictionary(
		{
			"entries":
			[
				{
					"id": "sfx.footstep.stone.run",
					"bus": "Footsteps",
					"streams": ["res://sounds/door.mp3"],
				},
				{
					"id": "sfx.footstep.wood.walk",
					"bus": "Footsteps",
					"streams": ["res://sounds/walk_wood.mp3"],
				},
			]
		}
	)
	assert_eq(
		SurfaceResolver.resolve_footstep_sound_id(
			catalog, SurfaceResolver.SURFACE_STONE, SurfaceResolver.GAIT_RUN
		),
		&"sfx.footstep.stone.run",
		"an exact surface and gait entry must win over any stand-in"
	)
	assert_eq(
		SurfaceResolver.resolve_footstep_sound_id(
			catalog, SurfaceResolver.SURFACE_STONE, SurfaceResolver.GAIT_WALK
		),
		&"",
		"stone must stay silent rather than borrow the wood pool"
	)
	assert_eq(
		SurfaceResolver.resolve_footstep_sound_id(
			catalog, SurfaceResolver.SURFACE_WOOD, SurfaceResolver.GAIT_RUN
		),
		&"sfx.footstep.wood.walk",
		"a missing gait falls back to the same surface at a walk"
	)
	assert_eq(
		SurfaceResolver.resolve_footstep_sound_id(catalog, SurfaceResolver.SURFACE_GRASS),
		&"",
		"grass has no entry and no reachable fallback in this fixture"
	)
	assert_eq(SurfaceResolver.resolve_footstep_sound_id(catalog, &""), &"")
	assert_eq(SurfaceResolver.resolve_footstep_sound_id(null, SurfaceResolver.SURFACE_WOOD), &"")


## A stand-in may only name the same material. R-1382 chained stone and sand
## onto the wood pool and grass onto the mud pool, so world_saaremaa knocked
## like a plank on its beaches and squelched like a swamp on its meadows.
func test_stand_ins_never_name_another_material() -> void:
	# dirt is the one documented fold: the first cut puts mud and dirt on one
	# surface, so the mud pool is dirt's own pool.
	var allowed: Dictionary = {SurfaceResolver.SURFACE_DIRT: [SurfaceResolver.VOCABULARY_MUD]}
	for surface: StringName in SurfaceResolver.SURFACES:
		var chain: Array = SurfaceResolver.SURFACE_FALLBACKS.get(surface, [])
		assert_eq(
			chain,
			allowed.get(surface, []),
			"surface %s must not borrow another material's pool" % surface
		)


## In the shipped catalog every surface must resolve to a pool of its own
## material. dirt is the one documented exception: the first cut folds mud and
## dirt together, so dirt plays the mud pool.
func test_shipped_catalog_resolves_each_surface_to_its_own_material() -> void:
	var catalog := SfxCatalog.load_default()
	for surface: StringName in SurfaceResolver.SURFACES:
		var expected := surface
		if surface == SurfaceResolver.SURFACE_DIRT:
			expected = SurfaceResolver.VOCABULARY_MUD
		assert_eq(
			SurfaceResolver.resolve_footstep_sound_id(catalog, surface),
			StringName("sfx.footstep.%s.walk" % expected),
			"%s must play its own pool" % surface
		)
