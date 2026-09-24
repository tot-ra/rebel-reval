class_name MapViewMaterialShaders
extends RefCounted

## Inline shader sources for animated MapViewMaterials surfaces.
## Small or stable shaders may live in sibling `*.gdshader` resources; the cache
## API keeps one shared Shader instance per logical name.


const WEAR_DECAL_SHADER := preload("res://scripts/map/view3d/map_view_wear_decal.gdshader")
const CLOTH_SHADER := preload("res://scripts/map/view3d/map_view_cloth.gdshader")
const PUDDLE_SHADER := preload("res://scripts/map/view3d/map_view_puddle.gdshader")
const HANGING_BANNER_CLOTH_SHADER := preload(
	"res://scripts/map/view3d/map_view_hanging_banner_cloth.gdshader"
)
const FISHING_NET_WIND_SHADER := preload(
	"res://scripts/map/view3d/map_view_fishing_net_wind.gdshader"
)
const GRASS_SHADER := preload("res://scripts/map/view3d/map_view_grass.gdshader")
const CANOPY_SHADER := preload("res://scripts/map/view3d/map_view_canopy.gdshader")

# gdlint: disable=max-line-length
const WATER_SHADER_CODE := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Water stays opaque to sorting, but reads the already-rendered bank and bed to
// simulate transmission. Depth reconstruction makes absorption and distortion
// respond to actual geometry instead of painting another animated blue texture.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 shallow_color : source_color = vec3(0.45, 0.62, 0.75);
uniform vec3 deep_color : source_color = vec3(0.16, 0.30, 0.44);
// The rendered terrain remains the physical bed. These tints layer sediment,
// stones and vegetation over it in stable world space instead of requiring a
// second authored mesh for every underwater material transition.
uniform vec3 sand_bed_color : source_color = vec3(0.62, 0.51, 0.30);
uniform vec3 stone_bed_color : source_color = vec3(0.32, 0.36, 0.35);
uniform vec3 algae_bed_color : source_color = vec3(0.14, 0.28, 0.20);
uniform float bed_vegetation = 1.0;
uniform vec3 deep_bed_color : source_color = vec3(0.035, 0.08, 0.11);
uniform float optical_depth = 0.075;
uniform float caustic_strength = 0.14;
uniform vec3 highlight_color : source_color = vec3(0.396, 0.694, 0.769);
uniform vec3 foam_color : source_color = vec3(0.72, 0.80, 0.78);
uniform float wave_height = 0.032;
uniform float wave_chaos = 1.0;
uniform float wave_speed = 1.0;
uniform float depth_absorption = 7.0;
uniform float refraction_strength = 0.012;
uniform float foam_intensity = 0.22;
uniform float breaker_intensity = 0.35;
// Water2-style dual normal detail without texture memory: two independent
// procedural layers are phase-blended and advected by the optional river flow.
uniform float detail_normal_strength = 0.30;
uniform float detail_normal_scale = 1.0;
// River current: world-XZ flow direction and strength. Zero for still water, so
// sea and pond surfaces are unaffected. Non-zero advects the wave field
// downstream and spawns drifting foam ribbons so a river reads as moving water.
uniform vec2 flow_direction = vec2(0.0, 0.0);
uniform float flow_strength = 0.0;
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
// Coastal terrain receives the live equilibrium tide. River water keeps zero
// response, while shallow/deep sea tune shoreline retreat and optical depth.
uniform float tide_level = 0.0;
uniform float tide_height = 0.0;
uniform float tide_shore_retreat = 0.0;
uniform float tide_optical_depth = 0.0;

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

// A finite-difference slope is a small procedural stand-in for a sampled normal
// map. Keeping the samples in world space makes detail continuous across the
// separate water meshes generated for each terrain cell.
vec2 _detail_gradient(vec2 position) {
	float sample_step = 0.07;
	return vec2(
		_noise(position + vec2(sample_step, 0.0)) - _noise(position - vec2(sample_step, 0.0)),
		_noise(position + vec2(0.0, sample_step)) - _noise(position - vec2(0.0, sample_step))
	) / (sample_step * 2.0);
}

// Water2-style dual scrolling detail: each layer has its own frequency, phase
// and scroll vector, while river current advects both layers downstream. This
// affects shading only; the physical displacement remains _water_shape() so
// boats and visuals continue to share the existing wave field.
vec3 _water_detail_normal(vec2 position, float time) {
	float scale = max(detail_normal_scale, 0.1);
	vec2 current_offset = flow_direction * (flow_strength * time * 0.42);
	vec2 layer_a = position * scale * 1.7 - current_offset;
	layer_a += vec2(-time * 0.19, time * 0.13) + vec2(12.4, -4.7);
	vec2 layer_b = position * scale * 3.9 - current_offset * 1.65;
	layer_b += vec2(time * 0.27, -time * 0.23) + vec2(-21.8, 16.1);
	vec2 slope = _detail_gradient(layer_a) * 0.58 + _detail_gradient(layer_b) * 0.42;
	return normalize(vec3(-slope.x * 0.18, 1.0, -slope.y * 0.18));
}

// Deterministic world-space masks keep the bed continuous across authored water
// terrain borders. The weights always sum to one, so depth changes material
// dominance instead of stacking four opaque color filters.
vec4 _seabed_layers(vec2 position, float water_depth) {
	float broad = _noise(position * 0.12 + vec2(31.7, -14.2));
	float broken = _noise(position * 0.46 + vec2(-9.3, 27.1));
	float detail = _noise(position * 1.85 + vec2(4.6, 18.8));
	float deep_weight = smoothstep(0.20, 0.34, water_depth);
	float shallow_weight = 1.0 - deep_weight;
	float stone_weight = smoothstep(0.56, 0.78, broken * 0.72 + detail * 0.28) * shallow_weight;
	float algae_depth = smoothstep(0.06, 0.16, water_depth) * (1.0 - smoothstep(0.30, 0.46, water_depth));
	// Sparse algae can tint an authentic shallow bed, but it must never read as
	// the terrestrial grass layer continuing below a pond or harbour surface.
	float algae_weight = smoothstep(0.48, 0.72, broad * 0.68 + broken * 0.32) * algae_depth * bed_vegetation * 0.22;
	float sand_weight = max(shallow_weight - stone_weight - algae_weight, 0.08 * shallow_weight);
	float shallow_total = max(sand_weight + stone_weight + algae_weight, 0.0001);
	vec3 shallow_layers = vec3(sand_weight, stone_weight, algae_weight) / shallow_total;
	return vec4(shallow_layers * shallow_weight, deep_weight);
}

float _bed_caustics(vec2 position, float time) {
	vec2 flow = position * 2.35 + vec2(time * 0.10, -time * 0.065);
	float crossing = sin(flow.x + sin(flow.y * 1.37)) + cos(flow.y + sin(flow.x * 1.19));
	return pow(clamp(1.0 - abs(crossing) * 0.56, 0.0, 1.0), 5.0);
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
	// Advect the wave field downstream so ripples travel along the current.
	vec2 flow_advection = flow_direction * (flow_strength * TIME * wave_speed * 0.6);
	vec3 shape = _water_shape(water_world_position.xz - flow_advection, TIME * wave_speed);
	// Low tide withdraws the clipped coastal edge instead of requiring a second
	// authored shoreline mesh. High tide reaches the original maximum contour.
	// The fragment stage clips the retreat band; vertices only change elevation.
	// Keep clipped patch seams pinned, but let the crest rise almost all the way
	// into the shallows. The old broad fade erased waves before they reached land.
	float displacement_fade = smoothstep(0.0, 0.16, shore_factor);
	float shoaling = mix(1.32, 1.0, smoothstep(0.0, 0.65, shore_factor));
	float displacement = shape.x * wave_height * displacement_fade * shoaling;
	VERTEX.y += tide_height * tide_level + displacement;
	water_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float tide_coverage = tide_shore_retreat * max(-tide_level, 0.0);
	if (shore_factor < tide_coverage) {
		discard;
	}
	// Advect the wave field downstream so ripples travel along the current.
	vec2 flow_advection = flow_direction * (flow_strength * TIME * wave_speed * 0.6);
	vec3 shape = _water_shape(water_world_position.xz - flow_advection, TIME * wave_speed);
	vec3 world_normal = normalize(vec3(-shape.y * wave_height, 1.0, -shape.z * wave_height));
	// Layer two independently scrolling detail normals over the broad wave normal.
	// The low-sun relief clamp still applies below, preventing sharp glint bands at
	// sunrise while preserving the small-scale broken reflection at daytime angles.
	vec3 detail_normal = _water_detail_normal(water_world_position.xz, TIME * wave_speed);
	world_normal = normalize(mix(world_normal, detail_normal, clamp(detail_normal_strength, 0.0, 1.0)));
	// Low-angle sunlight turns tiny animated normal changes into long, fast
	// specular bands. Keep the physical wave displacement, but reduce only the
	// shading normal relief near the horizon; the blend widens the sunrise and
	// sunset transition instead of switching the highlight on frame-to-frame.
	float sun_height_stability = smoothstep(0.03, 0.28, abs(sun_direction.y));
	float direct_normal_relief = mix(0.24, 0.80, sun_height_stability);
	vec3 calm_normal = normalize(mix(vec3(0.0, 1.0, 0.0), world_normal, direct_normal_relief));
	vec3 view_normal = normalize((VIEW_MATRIX * vec4(calm_normal, 0.0)).xyz);
	NORMAL = view_normal;

	float surface_depth = max(-VERTEX.z, 0.0001);
	float raw_scene_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	float scene_depth = _view_depth(SCREEN_UV, raw_scene_depth, INV_PROJECTION_MATRIX);
	float geometric_depth = max(scene_depth - surface_depth, 0.0);
	// Authored water cells share a flat gameplay bed. Their existing absorption
	// profiles also select a minimum optical column, so shallow/river/deep water
	// remain distinct while geometric depth still controls bank intersections,
	// refraction safety and edge foam.
	float terrain_optical_depth = optical_depth + max(depth_absorption - 5.0, 0.0) * 0.055;
	// Rising coastal water hides more of the layered bed; ebbing water exposes it.
	// Rivers use a zero tide_optical_depth profile and remain unchanged.
	terrain_optical_depth = max(terrain_optical_depth + tide_level * tide_optical_depth, 0.018);
	float water_depth = max(geometric_depth, terrain_optical_depth);

	// Distort only samples that remain behind the surface. This suppresses the
	// familiar refraction halo that otherwise pulls dry bank pixels into water.
	float depth_fade = smoothstep(0.0, 0.11, geometric_depth);
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

	// Sand dominates illuminated shallows, stones break it into cool patches,
	// algae occupies sheltered mid-depth water, and the final layer suppresses
	// all bed detail once little daylight reaches the floor. The actual rendered
	// floor remains visible below the tint, preserving quays, props and authored
	// bank materials seen through the surface.
	vec4 bed_layers = _seabed_layers(water_world_position.xz, water_depth);
	vec3 shallow_bed = (
		sand_bed_color * bed_layers.x
		+ stone_bed_color * bed_layers.y
		+ algae_bed_color * bed_layers.z
	);
	vec3 layered_bed = mix(shallow_bed, deep_bed_color, bed_layers.w);
	// The rendered terrain is physical geometry, but its grass texture should only
	// survive as a restrained hint right at a clear, shallow edge. Otherwise the
	// map's flat recessed bed makes it look like a meadow continues under water.
	float bed_detail_visibility = exp(-water_depth * 9.5) * 0.18;
	vec3 seabed = mix(layered_bed, floor_color * layered_bed * 1.18, bed_detail_visibility);

	// Wavelength-dependent transmission removes red first and blue last. This
	// creates depth lighting variation rather than uniformly darkening RGB.
	vec3 spectral_transmission = exp(-water_depth * depth_absorption * vec3(1.28, 0.72, 0.40));
	float absorption = 1.0 - dot(spectral_transmission, vec3(0.333333));
	vec3 transmitted = seabed * spectral_transmission;
	vec3 water_color = transmitted + deep_color * (vec3(1.0) - spectral_transmission) * 0.82;
	water_color = mix(water_color, shallow_color, (1.0 - absorption) * 0.12);

	// Caustics belong to the floor, so they fade with both depth and night. Keeping
	// the pattern in world space avoids UV seams between separate water materials.
	// The sun-disk visibility ramp is intentionally not used here: it spans only
	// a few degrees around the horizon and makes animated wave normals look like
	// a sudden band of moving illumination at sunrise and sunset. The wider solar
	// envelope keeps the transition visually continuous while the floor still
	// goes dark at night.
	float twilight_water_light = smoothstep(-0.25, 0.25, sun_direction.y);
	float caustic_visibility = exp(-water_depth * 7.0) * (1.0 - bed_layers.w) * twilight_water_light;
	float caustics = _bed_caustics(water_world_position.xz, TIME * wave_speed);
	water_color += highlight_color * caustics * caustic_visibility * caustic_strength;

	// Schlick Fresnel plus the PBR specular lobe produces stable sky reflection
	// and narrow sun glints at the shallow isometric viewing angle.
	float facing = clamp(dot(view_normal, normalize(VIEW)), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
	vec3 day_sky = mix(highlight_color, vec3(0.72, 0.82, 0.88), 0.32);
	vec3 night_sky = vec3(0.05, 0.07, 0.12);
	vec3 sky_reflection = mix(night_sky, day_sky, day_blend);
	// Keep the reflection legible from the gameplay camera. Fresnel still makes
	// grazing angles brightest, while this base share stops the shallow bed from
	// overpowering sky and sun reflections on broad, calm water.
	water_color = mix(water_color, sky_reflection, 0.34 + fresnel * mix(0.44, 0.62, day_blend));

	// WHY: DayNightCycle packs a solar day into 60s. Reflecting the catalog and
	// sun/moon through fully animated wave normals turns that race into frantic
	// pre-dawn sparkles on open sea. Celestial samples use a calmer normal so
	// waves still displace while glints stay readable instead of strobing.
	vec3 world_view = normalize((INV_VIEW_MATRIX * vec4(normalize(VIEW), 0.0)).xyz);
	vec3 reflection_normal = normalize(mix(vec3(0.0, 1.0, 0.0), world_normal, 0.38));
	vec3 reflected_sky_ray = normalize(reflect(-world_view, reflection_normal));
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
	foam *= smoothstep(0.012, 0.08, geometric_depth);

	// Downstream foam streaks for flowing rivers. The along-current coordinate
	// scrolls with time so the ribbons travel toward the far bank, while the
	// cross-current axis stays tight so the foam elongates into streaks rather
	// than round blobs. flow_strength == 0 leaves still water untouched.
	if (flow_strength > 0.0) {
		vec2 flow_dir = normalize(flow_direction + vec2(0.0001, 0.0));
		vec2 flow_cross = vec2(-flow_dir.y, flow_dir.x);
		float along = dot(water_world_position.xz, flow_dir) - TIME * wave_speed * flow_strength * 1.6;
		float across = dot(water_world_position.xz, flow_cross);
		vec2 streak_uv = vec2(across * 2.1, along * 0.55);
		float streak = _noise(streak_uv + _noise(streak_uv * 0.6 + vec2(9.1, 2.3)) * 1.4);
		float current_foam = smoothstep(0.60, 0.92, streak) * flow_strength;
		current_foam *= smoothstep(0.012, 0.08, geometric_depth);
		foam += current_foam * 0.30;
	}
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
"""
## Ground splat: two terrain pattern layers blended per vertex. CUSTOM0 carries
## pattern indices (x, y), blend weight (z), and brightness tone (w). COLOR.rgb
## is the palette tint lerp between the two terrain families.
const TERRAIN_BLEND_SHADER_CODE := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2DArray terrain_patterns;
uniform sampler2DArray cobble_patterns;
uniform sampler2D cobble_surface : filter_linear_mipmap, repeat_enable;
uniform float pattern_layers = 1.0;
uniform int cobblestone_layer = 12;
uniform int castle_paving_layer = 13;
uniform int timber_floor_layer = 15;
uniform int mud_layer = 8;
// Inclusive layer band covering trodden ground (farm soil through ash). These
// surfaces receive world-space relief so streets and yards stop reading as a
// single flat colour field between the paved strokes.
uniform int earth_layer_min = 6;
uniform int earth_layer_max = 11;
uniform float mud_wetness = 0.0;
uniform float natural_ground_uv_scale = 2.0;
uniform float natural_ground_variation = 0.72;
uniform float timber_floor_uv_scale = 2.0;

// CUSTOM0 is only readable in vertex(). Layer indices cannot be interpolated
// directly, so each corner resolves its own finished albedo and material
// weights before the rasterizer blends them across the triangle.
varying vec3 vertex_albedo;
varying float vertex_cobble_weight;
varying float vertex_earth_weight;
varying float vertex_mud_weight;
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
	vec3 primary = texture(terrain_patterns, vec3(fract(grass_uv), float(layer))).rgb;
	vec2 macro_uv = vec2(
		dot(grass_uv, vec2(0.61, 0.19)),
		dot(grass_uv, vec2(-0.17, 0.67))
	) * 0.58 + vec2(0.23, 0.41);
	vec3 macro = texture(terrain_patterns, vec3(fract(macro_uv), float(layer))).rgb;
	float patch = natural_noise(base_uv * 0.34 + vec2(4.8, 19.2));
	float fine = natural_noise(base_uv * 1.7 + vec2(31.4, 7.7));
	float variation = clamp(natural_ground_variation, 0.0, 1.0);
	float macro_mix = (0.14 + patch * 0.18) * variation;
	vec3 result = mix(primary, macro, macro_mix);
	result *= 1.0 + (fine - 0.5) * 0.20 * variation;
	return result;
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
	return layer == 0 || layer == 1 || layer == 2 || layer == 3 || layer == 15;
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
}
"""
# gdlint: enable=max-line-length

static var _cache: Dictionary = {}


static func reset() -> void:
	_cache.clear()


static func shader(name: String, code: String) -> Shader:
	var key := "shader:%s" % name
	if _cache.has(key):
		return _cache[key]
	var compiled_shader := Shader.new()
	compiled_shader.code = code
	_cache[key] = compiled_shader
	return compiled_shader


static func shader_resource(name: String, resource: Shader) -> Shader:
	var key := "shader:%s" % name
	if _cache.has(key):
		return _cache[key]
	_cache[key] = resource
	return resource
