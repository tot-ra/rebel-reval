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

#include "res://scripts/city/city_grass_ground.gdshaderinc"

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 suv = (world_pos.xz - splat_rect.xy) / splat_rect.zw;
	vec4 s = texture(splat, suv);
	float macro = value_noise(world_pos.xz * 0.035);
	float micro = value_noise(world_pos.xz * 0.6);

	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float rock = smoothstep(0.32, 0.5, slope + (macro - 0.5) * 0.12);
	float paving = smoothstep(0.25, 0.7, s.r + (micro - 0.5) * 0.25);
	float earth = smoothstep(0.15, 0.65, s.g + (micro - 0.5) * 0.3);
	float sand = smoothstep(0.2, 0.7, s.b + (macro - 0.5) * 0.3);
	float mud = smoothstep(0.2, 0.7, s.a + (micro - 0.5) * 0.3);
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
	// Exposed limestone on the klint faces and steep banks, triplanar so cliffs do not stretch.
	vec3 an = abs(world_normal);
	vec3 rx = texture(rock_albedo, world_pos.zy * rock_scale).rgb;
	vec3 rz = texture(rock_albedo, world_pos.xy * rock_scale).rgb;
	vec3 ry = texture(rock_albedo, world_pos.xz * rock_scale).rgb;
	vec3 rock_col = (rx * an.x + ry * an.y + rz * an.z) / (an.x + an.y + an.z) * vec3(0.95, 0.93, 0.86);
	col = mix(col, rock_col, rock);
	// Grassy banks too steep to hold turf show bare sand and clay before they turn to rock.
	float bank = smoothstep(0.13, 0.3, slope) * (1.0 - paving) * (1.0 - rock);
	col = mix(col, detiled(sand_albedo, wuv * sand_scale) * vec3(0.9, 0.82, 0.68), bank * 0.85);

	// Trodden earth and mud are lumpy, with ruts and hoof pocks: a procedural
	// height field adds relief on top of the plate normals. Cart roads add wheel
	// ruts, and the trail map adds every footprint Kalev has left nearby.
	float soft = clamp(earth + mud + road, 0.0, 1.0) * (1.0 - paving);
	float give = clamp(soft + (1.0 - soft) * (1.0 - sand) * 0.3 * grass_step(world_normal), 0.0, 1.0) * (1.0 - rock);
	// Far pixels see sub-texel relief as noise: fade it out with distance.
	float detail = 1.0 - smoothstep(0.1, 0.4, length(fwidth(wuv)));
	vec2 e = vec2(0.06, 0.0);
	float h0 = mud_height(wuv);
	vec2 mslope = vec2(mud_height(wuv + e.xy) - h0, mud_height(wuv + e.yx) - h0) / e.x;
	nxy += -mslope * 0.09 * soft * detail;
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
	float puddle = smoothstep(0.35, 0.6, pool) * puddles * (1.0 - paving);
	// Water seeps into the deepest prints and ruts of soaked ground even where no
	// standing puddle has formed yet.
	float seep = smoothstep(0.55, 0.9, max(pressed, in_rut * 0.7 * smoothstep(0.35, 0.7, value_noise(wuv * 0.4)))) * smoothstep(0.45, 0.9, wet_road) * (1.0 - paving) * flat_ground;
	puddle = max(puddle, seep * 0.8);
	float wet = clamp(wetness + mud * 0.35 + shore * 0.5 + puddles * soft * 0.5 + pressed * wet_road * 0.3, 0.0, 1.0);
	col = mix(col * mix(1.0, 0.62, wet), vec3(0.08, 0.09, 0.09), puddle * 0.85);
	nxy = mix(nxy, vec2(0.0), puddle);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.95, 0.6, wet * (1.0 - rock * 0.5)), 0.12, puddle);
	// Dust is the roughest thing there is; slick clay shines in the ruts.
	ROUGHNESS = mix(ROUGHNESS, 0.98, road * dryness * 0.6);
	ROUGHNESS = mix(ROUGHNESS, 0.5, in_rut * wet_road * 0.8);
	ROUGHNESS = mix(ROUGHNESS, 0.3, (pressed + rim * 0.5) * wet_road * 0.7);
	SPECULAR = mix(0.3, 0.55, puddle);
	nxy = clamp(nxy * mix(1.0, 0.75, wet) * (1.0 - rock), vec2(-0.95), vec2(0.95));
	NORMAL_MAP = vec3(nxy, sqrt(max(1.0 - dot(nxy, nxy), 0.0))) * 0.5 + 0.5;
}
