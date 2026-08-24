shader_type spatial;
render_mode depth_draw_opaque;

// Opaque compatibility-friendly skin pass. The wrap term keeps cheeks, hands,
// and limbs readable under the low-frequency directional light used by the map,
// while the small back-light term approximates soft subsurface transmission
// without relying on renderer-specific SSS features.
//
// Do not write ALPHA here: Godot treats any spatial shader that assigns ALPHA as
// transparent, even when the resulting value is 1.0. Skin is a solid surface;
// keeping it in the opaque depth path prevents the face from ghosting through
// nearby geometry and other character layers.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
// glTF ORM packs roughness in G (R=AO, B=metallic). hint_roughness_g keeps
// the sampler in the linear roughness path Godot expects for that channel.
uniform sampler2D roughness_texture : hint_roughness_g, filter_linear_mipmap;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float roughness_base : hint_range(0.0, 1.0) = 0.72;
uniform float wrap_lighting : hint_range(0.0, 1.0) = 0.35;
uniform float subsurface_strength : hint_range(0.0, 1.0) = 0.16;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	vec4 base = texture(albedo_texture, UV);
	ALBEDO = base.rgb * albedo_tint.rgb;
	vec3 normal_sample = texture(normal_texture, UV).rgb;
	// Solid-black embeds were shipped by a broken Non-Color export; treat them
	// as flat so lighting does not collapse into a specular glow blob.
	NORMAL_MAP = length(normal_sample) < 0.001 ? vec3(0.5, 0.5, 1.0) : normal_sample;
	// WHY: constant ORM with G=0 zeroed roughness_base and bloom-haloed characters.
	float map_roughness = texture(roughness_texture, UV).g;
	ROUGHNESS = clamp(
		(map_roughness < 0.001 ? 1.0 : map_roughness) * roughness_base,
		0.04,
		1.0
	);
	SPECULAR = specular_strength;
}

void light() {
	float ndotl = dot(normalize(NORMAL), normalize(LIGHT));
	float wrapped = clamp((ndotl + wrap_lighting) / (1.0 + wrap_lighting), 0.0, 1.0);
	float backlight = pow(max(dot(-normalize(NORMAL), normalize(LIGHT)), 0.0), 2.0);
	float diffuse = wrapped + backlight * subsurface_strength;
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * diffuse;

	// A restrained Blinn-Phong highlight keeps skin moist without making the
	// low-poly face look metallic, and works in the GL Compatibility light path.
	vec3 half_vector = normalize(normalize(LIGHT) + normalize(VIEW));
	float highlight = pow(max(dot(normalize(NORMAL), half_vector), 0.0), 24.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * highlight * specular_strength;
}
