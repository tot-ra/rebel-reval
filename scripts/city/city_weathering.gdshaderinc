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

// Photographic growth plates (tools/assets/build_wall_growth_plates.py), bound
// as shader defaults by CityBuildingBuilder.bind_ground. Moss A = cushion
// height, lichen A = rosette mask. Unbound plates read transparent, so a wall
// drawn before bind_ground grows nothing instead of opaque white moss.
#include "res://scripts/city/city_growth_plates.gdshaderinc"

// R-1661: moss and lichen on shaded masonry. `north` is how much the face
// looks away from the sun (world -Z), `above` its height over the street.
// Moss stays in the damp foot zone; lichen rosettes are sparse crusts on the
// stone above, so a wall still reads as its own colour (R-1465: blotchy green
// reads as camouflage). `nm` (normal-map texel) and `rough` take the moss
// relief and its matte surface.
vec3 shade_growth(vec3 col, inout vec3 nm, inout float rough, vec3 pos, vec3 nrm, float above, float amount) {
	float north = clamp(-nrm.z, 0.0, 1.0) * (1.0 - abs(nrm.y));
	if (north <= 0.0 || amount <= 0.0) {
		return col;
	}
	vec2 wp = vec2(dot(pos.xz, vec2(nrm.z, -nrm.x)), pos.y);
	float ragged = wfbm(wp * 1.6);
	float reach = 0.3 + ragged * 0.85 + north * 0.35;
	// Coverage climbs from the street: densest in the splash zone, thinning to
	// single cushions at the ragged upper edge. Colonies are patchy: broad
	// gaps of bare stone between them, never one even band.
	float cover = (1.0 - smoothstep(reach * 0.2, reach, above)) * north * amount;
	float colonies = wfbm(wp * 0.75 + 11.0) * 0.7 + wnoise(wp * 3.1) * 0.3;
	cover *= smoothstep(0.3, 0.62, colonies) * 0.85;
	// Recessed (darker) mortar and hollows hold water: moss starts there.
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	cover = clamp(cover + (0.28 - lum) * 0.4 * step(0.02, cover), 0.0, 1.0);
	// R-1747: shared multi-species sample (feather carpet, small domed
	// cushions, hoary grimmia), warped and colony-mixed against tile repeat.
	vec3 moss_n;
	vec4 moss_s = growth_moss_sample(wp, GROWTH_WALL_SPECIES, moss_n);
	// The cushion height is the edge: low cover leaves only crowns standing.
	float moss = smoothstep(1.0 - cover - 0.06, 1.0 - cover + 0.06, moss_s.a);
	// Damp halo: stone round the colonies stays wet and dark.
	col *= mix(1.0, 0.72, smoothstep(0.05, 0.5, cover) * (1.0 - moss));
	// Shaded north moss is deeper than the sunlit plate; higher, drier
	// cushions yellow and brown at the tips.
	float dry = smoothstep(0.3, 1.0, above / max(reach, 0.1)) * (0.5 + wnoise(wp * 0.9 + 4.0) * 0.5);
	vec3 moss_col = growth_season(moss_s.rgb * mix(vec3(0.62, 0.7, 0.5), vec3(0.78, 0.72, 0.5), dry), moss_s.a);
	col = mix(col, moss_col, moss);
	nm = mix(nm, moss_n, moss);
	rough = mix(rough, 0.97, moss);
	// Lichen: rosettes a few centimetres across in sparse colonies above the moss.
	vec4 crust = texture(lichen_tex, wp / 0.5 + vec2(0.31, 0.17));
	float colony = smoothstep(0.42, 0.62, wfbm(wp * 0.45 + 3.0));
	float lichen = crust.a * smoothstep(0.5, 1.3, above) * north * amount * colony * (1.0 - moss);
	// Warmed a little: pale crusts otherwise pick up the blue sky fill.
	vec3 lichen_col = crust.rgb * vec3(0.95, 0.95, 0.8) * clamp(lum * 2.0, 0.55, 0.9);
	return mix(col, lichen_col, lichen * 0.7);
}
