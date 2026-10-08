class_name FootstepAudio
extends Node

## Plays one catalog footstep per foot-contact event (ADR 0035 phase 2).
## MapViewRuntimeActors already consumes animation foot plants for mud prints;
## this node turns the same event into sound, so cadence comes from the rig and
## never from a timer inside the clip.
##
## Surface comes from the live terrain grid, gait from logic speed. When the
## catalog has no pool for a surface yet, SurfaceResolver's fallback chain picks
## an audible stand-in; adding the real entry retires the stand-in with no code
## change.

const SfxPlayerScript := preload("res://scripts/audio/sfx_player.gd")

var _definition: MapDefinition
var _grid: MapTerrainGrid
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
	_sfx.setup(_catalog, hash("footsteps"))


func configure(map_definition: MapDefinition, terrain_grid: MapTerrainGrid) -> void:
	_definition = map_definition
	_grid = terrain_grid


## Override seam for tests, which must not depend on the shipped catalog when
## they assert surface-to-ID mapping.
func set_catalog(catalog: SfxCatalog) -> void:
	_catalog = catalog
	if _sfx != null:
		_sfx.setup(catalog, hash("footsteps"))


func set_audio_enabled(enabled: bool) -> void:
	_audio_enabled = enabled


## Called on every animation foot plant with the planted foot's 3D position, in
## the same map-local space MapView3D.add_mud_footprint_at() uses. Terrain is
## sampled under the foot, not under the actor pivot, so a boot crossing a mud
## boundary sounds wet only where the sole actually lands.
func on_foot_plant(foot_world_position: Vector3, speed: float) -> StringName:
	if not _audio_enabled or _sfx == null or _definition == null:
		return &""
	var logic_position := MapViewBridge.world_to_logic(foot_world_position, _definition.cell_size)
	var surface := SurfaceResolver.surface_at_logic_position(
		_grid, _definition.cell_size, logic_position
	)
	_last_surface = surface
	if String(surface).is_empty():
		return &""
	var gait := SurfaceResolver.gait_for_speed(speed)
	var sound_id := SurfaceResolver.resolve_footstep_sound_id(_catalog, surface, gait)
	if String(sound_id).is_empty():
		return &""
	if _sfx.play(sound_id, foot_world_position) == null:
		return &""
	_played_count += 1
	_last_sound_id = sound_id
	return sound_id


## Test and debug-overlay accessors.
func played_count() -> int:
	return _played_count


func last_sound_id() -> StringName:
	return _last_sound_id


func last_surface() -> StringName:
	return _last_surface
