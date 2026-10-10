class_name FootstepAudio
extends Node

## Plays one catalog footstep per foot-contact event (ADR 0035 phase 2).
## MapViewRuntimeActors already consumes animation foot plants for mud prints;
## this node turns the same event into sound, so cadence comes from the rig and
## never from a timer inside the clip.
##
## Surface comes from the map view (MapView3D.footstep_surface_at: terrain grid
## plus visible puddles on district maps, CitySurfaceSampler in the seamless
## city), or from the terrain grid alone when no view is bound (tests). Gait
## comes from logic speed. A surface without a catalog pool stays silent.
##
## One instance serves the player and a second one, with its own voice budget
## and a lower level, serves every walking NPC near the listener (R-1641), so a
## crowd can never steal the player's own steps.

const SfxPlayerScript := preload("res://scripts/audio/sfx_player.gd")

## Added to every voice; NPC steps sit under the player's own.
var volume_offset_db := 0.0
## Seeds the variation RNG; a second instance must not mirror the first.
var rng_label := "footsteps"

var _definition: MapDefinition
var _grid: MapTerrainGrid
## Callable(foot_position: Vector3) -> StringName; overrides the grid lookup.
var _surface_provider: Callable
var _sfx: SfxPlayer
var _catalog: SfxCatalog
var _audio_enabled := true
var _played_count := 0
var _last_sound_id := &""
var _last_surface := &""


func _ready() -> void:
	_catalog = SfxCatalog.load_default()
	_sfx = SfxPlayerScript.new()
	_sfx.name = "FootstepSfxPlayer"
	add_child(_sfx)
	# Footsteps follow the player, so a fixed session seed keeps a replay of the
	# same walk audibly identical without affecting game state.
	_sfx.setup(_catalog, hash(rng_label))


func configure(
	map_definition: MapDefinition,
	terrain_grid: MapTerrainGrid,
	surface_provider: Callable = Callable()
) -> void:
	_definition = map_definition
	_grid = terrain_grid
	_surface_provider = surface_provider


## Override seam for tests, which must not depend on the shipped catalog when
## they assert surface-to-ID mapping.
func set_catalog(catalog: SfxCatalog) -> void:
	_catalog = catalog
	if _sfx != null:
		_sfx.setup(catalog, hash(rng_label))


func set_audio_enabled(enabled: bool) -> void:
	_audio_enabled = enabled


## Called on every animation foot plant with the planted foot's 3D position, in
## the same map-local space MapView3D.add_mud_footprint_at() uses. Terrain is
## sampled under the foot, not under the actor pivot, so a boot crossing a mud
## boundary sounds wet only where the sole actually lands. `sound_position` is
## the global point the voice plays at when it differs from the map-local foot
## (a streamed location offset from the world origin); the voice is top-level,
## so a map-local position there would place it beside the wrong map.
func on_foot_plant(
	foot_world_position: Vector3, speed: float, sound_position: Variant = null
) -> StringName:
	if not _audio_enabled or _sfx == null or _definition == null:
		return &""
	var surface := surface_under(foot_world_position)
	_last_surface = surface
	if String(surface).is_empty():
		return &""
	var gait := SurfaceResolver.gait_for_speed(speed)
	var sound_id := SurfaceResolver.resolve_footstep_sound_id(_catalog, surface, gait)
	if String(sound_id).is_empty():
		return &""
	var voice := _sfx.play(
		sound_id, sound_position if sound_position is Vector3 else foot_world_position
	)
	if voice == null:
		return &""
	if not is_zero_approx(volume_offset_db):
		voice.set(&"volume_db", float(voice.get(&"volume_db")) + volume_offset_db)
	_played_count += 1
	_last_sound_id = sound_id
	return sound_id


func surface_under(foot_world_position: Vector3) -> StringName:
	if _surface_provider.is_valid():
		return StringName(_surface_provider.call(foot_world_position))
	var logic_position := MapViewBridge.world_to_logic(foot_world_position, _definition.cell_size)
	return SurfaceResolver.surface_at_logic_position(_grid, _definition.cell_size, logic_position)


## Test and debug-overlay accessors.
func played_count() -> int:
	return _played_count


func last_sound_id() -> StringName:
	return _last_sound_id


func last_surface() -> StringName:
	return _last_surface
