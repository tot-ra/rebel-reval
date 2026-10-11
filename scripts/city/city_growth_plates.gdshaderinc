// R-1684: photographic growth shared by masonry, roofs and wind-swayed bark.
// Albedo alpha stores cushion height / rosette mask, not surface transparency.
// Missing plates must leave the underlying material untouched.
// The weathered roof converts its finished colour with city_albedo, so its
// plates must use the same raw-input hint as the substrate on RD renderers.
// R-1747: three moss species. moss_tex is the domed cushion moss (R-1683),
// feather is a flat Hypnum carpet, grimmia small hoary limestone cushions.
#ifdef CITY_ROOF_PLATE
uniform sampler2D moss_tex : CITY_PLATE filter_linear_mipmap_anisotropic, repeat_enable, hint_default_transparent;
uniform sampler2D moss_feather_tex : CITY_PLATE filter_linear_mipmap_anisotropic, repeat_enable, hint_default_transparent;
uniform sampler2D moss_grimmia_tex : CITY_PLATE filter_linear_mipmap_anisotropic, repeat_enable, hint_default_transparent;
uniform sampler2D lichen_tex : CITY_PLATE filter_linear_mipmap_anisotropic, repeat_enable, hint_default_transparent;
#else
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_transparent;
uniform sampler2D moss_feather_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_transparent;
uniform sampler2D moss_grimmia_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_transparent;
uniform sampler2D lichen_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_transparent;
#endif
uniform sampler2D moss_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_feather_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_grimmia_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

// R-1747: seasonal moss colour, written by MapViewWindMaterials from the game
// date. rgb multiplies the plate colour, a is drought (dry tips brown).
global uniform vec4 moss_season_g;

// Species mixes per surface (domed cushion, feather carpet, grimmia). The
// domed plate is out of every mix: it was photographed at an angle, so at low
// cover only its dome crowns pass the height threshold and read as rows of
// identical half-circle scales (user review 2026-10-11). It stays bound for a
// later reshot plate.
const vec3 GROWTH_WALL_SPECIES = vec3(0.0, 1.0, 0.4);
const vec3 GROWTH_ROOF_SPECIES = vec3(0.0, 1.0, 0.7);
const vec3 GROWTH_BARK_SPECIES = vec3(0.0, 1.0, 0.0);

float growth_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float growth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(growth_hash(i), growth_hash(i + vec2(1, 0)), u.x),
		mix(growth_hash(i + vec2(0, 1)), growth_hash(i + vec2(1, 1)), u.x), u.y);
}

vec3 growth_unpack_normal(vec3 texel, mat2 rotation) {
	vec3 n = texel * 2.0 - 1.0;
	// Undo the sample's UV rotation so relief stays in the mesh tangent frame.
	n.xy = transpose(rotation) * n.xy;
	return n;
}

// One cushion texel (rgb colour, a height) and its tangent normal (packed
// 0..1) at surface metres `wp`. Each species tiles at its own scale and angle
// and a low-frequency colony field decides which one grows where, so a wall
// carries patches of different mosses instead of one repeating plate.
vec4 growth_moss_sample(vec2 wp, vec3 species, out vec3 normal_packed) {
	// A few centimetres of warp bend the straight tile period out of sight.
	vec2 p = wp + (vec2(growth_noise(wp * 1.7), growth_noise(wp * 1.7 + 9.3)) - 0.5) * 0.09;
	mat2 r_a = mat2(vec2(1.0, 0.0), vec2(0.0, 1.0));
	mat2 r_b = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	mat2 r_c = mat2(vec2(-0.28, 0.96), vec2(-0.96, -0.28));
	// The domed plate is tiled small: its cushions read as 2-4 cm tufts.
	vec2 ua = p / 0.2;
	vec2 ub = r_b * p / 0.42 + 0.37;
	vec2 uc = r_c * p / 0.19 + 0.71;
	vec4 sa = texture(moss_tex, ua);
	vec4 sb = texture(moss_feather_tex, ub);
	vec4 sc = texture(moss_grimmia_tex, uc);
	// Colony field: each species owns patches tens of centimetres across; a
	// taller cushion still wins at a boundary, as overlapping colonies do.
	vec3 field = vec3(growth_noise(wp * 1.1 + 3.0), growth_noise(wp * 0.8 + 11.0),
		growth_noise(wp * 1.3 + 23.0));
	vec3 score = field * species + vec3(sa.a, sb.a, sc.a) * 0.25
		- step(species, vec3(0.0001)) * 4.0;
	float top = max(score.x, max(score.y, score.z));
	vec3 w = smoothstep(vec3(-0.1), vec3(0.0), score - top);
	w /= max(w.x + w.y + w.z, 0.0001);
	vec4 s = sa * w.x + sb * w.y + sc * w.z;
	vec3 n = growth_unpack_normal(texture(moss_normal_tex, ua).rgb, r_a) * w.x
		+ growth_unpack_normal(texture(moss_feather_normal_tex, ub).rgb, r_b) * w.y
		+ growth_unpack_normal(texture(moss_grimmia_normal_tex, uc).rgb, r_c) * w.z;
	normal_packed = normalize(n) * 0.5 + 0.5;
	// Colony-scale hue drift, and shoot-scale jitter on the height so cushion
	// edges never repeat the same arc. Unbound (alpha 0) texels stay bare.
	s.rgb *= mix(vec3(0.9, 1.04, 0.84), vec3(1.07, 0.96, 1.02), growth_noise(wp * 0.55 + 41.0));
	s.a = clamp(s.a + (growth_noise(p * 18.0) - 0.5) * 0.16, 0.0, 1.0) * step(0.0001, s.a);
	return s;
}

// Season on the finished moss colour: tint by the date, and in drought the
// tallest (driest) shoot tips go yellow-brown first.
vec3 growth_season(vec3 moss_col, float height) {
	vec3 c = moss_col * moss_season_g.rgb;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	float dry = moss_season_g.a * smoothstep(0.35, 0.95, height);
	return mix(c, lum * vec3(1.3, 1.02, 0.58), dry * 0.7);
}

float growth_height_mask(float height, float coverage) {
	float cover = clamp(coverage, 0.0, 1.0);
	// At zero coverage even the tallest cushion must disappear; transparent
	// fallback texels must also stay absent at full coverage.
	return smoothstep(1.0 - cover - 0.06, 1.0 - cover + 0.06, height)
		* step(0.0001, cover) * step(0.0001, height);
}

// wp is surface-local metres in the tangent frame, independent of wind sway.
// Keep ecological coverage in the caller; plates supply the small-scale edges,
// colour and relief. The returned moss mask also drives rain response on bark.
float shade_growth_plates(inout vec3 col, inout vec3 nm, inout float rough,
		vec2 wp, float moss_cover, float lichen_cover, vec3 moss_tint, vec3 species) {
	vec3 moss_normal;
	vec4 cushion = growth_moss_sample(wp, species, moss_normal);
	float moss = growth_height_mask(cushion.a, moss_cover);
	col = mix(col, growth_season(cushion.rgb * moss_tint, cushion.a), moss);
	nm = mix(nm, moss_normal, moss);
	rough = mix(rough, 0.97, moss);

	vec4 crust = texture(lichen_tex, wp / 0.5 + vec2(0.31, 0.17));
	// Whole rosettes where the caller's field allows: thresholding the mask
	// like a height kept only the rims and drew empty soap-bubble rings.
	float lichen = crust.a * clamp(lichen_cover * 3.0, 0.0, 1.0) * (1.0 - moss);
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	vec3 lichen_col = crust.rgb * vec3(0.95, 0.95, 0.8) * clamp(lum * 2.0, 0.55, 0.9);
	col = mix(col, lichen_col, lichen);
	// Thin crusts retain the substrate relief rather than inventing a normal plate.
	rough = mix(rough, 0.95, lichen);
	return moss;
}
