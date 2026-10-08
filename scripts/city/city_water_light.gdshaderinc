// R-1400 follow-up: lighting for the city sea, stream and moat (city_water,
// city_moat_water). The CloudShadowPass draws before transparent materials, so
// it cannot darken these surfaces; they read the same discrete cloud cells
// (`cloud_cells`, pushed each frame by CityWorld3D.apply_cloud_cells) and dim
// their own direct sun. WHY a custom light(): built-in lighting has no hook to
// scale one light, so this repeats Godot's diffuse_burley + specular_schlick_ggx
// and multiplies the directional light by the cell shadow.
// Hosts set `cloud_cell_shadow = city_water_cloud_shadow(world)` and
// `water_f0 = 0.16 * SPECULAR * SPECULAR` in fragment().

#include "res://scripts/map/view3d/cloud_cells.gdshaderinc"

global uniform sampler2D cloud_noise_tex : filter_linear_mipmap, repeat_enable;
global uniform vec3 cloud_sun_dir;

// Matches CELL_SHADOW_STRENGTH in cloud_shadow_pass.gdshader.
const float CITY_CLOUD_SHADOW_STRENGTH = 0.85;
// sin(-6 deg): MapViewLighting has handed the light to the moon below this.
const float CITY_SUN_HANDOFF_Y = -0.1045;

varying float cloud_cell_shadow;
varying float water_f0;


float city_water_cloud_shadow(vec3 world) {
	return cells_ground_shadow(world, cloud_sun_dir, cloud_noise_tex, 1.0)
		* smoothstep(CITY_SUN_HANDOFF_Y, 0.0, cloud_sun_dir.y);
}


void light() {
	vec3 h = normalize(VIEW + LIGHT);
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	float n_dot_v = max(dot(NORMAL, VIEW), 1e-4);
	float n_dot_h = max(dot(NORMAL, h), 0.0);
	float l_dot_h = max(dot(LIGHT, h), 0.0);
	float lit = LIGHT_IS_DIRECTIONAL ? 1.0 - cloud_cell_shadow * CITY_CLOUD_SHADOW_STRENGTH : 1.0;
	// Burley diffuse (Godot's diffuse_burley).
	float fd90 = 0.5 + 2.0 * l_dot_h * l_dot_h * ROUGHNESS;
	float fd_l = 1.0 + (fd90 - 1.0) * pow(1.0 - n_dot_l, 5.0);
	float fd_v = 1.0 + (fd90 - 1.0) * pow(1.0 - n_dot_v, 5.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * n_dot_l * fd_l * fd_v * lit / PI;
	// GGX x height-correlated Smith x Schlick Fresnel (specular_schlick_ggx).
	float alpha = ROUGHNESS * ROUGHNESS;
	float a2 = max(alpha * alpha, 1e-6);
	float d_den = n_dot_h * n_dot_h * (a2 - 1.0) + 1.0;
	float d = a2 / (PI * d_den * d_den);
	float gv = n_dot_l * sqrt(n_dot_v * n_dot_v * (1.0 - a2) + a2);
	float gl = n_dot_v * sqrt(n_dot_l * n_dot_l * (1.0 - a2) + a2);
	float v = 0.5 / max(gv + gl, 1e-5);
	float f = water_f0 + (1.0 - water_f0) * pow(1.0 - l_dot_h, 5.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * SPECULAR_AMOUNT * d * v * f * n_dot_l * lit;
}
