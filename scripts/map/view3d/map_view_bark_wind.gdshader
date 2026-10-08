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
	VERTEX += inverse(model) * offset;
}

void fragment() {
	vec3 albedo = texture(albedo_tex, UV).rgb * COLOR.rgb;
	ALBEDO = albedo * mix(1.0, 0.58, wetness);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(roughness_value, 0.38, wetness);
}
