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
##
## WR-5 obstacle mode (R-1510, configure_obstacles): a second instance of this class runs
## the same ping-pong as a camera-following wave sim for rocks, the sea stack and quays.
## State: R = scattered height (what obstacles add to the incident swell: reflection,
## diffraction, shadow), G = its vertical velocity, B = impact foam. The incident is the
## sea's own FFT + shore swell, evaluated by the step shader from uniforms copied off the
## sea material, so the sim is driven by the analytic sea at its wall boundaries and the
## window edge needs no matching (the scattered field fades to zero there). The obstacle
## mask (CityObstacleMask) is re-rasterised only when the window leaves its margin. It
## steps once per rendered frame by the ocean-clock delta (captures and pauses stay
## deterministic), and times its CPU work with Time.get_ticks_usec (step_usec_mean).

const SkyWeather3DScript := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const STEP_SHADER := preload("res://scripts/map/view3d/water_ripple_sim.gdshader")

const WINDOW_WORLD_SIZE := 64.0
## Gameplay impulses (wakes, swimmer, splashes) dispatched per step. Extra calls are dropped.
const MAX_IMPULSES := 32
## Rain is not simulated here: real rain rings span centimetres and live under a second,
## below the 25 cm texel, so injected drops grew into metre-wide rings that stopped at the
## window edge. map_view_water.gdshader draws them procedurally (rain_ring_intensity).
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

## WR-5 obstacle sim texels per 64 m window side, keyed by the sea LOD tier
## (MapViewWaterMaterials.sea_lod_tier): fixed per tier, off on minimum.
const OBSTACLE_SIM_SIZES := {&"minimum": 0, &"recommended": 128, &"high": 256}
## Mask texels kept beyond each window side, so a walking camera rasterises rarely.
const OBSTACLE_MASK_MARGIN := 32
## Longest ocean-clock step; a longer frame runs the sim slower instead of unstable.
const OBSTACLE_DT_MAX := 1.0 / 20.0
## A clock jump longer than this (scrubbing, reload) restarts the field flat.
const OBSTACLE_CLOCK_JUMP := 1.0
## Gravity in world units (0.87 m each, as the sea shaders assume).
const OBSTACLE_GRAVITY := 9.81 / 0.87
## Dominant incident wavelength (world units) for the depth-dependent wave speed: the
## FFT C1 band (4-16 m) that the fine LOD rings near the camera displace.
const OBSTACLE_WAVELENGTH := 8.0
## Wind drift of impact foam (world units per second at full wind strength).
const OBSTACLE_FOAM_DRIFT := 1.2
## Sea uniforms the obstacle kernel shares with map_view_water.gdshader; copied each step.
const OBSTACLE_SEA_UNIFORMS: Array[StringName] = [
	&"use_fft", &"fft_c0_disp", &"fft_c1_disp", &"fft_cascade", &"fft_disp_scale",
	&"ocean_amplitude", &"fft_cascade_count", &"choppiness", &"standing_wave_ratio",
	&"wind_direction", &"shore_geometry_scale", &"shore_field", &"shore_field_origin",
	&"shore_field_size", &"shore_field_valid", &"shore_sea_state", &"shore_strength",
	&"shore_tide_offset", &"shore_runup_gain", &"shore_wave_gain", &"shore_depth_scale",
	&"shore_foam_gain", &"shore_crest_shape", &"shore_bed_valid",
]

## Texels per window side (256 on recommended). 0 means the sim is off.
var sim_size := 0
## World XZ of the window's min corner, snapped to whole texels.
var window_origin := Vector2.ZERO
var window_size := WINDOW_WORLD_SIZE
var frame_index := 0
## Returns the camera focus as world Vector3; set by MapView3D.
var focus_provider: Callable
## Called after every step with (texture, window: Vector4, texel_count: float).
var bind_callback: Callable
## Last dispatched step, in window texel coordinates, for tests and captures.
var last_impulses := PackedVector4Array()
var last_shift := Vector2i.ZERO
## WR-5: true when configured by configure_obstacles().
var obstacle_mode := false
var obstacle_mask: CityObstacleMask
## The sea material whose swell drives the obstacle field.
var wave_source: ShaderMaterial
## Wind direction and strength (0..1) for the foam drift.
var foam_wind := Vector2.ZERO
## CPU cost of the last step and its running mean (microseconds), mask rasters included.
var last_step_usec := 0
var step_usec_mean := 0.0
var mask_builds := 0

var _queue := PackedVector4Array()
var _origin_texel := Vector2i.ZERO
var _has_origin := false
var _viewports: Array[SubViewport] = []
var _materials: Array[ShaderMaterial] = []
## Index of the viewport holding the newest state.
var _current := 0
var _reset_steps_left := RESET_STEPS
var _accumulator := 0.0

var _mask_image: Image
var _mask_texture: ImageTexture
var _mask_origin := Vector2i.ZERO
var _mask_valid := false
var _last_ocean_time := -1.0


## Window side in texels for a quality tier (0 = off).
static func sim_size_for_tier(tier: Variant) -> int:
	return int(SkyWeather3DScript.quality_settings(tier).get("ripple_sim_size", 0))


## WR-5 obstacle sim side in texels for a sea LOD tier (0 = off). Unknown tiers resolve
## like SkyWeather3D (auto -> recommended).
static func obstacle_sim_size_for_tier(tier: Variant) -> int:
	var id := StringName(String(tier if tier != null else "").to_lower())
	if not OBSTACLE_SIM_SIZES.has(id):
		id = SkyWeather3DScript.resolve_quality_tier(tier)
	return int(OBSTACLE_SIM_SIZES.get(id, 0))


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


## WR-5: builds the obstacle sim (see the class notes). `mask` supplies bathymetry and
## rocks, `sea` is the sea material whose swell drives it. size <= 0 builds nothing.
func configure_obstacles(size_texels: int, mask: CityObstacleMask, sea: ShaderMaterial) -> bool:
	obstacle_mode = true
	obstacle_mask = mask
	wave_source = sea
	_mask_valid = false
	_last_ocean_time = -1.0
	if not configure(size_texels):
		return false
	var texel := texel_world_size(sim_size)
	for material in _materials:
		material.set_shader_parameter(&"obstacle_mode", true)
		material.set_shader_parameter(&"obstacle_texel", texel)
		material.set_shader_parameter(&"obstacle_gravity", OBSTACLE_GRAVITY)
		material.set_shader_parameter(&"obstacle_k", TAU / OBSTACLE_WAVELENGTH)
	return true


## The obstacle mask texture of the current window (null before the first step).
func mask_texture() -> ImageTexture:
	return _mask_texture


## Mask texel of the window's texel (0, 0).
func mask_offset() -> Vector2i:
	return _origin_texel - _mask_origin


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


func _process(delta: float) -> void:
	if not is_active():
		return
	if obstacle_mode:
		# One step per rendered frame, by however far the ocean clock moved.
		step(_focus_xz())
		return
	_accumulator = minf(_accumulator + delta, 1.0 / STEP_HZ * 2.0)
	if _accumulator < 1.0 / STEP_HZ:
		return
	_accumulator -= 1.0 / STEP_HZ
	step(_focus_xz())


## One simulation step centred on `focus_xz`: scrolls the window, dispatches the queued
## impulses, schedules the partner viewport and rebinds the water.
## Public so headless tests can drive it without a frame loop.
func step(focus_xz: Vector2) -> void:
	if obstacle_mode:
		step_obstacles(focus_xz, _ocean_dt())
		return
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
	frame_index += 1
	if not is_active():
		return

	var target := 1 - _current
	var material := _materials[target]
	material.set_shader_parameter(&"window_shift", last_shift)
	material.set_shader_parameter(&"reset_state", _reset_steps_left > 0)
	material.set_shader_parameter(&"impulse_count", last_impulses.size())
	material.set_shader_parameter(&"impulses", _padded(last_impulses, MAX_IMPULSES))
	_reset_steps_left = maxi(_reset_steps_left - 1, 0)
	# UPDATE_ONCE renders on the next draw, before the main viewport, then drops back to
	# UPDATE_DISABLED, so only the target kernel runs this frame.
	_viewports[target].render_target_update_mode = SubViewport.UPDATE_ONCE
	_current = target
	if bind_callback.is_valid():
		bind_callback.call(state_texture(), window_uniform(), float(sim_size))


## WR-5: one obstacle step of `dt` seconds of ocean time centred on `focus_xz`: scrolls
## the window, re-rasterises the mask when the window leaves it, copies the sea's swell
## uniforms and schedules the partner viewport. Public so tests can drive it.
func step_obstacles(focus_xz: Vector2, dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	var texel := texel_world_size(sim_size)
	var next_origin := snap_origin_texel(focus_xz, sim_size)
	last_shift = window_shift(_origin_texel, next_origin) if _has_origin else Vector2i.ZERO
	_origin_texel = next_origin
	_has_origin = true
	window_origin = Vector2(next_origin) * texel
	frame_index += 1
	if not is_active():
		return
	_ensure_mask(next_origin, texel)
	var target := 1 - _current
	var material := _materials[target]
	material.set_shader_parameter(&"window_shift", last_shift)
	material.set_shader_parameter(&"reset_state", _reset_steps_left > 0)
	material.set_shader_parameter(&"obstacle_dt", clampf(dt, 0.0, OBSTACLE_DT_MAX))
	material.set_shader_parameter(&"obstacle_origin", window_origin)
	material.set_shader_parameter(&"mask_offset", next_origin - _mask_origin)
	material.set_shader_parameter(&"foam_drift", foam_wind * OBSTACLE_FOAM_DRIFT)
	_copy_sea_uniforms(material)
	_reset_steps_left = maxi(_reset_steps_left - 1, 0)
	_viewports[target].render_target_update_mode = SubViewport.UPDATE_ONCE
	_current = target
	if bind_callback.is_valid():
		bind_callback.call(state_texture(), window_uniform(), float(sim_size))
	last_step_usec = Time.get_ticks_usec() - t0
	# Exponential mean over ~60 steps: the steady-state per-frame cost.
	step_usec_mean = (
		float(last_step_usec) if frame_index <= 1
		else lerpf(step_usec_mean, float(last_step_usec), 1.0 / 60.0)
	)


## Ocean-clock seconds since the previous obstacle step (wrap-safe). A jump restarts flat.
func _ocean_dt() -> float:
	var now := MapViewRuntimeEnvironment.ocean_time()
	var previous := _last_ocean_time
	_last_ocean_time = now
	if previous < 0.0:
		return 0.0
	var dt := fposmod(now - previous, MapViewRuntimeEnvironment.OCEAN_TIME_WRAP_SECONDS)
	if dt > OBSTACLE_CLOCK_JUMP:
		_reset_steps_left = RESET_STEPS
		return 0.0
	return dt


## Keeps the mask raster around the window: rebuilt (rocks re-stamped, bathymetry
## re-sampled) only when the window has walked out of the margin.
func _ensure_mask(origin_texel: Vector2i, texel: float) -> void:
	var span := sim_size + OBSTACLE_MASK_MARGIN * 2
	var lo := origin_texel - _mask_origin
	if (
		_mask_valid and lo.x >= 0 and lo.y >= 0
		and lo.x + sim_size <= span and lo.y + sim_size <= span
	):
		return
	_mask_origin = origin_texel - Vector2i(OBSTACLE_MASK_MARGIN, OBSTACLE_MASK_MARGIN)
	if obstacle_mask != null:
		_mask_image = obstacle_mask.rasterise(_mask_origin, span, texel)
	else:
		_mask_image = Image.create_empty(span, span, false, Image.FORMAT_RF)
		_mask_image.fill(Color(100.0, 0.0, 0.0))
	if _mask_texture == null or _mask_texture.get_size() != Vector2(span, span):
		_mask_texture = ImageTexture.create_from_image(_mask_image)
	else:
		_mask_texture.update(_mask_image)
	_mask_valid = true
	mask_builds += 1
	for material in _materials:
		material.set_shader_parameter(&"obstacle_mask", _mask_texture)
		material.set_shader_parameter(&"mask_size", Vector2i(span, span))


func _copy_sea_uniforms(material: ShaderMaterial) -> void:
	if wave_source == null:
		material.set_shader_parameter(&"use_fft", false)
		material.set_shader_parameter(&"shore_field_valid", 0.0)
		return
	for uniform_name in OBSTACLE_SEA_UNIFORMS:
		material.set_shader_parameter(uniform_name, wave_source.get_shader_parameter(uniform_name))
	# The near-shore FFT geometry share (WR-1 depth presets) the sea mesh draws there.
	var shallow: Variant = wave_source.get_shader_parameter(&"sea_wave_shallow")
	material.set_shader_parameter(
		&"incident_fft_scale", (shallow as Vector4).y if shallow is Vector4 else 1.0
	)


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
	_mask_valid = false
