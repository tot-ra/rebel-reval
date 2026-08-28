shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.86, 0.84, 0.76);
uniform float sway_strength = 0.22;
uniform vec2 wind_direction = vec2(0.9285, 0.3714);
uniform float wind_strength = 0.22;
uniform vec2 free_edge = vec2(0.0, 1.0);

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 1.1 + world.z * 0.85;
	float power = mix(0.3, 1.55, clamp(wind_strength, 0.0, 1.0));
	float free_t = clamp(UV.x * free_edge.x + UV.y * free_edge.y, 0.0, 1.0);
	float weight = free_t * free_t;
	float gust = sin(TIME * (1.1 + wind_strength * 0.7) + phase);
	float ripple = sin(TIME * 3.2 + phase * 2.1 + UV.x * 6.0) * 0.55
		+ sin(TIME * 5.1 + phase * 1.4 + UV.y * 4.5) * 0.3;
	vec2 wind = normalize(wind_direction);
	vec2 across = vec2(-wind.y, wind.x);
	vec2 displace = wind * (power * (0.75 + 0.25 * gust) + ripple * 0.35)
		+ across * ripple * 0.65;
	// Convert world XZ sway into model space so rotated boats and poles still
	// billow downwind instead of shearing along local axes.
	vec3 world_delta = vec3(displace.x, ripple * 0.12 * power, displace.y)
		* sway_strength * weight;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(world_delta, 0.0)).xyz;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = base_color * COLOR.rgb;
	ROUGHNESS = 0.92;
}
