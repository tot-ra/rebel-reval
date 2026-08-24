shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

// Shared shell/card pass for hair and beard. The generated meshes already carry
// separate scalp, sideburn, nape, jaw, and moustache volumes; this pass adds the
// fibre breakup and directional highlight that a flat StandardMaterial cannot
// provide, while keeping alpha cutout available for future card masks.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform sampler2D roughness_texture : hint_roughness_g, filter_linear_mipmap;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float roughness_base : hint_range(0.0, 1.0) = 0.80;
uniform float anisotropy_strength : hint_range(0.0, 1.0) = 0.68;
uniform float strand_frequency : hint_range(1.0, 64.0) = 22.0;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.08;

void fragment() {
	vec4 base = texture(albedo_texture, UV);
	// COLOR carries the generated per-vertex fibre tint. The low-amplitude UV
	// modulation breaks up broad shell highlights without punching visible holes
	// into smart-projected islands.
	float fibre = 0.96 + 0.08 * (0.5 + 0.5 * sin((UV.x + UV.y * 0.18) * strand_frequency * TAU));
	ALBEDO = base.rgb * albedo_tint.rgb * COLOR.rgb * fibre;
	ALPHA = base.a * albedo_tint.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	vec3 normal_sample = texture(normal_texture, UV).rgb;
	NORMAL_MAP = length(normal_sample) < 0.001 ? vec3(0.5, 0.5, 1.0) : normal_sample;
	float map_roughness = texture(roughness_texture, UV).g;
	ROUGHNESS = clamp(
		(map_roughness < 0.001 ? 1.0 : map_roughness) * roughness_base,
		0.04,
		1.0
	);
	SPECULAR = 0.34;
	// Godot's spatial light path uses this flow to orient the anisotropic lobe
	// along the strand direction in tangent space, even on GL Compatibility.
	ANISOTROPY = anisotropy_strength;
	ANISOTROPY_FLOW = normalize(vec2(0.18, 1.0));
}

void light() {
	float ndotl = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * ndotl;
	// A narrow, restrained streak keeps hair directional without making the
	// palette metallic. The engine anisotropy lobe remains enabled above.
	vec3 half_vector = normalize(normalize(LIGHT) + normalize(VIEW));
	float highlight = pow(max(dot(normalize(NORMAL), half_vector), 0.0), 42.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * highlight * 0.42;
}
