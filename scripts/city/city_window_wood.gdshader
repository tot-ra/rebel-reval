shader_type spatial;
render_mode cull_back;

varying vec3 wood_pos;
varying vec3 wood_normal;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
		mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1)), f.x), f.y);
}
void vertex() {
	wood_pos = VERTEX;
	wood_normal = NORMAL;
}
void fragment() {
	// Rotate grain with each wall, not the world axes. Metre-scale coordinates
	// keep this continuous when merged chunks are split for interior cutaways.
	vec2 along = vec2(dot(wood_pos.xz, vec2(wood_normal.z, -wood_normal.x)), wood_pos.y);
	float grain = noise21(along * vec2(95.0, 2.5));
	float cracks = smoothstep(0.74, 0.91, grain);
	float worn = smoothstep(0.40, 0.72, noise21(along * vec2(8.0, 5.0)));
	vec3 paint = pow(COLOR.rgb, vec3(2.2));
	vec3 bare = vec3(0.18, 0.125, 0.075) * mix(0.75, 1.3, grain);
	float rain = smoothstep(0.6, 0.86, noise21(along * vec2(23.0, 0.8)));
	ALBEDO = mix(paint, bare, worn * 0.55) * (1.0 - cracks * 0.33 - rain * 0.12);
	ROUGHNESS = 0.88;
	SPECULAR = 0.18;
}
