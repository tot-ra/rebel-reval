shader_type spatial;

// Dense staggered iron links. Filter the ring edges and collapse their contrast
// below a pixel so the weave remains quiet at distance on GL Compatibility.
uniform vec4 albedo_tint : source_color = vec4(0.62, 0.67, 0.72, 1.0);
uniform float roughness_base : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	vec2 weave = UV * 110.0;
	weave.x += mod(floor(weave.y), 2.0) * 0.5;
	vec2 local = (fract(weave) - 0.5) * vec2(1.0, 1.2);
	float radius = length(local);
	float edge = max(fwidth(radius), 0.025);
	float ring = smoothstep(0.21 - edge, 0.21 + edge, radius)
		* (1.0 - smoothstep(0.43 - edge, 0.43 + edge, radius));
	float detail = 1.0 - smoothstep(0.35, 1.2, length(fwidth(weave)));
	float iron = mix(0.62, mix(0.30, 1.0, ring), detail);
	ALBEDO = albedo_tint.rgb * iron;
	METALLIC = 0.55;
	ROUGHNESS = roughness_base;
	SPECULAR = 0.25;
}
