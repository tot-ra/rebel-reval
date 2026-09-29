shader_type spatial;
// WHY no blend_mix: CloudShadowPass found blend_mix+ALPHA on this unshaded
// clip-space quad does not composite on Compatibility, so the water underside
// (seen_from_below) stays on screen. Fog-of-war uses the default blend with
// ALPHA 1 and actually replaces. Wet-lens ALPHA<1 still mix-blends.
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

// WS-13 underwater view. One screen quad drawn after the water (see
// UnderwaterPass). Technique after Tidewater's underwater / underwater-composite
// modules (lens straddle band, Beer-Lambert medium with an HG sun lobe, caustic
// light shafts, wet lens). Ported from Tidewater (MIT), see notice.code.tidewater.
//
// WHY the pass rebuilds the surface-from-below itself: hint_screen_texture is
// copied once before the transparent pass, so it holds the opaque scene without
// the water surface. Pixels whose eye ray meets the surface first are resolved
// here with the same _uw_window()/_uw_below_color() the water back face uses; every
// other underwater pixel reads the opaque scene and applies the medium.
//
// WHY no mipmap on the screen sampler: Compatibility's 8-bit copy plus
// filter_linear_mipmap is a default/chromatic buffer in capture paths (R-1048,
// R-932). The water shader still uses mips; this overlay only needs LOD 0.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

// Required before the shared FFT include; copied from the source water material.
uniform float choppiness = 0.85;
uniform float standing_wave_ratio = 0.12;
uniform vec2 wind_direction = vec2(0.9578, 0.2873);
global uniform float ocean_time;
#include "res://scripts/map/view3d/ocean_fft_common.gdshaderinc"
// WS-07 tiles: same helpers as the water shader so the underwater net matches the bed.
// WS-07 caustic tiles packed by WS-11: R = fine, G = broad (see caustics_common.gdshaderinc).
uniform sampler2D caustics_tiles : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec2 caustic_min_pair_mean = vec2(1.0, 1.0);
uniform bool caustic_full_quality = true;
uniform float caustic_pattern_scale = 3.0;
#include "res://scripts/map/view3d/caustics_common.gdshaderinc"

// 0 AIR (only the wet lens runs), 1 STRADDLE (per-pixel waterline), 2 UNDER.
uniform int medium_state = 0;
// Rest plane of the water under the camera: recessed mesh height plus tide.
uniform float water_plane_y = 0.0;
uniform vec3 shallow_color : source_color = vec3(0.45, 0.62, 0.75);
uniform vec3 deep_color : source_color = vec3(0.16, 0.30, 0.44);
uniform vec3 deep_bed_color : source_color = vec3(0.035, 0.08, 0.11);
uniform vec3 highlight_color : source_color = vec3(0.396, 0.694, 0.769);
uniform vec3 sun_reflection_color : source_color = vec3(1.0, 0.92, 0.74);
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform float day_blend = 1.0;
uniform float cloud_darken = 0.0;
// Tidewater `shafts` scale; `shaft_samples` is 8 on recommended, 4 on minimum.
uniform float shafts = 1.0;
uniform int shaft_samples = 8;
uniform float caustic_gain = 0.45;
// Wet lens after surfacing: 1 right after the camera leaves the water, fading
// to 0. lens_age is the seconds since surfacing and drives the sliding drops.
uniform float wet_lens = 0.0;
uniform float lens_age = 0.0;

const float METERS_PER_WORLD_UNIT = 0.87;
const float MAX_MEDIUM_M = 60.0;
// Tidewater `band 9`: meniscus half-width in pixels, dark line and lip refraction.
const float MENISCUS_BAND_PX = 9.0;
const float MENISCUS_LINE_PX = 2.0;
const float MENISCUS_LIFT_PX = 6.0;
const int MAX_SHAFT_SAMPLES = 8;
// R-904: readable shafts. The bed net lines are ~2.7 units apart, about one
// march step, so sampling them along the eye ray averaged every beam into haze.
// Shafts now read their own prefilter of the broad tile: a 20 m patch at mip 3
// gives soft ~0.6 m wide spots (tile autocorrelation ~3 % of the patch), and
// the focus smoothstep keeps only the brightest ~15 % as beams with dark gaps.
const float SHAFT_PATCH_M = 20.0;
const float SHAFT_MIP = 3.0;
const float SHAFT_FOCUS_LO = 1.3;
const float SHAFT_FOCUS_HI = 2.0;
// Near-field window: samples are importance-distributed along exp(-t / FALLOFF)
// so most land in the first metres, where one beam covers many pixels and stays
// distinct; far beams that would only add haze get little weight.
const float SHAFT_RANGE_M = 12.0;
const float SHAFT_FALLOFF_M = 3.5;
// Milder forward lobe than the medium's 0.75 so beams still read side-on.
const float SHAFT_PHASE_G = 0.5;
const float SHAFT_GAIN = 7.0;
// R-1068: when Compatibility overlay depth is empty/default, place a dummy
// opaque hit at this multiple of the vertical water column. Looking up still
// meets the surface first (Snell's window). A level look at a landing crib
// has a much larger surface_t, so the pre-transparent colour keeps the crib.
const float COMPAT_EMPTY_DEPTH_HIT_SCALE = 1.5;
// ADR 0021 (swim/dive): in a running Compatibility game the screen and depth samplers of
// this overlay read back the FFT atlas instead of the opaque scene (white/yellow noise
// over the whole lens, R-1087/R-1094), so Compatibility never samples them. It draws the
// medium as a translucent tint over the real opaque scene and the water mesh's own
// underside (map_view_water.gdshader seen_from_below), which keeps seabed, piles and hulls
// visible at any depth. Metal keeps the full screen-space composite.
const float COMPAT_TINT_ALPHA = 0.62;
// Colour of a wet-lens drop on Compatibility, where the lens cannot refract the screen.
const vec3 COMPAT_DROP_COLOR = vec3(0.78, 0.86, 0.92);

void vertex() {
	// Clip-space quad like map_fog_of_war: follows every camera with no transform.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Interleaved gradient noise (Jimenez 2014) jitters the shaft march per pixel.
float _ign(vec2 pixel) {
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

// WS-07 tiles at `p`. `full_quality` is the water recommended path (2 tiles);
// shafts pass false so the march stays at 1 tile / 2 samples per step.
// Intensity is the excess above the baked mean of 1, so average bed light
// adds nothing and only the bright net lines lift the medium.
float _caustic_at(vec3 p, bool full_quality, bool screen_grad) {
	float h_m = max(water_plane_y - p.y, 0.0) * METERS_PER_WORLD_UNIT;
	vec3 c = _caustic_tiles_at(p.xz, h_m, sun_direction, vec2(0.0), full_quality, screen_grad);
	return max((c.r + c.g + c.b) * (1.0 / 3.0) - 1.0, 0.0);
}

// R-904 beam mask (0..1) at `x`: walk up the refracted sun ray `sun_refr` to the
// surface point the light entered through and read the shaft prefilter there,
// so every point on one beam reads the same spot and beams slant with the sun.
// The two scrolling layers of _caustic_tile() make the beams drift and flicker.
float _shaft_beam(vec3 x, vec3 sun_refr) {
	float depth_units = max(water_plane_y - x.y, 0.0);
	vec2 entry = x.xz + sun_refr.xz * (depth_units / max(sun_refr.y, 0.2));
	vec2 uv = entry * METERS_PER_WORLD_UNIT / SHAFT_PATCH_M;
	vec2 wind = length(wind_direction) > 1e-3 ? normalize(wind_direction) : vec2(1.0, 0.0);
	float wrap_phase = ocean_time / CAUSTIC_OCEAN_TIME_WRAP_SECONDS;
	// Constant gradients pin the mip, so the loop takes no derivatives.
	float g = exp2(SHAFT_MIP) / CAUSTIC_TILE_RES;
	float v = _caustic_tile(
		caustics_tiles, vec2(0.0, 1.0), uv,
		wind * (wrap_phase * CAUSTIC_BROAD_A_TILES_PER_WRAP),
		-wind * (wrap_phase * CAUSTIC_BROAD_B_TILES_PER_WRAP),
		vec2(g, 0.0), vec2(0.0, g), vec2(0.0), caustic_min_pair_mean.y
	).g;
	return smoothstep(SHAFT_FOCUS_LO, SHAFT_FOCUS_HI, v);
}

float _surface_y(vec2 xz) {
	float y = water_plane_y;
	if (use_fft) {
		y += _fft_trough_floor(_fft_displacement(xz).y);
	}
	return y;
}

// Same raw-to-view helper as map_view_water.gdshader (WS-01). Do not reconstruct
// NDC Z separately: Compatibility needs uv and depth in one *2-1, Metal does not.
vec3 _view_position(vec2 screen_uv, float raw_depth, mat4 inverse_projection) {
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv, raw_depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
	#endif
	vec4 view_position = inverse_projection * vec4(ndc, 1.0);
	return view_position.xyz / view_position.w;
}

vec3 _world_from_view(vec3 view_position, mat4 inv_view) {
	return (inv_view * vec4(view_position, 1.0)).xyz;
}

vec3 _compat_scene_rgb(vec3 sampled) {
	return vec3(
		_compat_stored_alpha(sampled.r),
		_compat_stored_alpha(sampled.g),
		_compat_stored_alpha(sampled.b)
	);
}

// Procedural drops for the wet lens: one Voronoi seed per cell, sliding down
// with a per-cell speed. Returns the refraction offset in pixels (xy) and the
// drop coverage (z).
vec3 _lens_drops(vec2 pixel, vec2 viewport) {
	float cell_px = viewport.y / 7.0;
	vec3 best = vec3(0.0);
	float best_d = 1e9;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = floor(pixel / cell_px) + vec2(float(i), float(j));
			float r1 = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
			float r2 = fract(sin(dot(cell, vec2(269.5, 183.3))) * 43758.5453);
			float slide = r2 > 0.7 ? lens_age * lens_age * cell_px * 0.9 : 0.0;
			vec2 center = (cell + vec2(r1, r2)) * cell_px + vec2(0.0, slide);
			float radius = mix(0.12, 0.30, fract(r1 * 7.13 + r2)) * cell_px;
			vec2 to_center = center - pixel;
			float d = length(to_center) / radius;
			if (d < 1.0 && d < best_d) {
				best_d = d;
				// 3-8 px pull towards the drop centre, strongest at the rim.
				float pull = mix(3.0, 8.0, r2) * smoothstep(0.0, 1.0, d);
				best = vec3(normalize(to_center + vec2(1e-4)) * pull, 1.0 - smoothstep(0.8, 1.0, d));
			}
		}
	}
	return best;
}

void fragment() {
	vec2 viewport = VIEWPORT_SIZE;
	vec2 px = 1.0 / viewport;
	float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	// Pixel ray from the camera through this fragment. Compatibility near is
	// OpenGL NDC z = -1 (raw 0, WS-13); Metal reverse-Z near is raw 1.
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	float near_raw = 0.0;
	#else
	float near_raw = 1.0;
	#endif
	vec3 near_view = _view_position(SCREEN_UV, near_raw, INV_PROJECTION_MATRIX);
	vec3 scene_view = _view_position(SCREEN_UV, raw_depth, INV_PROJECTION_MATRIX);
	vec3 near_world = _world_from_view(near_view, INV_VIEW_MATRIX);
	vec3 scene_world = _world_from_view(scene_view, INV_VIEW_MATRIX);
	vec3 camera_world = INV_VIEW_MATRIX[3].xyz;
	// Direction in view space, then rotated to world: near_world - camera_world is only a
	// few centimetres at world coordinates near 100 and quantises into streaks in float32.
	vec3 ray = normalize((INV_VIEW_MATRIX * vec4(normalize(near_view), 0.0)).xyz);
	if (dot(ray, ray) < 0.5) {
		ray = normalize((INV_VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	}
	bool depth_valid = raw_depth > 0.0001 && raw_depth < 0.9999;
	bool sky = !depth_valid;

	// Per-pixel classification on the near plane. `h` is how far the lens point
	// sits below the displaced surface; its screen gradient turns it into a
	// pixel distance from the waterline for the meniscus band.
	float h = _surface_y(near_world.xz) - near_world.y;
	bool under = medium_state == 2 || (medium_state == 1 && h > 0.0);
	float h_grad = max(length(vec2(dFdx(h), dFdy(h))), 1e-6);
	float line_px = medium_state == 1 ? h / h_grad : 1e6;

	vec2 uv = SCREEN_UV;
	float lens_mask = 0.0;
	if (wet_lens > 0.001) {
		vec3 drop = _lens_drops(FRAGCOORD.xy, viewport);
		lens_mask = drop.z * wet_lens;
		uv += drop.xy * px * wet_lens;
	}
	float meniscus = 0.0;
	if (abs(line_px) < MENISCUS_BAND_PX) {
		float band = 1.0 - abs(line_px) / MENISCUS_BAND_PX;
		// The lens-water lip bends the image vertically towards the waterline.
		uv.y += sign(line_px) * MENISCUS_LIFT_PX * band * px.y;
		meniscus = 1.0 - smoothstep(0.0, MENISCUS_LINE_PX, abs(line_px));
	}
	uv = clamp(uv, vec2(0.001), vec2(0.999));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 scene = COMPAT_DROP_COLOR;
#else
	vec3 scene = _compat_scene_rgb(textureLod(screen_texture, uv, 0.0).rgb);
#endif

	float alpha = max(lens_mask, meniscus);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	alpha = max(lens_mask * 0.16, meniscus);
#endif
	vec3 color = scene;
	if (under) {
		vec3 sigma_t = _uw_sigma_t(cloud_darken);
		vec3 ambient;
		vec3 sun;
		_uw_lighting(
			mix(shallow_color, deep_color, 0.35), sun_reflection_color, sun_direction,
			day_blend, cloud_darken, ambient, sun
		);
		vec3 sun_refr = _uw_sun_refracted(sun_direction);
		float sun_strength = dot(sun, vec3(0.2126, 0.7152, 0.0722));
		float camera_depth_m = max(_surface_y(near_world.xz) - near_world.y, 0.0) * METERS_PER_WORLD_UNIT;

		// Distance through the water: the scene, or the surface when the eye ray
		// climbs into it first (the surface is then shaded here, see header).
		float scene_d = sky ? MAX_MEDIUM_M / METERS_PER_WORLD_UNIT : distance(camera_world, scene_world);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		// Overlay depth is empty/default on Compatibility (R-932 finding 3).
		// Dummy hit at 1.5x the vertical column: looking up still hits the
		// surface first; a level crib look does not, so screen colour shows.
		if (!depth_valid) {
			sky = false;
			float column = max(water_plane_y - camera_world.y, 0.05);
			scene_d = column * COMPAT_EMPTY_DEPTH_HIT_SCALE;
			scene_world = camera_world + ray * scene_d;
		}
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		// The tint has no depth to stop at, so let the shaft march see the full range.
		float compat_medium_d = SHAFT_RANGE_M / METERS_PER_WORLD_UNIT;
#endif
		float surface_t = 1e9;
		if (ray.y > 1e-4) {
			surface_t = max(water_plane_y - camera_world.y, 0.0) / ray.y;
		}
		bool hits_surface = surface_t < scene_d;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		float d_world = min(compat_medium_d, surface_t);
#else
		float d_world = min(scene_d, surface_t);
#endif
		float d_m = min(d_world * METERS_PER_WORLD_UNIT, MAX_MEDIUM_M);

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		// Medium only: the tint below is blended over the opaque scene and the water underside.
		vec3 transmittance = exp(-sigma_t * d_m);
		// Floor the medium so downward rays over the bed stay a readable green-blue, not black.
		color = max(
			_uw_inscatter(ray, camera_depth_m, ambient, sun, sun_direction, sigma_t),
			mix(deep_color, shallow_color, 0.5) * 0.9
		);
#else
		if (hits_surface) {
			vec3 hit = near_world + ray * surface_t;
			float crest;
			// World footprint of one pixel on the surface, so the FFT LOD and cascade
			// fade stay alias-free at grazing angles like on the water shader.
			float footprint = surface_t * 1.4 / viewport.y / max(ray.y, 0.05);
			vec3 surface_up = use_fft ? _fft_normal(hit.xz, footprint, crest) : vec3(0.0, 1.0, 0.0);
			UwWindow uw = _uw_window(uv, VIEW_MATRIX, ray, normalize(mix(vec3(0.0, 1.0, 0.0), surface_up, 0.6)));
			vec3 air = _compat_scene_rgb(vec3(
				textureLod(screen_texture, clamp(uw.uv + uw.fringe, vec2(0.001), vec2(0.999)), 0.0).r,
				textureLod(screen_texture, uw.uv, 0.0).g,
				textureLod(screen_texture, clamp(uw.uv - uw.fringe, vec2(0.001), vec2(0.999)), 0.0).b
			));
			scene = _uw_below_color(uw, air, ray, ambient, sun, sun_direction, sigma_t, deep_bed_color);
		} else if (!sky) {
			// Caustics on submerged surfaces, dimmed by the light lost on the way down.
			float p_depth_m = max(water_plane_y - scene_world.y, 0.0) * METERS_PER_WORLD_UNIT;
			vec3 t_down_p = exp(-sigma_t * p_depth_m);
			scene *= vec3(1.0) + highlight_color * _caustic_at(scene_world, caustic_full_quality, true) * t_down_p * caustic_gain * sun_strength;
		}

		vec3 transmittance = exp(-sigma_t * d_m);
		vec3 inscatter = _uw_inscatter(ray, camera_depth_m, ambient, sun, sun_direction, sigma_t);
		color = scene * transmittance + inscatter * (vec3(1.0) - transmittance);

#endif

		// Light shafts: march the eye ray, reading the beam mask where the light
		// that reaches each sample entered the surface (see _shaft_beam()).
		float march_m = min(d_m, SHAFT_RANGE_M);
		if (shafts > 0.0 && sun_strength > 0.001 && march_m > 0.01) {
			int steps = clamp(shaft_samples, 1, MAX_SHAFT_SAMPLES);
			// Stratified importance sampling of exp(-t / FALLOFF) over [0, march]:
			// equal-weight samples, dense near the lens. `span` is the weight the
			// window holds, so a ray that meets the bed after a metre stays dim.
			float span = 1.0 - exp(-march_m / SHAFT_FALLOFF_M);
			float jitter = _ign(FRAGCOORD.xy);
			vec3 shaft = vec3(0.0);
			for (int i = 0; i < MAX_SHAFT_SAMPLES; i++) {
				if (i >= steps) {
					break;
				}
				float u = (float(i) + jitter) / float(steps);
				float t_m = -SHAFT_FALLOFF_M * log(1.0 - u * span);
				vec3 x = near_world + ray * (t_m / METERS_PER_WORLD_UNIT);
				float x_depth_m = max(water_plane_y - x.y, 0.0) * METERS_PER_WORLD_UNIT;
				vec3 atten = exp(-sigma_t * (x_depth_m + t_m));
				shaft += atten * _shaft_beam(x, sun_refr);
			}
			float phase = _uw_hg(dot(ray, sun_refr), SHAFT_PHASE_G);
			// Beams need collimated light: overcast diffuses the sun long before it
			// stops lighting the medium, so shafts fade out faster than `sun`
			// (clear 1.0, cloudy ~0.75, storm ~0.1 on top of the dimmer sun).
			float collimation = 1.0 - smoothstep(0.1, 1.0, cloud_darken);
			#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
			// The tint overlay shows the beams only faintly; keep them a soft accent.
			collimation *= 0.3;
#endif
			color += sun * (shaft * (span / float(steps))) * phase * collimation * shafts * SHAFT_GAIN;
		}
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		alpha = COMPAT_TINT_ALPHA;
#else
		alpha = 1.0;
#endif
	}
	// Dark meniscus line where the lens cuts the surface.
	color *= 1.0 - meniscus * 0.55;
	// Drops catch a faint highlight on their upper rim.
	color += lens_mask * 0.04;
	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
