shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, blend_mix;

#include "res://scripts/map/view3d/sky_clouds.gdshaderinc"
#include "res://scripts/map/view3d/cloud_cells.gdshaderinc"

// WHY no hint_screen_texture: Godot 4.7 binds a default buffer for that hint
// in SceneTree capture paths (Metal beige mottling, Compatibility RGB noise).
// The pass darkens the live framebuffer by mixing black over it:
// dest * (1 - ALPHA). R-1400: the previous blend_mul wrote ALBEDO as the
// multiplier, but the Compatibility 3D buffer stores colour pre-scaled by its
// HDR luminance multiplier, so ALBEDO 1.0 multiplied the frame by about 0.25
// and the old COMPAT_BLEND_GAIN (2.34) still left every frame ~40% darker with
// no visible patches. Black is 0 under any multiplier or tonemapper, so
// mixing it is exact everywhere. Do not bring the screen-texture hint back.
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float sun_share : hint_range(0.0, 1.0) = 0.0;
uniform int shadow_samples : hint_range(1, 3) = 3;
// R-1400: noise mip for the discrete cells' billowed shadow edges.
uniform float cell_edge_lod = 1.0;
// Sea level for pixels without depth: water surfaces are transparent and do not
// write depth, so their shadow is placed on this plane instead.
uniform float water_plane_y = 0.0;

global uniform sampler2D cloud_noise_tex : filter_linear_mipmap, repeat_enable;
global uniform sampler2D cloud_shape_tex : filter_linear_mipmap, repeat_enable;
global uniform vec2 cloud_offset_g;
global uniform vec2 cloud_detail_offset_g;
global uniform float cloud_coverage_g;
global uniform float cloud_chaos_g;
global uniform float storm_intensity_g;
global uniform float storm_locality_g;
global uniform vec3 cloud_sun_dir;
global uniform float cloud_shadow_strength;

// Art knob: a physical 1.5 km layer makes one shadow larger than a whole map.
// 400 world units is about 350 m and keeps readable patches on a district.
const float CLOUD_LAYER_H = 400.0;
const float SHADOW_MIP_BIAS = 1.5;
const float SUN_SHARE_SKIP = 0.01;
// Direct-sun share a full cell shadow removes (sun_share scales it again).
const float CELL_SHADOW_STRENGTH = 0.85;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	// Night / full overcast: write nothing so a leftover overlay cannot
	// replace the sea. The node also hides itself at the same threshold.
	if (sun_share <= SUN_SHARE_SKIP) {
		discard;
	}
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	float factor = 1.0;
	vec3 world_position = vec3(0.0);
	bool has_surface = false;
	float surface_fade = 1.0;
	// Reverse-Z: sky reads 0. A far terrain pixel with the 0.08 gameplay near
	// plane is still ~1e-5. Pixels with no depth behind them (open sea with no
	// bed mesh) fall back to the sea plane below.
	if (depth > 1e-6) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
		vec4 view_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view_position.xyz /= view_position.w;
		world_position = (INV_VIEW_MATRIX * vec4(view_position.xyz, 1.0)).xyz;
		has_surface = true;
	} else {
		// No depth: shade the sea plane where a downward eye ray meets it, so a
		// shadow does not stop dead at a bedless stretch of sea. Upward rays are sky.
		vec4 near_p = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
		vec4 mid_p = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 0.5, 1.0);
		vec3 o = (INV_VIEW_MATRIX * vec4(near_p.xyz / near_p.w, 1.0)).xyz;
		vec3 e = (INV_VIEW_MATRIX * vec4(mid_p.xyz / mid_p.w, 1.0)).xyz;
		vec3 d = normalize(e - o);
		if (d.y < -1e-4) {
			float t = (water_plane_y - o.y) / d.y;
			// Fade out before the map edge, where depthless pixels are horizon haze.
			surface_fade = 1.0 - smoothstep(1500.0, 3000.0, t);
			if (t > 0.0 && surface_fade > 0.0) {
				world_position = o + d * t;
				has_surface = true;
			}
		}
	}
	if (has_surface) {
		vec3 sun_dir = cloud_sun_dir;
		float sun_y = max(sun_dir.y, 0.15);
		vec2 q = world_position.xz + sun_dir.xz / sun_y * (CLOUD_LAYER_H - world_position.y);
		vec2 uv = (q / CLOUD_LAYER_H) * 0.12 - cloud_offset_g;
		float cover = clamp(cloud_coverage_g, 0.0, 1.0);
		float shadow = 0.0;
		if (shadow_samples <= 1) {
			shadow = sky_cloud_shadow_cheap(uv, cover, cloud_shape_tex);
		} else {
			shadow = sky_cloud_shadow_soft(
				uv,
				cover,
				cloud_shape_tex,
				cloud_noise_tex,
				cloud_detail_offset_g,
				cloud_chaos_g,
				SHADOW_MIP_BIAS
			);
		}
		// R-1400: each discrete cloud throws its own moving shadow, projected
		// along the sun from the same cell the sky dome draws. Cells shade harder
		// than the soft deck pattern: a cumulus overhead blocks the direct sun.
		float cells = cells_ground_shadow(world_position, sun_dir, cloud_noise_tex, cell_edge_lod);
		float deck = shadow * cloud_shadow_strength;
		float cell_dark = cells * CELL_SHADOW_STRENGTH;
		factor = 1.0 - (1.0 - (1.0 - deck) * (1.0 - cell_dark)) * sun_share * surface_fade;
	}
	ALBEDO = vec3(0.0);
	ALPHA = clamp(1.0 - factor, 0.0, 1.0);
}
