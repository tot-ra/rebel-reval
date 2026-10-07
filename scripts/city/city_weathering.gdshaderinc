// Shared weathering for city walls and roofs (ADR 0031). The ground height
// comes from the city heightfield texture, so any wall knows how far above the
// street it is: rising damp, splash dirt and green algae collect at the foot,
// rain streaks run down from eaves and sills, roofs gather moss and lichen.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_height : filter_linear, repeat_disable;
uniform vec4 ground_rect = vec4(0.0, 0.0, 1.0, 1.0); // origin.xz, size.xz (world units)
uniform vec3 base_tint : source_color = vec3(1.0);
uniform vec3 uv_scale = vec3(0.4);
uniform float roughness_base = 0.92;
uniform float wetness = 0.0;
uniform float age = 1.0; // 0 crisp, 1 well weathered

varying vec3 w_pos;
varying vec3 w_nrm;

float wh(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float wnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(wh(i), wh(i + vec2(1, 0)), u.x), mix(wh(i + vec2(0, 1)), wh(i + vec2(1, 1)), u.x), u.y);
}

float wfbm(vec2 p) {
	return wnoise(p) * 0.55 + wnoise(p * 2.07 + 3.1) * 0.3 + wnoise(p * 4.3 + 7.7) * 0.15;
}

float ground_at(vec2 xz) {
	return texture(ground_height, (xz - ground_rect.xy) / ground_rect.zw).r;
}
