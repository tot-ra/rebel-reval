shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_map : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec4 roughness_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float roughness_value = 0.78;
uniform float normal_strength = 0.0;

vec3 linear_to_srgb(vec3 value) {
	return mix(12.92 * value, 1.055 * pow(max(value, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), value));
}

void fragment() {
	// glTF vertex pigmentation is linear; Compatibility shades in sRGB.
	vec3 pigment = OUTPUT_IS_SRGB ? linear_to_srgb(COLOR.rgb) : COLOR.rgb;
	ALBEDO = pigment * base_color.rgb * texture(albedo_map, UV).rgb;
	ROUGHNESS = clamp(roughness_value * dot(texture(roughness_map, UV), roughness_channel), 0.1, 1.0);
	NORMAL_MAP = texture(normal_map, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
