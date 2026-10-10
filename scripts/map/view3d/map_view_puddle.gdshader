shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Puddles are too shallow for a separate bed mesh, so the decal only darkens the
// ground it covers and adds a water specular lobe.
//
// WHY no screen texture: the project ships the GL Compatibility renderer, where
// sampling hint_screen_texture from these transparent decals produced flat white
// shards instead of the ground beneath them. A darkening film plus a real
// specular/fresnel response is both correct under alpha blending and cheaper,
// because it needs no back-buffer copy per puddle.
uniform vec3 water_tint : source_color = vec3(0.10, 0.11, 0.11);
uniform vec3 damp_tint : source_color = vec3(0.22, 0.20, 0.17);
uniform vec3 sheen_tint : source_color = vec3(0.62, 0.70, 0.80);
// R-1516: SkyWeather3D.puddle_wetness() / ground_dryness(). The same decal is the
// pool after rain and the baked crust of a drought; rain lowers dryness before any
// water stands, so the crust always fades out before the water fades in.
uniform float puddle_wetness = 0.0;
uniform float ground_dryness = 0.0;
// The only sampler in this shader (GL Compatibility caps a material at 16): crack
// relief comes from the plate's luminance, so no normal map is needed.
uniform sampler2D cracked_albedo : source_color, filter_linear_mipmap, repeat_enable;
// Plate repeats per world unit. District puddles are only ~0.3-0.7 wu across, so
// the plate runs ~3x denser than city_ground's 0.35 to fit several polygons per basin.
uniform float crack_scale = 1.1;
uniform vec3 silt_tint : source_color = vec3(0.64, 0.59, 0.52);

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

varying vec2 puddle_world_xz;
varying vec2 puddle_origin_xz;
varying vec4 puddle_soil;

void vertex() {
	// Instance colour: rgb = local soil tone, a = 1 where the basin may crack
	// (bare earth, never paving). See PUDDLE_CRUST_SOIL.
	// The tone is authored in sRGB like the palette; ALBEDO wants linear.
	puddle_soil = vec4(pow(COLOR.rgb, vec3(2.2)), COLOR.a);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	puddle_world_xz = world.xz;
	// Each MultiMesh instance receives a stable edge and raindrop phase without
	// requiring a unique material or texture allocation.
	puddle_origin_xz = (MODEL_MATRIX * vec4(vec3(0.0), 1.0)).xz;
}

void fragment() {
	vec2 local = UV * 2.0 - 1.0;
	float angle = atan(local.y, local.x);
	// Sampling the outline noise on the unit circle keeps it continuous across the
	// angle wrap; the earlier low harmonics produced a star rather than a pool.
	vec2 edge_direction = vec2(cos(angle), sin(angle));
	float edge_noise = _fbm(edge_direction * 1.35 + puddle_origin_xz * 0.37);
	float edge_radius = 0.70
		+ (edge_noise - 0.48) * 0.14
		+ sin(angle * 2.0 + puddle_origin_xz.x * 1.7) * 0.030
		+ sin(angle * 3.0 - puddle_origin_xz.y * 1.3) * 0.018;
	float edge_distance = length(local) - edge_radius;

	// Water ends first; a broader irregular damp band remains in the porous ground.
	// Keeping both masks continuous avoids the luminous hard-edged decal in the old
	// material while retaining a clearly readable waterline at close camera range.
	float water_mask = 1.0 - smoothstep(-0.025, 0.045, edge_distance);
	float wet_ground_mask = (1.0 - water_mask) * (1.0 - smoothstep(0.025, 0.16, edge_distance));
	float coverage = clamp(water_mask + wet_ground_mask, 0.0, 1.0);

	// Two very low-amplitude crossing wave trains break up the reflected highlight
	// without making this shallow, sheltered water look like a moving river.
	vec2 wave_a = normalize(vec2(0.91, 0.41));
	vec2 wave_b = normalize(vec2(-0.36, 0.93));
	vec2 slope = wave_a * cos(dot(puddle_world_xz, wave_a) * 12.0 + TIME * 0.34) * 0.010;
	slope += wave_b * cos(dot(puddle_world_xz, wave_b) * 18.5 - TIME * 0.27) * 0.006;

	// A deterministic occasional raindrop produces a fading circular normal wave.
	// It bends reflections only - no bright ring is painted into the albedo.
	float drop_phase = fract(TIME * 0.17 + _hash(floor(puddle_origin_xz * 7.0)));
	vec2 drop_center = vec2(
		_hash(floor(puddle_origin_xz * 11.0) + vec2(2.3, 7.1)),
		_hash(floor(puddle_origin_xz * 13.0) + vec2(5.7, 1.9))
	) * 0.70 - vec2(0.35);
	vec2 from_drop = local - drop_center;
	float drop_distance = length(from_drop);
	float ring_radius = drop_phase * 1.15;
	float ring_delta = drop_distance - ring_radius;
	float ring_envelope = exp(-abs(ring_delta) * 34.0) * (1.0 - drop_phase);
	float ring_slope = cos(ring_delta * 62.0) * ring_envelope * 0.035;
	slope += normalize(from_drop + vec2(0.0001)) * ring_slope;
	slope *= water_mask;

	vec3 world_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	vec3 view_normal = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	float fresnel = pow(1.0 - clamp(dot(view_normal, normalize(VIEW)), 0.0, 1.0), 5.0);

	// Alpha blending over the already-lit ground: a dark film is exactly the wet
	// darkening real water produces, and the sky sheen rides on top of it at
	// grazing angles instead of replacing the street with a bright decal.
	vec3 water_albedo = mix(damp_tint, water_tint, water_mask);
	float water_alpha = coverage * mix(0.30, 0.66, water_mask);
	water_alpha *= smoothstep(0.0005, 0.04, puddle_wetness);
	float water_roughness = mix(0.86, 0.075 + _noise(puddle_world_xz * 9.0) * 0.045, water_mask);
	// In Godot, 0.25 maps to roughly the F0 of water rather than a metallic mirror.
	float water_specular = mix(0.10, 0.25, water_mask);

	// Drought crust (R-1516, mirrors city_ground.gdshader): the basin bakes from its
	// centre outwards as dryness climbs past 0.45, and soaking rain shrinks it back.
	float crack_amount = smoothstep(0.45, 1.0, ground_dryness) * puddle_soil.a;
	float crust_radius = edge_radius * mix(0.35, 1.0, crack_amount);
	float crust_distance = length(local) - crust_radius;
	float crust_mask = (1.0 - smoothstep(-0.05, 0.03, crust_distance)) * step(0.001, crack_amount);
	// Pale silt settled last at the pool bottom: a faint rim just outside the crust.
	float silt_rim = (1.0 - crust_mask) * (1.0 - smoothstep(0.02, 0.14, crust_distance))
		* step(0.001, crack_amount);
	// The centre dried first, so its cracks mature first (fine net -> deep furrows).
	float crack_age = smoothstep(0.3, 0.95, crack_amount) * (1.0 - smoothstep(-0.35, -0.02, crust_distance));
	// World-space plate UV keeps neighbouring basins on one continuous crack field.
	vec2 cuv = puddle_world_xz * crack_scale;
	vec2 fuv = cuv * 3.5 + vec2(0.43, 0.17);
	float co = 1.5 / 1024.0;
	float cl = dot(texture(cracked_albedo, cuv).rgb, vec3(0.333));
	float cl_x = dot(texture(cracked_albedo, cuv + vec2(co, 0.0)).rgb, vec3(0.333));
	float cl_z = dot(texture(cracked_albedo, cuv + vec2(0.0, co)).rgb, vec3(0.333));
	float fl = dot(texture(cracked_albedo, fuv).rgb, vec3(0.333));
	// source_color samples are linear: plate median ~0.29, gaps under ~0.11 (the
	// darkest tenth). Fine hairlines carry weak contrast and give way to the coarse
	// furrows as the crust ages.
	float coarse_gap = 1.0 - smoothstep(0.03, 0.20, cl);
	float fine_gap = 1.0 - smoothstep(0.08, 0.24, fl);
	float gap = max(coarse_gap * mix(0.35, 1.0, crack_age), fine_gap * mix(0.55, 0.25, crack_age));
	// Luminance relief: a gap is a trench between raised, slightly curled plates.
	vec2 crack_slope = vec2(cl_x - cl, cl_z - cl) * mix(6.0, 18.0, crack_age) * crust_mask;
	// Plates: the local soil a shade paler where it baked, pulled towards silt; the
	// low plate alpha lets the real ground colour show through. Gaps: soil in shadow.
	vec3 plate_col = mix(puddle_soil.rgb * vec3(1.12, 1.08, 1.02), silt_tint, 0.32);
	vec3 gap_col = puddle_soil.rgb * 0.32;
	vec3 crust_albedo = mix(plate_col, gap_col, gap);
	crust_albedo = mix(silt_tint, crust_albedo, crust_mask);
	float crust_alpha = crust_mask * mix(0.46, 0.92, gap) + silt_rim * 0.16;
	// Fade the whole crust in from the 0.45 threshold instead of popping it on.
	crust_alpha *= smoothstep(0.0, 0.08, crack_amount);
	float crust_weight = step(0.001, crack_amount);

	// Height follows plate luminance, so the normal leans down its gradient.
	vec3 crust_normal = normalize(vec3(-crack_slope.x, 1.0, -crack_slope.y));
	NORMAL = normalize(mix(view_normal, (VIEW_MATRIX * vec4(crust_normal, 0.0)).xyz, crust_weight));
	ALBEDO = mix(water_albedo, crust_albedo, crust_weight);
	EMISSION = sheen_tint * fresnel * water_mask * 0.22 * (1.0 - crust_weight)
		* smoothstep(0.0005, 0.04, puddle_wetness);
	ALPHA = mix(water_alpha, crust_alpha, crust_weight);
	// Baked crust is chalk-matte with no water glint.
	ROUGHNESS = mix(water_roughness, 0.97, crust_weight);
	SPECULAR = mix(water_specular, 0.06, crust_weight);
}
