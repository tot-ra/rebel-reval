shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Puddles are too shallow for a separate bed mesh. Sampling the already-rendered
// ground preserves cobbles and mud beneath the water; the decal contributes only
// wet darkening, refraction, normals, and reflected light.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec3 wet_tint : source_color = vec3(0.72, 0.78, 0.82);
uniform vec3 sheen_tint : source_color = vec3(0.88, 0.92, 0.94);
uniform float refraction_strength = 0.032;

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

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	puddle_world_xz = world.xz;
	// Each MultiMesh instance receives a stable edge and raindrop phase without
	// requiring a unique material or texture allocation.
	puddle_origin_xz = (MODEL_MATRIX * vec4(vec3(0.0), 1.0)).xz;
}

void fragment() {
	vec2 local = UV * 2.0 - 1.0;
	float angle = atan(local.y, local.x);
	vec2 edge_direction = vec2(cos(angle), sin(angle));
	float edge_noise = _fbm(edge_direction * 1.85 + puddle_origin_xz * 0.37);
	float edge_radius = 0.68
		+ (edge_noise - 0.48) * 0.18
		+ sin(angle * 3.0 + puddle_origin_xz.x * 1.7) * 0.045
		+ sin(angle * 7.0 - puddle_origin_xz.y * 1.3) * 0.025;
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
	vec3 flat_view_normal = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = view_normal;

	// Offset from the flat normal, rather than the normal itself, prevents the
	// camera angle from shifting the whole image under every puddle.
	vec2 refraction_offset = (view_normal - flat_view_normal).xy * refraction_strength * water_mask;
	vec2 refracted_uv = clamp(SCREEN_UV + refraction_offset, vec2(0.001), vec2(0.999));
	vec3 transmitted_ground = textureLod(screen_texture, refracted_uv, 0.0).rgb;

	float fresnel = pow(1.0 - clamp(dot(view_normal, normalize(VIEW)), 0.0, 1.0), 5.0);
	float transmission = mix(0.58, 0.88, water_mask) * (1.0 - fresnel * 0.34);
	// Emission carries the pre-lit terrain exactly once; low ALBEDO leaves room for
	// Godot's dielectric specular lobe without washing the decal white.
	EMISSION = transmitted_ground * wet_tint * transmission;
	ALBEDO = mix(wet_tint * 0.035, sheen_tint * 0.075, fresnel * water_mask);
	ALPHA = coverage * mix(0.38, 0.70, water_mask);
	ROUGHNESS = mix(0.86, 0.075 + _noise(puddle_world_xz * 9.0) * 0.045, water_mask);
	// In Godot, 0.25 maps to roughly the F0 of water rather than a metallic mirror.
	SPECULAR = mix(0.10, 0.25, water_mask);
}
