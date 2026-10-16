// ADR 0045 task 6: one winter ice look for the moat, stream, lakes, the sea shore
// and frozen puddles. The old moat ice was two octaves of value noise, which read
// as soft grey blotches ("blurry") at every distance and wrote sRGB-tuned tones
// straight into linear ALBEDO, so snow on the ice glared whiter than snow on the
// ground beside it. Real lake ice reads through SHARP structure:
// - pans: ice freezes as plates that cement together, each a slightly different
//   tone (clear black ice or milky snow-ice), with a refrozen seam between them;
// - cracks: long thin lines, white planes in clear ice, dark wicked-up slush lines
//   in snowy ice;
// - air bubbles frozen into clear ice;
// - wind-blown snow lying in streaks along the wind (sastrugi), drifted deeper
//   against the bank, with glassy wind-swept patches between.
// Every line is antialiased against the pixel footprint `px` (metres per pixel):
// below a pixel it widens and fades to its coverage instead of shimmering.
// Colours here are sRGB tones like the city ground; hosts writing ALBEDO directly
// convert with ice_lin() (the city_albedo rule), city_ground mixes them into its
// own colour before its city_albedo().
// Function names carry an `ice_` prefix: hosts already define hash12/value_noise.

const vec3 ICE_SNOW_SRGB = vec3(0.86, 0.9, 0.95);
const vec3 ICE_CLEAR_SRGB = vec3(0.13, 0.17, 0.19);
const vec3 ICE_MILKY_SRGB = vec3(0.60, 0.66, 0.70);
// Pan size (m) and crack cell size (m).
const float ICE_PAN_SIZE = 3.2;
const float ICE_CRACK_SIZE = 1.15;

struct IceLook {
	vec3 albedo_srgb;
	float roughness;
	float specular;
	// World-space slope (dh/dx, dh/dz) of the ice and snow surface.
	vec2 slope;
	// 0 bare ice .. 1 snow lying on it.
	float snow;
};

vec3 ice_lin(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	vec3 x = max(c, vec3(0.0));
	return mix(x / 12.92, pow((x + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), x));
#endif
}

float ice_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 ice_hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float ice_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(ice_hash(i), ice_hash(i + vec2(1.0, 0.0)), u.x),
		mix(ice_hash(i + vec2(0.0, 1.0)), ice_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Voronoi in cell units: x = distance to the nearest site, y = distance to the
// nearest cell border (exact two-pass form, 3x3 second pass), z = cell id 0..1.
vec3 ice_cells(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + ice_hash2(n + g) * 0.85 - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	float border = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + ice_hash2(n + g) * 0.85 - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				border = min(border, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return vec3(sqrt(md), border, ice_hash(n + mg + vec2(17.0, 3.0)));
}

// A line of world `width` at world distance `d`: antialiased, fading to its
// coverage once the pixel footprint `px` is wider than the line.
float ice_line(float d, float width, float px) {
	float w = max(width, px * 1.25);
	return (1.0 - smoothstep(w * 0.5, w, d)) * clamp(width / w, 0.0, 1.0);
}

// Pans for a world position, shared by hosts that also need the freeze front.
vec3 ice_pans(vec2 xz) {
	return ice_cells(xz / ICE_PAN_SIZE + vec2(31.7, 12.3));
}

// thickness 0..1 (ice_cover_target), snow 0..1 (snow cover), bank 0..1 (1 at the
// shore where drifts pile and snow-ice forms), wind = horizontal wind direction.
IceLook ice_look(vec2 xz, vec3 pans, float thickness, float snow, float bank, vec2 wind, float px) {
	IceLook o;
	// Pan tone: some pans froze clear (black ice), others as milky snow-ice; the
	// shore and a snowy winter make more snow-ice.
	float milky = clamp(smoothstep(0.25, 0.95, pans.z) * 0.75 + bank * 0.45 + snow * 0.25 - 0.15, 0.0, 1.0);
	// Thin new ice is clear and dark whatever the pan.
	milky *= smoothstep(0.1, 0.5, thickness);
	vec3 body = mix(ICE_CLEAR_SRGB, ICE_MILKY_SRGB, milky);
	// Small tone wander inside a pan (frozen-in ripples), never a blotch across pans.
	body *= 0.94 + 0.12 * ice_noise(xz * 0.9 + pans.z * 40.0);
	// Air bubbles in clear ice: 6 cm grid, about one cell in six holds a 5-15 mm
	// bubble, in clusters. Beyond a pixel they average into a faint whitening.
	vec2 bc = floor(xz / 0.06);
	vec2 bf = fract(xz / 0.06);
	vec2 bp = ice_hash2(bc + vec2(5.3, 1.1)) * 0.7 + 0.15;
	float bubble_r = mix(0.12, 0.3, ice_hash(bc + vec2(2.9, 8.4)));
	float bubble_on = step(0.83, ice_hash(bc)) * smoothstep(0.35, 0.7, ice_noise(xz * 0.7 + vec2(9.1, 4.2)));
	float bubble = ice_line(length(bf - bp) * 0.06, bubble_r * 0.05, px) * bubble_on;
	body = mix(body, vec3(0.78, 0.84, 0.88), bubble * 0.8 * (1.0 - milky * 0.7) * smoothstep(0.15, 0.4, thickness));
	// Refrozen seam between pans: a pale weld line, 4 cm.
	float seam = ice_line(pans.y * ICE_PAN_SIZE, 0.04, px);
	// Crack net in clusters (domain-warped so polygons do not read as a lattice).
	vec2 warp = vec2(ice_noise(xz * 0.8), ice_noise(xz * 0.8 + vec2(7.3, 2.9))) - 0.5;
	vec3 crack_cells = ice_cells((xz + warp * 0.6) / ICE_CRACK_SIZE);
	float crack_gate = smoothstep(0.42, 0.62, ice_noise(xz * 0.22 + vec2(3.3, 7.7)));
	float crack = ice_line(crack_cells.y * ICE_CRACK_SIZE, 0.012, px) * crack_gate * smoothstep(0.2, 0.45, thickness);
	// In clear ice a crack is a white internal plane; in milky ice a grey line.
	body = mix(body, mix(vec3(0.82, 0.88, 0.92), body * 0.62, milky), crack * 0.85);
	body = mix(body, mix(vec3(0.55, 0.62, 0.66), body * 1.08, milky), seam * 0.7);
	// Wind-blown snow: streaks stretched along the wind, deeper against the bank.
	// Snow does not lie on thin ice (it sinks into grey slush).
	vec2 w = normalize(wind + vec2(0.0001));
	vec2 ws = vec2(dot(xz, w), dot(xz, vec2(-w.y, w.x)));
	vec2 suv = vec2(ws.x * 0.16, ws.y * 0.85);
	float s0 = ice_noise(suv);
	float s_field = s0 * 0.6 + ice_noise(suv * 3.1 + vec2(4.4, 1.7)) * 0.28 + ice_noise(xz * 7.0) * 0.12;
	float snow_live = snow * smoothstep(0.2, 0.5, thickness);
	// Even a full cover leaves wind-scoured glassy patches mid-channel (~1 in 6).
	float level = s_field + bank * 0.7 - (1.25 - snow_live * 0.95);
	// Sharp drift edge (a few cm), dusting just outside it.
	float soft = 0.035 + px * 0.6;
	float snow_lying = smoothstep(-soft, soft, level) * step(0.001, snow_live);
	float dusting = smoothstep(-0.25, 0.0, level) * snow_live * 0.35;
	// Slush where snow sank into thin ice: grey and wet.
	float slush = snow * (1.0 - smoothstep(0.2, 0.5, thickness)) * smoothstep(0.35, 0.65, s_field);
	body = mix(body, vec3(0.42, 0.46, 0.47), slush * 0.7);
	body = mix(body, ICE_SNOW_SRGB * 0.96, dusting);
	// Snow hides the crack net; only a faint grey trace where slush wicked up.
	vec3 snow_col = ICE_SNOW_SRGB * (0.92 + 0.08 * ice_noise(xz * 13.0));
	snow_col = mix(snow_col, snow_col * vec3(0.8, 0.84, 0.88), crack * 0.2 * (1.0 - smoothstep(0.0, 0.3, level)));
	o.albedo_srgb = mix(body, snow_col, snow_lying);
	o.snow = snow_lying;
	// Ice is near-mirror where clear, satin where milky; snow is matte.
	o.roughness = mix(mix(0.04, 0.22, milky), 0.4, max(dusting * 0.7, slush));
	o.roughness = mix(o.roughness, 0.88, snow_lying);
	o.specular = mix(0.5, 0.28, snow_lying);
	// Surface relief: frozen-in undulation on bare ice, drift shoulders in snow.
	vec2 e = vec2(0.25, 0.0);
	float u0 = ice_noise(xz * 0.35);
	vec2 ice_slope = vec2(ice_noise((xz + e.xy) * 0.35) - u0, ice_noise((xz + e.yx) * 0.35) - u0) / e.x * 0.012;
	vec2 sd = vec2(0.06, 0.0);
	vec2 drift_slope = vec2(
		ice_noise(vec2(dot(xz + sd.xy, w) * 0.16, dot(xz + sd.xy, vec2(-w.y, w.x)) * 0.85)) - s0,
		ice_noise(vec2(dot(xz + sd.yx, w) * 0.16, dot(xz + sd.yx, vec2(-w.y, w.x)) * 0.85)) - s0
	) / sd.x * 0.05;
	o.slope = mix(ice_slope, drift_slope, snow_lying);
	return o;
}
