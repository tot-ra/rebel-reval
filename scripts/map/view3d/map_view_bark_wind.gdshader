shader_type spatial;

// Wind-swayed trunk and branches of the city trees. Stands in for the
// StandardMaterial3D bark plate (same albedo x vertex colour, normal map and
// roughness) so the wood can move with the crown. COLOR.a carries the limb
// flexibility baked by MapViewTreeMeshes (0 = thick trunk, 1 = twig tip); the
// motion maths is shared with the leaves in tree_wind.gdshaderinc.
#include "res://scripts/map/view3d/tree_wind.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_roughness_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
// Same defaults as the crown material so wood and leaves share one sway scale.
// Crown-top height in model units and species flexibility (see tree_wind.gdshaderinc).
uniform float tree_top = 9.0;
uniform float slender = 1.0;
// Rain: dry bark darkens and turns glossy (mirrors MapViewPropMaterials wetness).
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
// R-1661: moss at the foot of the trunk and grey-green lichen higher up, both
// on the shaded north side (world -Z, as the roof shaders). Seeded per tree, so
// some trunks are clean and some green to knee height.
uniform float moss_amount : hint_range(0.0, 1.0) = 0.6;
uniform float lichen_amount : hint_range(0.0, 1.0) = 0.5;

varying vec3 bark_pos; // model space x scale: metres from the root, sway-free
varying vec3 bark_nrm; // world normal after the sway tilt
varying float bark_seed;

float bark_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float bark_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(bark_hash(i), bark_hash(i + vec3(1, 0, 0)), f.x),
			mix(bark_hash(i + vec3(0, 1, 0)), bark_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(bark_hash(i + vec3(0, 0, 1)), bark_hash(i + vec3(1, 0, 1)), f.x),
			mix(bark_hash(i + vec3(0, 1, 1)), bark_hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

void vertex() {
	float flex = clamp(COLOR.a, 0.0, 1.0);
	vec2 origin = MODEL_MATRIX[3].xz;
	float scale = length(MODEL_MATRIX[1].xyz);
	float push = wind_pressure_coarse(origin, TIME);
	mat3 model = mat3(MODEL_MATRIX);
	vec3 wind_point = model * VERTEX / max(scale, 0.00001);
	vec3 offset = tree_wind_offset(origin, wind_point, flex, scale, tree_top, slender,
		wind_strength(), push, TIME);
	float L = max(tree_top * scale, 2.0);
	vec2 tilt = tree_wind_tilt(origin, L, slender, wind_strength(), push, TIME)
		* tree_slope_shape(max(VERTEX.y, 0.0) * scale / L);
	NORMAL = normalize(inverse(model) * tree_wind_rotate(model * NORMAL, tilt));
	TANGENT = normalize(inverse(model) * tree_wind_rotate(model * TANGENT, tilt));
	BINORMAL = normalize(inverse(model) * tree_wind_rotate(model * BINORMAL, tilt));
	bark_pos = VERTEX * scale;
	bark_nrm = normalize(model * NORMAL);
	bark_seed = bark_hash(vec3(origin * 0.37, 5.1));
	VERTEX += inverse(model) * offset;
}

void fragment() {
	vec3 albedo = texture(albedo_tex, UV).rgb * COLOR.rgb;
	float rough = roughness_value;
	// North-facing bark keeps the damp; the bole and thick limbs carry the growth.
	float north = clamp(-bark_nrm.z * 0.75 + 0.25, 0.0, 1.0);
	float bole = 1.0 - smoothstep(0.12, 0.4, COLOR.a);
	float h = bark_pos.y;
	float patch = bark_noise(bark_pos * vec3(3.0, 1.6, 3.0) + bark_seed * 17.0) * 0.65
		+ bark_noise(bark_pos * 11.0) * 0.35;
	// Moss: a green skirt round the root that climbs highest on the north side.
	float tree_moss = moss_amount * smoothstep(0.25, 0.75, bark_seed);
	float reach = mix(0.25, 2.6, north) * tree_moss;
	float moss = (1.0 - smoothstep(reach * 0.5, reach + 0.05, h + (patch - 0.5) * 0.6))
		* smoothstep(0.3, 0.55, patch + north * 0.25) * bole * step(0.001, tree_moss);
	vec3 moss_col = mix(vec3(0.17, 0.24, 0.07), vec3(0.32, 0.38, 0.12), patch);
	albedo = mix(albedo, moss_col * mix(0.9, 1.1, COLOR.r), moss * 0.92);
	rough = mix(rough, 1.0, moss);
	// Lichen: pale grey-green crusts and rosettes from shin height into the crown.
	float tree_lichen = lichen_amount * smoothstep(0.15, 0.6, fract(bark_seed * 7.13));
	float spots = smoothstep(0.66, 0.74, bark_noise(bark_pos * 7.5 + 3.0) + north * 0.12 - patch * 0.08);
	float lichen = spots * tree_lichen * smoothstep(0.3, 1.0, h) * (0.35 + north * 0.65) * (1.0 - moss);
	albedo = mix(albedo, vec3(0.58, 0.63, 0.5) * mix(0.85, 1.05, patch), lichen * 0.85);
	// Moss soaks up rain and darkens less than bare bark glosses.
	ALBEDO = albedo * mix(1.0, mix(0.58, 0.75, moss), wetness);
	NORMAL_MAP = mix(texture(normal_tex, UV).rgb, vec3(0.5, 0.5, 1.0), moss * 0.6);
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(rough, mix(0.38, 0.8, moss), wetness);
}
