shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, shadows_disabled;

// Hanging fishing net: the upper rope is fixed to the oak rail while the free
// lower half follows the shared harbor wind. Height-based pinning works for the
// diamond net, outline rope, cork floats, and sinkers without CPU cloth bodies.
// World-space phasing prevents all six authored racks from moving in lockstep.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 wind_direction = vec2(0.9285, 0.3714);
uniform float wind_strength = 0.22;
uniform float sway_strength = 0.098;
uniform float pin_height = 1.36;
uniform float pin_fade = 0.17;
instance uniform float motion_scale = 1.0;
instance uniform float motion_phase = 0.0;
uniform float surface_roughness = 0.96;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wind = normalize(wind_direction);
	vec2 across = vec2(-wind.y, wind.x);
	float strength = clamp(wind_strength, 0.0, 1.0);
	float power = mix(0.28, 1.35, strength);
	float phase = world.x * 0.83 + world.z * 1.17 + motion_phase;

	// The top lashing remains exact. Motion transitions smoothly below it so the
	// strand junctions bend instead of revealing a rigid horizontal hinge.
	float free_weight = 1.0 - smoothstep(pin_height - pin_fade, pin_height, VERTEX.y);
	free_weight *= mix(0.52, 1.0, free_weight);

	// Slow pressure, irregular gusts, and a fine crosswind ripple give distinct
	// temporal scales. None use random state, so captures and clients stay stable.
	float slow = sin(TIME * (0.64 + strength * 0.38) + phase * 0.34);
	float gust = sin(TIME * 1.18 + phase * 0.51 + sin(TIME * 0.26 + phase) * 0.8);
	float ripple = sin(TIME * 3.35 + phase * 1.8 + VERTEX.y * 8.0)
		+ 0.42 * sin(TIME * 5.0 - phase * 2.3 + VERTEX.x * 11.0);
	float pressure = 0.34 * power + slow * 0.22 * power + gust * 0.12 * power;
	vec2 horizontal = wind * pressure + across * ripple * (0.022 + strength * 0.030);
	float lift = (slow * 0.015 + ripple * 0.005) * power;
	vec3 world_delta = vec3(horizontal.x, lift, horizontal.y)
		* sway_strength * free_weight * motion_scale;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(world_delta, 0.0)).xyz;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = texture(albedo_texture, UV).rgb;
	ROUGHNESS = surface_roughness;
	SPECULAR = 0.18;
}
