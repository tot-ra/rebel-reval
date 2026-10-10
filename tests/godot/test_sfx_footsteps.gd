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
					"id": "sfx.footstep.grass.walk",
					"bus": "Footsteps",
					"streams": ["res://sounds/footsteps/grass_step_01.mp3"],
					"spatial": "3d",
				},
			]
		}
	)
	return catalog


## Cells left to right: timber floor, grass, deep water, cobblestone.
func _install() -> FootstepAudio:
	var grid := MapTerrainGrid.new()
	grid.initialize_chunks(Vector2i(4, 1), CELL_SIZE, 11)
	grid.set_terrain(Vector2i(0, 0), MapTypes.TERRAIN_TIMBER_FLOOR)
	grid.set_terrain(Vector2i(1, 0), MapTypes.TERRAIN_GRASS)
	grid.set_terrain(Vector2i(2, 0), MapTypes.TERRAIN_DEEP_WATER)
	grid.set_terrain(Vector2i(3, 0), MapTypes.TERRAIN_COBBLESTONE)
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
	assert_eq(footsteps.on_foot_plant(_foot_in_cell(1), 60.0), &"sfx.footstep.grass.walk")
	assert_eq(footsteps.last_surface(), SurfaceResolver.SURFACE_GRASS)
	assert_eq(footsteps.played_count(), 2)
	footsteps.queue_free()


func test_deep_water_and_off_grid_plants_are_silent() -> void:
	var footsteps := _install()
	assert_eq(footsteps.on_foot_plant(_foot_in_cell(2), 60.0), &"")
	assert_eq(footsteps.on_foot_plant(_foot_in_cell(9), 60.0), &"")
	assert_eq(footsteps.played_count(), 0)
	footsteps.queue_free()


## R-1383: a surface the catalog does not cover must go quiet, not borrow the
## wood or mud pool. The fixture has no stone entry, so the cobbles are silent
## even though the surface itself is recognised.
func test_uncovered_surface_is_silent_not_substituted() -> void:
	var footsteps := _install()
	assert_eq(footsteps.on_foot_plant(_foot_in_cell(3), 60.0), &"")
	assert_eq(footsteps.last_surface(), SurfaceResolver.SURFACE_STONE)
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


## The map view answers the surface on every map (R-1641): a bound provider
## wins over the grid, which is how the seamless city, with no grid at all,
## gets its steps.
func test_surface_provider_overrides_the_grid() -> void:
	var footsteps := _install()
	var definition := MapDefinition.new()
	definition.cell_size = CELL_SIZE
	footsteps.configure(
		definition, null, func(_foot: Vector3) -> StringName: return SurfaceResolver.SURFACE_GRASS
	)
	assert_eq(footsteps.on_foot_plant(_foot_in_cell(0), 60.0), &"sfx.footstep.grass.walk")
	assert_eq(footsteps.last_surface(), SurfaceResolver.SURFACE_GRASS)
	footsteps.queue_free()


## NPC steps play on their own instance, lowered by volume_offset_db, and at
## the global sound position when one is given.
func test_volume_offset_and_sound_position_apply_to_the_voice() -> void:
	var footsteps := _install()
	footsteps.volume_offset_db = -5.0
	var sound_at := Vector3(100.0, 2.0, -40.0)
	assert_eq(
		footsteps.on_foot_plant(_foot_in_cell(0), 60.0, sound_at), &"sfx.footstep.wood.walk"
	)
	var voice: AudioStreamPlayer3D = null
	for child in footsteps.find_children("*", "AudioStreamPlayer3D", true, false):
		voice = child as AudioStreamPlayer3D
	assert_true(voice != null, "a 3D voice must play")
	if voice != null:
		assert_true(voice.volume_db <= -4.0, "the NPC offset must lower the voice")
		assert_eq(voice.position, sound_at)
	footsteps.queue_free()
