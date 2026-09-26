shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Water stays opaque to sorting, but reads the already-rendered bank and bed to
// simulate transmission. Depth reconstruction makes absorption and distortion
// respond to actual geometry instead of painting another animated blue texture.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 shallow_color : source_color = vec3(0.45, 0.62, 0.75);
uniform vec3 deep_color : source_color = vec3(0.16, 0.30, 0.44);
// The rendered terrain remains the physical bed. These tints layer sediment,
// stones and vegetation over it in stable world space instead of requiring a
// second authored mesh for every underwater material transition.
uniform vec3 sand_bed_color : source_color = vec3(0.62, 0.51, 0.30);
uniform vec3 stone_bed_color : source_color = vec3(0.32, 0.36, 0.35);
uniform vec3 algae_bed_color : source_color = vec3(0.14, 0.28, 0.20);
uniform float bed_vegetation = 1.0;
uniform vec3 deep_bed_color : source_color = vec3(0.035, 0.08, 0.11);
uniform float optical_depth = 0.075;
uniform float caustic_strength = 0.14;
uniform vec3 highlight_color : source_color = vec3(0.396, 0.694, 0.769);
uniform vec3 foam_color : source_color = vec3(0.72, 0.80, 0.78);
uniform float wave_height = 0.032;
uniform float wave_chaos = 1.0;
uniform float wave_speed = 1.0;
// Horizontal Gerstner sharpening. 0 is a sine sheet; ~1 peaks crests the way
// an FFT ocean's choppiness does, without a compute FFT on GL Compatibility.
uniform float choppiness = 0.85;
// 0 travels with the wind; ~0.4 bobs in place for sheltered harbors.
uniform float standing_wave_ratio = 0.12;
uniform float depth_absorption = 7.0;
uniform float refraction_strength = 0.012;
uniform float foam_intensity = 0.22;
uniform float breaker_intensity = 0.35;
// Water2-style dual normal detail without texture memory: two independent
// procedural layers are phase-blended and advected by the optional river flow.
uniform float detail_normal_strength = 0.30;
uniform float detail_normal_scale = 1.0;
// River current: world-XZ flow direction and strength. Zero for still water, so
// sea and pond surfaces are unaffected. Non-zero advects the wave field
// downstream and spawns drifting foam ribbons so a river reads as moving water.
uniform vec2 flow_direction = vec2(0.0, 0.0);
uniform float flow_strength = 0.0;
// Matches sky sun-disk fade / MapView3D day_blend. Defaults keep daytime look
// until apply_water_lighting() pushes the live cycle values.
uniform float sun_visibility = 1.0;
uniform float sun_reflection_visibility = 1.0;
uniform float day_blend = 1.0;
// The water samples the same catalog texture and celestial directions as the
// sky dome. This is cheaper than a planar reflection and stays deterministic.
uniform sampler2D star_map : filter_nearest, repeat_enable;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_reflection_color : source_color = vec3(1.0, 0.92, 0.74);
uniform float moon_visibility = 0.0;
uniform float star_visibility = 0.0;
uniform float observer_latitude = 1.0371;
uniform float sidereal_angle = 3.8101;
// Sky-dome gradient uniforms mirror sky_weather_3d defaults so reflected water
// matches the visible dome without a planar reflection pass.
uniform vec3 day_top_color : source_color = vec3(0.18, 0.38, 0.65);
uniform vec3 day_horizon_color : source_color = vec3(0.67, 0.75, 0.81);
uniform vec3 night_top_color : source_color = vec3(0.020, 0.045, 0.130);
uniform vec3 night_horizon_color : source_color = vec3(0.050, 0.100, 0.220);
uniform vec3 sunset_color : source_color = vec3(0.98, 0.45, 0.18);
uniform float sunset_factor = 0.0;
uniform float cloud_darken = 0.0;
// Coastal terrain receives the live equilibrium tide. River water keeps zero
// response, while shallow/deep sea tune shoreline retreat and optical depth.
uniform float tide_level = 0.0;
uniform float tide_height = 0.0;
uniform float tide_shore_retreat = 0.0;
uniform float tide_optical_depth = 0.0;
// Shared SkyWeather heading. Default matches the authored primary swell axis so
// calm seas keep the pre-P0-226 look until apply_sea_weather() pushes live wind.
uniform vec2 wind_direction = vec2(0.9578, 0.2873);

// WS-04 baked FFT ocean (tools/bake_ocean_fft.py, WS-03). One clock drives the
// sea on GPU and CPU: MapViewRuntimeEnvironment accumulates the scaled world
// delta into ocean_time, so time controls pause waves and boats read the same t.
global uniform float ocean_time;
// WS-08 shore swash (wave sets, breaking bore, run-up sheet, wall slosh).
#include "res://scripts/map/view3d/shore_swash.gdshaderinc"
// True only on the generated beach film (ShoreSwashSheet). It shares every
// other uniform with its source water family through MapViewMaterials.
uniform bool swash_sheet = false;
// Shore wave geometry budget, like fft_geometry_scale: the water column above
// the recessed bed is only a few hundredths of a unit, so crests are compressed
// while foam, turbidity and run-up keep the physical wave.
uniform float shore_geometry_scale = 0.12;
// WS-04 FFT uniforms and sampling live in the shared include (WS-13).
#include "res://scripts/map/view3d/ocean_fft_common.gdshaderinc"

// WS-15 interactive ripples (WaterRippleSim): R = height, G = previous height, B = aeration,
// on a camera-following window. ripple_window = (origin x, origin z, size, valid); valid 0
// (indoors, minimum tier, no sim) turns the whole path off.
uniform sampler2D ripple_state : filter_linear, repeat_disable;
uniform vec4 ripple_window = vec4(0.0, 0.0, 64.0, 0.0);
uniform float ripple_texel_count = 256.0;
// Shading slope per unit of height difference between neighbouring texels.
uniform float ripple_normal_strength = 25.0;
// Geometric lift per unit height. Kept tiny and crest-only: the FFT trough floor leaves just
// 0.0015 units above the recessed bed, and any ripple dip below it z-fights the bed on Metal
// (dark dashed rows in the wake). The normal carries the visible ring and its troughs.
uniform float ripple_vertex_amplitude = 0.004;
uniform float ripple_foam_strength = 0.85;
// Art-direction lever: under flat overcast light a bent normal alone barely changes the
// reflected sky, so ring flanks also catch a little highlight colour (rain reads on water).
uniform float ripple_sheen = 2.0;
// WS-06 whitecaps from the baked foam channel (FFT path only; the Gerstner fallback
// keeps the P0-223 Jacobian foam). foam_tile is the seamless bubble/speckle/streak
// detail from `bake_ocean_fft.py foam-tile`; unset it reads black, so no whitecaps.
uniform sampler2D foam_tile : hint_default_black, filter_linear_mipmap, repeat_enable;
// Tiles per world unit: Tidewater foamScale 0.09 per metre x 0.87 m per unit
// (one tile spans ~11 m). The second layer is 2.3x finer.
uniform float foam_tile_scale = 0.0783;
// Tidewater foamCoverage. The two cascade channels both carry full-sea whitecap
// statistics (WS-03 amendment 2), so the contract started at 0.5; with the capped
// mask the overcast/day plate needed the full 1.0 for scattered whitecaps.
uniform float foam_coverage = 1.0;
uniform float foam_sharpness = 2.2;
// Weather scale of the baked mask (apply_sea_weather: calm 0.2 .. storm 1.8).
uniform float storm_foam_coverage = 0.8;
// WS-06b debug: 1 writes the baked foam mask (fft_foam.x) to ALBEDO/EMISSION so
// Metal vs Compatibility coverage can be compared without lighting or the tile.
uniform float debug_foam_mask = 0.0;
// Wind streaks: storm share (0 calm .. 1 storm) times streak_amount. Tidewater's
// 0.3 vanished under the storm sky reflection on the gameplay camera.
uniform float storm_streaks = 0.0;
uniform float streak_amount = 0.6;
// Catspaws (gust) and glassy slicks: a slow, wind-borne field that scales the
// ripple cascade and the detail normal on every sea state.
uniform float gust_amount = 1.0;
uniform float slick_amount = 1.0;
// One gust lattice cell per ~60 world units.
uniform float gust_scale = 0.0167;
// MapViewRuntimeEnvironment.OCEAN_TIME_WRAP_SECONDS. Every drift below moves a whole
// number of tiles or lattice periods per wrap, so the ocean clock wrap never pops.
const float OCEAN_TIME_WRAP_SECONDS = 1638.4;
// Foam tile drift downwind: ~0.27 m/s and ~0.29 m/s, slow against the wave phase
// speed, so a foam patch still rides its crest.
const float FOAM_DRIFT_A_TILES_PER_WRAP = 40.0;
const float FOAM_DRIFT_B_TILES_PER_WRAP = 100.0;
// Gust field period along the wind (lattice cells) and its drift (~2.3 units/s).
const float GUST_PERIOD_CELLS = 16.0;
const float GUST_DRIFT_CELLS_PER_WRAP = 64.0;
// Highest effective whitecap mask. At 1.0 the darker half of the tile stays open, so the
// freshest foam still reads as clustered bubbles.
const float FOAM_MASK_CAP = 1.0;
// Fraction of the window over which ripples fade out, so the window edge never shows a seam.
const float RIPPLE_EDGE_FADE = 0.1;
// Steepest ripple facet the shading normal may take (about 31 degrees).
const float RIPPLE_MAX_SLOPE = 0.6;

varying vec3 water_world_position;
varying vec2 wave_sample_xz;
varying float shore_factor;
// WS-13b: 1 on in-map water whose rendered sea bed may lie below the flat gameplay
// bed; flat_bed_world_y is that bed plane in world space (from UV2).
varying float flat_bed_flag;
varying float flat_bed_world_y;
// WS-02 inputs for light(), written by fragment(). glint_alpha is the GGX alpha
// (roughness squared) after slope-variance widening. The directional gate covers
// the one DirectionalLight3D, which is the sun by day and the moon by night
// (MapViewLighting slerps it between them). Local lights (torches, forge spill)
// only lose the glint under foam. diffuse_share scales Lambert on ALBEDO.
varying float glint_alpha;
varying float directional_glint_gate;
varying float local_glint_gate;
varying float diffuse_share;

// Tidewater: glints are clamped to 400x so they stay inside fp16 range.
const float GLINT_CLAMP = 400.0;
// sin(-6 deg): MapViewLighting finishes handing the light from moon to sun here.
const float SUN_LIGHT_HANDOFF_Y = -0.1045;

float _hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Value noise that repeats every `period` lattice cells along x, so a drift of a
// whole number of periods is invisible (WS-06 gust field and the ocean clock wrap).
float _noise_periodic_x(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, period);
	float x1 = mod(i.x + 1.0, period);
	return mix(
		mix(_hash(vec2(x0, i.y)), _hash(vec2(x1, i.y)), u.x),
		mix(_hash(vec2(x0, i.y + 1.0)), _hash(vec2(x1, i.y + 1.0)), u.x),
		u.y
	);
}

float _noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(_hash(i), _hash(i + vec2(1.0, 0.0)), u.x),
		mix(_hash(i + vec2(0.0, 1.0)), _hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// Gerstner train. displacement is (dx, height, dz) before wave_height.
// normal_terms is (dh/dx, crest fold, dh/dz), also before wave_height.
// Keep the wavelengths and phases locked with BoatFloat3D.sample_wave.
void _accumulate_wave(
	vec2 position,
	vec2 direction,
	float frequency,
	float speed,
	float amplitude,
	float time,
	vec2 warp,
	float phase_offset,
	inout vec3 displacement,
	inout vec3 normal_terms
) {
	vec2 heading = normalize(direction);
	float spatial = dot(position + warp, heading) * frequency + phase_offset;
	float travel_s = sin(spatial - time * speed);
	float travel_c = cos(spatial - time * speed);
	float standing_s = sin(spatial) * sin(time * speed);
	float standing_c = cos(spatial) * sin(time * speed);
	float standing = clamp(standing_wave_ratio, 0.0, 1.0);
	float wave_s = mix(travel_s, standing_s, standing);
	float wave_c = mix(travel_c, standing_c, standing);
	// Sheltered water bobs more than it shears, so chop falls as standing rises.
	float chop = max(choppiness, 0.0) * (1.0 - standing * 0.65);
	displacement.x += chop * amplitude * heading.x * wave_c;
	displacement.y += amplitude * wave_s;
	displacement.z += chop * amplitude * heading.y * wave_c;
	float slope = frequency * amplitude * wave_c;
	normal_terms.x += heading.x * slope;
	normal_terms.y += chop * frequency * amplitude * wave_s;
	normal_terms.z += heading.y * slope;
}

vec2 _wave_heading(vec2 base_direction) {
	vec2 ref = normalize(vec2(1.0, 0.28));
	vec2 wind = wind_direction / max(length(wind_direction), 0.001);
	float angle = atan(wind.y, wind.x) - atan(ref.y, ref.x);
	float c = cos(angle);
	float s = sin(angle);
	vec2 dir = normalize(base_direction);
	return vec2(dir.x * c - dir.y * s, dir.x * s + dir.y * c);
}

// Three bands stand in for a JONSWAP FFT on GL Compatibility: swell and wind
// waves displace the mesh, ripples stay in the detail normal. Wavelengths stay
// longer than the 1/3-cell water grid so crests are geometric, not aliased.
void _water_field(vec2 position, float time, out vec3 displacement, out vec3 normal_terms) {
	vec2 drift = vec2(time * 0.035, -time * 0.021);
	vec2 warp_position = position * 0.115 + drift;
	vec2 warp = vec2(
		_noise(warp_position + vec2(17.2, -8.4)),
		_noise(warp_position * 0.83 + vec2(-11.7, 23.9))
	) - vec2(0.5);
	vec2 fine_warp = vec2(
		_noise(position * 0.31 + vec2(-time * 0.052, time * 0.018) + vec2(43.1, 7.6)),
		_noise(position * 0.27 + vec2(time * 0.024, time * 0.047) + vec2(-19.4, 31.8))
	) - vec2(0.5);
	warp = (warp * 2.8 + fine_warp * 0.65) * wave_chaos;

	float amplitude_noise = _noise(position * 0.16 + drift * 1.7 + vec2(5.3, 41.2));
	float amplitude_variation = mix(0.72, 1.22, amplitude_noise);
	displacement = vec3(0.0);
	normal_terms = vec3(0.0);
	// Swell: ~9 m and ~6 m, the scale a harbor camera can actually read.
	_accumulate_wave(position, _wave_heading(vec2(1.0, 0.28)), 0.62, 0.48, 0.62, time, warp, 0.3, displacement, normal_terms);
	_accumulate_wave(position, _wave_heading(vec2(0.82, 0.55)), 0.91, 0.61, 0.28, time, warp * 0.8, 1.7, displacement, normal_terms);
	// Wind waves: a few meters, still sampled by the subdivided water grid.
	_accumulate_wave(position, _wave_heading(vec2(0.36, 1.0)), 1.85, 1.05, 0.16, time, warp * 0.72, 2.1, displacement, normal_terms);
	_accumulate_wave(position, _wave_heading(vec2(-0.55, 0.84)), 2.70, 1.40, 0.08, time, fine_warp * wave_chaos, 4.2, displacement, normal_terms);
	displacement *= amplitude_variation;
	normal_terms *= amplitude_variation;
}

// Horizontal displacement Jacobian for crest whitecaps. Mirrors _water_field warp
// and wave trains; warp derivatives are omitted like common FFT-ocean stand-ins.
void _accumulate_wave_jacobian(
	vec2 position,
	vec2 direction,
	float frequency,
	float speed,
	float amplitude,
	float time,
	vec2 warp,
	float phase_offset,
	inout vec4 jacobian_terms
) {
	vec2 heading = normalize(direction);
	float spatial = dot(position + warp, heading) * frequency + phase_offset;
	float phase_travel = spatial - time * speed;
	float standing = clamp(standing_wave_ratio, 0.0, 1.0);
	float d_spatial_dx = heading.x * frequency;
	float d_spatial_dz = heading.y * frequency;
	float travel_ds_dx = cos(phase_travel) * d_spatial_dx;
	float travel_ds_dz = cos(phase_travel) * d_spatial_dz;
	float travel_dc_dx = -sin(phase_travel) * d_spatial_dx;
	float travel_dc_dz = -sin(phase_travel) * d_spatial_dz;
	float stand_ds_dx = cos(spatial) * sin(time * speed) * d_spatial_dx;
	float stand_ds_dz = cos(spatial) * sin(time * speed) * d_spatial_dz;
	float stand_dc_dx = -sin(spatial) * sin(time * speed) * d_spatial_dx;
	float stand_dc_dz = -sin(spatial) * sin(time * speed) * d_spatial_dz;
	float ds_dx = mix(travel_ds_dx, stand_ds_dx, standing);
	float ds_dz = mix(travel_ds_dz, stand_ds_dz, standing);
	float dc_dx = mix(travel_dc_dx, stand_dc_dx, standing);
	float dc_dz = mix(travel_dc_dz, stand_dc_dz, standing);
	float chop = max(choppiness, 0.0) * (1.0 - standing * 0.65);
	float ax = chop * amplitude * heading.x;
	float az = chop * amplitude * heading.y;
	jacobian_terms.x += ax * dc_dx;
	jacobian_terms.y += ax * dc_dz;
	jacobian_terms.z += az * dc_dx;
	jacobian_terms.w += az * dc_dz;
}

float _water_jacobian(vec2 position, float time) {
	vec2 drift = vec2(time * 0.035, -time * 0.021);
	vec2 warp_position = position * 0.115 + drift;
	vec2 warp = vec2(
		_noise(warp_position + vec2(17.2, -8.4)),
		_noise(warp_position * 0.83 + vec2(-11.7, 23.9))
	) - vec2(0.5);
	vec2 fine_warp = vec2(
		_noise(position * 0.31 + vec2(-time * 0.052, time * 0.018) + vec2(43.1, 7.6)),
		_noise(position * 0.27 + vec2(time * 0.024, time * 0.047) + vec2(-19.4, 31.8))
	) - vec2(0.5);
	warp = (warp * 2.8 + fine_warp * 0.65) * wave_chaos;
	float amplitude_noise = _noise(position * 0.16 + drift * 1.7 + vec2(5.3, 41.2));
	float amplitude_variation = mix(0.72, 1.22, amplitude_noise);
	vec4 jacobian_terms = vec4(0.0);
	_accumulate_wave_jacobian(position, _wave_heading(vec2(1.0, 0.28)), 0.62, 0.48, 0.62, time, warp, 0.3, jacobian_terms);
	_accumulate_wave_jacobian(position, _wave_heading(vec2(0.82, 0.55)), 0.91, 0.61, 0.28, time, warp * 0.8, 1.7, jacobian_terms);
	_accumulate_wave_jacobian(position, _wave_heading(vec2(0.36, 1.0)), 1.85, 1.05, 0.16, time, warp * 0.72, 2.1, jacobian_terms);
	_accumulate_wave_jacobian(position, _wave_heading(vec2(-0.55, 0.84)), 2.70, 1.40, 0.08, time, fine_warp * wave_chaos, 4.2, jacobian_terms);
	jacobian_terms *= amplitude_variation;
	return (1.0 + jacobian_terms.x) * (1.0 + jacobian_terms.w)
		- jacobian_terms.y * jacobian_terms.z;
}

// A finite-difference slope is a small procedural stand-in for a sampled normal
// map. Keeping the samples in world space makes detail continuous across the
// separate water meshes generated for each terrain cell.
vec2 _detail_gradient(vec2 position) {
	float sample_step = 0.07;
	return vec2(
		_noise(position + vec2(sample_step, 0.0)) - _noise(position - vec2(sample_step, 0.0)),
		_noise(position + vec2(0.0, sample_step)) - _noise(position - vec2(0.0, sample_step))
	) / (sample_step * 2.0);
}

// Water2-style dual scrolling detail: each layer has its own frequency, phase
// and scroll vector, while river current advects both layers downstream. This
// affects shading only; the physical displacement remains _water_shape() so
// boats and visuals continue to share the existing wave field.
vec3 _water_detail_normal(vec2 position, float time) {
	float scale = max(detail_normal_scale, 0.1);
	vec2 current_offset = flow_direction * (flow_strength * time * 0.42);
	vec2 layer_a = position * scale * 1.7 - current_offset;
	layer_a += vec2(-time * 0.19, time * 0.13) + vec2(12.4, -4.7);
	vec2 layer_b = position * scale * 3.9 - current_offset * 1.65;
	layer_b += vec2(time * 0.27, -time * 0.23) + vec2(-21.8, 16.1);
	vec2 slope = _detail_gradient(layer_a) * 0.58 + _detail_gradient(layer_b) * 0.42;
	return normalize(vec3(-slope.x * 0.18, 1.0, -slope.y * 0.18));
}

// Deterministic world-space masks keep the bed continuous across authored water
// terrain borders. The weights always sum to one, so depth changes material
// dominance instead of stacking four opaque color filters.
vec4 _seabed_layers(vec2 position, float water_depth) {
	float broad = _noise(position * 0.12 + vec2(31.7, -14.2));
	float broken = _noise(position * 0.46 + vec2(-9.3, 27.1));
	float detail = _noise(position * 1.85 + vec2(4.6, 18.8));
	float deep_weight = smoothstep(0.20, 0.34, water_depth);
	float shallow_weight = 1.0 - deep_weight;
	float stone_weight = smoothstep(0.56, 0.78, broken * 0.72 + detail * 0.28) * shallow_weight;
	float algae_depth = smoothstep(0.06, 0.16, water_depth) * (1.0 - smoothstep(0.30, 0.46, water_depth));
	// Sparse algae can tint an authentic shallow bed, but it must never read as
	// the terrestrial grass layer continuing below a pond or harbour surface.
	float algae_weight = smoothstep(0.48, 0.72, broad * 0.68 + broken * 0.32) * algae_depth * bed_vegetation * 0.22;
	float sand_weight = max(shallow_weight - stone_weight - algae_weight, 0.08 * shallow_weight);
	float shallow_total = max(sand_weight + stone_weight + algae_weight, 0.0001);
	vec3 shallow_layers = vec3(sand_weight, stone_weight, algae_weight) / shallow_total;
	return vec4(shallow_layers * shallow_weight, deep_weight);
}

float _bed_caustics(vec2 position, float time) {
	vec2 flow = position * 2.35 + vec2(time * 0.10, -time * 0.065);
	float crossing = sin(flow.x + sin(flow.y * 1.37)) + cos(flow.y + sin(flow.x * 1.19));
	return pow(clamp(1.0 - abs(crossing) * 0.56, 0.0, 1.0), 5.0);
}

float _view_depth(vec2 screen_uv, float raw_depth, mat4 inverse_projection) {
	// GL Compatibility uses OpenGL NDC, whose Z range is -1..1.
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth * 2.0 - 1.0);
	vec4 view_position = inverse_projection * vec4(ndc, 1.0);
	return -view_position.z / view_position.w;
}

// WS-13b: view depth where this pixel's eye ray meets the flat gameplay bed plane,
// decoded through the same raw-depth round trip as a depth-buffer sample so the
// result matches what the old flat bed wrote (on either renderer). Rays that do
// not descend (camera under the surface looking up) return a far value.
float _flat_bed_view_depth(
	vec3 view_vertex, float bed_world_y, vec2 screen_uv, mat4 projection,
	mat4 inverse_projection, mat4 inverse_view
) {
	bool orthographic = abs(projection[2][3]) < 0.5;
	vec3 ray = orthographic ? vec3(0.0, 0.0, -1.0) : normalize(view_vertex);
	float ray_world_y = (inverse_view * vec4(ray, 0.0)).y;
	float drop = (inverse_view * vec4(view_vertex, 1.0)).y - bed_world_y;
	if (ray_world_y > -0.0001 || drop <= 0.0) {
		return 1.0e9;
	}
	vec4 clip = projection * vec4(view_vertex + ray * (drop / -ray_world_y), 1.0);
	float ndc_z = clip.z / clip.w;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	float raw_depth = ndc_z * 0.5 + 0.5;
	#else
	float raw_depth = ndc_z;
	#endif
	return _view_depth(screen_uv, raw_depth, inverse_projection);
}

// Kept identical to the sky shader projection so constellations reflected in
// the water occupy the same astronomical positions as the visible sky dome.
vec2 _equatorial_uv(vec3 direction) {
	float north = -direction.z;
	float east = direction.x;
	float up = direction.y;
	float sin_lat = sin(observer_latitude);
	float cos_lat = cos(observer_latitude);
	float sin_dec = clamp(up * sin_lat + north * cos_lat, -1.0, 1.0);
	float declination = asin(sin_dec);
	float hour_angle = atan(-east, up * cos_lat - north * sin_lat);
	float right_ascension = sidereal_angle - hour_angle;
	return vec2(fract(right_ascension / TAU), 0.5 - declination / PI);
}

// Bounded analytic sky-dome color for reflected rays. Matches the sky shader's
// gradient path (without marching clouds) so fresnel reflections track the dome.
vec3 _sky_dome_gradient(vec3 dir) {
	float height = dir.y;
	vec3 top = mix(night_top_color, day_top_color, day_blend);
	vec3 horizon = mix(night_horizon_color, day_horizon_color, day_blend);
	float sun_amount = max(dot(dir, normalize(sun_direction)), 0.0);
	horizon = mix(horizon, sunset_color, sunset_factor * pow(sun_amount, 2.0) * 0.8);
	float air_mass = 1.0 / max(height + 0.12, 0.12);
	float haze = 1.0 - exp(-air_mass * (0.10 + cloud_darken * 0.12));
	vec3 color = mix(top, horizon, haze);
	float forward_scatter = pow(sun_amount, 12.0) * (0.06 + haze * 0.20);
	color += mix(sun_reflection_color, sunset_color, sunset_factor)
		* forward_scatter * day_blend * (1.0 - cloud_darken * 0.8);
	color = mix(color, horizon * vec3(0.83, 0.87, 0.93), cloud_darken * 0.38);
	color = mix(color, horizon * 0.55, clamp(-height * 3.0, 0.0, 1.0));
	return color;
}

// WS-06 catspaws and slicks: gain for the ripple cascade and the detail normal.
// Above 1 a gust roughens the water into a dark patch; below 1 a slick flattens it
// into a glassy streak that mirrors the sky. Lives in the wind frame and drifts
// downwind, so the patches cross the water with the wind.
float _sea_gust(vec2 world_xz) {
	vec2 p = _fft_to_wind(world_xz, _fft_wind_axis()) * gust_scale;
	float drift = ocean_time * GUST_DRIFT_CELLS_PER_WRAP / OCEAN_TIME_WRAP_SECONDS;
	float n = _noise_periodic_x(p - vec2(drift, 0.0), GUST_PERIOD_CELLS) * 0.7
		+ _noise_periodic_x(p * 3.0 - vec2(drift * 3.0, 0.0) + vec2(0.0, 7.3), GUST_PERIOD_CELLS * 3.0) * 0.3;
	float gust = smoothstep(0.52, 0.72, n);
	float slick = 1.0 - smoothstep(0.30, 0.46, n);
	return 1.0 + gust_amount * 0.4 * gust - slick_amount * 0.6 * slick;
}

vec2 _ripple_uv(vec2 world_xz) {
	return (world_xz - ripple_window.xy) / max(ripple_window.z, 0.001);
}

// 0 outside the window or with the sim off, 1 inside, fading near the window edge.
float _ripple_weight(vec2 uv) {
	vec2 edge = min(uv, vec2(1.0) - uv);
	return ripple_window.w * smoothstep(0.0, RIPPLE_EDGE_FADE, min(edge.x, edge.y));
}

// WS-02 specular terms (Tidewater water material). a2 is GGX alpha squared.
float _d_ggx(float n_dot_h, float a2) {
	float d = n_dot_h * n_dot_h * (a2 - 1.0) + 1.0;
	return a2 / (PI * d * d);
}

// Height-correlated Smith visibility; already divided by 4 NdL NdV.
float _v_smith_ggx_correlated(float n_dot_l, float n_dot_v, float a2) {
	float ggx_v = n_dot_l * sqrt(n_dot_v * n_dot_v * (1.0 - a2) + a2);
	float ggx_l = n_dot_v * sqrt(n_dot_l * n_dot_l * (1.0 - a2) + a2);
	return 0.5 / max(ggx_v + ggx_l, 1e-5);
}

// Exact unpolarised dielectric Fresnel. WHY not Schlick: Schlick overshoots at
// the grazing angles the gameplay camera sees most of the sea from.
float _fresnel_dielectric(float cos_theta, float ior) {
	float c = clamp(cos_theta, 0.0, 1.0);
	float g = sqrt(ior * ior - 1.0 + c * c);
	float a = (g - c) / (g + c);
	float b = (c * (g + c) - 1.0) / (c * (g - c) + 1.0);
	return 0.5 * a * a * (1.0 + b * b);
}

void vertex() {
	vec3 undisplaced_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wave_sample_xz = undisplaced_world.xz;
	shore_factor = clamp(COLOR.r, 0.0, 1.0);
	flat_bed_flag = step(0.5, UV2.x);
	flat_bed_world_y = (MODEL_MATRIX * vec4(VERTEX.x, UV2.y, VERTEX.z, 1.0)).y;
	// Processor functions cannot return early; the sheet restores this at the end.
	vec3 rest_vertex = VERTEX;
	// Advect the wave field downstream so ripples travel along the current.
	vec2 flow_advection = flow_direction * (flow_strength * TIME * wave_speed * 0.6);
	vec3 displacement = vec3(0.0);
	vec3 normal_terms = vec3(0.0);
	if (use_fft) {
		// FFT replaces wave_height; wave_height stays the Gerstner amplitude only.
		// Foam is resampled in fragment(): GL vertex atlas alpha is not trusted.
		displacement = _fft_displacement(wave_sample_xz).xyz;
	} else {
		_water_field(wave_sample_xz - flow_advection, TIME * wave_speed, displacement, normal_terms);
		displacement *= wave_height;
	}
	// Low tide withdraws the clipped coastal edge instead of requiring a second
	// authored shoreline mesh. High tide reaches the original maximum contour.
	// The fragment stage clips the retreat band. Vertices rise and also shift
	// horizontally so crests peak instead of staying a displaced sine sheet.
	// Keep clipped patch seams pinned, but let the crest rise almost all the way
	// into the shallows. The old broad fade erased waves before they reached land.
	float displacement_fade = smoothstep(0.0, 0.16, shore_factor);
	float shoaling = mix(1.32, 1.0, smoothstep(0.0, 0.65, shore_factor));
	displacement *= displacement_fade * shoaling;
	if (use_fft) {
		// WHY: the recessed bed sits only WATER_SURFACE_LIFT (0.006 units) below
		// the rest surface, so any trough exposes it. Troughs ease into a floor
		// just above the bed while crests keep their full height: broad troughs,
		// sharp crests. The shading normal still carries the full trough slope.
		// WS-05 hull sampling must apply the same floor to stay seated.
		if (displacement.y < 0.0) {
			displacement.y = -FFT_TROUGH_FLOOR * (1.0 - exp(displacement.y / FFT_TROUGH_FLOOR));
		}
	}
	if (ripple_window.w > 0.5) {
		vec2 ripple_uv = _ripple_uv(wave_sample_xz);
		float ripple_h = textureLod(ripple_state, ripple_uv, 0.0).r * ripple_vertex_amplitude;
		displacement.y += max(ripple_h * _ripple_weight(ripple_uv), 0.0);
	}
	if (shore_field_valid > 0.5 && shore_strength > 0.0) {
		ShoreState shore = shore_state(undisplaced_world.xz, ocean_time, shore_sea());
		// Crests and the wall slosh only rise: a trough would expose the recessed
		// bed, so the slosh reads as water climbing the wall and falling back to
		// rest. The crest top curls towards land.
		float shore_lift = (shore.height + max(shore.slosh, 0.0)) * shore_geometry_scale;
		displacement.y += shore_lift * shore.valid;
		displacement.xz += shore.to_land * shore.curl * shore_geometry_scale * shore.valid;
	}
	VERTEX.x += displacement.x;
	VERTEX.y += tide_height * tide_level + displacement.y;
	VERTEX.z += displacement.z;
	water_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (swash_sheet) {
		// The film lies on the sand; the ocean displacement must not lift it.
		VERTEX = rest_vertex;
		water_world_position = undisplaced_world;
	}
}

void fragment() {
	// WS-06b: per-pixel baked foam. Do not read a vertex varying; GL Compatibility
	// vertex fetches from the compressed disp arrays often drop the alpha.
	vec3 fft_foam = vec3(0.0);
	// WS-08 beach film. Processor functions cannot return early, so the film is
	// shaded into locals here and replaces the ocean outputs at the end.
	ShoreState sheet;
	vec3 sheet_normal = vec3(0.0, 0.0, 1.0);
	vec3 sheet_albedo = vec3(0.0);
	float sheet_alpha = 0.0;
	// WS-02: 0.22 is GGX alpha ~0.05, a wet film just rougher than calm sea.
	float sheet_roughness = 0.22;
	float sheet_foam = 0.0;
	if (swash_sheet) {
		// WS-08 beach film: exists only where the analytic swash currently covers
		// the sand. It is a thin, mostly transparent layer: the wet sand below is
		// already darkened by the terrain pass, so the film adds the extinction
		// tint, a strong Fresnel sky reflection, the sun glint and the front foam.
		sheet = shore_state(water_world_position.xz, ocean_time, shore_sea());
		if (sheet.valid * sheet.beach < 0.01 || sheet.wet < 0.5) {
			discard;
		}
		vec3 film_normal = normalize(mix(
			vec3(0.0, 1.0, 0.0), _water_detail_normal(water_world_position.xz, TIME * wave_speed), 0.35
		));
		vec3 film_view_normal = normalize((VIEW_MATRIX * vec4(film_normal, 0.0)).xyz);
		sheet_normal = film_view_normal;
		float film_facing = clamp(dot(film_view_normal, normalize(VIEW)), 0.0, 1.0);
		float film_fresnel = 0.02 + 0.98 * pow(1.0 - film_facing, 5.0);
		vec3 film_world_view = normalize((INV_VIEW_MATRIX * vec4(normalize(VIEW), 0.0)).xyz);
		vec3 film_sky_ray = normalize(reflect(-film_world_view, film_normal));
		vec3 film_sky = _sky_dome_gradient(film_sky_ray) * smoothstep(-0.01, 0.06, film_sky_ray.y);
		// Spectral extinction over the sheet thickness (metres -> world units).
		vec3 film_transmission = exp(
			-(sheet.sheet_thickness / SHORE_METERS_PER_UNIT) * depth_absorption * vec3(1.28, 0.72, 0.40) * 6.0
		);
		vec3 film_color = mix(shallow_color * 0.55, sand_bed_color * 0.7, film_transmission);
		film_color = mix(film_color, film_sky, clamp(0.30 + film_fresnel * 0.9, 0.0, 0.9));
		// WS-02: the film's sun glint comes from light() like the sea's.
		// Meniscus: the last SHORE_MENISCUS units bend down to the sand, so the edge
		// fades and darkens instead of ending on a cut polygon line.
		float meniscus = smoothstep(0.0, SHORE_MENISCUS, sheet.front_distance);
		film_color *= mix(0.78, 1.0, meniscus);
		float film_alpha = clamp(0.28 + sheet.sheet_thickness * 9.0 + film_fresnel * 0.45, 0.0, 0.8);
		film_alpha *= meniscus;
		float film_foam = clamp(sheet.front_foam * 1.2, 0.0, 1.0);
		film_foam *= smoothstep(0.0, 0.03, sheet.front_distance);
		sheet_albedo = mix(film_color, mix(foam_color, vec3(0.93, 0.95, 0.94), 0.6), film_foam);
		sheet_alpha = max(film_alpha, film_foam * 0.92);
		sheet_roughness = mix(0.22, 0.6, film_foam);
		sheet_foam = film_foam;
	}
	float tide_coverage = tide_shore_retreat * max(-tide_level, 0.0);
	if (shore_factor < tide_coverage) {
		discard;
	}
	// WS-08: one shore evaluation per fragment feeds the surf turbidity and the
	// bore / wall foam below. Rivers (shore_strength 0) and maps without a sea
	// shoreline keep the previous breaker bands.
	bool shore_live = shore_field_valid > 0.5 && shore_strength > 0.0;
	float swash_bore = 0.0;
	ShoreState shore_now;
	if (shore_live) {
		shore_now = shore_state(wave_sample_xz, ocean_time, shore_sea());
	}
	// Sample the undisplaced XZ. Evaluating Gerstner at the chopped position
	// feeds the displacement back into itself and swims the normal off the crest.
	vec2 flow_advection = flow_direction * (flow_strength * TIME * wave_speed * 0.6);
	vec3 displacement = vec3(0.0);
	vec3 normal_terms = vec3(0.0);
	vec3 world_normal = vec3(0.0, 1.0, 0.0);
	// Crest fold feeding the crest SSS glow: Gerstner normal_terms.y on the
	// fallback path, the FFT Jacobian 1 - (1 + Jx)(1 + Jz) on the FFT path.
	float crest_term = 0.0;
	// Pixel footprint in world units, taken in uniform control flow so the FFT
	// LOD and cascade fade stay valid inside the branch below.
	vec2 pixel_footprint = fwidth(wave_sample_xz);
	// WS-06 gust/slick gain; 1 on the Gerstner fallback (rivers, ponds).
	float sea_gust = 1.0;
	if (use_fft) {
		sea_gust = _sea_gust(wave_sample_xz);
		world_normal = _fft_normal_gust(
			wave_sample_xz, max(pixel_footprint.x, pixel_footprint.y), sea_gust, crest_term
		);
	} else {
		_water_field(wave_sample_xz - flow_advection, TIME * wave_speed, displacement, normal_terms);
		float crest_lift = max(1.0 - normal_terms.y * wave_height, 0.15);
		world_normal = normalize(vec3(
			-normal_terms.x * wave_height,
			crest_lift,
			-normal_terms.z * wave_height
		));
		crest_term = normal_terms.y;
	}
	// Layer two independently scrolling detail normals over the broad wave normal.
	// The low-sun relief clamp still applies below, preventing sharp glint bands at
	// sunrise while preserving the small-scale broken reflection at daytime angles.
	vec3 detail_normal = _water_detail_normal(water_world_position.xz, TIME * wave_speed);
	world_normal = normalize(mix(world_normal, detail_normal, clamp(detail_normal_strength * sea_gust, 0.0, 1.0)));
	// WS-15: ripple slopes from central differences, added on top of the FFT and detail
	// normals so rings bend reflections and glints. Aeration feeds the foam mask below.
	float ripple_aeration = 0.0;
	float ripple_slope_length = 0.0;
	if (ripple_window.w > 0.5) {
		vec2 ripple_uv = _ripple_uv(wave_sample_xz);
		float ripple_weight = _ripple_weight(ripple_uv);
		vec2 ripple_du = vec2(1.0 / max(ripple_texel_count, 1.0), 0.0);
		float ripple_hx = textureLod(ripple_state, ripple_uv + ripple_du.xy, 0.0).r
			- textureLod(ripple_state, ripple_uv - ripple_du.xy, 0.0).r;
		float ripple_hz = textureLod(ripple_state, ripple_uv + ripple_du.yx, 0.0).r
			- textureLod(ripple_state, ripple_uv - ripple_du.yx, 0.0).r;
		vec2 ripple_slope = vec2(ripple_hx, ripple_hz) * (0.5 * ripple_normal_strength * ripple_weight);
		// A hull crest can be several times a raindrop ring; unbounded slopes lay the normal
		// flat and mirror the dark lower hemisphere as black streaks.
		ripple_slope /= max(1.0, length(ripple_slope) / RIPPLE_MAX_SLOPE);
		world_normal = normalize(world_normal + vec3(-ripple_slope.x, 0.0, -ripple_slope.y));
		ripple_slope_length = length(ripple_slope);
		ripple_aeration = textureLod(ripple_state, ripple_uv, 0.0).b * ripple_weight;
	}
	// Low-angle sunlight turns tiny animated normal changes into long, fast
	// specular bands. Keep the physical wave displacement, but reduce only the
	// shading normal relief near the horizon; the blend widens the sunrise and
	// sunset transition instead of switching the highlight on frame-to-frame.
	float sun_height_stability = smoothstep(0.03, 0.28, abs(sun_direction.y));
	float direct_normal_relief = mix(0.24, 0.80, sun_height_stability);
	vec3 calm_normal = normalize(mix(vec3(0.0, 1.0, 0.0), world_normal, direct_normal_relief));
	vec3 view_normal = normalize((VIEW_MATRIX * vec4(calm_normal, 0.0)).xyz);
	NORMAL = view_normal;

	float surface_depth = max(-VERTEX.z, 0.0001);
	float raw_scene_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	float scene_depth = _view_depth(SCREEN_UV, raw_scene_depth, INV_PROJECTION_MATRIX);
	if (flat_bed_flag > 0.5) {
		// WS-13b: the rendered sea bed lies metres below the flat gameplay bed.
		// Every optical term below was tuned against that flat bed, so the column
		// is measured to it: identical top-down water, real depth for cameras
		// under the surface (UnderwaterPass reads the raw depth buffer).
		scene_depth = min(scene_depth, _flat_bed_view_depth(
			VERTEX, flat_bed_world_y, SCREEN_UV, PROJECTION_MATRIX, INV_PROJECTION_MATRIX,
			INV_VIEW_MATRIX
		));
	}
	float geometric_depth = max(scene_depth - surface_depth, 0.0);
	// Authored water cells share a flat gameplay bed. Their existing absorption
	// profiles also select a minimum optical column, so shallow/river/deep water
	// remain distinct while geometric depth still controls bank intersections,
	// refraction safety and edge foam.
	float terrain_optical_depth = optical_depth + max(depth_absorption - 5.0, 0.0) * 0.055;
	// Rising coastal water hides more of the layered bed; ebbing water exposes it.
	// Rivers use a zero tide_optical_depth profile and remain unchanged.
	terrain_optical_depth = max(terrain_optical_depth + tide_level * tide_optical_depth, 0.018);
	float water_depth = max(geometric_depth, terrain_optical_depth);

	// Distort only samples that remain behind the surface. This suppresses the
	// familiar refraction halo that otherwise pulls dry bank pixels into water.
	float depth_fade = smoothstep(0.0, 0.11, geometric_depth);
	vec2 refracted_uv = clamp(
		SCREEN_UV + view_normal.xy * refraction_strength * depth_fade,
		vec2(0.001),
		vec2(0.999)
	);
	float refracted_depth = _view_depth(
		refracted_uv,
		textureLod(depth_texture, refracted_uv, 0.0).r,
		INV_PROJECTION_MATRIX
	);
	if (refracted_depth <= surface_depth + 0.002) {
		refracted_uv = SCREEN_UV;
	}
	vec3 floor_color = textureLod(screen_texture, refracted_uv, 0.0).rgb;

	// Sand dominates illuminated shallows, stones break it into cool patches,
	// algae occupies sheltered mid-depth water, and the final layer suppresses
	// all bed detail once little daylight reaches the floor. The actual rendered
	// floor remains visible below the tint, preserving quays, props and authored
	// bank materials seen through the surface.
	vec4 bed_layers = _seabed_layers(water_world_position.xz, water_depth);
	vec3 shallow_bed = (
		sand_bed_color * bed_layers.x
		+ stone_bed_color * bed_layers.y
		+ algae_bed_color * bed_layers.z
	);
	vec3 layered_bed = mix(shallow_bed, deep_bed_color, bed_layers.w);
	// The rendered terrain is physical geometry, but its grass texture should only
	// survive as a restrained hint right at a clear, shallow edge. Otherwise the
	// map's flat recessed bed makes it look like a meadow continues under water.
	float bed_detail_visibility = exp(-water_depth * 9.5) * 0.18;
	vec3 seabed = mix(layered_bed, floor_color * layered_bed * 1.18, bed_detail_visibility);

	// Wavelength-dependent transmission removes red first and blue last. This
	// creates depth lighting variation rather than uniformly darkening RGB.
	vec3 spectral_transmission = exp(-water_depth * depth_absorption * vec3(1.28, 0.72, 0.40));
	float absorption = 1.0 - dot(spectral_transmission, vec3(0.333333));
	vec3 transmitted = seabed * spectral_transmission;
	vec3 water_color = transmitted + deep_color * (vec3(1.0) - spectral_transmission) * 0.82;
	water_color = mix(water_color, shallow_color, (1.0 - absorption) * 0.12);
	if (shore_live) {
		// Breaking waves stir sand into the surf zone.
		water_color = mix(water_color, sand_bed_color * 0.9, SHORE_TURBIDITY * shore_now.surf_zone * shore_now.valid);
	}

	// Caustics belong to the floor, so they fade with both depth and night. Keeping
	// the pattern in world space avoids UV seams between separate water materials.
	// The sun-disk visibility ramp is intentionally not used here: it spans only
	// a few degrees around the horizon and makes animated wave normals look like
	// a sudden band of moving illumination at sunrise and sunset. The wider solar
	// envelope keeps the transition visually continuous while the floor still
	// goes dark at night.
	float twilight_water_light = smoothstep(-0.25, 0.25, sun_direction.y);
	float caustic_visibility = exp(-water_depth * 7.0) * (1.0 - bed_layers.w) * twilight_water_light;
	float caustics = _bed_caustics(water_world_position.xz, TIME * wave_speed);
	water_color += highlight_color * caustics * caustic_visibility * caustic_strength;

	// WS-06 whitecaps. The baked mask decides where foam is; the foam tile, sampled at
	// the undisplaced wave_sample_xz (in the wind frame) so it rides the surface,
	// decides what it looks like: bubble clusters appear first where the tile is
	// bright, and the patch thins back into them as the baked foam decays.
	float whitecap = 0.0;
	float whitecap_fresh = 0.0;
	float wind_streak = 0.0;
	if (use_fft && !swash_sheet) {
		fft_foam = _fft_foam_terms(wave_sample_xz);
		vec2 whitecap_uv = _fft_to_wind(wave_sample_xz, _fft_wind_axis()) * foam_tile_scale;
		vec2 foam_drift_a = vec2(ocean_time * FOAM_DRIFT_A_TILES_PER_WRAP / OCEAN_TIME_WRAP_SECONDS, 0.0);
		vec2 foam_drift_b = vec2(ocean_time * FOAM_DRIFT_B_TILES_PER_WRAP / OCEAN_TIME_WRAP_SECONDS, 0.0);
		vec4 tile_a = texture(foam_tile, whitecap_uv - foam_drift_a);
		vec4 tile_b = texture(foam_tile, whitecap_uv * 2.3 + vec2(0.37, 0.61) - foam_drift_b);
		float foam_texture = mix(tile_a.r, tile_b.r, 0.5) * mix(0.7, 1.0, tile_a.g);
		// Capped so even a storm crest keeps bubble holes instead of a flat white sheet.
		float foam_mask = min(fft_foam.x * storm_foam_coverage * foam_coverage, FOAM_MASK_CAP);
		whitecap = clamp((foam_mask - (1.0 - foam_texture)) * foam_sharpness, 0.0, 1.0);
		// Storm streaks: the tile's B channel is stretched 6:1 along +X, which is
		// downwind in the wind frame. The coarse C0 mask links them to whitecaps.
		float streak_link = smoothstep(0.02, 0.3, fft_foam.z * storm_foam_coverage);
		float open_water = smoothstep(0.14, 0.48, shore_factor) * smoothstep(0.03, 0.10, geometric_depth);
		// Streak foam floats on the surface, so it is laid on as white foam below
		// instead of the sunk tint of old whitecap foam.
		wind_streak = clamp(tile_a.b * streak_amount * storm_streaks * streak_link, 0.0, 1.0) * open_water;
		whitecap *= open_water;
		// The bake decays foam over time: a high raw value just broke (bright,
		// opaque), a low one is old foam, thin and sunk under the surface.
		// A rougher sea breaks more often than the reference bake, so the weather scale
		// also lowers the bar for foam to count as freshly broken.
		whitecap_fresh = whitecap * smoothstep(0.35, 0.8, fft_foam.y * storm_foam_coverage);
		// The decayed tail of the baked foam falls below the whitecap threshold within
		// about a second; this thin lace over the brightest bubble rims keeps it
		// visible for the few seconds the bake still carries it.
		float foam_trail = smoothstep(0.06, 0.3, foam_mask) * smoothstep(0.35, 0.75, foam_texture) * open_water;
		float whitecap_old = max(whitecap - whitecap_fresh, foam_trail * 0.9);
		water_color = mix(water_color, mix(shallow_color, foam_color, 0.4), whitecap_old * 0.6);
		water_color = mix(water_color, mix(foam_color, vec3(0.93, 0.95, 0.94), 0.6), whitecap_fresh);
		water_color = mix(water_color, foam_color, wind_streak);
		whitecap_fresh = max(whitecap_fresh, wind_streak);
	}

	// Thin crests transmit more Baltic teal than troughs; fades with the same solar
	// envelope as floor caustics so night water stays dark without a bloom pass.
	float crest_subsurface = smoothstep(0.0, 0.30, max(crest_term, 0.0));
	crest_subsurface *= choppiness * smoothstep(0.14, 0.48, shore_factor);
	// Fresh foam is opaque: no light comes through the crest under it.
	crest_subsurface *= 1.0 - whitecap_fresh;
	float crest_sss_visibility = twilight_water_light * day_blend;
	vec3 crest_transmit_tint = mix(shallow_color, highlight_color, 0.58);
	water_color += crest_transmit_tint
		* crest_subsurface
		* crest_sss_visibility
		* (0.18 + (1.0 - absorption) * 0.22);

	// Schlick Fresnel plus the PBR specular lobe produces stable sky reflection
	// and narrow sun glints at the shallow isometric viewing angle.
	float facing = clamp(dot(view_normal, normalize(VIEW)), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
	vec3 world_view = normalize((INV_VIEW_MATRIX * vec4(normalize(VIEW), 0.0)).xyz);
	vec3 reflection_normal = normalize(mix(vec3(0.0, 1.0, 0.0), world_normal, 0.38));
	vec3 reflected_sky_ray = normalize(reflect(-world_view, reflection_normal));
	float reflected_above_horizon = smoothstep(-0.01, 0.06, reflected_sky_ray.y);
	vec3 sky_reflection = _sky_dome_gradient(reflected_sky_ray) * reflected_above_horizon;
	// Keep the reflection legible from the gameplay camera. Fresnel still makes
	// grazing angles brightest, while this base share stops the shallow bed from
	// overpowering sky and sun reflections on broad, calm water.
	float sky_reflection_weight = clamp(
		0.34 + fresnel * mix(0.44, 0.62, day_blend),
		0.0,
		0.88
	);
	// Fresh foam is rough and diffuse, so it does not mirror the sky. Old foam lies
	// under the surface and keeps the reflection on top of it.
	sky_reflection_weight *= 1.0 - whitecap_fresh;
	// WS-06 art-direction lever, like ripple_sheen: seen from the steep gameplay camera
	// a flatter or rougher normal barely changes a uniform sky, so a glassy slick also
	// mirrors a little more of it and a catspaw a little less, then reads darker.
	float gust_tone = sea_gust - 1.0;
	sky_reflection_weight = clamp(sky_reflection_weight * (1.0 - gust_tone * 0.5), 0.0, 0.92);
	water_color = mix(water_color, sky_reflection, sky_reflection_weight);
	water_color *= 1.0 - max(gust_tone, 0.0) * 0.3;

	// WHY: DayNightCycle packs a solar day into 60s. Reflecting the catalog and
	// sun/moon through fully animated wave normals turns that race into frantic
	// pre-dawn sparkles on open sea. Celestial samples use a calmer normal so
	// waves still displace while glints stay readable instead of strobing.
	vec3 reflected_stars = texture(star_map, _equatorial_uv(reflected_sky_ray)).rgb;
	// Drop star glitter as soon as the sun disk begins to rise so dawn does not
	// stack racing constellations on top of the emerging sun path.
	float night_sparkle = star_visibility * (1.0 - sun_reflection_visibility);
	water_color += reflected_stars * night_sparkle * reflected_above_horizon * fresnel * 0.16;

	// WS-02: sun and moon glints come from light() (GGX x Smith x exact Fresnel),
	// so the light's shadow removes them behind quays and hulls. These gates keep
	// the old twilight rules. Low sun elongates the glitter path; keep a warm dawn
	// cue without a racing sparkle highway while the disk skims the horizon on a
	// compressed day cycle.
	float low_sun_glitter = smoothstep(-0.02, 0.22, sun_direction.y);
	float sun_glint_gate = sun_reflection_visibility * mix(0.2, 1.0, low_sun_glitter);
	float sun_light_share = smoothstep(SUN_LIGHT_HANDOFF_Y, 0.0, sun_direction.y);
	// During the moon-to-sun handoff the light points between the two bodies, so
	// the moon share fades out quadratically and never paints a glint from nowhere.
	float moon_glint_gate = moon_visibility * (1.0 - sun_light_share) * (1.0 - sun_light_share);
	directional_glint_gate = (moon_glint_gate + sun_glint_gate * sun_light_share) * (1.0 - whitecap_fresh);
	local_glint_gate = 1.0 - whitecap_fresh;

	// COLOR.r is baked from the same smooth contour that clips the mesh. A pair
	// of advancing breaker bands now travels into that contour, crests, and fades
	// at the bank. This reads as surf arriving at shore rather than static edge foam.
	float shore = 1.0 - smoothstep(0.0, 0.88, shore_factor);
	float breaker_phase = shore_factor * 18.0 + TIME * (1.45 * wave_speed);
	float breaker_warp = (_noise(water_world_position.xz * 0.42 + vec2(TIME * 0.08, -TIME * 0.04)) - 0.5) * 3.4;
	float breaker_a = pow(max(sin(breaker_phase + breaker_warp), 0.0), 5.0);
	float breaker_b = pow(max(sin(breaker_phase * 0.62 + breaker_warp * 0.7 + 2.4), 0.0), 7.0);
	float breaker_band = (breaker_a + breaker_b * 0.55) * smoothstep(0.04, 0.92, shore);
	if (shore_live) {
		// The analytic bore replaces the travelling sin() bands; hard edges throw
		// foam at the foot of the wall instead of running up.
		float swash_foam = shore_now.bore_foam * mix(0.45, 1.0, _swash_patch(water_world_position.xz, TIME));
		swash_foam += shore_now.wall_foam * mix(0.35, 1.0, _swash_patch(water_world_position.xz * 1.3, TIME));
		breaker_band = mix(breaker_band, 0.0, shore_now.valid);
		// Broken water is aerated white, unlike the tinted edge foam: add it after the
		// breaker scale so the bore reads from the gameplay camera.
		swash_bore = clamp(swash_foam * shore_now.valid, 0.0, 1.0);
	}
	vec2 foam_uv = water_world_position.xz * 3.4 + vec2(-TIME * 0.22, TIME * 0.09) * wave_speed;
	float foam_noise = _noise(foam_uv + _noise(foam_uv * 0.47) * 2.2);
	float foam_ribbon = 0.5 + 0.5 * sin(
		dot(water_world_position.xz, vec2(5.4, 3.8)) - TIME * 0.85 * wave_speed + foam_noise * 3.0
	);
	float edge_foam = shore * smoothstep(0.52, 0.88, foam_noise * 0.70 + foam_ribbon * 0.30);
	float foam = edge_foam * foam_intensity + breaker_band * breaker_intensity;
	foam *= smoothstep(0.012, 0.08, geometric_depth);

	// Jacobian whitecaps on the Gerstner fallback: folding crests, not shoreline bands.
	// A short time lag leaves foam behind the advancing crest without a foam buffer.
	// The FFT path styles its baked, lingering foam above (WS-06 whitecap).
	if (!use_fft && flow_strength <= 0.001) {
		float jacobian_now = _water_jacobian(wave_sample_xz - flow_advection, TIME * wave_speed);
		float jacobian_trail = _water_jacobian(
			wave_sample_xz - flow_advection,
			TIME * wave_speed - 0.42
		);
		float crest_fold = max(
			smoothstep(0.92, 0.55, jacobian_now),
			smoothstep(0.92, 0.55, jacobian_trail) * 0.68
		);
		crest_fold *= choppiness * foam_intensity * 1.35;
		crest_fold *= smoothstep(0.14, 0.48, shore_factor);
		crest_fold *= smoothstep(0.03, 0.10, geometric_depth);
		foam += crest_fold;
	}

	// Downstream foam streaks for flowing rivers. The along-current coordinate
	// scrolls with time so the ribbons travel toward the far bank, while the
	// cross-current axis stays tight so the foam elongates into streaks rather
	// than round blobs. flow_strength == 0 leaves still water untouched.
	if (flow_strength > 0.0) {
		vec2 flow_dir = normalize(flow_direction + vec2(0.0001, 0.0));
		vec2 flow_cross = vec2(-flow_dir.y, flow_dir.x);
		float along = dot(water_world_position.xz, flow_dir) - TIME * wave_speed * flow_strength * 1.6;
		float across = dot(water_world_position.xz, flow_cross);
		vec2 streak_uv = vec2(across * 2.1, along * 0.55);
		float streak = _noise(streak_uv + _noise(streak_uv * 0.6 + vec2(9.1, 2.3)) * 1.4);
		float current_foam = smoothstep(0.60, 0.92, streak) * flow_strength;
		current_foam *= smoothstep(0.012, 0.08, geometric_depth);
		foam += current_foam * 0.30;
	}
	// WS-15 churned water behind hulls: broken into bubbly clumps rather than a flat sheet.
	if (ripple_aeration > 0.001) {
		float bubbles = _noise(water_world_position.xz * 7.5 + vec2(TIME * 0.3, -TIME * 0.2));
		bubbles = smoothstep(0.25, 0.75, bubbles * 0.6 + ripple_aeration * 0.6);
		foam += ripple_aeration * ripple_foam_strength * bubbles
			* smoothstep(0.012, 0.08, geometric_depth);
	}
	water_color = mix(water_color, highlight_color, clamp(ripple_slope_length * ripple_sheen, 0.0, 0.25));
	water_color = mix(water_color, foam_color, clamp(foam, 0.0, 0.72));
	// WS-08 surf bore on top of the tinted foam: brighter and whiter than edge foam.
	water_color = mix(water_color, mix(foam_color, vec3(0.93, 0.95, 0.94), 0.6), swash_bore * 0.85);

	ALBEDO = water_color;
	// WS-02 roughness from wave slope variance (Toksvig-style). Calm water is a
	// near mirror; rivers and foam are rougher. A rougher sea widens the glitter
	// path, and slope the pixel cannot resolve (distant waves, the detail normal
	// that calm_normal flattens at low sun) becomes roughness instead of a
	// single-pixel sparkle.
	vec3 normal_dx = dFdx(world_normal);
	vec3 normal_dy = dFdy(world_normal);
	float unresolved_slope = clamp(dot(normal_dx, normal_dx) + dot(normal_dy, normal_dy), 0.0, 0.25);
	float rough_water = max(step(0.001, flow_strength), clamp(foam, 0.0, 1.0));
	float base_alpha = mix(0.03, 0.08, rough_water);
	// choppiness x wave_chaos spans ~0.5 (calm) to ~1.9 (storm) under apply_sea_weather.
	float sea_variance = mix(0.0015, 0.02, smoothstep(0.45, 1.8, choppiness * wave_chaos));
	ROUGHNESS = sqrt(sqrt(base_alpha * base_alpha + sea_variance + unresolved_slope));
	// Godot maps SPECULAR to dielectric F0; 0.25 is approximately water's 0.02.
	// With the custom light() it only scales ambient and reflection-probe specular.
	SPECULAR = mix(0.05, 0.25, sun_visibility);
	// WS-06: fresh foam is a rough diffuse scatterer. It takes its brightness from
	// the lights through ALBEDO, so it dims with the night instead of glowing.
	ROUGHNESS = mix(ROUGHNESS, 0.6, whitecap_fresh);
	SPECULAR = mix(SPECULAR, 0.1, whitecap_fresh);
	glint_alpha = ROUGHNESS * ROUGHNESS;
	// WHY full Lambert rather than the ~0.02 of physical water: ALBEDO here is the
	// already composited transmitted bed plus sky reflection, tuned under the old
	// built-in diffuse. Dropping it to 0.02 would leave the sea lit by ambient
	// only. Moving the sky reflection out of ALBEDO belongs to WS-11.
	diffuse_share = 1.0;
	// WS-13: the surface seen from below. The old P0-227 fog tint is gone; the
	// UnderwaterPass fogs everything between the lens and this surface, so the
	// branch only resolves what the surface itself shows: Snell's window inside
	// the critical angle, total internal reflection (a silver-green mirror of the
	// lit water) outside it. Unshaded via EMISSION so the sun cannot light the
	// underside a second time.
	// WHY not FRONT_FACING: some view water meshes (map-edge strips) are wound the
	// other way, so their top reads as a back face from the gameplay camera. The
	// camera being below the surface point is the robust test.
	vec3 camera_world = INV_VIEW_MATRIX[3].xyz;
	bool seen_from_below = camera_world.y < water_world_position.y;
	if (seen_from_below && !swash_sheet) {
		vec3 uw_ambient;
		vec3 uw_sun;
		_uw_lighting(
			mix(shallow_color, deep_color, 0.35), sun_reflection_color, sun_direction,
			day_blend, cloud_darken, uw_ambient, uw_sun
		);
		NORMAL = -NORMAL;
		ALBEDO = vec3(0.0);
		UwWindow uw = _uw_window(
			SCREEN_UV, VIEW_MATRIX, -world_view, normalize(mix(vec3(0.0, 1.0, 0.0), world_normal, 0.6))
		);
		vec3 uw_air = vec3(
			textureLod(screen_texture, clamp(uw.uv + uw.fringe, vec2(0.001), vec2(0.999)), 0.0).r,
			textureLod(screen_texture, uw.uv, 0.0).g,
			textureLod(screen_texture, clamp(uw.uv - uw.fringe, vec2(0.001), vec2(0.999)), 0.0).b
		);
		EMISSION = _uw_below_color(
			uw, uw_air, -world_view, uw_ambient, uw_sun, sun_direction, _uw_sigma_t(cloud_darken),
			deep_bed_color
		);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		// light() ignores SPECULAR; the underside is EMISSION only.
		directional_glint_gate = 0.0;
		local_glint_gate = 0.0;
		diffuse_share = 0.0;
	}
	if (swash_sheet) {
		NORMAL = sheet_normal;
		ALBEDO = sheet_albedo;
		ALPHA = sheet_alpha;
		ROUGHNESS = sheet_roughness;
		SPECULAR = mix(0.05, 0.5, sun_visibility);
		glint_alpha = sheet_roughness * sheet_roughness;
		directional_glint_gate = sun_glint_gate * sun_light_share * (1.0 - sheet_foam);
		local_glint_gate = 1.0 - sheet_foam;
	}
	if (debug_foam_mask > 0.5) {
		// Unlit mask: lighting and the foam tile must not hide renderer coverage.
		vec3 mask = vec3(fft_foam.x);
		ALBEDO = mask;
		EMISSION = mask;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		ALPHA = 1.0;
		directional_glint_gate = 0.0;
		local_glint_gate = 0.0;
		diffuse_share = 0.0;
	}
}

// WS-02: GGX x height-correlated Smith x exact dielectric Fresnel for every
// light. NORMAL is the calm normal from fragment(), so the compressed day cycle
// does not turn wave detail into racing specular bands. ATTENUATION carries the
// shadow, so quays and hulls cut the glitter path.
void light() {
	vec3 half_vector = normalize(VIEW + LIGHT);
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	float n_dot_v = max(dot(NORMAL, VIEW), 1e-4);
	float n_dot_h = max(dot(NORMAL, half_vector), 0.0);
	float v_dot_h = max(dot(VIEW, half_vector), 0.0);
	float a2 = max(glint_alpha * glint_alpha, 1e-6);
	float glint = _d_ggx(n_dot_h, a2) * _v_smith_ggx_correlated(n_dot_l, n_dot_v, a2)
		* _fresnel_dielectric(v_dot_h, WATER_IOR) * n_dot_l;
	float gate = LIGHT_IS_DIRECTIONAL ? directional_glint_gate : local_glint_gate;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * min(glint, GLINT_CLAMP) * gate;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * n_dot_l * diffuse_share / PI;
}
