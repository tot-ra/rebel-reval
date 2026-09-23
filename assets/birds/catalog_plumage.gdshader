shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// UV2.x separates feather, keratin and eye response without extra draw calls.
// UV2.y selects the catalogue's barred, spotted and streaked plumage.
// Barb frequency is coarse enough to survive gameplay distance; the previous
// 185-cycle sine was filtered away and left a smooth plastic vane.
void fragment() {
	vec2 cell = fract(UV);
	float feather = 1.0 - smoothstep(0.2, 0.5, UV2.x);
	float eye = smoothstep(0.8, 1.0, UV2.x);
	float keratin = smoothstep(0.35, 0.55, UV2.x) * (1.0 - eye);
	float from_shaft = abs(cell.x - 0.5);
	float phase = (cell.y * 0.82 + from_shaft * 0.4) * 36.0;
	float filter_width = max(fwidth(phase), 0.001);
	float barb = sin(phase) * (1.0 - smoothstep(0.4, 2.2, filter_width));
	float shaft = 1.0 - smoothstep(0.01, 0.038 + fwidth(cell.x), from_shaft);
	float vane_edge = smoothstep(0.16, 0.46, from_shaft);
	float tip_wear = smoothstep(0.68, 0.98, cell.y);
	float marking = 0.0;
	if (UV2.y > 0.5 && UV2.y < 1.5) {
		marking = smoothstep(0.52, 0.78, sin(cell.y * 59.0 + sin(cell.x * 37.0) * 1.5)) * 0.18;
	} else if (UV2.y > 1.5 && UV2.y < 2.5) {
		vec2 spot = fract(UV * vec2(7.0, 9.0) + vec2(sin(floor(UV.y * 9.0) * 5.3) * 0.4, 0.0)) - 0.5;
		marking = (1.0 - smoothstep(0.13, 0.23, length(spot * vec2(1.0, 0.65)))) * 0.57;
	} else if (UV2.y > 2.5) {
		marking = pow(max(0.0, sin(cell.x * 46.0 + cell.y * 8.0)), 9.0) * 0.28;
	}
	float ridge = pow(max(0.0, sin(cell.y * 28.0)), 5.0);
	float shade = feather * (marking + 0.08 * barb + 0.1 * shaft + 0.16 * vane_edge + 0.08 * tip_wear);
	ALBEDO = COLOR.rgb * (1.0 - shade - keratin * ridge * 0.1);
	ROUGHNESS = mix(mix(0.82, 0.52, keratin), 0.1, eye);
	SPECULAR = mix(mix(0.2, 0.38, keratin), 0.72, eye);
	NORMAL_MAP = vec3(0.5 + barb * 0.07 * feather, 0.5 + shaft * 0.09 * feather + keratin * ridge * 0.06, 1.0);
	NORMAL_MAP_DEPTH = 0.5;
}
