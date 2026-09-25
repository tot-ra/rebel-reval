class_name WaterRippleSim
extends Node

## WS-15 interactive ripples: a damped discrete wave equation in a 64 x 64 world-unit window
## that follows the camera focus, sampled by map_view_water.gdshader as an additive detail on
## top of the FFT sea (height, normal and aeration foam). Technique after Tidewater's
## WakeKernel (local window, visc 0.006, bow push-up / stern hollow, aeration foam); Tidewater
## runs it in compute, here two SubViewports swap roles every step (a viewport cannot read its
## own output). Ported from Tidewater (MIT), see notice.code.tidewater.
##
## State channels: R = height h_t, G = height h_{t-1}, B = aeration (foam), A unused
## (Metal forces alpha to 1 in an opaque target).
##
## Storage decision: HDR float targets (use_hdr_2d), no packed-16 RGBA8. A non-headless probe
## on Godot 4.7.1 (canvas kernel writing vec4(0.3, -0.2, 0.01, 0.75)) read back the signed
## values exactly (half-float precision) from both a canvas_item and a spatial shader sampling
## the ViewportTexture, on GL Compatibility (opengl3) and on Metal. Unlike the WS-10 sky
## shader, the spatial water shader sees no sRGB decode, so no encode flag is needed.
##
## Texel convention: the step kernel indexes texels by FRAGCOORD (memory order on every
## backend, see the WS-10 note in agents/rebel-dev/playbook.md), so texel (i, j) covers world
## x = origin.x + (i + 0.5) * texel, z = origin.y + (j + 0.5) * texel, and the water shader's
## texture() UV (world - origin) / size lands on the same texel.
##
## Cadence: the step runs at a fixed STEP_HZ (at most one step per rendered frame), so wave
## speed in world units per second does not depend on the frame rate. Below 60 fps the
## ripples slow down rather than skipping steps.
##
## No CPU readback: gameplay never reads ripple heights (boats keep OceanFftSampler).
## Nothing is persisted; the sim starts flat on every map load.

const SkyWeather3DScript := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const STEP_SHADER := preload("res://scripts/map/view3d/water_ripple_sim.gdshader")

const WINDOW_WORLD_SIZE := 64.0
## Gameplay impulses (wakes, swimmer, splashes) dispatched per step. Extra calls are dropped.
const MAX_IMPULSES := 32
## Rain has its own uniform array so a storm never starves a boat wake of impulse slots.
const RAIN_DROPS_AT_FULL_INTENSITY := 40
const RAIN_RADIUS_TEXELS := Vector2(1.0, 2.0)
const RAIN_STRENGTH := Vector2(0.02, 0.05)
const RAIN_SEED := 0x5715A1
const STEP_HZ := 60.0
## c^2 of the five-point scheme; 2D CFL stability needs <= 0.5.
const WAVE_C2 := 0.02
const VISCOSITY := 0.006
## Velocity-Laplacian (Kelvin-Voigt) damping for grid-scale chatter; see the step shader.
const WAVE_SMOOTHING := 0.07
## Tidewater foamGain 0.35 is per compute tick of a pressure field; this gain maps the
## per-step hull forcing (~0.006 at 3 u/s) onto a 0..1 aeration value.
const AERATION_GAIN := 110.0
## Aeration e-folding rate per second: churned water fades over a few seconds.
const AERATION_DECAY := 0.45
const EDGE_ABSORB_TEXELS := 8.0
## Moving bodies: ring strength per step per unit of speed (world units per second) at the
## bow, and the stern's opposite-phase ring relative to it (Tidewater `bow` / `hollow`). The
## hull outruns the ring speed (WAVE_C2 -> ~2.1 u/s) at rowing pace, so the rings it emits
## every step form a V; at 3 u/s the accumulated crest stays near the rain-ring range.
const BOW_STRENGTH_PER_SPEED := 0.002
const STERN_HOLLOW_RATIO := 0.8
const BODY_STRENGTH_MAX := 0.012
## A ring's volume grows with radius squared, so wider hulls are normalised to this beam and
## a cog does not flood the window with a crest several times a rowing boat's.
const BODY_REFERENCE_HALF_BEAM := 0.45
## Two steps write zero so the never-rendered partner target cannot leak its clear colour.
const RESET_STEPS := 2

## Texels per window side (256 on recommended). 0 means the sim is off.
var sim_size := 0
## World XZ of the window's min corner, snapped to whole texels.
var window_origin := Vector2.ZERO
var window_size := WINDOW_WORLD_SIZE
var frame_index := 0
var rain_intensity := 0.0
## Returns the camera focus as world Vector3; set by MapView3D.
var focus_provider: Callable
## Called after every step with (texture, window: Vector4, texel_count: float).
var bind_callback: Callable
## Last dispatched step, in window texel coordinates, for tests and captures.
var last_impulses := PackedVector4Array()
var last_rain_drops := PackedVector4Array()
var last_shift := Vector2i.ZERO

var _queue := PackedVector4Array()
var _origin_texel := Vector2i.ZERO
var _has_origin := false
var _viewports: Array[SubViewport] = []
var _materials: Array[ShaderMaterial] = []
## Index of the viewport holding the newest state.
var _current := 0
var _reset_steps_left := RESET_STEPS
var _accumulator := 0.0


## Window side in texels for a quality tier (0 = off).
static func sim_size_for_tier(tier: Variant) -> int:
	return int(SkyWeather3DScript.quality_settings(tier).get("ripple_sim_size", 0))


## The sim exists only outdoors, on maps with water, on tiers that enable it.
static func should_create(tier: Variant, indoor: bool, has_water: bool) -> bool:
	return not indoor and has_water and sim_size_for_tier(tier) > 0


static func texel_world_size(size_texels: int) -> float:
	return WINDOW_WORLD_SIZE / float(maxi(size_texels, 1))


## Texel index of the window's min corner so the window is centred on `focus_xz`.
static func snap_origin_texel(focus_xz: Vector2, size_texels: int) -> Vector2i:
	var texel := texel_world_size(size_texels)
	var corner := focus_xz / texel - Vector2(size_texels, size_texels) * 0.5
	return Vector2i(floori(corner.x), floori(corner.y))


## Texel shift the step shader applies when reading the previous state: the new texel i
## covers the world spot the previous window stored at i + shift.
static func window_shift(previous_origin: Vector2i, next_origin: Vector2i) -> Vector2i:
	return next_origin - previous_origin


## Deterministic droplets for one step: vec4(texel x, texel y, radius texels, strength).
## The count scales with intensity (intensity * 40) and the RNG is seeded by the frame index.
static func rain_drops_for_frame(
	frame: int, intensity: float, size_texels: int
) -> PackedVector4Array:
	var drops := PackedVector4Array()
	var count := roundi(clampf(intensity, 0.0, 1.0) * float(RAIN_DROPS_AT_FULL_INTENSITY))
	if count <= 0 or size_texels <= 0:
		return drops
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(frame, RAIN_SEED))
	# Keep drops out of the absorbing border so each ring starts on live water.
	var lo := EDGE_ABSORB_TEXELS
	var hi := maxf(float(size_texels) - EDGE_ABSORB_TEXELS, lo + 1.0)
	for _index in count:
		drops.append(
			Vector4(
				rng.randf_range(lo, hi),
				rng.randf_range(lo, hi),
				rng.randf_range(RAIN_RADIUS_TEXELS.x, RAIN_RADIUS_TEXELS.y),
				rng.randf_range(RAIN_STRENGTH.x, RAIN_STRENGTH.y)
			)
		)
	return drops


## World-space bow and stern impulses (x, z, radius world units, strength) for a hull.
## The bow pushes water up ahead of the hull and the stern leaves a hollow, so a moving body
## emits a V wake; a hull at rest emits nothing.
static func moving_body_impulses(
	world_pos: Vector2, velocity: Vector2, half_length: float, half_beam: float
) -> PackedVector4Array:
	var impulses := PackedVector4Array()
	var speed := velocity.length()
	if speed < 0.001:
		return impulses
	var heading := velocity / speed
	var radius := maxf(half_beam, 0.1)
	var beam_scale := maxf(radius / BODY_REFERENCE_HALF_BEAM, 1.0)
	var strength := minf(speed * BOW_STRENGTH_PER_SPEED, BODY_STRENGTH_MAX) / (beam_scale * beam_scale)
	var bow := world_pos + heading * half_length
	var stern := world_pos - heading * half_length
	impulses.append(Vector4(bow.x, bow.y, radius, strength))
	impulses.append(Vector4(stern.x, stern.y, radius, -strength * STERN_HOLLOW_RATIO))
	return impulses


## Builds the two ping-pong viewports. size <= 0 builds nothing and returns false.
func configure(size_texels: int) -> bool:
	_release_viewports()
	sim_size = maxi(size_texels, 0)
	if sim_size <= 0:
		return false
	for index in 2:
		var viewport := SubViewport.new()
		viewport.name = "RippleState%s" % ["A", "B"][index]
		viewport.size = Vector2i(sim_size, sim_size)
		viewport.use_hdr_2d = true
		viewport.transparent_bg = false
		viewport.disable_3d = true
		viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var rect := ColorRect.new()
		rect.name = "RippleStep"
		rect.size = Vector2(sim_size, sim_size)
		var material := ShaderMaterial.new()
		material.shader = STEP_SHADER
		material.set_shader_parameter(&"sim_size", Vector2(sim_size, sim_size))
		material.set_shader_parameter(&"wave_c2", WAVE_C2)
		material.set_shader_parameter(&"viscosity", VISCOSITY)
		material.set_shader_parameter(&"wave_smoothing", WAVE_SMOOTHING)
		material.set_shader_parameter(&"aer_gain", AERATION_GAIN)
		material.set_shader_parameter(&"aer_decay", AERATION_DECAY)
		material.set_shader_parameter(&"step_dt", 1.0 / STEP_HZ)
		material.set_shader_parameter(&"edge_absorb_texels", EDGE_ABSORB_TEXELS)
		rect.material = material
		viewport.add_child(rect)
		add_child(viewport)
		_viewports.append(viewport)
		_materials.append(material)
	# Each kernel reads the partner's output (a viewport cannot sample itself).
	_materials[0].set_shader_parameter(&"prev_state", _viewports[1].get_texture())
	_materials[1].set_shader_parameter(&"prev_state", _viewports[0].get_texture())
	_reset_steps_left = RESET_STEPS
	_has_origin = false
	return true


func is_active() -> bool:
	return sim_size > 0 and not _viewports.is_empty()


func viewports() -> Array[SubViewport]:
	return _viewports


## Newest simulation state (R = h, G = previous h, B = aeration).
func state_texture() -> Texture2D:
	return _viewports[_current].get_texture() if is_active() else null


## vec4(origin x, origin z, window size, valid) as consumed by the water shader.
func window_uniform() -> Vector4:
	return Vector4(window_origin.x, window_origin.y, window_size, 1.0 if is_active() else 0.0)


func queued_impulse_count() -> int:
	return _queue.size()


## Queues a Gaussian bump for the next step. Returns false once MAX_IMPULSES are queued.
func add_impulse(world_pos: Vector2, radius: float, strength: float) -> bool:
	if _queue.size() >= MAX_IMPULSES:
		return false
	_queue.append(Vector4(world_pos.x, world_pos.y, radius, strength))
	return true


## Hook for moving vessels and (after WS-14) the swimmer: paired bow and stern impulses.
func add_moving_body(
	world_pos: Vector2, velocity: Vector2, half_length: float, half_beam: float
) -> void:
	for impulse in moving_body_impulses(world_pos, velocity, half_length, half_beam):
		add_impulse(Vector2(impulse.x, impulse.y), impulse.z, impulse.w)


## Called by SkyWeather3D with rain_intensity() (0 when rain is suppressed indoors).
func set_rain(intensity: float) -> void:
	rain_intensity = clampf(intensity, 0.0, 1.0)


func _process(delta: float) -> void:
	if not is_active():
		return
	_accumulator = minf(_accumulator + delta, 1.0 / STEP_HZ * 2.0)
	if _accumulator < 1.0 / STEP_HZ:
		return
	_accumulator -= 1.0 / STEP_HZ
	step(_focus_xz())


## One simulation step centred on `focus_xz`: scrolls the window, dispatches the queued
## impulses and this frame's rain, schedules the partner viewport and rebinds the water.
## Public so headless tests can drive it without a frame loop.
func step(focus_xz: Vector2) -> void:
	var texel := texel_world_size(sim_size)
	var next_origin := snap_origin_texel(focus_xz, sim_size)
	last_shift = window_shift(_origin_texel, next_origin) if _has_origin else Vector2i.ZERO
	_origin_texel = next_origin
	_has_origin = true
	window_origin = Vector2(next_origin) * texel

	last_impulses = PackedVector4Array()
	for impulse in _queue:
		last_impulses.append(
			Vector4(
				impulse.x / texel - float(next_origin.x),
				impulse.y / texel - float(next_origin.y),
				impulse.z / texel,
				impulse.w
			)
		)
	_queue.clear()
	last_rain_drops = rain_drops_for_frame(frame_index, rain_intensity, sim_size)
	frame_index += 1
	if not is_active():
		return

	var target := 1 - _current
	var material := _materials[target]
	material.set_shader_parameter(&"window_shift", last_shift)
	material.set_shader_parameter(&"reset_state", _reset_steps_left > 0)
	material.set_shader_parameter(&"impulse_count", last_impulses.size())
	material.set_shader_parameter(&"impulses", _padded(last_impulses, MAX_IMPULSES))
	material.set_shader_parameter(&"rain_count", last_rain_drops.size())
	material.set_shader_parameter(
		&"rain_drops", _padded(last_rain_drops, RAIN_DROPS_AT_FULL_INTENSITY)
	)
	_reset_steps_left = maxi(_reset_steps_left - 1, 0)
	# UPDATE_ONCE renders on the next draw, before the main viewport, then drops back to
	# UPDATE_DISABLED, so only the target kernel runs this frame.
	_viewports[target].render_target_update_mode = SubViewport.UPDATE_ONCE
	_current = target
	if bind_callback.is_valid():
		bind_callback.call(state_texture(), window_uniform(), float(sim_size))


func _focus_xz() -> Vector2:
	if focus_provider.is_valid():
		var focus: Vector3 = focus_provider.call()
		return Vector2(focus.x, focus.z)
	return window_origin + Vector2(window_size, window_size) * 0.5


## Uniform arrays keep a fixed length so the shader array never resizes.
static func _padded(values: PackedVector4Array, length: int) -> PackedVector4Array:
	var padded := values.duplicate()
	padded.resize(length)
	return padded


func _release_viewports() -> void:
	for viewport in _viewports:
		remove_child(viewport)
		viewport.free()
	_viewports.clear()
	_materials.clear()
	_current = 0
