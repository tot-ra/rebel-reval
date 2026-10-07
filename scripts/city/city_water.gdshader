shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

// ADR 0031 city water: Baltic sea, the Hareapea stream and wet moat pools.
// Wind-driven waves travel along `wind_dir` (the same vector flags and ropes
// read), so every moving surface agrees on where the wind blows.

uniform vec3 shallow_color : source_color = vec3(0.22, 0.34, 0.33);
uniform vec3 deep_color : source_color = vec3(0.05, 0.12, 0.17);
uniform float opacity = 0.86;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wave_strength = 0.12;
uniform float flow_speed = 0.0; // > 0 for the stream: water runs along UV.x
uniform float time_scale = 1.0;

varying vec3 world_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}

float waves(vec2 p, float t) {
	vec2 w = normalize(wind_dir);
	float h = 0.0;
	h += sin(dot(p, w) * 0.55 - t * 1.6) * 0.5;
	h += sin(dot(p, vec2(w.y, -w.x) * 0.6 + w * 0.8) * 1.1 - t * 2.3) * 0.25;
	h += (noise(p * 0.7 - w * t * 0.9) - 0.5) * 0.6;
	return h;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * time_scale;
	VERTEX.y += waves(world_pos.xz, t) * wave_strength;
}

void fragment() {
	float t = TIME * time_scale;
	vec2 p = world_pos.xz;
	if (flow_speed > 0.0) {
		p = vec2(UV.x * 3.0 - t * flow_speed, UV.y * 3.0);
	}
	float e = 0.15;
	float h0 = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t);
	float hz = waves(p + vec2(0.0, e), t);
	vec3 n = normalize(vec3((h0 - hx) * 1.6, 1.0, (h0 - hz) * 1.6));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float depth_hint = clamp(COLOR.r, 0.0, 1.0);
	ALBEDO = mix(shallow_color, deep_color, depth_hint);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = mix(opacity * mix(0.7, 1.0, depth_hint), 1.0, fres * 0.6);
}
