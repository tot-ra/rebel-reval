shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Moat water: murky, mostly opaque, and soft where it meets the bank. The depth
// buffer gives the water column at each pixel, so the edge fades into mud instead
// of cutting off, and colour deepens from silty green to dark with depth.
// Wind-driven waves travel along `wind_dir` (the same vector flags and ropes
// read), so every moving surface agrees on where the wind blows.

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 shallow_color : source_color = vec3(0.26, 0.30, 0.17);
uniform vec3 deep_color : source_color = vec3(0.07, 0.10, 0.07);
uniform vec3 mud_color : source_color = vec3(0.30, 0.24, 0.15);
uniform float opacity = 0.93;
uniform float edge_soft = 0.55;
uniform float deep_depth = 1.6;
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
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 ground_view = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV * 2.0 - 1.0, raw * 2.0 - 1.0), 1.0);
	ground_view.xyz /= ground_view.w;
	float column = max(VERTEX.z - ground_view.z, 0.0);
	float depth_hint = clamp(column / deep_depth, 0.0, 1.0);
	float silt = noise(world_pos.xz * 0.35 + vec2(t * 0.02, 0.0));
	vec3 body = mix(shallow_color, deep_color, depth_hint);
	body = mix(body, shallow_color * 1.25, silt * 0.25 * (1.0 - depth_hint));
	ALBEDO = mix(mud_color, body, smoothstep(0.0, edge_soft * 1.6, column));
	ROUGHNESS = 0.22;
	METALLIC = 0.0;
	SPECULAR = 0.35;
	float rim = smoothstep(0.0, edge_soft, column);
	ALPHA = rim * mix(opacity * mix(0.78, 1.0, depth_hint), 1.0, fres * 0.4);
}
