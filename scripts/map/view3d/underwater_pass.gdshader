shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

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

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
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

vec3 _world_at(vec2 screen_uv, float ndc_z, mat4 inv_projection, mat4 inv_view) {
	vec4 view_position = inv_projection * vec4(screen_uv * 2.0 - 1.0, ndc_z, 1.0);
	view_position.xyz /= view_position.w;
	return (inv_view * vec4(view_position.xyz, 1.0)).xyz;
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
	// Godot 4.7 uses reverse Z on every renderer: the near plane is NDC z = +1 and
	// an empty (sky) pixel reads raw depth 0. Compatibility keeps OpenGL's -1..1
	// NDC range, so only the raw-to-NDC mapping differs.
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	float scene_ndc_z = raw_depth * 2.0 - 1.0;
	#else
	float scene_ndc_z = raw_depth;
	#endif
	float near_ndc_z = 1.0;
	bool sky = raw_depth <= 0.000001;
	vec3 near_world = _world_at(SCREEN_UV, near_ndc_z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 scene_world = _world_at(SCREEN_UV, scene_ndc_z, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 camera_world = INV_VIEW_MATRIX[3].xyz;
	vec3 ray = normalize(scene_world - near_world);
	if (dot(ray, ray) < 0.5) {
		ray = normalize((INV_VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	}

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
	vec3 scene = textureLod(screen_texture, uv, 0.0).rgb;

	float alpha = max(lens_mask, meniscus);
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
		float scene_d = sky ? MAX_MEDIUM_M / METERS_PER_WORLD_UNIT : distance(near_world, scene_world);
		float surface_t = 1e9;
		if (ray.y > 1e-4) {
			surface_t = max(water_plane_y - near_world.y, 0.0) / ray.y;
		}
		bool hits_surface = surface_t < scene_d;
		float d_world = min(scene_d, surface_t);
		float d_m = min(d_world * METERS_PER_WORLD_UNIT, MAX_MEDIUM_M);

		if (hits_surface) {
			vec3 hit = near_world + ray * surface_t;
			float crest;
			// World footprint of one pixel on the surface, so the FFT LOD and cascade
			// fade stay alias-free at grazing angles like on the water shader.
			float footprint = surface_t * 1.4 / viewport.y / max(ray.y, 0.05);
			vec3 surface_up = use_fft ? _fft_normal(hit.xz, footprint, crest) : vec3(0.0, 1.0, 0.0);
			UwWindow uw = _uw_window(uv, VIEW_MATRIX, ray, normalize(mix(vec3(0.0, 1.0, 0.0), surface_up, 0.6)));
			vec3 air = vec3(
				textureLod(screen_texture, clamp(uw.uv + uw.fringe, vec2(0.001), vec2(0.999)), 0.0).r,
				textureLod(screen_texture, uw.uv, 0.0).g,
				textureLod(screen_texture, clamp(uw.uv - uw.fringe, vec2(0.001), vec2(0.999)), 0.0).b
			);
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
			color += sun * (shaft * (span / float(steps))) * phase * collimation * shafts * SHAFT_GAIN;
		}
		alpha = 1.0;
	}
	// Dark meniscus line where the lens cuts the surface.
	color *= 1.0 - meniscus * 0.55;
	// Drops catch a faint highlight on their upper rim.
	color += lens_mask * 0.04;
	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
