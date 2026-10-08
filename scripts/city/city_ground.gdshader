shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// ADR 0031 city ground: one continuous heightfield, surfaces blended from the
// baked splat (R paving, G packed earth, B sand, A mud) plus slope rock, so
// streets, yards, beaches and the Toompea klint read without tile seams.

uniform sampler2D splat : source_color, filter_linear, repeat_disable;
uniform vec4 splat_rect = vec4(0.0, 0.0, 1.0, 1.0); // origin.xz, size.xz in world units
// Cart roads (tools/city/terrain_relief.py road_map): R body, G signed lateral
// offset (128 = centreline, +-5 m), B traffic wear, A verge band. Same rect as splat.
uniform sampler2D roads : filter_linear, repeat_disable;
// Footprints, hoofprints and wheel tracks around Kalev (CityGroundTrail): R is
// 0.5 for undisturbed ground, below it pressed down, above it pushed up as a rim.
uniform sampler2D trail : filter_linear, repeat_disable;
uniform vec4 trail_rect = vec4(0.0, 0.0, 1.0, 1.0); // origin.xz, size.xz in world units
uniform float trail_depth = 0.17; // world units of relief at full press
// The city heightfield (CityPlan.height_texture): crests dry out, hollows stay damp.
uniform sampler2D ground_height : filter_linear, repeat_disable;
uniform vec4 ground_rect = vec4(0.0, 0.0, 1.0, 1.0); // origin.xz, size.xz in world units
// Trail relief mesh (CityGroundTrail._relief): a fine grid round Kalev displaced by the
// trail map so prints and ruts have a real silhouette at grazing angles. The
// coarse chunks under it sink by `trail_sink` at every grid vertex within
// `trail_mesh_rect.z` of the centre (xy) so the pressed relief is not buried;
// w = 0 switches the mesh off and nothing sinks. Visual only: CityPlan.ground_height
// and collision still follow the undisplaced surface.
uniform vec4 trail_mesh_rect = vec4(0.0, 0.0, 0.0, 0.0); // centre.xz, sink half-extent, on
uniform float trail_sink = 0.4; // > deepest print plus rut at trail_mesh_depth
// Share of the shaded print depth the mesh really displaces: the normal-map relief
// is exaggerated so a print reads from above, real geometry that deep looks dug.
uniform float trail_mesh_depth = 0.6;

uniform sampler2D earth_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

// Texture repeats per world unit. The plates cover ~1 m of ground, so a blade
// of grass or a pebble reads at its real size next to Kalev.
uniform float grass_scale = 0.62;
uniform float earth_scale = 0.55;
uniform float sand_scale = 0.5;
uniform float rock_scale = 0.3;
// Fieldstone paving shared with the district maps (fieldstone_paving.gdshaderinc).
uniform float cobble_cell_size = 0.2;
uniform float cobble_relief = 0.05;
// Meadow relief strength (normal, cavity shade) and turf specular, see grass_height().
uniform float grass_relief_normal = 0.12;
uniform float grass_relief_shade = 0.30;
uniform float grass_specular = 0.04;
uniform vec3 grass_tint : source_color = vec3(0.78, 0.86, 0.62);
uniform vec3 earth_tint : source_color = vec3(0.60, 0.55, 0.47);
uniform float wetness = 0.0;
// Standing water after rain (SkyWeather3D.puddle_wetness()).
uniform float puddles = 0.0;
uniform float sea_level = 0.0;

#include "res://scripts/map/view3d/fieldstone_paving.gdshaderinc"

varying vec3 world_pos;
varying vec3 world_normal;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float mud_height(vec2 p) {
	float lumps = value_noise(p * 0.9);
	float ruts = value_noise(vec2(p.x * 0.35, p.y * 3.1)) * value_noise(vec2(p.x * 3.1, p.y * 0.35));
	float pocks = value_noise(p * 4.7);
	return lumps * 0.55 + ruts * 0.3 + pocks * 0.15;
}

// Tilled field soil (black earth). The plan generator marks it in splat.png as full
// packed earth plus a mud-channel value of FIELD_MUD_LEVEL (110/255 = 0.43); no other
// surface sits in that band. Keep in sync with build_reval_city_plan.py and
// CityGrass.field_share.
float field_zone(vec4 s, float edge_noise) {
	float band = smoothstep(0.30, 0.36, s.a + edge_noise) * (1.0 - smoothstep(0.52, 0.60, s.a + edge_noise));
	return band * smoothstep(0.6, 0.85, s.g);
}

// Clods, ridges and small stones of a ploughed field as a height field (0..1).
// Returns x = height, y = stone mask (round pebbles standing out of the soil).
vec2 field_height(vec2 p) {
	// Broad ridges and hollows, warped so they never run ruler straight.
	vec2 w = p + vec2(value_noise(p * 0.21), value_noise(p * 0.21 + 7.3)) * 3.0;
	float ridges = value_noise(vec2(w.x * 0.9, w.y * 0.9));
	float clods = value_noise(p * 2.3) * 0.6 + value_noise(p * 5.9) * 0.4;
	vec2 cell = floor(p * 3.1);
	vec2 off = vec2(hash12(cell + 11.0), hash12(cell + 23.0)) * 0.6 + 0.2;
	float d = length(fract(p * 3.1) - off);
	float present = step(0.84, hash12(cell + 5.0));
	float stone = present * (1.0 - smoothstep(0.07, 0.15, d));
	return vec2(ridges * 0.45 + clods * 0.4 + stone * 0.6, stone);
}

// Cart road cross-section as height in world units (1 wu = 0.87 m): two wheel
// ruts a cart's gauge apart, a spoil berm outside each, and the hump the horse
// walks along. `rd` is the roads texel; wetness deepens everything because wet
// clay gives under the wheel while dry ground only crumbles.
// Returns (height, rut mask, hump mask).
vec3 road_profile(vec2 p, vec4 rd, float wet) {
	float lat = ((rd.g * 255.0 - 128.0) / 127.0) * 5.75;
	lat += (value_noise(p * 0.07) - 0.5) * 0.7 + (value_noise(p * 0.45) - 0.5) * 0.14;
	float depth = (0.5 + 0.9 * value_noise(p * 0.11)) * (0.35 + 0.65 * rd.b) * smoothstep(0.1, 0.6, rd.r);
	depth *= 0.95 + 0.6 * wet;
	float gauge = 0.82;
	float ruts = max(exp(-pow((lat + gauge) / 0.22, 2.0)), exp(-pow((lat - gauge) / 0.22, 2.0)));
	float berm = exp(-pow((abs(lat) - gauge - 0.46) / 0.24, 2.0));
	float hump = exp(-pow(lat / 0.5, 2.0));
	float h = (-ruts * 0.12 + berm * 0.05 - hump * 0.012) * depth;
	return vec3(h, ruts * depth, hump * depth);
}

float trail_height(vec2 p) {
	vec2 uv = (p - trail_rect.xy) / trail_rect.zw;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return 0.0;
	}
	return (texture(trail, uv).r - 0.5) * 2.0 * trail_depth;
}

float ground_at(vec2 p) {
	return texture(ground_height, (p - ground_rect.xy) / ground_rect.zw).r;
}

// Height above the mean of the ground 6 wu round: > 0 on a crest, < 0 in a hollow.
float curvature(vec2 p) {
	float r = 6.0;
	float around = (ground_at(p + vec2(r, 0.0)) + ground_at(p - vec2(r, 0.0))
		+ ground_at(p + vec2(0.0, r)) + ground_at(p - vec2(0.0, r))) * 0.25;
	return ground_at(p) - around;
}

// Tussock height of meadow turf in [0,1]. The grass plates only hold blade-scale
// detail, so under a low sun a pasture read as one smooth waxy sheet. Clumps of
// ~2 m, ridged tufts of ~0.7 m and blade lumps add mid-scale relief; the ridge
// term makes sharp valleys between tufts, the way turf shades its own soil.
float grass_height(vec2 p) {
	float clumps = value_noise(p * 0.5 + vec2(2.3, 8.1));
	float tufts = value_noise(p * 1.4 - vec2(6.7, 1.9));
	float blades = value_noise(p * 4.1 + vec2(11.2, 4.6));
	return clumps * 0.42 + (1.0 - abs(tufts * 2.0 - 1.0)) * 0.38 + blades * 0.20;
}

float grass_step(vec3 n) {
	return smoothstep(0.55, 0.9, n.y);
}

float slope_len(vec3 n) {
	return 1.0 - clamp(n.y, 0.0, 1.0);
}

// Two rotated samples break the visible repeat of every plate.
vec3 detiled(sampler2D tex, vec2 uv) {
	float n = value_noise(uv * 0.11);
	vec2 uv2 = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * uv * 0.73 + vec2(0.37, 0.71);
	return mix(texture(tex, uv).rgb, texture(tex, uv2).rgb, smoothstep(0.3, 0.7, n));
}


// --- Cliff rock ----------------------------------------------------------------
// The klint faces and steep banks are Ordovician limestone over sand and clay, not
// a masonry wall: horizontal beds of varying hardness (hard beds jut out, soft ones
// recess), vertical joints, spalled blocks and weathering. Procedural in world space
// so a face never stretches and never shows a repeating brick pattern.
// Returns relief height in world units; bed index in `bed`.
float cliff_height(vec3 p, out float bed) {
	// Warp so beds undulate and wedge out along the face instead of ruling dead straight.
	float warp = (value_noise(p.xz * 0.11) - 0.5) * 2.2 + (value_noise(p.xz * 0.45) - 0.5) * 0.5;
	float s = p.y * 1.15 + warp;
	bed = floor(s);
	float hard = hash12(vec2(bed, 3.7));
	float f = fract(s);
	// Hard beds keep a square nose; soft beds weather back into a slope.
	float profile = mix(smoothstep(0.0, 0.9, f) * 0.35, 1.0 - pow(1.0 - f, 5.0) * 0.6, hard);
	float h = profile * (0.10 + 0.16 * hard);
	// Vertical joints: ridged noise stretched along the fall line, cutting the beds into blocks.
	float along = p.x * 0.8 + p.z * 0.6;
	float joint_a = abs(value_noise(vec2(along * 1.7 + bed * 5.3, bed * 0.31)) * 2.0 - 1.0);
	float joint_b = abs(value_noise(vec2(along * 4.3 - bed * 2.9, p.y * 0.12)) * 2.0 - 1.0);
	float joints = (1.0 - smoothstep(0.0, 0.07, joint_a)) + (1.0 - smoothstep(0.0, 0.05, joint_b)) * 0.6;
	h -= clamp(joints, 0.0, 1.0) * 0.22;
	// Spalled and weathered surface: blocky mid scale plus fine grain.
	h += (value_noise(vec2(along * 2.3, p.y * 1.9) + bed) - 0.5) * 0.22;
	h += (value_noise(vec2(along * 9.0, p.y * 7.0)) - 0.5) * 0.06;
	return h;
}

// Sand bluffs (low coast banks, soft lower beds) erode into gullies running down the
// face rather than beds; same output convention as cliff_height().
float bluff_height(vec3 p) {
	float along = p.x * 0.8 + p.z * 0.6;
	float rills = value_noise(vec2(along * 3.1 + value_noise(vec2(along * 0.7, p.y * 0.3)) * 2.0, p.y * 0.35));
	float h = (rills - 0.5) * 0.2;
	h += (value_noise(vec2(along * 8.0, p.y * 5.0)) - 0.5) * 0.07;
	// Slumped terraces where a harder band holds a lip.
	h += smoothstep(0.7, 1.0, fract(p.y * 0.7 + value_noise(p.xz * 0.2) * 1.4)) * 0.1;
	return h;
}

// Share of sandy bluff vs limestone: low banks and some soft lower beds are sand.
float bluff_share(vec3 p, float bed, float sand_splat) {
	float low = 1.0 - smoothstep(3.0, 11.0, p.y);
	float soft_bed = step(0.78, hash12(vec2(bed, 9.1))) * 0.6;
	return clamp(max(max(low * 0.9, soft_bed), sand_splat), 0.0, 1.0);
}

float rock_surface(vec3 p, float sand_splat) {
	float bed;
	float lime = cliff_height(p, bed);
	float sandy = bluff_share(p, bed, sand_splat);
	return mix(lime, bluff_height(p), sandy);
}

#include "res://scripts/city/city_grass_ground.gdshaderinc"

// --- Trail relief mesh -------------------------------------------------------
// The mesh must lie exactly on the chunk surface, so it rebuilds it here: the
// same grid samples, the same diagonal split (CityTerrainBuilder._chunk_mesh,
// CityPlan.ground_height) and the same central-difference vertex normals and
// tangents, interpolated over the triangle like the rasteriser does for a chunk.

float grid_h(ivec2 g) {
	ivec2 n = textureSize(ground_height, 0);
	return texelFetch(ground_height, clamp(g, ivec2(0), n - 1), 0).r;
}

float grid_cell() {
	return ground_rect.z / float(textureSize(ground_height, 0).x);
}

vec3 grid_normal(ivec2 g, float cell) {
	float dx = grid_h(g + ivec2(1, 0)) - grid_h(g - ivec2(1, 0));
	float dz = grid_h(g + ivec2(0, 1)) - grid_h(g - ivec2(0, 1));
	return normalize(vec3(-dx, 2.0 * cell, -dz));
}

// Sink of a chunk vertex: a grid vertex well inside the mesh rect drops by
// trail_sink. Exact grid offsets from a grid-snapped centre, so the pattern does
// not flicker as Kalev walks.
float grid_sink(ivec2 g, vec2 origin, float cell) {
	vec2 off = abs(origin + vec2(g) * cell - trail_mesh_rect.xy);
	return (trail_mesh_rect.w > 0.5 && max(off.x, off.y) <= trail_mesh_rect.z) ? trail_sink : 0.0;
}

// Relief height the mesh lifts into geometry at p: the trail prints scaled by
// the fragment's `give` (soft ground takes prints, paving and rock do not) plus
// the cart-road rut profile, both without the per-pixel noise of the blend.
float vertex_relief(vec2 p, vec3 n, float tr, float wet_road) {
	vec2 suv = (p - splat_rect.xy) / splat_rect.zw;
	vec4 s = textureLod(splat, suv, 0.0);
	vec4 rd = textureLod(roads, suv, 0.0);
	float paving = smoothstep(0.25, 0.7, s.r);
	float road = rd.r * (1.0 - paving);
	float soft = clamp(smoothstep(0.15, 0.65, s.g) + smoothstep(0.2, 0.7, s.a) + road, 0.0, 1.0) * (1.0 - paving);
	float sand = smoothstep(0.2, 0.7, s.b);
	float rock = smoothstep(0.24, 0.4, 1.0 - clamp(n.y, 0.0, 1.0));
	float give = clamp(soft + (1.0 - soft) * (1.0 - sand) * 0.3 * grass_step(n), 0.0, 1.0) * (1.0 - rock);
	return tr * give * (0.45 + 1.3 * wet_road) + road_profile(p, rd, wet_road).x * road;
}

void trail_mesh_vertex(inout vec3 vtx, inout vec3 nrm, inout vec3 tan, inout vec3 bin, mat4 model) {
	vec2 p = (model * vec4(vtx, 1.0)).xz;
	float cell = grid_cell();
	vec2 origin = ground_rect.xy + cell * 0.5;
	ivec2 n = textureSize(ground_height, 0);
	vec2 f = clamp((p - origin) / cell, vec2(0.0), vec2(n) - 1.001);
	ivec2 i = ivec2(floor(f));
	vec2 uv = f - vec2(i);
	ivec2 ga = i, gb = i + ivec2(1, 0), gc = i + ivec2(0, 1), gd = i + ivec2(1, 1);
	float ha = grid_h(ga), hb = grid_h(gb), hc = grid_h(gc), hd = grid_h(gd);
	// Barycentric weights of the four corners on the triangle that holds p.
	vec4 w;
	if (abs(ha - hd) < abs(hb - hc)) {
		w = uv.x >= uv.y ? vec4(1.0 - uv.x, uv.x - uv.y, 0.0, uv.y) : vec4(1.0 - uv.y, 0.0, uv.y - uv.x, uv.x);
	} else {
		w = uv.x + uv.y <= 1.0 ? vec4(1.0 - uv.x - uv.y, uv.x, uv.y, 0.0) : vec4(0.0, 1.0 - uv.y, 1.0 - uv.x, uv.x + uv.y - 1.0);
	}
	float base = dot(w, vec4(ha, hb, hc, hd));
	vec3 na = grid_normal(ga, cell), nb = grid_normal(gb, cell), nc = grid_normal(gc, cell), nd = grid_normal(gd, cell);
	vec3 bn = na * w.x + nb * w.y + nc * w.z + nd * w.w;
	vec3 x = vec3(1.0, 0.0, 0.0);
	vec3 bt = normalize(x - na * na.x) * w.x + normalize(x - nb * nb.x) * w.y
		+ normalize(x - nc * nc.x) * w.z + normalize(x - nd * nd.x) * w.w;
	// The sunk chunk surface under p: the mesh may never dip below it, so in the
	// ramp band (part-sunk cells) deep prints are clamped instead of buried.
	float sink = dot(w, vec4(grid_sink(ga, origin, cell), grid_sink(gb, origin, cell),
		grid_sink(gc, origin, cell), grid_sink(gd, origin, cell)));
	float wet_road = clamp(wetness + puddles * 0.5, 0.0, 1.0);
	// A 3x3 tent 1.5 trail texels wide: the stamps have near-vertical walls that
	// read as torn cliffs in geometry; the blur slopes them like slumped mud.
	vec2 t = vec2(1.5 * trail_rect.z / float(textureSize(trail, 0).x), 0.0);
	float tr = trail_height(p) * 0.25
		+ (trail_height(p + t.xy) + trail_height(p - t.xy) + trail_height(p + t.yx) + trail_height(p - t.yx)) * 0.125
		+ (trail_height(p + t.xx) + trail_height(p - t.xx) + trail_height(p + vec2(t.x, -t.x)) + trail_height(p - vec2(t.x, -t.x))) * 0.0625;
	float disp = vertex_relief(p, normalize(bn), tr, wet_road) * trail_mesh_depth;
	// Fade out over the part-sunk band so a groove eases into the shader-only
	// relief past the mesh instead of ending in a step.
	vec2 off = abs(p - trail_mesh_rect.xy);
	disp *= smoothstep(trail_mesh_rect.z + cell * 0.75, trail_mesh_rect.z, max(off.x, off.y));
	// A hair above the chunk so the two never z-fight where neither moved.
	disp = max(disp, -sink) + 0.004;
	vtx.y = base + disp - model[3].y;
	// Shading keeps the undisplaced surface normal: the fragment's trail normal
	// map already shades the prints, exactly as on the chunks round the mesh.
	nrm = bn;
	tan = bt;
	bin = cross(bn, bt);
}

void vertex() {
	// The relief mesh carries vertex colour alpha 0; the chunks have no colour
	// array, which Godot reads as white. (An instance uniform would take a global
	// buffer slot for every chunk and overflow it.)
	if (COLOR.a < 0.5) {
		vec3 vtx = VERTEX, nrm = NORMAL, tan = TANGENT, bin = BINORMAL;
		trail_mesh_vertex(vtx, nrm, tan, bin, MODEL_MATRIX);
		VERTEX = vtx;
		NORMAL = nrm;
		TANGENT = tan;
		BINORMAL = bin;
	} else if (trail_mesh_rect.w > 0.5) {
		// Chunk vertices on grid points; sink the ones the trail mesh covers.
		vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
		float cell = grid_cell();
		vec2 origin = ground_rect.xy + cell * 0.5;
		VERTEX.y -= grid_sink(ivec2(round((p - origin) / cell)), origin, cell);
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 suv = (world_pos.xz - splat_rect.xy) / splat_rect.zw;
	vec4 s = texture(splat, suv);
	float macro = value_noise(world_pos.xz * 0.035);
	float micro = value_noise(world_pos.xz * 0.6);

	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float rock = smoothstep(0.24, 0.4, slope + (macro - 0.5) * 0.12);
	float paving = smoothstep(0.25, 0.7, s.r + (micro - 0.5) * 0.25);
	float earth = smoothstep(0.15, 0.65, s.g + (micro - 0.5) * 0.3);
	float sand = smoothstep(0.2, 0.7, s.b + (macro - 0.5) * 0.3);
	float mud = smoothstep(0.2, 0.7, s.a + (micro - 0.5) * 0.3);
	// Field soil carries a mud-channel marker: it is not mud, and its edge is ragged.
	float field = field_zone(s, (micro - 0.5) * 0.12 + (macro - 0.5) * 0.2);
	mud *= 1.0 - field;
	earth = max(earth * (1.0 - field), 0.0);
	// Beaches and the delta margin: everything within a metre of the sea is sand or mud.
	float shore = 1.0 - smoothstep(sea_level + 0.4, sea_level + 1.6, world_pos.y);
	sand = max(sand, shore * 0.9);

	vec2 wuv = world_pos.xz;
	vec4 rd = texture(roads, suv);
	float wet_road = clamp(wetness + puddles * 0.5, 0.0, 1.0);
	// Twelve seamless meadow plates on a warped lattice (city_grass_ground.gdshaderinc).
	GrassGround meadow = grass_ground(wuv, smoothstep(0.08, 0.45, s.g + s.a) * 0.75);
	vec3 grass = meadow.albedo * grass_tint * mix(0.85, 1.08, macro);
	// Crests dry to straw and thin out; hollows and swales stay lush and damp.
	float curv = curvature(world_pos.xz);
	float crest = smoothstep(0.1, 0.55, curv);
	float hollow_damp = smoothstep(0.1, 0.55, -curv);
	grass = mix(grass, grass * vec3(1.32, 1.16, 0.78) + vec3(0.04, 0.03, 0.0), crest * 0.7);
	grass = mix(grass, grass * vec3(0.72, 0.84, 0.66), hollow_damp * 0.8);
	vec3 col = grass;
	vec2 nxy = meadow.normal_xy;
	col = mix(col, detiled(earth_albedo, wuv * earth_scale) * earth_tint, earth);
	nxy = mix(nxy, texture(earth_normal, wuv * earth_scale).rg * 2.0 - 1.0, earth);
	col = mix(col, detiled(earth_albedo, wuv * earth_scale) * vec3(0.62, 0.55, 0.46), mud);
	nxy = mix(nxy, texture(earth_normal, wuv * earth_scale).rg * 2.0 - 1.0, mud);
	// Ploughed black earth: dark soil with lighter dry clods and stones, no turf.
	vec2 fh = field_height(wuv);
	vec3 soil_tex = detiled(earth_albedo, wuv * earth_scale);
	// The mud plate is orange clay: pull the hue towards grey-brown for black earth.
	soil_tex = mix(soil_tex, vec3(dot(soil_tex, vec3(0.33))), 0.55);
	vec3 soil = soil_tex * vec3(0.34, 0.29, 0.25);
	soil *= 0.7 + 0.7 * fh.x;
	soil = mix(soil, vec3(0.36, 0.34, 0.31) * (0.8 + 0.4 * micro), fh.y * 0.85);
	col = mix(col, soil, field);
	nxy = mix(nxy, texture(earth_normal, wuv * earth_scale).rg * 2.0 - 1.0, field);
	col = mix(col, detiled(sand_albedo, wuv * sand_scale), sand);
	nxy = mix(nxy, texture(sand_normal, wuv * sand_scale).rg * 2.0 - 1.0, sand);
	// Shore zones read from height (docs/SYSTEMS/CITY_SEA.md): two sands, a dark wet
	// strand, shingle ridges just above the swash, and a seabed of weed, stone and
	// ripple-marked sand, so no beach or sea floor is one flat tone.
	float hy = world_pos.y - sea_level;
	float sand_var = smoothstep(0.35, 0.7, value_noise(wuv * 0.07 + 11.0));
	col = mix(col, col * mix(vec3(1.06, 1.03, 0.96), vec3(0.74, 0.7, 0.62), sand_var), sand * 0.8);
	float wet_strand = (1.0 - smoothstep(0.2, 0.95 + (micro - 0.5) * 0.3, hy)) * sand;
	col = mix(col, col * vec3(0.52, 0.5, 0.48), wet_strand);
	float shingle_band = smoothstep(0.3, 0.7, hy) * (1.0 - smoothstep(1.6, 2.6, hy));
	float shingle = shingle_band * smoothstep(0.42, 0.62, value_noise(wuv * 0.31 + 3.0)) * sand;
	vec3 pebbles = texture(rock_albedo, wuv * 1.6).rgb * vec3(0.85, 0.82, 0.76);
	col = mix(col, pebbles, shingle * 0.9);
	nxy = mix(nxy, texture(rock_normal, wuv * 1.6).rg * 2.0 - 1.0, shingle);
	float under = step(hy, 0.05);
	float depth = max(-hy, 0.0);
	float weed = smoothstep(0.5, 0.7, value_noise(wuv * 0.21 + 7.0)) * smoothstep(0.3, 1.2, depth) * (1.0 - smoothstep(3.0, 5.0, depth));
	col = mix(col, vec3(0.16, 0.24, 0.13), weed * 0.7 * under);
	float seabed_rock = smoothstep(0.62, 0.8, value_noise(wuv * 0.45 + 21.0)) * under;
	col = mix(col, texture(rock_albedo, wuv * 0.9).rgb * vec3(0.55, 0.6, 0.58), seabed_rock * 0.8);
	nxy = mix(nxy, texture(rock_normal, wuv * 0.9).rg * 2.0 - 1.0, seabed_rock);
	float ripples = sin(wuv.x * 2.1 + value_noise(wuv * 0.3) * 6.0) * 0.5 + 0.5;
	col *= 1.0 - under * (1.0 - weed) * (1.0 - seabed_rock) * ripples * 0.09;
	if (paving > 0.001) {
		vec2 world_step = fwidth(wuv);
		FieldStone field = compute_fieldstone(wuv, max(world_step.x, world_step.y) / cobble_cell_size);
		col = mix(col, field.albedo, paving);
		nxy = mix(nxy, field.normal_xy, paving);
	}
	// Cart roads: pale dust when dry, dark clay when wet, a trodden strip down
	// the middle and stones where the wheels have scoured the surface.
	float road = rd.r * (1.0 - paving);
	vec3 road_prof = road_profile(wuv, rd, wet_road);
	if (road > 0.001) {
		vec3 clay = detiled(earth_albedo, wuv * earth_scale);
		vec3 dust_tone = vec3(1.2, 1.08, 0.88);
		vec3 clay_tone = vec3(0.5, 0.44, 0.39);
		vec3 road_col = clay * mix(dust_tone, clay_tone, wet_road);
		// Wheels and boots keep a used road bare: only the quiet margin of a
		// lightly travelled track shows a faint green fuzz of tiny sprouts.
		float quiet = (1.0 - smoothstep(0.15, 0.45, rd.b)) * (1.0 - smoothstep(0.35, 0.85, rd.r));
		float sprouts = quiet * smoothstep(0.5, 0.8, value_noise(wuv * 1.3)) * (1.0 - wet_road * 0.5);
		road_col = mix(road_col, grass * 0.7, clamp(sprouts, 0.0, 0.35));
		float pebbles = step(0.86, value_noise(wuv * 5.3)) * (0.4 + 0.6 * rd.b);
		road_col = mix(road_col, road_col * 1.35 + 0.05, pebbles * 0.5);
		col = mix(col, road_col, road);
		nxy = mix(nxy, texture(earth_normal, wuv * earth_scale).rg * 2.0 - 1.0, road);
	}
	// Grassy banks too steep to hold turf show bare sand and clay before they turn to rock.
	float bank = smoothstep(0.13, 0.3, slope) * (1.0 - paving) * (1.0 - rock);
	// Exposed limestone and sand bluff on the klint faces and steep banks (cliff_height()).
	float rock_ao = 1.0;
	vec2 rock_nxy = vec2(0.0);
	if (rock + bank > 0.003) {
		vec3 rp = world_pos;
		float bed;
		float lime_h = cliff_height(rp, bed);
		float sandy = max(bluff_share(rp, bed, smoothstep(0.2, 0.7, s.b)), bank);
		float h0r = mix(lime_h, bluff_height(rp), sandy);
		// Relief gradient by finite differences, projected on the face tangent plane.
		float de = 0.07;
		vec3 g = vec3(
			rock_surface(rp + vec3(de, 0.0, 0.0), smoothstep(0.2, 0.7, s.b)) - h0r,
			rock_surface(rp + vec3(0.0, de, 0.0), smoothstep(0.2, 0.7, s.b)) - h0r,
			rock_surface(rp + vec3(0.0, 0.0, de), smoothstep(0.2, 0.7, s.b)) - h0r) / de;
		vec3 wt = normalize((INV_VIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
		vec3 wb = normalize((INV_VIEW_MATRIX * vec4(BINORMAL, 0.0)).xyz);
		float rdetail = 1.0 - smoothstep(0.5, 2.5, length(fwidth(rp)));
		rock_nxy = -vec2(dot(g, wt), dot(g, wb)) * 0.26 * rdetail * clamp(rock + bank * 0.7, 0.0, 1.0);
		// Tone: per-bed variation in cream limestone, ochre sand, grey where wet or shaded.
		float bed_tone = hash12(vec2(bed, 1.3));
		vec3 lime_col = mix(vec3(0.70, 0.62, 0.48), vec3(0.84, 0.77, 0.62), bed_tone);
		lime_col = mix(lime_col, vec3(0.62, 0.55, 0.42), step(0.85, hash12(vec2(bed, 5.5))) * 0.7);
		vec3 sand_col = mix(vec3(0.72, 0.60, 0.40), vec3(0.82, 0.71, 0.50), value_noise(rp.xz * 0.4 + rp.y));
		vec3 rock_col = mix(lime_col, sand_col, sandy);
		// Grain so no flat colour survives a close look.
		rock_col *= 0.86 + 0.28 * value_noise(vec2((rp.x * 0.8 + rp.z * 0.6) * 5.0, rp.y * 4.0));
		// Cavity darkening in joints and recessed beds; the crests catch light.
		rock_ao = clamp(0.62 + h0r * 1.3, 0.35, 1.1);
		rock_col *= rock_ao;
		// Rain streaks run down from the ledges, and moss and lichen hold on the damp upper side.
		float streak = value_noise(vec2((rp.x * 0.8 + rp.z * 0.6) * 2.6, rp.y * 0.18));
		rock_col *= 1.0 - 0.22 * smoothstep(0.55, 0.85, streak);
		float moss = smoothstep(0.62, 0.85, value_noise(rp.xz * 0.5 + rp.y * 0.9)) * smoothstep(0.1, 0.5, h0r + 0.25) * (1.0 - sandy);
		rock_col = mix(rock_col, vec3(0.33, 0.38, 0.2), moss * 0.25);
		col = mix(col, rock_col, rock);
	}
	col = mix(col, detiled(sand_albedo, wuv * sand_scale) * vec3(0.9, 0.82, 0.68) * mix(1.0, rock_ao, 0.6), bank * 0.85);

	// Trodden earth and mud are lumpy, with ruts and hoof pocks: a procedural
	// height field adds relief on top of the plate normals. Cart roads add wheel
	// ruts, and the trail map adds every footprint Kalev has left nearby.
	float soft = clamp(earth + mud + field + road, 0.0, 1.0) * (1.0 - paving);
	float give = clamp(soft + (1.0 - soft) * (1.0 - sand) * 0.3 * grass_step(world_normal), 0.0, 1.0) * (1.0 - rock);
	// Far pixels see sub-texel relief as noise: fade it out with distance.
	float detail = 1.0 - smoothstep(0.1, 0.4, length(fwidth(wuv)));
	vec2 e = vec2(0.06, 0.0);
	float h0 = mud_height(wuv);
	vec2 mslope = vec2(mud_height(wuv + e.xy) - h0, mud_height(wuv + e.yx) - h0) / e.x;
	nxy += -mslope * 0.09 * soft * detail;
	// Field relief: clods, warped ridges and stones catch the light.
	float f0 = fh.x;
	vec2 fslope = vec2(field_height(wuv + e.xy).x - f0, field_height(wuv + e.yx).x - f0) / e.x;
	nxy += -fslope * 0.16 * field * detail;
	// Road and footprint relief by finite differences of the same height function.
	float prints_scale = give * (0.45 + 1.3 * wet_road) * detail;
	float tr0 = trail_height(wuv);
	float tr_x = trail_height(wuv + e.xy);
	float tr_z = trail_height(wuv + e.yx);
	vec4 rdx = texture(roads, (wuv + e.xy - splat_rect.xy) / splat_rect.zw);
	vec4 rdz = texture(roads, (wuv + e.yx - splat_rect.xy) / splat_rect.zw);
	float rp_x = road_profile(wuv + e.xy, rdx, wet_road).x;
	float rp_z = road_profile(wuv + e.yx, rdz, wet_road).x;
	float rp_0 = road_prof.x;
	vec2 relief_grad = vec2(
		(rp_x - rp_0) * road + (tr_x - tr0) * prints_scale,
		(rp_z - rp_0) * road + (tr_z - tr0) * prints_scale) / e.x;
	nxy += -relief_grad * detail;
	float pressed = clamp(-tr0 / trail_depth, 0.0, 1.0) * give;
	float rim = clamp(tr0 / trail_depth, 0.0, 1.0) * give;
	float in_rut = road_prof.y * road * detail;
	// Dry ground dusts the rims and packs the floor of a print; wet clay darkens
	// where it was pressed and shines.
	float dryness = 1.0 - wet_road;
	col *= mix(1.0, 0.86 + h0 * 0.28, soft);
	col *= 1.0 - 0.28 * in_rut * (0.5 + wet_road) - 0.42 * pressed * (0.4 + wet_road);
	// Wet mud squeezes up round a print and darkens into slick clay.
	col = mix(col, col * vec3(0.8, 0.74, 0.68), rim * wet_road * 0.6);
	col = mix(col, col * 1.18 + 0.03, rim * dryness * 0.6);
	col = mix(col, col * vec3(1.12, 1.05, 0.93) + 0.025, soft * dryness * 0.35);
	// Puddles gather in flat hollows of earth and mud after rain, and fill the
	// ruts and the deepest prints first.
	float hollow = 1.0 - smoothstep(0.32, 0.5, h0 + value_noise(wuv * 0.23) * 0.45);
	float flat_ground = 1.0 - smoothstep(0.04, 0.12, slope_len(world_normal));
	// Ruts hold water only where they are deepest; elsewhere they stay damp clay.
	float rut_pool = in_rut * smoothstep(0.35, 0.8, value_noise(wuv * 0.21)) * 1.5;
	float pool = max(hollow * soft, max(rut_pool, pressed)) * flat_ground;
	// Water has a level, not a switch: rain raises it through the hollows, so the
	// deepest basins fill first and the pools widen as `puddles` grows. `water_depth` is
	// the water standing over each point (negative = still above the waterline).
	float water_depth = (pool - (1.05 - puddles * 0.75)) * (1.0 - paving);
	// Gradation, driest to wettest: damp earth round the pool, a thin wet film that
	// still shows the bed, then standing water that hides it and mirrors the sky.
	float damp_ring = smoothstep(-0.32, 0.0, water_depth) * step(0.001, puddles);
	float film = smoothstep(0.0, 0.05, water_depth);
	float deep = smoothstep(0.04, 0.28, water_depth);
	// Water seeps into the deepest prints and ruts of soaked ground even where no
	// standing puddle has formed yet: a film only, never deep water.
	float seep = smoothstep(0.55, 0.9, max(pressed, in_rut * 0.7 * smoothstep(0.35, 0.7, value_noise(wuv * 0.4)))) * smoothstep(0.45, 0.9, wet_road) * (1.0 - paving) * flat_ground;
	float puddle = max(film, seep * 0.8);
	float wet = clamp(wetness + mud * 0.35 + shore * 0.5 + puddles * soft * 0.5 + pressed * wet_road * 0.3, 0.0, 1.0);
	col *= mix(1.0, 0.62, wet);
	// Soaked margin: darker, richer earth before any water is visible.
	col = mix(col, col * vec3(0.66, 0.6, 0.55), damp_ring * 0.65);
	// Film keeps the bed visible but dark; deep water is a murky, almost bedless tint.
	vec3 water_col = mix(col * 0.6, vec3(0.115, 0.135, 0.135), deep);
	col = mix(col, water_col, puddle * 0.92);
	// Water is level: the bed relief vanishes under it, and rain pocks the surface
	// with expanding rings. Only standing water (deep) ripples, a film just shines.
	nxy = mix(nxy, vec2(0.0), clamp(puddle * 0.55 + deep * 0.45, 0.0, 1.0));
	vec2 rcell = floor(wuv * 3.0);
	vec2 rloc = fract(wuv * 3.0) - 0.5;
	float rphase = fract(TIME * 0.9 + hash12(rcell));
	float rdist = length(rloc - (vec2(hash12(rcell + 3.1), hash12(rcell + 7.7)) - 0.5) * 0.5);
	float ring = cos((rdist - rphase * 0.7) * 38.0) * exp(-abs(rdist - rphase * 0.7) * 14.0) * (1.0 - rphase);
	float rain_on_water = smoothstep(0.2, 0.7, wetness) * deep * detail;
	nxy += normalize(rloc + vec2(0.0001)) * ring * 0.16 * rain_on_water;
	// Meadow relief: cavity shading and a tussock normal on pure turf only. Fades
	// out with distance like the other micro relief so it cannot shimmer.
	float turf = (1.0 - max(field, max(max(earth, mud), max(sand, max(road, paving))))) * (1.0 - max(rock, bank)) * (1.0 - puddle);
	float gh = grass_height(wuv);
	col *= 1.0 + (gh - 0.5) * grass_relief_shade * turf;
	vec2 gslope = vec2(grass_height(wuv + e.xy) - gh, grass_height(wuv + e.yx) - gh) / e.x;
	nxy += -gslope * grass_relief_normal * turf * detail;
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.95, 0.6, wet * (1.0 - rock * 0.5)), 0.5, damp_ring * 0.5);
	ROUGHNESS = mix(ROUGHNESS, mix(0.16, 0.025, deep), puddle);
	// Dust is the roughest thing there is; slick clay shines in the ruts.
	ROUGHNESS = mix(ROUGHNESS, 0.98, road * dryness * 0.6);
	ROUGHNESS = mix(ROUGHNESS, 0.5, in_rut * wet_road * 0.8);
	ROUGHNESS = mix(ROUGHNESS, 0.3, (pressed + rim * 0.5) * wet_road * 0.7);
	// Turf scatters light diffusely: no glint and no wet-gloss on dry-looking grass.
	ROUGHNESS = mix(ROUGHNESS, 1.0, turf * 0.85);
	SPECULAR = mix(mix(0.3, grass_specular, turf), mix(0.4, 0.6, deep), puddle);
	// Dry limestone and sand are matte: no sky sheen on the klint faces.
	ROUGHNESS = mix(ROUGHNESS, 0.95, max(rock, bank) * (1.0 - puddle) * (1.0 - wet * 0.5));
	SPECULAR = mix(SPECULAR, 0.1, max(rock, bank) * (1.0 - puddle));
	nxy = clamp(nxy * mix(1.0, 0.75, wet) * (1.0 - rock) + rock_nxy, vec2(-0.95), vec2(0.95));
	NORMAL_MAP = vec3(nxy, sqrt(max(1.0 - dot(nxy, nxy), 0.0))) * 0.5 + 0.5;
}
