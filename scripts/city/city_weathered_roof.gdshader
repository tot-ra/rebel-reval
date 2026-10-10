shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://scripts/city/city_plate_hint.gdshaderinc"
#define CITY_ROOF_PLATE
#include "res://scripts/city/city_weathering.gdshaderinc"

uniform float moss = 0.5; // shingle and tile gather moss, thatch greys

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV * uv_scale.xy;
	vec3 col = texture(albedo_tex, uv).rgb * base_tint * COLOR.rgb;
	if (!FRONT_FACING) {
		col *= 0.55; // underside of the eaves
	}
	float patch = wfbm(w_pos.xz * 0.35 + vec2(w_pos.y * 0.2));
	float lichen = smoothstep(0.62, 0.8, wnoise(w_pos.xz * 2.3));
	// Moss on the cool north pitches and in the lower courses where water lingers.
	float north = clamp(-w_nrm.z * 0.8 + 0.3, 0.0, 1.0);
	float m = smoothstep(0.5, 0.78, patch + north * 0.2) * moss * age;
	col = mix(col, vec3(0.24, 0.29, 0.14) * (0.8 + patch * 0.4), m * 0.6);
	col = mix(col, vec3(0.62, 0.6, 0.5), lichen * 0.18 * age);
	col *= mix(0.84, 1.08, wfbm(w_pos.xz * 0.12 + 5.0));
	ALBEDO = city_albedo(col * mix(1.0, 0.72, wetness));
	ROUGHNESS = mix(roughness_base, 0.4, wetness);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = mix(1.0, 0.6, wetness);
}
