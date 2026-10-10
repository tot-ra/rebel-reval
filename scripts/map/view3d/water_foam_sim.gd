class_name WaterFoamSim
extends Node

## WR-7 foam with memory (R-1512, docs/SYSTEMS/CITY_SEA.md "Foam memory"): a camera-
## following foam density buffer for the city sea on the recommended and high tiers.
## Foam is born where the FFT displacement Jacobian folds and where the surf rollers and
## wall slosh break, drifts with the wind (plus Stokes drift), decays, and its long-lived
## share is smeared along the wind into windrows. map_view_water.gdshader dissolves its
## WR-2 foam structure by it instead of the analytic coverage; outside the window and on
## the minimum tier the analytic WR-2 foam stays, blended over the window's edge band.
##
## Same GL Compatibility technique as WaterRippleSim (WS-15): two HDR SubViewports swap
## roles every step, a canvas kernel reads the partner's output. No CPU readback.
##
## Sampler budget: the sea's fragment stage already uses all 16 GL Compatibility texture
## units, and one more declared sampler makes the whole sea vanish on macOS without a link
## error. So the sim does not add a sampler: an atlas viewport copies the foam state and
## the WS-15 ripple state side by side into one HDR texture, bound to the sea's existing
## `ripple_state` with per-region rects (ripple_atlas_rect, foam_atlas_rect). The copy
## reads each state one step after it completed, so the draw order of the viewports never
## matters (a ripple lag of one 60 Hz step).
##
## Frame and drift: the buffer stores foam at the sea's rest (Lagrangian) coordinate, so
## the FFT vertex displacement carries it with the orbital motion and the shader's surge
## shift carries it with the swash. Only the net drift moves the buffer, and it moves the
## window itself: `_drift_offset` (sub-texel, world units) is added to the window origin
## and every whole texel of drift becomes part of the integer read shift. The state is
## never resampled, so travelling foam keeps its edges.
##
## Clock: steps follow the ocean clock (MapViewRuntimeEnvironment.ocean_time), so pausing
## time pauses the foam. The delta is taken modulo OCEAN_TIME_WRAP_SECONDS, so the wrap
## is an ordinary step; the FFT bake and shore sets are periodic over the wrap. A jump
## longer than MAX_STEP_GAP (load, time skip) reseeds the window from the analytic foam.

const SkyWeather3DScript := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const PerfProbeScript := preload("res://scripts/debug/perf_probe.gd")
const STEP_SHADER := preload("res://scripts/map/view3d/water_foam_sim.gdshader")
const WATER_MATERIALS := preload("res://scripts/map/view3d/map_view_water_materials.gd")
const OCEAN_TIME_WRAP_SECONDS := MapViewRuntimeEnvironment.OCEAN_TIME_WRAP_SECONDS

## Per WR-3 sea tier: texels per side and window side (world units). Minimum has no sim.
const TIER_SETTINGS := {
	&"minimum": {"size": 0, "window": 0.0},
	&"recommended": {"size": 256, "window": 128.0},
	&"high": {"size": 512, "window": 192.0},
}
## Foam is slow; 30 Hz keeps a 0.9 s fresh life smooth at a quarter of a 120 Hz frame rate.
const STEP_HZ := 30.0
## Ocean-clock gap (s) treated as a discontinuity: the window is reseeded.
const MAX_STEP_GAP := 1.0
## Largest dt one step integrates (a slow frame does not over-decay the foam).
const MAX_STEP_DT := 0.1
## Net surface drift (world units per second; the city is 1 m per unit) along the wind:
## wind drift ~3 % of U10 plus Stokes drift of the wind sea, from a light air
## (shore_sea_state 0) to a gale (1).
const DRIFT_SPEED := Vector2(0.08, 0.55)
## Share of the window side over which the shader blends from analytic to buffer foam.
const EDGE_BLEND := 0.2
## Seed steps: the partner target has never been rendered, so do not read it.
const RESET_STEPS := 2
## Atlas copy: one region per source, full atlas height, so only x offsets are involved
## (FRAGCOORD x is memory order on every backend; no y flip can split a region).
const ATLAS_COPY_CODE := """
shader_type canvas_item;
render_mode blend_disabled, unshaded;
uniform sampler2D source : filter_nearest, repeat_disable;
uniform float offset_x = 0.0;
void fragment() {
	ivec2 size = textureSize(source, 0);
	ivec2 p = clamp(ivec2(int(FRAGCOORD.x - offset_x), int(FRAGCOORD.y)), ivec2(0), size - 1);
	COLOR = vec4(texelFetch(source, p, 0).rgb, 1.0);
}
"""
const IDENTITY_RECT := Vector4(0.0, 0.0, 1.0, 1.0)

static var _atlas_copy_shader: Shader

var sim_size := 0
var window_size := 0.0
## World XZ of texel (0, 0)'s min corner, drift offset included.
var window_origin := Vector2.ZERO
var frame_index := 0
## Returns the camera focus as world Vector3.
var focus_provider: Callable
## Returns the ocean clock in seconds; unset reads MapViewRuntimeEnvironment.ocean_time().
var clock: Callable
## The city sea material; its FFT, shore and foam weather uniforms are mirrored each step.
var source_material: ShaderMaterial
## Sea materials that read the atlas through `ripple_state` (the city sea).
var sea_materials: Array[ShaderMaterial] = []
## Last dispatched step, for tests and captures.
var last_shift := Vector2i.ZERO
var last_dt := 0.0
var last_reset := false

var _viewports: Array[SubViewport] = []
var _materials: Array[ShaderMaterial] = []
var _current := 0
var _reset_steps_left := RESET_STEPS
var _origin_texel := Vector2i.ZERO
var _has_origin := false
## Sub-texel drift (world units, each axis in [0, texel)).
var _drift_offset := Vector2.ZERO
var _last_clock := 0.0
var _has_clock := false
var _accumulator := 0.0
var _mirrored_uniforms := PackedStringArray()
## Atlas: foam region at x 0, ripple region (if any) right of it.
var _atlas: SubViewport
var _atlas_foam_copy: ShaderMaterial
var _atlas_ripple_copy: ShaderMaterial
var _atlas_ripple_size := 0
## Engine frame of the last foam step; that frame's target is still in flight.
var _foam_step_frame := -1
## Foam steps whose target has been drawn (the atlas foam region is valid after one).
var _completed_steps := 0
## WS-15 ripple source: newest state, the one completed before it, its window and size.
var _ripple_latest: Texture2D
var _ripple_completed: Texture2D
var _ripple_frame := -1
var _ripple_window := Vector4.ZERO
var _ripple_texels := 0


## Window side in texels for a WR-3 sea tier (0 = off).
static func sim_size_for_tier(tier: Variant) -> int:
	return int(_tier_settings(tier)["size"])


static func window_size_for_tier(tier: Variant) -> float:
	return float(_tier_settings(tier)["window"])


static func _tier_settings(tier: Variant) -> Dictionary:
	var id := StringName(String(tier if tier != null else "").to_lower())
	if not TIER_SETTINGS.has(id):
		id = SkyWeather3DScript.resolve_quality_tier(id)
	return TIER_SETTINGS[id]


## The sim exists outdoors on maps with a sea, on tiers that enable it.
static func should_create(tier: Variant, indoor: bool, has_sea: bool) -> bool:
	return not indoor and has_sea and sim_size_for_tier(tier) > 0


## Ocean-clock seconds between two readings, across the wrap.
static func clock_delta(previous: float, now: float) -> float:
	return fposmod(now - previous, OCEAN_TIME_WRAP_SECONDS)


## Drift velocity (world units per second) for a wind heading and sea state 0..1.
static func drift_velocity(wind_direction: Vector2, sea_state: float) -> Vector2:
	# Near-zero wind has no usable heading, so fall back to +X instead of normalizing noise
	var heading := Vector2.RIGHT
	if wind_direction.length_squared() > 1e-6:
		heading = wind_direction.normalized()
	return heading * lerpf(DRIFT_SPEED.x, DRIFT_SPEED.y, clampf(sea_state, 0.0, 1.0))


## Folds a drift step into the sub-texel offset. Returns (new offset, whole texels the
## content moved): the offset stays in [0, texel) on both axes.
static func fold_drift(offset: Vector2, step: Vector2, texel: float) -> Array:
	var moved := offset + step
	var whole := Vector2i(floori(moved.x / texel), floori(moved.y / texel))
	return [moved - Vector2(whole) * texel, whole]


## Integer origin (texels) so the window, offset by `drift`, is centred on `focus_xz`.
static func snap_origin_texel(
		focus_xz: Vector2, size_texels: int, texel: float, drift: Vector2) -> Vector2i:
	var corner := (focus_xz - drift) / texel - Vector2(size_texels, size_texels) * 0.5
	return Vector2i(floori(corner.x), floori(corner.y))


## Sea-level point the camera looks at, at most `max_ahead` world units (horizontal) ahead
## of the camera; level or upward views take that distance along the heading.
static func view_focus(camera: Transform3D, max_ahead: float) -> Vector3:
	var origin := camera.origin
	var forward := -camera.basis.z
	var flat := Vector2(forward.x, forward.z)
	if flat.length() < 0.01:
		return Vector3(origin.x, 0.0, origin.z)
	var ahead := max_ahead
	if forward.y < -0.01:
		ahead = minf(origin.y / -forward.y * flat.length(), max_ahead)
	var heading := flat.normalized() * maxf(ahead, 0.0)
	return Vector3(origin.x + heading.x, 0.0, origin.z + heading.y)


## Restores the analytic WR-2 foam and the plain ripple binding on sea materials
## (minimum tier, or the sim leaving). `ripple` is the plain WS-15 state to rebind
## (null keeps whatever ripple_state holds).
static func unbind_materials(materials: Array, ripple: Texture2D = null) -> void:
	for material: ShaderMaterial in materials:
		if material == null:
			continue
		if ripple != null:
			material.set_shader_parameter(&"ripple_state", ripple)
		material.set_shader_parameter(&"ripple_atlas_rect", IDENTITY_RECT)
		material.set_shader_parameter(&"foam_window", Vector4(0.0, 0.0, 128.0, 0.0))


## Atlas layout for a foam and a ripple side (texels): size, foam rect, ripple rect (uv).
static func atlas_layout(foam_texels: int, ripple_texels: int) -> Dictionary:
	var size := Vector2i(foam_texels + ripple_texels, maxi(foam_texels, ripple_texels))
	var full := Vector2(size)
	return {
		"size": size,
		"foam": Vector4(0.0, 0.0, foam_texels / full.x, foam_texels / full.y),
		"ripple": (
			Vector4(foam_texels / full.x, 0.0, ripple_texels / full.x, ripple_texels / full.y)
			if ripple_texels > 0 else IDENTITY_RECT
		),
	}


## Builds the two ping-pong viewports for a tier. Returns false (nothing built) when the
## tier has no sim.
func configure(tier: Variant) -> bool:
	_release_viewports()
	sim_size = sim_size_for_tier(tier)
	window_size = window_size_for_tier(tier)
	if sim_size <= 0:
		return false
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	for index in 2:
		var viewport := SubViewport.new()
		viewport.name = "FoamState%s" % ["A", "B"][index]
		viewport.size = Vector2i(sim_size, sim_size)
		viewport.use_hdr_2d = true
		viewport.transparent_bg = false
		viewport.disable_3d = true
		viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var rect := ColorRect.new()
		rect.name = "FoamStep"
		rect.size = Vector2(sim_size, sim_size)
		var material := ShaderMaterial.new()
		material.shader = STEP_SHADER
		material.set_shader_parameter(&"sim_size", Vector2(sim_size, sim_size))
		material.set_shader_parameter(&"texel_world", texel_world_size())
		material.set_shader_parameter(&"compat_srgb_alpha", compat)
		rect.material = material
		viewport.add_child(rect)
		add_child(viewport)
		_viewports.append(viewport)
		_materials.append(material)
	_materials[0].set_shader_parameter(&"prev_state", _viewports[1].get_texture())
	_materials[1].set_shader_parameter(&"prev_state", _viewports[0].get_texture())
	_reset_steps_left = RESET_STEPS
	_has_origin = false
	_has_clock = false
	_drift_offset = Vector2.ZERO
	_mirrored_uniforms = PackedStringArray()
	_completed_steps = 0
	_build_atlas(_ripple_texels)
	return true


func is_active() -> bool:
	return sim_size > 0 and not _viewports.is_empty()


func viewports() -> Array[SubViewport]:
	return _viewports


func texel_world_size() -> float:
	return window_size / float(maxi(sim_size, 1))


## Newest state (R density, G fresh, B windrows).
func state_texture() -> Texture2D:
	return _viewports[_current].get_texture() if is_active() else null


## vec4(origin x, origin z, window size, valid) as read by the water shader.
func window_uniform() -> Vector4:
	return Vector4(window_origin.x, window_origin.y, window_size, 1.0 if is_active() else 0.0)


## Atlas texture bound to the sea's ripple_state (foam and ripple regions).
func atlas_texture() -> Texture2D:
	return _atlas.get_texture() if _atlas != null else null


func atlas_viewport() -> SubViewport:
	return _atlas


## WS-15 hook: CityMapView passes every ripple step (after the plain binding of all water
## materials), so the sea keeps its ripples through the atlas. A null texture or
## window.w 0 means the ripple sim is off.
func set_ripple_source(texture: Texture2D, window: Vector4, texel_count: float) -> void:
	var live := texture != null and window.w > 0.5
	var texels := int(texel_count) if live else 0
	if texels != _ripple_texels:
		_ripple_texels = texels
		if is_active():
			_build_atlas(texels)
	if texture != _ripple_latest:
		_ripple_completed = _ripple_latest
		_ripple_latest = texture
		_ripple_frame = Engine.get_process_frames()
	_ripple_window = window if live else Vector4(window.x, window.y, window.z, 0.0)
	_update_atlas_sources()
	rebind()


## Binds the atlas, both rects and the foam window to the sea materials.
func rebind() -> void:
	if not is_active() or _atlas == null:
		return
	var layout := atlas_layout(sim_size, _atlas_ripple_size)
	# The foam region is valid once a step's target has been drawn.
	var foam_live := 1.0 if _completed_steps > 0 else 0.0
	var window := Vector4(window_origin.x, window_origin.y, window_size, foam_live)
	for material in sea_materials:
		material.set_shader_parameter(&"ripple_state", _atlas.get_texture())
		material.set_shader_parameter(&"ripple_atlas_rect", layout["ripple"])
		material.set_shader_parameter(&"foam_atlas_rect", layout["foam"])
		material.set_shader_parameter(&"foam_window", window)


## Calibration view (tools only): the state shows R = birth, G = crest (1 - J),
## B = analytic seed density instead of the simulation.
func set_debug_birth(enabled: bool) -> void:
	for material in _materials:
		material.set_shader_parameter(&"debug_birth", enabled)


## Forces the next step to reseed the window from the analytic foam.
func request_reset() -> void:
	_reset_steps_left = maxi(_reset_steps_left, 1)


func _process(_delta: float) -> void:
	var probe_start := PerfProbeScript.start()
	_process_timed(_delta)
	PerfProbeScript.stop(&"water_foam", probe_start)


func _process_timed(_delta: float) -> void:
	if not is_active():
		return
	var frame := Engine.get_process_frames()
	if _foam_step_frame >= 0 and _foam_step_frame != frame and _completed_steps == 0:
		_completed_steps = 1
		rebind()
	_update_atlas_sources()
	var now: float = clock.call() if clock.is_valid() else MapViewRuntimeEnvironment.ocean_time()
	if not _has_clock:
		_last_clock = now
		_has_clock = true
		step(_focus_xz(), 0.0)
		return
	var gap := clock_delta(_last_clock, now)
	_last_clock = now
	if gap > MAX_STEP_GAP:
		request_reset()
		_accumulator = 0.0
		step(_focus_xz(), 0.0)
		return
	_accumulator += gap
	if _accumulator < 1.0 / STEP_HZ:
		return
	var dt := minf(_accumulator, MAX_STEP_DT)
	_accumulator = 0.0
	step(_focus_xz(), dt)


## One step of `dt` ocean seconds centred on `focus_xz`: drifts and scrolls the window,
## mirrors the sea uniforms, schedules the partner viewport and rebinds the sea.
## Public so headless tests can drive it without a frame loop.
func step(focus_xz: Vector2, dt: float) -> void:
	var texel := texel_world_size()
	var drift := Vector2.ZERO
	if source_material != null:
		drift = drift_velocity(
			_param_vec2(&"wind_direction", Vector2(0.9578, 0.2873)),
			_param_float(&"shore_sea_state", 0.35)
		) * dt
	var folded := fold_drift(_drift_offset, drift, texel)
	_drift_offset = folded[0]
	var moved: Vector2i = folded[1]
	var next_origin := snap_origin_texel(focus_xz, sim_size, texel, _drift_offset)
	# New texel i holds what old texel (i + shift) held; drift moved the content by
	# `moved` whole texels, so it now sits that much further along the window.
	last_shift = (next_origin - _origin_texel - moved) if _has_origin else Vector2i.ZERO
	_origin_texel = next_origin
	_has_origin = true
	window_origin = Vector2(next_origin) * texel + _drift_offset
	last_dt = dt
	last_reset = _reset_steps_left > 0
	frame_index += 1
	if not is_active():
		return
	var target := 1 - _current
	var material := _materials[target]
	_mirror_sea_uniforms(material)
	material.set_shader_parameter(&"window_origin", window_origin)
	material.set_shader_parameter(&"window_shift", last_shift)
	material.set_shader_parameter(&"step_dt", maxf(dt, 0.0))
	material.set_shader_parameter(&"reset_state", last_reset)
	_reset_steps_left = maxi(_reset_steps_left - 1, 0)
	# UPDATE_ONCE renders on the next draw, before the main viewport (WaterRippleSim).
	_viewports[target].render_target_update_mode = SubViewport.UPDATE_ONCE
	_current = target
	_foam_step_frame = Engine.get_process_frames()
	_update_atlas_sources()
	rebind()


## Points the atlas copies at the newest states already drawn: a target scheduled in this
## frame is still in flight, so the copy reads its partner (the previous state) instead.
func _update_atlas_sources() -> void:
	if _atlas == null or not is_active():
		return
	var frame := Engine.get_process_frames()
	var foam_index := (1 - _current) if _foam_step_frame == frame else _current
	_atlas_foam_copy.set_shader_parameter(&"source", _viewports[foam_index].get_texture())
	if _atlas_ripple_copy != null:
		var ripple := _ripple_latest
		if _ripple_frame == frame and _ripple_completed != null:
			ripple = _ripple_completed
		_atlas_ripple_copy.set_shader_parameter(&"source", ripple)


func _build_atlas(ripple_texels: int) -> void:
	_release_atlas()
	if sim_size <= 0:
		return
	if _atlas_copy_shader == null:
		_atlas_copy_shader = Shader.new()
		_atlas_copy_shader.code = ATLAS_COPY_CODE
	_atlas_ripple_size = maxi(ripple_texels, 0)
	var layout := atlas_layout(sim_size, _atlas_ripple_size)
	var size: Vector2i = layout["size"]
	_atlas = SubViewport.new()
	_atlas.name = "FoamRippleAtlas"
	_atlas.size = size
	_atlas.use_hdr_2d = true
	_atlas.transparent_bg = false
	_atlas.disable_3d = true
	_atlas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_atlas_foam_copy = _add_atlas_region(0, sim_size, size.y)
	_atlas_ripple_copy = null
	if _atlas_ripple_size > 0:
		_atlas_ripple_copy = _add_atlas_region(sim_size, _atlas_ripple_size, size.y)
	add_child(_atlas)
	_update_atlas_sources()


func _add_atlas_region(x: int, width: int, height: int) -> ShaderMaterial:
	var rect := ColorRect.new()
	rect.position = Vector2(x, 0.0)
	rect.size = Vector2(width, height)
	var material := ShaderMaterial.new()
	material.shader = _atlas_copy_shader
	material.set_shader_parameter(&"offset_x", float(x))
	rect.material = material
	_atlas.add_child(rect)
	return material


func _release_atlas() -> void:
	if _atlas != null:
		remove_child(_atlas)
		_atlas.free()
	_atlas = null
	_atlas_foam_copy = null
	_atlas_ripple_copy = null
	_atlas_ripple_size = 0


func _exit_tree() -> void:
	# Leave the shared sea material as other maps expect it: plain ripples, WR-2 foam.
	var ripple := _ripple_latest
	if ripple == null or _ripple_window.w < 0.5:
		ripple = WATER_MATERIALS.ripple_off_texture()
	unbind_materials(sea_materials, ripple)


## Copies every uniform the step kernel shares with the sea (FFT atlases and cascades,
## chop, wind, shore field and surf, foam weather), so birth and seed read the same sea.
func _mirror_sea_uniforms(material: ShaderMaterial) -> void:
	if source_material == null or source_material.shader == null:
		return
	if _mirrored_uniforms.is_empty():
		var own := {}
		for uniform: Dictionary in source_material.shader.get_shader_uniform_list():
			own[String(uniform["name"])] = true
		for uniform: Dictionary in STEP_SHADER.get_shader_uniform_list():
			var uniform_name := String(uniform["name"])
			if own.has(uniform_name) and uniform_name != "compat_srgb_alpha":
				_mirrored_uniforms.append(uniform_name)
	for uniform_name in _mirrored_uniforms:
		var value: Variant = source_material.get_shader_parameter(uniform_name)
		if value != null:
			material.set_shader_parameter(uniform_name, value)


func mirrored_uniforms() -> PackedStringArray:
	return _mirrored_uniforms


func _param_float(uniform_name: StringName, fallback: float) -> float:
	var value: Variant = source_material.get_shader_parameter(uniform_name)
	return fallback if value == null else float(value)


func _param_vec2(uniform_name: StringName, fallback: Vector2) -> Vector2:
	var value: Variant = source_material.get_shader_parameter(uniform_name)
	return fallback if not value is Vector2 else value


func _focus_xz() -> Vector2:
	if focus_provider.is_valid():
		var focus: Vector3 = focus_provider.call()
		return Vector2(focus.x, focus.z)
	return window_origin + Vector2(window_size, window_size) * 0.5


func _release_viewports() -> void:
	_release_atlas()
	for viewport in _viewports:
		remove_child(viewport)
		viewport.free()
	_viewports.clear()
	_materials.clear()
	_current = 0
