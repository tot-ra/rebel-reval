class_name UnderwaterPass
extends Node3D

## WS-13 underwater view. Classifies the camera medium every frame (AIR, STRADDLE where the
## near plane cuts the surface, UNDER) and drives one screen quad (underwater_pass.gdshader)
## that draws the Beer-Lambert medium, submerged caustics, light shafts, the per-pixel
## waterline with its meniscus, and the wet lens after surfacing. It also muffles the world
## SFX bus with a low-pass while the camera is under water. Technique after Tidewater's
## underwater modules. Ported from Tidewater (MIT), see notice.code.tidewater.
##
## WS-13c: one-shot submerge/emerge cues on AIR<->UNDER crossings. Emerge waits until the
## low-pass has opened so the splash is not still sitting under the 700 Hz cutoff.
##
## Cost: in AIR, with no wet lens left, the quad is hidden, so the renderer skips it and
## update() does one water probe. Rendering only: no gameplay state, nothing is persisted.
##
## Dependencies not landed yet (see docs/tasks/water_sky/WS-13_underwater_view_pass.md):
## - WS-05 OceanFftSampler: the camera surface height is the rest plane plus tide. The
##   view's FFT geometry is compressed to millimetres (fft_geometry_scale), so the error is
##   far below the hysteresis band. The shader still draws the displaced per-pixel waterline.
## WS-13f: WS-07 caustic tiles are bound here and sampled in the pass shader.

signal cue_played(cue_id: StringName)

const AudioBusServiceScript := preload("res://scripts/settings/audio_bus_service.gd")
const WaterMaterials := preload("res://scripts/map/view3d/map_view_water_materials.gd")
const PASS_SHADER := preload("res://scripts/map/view3d/underwater_pass.gdshader")

const STATE_AIR := 0
const STATE_STRADDLE := 1
const STATE_UNDER := 2

## Draw after every other transparent material, in particular the water surface.
const RENDER_PRIORITY := 127
## Hysteresis as a share of the straddle band, with a floor for very small near planes.
const HYSTERESIS_FRACTION := 0.25
const HYSTERESIS_MIN := 0.0005
## Tidewater LensParams: drops bead and run down the lens for 2.5 s after surfacing.
const WET_LENS_SECONDS := 2.5
const SFX_BUS := &"SFX"
## Resource name of the AudioEffectLowPassFilter in audio/default_bus_layout.tres.
const LOWPASS_EFFECT_NAME := "UnderwaterLowPass"
const LOWPASS_CUTOFF_HZ := 700.0
const LOWPASS_OPEN_HZ := 20000.0
const LOWPASS_FADE_SECONDS := 0.15
const SHAFT_SAMPLES_BY_TIER := {&"minimum": 4, &"recommended": 8}
const CUE_SUBMERGE := &"submerge"
const CUE_EMERGE := &"emerge"
const SUBMERGE_STREAM := preload("res://sounds/water/submerge.mp3")
const EMERGE_STREAM := preload("res://sounds/water/emerge.mp3")
const EMERGE_UNFILTERED_MIX := 0.001
## Water material uniforms the pass mirrors from the material under the camera, so the
## shared FFT include and the underwater light match the surface exactly.
const MIRRORED_UNIFORMS: Array[StringName] = [
	&"choppiness",
	&"standing_wave_ratio",
	&"wind_direction",
	&"use_fft",
	&"fft_c0_disp",
	&"fft_c0_deriv",
	&"fft_c1_disp",
	&"fft_c1_deriv",
	&"fft_c2_deriv",
	&"fft_cascade",
	&"fft_disp_scale",
	&"fft_deriv_scale",
	&"ocean_amplitude",
	&"fft_cascade_count",
	&"fft_geometry_scale",
	&"shallow_color",
	&"deep_color",
	&"deep_bed_color",
	&"highlight_color",
	&"sun_reflection_color",
	&"sun_direction",
	&"day_blend",
	&"cloud_darken",
	&"caustics_fine_tex",
	&"caustics_broad_tex",
	&"caustic_min_pair_mean",
	&"caustic_full_quality",
	&"caustic_pattern_scale",
]

var state := STATE_AIR
## Seconds of wet lens left after surfacing; the quad stays visible while it runs.
var wet_lens_remaining := 0.0
## 0..1 blend of the SFX low-pass (1 = fully muffled).
var lowpass_mix := 0.0
## Returns {"surface_y": float, "wave_margin": float, "material": ShaderMaterial} for world XZ,
## or {} over dry land. wave_margin is the geometric crest height of the displaced surface.
var water_probe: Callable
var camera: Camera3D
var quality_tier: StringName = &"recommended"

## Test-visible cue log. One entry per AIR->UNDER or completed UNDER->AIR crossing.
var played_cues: Array[StringName] = []

var _material: ShaderMaterial
var _quad: MeshInstance3D
var _submerge_player: AudioStreamPlayer
var _emerge_player: AudioStreamPlayer
var _submerged_since_air := false
var _emerge_pending := false
var _lens_age := 0.0


## Interiors never show water from below; maps without water never need the pass.
static func should_create(indoor: bool, has_water: bool) -> bool:
	return not indoor and has_water


## Near-plane band in which the lens can cut the surface: two near half-heights.
static func straddle_band(view_camera: Camera3D) -> float:
	var half_height := view_camera.near * tan(deg_to_rad(view_camera.fov) * 0.5)
	return half_height * 2.0


## camera_depth = surface_y - camera_y (positive below the surface). The boundary that
## would leave `previous` moves `hysteresis` further out, so a camera bobbing on the
## threshold keeps its state instead of flickering between two. `crest` widens only the
## AIR side: crests rise above the rest plane, while troughs are floored just below it.
static func classify(
	depth: float, band: float, previous: int, hysteresis: float, crest: float = 0.0
) -> int:
	var air_boundary := -band - crest + (hysteresis if previous == STATE_AIR else -hysteresis)
	var under_boundary := band + (-hysteresis if previous == STATE_UNDER else hysteresis)
	if depth < air_boundary:
		return STATE_AIR
	if depth > under_boundary:
		return STATE_UNDER
	return STATE_STRADDLE


static func hysteresis_for_band(band: float) -> float:
	return maxf(band * HYSTERESIS_FRACTION, HYSTERESIS_MIN)


func configure(view_camera: Camera3D, probe: Callable, tier: StringName) -> void:
	name = "UnderwaterPass"
	camera = view_camera
	water_probe = probe
	quality_tier = tier
	_material = ShaderMaterial.new()
	_material.shader = PASS_SHADER
	_material.render_priority = RENDER_PRIORITY
	_material.set_shader_parameter(&"shaft_samples", int(SHAFT_SAMPLES_BY_TIER.get(tier, 8)))
	_bind_caustic_tiles()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	mesh.flip_faces = true
	mesh.material = _material
	_quad = MeshInstance3D.new()
	_quad.name = "UnderwaterQuad"
	_quad.mesh = mesh
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.ignore_occlusion_culling = true
	_quad.extra_cull_margin = 16384.0
	_quad.visible = false
	add_child(_quad)
	_submerge_player = _make_player("SubmergeSfx", SUBMERGE_STREAM)
	_emerge_player = _make_player("EmergeSfx", EMERGE_STREAM)


func is_pass_visible() -> bool:
	return _quad != null and _quad.visible


func pass_material() -> ShaderMaterial:
	return _material


func _exit_tree() -> void:
	# The bus layout is global; never leave the world muffled after this view goes away.
	_emerge_pending = false
	lowpass_mix = 0.0
	_apply_lowpass()
	if _submerge_player != null:
		_submerge_player.stop()
	if _emerge_player != null:
		_emerge_player.stop()


## Called every frame by MapView3D.
func update(delta: float) -> void:
	if camera == null or not camera.is_inside_tree():
		return
	var probe := _probe(Vector2(camera.global_position.x, camera.global_position.z))
	advance(delta, _camera_depth(probe), probe)


## Steps the state machine with an explicit camera depth (NAN when not over water). Split
## from update() so tests can drive it with synthetic heights.
func advance(delta: float, depth: float, probe: Dictionary = {}) -> void:
	var previous := state
	# The top-down orthographic camera cannot submerge; it also has no near-plane band.
	var perspective := camera == null or camera.projection == Camera3D.PROJECTION_PERSPECTIVE
	if is_nan(depth) or not perspective:
		state = STATE_AIR
	else:
		# Crests rise above the rest plane, and the water shader already shows its
		# underside wherever one passes over the lens, so AIR starts above them.
		var band := straddle_band(camera) if camera != null else 0.0
		var crest := float(probe.get("wave_margin", 0.0))
		state = classify(depth, band, state, hysteresis_for_band(band), crest)
	if state == STATE_UNDER:
		if previous != STATE_UNDER:
			_emerge_pending = false
			_play_cue(CUE_SUBMERGE)
		_submerged_since_air = true
	if state == STATE_AIR and previous != STATE_AIR and _submerged_since_air:
		_submerged_since_air = false
		if perspective:
			wet_lens_remaining = WET_LENS_SECONDS
			_lens_age = 0.0
			_emerge_pending = true
	elif wet_lens_remaining > 0.0:
		wet_lens_remaining = maxf(wet_lens_remaining - delta, 0.0)
		_lens_age += delta
	if state != STATE_AIR:
		wet_lens_remaining = 0.0
	var target := 1.0 if state == STATE_UNDER else 0.0
	lowpass_mix = move_toward(lowpass_mix, target, delta / LOWPASS_FADE_SECONDS)
	_apply_lowpass()
	if _emerge_pending and lowpass_mix <= EMERGE_UNFILTERED_MIX:
		_emerge_pending = false
		_play_cue(CUE_EMERGE)
	var show := state != STATE_AIR or wet_lens_remaining > 0.0
	if _quad != null:
		_quad.visible = show
	if show:
		_sync_material(probe)


func _probe(xz: Vector2) -> Dictionary:
	if not water_probe.is_valid():
		return {}
	var result: Variant = water_probe.call(xz)
	return result if result is Dictionary else {}


static func _camera_depth_from(probe: Dictionary, camera_y: float) -> float:
	if probe.is_empty():
		return NAN
	return float(probe["surface_y"]) - camera_y


func _camera_depth(probe: Dictionary) -> float:
	return _camera_depth_from(probe, camera.global_position.y)


## Bind the WS-07 tiles even when no water material is mirrored (tests, dry probe).
## Quality follows this pass's tier so minimum stays at one tile.
func _bind_caustic_tiles() -> void:
	if _material == null:
		return
	var complete := true
	for uniform_name: String in WaterMaterials.CAUSTIC_TILE_PATHS:
		var tile := load(String(WaterMaterials.CAUSTIC_TILE_PATHS[uniform_name])) as Texture2D
		if tile == null:
			complete = false
			continue
		_material.set_shader_parameter(StringName(uniform_name), tile)
	if complete:
		_material.set_shader_parameter(&"caustic_min_pair_mean", WaterMaterials.CAUSTIC_MIN_PAIR_MEAN)
	else:
		_material.set_shader_parameter(&"caustic_min_pair_mean", Vector2.ONE)
	_material.set_shader_parameter(&"caustic_full_quality", quality_tier != &"minimum")
	_material.set_shader_parameter(&"caustic_pattern_scale", 3.0)


func _sync_material(probe: Dictionary) -> void:
	if _material == null:
		return
	var source := probe.get("material") as ShaderMaterial
	if source != null:
		for uniform_name in MIRRORED_UNIFORMS:
			var value: Variant = source.get_shader_parameter(uniform_name)
			if value != null:
				_material.set_shader_parameter(uniform_name, value)
	if probe.has("surface_y"):
		_material.set_shader_parameter(&"water_plane_y", float(probe["surface_y"]))
	_material.set_shader_parameter(&"medium_state", state)
	_material.set_shader_parameter(&"wet_lens", wet_lens_remaining / WET_LENS_SECONDS)
	_material.set_shader_parameter(&"lens_age", _lens_age)


## Index of the underwater low-pass on the SFX bus, or -1 if the layout lacks it.
static func lowpass_effect_index() -> int:
	var bus := AudioServer.get_bus_index(SFX_BUS)
	if bus < 0:
		return -1
	for index in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, index)
		if effect is AudioEffectLowPassFilter and effect.resource_name == LOWPASS_EFFECT_NAME:
			return index
	return -1


static func is_lowpass_enabled() -> bool:
	var index := lowpass_effect_index()
	return index >= 0 and AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index(SFX_BUS), index)


func _apply_lowpass() -> void:
	var index := lowpass_effect_index()
	if index < 0:
		return
	var bus := AudioServer.get_bus_index(SFX_BUS)
	var effect := AudioServer.get_bus_effect(bus, index) as AudioEffectLowPassFilter
	# Exponential sweep so the fade sounds even across octaves.
	effect.cutoff_hz = LOWPASS_OPEN_HZ * pow(LOWPASS_CUTOFF_HZ / LOWPASS_OPEN_HZ, lowpass_mix)
	var enabled := lowpass_mix > EMERGE_UNFILTERED_MIX
	if AudioServer.is_bus_effect_enabled(bus, index) != enabled:
		AudioServer.set_bus_effect_enabled(bus, index, enabled)


func _make_player(player_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	AudioBusServiceScript.assign_bus(player, AudioBusServiceScript.BUS_SFX)
	add_child(player)
	return player


func _play_cue(cue_id: StringName) -> void:
	played_cues.append(cue_id)
	cue_played.emit(cue_id)
	var player := _submerge_player if cue_id == CUE_SUBMERGE else _emerge_player
	if player == null or player.stream == null:
		return
	player.stop()
	player.play()
