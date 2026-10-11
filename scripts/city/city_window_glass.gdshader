shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform float opacity : hint_range(0.0, 1.0) = 0.56;
uniform vec3 glass_tint = vec3(0.57, 0.67, 0.56);
varying vec3 pane_pos;

void vertex() {
	pane_pos = VERTEX;
}
void fragment() {
	// Cheap two-sided uneven glazing, also supported by GL Compatibility.
	// No screen-texture refraction: multiple windows must not sample each other.
	float waves = sin(pane_pos.y * 29.0 + sin(dot(pane_pos.xz, vec2(7.0, 11.0))))
		* sin(dot(pane_pos.xz, vec2(31.0, 23.0)));
	ALBEDO = glass_tint * (0.85 + waves * 0.1);
	ALPHA = clamp(opacity + waves * 0.07, 0.0, 1.0);
	ROUGHNESS = mix(0.22, 0.72, opacity);
	SPECULAR = 0.35;
}
