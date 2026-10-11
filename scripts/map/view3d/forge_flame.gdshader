shader_type spatial;
// Soft furnace flame tongue for ForgeFlame3D particles. A flat fan mesh reads
// as a cut-out shape; real charcoal flame is a translucent sheet whose edge is
// constantly torn by turbulence. Each billboard is a teardrop mask eroded by
// two noise octaves scrolling upward, so tongues split, curl, and detach at the
// tip. Particle COLOR carries the cooling ramp; the core stays whiter.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float energy = 2.6;
uniform float rise_speed = 1.35;

varying float v_seed;
varying float v_life;

void vertex() {
	// Camera-facing particle billboard that keeps per-particle scale (the same
	// matrix Godot builds for BILLBOARD_PARTICLES, without the spin: flames
	// must stay upright and only lean through the noise distortion).
	mat4 face = mat4(
		normalize(INV_VIEW_MATRIX[0]),
		normalize(INV_VIEW_MATRIX[1]),
		normalize(INV_VIEW_MATRIX[2]),
		MODEL_MATRIX[3]
	);
	face = face * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * face;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	// anim_offset is randomised per particle and never animated: a stable seed.
	v_seed = INSTANCE_CUSTOM.z;
	v_life = INSTANCE_CUSTOM.y;
}

void fragment() {
	float h = 1.0 - UV.y;
	float t = TIME * rise_speed;
	vec2 seed_offset = vec2(v_seed * 7.13, v_seed * 3.71);
	float n1 = texture(noise_tex, vec2(UV.x * 0.55, UV.y * 0.7 + t) + seed_offset).r;
	float n2 = texture(noise_tex, vec2(UV.x * 1.3, UV.y * 1.6 + t * 1.7) + seed_offset * 1.9).r;
	float noise = n1 * 0.62 + n2 * 0.38;

	// Turbulence bends the tongue more the higher it climbs.
	float x = (UV.x - 0.5) * 2.0 + (n1 - 0.5) * 1.1 * h;
	float width = mix(0.78, 0.1, pow(h, 0.8));
	float body = 1.0 - smoothstep(width * 0.35, width, abs(x));
	float base = smoothstep(0.0, 0.16, h);
	// Erosion threshold climbs with height, so the tip shreds into licks.
	float erode = smoothstep(h * 0.75 - 0.05, h * 0.75 + 0.28, noise);
	// Distortion can push the tongue past the quad; fade the borders so no
	// straight cut-off edge ever shows.
	float border = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	float mask = body * base * erode * border;

	vec3 color = COLOR.rgb;
	float core = body * (1.0 - h) * (1.0 - h);
	color = mix(color, vec3(1.0, 0.8, 0.5), core * 0.3);
	ALBEDO = color * energy;
	ALPHA = clamp(mask * COLOR.a, 0.0, 1.0);
}
