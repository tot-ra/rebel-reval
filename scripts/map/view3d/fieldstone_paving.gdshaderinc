// Fieldstone paving shared by the district terrain (map_view_terrain_blend)
// and the seamless city ground (scripts/city/city_ground.gdshader, ADR 0031).
// Contract: the including shader declares
//   uniform float cobble_cell_size;  // one stone's footprint in world units
//   uniform float cobble_relief;     // dome height in world units
// before including this file.

float cobble_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float cobble_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(cobble_hash(i), cobble_hash(i + vec2(1.0, 0.0)), u.x),
		mix(cobble_hash(i + vec2(0.0, 1.0)), cobble_hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

struct FieldStone {
	vec3 albedo;
	vec2 normal_xy;
	float roughness;
	float stone;
};

vec2 cobble_hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453123);
}

// Rounded fieldstone street. One 3x3 Voronoi pass keeps the two nearest stone
// centres. A stone's inset distance is the smaller of half the gap to the
// neighbour (F2 - F1) / 2 and its own radius minus F1, so polygon corners are cut
// round. Both terms have exact gradients (unit vectors away from each centre), so
// the dome normal is analytic: no extra Voronoi taps, no 2x2 derivative blocks.
// `footprint` is the pixel size in stone cells: as stones approach one pixel,
// joints, grain, and relief fade to the average so distant streets keep their
// tone instead of shimmering or collapsing into a flat grey mip.
FieldStone compute_fieldstone(vec2 world_xz, float footprint) {
	vec2 p = world_xz / cobble_cell_size;
	// Low-frequency warp bends stone rows into the loose courses of hand-laid paving.
	p += (vec2(cobble_noise(p * 0.21 + vec2(3.7, 8.1)), cobble_noise(p * 0.21 + vec2(11.3, 1.9))) - 0.5) * 0.9;
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float d1 = 64.0;
	float d2 = 64.0;
	vec2 id = cell;
	vec2 r1 = vec2(0.0);
	vec2 r2 = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + 0.15 + cobble_hash2(cell + g) * 0.70 - local;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				r2 = r1;
				d1 = d;
				r1 = r;
				id = cell + g;
			} else if (d < d2) {
				d2 = d;
				r2 = r;
			}
		}
	}
	float f1 = sqrt(d1);
	float f2 = sqrt(d2);
	// Gradients of F1 and F2 point away from their stone centres.
	vec2 grad_f1 = -r1 / max(f1, 1e-4);
	vec2 grad_f2 = -r2 / max(f2, 1e-4);
	float h0 = cobble_hash(id + vec2(3.1, 7.7));
	float h1 = cobble_hash(id + vec2(9.4, 1.3));
	float h2 = cobble_hash(id + vec2(5.9, 12.6));
	float detail = 1.0 - smoothstep(0.25, 0.85, footprint);

	float gap_inset = (f2 - f1) * 0.5;
	float radius = 0.62 + h1 * 0.14;
	float round_inset = radius - f1;
	// Polynomial smooth-min: a hard min() leaves a crease where the two terms swap.
	float k = 0.10;
	float blend = clamp(0.5 + 0.5 * (round_inset - gap_inset) / k, 0.0, 1.0);
	float inset = mix(round_inset, gap_inset, blend) - k * blend * (1.0 - blend);
	vec2 grad_inset = mix(-grad_f1, (grad_f2 - grad_f1) * 0.5, blend);

	// Joint width varies per stone; the albedo edge softens with the pixel footprint.
	float joint = 0.025 + h0 * 0.03;
	float edge_soft = 0.03 + footprint * 0.5;
	float stone = smoothstep(joint, joint + edge_soft, inset);
	// Worn-flat stone: a narrow shoulder carries most of the rise right at the
	// edge, so ~3/4 of the face reads flat; a faint broad crown keeps it from
	// looking like a tile.
	float shoulder = 0.11;
	float t = clamp((inset - joint) / shoulder, 0.0, 1.0);
	float crown_span = 0.40;
	float tc = clamp((inset - joint) / crown_span, 0.0, 1.0);
	float edge_rise = 0.85;
	float dome = edge_rise * t * t * (3.0 - 2.0 * t) + (1.0 - edge_rise) * tc * tc * (3.0 - 2.0 * tc);
	// Some stones have sunk under cart wheels; others stand proud.
	float top = 0.55 + h2 * 0.45;
	vec2 grad_h = grad_inset * top * (
		edge_rise * 6.0 * t * (1.0 - t) / shoulder
		+ (1.0 - edge_rise) * 6.0 * tc * (1.0 - tc) / crown_span
	);
	// Sand joints are scoured below the stone feet: the bed dips toward the
	// middle of the gap (inset 0) and rises to meet the stone at `joint`.
	float sand_t = clamp(1.0 - inset / joint, 0.0, 1.0);
	float sand_depth = 0.35;
	grad_h += grad_inset * sand_depth * 2.0 * sand_t / joint;
	vec2 slope = grad_h * (cobble_relief / cobble_cell_size) * detail;
	float slope_len = length(slope);
	slope *= min(1.0, 0.75 / max(slope_len, 1e-4));

	// Reval streets were laid from glacial fieldstones: grey and red granite,
	// dark gneiss, and the odd buff limestone lump. Hues stay muted; the sky
	// ambient already pushes grey stone toward blue.
	vec3 stone_color = vec3(0.36, 0.34, 0.31);
	if (h1 > 0.86) {
		stone_color = vec3(0.40, 0.32, 0.28);
	} else if (h1 > 0.70) {
		stone_color = vec3(0.24, 0.23, 0.22);
	} else if (h1 > 0.60) {
		stone_color = vec3(0.42, 0.38, 0.31);
	} else if (h1 > 0.32) {
		stone_color = vec3(0.31, 0.30, 0.29);
	}
	stone_color *= 0.80 + h0 * 0.30;
	// Granite grain and lichen-dark flecks, only while they resolve on screen.
	float grain = cobble_noise(world_xz * 42.0 + id * 1.7);
	float fleck = cobble_noise(world_xz * 11.0 - id * 2.3);
	stone_color *= 1.0 + ((grain - 0.5) * 0.34 + (fleck - 0.5) * 0.22) * detail;
	// Traffic polishes the crowns; dirt and shade collect on the shoulders.
	stone_color *= mix(0.66, 1.03, dome);

	float age = cobble_noise(world_xz * 0.17 + vec2(13.7, 4.3));
	float mud_film = cobble_noise(world_xz * 0.29 - vec2(5.6, 1.8));
	float grit = cobble_noise(world_xz * 6.0 + vec2(8.4, 19.2));
	vec3 earth = mix(vec3(0.13, 0.11, 0.09), vec3(0.23, 0.19, 0.15), age);
	earth *= 0.8 + grit * 0.4 * detail;
	// Dried mud films over whole patches of street, strongest low on the stones.
	float film = smoothstep(0.55, 0.85, mud_film) * (1.0 - dome * 0.6);
	stone_color = mix(stone_color, earth * 1.35, film * 0.6);

	// Distant stones fade to the mean street tone at ~75% stone cover.
	vec3 mean_stone = vec3(0.30, 0.29, 0.27);
	stone_color = mix(mean_stone, stone_color, detail * 0.8 + 0.2);
	float cover = mix(0.75, stone, detail);
	FieldStone result;
	// The sunken joint sand sits in the stones' shadow: darken it toward the gap middle.
	vec3 joint_earth = earth * (1.0 - 0.4 * sand_t * detail);
	result.albedo = mix(joint_earth, stone_color, cover);
	result.normal_xy = -slope;
	result.roughness = mix(0.97, mix(0.88, 0.66, dome * top), cover);
	result.stone = cover;
	return result;
}
