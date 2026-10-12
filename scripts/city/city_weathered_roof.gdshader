shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// R-1760: shingle, board and thatch roofs as real courses, fully procedural
// from the roof UVs CityBuildingBuilder writes (u along the ridge, v down the
// slope from the ridge, both in metres), like city_tile_roof.gdshader. The old
// plate + thresholded fbm moss drew metre-wide blotches that read as military
// camouflage (R-1465); here every shingle, board and straw course has its own
// tone, relief and butt shadow, wood silvers with age and sun, and moss grows
// from the overlaps toward the eaves and on the north pitches.
//
// UV bands (CityBuildingBuilder._roof): v >= 0 the roof field, -2.5 < v <= -1
// the ridge capping (v = -1 - arc), v <= -3 the rolled eave/verge edge.
// COLOR.rgb is the per-house tint, COLOR.a the per-house seed (0..1) that
// picks board vs shingle, course sizes and how weathered the roof is.

#include "res://scripts/city/city_plate_hint.gdshaderinc"
#define CITY_ROOF_PLATE
#include "res://scripts/city/city_weathering.gdshaderinc"
#include "res://scripts/city/city_roof_cutaway.gdshaderinc"

uniform float moss = 0.5; // shingle and board gather moss, thatch greys and greens
uniform int cover = 0; // 0 split shingle (or long boards, by seed), 1 thatch
uniform float board_share = 0.3; // share of shingle-family houses with board roofs

const vec3 WOOD_FRESH = vec3(0.35, 0.26, 0.18);
const vec3 WOOD_SILVER = vec3(0.34, 0.345, 0.35);
const vec3 WOOD_DARK = vec3(0.16, 0.155, 0.15);
const vec3 STRAW_FRESH = vec3(0.44, 0.35, 0.21);
const vec3 STRAW_GREY = vec3(0.31, 0.295, 0.26);
const vec3 STRAW_ROT = vec3(0.2, 0.2, 0.155);
// Roof moss is the flat feather carpet only: the hoary grimmia plate (and
// its colony field) read as blue-grey blotches across a whole pitch.
const vec3 ROOF_MOSS_SPECIES = vec3(0.0, 1.0, 0.0);

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Overlapping split shingles: staggered joints, ragged butts, a shadow line
// under every course, the odd replaced (fresh) or rotten (dark) one.
vec3 shingles(vec2 uv, float seed, float wear, float sunny, float detail, out vec3 n_ts, out float crevice) {
	float hs = wh(vec2(seed * 173.0, 11.0));
	float course_len = mix(0.28, 0.4, wh(vec2(seed * 97.0, 5.0)));
	float w = mix(0.1, 0.17, hs);
	float course = floor(uv.y / course_len);
	float u = uv.x + wh(vec2(course, seed * 31.0)) * w;
	float col_id = floor(u / w);
	vec2 id = vec2(col_id, course) + seed * 57.0;
	float h1 = wh(id);
	float h2 = wh(id * 1.37 + 3.0);
	// Hand-split shingles never end on one line: each butt sits a little off.
	float cv = fract((uv.y + (h2 - 0.5) * 0.06) / course_len);
	float cu = fract(u / w);
	float gap = (1.0 - smoothstep(0.0, 0.014 / w, min(cu, 1.0 - cu))) * detail;
	float shadow = 1.0 - smoothstep(0.0, 0.2, cv);
	float grain = mix(0.5, wnoise(vec2(u * 70.0, uv.y * 4.0)), detail);
	// Each shingle thickens toward its butt, cups a little and is warped by hand.
	n_ts = normalize(vec3(
		(h1 - 0.5) * 0.35 + (grain - 0.5) * 0.25 + (cu - 0.5) * 0.25,
		-0.22 + smoothstep(0.0, 0.06, 0.06 - cv) * 1.4,
		1.0));
	float grey = clamp(wear * (0.7 + 0.35 * sunny) + (h1 - 0.5) * 0.3, 0.0, 1.0);
	vec3 wood = mix(WOOD_FRESH, WOOD_SILVER, grey);
	wood = mix(wood, WOOD_DARK, wear * (0.2 + 0.3 * (1.0 - sunny)) * smoothstep(0.35, 1.0, h2));
	wood = mix(wood, WOOD_FRESH * 1.08, step(0.975, h2) * 0.85); // replaced shingle
	wood *= (0.72 + 0.45 * h1) * (0.88 + 0.2 * grain);
	crevice = max(shadow, gap);
	return wood * (1.0 - shadow * 0.55) * (1.0 - gap * 0.55);
}

// Board roof: long split boards from ridge to eave, every other one laid on
// top over the joint (board-on-board), butt joints where two lengths meet.
vec3 boards(vec2 uv, float seed, float wear, float sunny, float detail, out vec3 n_ts, out float crevice) {
	float bw = mix(0.17, 0.27, wh(vec2(seed * 61.0, 2.0)));
	float col_id = floor(uv.x / bw);
	float cu = fract(uv.x / bw);
	float upper = mod(col_id, 2.0);
	float h1 = wh(vec2(col_id, seed * 43.0));
	float seg_len = mix(1.8, 3.4, h1);
	float sv = fract((uv.y + h1 * 3.0) / seg_len);
	float joint = 1.0 - smoothstep(0.0, 0.02 / seg_len, sv);
	float h2 = wh(vec2(col_id, floor((uv.y + h1 * 3.0) / seg_len)) + seed * 7.0);
	float grain = mix(0.5,
		wnoise(vec2(uv.x * 45.0, uv.y * 1.6)) * 0.6 + wnoise(vec2(uv.x * 120.0, uv.y * 0.7)) * 0.4, detail);
	// Lower boards sit in the shadow of their raised neighbours' edges.
	float edge = min(cu, 1.0 - cu);
	float under = (1.0 - upper) * (1.0 - smoothstep(0.0, 0.25, edge));
	n_ts = normalize(vec3(
		(upper > 0.5 ? (cu - 0.5) * 0.5 : 0.0) + (grain - 0.5) * 0.3 + (h2 - 0.5) * 0.2,
		-0.05 + joint * 1.2,
		1.0));
	float grey = clamp(wear * (0.75 + 0.35 * sunny) + (h2 - 0.5) * 0.3, 0.0, 1.0);
	vec3 wood = mix(WOOD_FRESH, WOOD_SILVER, grey);
	// Rain runs down the joints: dark streaks along the lower boards.
	wood = mix(wood, WOOD_DARK, under * 0.5 * wear + wear * 0.18 * (1.0 - sunny));
	wood *= (0.82 + 0.3 * h2) * (0.86 + 0.24 * grain);
	crevice = max(under, joint);
	return wood * (1.0 - joint * 0.5) * mix(0.78, 1.0, upper);
}

// Thatch: combed straw laid in courses, each course's lower edge a soft
// step, fine fibres running down the slope, grey and green with age.
vec3 thatch(vec2 uv, float seed, float wear, float eave_t, float detail, out vec3 n_ts, out float crevice) {
	float course_len = mix(0.42, 0.6, wh(vec2(seed * 83.0, 9.0)));
	float course = floor(uv.y / course_len);
	float cv = fract(uv.y / course_len);
	// Bundles: lumps about half a metre across, staggered course to course.
	float bundle = wh(vec2(floor(uv.x / 0.55 + wh(vec2(course, 1.0))), course) + seed * 19.0);
	// Fibres fade to their mean where a pixel spans several (no sparkle).
	float fib = mix(0.5, wnoise(vec2(uv.x * 140.0, uv.y * 5.0)), detail) * 0.6
		+ mix(0.5, wnoise(vec2(uv.x * 48.0, uv.y * 2.0)), sqrt(detail)) * 0.4;
	float fib_x = mix(0.5, wnoise(vec2(uv.x * 140.0 + 0.6, uv.y * 5.0)), detail) * 0.6
		+ mix(0.5, wnoise(vec2(uv.x * 48.0 + 0.2, uv.y * 2.0)), sqrt(detail)) * 0.4;
	float shadow = 1.0 - smoothstep(0.0, 0.25, cv);
	n_ts = normalize(vec3((fib - fib_x) * 2.4 + (bundle - 0.5) * 0.2,
		-0.18 + smoothstep(0.0, 0.08, 0.08 - cv) * 0.9, 1.0));
	float grey = clamp(wear * 0.85 + (bundle - 0.5) * 0.25, 0.0, 1.0);
	vec3 straw = mix(STRAW_FRESH, STRAW_GREY, grey);
	// The lower courses stay wet longest and darken toward rot at the eaves.
	straw = mix(straw, STRAW_ROT, wear * eave_t * 0.45);
	straw *= (0.78 + 0.3 * fib) * (0.9 + 0.18 * bundle);
	crevice = shadow;
	return straw * (1.0 - shadow * 0.4);
}

void fragment() {
	roof_cutaway(w_pos, CAMERA_POSITION_WORLD, FRAGCOORD.xy);
	float seed = COLOR.a;
	// Per-house wear: a few roofs newly laid, most silvered over decades.
	float wear = clamp(age * mix(0.3, 1.0, wh(vec2(seed * 211.0, 4.0))), 0.0, 1.0);
	vec2 uv = UV;
	// 1 where a pixel covers under ~1 cm of roof, 0 past ~4 cm: fine fibre,
	// grain and keyway detail fade out before they alias.
	float detail = 1.0 - smoothstep(0.01, 0.04, length(fwidth(UV)));
	float part = 0.0; // 0 field, 1 ridge, 2 rolled edge
	if (uv.y <= -2.5) {
		part = 2.0;
		uv.y = -uv.y - 3.0;
	} else if (uv.y <= -0.5) {
		part = 1.0;
		uv.y = -uv.y - 1.0;
	}
	// The sun stands in the south (+Z); north pitches (-Z) stay cool and damp.
	float north = clamp(-w_nrm.z * 0.8 + 0.3, 0.0, 1.0);
	float sunny = clamp(w_nrm.z * 0.6 + 0.5, 0.0, 1.0) * step(0.0, w_nrm.y);
	float eave_t = part == 2.0 ? 0.7 : (part == 1.0 ? 0.0 : smoothstep(1.5, 7.0, uv.y));
	vec3 n_ts;
	float crevice;
	vec3 col;
	bool is_board = cover == 0 && seed < board_share;
	if (part == 1.0) {
		// Ridge: a board ridge (shingle/board) or a bound straw ridge with
		// withy bands every half metre (thatch), both darker than the field.
		float g = wnoise(vec2(uv.x * 3.0, uv.y * 60.0));
		if (cover == 1) {
			// Withy binding every ~1.1 m: thin, faint ties, not tile joints.
			float band = smoothstep(0.47, 0.5, abs(fract(uv.x / 1.1) - 0.5)) * detail;
			col = mix(STRAW_GREY, STRAW_ROT, 0.35 + 0.3 * wear) * (0.82 + 0.25 * g) * (1.0 - band * 0.25);
			n_ts = normalize(vec3(0.0, (g - 0.5) * 0.4, 1.0));
		} else {
			col = mix(WOOD_FRESH, WOOD_SILVER, wear * 0.8) * 0.78 * (0.85 + 0.25 * g);
			n_ts = normalize(vec3(0.0, (g - 0.5) * 0.5, 1.0));
		}
		crevice = 0.0;
	} else if (cover == 1) {
		col = thatch(uv, seed, wear, eave_t, detail, n_ts, crevice);
		if (part == 2.0) {
			col *= 0.72; // cut straw ends at the eaves read dark
		}
	} else if (is_board) {
		col = boards(uv, seed, wear, sunny, detail, n_ts, crevice);
	} else {
		col = shingles(uv, seed, wear, sunny, detail, n_ts, crevice);
	}
	col *= COLOR.rgb;
	if (!FRONT_FACING) {
		col = WOOD_DARK * 0.55; // underside of the eaves: battens and boards
	}
	vec3 nm = n_ts * 0.5 + 0.5;
	// Moss: a gentle field (never a threshold, which drew camouflage blobs)
	// that grows toward the eaves and on north pitches, seeded in the
	// overlaps where water lingers. Lichen rosettes sit sparse on sunny wood.
	float field = 0.55 + 0.45 * wfbm(w_pos.xz * 0.16 + seed * 13.0);
	float m = moss * wear * (0.06 + eave_t * eave_t * 0.75) * (0.25 + north * 0.85) * field;
	// Moss starts in the overlaps (course butts, keyways, board joints).
	m = clamp(m * mix(0.3, 1.6, crevice), 0.0, 0.7);
	float lichen = 0.05 * wear * sunny * smoothstep(0.65, 0.9, wnoise(uv * 3.1 + seed * 5.0))
		* (cover == 1 ? 0.3 : 1.0);
	float rough = cover == 1 ? 0.96 : 0.88;
	// growth_height_mask lets the tallest cushion texels (clamped to 1.0; a
	// fifth of the grimmia plate is above 0.9) through at ANY cover > 0, so a
	// faint field speckled whole roofs green. Fade the mask in with cover.
	vec3 moss_n;
	vec4 cushion = growth_moss_sample(uv, ROOF_MOSS_SPECIES, moss_n);
	float mv = growth_height_mask(cushion.a, m) * smoothstep(0.08, 0.4, m);
	col = mix(col, growth_season(cushion.rgb * vec3(0.66, 0.68, 0.42), cushion.a), mv);
	nm = mix(nm, moss_n, mv);
	rough = mix(rough, 0.97, mv);
	// Lichen only (moss cover 0): rosettes on the bare wood between cushions.
	shade_growth_plates(col, nm, rough, uv, 0.0, lichen * (1.0 - mv), vec3(1.0), GROWTH_ROOF_SPECIES);
	ALBEDO = city_albedo(col * mix(1.0, 0.7, wetness));
	ROUGHNESS = mix(rough, 0.4, wetness);
	// Relief in the cotangent frame of the metric roof UVs: the city meshes
	// carry no tangents, so NORMAL_MAP would have no frame to work in.
	vec3 t_n = nm * 2.0 - 1.0;
	t_n.xy *= mix(1.0, 0.6, wetness);
	vec3 dp1 = dFdx(VERTEX);
	vec3 dp2 = dFdy(VERTEX);
	vec2 duv1 = dFdx(UV);
	vec2 duv2 = dFdy(UV);
	vec3 n0 = normalize(NORMAL);
	vec3 dp2perp = cross(dp2, n0);
	vec3 dp1perp = cross(n0, dp1);
	vec3 tan_u = dp2perp * duv1.x + dp1perp * duv2.x;
	vec3 tan_v = dp2perp * duv1.y + dp1perp * duv2.y;
	float inv = inversesqrt(max(max(dot(tan_u, tan_u), dot(tan_v, tan_v)), 1e-12));
	NORMAL = normalize(tan_u * inv * t_n.x + tan_v * inv * t_n.y + n0 * t_n.z);
}
