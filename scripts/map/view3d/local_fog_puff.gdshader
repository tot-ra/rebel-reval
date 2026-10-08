shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, blend_mix;

// Camera-facing soft puff. Terrain/wall intersections fade using opaque depth,
// not just UV edges: a vertical card sliced at its middle made straight stripes
// in the orthographic overview. Draw BEFORE screen-reading water materials so
// Compatibility still exposes opaque depth (see LocalFogBanks.FOG_RENDER_PRIORITY).
//
// The puff carries its own lighting because an unshaded sprite would glow at night and
// ignore the sun. A fake sphere normal from the quad UV gives a lit side, and a
// Henyey-Greenstein lobe brightens the rim when the camera looks toward the sun or moon.
uniform float bank_strength : hint_range(0.0, 1.0) = 0.0;
uniform float max_alpha : hint_range(0.0, 1.0) = 0.5;
// Unit vector toward the dominant light (sun, or moon at night), world space.
uniform vec3 light_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 light_color : source_color = vec3(1.0, 0.93, 0.8);
// 0..1 how much of that light reaches the fog (cloud cover, night, horizon).
uniform float light_amount : hint_range(0.0, 1.5) = 1.0;
uniform vec3 ambient_color : source_color = vec3(0.72, 0.78, 0.86);
uniform float ambient_amount : hint_range(0.0, 1.5) = 1.0;
uniform float forward_scatter : hint_range(0.0, 2.0) = 0.8;
uniform float anisotropy : hint_range(0.0, 0.95) = 0.55;
// Camera distance over which a puff fades in, so one never swallows the lens.
uniform float fade_near = 2.5;
uniform float fade_far = 9.0;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float intersection_softness = 2.5;
uniform float ground_height = 0.0;

varying float v_seed;
varying float v_height;

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
	float scale_x = length(MODEL_MATRIX[0].xyz);
	float scale_y = length(MODEL_MATRIX[1].xyz);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 front = INV_VIEW_MATRIX[2].xyz;
	mat4 world = mat4(
		vec4(right * scale_x, 0.0),
		vec4(up * scale_y, 0.0),
		vec4(front, 0.0),
		vec4(MODEL_MATRIX[3].xyz, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	v_height = (world * vec4(VERTEX, 1.0)).y - ground_height;
	v_seed = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
}

float henyey_greenstein(float cos_theta, float g) {
	float denom = max(1.0 + g * g - 2.0 * g * cos_theta, 1e-3);
	return (1.0 - g * g) / (denom * sqrt(denom)) * 0.07958; // 1 / (4 pi)
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float height01 = 1.0 - UV.y; // 0 at the foot, 1 at the top

	// Soft silhouette: rounded in X, fading in at the foot (so it never cuts the ground)
	// and out at the top (so the quad has no hard upper edge against the sky).
	float across = clamp(1.0 - p.x * p.x, 0.0, 1.0);
	float vertical = smoothstep(0.0, 0.3, height01) * (1.0 - smoothstep(0.4, 1.0, height01));
	// Elliptical support has no long straight horizontal shoulders.
	float ellipse = 1.0 - smoothstep(0.15, 1.0, dot(p, p));
	float shape = pow(across, 1.2) * vertical * ellipse;
	vec2 q = UV * vec2(3.2, 1.6) + vec2(v_seed * 37.0, v_seed * 11.0);
	float wisps = value_noise(q + vec2(TIME * 0.03, 0.0)) * 0.6
		+ value_noise(q * 2.3 - vec2(TIME * 0.05, 0.0)) * 0.4;
	float density = shape * mix(0.3, 1.0, wisps);

	// Fake sphere normal in view space and the light direction in the same space.
	vec3 n = normalize(vec3(p.x, (height01 - 0.5) * 2.0 * 0.6, sqrt(max(1.0 - p.x * p.x, 0.08))));
	vec3 l = normalize((VIEW_MATRIX * vec4(light_dir, 0.0)).xyz);
	vec3 view_ray = normalize(VERTEX);
	float wrap = clamp(dot(n, l) * 0.5 + 0.5, 0.0, 1.0);
	// Rim light: strongest where the puff thins out and the camera faces the light.
	float rim = 1.0 - clamp(density * 1.6, 0.0, 1.0);
	float scatter = henyey_greenstein(dot(view_ray, l), anisotropy) * forward_scatter * rim;
	vec3 lit = light_color * light_amount * (wrap * 0.75 + scatter);
	vec3 color = ambient_color * ambient_amount + lit;

	float near_fade = smoothstep(fade_near, fade_far, -VERTEX.z);
	float scene_depth = texture(depth_texture, SCREEN_UV).r;
	float contact_fade = 1.0;
	// Reverse-Z sky is zero; do not divide its infinite far-plane w by zero.
	if (scene_depth > 1e-6) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, scene_depth) * 2.0 - 1.0;
#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, scene_depth);
#endif
		vec4 scene_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		float scene_z = scene_view.z / scene_view.w;
		contact_fade = smoothstep(0.0, intersection_softness, VERTEX.z - scene_z);
	}
	float ground_fade = smoothstep(0.0, 1.2, v_height);
	ALBEDO = min(color, vec3(1.6));
	ALPHA = clamp(density, 0.0, 1.0) * COLOR.a * pow(bank_strength, 0.7) * max_alpha * near_fade * contact_fade * ground_fade;
}
