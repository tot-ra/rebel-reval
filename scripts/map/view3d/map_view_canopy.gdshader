shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.30, 0.42, 0.26);
uniform float sway_strength = 0.05;
uniform float shade_bottom = 0.62;
uniform vec2 wind_direction = vec2(0.9285, 0.3714);
uniform float wind_strength = 0.22;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wind = wind_direction / max(length(wind_direction), 0.001);
	vec2 across = vec2(-wind.y, wind.x);
	float strength = clamp(wind_strength, 0.0, 1.0);
	float phase = dot(world.xz, wind) * 0.65 - TIME * 1.4;
	float gust = 0.55 + 0.30 * sin(phase) + 0.15 * sin(phase * 0.43 + TIME * 0.37);
	float flutter = sin(TIME * 5.3 + dot(world, vec3(4.1, 2.7, 3.3)) + COLOR.g * 13.0);
	// Bushes and legacy canopy primitives share this material but have no
	// leaf UV contract. Only explicitly tagged leaves use petiole pinning.
	float weight = UV2.x > 0.5 ? UV.y * UV.y : clamp(VERTEX.y * 0.4 + 0.4, 0.0, 1.0);
	vec2 displace = (wind * (0.35 + gust) + across * flutter * 0.32)
		* sway_strength * strength * weight;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(displace.x, flutter * sway_strength * strength * weight * 0.18, displace.y);
}

void fragment() {
	// cull_disabled already orients backface normals in GL Compatibility.
	float across = abs(UV.x - 0.5);
	float pixel = max(fwidth(UV.x), 0.012);
	float midrib = 1.0 - smoothstep(0.012, 0.012 + pixel, across);
	float vein_phase = (UV.y - across * 0.65) * 9.0;
	float veins = 1.0 - smoothstep(0.04, 0.04 + max(fwidth(vein_phase), 0.08), abs(fract(vein_phase) - 0.5));
	float leaf_tag = step(0.5, UV2.x);
	float shade = mix(mix(1.05, shade_bottom, clamp(UV.y, 0.0, 1.0)),
		mix(shade_bottom, 1.03, smoothstep(0.0, 0.7, UV.y)), leaf_tag);
	ALBEDO = base_color * COLOR.rgb * shade * (1.0 + leaf_tag * (midrib * 0.14 + veins * 0.045));
	BACKLIGHT = ALBEDO * 0.38 * (1.0 - midrib * 0.4);
	ROUGHNESS = 0.76;
	SPECULAR = 0.28;
}
