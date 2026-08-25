shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

// Opaque scalp volumes and optional alpha-cutout breakup cards share this PBR
// pass. Hair stays readable as broad clumps first; the texture normal and
// engine anisotropy add fibre response without painting highlights into albedo.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform sampler2D roughness_texture : hint_roughness_g, filter_linear_mipmap;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float roughness_base : hint_range(0.0, 1.0) = 0.88;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.34;
uniform float anisotropy_strength : hint_range(0.0, 1.0) = 0.42;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.08;

void fragment() {
	vec4 base = texture(albedo_texture, UV);
	// COLOR carries low-frequency generated clump variation. Do not add a
	// procedural sine here: the source maps already contain fibre detail, and a
	// second periodic pattern produces the concentric plastic rings seen on buns.
	ALBEDO = base.rgb * albedo_tint.rgb * COLOR.rgb;
	ALPHA = base.a * albedo_tint.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	vec3 normal_sample = texture(normal_texture, UV).rgb;
	NORMAL_MAP = length(normal_sample) < 0.001 ? vec3(0.5, 0.5, 1.0) : normal_sample;
	// Hair normals should break up a broad clump, not emboss every texture line
	// as a deep groove. The lower depth also hides smart-UV island boundaries.
	NORMAL_MAP_DEPTH = normal_strength;
	float map_roughness = texture(roughness_texture, UV).g;
	ROUGHNESS = clamp(
		(map_roughness < 0.001 ? 1.0 : map_roughness) * roughness_base,
		0.55,
		1.0
	);
	SPECULAR = 0.24;
	ANISOTROPY = anisotropy_strength;
	ANISOTROPY_FLOW = normalize(vec2(0.18, 1.0));
}
