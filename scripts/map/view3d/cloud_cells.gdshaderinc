// R-1400: discrete world-space clouds (CloudCells). Shared by the sky dome, the
// ground cloud-shadow pass and the god-ray pass so a cloud, its shadow and the
// beams it cuts are one object. Two vec4 per slot, packed by CloudCells.uniforms():
//   a = (x, base altitude, z, radius), b = (height, weight, kind 0 cu / 1 cb, seed).
// Positions are wrapped into a CELL_DOMAIN tile; every caller takes the copy
// nearest to its own point. Noise is passed in so callers keep their samplers.

const int CELL_SLOTS = 16;
// Must match CloudCells.DOMAIN / STORM_DOMAIN / footprint / opacity constants.
// Storm cells tile a wider square: a 2 km thunderhead must stay visible from
// several kilometres away, while cumulus fade out sooner.
const float CELL_DOMAIN = 3200.0;
const float CELL_STORM_DOMAIN = 9600.0;
const float CELL_CU_FOOTPRINT = 0.94;
const float CELL_CB_FOOTPRINT = 1.35;
const float CELL_CU_OPACITY = 0.82;
const float CELL_CB_OPACITY = 0.97;
// World units per billow-noise tile: ~90 m lumps on a cumulus flank.
const float CELL_BILLOW_SCALE = 700.0;

uniform vec4 cloud_cells[32];


float cell_domain(float kind) {
	return kind > 0.5 ? CELL_STORM_DOMAIN : CELL_DOMAIN;
}


vec2 cell_wrap_delta(vec2 p, vec2 c, float kind) {
	float domain = cell_domain(kind);
	vec2 d = p - c;
	return d - domain * round(d / domain);
}


// Horizontal radius (x R) at normalised height h (0 base .. 1 top). Cumulus: flat
// base and a rounded cauliflower dome. Cumulonimbus: a narrower tower that spreads
// into a flat anvil near the tropopause.
float cell_profile(float h, float kind) {
	float cu = sqrt(max(1.0 - h * h, 0.0)) * mix(0.82, 1.0, smoothstep(0.0, 0.12, h));
	// Broad rain-cooled base, a narrower updraft column, then the anvil.
	float tower = mix(0.9, 0.55, smoothstep(0.0, 0.45, h));
	float anvil = smoothstep(0.72, 0.9, h) * 1.5 * (1.0 - smoothstep(0.96, 1.0, h));
	float cb = max(tower * (1.0 - smoothstep(0.92, 1.0, h)), anvil);
	return mix(cu, cb, kind);
}


// 3D Worley-FBM lookup (SkyWeatherResources.build_cell_noise_3d), tiled every
// `scale` world units. Bright values are puff centres.
float cell_noise3(vec3 p, float scale, float seed, sampler3D noise3) {
	return textureLod(noise3, p / scale + seed * vec3(0.37, 0.11, 0.73), 0.0).r;
}


// Density 0..1 at offset `local` from the cell centre column (y is world height).
// Large puffs swell the profile into separate turrets and lift the crown in
// places (cauliflower); small puffs boil the surface. Edges stay fairly crisp:
// a cumulus is a hard-edged body, not a soft fog ball.
float cell_density(vec3 local, float world_y, vec4 a, vec4 b, sampler3D noise3, vec3 world_p) {
	float h = (world_y - a.y) / max(b.x, 1.0);
	if (h < 0.0 || h > 1.0) {
		return 0.0;
	}
	float lump = cell_noise3(world_p, a.w * 2.0, b.w, noise3);
	float crown = clamp(h / mix(0.75, 1.15, lump), 0.0, 1.0);
	float r = a.w * cell_profile(crown, b.z) * mix(0.8, 1.15, lump);
	float boil = cell_noise3(world_p, max(a.w * 0.6, 120.0), b.w + 0.5, noise3);
	float dist = length(local.xz) / max(r, 1.0) + (0.5 - boil) * 0.35;
	return smoothstep(1.0, 0.86, dist) * smoothstep(0.0, 0.03, h) * b.y;
}


// Share of light the cells stop between `p` and the light (1 = full shadow).
// Each cell is flattened to the disc at its shadow-casting height; the mirror of
// CloudCells.shadow_at() plus billowed edges.
float cells_ground_shadow(vec3 p, vec3 to_light, sampler2D noise_tex, float lod) {
	float lit = 1.0;
	float sun_y = max(to_light.y, 0.15);
	for (int i = 0; i < CELL_SLOTS; i++) {
		vec4 a = cloud_cells[i * 2];
		vec4 b = cloud_cells[i * 2 + 1];
		if (b.y <= 0.001) {
			continue;
		}
		float layer = a.y + b.x * mix(0.35, 0.25, b.z);
		vec2 q = p.xz + to_light.xz / sun_y * (layer - p.y);
		vec2 d = cell_wrap_delta(q, a.xz, b.z);
		float r = a.w * mix(CELL_CU_FOOTPRINT, CELL_CB_FOOTPRINT, b.z);
		if (dot(d, d) > r * r * 1.7) {
			continue;
		}
		vec2 nuv = q / CELL_BILLOW_SCALE + b.w * 7.13;
		float n = textureLod(noise_tex, nuv, lod).r * 0.65
			+ textureLod(noise_tex, nuv * 2.7 + 0.31, lod).r * 0.35;
		float dist = length(d) / max(r, 1.0) + (n - 0.5) * 0.38;
		lit *= 1.0 - smoothstep(1.0, 0.8, dist) * b.y * mix(CELL_CU_OPACITY, CELL_CB_OPACITY, b.z);
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
