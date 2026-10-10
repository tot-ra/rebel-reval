// Shared weathering for city walls and roofs (ADR 0031). The ground height
// comes from the city heightfield texture, so any wall knows how far above the
// street it is: rising damp, splash dirt and green algae collect at the foot,
// rain streaks run down from eaves and sills, roofs gather moss and lichen.

#ifdef CITY_ROOF_PLATE
uniform sampler2D albedo_tex : CITY_PLATE filter_linear_mipmap_anisotropic, repeat_enable;
#else
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
#endif
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

// R-1661: moss and lichen on shaded masonry. `north` is how much the face
// looks away from the sun (world -Z), `above` its height over the street.
// Moss stays in the damp foot zone and the joints; lichen rosettes are small
// pale spots on the stone above, so a wall still reads as its own colour
// (R-1465: blotchy green reads as camouflage).
vec3 shade_growth(vec3 col, vec3 pos, vec3 nrm, float above, float amount) {
	float north = clamp(-nrm.z, 0.0, 1.0) * (1.0 - abs(nrm.y));
	if (north <= 0.0 || amount <= 0.0) {
		return col;
	}
	vec2 wp = vec2(dot(pos.xz, vec2(nrm.z, -nrm.x)), pos.y);
	float ragged = wfbm(wp * 1.6);
	float reach = 0.35 + ragged * 1.0 + north * 0.45;
	float foot = 1.0 - smoothstep(reach * 0.5, reach, above);
	// Fine grain breaks the moss into tufts so the stone shows between them.
	float tufts = wnoise(wp * 14.0) * 0.6 + wnoise(wp * 37.0) * 0.4;
	float moss = smoothstep(0.42, 0.62, ragged * 0.7 + tufts * 0.45) * foot * north * amount;
	// Moss takes the light and shade of the stone under it: keep the texture.
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	vec3 moss_col = mix(vec3(0.2, 0.27, 0.09), vec3(0.3, 0.37, 0.13), tufts) * clamp(lum * 2.2, 0.55, 1.2);
	col = mix(col, moss_col, clamp(moss, 0.0, 1.0) * 0.85);
	// Lichen: small crusts a few centimetres across, sparse, a little paler than the stone.
	vec2 sp = wp * 11.0;
	float rosette = smoothstep(0.74, 0.8, wnoise(sp) * 0.75 + wnoise(sp * 2.7 + 5.0) * 0.25);
	float lichen = rosette * smoothstep(0.6, 1.4, above) * north * amount
		* smoothstep(0.3, 0.55, wfbm(wp * 0.4 + 3.0));
	vec3 crust = mix(col, vec3(0.62, 0.66, 0.52), 0.65);
	return mix(col, crust, lichen * 0.75);
}
