shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// ADR 0031 city ground: one continuous heightfield, surfaces blended from the
// baked splat (R paving, G packed earth, B sand, A mud) plus slope rock, so
// streets, yards, beaches and the Toompea klint read without tile seams.

uniform sampler2D splat : source_color, filter_linear, repeat_disable;
uniform vec4 splat_rect = vec4(0.0, 0.0, 1.0, 1.0); // origin.xz, size.xz in world units

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float grass_scale = 0.16;
uniform float cobble_scale = 0.95;
uniform float earth_scale = 0.2;
uniform float sand_scale = 0.18;
uniform float rock_scale = 0.12;
uniform vec3 grass_tint : source_color = vec3(0.78, 0.86, 0.62);
uniform vec3 earth_tint : source_color = vec3(0.60, 0.55, 0.47);
uniform float wetness = 0.0;
uniform float sea_level = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Two rotated samples break the visible repeat of every plate.
vec3 detiled(sampler2D tex, vec2 uv) {
	float n = value_noise(uv * 0.11);
	vec2 uv2 = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * uv * 0.73 + vec2(0.37, 0.71);
	return mix(texture(tex, uv).rgb, texture(tex, uv2).rgb, smoothstep(0.3, 0.7, n));
}

vec3 detiled_normal(sampler2D tex, vec2 uv) {
	return texture(tex, uv).rgb;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 suv = (world_pos.xz - splat_rect.xy) / splat_rect.zw;
	vec4 s = texture(splat, suv);
	float macro = value_noise(world_pos.xz * 0.035);
	float micro = value_noise(world_pos.xz * 0.6);

	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float rock = smoothstep(0.32, 0.5, slope + (macro - 0.5) * 0.12);
	float paving = smoothstep(0.25, 0.7, s.r + (micro - 0.5) * 0.25);
	float earth = smoothstep(0.15, 0.65, s.g + (micro - 0.5) * 0.3);
	float sand = smoothstep(0.2, 0.7, s.b + (macro - 0.5) * 0.3);
	float mud = smoothstep(0.2, 0.7, s.a + (micro - 0.5) * 0.3);
	// Beaches and the delta margin: everything within a metre of the sea is sand or mud.
	float shore = 1.0 - smoothstep(sea_level + 0.4, sea_level + 1.6, world_pos.y);
	sand = max(sand, shore * 0.9);

	vec2 wuv = world_pos.xz;
	vec3 grass = detiled(grass_albedo, wuv * grass_scale) * grass_tint * mix(0.85, 1.08, macro);
	vec3 col = grass;
	vec3 nrm = detiled_normal(grass_normal, wuv * grass_scale);
	col = mix(col, detiled(earth_albedo, wuv * earth_scale) * earth_tint, earth);
	nrm = mix(nrm, detiled_normal(earth_normal, wuv * earth_scale), earth);
	col = mix(col, detiled(earth_albedo, wuv * earth_scale) * vec3(0.62, 0.55, 0.46), mud);
	nrm = mix(nrm, detiled_normal(earth_normal, wuv * earth_scale), mud);
	col = mix(col, detiled(sand_albedo, wuv * sand_scale), sand);
	nrm = mix(nrm, detiled_normal(sand_normal, wuv * sand_scale), sand);
	col = mix(col, detiled(cobble_albedo, wuv * cobble_scale) * vec3(0.62, 0.58, 0.52), paving);
	nrm = mix(nrm, detiled_normal(cobble_normal, wuv * cobble_scale), paving);
	// Exposed limestone on the klint faces and steep banks, triplanar so cliffs do not stretch.
	vec3 an = abs(world_normal);
	vec3 rx = texture(rock_albedo, world_pos.zy * rock_scale).rgb;
	vec3 rz = texture(rock_albedo, world_pos.xy * rock_scale).rgb;
	vec3 ry = texture(rock_albedo, world_pos.xz * rock_scale).rgb;
	vec3 rock_col = (rx * an.x + ry * an.y + rz * an.z) / (an.x + an.y + an.z) * vec3(0.95, 0.93, 0.86);
	col = mix(col, rock_col, rock);

	float wet = clamp(wetness + mud * 0.35 + shore * 0.5, 0.0, 1.0);
	ALBEDO = col * mix(1.0, 0.62, wet);
	ROUGHNESS = mix(0.95, 0.35, wet * (1.0 - rock * 0.5));
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = mix(1.0, 0.6, wet);
}
