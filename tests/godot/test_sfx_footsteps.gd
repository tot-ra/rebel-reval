extends "res://tests/godot/test_case.gd"

## FootstepAudio turns animation foot plants into catalog voices (ADR 0035
## phase 2). Surface comes from the terrain under the planted foot.

const FootstepAudioScript := preload("res://scripts/audio/footstep_audio.gd")
const CELL_SIZE := 32


func _catalog() -> SfxCatalog:
	var catalog := SfxCatalog.new()
	catalog.load_dictionary(
		{
			"entries":
			[
				{
					"id": "sfx.footstep.wood.walk",
					"bus": "Footsteps",
					"streams": ["res://sounds/walk_wood.mp3"],
					"spatial": "3d",
				},
				{
					"id": "sfx.footstep.dirt.walk",
					"bus": "Footsteps",
					"streams": ["res://sounds/walking_on_mud_stable_audio_3.mp3"],
					"spatial": "3d",
				},
			]
		}
	)
	return catalog


## Cells left to right: timber floor, grass, deep water.
func _install() -> FootstepAudio:
	var grid := MapTerrainGrid.new()
	grid.initialize_chunks(Vector2i(3, 1), CELL_SIZE, 11)
	grid.set_terrain(Vector2i(0, 0), MapTypes.TERRAIN_TIMBER_FLOOR)
	grid.set_terrain(Vector2i(1, 0), MapTypes.TERRAIN_GRASS)
	grid.set_terrain(Vector2i(2, 0), MapTypes.TERRAIN_DEEP_WATER)
	var definition := MapDefinition.new()
	definition.cell_size = CELL_SIZE
	var footsteps: FootstepAudio = FootstepAudioScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(footsteps)
	footsteps.set_catalog(_catalog())
	footsteps.configure(definition, grid)
	return footsteps


func _foot_in_cell(cell_x: int) -> Vector3:
	return MapViewBridge.cell_center_to_world(Vector2i(cell_x, 0), CELL_SIZE)


func test_foot_plant_picks_the_surface_under_the_foot() -> void:
	var footsteps := _install()
	assert_eq(footsteps.on_foot_plant(_foot_in_cell(0), 60.0), &"sfx.footstep.wood.walk")
	assert_eq(footsteps.last_surface(), SurfaceResolver.SURFACE_WOOD)
	# Grass has no pool yet, so the documented dirt stand-in plays.
	assert_eq(footsteps.on_foot_plant(_foot_in_cell(1), 60.0), &"sfx.footstep.dirt.walk")
	assert_eq(footsteps.last_surface(), SurfaceResolver.SURFACE_GRASS)
	assert_eq(footsteps.played_count(), 2)
	footsteps.queue_free()


func test_deep_water_and_off_grid_plants_are_silent() -> void:
	var footsteps := _install()
	assert_eq(footsteps.on_foot_plant(_foot_in_cell(2), 60.0), &"")
	assert_eq(footsteps.on_foot_plant(_foot_in_cell(9), 60.0), &"")
	assert_eq(footsteps.played_count(), 0)
	footsteps.queue_free()


func test_disabled_audio_plays_nothing() -> void:
	var footsteps := _install()
	footsteps.set_audio_enabled(false)
	assert_eq(footsteps.on_foot_plant(_foot_in_cell(0), 60.0), &"")
	assert_eq(footsteps.played_count(), 0)
	footsteps.set_audio_enabled(true)
	assert_ne(footsteps.on_foot_plant(_foot_in_cell(0), 60.0), &"")
	footsteps.queue_free()


func test_unconfigured_controller_is_silent() -> void:
	var footsteps: FootstepAudio = FootstepAudioScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(footsteps)
	assert_eq(footsteps.on_foot_plant(Vector3.ZERO, 60.0), &"")
	footsteps.queue_free()
