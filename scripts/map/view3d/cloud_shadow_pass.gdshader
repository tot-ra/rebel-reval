shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, blend_mul;

#include "res://scripts/map/view3d/sky_clouds.gdshaderinc"

// WHY no hint_screen_texture: Godot 4.7 binds a default buffer for that hint
// in SceneTree capture paths (Metal beige mottling, Compatibility RGB noise).
// Multiply the live framebuffer (dest * factor). blend_mix ALPHA on this
// unshaded quad did not composite. Compatibility still reads darker than
// Metal; that is a follow-up, not a return to hint_screen_texture.
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float sun_share : hint_range(0.0, 1.0) = 0.0;
uniform int shadow_samples : hint_range(1, 3) = 3;

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
	// Reverse-Z: empty / far-plane sky reads ~0. Leave those pixels untouched.
	if (depth >= 0.0001) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
		vec4 view_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view_position.xyz /= view_position.w;
		vec3 world_position = (INV_VIEW_MATRIX * vec4(view_position.xyz, 1.0)).xyz;
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
		factor = 1.0 - shadow * cloud_shadow_strength * sun_share;
	}
	ALBEDO = vec3(factor);
	ALPHA = 1.0;
}
