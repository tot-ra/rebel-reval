shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// UV2.x separates feather, keratin and eye response without extra draw calls.
// UV2.y selects the catalogue's barred, spotted and streaked plumage.
void fragment() {
	vec2 cell = fract(UV);
	float feather = 1.0 - smoothstep(0.2, 0.5, UV2.x);
	float eye = smoothstep(0.8, 1.0, UV2.x);
	float phase = (cell.y + abs(cell.x - 0.5) * 0.48) * 185.0;
	float filter_width = max(fwidth(phase), 0.001);
	float barb = sin(phase) * (1.0 - smoothstep(0.8, 3.0, filter_width));
	float shaft = 1.0 - smoothstep(0.006, 0.025 + fwidth(cell.x), abs(cell.x - 0.5));
	float marking = 0.0;
	if (UV2.y > 0.5 && UV2.y < 1.5) {
		marking = smoothstep(0.52, 0.78, sin(cell.y * 59.0 + sin(cell.x * 37.0) * 1.5)) * 0.18;
	} else if (UV2.y > 1.5 && UV2.y < 2.5) {
		vec2 spot = fract(UV * vec2(7.0, 9.0) + vec2(sin(floor(UV.y * 9.0) * 5.3) * 0.4, 0.0)) - 0.5;
		marking = (1.0 - smoothstep(0.13, 0.23, length(spot * vec2(1.0, 0.65)))) * 0.57;
	} else if (UV2.y > 2.5) {
		marking = pow(max(0.0, sin(cell.x * 46.0 + cell.y * 8.0)), 9.0) * 0.28;
	}
	ALBEDO = COLOR.rgb * (1.0 - feather * (marking + 0.026 * barb + 0.035 * shaft));
	ROUGHNESS = mix(mix(0.86, 0.48, smoothstep(0.2, 0.5, UV2.x)), 0.14, eye);
	SPECULAR = mix(0.25, 0.62, eye);
	NORMAL_MAP = vec3(0.5 + barb * 0.025 * feather, 0.5 + shaft * 0.04 * feather, 1.0);
	NORMAL_MAP_DEPTH = 0.35;
}
