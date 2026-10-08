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
uniform float trunk_sway : hint_range(0.0, 1.0) = 0.3;
// Rain: dry bark darkens and turns glossy (mirrors MapViewPropMaterials wetness).
uniform float wetness : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	vec2 wind = wind_dir();
	float strength = wind_strength();
	float flex = clamp(COLOR.a, 0.0, 1.0);
	vec2 origin = MODEL_MATRIX[3].xz;
	float push = wind_pressure_coarse(origin, TIME);
	// Thin parts take the full limb bend (the leaves on them do); the trunk and
	// thick limbs keep only a share, so they sway far less than the twigs.
	vec2 bend = tree_limb_bend(wind, origin, VERTEX.x, VERTEX.y, strength, sway_strength, push, TIME)
		* mix(TREE_THICK_BEND_SHARE, 1.0, flex)
		+ tree_twig_sway(wind, origin, VERTEX, flex, strength, sway_strength, push, TIME);
	vec2 lean = tree_trunk_lean(wind, origin, VERTEX.y, strength, sway_strength, trunk_sway, TIME);
	vec2 total = bend + lean;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(total.x, 0.0, total.y);
}

void fragment() {
	vec3 albedo = texture(albedo_tex, UV).rgb * COLOR.rgb;
	ALBEDO = albedo * mix(1.0, 0.58, wetness);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(roughness_value, 0.38, wetness);
}
