shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.38, 0.48, 0.24);
uniform float sway_strength = 0.10;
uniform vec2 wind_direction = vec2(0.9285, 0.3714);
uniform float wind_strength = 0.22;
uniform vec2 interact_center = vec2(0.0);
uniform float interact_strength = 0.0;
uniform float interact_radius = 0.65;
uniform vec2 interact_push = vec2(0.0);

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wind = wind_direction / max(length(wind_direction), 0.001);
	vec2 across = vec2(-wind.y, wind.x);
	float strength = clamp(wind_strength, 0.0, 1.0);
	// Same advected broad pressure field as trees; fine flutter varies by tuft.
	float phase = dot(world.xz, wind) * 0.65 - TIME * 1.4;
	float gust = 0.55 + 0.30 * sin(phase) + 0.15 * sin(phase * 0.43 + TIME * 0.37);
	float flutter = sin(TIME * 4.1 + world.x * 3.7 + world.z * 2.3);
	float weight = UV.y * UV.y;
	vec2 displace = (wind * (0.35 + gust) + across * flutter * 0.16)
		* strength * sway_strength * weight;
	vec3 world_displace = vec3(displace.x, -length(displace) * 0.18, displace.y);
	if (interact_strength > 0.001 && interact_radius > 0.001) {
		vec2 offset = world.xz - interact_center;
		float dist = length(offset);
		float falloff = 1.0 - smoothstep(0.0, interact_radius, dist);
		falloff *= falloff;
		vec2 radial = dist > 0.001 ? offset / dist : vec2(0.0, 1.0);
		vec2 interact_disp = radial * 0.9 + interact_push * 0.55;
		float tip = interact_strength * weight * falloff;
		world_displace += vec3(interact_disp.x * tip, -tip * 0.22, interact_disp.y * tip);
	}
	// MultiMeshes rotate each tuft. Convert a world-space push back to local
	// space so adjacent plants bend downwind rather than following their yaw.
	VERTEX += inverse(mat3(MODEL_MATRIX)) * world_displace;
}

void fragment() {
	// cull_disabled already orients backface normals in GL Compatibility.
	float blade = clamp(UV.y, 0.0, 1.0);
	float midrib = 1.0 - smoothstep(0.025, 0.025 + max(fwidth(UV.x), 0.035), abs(UV.x - 0.5));
	ALBEDO = base_color * COLOR.rgb * mix(0.58, 1.12, sqrt(blade));
	ALBEDO *= 1.0 + midrib * 0.10;
	// Light-driven transmission, not emission: plants remain dark at night.
	BACKLIGHT = ALBEDO * (0.26 + blade * 0.14);
	ROUGHNESS = mix(0.94, 0.72, blade);
	SPECULAR = 0.25;
}
