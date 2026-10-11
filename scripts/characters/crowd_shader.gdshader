shader_type spatial;

// Simplified crowd shader for Tier-2 character instancing (P0-152).
// Replaces the full SharedCharacterRig material stack with a cheap
// vertex-color tinted lit surface that works on GL Compatibility.
// WHY: MultiMeshInstance3D cannot share per-instance Skeleton3D poses,
// so crowd characters are frozen in a neutral bind pose; the shader
// keeps them visually distinct via palette tint and roughness variation.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform sampler2D roughness_texture : hint_roughness_g, filter_linear_mipmap;

// Per-instance color is set via MultiMesh.set_instance_color().
// Vertex color carries the palette tint from the MultiMesh; the shader
// blends it with the base albedo so clothing and skin read as distinct
// surfaces rather than flat blobs.
uniform float roughness_base : hint_range(0.0, 1.0) = 0.85;
uniform float metallic_base : hint_range(0.0, 1.0) = 0.0;
// Strength of the palette tint applied on top of the albedo texture.
uniform float tint_strength : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec4 albedo_sample = texture(albedo_texture, UV);
	// Vertex color from MultiMesh carries per-instance palette variation.
	vec3 tint = COLOR.rgb;
	// Blend base albedo with the instance tint so both texture detail
	// and palette variation survive at gameplay distance.
	ALBEDO = mix(albedo_sample.rgb, tint, tint_strength);
	ALPHA = albedo_sample.a;

	vec3 normal_sample = texture(normal_texture, UV).rgb;
	NORMAL_MAP = length(normal_sample) < 0.001 ? vec3(0.5, 0.5, 1.0) : normal_sample;
	float map_roughness = texture(roughness_texture, UV).g;
	ROUGHNESS = clamp(
		(map_roughness < 0.001 ? 1.0 : map_roughness) * roughness_base,
		0.04,
		1.0
	);
	METALLIC = metallic_base;
}
