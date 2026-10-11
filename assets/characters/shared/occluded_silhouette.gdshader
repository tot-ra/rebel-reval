shader_type spatial;
render_mode unshaded, depth_test_inverted, depth_draw_never, cull_back;

// Ghost pass for actors hidden behind view geometry: the inverted depth test
// makes this overlay draw only where the actor is occluded, as a translucent
// fill with a brighter rim so the pose stays readable through walls and roofs.
uniform vec4 fill_color : source_color = vec4(0.98, 0.84, 0.5, 0.42);
uniform vec4 rim_color : source_color = vec4(1.0, 0.94, 0.72, 0.9);
uniform float rim_power : hint_range(0.5, 8.0) = 2.4;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	vec4 color = mix(fill_color, rim_color, rim);
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
