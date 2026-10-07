shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Limestone floor flags: fine fossil-speckled grain, worn smooth (and a little
// polished) along the walking lines, small pits, darker where the slab edges
// meet. Each slab's tone comes from the vertex colour. World-space.

#include "res://scripts/city/city_weathering.gdshaderinc"

uniform vec3 stone : source_color = vec3(0.6, 0.55, 0.47);
uniform float indoor_ao = 0.62;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = w_pos.xz;
	float grain = wfbm(p * 7.0) - 0.5;
	float speck = smoothstep(0.78, 0.9, wnoise(p * 38.0));
	float pit = smoothstep(0.86, 0.95, wnoise(p * 21.0 + 9.0));
	float wear = wfbm(p * 0.35);
	vec3 col = stone * COLOR.rgb * (1.0 + grain * 0.18 - speck * 0.12 - pit * 0.25);
	col *= mix(0.92, 1.05, wear);
	ALBEDO = col * mix(1.0, indoor_ao, 0.6);
	AO = indoor_ao;
	AO_LIGHT_AFFECT = 0.0;
	// No sky haze indoors: the distance fog is for streets and the skyline.
	FOG = vec4(0.0);
	ROUGHNESS = mix(0.86, 0.6, smoothstep(0.55, 0.8, wear));
	SPECULAR = 0.3;
	NORMAL_MAP = normalize(vec3(grain * 0.6, pit * -0.8 + grain * 0.3, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
}
