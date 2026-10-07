shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2DArray terrain_patterns;
uniform sampler2DArray cobble_patterns;
uniform sampler2D cobble_surface : filter_linear_mipmap, repeat_enable;
// CO-01 (R-948): authored ground families share three arrays so five PBR sets
// cost three samplers (GL Compatibility has ~16 units, several reserved by the
// renderer). Layer order: 0 grass, 1 mud, 2 sand, 3 coast_sand, 4 shore_shingle.
// source_color is required: Mobile/Metal return raw sRGB without it. GL
// Compatibility already decodes these VRAM-compressed layers, so a manual decode
// there would linearise twice (verified by a render probe, 2026-09-28).
uniform sampler2DArray ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray ground_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray ground_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
// Per-family repeat (in terrain UV units, 1 UV = 4 world units), strength of the
// second, 0.17x-scale anti-tiling sample, and tangent normal gain. Art-overridable
// per ADR 0018 without touching the plates.
// Components are families 0-3 (grass, mud, sand, coast_sand); shore_shingle has
// its own scalar because uniform arrays cannot carry defaults in Godot shaders.
// The grass entry multiplies natural_ground_uv_scale, the shared meadow repeat.
uniform vec4 ground_uv_scale = vec4(1.0, 3.2, 3.0, 3.2);
// Stochastic tile offsets for the primary sample (0 = plain repeat). A dense
// mud repeat otherwise shows a regular grid of tufts once the camera zooms out.
uniform float ground_tile_break = 1.0;
uniform float shingle_uv_scale = 3.6;
uniform vec4 ground_detail_strength = vec4(0.72, 0.6, 0.7, 0.7);
uniform float shingle_detail_strength = 0.55;
uniform vec4 ground_normal_strength = vec4(0.55, 0.75, 0.6, 0.65);
uniform float shingle_normal_strength = 0.9;
// Sand plates are renormalised to the OutdoorTerrainPalette tint so beaches keep
// their map colour; 0 = raw plate colour, 1 = mean exactly equals the palette.
uniform float sand_palette_authority = 0.85;
// Value of the renormalised plate relative to the palette. 0.91 is the mean of
// the retired PATTERN_SPECKLE, so beaches keep their pre-CO-01 brightness.
uniform float sand_palette_value = 0.91;
// Storm-beach shingle strands mixed into coast_sand by a low-frequency mask.
uniform float coast_shingle_amount = 0.35;
uniform float use_authored_sand = 0.0;
uniform float use_authored_coast_sand = 0.0;
uniform float use_authored_shingle = 0.0;
uniform sampler2D timber_floor_albedo : source_color, filter_linear_mipmap, repeat_enable;
// Native 512 px flagstone plate for the stone layer: the shared 128 px array
// copy rendered stone aprons as a dark blur (R-1202).
uniform sampler2D stone_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D hay_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_authored_mud = 0.0;
uniform float use_authored_hay = 0.0;
uniform float use_authored_stone = 0.0;
uniform float pattern_layers = 1.0;
uniform int cobblestone_layer = 12;
uniform int castle_paving_layer = 13;
uniform int timber_floor_layer = 15;
uniform int stone_layer = 14;
// Measured repeat of the flagstone plate: one tile per shared 4.0-unit terrain repeat.
uniform float stone_uv_scale = 1.0;
uniform int mud_layer = 8;
// Roads and yards (farm soil, dirt) reuse the authored mud plate: the 128 px
// procedural earth read as a blurry blue-grey wave with plastic gloss.
uniform int dirt_layer = 7;
uniform int hay_layer = 4;
uniform int straw_layer = 5;
// Inclusive layer band covering trodden ground (farm soil through ash). These
// surfaces receive world-space relief so streets and yards stop reading as a
// single flat colour field between the paved strokes.
uniform int earth_layer_min = 6;
uniform int earth_layer_max = 11;
uniform float mud_wetness = 0.0;
// Street cobbles are rounded fieldstones laid in earth, not a dressed lattice:
// a world-space Voronoi gives every stone its own outline, height, and granite
// tint, with an analytic dome normal, so a street reads as relief without one
// mesh per stone. Castle paving keeps the baked dressed-stone lattice.
// cobble_cell_size is one stone's footprint in world units (~15 cm fieldstone).
uniform float cobble_cell_size = 0.2;
// Crown height in world units that the tangent-space normal is derived from.
uniform float cobble_relief = 0.05;
uniform float natural_ground_uv_scale = 2.0;
uniform float natural_ground_variation = 0.72;
uniform float timber_floor_uv_scale = 3.0;
// Authored hay/straw plate repeat (~0.9 m of strewn straw per tile).
uniform float hay_uv_scale = 3.6;
// WS-08 wet sand behind the swash. Only these two beach layers react.
uniform int sand_layer = 9;
uniform int coast_sand_layer = 10;
global uniform float ocean_time;
#include "res://scripts/map/view3d/shore_swash.gdshaderinc"

// CUSTOM0 is only readable in vertex(). Layer indices cannot be interpolated
// directly, so each corner resolves per-family weights (P0-219: no flat layer
// pair, so paving edges stay wedge-free) and the rasterizer blends them.
//
// CO-01 (R-948): authored plates are sampled per FRAGMENT from those weights.
// Sampling them in vertex() only read one texel per 0.29-unit subdivision
// vertex, which turned every authored plate into a tinted blur with speckles.
// Only the 128 px procedural families stay resolved per corner in
// vertex_albedo, pre-multiplied by their weight in family_weights.w.
varying vec3 vertex_albedo;
// x grass family (layers 0-3), y mud, z sand, w coast_sand.
varying vec4 ground_weights;
// x hay/straw, y timber floor, z cobble/castle paving, w procedural remainder.
varying vec4 family_weights;
// Weight of the authored flagstone plate, sampled per fragment.
varying float vertex_stone_weight;
varying vec3 vertex_tint;
varying float vertex_cobble_weight;
varying float vertex_castle_weight;
varying float vertex_earth_weight;
varying float vertex_mud_weight;
varying float vertex_sand_weight;
varying vec2 blend_mix;
varying vec2 terrain_world_xz;

vec2 terrain_pattern_uv(int layer, vec2 base_uv) {
	// Natural ground needs a tighter repeat than paving/soil: the authored grass
	// plate is intentionally broad, so matching it to the 2.0-unit actor keeps
	// blade clusters readable beside a house rather than billboard-sized.
	float scale = 1.0;
	if (layer >= 0 && layer <= 3) {
		scale = natural_ground_uv_scale;
	}
	if (layer == timber_floor_layer) {
		scale = timber_floor_uv_scale;
	}
	return base_uv * scale;
}

float natural_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float natural_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(natural_hash(cell), natural_hash(cell + vec2(1.0, 0.0)), local.x),
		mix(natural_hash(cell + vec2(0.0, 1.0)), natural_hash(cell + vec2(1.0, 1.0)), local.x),
		local.y
	);
}

vec2 natural_warp(vec2 uv) {
	// The warp is continuous in world space, so terrain chunks share the same
	// value along their seam instead of each chunk restarting a random pattern.
	float warp_x = natural_noise(uv * 0.52 + vec2(13.7, 4.3));
	float warp_y = natural_noise(uv * 0.52 + vec2(41.2, 19.8));
	return uv + (vec2(warp_x, warp_y) - 0.5) * 0.32;
}

float ground_family_value(vec4 families, float shingle, int family) {
	if (family == 4) {
		return shingle;
	}
	return families[family];
}

float ground_patch_mask(vec2 base_uv, float layer) {
	return natural_noise(base_uv * 0.34 + vec2(4.8, 19.2) + vec2(layer * 7.1, layer * 3.3));
}

// One authored ground family, sampled at two coherent world-space scales. The
// macro sample is rotated and stretched to ~0.17x so its repeat never lines up
// with the primary tile; a very low-frequency mask decides how much of it shows.
// Plates stay tileable, and the continuous warp hides the primary 2048 px grid.
// Returns albedo in rgb and roughness in a; normal xy goes to the out param.
vec4 sample_ground_family(int family, vec2 base_uv, vec4 uv_grad, out vec2 normal_xy) {
	float layer = float(family);
	float family_scale = ground_family_value(ground_uv_scale, shingle_uv_scale, family);
	vec2 primary_uv = natural_warp(base_uv * family_scale);
	vec2 macro_uv = vec2(
		dot(primary_uv, vec2(0.161, 0.050)),
		dot(primary_uv, vec2(-0.045, 0.176))
	) + vec2(0.23, 0.41);
	float detail = clamp(ground_family_value(ground_detail_strength, shingle_detail_strength, family), 0.0, 1.0);
	float macro_mix = (0.14 + ground_patch_mask(base_uv, layer) * 0.30) * detail;
	// Stochastic tiling (after Quilez, "texture repetition"): a world-continuous
	// noise picks one of many hashed whole-plate offsets, and neighbouring
	// variants cross-fade, so identical tufts never line up on a grid. Offsets
	// only translate the plate, so tangent-space normals stay valid. textureGrad
	// with the unshifted derivatives avoids mip seams where the variant changes.
	// uv_grad holds dFdx/dFdy(UV) taken in uniform control flow by fragment();
	// derivatives inside the per-family branches would be undefined. The
	// low-frequency warp is ignored here; it barely changes the mip choice.
	vec2 duv_dx = uv_grad.xy * family_scale;
	vec2 duv_dy = uv_grad.zw * family_scale;
	float variant = natural_noise(primary_uv * 0.37 + vec2(layer * 5.3, 2.7)) * 8.0 * clamp(ground_tile_break, 0.0, 1.0);
	float variant_a = floor(variant);
	vec3 uv_a = vec3(primary_uv + sin(vec2(3.0, 7.0) * variant_a), layer);
	vec3 uv_b = vec3(primary_uv + sin(vec2(3.0, 7.0) * (variant_a + 1.0)), layer);
	vec3 albedo_a = textureGrad(ground_albedo, uv_a, duv_dx, duv_dy).rgb;
	vec3 albedo_b = textureGrad(ground_albedo, uv_b, duv_dx, duv_dy).rgb;
	// Bias the seam by the colour difference so it follows plate features
	// instead of reading as a soft blurred band.
	float variant_mix = smoothstep(0.2, 0.8, fract(variant) - 0.1 * dot(albedo_a - albedo_b, vec3(1.0)));
	vec3 albedo = mix(
		mix(albedo_a, albedo_b, variant_mix),
		texture(ground_albedo, vec3(macro_uv, layer)).rgb,
		macro_mix
	);
	float fine = natural_noise(base_uv * 1.7 + vec2(31.4, 7.7));
	albedo *= 1.0 + (fine - 0.5) * 0.20 * detail;
	vec2 primary_n = mix(
		textureGrad(ground_normal, uv_a, duv_dx, duv_dy).rg,
		textureGrad(ground_normal, uv_b, duv_dx, duv_dy).rg,
		variant_mix
	) * 2.0 - 1.0;
	vec2 macro_n = texture(ground_normal, vec3(macro_uv, layer)).rg * 2.0 - 1.0;
	normal_xy = mix(primary_n, macro_n, macro_mix) * ground_family_value(ground_normal_strength, shingle_normal_strength, family);
	float rough = mix(
		textureGrad(ground_roughness, uv_a, duv_dx, duv_dy).r,
		textureGrad(ground_roughness, uv_b, duv_dx, duv_dy).r,
		variant_mix
	);
	return vec4(albedo, rough);
}

// Plate mean from the smallest mip, read through the same sampler as the plate
// so the division below happens in one colour space on every renderer.
vec3 ground_family_mean(int family) {
	return max(textureLod(ground_albedo, vec3(0.5, 0.5, float(family)), 12.0).rgb, vec3(0.02));
}

// Grass family (grass, meadow, forest floor, bog) shares one plate; layers
// 0-3 keep the natural_ground_uv_scale repeat that matches the 2.0-unit actor.
vec4 sample_natural_ground(vec2 base_uv, vec4 uv_grad, out vec2 normal_xy) {
	vec4 grass = sample_ground_family(0, base_uv * natural_ground_uv_scale, uv_grad * natural_ground_uv_scale, normal_xy);
	float variation = clamp(natural_ground_variation, 0.0, 1.0);
	float patch = natural_noise(base_uv * 0.34 + vec2(4.8, 19.2));
	grass.rgb *= 1.0 + (patch - 0.5) * 0.12 * variation;
	return grass;
}

vec4 sample_sand_family(int family, vec2 base_uv, vec4 uv_grad, vec3 palette_tint, out vec2 normal_xy) {
	vec4 sand = sample_ground_family(family, base_uv, uv_grad, normal_xy);
	vec3 gain = palette_tint * sand_palette_value / ground_family_mean(family);
	sand.rgb *= mix(vec3(1.0), gain, clamp(sand_palette_authority, 0.0, 1.0));
	return sand;
}

vec4 sample_coast_sand(vec2 base_uv, vec4 uv_grad, vec3 palette_tint, out vec2 normal_xy) {
	vec4 sand = sample_sand_family(3, base_uv, uv_grad, palette_tint, normal_xy);
	if (use_authored_shingle < 0.5 || coast_shingle_amount <= 0.0) {
		return sand;
	}
	// Shingle collects in long irregular strands along the storm line.
	float strand = natural_noise(vec2(base_uv.x * 0.9, base_uv.y * 0.35) + vec2(17.3, 2.1));
	float shingle_w = smoothstep(0.58, 0.78, strand) * clamp(coast_shingle_amount, 0.0, 1.0);
	if (shingle_w <= 0.001) {
		return sand;
	}
	vec2 shingle_n;
	vec4 shingle = sample_sand_family(4, base_uv, uv_grad, palette_tint * 0.92, shingle_n);
	normal_xy = mix(normal_xy, shingle_n, shingle_w);
	return mix(sand, shingle, shingle_w);
}

vec3 sample_authored_timber_floor(vec2 base_uv) {
	// Boards must stay mostly straight. A light warp hides the 512 px seam
	// without turning the floor into rubber wood.
	vec2 timber_uv = base_uv * timber_floor_uv_scale;
	vec2 warped = natural_warp(timber_uv);
	return texture(timber_floor_albedo, fract(mix(timber_uv, warped, 0.18))).rgb;
}

vec3 sample_authored_stone(vec2 base_uv) {
	return texture(stone_albedo, base_uv * stone_uv_scale).rgb;
}

vec3 sample_authored_hay(vec2 base_uv) {
	vec2 hay_uv = natural_warp(base_uv * hay_uv_scale);
	// No fract(): the sampler repeats, and fract's jump at every tile edge broke
	// the derivatives into a one-pixel low-mip seam, more visible at this repeat.
	return texture(hay_albedo, hay_uv).rgb;
}

bool is_hay_field_layer(int layer) {
	return layer == hay_layer || layer == straw_layer;
}

// Procedural remainder layers only (dirt, farm soil, ash, stone, plaster, and any
// authored family whose plate is missing). Authored plates, hay, timber floors
// and cobble are sampled per fragment instead.
//
// The stone layer stays tinted by its palette entry. Its source is an interior
// flagstone floor that, left untinted, rendered far brighter than the paving and
// earth it borders, producing pale wedges along stone aprons.
vec3 terrain_pattern_albedo(int layer, vec2 uv, vec3 palette_tint) {
	vec3 pattern = texture(terrain_patterns, vec3(terrain_pattern_uv(layer, uv), float(layer))).rgb;
	// Tinted multipliers keep palette authority while letting a plate carry its own
	// hue variation (dry dust versus damp hollow). Grayscale plates are unchanged
	// because all three channels already hold the same value.
	return pattern * palette_tint;
}

float earth_layer_weight(int layer) {
	return float(layer >= earth_layer_min && layer <= earth_layer_max);
}

float cobble_layer_weight(int layer) {
	return float(layer == cobblestone_layer || layer == castle_paving_layer);
}

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

// Continuous world-space height field for trodden ground. Octaves are coprime so
// the surface never repeats on the terrain tile, and every chunk shares the same
// value along its seam because the field is sampled in world coordinates.
float earth_height(vec2 p) {
	float lumps = cobble_noise(p * 0.31 + vec2(7.3, 2.9));
	float tread = cobble_noise(p * 0.83 - vec2(3.1, 11.7));
	float gravel = cobble_noise(p * 2.7 + vec2(19.4, 5.2));
	return lumps * 0.58 + tread * 0.29 + gravel * 0.13;
}

vec3 compute_cobble_albedo(vec2 uv, vec2 world_xz) {
	float pattern = texture(cobble_patterns, vec3(uv, 0.0)).r;
	vec4 surface = texture(cobble_surface, uv);
	float stone = surface.b;
	float palette = surface.a;
	float age = cobble_noise(world_xz * 0.17 + vec2(13.7, 4.3));
	age = age * 0.68 + cobble_noise(world_xz * 0.43 - vec2(2.1, 7.9)) * 0.32;
	float grit = cobble_noise(world_xz * 1.15 + vec2(8.4, 19.2));
	float mud_film = cobble_noise(world_xz * 0.29 - vec2(5.6, 1.8));
	vec3 earth = mix(vec3(0.20, 0.17, 0.13), vec3(0.32, 0.27, 0.20), age);
	vec3 gray = vec3(0.40, 0.39, 0.38);
	vec3 blue_gray = vec3(0.36, 0.38, 0.39);
	vec3 purple_gray = vec3(0.38, 0.36, 0.38);
	vec3 warm_gray = vec3(0.41, 0.38, 0.34);
	vec3 stone_color = gray;
	if (palette > 0.78) {
		stone_color = purple_gray;
	} else if (palette > 0.48) {
		stone_color = blue_gray;
	} else if (palette < 0.14) {
		stone_color = warm_gray;
	}
	stone_color *= mix(0.70, 0.92, pattern);
	stone_color = mix(stone_color, gray, 0.22);
	float dirt_amount = (1.0 - stone) * 0.58 + (1.0 - age) * 0.20 + grit * 0.10 + mud_film * 0.14;
	stone_color = mix(stone_color, earth, clamp(dirt_amount, 0.0, 0.72));
	return mix(earth, stone_color, stone * 0.82 + 0.06);
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
	// Dome: the shoulder rises over `shoulder` cells, the crown stays broad.
	float shoulder = 0.34;
	float t = clamp((inset - joint) / shoulder, 0.0, 1.0);
	float dome = t * t * (3.0 - 2.0 * t);
	// Some stones have sunk under cart wheels; others stand proud.
	float top = 0.55 + h2 * 0.45;
	vec2 grad_h = grad_inset * top * 6.0 * t * (1.0 - t) / shoulder;
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
	result.albedo = mix(earth, stone_color, cover);
	result.normal_xy = -slope;
	result.roughness = mix(0.97, mix(0.88, 0.66, dome * top), cover);
	result.stone = cover;
	return result;
}

// Adds one corner layer to the per-family weights. Procedural layers are
// resolved here, weighted, into vertex_albedo.
void accumulate_layer(int layer, float weight, vec2 uv, vec3 tint, inout vec4 ground, inout vec4 family, inout float stone, inout vec3 remainder) {
	if (layer >= 0 && layer <= 3) {
		ground.x += weight;
	} else if ((layer == mud_layer || layer == dirt_layer || layer == earth_layer_min) && use_authored_mud > 0.5) {
		ground.y += weight;
	} else if (layer == sand_layer && use_authored_sand > 0.5) {
		ground.z += weight;
	} else if (layer == coast_sand_layer && use_authored_coast_sand > 0.5) {
		ground.w += weight;
	} else if (is_hay_field_layer(layer) && use_authored_hay > 0.5) {
		family.x += weight;
	} else if (layer == timber_floor_layer) {
		family.y += weight;
	} else if (cobble_layer_weight(layer) > 0.5) {
		family.z += weight;
	} else if (layer == stone_layer && use_authored_stone > 0.5) {
		stone += weight;
	} else {
		family.w += weight;
		remainder += terrain_pattern_albedo(layer, uv, tint) * weight;
	}
}

void vertex() {
	ivec2 layers = ivec2(int(CUSTOM0.x + 0.5), int(CUSTOM0.y + 0.5));
	float raw_blend = clamp(CUSTOM0.z, 0.0, 1.0);
	blend_mix = vec2(raw_blend, CUSTOM0.w);
	terrain_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec3 tint = COLOR.rgb;
	vertex_tint = tint;
	vec4 ground = vec4(0.0);
	vec4 family = vec4(0.0);
	vec3 remainder = vec3(0.0);
	float stone_w = 0.0;
	accumulate_layer(layers.x, 1.0 - raw_blend, UV, tint, ground, family, stone_w, remainder);
	accumulate_layer(layers.y, raw_blend, UV, tint, ground, family, stone_w, remainder);
	vertex_stone_weight = stone_w;
	ground_weights = ground;
	family_weights = family;
	vertex_albedo = remainder;
	vertex_cobble_weight = family.z;
	vertex_castle_weight = mix(float(layers.x == castle_paving_layer), float(layers.y == castle_paving_layer), raw_blend);
	vertex_earth_weight = mix(earth_layer_weight(layers.x), earth_layer_weight(layers.y), raw_blend);
	vertex_mud_weight = mix(float(layers.x == mud_layer), float(layers.y == mud_layer), raw_blend);
	vertex_sand_weight = mix(
		float(layers.x == sand_layer || layers.x == coast_sand_layer),
		float(layers.y == sand_layer || layers.y == coast_sand_layer),
		raw_blend
	);
}

void fragment() {
	float tone = blend_mix.y;
	float cobble_weight = vertex_cobble_weight;
	float earth_weight = vertex_earth_weight * (1.0 - cobble_weight);
	float wet_mud = clamp(mud_wetness, 0.0, 1.0) * vertex_mud_weight;
	vec4 surface = texture(cobble_surface, UV);
	float stone = surface.b;
	vec3 tint = vertex_tint;
	vec3 realistic_tint = mix(vec3(1.0), tint, 0.16);

	// Fragment-rate families. Weights below the threshold skip their fetches, so
	// an ordinary fragment only pays for the one or two families it blends.
	vec3 albedo = vertex_albedo;
	vec2 plate_normal = vec2(0.0);
	float plate_rough = 0.0;
	float plate_weight = 0.0;
	vec2 family_normal;
	// Taken here, in uniform control flow, for the ground families' textureGrad.
	vec4 uv_grad = vec4(dFdx(UV), dFdy(UV));
	if (ground_weights.x > 0.001) {
		vec4 grass = sample_natural_ground(UV, uv_grad, family_normal);
		albedo += grass.rgb * realistic_tint * ground_weights.x;
		plate_normal += family_normal * ground_weights.x;
		plate_rough += grass.a * ground_weights.x;
		plate_weight += ground_weights.x;
	}
	if (ground_weights.y > 0.001) {
		vec4 mud = sample_ground_family(1, UV, uv_grad, family_normal);
		// Desaturate toward a dusty grey-brown: the raw plate is too orange next to grass.
		vec3 mud_rgb = mix(vec3(dot(mud.rgb, vec3(0.299, 0.587, 0.114))) * vec3(1.0, 0.93, 0.85), mud.rgb, 0.55) * 0.88;
		albedo += mud_rgb * realistic_tint * ground_weights.y;
		plate_normal += family_normal * ground_weights.y;
		plate_rough += mud.a * ground_weights.y;
		plate_weight += ground_weights.y;
	}
	if (ground_weights.z > 0.001) {
		vec4 sand = sample_sand_family(2, UV, uv_grad, tint, family_normal);
		albedo += sand.rgb * ground_weights.z;
		plate_normal += family_normal * ground_weights.z;
		plate_rough += sand.a * ground_weights.z;
		plate_weight += ground_weights.z;
	}
	if (ground_weights.w > 0.001) {
		vec4 coast = sample_coast_sand(UV, uv_grad, tint, family_normal);
		albedo += coast.rgb * ground_weights.w;
		plate_normal += family_normal * ground_weights.w;
		plate_rough += coast.a * ground_weights.w;
		plate_weight += ground_weights.w;
	}
	if (family_weights.x > 0.001) {
		albedo += sample_authored_hay(UV) * realistic_tint * family_weights.x;
	}
	if (family_weights.y > 0.001) {
		albedo += sample_authored_timber_floor(UV) * realistic_tint * family_weights.y;
	}
	if (vertex_stone_weight > 0.001) {
		// Tinted by the palette entry like the old array path: the raw interior
		// flagstone plate is far brighter than the paving and earth it borders.
		albedo += sample_authored_stone(UV) * tint * vertex_stone_weight;
	}
	// Street cobbles use the fieldstone Voronoi; castle paving keeps the lattice.
	float castle_weight = min(vertex_castle_weight, family_weights.z);
	float fieldstone_weight = family_weights.z - castle_weight;
	vec2 cobble_normal = (surface.rg * 2.0 - 1.0) * 0.55 * castle_weight;
	float cobble_rough = mix(0.99, 0.93, stone) * castle_weight;
	float cobble_stone = stone * castle_weight;
	if (castle_weight > 0.001) {
		albedo += compute_cobble_albedo(UV, terrain_world_xz) * castle_weight;
	}
	if (fieldstone_weight > 0.001) {
		vec2 world_step = fwidth(terrain_world_xz);
		FieldStone field = compute_fieldstone(terrain_world_xz, max(world_step.x, world_step.y) / cobble_cell_size);
		albedo += field.albedo * fieldstone_weight;
		cobble_normal += field.normal_xy * fieldstone_weight;
		cobble_rough += field.roughness * fieldstone_weight;
		cobble_stone += field.stone * fieldstone_weight;
	}

	ALBEDO = albedo * tone;
	float mud_pool = smoothstep(0.38, 0.78, cobble_noise(terrain_world_xz * 0.72 + vec2(9.1, 3.7)));
	float mud_film_weight = wet_mud * mix(0.58, 1.0, mud_pool);
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(0.48, 0.43, 0.36), mud_film_weight * 0.64);

	float earth_h = earth_height(terrain_world_xz);
	ALBEDO *= 1.0 + (earth_h - 0.5) * 0.22 * earth_weight;
	float eps = 0.10;
	vec2 earth_slope = vec2(
		earth_height(terrain_world_xz + vec2(eps, 0.0)) - earth_height(terrain_world_xz - vec2(eps, 0.0)),
		earth_height(terrain_world_xz + vec2(0.0, eps)) - earth_height(terrain_world_xz - vec2(0.0, eps))
	) * 2.6;
	vec3 earth_normal = normalize(vec3(-earth_slope.x, 1.0, -earth_slope.y)).xzy;
	// Tangent-space xy offsets add up: broad earth lumps, cobble joints and the
	// authored plate grain. z is rebuilt so the result stays unit length.
	vec2 combined_xy = earth_normal.xy * 0.30 * earth_weight
		+ cobble_normal
		+ plate_normal;
	combined_xy = clamp(combined_xy, vec2(-0.95), vec2(0.95));
	vec3 combined = vec3(combined_xy, sqrt(max(1.0 - dot(combined_xy, combined_xy), 0.0)));
	NORMAL_MAP = combined * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = 0.96 * (1.0 - cobble_weight) + cobble_rough;
	if (plate_weight > 0.001) {
		ROUGHNESS = mix(ROUGHNESS, plate_rough / plate_weight, clamp(plate_weight, 0.0, 1.0));
	}
	ROUGHNESS = mix(ROUGHNESS, mix(0.42, 0.20, mud_pool), mud_film_weight);
	// Polished stone crowns catch a little more light than the earth joints.
	SPECULAR = mix(0.12 + 0.14 * cobble_stone, 0.30, mud_film_weight);
	// WS-08: the same analytic swash as the water decides when this sand was last
	// covered; it darkens, turns glossy and dries over dryTime (28 s), and the
	// highest reach of each wave leaves a thin foam residue for residueLife (5 s).
	if (shore_field_valid > 0.5 && vertex_sand_weight > 0.01) {
		ShoreState shore = shore_state(terrain_world_xz, ocean_time, shore_sea());
		float sand = shore.valid * shore.beach * vertex_sand_weight;
		float wet = exp(-shore.time_since_wet / SHORE_DRY_TIME) * sand;
		ALBEDO *= 1.0 - 0.45 * wet;
		ROUGHNESS = mix(ROUGHNESS, 0.25, wet);
		SPECULAR = mix(SPECULAR, 0.42, wet);
		ALBEDO = mix(ALBEDO, vec3(0.80, 0.82, 0.78), clamp(shore.residue * sand, 0.0, 1.0) * 0.55);
	}
}
