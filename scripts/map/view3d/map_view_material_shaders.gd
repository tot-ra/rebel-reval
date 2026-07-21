class_name MapViewMaterialShaders
extends RefCounted

## Inline shader sources for animated MapViewMaterials surfaces.


const WATER_SHADER_CODE := "
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Water stays opaque to sorting, but reads the already-rendered bank and bed to
// simulate transmission. Depth reconstruction makes absorption and distortion
// respond to actual geometry instead of painting another animated blue texture.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 shallow_color : source_color = vec3(0.45, 0.62, 0.75);
uniform vec3 deep_color : source_color = vec3(0.16, 0.30, 0.44);
uniform vec3 highlight_color : source_color = vec3(0.396, 0.694, 0.769);
uniform vec3 foam_color : source_color = vec3(0.72, 0.80, 0.78);
uniform float wave_height = 0.032;
uniform float wave_chaos = 1.0;
uniform float wave_speed = 1.0;
uniform float depth_absorption = 7.0;
uniform float refraction_strength = 0.012;
uniform float foam_intensity = 0.22;
uniform float breaker_intensity = 0.35;
// Matches sky sun-disk fade / MapView3D day_blend. Defaults keep daytime look
// until apply_water_lighting() pushes the live cycle values.
uniform float sun_visibility = 1.0;
uniform float sun_reflection_visibility = 1.0;
uniform float day_blend = 1.0;
// The water samples the same catalog texture and celestial directions as the
// sky dome. This is cheaper than a planar reflection and stays deterministic.
uniform sampler2D star_map : filter_nearest, repeat_enable;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_reflection_color : source_color = vec3(1.0, 0.92, 0.74);
uniform float moon_visibility = 0.0;
uniform float star_visibility = 0.0;
uniform float observer_latitude = 1.0371;
uniform float sidereal_angle = 3.8101;

varying vec3 water_world_position;
varying float shore_factor;

float _hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float _noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(_hash(i), _hash(i + vec2(1.0, 0.0)), u.x),
		mix(_hash(i + vec2(0.0, 1.0)), _hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// Returns height plus its X/Z derivatives. Position-dependent phase warping
// bends otherwise regular wave trains, while the local amplitude field breaks
// up long repeating crests without introducing a visibly scrolling noise tile.
vec3 _wave(
	vec2 position,
	vec2 direction,
	float frequency,
	float speed,
	float amplitude,
	float time,
	vec2 warp,
	float phase_offset
) {
	vec2 heading = normalize(direction);
	float phase = dot(position + warp, heading) * frequency - time * speed + phase_offset;
	float slope = cos(phase) * frequency * amplitude;
	return vec3(sin(phase) * amplitude, heading.x * slope, heading.y * slope);
}

vec3 _water_shape(vec2 position, float time) {
	// Two unrelated, slowly drifting noise fields domain-warp all wave scales.
	// Their non-integer scales and offsets avoid a shared repeat interval across
	// the large uninterrupted water regions visible from the isometric camera.
	vec2 drift = vec2(time * 0.035, -time * 0.021);
	vec2 warp_position = position * 0.115 + drift;
	vec2 warp = vec2(
		_noise(warp_position + vec2(17.2, -8.4)),
		_noise(warp_position * 0.83 + vec2(-11.7, 23.9))
	) - vec2(0.5);
	vec2 fine_warp = vec2(
		_noise(position * 0.31 + vec2(-time * 0.052, time * 0.018) + vec2(43.1, 7.6)),
		_noise(position * 0.27 + vec2(time * 0.024, time * 0.047) + vec2(-19.4, 31.8))
	) - vec2(0.5);
	warp = (warp * 2.8 + fine_warp * 0.65) * wave_chaos;

	float amplitude_noise = _noise(position * 0.16 + drift * 1.7 + vec2(5.3, 41.2));
	float amplitude_variation = mix(0.72, 1.22, amplitude_noise);
	vec3 shape = _wave(position, vec2(1.0, 0.28), 0.97, 0.68, 0.46, time, warp, 0.3);
	shape += _wave(position, vec2(0.36, 1.0), 2.11, 1.03, 0.23, time, warp * 0.72, 2.1);
	shape += _wave(position, vec2(-0.72, 1.0), 4.37, 1.67, 0.09, time, fine_warp * wave_chaos, 4.7);
	shape += _wave(position, vec2(1.0, -0.62), 7.79, 2.31, 0.028, time, warp * 0.24, 1.4);
	shape *= amplitude_variation;
	return shape;
}

float _view_depth(vec2 screen_uv, float raw_depth, mat4 inverse_projection) {
	// GL Compatibility uses OpenGL NDC, whose Z range is -1..1.
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth * 2.0 - 1.0);
	vec4 view_position = inverse_projection * vec4(ndc, 1.0);
	return -view_position.z / view_position.w;
}

// Kept identical to the sky shader projection so constellations reflected in
// the water occupy the same astronomical positions as the visible sky dome.
vec2 _equatorial_uv(vec3 direction) {
	float north = -direction.z;
	float east = direction.x;
	float up = direction.y;
	float sin_lat = sin(observer_latitude);
	float cos_lat = cos(observer_latitude);
	float sin_dec = clamp(up * sin_lat + north * cos_lat, -1.0, 1.0);
	float declination = asin(sin_dec);
	float hour_angle = atan(-east, up * cos_lat - north * sin_lat);
	float right_ascension = sidereal_angle - hour_angle;
	return vec2(fract(right_ascension / TAU), 0.5 - declination / PI);
}

void vertex() {
	water_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	shore_factor = clamp(COLOR.r, 0.0, 1.0);
	vec3 shape = _water_shape(water_world_position.xz, TIME * wave_speed);
	// Keep clipped patch seams pinned, but let the crest rise almost all the way
	// into the shallows. The old broad fade erased waves before they reached land.
	float displacement_fade = smoothstep(0.0, 0.16, shore_factor);
	float shoaling = mix(1.32, 1.0, smoothstep(0.0, 0.65, shore_factor));
	float displacement = shape.x * wave_height * displacement_fade * shoaling;
	VERTEX.y += displacement;
	water_world_position.y += displacement;
}

void fragment() {
	vec3 shape = _water_shape(water_world_position.xz, TIME * wave_speed);
	vec3 world_normal = normalize(vec3(-shape.y * wave_height, 1.0, -shape.z * wave_height));
	vec3 view_normal = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	NORMAL = view_normal;

	float surface_depth = max(-VERTEX.z, 0.0001);
	float raw_scene_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	float scene_depth = _view_depth(SCREEN_UV, raw_scene_depth, INV_PROJECTION_MATRIX);
	float water_depth = max(scene_depth - surface_depth, 0.0);

	// Distort only samples that remain behind the surface. This suppresses the
	// familiar refraction halo that otherwise pulls dry bank pixels into water.
	float depth_fade = smoothstep(0.0, 0.11, water_depth);
	vec2 refracted_uv = clamp(
		SCREEN_UV + view_normal.xy * refraction_strength * depth_fade,
		vec2(0.001),
		vec2(0.999)
	);
	float refracted_depth = _view_depth(
		refracted_uv,
		textureLod(depth_texture, refracted_uv, 0.0).r,
		INV_PROJECTION_MATRIX
	);
	if (refracted_depth <= surface_depth + 0.002) {
		refracted_uv = SCREEN_UV;
	}
	vec3 floor_color = textureLod(screen_texture, refracted_uv, 0.0).rgb;

	// Beer-Lambert-style attenuation: nearby bed remains visible while deeper
	// rays lose warm light and converge on the terrain family's deep-water tint.
	float absorption = 1.0 - exp(-water_depth * depth_absorption);
	vec3 transmitted = floor_color * mix(vec3(0.94, 0.99, 1.02), shallow_color, 0.22);
	vec3 water_color = mix(transmitted, deep_color, clamp(absorption * 0.88, 0.0, 0.92));
	water_color = mix(water_color, shallow_color, 0.10 + absorption * 0.10);

	// Schlick Fresnel plus the PBR specular lobe produces stable sky reflection
	// and narrow sun glints at the shallow isometric viewing angle.
	float facing = clamp(dot(view_normal, normalize(VIEW)), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
	vec3 day_sky = mix(highlight_color, vec3(0.72, 0.82, 0.88), 0.32);
	vec3 night_sky = vec3(0.05, 0.07, 0.12);
	vec3 sky_reflection = mix(night_sky, day_sky, day_blend);
	water_color = mix(water_color, sky_reflection, fresnel * mix(0.35, 0.68, day_blend));

	// WHY: DayNightCycle packs a solar day into 60s. Reflecting the catalog and
	// sun/moon through fully animated wave normals turns that race into frantic
	// pre-dawn sparkles on open sea. Celestial samples use a calmer normal so
	// waves still displace while glints stay readable instead of strobing.
	vec3 world_view = normalize((INV_VIEW_MATRIX * vec4(normalize(VIEW), 0.0)).xyz);
	vec3 calm_normal = normalize(mix(vec3(0.0, 1.0, 0.0), world_normal, 0.38));
	vec3 reflected_sky_ray = normalize(reflect(-world_view, calm_normal));
	float reflected_above_horizon = smoothstep(-0.01, 0.06, reflected_sky_ray.y);
	vec3 reflected_stars = texture(star_map, _equatorial_uv(reflected_sky_ray)).rgb;
	// Drop star glitter as soon as the sun disk begins to rise so dawn does not
	// stack racing constellations on top of the emerging sun path.
	float night_sparkle = star_visibility * (1.0 - sun_reflection_visibility);
	water_color += reflected_stars * night_sparkle * reflected_above_horizon * fresnel * 0.16;

	// Explicit celestial glints remain visible in GL Compatibility, where the
	// environment prefilter alone does not reliably preserve tiny sky disks.
	float sun_alignment = max(dot(reflected_sky_ray, normalize(sun_direction)), 0.0);
	// Low sun elongates the glitter path; keep a warm dawn cue without a racing
	// sparkle highway while the disk skims the horizon on a compressed day cycle.
	float low_sun_glitter = smoothstep(-0.02, 0.22, sun_direction.y);
	float sun_glint = pow(sun_alignment, 220.0) * sun_reflection_visibility * mix(0.2, 1.0, low_sun_glitter);
	float moon_alignment = max(dot(reflected_sky_ray, normalize(moon_direction)), 0.0);
	float moon_glint = pow(moon_alignment, 320.0) * moon_visibility;
	water_color += sun_reflection_color * sun_glint * (0.45 + fresnel * 1.2);
	water_color += vec3(0.66, 0.72, 0.86) * moon_glint * (0.25 + fresnel * 0.75);

	// COLOR.r is baked from the same smooth contour that clips the mesh. A pair
	// of advancing breaker bands now travels into that contour, crests, and fades
	// at the bank. This reads as surf arriving at shore rather than static edge foam.
	float shore = 1.0 - smoothstep(0.0, 0.88, shore_factor);
	float breaker_phase = shore_factor * 18.0 + TIME * (1.45 * wave_speed);
	float breaker_warp = (_noise(water_world_position.xz * 0.42 + vec2(TIME * 0.08, -TIME * 0.04)) - 0.5) * 3.4;
	float breaker_a = pow(max(sin(breaker_phase + breaker_warp), 0.0), 5.0);
	float breaker_b = pow(max(sin(breaker_phase * 0.62 + breaker_warp * 0.7 + 2.4), 0.0), 7.0);
	float breaker_band = (breaker_a + breaker_b * 0.55) * smoothstep(0.04, 0.92, shore);
	vec2 foam_uv = water_world_position.xz * 3.4 + vec2(-TIME * 0.22, TIME * 0.09) * wave_speed;
	float foam_noise = _noise(foam_uv + _noise(foam_uv * 0.47) * 2.2);
	float foam_ribbon = 0.5 + 0.5 * sin(
		dot(water_world_position.xz, vec2(5.4, 3.8)) - TIME * 0.85 * wave_speed + foam_noise * 3.0
	);
	float edge_foam = shore * smoothstep(0.52, 0.88, foam_noise * 0.70 + foam_ribbon * 0.30);
	float foam = edge_foam * foam_intensity + breaker_band * breaker_intensity;
	foam *= smoothstep(0.012, 0.08, water_depth);
	water_color = mix(water_color, foam_color, clamp(foam, 0.0, 0.72));

	ALBEDO = water_color;
	float day_roughness = mix(0.09, 0.22, clamp(foam + absorption * 0.18, 0.0, 1.0));
	// WHY: DirectionalLight still tracks the sun a few degrees past the visual
	// disk fade (civil twilight). Without gating specular on sun_visibility the
	// PBR lobe keeps painting a false sun reflection onto sea after sunset.
	ROUGHNESS = mix(mix(0.32, 0.42, clamp(foam, 0.0, 1.0)), day_roughness, sun_visibility);
	// Godot maps SPECULAR to dielectric F0; 0.25 is approximately water's 0.02.
	SPECULAR = mix(0.05, 0.25, sun_visibility);
}
"

## Grass blades: instance color carries the tint, UV.y runs root(0) to tip(1).
## World wind (direction + strength from SkyWeather) leans tips downwind; a
## lighter cross-flutter keeps the field alive even in a steady breeze.
const GRASS_SHADER_CODE := "
shader_type spatial;
// depth_draw_opaque keeps stacked blade layers sorted; cull_disabled shows both
// faces. Wind stays in vertex(), but grass must not cast shadows: animated
// vertices make shadow maps jitter on thin geometry.
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.38, 0.48, 0.24);
uniform float sway_strength = 0.10;
uniform vec2 wind_direction = vec2(0.9285, 0.3714);
uniform float wind_strength = 0.22;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 1.9 + world.z * 1.4;
	float power = mix(0.35, 1.4, clamp(wind_strength, 0.0, 1.0));
	float gust = sin(TIME * (0.75 + wind_strength * 0.55) + phase * 0.23);
	float flutter = sin(TIME * 2.0 + phase) * (0.55 + 0.45 * gust)
		+ 0.4 * sin(TIME * 3.4 + phase * 1.7);
	float weight = UV.y * UV.y;
	vec2 wind = normalize(wind_direction);
	vec2 across = vec2(-wind.y, wind.x);
	vec2 displace = wind * (power * (0.65 + 0.35 * gust) + flutter * 0.4)
		+ across * flutter * 0.45;
	VERTEX.x += displace.x * sway_strength * weight;
	VERTEX.z += displace.y * sway_strength * weight;
}

void fragment() {
	// Double-sided blades otherwise flip normals and shadowed lighting flickers.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = base_color * COLOR.rgb * mix(0.5, 1.1, UV.y);
	ROUGHNESS = 0.95;
}
"

## Tree canopies: same world-wind field as grass, far gentler, weighted by height
## above the canopy base so trunks stay planted.
const CANOPY_SHADER_CODE := "
shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_color : source_color = vec3(0.30, 0.42, 0.26);
uniform float sway_strength = 0.05;
uniform float shade_bottom = 0.62;
uniform vec2 wind_direction = vec2(0.9285, 0.3714);
uniform float wind_strength = 0.22;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.9 + world.z * 0.7;
	float power = mix(0.4, 1.25, clamp(wind_strength, 0.0, 1.0));
	float weight = clamp(VERTEX.y * 0.4 + 0.4, 0.0, 1.0);
	float gust = sin(TIME * (1.05 + wind_strength * 0.4) + phase);
	float flutter = cos(TIME * 1.35 + phase * 1.3) * 0.55;
	vec2 wind = normalize(wind_direction);
	vec2 across = vec2(-wind.y, wind.x);
	vec2 displace = wind * (power * (0.7 + 0.3 * gust) + flutter * 0.35)
		+ across * flutter * 0.5;
	VERTEX.x += displace.x * sway_strength * weight;
	VERTEX.z += displace.y * sway_strength * weight;
}

void fragment() {
	// Primitive-mesh UVs run v = 0 at the top, so invert for canopy shading.
	float shade = mix(1.05, shade_bottom, clamp(UV.y, 0.0, 1.0));
	ALBEDO = base_color * COLOR.rgb * shade;
	ROUGHNESS = 0.95;
}
"

## Soft cloth for square sails and tower pennants. free_edge selects which UV
## axis is free (sail hangs from the yard via UV.y; flags fly from the hoist via
## UV.x). COLOR keeps sail panel striping without a dedicated texture.
const CLOTH_SHADER_CODE := "
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.86, 0.84, 0.76);
uniform float sway_strength = 0.22;
uniform vec2 wind_direction = vec2(0.9285, 0.3714);
uniform float wind_strength = 0.22;
uniform vec2 free_edge = vec2(0.0, 1.0);

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 1.1 + world.z * 0.85;
	float power = mix(0.3, 1.55, clamp(wind_strength, 0.0, 1.0));
	float free_t = clamp(UV.x * free_edge.x + UV.y * free_edge.y, 0.0, 1.0);
	float weight = free_t * free_t;
	float gust = sin(TIME * (1.1 + wind_strength * 0.7) + phase);
	float ripple = sin(TIME * 3.2 + phase * 2.1 + UV.x * 6.0) * 0.55
		+ sin(TIME * 5.1 + phase * 1.4 + UV.y * 4.5) * 0.3;
	vec2 wind = normalize(wind_direction);
	vec2 across = vec2(-wind.y, wind.x);
	vec2 displace = wind * (power * (0.75 + 0.25 * gust) + ripple * 0.35)
		+ across * ripple * 0.65;
	// Convert world XZ sway into model space so rotated boats and poles still
	// billow downwind instead of shearing along local axes.
	vec3 world_delta = vec3(displace.x, ripple * 0.12 * power, displace.y)
		* sway_strength * weight;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(world_delta, 0.0)).xyz;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = base_color * COLOR.rgb;
	ROUGHNESS = 0.92;
}
"

static var _cache: Dictionary = {}


## Ground splat: two terrain pattern layers blended per vertex. CUSTOM0 carries
## pattern indices (x, y), blend weight (z), and brightness tone (w). COLOR.rgb
## is the palette tint lerp between the two terrain families.
const TERRAIN_BLEND_SHADER_CODE := "
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2DArray terrain_patterns;
uniform sampler2DArray cobble_patterns;
uniform float pattern_layers = 1.0;
uniform int cobblestone_layer = 12;
uniform int castle_paving_layer = 13;

// CUSTOM0 is only readable in vertex(); layer indices must stay flat (an
// interpolated index would sample arbitrary in-between layers mid-triangle)
// while weight and tone interpolate for soft terrain borders.
varying flat ivec2 blend_layers;
varying vec2 blend_mix;

void vertex() {
	blend_layers = ivec2(int(CUSTOM0.x + 0.5), int(CUSTOM0.y + 0.5));
	blend_mix = CUSTOM0.zw;
}

float sample_terrain_pattern(int layer, vec2 uv) {
	if (layer == cobblestone_layer) {
		return texture(cobble_patterns, vec3(uv, 0.0)).r;
	}
	if (layer == castle_paving_layer) {
		return texture(cobble_patterns, vec3(uv, 1.0)).r;
	}
	return texture(terrain_patterns, vec3(uv, float(layer))).r;
}

void fragment() {
	float blend = clamp(blend_mix.x, 0.0, 1.0);
	float tone = blend_mix.y;

	float primary = sample_terrain_pattern(blend_layers.x, UV);
	float secondary = sample_terrain_pattern(blend_layers.y, UV);
	float pattern = mix(primary, secondary, blend);
	ALBEDO = vec3(pattern) * COLOR.rgb * tone;
	ROUGHNESS = mix(0.94, 0.82, blend * step(0.5, float(blend_layers.y)));
}
"

## Shallow wet patches on worked ground after rain. depth_prepass_alpha keeps
## soft edges without the speckled dither alpha_hash shows on flat decals.
const PUDDLE_SHADER_CODE := "
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, depth_draw_opaque, depth_prepass_alpha, blend_mix;

uniform vec3 wet_tint : source_color = vec3(0.72, 0.78, 0.82);
uniform vec3 sheen_tint : source_color = vec3(0.88, 0.92, 0.94);

float _hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float _noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(_hash(i), _hash(i + vec2(1.0, 0.0)), u.x),
		mix(_hash(i + vec2(0.0, 1.0)), _hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float _fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	value += amplitude * _noise(p);
	p = p * 2.03 + vec2(1.7);
	amplitude *= 0.5;
	value += amplitude * _noise(p);
	p = p * 2.03 + vec2(-2.3);
	amplitude *= 0.5;
	value += amplitude * _noise(p);
	return value;
}

varying vec2 world_xz;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = world.xz * 0.55;
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float blob_warp = _fbm(world_xz * 1.6 + vec2(0.41, 0.67));
	vec2 warped = centered * (1.0 + vec2(blob_warp - 0.5) * 0.55);
	float radial = length(warped);
	float edge_wobble = _fbm(world_xz * 3.4 + vec2(0.19, 0.83)) * 0.22;
	float organic = _fbm(world_xz * 2.2 + vec2(0.73, 0.11));
	float mask = smoothstep(1.02 + edge_wobble, 0.34, radial);
	mask *= smoothstep(0.28, 0.62, organic + 0.18);
	float rim = smoothstep(0.58, 0.94, radial);

	vec2 ripple_uv = world_xz * 2.4 + vec2(TIME * 0.018, -TIME * 0.013);
	float ripples = _fbm(ripple_uv) * 0.7 + _fbm(ripple_uv * 1.8 + vec2(TIME * 0.03)) * 0.3;

	vec3 ground = COLOR.rgb;
	vec3 wet = ground * wet_tint;
	vec3 sheen = mix(wet, ground * sheen_tint, ripples * 0.08 + rim * 0.05);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.6);
	sheen = mix(sheen, ground * sheen_tint, fresnel * 0.10);
	sheen = mix(sheen, ground * 0.82, smoothstep(0.0, 0.42, radial) * 0.35);

	ALBEDO = sheen;
	ALPHA = mask * 0.62;
	ROUGHNESS = mix(0.42, 0.62, ripples);
	SPECULAR = mix(0.08, 0.16, fresnel);
}
"

static func reset() -> void:
	_cache.clear()


static func shader(name: String, code: String) -> Shader:
	var key := "shader:%s" % name
	if _cache.has(key):
		return _cache[key]
	var shader := Shader.new()
	shader.code = code
	_cache[key] = shader
	return shader
