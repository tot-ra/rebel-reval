shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2DArray terrain_patterns;
uniform sampler2DArray cobble_patterns;
uniform sampler2D cobble_surface : filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D timber_floor_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D hay_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_authored_mud = 0.0;
uniform float use_authored_hay = 0.0;
uniform float pattern_layers = 1.0;
uniform int cobblestone_layer = 12;
uniform int castle_paving_layer = 13;
uniform int timber_floor_layer = 15;
uniform int mud_layer = 8;
uniform int hay_layer = 4;
uniform int straw_layer = 5;
// Inclusive layer band covering trodden ground (farm soil through ash). These
// surfaces receive world-space relief so streets and yards stop reading as a
// single flat colour field between the paved strokes.
uniform int earth_layer_min = 6;
uniform int earth_layer_max = 11;
uniform float mud_wetness = 0.0;
uniform float natural_ground_uv_scale = 2.0;
uniform float natural_ground_variation = 0.72;
uniform float timber_floor_uv_scale = 2.0;
// WS-08 wet sand behind the swash. Only these two beach layers react.
uniform int sand_layer = 9;
uniform int coast_sand_layer = 10;
global uniform float ocean_time;
#include "res://scripts/map/view3d/shore_swash.gdshaderinc"

// CUSTOM0 is only readable in vertex(). Layer indices cannot be interpolated
// directly, so each corner resolves its own finished albedo and material
// weights before the rasterizer blends them across the triangle.
varying vec3 vertex_albedo;
varying float vertex_cobble_weight;
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

// Blend the authored plate at two coherent scales and apply a very low-frequency
// tonal field. The source remains tileable, while the continuous world-space warp
// prevents its 2 m repeat from reading as a checkerboard across the whole meadow.
vec3 sample_natural_ground(int layer, vec2 base_uv) {
	vec2 grass_uv = natural_warp(base_uv * natural_ground_uv_scale);
	// Sample the native grass plate. The shared terrain array is only a 128 px
	// fallback and was the source of the meadow blur.
	vec3 primary = texture(grass_albedo, fract(grass_uv)).rgb;
	vec2 macro_uv = vec2(
		dot(grass_uv, vec2(0.61, 0.19)),
		dot(grass_uv, vec2(-0.17, 0.67))
	) * 0.58 + vec2(0.23, 0.41);
	vec3 macro = texture(grass_albedo, fract(macro_uv)).rgb;
	float patch = natural_noise(base_uv * 0.34 + vec2(4.8, 19.2));
	float fine = natural_noise(base_uv * 1.7 + vec2(31.4, 7.7));
	float variation = clamp(natural_ground_variation, 0.0, 1.0);
	float macro_mix = (0.14 + patch * 0.18) * variation;
	vec3 result = mix(primary, macro, macro_mix);
	result *= 1.0 + (fine - 0.5) * 0.20 * variation;
	return result;
}

vec3 sample_authored_mud(vec2 base_uv) {
	vec2 mud_uv = natural_warp(base_uv * 1.35);
	return texture(mud_albedo, fract(mud_uv)).rgb;
}

vec3 sample_authored_timber_floor(vec2 base_uv) {
	// Boards must stay mostly straight. A light warp hides the 512 px seam
	// without turning the floor into rubber wood.
	vec2 timber_uv = base_uv * timber_floor_uv_scale;
	vec2 warped = natural_warp(timber_uv);
	return texture(timber_floor_albedo, fract(mix(timber_uv, warped, 0.18))).rgb;
}

vec3 sample_authored_hay(vec2 base_uv) {
	vec2 hay_uv = natural_warp(base_uv * 1.6);
	return texture(hay_albedo, fract(hay_uv)).rgb;
}

bool is_hay_field_layer(int layer) {
	return layer == hay_layer || layer == straw_layer;
}

vec3 sample_terrain_pattern(int layer, vec2 uv) {
	if (layer == cobblestone_layer) {
		return vec3(texture(cobble_patterns, vec3(uv, 0.0)).r);
	}
	if (layer == castle_paving_layer) {
		return vec3(texture(cobble_patterns, vec3(uv, 1.0)).r);
	}
	if (layer >= 0 && layer <= 3) {
		return sample_natural_ground(layer, uv);
	}
	if (layer == mud_layer && use_authored_mud > 0.5) {
		return sample_authored_mud(uv);
	}
	if (layer == timber_floor_layer) {
		return sample_authored_timber_floor(uv);
	}
	if (is_hay_field_layer(layer) && use_authored_hay > 0.5) {
		return sample_authored_hay(uv);
	}
	return texture(terrain_patterns, vec3(terrain_pattern_uv(layer, uv), float(layer))).rgb;
}

bool uses_realistic_albedo(int layer) {
	// These layers are backed by authored RGB material plates. All other layers
	// remain grayscale procedural patterns multiplied by their palette tint.
	//
	// The stone layer is deliberately not in this list. Its authored plate is an
	// interior flagstone floor that, left untinted, rendered far brighter than the
	// paving and earth it borders, so every stone apron produced pale wedges along
	// the triangulated terrain boundary. Tinting it by the stone palette entry puts
	// outdoor limestone flags back in the same value range as the street.
	return layer == 0 || layer == 1 || layer == 2 || layer == 3
		|| layer == timber_floor_layer
		|| (layer == mud_layer && use_authored_mud > 0.5)
		|| (is_hay_field_layer(layer) && use_authored_hay > 0.5);
}

vec3 terrain_pattern_albedo(int layer, vec2 uv, vec3 palette_tint) {
	vec3 pattern = sample_terrain_pattern(layer, uv);
	if (uses_realistic_albedo(layer)) {
		return pattern * mix(vec3(1.0), palette_tint, 0.16);
	}
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

vec3 resolve_layer_albedo(int layer, vec2 uv, vec2 world_xz, vec3 palette_tint) {
	if (cobble_layer_weight(layer) > 0.5) {
		return compute_cobble_albedo(uv, world_xz);
	}
	return terrain_pattern_albedo(layer, uv, palette_tint);
}

void vertex() {
	ivec2 layers = ivec2(int(CUSTOM0.x + 0.5), int(CUSTOM0.y + 0.5));
	float raw_blend = clamp(CUSTOM0.z, 0.0, 1.0);
	blend_mix = vec2(raw_blend, CUSTOM0.w);
	terrain_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec3 tint = COLOR.rgb;
	vec3 primary_albedo = resolve_layer_albedo(layers.x, UV, terrain_world_xz, tint);
	vec3 secondary_albedo = resolve_layer_albedo(layers.y, UV, terrain_world_xz, tint);
	vertex_albedo = mix(primary_albedo, secondary_albedo, raw_blend);
	vertex_cobble_weight = mix(cobble_layer_weight(layers.x), cobble_layer_weight(layers.y), raw_blend);
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

	ALBEDO = vertex_albedo * tone;
	float mud_pool = smoothstep(0.38, 0.78, cobble_noise(terrain_world_xz * 0.72 + vec2(9.1, 3.7)));
	float mud_film_weight = wet_mud * mix(0.58, 1.0, mud_pool);
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(0.48, 0.43, 0.36), mud_film_weight * 0.64);

	float earth_h = earth_height(terrain_world_xz);
	ALBEDO *= 1.0 + (earth_h - 0.5) * 0.34 * earth_weight;
	vec2 normal_xy = surface.rg * 2.0 - 1.0;
	vec3 cobble_normal = vec3(normal_xy, sqrt(max(1.0 - dot(normal_xy, normal_xy), 0.0)));
	float eps = 0.10;
	vec2 earth_slope = vec2(
		earth_height(terrain_world_xz + vec2(eps, 0.0)) - earth_height(terrain_world_xz - vec2(eps, 0.0)),
		earth_height(terrain_world_xz + vec2(0.0, eps)) - earth_height(terrain_world_xz - vec2(0.0, eps))
	) * 2.6;
	vec3 earth_normal = normalize(vec3(-earth_slope.x, 1.0, -earth_slope.y)).xzy;
	NORMAL_MAP = mix(earth_normal * 0.5 + 0.5, cobble_normal * 0.5 + 0.5, cobble_weight);
	NORMAL_MAP_DEPTH = mix(0.85 * earth_weight, 0.55, cobble_weight);
	ROUGHNESS = mix(0.96, mix(0.99, 0.93, stone), cobble_weight);
	ROUGHNESS = mix(ROUGHNESS, mix(0.42, 0.20, mud_pool), mud_film_weight);
	SPECULAR = mix(0.12, 0.30, mud_film_weight);

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
