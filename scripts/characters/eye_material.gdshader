shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;

// Eye pass for the layered cornea, sclera, iris, and pupil surfaces. The
// shader is transparent only where the authored cornea material carries alpha;
// opaque eye layers retain depth and receive a compact catchlight highlight.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform sampler2D roughness_texture : hint_roughness_g, filter_linear_mipmap;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float roughness_base : hint_range(0.0, 1.0) = 0.20;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.82;
uniform float catchlight_strength : hint_range(0.0, 2.0) = 0.72;
uniform float catchlight_power : hint_range(8.0, 128.0) = 56.0;

void fragment() {
	vec4 base = texture(albedo_texture, UV);
	ALBEDO = base.rgb * albedo_tint.rgb;
	ALPHA = base.a * albedo_tint.a;
	vec3 normal_sample = texture(normal_texture, UV).rgb;
	NORMAL_MAP = length(normal_sample) < 0.001 ? vec3(0.5, 0.5, 1.0) : normal_sample;
	float map_roughness = texture(roughness_texture, UV).g;
	ROUGHNESS = clamp(
		(map_roughness < 0.001 ? 1.0 : map_roughness) * roughness_base,
		0.02,
		1.0
	);
	SPECULAR = specular_strength;
}

void light() {
	float ndotl = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * ndotl;

	vec3 half_vector = normalize(normalize(LIGHT) + normalize(VIEW));
	float highlight = pow(max(dot(normalize(NORMAL), half_vector), 0.0), catchlight_power);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * highlight * catchlight_strength;
}
