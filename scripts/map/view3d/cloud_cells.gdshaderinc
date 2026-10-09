// R-1400: discrete world-space clouds (CloudCells). Shared by the sky dome, the
// ground cloud-shadow pass and the god-ray pass so a cloud, its shadow and the
// beams it cuts are one object. Three vec4 per slot, packed by CloudCells.uniforms():
//   a = (x, base altitude, z, radius), b = (height, weight, kind 0 cu / 1 cb, seed),
//   c = (life 0..1, tower 0..1, windiness 0..1, absolute tile x + 64 z).
// `tower` is how far a crowded cumulus has merged into a thunderstorm (R-1481), so
// shading, shadow and rain blend toward cumulonimbus by cell_storminess().
// Positions are wrapped into a CELL_DOMAIN tile; every caller takes the copy
// nearest to its own point. Noise is passed in so callers keep their samplers.

const int CELL_SLOTS = 23;
const int CELL_STRIDE = 3;
const int CELL_LOBES = 3;
// Must match CloudCells.DOMAIN / STORM_DOMAIN / footprint / opacity / lobe constants.
// Storm cells tile a wider square: a 2 km thunderhead must stay visible from
// several kilometres away, while cumulus fade out sooner.
const float CELL_DOMAIN = 3200.0;
const float CELL_STORM_DOMAIN = 9600.0;
const float CELL_CU_FOOTPRINT = 0.94;
const float CELL_CB_FOOTPRINT = 1.1;
const float CELL_CU_OPACITY = 0.82;
const float CELL_CB_OPACITY = 0.97;
// Ray-march box half-width (x R): a lobed, stretched cumulus reaches much further
// from its centre than a single round thunderhead mass.
const float CELL_CU_REACH = 3.0;
const float CELL_CB_REACH = 1.9;
// World units per billow-noise tile: ~90 m lumps on a cumulus flank.
const float CELL_BILLOW_SCALE = 700.0;

uniform vec4 cloud_cells[69];


float cell_domain(float kind) {
	return kind > 0.5 ? CELL_STORM_DOMAIN : CELL_DOMAIN;
}


vec2 cell_wrap_delta(vec2 p, vec2 c, float kind) {
	float domain = cell_domain(kind);
	vec2 d = p - c;
	return d - domain * round(d / domain);
}


// 0 = fair cumulus, 1 = cumulonimbus: a real storm cell, or a cumulus that merged
// with its crowded neighbours into a towering thunderstorm.
float cell_storminess(vec4 b, vec4 c) {
	return max(b.z, c.y);
}


// R-1495: how far the lobes fold into one mass. A storm slot folds fully; a merged
// tower only partly, so it keeps a cluster of turrets instead of a round dome.
// Mirrors CloudCells.lobe_fold().
const float CELL_TOWER_LOBE_FOLD = 0.45;

float cell_lobe_fold(vec4 b, vec4 c) {
	return b.z > 0.5 ? 1.0 : c.y * CELL_TOWER_LOBE_FOLD;
}


// R-1493: enumerate the 5x5 periodic neighbourhood only for towering cumulus.
// Increasing fade alone would still teleport the nearest copy at the 1.6 km seam.
// Copy zero preserves the ordinary cumulus/storm fast path. Mirrors CloudCells.
const int CELL_TOWER_COPIES = 25;
const float CELL_TOWER_MATURE = 0.75;
const vec2 CELL_TOWER_FADE = vec2(5000.0, 6000.0);

vec2 cell_view_copy_offset(int copy) {
	int grid = copy == 0 ? 12 : (copy == 12 ? 0 : copy);
	return vec2(float(grid % 5 - 2), float(grid / 5 - 2)) * CELL_DOMAIN;
}

// R-1495: every periodic copy of the cumulus tile is its own cloud. Its shape seed
// and (for towers) height come from a hash of a stable copy label built from the
// tiles the cloud has drifted (c.w), so a copy keeps its shape while the wrapped
// centre crosses the seam. Beyond CELL_TOWER_GATE_RANGE only a seeded share of tower
// copies stays, so one merged cluster no longer prints identical storms all round
// the horizon. Mirrors CloudCells.copy_tile / copy_hash / copy_seed /
// copy_height_scale / copy_gate.
const float CELL_TILE_WRAP = 64.0;
const float CELL_TOWER_COPY_SHARE = 0.3;
const vec2 CELL_TOWER_GATE_RANGE = vec2(1600.0, 2400.0);
const vec2 CELL_TOWER_COPY_HEIGHT = vec2(0.65, 1.35);

vec2 cell_copy_tile(vec2 copy_centre, vec4 a, vec4 c) {
	vec2 home = vec2(mod(c.w, CELL_TILE_WRAP), floor(c.w / CELL_TILE_WRAP));
	// Step from the wrapped centre minus tiles drifted: constant for one copy.
	return mod(round((copy_centre - a.xz) / CELL_DOMAIN) - home, CELL_TILE_WRAP);
}

float cell_copy_hash(vec2 tile, float seed, float salt) {
	vec3 p = fract(vec3(tile, seed * 61.0 + salt) * 0.1031);
	p += dot(p, p.zyx + 3.33);
	return fract((p.x + p.y) * p.z);
}

// The copy's own (height, weight, kind, seed): storm slots draw one copy as-is.
vec4 cell_copy_b(vec2 copy_centre, vec4 a, vec4 b, vec4 c) {
	if (b.z > 0.5) {
		return b;
	}
	vec2 tile = cell_copy_tile(copy_centre, a, c);
	float h = mix(CELL_TOWER_COPY_HEIGHT.x, CELL_TOWER_COPY_HEIGHT.y, cell_copy_hash(tile, b.w, 1.0));
	vec4 out_b = b;
	out_b.x *= mix(1.0, h, smoothstep(0.5, CELL_TOWER_MATURE, c.y));
	out_b.w = cell_copy_hash(tile, b.w, 0.0);
	return out_b;
}

float cell_copy_gate(vec2 copy_centre, float distance, vec4 a, vec4 b, vec4 c) {
	if (b.z > 0.5) {
		return 1.0;
	}
	float keep = step(cell_copy_hash(cell_copy_tile(copy_centre, a, c), b.w, 2.0), CELL_TOWER_COPY_SHARE - 1e-6);
	float far = smoothstep(CELL_TOWER_GATE_RANGE.x, CELL_TOWER_GATE_RANGE.y, distance)
		* smoothstep(0.5, CELL_TOWER_MATURE, c.y);
	return mix(1.0, keep, far);
}

float cell_view_fade(float distance, float kind, float tower) {
	float domain = cell_domain(kind);
	float near_fade = 1.0 - smoothstep(0.36 * domain, 0.5 * domain, distance);
	if (kind > 0.5) {
		return near_fade;
	}
	float far_fade = 1.0 - smoothstep(CELL_TOWER_FADE.x, CELL_TOWER_FADE.y, distance);
	return mix(near_fade, far_fade, smoothstep(0.5, CELL_TOWER_MATURE, tower));
}


// Lobe k of a cumulus (R-1481) in the cell's stretch frame (x along the seeded axis,
// y across), in units of R: xy = centre offset, z = radius share, w = top height
// share. One cloud is a fused cluster of uneven heaps, not a single round dumpling;
// the side heaps drift apart as the cloud ages (`age`) and fold back into one
// mass as it towers into a storm (`cb` = cell_lobe_fold). Mirrored by CloudCells._lobe().
vec4 cell_lobe(int k, float seed, float cb, float age) {
	if (k == 0) {
		return vec4(0.0, 0.0, mix(0.8, 1.0, cb), 1.0);
	}
	float fk = float(k);
	float side = k == 1 ? 1.0 : -1.0;
	float along = side * (0.5 + fract(seed * (17.3 + 9.1 * fk)) * 0.4);
	float across = (fract(seed * (31.7 + 5.3 * fk)) - 0.5) * 0.6;
	vec2 off = vec2(along, across) * (1.0 + 0.3 * age) * (1.0 - cb);
	float r = mix(mix(0.5, 0.82, fract(seed * (7.9 + 3.3 * fk))), 1.0, cb);
	float top = mix(mix(0.45, 0.9, fract(seed * (11.3 + 2.9 * fk))), 1.0, cb);
	return vec4(off, r, top);
}


// Seeded stretch axis and aspect of a cell's footprint. Mirrored by CloudCells.
vec2 cell_axis(float seed) {
	float ang = fract(seed * 13.7) * 3.14159;
	return vec2(cos(ang), sin(ang));
}


float cell_aspect(float seed, float cb) {
	return mix(0.9, 1.3, fract(seed * 5.3)) * mix(1.0, 1.2, cb);
}


// Smooth-min width for fusing lobes. It fades out as the lobes fold into one mass
// (cb -> 1): a smooth min of coinciding lobes lowers the distance and would swell
// a storm past its march box.
float cell_lobe_blend(float cb) {
	return 0.35 * (1.0 - cb) + 0.001;
}


// Polynomial smooth minimum: neighbouring lobes fuse into one body with a soft
// saddle instead of a crease.
float cell_smin(float x, float y, float k) {
	float h = max(k - abs(x - y), 0.0) / k;
	return min(x, y) - h * h * k * 0.25;
}


// Horizontal radius (x R) at normalised height h (0 base .. 1 top). Cumulus: flat
// base and a rounded cauliflower dome. Cumulonimbus: a broad squat mass that
// narrows only slightly with height; `seed` (0..1) decides how much anvil spreads
// from the crown, so some storms are flat-topped, some ragged with no anvil at all.
// `anvil_max` is the widest anvil share and `taper` the width left at 0.7 h: a
// merged tower (R-1495) narrows more toward a cauliflower crown and spreads a
// wider anvil than a storm slot, whose march box is tighter.
float cell_profile(float h, float kind, float seed, float anvil_max, float taper) {
	float cu = sqrt(max(1.0 - h * h, 0.0)) * mix(0.82, 1.0, smoothstep(0.0, 0.12, h));
	float tower = mix(0.95, taper, smoothstep(0.0, 0.7, h));
	float anvil = smoothstep(0.7, 0.88, h) * mix(0.0, anvil_max, fract(seed * 7.7)) * (1.0 - smoothstep(0.95, 1.0, h));
	float cb = (tower + anvil) * (1.0 - smoothstep(0.9, 1.0, h));
	return mix(cu, cb, kind);
}


// 3D Worley-FBM lookup (SkyWeatherResources.build_cell_noise_3d), tiled every
// `scale` world units. Bright values are puff centres.
float cell_noise3(vec3 p, float scale, float seed, sampler3D noise3) {
	return textureLod(noise3, p / scale + seed * vec3(0.37, 0.11, 0.73), 0.0).r;
}


// Density 0..1 at offset `local` from the cell centre column (y is world height).
// Every cell is its own shape: a fused cluster of uneven lobes (cell_lobe), stretched
// along a seeded axis and downwind by the wind (`c.z`), domain-warped by large noise,
// and leaning downwind with height (shear). Large puffs swell the profile into
// turrets; small puffs boil the surface. An ageing cumulus spreads its lobes apart
// and tatters into ragged fragments (life past ~0.55) instead of just thinning,
// while CloudCells shrinks it, so it dissolves gradually.
float cell_density(vec3 local, float world_y, vec4 a, vec4 b, vec4 c, sampler3D noise3, vec3 world_p, vec2 wind) {
	float h = (world_y - a.y) / max(b.x, 1.0);
	if (h < 0.0 || h > 1.0) {
		return 0.0;
	}
	float cb = cell_storminess(b, c);
	float age = smoothstep(0.35, 1.0, c.x) * (1.0 - cb);
	float windy = c.z * (1.0 - cb);
	float lump = cell_noise3(world_p, a.w * 2.0, b.w, noise3);
	vec2 q = local.xz;
	// Lean downwind with height; cumulus tops shear harder than a storm's body, and
	// a strong wind shears them further.
	q -= wind * (h * a.w * mix(0.35, 0.2, cb) * (fract(b.w * 3.1) + 0.3) * (1.0 + 1.2 * windy));
	// Wind drags the cloud out downwind: compress the along-wind distance.
	vec2 wa = wind * dot(q, wind);
	q = (q - wa) + wa / (1.0 + 0.8 * windy);
	// Low-frequency warp breaks the outline into ragged lobes; older clouds warp more.
	float warp_a = cell_noise3(world_p, a.w * 1.3, b.w + 0.2, noise3);
	float warp_b = cell_noise3(world_p, a.w * 1.3, b.w + 0.7, noise3);
	q += (vec2(warp_a, warp_b) - 0.5) * a.w * mix(0.9, 1.3, age);
	vec2 ax = cell_axis(b.w);
	vec2 u = vec2(dot(q, ax), dot(q, vec2(-ax.y, ax.x))) / max(a.w, 1.0);
	u.x /= cell_aspect(b.w, cb);
	float swell = mix(0.75, 1.2, lump);
	float fold = cell_lobe_fold(b, c);
	float dist = 1e3;
	for (int k = 0; k < CELL_LOBES; k++) {
		vec4 lobe = cell_lobe(k, b.w, fold, age);
		float crown = clamp(h / (mix(0.75, 1.15, lump) * lobe.w), 0.0, 1.0);
		float r = lobe.z * cell_profile(
			crown, cb, b.w, b.z > 0.5 ? 0.42 : 0.6, b.z > 0.5 ? 0.72 : 0.55
		) * swell;
		dist = cell_smin(dist, length(u - lobe.xy) / max(r, 0.002), cell_lobe_blend(fold));
	}
	float boil = cell_noise3(world_p, max(a.w * 0.6, 120.0), b.w + 0.5, noise3);
	// Forming or dissolving clouds come apart along the large lumps (whole heaps
	// break off) and thin out, rather than crumbling at the fine boil scale, which
	// read as glittering speckles on the rim.
	float tatter = max(1.0 - clamp(b.y, 0.0, 1.0), smoothstep(0.55, 1.0, c.x) * (1.0 - cb));
	float erode = tatter * (1.0 - lump) * 0.4;
	dist += (0.5 - boil) * 0.4 + erode;
	// A wider edge ramp for fair cumulus gives a soft, wispy fringe instead of a
	// hard cut-out rim; storm towers keep their firm outline.
	return smoothstep(1.0, mix(0.72, 0.86, cb), dist) * smoothstep(0.0, 0.03, h)
		* mix(b.y, 1.0, 0.6) * (1.0 - 0.45 * tatter);
}


// Normalised footprint distance (1 = edge) of a cell at its shadow-casting layer,
// `d` the horizontal offset from its centre: the same stretch axis and lobes as
// cell_density without the 3D noise. Mirrored by CloudCells.footprint_distance().
float cell_footprint(vec2 d, vec4 a, vec4 b, vec4 c) {
	float cb = cell_storminess(b, c);
	float age = smoothstep(0.35, 1.0, c.x) * (1.0 - cb);
	float r = a.w * mix(CELL_CU_FOOTPRINT, CELL_CB_FOOTPRINT, cb);
	vec2 ax = cell_axis(b.w);
	vec2 u = vec2(dot(d, ax), dot(d, vec2(-ax.y, ax.x))) / max(r, 1.0);
	u.x /= cell_aspect(b.w, cb);
	float fold = cell_lobe_fold(b, c);
	float dist = 1e3;
	for (int k = 0; k < CELL_LOBES; k++) {
		vec4 lobe = cell_lobe(k, b.w, fold, age);
		dist = cell_smin(dist, length(u - lobe.xy) / lobe.z, cell_lobe_blend(fold));
	}
	return dist;
}


// Share of light the cells stop between `p` and the light (1 = full shadow).
// Each cell is flattened to its lobed footprint at its shadow-casting height; the
// mirror of CloudCells.shadow_at() plus billowed edges.
float cells_ground_shadow(vec3 p, vec3 to_light, sampler2D noise_tex, float lod) {
	float lit = 1.0;
	float sun_y = max(to_light.y, 0.15);
	for (int i = 0; i < CELL_SLOTS; i++) {
		vec4 a = cloud_cells[i * CELL_STRIDE];
		vec4 b = cloud_cells[i * CELL_STRIDE + 1];
		vec4 c = cloud_cells[i * CELL_STRIDE + 2];
		if (b.y <= 0.001) {
			continue;
		}
		float cb = cell_storminess(b, c);
		float layer = a.y + b.x * mix(0.35, 0.25, cb);
		vec2 q = p.xz + to_light.xz / sun_y * (layer - p.y);
		// R-1495: the copy under the point at the slot's own layer, then its own
		// height and seed (copies are 3.2 km apart, far more than the layer shift).
		vec2 copy_centre = q - cell_wrap_delta(q, a.xz, b.z);
		vec4 bc = cell_copy_b(copy_centre, a, b, c);
		layer = a.y + bc.x * mix(0.35, 0.25, cb);
		q = p.xz + to_light.xz / sun_y * (layer - p.y);
		vec2 d = q - copy_centre;
		float reach = a.w * mix(CELL_CU_REACH, CELL_CB_REACH, cell_lobe_fold(b, c));
		if (dot(d, d) > reach * reach) {
			continue;
		}
		vec2 nuv = q / CELL_BILLOW_SCALE + bc.w * 7.13;
		float n = textureLod(noise_tex, nuv, lod).r * 0.65
			+ textureLod(noise_tex, nuv * 2.7 + 0.31, lod).r * 0.35;
		float dist = cell_footprint(d, a, bc, c) + (n - 0.5) * 0.38;
		lit *= 1.0 - smoothstep(1.0, 0.8, dist) * b.y * mix(CELL_CU_OPACITY, CELL_CB_OPACITY, cb);
	}
	return 1.0 - lit;
}


// Ray vs axis-aligned box; returns (t_near, t_far), t_far < t_near on a miss.
vec2 cell_box_hit(vec3 ro, vec3 rd, vec3 lo, vec3 hi) {
	vec3 inv = 1.0 / (rd + vec3(1e-6) * sign(rd) + vec3(1e-7));
	vec3 t0 = (lo - ro) * inv;
	vec3 t1 = (hi - ro) * inv;
	vec3 tmin = min(t0, t1);
	vec3 tmax = max(t0, t1);
	return vec2(max(max(tmin.x, tmin.y), max(tmin.z, 0.0)), min(min(tmax.x, tmax.y), tmax.z));
}


// Distance from the ray to segment [p0, p1] and the ray parameter of the closest
// point (x = distance, y = t). Used to draw a lightning channel as a 3D line.
vec2 cell_ray_segment(vec3 ro, vec3 rd, vec3 p0, vec3 p1) {
	vec3 u = p1 - p0;
	vec3 w = ro - p0;
	float b = dot(rd, u);
	float c = dot(u, u);
	float d = dot(rd, w);
	float e = dot(u, w);
	float denom = c - b * b;
	float s = denom > 1e-4 ? clamp((e - b * d) / denom, 0.0, 1.0) : 0.0;
	float t = max(dot(rd, p0 + u * s - ro), 0.0);
	return vec2(length(ro + rd * t - (p0 + u * s)), t);
}


// Cheap deterministic 0..1 hash for bolt kinks.
float cell_hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}


// A jagged cloud-to-ground channel from `top` to `ground` with two side branches.
// Returns brightness (core + glow) for the eye ray; a hairline at any distance
// with a thin physical width that only shows on a very close strike.
float cell_bolt(vec3 ro, vec3 rd, vec3 top, vec3 ground, float seed) {
	const int KINKS = 9;
	float best = 1e9;
	float best_t = 1.0;
	float branch_best = 1e9;
	float branch_t = 1.0;
	vec3 down = ground - top;
	float len = length(down);
	vec3 side = normalize(cross(down, vec3(0.0, 0.0, 1.0)) + vec3(1e-4));
	vec3 side2 = normalize(cross(down, side));
	vec3 prev = top;
	for (int k = 1; k <= KINKS; k++) {
		float f = float(k) / float(KINKS);
		vec3 next = top + down * f;
		if (k < KINKS) {
			float j = len * 0.045;
			next += side * (cell_hash(seed * 13.0 + float(k)) - 0.5) * 2.0 * j;
			next += side2 * (cell_hash(seed * 29.0 + float(k)) - 0.5) * 2.0 * j;
		}
		vec2 hit = cell_ray_segment(ro, rd, prev, next);
		if (hit.x / max(hit.y, 1.0) < best / max(best_t, 1.0)) {
			best = hit.x;
			best_t = hit.y;
		}
		// Branches fork off kinks 2 and 4 and die out a third of the way down.
		if (k == 2 || k == 4) {
			float dir_sign = k == 2 ? 1.0 : -1.0;
			vec3 tip = next + down * 0.28 + side * dir_sign * len * 0.16
				+ side2 * (cell_hash(seed * 7.0 + float(k)) - 0.5) * len * 0.1;
			vec3 mid = mix(next, tip, 0.5) + side2 * (cell_hash(seed * 3.0 + float(k)) - 0.5) * len * 0.05;
			vec2 h1 = cell_ray_segment(ro, rd, next, mid);
			vec2 h2 = cell_ray_segment(ro, rd, mid, tip);
			vec2 hb = h1.x / max(h1.y, 1.0) < h2.x / max(h2.y, 1.0) ? h1 : h2;
			if (hb.x / max(hb.y, 1.0) < branch_best / max(branch_t, 1.0)) {
				branch_best = hb.x;
				branch_t = hb.y;
			}
		}
		prev = next;
	}
	// Widths are angular half-widths (radians). A real luminous channel is a few
	// centimetres to decimetres across, so it is sub-pixel past a few hundred metres
	// and photographs as a hairline: the physical term (0.35 m) only matters for a
	// strike very close by, and the floor (~0.6 px at 1080p / 70 deg FOV) keeps the
	// line unbroken without inflating it. The halo stays below 1.0 even after the
	// caller's x4 HDR gain, so only the core saturates and the scene glow adds the
	// soft bloom instead of a painted fat stroke.
	float ang = best / max(best_t, 1.0);
	float width = max(0.0007, 0.35 / max(best_t, 1.0));
	float core = 1.0 - smoothstep(width * 0.5, width, ang);
	float glow = exp(-ang / (width * 3.0)) * 0.12;
	// Branches carry less current: thinner and dimmer than the main stroke.
	float b_ang = branch_best / max(branch_t, 1.0);
	float b_width = max(0.0006, 0.15 / max(branch_t, 1.0));
	float branch = (1.0 - smoothstep(b_width * 0.5, b_width, b_ang)) * 0.4
		+ exp(-b_ang / (b_width * 2.5)) * 0.05;
	return core + glow + branch;
}
