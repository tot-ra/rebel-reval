shader_type spatial;
// Overlay for a damage-reduction ward on a character rig (R-1198).
// Draws lit, dark forged iron over the skinned body instead of a glowing bubble:
// the sheet spreads up from the feet, its leading edge carries temper colours
// (straw -> orange -> blue, like quenched steel), and it thins in a noise
// pattern so cloth and face detail stay readable under it.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

// 0..1 sweep of the iron sheet from the feet to the crown.
uniform float coverage : hint_range(0.0, 1.0) = 1.0;
// Overall opacity; the VFX fades it and flickers it before expiry.
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float body_height = 2.0;
uniform vec3 iron_color : source_color = vec3(0.23, 0.235, 0.25);

varying float v_height;
varying vec3 v_world;

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z
	);
}

void vertex() {
	// VERTEX is already skinned here, so the sweep follows the animated pose.
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_height = (v_world.y - NODE_POSITION_WORLD.y) / max(body_height, 0.01);
}

void fragment() {
	float grain = value_noise(v_world * 9.0);
	float patches = value_noise(v_world * 3.1 + vec3(4.7));
	// Ragged leading edge: noise pushes the front up and down a little.
	float front = coverage * 1.12 - 0.06;
	float edge_distance = front - v_height + (patches - 0.5) * 0.12;
	float covered = smoothstep(0.0, 0.035, edge_distance);
	// Temper band just behind the front: hot straw/orange, cooling to blue.
	float band = 1.0 - smoothstep(0.0, 0.11, abs(edge_distance - 0.04));
	vec3 temper = mix(vec3(0.95, 0.42, 0.08), vec3(0.98, 0.78, 0.32), band);
	vec3 blued = vec3(0.16, 0.2, 0.32);
	float cooled = smoothstep(0.04, 0.3, edge_distance);
	vec3 base = mix(iron_color, iron_color * 0.62, grain * 0.7);
	// A faint blued cast survives on the cooled metal, like oil-quenched iron.
	base = mix(base, blued, 0.18 * cooled * patches);
	ALBEDO = mix(temper, base, cooled);
	METALLIC = 0.92;
	ROUGHNESS = mix(0.28, 0.55, grain);
	// Rim sheen keeps the metal readable from the high orthographic camera.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = temper * band * covered * 2.2 + vec3(0.5, 0.55, 0.62) * rim * 0.22 * cooled;
	float coverage_alpha = mix(0.55, 0.82, patches) * covered;
	ALPHA = clamp(max(coverage_alpha, band * covered), 0.0, 1.0) * strength;
}
