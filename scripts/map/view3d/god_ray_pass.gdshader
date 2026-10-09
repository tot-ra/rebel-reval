shader_type spatial;
// R-1444: premultiplied blend (dest = ALBEDO + dest * (1 - ALPHA)) so lit air adds light
// and air in a cloud's shadow takes some of the uniform haze back out: the shadow
// columns between beams read darker, which is most of a crepuscular ray's contrast.
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, blend_premul_alpha;

// Volumetric crepuscular rays (god rays) ray-marched through the street air.
// GL Compatibility has no volumetric fog, and screen/depth hints are unreliable on
// this pipeline (see cloud_shadow_pass.gdshader and the underwater pass notes), so
// the pass carries its own scene description: a max-height raster of building and
// landmark masses (god_ray_pass.gd). Each pixel walks its eye ray through the air
// slab between the ground and the roofline, stops where the ray enters architecture,
// and at every sample marches toward the sun/moon through the same raster. Only
// samples that see the light scatter, so shafts start at real roof edges and gaps,
// buildings cut them like shadows, and air in a building's shade stays dark.
// A Henyey-Greenstein phase keeps the haze bright only when the camera looks toward
// the light; from straight above, the forward-scattered light does not reach the eye.
uniform sampler2D height_map : filter_nearest, repeat_disable;
// World XZ of the raster's (0, 0) corner and the world size of one texel.
uniform vec2 map_origin = vec2(0.0);
uniform float texel_size = 1.0;
// Air slab the march covers: ground floor to just above the tallest roof.
uniform float floor_y = 0.0;
uniform float volume_top = 12.0;
// Unit vector toward the light, world space.
uniform vec3 light_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 ray_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float strength : hint_range(0.0, 2.0) = 0.0;
// Soft ceiling of the added light: linear for faint haze, saturating toward the cap.
uniform float intensity_cap = 0.6;
uniform float anisotropy : hint_range(0.0, 0.95) = 0.6;
// Share of isotropic scatter mixed into the phase (light that reaches any view).
uniform float isotropic_share : hint_range(0.0, 1.0) = 0.0;
// Scatter per world unit of lit air; the beam saturates along long lit paths.
uniform float density = 0.05;
uniform float max_march = 90.0;
uniform float shadow_reach = 60.0;
uniform int view_steps = 16;
uniform int shadow_steps = 8;
// R-1400: discrete clouds shade the air too, so a beam is lit only where the
// cloud shadow on the street is open: shafts start at real cloud edges.
global uniform sampler2D cloud_noise_tex : filter_linear_mipmap, repeat_enable;
// R-1444: the dome cloud deck shades the air as well, through the same WS-12 plane the
// ground shadow pass projects (cloud_shadow_pass.gdshader), so a shaft lands on the
// sunlit patch of street the deck leaves open.
global uniform sampler2D cloud_shape_tex : filter_linear_mipmap, repeat_enable;
global uniform vec2 cloud_offset_g;
global uniform vec2 cloud_detail_offset_g;
global uniform float cloud_coverage_g;
global uniform float cloud_chaos_g;
#include "res://scripts/map/view3d/sky_clouds.gdshaderinc"
#include "res://scripts/map/view3d/cloud_cells.gdshaderinc"
// Scene depth bounds the far march so beams stop at terrain, roofs, trees and ships.
// Depth (unlike the screen texture) is reliable here: cloud_shadow_pass reads it too.
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
// Far march: kilometre-scale air between the eye and the cloud deck, where the
// shadow columns of whole clouds form. Thin haze, so it needs long lit paths.
// Distance over which the haze in front of a surface builds up (aerial perspective).
uniform float far_extinction = 900.0;
uniform float far_reach = 1600.0;
uniform int far_steps = 12;
// Extra light from lit far haze, and the share of the haze a fully shaded far path
// removes (the dark columns), both at the phase peak.
uniform float far_light = 0.1;
uniform float shade_strength = 0.6;
const float MAX_SHADE = 0.35;
// Must match cloud_shadow_pass.gdshader CLOUD_LAYER_H (art-scaled deck height).
const float DECK_H = 400.0;
const float DECK_MIP = 1.5;
// Single-layer deck density where the air starts to be shaded and where it is fully
// shaded (the dome draws the same density as an opaque cloud).
const float DECK_OPEN = 0.2;
const float DECK_SOLID = 0.55;

float height_at(vec2 xz) {
	ivec2 size = textureSize(height_map, 0);
	ivec2 cell = ivec2(floor((xz - map_origin) / texel_size));
	if (cell.x < 0 || cell.y < 0 || cell.x >= size.x || cell.y >= size.y) {
		return floor_y;
	}
	return texelFetch(height_map, cell, 0).r;
}

// 1 when the point sees the light through the height raster, 0 when a mass blocks it.
// Samples are packed toward the point (squared spacing): nearby roof edges shape the
// shaft, far ones only need to catch tall towers.
float sun_visibility(vec3 p, float jitter) {
	float reach = min((volume_top - p.y) / max(light_dir.y, 0.02), shadow_reach);
	for (int k = 0; k < shadow_steps; k++) {
		float f = (float(k) + jitter) / float(shadow_steps);
		vec3 q = p + light_dir * (reach * f * f + texel_size * 0.5);
		if (q.y < height_at(q.xz)) {
			return 0.0;
		}
	}
	return 1.0;
}

// Share of the light the clouds stop above air point `p` (1 = full shadow): the deck
// projected along the light onto its plane, times the discrete cells. A real (not
// clamped) light slope is used so dawn shafts lie as flat as the sun; only a floor
// keeps the projection finite at the horizon.
float cloud_shadow(vec3 p, float cell_lod) {
	float light_y = max(light_dir.y, 0.03);
	float deck = 0.0;
	if (p.y < DECK_H) {
		vec2 q = p.xz + light_dir.xz / light_y * (DECK_H - p.y);
		vec2 uv = (q / DECK_H) * 0.12 - cloud_offset_g;
		float body = sky_cloud_shadow_soft(
			uv, clamp(cloud_coverage_g, 0.0, 1.0), cloud_shape_tex, cloud_noise_tex,
			cloud_detail_offset_g, cloud_chaos_g, DECK_MIP
		);
		// Threshold like the dome's thick slab: a cloud the player sees as opaque must
		// shade its column, and the thin fringe between heaps must stay open.
		deck = smoothstep(DECK_OPEN, DECK_SOLID, body);
	}
	float cells = cells_ground_shadow(p, light_dir, cloud_noise_tex, cell_lod);
	return 1.0 - (1.0 - deck) * (1.0 - cells);
}

// Henyey-Greenstein normalised to 1 when looking straight at the light.
float phase(float cos_theta) {
	float g = anisotropy;
	float ratio = (1.0 - g) * (1.0 - g) / max(1.0 + g * g - 2.0 * g * cos_theta, 1e-4);
	return mix(ratio * sqrt(ratio), 1.0, isotropic_share);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	// Eye ray from two unprojected points on the pixel. Works for the orthographic
	// gameplay lens and the perspective close cameras, on both depth conventions.
	vec2 ndc = SCREEN_UV * 2.0 - 1.0;
	vec4 a = INV_PROJECTION_MATRIX * vec4(ndc, 0.25, 1.0);
	vec4 b = INV_PROJECTION_MATRIX * vec4(ndc, 0.75, 1.0);
	a.xyz /= a.w;
	b.xyz /= b.w;
	vec3 dir_view = normalize(b.xyz - a.xyz);
	if (dir_view.z > 0.0) {
		dir_view = -dir_view;
	}
	// Slide the point back to the camera plane (view z = 0): the eye for perspective,
	// the pixel's spot on the lens for orthographic.
	vec3 origin_view = a.xyz - dir_view * (a.z / dir_view.z);
	vec3 origin = (INV_VIEW_MATRIX * vec4(origin_view, 1.0)).xyz;
	vec3 dir = normalize(mat3(INV_VIEW_MATRIX) * dir_view);

	float t0 = 0.0;
	float t1 = max_march;
	if (abs(dir.y) > 1e-4) {
		float t_top = (volume_top - origin.y) / dir.y;
		float t_floor = (floor_y - origin.y) / dir.y;
		t0 = max(min(t_top, t_floor), 0.0);
		t1 = max(t_top, t_floor);
	} else if (origin.y > volume_top || origin.y < floor_y) {
		t1 = 0.0;
	}
	t1 = min(t1, t0 + max_march);

	// Distance along the eye ray to the first opaque surface; sky pixels have none.
	float scene_t = -1.0;
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	// Sky is 1.0 on the Compatibility depth range and 0.0 on reverse-Z renderers.
	if (depth > 1e-6 && depth < 0.999999) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 depth_ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
		vec3 depth_ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
		vec4 surface_view = INV_PROJECTION_MATRIX * vec4(depth_ndc, 1.0);
		surface_view.xyz /= surface_view.w;
		vec3 surface = (INV_VIEW_MATRIX * vec4(surface_view.xyz, 1.0)).xyz;
		scene_t = max(dot(surface - origin, dir), 0.0);
		t1 = min(t1, scene_t);
	}

	// Interleaved gradient noise: per-pixel step offset turns banding into fine grain.
	float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float lit = 0.0;
	if (t1 > t0) {
		float dt = (t1 - t0) / float(view_steps);
		for (int i = 0; i < view_steps; i++) {
			vec3 p = origin + dir * (t0 + (float(i) + jitter) * dt);
			if (p.y <= height_at(p.xz)) {
				break;
			}
			float cloud_lit = 1.0 - cloud_shadow(p, 2.0);
			lit += sun_visibility(p, jitter) * cloud_lit * dt;
		}
	}
	// R-1444 far march: the air from the eye out to the surface (or the deck plane),
	// lit or shaded by whole clouds. Roof shadows do not matter at this scale, so the
	// height raster is skipped. Only surfaces get it: the sky dome draws its own beams
	// from the visible deck (sky_weather_3d.gdshader `sky_sunbeams`). Each sample is
	// weighted by how much of its in-scattered haze still reaches the eye, so the
	// result is the lit and the shaded share of the scene's aerial haze. Samples are
	// packed toward the eye, where shafts are widest on screen.
	float far_lit = 0.0;
	float far_shade = 0.0;
	if (scene_t > 0.0 && far_steps > 0) {
		float far_end = min(scene_t, far_reach);
		if (dir.y > 1e-4) {
			far_end = min(far_end, (DECK_H - origin.y) / dir.y);
		}
		float prev_t = 0.0;
		for (int k = 0; k < far_steps; k++) {
			float f = (float(k) + jitter) / float(far_steps);
			float t = far_end * f * f;
			float w = exp(-t / far_extinction) * (t - prev_t) / far_extinction;
			prev_t = t;
			float s = cloud_shadow(origin + dir * t, 2.5);
			far_lit += (1.0 - s) * w;
			far_shade += s * w;
		}
	}
	float forward = strength * phase(dot(dir, light_dir));
	// Lit far air brightens only a little (the scene fog already assumes sunlit haze);
	// the contrast comes mostly from the shaded columns taking their haze back out.
	float beam = forward * (1.0 - exp(-density * lit) + far_lit * far_light);
	ALBEDO = ray_color * intensity_cap * (1.0 - exp(-beam / intensity_cap));
	ALPHA = clamp(forward * far_shade * shade_strength, 0.0, MAX_SHADE);
}
