// R-1436: water draws after CloudShadowPass, so it must shade its own direct sun.
// Keep the deck projection, erosion mip and cell union aligned with that pass.
// No screen read or independent clock: both fields use the sky's restored globals.
#include "res://scripts/map/view3d/sky_clouds.gdshaderinc"
#include "res://scripts/map/view3d/cloud_cells.gdshaderinc"

global uniform sampler2D cloud_noise_tex : filter_linear_mipmap, repeat_enable;
global uniform sampler2D cloud_shape_tex : filter_linear_mipmap, repeat_enable;
global uniform vec2 cloud_offset_g;
global uniform vec2 cloud_detail_offset_g;
global uniform float cloud_coverage_g;
global uniform float cloud_chaos_g;
global uniform vec3 cloud_sun_dir;
global uniform float cloud_shadow_strength;

const float WATER_CLOUD_LAYER_H = 400.0;
const float WATER_CLOUD_SHADOW_MIP_BIAS = 1.5;
const float WATER_CELL_SHADOW_STRENGTH = 0.85;
// sin(-6 deg): below this MapViewLighting has handed the light to the moon.
const float WATER_SUN_HANDOFF_Y = -0.1045;

float water_cloud_shadow(vec3 world) {
	vec2 q = world.xz + cloud_sun_dir.xz / max(cloud_sun_dir.y, 0.15)
		* (WATER_CLOUD_LAYER_H - world.y);
	vec2 uv = (q / WATER_CLOUD_LAYER_H) * 0.12 - cloud_offset_g;
	float deck = sky_cloud_shadow_soft(
		uv, clamp(cloud_coverage_g, 0.0, 1.0), cloud_shape_tex, cloud_noise_tex,
		cloud_detail_offset_g, cloud_chaos_g, WATER_CLOUD_SHADOW_MIP_BIAS
	) * cloud_shadow_strength;
	float cell = cells_ground_shadow(world, cloud_sun_dir, cloud_noise_tex, 1.0);
	// Union, not addition: overlap must not extinguish the sun twice. The caller
	// scales direct lighting only, so unlike the framebuffer pass no sun_share
	// factor is needed here. Ambient, moonlight and local lights remain unchanged.
	return (1.0 - (1.0 - deck) * (1.0 - cell * WATER_CELL_SHADOW_STRENGTH))
		* smoothstep(WATER_SUN_HANDOFF_Y, 0.0, cloud_sun_dir.y);
}
