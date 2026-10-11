shader_type spatial;
// Live charcoal in a forge pot. A burning lump is not orange all over: the
// surface is a dark grey ash crust, and heat shows through cracks and in the
// shaded gaps between lumps. Vertex COLOR.r carries per-lump heat (0 = dead,
// 1 = white-hot under the tuyere). Triplanar noise ridges draw the cracks and a
// slow world-space wave makes the glow breathe like bellows draught.
render_mode cull_back;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float energy = 4.0;
uniform float crack_scale = 2.4;

varying vec3 v_world;
varying vec3 v_world_normal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

float triplanar(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(noise_tex, p.zy).r * w.x
		+ texture(noise_tex, p.xz).r * w.y
		+ texture(noise_tex, p.xy).r * w.z;
}

void fragment() {
	float heat = COLOR.r;
	float n = triplanar(v_world * crack_scale, v_world_normal);
	float fine = triplanar(v_world * crack_scale * 3.1, v_world_normal);
	// Ridge of the noise field = thin glowing fissure through the crust.
	float crack = 1.0 - smoothstep(0.0, 0.07 + heat * 0.06, abs(n - 0.5));
	// Down-facing and lower faces sit inside the pile and glow the hottest.
	float buried = clamp(0.55 - v_world_normal.y * 0.5, 0.0, 1.0);
	float breathe = texture(noise_tex, v_world.xz * 0.6 + vec2(TIME * 0.05, TIME * 0.032)).r;
	float glow = heat * (crack * 0.9 + buried * 0.55 + fine * 0.25) * (0.7 + breathe * 0.6);
	glow = clamp(glow, 0.0, 1.4);

	vec3 ash = mix(vec3(0.05, 0.047, 0.045), vec3(0.12, 0.115, 0.11), fine * (1.0 - heat * 0.6));
	ALBEDO = ash;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	// Black-body ramp: dull red at low glow, orange, then yellow-white.
	vec3 hot = mix(vec3(0.55, 0.05, 0.0), vec3(1.0, 0.36, 0.04), smoothstep(0.1, 0.6, glow));
	hot = mix(hot, vec3(1.0, 0.78, 0.4), smoothstep(0.75, 1.3, glow));
	EMISSION = hot * glow * energy;
}
