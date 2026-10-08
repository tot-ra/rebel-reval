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
uniform float sway_strength = 0.06;
// Rain: dry bark darkens and turns glossy (mirrors MapViewPropMaterials wetness).
uniform float wetness : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float flex = clamp(COLOR.a, 0.0, 1.0);
	vec2 origin = MODEL_MATRIX[3].xz;
	float scale = length(MODEL_MATRIX[1].xyz);
	float push = wind_pressure_coarse(origin, TIME);
	vec3 offset = tree_wind_offset(origin, VERTEX, flex, scale, wind_strength(),
		sway_strength, push, TIME);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * offset;
}

void fragment() {
	vec3 albedo = texture(albedo_tex, UV).rgb * COLOR.rgb;
	ALBEDO = albedo * mix(1.0, 0.58, wetness);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(roughness_value, 0.38, wetness);
}
