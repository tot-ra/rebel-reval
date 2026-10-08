shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, blend_mix;

// Heat shimmer on the far horizon (horizon_mirage.gd): a short open cylinder around the
// camera whose face is a band of wavering bright streaks just above the ground line,
// like the pale pool a hot road shows far away (an inferior mirage). It does not warp
// the scene behind it (screen reads are unreliable in this pipeline); it is an
// additive-looking veil in the sky/horizon hue.
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 band_color : source_color = vec3(0.85, 0.9, 0.95);
uniform float band_height = 30.0;

varying vec3 v_world;
varying vec3 v_center;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_center = MODEL_MATRIX[3].xyz;
}

void fragment() {
	float h = clamp(UV.y, 0.0, 1.0); // UV.y 0 at the foot of the band, 1 at the top
	float angle = atan(v_world.x - v_center.x, v_world.z - v_center.z);
	// Streaks: long in azimuth, thin in height, rising and wobbling with time.
	float wobble = value_noise(vec2(angle * 9.0, TIME * 0.6)) * 2.0 - 1.0;
	float streak_y = h * 22.0 - TIME * 0.9 + wobble * 1.4;
	float streaks = value_noise(vec2(angle * 48.0, streak_y));
	streaks = smoothstep(0.42, 0.85, streaks);
	// Patchy along the horizon so it never reads as a uniform ring.
	float patches = smoothstep(0.35, 0.75, value_noise(vec2(angle * 5.0, 3.7 + TIME * 0.05)));
	float envelope = smoothstep(0.0, 0.12, h) * (1.0 - smoothstep(0.35, 1.0, h));
	ALBEDO = band_color;
	ALPHA = clamp(streaks * patches * envelope * strength * 0.8, 0.0, 1.0);
}
