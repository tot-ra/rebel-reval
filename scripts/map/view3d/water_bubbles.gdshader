shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = vec3(0.65, 0.78, 0.80);
	ROUGHNESS = 0.08;
	SPECULAR = 0.5;
	ALPHA = 0.05 + rim * 0.65;
}
