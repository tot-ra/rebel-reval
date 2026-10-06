shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, blend_add;

// Screen-space crepuscular rays (god rays). Additive full-screen quad: streaks fan
// out from the sun/moon's screen position. GL Compatibility has no volumetric fog,
// so the shafts are procedural angular noise, scaled on the CPU by haze, cloud
// gaps and sun elevation (see god_ray_pass.gd). No depth or screen texture is read
// (see the hint note in cloud_shadow_pass.gdshader), so rays are not occluded by
// geometry; strength stays low and the falloff keeps them to a soft atmospheric veil.
uniform vec2 light_uv = vec2(0.5, 0.2);
uniform vec3 ray_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 1.7778;
uniform float time_s = 0.0;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float angular_noise(float a) {
	float x = a * 18.0;
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), f);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - light_uv;
	d.x *= aspect;
	float dist = length(d);
	float ang = atan(d.y, d.x);
	// Two slowly drifting streak layers so the shafts shimmer instead of freezing.
	float streaks = angular_noise(ang + time_s * 0.01) * 0.6 + angular_noise(ang * 2.3 - time_s * 0.017) * 0.4;
	streaks = smoothstep(0.35, 0.95, streaks);
	float falloff = exp(-dist * 1.6);
	float core = smoothstep(0.0, 0.15, dist);
	float glow = exp(-dist * 5.0) * 0.5;
	float v = (streaks * falloff * core + glow) * strength;
	ALBEDO = ray_color * v;
	ALPHA = 1.0;
}
