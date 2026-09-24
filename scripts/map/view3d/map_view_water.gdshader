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
// Horizontal Gerstner sharpening. 0 is a sine sheet; ~1 peaks crests the way
// an FFT ocean's choppiness does, without a compute FFT on GL Compatibility.
uniform float choppiness = 0.85;
// 0 travels with the wind; ~0.4 bobs in place for sheltered harbors.
uniform float standing_wave_ratio = 0.12;
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
varying vec2 wave_sample_xz;
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

// Gerstner train. displacement is (dx, height, dz) before wave_height.
// normal_terms is (dh/dx, crest fold, dh/dz), also before wave_height.
// Keep the wavelengths and phases locked with BoatFloat3D.sample_wave.
void _accumulate_wave(
	vec2 position,
	vec2 direction,
	float frequency,
	float speed,
	float amplitude,
	float time,
	vec2 warp,
	float phase_offset,
	inout vec3 displacement,
	inout vec3 normal_terms
) {
	vec2 heading = normalize(direction);
	float spatial = dot(position + warp, heading) * frequency + phase_offset;
	float travel_s = sin(spatial - time * speed);
	float travel_c = cos(spatial - time * speed);
	float standing_s = sin(spatial) * sin(time * speed);
	float standing_c = cos(spatial) * sin(time * speed);
	float standing = clamp(standing_wave_ratio, 0.0, 1.0);
	float wave_s = mix(travel_s, standing_s, standing);
	float wave_c = mix(travel_c, standing_c, standing);
	// Sheltered water bobs more than it shears, so chop falls as standing rises.
	float chop = max(choppiness, 0.0) * (1.0 - standing * 0.65);
	displacement.x += chop * amplitude * heading.x * wave_c;
	displacement.y += amplitude * wave_s;
	displacement.z += chop * amplitude * heading.y * wave_c;
	float slope = frequency * amplitude * wave_c;
	normal_terms.x += heading.x * slope;
	normal_terms.y += chop * frequency * amplitude * wave_s;
	normal_terms.z += heading.y * slope;
}

// Three bands stand in for a JONSWAP FFT on GL Compatibility: swell and wind
// waves displace the mesh, ripples stay in the detail normal. Wavelengths stay
// longer than the 1/3-cell water grid so crests are geometric, not aliased.
void _water_field(vec2 position, float time, out vec3 displacement, out vec3 normal_terms) {
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
	displacement = vec3(0.0);
	normal_terms = vec3(0.0);
	// Swell: ~9 m and ~6 m, the scale a harbor camera can actually read.
	_accumulate_wave(position, vec2(1.0, 0.28), 0.62, 0.48, 0.62, time, warp, 0.3, displacement, normal_terms);
	_accumulate_wave(position, vec2(0.82, 0.55), 0.91, 0.61, 0.28, time, warp * 0.8, 1.7, displacement, normal_terms);
	// Wind waves: a few meters, still sampled by the subdivided water grid.
	_accumulate_wave(position, vec2(0.36, 1.0), 1.85, 1.05, 0.16, time, warp * 0.72, 2.1, displacement, normal_terms);
	_accumulate_wave(position, vec2(-0.55, 0.84), 2.70, 1.40, 0.08, time, fine_warp * wave_chaos, 4.2, displacement, normal_terms);
	displacement *= amplitude_variation;
	normal_terms *= amplitude_variation;
}

// Horizontal displacement Jacobian for crest whitecaps. Mirrors _water_field warp
// and wave trains; warp derivatives are omitted like common FFT-ocean stand-ins.
void _accumulate_wave_jacobian(
	vec2 position,
	vec2 direction,
	float frequency,
	float speed,
	float amplitude,
	float time,
	vec2 warp,
	float phase_offset,
	inout vec4 jacobian_terms
) {
	vec2 heading = normalize(direction);
	float spatial = dot(position + warp, heading) * frequency + phase_offset;
	float phase_travel = spatial - time * speed;
	float standing = clamp(standing_wave_ratio, 0.0, 1.0);
	float d_spatial_dx = heading.x * frequency;
	float d_spatial_dz = heading.y * frequency;
	float travel_ds_dx = cos(phase_travel) * d_spatial_dx;
	float travel_ds_dz = cos(phase_travel) * d_spatial_dz;
	float travel_dc_dx = -sin(phase_travel) * d_spatial_dx;
	float travel_dc_dz = -sin(phase_travel) * d_spatial_dz;
	float stand_ds_dx = cos(spatial) * sin(time * speed) * d_spatial_dx;
	float stand_ds_dz = cos(spatial) * sin(time * speed) * d_spatial_dz;
	float stand_dc_dx = -sin(spatial) * sin(time * speed) * d_spatial_dx;
	float stand_dc_dz = -sin(spatial) * sin(time * speed) * d_spatial_dz;
	float ds_dx = mix(travel_ds_dx, stand_ds_dx, standing);
	float ds_dz = mix(travel_ds_dz, stand_ds_dz, standing);
	float dc_dx = mix(travel_dc_dx, stand_dc_dx, standing);
	float dc_dz = mix(travel_dc_dz, stand_dc_dz, standing);
	float chop = max(choppiness, 0.0) * (1.0 - standing * 0.65);
	float ax = chop * amplitude * heading.x;
	float az = chop * amplitude * heading.y;
	jacobian_terms.x += ax * dc_dx;
	jacobian_terms.y += ax * dc_dz;
	jacobian_terms.z += az * dc_dx;
	jacobian_terms.w += az * dc_dz;
}

float _water_jacobian(vec2 position, float time) {
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
	vec4 jacobian_terms = vec4(0.0);
	_accumulate_wave_jacobian(position, vec2(1.0, 0.28), 0.62, 0.48, 0.62, time, warp, 0.3, jacobian_terms);
	_accumulate_wave_jacobian(position, vec2(0.82, 0.55), 0.91, 0.61, 0.28, time, warp * 0.8, 1.7, jacobian_terms);
	_accumulate_wave_jacobian(position, vec2(0.36, 1.0), 1.85, 1.05, 0.16, time, warp * 0.72, 2.1, jacobian_terms);
	_accumulate_wave_jacobian(position, vec2(-0.55, 0.84), 2.70, 1.40, 0.08, time, fine_warp * wave_chaos, 4.2, jacobian_terms);
	jacobian_terms *= amplitude_variation;
	return (1.0 + jacobian_terms.x) * (1.0 + jacobian_terms.w)
		- jacobian_terms.y * jacobian_terms.z;
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
	vec3 undisplaced_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wave_sample_xz = undisplaced_world.xz;
	shore_factor = clamp(COLOR.r, 0.0, 1.0);
	// Advect the wave field downstream so ripples travel along the current.
	vec2 flow_advection = flow_direction * (flow_strength * TIME * wave_speed * 0.6);
	vec3 displacement = vec3(0.0);
	vec3 normal_terms = vec3(0.0);
	_water_field(wave_sample_xz - flow_advection, TIME * wave_speed, displacement, normal_terms);
	// Low tide withdraws the clipped coastal edge instead of requiring a second
	// authored shoreline mesh. High tide reaches the original maximum contour.
	// The fragment stage clips the retreat band. Vertices rise and also shift
	// horizontally so crests peak instead of staying a displaced sine sheet.
	// Keep clipped patch seams pinned, but let the crest rise almost all the way
	// into the shallows. The old broad fade erased waves before they reached land.
	float displacement_fade = smoothstep(0.0, 0.16, shore_factor);
	float shoaling = mix(1.32, 1.0, smoothstep(0.0, 0.65, shore_factor));
	displacement *= wave_height * displacement_fade * shoaling;
	VERTEX.x += displacement.x;
	VERTEX.y += tide_height * tide_level + displacement.y;
	VERTEX.z += displacement.z;
	water_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float tide_coverage = tide_shore_retreat * max(-tide_level, 0.0);
	if (shore_factor < tide_coverage) {
		discard;
	}
	// Sample the undisplaced XZ. Evaluating Gerstner at the chopped position
	// feeds the displacement back into itself and swims the normal off the crest.
	vec2 flow_advection = flow_direction * (flow_strength * TIME * wave_speed * 0.6);
	vec3 displacement = vec3(0.0);
	vec3 normal_terms = vec3(0.0);
	_water_field(wave_sample_xz - flow_advection, TIME * wave_speed, displacement, normal_terms);
	float crest_lift = max(1.0 - normal_terms.y * wave_height, 0.15);
	vec3 world_normal = normalize(vec3(
		-normal_terms.x * wave_height,
		crest_lift,
		-normal_terms.z * wave_height
	));
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

	// Thin crests transmit more Baltic teal than troughs; fades with the same solar
	// envelope as floor caustics so night water stays dark without a bloom pass.
	float crest_subsurface = smoothstep(0.0, 0.30, max(normal_terms.y, 0.0));
	crest_subsurface *= choppiness * smoothstep(0.14, 0.48, shore_factor);
	float crest_sss_visibility = twilight_water_light * day_blend;
	vec3 crest_transmit_tint = mix(shallow_color, highlight_color, 0.58);
	water_color += crest_transmit_tint
		* crest_subsurface
		* crest_sss_visibility
		* (0.18 + (1.0 - absorption) * 0.22);

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

	// Jacobian whitecaps on open sea: folding Gerstner crests, not shoreline bands.
	// A short time lag leaves foam behind the advancing crest without a foam buffer.
	if (flow_strength <= 0.001) {
		float jacobian_now = _water_jacobian(wave_sample_xz - flow_advection, TIME * wave_speed);
		float jacobian_trail = _water_jacobian(
			wave_sample_xz - flow_advection,
			TIME * wave_speed - 0.42
		);
		float crest_fold = max(
			smoothstep(0.92, 0.55, jacobian_now),
			smoothstep(0.92, 0.55, jacobian_trail) * 0.68
		);
		crest_fold *= choppiness * foam_intensity * 1.35;
		crest_fold *= smoothstep(0.14, 0.48, shore_factor);
		crest_fold *= smoothstep(0.03, 0.10, geometric_depth);
		foam += crest_fold;
	}

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
